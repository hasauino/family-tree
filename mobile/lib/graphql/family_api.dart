import '../models/family_node.dart';
import 'graphql_client.dart';

/// A piece of the tree: the nodes to add plus the parent→child edges between
/// them. Edges are `(fromId, toId)` pairs (parent id → child id).
class TreeFragment {
  TreeFragment({required this.nodes, required this.edges});
  final List<FamilyNode> nodes;
  final List<(int from, int to)> edges;
}

/// A single "search by name" match (id + the full name with ancestors).
class PersonSearchResult {
  PersonSearchResult({required this.id, required this.name});
  final int id;
  final String name;
}

/// The editable fields of a person, used to prefill the edit form.
class PersonDetails {
  PersonDetails({
    required this.id,
    required this.name,
    required this.designation,
    required this.history,
    this.parentId,
  });
  final int id;
  final String name;
  final String designation;
  final String history;
  final int? parentId;
}

/// The result of adding multiple children at once.
class AddChildrenResult {
  AddChildrenResult({required this.nodes, required this.warnings});
  final List<FamilyNode> nodes;
  final List<String> warnings;
}

/// The currently signed-in user, as reported by the `me` query.
class CurrentUser {
  CurrentUser({
    required this.username,
    required this.isStaff,
    required this.isAuthenticated,
  });
  final String? username;
  final bool isStaff;
  final bool isAuthenticated;
}

/// The result of a mutation that can fail with a user-facing message.
class MutationResult {
  MutationResult({required this.ok, this.message});
  final bool ok;
  final String? message;
}

/// Wraps the GraphQL queries used by the tree view.
///
/// * [bootstrap] mirrors the Django `person_tree` view: grandfather → father →
///   person → sons → grandsons, in a single nested `person` query.
/// * [connectedNodes] mirrors the interactive web behaviour: tapping a node
///   loads its parent and its (visible) children.
class FamilyApi {
  FamilyApi(this._client);
  final GraphQLClient _client;

  static const String _bootstrapDoc = r'''
    query Bootstrap($id: ID!) {
      person(id: $id) {
        id
        name
        designation
        history
        parent {
          id
          name
          designation
          history
          parent {
            id
            name
            designation
            history
            parent { id }
          }
        }
        children {
          id
          name
          designation
          history
          children {
            id
            name
            designation
            history
          }
        }
      }
    }
  ''';

  static const String _connectedDoc = r'''
    query Connected($id: Int!) {
      connectedNodes(id: $id) {
        parent { id label group opacity title font { strokeWidth } }
        children { id label group opacity title font { strokeWidth } }
      }
    }
  ''';

  /// Loads the initial tree centered on [personId].
  Future<TreeFragment> bootstrap(int personId) async {
    final data = await _client.query(_bootstrapDoc, variables: {'id': personId});
    final person = data['person'] as Map<String, dynamic>?;
    if (person == null) {
      throw PersonNotFoundException(personId);
    }

    final nodes = <FamilyNode>[];
    final edges = <(int, int)>[];
    final seen = <int>{};

    void addNode(FamilyNode node) {
      if (seen.add(node.id)) nodes.add(node);
    }

    final personId0 = int.parse(person['id'].toString());

    // --- ancestors: father, grandfather ---
    int? fatherId;
    final father = person['parent'] as Map<String, dynamic>?;
    if (father != null) {
      fatherId = int.parse(father['id'].toString());
      final grandfather = father['parent'] as Map<String, dynamic>?;
      int? grandfatherId;
      if (grandfather != null) {
        grandfatherId = int.parse(grandfather['id'].toString());
        final ggf = grandfather['parent'] as Map<String, dynamic>?;
        final ggfId = ggf == null ? null : int.parse(ggf['id'].toString());
        addNode(FamilyNode.fromPersonJson(grandfather, parentId: ggfId));
        addNode(FamilyNode.fromPersonJson(father, parentId: grandfatherId));
        edges.add((grandfatherId, fatherId));
      } else {
        addNode(FamilyNode.fromPersonJson(father, parentId: null));
      }
      edges.add((fatherId, personId0));
    }

    // --- the focused person ---
    addNode(FamilyNode.fromPersonJson(person, parentId: fatherId));

    // --- descendants: sons, then grandsons ---
    for (final c in (person['children'] as List<dynamic>? ?? const [])) {
      final child = c as Map<String, dynamic>;
      final childId = int.parse(child['id'].toString());
      addNode(FamilyNode.fromPersonJson(child, parentId: personId0));
      edges.add((personId0, childId));
      for (final g in (child['children'] as List<dynamic>? ?? const [])) {
        final grand = g as Map<String, dynamic>;
        final grandId = int.parse(grand['id'].toString());
        addNode(FamilyNode.fromPersonJson(grand, parentId: childId));
        edges.add((childId, grandId));
      }
    }

    return TreeFragment(nodes: nodes, edges: edges);
  }

