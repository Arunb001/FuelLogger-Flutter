/// Type of local/in-app notification surfaced in [NotificationsView].
enum AppNotificationType {
  welcome,
  serviceDue,
  serviceOverdue,
  fillUpNudge,
  milestone,
  announcement,
}

extension AppNotificationTypeX on AppNotificationType {
  String get key {
    switch (this) {
      case AppNotificationType.welcome:
        return 'welcome';
      case AppNotificationType.serviceDue:
        return 'service_due';
      case AppNotificationType.serviceOverdue:
        return 'service_overdue';
      case AppNotificationType.fillUpNudge:
        return 'fill_up_nudge';
      case AppNotificationType.milestone:
        return 'milestone';
      case AppNotificationType.announcement:
        return 'announcement';
    }
  }

  String get label {
    switch (this) {
      case AppNotificationType.welcome:
        return 'Welcome';
      case AppNotificationType.serviceDue:
        return 'Service Due';
      case AppNotificationType.serviceOverdue:
        return 'Overdue Service';
      case AppNotificationType.fillUpNudge:
        return 'Fill-Up Reminder';
      case AppNotificationType.milestone:
        return 'Milestone';
      case AppNotificationType.announcement:
        return 'Update & Wishes';
    }
  }

  static AppNotificationType fromKey(String? value) {
    switch (value) {
      case 'welcome':
        return AppNotificationType.welcome;
      case 'service_due':
        return AppNotificationType.serviceDue;
      case 'service_overdue':
        return AppNotificationType.serviceOverdue;
      case 'fill_up_nudge':
        return AppNotificationType.fillUpNudge;
      case 'milestone':
        return AppNotificationType.milestone;
      case 'announcement':
        return AppNotificationType.announcement;
      default:
        return AppNotificationType.announcement;
    }
  }
}

/// Persistent notification inbox entry cached per user in SharedPreferences.
class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.routePayload,
    this.vehicleId,
  });

  final String id;
  final String title;
  final String body;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? routePayload;
  final String? vehicleId;

  AppNotificationItem copyWith({
    bool? isRead,
  }) {
    return AppNotificationItem(
      id: id,
      title: title,
      body: body,
      type: type,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      routePayload: routePayload,
      vehicleId: vehicleId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.key,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'route_payload': routePayload,
      'vehicle_id': vehicleId,
    };
  }

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      type: AppNotificationTypeX.fromKey(json['type']?.toString()),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isRead: json['is_read'] == true,
      routePayload: json['route_payload']?.toString(),
      vehicleId: json['vehicle_id']?.toString(),
    );
  }
}

/// Remote announcement or seasonal wish fetched from `public.app_announcements`.
class AppAnnouncement {
  const AppAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'general',
    this.scheduledFor,
    this.expiresAt,
    this.isActive = true,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime? scheduledFor;
  final DateTime? expiresAt;
  final bool isActive;

  factory AppAnnouncement.fromJson(Map<String, dynamic> json) {
    return AppAnnouncement(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      type: (json['type'] ?? 'general').toString(),
      scheduledFor: json['scheduled_for'] != null
          ? DateTime.tryParse(json['scheduled_for'].toString())
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'scheduled_for': scheduledFor?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_active': isActive,
    };
  }

  /// Whether this announcement is currently within its delivery window.
  bool isDeliverableAt(DateTime now) {
    if (!isActive) return false;
    if (expiresAt != null && !now.isBefore(expiresAt!)) return false;
    return true;
  }
}

/// User notification preferences stored locally in SharedPreferences.
class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = true,
    this.serviceDueReminders = true,
    this.fillUpNudge = true,
    this.fillUpNudgeDays = 14,
    this.wishesAndTips = true,
    this.milestones = true,
  });

  final bool enabled;
  final bool serviceDueReminders;
  final bool fillUpNudge;
  final int fillUpNudgeDays;
  final bool wishesAndTips;
  final bool milestones;

  NotificationPreferences copyWith({
    bool? enabled,
    bool? serviceDueReminders,
    bool? fillUpNudge,
    int? fillUpNudgeDays,
    bool? wishesAndTips,
    bool? milestones,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      serviceDueReminders: serviceDueReminders ?? this.serviceDueReminders,
      fillUpNudge: fillUpNudge ?? this.fillUpNudge,
      fillUpNudgeDays: fillUpNudgeDays ?? this.fillUpNudgeDays,
      wishesAndTips: wishesAndTips ?? this.wishesAndTips,
      milestones: milestones ?? this.milestones,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'service_due_reminders': serviceDueReminders,
      'fill_up_nudge': fillUpNudge,
      'fill_up_nudge_days': fillUpNudgeDays,
      'wishes_and_tips': wishesAndTips,
      'milestones': milestones,
    };
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      enabled: json['enabled'] != false,
      serviceDueReminders: json['service_due_reminders'] != false,
      fillUpNudge: json['fill_up_nudge'] != false,
      fillUpNudgeDays: (json['fill_up_nudge_days'] as num?)?.toInt() ?? 14,
      wishesAndTips: json['wishes_and_tips'] != false,
      milestones: json['milestones'] != false,
    );
  }
}
