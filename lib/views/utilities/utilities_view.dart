import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/vehicle.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import 'fuel_cards_view.dart';
import 'pollution_certificate_view.dart';

/// Utilities 2-option hub linking to dedicated [FuelCardsView] and
/// [PollutionCertificateView] screens (P7.7 / F9 / F10).
class UtilitiesView extends StatelessWidget {
  const UtilitiesView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final garage = context.watch<GarageProvider>();
    final cards = garage.fuelCards;
    final primaryCard = garage.primaryFuelCard;
    final vehicle = garage.activeVehicle;

    final String cardsStatus;
    final Color cardsBadgeColor;
    if (cards.isEmpty) {
      cardsStatus = 'Not configured';
      cardsBadgeColor = c.textMuted;
    } else if (primaryCard != null) {
      final remStr = primaryCard.cardLimit > 0 && primaryCard.remaining <= 0
          ? '₹0'
          : Formatters.currency(
              primaryCard.remaining,
              decimals: primaryCard.remaining % 1 != 0,
            );
      cardsStatus =
          '${cards.length} ${cards.length == 1 ? 'card' : 'cards'} • ${primaryCard.cardName} $remStr left';
      cardsBadgeColor = primaryCard.balanceStatus.color(c);
    } else {
      cardsStatus = '${cards.length} ${cards.length == 1 ? 'card' : 'cards'} • No primary set';
      cardsBadgeColor = c.distanceBlue;
    }

    final pucStatus = vehicle?.pucStatus() ?? PucStatus.notSet;
    final pucDays = vehicle?.pucRemainingDays();
    final vLabel = vehicle?.name ?? 'My Vehicle';

    final (String pucStatusText, Color pucColor) = switch (pucStatus) {
      PucStatus.valid => ('$vLabel: ${pucDays ?? 0} days left', c.mileageGreen),
      PucStatus.expiringSoon => (
          pucDays == 0 ? '$vLabel: Expires today' : '$vLabel: $pucDays days left',
          c.costAmber,
        ),
      PucStatus.expired => (
          '$vLabel: Expired ${(pucDays ?? 0).abs()}d ago',
          c.accentPrimary,
        ),
      PucStatus.notSet => ('$vLabel: Not set', c.textMuted),
    };

    final fuelCardAccent = context.isDarkTheme
        ? const Color(0xFFAB47BC)
        : const Color(0xFF8E24AA);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilities'),
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
                  _UtilityHubCard(
                    icon: Icons.credit_card_rounded,
                    iconColor: fuelCardAccent,
                    title: 'Fuel Cards',
                    subtitle: 'Manage monthly card limits & auto-resets',
                    badgeText: cardsStatus,
                    badgeColor: cardsBadgeColor,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FuelCardsView()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _UtilityHubCard(
                    icon: Icons.verified_user_outlined,
                    iconColor: pucStatus == PucStatus.notSet
                        ? c.distanceBlue
                        : pucColor,
                    title: 'Pollution Certificate',
                    subtitle: 'Track vehicle PUC expiry & renewal cycle',
                    badgeText: pucStatusText,
                    badgeColor: pucColor,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PollutionCertificateView(),
                        ),
                      );
                    },
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

class _UtilityHubCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final VoidCallback onTap;

  const _UtilityHubCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
