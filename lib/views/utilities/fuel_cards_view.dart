import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/fuel_card.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/custom_snackbar.dart';

/// Dedicated Fuel Cards tracker page (F9 / P7.7): manages monthly budgets & resets.
class FuelCardsView extends StatelessWidget {
  const FuelCardsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final garage = context.watch<GarageProvider>();
    final cards = garage.fuelCards;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel Cards'),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (context.isDarkTheme
                                  ? const Color(0xFFAB47BC)
                                  : const Color(0xFF8E24AA))
                              .withOpacity(0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.credit_card_rounded,
                          color: context.isDarkTheme
                              ? const Color(0xFFAB47BC)
                              : const Color(0xFF8E24AA),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fuel Cards',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                            Text(
                              'Manage monthly spending limits & auto-resets',
                              style: TextStyle(fontSize: 12, color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (cards.isEmpty)
                    _EmptyFuelCardsState(
                      onAddTap: () => showCardEditorSheet(context),
                    )
                  else ...[
                    ...cards.map(
                      (card) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _FuelCardItem(
                          card: card,
                          onTap: () => showCardEditorSheet(context, existing: card),
                          onSetPrimary: card.isPrimary
                              ? null
                              : () async {
                                  HapticFeedback.selectionClick();
                                  final ok = await garage.setPrimaryFuelCard(card.id);
                                  if (context.mounted && ok) {
                                    showCustomSnackBar(
                                      context,
                                      '${card.cardName} set as primary card',
                                    );
                                  }
                                },
                          onLongPress: () => confirmDeleteCard(context, card),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: () => showCardEditorSheet(context),
                      icon: const Icon(Icons.add_card_rounded, size: 18),
                      label: const Text('Add Fuel Card'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> showCardEditorSheet(
    BuildContext context, {
    FuelCard? existing,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _FuelCardEditorSheet(existing: existing),
    );
  }

  static Future<void> confirmDeleteCard(
    BuildContext context,
    FuelCard card,
  ) async {
    final c = context.appColors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fuel Card?'),
        content: Text(
          'Remove "${card.cardName}"? Your existing fill-up logs will remain intact.',
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
      final deleted = await context.read<GarageProvider>().deleteFuelCard(card.id);
      if (context.mounted) {
        showCustomSnackBar(
          context,
          deleted ? '${card.cardName} removed' : 'Failed to delete card',
          isError: !deleted,
        );
      }
    }
  }
}

class _FuelCardItem extends StatelessWidget {
  final FuelCard card;
  final VoidCallback onTap;
  final VoidCallback? onSetPrimary;
  final VoidCallback onLongPress;

  const _FuelCardItem({
    required this.card,
    required this.onTap,
    required this.onSetPrimary,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final statusColor = card.balanceStatus.color(c);
    final progressColor = card.balanceStatus == FuelCardStatus.healthy
        ? c.distanceBlue
        : statusColor;
    final remainColor = statusColor;
    final pct = (card.usagePercent * 100).round();
    final nextResetStr = DateFormat('d MMM').format(card.nextResetDate());

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.credit_card_rounded,
                          size: 18,
                          color: card.isPrimary ? c.costAmber : c.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            card.cardName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (card.isPrimary)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.costAmber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 13, color: c.costAmber),
                          const SizedBox(width: 3),
                          Text(
                            'PRIMARY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: c.costAmber,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    InkWell(
                      onTap: onSetPrimary,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_outline_rounded, size: 15, color: c.textMuted),
                            const SizedBox(width: 3),
                            Text(
                              'Set primary',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Remaining', style: TextStyle(fontSize: 11, color: c.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          card.cardLimit > 0 && card.remaining <= 0
                              ? '₹0'
                              : Formatters.currency(card.remaining, decimals: card.remaining % 1 != 0),
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: remainColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Monthly Limit', style: TextStyle(fontSize: 11, color: c.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.currency(card.cardLimit),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: card.usagePercent,
                  minHeight: 7,
                  backgroundColor: c.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Text(
                    'Used: ${card.limitUsed <= 0 ? '₹0' : Formatters.currency(card.limitUsed)} ($pct%)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.autorenew_rounded, size: 13, color: c.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Resets ${card.resetDayOrdinal} • Next $nextResetStr',
                    style: TextStyle(fontSize: 11.5, color: c.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFuelCardsState extends StatelessWidget {
  final VoidCallback onAddTap;

  const _EmptyFuelCardsState({required this.onAddTap});

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
              child: Icon(Icons.credit_card_outlined, size: 28, color: c.costAmber),
            ),
            const SizedBox(height: 14),
            Text(
              'No Fuel Cards Added',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add HPCL, BPCL, or fleet cards to track monthly fuel spending limits and automatic resets.',
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
              label: const Text('Add Fuel Card'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FuelCardEditorSheet extends StatefulWidget {
  final FuelCard? existing;

  const _FuelCardEditorSheet({this.existing});

  @override
  State<_FuelCardEditorSheet> createState() => _FuelCardEditorSheetState();
}

class _FuelCardEditorSheetState extends State<_FuelCardEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _limitCtrl;
  late final TextEditingController _usedCtrl;
  late int _resetDay;
  late bool _isPrimary;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    final garage = context.read<GarageProvider>();
    _nameCtrl = TextEditingController(text: ex?.cardName ?? '');
    _limitCtrl = TextEditingController(
      text: ex != null ? _numStr(ex.cardLimit) : '',
    );
    _usedCtrl = TextEditingController(
      text: ex != null ? _numStr(ex.limitUsed) : '0',
    );
    _resetDay = ex?.resetDayOfMonth ?? 1;
    _isPrimary = ex?.isPrimary ?? garage.fuelCards.isEmpty;
  }

  String _numStr(double val) {
    return val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _limitCtrl.dispose();
    _usedCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    final garage = context.read<GarageProvider>();
    final name = _nameCtrl.text.trim();
    final limit = double.tryParse(_limitCtrl.text.trim()) ?? 0.0;
    final used = double.tryParse(_usedCtrl.text.trim()) ?? 0.0;

    bool ok;
    if (widget.existing == null) {
      ok = await garage.addFuelCard(
        cardName: name,
        cardLimit: limit,
        limitUsed: used,
        resetDayOfMonth: _resetDay,
        isPrimary: _isPrimary,
      );
    } else {
      ok = await garage.updateFuelCard(
        widget.existing!.id,
        cardName: name,
        cardLimit: limit,
        limitUsed: used,
        resetDayOfMonth: _resetDay,
        isPrimary: _isPrimary,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      Navigator.pop(context);
      showCustomSnackBar(
        context,
        widget.existing == null ? 'Fuel card added!' : 'Fuel card updated!',
      );
    } else {
      showCustomSnackBar(context, 'Failed to save fuel card', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    const presetDays = [1, 5, 10, 15, 20, 28];

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
                  widget.existing == null ? 'Add Fuel Card' : 'Edit Fuel Card',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Card Name *',
                    hintText: 'e.g. HPCL Card, BPCL Petro',
                    prefixIcon: Icon(Icons.credit_card_outlined, size: 18),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Card name is required' : null,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _limitCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Monthly Limit (₹) *',
                          hintText: 'e.g. 5000',
                          prefixIcon: Icon(Icons.currency_rupee_rounded, size: 18),
                        ),
                        validator: (v) {
                          final val = double.tryParse((v ?? '').trim());
                          if (val == null || val <= 0) return 'Enter limit > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _usedCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Already Used (₹)',
                          prefixIcon: Icon(Icons.payments_outlined, size: 18),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final val = double.tryParse(v.trim());
                          if (val == null || val < 0) return 'Invalid amount';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Text(
                  'Monthly Auto-Reset Day',
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: presetDays.map((day) {
                    final sel = _resetDay == day;
                    return ChoiceChip(
                      label: Text(_ordinal(day), style: const TextStyle(fontSize: 12)),
                      selected: sel,
                      selectedColor: c.accentPrimary,
                      labelStyle: TextStyle(
                        color: sel ? Colors.white : c.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _resetDay = day),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: _resetDay,
                  decoration: const InputDecoration(
                    labelText: 'Exact Reset Day (1–31)',
                    prefixIcon: Icon(Icons.event_repeat_rounded, size: 18),
                  ),
                  items: List.generate(31, (i) => i + 1)
                      .map(
                        (d) => DropdownMenuItem<int>(
                          value: d,
                          child: Text('Day $d (${_ordinal(d)} of each month)'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _resetDay = val);
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Days 29–31 automatically reset on the last day of shorter months.',
                  style: TextStyle(fontSize: 11, color: c.textMuted),
                ),
                const SizedBox(height: 8),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Set as Primary Card'),
                  subtitle: const Text(
                    'Displayed in Home Fuel Card Limit tile',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _isPrimary,
                  onChanged: (val) => setState(() => _isPrimary = val),
                ),
                const SizedBox(height: 14),

                if (widget.existing != null)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  Navigator.pop(context);
                                  await FuelCardsView.confirmDeleteCard(
                                    context,
                                    widget.existing!,
                                  );
                                },
                          icon: Icon(Icons.delete_outline, size: 18, color: c.accentPrimary),
                          label: Text(
                            'Delete',
                            style: TextStyle(
                              color: c.accentPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: c.accentPrimary.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                              : const Text('Save Changes'),
                        ),
                      ),
                    ],
                  )
                else
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                        : const Text('Save Fuel Card'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _ordinal(int d) {
    if (d >= 11 && d <= 13) return '${d}th';
    switch (d % 10) {
      case 1:
        return '${d}st';
      case 2:
        return '${d}nd';
      case 3:
        return '${d}rd';
      default:
        return '${d}th';
    }
  }
}
