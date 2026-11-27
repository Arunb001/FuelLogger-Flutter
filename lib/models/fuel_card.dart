class FuelCard {
  final String id;
  final String userId;
  final String cardName;
  final double cardLimit;
  final double limitUsed;
  final bool isPrimary;
  final int resetDayOfMonth;
  final DateTime lastResetAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FuelCard({
    required this.id,
    required this.userId,
    required this.cardName,
    required this.cardLimit,
    this.limitUsed = 0.0,
    this.isPrimary = false,
    this.resetDayOfMonth = 1,
    required this.lastResetAt,
    this.createdAt,
    this.updatedAt,
  });

  double get remaining => (cardLimit - limitUsed).clamp(0.0, double.infinity);

  double get usagePercent =>
      cardLimit > 0 ? (limitUsed / cardLimit).clamp(0.0, 1.0) : 0.0;

  bool get isOverLimit => cardLimit > 0 && limitUsed >= cardLimit;

  String get resetDayOrdinal {
    final d = resetDayOfMonth.clamp(1, 31);
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

  /// Clamps [desiredDay] to the actual number of days in ([year], [month]).
  static int effectiveResetDay(int year, int month, int desiredDay) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return desiredDay.clamp(1, daysInMonth);
  }

  /// Returns the most recent scheduled reset calendar day <= [reference].
  DateTime latestResetBoundary([DateTime? reference]) {
    final now = (reference ?? DateTime.now()).toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonthResetDay = effectiveResetDay(now.year, now.month, resetDayOfMonth);
    final thisMonthReset = DateTime(now.year, now.month, thisMonthResetDay);

    if (!today.isBefore(thisMonthReset)) {
      return thisMonthReset;
    }

    final prevMonthYear = now.month == 1 ? now.year - 1 : now.year;
    final prevMonth = now.month == 1 ? 12 : now.month - 1;
    final prevResetDay = effectiveResetDay(prevMonthYear, prevMonth, resetDayOfMonth);
    return DateTime(prevMonthYear, prevMonth, prevResetDay);
  }

  /// Returns the next upcoming reset date strictly after [reference]
  /// (or today if today IS the reset date and not yet reset today).
  DateTime nextResetDate([DateTime? reference]) {
    final now = (reference ?? DateTime.now()).toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonthResetDay = effectiveResetDay(now.year, now.month, resetDayOfMonth);
    final thisMonthReset = DateTime(now.year, now.month, thisMonthResetDay);

    if (today.isBefore(thisMonthReset)) {
      return thisMonthReset;
    }

    final nextMonthYear = now.month == 12 ? now.year + 1 : now.year;
    final nextMonth = now.month == 12 ? 1 : now.month + 1;
    final nextResetDay = effectiveResetDay(nextMonthYear, nextMonth, resetDayOfMonth);
    return DateTime(nextMonthYear, nextMonth, nextResetDay);
  }

  /// True when [lastResetAt] occurred before the latest scheduled reset boundary.
  bool needsMonthlyReset([DateTime? reference]) {
    final localLast = lastResetAt.toLocal();
    final lastResetDay = DateTime(localLast.year, localLast.month, localLast.day);
    final boundary = latestResetBoundary(reference);
    return lastResetDay.isBefore(boundary);
  }

  factory FuelCard.fromJson(Map<String, dynamic> json) {
    final rawDay = int.tryParse(json['reset_day_of_month']?.toString() ?? '1') ?? 1;
    return FuelCard(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      cardName: json['card_name']?.toString() ?? 'Fuel Card',
      cardLimit: double.tryParse(json['card_limit']?.toString() ?? '0') ?? 0.0,
      limitUsed: double.tryParse(json['limit_used']?.toString() ?? '0') ?? 0.0,
      isPrimary: json['is_primary'] == true,
      resetDayOfMonth: rawDay.clamp(1, 31),
      lastResetAt: json['last_reset_at'] != null
          ? (DateTime.tryParse(json['last_reset_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'card_name': cardName,
      'card_limit': cardLimit,
      'limit_used': limitUsed,
      'is_primary': isPrimary,
      'reset_day_of_month': resetDayOfMonth.clamp(1, 31),
      'last_reset_at': lastResetAt.toUtc().toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    final map = toJson();
    map.remove('id');
    map.remove('created_at');
    map.remove('updated_at');
    return map;
  }

  FuelCard copyWith({
    String? id,
    String? userId,
    String? cardName,
    double? cardLimit,
    double? limitUsed,
    bool? isPrimary,
    int? resetDayOfMonth,
    DateTime? lastResetAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FuelCard(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      cardName: cardName ?? this.cardName,
      cardLimit: cardLimit ?? this.cardLimit,
      limitUsed: limitUsed ?? this.limitUsed,
      isPrimary: isPrimary ?? this.isPrimary,
      resetDayOfMonth: resetDayOfMonth ?? this.resetDayOfMonth,
      lastResetAt: lastResetAt ?? this.lastResetAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
