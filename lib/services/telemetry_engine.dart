import '../models/fuel_log.dart';
import '../models/telemetry_summary.dart';

class TelemetryEngine {
  /// Recalculates full cycle telemetry for all logs in chronological order.
  /// Follows the forward-linking engine:
  /// - Row i's `to_odometer` is populated from the next closing full fill's `from_odometer`.
  /// - `distance_traveled` = `to_odometer - from_odometer`.
  /// - `fuel_consumed` is the next fill's `liters_to_fill` (plus any intermediate partial fills),
  ///   representing the exact volume burned to travel that distance.
  /// - `calculated_mileage` = `distance_traveled / fuel_consumed`.
  /// - `cost_per_km` = `cost_per_ltr / calculated_mileage`.
  /// - The latest active fill (currently in the vehicle's tank) keeps `to_odometer = 0`,
  ///   `distance_traveled = 0.0`, `fuel_consumed = 0.0`, and `calculated_mileage = 0.0`.
  static List<FuelLog> recalculateCycles(List<FuelLog> logs) {
    if (logs.isEmpty) return [];

    // Sort ascending chronologically (date ASC, runId ASC, P before F, createdAt ASC)
    final sorted = List<FuelLog>.from(logs);
    sorted.sort((a, b) {
      final dCmp = a.date.compareTo(b.date);
      if (dCmp != 0) return dCmp;
      final rCmp = a.runId.compareTo(b.runId);
      if (rCmp != 0) return rCmp;
      if (a.isPartial && !b.isPartial) return -1;
      if (!a.isPartial && b.isPartial) return 1;
      if (a.createdAt != null && b.createdAt != null) {
        return a.createdAt!.compareTo(b.createdAt!);
      }
      return 0;
    });

    final List<FuelLog> recalculated = [];

    for (int i = 0; i < sorted.length; i++) {
      final row = sorted[i];
      final flag = row.fuelFillFlag.toUpperCase().trim();
      final fromOdo = row.fromOdometer;
      final cost = row.fuelCost;
      final liters = row.litersToFill;
      final cpl = liters > 0 ? double.parse((cost / liters).toStringAsFixed(2)) : 0.0;

      if (flag == 'P') {
        // Partial Fill ('P'): Derived telemetry columns are strictly 0.0
        recalculated.add(row.copyWith(
          fuelFillFlag: 'P',
          costPerLtr: cpl,
          fromOdometer: fromOdo,
          toOdometer: 0.0,
          distanceTraveled: 0.0,
          fuelConsumed: 0.0,
          calculatedMileage: 0.0,
          costPerKm: 0.0,
        ));
        continue;
      }

      // Full Fill ('F'): Look ahead for the next closing full fill
      int? nextFullIdx;
      for (int n = i + 1; n < sorted.length; n++) {
        final nFlag = sorted[n].fuelFillFlag.toUpperCase().trim();
        final nOdo = sorted[n].fromOdometer;
        if (nFlag != 'P' && nOdo > 0) {
          nextFullIdx = n;
          break;
        }
      }

      if (nextFullIdx != null) {
        final nextRow = sorted[nextFullIdx];
        final nextOdo = nextRow.fromOdometer;
        final toOdometer = nextOdo;

        // Sum all fuel pumped into tank between this fill and closing full fill
        double fuelCons = 0.0;
        for (int k = i + 1; k <= nextFullIdx; k++) {
          fuelCons += sorted[k].litersToFill;
        }
        fuelCons = double.parse(fuelCons.toStringAsFixed(2));

        final dist = (toOdometer > fromOdo && fromOdo > 0)
            ? double.parse((toOdometer - fromOdo).toStringAsFixed(2))
            : 0.0;
        final bool isBreak = (dist > 2000) || (dist <= 0) || (fuelCons > 0 && (dist / fuelCons) > 90);

        if (isBreak || dist <= 0 || fuelCons <= 0) {
          recalculated.add(row.copyWith(
            fuelFillFlag: 'F',
            costPerLtr: cpl,
            toOdometer: toOdometer,
            distanceTraveled: isBreak ? 0.0 : dist,
            fuelConsumed: fuelCons,
            calculatedMileage: 0.0,
            costPerKm: 0.0,
          ));
        } else {
          final mileage = double.parse((dist / fuelCons).toStringAsFixed(2));
          final costKm = (mileage > 0 && cpl > 0)
              ? double.parse((cpl / mileage).toStringAsFixed(2))
              : 0.0;

          recalculated.add(row.copyWith(
            fuelFillFlag: 'F',
            costPerLtr: cpl,
            toOdometer: toOdometer,
            distanceTraveled: dist,
            fuelConsumed: fuelCons,
            calculatedMileage: mileage,
            costPerKm: costKm,
          ));
        }
      } else {
        // Latest open fill: Active fuel burning in tank; subsequent fill not yet recorded
        recalculated.add(row.copyWith(
          fuelFillFlag: 'F',
          costPerLtr: cpl,
          toOdometer: 0.0,
          distanceTraveled: 0.0,
          fuelConsumed: 0.0,
          calculatedMileage: 0.0,
          costPerKm: 0.0,
        ));
      }
    }

    return recalculated;
  }

