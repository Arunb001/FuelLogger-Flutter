import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/fuel_card.dart';

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color canvasBg;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color subtleBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accentPrimary;
  final Color mileageGreen;
  final Color distanceBlue;
  final Color costAmber;
  final Color navBarBg;

  const AppSemanticColors({
    required this.canvasBg,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.subtleBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentPrimary,
    required this.mileageGreen,
    required this.distanceBlue,
    required this.costAmber,
    required this.navBarBg,
  });

  static const AppSemanticColors dark = AppSemanticColors(
    canvasBg: Color(0xFF111318),
    surfaceCard: Color(0xFF191C24),
    surfaceElevated: Color(0xFF222734),
    subtleBorder: Color(0xFF262C3B),
    textPrimary: Color(0xFFF5F7FA),
    textSecondary: Color(0xFFA2ABBD),
    textMuted: Color(0xFF6E778A),
    accentPrimary: Color(0xFFFF5252),
    mileageGreen: Color(0xFF69F0AE),
    distanceBlue: Color(0xFF40C4FF),
    costAmber: Color(0xFFFFD54F),
    navBarBg: Color(0xFF161922),
  );

  static const AppSemanticColors light = AppSemanticColors(
    canvasBg: Color(0xFFF5F7FB),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFECEFF6),
    subtleBorder: Color(0xFFE1E6F0),
    textPrimary: Color(0xFF12151C),
    textSecondary: Color(0xFF566074),
    textMuted: Color(0xFF838C9E),
    accentPrimary: Color(0xFFE53935),
    mileageGreen: Color(0xFF0E8A4D),
    distanceBlue: Color(0xFF0277BD),
    costAmber: Color(0xFFB26A00),
    navBarBg: Color(0xFFFFFFFF),
  );

  @override
  AppSemanticColors copyWith({
    Color? canvasBg,
    Color? surfaceCard,
    Color? surfaceElevated,
    Color? subtleBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accentPrimary,
    Color? mileageGreen,
    Color? distanceBlue,
    Color? costAmber,
    Color? navBarBg,
  }) {
    return AppSemanticColors(
      canvasBg: canvasBg ?? this.canvasBg,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      subtleBorder: subtleBorder ?? this.subtleBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      mileageGreen: mileageGreen ?? this.mileageGreen,
      distanceBlue: distanceBlue ?? this.distanceBlue,
      costAmber: costAmber ?? this.costAmber,
      navBarBg: navBarBg ?? this.navBarBg,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      canvasBg: Color.lerp(canvasBg, other.canvasBg, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      subtleBorder: Color.lerp(subtleBorder, other.subtleBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      mileageGreen: Color.lerp(mileageGreen, other.mileageGreen, t)!,
      distanceBlue: Color.lerp(distanceBlue, other.distanceBlue, t)!,
      costAmber: Color.lerp(costAmber, other.costAmber, t)!,
      navBarBg: Color.lerp(navBarBg, other.navBarBg, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppSemanticColors get appColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.dark;

  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;
}

extension FuelCardStatusColor on FuelCardStatus {
  Color color(AppSemanticColors c) {
    switch (this) {
      case FuelCardStatus.healthy:
        return c.mileageGreen;
      case FuelCardStatus.low:
        return c.costAmber;
      case FuelCardStatus.critical:
        return c.accentPrimary;
    }
  }
}

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

  static Color hexToColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return primary;
    }
  }

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

  static ThemeData get darkTheme => _buildTheme(Brightness.dark, AppSemanticColors.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light, AppSemanticColors.light);

  static ThemeData _buildTheme(Brightness brightness, AppSemanticColors colors) {
    final bool isDark = brightness == Brightness.dark;
    final baseTextTheme = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final textTheme = GoogleFonts.interTextTheme(baseTextTheme).apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.canvasBg,
      primaryColor: colors.accentPrimary,
      extensions: [colors],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.accentPrimary,
        onPrimary: Colors.white,
        secondary: colors.mileageGreen,
        onSecondary: isDark ? Colors.black : Colors.white,
        error: const Color(0xFFD32F2F),
        onError: Colors.white,
        surface: colors.surfaceCard,
        onSurface: colors.textPrimary,
        surfaceContainerHighest: colors.surfaceElevated,
        outline: colors.subtleBorder,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvasBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 1,
        shadowColor: isDark ? Colors.transparent : Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: isDark
              ? BorderSide.none
              : BorderSide(color: colors.subtleBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(
        color: colors.subtleBorder,
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: colors.accentPrimary,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.subtleBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accentPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.transparent : colors.subtleBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.transparent : colors.subtleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.accentPrimary, width: 1.5),
        ),
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
      ),
    );
  }
}
