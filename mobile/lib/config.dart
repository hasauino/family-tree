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
  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    return 'http://localhost:8000';
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
  static const Locale? locale = null;
}
