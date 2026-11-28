import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/fuel_log.dart';
import '../../models/service_log.dart';
import '../../providers/garage_provider.dart';
import '../../services/cache_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/service_editor.dart';
import '../upload/upload_view.dart';

class LogsView extends StatefulWidget {
  final ValueNotifier<bool>? serviceModeNotifier;

  const LogsView({super.key, this.serviceModeNotifier});

  @override
  State<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<LogsView> {
  late bool _isServiceMode;

  @override
  void initState() {
    super.initState();
    _isServiceMode = widget.serviceModeNotifier?.value ?? false;
    widget.serviceModeNotifier?.addListener(_onExternalModeChange);
  }

  @override
  void didUpdateWidget(covariant LogsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceModeNotifier != widget.serviceModeNotifier) {
      oldWidget.serviceModeNotifier?.removeListener(_onExternalModeChange);
      _isServiceMode = widget.serviceModeNotifier?.value ?? _isServiceMode;
      widget.serviceModeNotifier?.addListener(_onExternalModeChange);
    }
  }

  @override
  void dispose() {
    widget.serviceModeNotifier?.removeListener(_onExternalModeChange);
    super.dispose();
  }

  void _onExternalModeChange() {
    final next = widget.serviceModeNotifier?.value ?? false;
    if (mounted && next != _isServiceMode) {
      setState(() => _isServiceMode = next);
    }
  }

  void _setMode(bool serviceMode) {
    if (_isServiceMode == serviceMode) return;
    HapticFeedback.selectionClick();
    setState(() => _isServiceMode = serviceMode);
    if (widget.serviceModeNotifier != null &&
        widget.serviceModeNotifier!.value != serviceMode) {
      widget.serviceModeNotifier!.value = serviceMode;
    }
  }

