import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;

import '../auth/auth_service.dart';
import '../auth/login_page.dart';
import '../config.dart';
import '../graphql/family_api.dart';
import '../l10n/app_strings.dart';
import '../tree/search_overlay.dart';
import '../tree/tree_page.dart';
import '../widgets/color_wheel.dart';
import '../widgets/glass.dart';

/// Sentinel returned by [_TagPickerSheet] when the user picks "top level"
/// (i.e. no parent tag), as opposed to dismissing the sheet without a choice.
const Object _topLevelTag = Object();

/// BFS distance of every node from the virtual root (id 0) over the
/// *original* (admin-defined) hierarchy. Used to size nodes: ones close to
/// the global root (with many descendants) are shown bigger.
Map<int, int> _computeGlobalDepths(
  List<HomeNode> nodes,
  List<(int, int)> edges,
) {
  final children = <int, List<int>>{};
  for (final (from, to) in edges) {
    children.putIfAbsent(from, () => []).add(to);
  }
  final depth = <int, int>{0: 0};
  final queue = <int>[0];
  var qi = 0;
  while (qi < queue.length) {
    final node = queue[qi++];
    for (final c in children[node] ?? const <int>[]) {
      if (!depth.containsKey(c)) {
        depth[c] = depth[node]! + 1;
        queue.add(c);
      }
    }
  }
  return depth;
}

/// When a real bookmark is chosen as the home center, the virtual root
/// (id 0) carries no information of its own — splice it out of the graph,
/// reconnecting its other neighbours to the neighbour that sits between it
/// and [centerId], so the tree stays connected without showing it.
({List<HomeNode> nodes, List<(int, int)> edges}) _removeVirtualRoot(
  List<HomeNode> nodes,
  List<(int, int)> edges,
  int centerId,
) {
  if (centerId == 0 || !nodes.any((n) => n.id == 0)) {
    return (nodes: nodes, edges: edges);
  }

  final adjacency = <int, List<int>>{};
  for (final (from, to) in edges) {
    adjacency.putIfAbsent(from, () => []).add(to);
    adjacency.putIfAbsent(to, () => []).add(from);
  }

  // BFS from centerId to find the neighbour of 0 that sits on the path
  // toward centerId.
  final parentOf = <int, int>{};
  final visited = <int>{centerId};
  final queue = <int>[centerId];
  var qi = 0;
  while (qi < queue.length) {
    final node = queue[qi++];
    for (final nb in adjacency[node] ?? const <int>[]) {
      if (visited.add(nb)) {
        parentOf[nb] = node;
        queue.add(nb);
      }
    }
  }

  final towardCenter = parentOf[0];
  final neighbors0 = adjacency[0] ?? const <int>[];

  final newEdges = <(int, int)>[
    for (final e in edges)
      if (e.$1 != 0 && e.$2 != 0) e,
  ];
  if (towardCenter != null) {
    for (final nb in neighbors0) {
      if (nb != towardCenter) newEdges.add((towardCenter, nb));
    }
  }

  final newNodes = [
    for (final n in nodes)
      if (n.id != 0) n,
  ];
  return (nodes: newNodes, edges: newEdges);
}

/// Re-roots [edges] (an undirected adjacency over [nodes]) at [center] via
/// BFS, returning each node's children in the resulting tree. Used to drive
/// the collapse/expand state of the home tree.
Map<int, List<int>> _rerootedChildren(
  List<HomeNode> nodes,
  List<(int, int)> edges,
  int center,
) {
  final adjacency = <int, List<int>>{};
  for (final (from, to) in edges) {
    adjacency.putIfAbsent(from, () => []).add(to);
    adjacency.putIfAbsent(to, () => []).add(from);
  }
  final children = <int, List<int>>{};
  final visited = <int>{center};
  final queue = <int>[center];
  var qi = 0;
  while (qi < queue.length) {
    final node = queue[qi++];
    for (final nb in adjacency[node] ?? const <int>[]) {
      if (visited.add(nb)) {
        children.putIfAbsent(node, () => []).add(nb);
        queue.add(nb);
      }
    }
  }
  return children;
}

/// Finds the root of [nodes]/[edges]: the one node that is never a target of
/// an edge (the virtual root, id 0, in the original admin-defined hierarchy).
int _rootIdOf(List<HomeNode> nodes, List<(int, int)> edges) {
  final childIds = {for (final (_, to) in edges) to};
  for (final n in nodes) {
    if (!childIds.contains(n.id)) return n.id;
  }
  return nodes.isNotEmpty ? nodes.first.id : 0;
}

// ─── Radial layout ────────────────────────────────────────────────────────────

/// Lays out the home tree with **bottom-up, outward-oriented wedge packing**.
///
/// Each subtree is sized by its *magnetic radius* (Rmag): the radius of the
/// smallest circle, centered on the node, enclosing the node's glyph plus all
/// of its (recursively packed) children. A node fans its children around its
/// **outward axis** — the ray from its parent through it — within a wedge
/// capped at [_maxWedge], never behind it. Each child reserves a disjoint
/// angular slice sized by its Rmag, so sibling *and* cousin subtrees never
/// overlap (the slices cascade). The result reads as outward-branching
/// clusters, with each cluster rotated to face the global radial direction.
class _RadialLayout {
  /// Re-roots [nodes]/[edges] at [centerId] (falling back to the first node if
  /// [centerId] isn't present) and returns each node's position, with the
  /// center placed at the origin.
  Map<int, Offset> compute(
    List<HomeNode> nodes,
    List<(int, int)> edges, {
    required int centerId,
    required Map<int, int> globalDepth,
    required NodeSizeConfig sizeConfig,
  }) {
    if (nodes.isEmpty) return {};

    final nodeById = {for (final n in nodes) n.id: n};
    final ids = [for (final n in nodes) n.id];

    // Undirected adjacency, used to re-root the tree at `center`.
    final adjacency = <int, List<int>>{};
    for (final (from, to) in edges) {
      adjacency.putIfAbsent(from, () => []).add(to);
      adjacency.putIfAbsent(to, () => []).add(from);
    }

    final center = nodeById.containsKey(centerId) ? centerId : ids.first;

    // BFS from `center` -> re-rooted children.
    final children = <int, List<int>>{};
    final visited = <int>{center};
    final bfsQueue = <int>[center];
    var qi = 0;
    while (qi < bfsQueue.length) {
      final node = bfsQueue[qi++];
      for (final nb in adjacency[node] ?? const <int>[]) {
        if (visited.add(nb)) {
          children.putIfAbsent(node, () => []).add(nb);
          bfsQueue.add(nb);
        }
      }
    }

    // Radius of the smallest circle enclosing a node's own glyph.
    double coreRadius(int id) {
      final n = nodeById[id]!;
      final depth = globalDepth[id] ?? 1;
      final base = math.max(
        _NodeSize.halfW(n, depth, sizeConfig),
        _NodeSize.halfH(n, depth, sizeConfig),
      );
      // The center bookmark renders its description label below the bubble, so
      // it must reserve enough room to keep the child ring clear of that label.
      if (id == center) {
        final scale = _NodeSize.scaleForDepth(depth, sizeConfig);
        return math.max(base, _NodeSize.centerLabelRadius(n, scale));
      }
      return base;
    }

    // Gap kept between a child disk and its parent's glyph / its siblings.
    final pad = sizeConfig.padding;

    // Recursively packs [node]'s subtree in a *canonical frame*: the node sits
    // at the local origin and its children fan symmetrically around the +x
    // axis (the outward direction). The caller rotates this whole cloud so +x
    // aligns with the node's real outward direction. Returns the subtree Rmag
    // and the canonical positions.
    //
    // [isRoot] fans children over the full circle (the center has no outward
    // direction); every other node prefers a fan of [spread] but may widen it
    // toward the full circle to honor the [_ringRadius] edge-length cap.
    final spread = (sizeConfig.spreadDegrees * math.pi / 180.0).clamp(
      0.0,
      2 * math.pi,
    );
    final edgeFactor = math.max(1.0, sizeConfig.edgeFactor);

    ({double rmag, Map<int, Offset> pos}) layout(
      int node, {
      bool isRoot = false,
    }) {
      final core = coreRadius(node);
      final kids = children[node] ?? const <int>[];
      if (kids.isEmpty) {
        return (rmag: core, pos: {node: Offset.zero});
      }

      final results = [for (final k in kids) layout(k)];
      final radii = [for (final r in results) r.rmag];

      // Preferred fan breadth for this node's children.
      final wedge = isRoot ? 2 * math.pi : spread;
      final ring = _ringRadius(core, radii, pad, wedge, edgeFactor);

      // Actual angular slice each child needs at the chosen ring so its
      // Rmag-disk stays clear of its siblings'. If the edge cap forced a ring
      // smaller than `wedge` would require, these sum past `wedge` — the fan
      // widens (up to the full circle) instead of the edges stretching.
      final widths = [
        for (final r in radii) 2 * math.asin(math.min(1.0, (r + pad) / ring)),
      ];
      final totalW = widths.fold(0.0, (a, b) => a + b);

      // The root spreads its children evenly over the whole circle; a non-root
      // keeps them tightly fanned (minimal gaps) around its outward axis.
      final span = isRoot ? 2 * math.pi : totalW;

      final pos = <int, Offset>{node: Offset.zero};
      var cursor = -span / 2; // fan is centered on +x (outward)
      for (var i = 0; i < kids.length; i++) {
        final slice = totalW > 0
            ? widths[i] / totalW * span
            : span / kids.length;
        final mid = cursor + slice / 2;
        cursor += slice;

        final childCenter = Offset(ring * math.cos(mid), ring * math.sin(mid));
        // Rotate the child's canonical cloud so its outward (+x) axis points
        // along `mid` — i.e. radially outward from this node — then place it.
        final cos = math.cos(mid), sin = math.sin(mid);
        results[i].pos.forEach((id, off) {
          final rx = off.dx * cos - off.dy * sin;
          final ry = off.dx * sin + off.dy * cos;
          pos[id] = Offset(rx, ry) + childCenter;
        });
      }

      var rmag = core;
      for (var i = 0; i < kids.length; i++) {
        rmag = math.max(rmag, ring + radii[i]);
      }
      return (rmag: rmag, pos: pos);
    }

    return layout(center, isRoot: true).pos;
  }

