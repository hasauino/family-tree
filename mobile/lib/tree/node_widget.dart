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
    this.canExpand = false,
    this.isOnPath = false,
    this.dimmed = false,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
  });

  final FamilyNode node;
  final bool isRoot;
  final bool isExpanding;

  /// Whether tapping this node would reveal relatives that aren't on screen
  /// yet. When true a small chevron is shown so an un-expanded node isn't
  /// mistaken for a dead end.
  final bool canExpand;

  /// Whether this node sits on the highlighted "connect two people" route.
  final bool isOnPath;

  /// Whether a route is being shown and this node is *not* on it, so it should
  /// be faded back to let the route stand out.
  final bool dimmed;

  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = node.color;
    final subtitle = node.subtitle;
    final highlight = scheme.primary;

    final card = Container(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 230),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnPath
              ? highlight
              : (isRoot ? accent : scheme.outlineVariant),
          width: isOnPath ? 2.5 : (isRoot ? 2 : 1),
        ),
        boxShadow: [
          if (isOnPath)
            BoxShadow(
              color: highlight.withValues(alpha: 0.45),
              blurRadius: 16,
              spreadRadius: 1,
            )
          else
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
              padding: EdgeInsets.only(
                right: canExpand ? 4 : 14,
                top: 8,
                bottom: 8,
              ),
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
          if (canExpand)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.more_horiz,
                size: 18,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );

    // Combine the node's own opacity (e.g. dimmed unpublished nodes) with the
    // route fade, so an off-path node never appears brighter than on-path ones.
    final effectiveOpacity = dimmed ? node.opacity * 0.25 : node.opacity;
    final content = effectiveOpacity < 1.0
        ? Opacity(opacity: effectiveOpacity, child: card)
        : card;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        onSecondaryTap: onSecondaryTap ?? onLongPress,
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
