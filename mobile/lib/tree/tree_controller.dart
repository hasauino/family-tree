import 'package:flutter/foundation.dart';
import 'package:graphview/GraphView.dart';

import '../graphql/family_api.dart';
import '../graphql/graphql_client.dart';
import '../models/family_node.dart';

/// Holds the interactive tree state and talks to [FamilyApi].
///
/// The [Graph] is the layout/render model consumed by `GraphView`; [nodeData]
/// maps each person id to its display info. Tapping a node calls [expand],
/// which appends that person's parent and children — exactly like the
/// `connectedNodes` flow in the web `tree.js`.
class TreeController extends ChangeNotifier {
  TreeController({FamilyApi? api})
      : _api = api ?? FamilyApi(GraphQLClient());

  final FamilyApi _api;

  final Graph graph = Graph();
  final Map<int, FamilyNode> nodeData = {};

  final Set<String> _edgeKeys = {};
  final Set<int> _expanded = {};
  final Set<int> _expanding = {};

  int? rootId;
  bool loading = false;
  String? error;

  bool isExpanding(int id) => _expanding.contains(id);
  bool isExpanded(int id) => _expanded.contains(id);

  /// Resets the tree and loads the initial view centered on [personId]
  /// (grandfather → father → person → sons → grandsons).
  Future<void> loadRoot(int personId) async {
    loading = true;
    error = null;
    rootId = personId;
    _reset();
    notifyListeners();
    try {
      final fragment = await _api.bootstrap(personId);
      _apply(fragment);
      _expanded.add(personId);
    } on GraphQLException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Expands [personId] in place, adding its parent and visible children.
  Future<void> expand(int personId) async {
    if (_expanding.contains(personId)) return;
    _expanding.add(personId);
    notifyListeners();
    try {
      final fragment = await _api.connectedNodes(personId);
      _apply(fragment);
      _expanded.add(personId);
    } on GraphQLException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      _expanding.remove(personId);
      notifyListeners();
    }
  }

  void _reset() {
    nodeData.clear();
    _edgeKeys.clear();
    _expanded.clear();
    _expanding.clear();
    graph.nodes.clear();
    graph.edges.clear();
  }

  void _apply(TreeFragment fragment) {
    for (final node in fragment.nodes) {
      nodeData[node.id] = node;
      final graphNode = Node.Id(node.id);
      if (!graph.nodes.contains(graphNode)) {
        graph.addNode(graphNode);
      }
    }
    for (final (from, to) in fragment.edges) {
      final key = '$from->$to';
      if (_edgeKeys.add(key)) {
        graph.addEdge(Node.Id(from), Node.Id(to));
      }
    }
  }
}
