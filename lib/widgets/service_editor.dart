import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/service_log.dart';
import '../models/vehicle.dart';
import '../providers/garage_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'custom_snackbar.dart';

/// Shared service log form body used inline inside [UploadView] (P5)
/// and inside the modal editor sheet from [LogsView] (P7).
class ServiceFormBody extends StatefulWidget {
  final ServiceLog? existing;
  final VoidCallback? onSaved;

  const ServiceFormBody({
    super.key,
    this.existing,
    this.onSaved,
  });

  @override
  State<ServiceFormBody> createState() => _ServiceFormBodyState();
}

class _ServiceFormBodyState extends State<ServiceFormBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateCtrl;
  late final TextEditingController _odoCtrl;
  late final TextEditingController _centerCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _nextKmCtrl;
  late final TextEditingController _nextDateCtrl;
  late final TextEditingController _notesCtrl;

  late String _selectedServiceType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    final garage = context.read<GarageProvider>();
    final defaultOdo = garage.summary.latestOdometer > 0
        ? (garage.summary.latestOdometer % 1 == 0
            ? garage.summary.latestOdometer.toStringAsFixed(0)
            : garage.summary.latestOdometer.toStringAsFixed(1))
        : '';

    _dateCtrl = TextEditingController(
      text: ex?.serviceDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    _odoCtrl = TextEditingController(
      text: ex != null
          ? (ex.odometer % 1 == 0
              ? ex.odometer.toStringAsFixed(0)
              : ex.odometer.toStringAsFixed(1))
          : defaultOdo,
    );
    if (ex != null && ex.serviceType.trim().isNotEmpty) {
      _selectedServiceType = ex.serviceType.trim();
    } else if (garage.serviceTypes.contains(ServiceLog.defaultServiceType)) {
      _selectedServiceType = ServiceLog.defaultServiceType;
    } else if (garage.serviceTypes.isNotEmpty) {
      _selectedServiceType = garage.serviceTypes.first;
    } else {
      _selectedServiceType = ServiceLog.defaultServiceType;
    }
    _centerCtrl = TextEditingController(text: ex?.serviceCenter ?? '');
    _costCtrl = TextEditingController(
      text: ex != null
          ? (ex.totalCost % 1 == 0
              ? ex.totalCost.toStringAsFixed(0)
              : ex.totalCost.toStringAsFixed(2))
          : '',
    );
    _nextKmCtrl = TextEditingController(
      text: ex?.nextDueKm != null ? ex!.nextDueKm!.toStringAsFixed(0) : '',
    );
    _nextDateCtrl = TextEditingController(text: ex?.nextDueDate ?? '');
    _notesCtrl = TextEditingController(text: ex?.notes ?? '');
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _odoCtrl.dispose();
    _centerCtrl.dispose();
    _costCtrl.dispose();
    _nextKmCtrl.dispose();
    _nextDateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController target) async {
    final initial = DateTime.tryParse(target.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      target.text = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {});
    }
  }

  void _applyKmIncrement(int delta) {
    final base = double.tryParse(_odoCtrl.text.trim()) ?? 0.0;
    if (base <= 0) {
      showCustomSnackBar(
        context,
        'Enter current odometer reading first',
        isError: true,
      );
      return;
    }
    _nextKmCtrl.text = (base + delta).toStringAsFixed(0);
    setState(() {});
  }

  void _applyMonthIncrement(int months) {
    final base = DateTime.tryParse(_dateCtrl.text.trim()) ?? DateTime.now();
    final target = Vehicle.addMonthsClamped(base, months);
    _nextDateCtrl.text = DateFormat('yyyy-MM-dd').format(target);
    setState(() {});
  }

  Future<void> _showAddServiceTypeDialog() async {
    final c = context.appColors;
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surfaceCard,
        title: const Text('Add Service Type', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Service Type Name',
            hintText: 'e.g. Oil Change, Brake Service',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final clean = ctrl.text.trim();
              if (clean.isEmpty) return;
              final garage = context.read<GarageProvider>();
              garage.addCustomServiceType(clean);
              final matched = garage.serviceTypes.firstWhere(
                (t) => t.toLowerCase() == clean.toLowerCase(),
                orElse: () => clean,
              );
              setState(() => _selectedServiceType = matched);
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showManageServiceTypesDialog() async {
    final c = context.appColors;
    final addCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final garage = context.watch<GarageProvider>();
          final types = garage.serviceTypes;
          return AlertDialog(
            backgroundColor: c.surfaceCard,
            title: const Text('Manage Service Types', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: addCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'New Service Type',
                              hintText: 'e.g. Oil Change',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final name = addCtrl.text.trim();
                            if (name.isEmpty) return;
                            if (garage.addCustomServiceType(name)) {
                              addCtrl.clear();
                              setState(() => _selectedServiceType = name);
                              setDialogState(() {});
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...types.map((t) {
                      final canDelete = types.length > 1;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.build_circle_outlined,
                          size: 18,
                          color: t == _selectedServiceType ? c.accentPrimary : c.textSecondary,
                        ),
                        title: Text(
                          t,
                          style: TextStyle(
                            fontWeight: t == _selectedServiceType
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: c.textPrimary,
                          ),
                        ),
                        trailing: canDelete
                            ? IconButton(
                                tooltip: 'Delete $t',
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 19),
                                onPressed: () {
                                  final removed = garage.removeCustomServiceType(t);
                                  if (removed && mounted) {
                                    if (!garage.serviceTypes.contains(_selectedServiceType)) {
                                      setState(() {
                                        _selectedServiceType = garage.serviceTypes.isNotEmpty
                                            ? garage.serviceTypes.first
                                            : ServiceLog.defaultServiceType;
                                      });
                                    }
                                    setDialogState(() {});
                                  }
                                },
                              )
                            : Icon(Icons.lock_outline, size: 16, color: c.textMuted),
                        onTap: () {
                          setState(() => _selectedServiceType = t);
                          Navigator.pop(dialogCtx);
                        },
                      );
                    }),
                    if (types.length <= 1)
                      Text(
                        'At least 1 service type must remain.',
                        style: TextStyle(fontSize: 11, color: c.textMuted),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final garage = context.read<GarageProvider>();
    final serviceDate = _dateCtrl.text.trim();
    final odo = double.parse(_odoCtrl.text.trim());
    final serviceType = _selectedServiceType.trim().isEmpty
        ? ServiceLog.defaultServiceType
        : _selectedServiceType.trim();
    final center =
        _centerCtrl.text.trim().isEmpty ? null : _centerCtrl.text.trim();
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
    final nextKm = double.tryParse(_nextKmCtrl.text.trim());
    final nextDate =
        _nextDateCtrl.text.trim().isEmpty ? null : _nextDateCtrl.text.trim();
    final notes =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    bool ok;
    if (widget.existing == null) {
      ok = await garage.addServiceLog(
        serviceDate: serviceDate,
        odometer: odo,
        serviceType: serviceType,
        serviceCenter: center,
        totalCost: cost,
        nextDueKm: nextKm,
        nextDueDate: nextDate,
        notes: notes,
      );
    } else {
      ok = await garage.updateServiceLog(widget.existing!.id, {
        'service_date': serviceDate,
        'odometer': odo,
        'service_type': serviceType,
        'service_center': center,
        'total_cost': cost,
        'next_due_km': nextKm,
        'next_due_date': nextDate,
        'notes': notes,
      });
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      widget.onSaved?.call();
      if (widget.onSaved == null) {
        Navigator.pop(context);
      }
      showCustomSnackBar(
        context,
        widget.existing == null
            ? 'Service record saved!'
            : 'Service record updated!',
      );
    } else {
      showCustomSnackBar(
        context,
        'Failed to save service record',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final garage = context.watch<GarageProvider>();
    final availableTypes = List<String>.from(garage.serviceTypes);
    if (availableTypes.isEmpty) {
      availableTypes.add(ServiceLog.defaultServiceType);
    }
    if (!availableTypes.contains(_selectedServiceType) &&
        _selectedServiceType.trim().isNotEmpty) {
      availableTypes.insert(0, _selectedServiceType.trim());
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedServiceType,
                  decoration: const InputDecoration(
                    labelText: 'Service Type *',
                    prefixIcon: Icon(Icons.build_outlined, size: 18),
                  ),
                  items: [
                    ...availableTypes.map(
                      (type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(type, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    DropdownMenuItem<String>(
                      value: '__add__',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline, size: 17, color: c.distanceBlue),
                          const SizedBox(width: 8),
                          Text(
                            'Add Service Type...',
                            style: TextStyle(color: c.distanceBlue),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == '__add__') {
                      _showAddServiceTypeDialog();
                    } else if (val != null) {
                      setState(() => _selectedServiceType = val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Manage service types',
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _showManageServiceTypesDialog,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Icon(Icons.tune_rounded, size: 20, color: c.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dateCtrl,
                  readOnly: true,
                  onTap: () => _pickDate(_dateCtrl),
                  decoration: const InputDecoration(
                    labelText: 'Service Date *',
                    prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _odoCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Odometer (km) *',
                    prefixIcon: Icon(Icons.speed_rounded, size: 18),
                  ),
                  validator: (v) {
                    final val = double.tryParse((v ?? '').trim());
                    if (val == null || val <= 0) return 'Enter km';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _costCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Total Cost (₹) *',
                    prefixIcon: Icon(Icons.currency_rupee_rounded, size: 18),
                  ),
                  validator: (v) {
                    final val = double.tryParse((v ?? '').trim());
                    if (val == null || val < 0) return 'Enter cost';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _centerCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Workshop (Optional)',
                    prefixIcon: Icon(Icons.store_mall_directory_outlined, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            'Next Due Target (for Reminders)',
            style: TextStyle(fontSize: 12, color: c.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(
                label: const Text('+3,000 km'),
                onPressed: () => _applyKmIncrement(3000),
              ),
              ActionChip(
                label: const Text('+5,000 km'),
                onPressed: () => _applyKmIncrement(5000),
              ),
              ActionChip(
                label: const Text('+10,000 km'),
                onPressed: () => _applyKmIncrement(10000),
              ),
              ActionChip(
                label: const Text('+3 mo'),
                onPressed: () => _applyMonthIncrement(3),
              ),
              ActionChip(
                label: const Text('+6 mo'),
                onPressed: () => _applyMonthIncrement(6),
              ),
              ActionChip(
                label: const Text('+1 yr'),
                onPressed: () => _applyMonthIncrement(12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nextKmCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Next Due km',
                    prefixIcon: Icon(Icons.update_rounded, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _nextDateCtrl,
                  readOnly: true,
                  onTap: () => _pickDate(_nextDateCtrl),
                  decoration: InputDecoration(
                    labelText: 'Next Due Date',
                    prefixIcon: const Icon(Icons.event_repeat_outlined, size: 18),
                    suffixIcon: _nextDateCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _nextDateCtrl.clear()),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _notesCtrl,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes / Parts Replaced (Optional)',
              prefixIcon: Icon(Icons.notes_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 18),

          ElevatedButton(
            onPressed: _isSaving ? null : _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.existing == null
                        ? 'Save Service Record'
                        : 'Update Service Record',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet editor wrapper for editing an existing service record.
class ServiceEditorSheet {
  static Future<void> show(
    BuildContext context, {
    ServiceLog? existing,
  }) async {
    final c = context.appColors;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.subtleBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    existing == null ? 'Add Service Record' : 'Edit Service Record',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ServiceFormBody(
                    existing: existing,
                    onSaved: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Reusable card displaying a [ServiceLog] entry in Logs or Home.
class ServiceLogCard extends StatelessWidget {
  final ServiceLog log;
  final VoidCallback onTap;

  const ServiceLogCard({
    super.key,
    required this.log,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.costAmber.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      log.serviceType,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: c.costAmber,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Formatters.shortDate(log.serviceDate),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Formatters.currency(log.totalCost),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.speed_rounded, size: 15, color: c.distanceBlue),
                  const SizedBox(width: 4),
                  Text(
                    Formatters.odometer(log.odometer),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (log.serviceCenter != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.store_mall_directory_outlined,
                        size: 15, color: c.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        log.serviceCenter!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                      ),
                    ),
                  ] else
                    const Spacer(),
                ],
              ),
              if (log.nextDueKm != null || log.nextDueDate != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_active_outlined,
                          size: 13, color: c.mileageGreen),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          [
                            if (log.nextDueKm != null)
                              'Next ${Formatters.km(log.nextDueKm!)}',
                            if (log.nextDueDate != null)
                              Formatters.shortDate(log.nextDueDate!),
                          ].join(' • '),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: c.mileageGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable detail sheet for a [ServiceLog] with Edit & Delete actions.
Future<void> showServiceLogDetailModal(
  BuildContext context,
  ServiceLog log,
) async {
  final c = context.appColors;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.subtleBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.costAmber.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      log.serviceType,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.costAmber,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Formatters.shortDate(log.serviceDate),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _serviceDetailRow('Odometer', Formatters.odometer(log.odometer), c),
              _serviceDetailRow('Total Cost', Formatters.currency(log.totalCost), c),
              if (log.serviceCenter != null)
                _serviceDetailRow('Service Center', log.serviceCenter!, c),
              if (log.nextDueKm != null)
                _serviceDetailRow('Next Service km', Formatters.km(log.nextDueKm!), c),
              if (log.nextDueDate != null)
                _serviceDetailRow(
                  'Next Service Date',
                  Formatters.shortDate(log.nextDueDate!),
                  c,
                ),
              if (log.notes != null && log.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.subtleBorder),
                  ),
                  child: Text(
                    log.notes!,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ServiceEditorSheet.show(context, existing: log);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _confirmDeleteServiceLog(context, log);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.accentPrimary,
                        side: BorderSide(color: c.accentPrimary.withOpacity(0.5)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _serviceDetailRow(String label, String value, AppSemanticColors c) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

Future<void> _confirmDeleteServiceLog(
    BuildContext context, ServiceLog log) async {
  final c = context.appColors;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Service Log'),
      content: Text(
        'Delete "${log.serviceType}" recorded on ${Formatters.shortDate(log.serviceDate)}?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Delete', style: TextStyle(color: c.accentPrimary)),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    final deleted =
        await context.read<GarageProvider>().deleteServiceLog(log.id);
    if (context.mounted) {
      if (deleted) {
        showCustomSnackBar(context, 'Service record deleted');
      } else {
        showCustomSnackBar(context, 'Failed to delete service record',
            isError: true);
      }
    }
  }
}
