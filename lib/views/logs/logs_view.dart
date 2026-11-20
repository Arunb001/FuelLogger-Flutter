import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/fuel_log.dart';
import '../../widgets/custom_snackbar.dart';
import '../upload/upload_view.dart';

class LogsView extends StatelessWidget {
  const LogsView({Key? key}) : super(key: key);

  void _showDeleteDialog(BuildContext context, FuelLog log) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Row(
            children: const [
              Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
              SizedBox(width: 8),
              Text('Delete Log?', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Delete Run #${log.runId} (${log.date}, ${log.litersToFill}L)? Subsequent odometer intervals will automatically recalculate.',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await context.read<GarageProvider>().deleteFuelLog(log.id);
                if (context.mounted) {
                  if (ok) {
                    showCustomSnackBar(context, 'Run #${log.runId} deleted.');
                  } else {
                    showCustomSnackBar(context, 'Failed to delete log.', isError: true);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, FuelLog log) {
    final costCtrl = TextEditingController(text: log.fuelCost.toString());
    final litersCtrl = TextEditingController(text: log.litersToFill.toString());
    final odoCtrl = TextEditingController(text: log.fromOdometer.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Text('Edit Run #${log.runId}', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Total Cost (₹)', prefixIcon: Icon(Icons.currency_rupee, size: 18)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: litersCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Litres Filled', prefixIcon: Icon(Icons.water_drop, size: 18)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: odoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Odometer (km)', prefixIcon: Icon(Icons.speed, size: 18)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                final newCost = double.tryParse(costCtrl.text.trim()) ?? log.fuelCost;
                final newLiters = double.tryParse(litersCtrl.text.trim()) ?? log.litersToFill;
                final newOdo = int.tryParse(odoCtrl.text.trim()) ?? log.fromOdometer;

                Navigator.pop(ctx);
                final ok = await context.read<GarageProvider>().updateFuelLog(log.id, {
                  'fuel_cost': newCost,
                  'liters_to_fill': newLiters,
                  'from_odometer': newOdo,
                });

                if (context.mounted) {
                  if (ok) {
                    showCustomSnackBar(context, 'Run #${log.runId} updated and recalculated!');
                  } else {
                    showCustomSnackBar(context, 'Failed to update log.', isError: true);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final garage = context.watch<GarageProvider>();
    final logs = garage.fuelLogs;

    return Scaffold(
      appBar: AppBar(
        title: Text('Logs — ${garage.activeVehicleName}'),
      ),
      body: RefreshIndicator(
        onRefresh: () => garage.loadGarage(),
        color: AppTheme.primary,
        backgroundColor: AppTheme.cardBg,
        child: logs.isEmpty
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No Fill-Up Logs Recorded', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        'No logs have been recorded for \'${garage.activeVehicleName}\' yet.\nLog your first fill-up to track your fuel!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadView()));
                        },
                        icon: const Icon(Icons.local_gas_station, size: 18, color: Colors.white),
                        label: const Text(
                          'Log First Fill-Up',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Header (Run #, Date, Partial badge, Actions)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Run #${log.runId}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  if (log.isPartial)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.orange, width: 0.8),
                                      ),
                                      child: const Text('PARTIAL', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(log.date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _showEditDialog(context, log),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _showDeleteDialog(context, log),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 16, color: AppTheme.borderColor),

                          // Row 2: Metrics (Cost, Litres, Odometer, Fuel Type)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Fuel Cost', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text('₹${log.fuelCost.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.costAmber)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Volume', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text('${log.litersToFill} L', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.distanceBlue)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Odometer', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text('${log.fromOdometer} km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Fuel Type', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(log.fuelType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white70)),
                                ],
                              ),
                            ],
                          ),

                          // Row 3: Derived Telemetry Chips (Mileage, Distance, Cost/km)
                          if (!log.isPartial && log.calculatedMileage > 0) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildTelemetryChip(
                                  label: '${log.calculatedMileage.toStringAsFixed(2)} km/l',
                                  color: AppTheme.mileageGreen,
                                  icon: Icons.speed,
                                ),
                                const SizedBox(width: 8),
                                _buildTelemetryChip(
                                  label: '+${log.distanceTraveled.toInt()} km',
                                  color: AppTheme.distanceBlue,
                                  icon: Icons.trending_up,
                                ),
                                const SizedBox(width: 8),
                                _buildTelemetryChip(
                                  label: '₹${log.costPerKm.toStringAsFixed(2)}/km',
                                  color: AppTheme.costAmber,
                                  icon: Icons.currency_rupee,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildTelemetryChip({required String label, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