  /// Ring radius for packing children with magnetic radii [radii] around a
  /// parent of core radius [core], keeping [pad] clearance.
  ///
  /// The radius honors the preferred [wedge] (children fan within it), but is
  /// capped at `edgeFactor × clearance` so edges don't blow up when a node has
  /// many children — once the cap bites, the fan widens past [wedge] instead.
  /// It never drops below the full-circle floor, so disks never overlap.
  static double _ringRadius(
    double core,
    List<double> radii,
    double pad,
    double wedge,
    double edgeFactor,
  ) {
    final maxChild = radii.fold(0.0, math.max);
    final clearance = core + maxChild + pad;
    if (radii.length <= 1) return clearance;

    // Smallest ring whose children's slices sum to ≤ `limit` (half because
    // each child's slice is 2·asin(...)). Lower-bounded by clearance.
    double minRing(double limit) {
      double half(double r) {
        var s = 0.0;
        for (final ri in radii) {
          s += math.asin(math.min(1.0, (ri + pad) / r));
        }
        return s;
      }

      if (half(clearance) <= limit) return clearance;
      var lo = clearance;
      var hi = clearance * 2;
      while (half(hi) > limit && hi < 1e9) {
        hi *= 2;
      }
      for (var i = 0; i < 60; i++) {
        final mid = (lo + hi) / 2;
        if (half(mid) > limit) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return hi;
    }

    final floor = minRing(math.pi); // full-circle, never overlaps
    final preferred = minRing(wedge / 2); // honors the spread cap
    final cap = math.max(clearance * edgeFactor, floor);
    return preferred.clamp(floor, cap);
  }
}

// ─── Edge painter ─────────────────────────────────────────────────────────────

class _EdgePainter extends CustomPainter {
  const _EdgePainter({
    required this.edges,
    required this.positions,
    required this.canvasOffset,
    required this.color,
  });

  final List<(int, int)> edges;
  final Map<int, Offset> positions;
  final Offset canvasOffset;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final (from, to) in edges) {
      final a = (positions[from] ?? Offset.zero) + canvasOffset;
      final b = (positions[to] ?? Offset.zero) + canvasOffset;
      paint.color = color;
      canvas.drawLine(a, b, paint);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.color != color || old.edges != edges || old.positions != positions;
}

// ─── Node widgets ─────────────────────────────────────────────────────────────

/// Sizes used when positioning nodes and drawing edges.
class _NodeSize {
  /// Visual scale for a node at [depth] in the global hierarchy (BFS
  /// distance from the virtual root). Follows an exponential decay curve
  /// from [NodeSizeConfig.maxScale] at the root toward
  /// [NodeSizeConfig.minScale] for deep nodes, controlled by
  /// [NodeSizeConfig.decay] — this keeps the size difference between the
  /// root and its immediate children pronounced while still leaving room
  /// for very deep trees (100+ generations) to shrink toward, but never
  /// below, the configured minimum.
  static double scaleForDepth(int depth, NodeSizeConfig config) {
    final d = math.max(depth, 1) - 1;
    final span = config.maxScale - config.minScale;
    final scale = config.minScale + span * math.exp(-config.decay * d);
    return scale.clamp(
      math.min(config.minScale, config.maxScale),
      math.max(config.minScale, config.maxScale),
    );
  }

  static double halfW(HomeNode n, int depth, NodeSizeConfig config) {
    if (n.isRoot) return 38.0;
    final scale = scaleForDepth(depth, config);
    if (n.isTag) return 44.0 * scale; // approximate half-width of tag pill
    return 26.0 * scale; // bookmark circle radius
  }

  static double halfH(HomeNode n, int depth, NodeSizeConfig config) {
    if (n.isRoot) return 38.0;
    final scale = scaleForDepth(depth, config);
    if (n.isTag) return 20.0 * scale;
    return 26.0 * scale;
  }

  /// Width of the home-center bookmark's description label (also used by
  /// [_positionedNode] when laying the label out).
  static const double centerLabelWidth = 110.0;

  /// The radius the center bookmark must reserve so its description label —
  /// drawn just below the bubble, [centerLabelWidth]-wide and up to two lines
  /// tall — stays inside the node's disk and clear of the surrounding child
  /// ring. Returns 0 when there is no description to show.
  static double centerLabelRadius(HomeNode n, double scale) {
    if (!n.isBookmark || n.subtitle == null) return 0;
    final fontSize = (n.fontSizeOverride?.toDouble() ?? 12) * scale;
    final labelHeight = fontSize * 1.35 * 2; // up to two wrapped lines
    final radial = 26.0 * scale + 4.0 + labelHeight; // bubble + gap + label
    final halfWidth = centerLabelWidth * scale / 2;
    return math.sqrt(halfWidth * halfWidth + radial * radial);
  }
}

/// Central anchor node – large filled circle. Shows the configured root label
/// (styled like any other node) when one is set, otherwise falls back to the
/// default tree icon. Color, font color, and font size are all admin-overridable.
class _RootNode extends StatelessWidget {
  const _RootNode({required this.node, this.onLongPress});

  final HomeNode node;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasColor =
        node.colorOverride != null && node.colorOverride!.isNotEmpty;
    final fill = hasColor ? node.color : scheme.primary;
    final onFill = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final label = node.label.trim();

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        width: 76,
        height: 76,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          boxShadow: [
            BoxShadow(
              color: fill.withValues(alpha: 0.30),
              blurRadius: 22,
              spreadRadius: 4,
            ),
          ],
        ),
        child: label.isEmpty
            ? Icon(Icons.account_tree_rounded, color: onFill, size: 34)
            : Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: node.fontColor ?? onFill,
                  fontSize: node.fontSizeOverride?.toDouble() ?? 16,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
      ),
    );
  }
}