  /// Computes aggregate summary statistics and fuel breakdown.
  static TelemetrySummary computeSummary(List<FuelLog> rawLogs) {
    if (rawLogs.isEmpty) return TelemetrySummary.empty();

    final logs = recalculateCycles(rawLogs);

    double totalDist = 0.0;
    double totalCost = 0.0;
    double totalLiters = 0.0;
    final List<double> validMileages = [];
    double latestMileage = 0.0;
    double latestDist = 0.0;
    double latestOdo = 0.0;
    int maxSno = 0;
    int lastSno = 0;

    final Map<String, _FuelTypeAccumulator> fuelMap = {};

    for (final row in logs) {
      if (row.runId > maxSno) maxSno = row.runId;
      if (row.runId > 0) lastSno = row.runId;

      if (row.fromOdometer > latestOdo) latestOdo = row.fromOdometer;
      if (row.toOdometer > latestOdo) latestOdo = row.toOdometer;

      totalCost += row.fuelCost;
      totalLiters += row.litersToFill;

      final ft = row.fuelType.isEmpty ? 'XP95' : row.fuelType;
      fuelMap.putIfAbsent(ft, () => _FuelTypeAccumulator(ft));
      fuelMap[ft]!.cost += row.fuelCost;
      fuelMap[ft]!.liters += row.litersToFill;

      if (!row.isPartial && row.distanceTraveled > 0) {
        totalDist += row.distanceTraveled;
        fuelMap[ft]!.distance += row.distanceTraveled;

        if (row.calculatedMileage > 0) {
          validMileages.add(row.calculatedMileage);
          fuelMap[ft]!.mileages.add(row.calculatedMileage);
          latestMileage = row.calculatedMileage;
          latestDist = row.distanceTraveled;
        }
      }
    }

    final double avgMileage = validMileages.isNotEmpty
        ? double.parse((validMileages.reduce((a, b) => a + b) / validMileages.length).toStringAsFixed(2))
        : 0.0;

    final double bestMileage = validMileages.isNotEmpty
        ? validMileages.reduce((a, b) => a > b ? a : b)
        : 0.0;

    final double lowestMileage = validMileages.isNotEmpty
        ? validMileages.reduce((a, b) => a < b ? a : b)
        : 0.0;

    final Map<String, FuelTypeMetrics> byFuelType = {};
    fuelMap.forEach((k, acc) {
      final double fAvg = acc.mileages.isNotEmpty
          ? double.parse((acc.mileages.reduce((a, b) => a + b) / acc.mileages.length).toStringAsFixed(2))
          : 0.0;
      final double fBest = acc.mileages.isNotEmpty ? acc.mileages.reduce((a, b) => a > b ? a : b) : 0.0;
      final double fLow = acc.mileages.isNotEmpty ? acc.mileages.reduce((a, b) => a < b ? a : b) : 0.0;

      byFuelType[k] = FuelTypeMetrics(
        fuelType: k,
        distance: acc.distance,
        totalCost: acc.cost,
        totalLiters: acc.liters,
        avgMileage: fAvg,
        bestMileage: fBest,
        lowestMileage: fLow,
        count: acc.mileages.length,
      );
    });

    // Calculate active run ID:
    // A run ID only advances after a full tank fill has closed the cycle.
    // If the last fill was partial, the run ID remains the same until closed by a full tank fill.
    int activeRunId = 1;
    bool isCycleOpen = false;

    if (logs.isNotEmpty) {
      final lastLog = logs.last;
      isCycleOpen = lastLog.isPartial;
      if (isCycleOpen) {
        activeRunId = lastLog.runId;
      } else {
        activeRunId = maxSno + 1;
      }
    }

    return TelemetrySummary(
      totalDistance: totalDist,
      avgMileage: avgMileage,
      totalFuelCost: totalCost,
      totalLiters: totalLiters,
      bestMileage: bestMileage,
      lowestMileage: lowestMileage,
      latestAvgMileage: latestMileage,
      latestDistance: latestDist,
      nextSno: activeRunId,
      lastSno: lastSno,
      isCycleOpen: isCycleOpen,
      totalEntries: logs.length,
      latestOdometer: latestOdo,
      byFuelType: byFuelType,
    );
  }
}

class _FuelTypeAccumulator {
  final String name;
  double distance = 0.0;
  double cost = 0.0;
  double liters = 0.0;
  final List<double> mileages = [];

  _FuelTypeAccumulator(this.name);
}
