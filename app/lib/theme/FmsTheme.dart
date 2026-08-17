import 'package:flutter/material.dart';

import '../API/config.dart';
import 'FmsTextStyles.dart';

/// FMS design system's app-wide `ThemeData` (2026-08-24). Wired into
/// `MaterialApp.theme` in main.dart — before this pass, `MaterialApp` used
/// a bare `ColorScheme.fromSeed(seedColor: Colors.blueGrey)` with no custom
/// `AppBarTheme`/button themes/etc. at all, so every screen had to hand-roll
/// its own styling from scratch, and any stock Material widget a screen
/// forgot to re-skin would show Flutter's default blue-grey Material look
/// instead of FMS's Navy+Gold identity. This doesn't replace the explicit
/// `LightColors.*` usage already spread across every screen (that's a much
/// larger mechanical change with little benefit on its own) — it's a
/// baseline so anything NOT explicitly styled still looks on-brand.
class FmsTheme {
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: LightColors.navy,
      brightness: Brightness.light,
      primary: LightColors.navy,
      secondary: LightColors.gold,
      error: LightColors.error,
      surface: LightColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: LightColors.bg,
      fontFamily: null,
      dividerTheme: const DividerThemeData(
        color: LightColors.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: LightColors.bg,
        foregroundColor: LightColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: LightColors.textPrimary),
        titleTextStyle: TextStyle(
          color: LightColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: LightColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: LightColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LightColors.gold,
          foregroundColor: LightColors.deepNavy,
          disabledBackgroundColor: LightColors.border,
          disabledForegroundColor: LightColors.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: FmsTextStyles.buttonLabel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LightColors.navy,
          side: const BorderSide(color: LightColors.border),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: FmsTextStyles.buttonLabel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LightColors.goldMuted,
          textStyle: FmsTextStyles.buttonLabel,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LightColors.surface,
        hintStyle: const TextStyle(color: LightColors.textMuted, fontSize: 13.5),
        labelStyle: const TextStyle(color: LightColors.textSecondary, fontSize: 13.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LightColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LightColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LightColors.navy, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LightColors.error),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: LightColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: FmsTextStyles.sectionTitle,
        contentTextStyle: FmsTextStyles.body,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: LightColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: LightColors.deepNavy,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: LightColors.surface,
        selectedItemColor: LightColors.gold,
        unselectedItemColor: LightColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: LightColors.surface,
        selectedColor: LightColors.navy,
        labelStyle: const TextStyle(color: LightColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
        side: const BorderSide(color: LightColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: LightColors.navy),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: LightColors.navy,
        selectionColor: Color(0x3316213E),
        selectionHandleColor: LightColors.navy,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? LightColors.gold : LightColors.surface),
        checkColor: const WidgetStatePropertyAll(LightColors.deepNavy),
        side: const BorderSide(color: LightColors.border),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? LightColors.gold : LightColors.border),
      ),
    );
  }
}
