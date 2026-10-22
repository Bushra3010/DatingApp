import 'package:flutter/material.dart';

/// Modern Premium: purple, pink and black. Token names stay the same as the
/// old editorial theme so every screen re-themes automatically — only the
/// values changed, plus a few new tokens for the gradient look.
abstract final class EverlaneColors {
  /// Set from the Dark mode switch in Settings. The premium look is dark
  /// by default; neutrals are read at build time, the accent colours are
  /// the same in both themes.
  static bool dark = true;

  static Color get paper =>
      dark ? const Color(0xFF0D0B12) : const Color(0xFFFAF7FF);
  static Color get card =>
      dark ? const Color(0xFF191621) : const Color(0xFFFFFFFF);

  /// Text and icons.
  static Color get plum =>
      dark ? const Color(0xFFFFFFFF) : const Color(0xFF1B1530);

  /// Surfaces that carry white content (buttons, banners, own bubbles) —
  /// Primary Purple.
  static Color get deep => const Color(0xFF7C3AED);
  static Color get blush =>
      dark ? const Color(0xFF261C3B) : const Color(0xFFF2E9FF);
  static Color get muted =>
      dark ? const Color(0xFFA1A1AA) : const Color(0xFF6E6680);
  static Color get line =>
      dark ? const Color(0xFF2A2436) : const Color(0xFFE8E0F7);
  static const star = Color(0xFFF2A93B);
  static const pass = Color(0xFF8D82A3);

  /// Romantic Pink — the primary "like"/heart accent.
  static const like = Color(0xFFF472B6);
  static const boost = Color(0xFF2F9E75);

  /// Accent Lavender — subtle highlights on dark surfaces.
  static const lavender = Color(0xFFC4B5FD);

  /// Purple → pink, used for hero buttons and the match celebration.
  static const gradientStart = Color(0xFF7C3AED);
  static const gradientEnd = Color(0xFFEC4899);
  static const premiumGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [gradientStart, gradientEnd]);
}

ThemeData everlaneTheme() => ThemeData(
      useMaterial3: true,
      brightness: EverlaneColors.dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: EverlaneColors.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: EverlaneColors.deep,
        brightness: EverlaneColors.dark ? Brightness.dark : Brightness.light,
        primary: EverlaneColors.deep,
        onPrimary: Colors.white,
        secondary: EverlaneColors.like,
        surface: EverlaneColors.paper,
        onSurface: EverlaneColors.plum,
      ),
      cardColor: EverlaneColors.card,
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: EverlaneColors.paper,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
      dialogTheme: DialogThemeData(
          backgroundColor: EverlaneColors.card,
          surfaceTintColor: Colors.transparent),
      drawerTheme: DrawerThemeData(backgroundColor: EverlaneColors.paper),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 26,
            height: 1.15,
            letterSpacing: -.8,
            color: EverlaneColors.plum),
        headlineMedium: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 26,
            height: 1.2,
            letterSpacing: -.8,
            color: EverlaneColors.plum),
        titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: EverlaneColors.plum),
        bodyLarge:
            TextStyle(fontSize: 16, height: 1.5, color: EverlaneColors.plum),
        bodyMedium:
            TextStyle(fontSize: 14, height: 1.5, color: EverlaneColors.plum),
        labelLarge: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: .2),
      ),
      dividerColor: EverlaneColors.line,
      appBarTheme: AppBarTheme(
          backgroundColor: EverlaneColors.paper,
          foregroundColor: EverlaneColors.plum,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        backgroundColor: EverlaneColors.deep,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        elevation: 0,
        shadowColor: EverlaneColors.deep.withValues(alpha: .55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        foregroundColor: EverlaneColors.plum,
        side: BorderSide(color: EverlaneColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EverlaneColors.card,
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: EverlaneColors.line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: EverlaneColors.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: EverlaneColors.deep, width: 1.6)),
      ),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: EverlaneColors.deep,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
