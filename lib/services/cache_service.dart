import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vehicle.dart';
import '../models/fuel_log.dart';
import '../models/service_log.dart';
import '../models/user_entitlement.dart';
import '../models/app_update_config.dart';
import '../models/app_notification.dart';
import 'supabase_service.dart';

class CacheService {
  static const String _keyActiveVehicle = 'active_vehicle';
  static const String _keyVehicleIcons = 'vehicle_icons';
  static const String _keyVehicleColors = 'vehicle_colors';
  static const String _keyCachedVehicles = 'cached_vehicles';
  static const String _keyPrefixLogs = 'cached_logs_';
  static const String _keyPrefixServiceLogs = 'cached_service_logs_';
  static const String _keyHomeSummary = 'cached_home_summary_';
  static const String _keyFuelTypes = 'cached_fuel_types';
  static const String _keyFuelColors = 'cached_fuel_colors';
  static const String _keyEntitlement = 'cached_entitlement';
  static const String _keyUpdateConfig = 'cached_app_update_config';
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyNotificationsPrefix = 'cached_notifications_';
  static const String _keySeenAnnouncements = 'seen_announcement_ids';
  static const String _keyTriggeredAlertsPrefix = 'triggered_alerts_';
  static const String _keyWelcomeShownPrefix = 'welcome_notif_shown_';
  static const String _keyNotifPrefs = 'notification_preferences';

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

