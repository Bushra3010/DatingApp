import 'package:flutter/material.dart';

abstract final class KindredColors {
  static const paper = Color(0xFFFAF8F4);
  static const plum = Color(0xFF382B3C);
  static const coral = Color(0xFFC55D48);
  static const blush = Color(0xFFF3E7E1);
  static const muted = Color(0xFF79747B);
  static const line = Color(0xFFE8E2DD);
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
            fontFamily: 'Lora',
            fontSize: 38,
            height: 1.15,
            letterSpacing: -1.5,
            color: KindredColors.plum),
        headlineMedium: TextStyle(
            fontFamily: 'Lora',
            fontSize: 30,
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
