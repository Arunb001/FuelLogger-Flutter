import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/service_log.dart';
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
  late final TextEditingController _typeCtrl;
  late final TextEditingController _centerCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _nextKmCtrl;
  late final TextEditingController _nextDateCtrl;
  late final TextEditingController _notesCtrl;

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
    _typeCtrl = TextEditingController(
      text: ex?.serviceType ?? ServiceLog.commonTypes.first,
    );
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
    _typeCtrl.dispose();
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
    final target = DateTime(base.year, base.month + months, base.day);
    _nextDateCtrl.text = DateFormat('yyyy-MM-dd').format(target);
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final garage = context.read<GarageProvider>();
    final serviceDate = _dateCtrl.text.trim();
    final odo = double.parse(_odoCtrl.text.trim());
    final serviceType = _typeCtrl.text.trim();
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

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Service Type',
            style: TextStyle(fontSize: 12, color: c.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ServiceLog.commonTypes.map((type) {
              final selected = _typeCtrl.text.trim() == type;
              return ChoiceChip(
                label: Text(type, style: const TextStyle(fontSize: 12)),
                selected: selected,
                selectedColor: c.accentPrimary,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _typeCtrl.text = type),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _typeCtrl,
            decoration: const InputDecoration(
              labelText: 'Service Name / Work Done *',
              prefixIcon: Icon(Icons.build_outlined, size: 18),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
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
