import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _intFormat = NumberFormat('#,##0');
  static final NumberFormat _oneDecFormat = NumberFormat('#,##0.0');
  static final NumberFormat _twoDecFormat = NumberFormat('#,##0.00');

  static String km(num value, {bool forceDecimal = false}) {
    if (value <= 0) return '-- km';
    if (!forceDecimal && value % 1 == 0) {
      return '${_intFormat.format(value.toInt())} km';
    }
    return '${_oneDecFormat.format(value)} km';
  }

  static String odometer(num value) {
    if (value <= 0) return '0 km';
    if (value % 1 == 0) {
      return '${_intFormat.format(value.toInt())} km';
    }
    return '${_oneDecFormat.format(value)} km';
  }

  static String currency(num value, {bool decimals = false}) {
    if (value <= 0) return '₹--';
    if (!decimals && value % 1 == 0) {
      return '₹${_intFormat.format(value.toInt())}';
    }
    return '₹${decimals ? _twoDecFormat.format(value) : _intFormat.format(value.round())}';
  }

  static String currencyPerLiter(num value) {
    if (value <= 0) return '₹--/L';
    return '₹${_twoDecFormat.format(value)}/L';
  }

  static String liters(num value, {bool compact = true}) {
    if (value <= 0) return '-- L';
    if (compact) {
      return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)} L';
    }
    return '${value.toStringAsFixed(2)} L';
  }

  static String mileage(num value) {
    if (value <= 0) return '-- km/l';
    return '${value.toStringAsFixed(2)} km/l';
  }

  static String shortDate(String isoDate) {
    final dt = DateTime.tryParse(isoDate.trim());
    if (dt == null) return isoDate;
    return DateFormat('d MMM yyyy').format(dt);
  }

  static String compactDate(String isoDate) {
    final dt = DateTime.tryParse(isoDate.trim());
    if (dt == null) return isoDate;
    return DateFormat('d MMM').format(dt);
  }

  static String relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dateTime);
  }
}
