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

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    const storage = FlutterSecureStorage();
    final onboardingSeen = await storage.read(key: 'onboarding_seen');

    if (onboardingSeen != 'true') {
      Navigator.pushReplacementNamed(context, AppRouter.onboarding);
      return;
    }

    final authProvider = context.read<AuthProvider>();
    await authProvider.checkSession();

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      final hasUsername = await authProvider.checkUsername();
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        hasUsername ? AppRouter.home : AppRouter.chooseUsername,
      );
    } else {
      Navigator.pushReplacementNamed(context, AppRouter.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          '📦',
          style: TextStyle(fontSize: 64),
        ),
      ),
    );
  }
}