import 'package:flutter/material.dart';

abstract final class KindredColors {
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

ThemeData kindredTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: KindredColors.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: KindredColors.plum,
        primary: KindredColors.plum,
        secondary: KindredColors.coral,
        surface: KindredColors.paper,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 26,
            height: 1.15,
            letterSpacing: -.8,
            color: KindredColors.plum),
        headlineMedium: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 26,
            height: 1.2,
            letterSpacing: -.8,
            color: KindredColors.plum),
        titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: KindredColors.plum),
        bodyLarge:
            TextStyle(fontSize: 16, height: 1.5, color: KindredColors.plum),
        bodyMedium:
            TextStyle(fontSize: 14, height: 1.5, color: KindredColors.plum),
        labelLarge: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: .2),
      ),
      dividerColor: KindredColors.line,
      appBarTheme: const AppBarTheme(
          backgroundColor: KindredColors.paper,
          foregroundColor: KindredColors.plum,
          elevation: 0,
          scrolledUnderElevation: 0),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        backgroundColor: KindredColors.plum,
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
            borderSide: const BorderSide(color: KindredColors.line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: KindredColors.line)),
      ),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: KindredColors.plum,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
