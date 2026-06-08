import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/auth_service.dart';
import 'config.dart';
import 'l10n/app_strings.dart';
import 'tree/tree_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthService();
  // Restore any persisted login in the background; the UI updates via the
  // AuthService listenable once it resolves.
  auth.restore();
  runApp(FamilyTreeApp(auth: auth));
}

class FamilyTreeApp extends StatelessWidget {
  const FamilyTreeApp({super.key, required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5B8FF9);
    return MaterialApp(
      onGenerateTitle: (context) => AppStrings.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      // Language: forced by AppConfig.locale, or follows the device when null.
      locale: AppConfig.locale,
      supportedLocales: AppConfig.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: ThemeMode.system,
      theme: _buildTheme(ColorScheme.fromSeed(seedColor: seed)),
      darkTheme: _buildTheme(
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      ),
      home: TreePage(auth: auth),
    );
  }

  /// A flat, left-aligned, transparent-app-bar look shared by every page so
  /// the chrome blends with the content instead of sitting in its own bar.
  ThemeData _buildTheme(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
    );
  }
}
