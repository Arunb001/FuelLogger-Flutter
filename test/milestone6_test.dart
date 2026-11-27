import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuel_logger/config/env_dev.dart';
import 'package:fuel_logger/models/fuel_card.dart';
import 'package:fuel_logger/models/fuel_log.dart';
import 'package:fuel_logger/models/service_log.dart';
import 'package:fuel_logger/models/vehicle.dart';
import 'package:fuel_logger/providers/auth_provider.dart';
import 'package:fuel_logger/providers/garage_provider.dart';
import 'package:fuel_logger/providers/theme_provider.dart';
import 'package:fuel_logger/services/cache_service.dart';
import 'package:fuel_logger/theme/app_theme.dart';
import 'package:fuel_logger/views/calculations/calculations_view.dart';
import 'package:fuel_logger/views/home/home_view.dart';
import 'package:fuel_logger/views/logs/logs_view.dart';
import 'package:fuel_logger/views/settings/settings_view.dart';
import 'package:fuel_logger/views/shell/main_shell.dart';
import 'package:fuel_logger/views/upload/upload_view.dart';
import 'package:fuel_logger/views/utilities/utilities_view.dart';

Widget _wrapWithProviders({
  required Widget child,
  required GarageProvider garage,
  ThemeProvider? theme,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>.value(value: theme ?? ThemeProvider()),
      ChangeNotifierProvider<GarageProvider>.value(value: garage),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: child,
    ),
  );
}

