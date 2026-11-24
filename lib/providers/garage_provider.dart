import 'package:flutter/foundation.dart';
import '../models/vehicle.dart';
import '../models/fuel_log.dart';
import '../models/telemetry_summary.dart';
import '../services/supabase_service.dart';
import '../services/telemetry_engine.dart';
import '../services/cache_service.dart';
import '../services/csv_service.dart';

class GarageProvider extends ChangeNotifier {
  List<Vehicle> _vehicles = [];
  Vehicle? _activeVehicle;
  List<FuelLog> _fuelLogs = [];
  TelemetrySummary _summary = TelemetrySummary.empty();
  bool _isLoading = false;
  String? _loadedUserId;

  List<String> _fuelTypes = CacheService.getCachedFuelTypes();

  GarageProvider() {
    _initFromCache();
  }

  /// Resets in-memory garage and fuel types when signing out or switching accounts
  void resetOnSignOut() {
    _vehicles = [];
    _activeVehicle = null;
    _fuelLogs = [];
    _summary = TelemetrySummary.empty();
    _fuelTypes = CacheService.getCachedFuelTypes();
    _loadedUserId = null;
    _isLoading = false;
    notifyListeners();
  }

  void _initFromCache() {
    final cached = CacheService.getCachedVehicles();
    if (cached.isNotEmpty) {
      _vehicles = cached;
      final savedActive = CacheService.getActiveVehicle();
      _activeVehicle = _vehicles.firstWhere(
        (v) => v.name.toLowerCase() == savedActive.toLowerCase(),
        orElse: () => _vehicles.first,
      );

      // 1. Immediately restore Home Screen metrics from dedicated summary cache
      final homeSummary = CacheService.getCachedHomeSummary(_activeVehicle!.id);
      _summary = TelemetrySummary(
        totalDistance: homeSummary['totalDistance'] ?? 0.0,
        avgMileage: homeSummary['avgMileage'] ?? 0.0,
        totalFuelCost: 0.0,
        totalLiters: 0.0,
        bestMileage: 0.0,
        lowestMileage: 0.0,
        latestAvgMileage: 0.0,
        latestDistance: 0.0,
        latestOdometer: 0.0,
        nextSno: 1,
        lastSno: 1,
        isCycleOpen: false,
        byFuelType: {},
      );

      final cachedLogs = CacheService.getCachedLogs(_activeVehicle!.id);
      if (cachedLogs.isNotEmpty) {
        final sorted = List<FuelLog>.from(cachedLogs);
        sorted.sort((a, b) {
          final rCmp = b.runId.compareTo(a.runId);
          if (rCmp != 0) return rCmp;
          if (a.createdAt != null && b.createdAt != null) {
            final tCmp = b.createdAt!.compareTo(a.createdAt!);
            if (tCmp != 0) return tCmp;
          }
          if (!b.isPartial && a.isPartial) return 1;
          if (b.isPartial && !a.isPartial) return -1;
          return b.date.compareTo(a.date);
        });
        _fuelLogs = sorted;
        _summary = TelemetryEngine.computeSummary(cachedLogs);
      }
    }
    _fuelTypes = CacheService.getCachedFuelTypes();
  }

  List<Vehicle> get vehicles => _vehicles;
  Vehicle? get activeVehicle => _activeVehicle;
  String get activeVehicleName => _activeVehicle?.name ?? 'My Vehicle';
  List<FuelLog> get fuelLogs => _fuelLogs;
  TelemetrySummary get summary => _summary;
  bool get isLoading => _isLoading;
  List<String> get fuelTypes => _fuelTypes;

