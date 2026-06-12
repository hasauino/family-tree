import 'package:flutter/material.dart';

import 'glass.dart';

/// Shows a transient confirmation message anchored to the *top* of the screen.
///
/// We deliberately avoid [SnackBar] here: snackbars are pinned to the bottom of
/// the [Scaffold], where they conceal the floating action bar of the tree view.
/// A root [Overlay] entry instead lets the message slide in from the top and
/// stay visible even when the surface that triggered it (e.g. the person-actions
/// sheet) has just been popped.
void showTopToast(BuildContext context, String message) {
  showTopToastOn(Overlay.of(context, rootOverlay: true), message);
}

/// Variant that takes a pre-captured [OverlayState], for callers that pop their
/// own route before the toast should appear (capture the overlay *before* the
/// pop, just like a [ScaffoldMessengerState] would be captured for a snackbar).
void showTopToastOn(OverlayState overlay, String message) {
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopToast(
      message: message,
      onDismissed: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _TopToast extends StatefulWidget {
  const _TopToast({required this.message, required this.onDismissed});

  final String message;
  final VoidCallback onDismissed;

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(0, -0.6),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _offset,
          child: GestureDetector(
            onTap: _dismiss,
            child: GlassPanel(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: DefaultTextStyle(
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: scheme.onSurface),
                  textAlign: TextAlign.center,
                  child: Text(widget.message),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
