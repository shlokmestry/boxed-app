import 'package:flutter/material.dart';

class AppTheme {
  // Dark colors
  static const Color darkBg = Color(0xFF0A0A0A);
  static const Color darkSurface = Color(0xFF111111);
  static const Color darkSurface2 = Color(0xFF1A1A1A);

  // Light colors
  static const Color lightBg = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFEEEEEE);

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        onPrimary: Colors.black,
        surface: darkSurface,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: _textTheme(isDark: true),
    );
  }

  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: Colors.black,
        onPrimary: Colors.white,
        surface: lightSurface,
        onSurface: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: _textTheme(isDark: false),
    );
  }

  static TextTheme _textTheme({required bool isDark}) {
    final base = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final color = isDark ? Colors.white : Colors.black;
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
          fontSize: 28, fontWeight: FontWeight.w800, color: color),
      headlineSmall: base.headlineSmall?.copyWith(
          fontSize: 22, fontWeight: FontWeight.w800, color: color),
      titleLarge: base.titleLarge?.copyWith(
          fontSize: 18, fontWeight: FontWeight.w700, color: color),
      titleMedium: base.titleMedium?.copyWith(
          fontSize: 16, fontWeight: FontWeight.w600, color: color),
      bodyLarge: base.bodyLarge?.copyWith(
          fontSize: 16, fontWeight: FontWeight.w500, color: color),
      bodyMedium: base.bodyMedium?.copyWith(
          fontSize: 14, fontWeight: FontWeight.w400, color: color),
      bodySmall: base.bodySmall?.copyWith(
          fontSize: 12, fontWeight: FontWeight.w400, color: color),
      labelLarge: base.labelLarge?.copyWith(
          fontSize: 15, fontWeight: FontWeight.w700, color: color),
    );
  }

  // Static color constants used across the app
  static const Color cardDark = Color(0xFF111111);
  static const Color cardDark2 = Color(0xFF1A1A1A);
  static const Color mutedText = Color(0xFF9CA3AF);
  static const Color mutedText2 = Color(0xFF6B7280);
  static const Color accent = Color(0xFFD4AF37);
  static const Color green = Color(0xFF10B981);
  static const Color blue = Color(0xFF3B82F6);
  static const Color red = Color(0xFFEF4444);
}