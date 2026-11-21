class FuelTypeMetrics {
  final String fuelType;
  final double distance;
  final double totalCost;
  final double totalLiters;
  final double avgMileage;
  final double bestMileage;
  final double lowestMileage;
  final int count;

  FuelTypeMetrics({
    required this.fuelType,
    this.distance = 0.0,
    this.totalCost = 0.0,
    this.totalLiters = 0.0,
    this.avgMileage = 0.0,
    this.bestMileage = 0.0,
    this.lowestMileage = 0.0,
    this.count = 0,
  });
}

class TelemetrySummary {
  final double totalDistance;
  final double avgMileage;
  final double totalFuelCost;
  final double totalLiters;
  final double bestMileage;
  final double lowestMileage;
  final double latestAvgMileage;
  final double latestDistance;
  final int nextSno;
  final int lastSno;
  final bool isCycleOpen;
  final int totalEntries;
  final int latestOdometer;
  final Map<String, FuelTypeMetrics> byFuelType;

  TelemetrySummary({
    this.totalDistance = 0.0,
    this.avgMileage = 0.0,
    this.totalFuelCost = 0.0,
    this.totalLiters = 0.0,
    this.bestMileage = 0.0,
    this.lowestMileage = 0.0,
    this.latestAvgMileage = 0.0,
    this.latestDistance = 0.0,
    this.nextSno = 1,
    this.lastSno = 0,
    this.isCycleOpen = false,
    this.totalEntries = 0,
    this.latestOdometer = 0,
    this.byFuelType = const {},
  });

  factory TelemetrySummary.empty() => TelemetrySummary();
}
