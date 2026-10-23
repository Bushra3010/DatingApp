import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  /// A softer violet → pink pair for gradient *text* (headlines), separate
  /// from the stronger button gradient above.
  static const textGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFA78BFA), Color(0xFFF472B6)]);

  /// Body copy sits a shade off pure white so long paragraphs are easier on
  /// the eyes; headings stay pure white/near-black via [plum].
  static Color get body =>
      dark ? const Color(0xFFE4E4E7) : const Color(0xFF332B47);
  static const disabledText = Color(0xFF71717A);
}

/// Modern Premium typography: Inter for the interface, Poppins for headings,
/// Playfair Display used sparingly for romantic moments (the match screen).
abstract final class EverlaneFonts {
  static TextStyle inter(
          {required double size,
          FontWeight weight = FontWeight.w400,
          Color? color,
          double? height,
          double? letterSpacing}) =>
      GoogleFonts.inter(
          fontSize: size,
          fontWeight: weight,
          color: color ?? EverlaneColors.plum,
          height: height,
          letterSpacing: letterSpacing);

  static TextStyle poppins(
          {required double size,
          FontWeight weight = FontWeight.w600,
          Color? color,
          double? height,
          double? letterSpacing}) =>
      GoogleFonts.poppins(
          fontSize: size,
          fontWeight: weight,
          color: color ?? EverlaneColors.plum,
          height: height,
          letterSpacing: letterSpacing);

  /// The Everlane wordmark: hand-lettered marker script (Caveat Bold), like
  /// the logo the client picked. Caveat runs small, so it's scaled up.
  static TextStyle logo({double size = 30, Color? color}) =>
      GoogleFonts.caveat(
          fontSize: size * 1.25,
          fontWeight: FontWeight.w700,
          color: color ?? EverlaneColors.plum,
          height: 1.0);

  /// "Ananya, 27": the name in Plus Jakarta Sans Bold, the age in a
  /// lighter Cormorant Garamond italic. Plain text stays "Name, age".
  static TextSpan nameAge(String name, int age,
          {double size = 34, Color color = Colors.white}) =>
      TextSpan(children: [
        TextSpan(
            text: name,
            style: GoogleFonts.plusJakartaSans(
                fontSize: size * .9,
                fontWeight: FontWeight.w700,
                letterSpacing: -.6,
                color: color)),
        TextSpan(
            text: ', $age',
            style: GoogleFonts.cormorantGaramond(
                fontSize: size * 1.02,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                color: color.withValues(alpha: .9))),
      ]);

  /// Use sparingly — romantic headlines and the match celebration only.
  static TextStyle playfair(
          {required double size,
          FontWeight weight = FontWeight.w600,
          Color? color,
          double? height}) =>
      GoogleFonts.playfairDisplay(
          fontSize: size,
          fontWeight: weight,
          color: color ?? Colors.white,
          height: height);
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
      // Inter is the base for every slot (body, buttons, nav, forms); Poppins
      // then takes over the heading slots. Any inline TextStyle elsewhere in
      // the app that doesn't set its own fontFamily inherits Inter from here.
      textTheme: GoogleFonts.interTextTheme(TextTheme(
        headlineLarge: EverlaneFonts.poppins(
            size: 28, weight: FontWeight.w600, height: 1.15, letterSpacing: -.6),
        headlineMedium: EverlaneFonts.poppins(
            size: 24, weight: FontWeight.w600, height: 1.2, letterSpacing: -.4),
        titleLarge: EverlaneFonts.inter(size: 24, weight: FontWeight.w700),
        bodyLarge: EverlaneFonts.inter(
            size: 16, height: 1.5, color: EverlaneColors.body),
        bodyMedium: EverlaneFonts.inter(
            size: 14, height: 1.5, color: EverlaneColors.body),
        labelLarge:
            EverlaneFonts.inter(size: 15, weight: FontWeight.w600, letterSpacing: .2),
      )),
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
        // Every filled button gets the purple-to-pink gradient, not just the
        // hero ones — this is what the premium look rides on.
        backgroundBuilder: (context, states, child) => DecoratedBox(
            decoration: BoxDecoration(
                gradient: states.contains(WidgetState.disabled)
                    ? null
                    : EverlaneColors.premiumGradient,
                color:
                    states.contains(WidgetState.disabled) ? EverlaneColors.line : null),
            child: child),
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
          backgroundColor: EverlaneColors.card,
          contentTextStyle: TextStyle(color: EverlaneColors.plum),
          actionTextColor: EverlaneColors.like,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: EverlaneColors.deep.withValues(alpha: .6)))),
    );
