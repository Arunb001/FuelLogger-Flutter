import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/garage_provider.dart';
import '../theme/app_theme.dart';
import '../models/vehicle.dart';

class VehicleBanner extends StatelessWidget {
  final VoidCallback onSettingsTap;

  const VehicleBanner({Key? key, required this.onSettingsTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final garage = context.watch<GarageProvider>();
    final vehicle = garage.activeVehicle;
    final vName = vehicle?.name ?? 'My Vehicle';
    final colorKey = vehicle?.colorKey ?? 'red';
    final iconKey = vehicle?.iconKey ?? 'bike';

    final gradientColors = AppTheme.vehicleGradients[colorKey] ?? AppTheme.vehicleGradients['red']!;
    final iconData = AppTheme.vehicleIcons[iconKey] ?? Icons.two_wheeler;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showSwitchVehicleDialog(context, garage),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              vName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 20),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tap to switch vehicle • Garage',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white70),
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
    final addCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Row(
            children: const [
              Icon(Icons.add_circle_outline, color: AppTheme.mileageGreen, size: 22),
              SizedBox(width: 8),
              Text('Add New Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: TextField(
            controller: addCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Vehicle Name',
              hintText: 'e.g. Honda City',
              prefixIcon: Icon(Icons.directions_car, size: 18),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
                backgroundColor: AppTheme.mileageGreen,
                foregroundColor: Colors.black,
              ),
              child: const Text('Add Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSwitchVehicleDialog(BuildContext context, GarageProvider garage) {
    final List<Vehicle> vehicles = garage.vehicles.isNotEmpty
        ? garage.vehicles
        : [
            garage.activeVehicle ??
                Vehicle(id: 'local_primary', userId: '', name: 'My Vehicle', iconKey: 'bike', colorKey: 'red')
          ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.directions_car, color: AppTheme.primary, size: 22),
                  SizedBox(width: 10),
                  Text('Switch Vehicle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppTheme.mileageGreen, size: 24),
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
                    final vColor = AppTheme.vehiclePrimaryColors[v.colorKey] ?? AppTheme.primary;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? vColor.withOpacity(0.18) : AppTheme.surfaceHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? vColor : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(vIcon, color: isSelected ? vColor : Colors.white70),
                        title: Text(
                          v.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                    icon: const Icon(Icons.add, size: 16, color: AppTheme.mileageGreen),
                    label: const Text('+ Add New Vehicle', style: TextStyle(color: AppTheme.mileageGreen, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }
}
