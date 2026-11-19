import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vehicle.dart';
import '../models/fuel_log.dart';

class CacheService {
  static const String _keyActiveVehicle = 'active_vehicle';
  static const String _keyVehicleIcons = 'vehicle_icons';
  static const String _keyVehicleColors = 'vehicle_colors';
  static const String _keyCachedVehicles = 'cached_vehicles';
  static const String _keyPrefixLogs = 'cached_logs_';

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

  // ── Cached Vehicles List ──

  static List<Vehicle> getCachedVehicles() {
    final raw = _prefs?.getString(_keyCachedVehicles);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => Vehicle.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCachedVehicles(List<Vehicle> list) async {
    try {
      final jsonList = list.map((v) => {
        'id': v.id,
        'user_id': v.userId,
        'name': v.name,
        'is_active': v.isActive,
        'icon_key': v.iconKey,
        'color_key': v.colorKey,
      }).toList();
      await _prefs?.setString(_keyCachedVehicles, jsonEncode(jsonList));
    } catch (_) {}
  }

  // ── Cached Fuel Logs ──

  static List<FuelLog> getCachedLogs(String vehicleId) {
    if (vehicleId.isEmpty) return [];
    final raw = _prefs?.getString('$_keyPrefixLogs$vehicleId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => FuelLog.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCachedLogs(String vehicleId, List<FuelLog> logs) async {
    if (vehicleId.isEmpty) return;
    try {
      final jsonList = logs.map((log) => log.toJson()).toList();
      await _prefs?.setString('$_keyPrefixLogs$vehicleId', jsonEncode(jsonList));
    } catch (_) {}
  }
}
