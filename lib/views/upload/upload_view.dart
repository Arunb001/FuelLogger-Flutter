import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/garage_provider.dart';
import '../../services/cache_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/service_editor.dart';

class UploadView extends StatefulWidget {
  final bool initialIsService;

  const UploadView({
    super.key,
    this.initialIsService = false,
  });

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
  final _stationController = TextEditingController();
  final _remarkController = TextEditingController();

  late bool _isServiceMode;
  String _selectedFuelType = 'Standard petrol';
  String? _selectedFuelCardId;
  String _fillFlag = 'F';
  bool _isUploading = false;
  bool _editingEntryNum = false;

  @override
  void initState() {
    super.initState();
    _isServiceMode = widget.initialIsService;
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
    _stationController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  void _setFillMode(String mode) {
    HapticFeedback.selectionClick();
    setState(() {
      _fillFlag = mode;
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
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _showAddFuelTypeDialog() {
    final c = context.appColors;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: c.surfaceCard,
          title: const Text('Add Custom Fuel Type', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Fuel Name', hintText: 'e.g. Shell V-Power'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  context.read<GarageProvider>().addCustomFuelType(name);
                  setState(() => _selectedFuelType = name);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
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
    final odo = double.tryParse(_odoController.text.trim()) ?? 0.0;
    final density = double.tryParse(_densityController.text.trim()) ?? 0.0;
    final station = _stationController.text.trim();
    final remark = _remarkController.text.trim();

    HapticFeedback.lightImpact();
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
          stationName: station.isNotEmpty ? station : null,
          remark: remark.isNotEmpty ? remark : null,
          fuelCardId: _selectedFuelCardId,
        );

    if (!mounted) return;
    setState(() => _isUploading = false);

    if (ok) {
      showCustomSnackBar(context, 'Fill-up saved!');
      Navigator.pop(context);
    } else {
      showCustomSnackBar(context, 'Failed to save fill-up. Please try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final garage = context.watch<GarageProvider>();
    final isFull = _fillFlag == 'F';
    final stations = garage.stationSuggestions;

    final double cost = double.tryParse(_costController.text) ?? 0.0;
    final double liters = double.tryParse(_litersController.text) ?? 0.0;
    final double odo = double.tryParse(_odoController.text) ?? 0.0;
    double prevOdo = garage.summary.latestOdometer;
    for (final l in garage.fuelLogs) {
      if (l.fromOdometer > prevOdo) prevOdo = l.fromOdometer;
      if (l.toOdometer > prevOdo) prevOdo = l.toOdometer;
    }
    final double cpl = liters > 0 ? (cost / liters) : 0.0;
    final double dist = (odo > prevOdo && isFull) ? (odo - prevOdo) : 0.0;
    final double expectedMileage = (dist > 0 && liters > 0) ? (dist / liters) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isServiceMode
              ? 'Log Service — ${garage.activeVehicleName}'
              : 'Log Fill-Up — ${garage.activeVehicleName}',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fuel / Service Toggle (P5)
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
                const SizedBox(height: 14),

                if (_isServiceMode)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: ServiceFormBody(
                        onSaved: () {
                          if (mounted) Navigator.pop(context);
                        },
                      ),
                    ),
                  )
                else
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  if (garage.summary.isCycleOpen)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: c.costAmber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.costAmber.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.hourglass_top, color: c.costAmber, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Entry #${garage.summary.nextSno} is open with partial fill(s). This entry will link under Entry #${garage.summary.nextSno}.',
                              style: TextStyle(color: c.costAmber, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Fill Mode Toggle
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.local_gas_station_rounded, size: 18),
                          label: const Text('Full Tank', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _setFillMode('F'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFull ? const Color(0xFF2E7D32) : c.surfaceElevated,
                            foregroundColor: isFull ? Colors.white : c.textSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isFull ? c.mileageGreen : Colors.transparent,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.hourglass_bottom_rounded, size: 18),
                          label: const Text('Partial Fill', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _setFillMode('P'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !isFull ? const Color(0xFFEF6C00) : c.surfaceElevated,
                            foregroundColor: !isFull ? Colors.white : c.textSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: !isFull ? c.costAmber : Colors.transparent,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Primary Fill-Up Form Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Compact Entry # Chip Row
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: c.surfaceElevated,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.tag_rounded, size: 15, color: c.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Entry #${_snoController.text.isEmpty ? garage.summary.nextSno : _snoController.text}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: c.textPrimary,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () => setState(() => _editingEntryNum = !_editingEntryNum),
                                icon: Icon(_editingEntryNum ? Icons.check : Icons.edit_outlined, size: 15),
                                label: Text(_editingEntryNum ? 'Done' : 'Change #', style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          if (_editingEntryNum) ...[
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _snoController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Entry Number *',
                                prefixIcon: Icon(Icons.numbers, size: 20),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required *' : null,
                            ),
                          ],
                          const SizedBox(height: 14),

                          // Date Picker + Optional Fuel Card Row (P5)
                          if (garage.fuelCards.isEmpty)
                            TextFormField(
                              controller: _dateController,
                              readOnly: true,
                              onTap: _selectDate,
                              decoration: const InputDecoration(
                                labelText: 'Fill Date *',
                                prefixIcon: Icon(Icons.calendar_month_outlined, size: 20),
                              ),
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _dateController,
                                    readOnly: true,
                                    onTap: _selectDate,
                                    decoration: const InputDecoration(
                                      labelText: 'Fill Date *',
                                      prefixIcon: Icon(Icons.calendar_month_outlined, size: 19),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String?>(
                                    isExpanded: true,
                                    value: garage.fuelCards.any((fc) => fc.id == _selectedFuelCardId)
                                        ? _selectedFuelCardId
                                        : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Fuel Card',
                                      prefixIcon: Icon(Icons.credit_card_outlined, size: 19),
                                    ),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('None', overflow: TextOverflow.ellipsis),
                                      ),
                                      ...garage.fuelCards.map(
                                        (fc) => DropdownMenuItem<String?>(
                                          value: fc.id,
                                          child: Text(
                                            '${fc.cardName} (${Formatters.currency(fc.remaining)})',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) => setState(() => _selectedFuelCardId = val),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 14),

                          // Fuel Type Dropdown
                          DropdownButtonFormField<String>(
                            value: garage.fuelTypes.contains(_selectedFuelType)
                                ? _selectedFuelType
                                : (garage.fuelTypes.isNotEmpty ? garage.fuelTypes.first : null),
                            decoration: const InputDecoration(
                              labelText: 'Fuel Type *',
                              prefixIcon: Icon(Icons.local_gas_station_outlined, size: 20),
                            ),
                            items: [
                              ...garage.fuelTypes.map((ft) {
                                final cHex = CacheService.getFuelColorHex(ft);
                                final ftColor = AppTheme.hexToColor(cHex);
                                return DropdownMenuItem(
                                  value: ft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: ftColor)),
                                      const SizedBox(width: 8),
                                      Text(ft),
                                    ],
                                  ),
                                );
                              }),
                              DropdownMenuItem(
                                value: '__add__',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_circle_outline, size: 17, color: c.distanceBlue),
                                    const SizedBox(width: 8),
                                    Text('Add Custom Fuel Type...', style: TextStyle(color: c.distanceBlue)),
                                  ],
                                ),
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

                          // Cost + Litres Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _costController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                  decoration: const InputDecoration(
                                    labelText: 'Total Cost (₹) *',
                                    prefixIcon: Icon(Icons.currency_rupee, size: 19),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) => (v == null || double.tryParse(v) == null || double.parse(v) <= 0)
                                      ? 'Valid cost *'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _litersController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                  decoration: const InputDecoration(
                                    labelText: 'Litres (L) *',
                                    prefixIcon: Icon(Icons.water_drop_outlined, size: 19),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) => (v == null || double.tryParse(v) == null || double.parse(v) <= 0)
                                      ? 'Valid litres *'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Odometer Reading
                          TextFormField(
                            controller: _odoController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                            decoration: InputDecoration(
                              labelText: isFull
                                  ? 'Odometer Reading (km) *'
                                  : 'Odometer Reading (Optional for Partial)',
                              hintText: isFull
                                  ? (prevOdo > 0 ? 'Last: ${Formatters.odometer(prevOdo)}' : 'e.g. 15000 or 1542.5')
                                  : '0 km',
                              prefixIcon: const Icon(Icons.speed_outlined, size: 20),
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              if (!isFull) {
                                if (v == null || v.trim().isEmpty || v.trim() == '0') {
                                  return null;
                                }
                                final n = double.tryParse(v.trim());
                                if (n == null || n < 0) return 'Enter valid odometer number';
                                return null;
                              }
                              if (v == null || v.trim().isEmpty) return 'Odometer reading is required *';
                              final n = double.tryParse(v.trim());
                              if (n == null || n < 0) return 'Enter valid odometer number *';
                              if (prevOdo > 0 && n <= prevOdo) {
                                return 'Odometer must exceed ${Formatters.odometer(prevOdo)} *';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // F3: Fuel Station Name + 1-Tap Chips
                          TextFormField(
                            controller: _stationController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Fuel Station (Optional)',
                              hintText: 'e.g. Shell, IndianOil, HPCL',
                              prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                            ),
                          ),
                          if (stations.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: stations.map((st) {
                                  final selected = _stationController.text.trim().toLowerCase() == st.toLowerCase();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(st, style: const TextStyle(fontSize: 12)),
                                      selected: selected,
                                      visualDensity: VisualDensity.compact,
                                      onSelected: (_) {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          _stationController.text = selected ? '' : st;
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),

                          // Fuel Density + Remark
                          TextFormField(
                            controller: _densityController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                            decoration: const InputDecoration(
                              labelText: 'Fuel Density (kg/m³) (Optional)',
                              hintText: 'e.g. 745.5',
                              prefixIcon: Icon(Icons.opacity, size: 20),
                            ),
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _remarkController,
                            textCapitalization: TextCapitalization.sentences,
                            maxLength: 160,
                            decoration: const InputDecoration(
                              labelText: 'Remark (Optional)',
                              hintText: 'e.g. Highway ride, City traffic, Tank brimmed',
                              prefixIcon: Icon(Icons.notes_rounded, size: 20),
                              counterText: '',
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
                        color: c.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                        border: context.isDarkTheme ? null : Border.all(color: c.subtleBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text('Cost / Litre', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(
                                Formatters.currencyPerLiter(cpl),
                                style: TextStyle(
                                  color: c.costAmber,
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          if (dist > 0) ...[
                            Column(
                              children: [
                                Text('Trip Distance', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(
                                  Formatters.km(dist),
                                  style: TextStyle(
                                    color: c.distanceBlue,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text('Expected Mileage', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(
                                  Formatters.mileage(expectedMileage),
                                  style: TextStyle(
                                    color: c.mileageGreen,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  ElevatedButton(
                    onPressed: _isUploading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accentPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text(
                            'Save Fill-Up',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
