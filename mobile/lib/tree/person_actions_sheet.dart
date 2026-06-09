import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../graphql/graphql_client.dart';
import '../l10n/app_strings.dart';
import '../models/family_node.dart';
import '../widgets/glass.dart';
import 'edit_person_page.dart';
import 'search_overlay.dart';
import 'tree_controller.dart';

/// The long-press menu for a person node — the Flutter equivalent of the web
/// right-click menu. Read-only users see details + "center here"; authenticated
/// users also get Add children / Edit / Move / Delete; staff additionally get
/// Publish/Unpublish and Bookmark/Unbookmark.
class PersonActionsSheet extends StatefulWidget {
  const PersonActionsSheet({
    super.key,
    required this.node,
    required this.controller,
    required this.auth,
    required this.onCenter,
    this.onMoved,
  });

  final FamilyNode node;
  final TreeController controller;
  final AuthService auth;

  /// Re-centers the tree on this node (used by the "center here" action).
  final VoidCallback onCenter;

  /// Called after a successful move so the tree can be reloaded.
  final VoidCallback? onMoved;

  @override
  State<PersonActionsSheet> createState() => _PersonActionsSheetState();
}

class _PersonActionsSheetState extends State<PersonActionsSheet> {
  bool _loadingStatus = false;
  bool _busy = false;
  bool? _canDelete;
  bool? _published;
  bool? _bookmarked;
  // null = not loaded; true = has parent; false = no parent (orphan root)
  bool? _hasParent;

  int get _id => widget.node.id;

