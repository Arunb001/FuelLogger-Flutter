import 'package:flutter/foundation.dart';
import '../models/vehicle.dart';
import '../models/fuel_log.dart';
import '../models/fuel_card.dart';
import '../models/service_log.dart';
import '../models/telemetry_summary.dart';
import '../services/supabase_service.dart';
import '../services/telemetry_engine.dart';
import '../services/cache_service.dart';
import '../services/csv_service.dart';
import '../services/notification_service.dart';

class GarageProvider extends ChangeNotifier {
  List<Vehicle> _vehicles = [];
  Vehicle? _activeVehicle;
  List<FuelLog> _fuelLogs = [];
  List<ServiceLog> _serviceLogs = [];
  List<FuelCard> _fuelCards = [];
  TelemetrySummary _summary = TelemetrySummary.empty();
  ServiceSummary _serviceSummary = ServiceSummary.empty();
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
    _serviceLogs = [];
    _fuelCards = [];
    _summary = TelemetrySummary.empty();
    _serviceSummary = ServiceSummary.empty();
    _fuelTypes = CacheService.getCachedFuelTypes();
    _loadedUserId = null;
    _isLoading = false;
    notifyListeners();
  }

  Vehicle _resolveActiveVehicle(List<Vehicle> list, String? savedActiveName) {
    if (savedActiveName != null && savedActiveName.isNotEmpty) {
      for (final v in list) {
        if (v.name.toLowerCase() == savedActiveName.toLowerCase()) {
          return v;
        }
      }
    }
    for (final v in list) {
      if (v.isActive) return v;
    }
    return list.first;
  }

  void _initFromCache() {
    _fuelCards = CacheService.getCachedFuelCards()
        .map((c) => c.needsMonthlyReset()
            ? c.copyWith(limitUsed: 0.0, lastResetAt: DateTime.now())
            : c)
        .toList();
    final cached = CacheService.getCachedVehicles();
    if (cached.isNotEmpty) {
      _vehicles = cached;
      final savedActive = CacheService.getSavedActiveVehicleOrNull();
      _activeVehicle = _resolveActiveVehicle(_vehicles, savedActive);

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
        TelemetryEngine.sortDescending(sorted);
        _fuelLogs = sorted;
        _summary = TelemetryEngine.computeSummary(cachedLogs);
      }

      final cachedServices = CacheService.getCachedServiceLogs(_activeVehicle!.id);
      if (cachedServices.isNotEmpty) {
        _serviceLogs = _sortServiceLogsDesc(cachedServices);
        _serviceSummary = ServiceSummary.compute(
            _serviceLogs, _summary.latestOdometer);
      }
    }
    _fuelTypes = CacheService.getCachedFuelTypes();
  }

  List<ServiceLog> _sortServiceLogsDesc(List<ServiceLog> items) {
    final sorted = List<ServiceLog>.from(items);
    sorted.sort((a, b) {
      final d = b.serviceDate.compareTo(a.serviceDate);
      if (d != 0) return d;
      return b.odometer.compareTo(a.odometer);
    });
    return sorted;
  }

  List<Vehicle> get vehicles => _vehicles;
  Vehicle? get activeVehicle => _activeVehicle;
  String get activeVehicleName => _activeVehicle?.name ?? 'My Vehicle';
  List<FuelLog> get fuelLogs => _fuelLogs;
  List<ServiceLog> get serviceLogs => _serviceLogs;
  List<FuelCard> get fuelCards => _fuelCards;
  FuelCard? get primaryFuelCard {
    for (final c in _fuelCards) {
      if (c.isPrimary) return c;
    }
    return null;
  }

  FuelCard? fuelCardById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final c in _fuelCards) {
      if (c.id == id) return c;
    }
    return null;
  }

  TelemetrySummary get summary => _summary;
  ServiceSummary get serviceSummary => _serviceSummary;
  bool get isLoading => _isLoading;
  List<String> get fuelTypes => _fuelTypes;
  bool get canAddVehicle => true;

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
        final savedActiveName = CacheService.getSavedActiveVehicleOrNull();
        final resolved = _resolveActiveVehicle(cloudVehicles, savedActiveName);
        final bool dbNeedsSync = !resolved.isActive || cloudVehicles.where((v) => v.isActive).length != 1;
        _vehicles = cloudVehicles.map((v) => v.copyWith(isActive: v.id == resolved.id)).toList();
        _activeVehicle = _vehicles.firstWhere((v) => v.id == resolved.id, orElse: () => resolved);
        await CacheService.setActiveVehicle(_activeVehicle!.name);
        await CacheService.saveCachedVehicles(_vehicles);
        if (dbNeedsSync && _activeVehicle!.id.isNotEmpty) {
          SupabaseService.setActiveVehicle(_activeVehicle!.id);
        }
      } else if (_vehicles.isEmpty) {
        final def = Vehicle(
          id: 'local_primary',
          userId: SupabaseService.userId,
          name: 'My Vehicle',
          isActive: true,
          iconKey: 'bike',
          colorKey: 'red',
        );
        _vehicles = [def];
        _activeVehicle = def;
        await CacheService.saveCachedVehicles(_vehicles);
      }

      await _loadLogsForActiveVehicle();
      await _loadFuelCardsAndResetIfNeeded();
      NotificationService.syncRemoteAnnouncements();
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> switchVehicle(Vehicle v) async {
    _vehicles = _vehicles.map((item) => item.copyWith(isActive: item.id == v.id)).toList();
    _activeVehicle = v.copyWith(isActive: true);
    await CacheService.setActiveVehicle(v.name);
    await CacheService.saveCachedVehicles(_vehicles);
    SupabaseService.setActiveVehicle(v.id);

    // Instant 0ms switch using cached logs & service records
    final cachedLogs = CacheService.getCachedLogs(v.id);
    if (cachedLogs.isNotEmpty) {
      final sorted = List<FuelLog>.from(cachedLogs);
      TelemetryEngine.sortDescending(sorted);
      _fuelLogs = sorted;
      _summary = TelemetryEngine.computeSummary(cachedLogs);
    } else {
      _fuelLogs = [];
      _summary = TelemetrySummary.empty();
    }

    final cachedServices = CacheService.getCachedServiceLogs(v.id);
    if (cachedServices.isNotEmpty) {
      _serviceLogs = _sortServiceLogsDesc(cachedServices);
      _serviceSummary =
          ServiceSummary.compute(_serviceLogs, _summary.latestOdometer);
    } else {
      _serviceLogs = [];
      _serviceSummary = ServiceSummary.empty();
    }
    notifyListeners();

    // Revalidate with cloud
    await _loadLogsForActiveVehicle();
  }

  Future<void> _loadLogsForActiveVehicle() async {
    if (_activeVehicle == null) {
      _fuelLogs = [];
      _serviceLogs = [];
      _summary = TelemetrySummary.empty();
      _serviceSummary = ServiceSummary.empty();
      notifyListeners();
      return;
    }

    final vehicleId =
        _activeVehicle!.id.isNotEmpty ? _activeVehicle!.id : 'local_primary';
    final rawLogs = await SupabaseService.getFuelLogs(vehicleId);
    final rawServices = await SupabaseService.getServiceLogs(vehicleId);
    _serviceLogs = _sortServiceLogsDesc(rawServices);

    if (rawLogs.isEmpty) {
      _fuelLogs = [];
      _summary = TelemetrySummary.empty();
      _serviceSummary = ServiceSummary.compute(_serviceLogs, 0.0);
      CacheService.saveCachedHomeSummary(vehicleId, 0.0, 0.0);
      CacheService.saveCachedLogs(vehicleId, []);
      await syncFuelTypesWithCloudAndLogs([]);
      await NotificationService.evaluateTelemetryNotifications(
        vehicle: _activeVehicle!,
        fuelLogs: _fuelLogs,
        fuelSummary: _summary,
        serviceLogs: _serviceLogs,
        serviceSummary: _serviceSummary,
      );
      notifyListeners();
      return;
    }

    // Compute forward-linking cycle telemetry (to_odometer, fuel_consumed, distance, mileage)
    final recalculated = TelemetryEngine.recalculateCycles(rawLogs);
    _summary = TelemetryEngine.computeSummary(recalculated);
    _serviceSummary =
        ServiceSummary.compute(_serviceLogs, _summary.latestOdometer);

    // Synchronize user fuel types from cloud DB and actual logs
    await syncFuelTypesWithCloudAndLogs(rawLogs);

    // Save home screen summary cache
    CacheService.saveCachedHomeSummary(
        vehicleId, _summary.avgMileage, _summary.totalDistance);

    // Asynchronously sync to_odometer and recalculated fields back to Supabase DB
    SupabaseService.syncRecalculatedTelemetry(vehicleId, rawLogs, recalculated);

    // Sort reverse-chronological (latest run first)
    TelemetryEngine.sortDescending(recalculated);
    _fuelLogs = recalculated;

    await NotificationService.evaluateTelemetryNotifications(
      vehicle: _activeVehicle!,
      fuelLogs: _fuelLogs,
      fuelSummary: _summary,
      serviceLogs: _serviceLogs,
      serviceSummary: _serviceSummary,
    );
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
    await CacheService.migrateVehicleCustomization(oldName, clean);

    // Update in-memory state & save full vehicle list cache
    final idx = _vehicles.indexWhere((v) => v.id == vehicleId || v.name == oldName);
    final updated = _activeVehicle!.copyWith(name: clean);
    if (idx != -1) {
      _vehicles[idx] = updated;
    } else {
      _vehicles.add(updated);
    }
    _activeVehicle = updated;
    await CacheService.setActiveVehicle(clean);
    await CacheService.saveCachedVehicles(_vehicles);
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

  List<String> get stationSuggestions {
    const defaults = ['IndianOil', 'HPCL', 'BPCL', 'Shell', 'Jio-bp'];
    final seen = <String>{};
    final result = <String>[];
    for (final log in _fuelLogs) {
      final st = log.stationName?.trim();
      if (st != null && st.isNotEmpty && seen.add(st.toLowerCase())) {
        result.add(st);
      }
    }
    for (final d in defaults) {
      if (seen.add(d.toLowerCase())) {
        result.add(d);
      }
    }
    return result;
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
    String? stationName,
    String? remark,
    String? fuelCardId,
  }) async {
    if (_activeVehicle == null) return false;

    final vehicleId = _activeVehicle!.id.isNotEmpty ? _activeVehicle!.id : 'local_primary';

    final double cpl = litersToFill > 0 ? double.parse((fuelCost / litersToFill).toStringAsFixed(2)) : 0.0;
    final cleanStation = (stationName != null && stationName.trim().isNotEmpty) ? stationName.trim() : null;
    final cleanRemark = (remark != null && remark.trim().isNotEmpty) ? remark.trim() : null;
    final cleanCardId = (fuelCardId != null && fuelCardId.trim().isNotEmpty) ? fuelCardId.trim() : null;

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
      stationName: cleanStation,
      remark: cleanRemark,
      fuelCardId: cleanCardId,
    );

    final res = await SupabaseService.addFuelLog(log);
    if (res != null) {
      if (cleanCardId != null) {
        await _adjustFuelCardUsage(cleanCardId, fuelCost);
      }
      await _loadLogsForActiveVehicle();
      return true;
    }
    return false;
  }

  Future<bool> updateFuelLog(String id, Map<String, dynamic> data) async {
    final vehicleId = _activeVehicle?.id.isNotEmpty == true ? _activeVehicle!.id : 'local_primary';
    FuelLog? existing;
    for (final l in _fuelLogs) {
      if (l.id == id) {
        existing = l;
        break;
      }
    }

    final ok = await SupabaseService.updateFuelLog(id, vehicleId, data);
    if (ok) {
      if (existing != null) {
        final oldCardId = existing.fuelCardId;
        final oldCost = existing.fuelCost;
        final String? newCardId = data.containsKey('fuel_card_id')
            ? (data['fuel_card_id']?.toString().trim().isNotEmpty == true
                ? data['fuel_card_id'].toString().trim()
                : null)
            : oldCardId;
        final double newCost = data['fuel_cost'] != null
            ? (data['fuel_cost'] as num).toDouble()
            : oldCost;

        if (oldCardId == newCardId) {
          if (newCardId != null && (newCost - oldCost).abs() > 0.001) {
            await _adjustFuelCardUsage(newCardId, newCost - oldCost);
          }
        } else {
          if (oldCardId != null) {
            await _adjustFuelCardUsage(oldCardId, -oldCost);
          }
          if (newCardId != null) {
            await _adjustFuelCardUsage(newCardId, newCost);
          }
        }
      }
      await _loadLogsForActiveVehicle();
      return true;
    }
    return false;
  }

  Future<bool> deleteFuelLog(String id) async {
    final vehicleId = _activeVehicle?.id.isNotEmpty == true ? _activeVehicle!.id : 'local_primary';
    FuelLog? existing;
    for (final l in _fuelLogs) {
      if (l.id == id) {
        existing = l;
        break;
      }
    }

    final ok = await SupabaseService.deleteFuelLog(id, vehicleId);
    if (ok) {
      if (existing?.fuelCardId != null) {
        await _adjustFuelCardUsage(existing!.fuelCardId!, -existing.fuelCost);
      }
      await _loadLogsForActiveVehicle();
      return true;
    }
    return false;
  }

  // ── Fuel Cards & Monthly Reset (F9) ──

  Future<void> _loadFuelCardsAndResetIfNeeded() async {
    final fetched = await SupabaseService.getFuelCards();
    final List<FuelCard> resolved = [];
    for (final card in fetched) {
      if (card.needsMonthlyReset()) {
        final now = DateTime.now();
        final resetIso = now.toUtc().toIso8601String();
        await SupabaseService.updateFuelCard(card.id, {
          'limit_used': 0.0,
          'last_reset_at': resetIso,
        });
        resolved.add(card.copyWith(limitUsed: 0.0, lastResetAt: now));
      } else {
        resolved.add(card);
      }
    }
    _fuelCards = resolved;
    await CacheService.saveCachedFuelCards(_fuelCards);
  }

  Future<void> _adjustFuelCardUsage(String? cardId, double delta) async {
    if (cardId == null || cardId.isEmpty || delta.abs() <= 0.001) return;
    final idx = _fuelCards.indexWhere((c) => c.id == cardId);
    if (idx == -1) return;
    final card = _fuelCards[idx];
    final nextUsed = double.parse(
      (card.limitUsed + delta).clamp(0.0, double.infinity).toStringAsFixed(2),
    );
    _fuelCards[idx] = card.copyWith(limitUsed: nextUsed);
    await CacheService.saveCachedFuelCards(_fuelCards);
    await SupabaseService.updateFuelCard(cardId, {'limit_used': nextUsed});
    notifyListeners();
  }

  Future<bool> addFuelCard({
    required String cardName,
    required double cardLimit,
    double limitUsed = 0.0,
    int resetDayOfMonth = 1,
    bool isPrimary = false,
  }) async {
    final cleanName = cardName.trim();
    if (cleanName.isEmpty || cardLimit < 0) return false;

    final shouldBePrimary = _fuelCards.isEmpty ? true : isPrimary;
    final entry = FuelCard(
      id: '',
      userId: SupabaseService.userId,
      cardName: cleanName,
      cardLimit: cardLimit,
      limitUsed: limitUsed.clamp(0.0, double.infinity),
      isPrimary: shouldBePrimary,
      resetDayOfMonth: resetDayOfMonth.clamp(1, 31),
      lastResetAt: DateTime.now(),
    );

    final created = await SupabaseService.addFuelCard(entry);
    if (created != null) {
      await _loadFuelCardsAndResetIfNeeded();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> updateFuelCard(
    String id, {
    required String cardName,
    required double cardLimit,
    required double limitUsed,
    required int resetDayOfMonth,
    required bool isPrimary,
  }) async {
    final ok = await SupabaseService.updateFuelCard(id, {
      'card_name': cardName.trim(),
      'card_limit': cardLimit,
      'limit_used': limitUsed.clamp(0.0, double.infinity),
      'reset_day_of_month': resetDayOfMonth.clamp(1, 31),
    });
    if (!ok) return false;

    if (isPrimary) {
      await SupabaseService.setPrimaryFuelCard(id);
    }
    await _loadFuelCardsAndResetIfNeeded();
    notifyListeners();
    return true;
  }

  Future<bool> setPrimaryFuelCard(String id) async {
    final ok = await SupabaseService.setPrimaryFuelCard(id);
    if (ok) {
      _fuelCards = _fuelCards.map((c) => c.copyWith(isPrimary: c.id == id)).toList();
      await CacheService.saveCachedFuelCards(_fuelCards);
      notifyListeners();
    }
    return ok;
  }

  Future<bool> deleteFuelCard(String id) async {
    final wasPrimary = _fuelCards.any((c) => c.id == id && c.isPrimary);
    final ok = await SupabaseService.deleteFuelCard(id);
    if (ok) {
      _fuelCards.removeWhere((c) => c.id == id);
      if (wasPrimary && _fuelCards.isNotEmpty) {
        await setPrimaryFuelCard(_fuelCards.first.id);
      } else {
        await CacheService.saveCachedFuelCards(_fuelCards);
        notifyListeners();
      }
      return true;
    }
    return false;
  }

  // ── Service & Maintenance Logs (F5) ──

  Future<bool> addServiceLog({
    required String serviceDate,
    required double odometer,
    required String serviceType,
    String? serviceCenter,
    required double totalCost,
    double? nextDueKm,
    String? nextDueDate,
    String? notes,
  }) async {
    if (_activeVehicle == null) return false;
    final vehicleId =
        _activeVehicle!.id.isNotEmpty ? _activeVehicle!.id : 'local_primary';

    final entry = ServiceLog(
      id: '',
      userId: SupabaseService.userId,
      vehicleId: vehicleId,
      serviceDate: serviceDate,
      odometer: odometer,
      serviceType: serviceType.trim().isEmpty ? 'Periodic Service' : serviceType.trim(),
      serviceCenter: serviceCenter,
      totalCost: totalCost,
      nextDueKm: nextDueKm,
      nextDueDate: nextDueDate,
      notes: notes,
    );

    final created = await SupabaseService.addServiceLog(entry);
    if (created != null) {
      await _loadLogsForActiveVehicle();
      return true;
    }
    return false;
  }

  Future<bool> updateServiceLog(String id, Map<String, dynamic> data) async {
    final vehicleId = _activeVehicle?.id.isNotEmpty == true
        ? _activeVehicle!.id
        : 'local_primary';
    final ok = await SupabaseService.updateServiceLog(id, vehicleId, data);
    if (ok) {
      await _loadLogsForActiveVehicle();
      return true;
    }
    return false;
  }

  Future<bool> deleteServiceLog(String id) async {
    final vehicleId = _activeVehicle?.id.isNotEmpty == true
        ? _activeVehicle!.id
        : 'local_primary';
    final ok = await SupabaseService.deleteServiceLog(id, vehicleId);
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