  void _showDeleteDialog(BuildContext context, FuelLog log) {
    final c = context.appColors;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: c.surfaceCard,
          title: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
              SizedBox(width: 8),
              Text('Delete Log?', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Delete Entry #${log.runId} (${Formatters.shortDate(log.date)}, ${Formatters.liters(log.litersToFill)})? Intervals will automatically recalculate.',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await context.read<GarageProvider>().deleteFuelLog(log.id);
                if (context.mounted) {
                  if (ok) {
                    showCustomSnackBar(context, 'Entry #${log.runId} deleted.');
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
    final c = context.appColors;
    final garage = context.read<GarageProvider>();
    String editDate = log.date;
    String editFuelType = garage.fuelTypes.contains(log.fuelType)
        ? log.fuelType
        : (garage.fuelTypes.isNotEmpty ? garage.fuelTypes.first : log.fuelType);
    String? editCardId = garage.fuelCards.any((fc) => fc.id == log.fuelCardId)
        ? log.fuelCardId
        : null;

    final dateCtrl = TextEditingController(text: editDate);
    final costCtrl = TextEditingController(text: log.fuelCost.toString());
    final litersCtrl = TextEditingController(text: log.litersToFill.toString());
    final odoText = log.fromOdometer % 1 == 0
        ? log.fromOdometer.toInt().toString()
        : log.fromOdometer.toString();
    final odoCtrl = TextEditingController(text: odoText);
    final stationCtrl = TextEditingController(text: log.stationName ?? '');
    final remarkCtrl = TextEditingController(text: log.remark ?? '');
    final stations = garage.stationSuggestions;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: c.surfaceCard,
              title: Row(
                children: [
                  Icon(Icons.edit_note, color: c.accentPrimary, size: 22),
                  const SizedBox(width: 8),
                  Text('Edit Entry #${log.runId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () async {
                        final initial = DateTime.tryParse(editDate) ?? DateTime.now();
                        final picked = await showDatePicker(
                          context: dialogCtx,
                          initialDate: initial,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            editDate = DateFormat('yyyy-MM-dd').format(picked);
                            dateCtrl.text = editDate;
                          });
                        }
                      },
                      child: IgnorePointer(
                        child: TextField(
                          controller: dateCtrl,
                          decoration: InputDecoration(
                            labelText: 'Date (YYYY-MM-DD)',
                            prefixIcon: const Icon(Icons.calendar_today, size: 18),
                            suffixIcon: Icon(Icons.edit_calendar, size: 18, color: c.accentPrimary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (garage.fuelTypes.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: garage.fuelTypes.contains(editFuelType) ? editFuelType : garage.fuelTypes.first,
                        decoration: const InputDecoration(
                          labelText: 'Fuel Type',
                          prefixIcon: Icon(Icons.local_gas_station_outlined, size: 18),
                        ),
                        items: garage.fuelTypes
                            .map((ft) => DropdownMenuItem(value: ft, child: Text(ft)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => editFuelType = val);
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (garage.fuelCards.isNotEmpty) ...[
                      DropdownButtonFormField<String?>(
                        isExpanded: true,
                        value: editCardId,
                        decoration: const InputDecoration(
                          labelText: 'Fuel Card (Optional)',
                          prefixIcon: Icon(Icons.credit_card_outlined, size: 18),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None'),
                          ),
                          ...garage.fuelCards.map(
                            (fc) => DropdownMenuItem<String?>(
                              value: fc.id,
                              child: Text(
                                '${fc.cardName} (${Formatters.currency(fc.remaining)})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) => setDialogState(() => editCardId = val),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Total Cost (₹)',
                        prefixIcon: Icon(Icons.currency_rupee, size: 18),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: litersCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Litres Filled (L)',
                        prefixIcon: Icon(Icons.water_drop_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: odoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Odometer (km)',
                        prefixIcon: Icon(Icons.speed, size: 18),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: stationCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Fuel Station (Optional)',
                        prefixIcon: Icon(Icons.storefront_outlined, size: 18),
                      ),
                    ),
                    if (stations.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: stations.map((st) {
                            final sel = stationCtrl.text.trim().toLowerCase() == st.toLowerCase();
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(st, style: const TextStyle(fontSize: 11)),
                                selected: sel,
                                visualDensity: VisualDensity.compact,
                                onSelected: (_) => setDialogState(() {
                                  stationCtrl.text = sel ? '' : st;
                                }),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: remarkCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 160,
                      decoration: const InputDecoration(
                        labelText: 'Remark (Optional)',
                        prefixIcon: Icon(Icons.notes_rounded, size: 18),
                        counterText: '',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newCost = double.tryParse(costCtrl.text.trim()) ?? log.fuelCost;
                    final newLiters = double.tryParse(litersCtrl.text.trim()) ?? log.litersToFill;
                    final newOdo = double.tryParse(odoCtrl.text.trim()) ?? log.fromOdometer;
                    final cleanStation = stationCtrl.text.trim();
                    final cleanRemark = remarkCtrl.text.trim();

                    Navigator.pop(ctx);
                    final ok = await context.read<GarageProvider>().updateFuelLog(log.id, {
                      'date': editDate,
                      'fuel_type': editFuelType,
                      'fuel_cost': newCost,
                      'liters_to_fill': newLiters,
                      'from_odometer': newOdo,
                      'station_name': cleanStation.isNotEmpty ? cleanStation : null,
                      'remark': cleanRemark.isNotEmpty ? cleanRemark : null,
                      'fuel_card_id': editCardId,
                    });

                    if (context.mounted) {
                      if (ok) {
                        showCustomSnackBar(context, 'Entry #${log.runId} updated!');
                      } else {
                        showCustomSnackBar(context, 'Failed to update log.', isError: true);
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// F4 Option A: Tap card to open full Log Detail Pop-Up (user inputs + Mileage, keeping fuel_consumed/distance hidden)
  void _showLogDetailSheet(BuildContext context, FuelLog log) {
    final c = context.appColors;
    final garage = context.read<GarageProvider>();
    final fuelColor = AppTheme.hexToColor(CacheService.getFuelColorHex(log.fuelType));
    final linkedCard = garage.fuelCardById(log.fuelCardId);
    final String mileageText = log.isPartial
        ? 'Partial Fill (Cycle Open)'
        : (log.calculatedMileage > 0 ? Formatters.mileage(log.calculatedMileage) : 'In Tank (Active)');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: BoxDecoration(
            color: c.surfaceCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
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
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Entry #${log.runId}',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (log.isPartial ? c.costAmber : c.mileageGreen).withOpacity(0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          log.isPartial ? 'PARTIAL' : 'FULL TANK',
                          style: TextStyle(
                            color: log.isPartial ? c.costAmber : c.mileageGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: c.textSecondary),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: c.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.speed_rounded, color: c.mileageGreen, size: 20),
                        const SizedBox(width: 10),
                        Text('Mileage', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                        const Spacer(),
                        Text(
                          mileageText,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: (!log.isPartial && log.calculatedMileage > 0) ? c.mileageGreen : c.textSecondary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  _DetailRow(label: 'Date', value: Formatters.shortDate(log.date)),
                  _DetailRow(
                    label: 'Fuel Type',
                    value: log.fuelType,
                    leadingDotColor: fuelColor,
                  ),
                  if (log.stationName != null && log.stationName!.isNotEmpty)
                    _DetailRow(label: 'Fuel Station', value: log.stationName!),
                  if (linkedCard != null)
                    _DetailRow(label: 'Fuel Card', value: linkedCard.cardName),
                  _DetailRow(label: 'Total Cost', value: Formatters.currency(log.fuelCost, decimals: true)),
                  _DetailRow(label: 'Volume Filled', value: Formatters.liters(log.litersToFill, compact: false)),
                  if (log.costPerLtr > 0)
                    _DetailRow(label: 'Cost / Litre', value: Formatters.currencyPerLiter(log.costPerLtr)),
                  _DetailRow(label: 'Odometer', value: Formatters.odometer(log.fromOdometer)),
                  if (log.fuelDensity > 0)
                    _DetailRow(label: 'Fuel Density', value: '${log.fuelDensity.toStringAsFixed(1)} kg/m³'),
                  if (log.remark != null && log.remark!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Remark', style: TextStyle(fontSize: 11, color: c.textMuted)),
                          const SizedBox(height: 4),
                          Text(log.remark!, style: TextStyle(fontSize: 13, color: c.textPrimary, height: 1.35)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _showDeleteDialog(context, log);
                          },
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          label: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _showEditDialog(context, log);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit Entry'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final garage = context.watch<GarageProvider>();
    final fuelLogs = garage.fuelLogs;
    final serviceLogs = garage.serviceLogs;

    return Scaffold(
      appBar: AppBar(
        title: Text('Logs — ${garage.activeVehicleName}'),
      ),
      body: RefreshIndicator(
        onRefresh: () => garage.loadGarage(),
        color: c.accentPrimary,
        backgroundColor: c.surfaceCard,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: SegmentedButton<bool>(
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
                    onSelectionChanged: (sel) => _setMode(sel.first),
                  ),
                ),
                Expanded(
                  child: _isServiceMode
                      ? _ServiceLogsTabContent(
                          garage: garage,
                          logs: serviceLogs,
                        )
                      : _buildFuelLogsList(context, garage, fuelLogs, c),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFuelLogsList(
    BuildContext context,
    GarageProvider garage,
    List<FuelLog> logs,
    AppSemanticColors c,
  ) {
    if (logs.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.58,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 60, color: c.textMuted),
              const SizedBox(height: 16),
              Text(
                'No Fill-Up Logs Recorded',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'No logs recorded for \'${garage.activeVehicleName}\' yet.\nLog your first fill-up to start tracking!',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadView()));
                },
                icon: const Icon(Icons.local_gas_station, size: 18, color: Colors.white),
                label: const Text('Log First Fill-Up'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final fuelColor = AppTheme.hexToColor(CacheService.getFuelColorHex(log.fuelType));
        final hasMileage = !log.isPartial && log.calculatedMileage > 0;
        final String badgeText = log.isPartial
            ? 'Partial'
            : (hasMileage ? Formatters.mileage(log.calculatedMileage) : 'In Tank');
        final Color badgeColor = hasMileage
            ? c.mileageGreen
            : (log.isPartial ? c.costAmber : c.textMuted);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              HapticFeedback.selectionClick();
              _showLogDetailSheet(context, log);
            },
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Entry #${log.runId}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (log.isPartial)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.costAmber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PARTIAL',
                            style: TextStyle(
                              color: c.costAmber,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        Formatters.shortDate(log.date),
                        style: TextStyle(color: c.textSecondary, fontSize: 12),
                      ),
                      if (log.stationName != null && log.stationName!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.storefront_outlined, size: 12, color: c.textMuted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            log.stationName!,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Divider(height: 18, color: c.subtleBorder.withOpacity(0.6)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fuel Cost', style: TextStyle(color: c.textMuted, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            Formatters.currency(log.fuelCost),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: c.costAmber,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Volume', style: TextStyle(color: c.textMuted, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            Formatters.liters(log.litersToFill),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: c.distanceBlue,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Odometer', style: TextStyle(color: c.textMuted, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            Formatters.odometer(log.fromOdometer),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: c.textPrimary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Fuel', style: TextStyle(color: c.textMuted, fontSize: 11)),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: fuelColor),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                log.fuelType,
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: c.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
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

class _ServiceLogsTabContent extends StatelessWidget {
  final GarageProvider garage;
  final List<ServiceLog> logs;

  const _ServiceLogsTabContent({
    required this.garage,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    if (logs.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.58,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.build_outlined, size: 60, color: c.textMuted),
              const SizedBox(height: 16),
              Text(
                'No Service Logs Recorded',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'No logs recorded for \'${garage.activeVehicleName}\' yet.\nLog your first service to start tracking!',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UploadView(initialIsService: true),
                    ),
                  );
                },
                icon: const Icon(Icons.build_outlined, size: 18, color: Colors.white),
                label: const Text('Log First Service'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ServiceLogCard(
            log: log,
            onTap: () => showServiceLogDetailModal(context, log),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? leadingDotColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.leadingDotColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
          const Spacer(),
          if (leadingDotColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: leadingDotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
