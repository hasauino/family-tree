import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../theme_controller.dart';
import 'notifications_page.dart';

/// The bell button (with an unread-count badge) shown in the action bars, just
/// like the old web GUI's bell — but for every signed-in user, not only admins.
///
/// It polls the cheap `unreadNotificationCount` query on a timer and refreshes
/// immediately whenever the user returns from the [NotificationsPage] (so the
/// badge clears after "mark all as read"). Hidden entirely when signed out.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, required this.auth, required this.theme});

  final AuthService auth;
  final ThemeController theme;

  /// How often to refresh the unread badge while the app is foregrounded.
  static const pollInterval = Duration(seconds: 30);

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
    _refresh();
    _timer = Timer.periodic(NotificationBell.pollInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _onAuthChanged() {
    // Sign-in/out: clear stale count and re-fetch for the new user.
    if (mounted) setState(() => _unread = 0);
    _refresh();
  }

  Future<void> _refresh() async {
    if (!widget.auth.isAuthenticated) return;
    try {
      final count = await widget.auth.api.unreadNotificationCount();
      if (mounted) setState(() => _unread = count);
    } catch (_) {
      // Network hiccup — keep the last known count, try again next tick.
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsPage(auth: widget.auth, theme: widget.theme),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.isAuthenticated) return const SizedBox.shrink();
    final t = AppStrings.of(context);
    final icon = Icon(_unread > 0 ? Icons.notifications : Icons.notifications_none);
    return IconButton(
      tooltip: t.notificationsTooltip,
      onPressed: _open,
      icon: _unread > 0
          ? Badge(
              label: Text(_unread > 99 ? '99+' : '$_unread'),
              child: icon,
            )
          : icon,
    );
  }
}