  Future<void> loadGarage() async {
    final currentUid = SupabaseService.userId;
    if (_loadedUserId != null && _loadedUserId != currentUid) {
      resetOnSignOut();
    }
    _loadedUserId = currentUid;

    // Refresh fuel types from cache
    _fuelTypes = CacheService.getCachedFuelTypes();

    // Only show loading indicator if we don't already have cached vehicles
    if (_vehicles.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final cloudVehicles = await SupabaseService.getVehicles();

      if (cloudVehicles.isNotEmpty) {
        _vehicles = cloudVehicles;
        final savedActiveName = CacheService.getActiveVehicle();
        _activeVehicle = _vehicles.firstWhere(
          (v) => v.name.toLowerCase() == savedActiveName.toLowerCase(),
          orElse: () => _vehicles.first,
        );
      } else if (_vehicles.isEmpty) {
        final def = Vehicle(
          id: 'local_primary',
          userId: SupabaseService.userId,
          name: 'My Vehicle',
          iconKey: 'bike',
          colorKey: 'red',
        );
        _vehicles = [def];
        _activeVehicle = def;
        await CacheService.saveCachedVehicles(_vehicles);
      }

      await _loadLogsForActiveVehicle();
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> switchVehicle(Vehicle v) async {
    _activeVehicle = v;
    await CacheService.setActiveVehicle(v.name);

    // Instant 0ms switch using cached logs
    final cachedLogs = CacheService.getCachedLogs(v.id);
    if (cachedLogs.isNotEmpty) {
      final sorted = List<FuelLog>.from(cachedLogs);
      sorted.sort((a, b) {
        final rCmp = b.runId.compareTo(a.runId);
        if (rCmp != 0) return rCmp;
        if (a.createdAt != null && b.createdAt != null) {
          final tCmp = b.createdAt!.compareTo(a.createdAt!);
          if (tCmp != 0) return tCmp;
        }
        if (!b.isPartial && a.isPartial) return 1;
        if (b.isPartial && !a.isPartial) return -1;
        return b.date.compareTo(a.date);
      });
      _fuelLogs = sorted;
      _summary = TelemetryEngine.computeSummary(cachedLogs);
    } else {
      _fuelLogs = [];
      _summary = TelemetrySummary.empty();
    }
    notifyListeners();

    // Revalidate with cloud
    await _loadLogsForActiveVehicle();
  }

  Future<void> _loadLogsForActiveVehicle() async {
    if (_activeVehicle == null) {
      _fuelLogs = [];
      _summary = TelemetrySummary.empty();
      notifyListeners();
      return;
    }

    final vehicleId = _activeVehicle!.id.isNotEmpty ? _activeVehicle!.id : 'local_primary';
    final rawLogs = await SupabaseService.getFuelLogs(vehicleId);

    if (rawLogs.isEmpty) {
      _fuelLogs = [];
      _summary = TelemetrySummary.empty();
      CacheService.saveCachedHomeSummary(vehicleId, 0.0, 0.0);
      CacheService.saveCachedLogs(vehicleId, []);
      await syncFuelTypesWithCloudAndLogs([]);
      notifyListeners();
      return;
    }

    // Compute forward-linking cycle telemetry (to_odometer, fuel_consumed, distance, mileage)
    final recalculated = TelemetryEngine.recalculateCycles(rawLogs);
    _summary = TelemetryEngine.computeSummary(recalculated);

    // Synchronize user fuel types from cloud DB and actual logs
    await syncFuelTypesWithCloudAndLogs(rawLogs);

    // Save home screen summary cache
    CacheService.saveCachedHomeSummary(vehicleId, _summary.avgMileage, _summary.totalDistance);

    // Asynchronously sync to_odometer and recalculated fields back to Supabase DB
    SupabaseService.syncRecalculatedTelemetry(vehicleId, rawLogs, recalculated);

    // Sort reverse-chronological (latest run first)
    recalculated.sort((a, b) {
      // 1. Primary: latest runId first (descending)
      final rCmp = b.runId.compareTo(a.runId);
      if (rCmp != 0) return rCmp;

      // 2. Secondary: latest createdAt timestamp first (descending)
      if (a.createdAt != null && b.createdAt != null) {
        final tCmp = b.createdAt!.compareTo(a.createdAt!);
        if (tCmp != 0) return tCmp;
      }

      // 3. Tertiary: Full tank fill ('F') closes the cycle, so in reverse-chronology,
      // the Full fill must appear on TOP of earlier partial fill(s) ('P')!
      if (!b.isPartial && a.isPartial) return 1;
      if (b.isPartial && !a.isPartial) return -1;

      // 4. Quaternary: latest date first (descending)
      return b.date.compareTo(a.date);
    });
    _fuelLogs = recalculated;
    notifyListeners();
  }

  Future<bool> addVehicle(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return false;

    final created = await SupabaseService.addVehicle(clean);
    if (created != null) {
      final exists = _vehicles.any((v) => v.id == created.id);
      if (!exists) {
        _vehicles.add(created);
      }
      await switchVehicle(created);
      return true;
    }
    return false;
  }

  Future<bool> renameActiveVehicle(String newName) async {
    final clean = newName.trim();
    if (_activeVehicle == null || clean.isEmpty) return false;

    final oldName = _activeVehicle!.name;
    final vehicleId = _activeVehicle!.id.isNotEmpty ? _activeVehicle!.id : 'local_primary';

    // Update in Supabase / Cache service
    await SupabaseService.renameVehicle(vehicleId, clean);

    // Update in-memory state
    final idx = _vehicles.indexWhere((v) => v.id == vehicleId || v.name == oldName);
    final updated = _activeVehicle!.copyWith(name: clean);
    if (idx != -1) {
      _vehicles[idx] = updated;
    } else {
      _vehicles.add(updated);
    }
    _activeVehicle = updated;
    await CacheService.setActiveVehicle(clean);
    notifyListeners();
    return true;
  }

  Future<void> updateCustomization({String? iconKey, String? colorKey}) async {
    if (_activeVehicle == null) return;
    if (iconKey != null) {
      await CacheService.setVehicleIcon(_activeVehicle!.name, iconKey);
      _activeVehicle = _activeVehicle!.copyWith(iconKey: iconKey);
    }
    if (colorKey != null) {
      await CacheService.setVehicleColor(_activeVehicle!.name, colorKey);
      _activeVehicle = _activeVehicle!.copyWith(colorKey: colorKey);
    }
    final idx = _vehicles.indexWhere((v) => v.id == _activeVehicle!.id);
    if (idx != -1) {
      _vehicles[idx] = _activeVehicle!;
    }
    await CacheService.saveCachedVehicles(_vehicles);
    notifyListeners();
  }

  Future<bool> deleteVehicle(Vehicle v) async {
    if (_vehicles.length <= 1) return false; // Safeguard: keep at least 1 vehicle

    final ok = await SupabaseService.deleteVehicle(v.id);
    if (ok) {
      _vehicles.removeWhere((x) => x.id == v.id);
      if (_activeVehicle?.id == v.id) {
        await switchVehicle(_vehicles.first);
      } else {
        notifyListeners();
      }
      return true;
    }
    return false;
  }

  Future<bool> addFuelLog({
    required int runId,
    required String date,
    required String fuelType,
    required double fuelCost,
    required double litersToFill,
    required double fromOdometer,
    double fuelDensity = 0.0,
    String fuelFillFlag = 'F',
  }) async {
    if (_activeVehicle == null) return false;

    final vehicleId = _activeVehicle!.id.isNotEmpty ? _activeVehicle!.id : 'local_primary';

    final double cpl = litersToFill > 0 ? double.parse((fuelCost / litersToFill).toStringAsFixed(2)) : 0.0;

    final log = FuelLog(
      id: '',
      userId: SupabaseService.userId,
      vehicleId: vehicleId,
      runId: runId,
      date: date,
      fuelType: fuelType,
      fuelDensity: fuelDensity,
      fuelCost: fuelCost,
      litersToFill: litersToFill,
      costPerLtr: cpl,
      fromOdometer: fromOdometer,
      toOdometer: 0.0,
      distanceTraveled: 0.0,
      fuelConsumed: 0.0,
      calculatedMileage: 0.0,
      costPerKm: 0.0,
      fuelFillFlag: fuelFillFlag,
    );

    final res = await SupabaseService.addFuelLog(log);
    if (res != null) {
      await _loadLogsForActiveVehicle();
      return true;
    }
    return false;
  }

  Future<bool> updateFuelLog(String id, Map<String, dynamic> data) async {
    final vehicleId = _activeVehicle?.id.isNotEmpty == true ? _activeVehicle!.id : 'local_primary';
    final ok = await SupabaseService.updateFuelLog(id, vehicleId, data);
    if (ok) {
      await _loadLogsForActiveVehicle();
      return true;
    }
    return false;
  }

  Future<bool> deleteFuelLog(String id) async {
    final vehicleId = _activeVehicle?.id.isNotEmpty == true ? _activeVehicle!.id : 'local_primary';
    final ok = await SupabaseService.deleteFuelLog(id, vehicleId);
    if (ok) {
      await _loadLogsForActiveVehicle();
      return true;
    }
    return false;
  }

  Future<int> importFuelLogsFromCsv(String csvText, {bool replaceExisting = false}) async {
    if (_activeVehicle == null) return 0;
    final vehicleId = _activeVehicle!.id.isNotEmpty ? _activeVehicle!.id : 'local_primary';

    final parsed = CsvService.parseCsv(
      csvText,
      userId: SupabaseService.userId,
      vehicleId: vehicleId,
      startRunId: replaceExisting ? 1 : (_summary.nextSno),
    );

    if (parsed.isEmpty) return 0;

    await SupabaseService.bulkInsertFuelLogs(
      vehicleId,
      parsed,
      replaceExisting: replaceExisting,
    );

    await _loadLogsForActiveVehicle();
    return parsed.length;
  }

  String exportFuelLogsToCsv() {
    return CsvService.exportLogsToCsv(_fuelLogs);
  }

  /// Synchronizes active fuel types and user-defined colors between Supabase DB, local cache, and vehicle logs.
  Future<void> syncFuelTypesWithCloudAndLogs(List<FuelLog> logs) async {
    final uid = SupabaseService.userId;

    // 1. Fetch from cloud database (Supabase fuel_types table)
    final cloudTypes = await SupabaseService.getCloudFuelTypes();

    // Check if cloud entries are the legacy trigger defaults:
    // (In earlier Supabase setup, trigger on_auth_user_created automatically inserted XP95, XP100, Unleaded, Power)
    final legacyTriggerNames = {'xp95', 'xp100', 'unleaded', 'power'};
    final cloudNamesLower = cloudTypes.map((c) => c['name']!.toLowerCase().trim()).toSet();
    final bool isLegacyTriggerDefault = logs.isEmpty &&
        ((cloudNamesLower.length == 4 && cloudNamesLower.containsAll(legacyTriggerNames)) ||
         (cloudNamesLower.contains('unleaded') && cloudNamesLower.contains('power') && cloudNamesLower.length >= 3));

    if (isLegacyTriggerDefault) {
      // Clean legacy trigger fuel types out of the cloud DB for this new user
      for (final item in cloudTypes) {
        await SupabaseService.deleteCloudFuelType(item['name']!);
      }
      cloudTypes.clear();
    }

    final List<String> result = [];
    if (cloudTypes.isNotEmpty) {
      for (final item in cloudTypes) {
        final rawName = item['name']!;
        final color = item['color']!;
        final name = (rawName == 'Standard / Unleaded') ? 'Standard petrol' : rawName;
        if (!result.contains(name)) {
          result.add(name);
        }
        await CacheService.setFuelColorHex(name, color, uid);
      }
    } else {
      // Fallback to local user-scoped cache
      final cached = CacheService.getCachedFuelTypes(uid);
      for (final c in cached) {
        final name = (c == 'Standard / Unleaded') ? 'Standard petrol' : c;
        if (!result.contains(name)) {
          result.add(name);
        }
      }
    }

    // 2. Self-heal from user's actual fuel logs:
    // If the user's logs contain fuel types (e.g. 'XP95', 'XP100', 'Standard petrol'),
    // EVERY fuel type in their logs must be available in their active fuel types list!
    final logFuelTypes = logs.map((l) => l.fuelType.trim()).where((t) => t.isNotEmpty).toSet();
    for (final lt in logFuelTypes) {
      final name = (lt == 'Standard / Unleaded') ? 'Standard petrol' : lt;
      if (!result.contains(name)) {
        result.add(name);
        final cHex = CacheService.getFuelColorHex(name, uid);
        await SupabaseService.addCloudFuelType(name, cHex);
        await CacheService.setFuelColorHex(name, cHex, uid);
      }
    }

    // 3. For a brand new user (0 cloud entries, 0 logs, empty list):
    // Strictly ONE default fuel: "Standard petrol"
    if (result.isEmpty) {
      result.add('Standard petrol');
      await SupabaseService.addCloudFuelType('Standard petrol', '#FF5252');
      await CacheService.setFuelColorHex('Standard petrol', '#FF5252', uid);
    }

    _fuelTypes = result;
    await CacheService.saveCachedFuelTypes(_fuelTypes, uid);
    notifyListeners();
  }

  void addCustomFuelType(String name) {
    final clean = name.trim();
    if (clean.isNotEmpty && !_fuelTypes.contains(clean)) {
      _fuelTypes.insert(0, clean);
      final uid = SupabaseService.userId;
      final colorHex = CacheService.getFuelColorHex(clean, uid);
      CacheService.saveCachedFuelTypes(_fuelTypes, uid);
      SupabaseService.addCloudFuelType(clean, colorHex);
      notifyListeners();
    }
  }

  void removeCustomFuelType(String name) {
    if (_fuelTypes.length > 1) {
      _fuelTypes.remove(name);
      final uid = SupabaseService.userId;
      CacheService.saveCachedFuelTypes(_fuelTypes, uid);
      SupabaseService.deleteCloudFuelType(name);
      notifyListeners();
    }
  }

  Future<void> updateFuelTypeColor(String name, String hexColor) async {
    final uid = SupabaseService.userId;
    await CacheService.setFuelColorHex(name, hexColor, uid);
    await SupabaseService.updateCloudFuelTypeColor(name, hexColor);
    notifyListeners();
  }
}
