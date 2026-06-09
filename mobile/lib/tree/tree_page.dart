import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

import '../auth/auth_service.dart';
import '../auth/login_page.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../models/family_node.dart';
import '../widgets/glass.dart';
import 'node_widget.dart';
import 'person_actions_sheet.dart';
import 'search_overlay.dart';
import 'tree_controller.dart';
import 'tree_path_dialog.dart';

/// The interactive, pan/zoomable family-tree screen.
class TreePage extends StatefulWidget {
  const TreePage({super.key, required this.auth});

  final AuthService auth;

  @override
  State<TreePage> createState() => _TreePageState();
}

class _TreePageState extends State<TreePage>
    with SingleTickerProviderStateMixin {
  late final TreeController _controller =
      TreeController(api: widget.auth.api);
  final TransformationController _viewer = TransformationController();
  final GlobalKey _viewportKey = GlobalKey();

  late final AnimationController _panController = AnimationController(
    vsync: this,
    duration: AppConfig.nodePanDuration,
  );
  Matrix4Tween? _panTween;

  late final BuchheimWalkerConfiguration _layout = BuchheimWalkerConfiguration()
    ..siblingSeparation = 25
    ..levelSeparation = 70
    ..subtreeSeparation = 35
    ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;

  @override
  void initState() {
    super.initState();
    _panController.addListener(() {
      final tween = _panTween;
      if (tween != null) {
        _viewer.value =
            tween.lerp(Curves.easeInOut.transform(_panController.value));
      }
    });
    _loadRootCentered(AppConfig.rootPersonId);
  }

  @override
  void dispose() {
    _panController.dispose();
    _controller.dispose();
    _viewer.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _panController.stop();
    _viewer.value = Matrix4.identity();
  }

  /// Smoothly animates [_viewer] from its current transform to [target].
  /// [duration] overrides the controller's duration for this one animation;
  /// omit it to use [AppConfig.nodePanDuration]. Interrupts any in-progress
  /// pan animation.
  void _animateTo(Matrix4 target, {Duration? duration}) {
    _panController.duration = duration ?? AppConfig.nodePanDuration;
    _panTween = Matrix4Tween(begin: _viewer.value.clone(), end: target);
    _panController.forward(from: 0);
  }

  /// Centers the view on [id]'s node, retrying for a few frames if its layout
  /// (position/size) or the viewport isn't ready yet — e.g. right after a
  /// fresh load, where the graph is rebuilt from scratch and the first
  /// post-frame callback can fire before the layout pass has run. Bounded so
  /// a node that never appears doesn't retry forever (this is what caused the
  /// tree to vanish on a web cold start before the retry was bounded).
  ///
  /// Pass [animated] to smoothly pan instead of snapping. Pass [targetScale]
  /// to override the zoom level at the destination (defaults to the current
  /// viewer scale, preserving whatever the user has set).
  void _centerNode(
    int id, {
    bool animated = false,
    double? targetScale,
    Duration? animationDuration,
    int retriesLeft = 20,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final node = _nodeFor(id);
      final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
      final ready = node != null &&
          node.size != Size.zero &&
          box != null &&
          box.hasSize;
      if (!ready) {
        if (retriesLeft > 0) {
          _centerNode(id,
              animated: animated,
              targetScale: targetScale,
              animationDuration: animationDuration,
              retriesLeft: retriesLeft - 1);
        }
        return;
      }
      final viewport = box.size;
      final scale = targetScale ?? _viewer.value.getMaxScaleOnAxis();
      const pad = 60.0; // matches the Padding around the graph
      final nodeCenter = Offset(
        pad + node.position.dx + node.size.width / 2,
        pad + node.position.dy + node.size.height / 2,
      );
      final t =
          Offset(viewport.width / 2, viewport.height / 2) - nodeCenter * scale;
      final target = Matrix4.identity()
        ..translateByDouble(t.dx, t.dy, 0, 1)
        ..scaleByDouble(scale, scale, scale, 1);
      if (animated) {
        _animateTo(target, duration: animationDuration);
      } else {
        _viewer.value = target;
      }
    });
  }

  /// Re-roots the tree on [id], resetting zoom and centering on the new root
  /// once it's loaded and laid out. Used on first load, "center tree here",
  /// search selection, and double-tapping a node.
  void _loadRootCentered(int id) {
    _resetZoom();
    _controller.loadRoot(id, isStaff: widget.auth.isStaff).then((_) {
      if (mounted) _centerNode(id);
    });
  }

  Node? _nodeFor(int id) {
    for (final node in _controller.graph.nodes) {
      if (node.key?.value == id) return node;
    }
    return null;
  }

  /// Scales and pans the view so the entire tree fits inside the viewport,
  /// with a small margin. Retries for a few frames if layout isn't ready yet.
  /// [onDone] is called after the viewport is updated, e.g. to chain a
  /// subsequent animated pan to a specific node.
  void _fitToWindow({VoidCallback? onDone, int retriesLeft = 20}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        if (retriesLeft > 0) {
          _fitToWindow(onDone: onDone, retriesLeft: retriesLeft - 1);
        }
        return;
      }

      var minX = double.infinity, minY = double.infinity;
      var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      for (final node in _controller.graph.nodes) {
        if (node.size == Size.zero) continue;
        minX = math.min(minX, node.position.dx);
        minY = math.min(minY, node.position.dy);
        maxX = math.max(maxX, node.position.dx + node.size.width);
        maxY = math.max(maxY, node.position.dy + node.size.height);
      }
      if (minX == double.infinity) {
        // Nothing laid out yet — retry.
        if (retriesLeft > 0) {
          _fitToWindow(onDone: onDone, retriesLeft: retriesLeft - 1);
        }
        return;
      }

      const pad = 60.0; // matches the Padding around the graph
      const margin = 32.0; // breathing room inside the viewport
      final contentW = maxX - minX;
      final contentH = maxY - minY;
      final viewport = box.size;
      final scale = math
          .min(
            (viewport.width - margin * 2) / contentW,
            (viewport.height - margin * 2) / contentH,
          )
          .clamp(0.1, 3.0);
      final contentCenter = Offset(
        pad + minX + contentW / 2,
        pad + minY + contentH / 2,
      );
      final t =
          Offset(viewport.width / 2, viewport.height / 2) - contentCenter * scale;
      _viewer.value = Matrix4.identity()
        ..translateByDouble(t.dx, t.dy, 0, 1)
        ..scaleByDouble(scale, scale, scale, 1);
      onDone?.call();
    });
  }

  void _showDetails(FamilyNode node) {
    showModalBottomSheet<void>(
      context: context,
      // Transparent + a faint barrier so the sheet's own frosted-glass card
      // (matching the search overlay's look) blurs the tree through it,
      // instead of sitting on an opaque sheet over a dark scrim.
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      isScrollControlled: true,
      builder: (ctx) => PersonActionsSheet(
        node: node,
        controller: _controller,
        auth: widget.auth,
        onCenter: () => _loadRootCentered(node.id),
        onMoved: () => _loadRootCentered(node.id),
      ),
    );
  }

  /// Opens the blurred "search by name" overlay; on selection, re-roots the tree.
  Future<void> _openSearch() async {
    final result = await showSearchOverlay(context, widget.auth.api);
    if (result != null) _loadRootCentered(result.id);
  }

  /// Opens the "from ancestor → to descendant" picker; on confirmation loads
  /// the path and centers on the descendant.
  Future<void> _openTreePath() async {
    final picked = await showTreePathDialog(context, widget.auth.api);
    if (picked != null) _loadPathCentered(picked.from, picked.to);
  }

  void _loadPathCentered(int fromId, int toId) {
    _resetZoom();
    _controller.loadPath(fromId, toId).then((_) {
      if (!mounted) return;
      // First snap the viewport to show the full path, then animate the
      // camera into the target node so the user sees the context before
      // landing on the destination.
      _fitToWindow(
        onDone: () => _centerNode(
          toId,
          animated: true,
          targetScale: 1.0,
          animationDuration: AppConfig.treePathZoomDuration,
        ),
      );
    });
  }

  Future<void> _handleLogin() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LoginPage(auth: widget.auth)),
    );
  }

  Future<void> _handleLogout() async {
    await widget.auth.logout();
  }

  /// The login button (signed out) or an account menu with logout (signed in).
  Widget _buildAccountMenu(AppStrings t) {
    if (!widget.auth.isAuthenticated) {
      return IconButton(
        tooltip: t.login,
        icon: const Icon(Icons.login),
        onPressed: _handleLogin,
      );
    }
    return PopupMenuButton<String>(
      tooltip: widget.auth.username ?? t.account,
      icon: Icon(
        widget.auth.isStaff ? Icons.shield_outlined : Icons.account_circle,
      ),
      onSelected: (value) {
        if (value == 'logout') _handleLogout();
      },
      itemBuilder: (context) => [
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

  /// Groups the page actions into a single frosted-glass, pill-shaped
  /// floating bar — the same [GlassPanel] surface used for the search
  /// overlay and person-actions sheet, so every floating panel matches.
  Widget _actionBar(AppStrings t) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          // IntrinsicHeight bounds the row to its tallest button instead
          // of the loose (near-full-screen) height the floating Align
          // offers — without it, VerticalDivider has nothing to size
          // itself against and stretches the whole pill vertically.
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: t.searchTooltip,
                  icon: const Icon(Icons.search),
                  onPressed: _openSearch,
                ),
                IconButton(
                  tooltip: t.treePathTooltip,
                  icon: const Icon(Icons.alt_route),
                  onPressed: _openTreePath,
                ),
                IconButton(
                  tooltip: t.fitTreeTooltip,
                  icon: const Icon(Icons.fit_screen),
                  onPressed: _fitToWindow,
                ),
                IconButton(
                  tooltip: t.reloadTooltip,
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    final id = _controller.rootId;
                    if (id != null) _loadRootCentered(id);
                  },
                ),
                VerticalDivider(
                  width: 1,
                  indent: 14,
                  endIndent: 14,
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
                ListenableBuilder(
                  listenable: widget.auth,
                  builder: (context, _) => _buildAccountMenu(t),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  if (_controller.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_controller.error != null &&
                      _controller.graph.nodeCount() == 0) {
                    return _ErrorView(
                      error: _controller.error!,
                      onRetry: () => _controller.loadRoot(
                        _controller.rootId ?? AppConfig.rootPersonId,
                        isStaff: widget.auth.isStaff,
                      ),
                    );
                  }
                  if (_controller.graph.nodeCount() == 0) {
                    return Center(child: Text(t.noData));
                  }
                  return _buildGraph();
                },
              ),
            ),
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

  Widget _buildGraph() {
    final edgeColor = Theme.of(context).colorScheme.outline;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        return InteractiveViewer(
          key: _viewportKey,
          transformationController: _viewer,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(800),
          minScale: 0.1,
          maxScale: 3.0,
          child: Stack(
            alignment: Alignment.topLeft,
            children: [
              // An invisible spacer that pads the pannable canvas out to at
              // least the viewport size, so panning a small tree never
              // reveals a hard edge where the canvas ends. Both this and the
              // padded GraphView are top-left aligned, so GraphView keeps
              // sitting at the fixed (pad, pad) offset that
              // _centerNode/_fitToWindow assume — Stack sizes itself to the
              // larger of the two, whichever that is.
              SizedBox(width: viewport.width, height: viewport.height),
              Padding(
                padding: const EdgeInsets.all(60),
                child: GraphView(
                  graph: _controller.graph,
                  algorithm:
                      BuchheimWalkerAlgorithm(_layout, TreeEdgeRenderer(_layout)),
                  toggleAnimationDuration: AppConfig.treeLayoutAnimationDuration,
                  paint: Paint()
                    ..color = edgeColor
                    ..strokeWidth = 1.4
                    ..style = PaintingStyle.stroke,
                  builder: (Node node) {
                    final id = node.key!.value as int;
                    final data = _controller.nodeData[id];
                    if (data == null) return const SizedBox.shrink();
                    return NodeWidget(
                      node: data,
                      isRoot: id == _controller.rootId,
                      isExpanding: _controller.isExpanding(id),
                      onTap: () {
                        _centerNode(id, animated: true);
                        _controller.expand(id).then((_) {
                          if (mounted) _centerNode(id, animated: true);
                        });
                      },
                      onDoubleTap: () => _loadRootCentered(id),
                      onLongPress: () => _showDetails(data),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final TreeError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final message = switch (error.kind) {
      TreeErrorKind.personNotFound =>
        t.errorPersonNotFound(error.personId ?? 0),
      TreeErrorKind.connection => t.errorConnection,
      TreeErrorKind.noPath => t.errorNoPath,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
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
