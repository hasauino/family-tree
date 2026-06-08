import '../models/family_node.dart';
import 'graphql_client.dart';

/// A piece of the tree: the nodes to add plus the parent→child edges between
/// them. Edges are `(fromId, toId)` pairs (parent id → child id).
class TreeFragment {
  TreeFragment({required this.nodes, required this.edges});
  final List<FamilyNode> nodes;
  final List<(int from, int to)> edges;
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
}
