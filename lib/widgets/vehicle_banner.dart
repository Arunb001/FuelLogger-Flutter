import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vehicle.dart';
import '../providers/garage_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'vehicle_limit_dialog.dart';

class VehicleBanner extends StatelessWidget {
  final VoidCallback? onSettingsTap;

  const VehicleBanner({super.key, this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    final garage = context.watch<GarageProvider>();
    final vehicle = garage.activeVehicle;
    final vName = vehicle?.name ?? 'My Vehicle';
    final colorKey = vehicle?.colorKey ?? 'red';
    final iconKey = vehicle?.iconKey ?? 'bike';

    final gradientColors = AppTheme.vehicleGradients[colorKey] ?? AppTheme.vehicleGradients['red']!;
    final iconData = AppTheme.vehicleIcons[iconKey] ?? Icons.two_wheeler;
    final latestOdo = garage.summary.latestOdometer;
    final subtitleText = latestOdo > 0
        ? '${Formatters.odometer(latestOdo)} • Tap to switch'
        : 'Tap to switch or add vehicle';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(context.isDarkTheme ? 0.32 : 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showSwitchVehicleDialog(context, garage),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.24),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(iconData, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              vName,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 22),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitleText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                if (onSettingsTap != null)
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, color: Colors.white70),
                    tooltip: 'Vehicle Settings',
                    onPressed: onSettingsTap,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddVehicleDialog(BuildContext context, GarageProvider garage) {
    if (!garage.canAddVehicle) {
      VehicleLimitDialog.show(context, limit: garage.maxFreeVehicles);
      return;
    }
    final c = context.appColors;
    final addCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: c.surfaceCard,
          title: Row(
            children: [
              Icon(Icons.add_circle_outline, color: c.mileageGreen, size: 22),
              const SizedBox(width: 8),
              Text('Add New Vehicle', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
            ],
          ),
          content: TextField(
            controller: addCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Vehicle Name',
              hintText: 'e.g. Honda City',
              prefixIcon: Icon(Icons.directions_car, size: 18),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = addCtrl.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx);
                  await garage.addVehicle(name);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: c.mileageGreen,
                foregroundColor: context.isDarkTheme ? Colors.black : Colors.white,
              ),
              child: const Text('Add Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSwitchVehicleDialog(BuildContext context, GarageProvider garage) {
    final c = context.appColors;
    final List<Vehicle> vehicles = garage.vehicles.isNotEmpty
        ? garage.vehicles
        : [
            garage.activeVehicle ??
                Vehicle(id: 'local_primary', userId: '', name: 'My Vehicle', isActive: true, iconKey: 'bike', colorKey: 'red')
          ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: c.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.garage_outlined, color: c.accentPrimary, size: 22),
                  const SizedBox(width: 10),
                  Text('Your Garage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
                ],
              ),
              IconButton(
                icon: Icon(Icons.add_circle, color: c.mileageGreen, size: 24),
                tooltip: 'Add Vehicle',
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAddVehicleDialog(context, garage);
                },
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...vehicles.map((v) {
                    final isSelected = v.id == garage.activeVehicle?.id ||
                        (v.id.isEmpty && v.name == garage.activeVehicleName);
                    final vIcon = AppTheme.vehicleIcons[v.iconKey] ?? Icons.two_wheeler;
                    final vColor = AppTheme.vehiclePrimaryColors[v.colorKey] ?? c.accentPrimary;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? vColor.withOpacity(0.14) : c.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? vColor : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(vIcon, color: isSelected ? vColor : c.textSecondary),
                        title: Text(
                          v.name,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        trailing: isSelected ? Icon(Icons.check_circle, color: vColor, size: 20) : null,
                        onTap: () {
                          garage.switchVehicle(v);
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAddVehicleDialog(context, garage);
                    },
                    icon: Icon(Icons.add_rounded, size: 18, color: c.mileageGreen),
                    label: Text(
                      'Add New Vehicle',
                      style: TextStyle(color: c.mileageGreen, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close', style: TextStyle(color: c.textSecondary)),
            ),
          ],
        );
      },
    );
  }
}