  /// Loads the parent and visible children of [personId] (interactive expand).
  Future<TreeFragment> connectedNodes(int personId) async {
    final data =
        await _client.query(_connectedDoc, variables: {'id': personId});
    final connected = data['connectedNodes'] as Map<String, dynamic>?;
    if (connected == null) {
      return TreeFragment(nodes: const [], edges: const []);
    }

    final nodes = <FamilyNode>[];
    final edges = <(int, int)>[];

    final parent = connected['parent'] as Map<String, dynamic>?;
    if (parent != null) {
      final parentNode = FamilyNode.fromConnectedJson(parent);
      nodes.add(parentNode);
      edges.add((parentNode.id, personId));
    }

    for (final c in (connected['children'] as List<dynamic>? ?? const [])) {
      final childNode = FamilyNode.fromConnectedJson(c as Map<String, dynamic>);
      nodes.add(childNode);
      edges.add((personId, childNode.id));
    }

    return TreeFragment(nodes: nodes, edges: edges);
  }

  // --- Tree path ----------------------------------------------------------

  static const String _treePathDoc = r'''
    query TreePath($fromId: Int!, $toId: Int!) {
      treePath(fromId: $fromId, toId: $toId) {
        nodes { id label group opacity title font { strokeWidth } }
        edges { fromId toId }
      }
    }
  ''';

  /// Loads the chain of nodes connecting ancestor [fromId] to descendant
  /// [toId] — the mobile equivalent of the web "from ancestor to person"
  /// navigation page. Throws [NoTreePathException] when no such chain exists
  /// (either person is missing, not visible, or [fromId] is not an ancestor
  /// of [toId]).
  Future<TreeFragment> treePath(int fromId, int toId) async {
    final data = await _client.query(
      _treePathDoc,
      variables: {'fromId': fromId, 'toId': toId},
    );
    final path = data['treePath'] as Map<String, dynamic>?;
    if (path == null) throw NoTreePathException();

    final nodes = [
      for (final n in (path['nodes'] as List<dynamic>? ?? const []))
        FamilyNode.fromConnectedJson(n as Map<String, dynamic>),
    ];
    final edges = [
      for (final e in (path['edges'] as List<dynamic>? ?? const []))
        (
          (e as Map<String, dynamic>)['fromId'] as int,
          e['toId'] as int,
        ),
    ];
    return TreeFragment(nodes: nodes, edges: edges);
  }

  // --- Account ------------------------------------------------------------

  static const String _meDoc = r'''
    query Me {
      me { username isStaff isAuthenticated }
    }
  ''';

  /// Returns the signed-in user, or null when the response has no user.
  Future<CurrentUser?> me() async {
    final data = await _client.query(_meDoc);
    final me = data['me'] as Map<String, dynamic>?;
    if (me == null) return null;
    return CurrentUser(
      username: me['username'] as String?,
      isStaff: (me['isStaff'] as bool?) ?? false,
      isAuthenticated: (me['isAuthenticated'] as bool?) ?? false,
    );
  }

  // --- Search -------------------------------------------------------------

  static const String _searchDoc = r'''
    query Search($query: String!) {
      searchPersons(query: $query) { id name }
    }
  ''';

