import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/env.dart';
import '../models/vehicle.dart';
import '../models/fuel_log.dart';
import '../models/fuel_card.dart';
import '../models/service_log.dart';
import '../models/app_notification.dart';
import 'cache_service.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser {
    try {
      return client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  static Session? get currentSession {
    try {
      return client.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

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
        serverClientId: AppConfig.googleWebClientId,
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
      }
    } catch (e) {
      // If native sign-in fails, fall back to Supabase Web OAuth using the flavor redirect URL
      try {
        await client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: AppConfig.isDev
              ? 'com.fuellogger.app.dev://auth'
              : 'fuellogger://auth',
        );
        return null;
      } catch (_) {
        rethrow;
      }
    }
    return null;
  }

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AppConfig.isDev
          ? 'com.fuellogger.app.dev://auth'
          : 'fuellogger://auth',
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

        // If authenticated user has 0 vehicles in cloud (new user), auto-provision initial vehicle
        final initial = await addVehicle('My Vehicle');
        if (initial != null) {
          await setActiveVehicle(initial.id);
          return [initial.copyWith(isActive: true)];
        }
      } catch (_) {
        // Network or offline error: fallback to locally cached vehicles
        final localCached = CacheService.getCachedVehicles();
        if (localCached.isNotEmpty) {
          return localCached;
        }
      }
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
        await client
            .from('vehicles')
            .update({
              'name': clean,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', id)
            .eq('user_id', userId);
      } catch (e) {
        debugPrint('SupabaseService.renameVehicle error: $e');
      }
    }

    // Always update in local cache by vehicle id
    final cached = CacheService.getCachedVehicles();
    final idx = cached.indexWhere((v) => v.id == id);
    if (idx != -1) {
      await CacheService.migrateVehicleCustomization(cached[idx].name, clean);
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

  /// Atomically sets [vehicleId] as active in Supabase via `set_active_vehicle` RPC
  /// and mirrors `isActive` state into local cache.
  static Future<bool> setActiveVehicle(String vehicleId) async {
    if (vehicleId.isEmpty) return false;

    final cached = CacheService.getCachedVehicles();
    if (cached.isNotEmpty) {
      final updated = cached.map((v) => v.copyWith(isActive: v.id == vehicleId)).toList();
      await CacheService.saveCachedVehicles(updated);
    }

    if (isAuthenticated && !vehicleId.startsWith('local_')) {
      try {
        await client.rpc('set_active_vehicle', params: {'p_vehicle_id': vehicleId});
        return true;
      } catch (e) {
        debugPrint('SupabaseService.setActiveVehicle RPC error: $e');
        return false;
      }
    }
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
            .order('run_id', ascending: false)
            .order('from_odometer', ascending: false);

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
      stationName: log.stationName,
      remark: log.remark,
      fuelCardId: log.fuelCardId,
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
        date: data['date'] != null ? data['date'].toString() : existing.date,
        fuelCost: data['fuel_cost'] != null ? (data['fuel_cost'] as num).toDouble() : existing.fuelCost,
        litersToFill: data['liters_to_fill'] != null ? (data['liters_to_fill'] as num).toDouble() : existing.litersToFill,
        fromOdometer: data['from_odometer'] != null ? (data['from_odometer'] as num).toDouble() : existing.fromOdometer,
        fuelType: data['fuel_type'] != null ? data['fuel_type'].toString() : existing.fuelType,
        fuelDensity: data['fuel_density'] != null ? (data['fuel_density'] as num).toDouble() : existing.fuelDensity,
        fuelFillFlag: data['fuel_fill_flag'] != null ? data['fuel_fill_flag'].toString() : existing.fuelFillFlag,
        stationName: data.containsKey('station_name') ? (data['station_name']?.toString().trim().isNotEmpty == true ? data['station_name'].toString().trim() : null) : existing.stationName,
        clearStationName: data.containsKey('station_name') && (data['station_name'] == null || data['station_name'].toString().trim().isEmpty),
        remark: data.containsKey('remark') ? (data['remark']?.toString().trim().isNotEmpty == true ? data['remark'].toString().trim() : null) : existing.remark,
        clearRemark: data.containsKey('remark') && (data['remark'] == null || data['remark'].toString().trim().isEmpty),
        fuelCardId: data.containsKey('fuel_card_id') ? (data['fuel_card_id']?.toString().trim().isNotEmpty == true ? data['fuel_card_id'].toString().trim() : null) : existing.fuelCardId,
        clearFuelCardId: data.containsKey('fuel_card_id') && (data['fuel_card_id'] == null || data['fuel_card_id'].toString().trim().isEmpty),
      );
      list[idx] = updated;
      await CacheService.saveCachedLogs(vehicleId, list);
    }
    return true;
  }

  static Future<bool> bulkInsertFuelLogs(
    String vehicleId,
    List<FuelLog> logs, {
    bool replaceExisting = false,
  }) async {
    if (vehicleId.isEmpty || logs.isEmpty) return false;

    if (isAuthenticated && !vehicleId.startsWith('local_')) {
      try {
        if (replaceExisting) {
          await client.from('fuel_logs').delete().eq('vehicle_id', vehicleId);
        }

        final payload = logs.map((l) {
          final m = l.toJson();
          m.remove('id'); // let Postgres generate UUIDs
          m['vehicle_id'] = vehicleId;
          m['user_id'] = userId;
          return m;
        }).toList();

        // Batch in chunks of 50
        for (int i = 0; i < payload.length; i += 50) {
          final end = (i + 50 < payload.length) ? i + 50 : payload.length;
          final batch = payload.sublist(i, end);
          await client.from('fuel_logs').insert(batch);
        }

        final fresh = await client
            .from('fuel_logs')
            .select()
            .eq('vehicle_id', vehicleId)
            .order('run_id', ascending: true);
        final freshLogs = (fresh as List).map((x) => FuelLog.fromJson(x)).toList();
        await CacheService.saveCachedLogs(vehicleId, freshLogs);
        return true;
      } catch (_) {}
    }

    // Local / Offline fallback
    List<FuelLog> current = replaceExisting ? [] : CacheService.getCachedLogs(vehicleId);
    final mapped = logs.map((l) {
      return l.copyWith(
        id: 'log_${DateTime.now().millisecondsSinceEpoch}_${l.runId}',
        userId: userId,
        vehicleId: vehicleId,
      );
    }).toList();

    current.addAll(mapped);
    await CacheService.saveCachedLogs(vehicleId, current);
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

  /// Asynchronously syncs recalculated forward-linking telemetry (to_odometer,
  /// fuel_consumed, distance_traveled, calculated_mileage, cost_per_km) back to Supabase.
  static Future<void> syncRecalculatedTelemetry(
    String vehicleId,
    List<FuelLog> originalLogs,
    List<FuelLog> recalculatedLogs,
  ) async {
    // 1. Update local offline cache with recalculated logs
    await CacheService.saveCachedLogs(vehicleId, recalculatedLogs);

    // 2. If authenticated and not a local-only vehicle, update changed records in Supabase
    if (isAuthenticated && vehicleId.isNotEmpty && !vehicleId.startsWith('local_')) {
      try {
        final origMap = <String, FuelLog>{};
        for (final o in originalLogs) {
          if (o.id.isNotEmpty) origMap[o.id] = o;
        }

        for (final log in recalculatedLogs) {
          if (log.id.isEmpty || log.id.startsWith('log_')) continue;
          final orig = origMap[log.id];

          final bool needsUpdate = orig == null ||
              orig.toOdometer != log.toOdometer ||
              (orig.distanceTraveled - log.distanceTraveled).abs() > 0.01 ||
              (orig.fuelConsumed - log.fuelConsumed).abs() > 0.01 ||
              (orig.calculatedMileage - log.calculatedMileage).abs() > 0.01 ||
              (orig.costPerKm - log.costPerKm).abs() > 0.01 ||
              (orig.costPerLtr - log.costPerLtr).abs() > 0.01;

          if (needsUpdate) {
            await client.from('fuel_logs').update({
              'to_odometer': log.toOdometer,
              'distance_traveled': log.distanceTraveled,
              'fuel_consumed': log.fuelConsumed,
              'calculated_mileage': log.calculatedMileage,
              'cost_per_km': log.costPerKm,
              'cost_per_ltr': log.costPerLtr,
              'fuel_fill_flag': log.fuelFillFlag,
            }).eq('id', log.id);
          }
        }
      } catch (_) {}
    }
  }

  // ── Fuel Types Cloud CRUD ──

  /// Fetches the user's configured fuel types and colors from Supabase cloud database
  static Future<List<Map<String, String>>> getCloudFuelTypes() async {
    if (!isAuthenticated || userId.isEmpty) return [];
    try {
      final res = await client
          .from('fuel_types')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      final List<Map<String, String>> result = [];
      for (final item in res as List) {
        final name = item['name']?.toString().trim() ?? '';
        final color = item['color']?.toString().trim() ?? '#FF5252';
        if (name.isNotEmpty) {
          result.add({'name': name, 'color': color});
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Adds a fuel type for the current user in Supabase cloud database
  static Future<bool> addCloudFuelType(String name, String color) async {
    final clean = name.trim();
    if (clean.isEmpty || !isAuthenticated || userId.isEmpty) return false;
    try {
      final existing = await client
          .from('fuel_types')
          .select('id')
          .eq('user_id', userId)
          .ilike('name', clean);

      if ((existing as List).isNotEmpty) {
        await client
            .from('fuel_types')
            .update({'color': color})
            .eq('user_id', userId)
            .ilike('name', clean);
        return true;
      }

      await client.from('fuel_types').insert({
        'user_id': userId,
        'name': clean,
        'color': color,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Updates the color of a fuel type in Supabase cloud database
  static Future<bool> updateCloudFuelTypeColor(String name, String hexColor) async {
    final clean = name.trim();
    if (clean.isEmpty || !isAuthenticated || userId.isEmpty) return false;
    try {
      final existing = await client
          .from('fuel_types')
          .select('id')
          .eq('user_id', userId)
          .ilike('name', clean);

      if ((existing as List).isNotEmpty) {
        await client
            .from('fuel_types')
            .update({'color': hexColor})
            .eq('user_id', userId)
            .ilike('name', clean);
        return true;
      } else {
        await client.from('fuel_types').insert({
          'user_id': userId,
          'name': clean,
          'color': hexColor,
        });
        return true;
      }
    } catch (_) {
      return false;
    }
  }

  /// Deletes a fuel type for the current user in Supabase cloud database
  static Future<bool> deleteCloudFuelType(String name) async {
    final clean = name.trim();
    if (clean.isEmpty || !isAuthenticated || userId.isEmpty) return false;
    try {
      await client
          .from('fuel_types')
          .delete()
          .eq('user_id', userId)
          .ilike('name', clean);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Service Logs Cloud CRUD (F5) ──

  static Future<List<ServiceLog>> getServiceLogs(String vehicleId) async {
    final localCached = CacheService.getCachedServiceLogs(vehicleId);
    if (!isAuthenticated ||
        userId.isEmpty ||
        vehicleId.isEmpty ||
        vehicleId.startsWith('local_')) {
      return localCached;
    }

    try {
      final res = await client
          .from('service_logs')
          .select()
          .eq('vehicle_id', vehicleId)
          .order('service_date', ascending: false);

      final cloud = (res as List)
          .map((e) => ServiceLog.fromJson(e as Map<String, dynamic>))
          .toList();
      await CacheService.saveCachedServiceLogs(vehicleId, cloud);
      return cloud;
    } catch (_) {
      return localCached;
    }
  }

  static Future<ServiceLog?> addServiceLog(ServiceLog log) async {
    if (!isAuthenticated ||
        userId.isEmpty ||
        log.vehicleId.isEmpty ||
        log.vehicleId.startsWith('local_')) {
      final local = log.copyWith(
        id: 'svc_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
      );
      final cached = CacheService.getCachedServiceLogs(log.vehicleId);
      cached.insert(0, local);
      await CacheService.saveCachedServiceLogs(log.vehicleId, cached);
      return local;
    }

    try {
      final payload = log.toInsertJson();
      payload['user_id'] = userId;
      final res = await client
          .from('service_logs')
          .insert(payload)
          .select()
          .single();
      final created = ServiceLog.fromJson(res);
      final cached = CacheService.getCachedServiceLogs(log.vehicleId);
      cached.insert(0, created);
      await CacheService.saveCachedServiceLogs(log.vehicleId, cached);
      return created;
    } catch (e) {
      debugPrint('SupabaseService.addServiceLog error: $e');
      return null;
    }
  }

  static Future<bool> updateServiceLog(
      String id, String vehicleId, Map<String, dynamic> data) async {
    final cached = CacheService.getCachedServiceLogs(vehicleId);
    final idx = cached.indexWhere((s) => s.id == id);

    if (!isAuthenticated ||
        vehicleId.startsWith('local_') ||
        id.startsWith('svc_')) {
      if (idx != -1) {
        final merged = cached[idx].toJson()..addAll(data);
        cached[idx] = ServiceLog.fromJson(merged);
        await CacheService.saveCachedServiceLogs(vehicleId, cached);
      }
      return true;
    }

    try {
      await client
          .from('service_logs')
          .update(data)
          .eq('id', id)
          .eq('user_id', userId);
      if (idx != -1) {
        final merged = cached[idx].toJson()..addAll(data);
        cached[idx] = ServiceLog.fromJson(merged);
        await CacheService.saveCachedServiceLogs(vehicleId, cached);
      }
      return true;
    } catch (e) {
      debugPrint('SupabaseService.updateServiceLog error: $e');
      return false;
    }
  }

  static Future<bool> deleteServiceLog(String id, String vehicleId) async {
    final cached = CacheService.getCachedServiceLogs(vehicleId)
      ..removeWhere((s) => s.id == id);

    if (!isAuthenticated ||
        vehicleId.startsWith('local_') ||
        id.startsWith('svc_')) {
      await CacheService.saveCachedServiceLogs(vehicleId, cached);
      return true;
    }

    try {
      await client
          .from('service_logs')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
      await CacheService.saveCachedServiceLogs(vehicleId, cached);
      return true;
    } catch (e) {
      debugPrint('SupabaseService.deleteServiceLog error: $e');
      return false;
    }
  }

  // ── Fuel Cards CRUD (F9) ──

  static Future<List<FuelCard>> getFuelCards() async {
    final localCached = CacheService.getCachedFuelCards();
    if (!isAuthenticated || userId.isEmpty) {
      return localCached;
    }

    try {
      final res = await client
          .from('fuel_cards')
          .select()
          .eq('user_id', userId)
          .order('is_primary', ascending: false)
          .order('created_at', ascending: true);

      final cloud = (res as List)
          .map((e) => FuelCard.fromJson(e as Map<String, dynamic>))
          .toList();
      await CacheService.saveCachedFuelCards(cloud);
      return cloud;
    } catch (e) {
      debugPrint('SupabaseService.getFuelCards error: $e');
      return localCached;
    }
  }

  static Future<FuelCard?> addFuelCard(FuelCard card) async {
    if (!isAuthenticated || userId.isEmpty) {
      final localId = 'card_${DateTime.now().millisecondsSinceEpoch}';
      final cached = CacheService.getCachedFuelCards();
      final updated = card.isPrimary
          ? cached.map((c) => c.copyWith(isPrimary: false)).toList()
          : List<FuelCard>.from(cached);
      final localCard = card.copyWith(
        id: localId,
        userId: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      updated.add(localCard);
      await CacheService.saveCachedFuelCards(updated);
      return localCard;
    }

    try {
      final payload = card.toInsertJson();
      payload['user_id'] = userId;
      // Insert with is_primary = false first to avoid partial unique index race,
      // then atomically set primary via RPC if requested.
      final wantsPrimary = card.isPrimary;
      payload['is_primary'] = false;

      final res = await client
          .from('fuel_cards')
          .insert(payload)
          .select()
          .single();

      var created = FuelCard.fromJson(res);
      if (wantsPrimary && created.id.isNotEmpty) {
        final ok = await setPrimaryFuelCard(created.id);
        if (ok) {
          created = created.copyWith(isPrimary: true);
        }
      }

      final fresh = await getFuelCards();
      if (fresh.isNotEmpty) {
        return fresh.firstWhere((c) => c.id == created.id, orElse: () => created);
      }
      return created;
    } catch (e) {
      debugPrint('SupabaseService.addFuelCard error: $e');
      return null;
    }
  }

  static Future<bool> updateFuelCard(String id, Map<String, dynamic> data) async {
    final cached = CacheService.getCachedFuelCards();
    final idx = cached.indexWhere((c) => c.id == id);

    void applyCacheUpdate() {
      if (idx == -1) return;
      final existing = cached[idx];
      cached[idx] = existing.copyWith(
        cardName: data['card_name']?.toString() ?? existing.cardName,
        cardLimit: data['card_limit'] != null
            ? (data['card_limit'] as num).toDouble()
            : existing.cardLimit,
        limitUsed: data['limit_used'] != null
            ? (data['limit_used'] as num).toDouble()
            : existing.limitUsed,
        resetDayOfMonth: data['reset_day_of_month'] != null
            ? (data['reset_day_of_month'] as num).toInt().clamp(1, 31)
            : existing.resetDayOfMonth,
        lastResetAt: data['last_reset_at'] != null
            ? (DateTime.tryParse(data['last_reset_at'].toString()) ?? existing.lastResetAt)
            : existing.lastResetAt,
        updatedAt: DateTime.now(),
      );
    }

    if (!isAuthenticated || userId.isEmpty || id.startsWith('card_')) {
      applyCacheUpdate();
      await CacheService.saveCachedFuelCards(cached);
      return true;
    }

    try {
      final payload = Map<String, dynamic>.from(data);
      payload['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await client
          .from('fuel_cards')
          .update(payload)
          .eq('id', id)
          .eq('user_id', userId);
      applyCacheUpdate();
      await CacheService.saveCachedFuelCards(cached);
      return true;
    } catch (e) {
      debugPrint('SupabaseService.updateFuelCard error: $e');
      return false;
    }
  }

  static Future<bool> setPrimaryFuelCard(String cardId) async {
    if (cardId.isEmpty) return false;

    final cached = CacheService.getCachedFuelCards();
    if (cached.isNotEmpty) {
      final updated =
          cached.map((c) => c.copyWith(isPrimary: c.id == cardId)).toList();
      await CacheService.saveCachedFuelCards(updated);
    }

    if (isAuthenticated && userId.isNotEmpty && !cardId.startsWith('card_')) {
      try {
        await client.rpc('set_primary_fuel_card', params: {'p_card_id': cardId});
        return true;
      } catch (e) {
        debugPrint('SupabaseService.setPrimaryFuelCard RPC error: $e');
        return false;
      }
    }
    return true;
  }

  static Future<bool> deleteFuelCard(String id) async {
    final cached = CacheService.getCachedFuelCards()
      ..removeWhere((c) => c.id == id);

    if (!isAuthenticated || userId.isEmpty || id.startsWith('card_')) {
      await CacheService.saveCachedFuelCards(cached);
      return true;
    }

    try {
      await client
          .from('fuel_cards')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
      await CacheService.saveCachedFuelCards(cached);
      return true;
    } catch (e) {
      debugPrint('SupabaseService.deleteFuelCard error: $e');
      return false;
    }
  }

  // ── App Announcements / Remote Wishes (F6) ──

  static Future<List<AppAnnouncement>> getActiveAnnouncements() async {
    try {
      final res = await client
          .from('app_announcements')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(20);
      return (res as List)
          .map((e) => AppAnnouncement.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
