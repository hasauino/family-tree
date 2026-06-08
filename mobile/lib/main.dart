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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: TreePage(auth: auth),
    );
  }
}
