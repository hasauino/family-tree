import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../auth/auth_service.dart';
import '../theme_controller.dart';
import '../tree/tree_page.dart';

/// Background isolate handler. Must be a top-level function. We don't need to do
/// anything here (the OS shows the notification automatically when the message
/// carries a `notification` block); it exists so FCM can wake the app.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op: the system tray notification is drawn by the OS from the payload.
}

/// Wires Firebase Cloud Messaging into the app: requests permission, registers
/// this device's token with the backend (so it can be pushed to), renders a
/// banner for messages that arrive while the app is foregrounded, and deep-links
/// to the relevant person when a notification is tapped.
///
/// Entirely best-effort: if Firebase isn't configured for the current platform
/// (missing `google-services.json` / `GoogleService-Info.plist`) initialisation
/// fails quietly and the app simply runs without push — in-app notifications via
/// the bell still work.
class PushService {
  PushService({
    required this.auth,
    required this.theme,
    required this.navigatorKey,
  });

  final AuthService auth;
  final ThemeController theme;
  final GlobalKey<NavigatorState> navigatorKey;

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'family_tree_default',
    'Notifications',
    description: 'Family tree updates and announcements',
    importance: Importance.high,
  );

  bool _enabled = false;
  String? _token;

  /// Call once at startup (after [AuthService.restore]). Safe to call when
  /// Firebase is unconfigured — it just disables push.
  Future<void> init() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('PushService: Firebase not configured, push disabled ($e)');
      return;
    }
    _enabled = true;

    await _initLocalNotifications();

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    // iOS: also show banners while the app is foregrounded.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    // Cold start from a tapped notification.
    final initial = await messaging.getInitialMessage();
    if (initial != null) _onMessageOpened(initial);

    messaging.onTokenRefresh.listen((token) {
      _token = token;
      _registerIfPossible();
    });

    _token = await messaging.getToken();

    // Register now (if already signed in) and whenever auth state changes.
    auth.addListener(_onAuthChanged);
    _registerIfPossible();
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final personId = int.tryParse(response.payload ?? '');
        if (personId != null) _openPerson(personId);
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  bool _wasAuthenticated = false;

  void _onAuthChanged() {
    final isAuth = auth.isAuthenticated;
    if (isAuth && !_wasAuthenticated) {
      _registerIfPossible();
    } else if (!isAuth && _wasAuthenticated) {
      _unregister();
    }
    _wasAuthenticated = isAuth;
  }

  Future<void> _registerIfPossible() async {
    if (!_enabled || _token == null || !auth.isAuthenticated) return;
    try {
      await auth.api.registerDeviceToken(_token!, _platformName());
    } catch (e) {
      debugPrint('PushService: token registration failed ($e)');
    }
  }

  Future<void> _unregister() async {
    final token = _token;
    if (!_enabled || token == null) return;
    try {
      await auth.api.unregisterDeviceToken(token);
    } catch (_) {
      // Best-effort; the backend also prunes stale tokens on send failure.
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['person_id']?.toString(),
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    final personId = int.tryParse(message.data['person_id']?.toString() ?? '');
    if (personId != null && personId > 0) _openPerson(personId);
  }

  void _openPerson(int personId) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => TreePage(
          auth: auth,
          theme: theme,
          initialPersonId: personId,
        ),
      ),
    );
  }

  String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return kIsWeb ? 'web' : 'other';
    }
  }
}
