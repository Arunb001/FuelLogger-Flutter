import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_logger/models/app_update_config.dart';
import 'package:fuel_logger/models/user_entitlement.dart';
import 'package:fuel_logger/services/update_checker_service.dart';

void main() {
  group('F7 UserEntitlement & 2-Vehicle Free Cap', () {
    test('free non-grandfathered account allows up to 2 vehicles only', () {
      const ent = UserEntitlement(userId: 'u_new', isPro: false, isGrandfathered: false, maxFreeVehicles: 2);
      expect(ent.isUnlimited, isFalse);
      expect(ent.canAddVehicle(0), isTrue);
      expect(ent.canAddVehicle(1), isTrue);
      expect(ent.canAddVehicle(2), isFalse);
      expect(ent.canAddVehicle(3), isFalse);
    });

    test('grandfathered Closed Testing user retains unlimited vehicles (Option B)', () {
      final ent = UserEntitlement.fromJson({
        'user_id': 'u_early',
        'is_pro': false,
        'is_grandfathered': true,
        'max_free_vehicles': 2,
      });
      expect(ent.isUnlimited, isTrue);
      expect(ent.canAddVehicle(1), isTrue);
      expect(ent.canAddVehicle(2), isTrue);
      expect(ent.canAddVehicle(10), isTrue);
    });

    test('Pro account unlocks unlimited vehicles', () {
      const ent = UserEntitlement(userId: 'u_pro', isPro: true, isGrandfathered: false);
      expect(ent.isUnlimited, isTrue);
      expect(ent.canAddVehicle(5), isTrue);
    });
  });

  group('F8 UpdateCheckerService 2-Backward-Version & Critical Rules', () {
    test('allows N, N-1, N-2 and forces N-3 when non-critical', () {
      const cfg = AppUpdateConfig(
        latestVersion: '3.0.2',
        latestBuild: 26,
        minSupportedBuild: 24, // Supports 26 (N), 25 (N-1), 24 (N-2)
        isCritical: false,
      );

      expect(UpdateCheckerService.evaluate(27, cfg), UpdateRequirement.upToDate);
      expect(UpdateCheckerService.evaluate(26, cfg), UpdateRequirement.upToDate);
      expect(UpdateCheckerService.evaluate(25, cfg), UpdateRequirement.optionalUpdate);
      expect(UpdateCheckerService.evaluate(24, cfg), UpdateRequirement.optionalUpdate);
      expect(UpdateCheckerService.evaluate(23, cfg), UpdateRequirement.forceUpdate); // N-3 forced
      expect(UpdateCheckerService.evaluate(22, cfg), UpdateRequirement.forceUpdate);
    });

    test('forces immediate update when isCritical is true even if minSupportedBuild is stale', () {
      const cfg = AppUpdateConfig(
        latestVersion: '3.0.3',
        latestBuild: 27,
        minSupportedBuild: 25,
        isCritical: true,
      );

      expect(UpdateCheckerService.evaluate(27, cfg), UpdateRequirement.upToDate);
      expect(UpdateCheckerService.evaluate(26, cfg), UpdateRequirement.forceUpdate);
      expect(UpdateCheckerService.evaluate(25, cfg), UpdateRequirement.forceUpdate);
    });

    test('defaults minSupportedBuild to latestBuild - 2 when omitted/zero', () {
      const cfg = AppUpdateConfig(
        latestVersion: '3.1.0',
        latestBuild: 30,
        minSupportedBuild: 0,
        isCritical: false,
      );
      expect(cfg.effectiveMinSupportedBuild, 28);
      expect(UpdateCheckerService.evaluate(28, cfg), UpdateRequirement.optionalUpdate);
      expect(UpdateCheckerService.evaluate(27, cfg), UpdateRequirement.forceUpdate);
    });
  });
}