  /// Live search by (the start of) a name, mirroring the web search box.
  Future<List<PersonSearchResult>> searchPersons(String query) async {
    final data = await _client.query(_searchDoc, variables: {'query': query});
    final results = data['searchPersons'] as List<dynamic>? ?? const [];
    return [
      for (final r in results)
        PersonSearchResult(
          id: (r as Map<String, dynamic>)['id'] as int,
          name: (r['name'] as String?) ?? '',
        ),
    ];
  }

  // --- Mutations (require an authenticated session) -----------------------

  static const String _canDeleteDoc = r'''
    query CanDelete($id: Int!) { canDelete(id: $id) }
  ''';

  /// Whether the current user is allowed to delete [personId].
  Future<bool> canDelete(int personId) async {
    final data = await _client.query(_canDeleteDoc, variables: {'id': personId});
    return (data['canDelete'] as bool?) ?? false;
  }

  static const String _publishStatusDoc = r'''
    query PublishStatus($id: ID!) {
      person(id: $id) { published bookmarked }
    }
  ''';

  /// The publish/bookmark flags for [personId] (used to pick which staff
  /// actions to offer).
  Future<({bool published, bool bookmarked})> publishStatus(
    int personId,
  ) async {
    final data =
        await _client.query(_publishStatusDoc, variables: {'id': personId});
    final person = data['person'] as Map<String, dynamic>?;
    return (
      published: (person?['published'] as bool?) ?? false,
      bookmarked: (person?['bookmarked'] as bool?) ?? false,
    );
  }

  static const String _personDetailsDoc = r'''
    query PersonDetails($id: ID!) {
      person(id: $id) { id name designation history parent { id } }
    }
  ''';

  /// Fetches the raw editable fields of [personId] to prefill the edit form.
  Future<PersonDetails> personDetails(int personId) async {
    final data =
        await _client.query(_personDetailsDoc, variables: {'id': personId});
    final person = data['person'] as Map<String, dynamic>?;
    if (person == null) throw PersonNotFoundException(personId);
    final parentJson = person['parent'] as Map<String, dynamic>?;
    return PersonDetails(
      id: int.parse(person['id'].toString()),
      name: (person['name'] as String?) ?? '',
      designation: (person['designation'] as String?) ?? '',
      history: (person['history'] as String?) ?? '',
      parentId: parentJson != null
          ? int.parse(parentJson['id'].toString())
          : null,
    );
  }

  static const String _editPersonDoc = r'''
    mutation EditPerson(
      $id: Int!, $name: String, $designation: String, $history: String
    ) {
      editPerson(
        id: $id, name: $name, designation: $designation, history: $history
      ) {
        id label group opacity title font { strokeWidth }
        ok message
      }
    }
  ''';

  /// Updates [personId]'s name/designation/history and returns the refreshed
  /// node. Throws [GraphQLException] with the backend message on failure.
  Future<FamilyNode> editPerson(
    int personId, {
    required String name,
    required String designation,
    required String history,
  }) async {
    final data = await _client.query(_editPersonDoc, variables: {
      'id': personId,
      'name': name,
      'designation': designation,
      'history': history,
    });
    final result = data['editPerson'] as Map<String, dynamic>?;
    if (result == null || result['ok'] != true) {
      throw GraphQLException(
        (result?['message'] as String?) ?? 'Could not save changes.',
      );
    }
    return FamilyNode.fromConnectedJson(result);
  }

  static const String _addPersonDoc = r'''
    mutation AddPerson($id: Int!, $childName: String!) {
      addPerson(id: $id, childName: $childName) {
        id label group opacity title font { strokeWidth }
        ok message
      }
    }
  ''';

  /// Adds a child named [childName] under [parentId]. Returns the new node on
  /// success, or throws [GraphQLException] with the backend message on failure.
  Future<FamilyNode> addPerson(int parentId, String childName) async {
    final data = await _client.query(
      _addPersonDoc,
      variables: {'id': parentId, 'childName': childName},
    );
    final result = data['addPerson'] as Map<String, dynamic>?;
    if (result == null || result['ok'] != true) {
      throw GraphQLException(
        (result?['message'] as String?) ?? 'Could not add child.',
      );
    }
    return FamilyNode.fromConnectedJson(result);
  }

