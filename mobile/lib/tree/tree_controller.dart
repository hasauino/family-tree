import 'package:flutter/foundation.dart';
import 'package:graphview/GraphView.dart';

import '../graphql/family_api.dart';
import '../graphql/graphql_client.dart';
import '../models/family_node.dart';

/// A load failure, kept locale-agnostic so the UI can render it in the active
/// language. [personId] is set only for [TreeErrorKind.personNotFound].
class TreeError {
  TreeError(this.kind, {this.personId});
  final TreeErrorKind kind;
  final int? personId;
}

enum TreeErrorKind { personNotFound, connection }

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
  TreeError? error;

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
    } on PersonNotFoundException catch (e) {
      error = TreeError(TreeErrorKind.personNotFound, personId: e.personId);
    } catch (_) {
      error = TreeError(TreeErrorKind.connection);
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
    } on PersonNotFoundException catch (e) {
      error = TreeError(TreeErrorKind.personNotFound, personId: e.personId);
    } catch (_) {
      error = TreeError(TreeErrorKind.connection);
    } finally {
      _expanding.remove(personId);
      notifyListeners();
    }
  }

  // --- Authenticated edits (mirror the web right-click menu) --------------

  /// Whether the current user may delete [personId].
  Future<bool> canDelete(int personId) => _api.canDelete(personId);

  /// The publish/bookmark status of [personId], for choosing staff actions.
  Future<({bool published, bool bookmarked})> publishStatus(int personId) =>
      _api.publishStatus(personId);

  /// The raw editable fields of [personId], to prefill the edit form.
  Future<PersonDetails> personDetails(int personId) =>
      _api.personDetails(personId);

  /// Saves edits to [personId] and refreshes its node (label/title) in place.
  Future<void> editPerson(
    int personId, {
    required String name,
    required String designation,
    required String history,
  }) async {
    final updated = await _api.editPerson(
      personId,
      name: name,
      designation: designation,
      history: history,
    );
    nodeData[personId] = updated;
    notifyListeners();
  }

  /// Adds a child named [childName] under [parentId] and grafts it into the
  /// tree. Throws [GraphQLException] (with the backend message) on failure.
  Future<void> addChild(int parentId, String childName) async {
    final child = await _api.addPerson(parentId, childName);
    nodeData[child.id] = child;
    final childNode = Node.Id(child.id);
    if (!graph.nodes.contains(childNode)) graph.addNode(childNode);
    final key = '$parentId->${child.id}';
    if (_edgeKeys.add(key)) graph.addEdge(Node.Id(parentId), childNode);
    notifyListeners();
  }

  /// Removes [personId] from the tree after a successful delete.
  Future<void> deletePerson(int personId) async {
    final result = await _api.deletePerson(personId);
    if (!result.ok) {
      throw GraphQLException(result.message ?? 'Could not delete person.');
    }
    nodeData.remove(personId);
    _expanded.remove(personId);
    _expanding.remove(personId);
    _edgeKeys.removeWhere(
      (k) => k.startsWith('$personId->') || k.endsWith('->$personId'),
    );
    graph.removeNode(Node.Id(personId));
    notifyListeners();
  }

  /// Publishes [personId] and un-dims its node (and its loaded children, which
  /// the backend also publishes).
  Future<void> publishPerson(int personId) async {
    final result = await _api.publishPerson(personId);
    if (!result.ok) {
      throw GraphQLException(result.message ?? 'Could not publish person.');
    }
    _setOpacity(personId, 1.0);
    for (final node in graph.successorsOf(Node.Id(personId))) {
      _setOpacity(node.key!.value as int, 1.0);
    }
    notifyListeners();
  }

  /// Unpublishes [personId] and dims its node (and its loaded children).
  Future<void> unpublishPerson(int personId) async {
    final result = await _api.unpublishPerson(personId);
    if (!result.ok) {
      throw GraphQLException(result.message ?? 'Could not unpublish person.');
    }
    _setOpacity(personId, 0.3);
    for (final node in graph.successorsOf(Node.Id(personId))) {
      _setOpacity(node.key!.value as int, 0.3);
    }
    notifyListeners();
  }

  Future<MutationResult> bookmarkPerson(int personId) =>
      _api.bookmarkPerson(personId);

  Future<MutationResult> unbookmarkPerson(int personId) =>
      _api.unbookmarkPerson(personId);

  void _setOpacity(int id, double opacity) {
    final node = nodeData[id];
    if (node != null) nodeData[id] = node.copyWith(opacity: opacity);
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
