import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/garage_provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/env.dart';
import '../../config/version.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';
import '../auth/login_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({Key? key}) : super(key: key);

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _renameController = TextEditingController();
  final _addVehicleController = TextEditingController();

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
    super.dispose();
  }

  Future<void> _saveCustomization() async {
    final garage = context.read<GarageProvider>();
    final newName = _renameController.text.trim();

    if (newName.isNotEmpty && newName != garage.activeVehicleName) {
      await garage.renameActiveVehicle(newName);
    }

    await garage.updateCustomization(iconKey: _selectedIcon, colorKey: _selectedColor);
    showCustomSnackBar(context, '✅ Vehicle customization saved!');
  }

  Future<void> _addNewVehicle() async {
    final name = _addVehicleController.text.trim();
    if (name.isEmpty) return;

    final ok = await context.read<GarageProvider>().addVehicle(name);
    if (ok) {
      _addVehicleController.clear();
      _renameController.text = name;
      showCustomSnackBar(context, '✅ New vehicle \'$name\' created!');
    } else {
      showCustomSnackBar(context, '⚠️ Failed to create vehicle.', isError: true);
    }
  }

  void _showDeleteVehicleDialog() {
    final garage = context.read<GarageProvider>();
    if (garage.vehicles.length <= 1) {
      showCustomSnackBar(context, '⚠️ Garage safeguard: You must have at least 1 vehicle.', isError: true);
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
                if (ok) {
                  _renameController.text = garage.activeVehicleName;
                  showCustomSnackBar(context, '✅ Vehicle deleted.');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
              child: const Text('Delete Permanently'),
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
              Text('Set Account Password'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Set a password to sign in instantly on any device without checking your email inbox.',
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
                if (ok) {
                  showCustomSnackBar(context, '✅ Password updated successfully!');
                } else {
                  showCustomSnackBar(context, '⚠️ Failed to update password.', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('Save Password'),
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
          title: const Text('Sign Out?'),
          content: const Text('Are you sure you want to sign out of Fuel Logger?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await context.read<AuthProvider>().signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginView()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Save Customization', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    const Text('Creates a new isolated vehicle garage in your cloud database:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addVehicleController,
                      decoration: const InputDecoration(
                        labelText: 'New Vehicle Name',
                        hintText: 'e.g. KTM Duke 390',
                        prefixIcon: Icon(Icons.two_wheeler, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _addNewVehicle,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create Vehicle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.mileageGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 3: Delete Vehicle (Danger zone)
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Delete'),
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
                            icon: const Icon(Icons.key, size: 16),
                            label: const Text('Set Password'),
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
                          icon: const Icon(Icons.logout, size: 16),
                          label: Text(auth.isGuest ? 'Exit Guest Mode' : 'Sign Out'),
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
                        'Developer Support • Email id: arunbaalajiabs@gmail.com',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Version Footer
            Center(
              child: Column(
                children: [
                  Text(
                    '${AppConfig.appName} • ${AppVersion.display}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Environment: ${AppConfig.flavor.toUpperCase()} • Cloud Edition',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppConfig.isDev ? AppTheme.costAmber : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
