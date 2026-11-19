import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _keyActiveVehicle = 'active_vehicle';
  static const String _keyVehicleIcons = 'vehicle_icons';
  static const String _keyVehicleColors = 'vehicle_colors';
  static const String _keyCachedSummary = 'cached_summary';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static String getActiveVehicle({String defaultName = 'My Vehicle'}) {
    return _prefs?.getString(_keyActiveVehicle) ?? defaultName;
  }

  static Future<void> setActiveVehicle(String name) async {
    await _prefs?.setString(_keyActiveVehicle, name);
  }

  static String getVehicleIcon(String vehicleName) {
    final raw = _prefs?.getString(_keyVehicleIcons);
    if (raw == null) return 'bike';
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map[vehicleName] ?? 'bike';
    } catch (_) {
      return 'bike';
    }
  }

  static Future<void> setVehicleIcon(String vehicleName, String iconKey) async {
    final raw = _prefs?.getString(_keyVehicleIcons);
    Map<String, dynamic> map = {};
    if (raw != null) {
      try {
        map = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    map[vehicleName] = iconKey;
    await _prefs?.setString(_keyVehicleIcons, jsonEncode(map));
  }

  static String getVehicleColor(String vehicleName) {
    final raw = _prefs?.getString(_keyVehicleColors);
    if (raw == null) return 'red';
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map[vehicleName] ?? 'red';
    } catch (_) {
      return 'red';
    }
  }

  static Future<void> setVehicleColor(String vehicleName, String colorKey) async {
    final raw = _prefs?.getString(_keyVehicleColors);
    Map<String, dynamic> map = {};
    if (raw != null) {
      try {
        map = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    map[vehicleName] = colorKey;
    await _prefs?.setString(_keyVehicleColors, jsonEncode(map));
  }
}
