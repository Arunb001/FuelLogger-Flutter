import '../models/fuel_log.dart';
import '../models/telemetry_summary.dart';

class TelemetryEngine {
  /// Recalculates full cycle telemetry for all logs in chronological order.
  static List<FuelLog> recalculateCycles(List<FuelLog> logs) {
    if (logs.isEmpty) return [];

    // Sort ascending by runId, then by flag (P before F)
    final sorted = List<FuelLog>.from(logs);
    sorted.sort((a, b) {
      final rCmp = a.runId.compareTo(b.runId);
      if (rCmp != 0) return rCmp;
      if (a.isPartial && !b.isPartial) return -1;
      if (!a.isPartial && b.isPartial) return 1;
      return a.date.compareTo(b.date);
    });

    final List<FuelLog> recalculated = [];
    int cycleStartOdo = 0;
    double cycleAccumLiters = 0.0;
    double cycleAccumCost = 0.0;
    bool inCycle = false;

    for (int i = 0; i < sorted.length; i++) {
      final row = sorted[i];
      final flag = row.fuelFillFlag.toUpperCase();
      final odo = row.fromOdometer;
      final liters = row.litersToFill;
      final cost = row.fuelCost;
      final cpl = liters > 0 ? double.parse((cost / liters).toStringAsFixed(2)) : 0.0;

      if (!inCycle) {
        cycleStartOdo = odo;
        cycleAccumLiters = 0.0;
        cycleAccumCost = 0.0;
        inCycle = true;
      }

      cycleAccumLiters += liters;
      cycleAccumCost += cost;

      if (flag == 'P') {
        // Partial fill: Telemetry columns are strictly 0.0 until cycle is closed by a Full fill
        recalculated.add(FuelLog(
          id: row.id,
          userId: row.userId,
          vehicleId: row.vehicleId,
          runId: row.runId,
          date: row.date,
          fuelType: row.fuelType,
          fuelDensity: row.fuelDensity,
          fuelCost: cost,
          litersToFill: liters,
          costPerLtr: cpl,
          fromOdometer: row.fromOdometer,
          toOdometer: 0,
          distanceTraveled: 0.0,
          fuelConsumed: 0.0,
          calculatedMileage: 0.0,
          costPerKm: 0.0,
          fuelFillFlag: 'P',
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        ));
      } else {
        // Full fill: Closes the cycle and computes complete derived metrics
        final dist = (odo > cycleStartOdo && i > 0) ? (odo - cycleStartOdo).toDouble() : 0.0;
        final mileage = (dist > 0 && cycleAccumLiters > 0)
            ? double.parse((dist / cycleAccumLiters).toStringAsFixed(2))
            : 0.0;
        final cpk = (dist > 0 && cycleAccumCost > 0)
            ? double.parse((cycleAccumCost / dist).toStringAsFixed(2))
            : 0.0;

        recalculated.add(FuelLog(
          id: row.id,
          userId: row.userId,
          vehicleId: row.vehicleId,
          runId: row.runId,
          date: row.date,
          fuelType: row.fuelType,
          fuelDensity: row.fuelDensity,
          fuelCost: cost,
          litersToFill: liters,
          costPerLtr: cpl,
          fromOdometer: row.fromOdometer,
          toOdometer: cycleStartOdo,
          distanceTraveled: dist,
          fuelConsumed: double.parse(cycleAccumLiters.toStringAsFixed(2)),
          calculatedMileage: mileage,
          costPerKm: cpk,
          fuelFillFlag: 'F',
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        ));

        // Reset cycle baseline for subsequent fill-up cycle
        cycleStartOdo = odo;
        cycleAccumLiters = 0.0;
        cycleAccumCost = 0.0;
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
    int latestOdo = 0;
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

    return TelemetrySummary(
      totalDistance: totalDist,
      avgMileage: avgMileage,
      totalFuelCost: totalCost,
      totalLiters: totalLiters,
      bestMileage: bestMileage,
      lowestMileage: lowestMileage,
      latestAvgMileage: latestMileage,
      latestDistance: latestDist,
      nextSno: maxSno + 1,
      lastSno: lastSno,
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
