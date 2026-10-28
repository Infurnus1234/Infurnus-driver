import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InfurnusTheme {
  // Brand Colors: White + Emerald Green Theme with Black Buttons
  static const Color primaryGreen = Color(0xFF10B981); // Emerald Green
  static const Color greenDark = Color(0xFF047857);
  static const Color greenLight = Color(0xFFECFDF5);
  static const Color greenBorder = Color(0xFFA7F3D0);

  static const Color bgWhite = Color(0xFFFFFFFF); // Clean White Background
  static const Color surfaceCard = Colors.white;
  static const Color buttonBlack = Colors.black; // ALL BUTTONS BLACK

  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderSubtle = Color(0xFFE3E8F0);
  static const Color iconBoxBg = Color(0xFFF1F5F9);

  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color infoBlue = Color(0xFF3B82F6);

  // Aliases for compatibility (Deprecated)
  @Deprecated('Use InfurnusTheme.bgWhite instead')
  static const Color primaryDark = Colors.white;
  @Deprecated('Use InfurnusTheme.primaryGreen instead')
  static const Color accentOrange = Color(0xFF10B981);

  // Spacing & Radius Constants
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;

  static const double r16 = 16.0;
  static const double r12 = 12.0;
  static const double r8 = 8.0;

  @visibleForTesting
  static bool isTesting = false;

  static TextStyle interStyle({
    TextStyle? textStyle,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    if (isTesting) {
      return (textStyle ?? const TextStyle()).copyWith(
        fontFamily: 'Roboto',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    }
    return GoogleFonts.inter(
      textStyle: textStyle,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: bgWhite,
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        secondary: buttonBlack,
        surface: surfaceCard,
        onSurface: textDark,
        error: dangerRed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgWhite,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: interStyle(
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: textDark),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r16),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBlack,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r16),
          ),
          textStyle: interStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonBlack,
          side: const BorderSide(color: buttonBlack, width: 1.5),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r16),
          ),
          textStyle: interStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: s16,
          vertical: s16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r12),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r12),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        labelStyle: interStyle(color: textMuted),
        hintStyle: interStyle(color: textMuted),
      ),
      textTheme: TextTheme(
        displayLarge: interStyle(color: textDark, fontSize: 30, fontWeight: FontWeight.w700),
        headlineMedium: interStyle(
          color: textDark,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: interStyle(
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: interStyle(
          color: textDark,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: interStyle(color: textDark, fontSize: 14),
        bodyMedium: interStyle(color: textMuted, fontSize: 13),
      ),
    );
  }
}
