import 'package:flutter/material.dart';

import '../models/family_node.dart';
import 'graphql_client.dart';

/// A piece of the tree: the nodes to add plus the parent→child edges between
/// them. Edges are `(fromId, toId)` pairs (parent id → child id).
class TreeFragment {
  TreeFragment({required this.nodes, required this.edges});
  final List<FamilyNode> nodes;
  final List<(int from, int to)> edges;
}

/// The result of a "connect two people" query: the [fragment] to render, the
/// ordered [pathIds] forming the route to highlight (from → meeting → to), and
/// metadata describing the relationship.
///
/// [isDirect] is true when one endpoint is an ancestor of the other; then
/// [meetingId] is that ancestor and one of [fromGenerations]/[toGenerations]
/// is 0. Otherwise [meetingId] is their lowest common ancestor and each count
/// is the number of generations between an endpoint and the meeting node.
class TreePathResult {
  TreePathResult({
    required this.fragment,
    required this.pathIds,
    required this.meetingId,
    required this.fromGenerations,
    required this.toGenerations,
    required this.isDirect,
  });
  final TreeFragment fragment;
  final List<int> pathIds;
  final int meetingId;
  final int fromGenerations;
  final int toGenerations;
  final bool isDirect;
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

/// Which sign-in/sign-up methods the backend has enabled and configured, from
/// the `authConfig` query. The UI shows a method only when its flag is true, so
/// an un-credentialed provider never appears.
class AuthConfig {
  const AuthConfig({
    required this.emailEnabled,
    required this.googleEnabled,
    required this.appleEnabled,
    required this.facebookEnabled,
    required this.requireActivation,
  });

  final bool emailEnabled;
  final bool googleEnabled;
  final bool appleEnabled;
  final bool facebookEnabled;

  /// Whether email sign-up needs an activation link before the account works.
  final bool requireActivation;

  /// A safe default used before the backend responds (or if it can't be
  /// reached): only email, no social, activation required.
  static const fallback = AuthConfig(
    emailEnabled: true,
    googleEnabled: false,
    appleEnabled: false,
    facebookEnabled: false,
    requireActivation: true,
  );

  bool get anySocial => googleEnabled || appleEnabled || facebookEnabled;
}

/// Outcome of an email registration: either the account is live and the caller
/// is now signed in ([signedIn] with a [user]), or an activation email was sent
/// and the user must click the link before signing in ([activationSent]).
enum RegisterOutcome { signedIn, activationSent }

class RegisterResult {
  RegisterResult(this.outcome, this.user);
  final RegisterOutcome outcome;
  final CurrentUser? user;
}

/// Kind of a node in the home radial tree.
enum HomeNodeKind { root, tag, bookmark }

/// A node in the home radial tree (virtual root, admin tag, or bookmarked person).
class HomeNode {
  HomeNode({
    required this.id,
    required this.kind,
    required this.label,
    this.group = 'g0',
    this.title,
    this.opacity = 1.0,
    this.colorOverride,
    this.fontColorOverride,
    this.fontSizeOverride,
  });

  final int id;
  final HomeNodeKind kind;
  final String label;
  final String group;
  final String? title;
  final double opacity;

  /// Admin-configured override color (hex, no '#'), or null for the default
  /// palette color.
  final String? colorOverride;

  /// Admin-configured label text color (hex, no '#'), or null for the default.
  final String? fontColorOverride;

  /// Admin-configured label font size, or null for the default.
  final int? fontSizeOverride;

  bool get isRoot => kind == HomeNodeKind.root;
  bool get isTag => kind == HomeNodeKind.tag;
  bool get isBookmark => kind == HomeNodeKind.bookmark;

  Color get color {
    if (colorOverride != null && colorOverride!.isNotEmpty) {
      final hex = int.tryParse(colorOverride!, radix: 16);
      if (hex != null) return Color(0xFF000000 | hex);
    }
    final n = int.tryParse(group.replaceFirst('g', '')) ?? 0;
    return kGroupColors[n % kColorCount];
  }

