import 'package:flutter/material.dart';
import 'package:boxed_app/features/splash/splash_screen.dart';
import 'package:boxed_app/features/onboarding/screens/onboarding_screen.dart';
import 'package:boxed_app/features/auth/screens/auth_screen.dart';
import 'package:boxed_app/features/auth/screens/choose_username_screen.dart';
import 'package:boxed_app/features/auth/screens/forgot_password_screen.dart';
import 'package:boxed_app/features/auth/screens/change_password_screen.dart';
import 'package:boxed_app/features/capsules/screens/home_screen.dart';
import 'package:boxed_app/features/capsules/screens/create_capsule_screen.dart';
import 'package:boxed_app/features/capsules/screens/capsule_detail_screen.dart';
import 'package:boxed_app/features/memories/screens/add_memory_screen.dart';
import 'package:boxed_app/features/profile/screens/profile_screen.dart';
import 'package:boxed_app/features/settings/screens/settings_screen.dart';

class AppRouter {
  static const String splash          = '/';
  static const String onboarding      = '/onboarding';
  static const String login           = '/login';
  static const String signup          = '/signup';
  static const String chooseUsername  = '/choose-username';
  static const String forgotPassword  = '/forgot-password';
  static const String changePassword  = '/change-password';
  static const String home            = '/home';
  static const String createCapsule   = '/create-capsule';
  static const String capsuleDetail   = '/capsule-detail';
  static const String addMemory       = '/add-memory';
  static const String profile         = '/profile';
  static const String settings        = '/settings';

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return _route(const SplashScreen());
      case onboarding:
        return _route(const OnboardingScreen());
      case login:
        return _route(const AuthScreen(isLogin: true));
      case signup:
        return _route(const AuthScreen(isLogin: false));
      case chooseUsername:
        return _route(const ChooseUsernameScreen());
      case forgotPassword:
        return _route(const ForgotPasswordScreen());
      case changePassword:
        return _route(const ChangePasswordScreen());
      case home:
        return _route(const HomeScreen());
      case createCapsule:
        return _route(const CreateCapsuleScreen());
      case capsuleDetail:
        final capsuleId = routeSettings.arguments as String;
        return _route(CapsuleDetailScreen(capsuleId: capsuleId));
      case addMemory:
        final capsuleId = routeSettings.arguments as String;
        return _route(AddMemoryScreen(capsuleId: capsuleId));
      case profile:
        return _route(const ProfileScreen());
      case settings:
        return _route(const SettingsScreen());
      default:
        return _route(const SplashScreen());
    }
  }

  static MaterialPageRoute _route(Widget page) {
    return MaterialPageRoute(builder: (_) => page);
  }
}