import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/fuel_log.dart';
import '../services/telemetry_engine.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class MileageTrendCard extends StatelessWidget {
  final List<FuelLog> logs;
  final String title;
  final int maxPoints;
  final double chartHeight;

  const MileageTrendCard({
    super.key,
    required this.logs,
    this.title = 'Recent Mileage Trend',
    this.maxPoints = 10,
    this.chartHeight = 148,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final ascLogs = List<FuelLog>.from(logs);
    TelemetryEngine.sortAscending(ascLogs);

    final valid = ascLogs
        .where((l) => !l.isPartial && l.calculatedMileage > 0)
        .toList();
    final recent = valid.length > maxPoints
        ? valid.sublist(valid.length - maxPoints)
        : valid;

    if (recent.length < 2) {
      return Container(
        padding: const EdgeInsets.all(18),
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
                color: c.distanceBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.show_chart_rounded, color: c.distanceBlue, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Log at least 2 full-tank cycles to visualize mileage trends.',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    double minY = recent.first.calculatedMileage;
    double maxY = recent.first.calculatedMileage;
    for (final r in recent) {
      minY = math.min(minY, r.calculatedMileage);
      maxY = math.max(maxY, r.calculatedMileage);
    }
    final paddingY = math.max(1.5, (maxY - minY) * 0.25);
    final chartMinY = math.max(0.0, minY - paddingY);
    final chartMaxY = maxY + paddingY;

    final spots = <FlSpot>[
      for (int i = 0; i < recent.length; i++)
        FlSpot(i.toDouble(), recent[i].calculatedMileage),
    ];

    final latest = recent.last;

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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Last ${recent.length} full-tank cycles',
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.mileageGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  Formatters.mileage(latest.calculatedMileage),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.mileageGreen,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: chartHeight,
            child: LineChart(
              LineChartData(
                minY: chartMinY,
                maxY: chartMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(1.0, (chartMaxY - chartMinY) / 3),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: c.subtleBorder.withOpacity(0.6),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: math.max(1.0, (chartMaxY - chartMinY) / 3),
                      getTitlesWidget: (val, _) => Text(
                        val.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 10,
                          color: c.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: math.max(1, (recent.length / 4).floorToDouble()),
                      getTitlesWidget: (val, _) {
                        final idx = val.round();
                        if (idx < 0 || idx >= recent.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '#${recent[idx].runId}',
                            style: TextStyle(
                              fontSize: 10,
                              color: c.textMuted,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => c.surfaceElevated,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.round().clamp(0, recent.length - 1);
                        final row = recent[idx];
                        return LineTooltipItem(
                          'Entry #${row.runId}\n${row.calculatedMileage.toStringAsFixed(2)} km/l',
                          TextStyle(
                            color: c.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.28,
                    color: c.mileageGreen,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 3.5,
                        color: c.mileageGreen,
                        strokeWidth: 1.5,
                        strokeColor: c.surfaceCard,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          c.mileageGreen.withOpacity(0.24),
                          c.mileageGreen.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