  /// Admin-configured label text color, or null for the default.
  Color? get fontColor {
    if (fontColorOverride == null || fontColorOverride!.isEmpty) return null;
    final hex = int.tryParse(fontColorOverride!, radix: 16);
    return hex == null ? null : Color(0xFF000000 | hex);
  }

  String get initial {
    final t = label.trim();
    return t.isEmpty ? '?' : t.characters.first.toUpperCase();
  }

  String? get subtitle {
    final t = title?.trim();
    if (t == null || t.isEmpty) return null;
    final firstLine = t.split('\n').first.trim();
    return firstLine.isEmpty ? null : firstLine;
  }
}

/// A lightweight tag record returned by listTags and createTag.
class TagInfo {
  TagInfo({required this.id, required this.name, this.parentId});
  final int id;
  final String name;

  /// ID of the parent tag, or null if this is a top-level tag.
  final int? parentId;
}

/// Admin-configurable parameters controlling how home-tree node size scales
/// with depth from the global tree root.
class NodeSizeConfig {
  const NodeSizeConfig({
    required this.maxScale,
    required this.minScale,
    required this.decay,
    this.padding = 8.0,
    this.spreadDegrees = 160.0,
    this.edgeFactor = 2.0,
  });

  /// Visual scale of nodes at the root.
  final double maxScale;

  /// Visual scale of the deepest (leaf) nodes.
  final double minScale;

  /// How quickly node size shrinks per generation away from the root.
  final double decay;

  /// Gap (in logical pixels) kept between a node disk and its parent / its
  /// siblings when packing the home tree. 0 packs disks edge-to-edge.
  final double padding;

  /// Preferred breadth (in degrees) of the forward fan a non-root node spreads
  /// its children over, centered on its outward axis. Wider = shorter edges
  /// when a node has many children.
  final double spreadDegrees;

  /// Caps how far a child may sit from its parent, as a multiple of the
  /// minimum (no-overlap) spacing. Lower = shorter edges; when the cap is hit,
  /// the fan widens past [spreadDegrees] instead of stretching the edges.
  final double edgeFactor;

  static const fallback = NodeSizeConfig(
    maxScale: 1.2,
    minScale: 0.5,
    decay: 0.15,
    padding: 8.0,
    spreadDegrees: 160.0,
    edgeFactor: 2.0,
  );
}

/// The home tree payload: all nodes (root + tags + bookmarks) and the edges.
class HomeData {
  HomeData({
    required this.nodes,
    required this.edges,
    this.centerId = 0,
    this.nodeSizeConfig = NodeSizeConfig.fallback,
  });
  final List<HomeNode> nodes;
  final List<(int from, int to)> edges;

  /// ID of the home node to center the view on (admin-configurable).
  /// 0 means the virtual root (default).
  final int centerId;

  /// Admin-configurable node size scaling parameters.
  final NodeSizeConfig nodeSizeConfig;
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
        published
        parent {
          id
          name
          designation
          history
          published
          parent {
            id
            name
            designation
            history
            published
            parent { id }
          }
        }
        children {
          id
          name
          designation
          history
          published
          children {
            id
            name
            designation
            history
            published
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
  /// [isStaff] is forwarded to [FamilyNode.fromPersonJson] so that admins see
  /// unpublished nodes dimmed (opacity 0.3) from the very first load.
  Future<TreeFragment> bootstrap(int personId, {bool isStaff = false}) async {
    final data = await _client.query(
      _bootstrapDoc,
      variables: {'id': personId},
    );
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
        addNode(
          FamilyNode.fromPersonJson(
            grandfather,
            parentId: ggfId,
            isStaff: isStaff,
          ),
        );
        addNode(
          FamilyNode.fromPersonJson(
            father,
            parentId: grandfatherId,
            isStaff: isStaff,
          ),
        );
        edges.add((grandfatherId, fatherId));
      } else {
        addNode(
          FamilyNode.fromPersonJson(father, parentId: null, isStaff: isStaff),
        );
      }
      edges.add((fatherId, personId0));
    }

    // --- the focused person ---
    addNode(
      FamilyNode.fromPersonJson(person, parentId: fatherId, isStaff: isStaff),
    );

    // --- descendants: sons, then grandsons ---
    for (final c in (person['children'] as List<dynamic>? ?? const [])) {
      final child = c as Map<String, dynamic>;
      final childId = int.parse(child['id'].toString());
      addNode(
        FamilyNode.fromPersonJson(child, parentId: personId0, isStaff: isStaff),
      );
      edges.add((personId0, childId));
      for (final g in (child['children'] as List<dynamic>? ?? const [])) {
        final grand = g as Map<String, dynamic>;
        final grandId = int.parse(grand['id'].toString());
        addNode(
          FamilyNode.fromPersonJson(grand, parentId: childId, isStaff: isStaff),
        );
        edges.add((childId, grandId));
      }
    }

    return TreeFragment(nodes: nodes, edges: edges);
  }

