import 'package:flutter/foundation.dart';
import '../models/vehicle.dart';
import '../models/fuel_log.dart';
import '../models/telemetry_summary.dart';
import '../services/supabase_service.dart';
import '../services/telemetry_engine.dart';
import '../services/cache_service.dart';

class GarageProvider extends ChangeNotifier {
  List<Vehicle> _vehicles = [];
  Vehicle? _activeVehicle;
  List<FuelLog> _fuelLogs = [];
  TelemetrySummary _summary = TelemetrySummary.empty();
  bool _isLoading = false;

  List<String> _fuelTypes = CacheService.getCachedFuelTypes();

  List<Vehicle> get vehicles => _vehicles;
  Vehicle? get activeVehicle => _activeVehicle;
  String get activeVehicleName => _activeVehicle?.name ?? 'My Vehicle';
  List<FuelLog> get fuelLogs => _fuelLogs;
  TelemetrySummary get summary => _summary;
  bool get isLoading => _isLoading;
  List<String> get fuelTypes => _fuelTypes;

  Future<void> loadGarage() async {
    _isLoading = true;
    notifyListeners();

    try {
      _vehicles = await SupabaseService.getVehicles();

      if (_vehicles.isEmpty) {
        final def = Vehicle(
          id: 'local_primary',
          userId: SupabaseService.userId,
          name: 'My Vehicle',
          iconKey: 'bike',
          colorKey: 'red',
        );
        _vehicles = [def];
        await CacheService.saveCachedVehicles(_vehicles);
      }

      final savedActiveName = CacheService.getActiveVehicle();
      _activeVehicle = _vehicles.firstWhere(
        (v) => v.name.toLowerCase() == savedActiveName.toLowerCase(),
        orElse: () => _vehicles.first,
      );

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
    notifyListeners();
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
    _summary = TelemetryEngine.computeSummary(rawLogs);

    // Compute cycle telemetry in-memory and sort reverse-chronological (latest run first)
    final recalculated = TelemetryEngine.recalculateCycles(rawLogs);
    recalculated.sort((a, b) {
      final rCmp = b.runId.compareTo(a.runId);
      if (rCmp != 0) return rCmp;
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
    required int fromOdometer,
    double fuelDensity = 0.0,
    String fuelFillFlag = 'F',
  }) async {
    if (_activeVehicle == null) return false;

    final vehicleId = _activeVehicle!.id.isNotEmpty ? _activeVehicle!.id : 'local_primary';

    // Derived quick pre-calc
    final double cpl = litersToFill > 0 ? double.parse((fuelCost / litersToFill).toStringAsFixed(2)) : 0.0;
    final int prevOdo = _summary.latestOdometer;
    final double dist = (fromOdometer > prevOdo && fuelFillFlag == 'F') ? (fromOdometer - prevOdo).toDouble() : 0.0;
    final double mileage = (dist > 0 && litersToFill > 0) ? double.parse((dist / litersToFill).toStringAsFixed(2)) : 0.0;
    final double cpk = (dist > 0 && fuelCost > 0) ? double.parse((fuelCost / dist).toStringAsFixed(2)) : 0.0;

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
      toOdometer: 0,
      distanceTraveled: dist,
      fuelConsumed: litersToFill,
      calculatedMileage: mileage,
      costPerKm: cpk,
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

  void addCustomFuelType(String name) {
    final clean = name.trim();
    if (clean.isNotEmpty && !_fuelTypes.contains(clean)) {
      _fuelTypes.insert(0, clean);
      CacheService.saveCachedFuelTypes(_fuelTypes);
      notifyListeners();
    }
  }

  void removeCustomFuelType(String name) {
    if (_fuelTypes.length > 1) {
      _fuelTypes.remove(name);
      CacheService.saveCachedFuelTypes(_fuelTypes);
      notifyListeners();
    }
  }
}
