import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';
import '../models/app_notification.dart';
import '../models/fuel_log.dart';
import '../models/service_log.dart';
import '../models/telemetry_summary.dart';
import '../models/vehicle.dart';
import 'cache_service.dart';
import 'supabase_service.dart';

const String _bgSyncUniqueName = 'fuel_logger_periodic_notification_sync';
const String _bgSyncTaskName = 'fuel_logger_notification_sync_task';

@pragma('vm:entry-point')
void notificationWorkmanagerCallback() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await CacheService.init();
      final prefs = CacheService.getNotificationPreferences();
      if (!prefs.enabled) return true;

      await NotificationService.initPluginOnly();

      // Re-initialize Supabase inside background isolate if credentials provided.
      final url = inputData?['supabaseUrl']?.toString() ?? '';
      final anonKey = inputData?['supabaseAnonKey']?.toString() ?? '';
      bool hasSupabase = false;
      try {
        // Check if Supabase is already initialized in this isolate
        Supabase.instance.client;
        hasSupabase = true;
      } catch (_) {
        if (url.isNotEmpty && anonKey.isNotEmpty) {
          try {
            await Supabase.initialize(url: url, anonKey: anonKey);
            hasSupabase = true;
          } catch (_) {}
        }
      }

      if (hasSupabase && prefs.wishesAndTips) {
        await NotificationService.syncRemoteAnnouncements();
      }
      return true;
    } catch (e) {
      debugPrint('Workmanager notification task error: $e');
      return true;
    }
  });
}

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _tzInitialized = false;
  static String? _pendingInitialPayload;

  static final StreamController<String?> _tapController =
      StreamController<String?>.broadcast();

  static final ValueNotifier<int> inboxVersion = ValueNotifier<int>(0);

  static Stream<String?> get onNotificationTap => _tapController.stream;

  static const String _reminderChannelId = 'fuel_logger_reminders';
  static const String _reminderChannelName = 'Service & Fill-Up Reminders';
  static const String _updatesChannelId = 'fuel_logger_updates';
  static const String _updatesChannelName = 'Milestones & Wishes';

  static const int _idWelcome = 1001;
  static const int _idFillNudge = 1002;
  static const int _idServiceReminder = 2001;
  static const int _idServiceDueAlert = 2002;

  static String? consumePendingInitialPayload() {
    final p = _pendingInitialPayload;
    _pendingInitialPayload = null;
    return p;
  }

  static void _ensureTimezones() {
    if (!_tzInitialized) {
      tz_data.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  static Future<void> initPluginOnly() async {
    if (_initialized) return;
    _ensureTimezones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _tapController.add(response.payload);
      },
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingInitialPayload = launchDetails?.notificationResponse?.payload;
    }

    _initialized = true;
  }

  static Future<void> init({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    try {
      await initPluginOnly();
      await Workmanager().initialize(notificationWorkmanagerCallback);
      await Workmanager().registerPeriodicTask(
        _bgSyncUniqueName,
        _bgSyncTaskName,
        frequency: const Duration(hours: 12),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(networkType: NetworkType.connected),
        inputData: {
          'supabaseUrl': supabaseUrl,
          'supabaseAnonKey': supabaseAnonKey,
        },
      );
    } catch (e) {
      debugPrint('NotificationService.init error: $e');
    }
  }

  static Future<bool> requestPermissionIfNeeded() async {
    try {
      await initPluginOnly();
      final androidImpl =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl == null) return true;
      final already = await androidImpl.areNotificationsEnabled() ?? true;
      if (already) return true;
      return await androidImpl.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  static NotificationDetails _details({required bool isReminder}) {
    final android = AndroidNotificationDetails(
      isReminder ? _reminderChannelId : _updatesChannelId,
      isReminder ? _reminderChannelName : _updatesChannelName,
      channelDescription: isReminder
          ? 'Reminders for scheduled vehicle maintenance and overdue fill-up check-ins.'
          : 'Mileage milestones, seasonal wishes, and Fuel Logger announcements.',
      importance: isReminder ? Importance.high : Importance.defaultImportance,
      priority: isReminder ? Priority.high : Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    return NotificationDetails(android: android);
  }

  static Future<void> _recordInInbox({
    required String id,
    required String title,
    required String body,
    required AppNotificationType type,
    String? routePayload,
    String? vehicleId,
  }) async {
    final uid = SupabaseService.userId;
    final items = CacheService.getCachedNotifications(uid);
    if (items.any((e) => e.id == id)) return;

    items.insert(
      0,
      AppNotificationItem(
        id: id,
        title: title,
        body: body,
        type: type,
        createdAt: DateTime.now(),
        routePayload: routePayload,
        vehicleId: vehicleId,
      ),
    );
    await CacheService.saveCachedNotifications(items, uid);
    inboxVersion.value++;
  }

  static int getUnreadCount() {
    final items = CacheService.getCachedNotifications(SupabaseService.userId);
    return items.where((e) => !e.isRead).length;
  }

  static List<AppNotificationItem> getInboxItems() {
    return CacheService.getCachedNotifications(SupabaseService.userId);
  }

  static Future<void> markAllRead() async {
    final uid = SupabaseService.userId;
    final updated = CacheService.getCachedNotifications(uid)
        .map((e) => e.copyWith(isRead: true))
        .toList();
    await CacheService.saveCachedNotifications(updated, uid);
    inboxVersion.value++;
  }

  static Future<void> markRead(String id) async {
    final uid = SupabaseService.userId;
    final updated = CacheService.getCachedNotifications(uid)
        .map((e) => e.id == id ? e.copyWith(isRead: true) : e)
        .toList();
    await CacheService.saveCachedNotifications(updated, uid);
    inboxVersion.value++;
  }

  static Future<void> clearInbox() async {
    final uid = SupabaseService.userId;
    await CacheService.saveCachedNotifications([], uid);
    inboxVersion.value++;
  }

  static Future<void> _showNow({
    required int osId,
    required String inboxId,
    required String title,
    required String body,
    required AppNotificationType type,
    bool isReminder = false,
    String? payload,
    String? vehicleId,
  }) async {
    await _recordInInbox(
      id: inboxId,
      title: title,
      body: body,
      type: type,
      routePayload: payload,
      vehicleId: vehicleId,
    );

    final prefs = CacheService.getNotificationPreferences();
    if (!prefs.enabled) return;

    try {
      await initPluginOnly();
      await _plugin.show(
        id: osId,
        title: title,
        body: body,
        notificationDetails: _details(isReminder: isReminder),
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService._showNow error: $e');
    }
  }

  static Future<void> _scheduleInexact({
    required int osId,
    required String title,
    required String body,
    required DateTime whenLocal,
    bool isReminder = true,
    String? payload,
  }) async {
    final prefs = CacheService.getNotificationPreferences();
    if (!prefs.enabled) return;
    if (!whenLocal.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return;
    }

    try {
      await initPluginOnly();
      _ensureTimezones();
      final scheduled = tz.TZDateTime.from(whenLocal, tz.local);
      await _plugin.zonedSchedule(
        id: osId,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _details(isReminder: isReminder),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService._scheduleInexact error: $e');
    }
  }

  /// Sends a one-time welcome notification when the user first enters MainShell.
  static Future<void> maybeSendWelcome() async {
    final uid = SupabaseService.userId;
    if (uid.isEmpty || CacheService.wasWelcomeNotificationShown(uid)) return;
    await CacheService.markWelcomeNotificationShown(uid);

    const title = 'Welcome to Fuel Logger';
    const body =
        'Track fill-ups, monitor service intervals, and view efficiency trends in one place.';
    await _showNow(
      osId: _idWelcome,
      inboxId: 'welcome_$uid',
      title: title,
      body: body,
      type: AppNotificationType.welcome,
      isReminder: false,
      payload: 'home',
    );
  }

  /// Evaluates telemetry, service due states, fill-up nudges, and km milestones.
  static Future<void> evaluateTelemetryNotifications({
    required Vehicle vehicle,
    required List<FuelLog> fuelLogs,
    required TelemetrySummary fuelSummary,
    required List<ServiceLog> serviceLogs,
    required ServiceSummary serviceSummary,
  }) async {
    final uid = SupabaseService.userId;
    if (uid.isEmpty) return;

    final prefs = CacheService.getNotificationPreferences();
    if (!prefs.enabled) {
      await _plugin.cancelAll();
      return;
    }

    final triggered = CacheService.getTriggeredAlertKeys(uid);

    // 1. Service Due / Overdue Check
    if (prefs.serviceDueReminders && serviceLogs.isNotEmpty) {
      await _evaluateServiceReminders(
        uid: uid,
        vehicle: vehicle,
        serviceSummary: serviceSummary,
        triggered: triggered,
      );
    } else {
      await _plugin.cancel(id: _idServiceReminder);
    }

    // 2. Fill-Up Check-In Nudge
    if (prefs.fillUpNudge && fuelLogs.isNotEmpty) {
      await _evaluateFillUpNudge(
        uid: uid,
        vehicle: vehicle,
        latestLog: fuelLogs.first,
        nudgeDays: prefs.fillUpNudgeDays,
        triggered: triggered,
      );
    } else {
      await _plugin.cancel(id: _idFillNudge);
    }

    // 3. Distance Milestones
    if (prefs.milestones && fuelSummary.totalDistance > 0) {
      await _evaluateMilestones(
        uid: uid,
        vehicle: vehicle,
        totalDistance: fuelSummary.totalDistance,
        triggered: triggered,
      );
    }
  }

  static Future<void> _evaluateServiceReminders({
    required String uid,
    required Vehicle vehicle,
    required ServiceSummary serviceSummary,
    required Set<String> triggered,
  }) async {
    if (serviceSummary.isOverdue) {
      final key =
          'svc_overdue_${vehicle.id}_${serviceSummary.nextDueKm ?? ""}_${serviceSummary.nextDueDate ?? ""}';
      if (!triggered.contains(key)) {
        await CacheService.addTriggeredAlertKey(key, uid);
        await _showNow(
          osId: _idServiceDueAlert,
          inboxId: key,
          title: '${vehicle.name}: Service Overdue',
          body:
              'Scheduled maintenance target has passed. Tap to log or update your next service.',
          type: AppNotificationType.serviceOverdue,
          isReminder: true,
          payload: 'service',
          vehicleId: vehicle.id,
        );
      }
      return;
    }

    if (serviceSummary.isDueSoon) {
      final key =
          'svc_due_${vehicle.id}_${serviceSummary.nextDueKm ?? ""}_${serviceSummary.nextDueDate ?? ""}';
      if (!triggered.contains(key)) {
        await CacheService.addTriggeredAlertKey(key, uid);
        final parts = <String>[];
        if (serviceSummary.remainingKm != null) {
          parts.add('${serviceSummary.remainingKm!.round()} km left');
        }
        if (serviceSummary.remainingDays != null) {
          parts.add('${serviceSummary.remainingDays} days left');
        }
        final detail = parts.isNotEmpty ? parts.join(' / ') : 'coming up soon';
        await _showNow(
          osId: _idServiceDueAlert,
          inboxId: key,
          title: '${vehicle.name}: Service Due Soon',
          body: 'Next maintenance ($detail). Plan your service visit.',
          type: AppNotificationType.serviceDue,
          isReminder: true,
          payload: 'service',
          vehicleId: vehicle.id,
        );
      }
    }

    // Schedule upcoming date-based reminder at 09:00 AM (7 days ahead if possible)
    if (serviceSummary.nextDueDate != null &&
        serviceSummary.nextDueDate!.isNotEmpty) {
      final due = DateTime.tryParse(serviceSummary.nextDueDate!);
      if (due != null) {
        final sevenDaysBefore = DateTime(due.year, due.month, due.day, 9)
            .subtract(const Duration(days: 7));
        final onDueDay = DateTime(due.year, due.month, due.day, 9);
        final now = DateTime.now();
        final target =
            sevenDaysBefore.isAfter(now) ? sevenDaysBefore : onDueDay;
        if (target.isAfter(now)) {
          await _scheduleInexact(
            osId: _idServiceReminder,
            title: '${vehicle.name}: Upcoming Service Reminder',
            body:
                'Scheduled service is due around ${serviceSummary.nextDueDate}.',
            whenLocal: target,
            isReminder: true,
            payload: 'service',
          );
        }
      }
    }
  }

  static Future<void> _evaluateFillUpNudge({
    required String uid,
    required Vehicle vehicle,
    required FuelLog latestLog,
    required int nudgeDays,
    required Set<String> triggered,
  }) async {
    final lastDate = DateTime.tryParse(latestLog.date.split(' ').first);
    if (lastDate == null) return;

    final now = DateTime.now();
    final targetDate =
        DateTime(lastDate.year, lastDate.month, lastDate.day, 18)
            .add(Duration(days: nudgeDays));

    await _plugin.cancel(id: _idFillNudge);

    if (now.isAfter(targetDate)) {
      final key = 'fill_nudge_${vehicle.id}_${latestLog.id}_$nudgeDays';
      if (!triggered.contains(key)) {
        await CacheService.addTriggeredAlertKey(key, uid);
        await _showNow(
          osId: _idFillNudge,
          inboxId: key,
          title: 'Time to log a fill-up?',
          body:
              'No fuel log recorded for ${vehicle.name} in over $nudgeDays days.',
          type: AppNotificationType.fillUpNudge,
          isReminder: true,
          payload: 'upload',
          vehicleId: vehicle.id,
        );
      }
    } else {
      await _scheduleInexact(
        osId: _idFillNudge,
        title: 'Time to log a fill-up?',
        body:
            'It has been $nudgeDays days since ${vehicle.name}\'s last recorded fill-up.',
        whenLocal: targetDate,
        isReminder: true,
        payload: 'upload',
      );
    }
  }

  static Future<void> _evaluateMilestones({
    required String uid,
    required Vehicle vehicle,
    required double totalDistance,
    required Set<String> triggered,
  }) async {
    const thresholds = [1000, 5000, 10000, 25000, 50000, 100000];
    int? highestReached;
    for (final m in thresholds) {
      if (totalDistance >= m) highestReached = m;
    }
    if (highestReached == null) return;

    final key = 'milestone_km_${vehicle.id}_$highestReached';
    if (!triggered.contains(key)) {
      await CacheService.addTriggeredAlertKey(key, uid);
      final osId = 3000 + (key.hashCode & 0x0FFF);
      await _showNow(
        osId: osId,
        inboxId: key,
        title: 'Distance Milestone: $highestReached km!',
        body:
            '${vehicle.name} has crossed $highestReached km of tracked distance in Fuel Logger.',
        type: AppNotificationType.milestone,
        isReminder: false,
        payload: 'home',
        vehicleId: vehicle.id,
      );
    }
  }

  /// Syncs remote announcements / festival wishes from Supabase `app_announcements`.
  static Future<void> syncRemoteAnnouncements() async {
    final prefs = CacheService.getNotificationPreferences();
    if (!prefs.enabled || !prefs.wishesAndTips) return;

    final announcements = await SupabaseService.getActiveAnnouncements();
    if (announcements.isEmpty) return;

    final seen = CacheService.getSeenAnnouncementIds();
    final now = DateTime.now();

    for (final item in announcements) {
      if (seen.contains(item.id) || !item.isDeliverableAt(now)) continue;
      await CacheService.markAnnouncementSeen(item.id);

      final osId = 4000 + (item.id.hashCode & 0x0FFF);
      final sched = item.scheduledFor?.toLocal();
      if (sched != null && sched.isAfter(now.add(const Duration(minutes: 1)))) {
        await _scheduleInexact(
          osId: osId,
          title: item.title,
          body: item.body,
          whenLocal: sched,
          isReminder: false,
          payload: 'notifications',
        );
      } else {
        await _showNow(
          osId: osId,
          inboxId: 'ann_${item.id}',
          title: item.title,
          body: item.body,
          type: AppNotificationType.announcement,
          isReminder: false,
          payload: 'notifications',
        );
      }
    }
  }

  /// Re-applies preferences immediately after user edits Settings toggles.
  static Future<void> applyPreferences(NotificationPreferences prefs) async {
    await CacheService.saveNotificationPreferences(prefs);
    if (!prefs.enabled) {
      await _plugin.cancelAll();
    } else {
      await requestPermissionIfNeeded();
    }
  }
}
