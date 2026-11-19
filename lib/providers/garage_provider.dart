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

  List<String> _fuelTypes = ['XP95', 'XP100', 'Standard / Unleaded', 'Power 100', 'Diesel'];

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

      final savedActiveName = CacheService.getActiveVehicle();
      if (_vehicles.isNotEmpty) {
        _activeVehicle = _vehicles.firstWhere(
          (v) => v.name.toLowerCase() == savedActiveName.toLowerCase(),
          orElse: () => _vehicles.first,
        );
      } else {
        _activeVehicle = Vehicle(id: '', userId: '', name: 'My Vehicle');
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
    notifyListeners();
    await _loadLogsForActiveVehicle();
  }

  Future<void> _loadLogsForActiveVehicle() async {
    if (_activeVehicle == null || _activeVehicle!.id.isEmpty) {
      _fuelLogs = [];
      _summary = TelemetrySummary.empty();
      notifyListeners();
      return;
    }

    _fuelLogs = await SupabaseService.getFuelLogs(_activeVehicle!.id);
    _summary = TelemetryEngine.computeSummary(_fuelLogs);
    notifyListeners();
  }

  Future<bool> addVehicle(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return false;

    final created = await SupabaseService.addVehicle(clean);
    if (created != null) {
      _vehicles.add(created);
      await switchVehicle(created);
      return true;
    }
    return false;
  }

  Future<bool> renameActiveVehicle(String newName) async {
    if (_activeVehicle == null || newName.trim().isEmpty) return false;

    final ok = await SupabaseService.renameVehicle(_activeVehicle!.id, newName.trim());
    if (ok) {
      final idx = _vehicles.indexWhere((v) => v.id == _activeVehicle!.id);
      if (idx != -1) {
        _vehicles[idx] = _vehicles[idx].copyWith(name: newName.trim());
        _activeVehicle = _vehicles[idx];
        await CacheService.setActiveVehicle(newName.trim());
        notifyListeners();
      }
      return true;
    }
    return false;
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
    notifyListeners();
  }

  Future<bool> deleteVehicle(Vehicle v) async {
    if (_vehicles.length <= 1) return false; // Prevent deleting last vehicle

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
    if (_activeVehicle == null || _activeVehicle!.id.isEmpty) return false;

    // Derived quick pre-calc
    final double cpl = litersToFill > 0 ? double.parse((fuelCost / litersToFill).toStringAsFixed(2)) : 0.0;
    final int prevOdo = _summary.latestOdometer;
    final double dist = (fromOdometer > prevOdo && fuelFillFlag == 'F') ? (fromOdometer - prevOdo).toDouble() : 0.0;
    final double mileage = (dist > 0 && litersToFill > 0) ? double.parse((dist / litersToFill).toStringAsFixed(2)) : 0.0;
    final double cpk = (dist > 0 && fuelCost > 0) ? double.parse((fuelCost / dist).toStringAsFixed(2)) : 0.0;

    final log = FuelLog(
      id: '',
      userId: SupabaseService.userId,
      vehicleId: _activeVehicle!.id,
      runId: runId,
      date: date,
      fuelType: fuelType,
      fuelDensity: fuelDensity,
      fuelCost: fuelCost,
      litersToFill: litersToFill,
      costPerLtr: cpl,
      fromOdometer: prevOdo > 0 ? prevOdo : fromOdometer,
      toOdometer: fromOdometer,
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
    final ok = await SupabaseService.updateFuelLog(id, data);
    if (ok) {
      await _loadLogsForActiveVehicle();
      return true;
    }
    return false;
  }

  Future<bool> deleteFuelLog(String id) async {
    final ok = await SupabaseService.deleteFuelLog(id);
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
      notifyListeners();
    }
  }
}
