import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle.dart';
import '../models/fuel_log.dart';
import 'cache_service.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;
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

  static Future<void> sendOtp(String email) async {
    await client.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: 'fuellogger://auth',
    );
  }

  static Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) async {
    return await client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  static Future<UserResponse> updatePassword(String newPassword) async {
    return await client.auth.updateUser(
      UserAttributes(password: newPassword.trim()),
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // ── Vehicles CRUD ──

  static Future<List<Vehicle>> getVehicles() async {
    if (!isAuthenticated) return [];

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

      // If database has 0 vehicles for user, auto-provision initial vehicle
      if (vehicles.isEmpty) {
        final newV = await addVehicle('My Vehicle');
        if (newV != null) vehicles.add(newV);
      }

      return vehicles;
    } catch (_) {
      return [];
    }
  }

  static Future<Vehicle?> addVehicle(String name) async {
    if (!isAuthenticated) return null;
    try {
      final res = await client.from('vehicles').insert({
        'user_id': userId,
        'name': name.trim(),
        'is_active': false,
      }).select().single();
      return Vehicle.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> renameVehicle(String id, String newName) async {
    if (!isAuthenticated) return false;
    try {
      await client.from('vehicles').update({'name': newName.trim()}).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteVehicle(String id) async {
    if (!isAuthenticated) return false;
    try {
      await client.from('vehicles').delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Fuel Logs CRUD ──

  static Future<List<FuelLog>> getFuelLogs(String vehicleId) async {
    if (!isAuthenticated || vehicleId.isEmpty) return [];
    try {
      final res = await client
          .from('fuel_logs')
          .select()
          .eq('vehicle_id', vehicleId)
          .order('date', ascending: false)
          .order('run_id', ascending: false);

      return (res as List).map((x) => FuelLog.fromJson(x)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<FuelLog?> addFuelLog(FuelLog log) async {
    if (!isAuthenticated) return null;
    try {
      final res = await client.from('fuel_logs').insert(log.toJson()).select().single();
      return FuelLog.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> updateFuelLog(String id, Map<String, dynamic> data) async {
    if (!isAuthenticated) return false;
    try {
      await client.from('fuel_logs').update(data).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteFuelLog(String id) async {
    if (!isAuthenticated) return false;
    try {
      await client.from('fuel_logs').delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }
}
