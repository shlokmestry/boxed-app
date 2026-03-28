import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boxed_app/features/auth/providers/auth_provider.dart';
import 'package:boxed_app/core/router/app_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();

  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();
    _navigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    final results = await Future.wait([
      _resolveDestination(),
      Future.delayed(const Duration(milliseconds: 1400)),
    ]);

    if (!mounted) return;
    final destination = results[0] as String;
    Navigator.pushReplacementNamed(context, destination);
  }

  Future<String> _resolveDestination() async {
    try {
      final onboardingSeen = await _storage.read(key: 'onboarding_seen');
      if (onboardingSeen != 'true') return AppRouter.onboarding;

      final authProvider = context.read<AuthProvider>();
      await authProvider.checkSession();
      if (!mounted) return AppRouter.login;

      if (authProvider.isAuthenticated) {
        final hasUsername = await authProvider.checkUsername();
        return hasUsername ? AppRouter.home : AppRouter.chooseUsername;
      }

      return AppRouter.login;
    } catch (_) {
      return AppRouter.login;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            // Centered "boxed." wordmark
            const Center(
              child: Text(
                'boxed.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Georgia',
                  letterSpacing: -1,
                ),
              ),
            ),

            // Tagline pinned to bottom
            Positioned(
              bottom: 52,
              left: 0,
              right: 0,
              child: Text(
                'seal memories. open later.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}