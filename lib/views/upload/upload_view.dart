import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/garage_provider.dart';
import '../../services/cache_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';
import '../logs/csv_import_sheet.dart';

class UploadView extends StatefulWidget {
  const UploadView({Key? key}) : super(key: key);

  @override
  State<UploadView> createState() => _UploadViewState();
}

class _UploadViewState extends State<UploadView> {
  final _formKey = GlobalKey<FormState>();

  final _snoController = TextEditingController();
  final _dateController = TextEditingController();
  final _costController = TextEditingController();
  final _litersController = TextEditingController();
  final _odoController = TextEditingController();
  final _densityController = TextEditingController();

  String _selectedFuelType = 'XP95';
  String _fillFlag = 'F'; // 'F' for Full, 'P' for Partial
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final garage = context.read<GarageProvider>();
    _snoController.text = garage.summary.nextSno.toString();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (garage.summary.isCycleOpen) {
      _fillFlag = 'P';
    }
    if (garage.fuelTypes.isNotEmpty) {
      _selectedFuelType = garage.fuelTypes.first;
    }
  }

  @override
  void dispose() {
    _snoController.dispose();
    _dateController.dispose();
    _costController.dispose();
    _litersController.dispose();
    _odoController.dispose();
    _densityController.dispose();
    super.dispose();
  }

  void _setFillMode(String mode) {
    setState(() {
      _fillFlag = mode;
      // Do not decrement or alter the run number - it remains the active cycle run number!
      if (_snoController.text.trim().isEmpty) {
        _snoController.text = context.read<GarageProvider>().summary.nextSno.toString();
      }
    });
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primary,
              surface: AppTheme.cardBg,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _showAddFuelTypeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('Add Custom Fuel Type', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Fuel Name', hintText: 'e.g. Shell V-Power'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  context.read<GarageProvider>().addCustomFuelType(name);
                  setState(() => _selectedFuelType = name);
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final runId = int.tryParse(_snoController.text.trim()) ?? 1;
    final date = _dateController.text.trim();
    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
    final liters = double.tryParse(_litersController.text.trim()) ?? 0.0;
    final odo = int.tryParse(_odoController.text.trim()) ?? 0;
    final density = double.tryParse(_densityController.text.trim()) ?? 0.0;

    setState(() => _isUploading = true);

    final ok = await context.read<GarageProvider>().addFuelLog(
          runId: runId,
          date: date,
          fuelType: _selectedFuelType,
          fuelCost: cost,
          litersToFill: liters,
          fromOdometer: odo,
          fuelDensity: density,
          fuelFillFlag: _fillFlag,
        );

    if (!mounted) return;
    setState(() => _isUploading = false);

    if (ok) {
      showCustomSnackBar(context, 'Fill-up log saved successfully!');
      Navigator.pop(context);
    } else {
      showCustomSnackBar(context, 'Failed to save log. Please try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final garage = context.watch<GarageProvider>();
    final isFull = _fillFlag == 'F';

    // Live preview metrics
    final double cost = double.tryParse(_costController.text) ?? 0.0;
    final double liters = double.tryParse(_litersController.text) ?? 0.0;
    final int odo = int.tryParse(_odoController.text) ?? 0;
    int prevOdo = garage.summary.latestOdometer;
    for (final l in garage.fuelLogs) {
      if (l.fromOdometer > prevOdo) prevOdo = l.fromOdometer;
      if (l.toOdometer > prevOdo) prevOdo = l.toOdometer;
    }
    final double cpl = liters > 0 ? (cost / liters) : 0.0;
    final double dist = (odo > prevOdo && isFull) ? (odo - prevOdo).toDouble() : 0.0;
    final double expectedMileage = (dist > 0 && liters > 0) ? (dist / liters) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Log Fill-Up — ${garage.activeVehicleName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cycle in progress indicator
              if (garage.summary.isCycleOpen)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top, color: Colors.orangeAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Run #${garage.summary.nextSno} is currently open with partial fill(s). This fill will log under Run #${garage.summary.nextSno}.',
                          style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

              // Fill Type Selector Row (Full vs Partial)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.local_gas_station, size: 18),
                      label: const Text('Full Tank Fill', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _setFillMode('F'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFull ? const Color(0xFF2E7D32) : AppTheme.surfaceHigh,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: isFull ? Colors.greenAccent : Colors.transparent, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.hourglass_bottom, size: 18),
                      label: const Text('Half / Partial Fill', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _setFillMode('P'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !isFull ? const Color(0xFFEF6C00) : AppTheme.surfaceHigh,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: !isFull ? Colors.orangeAccent : Colors.transparent, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Inputs Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      // S.No / Run #
                      TextFormField(
                        controller: _snoController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'S.No / Run # *',
                          prefixIcon: Icon(Icons.numbers, size: 20),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required *' : null,
                      ),
                      const SizedBox(height: 14),

                      // Date Picker
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        textAlign: TextAlign.center,
                        onTap: _selectDate,
                        decoration: const InputDecoration(
                          labelText: 'Date *',
                          prefixIcon: Icon(Icons.calendar_month, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Fuel Type Dropdown
                      DropdownButtonFormField<String>(
                        value: garage.fuelTypes.contains(_selectedFuelType) ? _selectedFuelType : null,
                        decoration: const InputDecoration(
                          labelText: 'Fuel Type *',
                          prefixIcon: Icon(Icons.ev_station, size: 20),
                        ),
                        items: [
                          ...garage.fuelTypes.map((ft) {
                            final cHex = CacheService.getFuelColorHex(ft);
                            final c = AppTheme.hexToColor(cHex);
                            return DropdownMenuItem(
                              value: ft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
                                  const SizedBox(width: 8),
                                  Text(ft),
                                ],
                              ),
                            );
                          }),
                          const DropdownMenuItem(
                            value: '__add__',
                            child: Text('➕ Add Custom Fuel Type...', style: TextStyle(color: AppTheme.distanceBlue)),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == '__add__') {
                            _showAddFuelTypeDialog();
                          } else if (val != null) {
                            setState(() => _selectedFuelType = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Cost (₹)
                      TextFormField(
                        controller: _costController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'Total Fuel Cost (₹) *',
                          prefixIcon: Icon(Icons.currency_rupee, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v == null || double.tryParse(v) == null || double.parse(v) <= 0) ? 'Enter valid cost *' : null,
                      ),
                      const SizedBox(height: 14),

                      // Litres Filled
                      TextFormField(
                        controller: _litersController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'Litres Filled (L) *',
                          prefixIcon: Icon(Icons.water_drop_outlined, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v == null || double.tryParse(v) == null || double.parse(v) <= 0) ? 'Enter valid litres *' : null,
                      ),
                      const SizedBox(height: 14),

                      // Odometer Reading
                      TextFormField(
                        controller: _odoController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: isFull
                              ? 'Odometer Reading (km) *'
                              : 'Odometer Reading (Optional for Half Tank)',
                          hintText: isFull
                              ? (prevOdo > 0 ? 'Last: $prevOdo km' : 'e.g. 15000')
                              : '0 km (Not required for half tank)',
                          prefixIcon: const Icon(Icons.speed, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (!isFull) {
                            // Odometer reading is strictly NOT required on half tank / partial fills!
                            if (v == null || v.trim().isEmpty || v.trim() == '0') {
                              return null; // Valid (will default to 0)
                            }
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 0) return 'Enter valid odometer number';
                            return null;
                          }
                          // Full tank fills require odometer to compute cycle distance and mileage
                          if (v == null || v.trim().isEmpty) return 'Odometer reading is required *';
                          final n = int.tryParse(v.trim());
                          if (n == null || n < 0) return 'Enter valid odometer number *';
                          if (prevOdo > 0 && n <= prevOdo) {
                            return 'Odometer must be greater than previous ($prevOdo km) *';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Fuel Density
                      TextFormField(
                        controller: _densityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'Fuel Density (kg/m³) (Optional)',
                          hintText: 'e.g. 745.5',
                          prefixIcon: Icon(Icons.opacity, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Live Telemetry Preview Card
              if (cost > 0 && liters > 0) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Cost / Litre', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text('₹${cpl.toStringAsFixed(2)}/L', style: const TextStyle(color: AppTheme.costAmber, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (dist > 0) ...[
                        Column(
                          children: [
                            const Text('Trip Distance', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text('${dist.toInt()} km', style: const TextStyle(color: AppTheme.distanceBlue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Calculated Mileage', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text('${expectedMileage.toStringAsFixed(2)} km/l', style: const TextStyle(color: AppTheme.mileageGreen, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submit Button
              ElevatedButton(
                onPressed: _isUploading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        'Upload Fuel Log',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () => CsvImportSheet.show(context),
                  icon: const Icon(Icons.file_upload_outlined, size: 16, color: AppTheme.distanceBlue),
                  label: const Text(
                    'Or bulk import multiple fill-ups via CSV',
                    style: TextStyle(color: AppTheme.distanceBlue, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
