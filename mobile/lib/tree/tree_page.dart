import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

import '../config.dart';
import '../models/family_node.dart';
import 'node_widget.dart';
import 'tree_controller.dart';

/// The interactive, pan/zoomable family-tree screen.
class TreePage extends StatefulWidget {
  const TreePage({super.key});

  @override
  State<TreePage> createState() => _TreePageState();
}

class _TreePageState extends State<TreePage> {
  final TreeController _controller = TreeController();
  final TransformationController _viewer = TransformationController();
  final GlobalKey _viewportKey = GlobalKey();

  late final BuchheimWalkerConfiguration _layout = BuchheimWalkerConfiguration()
    ..siblingSeparation = 25
    ..levelSeparation = 70
    ..subtreeSeparation = 35
    ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;

  @override
  void initState() {
    super.initState();
    _controller.loadRoot(AppConfig.rootPersonId);
  }

  @override
  void dispose() {
    _controller.dispose();
    _viewer.dispose();
    super.dispose();
  }

  void _resetZoom() => _viewer.value = Matrix4.identity();

  /// Centers the view on [id]'s node. Only used for user actions (tapping a
  /// node, the center button) when the viewport is already laid out — we never
  /// center on first load, which is what caused the tree to vanish on a web
  /// cold start.
  void _centerNode(int id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final node = _nodeFor(id);
      final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
      if (node == null ||
          node.size == Size.zero ||
          box == null ||
          !box.hasSize) {
        return;
      }
      final viewport = box.size;
      final scale = _viewer.value.getMaxScaleOnAxis();
      const pad = 60.0; // matches the Padding around the graph
      final nodeCenter = Offset(
        pad + node.position.dx + node.size.width / 2,
        pad + node.position.dy + node.size.height / 2,
      );
      final t =
          Offset(viewport.width / 2, viewport.height / 2) - nodeCenter * scale;
      _viewer.value = Matrix4.identity()
        ..translateByDouble(t.dx, t.dy, 0, 1)
        ..scaleByDouble(scale, scale, scale, 1);
    });
  }

  Node? _nodeFor(int id) {
    for (final node in _controller.graph.nodes) {
      if (node.key?.value == id) return node;
    }
    return null;
  }

  Future<void> _promptOpenPerson() async {
    final textController = TextEditingController(
      text: _controller.rootId?.toString() ?? '',
    );
    final id = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open person tree'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Person id',
            hintText: 'e.g. 1',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(textController.text.trim())),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    if (id != null) {
      _resetZoom();
      _controller.loadRoot(id);
    }
  }

  void _showDetails(FamilyNode node) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.label, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(node.title ?? 'No further details.'),
            const SizedBox(height: 20),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resetZoom();
                    _controller.loadRoot(node.id);
                  },
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('Center tree here'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Tree'),
        actions: [
          IconButton(
            tooltip: 'Open person',
            icon: const Icon(Icons.person_search),
            onPressed: _promptOpenPerson,
          ),
          IconButton(
            tooltip: 'Center on active person',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () {
              final id = _controller.rootId;
              if (id != null) _centerNode(id);
            },
          ),
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final id = _controller.rootId;
              if (id != null) {
                _resetZoom();
                _controller.loadRoot(id);
              }
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.error != null && _controller.graph.nodeCount() == 0) {
            return _ErrorView(
              message: _controller.error!,
              onRetry: () => _controller.loadRoot(
                _controller.rootId ?? AppConfig.rootPersonId,
              ),
            );
          }
          if (_controller.graph.nodeCount() == 0) {
            return const Center(child: Text('No data.'));
          }
          return _buildGraph();
        },
      ),
    );
  }

  Widget _buildGraph() {
    final edgeColor = Theme.of(context).colorScheme.outline;
    return InteractiveViewer(
      key: _viewportKey,
      transformationController: _viewer,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(800),
      minScale: 0.1,
      maxScale: 3.0,
      child: Padding(
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
            if (data == null) {
              return const SizedBox.shrink();
            }
            return NodeWidget(
              node: data,
              isRoot: id == _controller.rootId,
              isExpanding: _controller.isExpanding(id),
              onTap: () {
                _centerNode(id);
                _controller.expand(id).then((_) {
                  if (mounted) _centerNode(id);
                });
              },
              onDoubleTap: () {
                _resetZoom();
                _controller.loadRoot(id);
              },
              onLongPress: () => _showDetails(data),
            );
          },
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
