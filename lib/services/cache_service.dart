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
  static const String _keyHomeSummary = 'cached_home_summary_';
  static const String _keyFuelTypes = 'cached_fuel_types';
  static const String _keyFuelColors = 'cached_fuel_colors';
  static const String _keyFuelTypesMigratedV2 = 'fuel_types_migrated_v2_single';

  static const List<String> fuelColorPalette = [
    '#FF9800', // Amber / Orange
    '#E91E63', // Pink
    '#FF5252', // Red
    '#4CAF50', // Green
    '#2196F3', // Blue
    '#9C27B0', // Purple
    '#00BCD4', // Cyan
    '#FFEB3B', // Yellow
    '#607D8B', // Blue Grey
    '#795548', // Brown
  ];

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

  // ── Cached Home Screen Summary ──

  static Map<String, double> getCachedHomeSummary(String vehicleId) {
    if (vehicleId.isEmpty) return {'avgMileage': 0.0, 'totalDistance': 0.0};
    final raw = _prefs?.getString('$_keyHomeSummary$vehicleId');
    if (raw == null) return {'avgMileage': 0.0, 'totalDistance': 0.0};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        'avgMileage': (map['avgMileage'] as num?)?.toDouble() ?? 0.0,
        'totalDistance': (map['totalDistance'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (_) {
      return {'avgMileage': 0.0, 'totalDistance': 0.0};
    }
  }

  static Future<void> saveCachedHomeSummary(String vehicleId, double avgMileage, double totalDistance) async {
    if (vehicleId.isEmpty) return;
    try {
      await _prefs?.setString('$_keyHomeSummary$vehicleId', jsonEncode({
        'avgMileage': avgMileage,
        'totalDistance': totalDistance,
      }));
    } catch (_) {}
  }

  // ── Cached Fuel Types ──

  static List<String> getCachedFuelTypes() {
    // One-time migration to strictly single default fuel ("Standard petrol")
    final migratedFlag = _prefs?.getBool(_keyFuelTypesMigratedV2) ?? false;
    if (!migratedFlag) {
      _prefs?.setBool(_keyFuelTypesMigratedV2, true);
      final existing = _prefs?.getStringList(_keyFuelTypes);
      // If cached fuel types contain legacy multi-defaults (e.g. XP95 + XP100 + Unleaded), reset to strictly single default
      if (existing == null ||
          existing.isEmpty ||
          (existing.contains('XP95') && existing.contains('XP100') && existing.length >= 3)) {
        _prefs?.setStringList(_keyFuelTypes, ['Standard petrol']);
        return ['Standard petrol'];
      }
    }

    final list = _prefs?.getStringList(_keyFuelTypes);
    if (list != null && list.isNotEmpty) {
      // Migrate old "Standard / Unleaded" to "Standard petrol"
      final migrated = list.map((t) {
        if (t.toLowerCase().contains('unleaded') || t == 'Standard / Unleaded') {
          return 'Standard petrol';
        }
        return t;
      }).toSet().toList();
      return migrated;
    }
    // New user default: strictly ONE type "Standard petrol"
    return ['Standard petrol'];
  }

  static Future<void> saveCachedFuelTypes(List<String> types) async {
    await _prefs?.setStringList(_keyFuelTypes, types);
  }

  /// Clears user-specific session cache when signing out or switching accounts.
  static Future<void> clearUserCache() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.remove(_keyActiveVehicle);
      await prefs.remove(_keyCachedVehicles);
      await prefs.remove(_keyFuelColors);
      // Reset fuel types strictly to ['Standard petrol']
      await prefs.setStringList(_keyFuelTypes, ['Standard petrol']);
      await prefs.setBool(_keyFuelTypesMigratedV2, true);

      // Clean all vehicle logs and summary metrics
      final keys = List<String>.from(prefs.getKeys());
      for (final k in keys) {
        if (k.startsWith(_keyPrefixLogs) || k.startsWith(_keyHomeSummary)) {
          await prefs.remove(k);
        }
      }
    } catch (_) {}
  }

  // ── Cached Fuel Colors ──

  static String getFuelColorHex(String fuelName) {
    final clean = fuelName.toLowerCase().trim();
    final raw = _prefs?.getString(_keyFuelColors);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        if (map.containsKey(clean)) {
          return map[clean].toString();
        }
      } catch (_) {}
    }

    // Default color mappings matching the original Python app
    if (clean.contains('xp95')) return '#FF9800';
    if (clean.contains('xp100')) return '#E91E63';
    if (clean.contains('diesel')) return '#4CAF50';
    if (clean.contains('power')) return '#2196F3';
    if (clean.contains('unleaded') || clean.contains('standard') || clean.contains('petrol')) return '#FF5252';

    // Hash-based deterministic fallback from palette
    final hash = clean.codeUnits.fold(0, (acc, c) => acc + c);
    return fuelColorPalette[hash % fuelColorPalette.length];
  }

  static Future<void> setFuelColorHex(String fuelName, String hexColor) async {
    final clean = fuelName.toLowerCase().trim();
    final raw = _prefs?.getString(_keyFuelColors);
    Map<String, dynamic> map = {};
    if (raw != null) {
      try {
        map = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    map[clean] = hexColor;
    await _prefs?.setString(_keyFuelColors, jsonEncode(map));
  }
}
