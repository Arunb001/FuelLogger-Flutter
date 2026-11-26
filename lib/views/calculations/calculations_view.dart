import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/garage_provider.dart';
import '../../services/cache_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/metric_tile.dart';
import '../../widgets/mileage_trend_card.dart';

class CalculationsView extends StatelessWidget {
  const CalculationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final garage = context.watch<GarageProvider>();
    final summary = garage.summary;

    final distStr = Formatters.km(summary.totalDistance);
    final avgMStr = Formatters.mileage(summary.avgMileage);
    final costStr = Formatters.currency(summary.totalFuelCost);
    final bestMStr = Formatters.mileage(summary.bestMileage);
    final latestMStr = Formatters.mileage(summary.latestAvgMileage);
    final latestDStr = Formatters.km(summary.latestDistance);
    final lowMStr = Formatters.mileage(summary.lowestMileage);
    final volStr = Formatters.liters(summary.totalLiters);

    return Scaffold(
      appBar: AppBar(
        title: Text('Insights — ${garage.activeVehicleName}'),
      ),
      body: RefreshIndicator(
        onRefresh: () => garage.loadGarage(),
        color: c.accentPrimary,
        backgroundColor: c.surfaceCard,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics_outlined, color: c.accentPrimary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Overall Telemetry',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Total Distance',
                          value: distStr,
                          valueColor: c.distanceBlue,
                          icon: Icons.timeline,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MetricTile(
                          label: 'Total Avg Mileage',
                          value: avgMStr,
                          valueColor: c.mileageGreen,
                          icon: Icons.speed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Total Fuel Cost',
                          value: costStr,
                          valueColor: c.costAmber,
                          icon: Icons.currency_rupee,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MetricTile(
                          label: 'Best Mileage',
                          value: bestMStr,
                          valueColor: c.mileageGreen,
                          icon: Icons.star_border,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Latest Mileage',
                          value: latestMStr,
                          valueColor: c.mileageGreen,
                          icon: Icons.bolt,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MetricTile(
                          label: 'Latest Trip',
                          value: latestDStr,
                          valueColor: c.distanceBlue,
                          icon: Icons.near_me,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Lowest Mileage',
                          value: lowMStr,
                          valueColor: c.costAmber,
                          icon: Icons.trending_down,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MetricTile(
                          label: 'Total Fuel Volume',
                          value: volStr,
                          valueColor: c.distanceBlue,
                          icon: Icons.water_drop_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  MileageTrendCard(
                    logs: garage.fuelLogs,
                    title: 'Mileage Performance Trend',
                    maxPoints: 16,
                    chartHeight: 175,
                  ),
                  const SizedBox(height: 22),

                  Row(
                    children: [
                      Icon(Icons.local_gas_station, color: c.costAmber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Breakdown by Fuel Type',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (summary.byFuelType.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                      decoration: BoxDecoration(
                        color: c.surfaceCard,
                        borderRadius: BorderRadius.circular(18),
                        border: context.isDarkTheme ? null : Border.all(color: c.subtleBorder),
                      ),
                      child: Center(
                        child: Text(
                          'No fill-up logs recorded for ${garage.activeVehicleName} yet.',
                          style: TextStyle(color: c.textSecondary, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...summary.byFuelType.entries.map((entry) {
                      final ftName = entry.key;
                      final f = entry.value;

                      final fDist = Formatters.km(f.distance);
                      final fAvg = Formatters.mileage(f.avgMileage);
                      final fCost = Formatters.currency(f.totalCost);
                      final fVol = Formatters.liters(f.totalLiters);
                      final fBest = Formatters.mileage(f.bestMileage);
                      final fLow = Formatters.mileage(f.lowestMileage);

                      final fuelHex = CacheService.getFuelColorHex(ftName);
                      final fuelColor = AppTheme.hexToColor(fuelHex);
                      final sharePct = summary.totalFuelCost > 0
                          ? (f.totalCost / summary.totalFuelCost).clamp(0.0, 1.0)
                          : 0.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.surfaceCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: fuelColor.withOpacity(0.55), width: 1.4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(color: fuelColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ftName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(sharePct * 100).round()}% spend',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: sharePct,
                                minHeight: 5,
                                backgroundColor: c.surfaceElevated,
                                valueColor: AlwaysStoppedAnimation<Color>(fuelColor),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: MetricTile(label: 'Distance Driven', value: fDist, valueColor: c.distanceBlue),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: MetricTile(label: 'Avg Mileage', value: fAvg, valueColor: c.mileageGreen),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: MetricTile(label: 'Fuel Cost', value: fCost, valueColor: c.costAmber),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: MetricTile(label: 'Total Volume', value: fVol, valueColor: c.distanceBlue),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: MetricTile(label: 'Best Mileage', value: fBest, valueColor: c.mileageGreen),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: MetricTile(label: 'Lowest Mileage', value: fLow, valueColor: c.costAmber),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
