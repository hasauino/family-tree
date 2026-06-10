/// App-wide configuration.
///
/// The GraphQL endpoint of the Django backend. Override at build/run time with:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
///
/// Defaults:
///   * Web / iOS simulator / desktop -> http://localhost:8000
///   * Android emulator              -> http://10.0.2.2:8000 (host loopback)
///
/// The Django dev server is started with `python manage.py runserver`.
library;

import 'package:flutter/widgets.dart' show Locale;

class AppConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Base URL of the backend (no trailing slash).
  ///
  /// Defaults to `127.0.0.1` (not `localhost`) on purpose: `localhost` resolves
  /// to both IPv4 `127.0.0.1` and IPv6 `::1`, and clients (iOS, browsers) often
  /// try `::1` first — but Django's `runserver` binds IPv4 only, so the request
  /// is refused. Using `127.0.0.1` forces IPv4 and "just works" for the web
  /// build, the iOS simulator, and desktop. For the Android emulator, override
  /// with `--dart-define=API_BASE_URL=http://10.0.2.2:8000`; for a physical
  /// device, use the host's LAN IP.
  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    return 'http://192.168.1.23:8000';
  }

  /// Full URL of the GraphQL endpoint (see `main/urls.py`).
  static String get graphqlUrl => '$baseUrl/graphql';

  /// The person whose tree is opened first when the app launches.
  /// Change this to any existing person id in your database.
  static const int rootPersonId =
      int.fromEnvironment('ROOT_PERSON_ID', defaultValue: 4356);

  // --- Tree animation tuning ---------------------------------------------
  // Durations driving the interactive tree. Lower = snappier; set to
  // [Duration.zero] to disable an animation entirely.

  /// How long nodes take to slide into their new layout positions when the
  /// tree expands/repositions (graphview `toggleAnimationDuration`).
  static const Duration treeLayoutAnimationDuration =
      Duration(milliseconds: 100);

  /// How long the animated pan takes when centering on a node after a tap.
  /// Set to [Duration.zero] to snap instantly.
  static const Duration nodePanDuration = Duration(milliseconds: 400);

  /// How long the zoom-in animation takes after the from→to path is loaded
  /// (the camera flies from the full-tree view into the target node).
  /// Set to [Duration.zero] to snap instantly.
  static const Duration treePathZoomDuration = Duration(milliseconds: 2000);

  /// How long the home view's load-time intro takes: the camera starts zoomed
  /// in on the center node and glides back out to fit the whole tree.
  /// Set to [Duration.zero] to skip the intro and snap straight to the fit.
  static const Duration homeIntroZoomDuration = Duration(milliseconds: 1100);

  // --- Localization ------------------------------------------------------
  // To add a language: add its [Locale] here AND a matching entry in
  // `_values` inside `lib/l10n/app_strings.dart`. Arabic renders right-to-left
  // automatically once it is the active locale.

  /// Languages the app ships with. The first entry is the fallback used when
  /// the device language is not supported.
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ar'),
  ];

  /// The language the app starts in.
  ///   * `null`         -> follow the device language, falling back to the
  ///                       first [supportedLocales] entry when unsupported.
  ///   * `Locale('ar')` -> force Arabic (RTL) regardless of the device.
  ///   * `Locale('en')` -> force English regardless of the device.
  static const Locale? locale = Locale('ar');

  // --- Authentication ----------------------------------------------------
  // Which sign-in methods actually appear is decided by the backend's
  // `authConfig` query, so a provider only shows once it is enabled AND
  // credentialed server-side. The values below are the *client-side* pieces a
  // provider additionally needs, supplied at build time, e.g.:
  //
  //   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
  //
  // Facebook and Apple need no Dart value — their credentials live in the
  // native iOS/Android config (see ios/Runner/Info.plist and
  // android/app/src/main/res/values/strings.xml).

  /// The OAuth *web/server* client id used as the audience of the Google ID
  /// token, so the token the app sends verifies against the backend's
  /// `GOOGLE_CLIENT_IDS`. Required for Google sign-in; leave empty to rely on
  /// the platform default (Android reads it from `google-services`).
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
}
