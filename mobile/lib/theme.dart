import 'package:flutter/material.dart';

abstract final class EverlaneColors {
  /// Set from the Dark mode switch in Settings. Neutrals are read at build
  /// time; the accent colours are the same in both themes.
  static bool dark = false;

  static Color get paper =>
      dark ? const Color(0xFF17120F) : const Color(0xFFFFF8EC);
  static Color get card => dark ? const Color(0xFF241D19) : Colors.white;

  /// Text and icons.
  static Color get plum =>
      dark ? const Color(0xFFF5ECE1) : const Color(0xFF2A1F1A);

  /// Dark surfaces that carry white content (buttons, banners, own bubbles).
  static Color get deep =>
      dark ? const Color(0xFF3B2F28) : const Color(0xFF2A1F1A);
  static Color get blush =>
      dark ? const Color(0xFF3A2229) : const Color(0xFFFCE4EC);
  static Color get muted =>
      dark ? const Color(0xFFA99B8D) : const Color(0xFF7A6E64);
  static Color get line =>
      dark ? const Color(0xFF3A302A) : const Color(0xFFF1E7D8);
  static const star = Color(0xFFF2A93B);
  static const pass = Color(0xFF8A7B6D);
  static const like = Color(0xFFD6336C);
  static const boost = Color(0xFF2F9E75);
}

ThemeData everlaneTheme() => ThemeData(
      useMaterial3: true,
      brightness: EverlaneColors.dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: EverlaneColors.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: EverlaneColors.like,
        brightness: EverlaneColors.dark ? Brightness.dark : Brightness.light,
        primary: EverlaneColors.plum,
        onPrimary: EverlaneColors.paper,
        secondary: EverlaneColors.like,
        surface: EverlaneColors.paper,
        onSurface: EverlaneColors.plum,
      ),
      cardColor: EverlaneColors.card,
      bottomSheetTheme:
          BottomSheetThemeData(backgroundColor: EverlaneColors.paper),
      dialogTheme: DialogThemeData(backgroundColor: EverlaneColors.card),
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
          scrolledUnderElevation: 0),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        backgroundColor: EverlaneColors.deep,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
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
      ),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: EverlaneColors.deep,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
