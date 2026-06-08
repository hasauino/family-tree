import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../graphql/graphql_client.dart';
import '../l10n/app_strings.dart';
import '../models/family_node.dart';
import 'edit_person_page.dart';
import 'tree_controller.dart';

/// The long-press menu for a person node — the Flutter equivalent of the web
/// right-click menu. Read-only users see details + "center here"; authenticated
/// users also get Add child / Edit / Delete; staff additionally get
/// Publish/Unpublish and Bookmark/Unbookmark.
class PersonActionsSheet extends StatefulWidget {
  const PersonActionsSheet({
    super.key,
    required this.node,
    required this.controller,
    required this.auth,
    required this.onCenter,
  });

  final FamilyNode node;
  final TreeController controller;
  final AuthService auth;

  /// Re-centers the tree on this node (used by the "center here" action).
  final VoidCallback onCenter;

  @override
  State<PersonActionsSheet> createState() => _PersonActionsSheetState();
}

class _PersonActionsSheetState extends State<PersonActionsSheet> {
  bool _loadingStatus = false;
  bool _busy = false;
  bool? _canDelete;
  bool? _published;
  bool? _bookmarked;

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

  Future<void> _addChild() async {
    final t = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await _promptText(t.addChildTitle, t.childNameLabel);
    if (name == null || name.trim().isEmpty) return;
    await _run(() async {
      await widget.controller.addChild(_id, name.trim());
      if (mounted) Navigator.pop(context);
      _toastVia(messenger, t.childAdded);
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

  Future<void> _delete() async {
    final t = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteTitle),
        content: Text(t.deleteConfirm(widget.node.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
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

  Future<String?> _promptText(String title, String label) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _TextPromptDialog(title: title, label: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final auth = widget.auth;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.node.label, style: Theme.of(context).textTheme.titleLarge),
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
                  onPressed: _busy ? null : _addChild,
                  icon: const Icon(Icons.person_add),
                  label: Text(t.addChild),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _edit,
                  icon: const Icon(Icons.edit),
                  label: Text(t.edit),
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
                    style: FilledButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(t.delete),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A small "enter some text" dialog that owns its [TextEditingController].
///
/// Keeping the controller in a [State] (rather than disposing it via the
/// showDialog future's `whenComplete`) means it stays alive through the dialog's
/// exit transition and is only disposed once the route is gone — avoiding a
/// "used after being disposed" crash when the closing dialog rebuilds.
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
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: widget.label),
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
