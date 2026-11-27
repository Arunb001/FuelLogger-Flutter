import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/service_log.dart';
import '../../providers/garage_provider.dart';
import '../../services/cache_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/metric_tile.dart';
import '../../widgets/mileage_trend_card.dart';

class CalculationsView extends StatefulWidget {
  const CalculationsView({super.key});

  @override
  State<CalculationsView> createState() => _CalculationsViewState();
}

class _CalculationsViewState extends State<CalculationsView> {
  bool _isServiceMode = false;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final garage = context.watch<GarageProvider>();

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
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.local_gas_station_rounded, size: 17),
                        label: Text('Fuel'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.build_rounded, size: 17),
                        label: Text('Service'),
                      ),
                    ],
                    selected: {_isServiceMode},
                    onSelectionChanged: (sel) {
                      HapticFeedback.selectionClick();
                      setState(() => _isServiceMode = sel.first);
                    },
                  ),
                  const SizedBox(height: 16),

                  if (_isServiceMode)
                    _ServiceInsightsSection(garage: garage)
                  else
                    _FuelInsightsSection(garage: garage),
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

class _FuelInsightsSection extends StatelessWidget {
  final GarageProvider garage;

  const _FuelInsightsSection({required this.garage});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final summary = garage.summary;

    final distStr = Formatters.km(summary.totalDistance);
    final avgMStr = Formatters.mileage(summary.avgMileage);
    final costStr = Formatters.currency(summary.totalFuelCost);
    final volStr = Formatters.liters(summary.totalLiters);
    final latestMStr = Formatters.mileage(summary.latestAvgMileage);
    final latestDStr = Formatters.km(summary.latestDistance);
    final bestMStr = Formatters.mileage(summary.bestMileage);
    final lowMStr = Formatters.mileage(summary.lowestMileage);

    return Column(
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

        // 1A: Total Distance | 1B: Total Avg Mileage
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

        // 2A: Total Fuel Cost | 2B: Total Fuel Volume (reordered per P6)
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
                label: 'Total Fuel Volume',
                value: volStr,
                valueColor: c.distanceBlue,
                icon: Icons.water_drop_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 3A: Latest Mileage | 3B: Latest Trip
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

        // 4A: Best Mileage | 4B: Lowest Mileage (reordered per P6)
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Best Mileage',
                value: bestMStr,
                valueColor: c.mileageGreen,
                icon: Icons.star_border,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                label: 'Lowest Mileage',
                value: lowMStr,
                valueColor: c.costAmber,
                icon: Icons.trending_down,
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
      ],
    );
  }
}

class _ServiceInsightsSection extends StatelessWidget {
  final GarageProvider garage;

  const _ServiceInsightsSection({required this.garage});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final logs = garage.serviceLogs;
    final summary = garage.serviceSummary;
    final avgCost = logs.isNotEmpty ? (summary.totalCost / logs.length) : 0.0;

    final nextKmLabel = summary.nextDueKm != null
        ? Formatters.km(summary.nextDueKm!)
        : '-- km';
    final nextKmSub = summary.remainingKm == null
        ? null
        : (summary.remainingKm! <= 0
            ? 'Overdue ${summary.remainingKm!.abs().round()} km'
            : '${summary.remainingKm!.round()} km left');

    final nextDateLabel =
        (summary.nextDueDate != null && summary.nextDueDate!.isNotEmpty)
            ? Formatters.shortDate(summary.nextDueDate!)
            : '--';
    final nextDateSub = summary.remainingDays == null
        ? null
        : (summary.remainingDays! < 0
            ? 'Overdue ${summary.remainingDays!.abs()}d'
            : (summary.remainingDays == 0
                ? 'Due today'
                : '${summary.remainingDays} days left'));

