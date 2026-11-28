import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/env.dart';
import '../../models/fuel_log.dart';
import '../../models/service_log.dart';
import '../../providers/garage_provider.dart';
import '../../services/cache_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/metric_tile.dart';
import '../../widgets/mileage_trend_card.dart';
import '../../widgets/vehicle_banner.dart';
import '../notifications/notifications_view.dart';
import '../settings/settings_view.dart';
import '../upload/upload_view.dart';
import '../utilities/fuel_cards_view.dart';

class HomeView extends StatelessWidget {
  final void Function(int tabIndex)? onSwitchTab;
  final VoidCallback? onOpenServiceLogs;
  final VoidCallback? onLogTap;
  final VoidCallback? onOpenNotifications;

  const HomeView({
    super.key,
    this.onSwitchTab,
    this.onOpenServiceLogs,
    this.onLogTap,
    this.onOpenNotifications,
  });

  (String, String?, Color) _serviceDueMeta(
    ServiceSummary s,
    bool noServiceLogs,
    AppSemanticColors c,
  ) {
    final remKm = s.remainingKm;
    final remDays = s.remainingDays;

    if (s.isOverdue) {
      final parts = <String>[];
      if (remKm != null && remKm <= 0) {
        parts.add('${remKm.abs().round()} km past');
      }
      if (remDays != null && remDays < 0) {
        parts.add('${remDays.abs()}d past');
      }
      return (
        'Overdue',
        parts.isNotEmpty ? parts.join(' • ') : 'Service required',
        c.accentPrimary,
      );
    }

    if (remKm != null && remDays != null) {
      final dayLabel = remDays == 0 ? 'Today' : '$remDays days';
      return (
        '${remKm.round()} km • $dayLabel',
        s.nextDueKm != null ? 'Due at ${Formatters.km(s.nextDueKm!)}' : null,
        s.isDueSoon ? c.costAmber : c.mileageGreen,
      );
    }

    if (remKm != null) {
      return (
        Formatters.km(remKm.round()),
        'Due at ${Formatters.km(s.nextDueKm!)}',
        s.isDueSoon ? c.costAmber : c.mileageGreen,
      );
    }

    if (remDays != null) {
      return (
        remDays == 0 ? 'Due today' : '$remDays days',
        s.nextDueDate != null ? 'On ${Formatters.shortDate(s.nextDueDate!)}' : null,
        s.isDueSoon ? c.costAmber : c.distanceBlue,
      );
    }

    if (s.nextDueKm != null ||
        (s.nextDueDate != null && s.nextDueDate!.isNotEmpty)) {
      return (
        s.nextDueKm != null
            ? Formatters.km(s.nextDueKm!)
            : Formatters.compactDate(s.nextDueDate!),
        'Target scheduled',
        c.distanceBlue,
      );
    }

    return (
      '--',
      noServiceLogs ? 'No service logged' : 'No due target set',
      c.textMuted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final garage = context.watch<GarageProvider>();
    final summary = garage.summary;
    final serviceSummary = garage.serviceSummary;
    final latestLog = garage.fuelLogs.isNotEmpty ? garage.fuelLogs.first : null;
    final latestService =
        garage.serviceLogs.isNotEmpty ? garage.serviceLogs.first : null;
    final primaryCard = garage.primaryFuelCard;

    final avgMileageStr = Formatters.mileage(summary.avgMileage);
    final totalKmStr = Formatters.km(summary.totalDistance);

    final String cardValue;
    final String cardSub;
    final Color cardColor;
    if (primaryCard != null) {
      cardValue = primaryCard.cardLimit > 0 && primaryCard.remaining <= 0
          ? '₹0'
          : Formatters.currency(
              primaryCard.remaining,
              decimals: primaryCard.remaining % 1 != 0,
            );
      cardSub =
          '${primaryCard.cardName} • of ${Formatters.currency(primaryCard.cardLimit)}';
      cardColor = primaryCard.balanceStatus.color(c);
    } else {
      cardValue = '--';
      cardSub = garage.fuelCards.isEmpty
          ? 'Add card in Utilities'
          : 'Set primary in Utilities';
      cardColor = c.textMuted;
    }

    final (svcValue, svcSub, svcColor) = _serviceDueMeta(
      serviceSummary,
      garage.serviceLogs.isEmpty,
      c,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: c.accentPrimary.withOpacity(0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.local_gas_station_rounded, color: c.accentPrimary, size: 18),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                AppConfig.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (AppConfig.isDev) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.costAmber.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'DEV',
                  style: TextStyle(color: c.costAmber, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: NotificationService.inboxVersion,
            builder: (context, _, __) {
              final unread = NotificationService.getUnreadCount();
              return IconButton(
                tooltip: 'Notifications',
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(unread > 9 ? '9+' : '$unread'),
                  backgroundColor: c.accentPrimary,
                  child: Icon(
                    unread > 0
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none_rounded,
                    color: c.textSecondary,
                  ),
                ),
                onPressed: onOpenNotifications ??
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsView()),
                      );
                    },
              );
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: Icon(Icons.settings_outlined, color: c.textSecondary),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsView()));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => garage.loadGarage(),
        color: c.accentPrimary,
        backgroundColor: c.surfaceCard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const VehicleBanner(),
                  if (serviceSummary.needsBanner) ...[
                    const SizedBox(height: 12),
                    _ServiceDueAlertBanner(
                      summary: serviceSummary,
                      onTap: onOpenServiceLogs ?? () => onSwitchTab?.call(2),
                    ),
                  ],
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Average Mileage',
                          value: avgMileageStr,
                          valueColor: c.mileageGreen,
                          icon: Icons.speed_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricTile(
                          label: 'Distance Driven',
                          value: totalKmStr,
                          valueColor: c.distanceBlue,
                          icon: Icons.timeline_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Fuel Card Limit',
                          value: cardValue,
                          subtitle: cardSub,
                          valueColor: cardColor,
                          iconColor: context.isDarkTheme
                              ? const Color(0xFFAB47BC)
                              : const Color(0xFF8E24AA),
                          icon: Icons.credit_card_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FuelCardsView(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricTile(
                          label: 'Service Due',
                          value: svcValue,
                          subtitle: svcSub,
                          valueColor: svcColor,
                          iconColor: context.isDarkTheme
                              ? const Color(0xFFFFD54F)
                              : const Color(0xFFF9A825),
                          icon: Icons.build_circle_outlined,
                          onTap: onOpenServiceLogs ?? () => onSwitchTab?.call(2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  MileageTrendCard(
                    logs: garage.fuelLogs,
                    title: 'Mileage Trend',
                    maxPoints: 8,
                    chartHeight: 136,
                  ),
                  const SizedBox(height: 14),

                  _LatestFillCard(
                    latestLog: latestLog,
                    onViewAll: () => onSwitchTab?.call(2),
                    onLogFirst: onLogTap ??
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UploadView()),
                          );
                        },
                  ),
                  const SizedBox(height: 14),

                  _LatestServiceCard(
                    latestService: latestService,
                    onViewAll: onOpenServiceLogs ?? () => onSwitchTab?.call(2),
                    onLogFirst: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UploadView(initialIsService: true),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LatestFillCard extends StatelessWidget {
  final FuelLog? latestLog;
  final VoidCallback onViewAll;
  final VoidCallback onLogFirst;

  const _LatestFillCard({
    required this.latestLog,
    required this.onViewAll,
    required this.onLogFirst,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    if (latestLog == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: context.isDarkTheme ? null : Border.all(color: c.subtleBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.accentPrimary.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_gas_station_outlined,
                color: c.accentPrimary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No fill-ups logged yet',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Record a fill-up to track mileage.',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onLogFirst,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accentPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(68, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Log',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final log = latestLog!;
    final fuelColor = AppTheme.hexToColor(CacheService.getFuelColorHex(log.fuelType));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: context.isDarkTheme ? null : Border.all(color: c.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Latest Fill-Up',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Entry #${log.runId}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('See all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniMetric(
                label: 'Cost',
                value: Formatters.currency(log.fuelCost),
                color: c.costAmber,
              ),
              _MiniMetric(
                label: 'Volume',
                value: Formatters.liters(log.litersToFill),
                color: c.distanceBlue,
              ),
              _MiniMetric(
                label: 'Odometer',
                value: Formatters.odometer(log.fromOdometer),
                color: c.textPrimary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: fuelColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                log.fuelType,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
              ),
              const Spacer(),
              Text(
                Formatters.shortDate(log.date),
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LatestServiceCard extends StatelessWidget {
  final ServiceLog? latestService;
  final VoidCallback onViewAll;
  final VoidCallback onLogFirst;

  const _LatestServiceCard({
    required this.latestService,
    required this.onViewAll,
    required this.onLogFirst,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    if (latestService == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: context.isDarkTheme ? null : Border.all(color: c.subtleBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.costAmber.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.build_outlined, color: c.costAmber, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No service records yet',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Track maintenance & next due reminders.',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onLogFirst,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accentPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(68, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Log',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final svc = latestService!;
    final nextDueLabel = svc.nextDueKm != null
        ? Formatters.km(svc.nextDueKm!)
        : (svc.nextDueDate != null && svc.nextDueDate!.isNotEmpty
            ? Formatters.compactDate(svc.nextDueDate!)
            : '--');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: context.isDarkTheme ? null : Border.all(color: c.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Latest Service',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.costAmber.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    svc.serviceType,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.costAmber,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniMetric(
                label: 'Cost',
                value: Formatters.currency(svc.totalCost),
                color: c.costAmber,
              ),
              _MiniMetric(
                label: 'Odometer',
                value: Formatters.odometer(svc.odometer),
                color: c.distanceBlue,
              ),
              _MiniMetric(
                label: 'Next Due',
                value: nextDueLabel,
                color: c.mileageGreen,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.store_mall_directory_outlined,
                size: 13,
                color: c.textMuted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  svc.serviceCenter ?? 'Workshop not specified',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.shortDate(svc.serviceDate),
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: c.textMuted)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ServiceDueAlertBanner extends StatelessWidget {
  final ServiceSummary summary;
  final VoidCallback onTap;

  const _ServiceDueAlertBanner({
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isOverdue = summary.isOverdue;
    final tint = isOverdue ? c.accentPrimary : c.costAmber;

    final details = <String>[];
    if (summary.remainingKm != null) {
      final rem = summary.remainingKm!;
      details.add(
        rem <= 0
            ? 'Overdue by ${rem.abs().round()} km'
            : '${rem.round()} km remaining',
      );
    }
    if (summary.remainingDays != null) {
      final d = summary.remainingDays!;
      details.add(
        d < 0
            ? 'Overdue by ${d.abs()} days'
            : (d == 0 ? 'Due today' : '$d days left'),
      );
    }

    return Material(
      color: tint.withOpacity(0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tint.withOpacity(0.45)),
          ),
          child: Row(
            children: [
              Icon(
                isOverdue
                    ? Icons.warning_amber_rounded
                    : Icons.build_circle_outlined,
                color: tint,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOverdue ? 'Service Overdue' : 'Service Due Soon',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: tint,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        details.join(' • '),
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: tint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