/// Admin-defined tag node – rounded rectangle pill.
class _TagNode extends StatelessWidget {
  const _TagNode({
    required this.node,
    this.scale = 1.0,
    this.onTap,
    this.onLongPress,
  });

  final HomeNode node;
  final double scale;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final accent = node.color;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 9 * scale,
        ),
        constraints: BoxConstraints(
          minWidth: 64 * scale,
          maxWidth: 140 * scale,
        ),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14 * scale),
          border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.8),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 14,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          node.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: node.fontColor ?? accent,
            fontSize: (node.fontSizeOverride?.toDouble() ?? 13) * scale,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Small "+" badge overlaid on a node's corner to show it has hidden
/// children that can be revealed by tapping the node.
class _ExpandBadge extends StatelessWidget {
  const _ExpandBadge({this.scale = 1.0});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = (16 * scale).clamp(12.0, 18.0);
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primary,
          border: Border.all(color: scheme.surface, width: 1.5),
        ),
        child: Icon(Icons.add, size: size * 0.7, color: scheme.onPrimary),
      ),
    );
  }
}

/// Bookmarked-person node – circle with initial. The name/subtitle are drawn
/// separately by [_BookmarkLabel] so they can be placed on whichever side
/// has open space (see [_HomeScreenState._positionedNode]).
class _BookmarkCircle extends StatelessWidget {
  const _BookmarkCircle({
    required this.node,
    this.scale = 1.0,
    this.showFullLabel = false,
    this.onTap,
    this.onLongPress,
  });

  final HomeNode node;
  final double scale;

  /// When true, the bubble shows the node's full (admin-customizable) label
  /// wrapped inside it instead of a single initial. Used only for the
  /// home-center bookmark, which stands in for the root; every other bookmark
  /// keeps the compact initial.
  final bool showFullLabel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static const double baseRadius = 26.0;

