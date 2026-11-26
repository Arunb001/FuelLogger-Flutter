class ServiceLog {
  final String id;
  final String userId;
  final String vehicleId;
  final String serviceDate;
  final double odometer;
  final String serviceType;
  final String? serviceCenter;
  final double totalCost;
  final double? nextDueKm;
  final String? nextDueDate;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const List<String> commonTypes = [
    'Periodic Service',
    'Oil Change',
    'Chain & Sprocket',
    'Brake Service',
    'Tyre Change',
    'Battery',
    'General Repair',
  ];

  const ServiceLog({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.serviceDate,
    required this.odometer,
    required this.serviceType,
    this.serviceCenter,
    required this.totalCost,
    this.nextDueKm,
    this.nextDueDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  static String? _cleanText(dynamic raw) {
    if (raw == null) return null;
    final trimmed = raw.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  factory ServiceLog.fromJson(Map<String, dynamic> json) {
    return ServiceLog(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      vehicleId: json['vehicle_id']?.toString() ?? '',
      serviceDate: json['service_date']?.toString() ?? '',
      odometer: double.tryParse(json['odometer']?.toString() ?? '0') ?? 0.0,
      serviceType: json['service_type']?.toString() ?? 'Periodic Service',
      serviceCenter: _cleanText(json['service_center']),
      totalCost: double.tryParse(json['total_cost']?.toString() ?? '0') ?? 0.0,
      nextDueKm: json['next_due_km'] != null
          ? double.tryParse(json['next_due_km'].toString())
          : null,
      nextDueDate: _cleanText(json['next_due_date']),
      notes: _cleanText(json['notes']),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'vehicle_id': vehicleId,
      'service_date': serviceDate,
      'odometer': odometer,
      'service_type': serviceType,
      'service_center': _cleanText(serviceCenter),
      'total_cost': totalCost,
      'next_due_km': nextDueKm,
      'next_due_date': _cleanText(nextDueDate),
      'notes': _cleanText(notes),
    };
  }

  Map<String, dynamic> toInsertJson() {
    final map = toJson();
    map.remove('id');
    return map;
  }

  ServiceLog copyWith({
    String? id,
    String? userId,
    String? vehicleId,
    String? serviceDate,
    double? odometer,
    String? serviceType,
    String? serviceCenter,
    bool clearServiceCenter = false,
    double? totalCost,
    double? nextDueKm,
    bool clearNextDueKm = false,
    String? nextDueDate,
    bool clearNextDueDate = false,
    String? notes,
    bool clearNotes = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vehicleId: vehicleId ?? this.vehicleId,
      serviceDate: serviceDate ?? this.serviceDate,
      odometer: odometer ?? this.odometer,
      serviceType: serviceType ?? this.serviceType,
      serviceCenter: clearServiceCenter ? null : (serviceCenter ?? this.serviceCenter),
      totalCost: totalCost ?? this.totalCost,
      nextDueKm: clearNextDueKm ? null : (nextDueKm ?? this.nextDueKm),
      nextDueDate: clearNextDueDate ? null : (nextDueDate ?? this.nextDueDate),
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ServiceSummary {
  final double totalCost;
  final double recentCost;
  final double? nextDueKm;
  final double? remainingKm;
  final String? nextDueDate;
  final int? remainingDays;

  const ServiceSummary({
    this.totalCost = 0.0,
    this.recentCost = 0.0,
    this.nextDueKm,
    this.remainingKm,
    this.nextDueDate,
    this.remainingDays,
  });

  factory ServiceSummary.empty() => const ServiceSummary();

  bool get isOverdue =>
      (remainingKm != null && remainingKm! <= 0) ||
      (remainingDays != null && remainingDays! < 0);

  bool get isDueSoon =>
      !isOverdue &&
      ((remainingKm != null && remainingKm! <= 500) ||
          (remainingDays != null && remainingDays! <= 7));

  bool get needsBanner => isOverdue || isDueSoon;

  static ServiceSummary compute(List<ServiceLog> logs, double currentOdometer) {
    if (logs.isEmpty) return ServiceSummary.empty();

    double total = 0.0;
    for (final s in logs) {
      total += s.totalCost;
    }

    // Logs are expected sorted newest-first, compute robustly either way
    final sorted = List<ServiceLog>.from(logs)
      ..sort((a, b) {
        final d = b.serviceDate.compareTo(a.serviceDate);
        if (d != 0) return d;
        return b.odometer.compareTo(a.odometer);
      });

    final latest = sorted.first;
    double? nextKm;
    String? nextDateStr;
    for (final s in sorted) {
      if (nextKm == null && s.nextDueKm != null && s.nextDueKm! > 0) {
        nextKm = s.nextDueKm;
      }
      if (nextDateStr == null && s.nextDueDate != null && s.nextDueDate!.isNotEmpty) {
        nextDateStr = s.nextDueDate;
      }
      if (nextKm != null && nextDateStr != null) break;
    }

    final double? remKm = (nextKm != null && currentOdometer > 0)
        ? double.parse((nextKm - currentOdometer).toStringAsFixed(1))
        : null;

    int? remDays;
    if (nextDateStr != null) {
      final dt = DateTime.tryParse(nextDateStr);
      if (dt != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dueDay = DateTime(dt.year, dt.month, dt.day);
        remDays = dueDay.difference(today).inDays;
      }
    }

    return ServiceSummary(
      totalCost: total,
      recentCost: latest.totalCost,
      nextDueKm: nextKm,
      remainingKm: remKm,
      nextDueDate: nextDateStr,
      remainingDays: remDays,
    );
  }
}
