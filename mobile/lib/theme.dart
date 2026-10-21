import 'package:flutter/material.dart';

abstract final class EverlaneColors {
  static const paper = Color(0xFFFFFFFF);
  static const plum = Color(0xFF222126);
  static const coral = Color(0xFFB83E55);
  static const blush = Color(0xFFFFEFF1);
  static const muted = Color(0xFF6E6B72);
  static const line = Color(0xFFF0EDF0);
  static const blue = Color(0xFF91BFE2);
  static const purple = Color(0xFFB77EA4);
  static const lime = Color(0xFFB6D96F);
  static const red = Color(0xFFFF666D);
  static const green = Color(0xFF527062);
}

ThemeData everlaneTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: EverlaneColors.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: EverlaneColors.plum,
        primary: EverlaneColors.plum,
        secondary: EverlaneColors.coral,
        surface: EverlaneColors.paper,
      ),
      textTheme: const TextTheme(
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
        labelLarge: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: .2),
      ),
      dividerColor: EverlaneColors.line,
      appBarTheme: const AppBarTheme(
          backgroundColor: EverlaneColors.paper,
          foregroundColor: EverlaneColors.plum,
          elevation: 0,
          scrolledUnderElevation: 0),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        backgroundColor: EverlaneColors.plum,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: EverlaneColors.line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: EverlaneColors.line)),
      ),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: EverlaneColors.plum,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
