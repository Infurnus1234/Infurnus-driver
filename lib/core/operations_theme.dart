import 'package:flutter/material.dart';

/// Sampled from the supplied INFURNUS reference, 20 October 2026.
/// White canvas and surfaces, reference green and charcoal actions.
abstract final class Ops {
  static const backgroundPrimary = Color(0xFFFFFFFF);
  static const backgroundSecondary = Color(0xFFF5F8F6);
  static const surfacePrimary = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const surfaceOverlay = Color(0xFFEDF7F0);
  static const textPrimary = Color(0xFF171D1A);
  static const textSecondary = Color(0xFF626B65);
  static const textMuted = Color(0xFF626B65);
  static const borderSubtle = Color(0xFFE2E8E3);
  static const actionPrimary = Color(0xFF007A3E);
  static const actionPrimaryPressed = Color(0xFF006332);
  static const actionDark = Color(0xFF111820);
  static const onAction = Colors.white;
  static const disabled = Color(0xFFE1E5E2);
  static const success = actionPrimary;
  static const warning = Color(0xFF854D0E);
  static const error = Color(0xFFB42318);
  static const info = success;
  static const mapSurface = Color(0xFFF0F3F0);
  static const scrim = Color(0x66000000);
  static const padding = 16.0, gap = 12.0, radius = 12.0, buttonHeight = 48.0;
  static const pageTitleSize = 24.0;
  static const sectionTitleSize = 18.0;
  static const bodySize = 15.0;
  static const helperSize = 13.0;
  static const labelSize = 13.0;
  static const metric = TextStyle(
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static ButtonStyle _buttonStyle({
    required Color background,
    required Color pressed,
  }) =>
      FilledButton.styleFrom(
        minimumSize: const Size(48, buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return disabled;
          if (states.contains(WidgetState.pressed)) return pressed;
          return background;
        }),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.disabled) ? textMuted : onAction,
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? Colors.white.withValues(alpha: 0.12)
              : null,
        ),
      );

  static ButtonStyle get darkButton =>
      _buttonStyle(background: actionDark, pressed: const Color(0xFF263442));
  static ButtonStyle get criticalButton =>
      _buttonStyle(background: error, pressed: const Color(0xFF8F1D14));
  static ThemeData get theme {
    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    final text = base.textTheme.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );
    final positive =
        _buttonStyle(
          background: actionPrimary,
          pressed: actionPrimaryPressed,
        ).copyWith(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              inherit: false,
              fontFamily: 'Roboto',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    final outlined =
        OutlinedButton.styleFrom(
          minimumSize: const Size(48, buttonHeight),
          side: const BorderSide(color: borderSubtle),
          shape: shape,
          textStyle: const TextStyle(
            inherit: false,
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? backgroundSecondary
                : surfacePrimary,
          ),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return textMuted;
            if (states.contains(WidgetState.pressed)) {
              return actionPrimaryPressed;
            }
            return textPrimary;
          }),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? disabled
                  : states.contains(WidgetState.pressed)
                  ? actionPrimaryPressed
                  : borderSubtle,
            ),
          ),
        );
    final textButton =
        TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(
            inherit: false,
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return textMuted;
            if (states.contains(WidgetState.pressed)) {
              return actionPrimaryPressed;
            }
            return success;
          }),
        );
    return base.copyWith(
      scaffoldBackgroundColor: backgroundPrimary,
      colorScheme: const ColorScheme.light(
        primary: success,
        onPrimary: onAction,
        secondary: actionDark,
        onSecondary: onAction,
        surface: surfacePrimary,
        onSurface: textPrimary,
        error: error,
        onError: onAction,
        surfaceContainerHighest: backgroundSecondary,
        outline: borderSubtle,
      ),
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 15, height: 1.4),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfacePrimary,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: surfacePrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: borderSubtle),
        ),
      ),
      dividerTheme: const DividerThemeData(color: borderSubtle, thickness: 1),
      listTileTheme: const ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfacePrimary,
        elevation: 0,
        selectedItemColor: success,
        unselectedItemColor: textMuted,
        selectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 10),
      ),
      filledButtonTheme: FilledButtonThemeData(style: positive),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: positive.copyWith(elevation: const WidgetStatePropertyAll(0)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlined),
      textButtonTheme: TextButtonThemeData(style: textButton),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfacePrimary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: success, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfacePrimary,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfacePrimary,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        modalBarrierColor: scrim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: backgroundSecondary,
        selectedColor: actionPrimary,
        secondarySelectedColor: actionPrimary,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        labelStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: textPrimary,
          fontSize: 12,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: onAction,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: onAction,
        unselectedLabelColor: textSecondary,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: actionPrimary,
          borderRadius: BorderRadius.circular(24),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: actionPrimary,
        linearTrackColor: borderSubtle,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? actionPrimary
              : const Color(0xFF9A9F9B),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: actionDark,
        contentTextStyle: TextStyle(fontFamily: 'Roboto', color: onAction),
      ),
    );
  }
}
