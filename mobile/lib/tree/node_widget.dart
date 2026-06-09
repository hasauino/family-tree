import 'package:flutter/material.dart';

import '../models/family_node.dart';

/// A single tappable person node, styled as a clean Material card.
///
/// * tap        -> expand (load parent + children)
/// * long-press -> show details (designation / history)
/// * double-tap -> re-center the whole tree on this person
class NodeWidget extends StatelessWidget {
  const NodeWidget({
    super.key,
    required this.node,
    required this.isRoot,
    required this.isExpanding,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
  });

  final FamilyNode node;
  final bool isRoot;
  final bool isExpanding;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = node.color;
    final subtitle = node.subtitle;

    final card = Container(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 230),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRoot ? accent : scheme.outlineVariant,
          width: isRoot ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Colored branch accent strip.
          Container(width: 5, height: 52, color: accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
            child: _avatar(accent),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      height: 1.15,
                      fontWeight: isRoot ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final content = node.opacity < 1.0
        ? Opacity(opacity: node.opacity, child: card)
        : card;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        child: content,
      ),
    );
  }

  /// Circular initial avatar, or a spinner while the node is expanding.
  Widget _avatar(Color accent) {
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    return SizedBox(
      width: 36,
      height: 36,
      child: isExpanding
          ? Padding(
              padding: const EdgeInsets.all(8),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  node.initial,
                  style: TextStyle(
                    color: onAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
    );
  }
}
