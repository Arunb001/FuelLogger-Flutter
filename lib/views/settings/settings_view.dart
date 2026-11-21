import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/garage_provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/version.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';
import '../../services/cache_service.dart';
import '../../models/fuel_log.dart';
import '../auth/login_view.dart';
import '../logs/csv_import_sheet.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({Key? key}) : super(key: key);

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _renameController = TextEditingController();
  final _addVehicleController = TextEditingController();
  final _addFuelTypeController = TextEditingController();

  String _selectedIcon = 'bike';
  String _selectedColor = 'red';

  @override
  void initState() {
    super.initState();
    final garage = context.read<GarageProvider>();
    _renameController.text = garage.activeVehicleName;
    _selectedIcon = garage.activeVehicle?.iconKey ?? 'bike';
    _selectedColor = garage.activeVehicle?.colorKey ?? 'red';
  }

  @override
  void dispose() {
    _renameController.dispose();
    _addVehicleController.dispose();
    _addFuelTypeController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomization() async {
    final garage = context.read<GarageProvider>();
    final newName = _renameController.text.trim();

    if (newName.isNotEmpty) {
      await garage.renameActiveVehicle(newName);
    }

    await garage.updateCustomization(iconKey: _selectedIcon, colorKey: _selectedColor);

    if (mounted) {
      _renameController.text = garage.activeVehicleName;
      showCustomSnackBar(context, 'Vehicle customization saved!');
    }
  }

  Future<void> _addNewVehicle() async {
    final name = _addVehicleController.text.trim();
    if (name.isEmpty) return;

    final garage = context.read<GarageProvider>();
    final ok = await garage.addVehicle(name);
    if (!mounted) return;

    if (ok) {
      _addVehicleController.clear();
      _renameController.text = garage.activeVehicleName;
      setState(() {
        _selectedIcon = garage.activeVehicle?.iconKey ?? 'bike';
        _selectedColor = garage.activeVehicle?.colorKey ?? 'red';
      });
      showCustomSnackBar(context, 'New vehicle \'$name\' created!');
    } else {
      showCustomSnackBar(context, 'Failed to create vehicle.', isError: true);
    }
  }

  void _showDeleteVehicleDialog() {
    final garage = context.read<GarageProvider>();
    if (garage.vehicles.length <= 1) {
      showCustomSnackBar(context, 'Garage safeguard: You must have at least 1 vehicle.', isError: true);
      return;
    }

    final target = garage.activeVehicle;
    if (target == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('Delete Vehicle?', style: TextStyle(color: Colors.redAccent)),
          content: Text('Permanently delete \'${target.name}\' and all its fill-up logs? This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await garage.deleteVehicle(target);
                if (mounted && ok) {
                  _renameController.text = garage.activeVehicleName;
                  showCustomSnackBar(context, 'Vehicle deleted.');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Permanently', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSetPasswordDialog() {
    final pwCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Row(
            children: const [
              Icon(Icons.key, color: AppTheme.costAmber, size: 22),
              SizedBox(width: 8),
              Text('Set Account Password', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Set a password to sign in on any device without checking your email inbox.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pwCtrl,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'New Password', hintText: 'Min 6 characters'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                final pw = pwCtrl.text.trim();
                if (pw.length < 6) {
                  showCustomSnackBar(context, 'Password must be at least 6 characters.', isError: true);
                  return;
                }
                Navigator.pop(ctx);
                final ok = await context.read<AuthProvider>().updatePassword(pw);
                if (mounted) {
                  if (ok) {
                    showCustomSnackBar(context, 'Password updated successfully!');
                  } else {
                    showCustomSnackBar(context, 'Failed to update password.', isError: true);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to sign out of Fuel Logger?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await context.read<AuthProvider>().signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginView()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showFuelColorPicker(BuildContext context, String fuelType, GarageProvider garage) {
    final currentColorHex = CacheService.getFuelColorHex(fuelType);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.hexToColor(currentColorHex),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text('Color for \'$fuelType\'', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tap any color circle below to apply:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: CacheService.fuelColorPalette.map((hex) {
                  final isSel = hex.toLowerCase() == currentColorHex.toLowerCase();
                  final c = AppTheme.hexToColor(hex);
                  return GestureDetector(
                    onTap: () {
                      garage.updateFuelTypeColor(fuelType, hex);
                      Navigator.pop(ctx);
                      showCustomSnackBar(context, 'Color updated for \'$fuelType\'!');
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: isSel ? const Icon(Icons.check, size: 20, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
            ],
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

  Future<void> _downloadCsvFile(GarageProvider garage) async {
    final logs = garage.fuelLogs;
    if (logs.isEmpty) {
      showCustomSnackBar(context, 'No fuel logs available to export.', isError: true);
      return;
    }

    final StringBuffer csv = StringBuffer();
    csv.writeln('run_id,date,fuel_type,odometer,fuel_cost,liters_to_fill,cost_per_ltr,distance_traveled,fuel_consumed,calculated_mileage,cost_per_km,fuel_density,fill_flag');

    final sorted = List<FuelLog>.from(logs);
    sorted.sort((a, b) => a.runId.compareTo(b.runId));

    for (final l in sorted) {
      csv.writeln('${l.runId},${l.date},"${l.fuelType}",${l.fromOdometer},${l.fuelCost},${l.litersToFill},${l.costPerLtr},${l.distanceTraveled},${l.fuelConsumed},${l.calculatedMileage},${l.costPerKm},${l.fuelDensity},${l.fuelFillFlag}');
    }

    final fileName = '${garage.activeVehicleName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}_fuel_logs.csv';

    try {
      final bytes = Uint8List.fromList(utf8.encode(csv.toString()));
      final res = await FilePicker.saveFile(
        dialogTitle: 'Download Vehicle Logs (.csv)',
        fileName: fileName,
        bytes: bytes,
        mimeType: 'text/csv',
      );

      if (mounted && res != null) {
        showCustomSnackBar(context, '$fileName downloaded successfully!');
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'Failed to download CSV: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final garage = context.watch<GarageProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle & Garage Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card 1: Vehicle Customization
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.palette_outlined, color: AppTheme.primary, size: 20),
                        SizedBox(width: 8),
                        Text('Vehicle Customization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Rename Field
                    TextField(
                      controller: _renameController,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Nickname',
                        prefixIcon: Icon(Icons.edit, size: 18),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Icon Selector
                    const Text('Vehicle Type Icon:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: AppTheme.vehicleIcons.entries.map((e) {
                        final isSel = e.key == _selectedIcon;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Icon(e.value, size: 20, color: isSel ? Colors.white : Colors.grey),
                            selected: isSel,
                            selectedColor: AppTheme.primary,
                            backgroundColor: AppTheme.surfaceHigh,
                            onSelected: (_) => setState(() => _selectedIcon = e.key),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Color Selector
                    const Text('Theme Gradient Color:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: AppTheme.vehiclePrimaryColors.entries.map((e) {
                        final isSel = e.key == _selectedColor;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = e.key),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: e.value,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: isSel ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    ElevatedButton(
                      onPressed: _saveCustomization,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Center(
                        child: Text(
                          'Save Customization',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 2: Add New Vehicle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.add_circle_outline, color: AppTheme.mileageGreen, size: 20),
                        SizedBox(width: 8),
                        Text('Add New Vehicle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('Creates a new vehicle profile in your garage:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addVehicleController,
                      decoration: const InputDecoration(
                        labelText: 'New Vehicle Name',
                        hintText: 'e.g. KTM Duke 390',
                        prefixIcon: Icon(Icons.two_wheeler, size: 18),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _addNewVehicle,
                      icon: const Icon(Icons.add, size: 18, color: Colors.black),
                      label: const Text('Create Vehicle', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.mileageGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 3: Manage Fuel Types
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.local_gas_station, color: AppTheme.costAmber, size: 20),
                        SizedBox(width: 8),
                        Text('Manage Fuel Types', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Active fuel options (tap chip to change color, ✕ to delete):', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: garage.fuelTypes.map((ft) {
                        final canDelete = garage.fuelTypes.length > 1;
                        final colorHex = CacheService.getFuelColorHex(ft);
                        final fuelColor = AppTheme.hexToColor(colorHex);

                        return InputChip(
                          backgroundColor: AppTheme.surfaceHigh,
                          side: BorderSide(color: fuelColor, width: 1.5),
                          avatar: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: fuelColor),
                          ),
                          label: Text(ft, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          tooltip: 'Tap to change color, ✕ to delete',
                          onPressed: () => _showFuelColorPicker(context, ft, garage),
                          deleteIcon: canDelete ? const Icon(Icons.close, size: 16, color: Colors.redAccent) : null,
                          onDeleted: canDelete
                              ? () {
                                  garage.removeCustomFuelType(ft);
                                  showCustomSnackBar(context, 'Removed fuel type \'$ft\'');
                                }
                              : null,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _addFuelTypeController,
                            decoration: const InputDecoration(
                              labelText: 'New Fuel Type Name',
                              hintText: 'e.g. Shell V-Power',
                              prefixIcon: Icon(Icons.add, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            final name = _addFuelTypeController.text.trim();
                            if (name.isNotEmpty) {
                              garage.addCustomFuelType(name);
                              _addFuelTypeController.clear();
                              showCustomSnackBar(context, 'Added fuel type \'$name\'!');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.distanceBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 4: Export Vehicle Data
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.import_export, color: AppTheme.distanceBlue, size: 22),
                        SizedBox(width: 8),
                        Text('Data Backup & CSV Transfer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bulk import fuel logs from CSV or export all logs for \'${garage.activeVehicleName}\':',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => CsvImportSheet.show(context),
                          icon: const Icon(Icons.file_upload_outlined, size: 18, color: Colors.white),
                          label: const Text('Import CSV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _downloadCsvFile(garage),
                          icon: const Icon(Icons.download, size: 18, color: AppTheme.mileageGreen),
                          label: const Text('Download CSV', style: TextStyle(color: AppTheme.mileageGreen, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.mileageGreen),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 5: Delete Vehicle (Danger zone)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Delete Current Vehicle', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        const SizedBox(height: 3),
                        Text('Permanently remove \'${garage.activeVehicleName}\'', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _showDeleteVehicleDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade900,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 4: Account Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.person, color: AppTheme.distanceBlue, size: 20),
                        SizedBox(width: 8),
                        Text('Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Email: ${auth.userEmail}', style: const TextStyle(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (!auth.isGuest) ...[
                          ElevatedButton.icon(
                            onPressed: _showSetPasswordDialog,
                            icon: const Icon(Icons.key, size: 16, color: Colors.white),
                            label: const Text('Set Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.surfaceHigh,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        ElevatedButton.icon(
                          onPressed: _showSignOutDialog,
                          icon: const Icon(Icons.logout, size: 16, color: Colors.white),
                          label: Text(
                            auth.isGuest ? 'Exit Guest Mode' : 'Sign Out',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade900,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Support info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: const [
                    Icon(Icons.headset_mic_outlined, color: AppTheme.costAmber, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Developer Support • arunbaalajiabs@gmail.com',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Version Footer - Only "Version - #"
            Center(
              child: Text(
                AppVersion.display,
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
