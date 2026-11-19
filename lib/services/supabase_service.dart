import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/vehicle.dart';
import '../models/fuel_log.dart';
import 'cache_service.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;
  static Session? get currentSession => client.auth.currentSession;
  static bool get hasValidSession => currentSession != null;
  static bool get isAuthenticated => currentUser != null && hasValidSession;
  static String get userEmail => currentUser?.email ?? 'guest@fuellogger.app';
  static String get userId => currentUser?.id ?? '';

  // ── Authentication ──

  static Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  static Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    return await client.auth.signUp(
      email: email.trim(),
      password: password.trim(),
    );
  }

  static Future<AuthResponse?> signInWithGoogleNative() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return null; // User cancelled the sign-in sheet
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken != null) {
        return await client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
      } else {
        // Fallback to web OAuth if idToken is not returned by the platform
        await client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'fuellogger://auth',
        );
        return null;
      }
    } catch (_) {
      rethrow;
    }
  }

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'fuellogger://auth',
    );
  }

  static Future<UserResponse> updatePassword(String newPassword) async {
    return await client.auth.updateUser(
      UserAttributes(password: newPassword.trim()),
    );
  }

  static Future<void> signOut() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (_) {}
    await client.auth.signOut();
  }

  // ── Vehicles CRUD ──

  static Future<List<Vehicle>> getVehicles() async {
    // 1. Try fetching from Supabase if authenticated with valid session
    if (isAuthenticated) {
      try {
        final res = await client
            .from('vehicles')
            .select()
            .order('created_at', ascending: true);

        final List<Vehicle> vehicles = (res as List).map((x) {
          final v = Vehicle.fromJson(x);
          final icon = CacheService.getVehicleIcon(v.name);
          final color = CacheService.getVehicleColor(v.name);
          return v.copyWith(iconKey: icon, colorKey: color);
        }).toList();

        if (vehicles.isNotEmpty) {
          await CacheService.saveCachedVehicles(vehicles);
          return vehicles;
        }

        // If user has 0 vehicles in cloud, auto-provision initial vehicle
        final initial = await addVehicle('My Vehicle');
        if (initial != null) {
          return [initial];
        }
      } catch (_) {}
    }

    // 2. Fallback to locally cached vehicles
    final cached = CacheService.getCachedVehicles();
    if (cached.isNotEmpty) {
      return cached;
    }

    // 3. Fallback: create default initial vehicle and cache it
    final defaultVehicle = Vehicle(
      id: 'local_primary',
      userId: userId,
      name: 'My Vehicle',
      iconKey: 'bike',
      colorKey: 'red',
    );
    await CacheService.saveCachedVehicles([defaultVehicle]);
    return [defaultVehicle];
  }

  static Future<Vehicle?> addVehicle(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return null;

    if (isAuthenticated) {
      try {
        final res = await client.from('vehicles').insert({
          'user_id': userId,
          'name': cleanName,
          'is_active': false,
        }).select().single();
        final v = Vehicle.fromJson(res);
        final cached = CacheService.getCachedVehicles();
        cached.add(v);
        await CacheService.saveCachedVehicles(cached);
        return v;
      } catch (_) {}
    }

    // Offline / Guest / Local fallback
    final localVehicle = Vehicle(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      name: cleanName,
      iconKey: 'bike',
      colorKey: 'red',
    );
    final cached = CacheService.getCachedVehicles();
    cached.add(localVehicle);
    await CacheService.saveCachedVehicles(cached);
    return localVehicle;
  }

  static Future<bool> renameVehicle(String id, String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) return false;

    // Update in Supabase if online and cloud ID
    if (isAuthenticated && id.isNotEmpty && !id.startsWith('local_')) {
      try {
        await client.from('vehicles').update({'name': clean}).eq('id', id);
      } catch (_) {}
    }

    // Always update in local cache
    final cached = CacheService.getCachedVehicles();
    final idx = cached.indexWhere((v) => v.id == id || v.name == newName);
    if (idx != -1) {
      cached[idx] = cached[idx].copyWith(name: clean);
      await CacheService.saveCachedVehicles(cached);
    }
    return true;
  }

  static Future<bool> deleteVehicle(String id) async {
    if (isAuthenticated && id.isNotEmpty && !id.startsWith('local_')) {
      try {
        await client.from('vehicles').delete().eq('id', id);
      } catch (_) {}
    }

    final cached = CacheService.getCachedVehicles();
    cached.removeWhere((x) => x.id == id);
    await CacheService.saveCachedVehicles(cached);
    return true;
  }

  // ── Fuel Logs CRUD ──

  static Future<List<FuelLog>> getFuelLogs(String vehicleId) async {
    if (vehicleId.isEmpty) return [];

    if (isAuthenticated && !vehicleId.startsWith('local_')) {
      try {
        final res = await client
            .from('fuel_logs')
            .select()
            .eq('vehicle_id', vehicleId)
            .order('date', ascending: false)
            .order('run_id', ascending: false);

        final logs = (res as List).map((x) => FuelLog.fromJson(x)).toList();
        await CacheService.saveCachedLogs(vehicleId, logs);
        return logs;
      } catch (_) {}
    }

    // Return locally cached logs
    return CacheService.getCachedLogs(vehicleId);
  }

  static Future<FuelLog?> addFuelLog(FuelLog log) async {
    if (isAuthenticated && log.vehicleId.isNotEmpty && !log.vehicleId.startsWith('local_')) {
      try {
        final res = await client.from('fuel_logs').insert(log.toJson()).select().single();
        final created = FuelLog.fromJson(res);
        final list = CacheService.getCachedLogs(log.vehicleId);
        list.insert(0, created);
        await CacheService.saveCachedLogs(log.vehicleId, list);
        return created;
      } catch (_) {}
    }

    // Local / Offline fallback
    final localLog = FuelLog(
      id: log.id.isNotEmpty ? log.id : 'log_${DateTime.now().millisecondsSinceEpoch}',
      userId: log.userId,
      vehicleId: log.vehicleId,
      runId: log.runId,
      date: log.date,
      fuelType: log.fuelType,
      fuelDensity: log.fuelDensity,
      fuelCost: log.fuelCost,
      litersToFill: log.litersToFill,
      costPerLtr: log.costPerLtr,
      fromOdometer: log.fromOdometer,
      toOdometer: log.toOdometer,
      distanceTraveled: log.distanceTraveled,
      fuelConsumed: log.fuelConsumed,
      calculatedMileage: log.calculatedMileage,
      costPerKm: log.costPerKm,
      fuelFillFlag: log.fuelFillFlag,
      createdAt: DateTime.now(),
    );

    final list = CacheService.getCachedLogs(log.vehicleId);
    list.insert(0, localLog);
    await CacheService.saveCachedLogs(log.vehicleId, list);
    return localLog;
  }

  static Future<bool> updateFuelLog(String id, String vehicleId, Map<String, dynamic> data) async {
    if (isAuthenticated && id.isNotEmpty && !id.startsWith('log_')) {
      try {
        await client.from('fuel_logs').update(data).eq('id', id);
      } catch (_) {}
    }

    // Update locally cached logs
    final list = CacheService.getCachedLogs(vehicleId);
    final idx = list.indexWhere((x) => x.id == id);
    if (idx != -1) {
      final existing = list[idx];
      final updated = existing.copyWith(
        fuelCost: data['fuel_cost'] != null ? (data['fuel_cost'] as num).toDouble() : existing.fuelCost,
        litersToFill: data['liters_to_fill'] != null ? (data['liters_to_fill'] as num).toDouble() : existing.litersToFill,
        fromOdometer: data['from_odometer'] != null ? (data['from_odometer'] as num).toInt() : existing.fromOdometer,
      );
      list[idx] = updated;
      await CacheService.saveCachedLogs(vehicleId, list);
    }
    return true;
  }

  static Future<bool> deleteFuelLog(String id, String vehicleId) async {
    if (isAuthenticated && id.isNotEmpty && !id.startsWith('log_')) {
      try {
        await client.from('fuel_logs').delete().eq('id', id);
      } catch (_) {}
    }

    final list = CacheService.getCachedLogs(vehicleId);
    list.removeWhere((x) => x.id == id);
    await CacheService.saveCachedLogs(vehicleId, list);
    return true;
  }
}
