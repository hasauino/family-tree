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

enum TreeErrorKind { personNotFound, connection, noPath }

/// Describes a connection between two people, used to render the summary sheet.
///
/// When [isDirect] is true, one endpoint is an ancestor of the other and
/// [meetingId] is that ancestor (one of the generation counts is 0). Otherwise
/// [meetingId] is the lowest common ancestor and each count is the number of
/// generations between an endpoint and the meeting node.
class TreePathInfo {
  TreePathInfo({
    required this.fromId,
    required this.toId,
    required this.meetingId,
    required this.fromGenerations,
    required this.toGenerations,
    required this.isDirect,
  });
  final int fromId;
  final int toId;
  final int meetingId;
  final int fromGenerations;
  final int toGenerations;
  final bool isDirect;

  /// In a direct line, the total generations between the two endpoints.
  int get directGenerations => fromGenerations + toGenerations;
}

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

  /// Set while a "connect two people" route is being shown. [pathIds] holds the
  /// ids on the highlighted route; [pathInfo] carries the relationship details
  /// (meeting node + generation counts) for the summary sheet. Both are cleared
  /// by [_reset] (i.e. on any other navigation).
  final Set<int> pathIds = {};
  TreePathInfo? pathInfo;

  bool get pathActive => pathIds.isNotEmpty;
  bool isOnPath(int id) => pathIds.contains(id);

  bool isExpanding(int id) => _expanding.contains(id);
  bool isExpanded(int id) => _expanded.contains(id);

  /// Resets the tree and loads the initial view centered on [personId]
  /// (grandfather → father → person → sons → grandsons).
  /// Pass [isStaff] so that admins see unpublished nodes dimmed from the start.
  Future<void> loadRoot(int personId, {bool isStaff = false}) async {
    loading = true;
    error = null;
    rootId = personId;
    _reset();
    notifyListeners();
    try {
      final fragment = await _api.bootstrap(personId, isStaff: isStaff);
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

  /// Resets the tree and loads the route connecting [fromId] and [toId],
  /// highlighting it. When one is an ancestor of the other the route is the
  /// straight line between them; otherwise it runs up to their lowest common
  /// ancestor. Sets [rootId] to [toId] so centering and retry both target it,
  /// and populates [pathIds]/[pathInfo] for highlighting and the summary sheet.
  Future<void> loadPath(int fromId, int toId) async {
    loading = true;
    error = null;
    rootId = toId;
    _reset();
    notifyListeners();
    try {
      final result = await _api.treePath(fromId, toId);
      _apply(result.fragment);
      pathIds
        ..clear()
        ..addAll(result.pathIds);
      pathInfo = TreePathInfo(
        fromId: fromId,
        toId: toId,
        meetingId: result.meetingId,
        fromGenerations: result.fromGenerations,
        toGenerations: result.toGenerations,
        isDirect: result.isDirect,
      );
      _expanded.add(toId);
    } on NoTreePathException catch (_) {
      error = TreeError(TreeErrorKind.noPath);
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

  /// Descendant count and orphan-eligibility for [personId].
  Future<({int descendantCount, bool isRootWithSingleChild})> deleteInfo(
    int personId,
  ) => _api.deleteInfo(personId);

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

  /// Creates a new parent node above [personId] (which must be a root) and
  /// grafts it into the tree. The caller should reload after success so the
  /// new parent is shown in context above the node.
  Future<void> addParent(int personId, String parentName) async {
    final parent = await _api.addParent(personId, parentName);
    nodeData[parent.id] = parent;
    final parentNode = Node.Id(parent.id);
    if (!graph.nodes.contains(parentNode)) graph.addNode(parentNode);
    final key = '${parent.id}->$personId';
    if (_edgeKeys.add(key)) graph.addEdge(parentNode, Node.Id(personId));
    notifyListeners();
  }

  /// Adds multiple children under [parentId] at once. Grafts new nodes into
  /// the tree. Returns the result (including any duplicate-name warnings).
  Future<AddChildrenResult> addChildren(
    int parentId,
    List<String> childNames,
  ) async {
    final result = await _api.addChildren(parentId, childNames);
    for (final child in result.nodes) {
      nodeData[child.id] = child;
      final childNode = Node.Id(child.id);
      if (!graph.nodes.contains(childNode)) graph.addNode(childNode);
      final key = '$parentId->${child.id}';
      if (_edgeKeys.add(key)) graph.addEdge(Node.Id(parentId), childNode);
    }
    notifyListeners();
    return result;
  }

  /// Moves [personId] under [newParentId]. Throws [GraphQLException] on
  /// failure. The caller should reload the tree after a successful move.
  Future<void> movePerson(int personId, int newParentId) async {
    final result = await _api.movePerson(personId, newParentId: newParentId);
    if (!result.ok) {
      throw GraphQLException(result.message ?? 'Could not move person.');
    }
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
    pathIds.clear();
    pathInfo = null;
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
