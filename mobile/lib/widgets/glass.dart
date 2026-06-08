import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// The "frosted glass" visual language shared by every floating surface in
/// the app — action bar, search overlay, person-actions sheet, dialogs, and
/// page cards — so they all read as one consistent design rather than a mix
/// of opaque Material defaults and ad-hoc translucent panels.

/// A blurred, translucent surface: blurs whatever sits behind it and tints
/// it with [ColorScheme.surface], giving the "glass over the gradient
/// backdrop" look used throughout the tree screen.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blurSigma = 18,
    this.opacity = 0.4,
  });

  final Widget child;
  final BorderRadiusGeometry borderRadius;
  final double blurSigma;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: opacity),
            borderRadius: borderRadius,
            border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A frosted-glass replacement for [AlertDialog] — same title/content/actions
/// shape, rendered on a blurred [GlassPanel] instead of an opaque card so
/// confirmation and prompt dialogs match the rest of the app.
class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    this.title,
    required this.content,
    this.actions = const [],
  });

  final String? title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassPanel(
        borderRadius: BorderRadius.circular(28),
        opacity: 0.6,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(title!, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
              ],
              content,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final (i, action) in actions.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      action,
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A translucent, pill-shaped, [color]-tinted [FilledButton] style — the
/// look every filled button in the app shares by default (set as the app's
/// [FilledButtonThemeData]), and that one-off "tinted" actions (e.g. the
/// error-coloured "delete" button) opt into explicitly via [FilledButton]'s
/// `style` parameter.
ButtonStyle glassButtonStyle(Color color) => FilledButton.styleFrom(
      backgroundColor: color.withValues(alpha: 0.12),
      foregroundColor: color,
      shape: const StadiumBorder(),
    );

/// A subtle, rounded outline for text fields in multi-field forms (the
/// add-child prompt, the edit-person form) — these sit directly on a
/// [GlassPanel] card and read better with a hairline border to separate
/// them, unlike the single-field search bar which stays borderless.
InputBorder glassFieldBorder(ColorScheme scheme, {bool focused = false}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: focused
          ? BorderSide(color: scheme.primary, width: 1.5)
          : BorderSide(color: scheme.onSurface.withValues(alpha: 0.12)),
    );

/// Applies [glassFieldBorder] to all of an [InputDecoration]'s border states.
InputDecoration glassFieldDecoration(BuildContext context, InputDecoration base) {
  final scheme = Theme.of(context).colorScheme;
  return base.copyWith(
    border: glassFieldBorder(scheme),
    enabledBorder: glassFieldBorder(scheme),
    focusedBorder: glassFieldBorder(scheme, focused: true),
  );
}
