/// Pollution Certificate (PUC) validity state for a vehicle.
enum PucStatus {
  notSet,
  valid,
  expiringSoon,
  expired,
}

class Vehicle {
  static const List<int> pucRenewalOptions = [3, 6, 12];
  static const int pucExpiringSoonDays = 15;

  final String id;
  final String userId;
  final String name;
  final bool isActive;
  final String iconKey;
  final String colorKey;
  final String? pucExpiryDate;
  final int pucRenewalMonths;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Vehicle({
    required this.id,
    required this.userId,
    required this.name,
    this.isActive = false,
    this.iconKey = 'bike',
    this.colorKey = 'red',
    this.pucExpiryDate,
    this.pucRenewalMonths = 6,
    this.createdAt,
    this.updatedAt,
  });

  static String? _cleanDateStr(dynamic raw) {
    if (raw == null) return null;
    final trimmed = raw.toString().trim();
    if (trimmed.isEmpty) return null;
    return trimmed.split('T').first;
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    final parsedMonths = (json['puc_renewal_months'] as num?)?.toInt() ??
        int.tryParse(json['puc_renewal_months']?.toString() ?? '') ??
        6;
    return Vehicle(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'My Vehicle',
      isActive: json['is_active'] == true,
      iconKey: json['icon_key']?.toString() ?? 'bike',
      colorKey: json['color_key']?.toString() ?? 'red',
      pucExpiryDate: _cleanDateStr(json['puc_expiry_date']),
      pucRenewalMonths: parsedMonths > 0 ? parsedMonths : 6,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'is_active': isActive,
      'icon_key': iconKey,
      'color_key': colorKey,
      'puc_expiry_date': pucExpiryDate,
      'puc_renewal_months': pucRenewalMonths,
    };
  }

  DateTime? get pucExpiryDateTime {
    if (pucExpiryDate == null || pucExpiryDate!.trim().isEmpty) return null;
    return DateTime.tryParse(pucExpiryDate!.trim());
  }

  /// Calendar days remaining until [pucExpiryDate] (negative when expired).
  int? pucRemainingDays([DateTime? now]) {
    final expiry = pucExpiryDateTime;
    if (expiry == null) return null;
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    return expiryDay.difference(today).inDays;
  }

  PucStatus pucStatus([DateTime? now]) {
    final days = pucRemainingDays(now);
    if (days == null) return PucStatus.notSet;
    if (days < 0) return PucStatus.expired;
    if (days <= pucExpiringSoonDays) return PucStatus.expiringSoon;
    return PucStatus.valid;
  }

  /// Computes next PUC expiry date from current expiry (if still valid) or today,
  /// clamping day-of-month for shorter target months.
  DateTime computeNextPucExpiry({DateTime? now, int? overrideMonths}) {
    final months = (overrideMonths ?? pucRenewalMonths) > 0
        ? (overrideMonths ?? pucRenewalMonths)
        : 6;
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final current = pucExpiryDateTime;
    final DateTime base;
    if (current != null) {
      final currentDay = DateTime(current.year, current.month, current.day);
      base = currentDay.isBefore(today) ? today : currentDay;
    } else {
      base = today;
    }
    return addMonthsClamped(base, months);
  }

  static DateTime addMonthsClamped(DateTime date, int months) {
    final totalMonths = (date.year * 12 + (date.month - 1)) + months;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = (totalMonths % 12) + 1;
    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final clampedDay = date.day > lastDay ? lastDay : date.day;
    return DateTime(targetYear, targetMonth, clampedDay);
  }

  Vehicle copyWith({
    String? id,
    String? userId,
    String? name,
    bool? isActive,
    String? iconKey,
    String? colorKey,
    String? pucExpiryDate,
    bool clearPucExpiryDate = false,
    int? pucRenewalMonths,
  }) {
    return Vehicle(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      iconKey: iconKey ?? this.iconKey,
      colorKey: colorKey ?? this.colorKey,
      pucExpiryDate: clearPucExpiryDate ? null : (pucExpiryDate ?? this.pucExpiryDate),
      pucRenewalMonths: pucRenewalMonths ?? this.pucRenewalMonths,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
