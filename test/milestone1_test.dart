import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_logger/models/app_update_config.dart';
import 'package:fuel_logger/models/fuel_card.dart';
import 'package:fuel_logger/services/update_checker_service.dart';

void main() {
  group('F9 FuelCard Limits & Monthly Auto-Reset', () {
    test('computes remaining balance, usage percentage, and over-limit state', () {
      final card = FuelCard(
        id: 'c1',
        userId: 'u1',
        cardName: 'HPCL Card',
        cardLimit: 5000,
        limitUsed: 1800,
        isPrimary: true,
        resetDayOfMonth: 15,
        lastResetAt: DateTime(2026, 11, 15, 9, 0),
      );

      expect(card.remaining, 3200);
      expect(card.usagePercent, closeTo(0.36, 0.001));
      expect(card.isOverLimit, isFalse);
      expect(card.resetDayOrdinal, '15th');

      final maxed = card.copyWith(limitUsed: 5600);
      expect(maxed.remaining, 0);
      expect(maxed.usagePercent, 1.0);
      expect(maxed.isOverLimit, isTrue);
    });

    test('clamps reset days 29-31 to last day of shorter months (e.g., Feb)', () {
      final card = FuelCard(
        id: 'c2',
        userId: 'u1',
        cardName: 'BPCL Petro',
        cardLimit: 3000,
        limitUsed: 1200,
        resetDayOfMonth: 31,
        lastResetAt: DateTime(2026, 1, 31, 10, 0),
      );

      // Feb 27, 2026 (non-leap year): has not reached Feb 28 yet -> boundary Jan 31
      expect(
        card.needsMonthlyReset(DateTime(2026, 2, 27, 20, 0)),
        isFalse,
      );
      // Feb 28, 2026: reached clamped Feb 28 reset day -> reset needed
      expect(
        card.needsMonthlyReset(DateTime(2026, 2, 28, 8, 0)),
        isTrue,
      );
      expect(
        card.nextResetDate(DateTime(2026, 2, 27)),
        DateTime(2026, 2, 28),
      );
      // Leap year Feb 2024: resets on Feb 29, not Feb 28
      final leapCard = card.copyWith(lastResetAt: DateTime(2024, 1, 31));
      expect(leapCard.needsMonthlyReset(DateTime(2024, 2, 28)), isFalse);
      expect(leapCard.needsMonthlyReset(DateTime(2024, 2, 29)), isTrue);
    });

    test('triggers reset on exact reset day and after missed months without double resetting', () {
      final card = FuelCard(
        id: 'c3',
        userId: 'u1',
        cardName: 'Shell',
        cardLimit: 4000,
        limitUsed: 2500,
        resetDayOfMonth: 10,
        lastResetAt: DateTime(2026, 9, 12, 14, 0),
      );

      // Before Oct 10 -> no reset yet
      expect(card.needsMonthlyReset(DateTime(2026, 10, 9)), isFalse);
      // On Oct 10 -> reset needed
      expect(card.needsMonthlyReset(DateTime(2026, 10, 10, 0, 1)), isTrue);
      // Opened months later -> reset needed
      expect(card.needsMonthlyReset(DateTime(2026, 12, 5)), isTrue);

      // After reset performed on Oct 10 -> does not reset again on Oct 11
      final alreadyReset = card.copyWith(
        limitUsed: 500,
        lastResetAt: DateTime(2026, 10, 10, 9, 30),
      );
      expect(alreadyReset.needsMonthlyReset(DateTime(2026, 10, 11)), isFalse);
    });
  });

  group('F8 UpdateCheckerService 2-Backward-Version & Critical Rules', () {
    test('allows N, N-1, N-2 and forces N-3 when non-critical', () {
      const cfg = AppUpdateConfig(
        latestVersion: '3.1.0',
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
        latestVersion: '3.1.1',
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
        latestVersion: '3.2.0',
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
