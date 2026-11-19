import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color scaffoldBg = Color(0xFF14161C);
  static const Color cardBg = Color(0xFF1E222D);
  static const Color surfaceHigh = Color(0xFF262B38);
  static const Color borderColor = Color(0xFF2D3342);

  static const Color primary = Color(0xFFFF5252);
  static const Color primaryDark = Color(0xFFD32F2F);
  static const Color mileageGreen = Color(0xFF69F0AE);
  static const Color distanceBlue = Color(0xFF40C4FF);
  static const Color costAmber = Color(0xFFFFD54F);

  // Vehicle Theme Color Gradients
  static const Map<String, List<Color>> vehicleGradients = {
    'red': [Color(0xFFB71C1C), Color(0xFF3E0A0A)],
    'blue': [Color(0xFF0D47A1), Color(0xFF081C44)],
    'purple': [Color(0xFF4A148C), Color(0xFF1A0538)],
    'green': [Color(0xFF1B5E20), Color(0xFF0A290E)],
    'orange': [Color(0xFFE65100), Color(0xFF421500)],
    'cyan': [Color(0xFF006064), Color(0xFF002224)],
  };

  static const Map<String, Color> vehiclePrimaryColors = {
    'red': Color(0xFFFF5252),
    'blue': Color(0xFF2196F3),
    'purple': Color(0xFFAB47BC),
    'green': Color(0xFF4CAF50),
    'orange': Color(0xFFFF9800),
    'cyan': Color(0xFF00BCD4),
  };

  static const Map<String, IconData> vehicleIcons = {
    'bike': Icons.two_wheeler,
    'car': Icons.directions_car,
    'bus': Icons.directions_bus,
    'van': Icons.airport_shuttle,
    'truck': Icons.local_shipping,
  };

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffoldBg,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: mileageGreen,
        surface: cardBg,
        onSurface: Colors.white,
        onPrimary: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderColor, width: 0.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
    );
  }
}