  @override
  Widget build(BuildContext context) {
    final accent = node.color;
    final fgColor =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final r = baseRadius * scale;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: r * 2,
        height: r * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: node.opacity),
          border: Border.all(color: accent.withValues(alpha: 0.50), width: 2.0),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.20),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(showFullLabel ? 6 * scale : 0),
            child: Text(
              showFullLabel ? node.label : node.initial,
              textAlign: TextAlign.center,
              maxLines: showFullLabel ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: node.fontColor ?? fgColor,
                fontSize: showFullLabel
                    ? (node.fontSizeOverride?.toDouble() ?? 14) * scale
                    : 17 * scale,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The name (+ optional subtitle) of a bookmark node, laid out within its
/// box according to [align] so it reads naturally whether it sits above,
/// below, or beside the node's circle.
class _BookmarkLabel extends StatelessWidget {
  const _BookmarkLabel({
    required this.node,
    required this.scale,
    required this.align,
    this.showName = true,
  });

  final HomeNode node;
  final double scale;
  final CrossAxisAlignment align;

  /// Whether to render the name line. The center bookmark shows its name
  /// inside its bubble, so its side label carries only the description.
  final bool showName;

  TextAlign get _textAlign => switch (align) {
    CrossAxisAlignment.start => TextAlign.left,
    CrossAxisAlignment.end => TextAlign.right,
    _ => TextAlign.center,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The label's box is positioned in absolute screen coordinates relative
    // to its node (see _positionedNode), so force LTR here: otherwise
    // CrossAxisAlignment.start/end flip in RTL locales and the text renders
    // on the far side of the box, away from the node it belongs to.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: align,
        children: [
          if (showName)
            Text(
              node.label,
              textAlign: _textAlign,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ((node.fontSizeOverride?.toDouble() ?? 11) * scale)
                    .clamp(
                      9.0,
                      node.fontSizeOverride != null ? double.infinity : 13.0,
                    ),
                fontWeight: FontWeight.w600,
                color: node.fontColor ?? scheme.onSurface,
                height: 1.2,
              ),
            ),
          if (node.subtitle != null)
            Text(
              node.subtitle!,
              textAlign: _textAlign,
              maxLines: showName ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                // For the center bookmark the description is the whole label,
                // so it honours the node's customizable font size; other nodes
                // keep a fixed, compact subtitle size.
                fontSize: showName
                    ? (10 * scale).clamp(8.0, 12.0)
                    : (node.fontSizeOverride?.toDouble() ?? 12) * scale,
                color: node.fontColor ?? scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Home screen ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static final _layout = _RadialLayout();

  final _viewer = TransformationController();
  final _viewportKey = GlobalKey();

  late final AnimationController _panController = AnimationController(
    vsync: this,
    duration: AppConfig.nodePanDuration,
  );
  Matrix4Tween? _panTween;

  List<HomeNode> _nodes = [];
  List<(int, int)> _edges = [];
  List<HomeNode> _allDisplayNodes = [];
  List<(int, int)> _allDisplayEdges = [];
  List<HomeNode> _displayNodes = [];
  List<(int, int)> _displayEdges = [];
  Map<int, Offset> _positions = {};
  Map<int, int> _globalDepth = {};
  Map<int, List<int>> _childrenMap = {};
  Set<int> _expandedIds = {};
  int _centerId = 0;
  NodeSizeConfig _nodeSizeConfig = NodeSizeConfig.fallback;
  bool _loading = false;
  Object? _error;

  FamilyApi get _api => widget.auth.api;

  // ── helpers ───────────────────────────────────────────────────────────────

  int get _rootId {
    final childIds = {for (final (_, to) in _edges) to};
    for (final n in _nodes) {
      if (!childIds.contains(n.id)) return n.id;
    }
    return _nodes.isNotEmpty ? _nodes.first.id : 0;
  }

  /// The node the home tree is visually centered on: the admin-chosen
  /// bookmark, or the virtual root if none has been chosen.
  int get _focusId => _centerId == 0 ? _rootId : _centerId;

  // Walk the edge tree upwards from [nodeId]; return tag DB id (positive)
  // or null if the bookmark is floating.
  int? _effectiveTagDbId(int nodeId) {
    final parentOf = {for (final (from, to) in _edges) to: from};
    var cur = nodeId;
    while (true) {
      final par = parentOf[cur];
      if (par == null || par == 0) return null; // floating / root
      if (par < 0) return -par; // tag node id is negative
      cur = par;
    }
  }

  // Returns the home-tree node id of [tagNodeId]'s parent (negative for a
  // tag, positive for a bookmarked person), or null if it's top-level
  // (parented directly to the virtual root).
  int? _tagParentNodeId(int tagNodeId) {
    for (final (from, to) in _edges) {
      if (to == tagNodeId) return from == 0 ? null : from;
    }
    return null;
  }

  // All home-tree node ids nested (at any depth) under [nodeId].
  Set<int> _descendantNodeIds(int nodeId) {
    final children = <int, List<int>>{};
    for (final (from, to) in _edges) {
      children.putIfAbsent(from, () => []).add(to);
    }
    final result = <int>{};
    void visit(int id) {
      for (final child in children[id] ?? const []) {
        result.add(child);
        visit(child);
      }
    }

    visit(nodeId);
    return result;
  }

  // ── data loading ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _panController.addListener(() {
      final tween = _panTween;
      if (tween != null) {
        _viewer.value = tween.lerp(
          Curves.easeInOut.transform(_panController.value),
        );
      }
    });
    _load();
  }

  @override
  void dispose() {
    _panController.dispose();
    _viewer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.homeTree();
      if (!mounted) return;
      final globalDepth = _computeGlobalDepths(data.nodes, data.edges);
      final display = _removeVirtualRoot(data.nodes, data.edges, data.centerId);
      final focusId = data.centerId == 0
          ? _rootIdOf(data.nodes, data.edges)
          : data.centerId;
      final childrenMap = _rerootedChildren(
        display.nodes,
        display.edges,
        focusId,
      );
      setState(() {
        _nodes = data.nodes;
        _edges = data.edges;
        _allDisplayNodes = display.nodes;
        _allDisplayEdges = display.edges;
        _globalDepth = globalDepth;
        _centerId = data.centerId;
        _nodeSizeConfig = data.nodeSizeConfig;
        _childrenMap = childrenMap;
        _expandedIds = {focusId};
        _recomputeVisible();
      });
      _centerOnFocus();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── collapse / expand ─────────────────────────────────────────────────────

  /// Recomputes [_displayNodes]/[_displayEdges]/[_positions] from
  /// [_allDisplayNodes]/[_allDisplayEdges] based on [_expandedIds]. The focus
  /// node and its direct children are always shown; a node's children are
  /// only shown once the node itself is expanded. Must be called inside
  /// [setState].
  void _recomputeVisible() {
    final visible = <int>{_focusId};
    void visit(int node) {
      if (!_expandedIds.contains(node)) return;
      for (final child in _childrenMap[node] ?? const <int>[]) {
        visible.add(child);
        visit(child);
      }
    }

    visit(_focusId);

    _displayNodes = [
      for (final n in _allDisplayNodes)
        if (visible.contains(n.id)) n,
    ];
    _displayEdges = [
      for (final e in _allDisplayEdges)
        if (visible.contains(e.$1) && visible.contains(e.$2)) e,
    ];
    _positions = _layout.compute(
      _displayNodes,
      _displayEdges,
      centerId: _centerId,
      globalDepth: _globalDepth,
      sizeConfig: _nodeSizeConfig,
    );
  }

  bool _hasChildren(int nodeId) =>
      (_childrenMap[nodeId] ?? const <int>[]).isNotEmpty;

  bool _isCollapsed(int nodeId) =>
      _hasChildren(nodeId) && !_expandedIds.contains(nodeId);

  /// Toggles whether [nodeId]'s children are shown. Collapsing a node also
  /// collapses its descendants, so re-expanding it later starts fresh.
  void _toggleExpand(int nodeId) {
    setState(() {
      if (_expandedIds.contains(nodeId)) {
        _expandedIds.remove(nodeId);
        void collapseDescendants(int node) {
          for (final child in _childrenMap[node] ?? const <int>[]) {
            _expandedIds.remove(child);
            collapseDescendants(child);
          }
        }

        collapseDescendants(nodeId);
      } else {
        _expandedIds.add(nodeId);
      }
      _recomputeVisible();
    });
  }

  // ── centering ─────────────────────────────────────────────────────────────

  static const double _pad = 130.0;
  static const double _labelH = 54.0;

  double get _maxR => 44.0 * _nodeSizeConfig.maxScale;

  Offset _canvasOffset() {
    if (_positions.isEmpty) return Offset(_pad, _pad);
    final maxR = _maxR;
    final minX =
        _positions.values.map((p) => p.dx).reduce(math.min) - maxR - _pad;
    final minY =
        _positions.values.map((p) => p.dy).reduce(math.min) - maxR - _pad;
    return Offset(-minX, -minY);
  }

  Size _canvasSize(Offset offset) {
    if (_positions.isEmpty) return const Size(400, 400);
    final maxR = _maxR;
    final maxX =
        _positions.values.map((p) => p.dx).reduce(math.max) + maxR + _pad;
    final maxY =
        _positions.values.map((p) => p.dy).reduce(math.max) +
        maxR +
        _pad +
        _labelH;
    return Size(maxX + offset.dx, maxY + offset.dy);
  }

  /// Smoothly animates [_viewer] from its current transform to [target],
  /// interrupting any in-progress pan.
  void _animateTo(Matrix4 target) {
    _panTween = Matrix4Tween(begin: _viewer.value.clone(), end: target);
    _panController.forward(from: 0);
  }

  /// Pans the viewport so [id]'s node sits at the center, preserving the
  /// current zoom. Runs after the next frame so it reads the layout produced
  /// by a just-completed expand/collapse, and retries for a few frames while
  /// the position or viewport isn't ready yet. Pass [animated] to glide
  /// instead of snapping.
  void _panToNode(int id, {bool animated = true, int retriesLeft = 20}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
      final pos = _positions[id];
      if (pos == null || box == null || !box.hasSize) {
        if (retriesLeft > 0) {
          _panToNode(id, animated: animated, retriesLeft: retriesLeft - 1);
        }
        return;
      }
      final viewport = box.size;
      final scale = _viewer.value.getMaxScaleOnAxis();
      final nodeCanvas = pos + _canvasOffset();
      final t =
          Offset(viewport.width / 2, viewport.height / 2) - nodeCanvas * scale;
      final target = Matrix4.identity()
        ..translateByDouble(t.dx, t.dy, 0, 1)
        ..scaleByDouble(scale, scale, scale, 1);
      if (animated) {
        _animateTo(target);
      } else {
        _viewer.value = target;
      }
    });
  }

  void _centerOnFocus({int retriesLeft = 20}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _positions.isEmpty) return;
      final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        if (retriesLeft > 0) _centerOnFocus(retriesLeft: retriesLeft - 1);
        return;
      }
      final viewport = box.size;
      final co = _canvasOffset();
      final focusCanvas = (_positions[_focusId] ?? Offset.zero) + co;
      const scale = 0.82;
      _viewer.value = Matrix4.identity()
        ..translateByDouble(
          viewport.width / 2 - focusCanvas.dx * scale,
          viewport.height / 2 - focusCanvas.dy * scale,
          0,
          1,
        )
        ..scaleByDouble(scale, scale, scale, 1);
    });
  }

  /// Scales and pans the viewport so the whole bookmark cloud fits, centred,
  /// with a small margin. Retries for a few frames if layout isn't ready yet.
  void _fitToWindow({int retriesLeft = 20}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _positions.isEmpty) return;
      final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        if (retriesLeft > 0) _fitToWindow(retriesLeft: retriesLeft - 1);
        return;
      }
      final co = _canvasOffset();
      final maxR = _maxR;
      var minX = double.infinity, minY = double.infinity;
      var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      for (final pos in _positions.values) {
        final c = pos + co;
        minX = math.min(minX, c.dx - maxR);
        minY = math.min(minY, c.dy - maxR);
        maxX = math.max(maxX, c.dx + maxR);
        maxY = math.max(maxY, c.dy + maxR + _labelH);
      }

      const margin = 32.0; // breathing room inside the viewport
      final contentW = maxX - minX;
      final contentH = maxY - minY;
      final viewport = box.size;
      final scale = math
          .min(
            (viewport.width - margin * 2) / contentW,
            (viewport.height - margin * 2) / contentH,
          )
          .clamp(0.08, 3.0);
      final contentCenter = Offset(minX + contentW / 2, minY + contentH / 2);
      final t =
          Offset(viewport.width / 2, viewport.height / 2) -
          contentCenter * scale;
      _viewer.value = Matrix4.identity()
        ..translateByDouble(t.dx, t.dy, 0, 1)
        ..scaleByDouble(scale, scale, scale, 1);
    });
  }

  // ── navigation ────────────────────────────────────────────────────────────

  void _openTree(int personId) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TreePage(auth: widget.auth, initialPersonId: personId),
    ),
  );

  Future<void> _openSearch() async {
    final r = await showSearchOverlay(context, _api);
    if (r != null && mounted) _openTree(r.id);
  }

  // ── staff actions ─────────────────────────────────────────────────────────

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _editNodeSizeSettings() async {
    final t = AppStrings.of(context);
    final result = await showDialog<NodeSizeConfig>(
      context: context,
      builder: (ctx) => _NodeSizeSettingsDialog(initial: _nodeSizeConfig),
    );
    if (result == null || !mounted) return;

    try {
      final r = await _api.setNodeSizeConfig(result);
      if (r.ok) {
        _toast(t.nodeSizeSettingsUpdated);
        _load();
      } else {
        _toast(r.message ?? t.errorConnection);
      }
    } catch (_) {
      _toast(t.errorConnection);
    }
  }

  /// Long-pressing the central root node (staff only) opens the style dialog,
  /// which for the root also includes an editable label so it can show custom
  /// text instead of the default tree icon.
  Future<void> _showRootOptions(HomeNode root) async {
    final t = AppStrings.of(context);
    final result = await showDialog<StyleSettingsResult>(
      context: context,
      builder: (ctx) => _StyleSettingsDialog(
        showLabel: true,
        initialLabel: root.label,
        initialColor: root.colorOverride,
        initialFontColor: root.fontColorOverride,
        initialFontSize: root.fontSizeOverride,
      ),
    );
    if (result == null || !mounted) return;
    try {
      final r = await _api.setRootStyle(
        label: result.label,
        color: result.color,
        fontColor: result.fontColor,
        fontSize: result.fontSize,
      );
      _toast(r.ok ? t.styleUpdated : (r.message ?? t.errorConnection));
      if (r.ok) _load();
    } catch (_) {
      _toast(t.errorConnection);
    }
  }

  Future<void> _createTag() async {
    final t = AppStrings.of(context);
    final name = await _promptText(t.createTagTitle, t.tagNameLabel);
    if (name == null || name.trim().isEmpty) return;
    if (!mounted) return;

    final tags = _nodes.where((n) => n.isTag).toList();
    final bookmarks = _nodes.where((n) => n.isBookmark).toList();
    Object? parentSelection;
    if (tags.isNotEmpty || bookmarks.isNotEmpty) {
      parentSelection = await showModalBottomSheet<Object?>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.15),
        isScrollControlled: true,
        builder: (ctx) => _TagPickerSheet(
          title: t.parentTagLabel,
          tags: tags,
          bookmarks: bookmarks,
          currentParentNodeId: null,
          excludedNodeIds: const {},
          onSelected: (selection) => Navigator.pop(ctx, selection),
        ),
      );
    }
    final parentNodeId =
        (parentSelection == null || identical(parentSelection, _topLevelTag))
        ? null
        : parentSelection as int;

    try {
      final r = await _api.createTag(name.trim(), parentNodeId: parentNodeId);
      if (r.ok) {
        _toast(t.tagCreated);
        _load();
      } else {
        _toast(r.message ?? t.errorConnection);
      }
    } catch (_) {
      _toast(t.errorConnection);
    }
  }

  Future<void> _showTagOptions(HomeNode tag) async {
    final t = AppStrings.of(context);
    final tagDbId = -tag.id; // tag nodes have negative IDs
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      isScrollControlled: true,
      builder: (ctx) => _TagOptionsSheet(
        tag: tag,
        onRename: () async {
          Navigator.pop(ctx);
          final newName = await _promptText(
            t.renameTagTitle,
            t.tagNameLabel,
            initial: tag.label,
          );
          if (newName == null || newName.trim().isEmpty) return;
          try {
            final r = await _api.renameTag(tagDbId, newName.trim());
            _toast(r.ok ? t.tagRenamed : (r.message ?? t.errorConnection));
            if (r.ok) _load();
          } catch (_) {
            _toast(t.errorConnection);
          }
        },
        onMove: () async {
          Navigator.pop(ctx);
          final tags = _nodes.where((n) => n.isTag).toList();
          final bookmarks = _nodes.where((n) => n.isBookmark).toList();
          final excluded = {tag.id, ..._descendantNodeIds(tag.id)};
          final currentParentNodeId = _tagParentNodeId(tag.id);

          if (!mounted) return;
          final selection = await showModalBottomSheet<Object?>(
            context: context,
            backgroundColor: Colors.transparent,
            barrierColor: Colors.black.withValues(alpha: 0.15),
            isScrollControlled: true,
            builder: (ctx2) => _TagPickerSheet(
              title: t.moveTagTitle,
              tags: tags,
              bookmarks: bookmarks,
              currentParentNodeId: currentParentNodeId,
              excludedNodeIds: excluded,
              onSelected: (s) => Navigator.pop(ctx2, s),
            ),
          );
          if (selection == null) return; // dismissed without choosing
          final newParentNodeId = identical(selection, _topLevelTag)
              ? null
              : selection as int;
          try {
            final r = await _api.moveTag(tagDbId, newParentNodeId);
            _toast(r.ok ? t.tagMoved : (r.message ?? t.errorConnection));
            if (r.ok) _load();
          } catch (_) {
            _toast(t.errorConnection);
          }
        },
        onEditStyle: () async {
          Navigator.pop(ctx);
          final result = await showDialog<StyleSettingsResult>(
            context: context,
            builder: (ctx2) => _StyleSettingsDialog(
              initialColor: tag.colorOverride,
              initialFontColor: tag.fontColorOverride,
              initialFontSize: tag.fontSizeOverride,
            ),
          );
          if (result == null || !mounted) return;
          try {
            final r = await _api.setTagStyle(
              tagDbId,
              color: result.color,
              fontColor: result.fontColor,
              fontSize: result.fontSize,
            );
            _toast(r.ok ? t.styleUpdated : (r.message ?? t.errorConnection));
            if (r.ok) _load();
          } catch (_) {
            _toast(t.errorConnection);
          }
        },
        onDelete: () async {
          Navigator.pop(ctx);
          final confirmed = await _confirmDeleteTag(tag.label);
          if (!confirmed) return;
          try {
            final r = await _api.deleteTag(tagDbId);
            _toast(r.ok ? t.tagDeleted : (r.message ?? t.errorConnection));
            if (r.ok) _load();
          } catch (_) {
            _toast(t.errorConnection);
          }
        },
      ),
    );
  }

  Future<void> _showBookmarkOptions(HomeNode bookmark) async {
    final t = AppStrings.of(context);
    final tags = _nodes.where((n) => n.isTag).toList();
    final effectiveTagDbId = _effectiveTagDbId(bookmark.id);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      isScrollControlled: true,
      builder: (ctx) => _BookmarkTagSheet(
        bookmark: bookmark,
        tags: tags,
        currentTagDbId: effectiveTagDbId,
        isHomeCenter: _centerId == bookmark.id,
        onOpenTree: () {
          Navigator.pop(ctx);
          _openTree(bookmark.id);
        },
        onTagSelected: (tagDbId) async {
          Navigator.pop(ctx);
          try {
            final r = await _api.setBookmarkTag(bookmark.id, tagDbId);
            _toast(r.ok ? t.tagAssigned : (r.message ?? t.errorConnection));
            if (r.ok) _load();
          } catch (_) {
            _toast(t.errorConnection);
          }
        },
        onToggleHomeCenter: () async {
          Navigator.pop(ctx);
          final newCenter = _centerId == bookmark.id ? null : bookmark.id;
          try {
            final r = await _api.setHomeCenter(newCenter);
            _toast(
              r.ok ? t.homeCenterUpdated : (r.message ?? t.errorConnection),
            );
            if (r.ok) _load();
          } catch (_) {
            _toast(t.errorConnection);
          }
        },
        onEditStyle: () async {
          Navigator.pop(ctx);
          // Only the home-center bookmark may set custom in-bubble text; other
          // bookmarks just get color/font styling.
          final isCenter = _centerId == bookmark.id;
          final result = await showDialog<StyleSettingsResult>(
            context: context,
            builder: (ctx2) => _StyleSettingsDialog(
              showLabel: isCenter,
              labelIsRoot: false,
              showFontFields: isCenter,
              initialLabel: isCenter ? bookmark.label : null,
              initialColor: bookmark.colorOverride,
              initialFontColor: bookmark.fontColorOverride,
              initialFontSize: bookmark.fontSizeOverride,
            ),
          );
          if (result == null || !mounted) return;
          try {
            final r = await _api.setBookmarkStyle(
              bookmark.id,
              label: result.label,
              color: result.color,
              fontColor: result.fontColor,
              fontSize: result.fontSize,
            );
            _toast(r.ok ? t.styleUpdated : (r.message ?? t.errorConnection));
            if (r.ok) _load();
          } catch (_) {
            _toast(t.errorConnection);
          }
        },
      ),
    );
  }

  Future<bool> _confirmDeleteTag(String name) async {
    final t = AppStrings.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => GlassDialog(
            title: t.deleteTagTitle,
            content: Text(t.deleteTagConfirm(name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t.cancel),
              ),
              FilledButton(
                style: glassButtonStyle(Theme.of(ctx).colorScheme.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t.delete),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _promptText(
    String title,
    String label, {
    String initial = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) =>
          _TextPromptDialog(title: title, label: label, initial: initial),
    );
  }

  // ── auth bar ──────────────────────────────────────────────────────────────

  Widget _accountMenu(AppStrings t) {
    if (!widget.auth.isAuthenticated) {
      return IconButton(
        tooltip: t.login,
        icon: const Icon(Icons.login),
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => LoginPage(auth: widget.auth))),
      );
    }
    return PopupMenuButton<String>(
      tooltip: widget.auth.username ?? t.account,
      icon: Icon(
        widget.auth.isStaff ? Icons.shield_outlined : Icons.account_circle,
      ),
      onSelected: (v) {
        if (v == 'logout') widget.auth.logout();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(widget.auth.username ?? t.account),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, size: 20),
              const SizedBox(width: 12),
              Text(t.logout),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionBar(AppStrings t) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: t.reloadTooltip,
                  icon: const Icon(Icons.refresh),
                  onPressed: _loading ? null : _load,
                ),
                IconButton(
                  tooltip: t.searchTooltip,
                  icon: const Icon(Icons.search),
                  onPressed: _openSearch,
                ),
                IconButton(
                  tooltip: t.fitTreeTooltip,
                  icon: const Icon(Icons.fit_screen),
                  onPressed: _fitToWindow,
                ),
                if (widget.auth.isStaff)
                  IconButton(
                    tooltip: t.createTagTooltip,
                    icon: const Icon(Icons.label_outline),
                    onPressed: _createTag,
                  ),
                if (widget.auth.isStaff)
                  IconButton(
                    tooltip: t.nodeSizeSettingsTooltip,
                    icon: const Icon(Icons.tune),
                    onPressed: _editNodeSizeSettings,
                  ),
                VerticalDivider(
                  width: 1,
                  indent: 14,
                  endIndent: 14,
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
                ListenableBuilder(
                  listenable: widget.auth,
                  builder: (context, _) => _accountMenu(t),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── tree canvas ───────────────────────────────────────────────────────────

  Widget _buildTree() {
    final co = _canvasOffset();
    final cs = _canvasSize(co);
    final edgeColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.16);
    final isStaff = widget.auth.isStaff;

    return LayoutBuilder(
      builder: (context, constraints) {
        final vp = constraints.biggest;
        return InteractiveViewer(
          key: _viewportKey,
          transformationController: _viewer,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          minScale: 0.08,
          maxScale: 3.0,
          child: SizedBox(
            width: math.max(vp.width, cs.width),
            height: math.max(vp.height, cs.height),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _EdgePainter(
                      edges: _displayEdges,
                      positions: _positions,
                      canvasOffset: co,
                      color: edgeColor,
                    ),
                  ),
                ),
                for (final node in _displayNodes)
                  if (_positions.containsKey(node.id))
                    ..._positionedNode(node, co, isStaff),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the widgets for [node]. Bookmark nodes are split into a circle
  /// (positioned exactly on the layout point) and a separate label that is
  /// placed on whichever side points away from the focus node, so it tends
  /// to land in the open space beyond the node rather than under it where
  /// sibling nodes often sit.
  Iterable<Widget> _positionedNode(
    HomeNode node,
    Offset co,
    bool isStaff,
  ) sync* {
    final pos = _positions[node.id]!;
    final depth = _globalDepth[node.id] ?? 1;
    final scale = _NodeSize.scaleForDepth(depth, _nodeSizeConfig);
    final hw = _NodeSize.halfW(node, depth, _nodeSizeConfig);
    final hh = _NodeSize.halfH(node, depth, _nodeSizeConfig);

    if (node.isRoot) {
      yield Positioned(
        left: pos.dx + co.dx - hw,
        top: pos.dy + co.dy - hh,
        child: _RootNode(
          node: node,
          onLongPress: isStaff ? () => _showRootOptions(node) : null,
        ),
      );
      return;
    }

    final hasChildren = _hasChildren(node.id);
    // The focus (root) node is uncollapsible: it always stays expanded and
    // tapping it opens the tree like any other bookmark, rather than toggling
    // the home view's collapse state.
    final isFocus = node.id == _focusId;
    final collapsed = _isCollapsed(node.id) && !isFocus;

    if (node.isTag) {
      yield Positioned(
        left: pos.dx + co.dx - hw,
        top: pos.dy + co.dy - hh,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _TagNode(
              node: node,
              scale: scale,
              onTap: () {
                if (hasChildren) _toggleExpand(node.id);
                _panToNode(node.id);
              },
              onLongPress: isStaff ? () => _showTagOptions(node) : null,
            ),
            if (collapsed)
              Positioned(
                right: -4,
                bottom: -4,
                child: _ExpandBadge(scale: scale),
              ),
          ],
        ),
      );
      return;
    }

    yield Positioned(
      left: pos.dx + co.dx - hw,
      top: pos.dy + co.dy - hh,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _BookmarkCircle(
            node: node,
            scale: scale,
            showFullLabel: isFocus,
            onTap: (hasChildren && !isFocus)
                ? () {
                    _toggleExpand(node.id);
                    _panToNode(node.id);
                  }
                : () => _openTree(node.id),
            onLongPress: isStaff ? () => _showBookmarkOptions(node) : null,
          ),
          if (collapsed)
            Positioned(
              right: -2,
              bottom: -2,
              child: _ExpandBadge(scale: scale),
            ),
        ],
      ),
    );

    // The center bookmark's label sits directly below its bubble, centered,
    // within the radius reserved for it in the layout (see coreRadius) so it
    // stays clear of the surrounding child ring.
    if (isFocus) {
      final width = _NodeSize.centerLabelWidth * scale;
      yield Positioned(
        left: pos.dx + co.dx - width / 2,
        top: pos.dy + co.dy + hh + 4.0,
        width: width,
        child: _BookmarkLabel(
          node: node,
          scale: scale,
          align: CrossAxisAlignment.center,
          showName: false,
        ),
      );
      return;
    }

    final focusPos = _positions[_focusId] ?? pos;
    final dir = pos - focusPos;
    const gap = 4.0;
    final width = 110.0 * scale;

    double left, top;
    CrossAxisAlignment align;
    var flipUp = false;
    if (dir != Offset.zero && dir.dx.abs() >= dir.dy.abs()) {
      top = pos.dy + co.dy - hh;
      if (dir.dx >= 0) {
        left = pos.dx + co.dx + hw + gap;
        align = CrossAxisAlignment.start;
      } else {
        left = pos.dx + co.dx - hw - gap - width;
        align = CrossAxisAlignment.end;
      }
    } else {
      left = pos.dx + co.dx - width / 2;
      align = CrossAxisAlignment.center;
      if (dir.dy <= 0) {
        // Anchor the label's bottom edge to the node's top edge without
        // needing to know the label's height up front.
        top = pos.dy + co.dy - hh - gap;
        flipUp = true;
      } else {
        top = pos.dy + co.dy + hh + gap;
      }
    }

    final label = _BookmarkLabel(node: node, scale: scale, align: align);
    yield Positioned(
      left: left,
      top: top,
      width: width,
      child: flipUp
          ? FractionalTranslation(
              translation: const Offset(0, -1),
              child: label,
            )
          : label,
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _nodes.isEmpty) {
      body = _ErrorView(onRetry: _load, t: t);
    } else if (_nodes.isEmpty || (_nodes.length == 1 && _nodes.first.isRoot)) {
      // Only the virtual root = nothing interesting to show
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            t.noBookmarks,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      body = _buildTree();
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: body),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _actionBar(t),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tag options sheet ────────────────────────────────────────────────────────

class _TagOptionsSheet extends StatelessWidget {
  const _TagOptionsSheet({
    required this.tag,
    required this.onRename,
    required this.onMove,
    required this.onEditStyle,
    required this.onDelete,
  });

  final HomeNode tag;
  final VoidCallback onRename;
  final VoidCallback onMove;
  final VoidCallback onEditStyle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(tag.label, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onRename,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(t.renameTagTitle),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onMove,
                    icon: const Icon(Icons.drive_file_move_outline),
                    label: Text(t.moveTagTitle),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onEditStyle,
                    icon: const Icon(Icons.palette_outlined),
                    label: Text(t.editStyleTitle),
                  ),
                  FilledButton.tonalIcon(
                    style: glassButtonStyle(scheme.error),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(t.deleteTagTitle),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bookmark tag assignment sheet ───────────────────────────────────────────

class _BookmarkTagSheet extends StatelessWidget {
  const _BookmarkTagSheet({
    required this.bookmark,
    required this.tags,
    required this.currentTagDbId,
    required this.isHomeCenter,
    required this.onOpenTree,
    required this.onTagSelected,
    required this.onToggleHomeCenter,
    required this.onEditStyle,
  });

  final HomeNode bookmark;
  final List<HomeNode> tags;
  final int? currentTagDbId;
  final bool isHomeCenter;
  final VoidCallback onOpenTree;
  final void Function(int? tagDbId) onTagSelected;
  final VoidCallback onToggleHomeCenter;
  final VoidCallback onEditStyle;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;

    return GlassPanel(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                bookmark.label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (bookmark.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  bookmark.subtitle!,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onOpenTree,
                    icon: const Icon(Icons.account_tree_outlined),
                    label: Text(t.openTreeTooltip),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onToggleHomeCenter,
                    icon: Icon(
                      isHomeCenter
                          ? Icons.center_focus_strong
                          : Icons.center_focus_weak_outlined,
                    ),
                    label: Text(
                      isHomeCenter ? t.resetHomeCenter : t.setHomeCenter,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onEditStyle,
                    icon: const Icon(Icons.palette_outlined),
                    label: Text(t.editStyleTitle),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                t.assignTag,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // "No tag" chip
                  _TagChip(
                    label: t.noTag,
                    color: scheme.outline,
                    selected: currentTagDbId == null,
                    onTap: () => onTagSelected(null),
                  ),
                  // One chip per tag
                  for (final tag in tags)
                    _TagChip(
                      label: tag.label,
                      color: tag.color,
                      selected: currentTagDbId == -tag.id,
                      onTap: () => onTagSelected(-tag.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.22)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.7 : 0.3),
            width: selected ? 2.0 : 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Tag picker sheet ─────────────────────────────────────────────────────────

/// A bottom sheet for choosing a (parent) home-tree node, used both when
/// creating a new tag and when moving an existing one. The parent can be
/// another tag or a bookmarked person.
///
/// [onSelected] is called with [_topLevelTag] for "no parent", or an `int`
/// home-tree node id (negative for a tag, positive for a bookmarked person).
/// If the sheet is dismissed without a selection, the caller's
/// [showModalBottomSheet] future resolves to `null`.
class _TagPickerSheet extends StatelessWidget {
  const _TagPickerSheet({
    required this.title,
    required this.tags,
    required this.bookmarks,
    required this.currentParentNodeId,
    required this.excludedNodeIds,
    required this.onSelected,
  });

  final String title;
  final List<HomeNode> tags;
  final List<HomeNode> bookmarks;
  final int? currentParentNodeId;
  final Set<int> excludedNodeIds;
  final void Function(Object selection) onSelected;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final availableTags = tags
        .where((tag) => !excludedNodeIds.contains(tag.id))
        .toList();
    final availableBookmarks = bookmarks
        .where((bm) => !excludedNodeIds.contains(bm.id))
        .toList();

    return GlassPanel(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TagChip(
                    label: t.topLevelTag,
                    color: scheme.outline,
                    selected: currentParentNodeId == null,
                    onTap: () => onSelected(_topLevelTag),
                  ),
                  for (final tag in availableTags)
                    _TagChip(
                      label: tag.label,
                      color: tag.color,
                      selected: currentParentNodeId == tag.id,
                      onTap: () => onSelected(tag.id),
                    ),
                  for (final bm in availableBookmarks)
                    _TagChip(
                      label: bm.label,
                      color: bm.color,
                      selected: currentParentNodeId == bm.id,
                      onTap: () => onSelected(bm.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Text prompt dialog ───────────────────────────────────────────────────────

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.label,
    this.initial = '',
  });

  final String title;
  final String label;
  final String initial;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return GlassDialog(
      title: widget.title,
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: glassFieldDecoration(
          context,
          InputDecoration(labelText: widget.label),
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: Text(t.save),
        ),
      ],
    );
  }
}

// ─── Node size settings dialog ─────────────────────────────────────────────────

/// Lets staff tune how home-tree node size scales with depth from the
/// global root. Returns the edited [NodeSizeConfig], or null if cancelled.
class _NodeSizeSettingsDialog extends StatefulWidget {
  const _NodeSizeSettingsDialog({required this.initial});

  final NodeSizeConfig initial;

  @override
  State<_NodeSizeSettingsDialog> createState() =>
      _NodeSizeSettingsDialogState();
}

class _NodeSizeSettingsDialogState extends State<_NodeSizeSettingsDialog> {
  late final TextEditingController _maxCtrl = TextEditingController(
    text: _formatNum(widget.initial.maxScale),
  );
  late final TextEditingController _minCtrl = TextEditingController(
    text: _formatNum(widget.initial.minScale),
  );
  late final TextEditingController _decayCtrl = TextEditingController(
    text: _formatNum(widget.initial.decay),
  );
  late final TextEditingController _paddingCtrl = TextEditingController(
    text: _formatNum(widget.initial.padding),
  );
  late final TextEditingController _spreadCtrl = TextEditingController(
    text: _formatNum(widget.initial.spreadDegrees),
  );
  late final TextEditingController _edgeFactorCtrl = TextEditingController(
    text: _formatNum(widget.initial.edgeFactor),
  );
  String? _error;

  static String _formatNum(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }

  @override
  void dispose() {
    _maxCtrl.dispose();
    _minCtrl.dispose();
    _decayCtrl.dispose();
    _paddingCtrl.dispose();
    _spreadCtrl.dispose();
    _edgeFactorCtrl.dispose();
    super.dispose();
  }

  /// Some keyboards (and locales) produce a comma instead of a dot for the
  /// decimal separator; normalize before parsing.
  static double? _parseNum(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  void _submit() {
    final maxScale = _parseNum(_maxCtrl.text);
    final minScale = _parseNum(_minCtrl.text);
    final decay = _parseNum(_decayCtrl.text);
    final padding = _parseNum(_paddingCtrl.text);
    final spread = _parseNum(_spreadCtrl.text);
    final edgeFactor = _parseNum(_edgeFactorCtrl.text);
    final t = AppStrings.of(context);

    if (maxScale == null ||
        minScale == null ||
        decay == null ||
        padding == null ||
        spread == null ||
        edgeFactor == null ||
        maxScale <= 0 ||
        minScale <= 0 ||
        decay < 0 ||
        padding < 0 ||
        spread <= 0 ||
        spread > 360 ||
        edgeFactor < 1 ||
        minScale > maxScale) {
      setState(() => _error = t.nodeSizeSettingsInvalid);
      return;
    }

    Navigator.pop(
      context,
      NodeSizeConfig(
        maxScale: maxScale,
        minScale: minScale,
        decay: decay,
        padding: padding,
        spreadDegrees: spread,
        edgeFactor: edgeFactor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return GlassDialog(
      title: t.nodeSizeSettingsTitle,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
            t.nodeSizeSettingsHelp,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _maxCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: glassFieldDecoration(
              context,
              InputDecoration(labelText: t.nodeMaxScaleLabel),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: glassFieldDecoration(
              context,
              InputDecoration(labelText: t.nodeMinScaleLabel),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _decayCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: glassFieldDecoration(
              context,
              InputDecoration(labelText: t.nodeSizeDecayLabel),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _paddingCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: glassFieldDecoration(
              context,
              InputDecoration(labelText: t.nodePaddingLabel),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _spreadCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: glassFieldDecoration(
              context,
              InputDecoration(labelText: t.nodeSpreadLabel),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _edgeFactorCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: glassFieldDecoration(
              context,
              InputDecoration(labelText: t.nodeEdgeLengthLabel),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: scheme.error, fontSize: 12)),
          ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(t.save)),
      ],
    );
  }
}

// ─── Node/tag style settings dialog ────────────────────────────────────────────

/// The style values returned by [_StyleSettingsDialog]. An empty [color] /
/// [fontColor] resets that color to the default, [fontSize] is -1 to reset,
/// and [label] is null when the dialog has no label field.
typedef StyleSettingsResult = ({
  String? label,
  String color,
  String fontColor,
  double fontSize,
});

/// Lets staff override a node's color, font color, and font size — and, when
/// [showLabel] is set (the root node), its label text too. Returns a
/// [StyleSettingsResult] where an empty string resets a color and `-1` resets
/// the font size, or null if cancelled.
class _StyleSettingsDialog extends StatefulWidget {
  const _StyleSettingsDialog({
    this.initialColor,
    this.initialFontColor,
    this.initialFontSize,
    this.initialLabel,
    this.showLabel = false,
    this.labelIsRoot = true,
    this.showFontFields = true,
  });

  final String? initialColor;
  final String? initialFontColor;
  final int? initialFontSize;
  final String? initialLabel;

  /// Whether to show the font color/size fields. Disabled for ordinary
  /// bookmarks — only the home-center bookmark (and the root/tags) may tune
  /// their label font.
  final bool showFontFields;

  /// Whether to show an editable label field. Used by the root node and the
  /// home-center bookmark, whose in-bubble text is admin-configurable.
  final bool showLabel;

  /// Tailors the label field's caption/hint: the root falls back to an icon
  /// when blank, the center bookmark falls back to the person's name.
  final bool labelIsRoot;

  @override
  State<_StyleSettingsDialog> createState() => _StyleSettingsDialogState();
}

class _StyleSettingsDialogState extends State<_StyleSettingsDialog> {
  late final TextEditingController _labelCtrl = TextEditingController(
    text: widget.initialLabel ?? '',
  );
  late final TextEditingController _colorCtrl = TextEditingController(
    text: widget.initialColor ?? '',
  );
  late final TextEditingController _fontColorCtrl = TextEditingController(
    text: widget.initialFontColor ?? '',
  );
  late final TextEditingController _fontSizeCtrl = TextEditingController(
    text: widget.initialFontSize == null ? '' : '${widget.initialFontSize}',
  );
  String? _error;

  static final _hexRegExp = RegExp(r'^[0-9a-fA-F]{6}$');

  @override
  void dispose() {
    _labelCtrl.dispose();
    _colorCtrl.dispose();
    _fontColorCtrl.dispose();
    _fontSizeCtrl.dispose();
    super.dispose();
  }

  static String _colorToHex(Color c) {
    int channel(double v) => (v * 255.0).round().clamp(0, 255);
    return '${channel(c.r).toRadixString(16).padLeft(2, '0')}'
        '${channel(c.g).toRadixString(16).padLeft(2, '0')}'
        '${channel(c.b).toRadixString(16).padLeft(2, '0')}';
  }

  /// Parses a 6-digit hex into a [Color], or null if [text] isn't valid hex.
  static Color? _hexToColor(String text) {
    final t = text.trim();
    return _hexRegExp.hasMatch(t) ? Color(int.parse('FF$t', radix: 16)) : null;
  }

  /// Opens the colour wheel seeded from [ctrl]'s current hex (falling back to
  /// the theme's primary), writing the chosen colour back as a hex string.
  Future<void> _pickColor(TextEditingController ctrl, String title) async {
    final t = AppStrings.of(context);
    final seed =
        _hexToColor(ctrl.text) ?? Theme.of(context).colorScheme.primary;
    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        var temp = seed;
        return GlassDialog(
          title: title,
          content: StatefulBuilder(
            builder: (c, setSB) => ColorWheelPicker(
              color: seed,
              onChanged: (col) => setSB(() => temp = col),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, temp),
              child: Text(t.save),
            ),
          ],
        );
      },
    );
    if (result != null) {
      setState(() => ctrl.text = _colorToHex(result));
    }
  }

  /// A small circular preview of [ctrl]'s current colour, shown as the field's
  /// prefix; empty (outlined) when the field is blank or not yet valid hex.
  Widget _colorSwatch(TextEditingController ctrl) {
    final scheme = Theme.of(context).colorScheme;
    final c = _hexToColor(ctrl.text);
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c ?? Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outline, width: 1),
      ),
    );
  }

  void _submit() {
    final t = AppStrings.of(context);
    final color = _colorCtrl.text.trim();
    final fontColor = _fontColorCtrl.text.trim();
    final fontSizeText = _fontSizeCtrl.text.trim().replaceAll(',', '.');

    if ((color.isNotEmpty && !_hexRegExp.hasMatch(color)) ||
        (fontColor.isNotEmpty && !_hexRegExp.hasMatch(fontColor))) {
      setState(() => _error = t.styleInvalid);
      return;
    }
    final fontSize = fontSizeText.isEmpty
        ? -1.0
        : double.tryParse(fontSizeText);
    if (fontSize == null || (fontSize != -1 && fontSize <= 0)) {
      setState(() => _error = t.styleInvalid);
      return;
    }

    Navigator.pop<StyleSettingsResult>(context, (
      label: widget.showLabel ? _labelCtrl.text : null,
      color: color,
      fontColor: fontColor,
      fontSize: fontSize,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return GlassDialog(
      title: t.editStyleTitle,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showLabel) ...[
              TextField(
                controller: _labelCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: glassFieldDecoration(
                  context,
                  InputDecoration(
                    labelText: widget.labelIsRoot
                        ? t.rootLabelLabel
                        : t.nodeLabelLabel,
                    hintText: widget.labelIsRoot
                        ? t.rootLabelHint
                        : t.nodeLabelHint,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: t.resetToDefault,
                      onPressed: () => setState(() => _labelCtrl.clear()),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _colorCtrl,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: glassFieldDecoration(
                context,
                InputDecoration(
                  labelText: t.nodeColorLabel,
                  hintText: t.colorHexHint,
                  prefixIcon: _colorSwatch(_colorCtrl),
                  prefixIconConstraints: const BoxConstraints(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.colorize),
                        tooltip: t.nodeColorLabel,
                        onPressed: () =>
                            _pickColor(_colorCtrl, t.nodeColorLabel),
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: t.resetToDefault,
                        onPressed: () => setState(() => _colorCtrl.clear()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.showFontFields) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _fontColorCtrl,
                onChanged: (_) => setState(() {}),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: glassFieldDecoration(
                  context,
                  InputDecoration(
                    labelText: t.fontColorLabel,
                    hintText: t.colorHexHint,
                    prefixIcon: _colorSwatch(_fontColorCtrl),
                    prefixIconConstraints: const BoxConstraints(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.colorize),
                          tooltip: t.fontColorLabel,
                          onPressed: () =>
                              _pickColor(_fontColorCtrl, t.fontColorLabel),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: t.resetToDefault,
                          onPressed: () =>
                              setState(() => _fontColorCtrl.clear()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fontSizeCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: glassFieldDecoration(
                  context,
                  InputDecoration(
                    labelText: t.fontSizeLabel,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: t.resetToDefault,
                      onPressed: () => setState(() => _fontSizeCtrl.clear()),
                    ),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(t.save)),
      ],
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry, required this.t});

  final VoidCallback onRetry;
  final AppStrings t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(t.errorConnection, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(t.retry),
            ),
          ],
        ),
      ),
    );
  }
}
