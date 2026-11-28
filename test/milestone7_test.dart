import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuel_logger/config/env_dev.dart';
import 'package:fuel_logger/config/version.dart';
import 'package:fuel_logger/models/fuel_card.dart';
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
import 'package:fuel_logger/views/utilities/fuel_cards_view.dart';
import 'package:fuel_logger/views/utilities/pollution_certificate_view.dart';
import 'package:fuel_logger/views/utilities/utilities_view.dart';

Widget _wrap({
  required Widget child,
  required GarageProvider garage,
  ThemeMode themeMode = ThemeMode.dark,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<GarageProvider>.value(value: garage),
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
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

  group('Milestone 7 Unit Tests — Version, Service Types & PUC Logic', () {
    test('AppVersion formats Fuel Logger - 3.2.1 (27)', () {
      expect(AppVersion.appVersion, '3.2.1');
      expect(AppVersion.buildNumber, 27);
      expect(AppVersion.display, 'Fuel Logger - 3.2.1 (27)');
      expect(AppVersion.fullDisplay, 'Fuel Logger - 3.2.1 (27)');
    });

    test('FuelCard balanceStatus changes by remaining limit left (>=50% green, <50% yellow, <25% red)', () {
      final now = DateTime(2026, 11, 28);
      FuelCard cardWithUsed(double used) => FuelCard(
            id: 'c1',
            userId: 'u1',
            cardName: 'HPCL',
            cardLimit: 1000,
            limitUsed: used,
            isPrimary: true,
            lastResetAt: now,
          );

      // 100% left and 50% left -> Green (healthy)
      expect(cardWithUsed(0).balanceStatus, FuelCardStatus.healthy);
      expect(cardWithUsed(500).balanceStatus, FuelCardStatus.healthy);

      // Below 50% down to 25% left -> Yellow (low)
      expect(cardWithUsed(501).balanceStatus, FuelCardStatus.low);
      expect(cardWithUsed(750).balanceStatus, FuelCardStatus.low);

      // Below 25% left -> Red (critical)
      expect(cardWithUsed(751).balanceStatus, FuelCardStatus.critical);
      expect(cardWithUsed(1000).balanceStatus, FuelCardStatus.critical);
      expect(cardWithUsed(1200).balanceStatus, FuelCardStatus.critical);
    });

    test('Vehicle PUC status thresholds and month clamping work accurately', () {
      final now = DateTime(2026, 11, 28);
      final notSet = Vehicle(id: 'v0', userId: '', name: 'Bike');
      expect(notSet.pucStatus(now), PucStatus.notSet);
      expect(notSet.pucRemainingDays(now), isNull);

      final expired = notSet.copyWith(pucExpiryDate: '2026-11-20');
      expect(expired.pucStatus(now), PucStatus.expired);
      expect(expired.pucRemainingDays(now), -8);

      final soon = notSet.copyWith(pucExpiryDate: '2026-12-10');
      expect(soon.pucStatus(now), PucStatus.expiringSoon);
      expect(soon.pucRemainingDays(now), 12);

      final valid = notSet.copyWith(pucExpiryDate: '2027-01-15');
      expect(valid.pucStatus(now), PucStatus.valid);
      expect(valid.pucRemainingDays(now), 48);

      // Renewing when still valid extends from current expiry; when expired uses today
      expect(valid.computeNextPucExpiry(now: now, overrideMonths: 6), DateTime(2027, 7, 15));
      expect(expired.computeNextPucExpiry(now: now, overrideMonths: 6), DateTime(2027, 5, 28));

      // Clamps Feb 28 / Feb 29 without spilling into March
      expect(Vehicle.addMonthsClamped(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28));
      expect(Vehicle.addMonthsClamped(DateTime(2023, 8, 31), 6), DateTime(2024, 2, 29));
    });

    test('GarageProvider Service Types default strictly to General Repair with Add/Delete & PUC persistence',
        () async {
      await CacheService.saveCachedVehicles([
        Vehicle(id: 'local_v1', userId: '', name: 'City', isActive: true),
      ]);
      final garage = GarageProvider();

      expect(garage.serviceTypes, ['General Repair']);
      expect(garage.removeCustomServiceType('General Repair'), isFalse);

      expect(garage.addCustomServiceType('Oil Change'), isTrue);
      expect(garage.addCustomServiceType('oil change'), isFalse);
      expect(garage.serviceTypes, ['General Repair', 'Oil Change']);
      expect(CacheService.getCachedServiceTypes(), ['General Repair', 'Oil Change']);

      expect(garage.removeCustomServiceType('Oil Change'), isTrue);
      expect(garage.serviceTypes, ['General Repair']);

      final saved = await garage.updateVehiclePuc(
        pucExpiryDate: '2027-03-15',
        pucRenewalMonths: 12,
      );
      expect(saved, isTrue);
      expect(garage.activeVehicle?.pucExpiryDate, '2027-03-15');
      expect(garage.activeVehicle?.pucRenewalMonths, 12);
      expect(CacheService.getCachedVehicles().first.pucExpiryDate, '2027-03-15');

      final cleared = await garage.updateVehiclePuc(
        pucExpiryDate: null,
        pucRenewalMonths: 6,
      );
      expect(cleared, isTrue);
      expect(garage.activeVehicle?.pucExpiryDate, isNull);
    });
  });

  group('Milestone 7 Widget & Navigation Tests', () {
    testWidgets('P7.1 HomeView uses compact empty cards, red/white Log buttons, and colored Fuel Card / Service Due icons',
        (tester) async {
      await CacheService.saveCachedVehicles([
        Vehicle(id: 'local_v1', userId: '', name: 'Apache', isActive: true),
      ]);
      final garage = GarageProvider();

      await tester.pumpWidget(_wrap(garage: garage, child: const HomeView()));

      expect(find.text('No fill-ups logged yet'), findsOneWidget);
      expect(find.text('No service records yet'), findsOneWidget);
      expect(find.text('Log'), findsNWidgets(2));

      final cardIcon = tester.widget<Icon>(find.byIcon(Icons.credit_card_rounded));
      expect(cardIcon.color, const Color(0xFFAB47BC));

      final svcIcon = tester.widget<Icon>(find.byIcon(Icons.build_circle_outlined));
      expect(svcIcon.color, const Color(0xFFFFD54F));
    });

    testWidgets('HomeView colors Fuel Card Limit value Green (>=50%), Yellow (<50%), and Red (<25%) while keeping icon Purple',
        (tester) async {
      Future<void> expectValueColorForUsed(double used, String expectedText, Color expectedColor) async {
        await CacheService.saveCachedVehicles([
          Vehicle(id: 'local_v1', userId: '', name: 'Apache', isActive: true),
        ]);
        await CacheService.saveCachedFuelCards([
          FuelCard(
            id: 'c1',
            userId: '',
            cardName: 'HPCL',
            cardLimit: 1000,
            limitUsed: used,
            isPrimary: true,
            lastResetAt: DateTime.now(),
          ),
        ]);
        final garage = GarageProvider();
        await tester.pumpWidget(_wrap(garage: garage, child: const HomeView()));

        final valueWidget = tester.widget<Text>(find.text(expectedText));
        expect(valueWidget.style?.color, expectedColor);
        final cardIcon = tester.widget<Icon>(find.byIcon(Icons.credit_card_rounded));
        expect(cardIcon.color, const Color(0xFFAB47BC));
      }

      // 100% left (₹1,000) -> Green
      await expectValueColorForUsed(0, '₹1,000', AppSemanticColors.dark.mileageGreen);
      // 40% left (₹400, below 50%) -> Yellow
      await expectValueColorForUsed(600, '₹400', AppSemanticColors.dark.costAmber);
      // 20% left (₹200, below 25%) -> Red
      await expectValueColorForUsed(800, '₹200', AppSemanticColors.dark.accentPrimary);
    });

    testWidgets('P7.2 MainShell animates bottom nav selections without overflow', (tester) async {
      await CacheService.saveCachedVehicles([
        Vehicle(id: 'local_v1', userId: '', name: 'Bike', isActive: true),
      ]);
      final garage = GarageProvider();

      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(garage: garage, child: const MainShell()));
      await tester.pump();

      expect(find.byType(AnimatedScale), findsWidgets);
      expect(find.byType(AnimatedSwitcher), findsNWidgets(4));

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(find.text('Maintenance Overview'), findsNothing);
    });

    testWidgets('P7.3 SettingsView consolidates Vehicle Customization, enforces 8-card order, and shows Fuel Logger - 3.2.1 (27)',
        (tester) async {
      await CacheService.saveCachedVehicles([
        Vehicle(id: 'local_v1', userId: '', name: 'City', isActive: true),
        Vehicle(id: 'local_v2', userId: '', name: 'Duke', isActive: false),
      ]);
      final garage = GarageProvider();

      tester.view.physicalSize = const Size(420, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(garage: garage, child: const SettingsView()));

      expect(find.text('Select Vehicle'), findsOneWidget);
      expect(find.text('Add New Vehicle'), findsOneWidget);
      expect(find.text('Delete Current Vehicle'), findsOneWidget);
      expect(find.text('Fuel Logger - 3.2.1 (27)'), findsOneWidget);

      final yTheme = tester.getTopLeft(find.text('Theme Mode')).dy;
      final yVehicle = tester.getTopLeft(find.text('Vehicle Customization')).dy;
      final yFuelTypes = tester.getTopLeft(find.text('Manage Fuel Types')).dy;
      final yNotifs = tester.getTopLeft(find.text('Notifications & Reminders')).dy;
      final yBackup = tester.getTopLeft(find.text('Data Backup & CSV Transfer')).dy;
      final yAccount = tester.getTopLeft(find.text('Account')).dy;
      final yGuide = tester.getTopLeft(find.text('User Guide & FAQs')).dy;
      final ySupport = tester.getTopLeft(find.text('Developer Support')).dy;

      expect(yTheme < yVehicle, isTrue);
      expect(yVehicle < yFuelTypes, isTrue);
      expect(yFuelTypes < yNotifs, isTrue);
      expect(yNotifs < yBackup, isTrue);
      expect(yBackup < yAccount, isTrue);
      expect(yAccount < yGuide, isTrue);
      expect(yGuide < ySupport, isTrue);
    });

    testWidgets('P7.4 ServiceFormBody uses Service Type dropdown defaulting to General Repair',
        (tester) async {
      await CacheService.saveCachedVehicles([
        Vehicle(id: 'local_v1', userId: '', name: 'Bike', isActive: true),
      ]);
      final garage = GarageProvider();

      await tester.pumpWidget(
        _wrap(garage: garage, child: const UploadView(initialIsService: true)),
      );

      expect(find.text('Service Type *'), findsOneWidget);
      expect(find.text('General Repair'), findsOneWidget);
      expect(find.text('Service Name / Work Done *'), findsNothing);
      expect(find.text('Chain & Sprocket'), findsNothing);
    });

    testWidgets('P7.5 & P7.6 Insights aligns top in Service mode and Logs hides KPIs and + Add button',
        (tester) async {
      await CacheService.saveCachedVehicles([
        Vehicle(id: 'local_v1', userId: '', name: 'Bike', isActive: true),
      ]);
      final garage = GarageProvider();

      await tester.pumpWidget(_wrap(garage: garage, child: const CalculationsView()));
      await tester.tap(find.text('Service'));
      await tester.pumpAndSettle();

      final segTopY = tester.getTopLeft(find.byType(SegmentedButton<bool>)).dy;
      expect(segTopY, lessThan(130));

      await tester.pumpWidget(_wrap(garage: garage, child: const LogsView()));
      await tester.tap(find.text('Service'));
      await tester.pumpAndSettle();

      expect(find.text('Add'), findsNothing);
      expect(find.text('Total Spent'), findsNothing);
      expect(find.text('No Service Logs Recorded'), findsOneWidget);
      expect(find.text('Log First Service'), findsOneWidget);
    });

    testWidgets('P7.7 & P7.8 Utilities Hub pushes FuelCardsView (no AppBar Add Card) and PollutionCertificateView',
        (tester) async {
      final soonDate = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(const Duration(days: 10)));
      await CacheService.saveCachedVehicles([
        Vehicle(
          id: 'local_v1',
          userId: '',
          name: 'Apache',
          isActive: true,
          pucExpiryDate: soonDate,
          pucRenewalMonths: 6,
        ),
      ]);
      final garage = GarageProvider();

      await tester.pumpWidget(_wrap(garage: garage, child: const UtilitiesView()));
      expect(find.text('Fuel Cards'), findsOneWidget);
      expect(find.text('Pollution Certificate'), findsOneWidget);
      expect(find.textContaining('10 days left'), findsOneWidget);

      await tester.tap(find.text('Fuel Cards'));
      await tester.pumpAndSettle();
      expect(find.byType(FuelCardsView), findsOneWidget);
      expect(find.text('Add Card'), findsNothing);
      expect(find.text('Add Fuel Card'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pollution Certificate'));
      await tester.pumpAndSettle();
      expect(find.byType(PollutionCertificateView), findsOneWidget);
      expect(find.text('3 Months'), findsOneWidget);
      expect(find.text('6 Months'), findsOneWidget);
      expect(find.text('12 Months'), findsOneWidget);
      expect(find.text('Save PUC Details'), findsOneWidget);
      expect(find.text('Renewed Today (+6 mo)'), findsOneWidget);
    });
  });
}
