import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/vehicle.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/vehicle_banner.dart';

/// Per-vehicle Pollution Certificate (PUC) expiry & renewal tracker (F10 / P7.8).
class PollutionCertificateView extends StatefulWidget {
  const PollutionCertificateView({super.key});

  @override
  State<PollutionCertificateView> createState() =>
      _PollutionCertificateViewState();
}

class _PollutionCertificateViewState extends State<PollutionCertificateView> {
  final _expiryCtrl = TextEditingController();
  int _renewalMonths = 6;
  String? _syncedVehicleId;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = context.watch<GarageProvider>().activeVehicle;
    if (active != null && active.id != _syncedVehicleId) {
      _syncedVehicleId = active.id;
      _expiryCtrl.text = active.pucExpiryDate ?? '';
      _renewalMonths = Vehicle.pucRenewalOptions.contains(active.pucRenewalMonths)
          ? active.pucRenewalMonths
          : 6;
    }
  }

  @override
  void dispose() {
    _expiryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final initial = DateTime.tryParse(_expiryCtrl.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() {
        _expiryCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _savePuc({bool showToast = true}) async {
    if (_isSaving) return;
    final garage = context.read<GarageProvider>();
    final active = garage.activeVehicle;
    if (active == null) return;

    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    final expiry = _expiryCtrl.text.trim().isEmpty ? null : _expiryCtrl.text.trim();
    final ok = await garage.updateVehiclePuc(
      vehicleId: active.id,
      pucExpiryDate: expiry,
      pucRenewalMonths: _renewalMonths,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (showToast) {
      showCustomSnackBar(
        context,
        ok ? 'PUC details saved for ${active.name}' : 'Failed to save PUC details',
        isError: !ok,
      );
    }
  }

  Future<void> _renewToday() async {
    if (_isSaving) return;
    final garage = context.read<GarageProvider>();
    final active = garage.activeVehicle;
    if (active == null) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final ok = await garage.renewVehiclePucToday(
      vehicleId: active.id,
      renewalMonths: _renewalMonths,
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _expiryCtrl.text = garage.activeVehicle?.pucExpiryDate ?? '';
    });

    showCustomSnackBar(
      context,
      ok
          ? 'PUC renewed for $_renewalMonths months!'
          : 'Failed to renew PUC',
      isError: !ok,
    );
  }

  Future<void> _clearExpiry() async {
    setState(() => _expiryCtrl.clear());
    await _savePuc(showToast: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final garage = context.watch<GarageProvider>();
    final vehicle = garage.activeVehicle;

    final previewVehicle = (vehicle ??
            Vehicle(id: '', userId: '', name: 'My Vehicle', isActive: true))
        .copyWith(
      pucExpiryDate: _expiryCtrl.text.trim().isEmpty ? null : _expiryCtrl.text.trim(),
      clearPucExpiryDate: _expiryCtrl.text.trim().isEmpty,
      pucRenewalMonths: _renewalMonths,
    );

    final status = previewVehicle.pucStatus();
    final remDays = previewVehicle.pucRemainingDays();
    final nextRenewPreview = DateFormat('d MMM yyyy').format(
      previewVehicle.computeNextPucExpiry(overrideMonths: _renewalMonths),
    );

    final (
      String statusTitle,
      String statusSubtitle,
      Color statusColor,
      IconData statusIcon,
    ) = switch (status) {
      PucStatus.valid => (
          'Valid (${remDays ?? 0} days left)',
          'Expires on ${Formatters.shortDate(previewVehicle.pucExpiryDate!)} • $_renewalMonths-month cycle',
          c.mileageGreen,
          Icons.verified_user_rounded,
        ),
      PucStatus.expiringSoon => (
          remDays == 0 ? 'Expires Today' : 'Expiring Soon ($remDays days left)',
          'Due on ${Formatters.shortDate(previewVehicle.pucExpiryDate!)} — renew before expiry.',
          c.costAmber,
          Icons.warning_amber_rounded,
        ),
      PucStatus.expired => (
          'Expired (${(remDays ?? 0).abs()} days ago)',
          'Expired on ${Formatters.shortDate(previewVehicle.pucExpiryDate!)} — renewal required.',
          c.accentPrimary,
          Icons.gpp_bad_outlined,
        ),
      PucStatus.notSet => (
          'PUC Expiry Not Set',
          'Set an expiry date or tap Renewed Today to track validity alerts.',
          c.textMuted,
          Icons.verified_user_outlined,
        ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pollution Certificate'),
      ),
      body: RefreshIndicator(
        onRefresh: () => garage.loadGarage(),
        color: c.accentPrimary,
        backgroundColor: c.surfaceCard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const VehicleBanner(),
                  const SizedBox(height: 14),

                  // Status Hero Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: statusColor.withOpacity(0.45)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(statusIcon, color: statusColor, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusTitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                statusSubtitle,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: c.textPrimary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // PUC Form Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Certificate Details',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _expiryCtrl,
                            readOnly: true,
                            onTap: _pickExpiryDate,
                            decoration: InputDecoration(
                              labelText: 'PUC Expiry Date (YYYY-MM-DD)',
                              hintText: 'Tap to select expiry date',
                              prefixIcon: const Icon(Icons.event_available_outlined, size: 20),
                              suffixIcon: _expiryCtrl.text.isNotEmpty
                                  ? IconButton(
                                      tooltip: 'Clear date',
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () => setState(() => _expiryCtrl.clear()),
                                    )
                                  : Icon(Icons.calendar_today_outlined,
                                      size: 18, color: c.accentPrimary),
                            ),
                          ),
                          const SizedBox(height: 18),

                          Text(
                            'Renewal Frequency',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: Vehicle.pucRenewalOptions.map((months) {
                              final selected = _renewalMonths == months;
                              return ChoiceChip(
                                label: Text(
                                  '$months Months',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: selected ? Colors.white : c.textPrimary,
                                  ),
                                ),
                                selected: selected,
                                selectedColor: c.accentPrimary,
                                backgroundColor: c.surfaceElevated,
                                onSelected: (_) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _renewalMonths = months);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '1-tap renew extends expiry to $nextRenewPreview. Reminders alert within 15 days of expiry.',
                            style: TextStyle(fontSize: 11.5, color: c.textMuted, height: 1.35),
                          ),
                          const SizedBox(height: 18),

                          ElevatedButton.icon(
                            onPressed: _isSaving ? null : () => _savePuc(),
                            icon: _isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined, size: 18),
                            label: const Text('Save PUC Details'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _isSaving ? null : _renewToday,
                            icon: const Icon(Icons.autorenew_rounded, size: 18),
                            label: Text('Renewed Today (+$_renewalMonths mo)'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                          if (vehicle?.pucExpiryDate != null ||
                              _expiryCtrl.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: _isSaving ? null : _clearExpiry,
                              child: Text(
                                'Clear Expiry Date',
                                style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