  @override
  void initState() {
    super.initState();
    if (widget.auth.isAuthenticated) _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loadingStatus = true);
    try {
      final canDelete = await widget.controller.canDelete(_id);
      final details = await widget.controller.personDetails(_id);
      bool? published;
      bool? bookmarked;
      if (widget.auth.isStaff) {
        final status = await widget.controller.publishStatus(_id);
        published = status.published;
        bookmarked = status.bookmarked;
      }
      if (!mounted) return;
      setState(() {
        _canDelete = canDelete;
        _hasParent = details.parentId != null;
        _published = published;
        _bookmarked = bookmarked;
      });
    } catch (_) {
      // Leave actions hidden if we can't determine permissions.
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Shows a snackbar via [messenger], which stays valid even after the sheet
  /// is popped (used for "success" toasts that follow a dismiss).
  void _toastVia(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Runs an authenticated action with a busy guard and uniform error toast.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    final fallback = AppStrings.of(context).errorConnection;
    setState(() => _busy = true);
    try {
      await action();
    } on GraphQLException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast(fallback);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addChildren() async {
    final t = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final names = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => const _AddChildrenDialog(),
    );
    if (names == null || names.isEmpty) return;
    await _run(() async {
      final result = await widget.controller.addChildren(_id, names);
      if (mounted) Navigator.pop(context);
      if (result.warnings.isEmpty) {
        _toastVia(messenger, t.childrenAdded);
      } else {
        _toastVia(
          messenger,
          t.childrenAddedWarning(result.warnings.join(', ')),
        );
      }
    });
  }

  Future<void> _edit() async {
    final navigator = Navigator.of(context);
    final saved = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => EditPersonPage(
          controller: widget.controller,
          personId: _id,
        ),
      ),
    );
    // Close the sheet once the edit is saved so the refreshed node shows.
    if (saved == true && mounted) navigator.pop();
  }

  Future<void> _addParentNode() async {
    final t = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await _promptText(t.addParentTitle, t.parentNameLabel);
    if (name == null || name.trim().isEmpty) return;
    await _run(() async {
      await widget.controller.addParent(_id, name.trim());
      if (mounted) Navigator.pop(context);
      _toastVia(messenger, t.parentAdded);
      widget.onMoved?.call();
    });
  }

  Future<void> _moveNode() async {
    final t = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showSearchOverlay(
      context,
      widget.auth.api,
      hint: t.selectParentHint,
    );
    if (picked == null) return;
    await _run(() async {
      await widget.controller.movePerson(_id, picked.id);
      if (mounted) Navigator.pop(context);
      _toastVia(messenger, t.nodeMoved);
      widget.onMoved?.call();
    });
  }

  Future<String?> _promptText(String title, String label) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _TextPromptDialog(title: title, label: label),
    );
  }

  Future<void> _delete() async {
    final t = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final info = await widget.controller.deleteInfo(_id);
    if (!mounted) return;

    String confirmMessage;
    if (info.isRootWithSingleChild) {
      confirmMessage = t.deleteOrphanConfirm(widget.node.label);
    } else if (info.descendantCount > 0) {
      confirmMessage = t.deleteCascadeConfirm(widget.node.label, info.descendantCount);
    } else {
      confirmMessage = t.deleteConfirm(widget.node.label);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassDialog(
        title: t.deleteTitle,
        content: Text(confirmMessage),
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
    );
    if (confirmed != true) return;
    await _run(() async {
      await widget.controller.deletePerson(_id);
      if (mounted) Navigator.pop(context);
      _toastVia(messenger, t.personDeleted);
    });
  }

  Future<void> _togglePublish() async {
    final t = AppStrings.of(context);
    await _run(() async {
      if (_published == true) {
        await widget.controller.unpublishPerson(_id);
        setState(() {
          _published = false;
          _bookmarked = false;
        });
        _toast(t.unpublished);
      } else {
        await widget.controller.publishPerson(_id);
        setState(() => _published = true);
        _toast(t.published);
      }
    });
  }

  Future<void> _toggleBookmark() async {
    final t = AppStrings.of(context);
    await _run(() async {
      if (_bookmarked == true) {
        final r = await widget.controller.unbookmarkPerson(_id);
        if (!r.ok) throw GraphQLException(r.message ?? t.errorConnection);
        setState(() => _bookmarked = false);
        _toast(t.bookmarkRemoved);
      } else {
        final r = await widget.controller.bookmarkPerson(_id);
        if (!r.ok) throw GraphQLException(r.message ?? t.errorConnection);
        setState(() => _bookmarked = true);
        _toast(t.bookmarked);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final auth = widget.auth;
    final scheme = Theme.of(context).colorScheme;
    // The same frosted-glass surface as the search overlay / action bar —
    // a blurred, translucent panel rather than the sheet's opaque default.
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
                widget.node.label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(widget.node.title ?? t.noDetails),
              const SizedBox(height: 16),
              if (_loadingStatus || _busy) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _busy
                        ? null
                        : () {
                            Navigator.pop(context);
                            widget.onCenter();
                          },
                    icon: const Icon(Icons.center_focus_strong),
                    label: Text(t.centerTreeHere),
                  ),
                  if (auth.isAuthenticated) ...[
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _addChildren,
                      icon: const Icon(Icons.group_add),
                      label: Text(t.addChildren),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _edit,
                      icon: const Icon(Icons.edit),
                      label: Text(t.edit),
                    ),
                    // "Add parent" for orphan nodes, "Move" for nodes with a parent.
                    if (_hasParent == false)
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _addParentNode,
                        icon: const Icon(Icons.account_tree),
                        label: Text(t.addParent),
                      ),
                    if (_hasParent == true)
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _moveNode,
                        icon: const Icon(Icons.drive_file_move_outline),
                        label: Text(t.moveNode),
                      ),
                    if (auth.isStaff && _published != null)
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _togglePublish,
                        icon: Icon(
                          _published! ? Icons.visibility_off : Icons.visibility,
                        ),
                        label: Text(_published! ? t.unpublish : t.publish),
                      ),
                    if (auth.isStaff && _published == true)
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _toggleBookmark,
                        icon: Icon(
                          _bookmarked == true ? Icons.star : Icons.star_border,
                        ),
                        label: Text(
                          _bookmarked == true ? t.removeBookmark : t.bookmark,
                        ),
                      ),
                    if (_canDelete == true)
                      FilledButton.tonalIcon(
                        // The one action that needs to read as "dangerous" —
                        // tinted with the error colour rather than the app's
                        // default primary-tinted glass-button look.
                        style: glassButtonStyle(scheme.error),
                        onPressed: _busy ? null : _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(t.delete),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({required this.title, required this.label});

  final String title;
  final String label;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return GlassDialog(
      title: widget.title,
      content: TextField(
        controller: _controller,
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
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(t.add),
        ),
      ],
    );
  }
}

/// A dialog for entering multiple child names at once. Each name is added to
/// a chip list; the whole list is returned when the user confirms.
class _AddChildrenDialog extends StatefulWidget {
  const _AddChildrenDialog();

  @override
  State<_AddChildrenDialog> createState() => _AddChildrenDialogState();
}

class _AddChildrenDialogState extends State<_AddChildrenDialog> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _names = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addName() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _names.add(name);
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return GlassDialog(
      title: t.addChildrenTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: glassFieldDecoration(
                    context,
                    InputDecoration(
                      labelText: t.childNameLabel,
                      hintText: t.childNamesHint,
                    ),
                  ),
                  onSubmitted: (_) => _addName(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _addName,
                icon: const Icon(Icons.add, size: 18),
                label: Text(t.add),
              ),
            ],
          ),
          if (_names.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in _names)
                  Chip(
                    label: Text(name),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() => _names.remove(name)),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: _names.isEmpty
              ? null
              : () => Navigator.pop(context, List<String>.from(_names)),
          child: Text(t.add),
        ),
      ],
    );
  }
}
