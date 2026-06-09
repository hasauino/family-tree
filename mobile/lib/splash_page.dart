import 'package:flutter/material.dart';

import 'auth/auth_service.dart';
import 'tree/tree_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.auth});

  final AuthService auth;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  // Matches the reference gradient (dark teal-green → light mint).
  static const _gradientTop = Color(0xFF0C6558);
  static const _gradientBottom = Color(0xFF2DC4A2);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 1800), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => TreePage(auth: widget.auth),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_gradientTop, _gradientBottom],
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                // logo_shadow.png has baked-in shadow padding — display larger
                // so the visible icon content matches the reference bitmap size.
                child: Image.asset(
                  'assets/icon/tree_512.png',
                  width: 240,
                  height: 240,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
