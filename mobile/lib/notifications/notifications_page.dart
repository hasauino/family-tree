import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../models/app_notification.dart';
import '../theme_controller.dart';
import '../tree/tree_page.dart';
import '../widgets/glass.dart';
import '../widgets/top_toast.dart';

/// The notification bell's destination: a list of the signed-in user's
/// notifications with a "mark all as read" action. Tapping an entry marks it
/// read and — when it points at a person — opens that person's tree.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.auth, required this.theme});

  final AuthService auth;
  final ThemeController theme;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<NotificationPage> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = widget.auth.api.notifications();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.auth.api.notifications());
    await _future;
  }

  Future<void> _markAllRead() async {
    final t = AppStrings.of(context);
    setState(() => _busy = true);
    try {
      await widget.auth.api.markAllNotificationsRead();
      await _reload();
    } catch (_) {
      if (mounted) showTopToast(context, t.errorConnection);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onTap(AppNotification n) async {
    // Mark read in the background; don't block navigation on it.
    if (!n.isRead) {
      widget.auth.api.markNotificationRead(n.id).then((_) {}, onError: (_) {});
    }
    if (n.personId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TreePage(
            auth: widget.auth,
            theme: widget.theme,
            initialPersonId: n.personId,
          ),
        ),
      );
    }
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.notificationsTitle),
        actions: [
          IconButton(
            tooltip: t.markAllRead,
            icon: _busy
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.done_all),
            onPressed: _busy ? null : _markAllRead,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<NotificationPage>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _EmptyOrError(message: t.errorConnection, onRetry: _reload);
            }
            final items = snap.data?.notifications ?? const [];
            if (items.isEmpty) {
              return _EmptyOrError(message: t.notificationsEmpty, onRetry: _reload);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _NotificationTile(
                notification: items[i],
                onTap: () => _onTap(items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final n = notification;
    final body = _localizedBody(t, n);
    return GlassPanel(
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.primary.withValues(alpha: 0.12),
          child: Icon(_iconFor(n.kind), color: scheme.primary, size: 20),
        ),
        title: Text(
          _localizedTitle(t, n),
          style: TextStyle(
            fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body.isNotEmpty) Text(body),
            const SizedBox(height: 4),
            Text(
              _relativeTime(t, n.createdAt),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        isThreeLine: body.isNotEmpty,
        trailing: n.isRead
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
              ),
      ),
    );
  }

  IconData _iconFor(AppNotificationKind kind) {
    switch (kind) {
      case AppNotificationKind.pendingAddition:
        return Icons.person_add_alt;
      case AppNotificationKind.changeVerified:
        return Icons.verified;
      case AppNotificationKind.nodeChanged:
        return Icons.edit_note;
      case AppNotificationKind.broadcast:
        return Icons.campaign;
      case AppNotificationKind.unknown:
        return Icons.notifications;
    }
  }

  /// The title shown for [n], localized to the reader's language. Only the
  /// admin-authored broadcast keeps its server-stored title.
  String _localizedTitle(AppStrings t, AppNotification n) {
    switch (n.kind) {
      case AppNotificationKind.pendingAddition:
        return t.notifKindPending;
      case AppNotificationKind.changeVerified:
        return t.notifKindVerified;
      case AppNotificationKind.nodeChanged:
        return t.notifKindChanged;
      case AppNotificationKind.broadcast:
        return n.title.isNotEmpty ? n.title : t.notifKindBroadcast;
      case AppNotificationKind.unknown:
        return n.title.isNotEmpty ? n.title : t.notificationsTitle;
    }
  }

  /// The body shown for [n], built in the reader's language from the structured
  /// fields. The broadcast (admin free-text) and unknown kinds fall back to the
  /// server-stored body.
  String _localizedBody(AppStrings t, AppNotification n) {
    switch (n.kind) {
      case AppNotificationKind.pendingAddition:
        if (n.names.length <= 1) {
          return t.notifBodyAddedOne(
            n.actorName ?? '',
            n.names.isNotEmpty ? n.names.first : '',
          );
        }
        return t.notifBodyAddedMany(n.actorName ?? '', n.count, _joinItems(t, n.names));
      case AppNotificationKind.changeVerified:
        if (n.names.length <= 1) {
          return t.notifBodyVerifiedOne(
            n.names.isNotEmpty ? n.names.first : (n.personName ?? ''),
          );
        }
        return t.notifBodyVerifiedMany(n.count, _joinItems(t, n.names));
      case AppNotificationKind.nodeChanged:
        final labels = n.fieldKeys.map((f) => _fieldLabel(t, f)).toList();
        return t.notifBodyChanged(n.personName ?? '', _joinItems(t, labels));
      case AppNotificationKind.broadcast:
      case AppNotificationKind.unknown:
        return n.body;
    }
  }

  /// Joins names/labels with the locale's separator, capping the inline list at
  /// five and appending "and N more" beyond that (mirrors the server format).
  String _joinItems(AppStrings t, List<String> items) {
    const max = 5;
    final shown = items.take(max).toList();
    var text = shown.join(t.listSeparator);
    final extra = items.length - shown.length;
    if (extra > 0) text += ' ${t.notifAndMore(extra)}';
    return text;
  }

  String _fieldLabel(AppStrings t, String key) {
    switch (key) {
      case 'name':
        return t.notifFieldName;
      case 'designation':
        return t.notifFieldDesignation;
      case 'history':
        return t.notifFieldHistory;
      case 'parent':
        return t.notifFieldParent;
      default:
        return key;
    }
  }

  String _relativeTime(AppStrings t, DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return t.timeJustNow;
    if (diff.inMinutes < 60) return t.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return t.timeHoursAgo(diff.inHours);
    return t.timeDaysAgo(diff.inDays);
  }
}

class _EmptyOrError extends StatelessWidget {
  const _EmptyOrError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    // Wrap in a scrollable so RefreshIndicator still works when empty.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(message, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}
