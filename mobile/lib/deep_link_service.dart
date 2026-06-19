import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth/auth_service.dart';
import 'deep_link.dart';
import 'theme_controller.dart';
import 'tree/tree_page.dart';

/// Receives links from outside the running UI and opens the matching tree:
///
///   * the URL the app was launched with (cold start), and
///   * any Android App Link / iOS Universal Link tapped while it is running.
///
/// Navigation goes through [navigatorKey] (the same global key the push
/// service uses) so it works without a [BuildContext].
class DeepLinkService {
  DeepLinkService({
    required this.auth,
    required this.theme,
    required this.navigatorKey,
  });

  final AuthService auth;
  final ThemeController theme;
  final GlobalKey<NavigatorState> navigatorKey;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// The link the app was launched from, if any. On the web this is just the
  /// current address; on native it is the App/Universal Link that opened the
  /// app (null for a normal launch).
  Future<DeepLink?> initialLink() async {
    if (kIsWeb) return DeepLink.parse(Uri.base);
    try {
      final uri = await _appLinks.getInitialLink();
      return uri == null ? null : DeepLink.parse(uri);
    } catch (e) {
      debugPrint('DeepLinkService: getInitialLink failed ($e)');
      return null;
    }
  }

  /// Subscribes to links tapped while the app is already running (native
  /// only; a no-op stream on the web). Call once at startup.
  void listen() {
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        final link = DeepLink.parse(uri);
        if (link != null) open(link);
      },
      onError: (Object e) =>
          debugPrint('DeepLinkService: uriLinkStream error ($e)'),
    );
  }

  /// Pushes the tree screen for [link] on top of the current navigation
  /// stack. Safe to call before the navigator is mounted (it no-ops).
  void open(DeepLink link) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => switch (link) {
          PersonLink(:final id) =>
            TreePage(auth: auth, theme: theme, initialPersonId: id),
          PathLink(:final from, :final to) =>
            TreePage(auth: auth, theme: theme, initialPath: (from: from, to: to)),
        },
      ),
    );
  }

  void dispose() {
    _sub?.cancel();
  }
}
