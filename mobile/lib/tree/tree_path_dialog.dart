import 'package:flutter/material.dart';

import '../graphql/family_api.dart';
import '../l10n/app_strings.dart';
import '../widgets/glass.dart';
import 'search_overlay.dart';

/// Opens the "show path from ancestor to descendant" picker dialog. Returns
/// `(from: ancestorId, to: descendantId)` when the user taps Go, or null if
/// they cancel.
Future<({int from, int to})?> showTreePathDialog(
  BuildContext context,
  FamilyApi api,
) {
  return showDialog<({int from, int to})>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.15),
    builder: (ctx) => _TreePathDialog(api: api),
  );
}

class _TreePathDialog extends StatefulWidget {
  const _TreePathDialog({required this.api});

  final FamilyApi api;

  @override
  State<_TreePathDialog> createState() => _TreePathDialogState();
}

class _TreePathDialogState extends State<_TreePathDialog> {
  PersonSearchResult? _from;
  PersonSearchResult? _to;

  Future<void> _pick({required bool isFrom}) async {
    final t = AppStrings.of(context);
    final picked = await showSearchOverlay(
      context,
      widget.api,
      hint: isFrom ? t.treePathFromHint : t.treePathToHint,
    );
    if (picked != null && mounted) {
      setState(() => isFrom ? _from = picked : _to = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final canGo = _from != null && _to != null;
    return GlassDialog(
      title: t.treePathTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PersonPickerField(
            label: t.treePathFromLabel,
            person: _from,
            onTap: () => _pick(isFrom: true),
          ),
          const SizedBox(height: 12),
          _PersonPickerField(
            label: t.treePathToLabel,
            person: _to,
            onTap: () => _pick(isFrom: false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: canGo
              ? () => Navigator.pop(context, (from: _from!.id, to: _to!.id))
              : null,
          child: Text(t.treePathGo),
        ),
      ],
    );
  }
}

/// A tappable, field-shaped row that shows the selected person's name (or a
/// placeholder when nothing is selected yet). Tapping opens the search overlay.
class _PersonPickerField extends StatelessWidget {
  const _PersonPickerField({
    required this.label,
    required this.person,
    required this.onTap,
  });

  final String label;
  final PersonSearchResult? person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: glassFieldDecoration(
          context,
          InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.search, size: 20),
          ),
        ),
        child: Text(
          person?.name ?? t.treePathPickHint,
          style: person == null
              ? TextStyle(color: scheme.onSurface.withValues(alpha: 0.4))
              : null,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
