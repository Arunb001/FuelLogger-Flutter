import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/metric_tile.dart';

class CalculationsView extends StatelessWidget {
  const CalculationsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final garage = context.watch<GarageProvider>();
    final summary = garage.summary;

    final distStr = summary.totalDistance > 0 ? '${summary.totalDistance.toInt()} km' : '-- km';
    final avgMStr = summary.avgMileage > 0 ? '${summary.avgMileage} km/l' : '-- km/l';
    final costStr = summary.totalFuelCost > 0 ? '₹${summary.totalFuelCost.toInt()}' : '₹ --';
    final bestMStr = summary.bestMileage > 0 ? '${summary.bestMileage} km/l' : '-- km/l';
    final latestMStr = summary.latestAvgMileage > 0 ? '${summary.latestAvgMileage} km/l' : '-- km/l';
    final latestDStr = summary.latestDistance > 0 ? '${summary.latestDistance.toInt()} km' : '-- km';
    final lowMStr = summary.lowestMileage > 0 ? '${summary.lowestMileage} km/l' : '-- km/l';
    final volStr = summary.totalLiters > 0 ? '${summary.totalLiters.toStringAsFixed(1)} L' : '-- L';

    return Scaffold(
      appBar: AppBar(
        title: Text('Calculations — ${garage.activeVehicleName}'),
      ),
      body: RefreshIndicator(
        onRefresh: () => garage.loadGarage(),
        color: AppTheme.primary,
        backgroundColor: AppTheme.cardBg,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Overall Section Header
              Row(
                children: const [
                  Icon(Icons.analytics_outlined, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Overall Telemetry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),

              // Grid Row 1
              Row(
                children: [
                  Expanded(child: MetricTile(label: 'Total Distance', value: distStr, valueColor: AppTheme.distanceBlue, icon: Icons.timeline)),
                  const SizedBox(width: 10),
                  Expanded(child: MetricTile(label: 'Total Avg Mileage', value: avgMStr, valueColor: AppTheme.mileageGreen, icon: Icons.speed)),
                ],
              ),
              const SizedBox(height: 10),

              // Grid Row 2
              Row(
                children: [
                  Expanded(child: MetricTile(label: 'Total Fuel Cost', value: costStr, valueColor: AppTheme.costAmber, icon: Icons.currency_rupee)),
                  const SizedBox(width: 10),
                  Expanded(child: MetricTile(label: 'Best Mileage', value: bestMStr, valueColor: AppTheme.mileageGreen, icon: Icons.star_border)),
                ],
              ),
              const SizedBox(height: 10),

              // Grid Row 3
              Row(
                children: [
                  Expanded(child: MetricTile(label: 'Latest Avg Mileage', value: latestMStr, valueColor: AppTheme.mileageGreen, icon: Icons.bolt)),
                  const SizedBox(width: 10),
                  Expanded(child: MetricTile(label: 'Latest Distance', value: latestDStr, valueColor: AppTheme.distanceBlue, icon: Icons.near_me)),
                ],
              ),
              const SizedBox(height: 10),

              // Grid Row 4
              Row(
                children: [
                  Expanded(child: MetricTile(label: 'Lowest Mileage', value: lowMStr, valueColor: Colors.orangeAccent, icon: Icons.trending_down)),
                  const SizedBox(width: 10),
                  Expanded(child: MetricTile(label: 'Total Fuel Volume', value: volStr, valueColor: AppTheme.distanceBlue, icon: Icons.water_drop)),
                ],
              ),
              const SizedBox(height: 24),

              // Breakdown by Fuel Type
              Row(
                children: const [
                  Icon(Icons.local_gas_station, color: AppTheme.costAmber, size: 20),
                  SizedBox(width: 8),
                  Text('Breakdown by Fuel Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),

              if (summary.byFuelType.isEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Center(
                      child: Text(
                        'No fill-up logs recorded for ${garage.activeVehicleName} yet.',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                ...summary.byFuelType.entries.map((entry) {
                  final ftName = entry.key;
                  final f = entry.value;

                  final fDist = f.distance > 0 ? '${f.distance.toInt()} km' : '-- km';
                  final fAvg = f.avgMileage > 0 ? '${f.avgMileage} km/l' : '-- km/l';
                  final fCost = f.totalCost > 0 ? '₹${f.totalCost.toInt()}' : '₹ --';
                  final fVol = f.totalLiters > 0 ? '${f.totalLiters.toStringAsFixed(1)} L' : '-- L';
                  final fBest = f.bestMileage > 0 ? '${f.bestMileage} km/l' : '-- km/l';
                  final fLow = f.lowestMileage > 0 ? '${f.lowestMileage} km/l' : '-- km/l';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(ftName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: MetricTile(label: 'Distance Driven', value: fDist, valueColor: AppTheme.distanceBlue)),
                              const SizedBox(width: 8),
                              Expanded(child: MetricTile(label: 'Avg Mileage', value: fAvg, valueColor: AppTheme.mileageGreen)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: MetricTile(label: 'Fuel Cost', value: fCost, valueColor: AppTheme.costAmber)),
                              const SizedBox(width: 8),
                              Expanded(child: MetricTile(label: 'Total Volume', value: fVol, valueColor: AppTheme.distanceBlue)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: MetricTile(label: 'Best Mileage', value: fBest, valueColor: AppTheme.mileageGreen)),
                              const SizedBox(width: 8),
                              Expanded(child: MetricTile(label: 'Lowest Mileage', value: fLow, valueColor: Colors.orangeAccent)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
