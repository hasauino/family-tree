import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/auth_service.dart';
import 'config.dart';
import 'l10n/app_strings.dart';
import 'splash_page.dart';
import 'theme_controller.dart';
import 'widgets/glass.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthService();
  // Restore any persisted login in the background; the UI updates via the
  // AuthService listenable once it resolves.
  auth.restore();
  final theme = ThemeController();
  // Likewise restore the persisted light/dark/auto choice in the background;
  // the MaterialApp rebuilds via the listenable once it resolves.
  theme.restore();
  runApp(FamilyTreeApp(auth: auth, theme: theme));
}

class FamilyTreeApp extends StatelessWidget {
  const FamilyTreeApp({super.key, required this.auth, required this.theme});

  final AuthService auth;
  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5B8FF9);
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) => MaterialApp(
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
        themeMode: theme.mode,
        theme: _buildTheme(ColorScheme.fromSeed(seedColor: seed)),
        darkTheme: _buildTheme(
          ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        ),
        builder: (context, child) => _GradientBackground(child: child),
        home: SplashPage(auth: auth, theme: theme),
      ),
    );
  }

  /// A flat, left-aligned, transparent-app-bar look shared by every page so
  /// the chrome blends with the content instead of sitting in its own bar.
  /// The scaffold background is transparent so [_GradientBackground] shows
  /// through underneath every page.
  ThemeData _buildTheme(ColorScheme scheme) {
    final fieldRadius = BorderRadius.circular(16);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
      // Every filled button — across the tree sheet, login, and edit-person
      // forms — gets the same translucent "glass pill" look, so the app
      // reads as one design language instead of a mix of stock Material
      // controls and ad-hoc overlay styling. One-off tints (e.g. the
      // error-coloured "delete" action) opt out via their own `style`.
      filledButtonTheme: FilledButtonThemeData(
        style: glassButtonStyle(scheme.primary).copyWith(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ),
      // Borderless text fields everywhere — the look the search field always
      // had: text sitting directly on whatever glass surface it's on, with
      // no outline stroke or extra fill layered on top of it.
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide.none),
      ),
    );
  }
}

/// Paints a soft "mesh gradient" backdrop behind every page: several large,
/// softly-faded colour pools overlap on a near-neutral base so their edges
/// blend into one another — a modern, multi-hue look (rather than a flat
/// linear blend) kept light enough to stay out of the way of the content
/// that sits on top of it.
class _GradientBackground extends StatelessWidget {
  const _GradientBackground({required this.child});

  final Widget? child;

  static const _lightBase = Color(0xFFEAEFFA);
  static const _lightPools = [
    _Pool(Alignment(-1.4, -1.2), Color(0xFFDFF5EF)), // seafoam
    _Pool(Alignment(1.5, -1.0), Color(0xFFDCEBFB)), // ice blue
    _Pool(Alignment(1.3, 1.3), Color(0xFFE6E1FB)), // soft violet
    _Pool(Alignment(-1.3, 1.2), Color(0xFFF6E0F4)), // orchid pink
    _Pool(Alignment(0.15, -0.05), Color(0xFFE9F2FC)), // pale sky
  ];

  static const _darkBase = Color(0xFF0E1117);
  static const _darkPools = [
    _Pool(Alignment(-1.4, -1.2), Color(0xFF163B3A)), // teal
    _Pool(Alignment(1.5, -1.0), Color(0xFF1E2A52)), // indigo
    _Pool(Alignment(1.3, 1.3), Color(0xFF2E2356)), // violet
    _Pool(Alignment(-1.3, 1.2), Color(0xFF3A1F40)), // dim magenta
    _Pool(Alignment(0.15, -0.05), Color(0xFF15294A)), // sky
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? _darkBase : _lightBase;
    final pools = isDark ? _darkPools : _lightPools;

    // Keep the OS status bar (clock/wifi/battery) legible against the gradient:
    // dark icons over the light theme, light icons over the dark theme. The
    // bar stays transparent so the tree/gradient shows through underneath it.
    // None of the tree pages use an AppBar, so this is the only thing driving
    // the overlay style — set it here so every page gets it.
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: base),
            for (final pool in pools)
              Align(
                alignment: pool.alignment,
                child: FractionallySizedBox(
                  widthFactor: 1.7,
                  heightFactor: 1.3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [pool.color, pool.color.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
            ?child,
          ],
        ),
      ),
    );
  }
}

/// A single soft colour pool of the mesh backdrop: an off-canvas anchor point
/// whose radial glow fades to transparent, so only its edge bleeds into view.
class _Pool {
  const _Pool(this.alignment, this.color);

  final Alignment alignment;
  final Color color;
}
