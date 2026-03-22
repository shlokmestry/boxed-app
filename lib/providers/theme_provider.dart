import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';
  final _storage = const FlutterSecureStorage();
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeProvider() {
    _load();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _storage.write(key: _key, value: mode.name);
  }

  Future<void> _load() async {
    final stored = await _storage.read(key: _key);
    switch (stored) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'system':
        _themeMode = ThemeMode.system;
        break;
      default:
        _themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }
}