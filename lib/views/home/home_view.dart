import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/garage_provider.dart';
import '../../config/env.dart';
import '../../theme/app_theme.dart';
import '../../widgets/vehicle_banner.dart';
import '../../widgets/metric_tile.dart';
import '../upload/upload_view.dart';
import '../calculations/calculations_view.dart';
import '../logs/logs_view.dart';
import '../settings/settings_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GarageProvider>().loadGarage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final garage = context.watch<GarageProvider>();
    final summary = garage.summary;

    final avgMileageStr = summary.avgMileage > 0 ? '${summary.avgMileage} km/l' : '-- km/l';
    final totalKmStr = summary.totalDistance > 0 ? '${summary.totalDistance.toInt()} km' : '-- km';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.local_gas_station, color: AppTheme.primary, size: 22),
            const SizedBox(width: 8),
            Text(AppConfig.appName),
            if (AppConfig.isDev) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.costAmber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.costAmber, width: 0.8),
                ),
                child: const Text('DEV', style: TextStyle(color: AppTheme.costAmber, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => garage.loadGarage(),
        color: AppTheme.primary,
        backgroundColor: AppTheme.cardBg,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: Vehicle Banner
              VehicleBanner(
                onSettingsTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsView()));
                },
              ),
              const SizedBox(height: 16),

              // Row 2: 2-Tile Performance Metrics
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Total Avg Mileage',
                      value: avgMileageStr,
                      valueColor: AppTheme.mileageGreen,
                      icon: Icons.speed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricTile(
                      label: 'Total Driven KMs',
                      value: totalKmStr,
                      valueColor: AppTheme.distanceBlue,
                      icon: Icons.timeline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Row 3: Action Navigation Cards
              _buildNavCard(
                icon: Icons.local_gas_station,
                iconColor: AppTheme.primary,
                title: 'Log New Fill-Up',
                subtitle: 'Record litres, price, density & odometer',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadView()));
                },
              ),
              const SizedBox(height: 12),

              _buildNavCard(
                icon: Icons.insert_chart_outlined,
                iconColor: AppTheme.distanceBlue,
                title: 'View Calculations',
                subtitle: 'Stats & breakdown by fuel type',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CalculationsView()));
                },
              ),
              const SizedBox(height: 12),

              _buildNavCard(
                icon: Icons.receipt_long,
                iconColor: AppTheme.costAmber,
                title: 'Manage Logs',
                subtitle: 'View inputs, edit mistakes or delete logs',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LogsView()));
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