  static const String _addChildrenDoc = r'''
    mutation AddChildren($id: Int!, $childNames: [String!]!) {
      addChildren(id: $id, childNames: $childNames) {
        nodes { id label group opacity title font { strokeWidth } }
        warnings
        ok message
      }
    }
  ''';

  /// Adds multiple children under [parentId] in one call. Returns the new
  /// (or re-used) nodes and a list of names that already existed.
  Future<AddChildrenResult> addChildren(
    int parentId,
    List<String> childNames,
  ) async {
    final data = await _client.query(
      _addChildrenDoc,
      variables: {'id': parentId, 'childNames': childNames},
    );
    final result = data['addChildren'] as Map<String, dynamic>?;
    if (result == null || result['ok'] != true) {
      throw GraphQLException(
        (result?['message'] as String?) ?? 'Could not add children.',
      );
    }
    final nodes = [
      for (final n in (result['nodes'] as List<dynamic>? ?? const []))
        FamilyNode.fromConnectedJson(n as Map<String, dynamic>),
    ];
    final warnings = [
      for (final w in (result['warnings'] as List<dynamic>? ?? const []))
        w as String,
    ];
    return AddChildrenResult(nodes: nodes, warnings: warnings);
  }

  static const String _movePersonDoc = r'''
    mutation MovePerson($id: Int!, $newParentId: Int!) {
      movePerson(id: $id, newParentId: $newParentId) {
        ok message
      }
    }
  ''';

  /// Moves [personId] to be a child of [newParentId]. Throws [GraphQLException]
  /// on failure (permission denied, cycle detected, etc.).
  Future<MutationResult> movePerson(
    int personId, {
    required int newParentId,
  }) async {
    final data = await _client.query(
      _movePersonDoc,
      variables: {'id': personId, 'newParentId': newParentId},
    );
    final result = data['movePerson'] as Map<String, dynamic>?;
    return MutationResult(
      ok: (result?['ok'] as bool?) ?? false,
      message: result?['message'] as String?,
    );
  }

  static const String _deletePersonDoc = r'''
    mutation DeletePerson($id: Int!) {
      deletePerson(id: $id) { ok message }
    }
  ''';

  Future<MutationResult> deletePerson(int personId) =>
      _simpleMutation(_deletePersonDoc, 'deletePerson', personId);

  static const String _publishDoc = r'''
    mutation Publish($id: Int!) { publishPerson(id: $id) { ok message } }
  ''';

  Future<MutationResult> publishPerson(int personId) =>
      _simpleMutation(_publishDoc, 'publishPerson', personId);

  static const String _unpublishDoc = r'''
    mutation Unpublish($id: Int!) { unpublishPerson(id: $id) { ok message } }
  ''';

  Future<MutationResult> unpublishPerson(int personId) =>
      _simpleMutation(_unpublishDoc, 'unpublishPerson', personId);

  static const String _bookmarkDoc = r'''
    mutation Bookmark($id: Int!) { bookmarkPerson(id: $id) { ok message } }
  ''';

  Future<MutationResult> bookmarkPerson(int personId) =>
      _simpleMutation(_bookmarkDoc, 'bookmarkPerson', personId);

  static const String _unbookmarkDoc = r'''
    mutation Unbookmark($id: Int!) { unbookmarkPerson(id: $id) { ok message } }
  ''';

  Future<MutationResult> unbookmarkPerson(int personId) =>
      _simpleMutation(_unbookmarkDoc, 'unbookmarkPerson', personId);

  /// Runs a mutation shaped like `field(id: $id) { ok message }`.
  Future<MutationResult> _simpleMutation(
    String document,
    String field,
    int personId,
  ) async {
    final data = await _client.query(document, variables: {'id': personId});
    final result = data[field] as Map<String, dynamic>?;
    return MutationResult(
      ok: (result?['ok'] as bool?) ?? false,
      message: result?['message'] as String?,
    );
  }
}
