import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/service_log.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/metric_tile.dart';
import '../../widgets/vehicle_banner.dart';

/// Service & Maintenance Logs screen (F5).
class ServiceLogsView extends StatelessWidget {
  const ServiceLogsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final garage = context.watch<GarageProvider>();
    final logs = garage.serviceLogs;
    final summary = garage.serviceSummary;

    final (nextKmLabel, nextKmSub, nextKmColor) = _nextKmMeta(summary, c);
    final (nextDateLabel, nextDateSub, nextDateColor) =
        _nextDateMeta(summary, c);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Logs'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: () => _showServiceEditorSheet(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
              style: FilledButton.styleFrom(
                backgroundColor: c.accentPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 36),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => garage.loadGarage(),
        color: c.accentPrimary,
        backgroundColor: c.surfaceCard,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                const VehicleBanner(),
                const SizedBox(height: 14),

                // 2x2 Maintenance KPI Grid
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        label: 'Total Spent',
                        value: Formatters.currency(summary.totalCost),
                        valueColor: c.costAmber,
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricTile(
                        label: 'Last Service',
                        value: Formatters.currency(summary.recentCost),
                        valueColor: c.distanceBlue,
                        icon: Icons.build_circle_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        label: 'Next Due km',
                        value: nextKmLabel,
                        subtitle: nextKmSub,
                        valueColor: nextKmColor,
                        icon: Icons.speed_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricTile(
                        label: 'Next Due Date',
                        value: nextDateLabel,
                        subtitle: nextDateSub,
                        valueColor: nextDateColor,
                        icon: Icons.event_available_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Text(
                      'Service History (${logs.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (logs.isNotEmpty)
                      Text(
                        'Tap record for details',
                        style: TextStyle(fontSize: 11.5, color: c.textMuted),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (logs.isEmpty)
                  _EmptyServiceState(
                    vehicleName: garage.activeVehicleName,
                    onAddTap: () => _showServiceEditorSheet(context),
                  )
                else
                  ...logs.map(
                    (log) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ServiceLogCard(
                        log: log,
                        onTap: () => _showServiceDetailModal(context, log),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (String, String?, Color) _nextKmMeta(
      ServiceSummary s, AppSemanticColors c) {
    if (s.nextDueKm == null) return ('-- km', null, c.textSecondary);
    final label = Formatters.km(s.nextDueKm!);
    final rem = s.remainingKm;
    if (rem == null) return (label, null, c.mileageGreen);
    if (rem <= 0) {
      return (label, 'Overdue ${rem.abs().round()} km', c.accentPrimary);
    }
    if (rem <= 500) {
      return (label, '${rem.round()} km left', c.costAmber);
    }
    return (label, '${rem.round()} km left', c.mileageGreen);
  }

  (String, String?, Color) _nextDateMeta(
      ServiceSummary s, AppSemanticColors c) {
    if (s.nextDueDate == null || s.nextDueDate!.isEmpty) {
      return ('--', null, c.textSecondary);
    }
    final label = Formatters.shortDate(s.nextDueDate!);
    final days = s.remainingDays;
    if (days == null) return (label, null, c.textPrimary);
    if (days < 0) {
      return (label, 'Overdue ${days.abs()}d', c.accentPrimary);
    }
    if (days == 0) {
      return (label, 'Due today', c.costAmber);
    }
    if (days <= 7) {
      return (label, '$days days left', c.costAmber);
    }
    return (label, '$days days left', c.textPrimary);
  }

  static Future<void> _showServiceDetailModal(
      BuildContext context, ServiceLog log) async {
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
                _detailRow('Odometer', Formatters.odometer(log.odometer), c),
                _detailRow('Total Cost', Formatters.currency(log.totalCost), c),
                if (log.serviceCenter != null)
                  _detailRow('Service Center', log.serviceCenter!, c),
                if (log.nextDueKm != null)
                  _detailRow('Next Service km', Formatters.km(log.nextDueKm!), c),
                if (log.nextDueDate != null)
                  _detailRow(
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
                          _showServiceEditorSheet(context, existing: log);
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
                          await _confirmDelete(context, log);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.accentPrimary,
                          side: BorderSide(
                            color: c.accentPrimary.withOpacity(0.5),
                          ),
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

  static Widget _detailRow(
      String label, String value, AppSemanticColors c) {
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

  static Future<void> _confirmDelete(
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

  static Future<void> _showServiceEditorSheet(
    BuildContext context, {
    ServiceLog? existing,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ServiceEditorSheet(existing: existing),
    );
  }
}

class _ServiceLogCard extends StatelessWidget {
  final ServiceLog log;
  final VoidCallback onTap;

  const _ServiceLogCard({required this.log, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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

class _EmptyServiceState extends StatelessWidget {
  final String vehicleName;
  final VoidCallback onAddTap;

  const _EmptyServiceState({
    required this.vehicleName,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.costAmber.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.build_outlined, size: 28, color: c.costAmber),
            ),
            const SizedBox(height: 14),
            Text(
              'No service records for $vehicleName',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Log oil changes, periodic services, parts & set next due km or date reminders.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: c.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAddTap,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add First Service Record'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceEditorSheet extends StatefulWidget {
  final ServiceLog? existing;

  const _ServiceEditorSheet({this.existing});

  @override
  State<_ServiceEditorSheet> createState() => _ServiceEditorSheetState();
}

class _ServiceEditorSheetState extends State<_ServiceEditorSheet> {
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
        ? garage.summary.latestOdometer.toStringAsFixed(0)
        : '';

    _dateCtrl = TextEditingController(
      text: ex?.serviceDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    _odoCtrl = TextEditingController(
      text: ex != null ? ex.odometer.toStringAsFixed(0) : defaultOdo,
    );
    _typeCtrl = TextEditingController(
      text: ex?.serviceType ?? ServiceLog.commonTypes.first,
    );
    _centerCtrl = TextEditingController(text: ex?.serviceCenter ?? '');
    _costCtrl = TextEditingController(
      text: ex != null ? ex.totalCost.toStringAsFixed(0) : '',
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
      showCustomSnackBar(context, 'Enter current odometer reading first',
          isError: true);
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
    final center = _centerCtrl.text.trim().isEmpty
        ? null
        : _centerCtrl.text.trim();
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
    final nextKm = double.tryParse(_nextKmCtrl.text.trim());
    final nextDate = _nextDateCtrl.text.trim().isEmpty
        ? null
        : _nextDateCtrl.text.trim();
    final notes = _notesCtrl.text.trim().isEmpty
        ? null
        : _notesCtrl.text.trim();

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
      Navigator.pop(context);
      showCustomSnackBar(
        context,
        widget.existing == null
            ? 'Service record saved!'
            : 'Service record updated!',
      );
    } else {
      showCustomSnackBar(context, 'Failed to save service record',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
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
                  widget.existing == null
                      ? 'Add Service Record'
                      : 'Edit Service Record',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),

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
                const SizedBox(height: 10),
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
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
                        decoration: const InputDecoration(
                          labelText: 'Workshop (Optional)',
                          prefixIcon:
                              Icon(Icons.store_mall_directory_outlined, size: 18),
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
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
                          prefixIcon:
                              const Icon(Icons.event_repeat_outlined, size: 18),
                          suffixIcon: _nextDateCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () =>
                                      setState(() => _nextDateCtrl.clear()),
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
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Parts Replaced (Optional)',
                    prefixIcon: Icon(Icons.notes_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 18),

                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(widget.existing == null
                          ? 'Save Service Record'
                          : 'Update Service Record'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