  /// Loads the parent and visible children of [personId] (interactive expand).
  Future<TreeFragment> connectedNodes(int personId) async {
    final data = await _client.query(
      _connectedDoc,
      variables: {'id': personId},
    );
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
        pathIds
        meetingId
        fromGenerations
        toGenerations
        isDirect
      }
    }
  ''';

  /// Connects two people in the tree. When [fromId] is an ancestor of [toId]
  /// (or vice-versa) the result describes the straight line between them;
  /// otherwise it runs up to their lowest common ancestor. Throws
  /// [NoTreePathException] when no connection exists (either person is missing
  /// or not visible, or the two share no common ancestor).
  Future<TreePathResult> treePath(int fromId, int toId) async {
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
        ((e as Map<String, dynamic>)['fromId'] as int, e['toId'] as int),
    ];
    return TreePathResult(
      fragment: TreeFragment(nodes: nodes, edges: edges),
      pathIds: [
        for (final id in (path['pathIds'] as List<dynamic>? ?? const []))
          id as int,
      ],
      meetingId: path['meetingId'] as int,
      fromGenerations: path['fromGenerations'] as int,
      toGenerations: path['toGenerations'] as int,
      isDirect: path['isDirect'] as bool? ?? false,
    );
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

  // --- Sign in / sign up --------------------------------------------------

  static const String _authConfigDoc = r'''
    query AuthConfig {
      authConfig {
        emailEnabled googleEnabled appleEnabled facebookEnabled requireActivation
      }
    }
  ''';

  /// Which sign-in methods the backend offers. Falls back to email-only if the
  /// field is missing (older backend) so the app still works.
  Future<AuthConfig> authConfig() async {
    final data = await _client.query(_authConfigDoc);
    final cfg = data['authConfig'] as Map<String, dynamic>?;
    if (cfg == null) return AuthConfig.fallback;
    return AuthConfig(
      emailEnabled: (cfg['emailEnabled'] as bool?) ?? true,
      googleEnabled: (cfg['googleEnabled'] as bool?) ?? false,
      appleEnabled: (cfg['appleEnabled'] as bool?) ?? false,
      facebookEnabled: (cfg['facebookEnabled'] as bool?) ?? false,
      requireActivation: (cfg['requireActivation'] as bool?) ?? true,
    );
  }

  static const String _passwordLoginDoc = r'''
    mutation PasswordLogin($identifier: String!, $password: String!) {
      passwordLogin(identifier: $identifier, password: $password) {
        ok message user { username isStaff isAuthenticated }
      }
    }
  ''';

  /// Signs in with an email or username plus password. Throws
  /// [AuthFailedException] (with the backend's message) on bad credentials.
  Future<CurrentUser> passwordLogin(String identifier, String password) async {
    final data = await _client.query(
      _passwordLoginDoc,
      variables: {'identifier': identifier, 'password': password},
    );
    return _userFromAuthReply(data['passwordLogin'] as Map<String, dynamic>?);
  }

  static const String _socialLoginDoc = r'''
    mutation SocialLogin($provider: String!, $token: String!, $firstName: String, $lastName: String) {
      socialLogin(provider: $provider, token: $token, firstName: $firstName, lastName: $lastName) {
        ok message user { username isStaff isAuthenticated }
      }
    }
  ''';

  /// Exchanges a verified provider token for a session. [firstName]/[lastName]
  /// let the client forward what Apple gives only on first sign-in.
  Future<CurrentUser> socialLogin(
    String provider,
    String token, {
    String? firstName,
    String? lastName,
  }) async {
    final data = await _client.query(
      _socialLoginDoc,
      variables: {
        'provider': provider,
        'token': token,
        'firstName': firstName,
        'lastName': lastName,
      },
    );
    return _userFromAuthReply(data['socialLogin'] as Map<String, dynamic>?);
  }

  static const String _registerEmailDoc = r'''
    mutation RegisterEmail($email: String!, $password: String!, $firstName: String, $lastName: String) {
      registerEmail(email: $email, password: $password, firstName: $firstName, lastName: $lastName) {
        ok message user { username isStaff isAuthenticated }
      }
    }
  ''';

  /// Registers a new email account. Returns whether an activation email was
  /// sent or the user was signed in immediately. Throws [AuthFailedException]
  /// on validation errors (duplicate email, weak password, ...).
  Future<RegisterResult> registerEmail(
    String email,
    String password, {
    String? firstName,
    String? lastName,
  }) async {
    final data = await _client.query(
      _registerEmailDoc,
      variables: {
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
      },
    );
    final reply = data['registerEmail'] as Map<String, dynamic>?;
    if (reply == null || reply['ok'] != true) {
      throw AuthFailedException(
        (reply?['message'] as String?) ?? 'Registration failed.',
      );
    }
    final user = reply['user'] as Map<String, dynamic>?;
    if (user == null) {
      return RegisterResult(RegisterOutcome.activationSent, null);
    }
    return RegisterResult(RegisterOutcome.signedIn, _user(user));
  }

  /// Unwraps an `{ok, message, user}` auth reply into a [CurrentUser], throwing
  /// [AuthFailedException] when the backend reports failure.
  CurrentUser _userFromAuthReply(Map<String, dynamic>? reply) {
    final user = reply?['user'] as Map<String, dynamic>?;
    if (reply == null || reply['ok'] != true || user == null) {
      throw AuthFailedException(
        (reply?['message'] as String?) ?? 'Sign-in failed.',
      );
    }
    return _user(user);
  }

  CurrentUser _user(Map<String, dynamic> user) => CurrentUser(
    username: user['username'] as String?,
    isStaff: (user['isStaff'] as bool?) ?? false,
    isAuthenticated: (user['isAuthenticated'] as bool?) ?? true,
  );

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
    final data = await _client.query(
      _canDeleteDoc,
      variables: {'id': personId},
    );
    return (data['canDelete'] as bool?) ?? false;
  }

  static const String _deleteInfoDoc = r'''
    query DeleteInfo($id: Int!) {
      deleteInfo(id: $id) { descendantCount isRootWithSingleChild }
    }
  ''';

  /// Descendant count and whether [personId] is a root with exactly one child.
  Future<({int descendantCount, bool isRootWithSingleChild})> deleteInfo(
    int personId,
  ) async {
    final data = await _client.query(
      _deleteInfoDoc,
      variables: {'id': personId},
    );
    final info = data['deleteInfo'] as Map<String, dynamic>? ?? {};
    return (
      descendantCount: (info['descendantCount'] as int?) ?? 0,
      isRootWithSingleChild: (info['isRootWithSingleChild'] as bool?) ?? false,
    );
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
    final data = await _client.query(
      _publishStatusDoc,
      variables: {'id': personId},
    );
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
    final data = await _client.query(
      _personDetailsDoc,
      variables: {'id': personId},
    );
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
    final data = await _client.query(
      _editPersonDoc,
      variables: {
        'id': personId,
        'name': name,
        'designation': designation,
        'history': history,
      },
    );
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

  static const String _addParentDoc = r'''
    mutation AddParent($id: Int!, $parentName: String!) {
      addParent(id: $id, parentName: $parentName) {
        id label group opacity title font { strokeWidth }
        ok message
      }
    }
  ''';

  /// Creates a new parent node above [personId] (which must currently be a
  /// root with no parent). Returns the new parent node on success.
  Future<FamilyNode> addParent(int personId, String parentName) async {
    final data = await _client.query(
      _addParentDoc,
      variables: {'id': personId, 'parentName': parentName},
    );
    final result = data['addParent'] as Map<String, dynamic>?;
    if (result == null || result['ok'] != true) {
      throw GraphQLException(
        (result?['message'] as String?) ?? 'Could not add parent.',
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

  // --- Home tree --------------------------------------------------------------

  static const String _homeTreeDoc = r'''
    query HomeTree {
      homeTree {
        nodes { id kind label group title opacity color fontColor fontSize }
        edges { fromId toId }
        centerId
        nodeSizeConfig { maxScale minScale decay padding spreadDegrees edgeFactor }
      }
    }
  ''';

  Future<HomeData> homeTree() async {
    final data = await _client.query(_homeTreeDoc);
    final tree = data['homeTree'] as Map<String, dynamic>?;
    if (tree == null) return HomeData(nodes: [], edges: []);

    final nodes = [
      for (final n in (tree['nodes'] as List<dynamic>? ?? const []))
        HomeNode(
          id: (n as Map<String, dynamic>)['id'] as int,
          kind: _parseKind((n['kind'] as String?) ?? 'bookmark'),
          label: (n['label'] as String?) ?? '',
          group: (n['group'] as String?) ?? 'g0',
          title: n['title'] as String?,
          opacity: (n['opacity'] as num?)?.toDouble() ?? 1.0,
          colorOverride: n['color'] as String?,
          fontColorOverride: n['fontColor'] as String?,
          fontSizeOverride: n['fontSize'] as int?,
        ),
    ];

    final edges = [
      for (final e in (tree['edges'] as List<dynamic>? ?? const []))
        ((e as Map<String, dynamic>)['fromId'] as int, e['toId'] as int),
    ];

    final sizeConfig = tree['nodeSizeConfig'] as Map<String, dynamic>?;

    return HomeData(
      nodes: nodes,
      edges: edges,
      centerId: (tree['centerId'] as int?) ?? 0,
      nodeSizeConfig: sizeConfig == null
          ? NodeSizeConfig.fallback
          : NodeSizeConfig(
              maxScale:
                  (sizeConfig['maxScale'] as num?)?.toDouble() ??
                  NodeSizeConfig.fallback.maxScale,
              minScale:
                  (sizeConfig['minScale'] as num?)?.toDouble() ??
                  NodeSizeConfig.fallback.minScale,
              decay:
                  (sizeConfig['decay'] as num?)?.toDouble() ??
                  NodeSizeConfig.fallback.decay,
              padding:
                  (sizeConfig['padding'] as num?)?.toDouble() ??
                  NodeSizeConfig.fallback.padding,
              spreadDegrees:
                  (sizeConfig['spreadDegrees'] as num?)?.toDouble() ??
                  NodeSizeConfig.fallback.spreadDegrees,
              edgeFactor:
                  (sizeConfig['edgeFactor'] as num?)?.toDouble() ??
                  NodeSizeConfig.fallback.edgeFactor,
            ),
    );
  }

  static HomeNodeKind _parseKind(String raw) => switch (raw) {
    'root' => HomeNodeKind.root,
    'tag' => HomeNodeKind.tag,
    _ => HomeNodeKind.bookmark,
  };

  // --- Tag management (staff only) ------------------------------------------

  static const String _listTagsDoc = r'''
    query ListTags {
      listTags { id name parentId }
    }
  ''';

  Future<List<TagInfo>> listTags() async {
    final data = await _client.query(_listTagsDoc);
    return [
      for (final t in (data['listTags'] as List<dynamic>? ?? const []))
        TagInfo(
          id: (t as Map<String, dynamic>)['id'] as int,
          name: (t['name'] as String?) ?? '',
          parentId: t['parentId'] as int?,
        ),
    ];
  }

  static const String _createTagDoc = r'''
    mutation CreateTag($name: String!, $parentNodeId: Int) {
      createTag(name: $name, parentNodeId: $parentNodeId) { ok message id name }
    }
  ''';

  /// Creates a new tag, optionally nested under the home-tree node
  /// [parentNodeId] (a negative tag id, a positive bookmarked person id, or
  /// null/0 for top-level).
  Future<({bool ok, String? message, int? id, String? name})> createTag(
    String name, {
    int? parentNodeId,
  }) async {
    final data = await _client.query(
      _createTagDoc,
      variables: {'name': name, 'parentNodeId': parentNodeId},
    );
    final r = data['createTag'] as Map<String, dynamic>?;
    return (
      ok: (r?['ok'] as bool?) ?? false,
      message: r?['message'] as String?,
      id: r?['id'] as int?,
      name: r?['name'] as String?,
    );
  }

  static const String _renameTagDoc = r'''
    mutation RenameTag($id: Int!, $name: String!) {
      renameTag(id: $id, name: $name) { ok message }
    }
  ''';

  Future<MutationResult> renameTag(int id, String name) async {
    final data = await _client.query(
      _renameTagDoc,
      variables: {'id': id, 'name': name},
    );
    final r = data['renameTag'] as Map<String, dynamic>?;
    return MutationResult(
      ok: (r?['ok'] as bool?) ?? false,
      message: r?['message'] as String?,
    );
  }

  static const String _moveTagDoc = r'''
    mutation MoveTag($id: Int!, $parentNodeId: Int) {
      moveTag(id: $id, parentNodeId: $parentNodeId) { ok message }
    }
  ''';

  /// Re-parents a tag under the home-tree node [parentNodeId] (a negative tag
  /// id, a positive bookmarked person id, or null/0 for top-level).
  Future<MutationResult> moveTag(int id, int? parentNodeId) async {
    final data = await _client.query(
      _moveTagDoc,
      variables: {'id': id, 'parentNodeId': parentNodeId},
    );
    final r = data['moveTag'] as Map<String, dynamic>?;
    return MutationResult(
      ok: (r?['ok'] as bool?) ?? false,
      message: r?['message'] as String?,
    );
  }

  static const String _deleteTagDoc = r'''
    mutation DeleteTag($id: Int!) {
      deleteTag(id: $id) { ok message }
    }
  ''';

  Future<MutationResult> deleteTag(int id) async {
    final data = await _client.query(_deleteTagDoc, variables: {'id': id});
    final r = data['deleteTag'] as Map<String, dynamic>?;
    return MutationResult(
      ok: (r?['ok'] as bool?) ?? false,
      message: r?['message'] as String?,
    );
  }

  static const String _setBookmarkTagDoc = r'''
    mutation SetBookmarkTag($personId: Int!, $tagId: Int) {
      setBookmarkTag(personId: $personId, tagId: $tagId) { ok message }
    }
  ''';

  /// Pass [tagId] = null to remove the tag (bookmark becomes floating).
  Future<MutationResult> setBookmarkTag(int personId, int? tagId) async {
    final data = await _client.query(
      _setBookmarkTagDoc,
      variables: {'personId': personId, 'tagId': tagId},
    );
    final r = data['setBookmarkTag'] as Map<String, dynamic>?;
    return MutationResult(
      ok: (r?['ok'] as bool?) ?? false,
      message: r?['message'] as String?,
    );
  }

  static const String _setHomeCenterDoc = r'''
    mutation SetHomeCenter($personId: Int) {
      setHomeCenter(personId: $personId) { ok message }
    }
  ''';

  /// Sets the bookmark used as the center of the home tree, or pass
  /// [personId] = null to reset to the default (virtual root).
  Future<MutationResult> setHomeCenter(int? personId) async {
    final data = await _client.query(
      _setHomeCenterDoc,
      variables: {'personId': personId},
    );
    final r = data['setHomeCenter'] as Map<String, dynamic>?;
    return MutationResult(
      ok: (r?['ok'] as bool?) ?? false,
      message: r?['message'] as String?,
    );
  }

  static const String _setNodeSizeConfigDoc = r'''
    mutation SetNodeSizeConfig($maxScale: Float!, $minScale: Float!, $decay: Float!, $padding: Float!, $spreadDegrees: Float!, $edgeFactor: Float!) {
      setNodeSizeConfig(maxScale: $maxScale, minScale: $minScale, decay: $decay, padding: $padding, spreadDegrees: $spreadDegrees, edgeFactor: $edgeFactor) { ok message }
    }
  ''';

  /// Configures how home-tree node size scales with depth from the global root.
  Future<MutationResult> setNodeSizeConfig(NodeSizeConfig config) async {
    final data = await _client.query(
      _setNodeSizeConfigDoc,
      variables: {
        'maxScale': config.maxScale,
        'minScale': config.minScale,
        'decay': config.decay,
        'padding': config.padding,
        'spreadDegrees': config.spreadDegrees,
        'edgeFactor': config.edgeFactor,
      },
    );
    final r = data['setNodeSizeConfig'] as Map<String, dynamic>?;
    return MutationResult(
      ok: (r?['ok'] as bool?) ?? false,
      message: r?['message'] as String?,
    );
  }

  static const String _setTagStyleDoc = r'''
    mutation SetTagStyle($id: Int!, $color: String, $fontColor: String, $fontSize: Float) {
      setTagStyle(id: $id, color: $color, fontColor: $fontColor, fontSize: $fontSize) { ok message }
    }
  ''';

  /// Configures a tag's color, font color, and font size. Pass an empty
  /// string for [color]/[fontColor] or -1 for [fontSize] to reset to the
  /// default.
  Future<MutationResult> setTagStyle(
    int id, {
    String? color,
    String? fontColor,
    double? fontSize,
  }) async {
    final data = await _client.query(
      _setTagStyleDoc,
      variables: {
        'id': id,
        'color': color,
        'fontColor': fontColor,
        'fontSize': fontSize,
      },
    );
    final r = data['setTagStyle'] as Map<String, dynamic>?;
    return MutationResult(
      ok: (r?['ok'] as bool?) ?? false,
      message: r?['message'] as String?,
    );
  }

  static const String _setBookmarkStyleDoc = r'''
    mutation SetBookmarkStyle($id: Int!, $label: String, $color: String, $fontColor: String, $fontSize: Float) {
      editBookmark(id: $id, label: $label, color: $color, fontColor: $fontColor, fontSize: $fontSize) { ok message }
    }
  ''';

  /// Configures a bookmarked person's node label, color, font color, and font
  /// size. Pass null to leave a field unchanged, an empty string for
  /// [label]/[color]/[fontColor] or -1 for [fontSize] to reset to the default.
  /// Only the home-center bookmark uses [label] (its in-bubble text).
  Future<MutationResult> setBookmarkStyle(
    int personId, {
    String? label,
    String? color,
    String? fontColor,
    double? fontSize,
  }) async {
    final data = await _client.query(
      _setBookmarkStyleDoc,
      variables: {
        'id': personId,
        'label': label,
        'color': color,
        'fontColor': fontColor,
        'fontSize': fontSize,
      },
    );
    final r = data['editBookmark'] as Map<String, dynamic>?;
    return MutationResult(
      ok: (r?['ok'] as bool?) ?? false,
      message: r?['message'] as String?,
    );
  }

  static const String _setRootStyleDoc = r'''
    mutation SetRootStyle($label: String, $color: String, $fontColor: String, $fontSize: Float) {
      setRootStyle(label: $label, color: $color, fontColor: $fontColor, fontSize: $fontSize) { ok message }
    }
  ''';

  /// Configures the central root node's label, color, font color, and font
  /// size. Pass an empty string for [label]/[color]/[fontColor] or -1 for
  /// [fontSize] to reset that field to the default.
  Future<MutationResult> setRootStyle({
    String? label,
    String? color,
    String? fontColor,
    double? fontSize,
  }) async {
    final data = await _client.query(
      _setRootStyleDoc,
      variables: {
        'label': label,
        'color': color,
        'fontColor': fontColor,
        'fontSize': fontSize,
      },
    );
    final r = data['setRootStyle'] as Map<String, dynamic>?;
    return MutationResult(
      ok: (r?['ok'] as bool?) ?? false,
      message: r?['message'] as String?,
    );
  }

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