  static String? getSavedActiveVehicleOrNull() {
    final val = _prefs?.getString(_keyActiveVehicle);
    return (val != null && val.trim().isNotEmpty) ? val.trim() : null;
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

  static String _fuelTypesKey([String? userId]) {
    final uid = userId ?? SupabaseService.userId;
    return uid.isNotEmpty ? '${_keyFuelTypes}_$uid' : _keyFuelTypes;
  }

  static String _fuelColorsKey([String? userId]) {
    final uid = userId ?? SupabaseService.userId;
    return uid.isNotEmpty ? '${_keyFuelColors}_$uid' : _keyFuelColors;
  }

  static List<String> getCachedFuelTypes([String? userId]) {
    final key = _fuelTypesKey(userId);
    final list = _prefs?.getStringList(key);
    if (list != null && list.isNotEmpty) {
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

  static Future<void> saveCachedFuelTypes(List<String> types, [String? userId]) async {
    final key = _fuelTypesKey(userId);
    await _prefs?.setStringList(key, types);
  }

  /// Clears active vehicle session cache on sign out
  static Future<void> clearUserCache() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.remove(_keyActiveVehicle);
      await prefs.remove(_keyCachedVehicles);
    } catch (_) {}
  }

  // ── Cached User Entitlement (F7) ──

  static String _entitlementKey([String? userId]) {
    final uid = userId ?? SupabaseService.userId;
    return uid.isNotEmpty ? '${_keyEntitlement}_$uid' : _keyEntitlement;
  }

  static UserEntitlement? getCachedEntitlement([String? userId]) {
    final raw = _prefs?.getString(_entitlementKey(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserEntitlement.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCachedEntitlement(UserEntitlement entitlement, [String? userId]) async {
    try {
      await _prefs?.setString(_entitlementKey(userId), jsonEncode(entitlement.toJson()));
    } catch (_) {}
  }

  // ── Cached Update Config (F8) ──

  static AppUpdateConfig? getCachedUpdateConfig() {
    final raw = _prefs?.getString(_keyUpdateConfig);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppUpdateConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCachedUpdateConfig(AppUpdateConfig config) async {
    try {
      await _prefs?.setString(_keyUpdateConfig, jsonEncode(config.toJson()));
    } catch (_) {}
  }

  // ── Theme Preference (F2) ──

  static String getSavedThemeMode() {
    return _prefs?.getString(_keyThemeMode) ?? 'system';
  }

  static Future<void> saveThemeMode(String mode) async {
    await _prefs?.setString(_keyThemeMode, mode);
  }

  // ── Service Logs Cache (F5) ──

  static List<ServiceLog> getCachedServiceLogs(String vehicleId) {
    if (vehicleId.isEmpty) return [];
    final raw = _prefs?.getString('$_keyPrefixServiceLogs$vehicleId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ServiceLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCachedServiceLogs(
      String vehicleId, List<ServiceLog> logs) async {
    if (vehicleId.isEmpty) return;
    final list = logs.map((l) => l.toJson()).toList();
    await _prefs?.setString('$_keyPrefixServiceLogs$vehicleId', jsonEncode(list));
  }

  // ── Notifications & Announcements Cache (F6) ──

  static String _notifKey(String? userId) {
    final uid = (userId ?? SupabaseService.userId).trim();
    return uid.isEmpty
        ? '${_keyNotificationsPrefix}guest'
        : '$_keyNotificationsPrefix$uid';
  }

  static List<AppNotificationItem> getCachedNotifications([String? userId]) {
    final raw = _prefs?.getString(_notifKey(userId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final items = list
          .map((e) => AppNotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCachedNotifications(
      List<AppNotificationItem> items, [String? userId]) async {
    final trimmed = items.take(50).map((i) => i.toJson()).toList();
    await _prefs?.setString(_notifKey(userId), jsonEncode(trimmed));
  }

  static Set<String> getSeenAnnouncementIds() {
    final list = _prefs?.getStringList(_keySeenAnnouncements) ?? const [];
    return list.toSet();
  }

  static Future<void> markAnnouncementSeen(String announcementId) async {
    final clean = announcementId.trim();
    if (clean.isEmpty) return;
    final current = getSeenAnnouncementIds();
    if (current.add(clean)) {
      await _prefs?.setStringList(_keySeenAnnouncements, current.toList());
    }
  }

  static Set<String> getTriggeredAlertKeys([String? userId]) {
    final uid = (userId ?? SupabaseService.userId).trim();
    final key = uid.isEmpty
        ? '${_keyTriggeredAlertsPrefix}guest'
        : '$_keyTriggeredAlertsPrefix$uid';
    return (_prefs?.getStringList(key) ?? const []).toSet();
  }

  static Future<void> addTriggeredAlertKey(String alertKey, [String? userId]) async {
    final clean = alertKey.trim();
    if (clean.isEmpty) return;
    final uid = (userId ?? SupabaseService.userId).trim();
    final key = uid.isEmpty
        ? '${_keyTriggeredAlertsPrefix}guest'
        : '$_keyTriggeredAlertsPrefix$uid';
    final current = getTriggeredAlertKeys(userId);
    if (current.add(clean)) {
      final list = current.toList();
      if (list.length > 200) {
        list.removeRange(0, list.length - 200);
      }
      await _prefs?.setStringList(key, list);
    }
  }

  static bool wasWelcomeNotificationShown([String? userId]) {
    final uid = (userId ?? SupabaseService.userId).trim();
    if (uid.isEmpty) return true;
    return _prefs?.getBool('$_keyWelcomeShownPrefix$uid') ?? false;
  }

  static Future<void> markWelcomeNotificationShown([String? userId]) async {
    final uid = (userId ?? SupabaseService.userId).trim();
    if (uid.isEmpty) return;
    await _prefs?.setBool('$_keyWelcomeShownPrefix$uid', true);
  }

  static NotificationPreferences getNotificationPreferences() {
    final raw = _prefs?.getString(_keyNotifPrefs);
    if (raw == null || raw.isEmpty) return const NotificationPreferences();
    try {
      return NotificationPreferences.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const NotificationPreferences();
    }
  }

  static Future<void> saveNotificationPreferences(
      NotificationPreferences prefs) async {
    await _prefs?.setString(_keyNotifPrefs, jsonEncode(prefs.toJson()));
  }

  // ── Cached Fuel Colors ──

  static String getFuelColorHex(String fuelName, [String? userId]) {
    final clean = fuelName.toLowerCase().trim();
    final key = _fuelColorsKey(userId);
    final raw = _prefs?.getString(key);
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

  static Future<void> setFuelColorHex(String fuelName, String hexColor, [String? userId]) async {
    final clean = fuelName.toLowerCase().trim();
    final key = _fuelColorsKey(userId);
    final raw = _prefs?.getString(key);
    Map<String, dynamic> map = {};
    if (raw != null) {
      try {
        map = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    map[clean] = hexColor;
    await _prefs?.setString(key, jsonEncode(map));
  }
}
