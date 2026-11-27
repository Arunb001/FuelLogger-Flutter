import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../providers/garage_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/app_notification.dart';
import '../../config/version.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';
import '../../services/cache_service.dart';
import '../../services/notification_service.dart';
import '../auth/login_view.dart';
import '../logs/csv_import_sheet.dart';
import '../notifications/notifications_view.dart';
import 'user_guide_sheet.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _renameController = TextEditingController();
  final _addVehicleController = TextEditingController();
  final _addFuelTypeController = TextEditingController();

  String _selectedIcon = 'bike';
  String _selectedColor = 'red';
  NotificationPreferences _notifPrefs =
      CacheService.getNotificationPreferences();

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
    final garage = context.read<GarageProvider>();
    final name = _addVehicleController.text.trim();
    if (name.isEmpty) return;

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
    final c = context.appColors;
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
          backgroundColor: c.surfaceCard,
          title: const Text('Delete Vehicle?', style: TextStyle(color: Colors.redAccent)),
          content: Text('Permanently delete \'${target.name}\' and all its fill-up logs? This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
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
    final c = context.appColors;
    final pwCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: c.surfaceCard,
          title: Row(
            children: [
              Icon(Icons.key, color: c.costAmber, size: 22),
              const SizedBox(width: 8),
              const Text('Set Account Password', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Set a password to sign in on any device without checking your email inbox.',
                style: TextStyle(fontSize: 12, color: c.textSecondary),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
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
                backgroundColor: c.accentPrimary,
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
    final c = context.appColors;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: c.surfaceCard,
          title: const Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to sign out of Fuel Logger?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                context.read<GarageProvider>().resetOnSignOut();
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

  Future<void> _launchSupportEmail() async {
    final String subject = Uri.encodeComponent('Fuel Logger: Support & Feedback').replaceAll('+', '%20');
    final Uri emailLaunchUri = Uri.parse('mailto:arunbaalajiabs@gmail.com?subject=$subject');
    try {
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        showCustomSnackBar(
          context,
          'Could not open mail app. Support email: arunbaalajiabs@gmail.com',
          isError: true,
        );
      }
    }
  }

  void _showFuelColorPicker(BuildContext context, String fuelType, GarageProvider garage) {
    final c = context.appColors;
    final currentColorHex = CacheService.getFuelColorHex(fuelType);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: c.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
              Text('Tap any color circle below to apply:', style: TextStyle(fontSize: 12, color: c.textSecondary)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: CacheService.fuelColorPalette.map((hex) {
                  final isSel = hex.toLowerCase() == currentColorHex.toLowerCase();
                  final swatchColor = AppTheme.hexToColor(hex);
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
                        color: swatchColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? c.textPrimary : Colors.transparent,
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
              child: Text('Close', style: TextStyle(color: c.textSecondary)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadCsvFile(GarageProvider garage) async {
    final csvContent = garage.exportFuelLogsToCsv();
    if (csvContent.isEmpty) {
      showCustomSnackBar(context, 'No fuel logs available to export.', isError: true);
      return;
    }

    final fileName = '${garage.activeVehicleName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}_fuel_logs.csv';

    try {
      final bytes = Uint8List.fromList(utf8.encode(csvContent));
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
    final c = context.appColors;
    final garage = context.watch<GarageProvider>();
    final auth = context.watch<AuthProvider>();
    final themeProv = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Garage'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Appearance (Theme Mode)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.contrast_rounded, color: c.distanceBlue, size: 20),
                            const SizedBox(width: 8),
                            Text('Theme Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Choose Light, AMOLED Dark, or follow your phone system theme.',
                          style: TextStyle(fontSize: 12, color: c.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_rounded, size: 17),
                              label: Text('System'),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_rounded, size: 17),
                              label: Text('Light'),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_rounded, size: 17),
                              label: Text('Dark'),
                            ),
                          ],
                          selected: {themeProv.themeMode},
                          onSelectionChanged: (sel) {
                            HapticFeedback.selectionClick();
                            themeProv.setThemeMode(sel.first);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Notifications & Reminders (F6)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.notifications_active_outlined,
                                color: c.mileageGreen, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Notifications & Reminders',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: c.textPrimary),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsView(),
                                  ),
                                );
                              },
                              child: const Text('Inbox'),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable Notifications'),
                          subtitle: const Text(
                            'Master switch for reminders, milestones & updates',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: _notifPrefs.enabled,
                          onChanged: (val) async {
                            final next = _notifPrefs.copyWith(enabled: val);
                            setState(() => _notifPrefs = next);
                            await NotificationService.applyPreferences(next);
                          },
                        ),
                        if (_notifPrefs.enabled) ...[
                          Divider(color: c.subtleBorder, height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Service Due Reminders'),
                            subtitle: const Text(
                              'Alert when maintenance is within 500 km or 7 days',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _notifPrefs.serviceDueReminders,
                            onChanged: (val) async {
                              final next = _notifPrefs.copyWith(
                                  serviceDueReminders: val);
                              setState(() => _notifPrefs = next);
                              await NotificationService.applyPreferences(next);
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                                'Fill-Up Nudge (${_notifPrefs.fillUpNudgeDays}d idle)'),
                            subtitle: const Text(
                              'Gentle check-in if no fill-up logged in 2 weeks',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _notifPrefs.fillUpNudge,
                            onChanged: (val) async {
                              final next =
                                  _notifPrefs.copyWith(fillUpNudge: val);
                              setState(() => _notifPrefs = next);
                              await NotificationService.applyPreferences(next);
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Milestones & Wishes'),
                            subtitle: const Text(
                              'Odometer milestones and occasional festive wishes',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _notifPrefs.wishesAndTips &&
                                _notifPrefs.milestones,
                            onChanged: (val) async {
                              final next = _notifPrefs.copyWith(
                                wishesAndTips: val,
                                milestones: val,
                              );
                              setState(() => _notifPrefs = next);
                              await NotificationService.applyPreferences(next);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Card 1: Vehicle Customization
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.palette_outlined, color: c.accentPrimary, size: 20),
                            const SizedBox(width: 8),
                            Text('Vehicle Customization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 14),

                        TextField(
                          controller: _renameController,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Nickname',
                            prefixIcon: Icon(Icons.edit, size: 18),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text('Vehicle Type Icon', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: AppTheme.vehicleIcons.entries.map((e) {
                            final isSel = e.key == _selectedIcon;
                            return ChoiceChip(
                              label: Icon(e.value, size: 20, color: isSel ? Colors.white : c.textSecondary),
                              selected: isSel,
                              selectedColor: c.accentPrimary,
                              backgroundColor: c.surfaceElevated,
                              onSelected: (_) => setState(() => _selectedIcon = e.key),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        Text('Theme Gradient Color', style: TextStyle(fontSize: 12, color: c.textSecondary)),
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
                                    color: isSel ? c.textPrimary : Colors.transparent,
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
                            backgroundColor: c.accentPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                const SizedBox(height: 14),

                // Card 2: Add New Vehicle
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.add_circle_outline, color: c.mileageGreen, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Add New Vehicle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('Create a new vehicle profile in your garage.', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addVehicleController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'New Vehicle Name',
                            hintText: 'e.g. KTM Duke 390',
                            prefixIcon: Icon(Icons.two_wheeler, size: 18),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _addNewVehicle,
                          icon: Icon(
                            Icons.add,
                            size: 18,
                            color: context.isDarkTheme ? Colors.black : Colors.white,
                          ),
                          label: Text(
                            'Create Vehicle',
                            style: TextStyle(
                              color: context.isDarkTheme ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.mileageGreen,
                            foregroundColor: context.isDarkTheme ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Card 3: Manage Fuel Types
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_gas_station, color: c.costAmber, size: 20),
                            const SizedBox(width: 8),
                            Text('Manage Fuel Types', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Tap a fuel chip to change color, or ✕ to delete.', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: garage.fuelTypes.map((ft) {
                            final canDelete = garage.fuelTypes.length > 1;
                            final colorHex = CacheService.getFuelColorHex(ft);
                            final fuelColor = AppTheme.hexToColor(colorHex);

                            return InputChip(
                              backgroundColor: c.surfaceElevated,
                              side: BorderSide(color: fuelColor, width: 1.4),
                              avatar: Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: fuelColor),
                              ),
                              label: Text(ft, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: c.textPrimary)),
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
                                textCapitalization: TextCapitalization.words,
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
                                backgroundColor: c.distanceBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Card 4: CSV Transfer
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.import_export, color: c.distanceBlue, size: 22),
                            const SizedBox(width: 8),
                            Text('Data Backup & CSV Transfer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Import fill-up records from CSV or export logs for \'${garage.activeVehicleName}\'.',
                          style: TextStyle(fontSize: 12, color: c.textSecondary),
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
                                backgroundColor: c.accentPrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _downloadCsvFile(garage),
                              icon: Icon(Icons.download, size: 18, color: c.mileageGreen),
                              label: Text('Download CSV', style: TextStyle(color: c.mileageGreen, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: c.mileageGreen),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Card 5: Delete Vehicle
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Delete Current Vehicle', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                              const SizedBox(height: 3),
                              Text('Permanently remove \'${garage.activeVehicleName}\'', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _showDeleteVehicleDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade900,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Card 6: Account
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: c.distanceBlue, size: 20),
                            const SizedBox(width: 8),
                            Text('Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Email: ${auth.userEmail}', style: TextStyle(fontSize: 14, color: c.textSecondary)),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            if (!auth.isGuest)
                              ElevatedButton.icon(
                                onPressed: _showSetPasswordDialog,
                                icon: Icon(Icons.key, size: 16, color: c.textPrimary),
                                label: Text('Set Password', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: c.surfaceElevated,
                                  foregroundColor: c.textPrimary,
                                ),
                              ),
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
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // User Guide
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => UserGuideSheet.show(context),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: c.mileageGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.menu_book_outlined, color: c.mileageGreen, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'User Guide & FAQs',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Rules for full/half tanks, odometer, edits & CSV',
                                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 14, color: c.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Developer Support
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _launchSupportEmail,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: c.costAmber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.mail_outline_rounded, color: c.costAmber, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Developer Support',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'arunbaalajiabs@gmail.com',
                                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _launchSupportEmail,
                            icon: const Icon(Icons.send_rounded, size: 14),
                            label: const Text('Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.accentPrimary.withOpacity(0.14),
                              foregroundColor: c.accentPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Center(
                  child: Text(
                    AppVersion.display,
                    style: TextStyle(fontSize: 12, color: c.textMuted, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