void main() {
  setUpAll(() {
    EnvDev.init();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheService.init();
  });

  group('Milestone 6 FuelCard Deduction, Adjustment & Rename Sync', () {
    test('deducts on addFuelLog, adjusts on updateFuelLog, and refunds on deleteFuelLog', () async {
      await CacheService.saveCachedVehicles([
        Vehicle(id: 'local_v1', userId: '', name: 'Apache RTR', isActive: true),
      ]);

      final garage = GarageProvider();
      expect(garage.canAddVehicle, isTrue);

      final addedCard1 = await garage.addFuelCard(
        cardName: 'HPCL Card',
        cardLimit: 5000,
        resetDayOfMonth: 15,
      );
      expect(addedCard1, isTrue);
      expect(garage.fuelCards.length, 1);
      expect(garage.primaryFuelCard?.cardName, 'HPCL Card');
      expect(garage.primaryFuelCard?.isPrimary, isTrue);

      final addedCard2 = await garage.addFuelCard(
        cardName: 'BPCL Card',
        cardLimit: 3000,
        resetDayOfMonth: 1,
        isPrimary: false,
      );
      expect(addedCard2, isTrue);
      expect(garage.fuelCards.length, 2);

      final hpclId = garage.fuelCards.firstWhere((c) => c.cardName == 'HPCL Card').id;
      final bpclId = garage.fuelCards.firstWhere((c) => c.cardName == 'BPCL Card').id;

      // 1. Add fuel log linked to HPCL card -> limitUsed becomes 1200
      final okAdd = await garage.addFuelLog(
        runId: 1,
        date: '2026-11-27',
        fuelType: 'Standard petrol',
        fuelCost: 1200,
        litersToFill: 11.5,
        fromOdometer: 3500,
        fuelCardId: hpclId,
      );
      expect(okAdd, isTrue);
      expect(garage.fuelCardById(hpclId)!.limitUsed, 1200);
      expect(garage.fuelCardById(hpclId)!.remaining, 3800);

      final logId = garage.fuelLogs.first.id;

      // 2. Edit fill-up cost (1200 -> 1500) -> HPCL limitUsed becomes 1500
      final okEditCost = await garage.updateFuelLog(logId, {
        'fuel_cost': 1500.0,
        'fuel_card_id': hpclId,
      });
      expect(okEditCost, isTrue);
      expect(garage.fuelCardById(hpclId)!.limitUsed, 1500);

      // 3. Switch fill-up card (HPCL -> BPCL) -> HPCL refunds to 0, BPCL charges 1500
      final okSwitchCard = await garage.updateFuelLog(logId, {
        'fuel_cost': 1500.0,
        'fuel_card_id': bpclId,
      });
      expect(okSwitchCard, isTrue);
      expect(garage.fuelCardById(hpclId)!.limitUsed, 0);
      expect(garage.fuelCardById(bpclId)!.limitUsed, 1500);

      // 4. Delete fill-up -> BPCL refunds back to 0
      final okDelete = await garage.deleteFuelLog(logId);
      expect(okDelete, isTrue);
      expect(garage.fuelCardById(bpclId)!.limitUsed, 0);
    });

    test('renameActiveVehicle preserves icon/color customization and updates vehicle cache', () async {
      await CacheService.saveCachedVehicles([
        Vehicle(id: 'local_v1', userId: '', name: 'My Vehicle', isActive: true),
      ]);
      await CacheService.setVehicleIcon('My Vehicle', 'car');
      await CacheService.setVehicleColor('My Vehicle', 'blue');

      final garage = GarageProvider();
      await garage.updateCustomization(iconKey: 'car', colorKey: 'blue');
      final ok = await garage.renameActiveVehicle('Honda City');

      expect(ok, isTrue);
      expect(garage.activeVehicleName, 'Honda City');
      expect(CacheService.getActiveVehicle(), 'Honda City');
      expect(CacheService.getVehicleIcon('Honda City'), 'car');
      expect(CacheService.getVehicleColor('Honda City'), 'blue');
      expect(CacheService.getCachedVehicles().first.name, 'Honda City');
    });
  });

  group('Milestone 6 UI Views & Navigation Verification', () {
    testWidgets('HomeView shows Fuel Card Limit, Service Due, and Latest Service', (tester) async {
      await CacheService.saveCachedVehicles([
        Vehicle(id: 'local_v1', userId: '', name: 'Apache 310', isActive: true),
      ]);
      await CacheService.saveCachedFuelCards([
        FuelCard(
          id: 'card_1',
          userId: '',
          cardName: 'HPCL Rewards',
          cardLimit: 5000,
          limitUsed: 2000,
          isPrimary: true,
          resetDayOfMonth: 15,
          lastResetAt: DateTime.now(),
        ),
      ]);
      await CacheService.saveCachedLogs('local_v1', [
        FuelLog(
          id: 'log_1',
          userId: '',
          vehicleId: 'local_v1',
          runId: 1,
          date: '2026-11-20',
          fuelType: 'Standard petrol',
          fuelCost: 1000,
          litersToFill: 10,
          fromOdometer: 4000,
          toOdometer: 4350,
          distanceTraveled: 350,
          calculatedMileage: 35.0,
        ),
      ]);
      await CacheService.saveCachedServiceLogs('local_v1', [
        const ServiceLog(
          id: 'svc_1',
          userId: '',
          vehicleId: 'local_v1',
          serviceDate: '2026-11-22',
          odometer: 4100,
          serviceType: 'Oil Change',
          serviceCenter: 'TVS Service',
          totalCost: 1450,
          nextDueKm: 4700,
        ),
      ]);

      final garage = GarageProvider();
      await tester.pumpWidget(_wrapWithProviders(garage: garage, child: const HomeView()));

      expect(find.text('Fuel Card Limit'), findsOneWidget);
      expect(find.text('₹3,000'), findsOneWidget);
      expect(find.text('Service Due'), findsOneWidget);
      expect(find.text('Latest Service'), findsOneWidget);
      expect(find.text('Oil Change'), findsOneWidget);
      expect(find.text('TVS Service'), findsOneWidget);
    });

    testWidgets('MainShell bottom bar has Home, Insights, Log, Logs, Utilities in order',
        (tester) async {
      await CacheService.saveCachedVehicles([
        Vehicle(id: 'local_v1', userId: '', name: 'Bike', isActive: true),
      ]);
      final garage = GarageProvider();

      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrapWithProviders(garage: garage, child: const MainShell()),
      );
      await tester.pump();

      final bottomNav = find.byType(SafeArea).last;
      expect(find.descendant(of: bottomNav, matching: find.text('Home')), findsOneWidget);
      expect(find.descendant(of: bottomNav, matching: find.text('Insights')), findsOneWidget);
      expect(find.descendant(of: bottomNav, matching: find.text('Log')), findsOneWidget);
      expect(find.descendant(of: bottomNav, matching: find.text('Logs')), findsOneWidget);
      expect(find.descendant(of: bottomNav, matching: find.text('Utilities')), findsOneWidget);
      expect(find.descendant(of: bottomNav, matching: find.text('Service')), findsNothing);

      final homeX = tester.getCenter(find.descendant(of: bottomNav, matching: find.text('Home'))).dx;
      final insightsX = tester.getCenter(find.descendant(of: bottomNav, matching: find.text('Insights'))).dx;
      final logX = tester.getCenter(find.descendant(of: bottomNav, matching: find.text('Log'))).dx;
      final logsX = tester.getCenter(find.descendant(of: bottomNav, matching: find.text('Logs'))).dx;
      final utilitiesX = tester.getCenter(find.descendant(of: bottomNav, matching: find.text('Utilities'))).dx;

      expect(homeX < insightsX, isTrue);
      expect(insightsX < logX, isTrue);
      expect(logX < logsX, isTrue);
      expect(logsX < utilitiesX, isTrue);

      await tester.tap(find.text('Utilities'));
      await tester.pumpAndSettle();
      expect(find.text('Fuel Cards'), findsOneWidget);
    });

    testWidgets('CalculationsView reorders Fuel boxes and toggles cleanly to Service insights',
        (tester) async {
      await CacheService.saveCachedVehicles([
        Vehicle(id: 'local_v1', userId: '', name: 'Bike', isActive: true),
      ]);
      final garage = GarageProvider();

      await tester.pumpWidget(
        _wrapWithProviders(garage: garage, child: const CalculationsView()),
      );

      final volY = tester.getTopLeft(find.text('Total Fuel Volume').first).dy;
      final latestY = tester.getTopLeft(find.text('Latest Mileage').first).dy;
      final bestY = tester.getTopLeft(find.text('Best Mileage').first).dy;
      final lowestY = tester.getTopLeft(find.text('Lowest Mileage').first).dy;

      // P6: Row 2B (Total Fuel Volume) appears above Row 3 (Latest Mileage) & Row 4 (Best / Lowest Mileage)
      expect(volY < latestY, isTrue);
      expect(latestY < bestY, isTrue);
      expect((bestY - lowestY).abs() < 2.0, isTrue);

      await tester.tap(find.text('Service'));
      await tester.pumpAndSettle();
      expect(find.text('Maintenance Overview'), findsOneWidget);
      expect(find.text('Total Service Cost'), findsOneWidget);
      expect(find.text('Breakdown by Service Type'), findsOneWidget);
    });

    testWidgets('UploadView shows Fuel/Service toggle & Fuel Card dropdown when cards exist',
        (tester) async {
      await CacheService.saveCachedVehicles([
        Vehicle(id: 'local_v1', userId: '', name: 'Bike', isActive: true),
      ]);
      await CacheService.saveCachedFuelCards([
        FuelCard(
          id: 'card_1',
          userId: '',
          cardName: 'HPCL',
          cardLimit: 2000,
          limitUsed: 400,
          isPrimary: true,
          resetDayOfMonth: 1,
          lastResetAt: DateTime.now(),
        ),
      ]);
      final garage = GarageProvider();

      await tester.pumpWidget(
        _wrapWithProviders(garage: garage, child: const UploadView()),
      );

      expect(find.text('Fuel'), findsOneWidget);
      expect(find.text('Service'), findsOneWidget);
      expect(find.text('Fuel Card'), findsOneWidget);

      await tester.tap(find.text('Service'));
      await tester.pumpAndSettle();
      expect(find.text('Service Name / Work Done *'), findsOneWidget);
      expect(find.text('Save Service Record'), findsOneWidget);
    });

    testWidgets('LogsView and UtilitiesView render Fuel/Service toggle and Fuel Cards cleanly',
        (tester) async {
      await CacheService.saveCachedVehicles([
        Vehicle(id: 'local_v1', userId: '', name: 'Bike', isActive: true),
      ]);
      final garage = GarageProvider();

      await tester.pumpWidget(
        _wrapWithProviders(garage: garage, child: const LogsView()),
      );
      expect(find.text('No Fill-Up Logs Recorded'), findsOneWidget);

      await tester.tap(find.text('Service'));
      await tester.pumpAndSettle();
      expect(find.text('Service History (0)'), findsOneWidget);

      await tester.pumpWidget(
        _wrapWithProviders(garage: garage, child: const UtilitiesView()),
      );
      expect(find.text('Fuel Cards'), findsOneWidget);
      expect(find.text('No Fuel Cards Added'), findsOneWidget);
    });

    testWidgets('SettingsView shows Theme Mode and omits 2-vehicle quota badge', (tester) async {
      await CacheService.saveCachedVehicles([
        Vehicle(id: 'local_v1', userId: '', name: 'Bike', isActive: true),
      ]);
      final garage = GarageProvider();
      final auth = AuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<GarageProvider>.value(value: garage),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const SettingsView(),
          ),
        ),
      );

      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Appearance'), findsNothing);
      expect(find.textContaining('free'), findsNothing);
    });
  });
}
