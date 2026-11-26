import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuel_logger/models/app_notification.dart';
import 'package:fuel_logger/models/fuel_log.dart';
import 'package:fuel_logger/models/service_log.dart';
import 'package:fuel_logger/providers/theme_provider.dart';
import 'package:fuel_logger/services/cache_service.dart';
import 'package:fuel_logger/services/csv_service.dart';
import 'package:fuel_logger/theme/app_theme.dart';
import 'package:fuel_logger/utils/formatters.dart';
import 'package:fuel_logger/views/notifications/notifications_view.dart';
import 'package:fuel_logger/widgets/mileage_trend_card.dart';

void main() {
  group('CSV Export Privacy & Station/Remark Support (F3 / Privacy)', () {
    test('exportLogsToCsv includes station_name & remark and omits derived cycle fields', () {
      final logs = [
        FuelLog(
          id: 'log_1',
          userId: 'u_1',
          vehicleId: 'v_1',
          runId: 1,
          date: '2026-11-20',
          fuelType: 'XP95',
          fuelDensity: 750.5,
          fuelCost: 1050.0,
          litersToFill: 10.0,
          costPerLtr: 105.0,
          fromOdometer: 1000.0,
          toOdometer: 1450.0,
          distanceTraveled: 450.0,
          fuelConsumed: 10.0,
          calculatedMileage: 45.0,
          costPerKm: 2.33,
          fuelFillFlag: 'F',
          stationName: 'IndianOil',
          remark: 'Morning commute',
        ),
      ];

      final csv = CsvService.exportLogsToCsv(logs);
      final header = csv.split('\n').first;

      expect(header, contains('station_name'));
      expect(header, contains('remark'));
      expect(csv, contains('IndianOil'));
      expect(csv, contains('Morning commute'));

      // Privacy guarantee: internal calculated pairing metrics stay excluded
      expect(header, isNot(contains('to_odometer')));
      expect(header, isNot(contains('distance_traveled')));
      expect(header, isNot(contains('fuel_consumed')));
      expect(header, isNot(contains('calculated_mileage')));
      expect(header, isNot(contains('cost_per_km')));
    });

    test('parseCsv parses optional station_name and remark columns cleanly', () {
      const sample = 'run_id,date,fuel_type,odometer,fuel_cost,liters_to_fill,fuel_density,fill_flag,station_name,remark\n'
          '1,2026-11-20,Standard petrol,2500,500,5.0,750.0,F,Shell,"Highway run"\n';

      final parsed = CsvService.parseCsv(
        sample,
        userId: 'u_1',
        vehicleId: 'v_1',
      );

      expect(parsed.length, 1);
      expect(parsed.first.stationName, 'Shell');
      expect(parsed.first.remark, 'Highway run');
      expect(parsed.first.fromOdometer, 2500);
    });
  });

  group('F5 ServiceSummary Due / Overdue Thresholds', () {
    test('detects overdue when remaining km <= 0', () {
      final logs = [
        const ServiceLog(
          id: 's1',
          userId: 'u1',
          vehicleId: 'v1',
          serviceDate: '2026-11-01',
          odometer: 5000,
          serviceType: 'Periodic Service',
          totalCost: 1200,
          nextDueKm: 8000,
        ),
      ];

      final summary = ServiceSummary.compute(logs, 8050);
      expect(summary.isOverdue, isTrue);
      expect(summary.isDueSoon, isFalse);
      expect(summary.needsBanner, isTrue);
      expect(summary.remainingKm, -50);
    });

    test('detects due soon when within 500 km or 7 days', () {
      final inFiveDays = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(const Duration(days: 5)));
      final logs = [
        ServiceLog(
          id: 's2',
          userId: 'u1',
          vehicleId: 'v1',
          serviceDate: '2026-11-01',
          odometer: 5000,
          serviceType: 'Oil Change',
          totalCost: 850,
          nextDueKm: 8500,
          nextDueDate: inFiveDays,
        ),
      ];

      final summary = ServiceSummary.compute(logs, 8150);
      expect(summary.isOverdue, isFalse);
      expect(summary.isDueSoon, isTrue);
      expect(summary.needsBanner, isTrue);
      expect(summary.remainingKm, 350);
      expect(summary.remainingDays, 5);
    });

    test('remains calm when plenty of km and days remain', () {
      final inSixMonths = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(const Duration(days: 180)));
      final logs = [
        ServiceLog(
          id: 's3',
          userId: 'u1',
          vehicleId: 'v1',
          serviceDate: '2026-11-01',
          odometer: 5000,
          serviceType: 'Periodic Service',
          totalCost: 1500,
          nextDueKm: 10000,
          nextDueDate: inSixMonths,
        ),
      ];

      final summary = ServiceSummary.compute(logs, 6000);
      expect(summary.isOverdue, isFalse);
      expect(summary.isDueSoon, isFalse);
      expect(summary.needsBanner, isFalse);
      expect(summary.totalCost, 1500);
    });
  });

  group('F6 Notifications, Announcements & Formatters', () {
    test('AppAnnouncement.isDeliverableAt respects isActive and expiresAt', () {
      final active = AppAnnouncement(
        id: 'a1',
        title: 'Happy New Year!',
        body: 'Ride safe!',
        isActive: true,
        expiresAt: DateTime.now().add(const Duration(days: 2)),
      );
      final expired = AppAnnouncement(
        id: 'a2',
        title: 'Old Offer',
        body: 'Expired',
        isActive: true,
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final now = DateTime.now();
      expect(active.isDeliverableAt(now), isTrue);
      expect(expired.isDeliverableAt(now), isFalse);
    });

    test('AppNotificationItem and NotificationPreferences roundtrip JSON', () {
      const prefs = NotificationPreferences(
        enabled: true,
        serviceDueReminders: true,
        fillUpNudge: false,
        fillUpNudgeDays: 14,
        wishesAndTips: true,
        milestones: false,
      );
      final decodedPrefs = NotificationPreferences.fromJson(prefs.toJson());
      expect(decodedPrefs.fillUpNudge, isFalse);
      expect(decodedPrefs.milestones, isFalse);
      expect(decodedPrefs.serviceDueReminders, isTrue);

      final item = AppNotificationItem(
        id: 'n1',
        title: 'Milestone',
        body: 'Reached 5000 km',
        type: AppNotificationType.milestone,
        createdAt: DateTime(2026, 11, 26, 12, 0),
        routePayload: 'home',
      );
      final roundtrip = AppNotificationItem.fromJson(item.toJson());
      expect(roundtrip.type, AppNotificationType.milestone);
      expect(roundtrip.routePayload, 'home');
      expect(Formatters.relativeTime(DateTime.now()), 'Just now');
    });
  });

  group('F1 / F2 ThemeProvider & Widget Smoke Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await CacheService.init();
    });

    test('ThemeProvider defaults to system and persists dark/light mode', () async {
      final tp = ThemeProvider();
      expect(tp.themeMode, ThemeMode.system);

      await tp.setThemeMode(ThemeMode.dark);
      expect(tp.themeMode, ThemeMode.dark);
      expect(CacheService.getSavedThemeMode(), 'dark');

      await tp.setThemeMode(ThemeMode.light);
      expect(tp.themeMode, ThemeMode.light);
      expect(CacheService.getSavedThemeMode(), 'light');
    });

    testWidgets('NotificationsView and MileageTrendCard render under light and dark themes',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const NotificationsView(),
        ),
      );
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('All caught up'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: MileageTrendCard(
              logs: [
                FuelLog(
                  id: '1',
                  userId: 'u',
                  vehicleId: 'v',
                  runId: 1,
                  date: '2026-11-01',
                  fuelType: 'Standard petrol',
                  fuelCost: 500,
                  litersToFill: 5,
                  fromOdometer: 1000,
                  toOdometer: 1200,
                  distanceTraveled: 200,
                  calculatedMileage: 40.0,
                ),
                FuelLog(
                  id: '2',
                  userId: 'u',
                  vehicleId: 'v',
                  runId: 2,
                  date: '2026-11-10',
                  fuelType: 'Standard petrol',
                  fuelCost: 520,
                  litersToFill: 5,
                  fromOdometer: 1200,
                  toOdometer: 1420,
                  distanceTraveled: 220,
                  calculatedMileage: 44.0,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Recent Mileage Trend'), findsOneWidget);
      expect(find.textContaining('44.00'), findsOneWidget);
    });
  });
}
