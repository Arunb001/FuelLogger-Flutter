import 'package:flutter/material.dart';
import '../services/cache_service.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = _parseMode(CacheService.getSavedThemeMode());

  ThemeMode get themeMode => _themeMode;

  String get modeKey {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  String get modeLabel {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await CacheService.saveThemeMode(modeKey);
    notifyListeners();
  }

  static ThemeMode _parseMode(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
