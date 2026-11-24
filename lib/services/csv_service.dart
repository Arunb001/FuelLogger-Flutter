import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/fuel_log.dart';
import 'telemetry_engine.dart';

class CsvService {
  /// Generates a minimal sample CSV template with header and exactly 1 sample row as requested.
  static String generateSampleCsv() {
    return '''run_id,date,fuel_type,odometer,fuel_cost,liters_to_fill,fuel_density,fill_flag
1,2026-11-01,Standard petrol,1929,801.00,9.30,750.7,F''';
  }

  /// Parses CSV string into structured FuelLog objects with full cycle telemetry recalculated.
  static List<FuelLog> parseCsv(
    String csvText, {
    required String userId,
    required String vehicleId,
    int startRunId = 1,
  }) {
    final clean = csvText.replaceFirst('\uFEFF', '').trim();
    if (clean.isEmpty) return [];

    // Parse CSV rows handling quoted commas and newlines
    List<List<dynamic>> rows;
    try {
      rows = const CsvDecoder().convert(clean.replaceAll('\r\n', '\n'));
    } catch (_) {
      // Fallback simple line-by-line split
      rows = clean
          .split('\n')
          .map((line) => line.split(',').map((e) => e.trim()).toList())
          .toList();
    }

    if (rows.isEmpty) return [];

    // Determine header row index and column positions
    int headerRowIdx = -1;
    int colRunId = -1;
    int colDate = -1;
    int colFuelType = -1;
    int colOdo = -1;
    int colCost = -1;
    int colLiters = -1;
    int colDensity = -1;
    int colFlag = -1;

    for (int i = 0; i < rows.length && i < 3; i++) {
      final r = rows[i].map((c) => c.toString().trim().toLowerCase()).toList();
      for (int c = 0; c < r.length; c++) {
        final val = r[c];
        if (val == 'run_id' || val == 'run' || val.contains('sno') || val.contains('s_no') || val.contains('s.no') || val == 'id' || (val.contains('run') && colRunId == -1)) {
          colRunId = c;
        } else if (val.contains('date') || val.contains('time')) {
          if (colDate == -1) colDate = c;
        } else if (val.contains('flag') || val.contains('fill_type')) {
          colFlag = c;
        } else if (val == 'fuel_type' || val == 'fuel' || val == 'type' ||
            ((val.contains('fuel') || val.contains('type')) &&
             !val.contains('cost') &&
             !val.contains('density') &&
             !val.contains('flag') &&
             !val.contains('consumed') &&
             !val.contains('eff') &&
             !val.contains('econ') &&
             !val.contains('mileage') &&
             !val.contains('liter') &&
             !val.contains('litre') &&
             !val.contains('volume') &&
             !val.contains('qty'))) {
          if (colFuelType == -1) colFuelType = c;
        }

        if (val == 'from_odometer' || val == 'odometer' ||
            ((val.contains('odo') || val.contains('meter')) && !val.startsWith('to_'))) {
          colOdo = c;
        } else if (val.contains('cost') || val.contains('price') || val.contains('amount')) {
          if (!val.contains('per') && colCost == -1) colCost = c;
        } else if (val.contains('liter') || val.contains('litre') || val.contains('volume') || val.contains('qty')) {
          if (!val.contains('cost') && !val.contains('per') && !val.contains('consumed') && colLiters == -1) {
            colLiters = c;
          }
        } else if (val.contains('density')) {
          colDensity = c;
        }
      }

      // If at least cost/liters and odo/date are identified, consider this a header row
      if (colOdo != -1 || colCost != -1 || colLiters != -1) {
        headerRowIdx = i;
        break;
      }
    }

    final bool hasHeader = headerRowIdx != -1;
    final int dataStart = hasHeader ? headerRowIdx + 1 : 0;
    final int totalDataRows = rows.length - dataStart;
    final List<FuelLog> logs = [];
    int autoRun = startRunId;

    for (int i = dataStart; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) {
        continue;
      }

      String getCol(int idx, int fallbackPos) {
        if (idx != -1) {
          return idx < row.length ? row[idx].toString().trim() : '';
        }
        // Only fall back to fixed positional columns when CSV has no header row
        if (!hasHeader && fallbackPos < row.length) {
          return row[fallbackPos].toString().trim();
        }
        return '';
      }

      final rawRunId = getCol(colRunId, 0);
      final rawDate = getCol(colDate, 1);
      final rawFuelType = getCol(colFuelType, 2);
      final rawOdo = getCol(colOdo, 3);
      final rawCost = getCol(colCost, 4);
      final rawLiters = getCol(colLiters, 5);
      final rawDensity = getCol(colDensity, 6);
      final rawFlag = getCol(colFlag, 7);

      // Clean & parse numbers
      final double cost = _parseDouble(rawCost);
      final double liters = _parseDouble(rawLiters);
      final double odo = _parseDouble(rawOdo);
      final double density = _parseDouble(rawDensity);

      // Skip lines that have 0 cost and 0 liters and 0 odo (empty lines)
      if (cost == 0 && liters == 0 && odo == 0) {
        continue;
      }

      int runId = int.tryParse(rawRunId) ?? autoRun;
      if (runId <= 0) runId = autoRun;
      autoRun = runId + 1;

      String fuelType = rawFuelType.isNotEmpty ? rawFuelType : 'Standard petrol';
      if (fuelType == '-' || fuelType == '0') fuelType = 'Standard petrol';

      String flag = rawFlag.toUpperCase();
      if (flag != 'P' && flag != 'F') {
        flag = flag.startsWith('P') ? 'P' : 'F';
      }

      final int dataIdx = i - dataStart;
      final String date = _normalizeDate(rawDate, dataIdx, totalDataRows);

      logs.add(FuelLog(
        id: '', // Will be assigned by database or cache
        userId: userId,
        vehicleId: vehicleId,
        runId: runId,
        date: date,
        fuelType: fuelType,
        fuelDensity: density,
        fuelCost: cost,
        litersToFill: liters,
        costPerLtr: liters > 0 ? double.parse((cost / liters).toStringAsFixed(2)) : 0.0,
        fromOdometer: odo,
        toOdometer: 0.0,
        distanceTraveled: 0.0,
        fuelConsumed: liters,
        calculatedMileage: 0.0,
        costPerKm: 0.0,
        fuelFillFlag: flag,
        createdAt: DateTime.now(),
      ));
    }

