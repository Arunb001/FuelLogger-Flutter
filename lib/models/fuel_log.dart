class FuelLog {
  final String id;
  final String userId;
  final String vehicleId;
  final int runId;
  final String date;
  final String fuelType;
  final double fuelDensity;
  final double fuelCost;
  final double litersToFill;
  final double costPerLtr;
  final double fromOdometer;
  final double toOdometer;
  final double distanceTraveled;
  final double fuelConsumed;
  final double calculatedMileage;
  final double costPerKm;
  final String fuelFillFlag; // 'F' for Full, 'P' for Partial
  final String? stationName;
  final String? remark;
  final String? fuelCardId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FuelLog({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.runId,
    required this.date,
    required this.fuelType,
    this.fuelDensity = 0.0,
    required this.fuelCost,
    required this.litersToFill,
    this.costPerLtr = 0.0,
    this.fromOdometer = 0.0,
    this.toOdometer = 0.0,
    this.distanceTraveled = 0.0,
    this.fuelConsumed = 0.0,
    this.calculatedMileage = 0.0,
    this.costPerKm = 0.0,
    this.fuelFillFlag = 'F',
    this.stationName,
    this.remark,
    this.fuelCardId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPartial => fuelFillFlag.toUpperCase() == 'P';

  static String? _cleanOptionalText(dynamic raw) {
    if (raw == null) return null;
    final trimmed = raw.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  factory FuelLog.fromJson(Map<String, dynamic> json) {
    return FuelLog(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      vehicleId: json['vehicle_id']?.toString() ?? '',
      runId: int.tryParse(json['run_id']?.toString() ?? '1') ?? 1,
      date: json['date']?.toString() ?? '',
      fuelType: json['fuel_type']?.toString() ?? 'Standard petrol',
      fuelDensity: double.tryParse(json['fuel_density']?.toString() ?? '0') ?? 0.0,
      fuelCost: double.tryParse(json['fuel_cost']?.toString() ?? '0') ?? 0.0,
      litersToFill: double.tryParse(json['liters_to_fill']?.toString() ?? '0') ?? 0.0,
      costPerLtr: double.tryParse(json['cost_per_ltr']?.toString() ?? '0') ?? 0.0,
      fromOdometer: double.tryParse(json['from_odometer']?.toString() ?? '0') ?? 0.0,
      toOdometer: double.tryParse(json['to_odometer']?.toString() ?? '0') ?? 0.0,
      distanceTraveled: double.tryParse(json['distance_traveled']?.toString() ?? '0') ?? 0.0,
      fuelConsumed: double.tryParse(json['fuel_consumed']?.toString() ?? '0') ?? 0.0,
      calculatedMileage: double.tryParse(json['calculated_mileage']?.toString() ?? '0') ?? 0.0,
      costPerKm: double.tryParse(json['cost_per_km']?.toString() ?? '0') ?? 0.0,
      fuelFillFlag: json['fuel_fill_flag']?.toString() ?? 'F',
      stationName: _cleanOptionalText(json['station_name']),
      remark: _cleanOptionalText(json['remark']),
      fuelCardId: _cleanOptionalText(json['fuel_card_id']),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final cleanStation = _cleanOptionalText(stationName);
    final cleanRemark = _cleanOptionalText(remark);
    final cleanCardId = _cleanOptionalText(fuelCardId);
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'vehicle_id': vehicleId,
      'run_id': runId,
      'date': date,
      'fuel_type': fuelType,
      'fuel_density': fuelDensity,
      'fuel_cost': fuelCost,
      'liters_to_fill': litersToFill,
      'cost_per_ltr': costPerLtr,
      'from_odometer': fromOdometer,
      'to_odometer': toOdometer,
      'distance_traveled': distanceTraveled,
      'fuel_consumed': fuelConsumed,
      'calculated_mileage': calculatedMileage,
      'cost_per_km': costPerKm,
      'fuel_fill_flag': fuelFillFlag,
      'station_name': cleanStation,
      'remark': cleanRemark,
      if (cleanCardId != null) 'fuel_card_id': cleanCardId,
    };
  }

  FuelLog copyWith({
    String? id,
    String? userId,
    String? vehicleId,
    int? runId,
    String? date,
    String? fuelType,
    double? fuelDensity,
    double? fuelCost,
    double? litersToFill,
    double? costPerLtr,
    double? fromOdometer,
    double? toOdometer,
    double? distanceTraveled,
    double? fuelConsumed,
    double? calculatedMileage,
    double? costPerKm,
    String? fuelFillFlag,
    String? stationName,
    String? remark,
    String? fuelCardId,
    bool clearStationName = false,
    bool clearRemark = false,
    bool clearFuelCardId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FuelLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vehicleId: vehicleId ?? this.vehicleId,
      runId: runId ?? this.runId,
      date: date ?? this.date,
      fuelType: fuelType ?? this.fuelType,
      fuelDensity: fuelDensity ?? this.fuelDensity,
      fuelCost: fuelCost ?? this.fuelCost,
      litersToFill: litersToFill ?? this.litersToFill,
      costPerLtr: costPerLtr ?? this.costPerLtr,
      fromOdometer: fromOdometer ?? this.fromOdometer,
      toOdometer: toOdometer ?? this.toOdometer,
      distanceTraveled: distanceTraveled ?? this.distanceTraveled,
      fuelConsumed: fuelConsumed ?? this.fuelConsumed,
      calculatedMileage: calculatedMileage ?? this.calculatedMileage,
      costPerKm: costPerKm ?? this.costPerKm,
      fuelFillFlag: fuelFillFlag ?? this.fuelFillFlag,
      stationName: clearStationName ? null : (stationName ?? this.stationName),
      remark: clearRemark ? null : (remark ?? this.remark),
      fuelCardId: clearFuelCardId ? null : (fuelCardId ?? this.fuelCardId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
