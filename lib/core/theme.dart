import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InfurnusTheme {
  // Brand Colors: White + Emerald Green Theme with Black Buttons
  static const Color primaryGreen = Color(0xFF047857);
  static const Color greenDark = Color(0xFF065F46);
  static const Color greenLight = Color(0xFFECFDF5);
  static const Color greenBorder = Color(0xFFA7F3D0);

  static const Color bgWhite = Color(0xFFFFFFFF); // Clean White Background
  static const Color surfaceCard = Colors.white;
  static const Color buttonBlack = Colors.black; // ALL BUTTONS BLACK

  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  static const Color successGreen = Color(0xFF047857);
  static const Color warningAmber = Color(0xFF92400E);
  static const Color dangerRed = Color(0xFFB42318);
  static const Color infoBlue = Color(0xFF1D4ED8);

  static const double titleSize = 24;
  static const double sectionSize = 20;
  static const double bodySize = 15;
  static const double helperSize = 14;
  static const double labelSize = 12;

  // Aliases for White + Green palette
  static const Color primaryDark = Colors.white;
  static const Color primaryNavy = Color(0xFFECFDF5);
  static const Color accentOrange = Color(0xFF10B981);

  static ThemeData get lightTheme {
    final filledStyle =
        ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFFE1E5E2);
            }
            if (states.contains(WidgetState.pressed)) {
              return const Color(0xFF333333);
            }
            return buttonBlack;
          }),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? textMuted
                : Colors.white,
          ),
        );
    final outlinedStyle =
        OutlinedButton.styleFrom(
          side: const BorderSide(color: buttonBlack, width: 1.5),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? textMuted : buttonBlack,
          ),
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? primaryGreen.withValues(alpha: 0.12)
                : null,
          ),
        );
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
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedStyle),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        labelStyle: GoogleFonts.inter(color: textMuted),
        hintStyle: GoogleFonts.inter(color: textMuted),
      ),
      textTheme: TextTheme(
        headlineMedium: GoogleFonts.inter(
          color: textDark,
          fontSize: titleSize,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: GoogleFonts.inter(
          color: textDark,
          fontSize: sectionSize,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: GoogleFonts.inter(
          color: textDark,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(color: textDark, fontSize: bodySize),
        bodyMedium: GoogleFonts.inter(color: textDark, fontSize: helperSize),
        bodySmall: GoogleFonts.inter(
          color: textMuted,
          fontSize: helperSize,
          height: 1.35,
        ),
        labelSmall: GoogleFonts.inter(color: textMuted, fontSize: labelSize),
      ),
    );
  }
}
