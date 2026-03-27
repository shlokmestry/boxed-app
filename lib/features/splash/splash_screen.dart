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
  // ✅ Class-level field
  final _storage = const FlutterSecureStorage();

  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    // ✅ Scale from 0.85 → 1.0 with a smooth ease-out
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
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
    // ✅ Run auth check and minimum display time in parallel
    final results = await Future.wait([
      _resolveDestination(),
      Future.delayed(const Duration(milliseconds: 1200)),
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
      // ✅ If anything throws, fall back to login safely
      return AppRouter.login;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ Scale + Fade on the icon
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Text('📦', style: TextStyle(fontSize: 48)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Boxed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              // ✅ w500 + opacity 0.6 for legibility
              Text(
                'Seal memories. Open later.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}