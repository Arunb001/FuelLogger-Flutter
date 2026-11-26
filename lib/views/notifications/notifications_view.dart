import 'package:flutter/material.dart';
import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

/// Notification inbox view listing service alerts, fill-up nudges, milestones,
/// and seasonal wishes / announcements.
class NotificationsView extends StatelessWidget {
  final ValueChanged<String?>? onNavigatePayload;

  const NotificationsView({super.key, this.onNavigatePayload});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: NotificationService.inboxVersion,
            builder: (context, _, __) {
              final items = NotificationService.getInboxItems();
              if (items.isEmpty) return const SizedBox.shrink();
              final hasUnread = items.any((e) => !e.isRead);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasUnread)
                    TextButton(
                      onPressed: () => NotificationService.markAllRead(),
                      child: const Text('Mark read'),
                    ),
                  IconButton(
                    tooltip: 'Clear all',
                    icon: Icon(Icons.delete_sweep_outlined, color: c.textSecondary),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear Notifications'),
                          content: const Text(
                            'Remove all past notifications from this inbox?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(
                                'Clear',
                                style: TextStyle(color: c.accentPrimary),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await NotificationService.clearInbox();
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: NotificationService.inboxVersion,
        builder: (context, _, __) {
          final items = NotificationService.getInboxItems();
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: c.distanceBlue.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 32,
                        color: c.distanceBlue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All caught up',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Service reminders, fill-up nudges, mileage milestones, and wishes will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: c.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _NotificationCard(
                    item: item,
                    onTap: () async {
                      await NotificationService.markRead(item.id);
                      if (!context.mounted) return;
                      if (item.routePayload != null &&
                          item.routePayload != 'notifications' &&
                          onNavigatePayload != null) {
                        Navigator.pop(context);
                        onNavigatePayload!(item.routePayload);
                      }
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotificationItem item;
  final VoidCallback onTap;

  const _NotificationCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final (icon, tint) = _styleFor(item.type, c);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: item.isRead
              ? c.subtleBorder
              : tint.withOpacity(0.55),
          width: item.isRead ? 1 : 1.3,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: tint, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: tint.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.type.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: tint,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          Formatters.relativeTime(item.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textMuted,
                          ),
                        ),
                        if (!item.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: c.accentPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            item.isRead ? FontWeight.w600 : FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _styleFor(AppNotificationType type, AppSemanticColors c) {
    switch (type) {
      case AppNotificationType.welcome:
        return (Icons.waving_hand_rounded, c.mileageGreen);
      case AppNotificationType.serviceDue:
        return (Icons.build_circle_outlined, c.costAmber);
      case AppNotificationType.serviceOverdue:
        return (Icons.warning_amber_rounded, c.accentPrimary);
      case AppNotificationType.fillUpNudge:
        return (Icons.local_gas_station_rounded, c.distanceBlue);
      case AppNotificationType.milestone:
        return (Icons.emoji_events_rounded, c.mileageGreen);
      case AppNotificationType.announcement:
        return (Icons.campaign_rounded, c.distanceBlue);
    }
  }
}