    // Aggregate cost & count by service type
    final Map<String, ({int count, double cost})> byType = {};
    for (final s in logs) {
      final key = s.serviceType.trim().isEmpty ? 'Other' : s.serviceType.trim();
      final prev = byType[key];
      byType[key] = (
        count: (prev?.count ?? 0) + 1,
        cost: (prev?.cost ?? 0.0) + s.totalCost,
      );
    }
    final sortedTypes = byType.entries.toList()
      ..sort((a, b) => b.value.cost.compareTo(a.value.cost));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.build_circle_outlined, color: c.costAmber, size: 20),
            const SizedBox(width: 8),
            Text(
              'Maintenance Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Total Service Cost',
                value: Formatters.currency(summary.totalCost),
                valueColor: c.costAmber,
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                label: 'Last Service Cost',
                value: Formatters.currency(summary.recentCost),
                valueColor: c.distanceBlue,
                icon: Icons.receipt_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Total Services',
                value: '${logs.length}',
                valueColor: c.mileageGreen,
                icon: Icons.history_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                label: 'Avg / Service',
                value: Formatters.currency(avgCost),
                valueColor: c.textPrimary,
                icon: Icons.calculate_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Next Due km',
                value: nextKmLabel,
                subtitle: nextKmSub,
                valueColor: (summary.remainingKm != null && summary.remainingKm! <= 0)
                    ? c.accentPrimary
                    : ((summary.remainingKm != null && summary.remainingKm! <= 500)
                        ? c.costAmber
                        : c.mileageGreen),
                icon: Icons.speed_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                label: 'Next Due Date',
                value: nextDateLabel,
                subtitle: nextDateSub,
                valueColor: (summary.remainingDays != null && summary.remainingDays! < 0)
                    ? c.accentPrimary
                    : ((summary.remainingDays != null && summary.remainingDays! <= 7)
                        ? c.costAmber
                        : c.distanceBlue),
                icon: Icons.event_available_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        _ServiceCostTrendCard(logs: logs),
        const SizedBox(height: 22),

        Row(
          children: [
            Icon(Icons.category_outlined, color: c.distanceBlue, size: 20),
            const SizedBox(width: 8),
            Text(
              'Breakdown by Service Type',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (sortedTypes.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: c.surfaceCard,
              borderRadius: BorderRadius.circular(18),
              border: context.isDarkTheme ? null : Border.all(color: c.subtleBorder),
            ),
            child: Center(
              child: Text(
                'No service records logged for ${garage.activeVehicleName} yet.',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
            ),
          )
        else
          ...sortedTypes.map((entry) {
            final typeName = entry.key;
            final data = entry.value;
            final sharePct = summary.totalCost > 0
                ? (data.cost / summary.totalCost).clamp(0.0, 1.0)
                : 0.0;
            final perVisit = data.count > 0 ? data.cost / data.count : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: c.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: context.isDarkTheme ? null : Border.all(color: c.subtleBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          typeName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${data.count} ${data.count == 1 ? 'visit' : 'visits'} • ${(sharePct * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
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
                      valueColor: AlwaysStoppedAnimation<Color>(c.costAmber),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Total: ${Formatters.currency(data.cost)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: c.costAmber,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Avg: ${Formatters.currency(perVisit)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _ServiceCostTrendCard extends StatelessWidget {
  final List<ServiceLog> logs;

  const _ServiceCostTrendCard({required this.logs});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final ordered = List<ServiceLog>.from(logs.reversed);
    final recent = ordered.length > 8
        ? ordered.sublist(ordered.length - 8)
        : ordered;

    if (recent.length < 2) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: context.isDarkTheme ? null : Border.all(color: c.subtleBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.costAmber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.bar_chart_rounded, color: c.costAmber, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service Spend Trend',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Log at least 2 service records to visualize maintenance spend.',
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    double maxCost = 0;
    for (final s in recent) {
      if (s.totalCost > maxCost) maxCost = s.totalCost;
    }
    final topY = maxCost > 0 ? maxCost * 1.2 : 100.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: c.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: context.isDarkTheme ? null : Border.all(color: c.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service Spend Trend',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            'Last ${recent.length} service visits',
            style: TextStyle(fontSize: 11, color: c.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 155,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: topY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: c.subtleBorder.withOpacity(0.55),
                    strokeWidth: 0.8,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (val, meta) {
                        if (val <= 0 || val == meta.max) return const SizedBox.shrink();
                        return Text(
                          val >= 1000
                              ? '₹${(val / 1000).toStringAsFixed(1)}k'
                              : '₹${val.toInt()}',
                          style: TextStyle(color: c.textMuted, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= recent.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            Formatters.compactDate(recent[idx].serviceDate),
                            style: TextStyle(color: c.textMuted, fontSize: 9.5),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(recent.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: recent[i].totalCost,
                        width: 16,
                        color: c.costAmber,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