    if (logs.isEmpty) return [];

    // In append mode (startRunId > 1), prevent CSV files numbered 1..N from colliding with existing run_ids
    if (startRunId > 1) {
      int minRunId = logs.first.runId;
      for (final l in logs) {
        if (l.runId < minRunId) minRunId = l.runId;
      }
      if (minRunId < startRunId) {
        final offset = startRunId - minRunId;
        for (int idx = 0; idx < logs.length; idx++) {
          logs[idx] = logs[idx].copyWith(runId: logs[idx].runId + offset);
        }
      }
    }

    // Recalculate 16-column cycle math (odometer deltas, full/partial tank math, mpg/kpl)
    return TelemetryEngine.recalculateCycles(logs);
  }

  /// Exports fuel logs to a standard CSV string.
  static String exportLogsToCsv(List<FuelLog> logs) {
    if (logs.isEmpty) return '';

    // Sort ascending for standard chronology
    final sorted = List<FuelLog>.from(logs);
    TelemetryEngine.sortAscending(sorted);

    final buffer = StringBuffer();
    buffer.writeln('run_id,date,fuel_type,fuel_density,fuel_cost,liters_to_fill,cost_per_ltr,from_odometer,to_odometer,distance_traveled,fuel_consumed,calculated_mileage,cost_per_km,fuel_fill_flag');

    for (final l in sorted) {
      buffer.writeln(
        '${l.runId},'
        '${l.date},'
        '${l.fuelType},'
        '${l.fuelDensity.toStringAsFixed(1)},'
        '${l.fuelCost.toStringAsFixed(2)},'
        '${l.litersToFill.toStringAsFixed(2)},'
        '${l.costPerLtr.toStringAsFixed(2)},'
        '${l.fromOdometer},'
        '${l.toOdometer},'
        '${l.distanceTraveled.toStringAsFixed(1)},'
        '${l.fuelConsumed.toStringAsFixed(2)},'
        '${l.calculatedMileage.toStringAsFixed(2)},'
        '${l.costPerKm.toStringAsFixed(2)},'
        '${l.fuelFillFlag}'
      );
    }
    return buffer.toString();
  }

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    final s = val.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(s) ?? 0.0;
  }


  static String _normalizeDate(String raw, int fallbackIdx, [int totalRows = 30]) {
    final clean = raw.trim();
    if (clean.isEmpty || clean == '-') {
      // Fallback: staggered dates leading up to today based on CSV length
      final span = totalRows > 1 ? totalRows - 1 : 0;
      final daysAgo = (span - fallbackIdx).clamp(0, 3650);
      final d = DateTime.now().subtract(Duration(days: daysAgo));
      return DateFormat('yyyy-MM-dd').format(d);
    }

    // Try standard yyyy-MM-dd
    if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(clean)) {
      try {
        final dt = DateTime.parse(clean);
        return DateFormat('yyyy-MM-dd').format(dt);
      } catch (_) {}
    }

    // Try dd/MM/yyyy, dd-MM-yyyy, MM/dd/yyyy, yyyy/MM/dd, etc.
    final slashParts = clean.split(RegExp(r'[/.-]'));
    if (slashParts.length == 3) {
      if (slashParts[0].length <= 2 && slashParts[2].length == 4) {
        int d = int.tryParse(slashParts[0]) ?? 1;
        int m = int.tryParse(slashParts[1]) ?? 1;
        final y = int.tryParse(slashParts[2]) ?? 2026;
        if (m > 12 && d >= 1 && d <= 12) {
          final tmp = d;
          d = m;
          m = tmp;
        }
        return DateFormat('yyyy-MM-dd').format(DateTime(y, m, d));
      } else if (slashParts[0].length == 4 && slashParts[2].length <= 2) {
        final y = int.tryParse(slashParts[0]) ?? 2026;
        final m = int.tryParse(slashParts[1]) ?? 1;
        final d = int.tryParse(slashParts[2]) ?? 1;
        return DateFormat('yyyy-MM-dd').format(DateTime(y, m, d));
      }
    }

    final parsed = DateTime.tryParse(clean);
    if (parsed != null) {
      return DateFormat('yyyy-MM-dd').format(parsed);
    }

    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }
}
