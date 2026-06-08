import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../graphql/family_api.dart';
import '../l10n/app_strings.dart';

/// Opens the live "search by name" UI as a translucent, blurred overlay that
/// floats on top of the tree. Returns the chosen person's id (or null if the
/// overlay was dismissed), which the caller uses to re-root the tree.
Future<int?> showSearchOverlay(BuildContext context, FamilyApi api) {
  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.15),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, _) => _SearchOverlay(api: api),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _SearchOverlay extends StatefulWidget {
  const _SearchOverlay({required this.api});

  final FamilyApi api;

  @override
  State<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<_SearchOverlay> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();

  Timer? _debounce;
  String _lastDispatched = '';
  int _requestSeq = 0;
  Future<List<PersonSearchResult>>? _pending;

  // The web search needs at least 2 characters; we follow the same rule.
  bool get _isQueryable => _query.text.trim().length >= 2;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    final trimmed = _query.text.trim();
    if (trimmed == _lastDispatched) return;
    _lastDispatched = trimmed;
    _debounce?.cancel();

    if (!_isQueryable) {
      setState(() => _pending = null);
      return;
    }

    final seq = ++_requestSeq;
    final completer = Completer<List<PersonSearchResult>>();
    setState(() {
      _pending = completer.future;
    });
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await widget.api.searchPersons(trimmed);
        if (seq == _requestSeq && !completer.isCompleted) {
          completer.complete(results);
        }
      } catch (e) {
        if (seq == _requestSeq && !completer.isCompleted) {
          completer.completeError(e);
        }
      }
    });
  }

  void _clear() {
    _query.clear();
    _lastDispatched = '';
    setState(() => _pending = null);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: GestureDetector(
        // Tapping the blurred backdrop dismisses the overlay.
        onTap: () => Navigator.pop(context),
        child: Container(
          color: scheme.surface.withValues(alpha: 0.18),
          child: SafeArea(
            child: GestureDetector(
              // Swallow taps on the panel so they don't dismiss.
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _SearchBar(
                      controller: _query,
                      focus: _focus,
                      hint: t.searchHint,
                      onChanged: _onChanged,
                      onClear: _query.text.isEmpty ? null : _clear,
                      onBack: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: _buildResults(t, scheme)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(AppStrings t, ColorScheme scheme) {
    if (!_isQueryable) {
      return _Hint(text: t.searchMinChars);
    }
    return FutureBuilder<List<PersonSearchResult>>(
      future: _pending,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Hint(text: t.searchError);
        }
        final results = snapshot.data ?? const [];
        if (results.isEmpty) {
          return _Hint(text: t.searchNoResults);
        }
        return _ResultsPanel(
          scheme: scheme,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final person = results[i];
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(person.name),
                onTap: () => Navigator.pop(context, person.id),
              );
            },
          ),
        );
      },
    );
  }
}

/// The floating, translucent search field at the top of the overlay.
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focus,
    required this.hint,
    required this.onChanged,
    required this.onClear,
    required this.onBack,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      color: scheme.surface.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(28),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
              ),
            ),
          ),
          if (onClear != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: onClear,
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// A translucent rounded card that hosts the results list.
class _ResultsPanel extends StatelessWidget {
  const _ResultsPanel({required this.scheme, required this.child});

  final ColorScheme scheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: scheme.surface.withValues(alpha: 0.82),
        child: child,
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      );
}
