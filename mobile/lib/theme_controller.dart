import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_strings.dart';

/// Holds the app-wide [ThemeMode] and persists the user's choice so it
/// survives restarts. The whole app rebuilds its [MaterialApp.themeMode]
/// off this notifier; the home and tree screens flip it via [cycle].
class ThemeController extends ChangeNotifier {
  static const _key = 'theme.mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Loads any persisted choice; defaults to following the device ("auto").
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = _decode(prefs.getString(_key));
    notifyListeners();
  }

  /// Advances to the next mode, cycling auto → light → dark → auto, and
  /// persists the new choice.
  void cycle() {
    _mode = switch (_mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _encode(_mode));
  }

  static ThemeMode _decode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _encode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  /// The icon representing the *current* mode (not the next one), so the
  /// button shows what's active at a glance.
  static IconData iconFor(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Icons.contrast,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
  };

  /// The localized name of [mode], used in the toggle button's tooltip so the
  /// user knows what's active and that tapping cycles to the next mode.
  static String labelFor(ThemeMode mode, AppStrings t) => switch (mode) {
    ThemeMode.system => t.themeModeAuto,
    ThemeMode.light => t.themeModeLight,
    ThemeMode.dark => t.themeModeDark,
  };
}

/// An [IconButton] that cycles the app theme auto → light → dark, showing the
/// icon of the currently-active mode. Shared by the home and tree action bars
/// so both screens flip the same persisted [ThemeController].
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, required this.theme, required this.t});

  final ThemeController theme;
  final AppStrings t;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) => IconButton(
        tooltip: t.themeToggleTooltip(
          ThemeController.labelFor(theme.mode, t),
        ),
        icon: Icon(ThemeController.iconFor(theme.mode)),
        onPressed: theme.cycle,
      ),
    );
  }
}
