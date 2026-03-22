import 'package:flutter/material.dart';

class AppTheme {
  static const Color _darkBg = Color(0xFF000000);
  static const Color _darkSurface = Color(0xFF1A1A1A);
  static const Color _lightBg = Color(0xFFFFFFFF);
  static const Color _lightSurface = Color(0xFFF4F4F4);

  static ThemeData light() {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: _lightBg,
      colorScheme: const ColorScheme.light(
        primary: Colors.black,
        onPrimary: Colors.white,
        surface: _lightSurface,
        onSurface: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBg,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: _textTheme(base.textTheme),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: _darkBg,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        onPrimary: Colors.black,
        surface: _darkSurface,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: _textTheme(base.textTheme),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.w800),
      headlineSmall: base.headlineSmall?.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
      titleLarge: base.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: base.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge: base.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }

  static const Color cardDark = Color(0xFF1A1A1A);
  static const Color cardDark2 = Color(0xFF2A2A2A);
  static const Color mutedText = Color(0xFF9CA3AF);
  static const Color mutedText2 = Color(0xFF6B7280);
  static const Color accent = Color(0xFFD4AF37);
  static const Color green = Color(0xFF10B981);
  static const Color blue = Color(0xFF3B82F6);
  static const Color red = Color(0xFFEF4444);
}