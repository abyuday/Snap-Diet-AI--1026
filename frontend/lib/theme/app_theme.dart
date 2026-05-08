import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand Teal Palette ──────────────────────────────────────────────────
  static const primaryColor    = Color(0xFF1EDD88); // Bright teal from mockup
  static const primaryDark     = Color(0xFF17B56E); // Darker teal for hover
  static const secondaryColor  = Color(0xFF00B87A); // Deep teal for gradients

  // ── Accent ──────────────────────────────────────────────────────────────
  static const accentOrange    = Color(0xFFFF9800);
  static const accentRed       = Color(0xFFFF4D4D);
  static const accentBlue      = Color(0xFF4FA3E0);
  static const accentPurple    = Color(0xFF8B5CF6);

  // ── Dark Mode Tokens ────────────────────────────────────────────────────
  static const darkBg          = Color(0xFF0D1117); // Main background
  static const darkSurface     = Color(0xFF161B22); // Card surface
  static const darkSurface2    = Color(0xFF1C2128); // Elevated cards
  static const darkBorder      = Color(0xFF30363D); // Subtle borders
  static const darkTextPrimary = Color(0xFFE6EDF3);
  static const darkTextMuted   = Color(0xFF8B949E);

  // ── Light Mode Tokens ───────────────────────────────────────────────────
  static const lightBg         = Color(0xFFF0F4F8);
  static const lightSurface    = Color(0xFFFFFFFF);
  static const lightSurface2   = Color(0xFFEEF2F6);
  static const lightBorder     = Color(0xFFD0D7DE);
  static const lightTextPrimary= Color(0xFF0D1117);
  static const lightTextMuted  = Color(0xFF6E7681);

  // ── Legacy aliases (used across existing screens) ───────────────────────
  static const backgroundColor = darkBg;
  static const surfaceColor    = darkSurface;

  // ── Dark Theme ──────────────────────────────────────────────────────────
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: darkSurface,
      onPrimary: Colors.white,
      onSurface: darkTextPrimary,
    ),
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 32, color: darkTextPrimary),
      titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 18, color: primaryColor),
      bodyMedium: GoogleFonts.outfit(fontSize: 14, color: darkTextMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    ),
    cardTheme: CardTheme(
      color: darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      hintStyle: const TextStyle(color: darkTextMuted),
    ),
  );

  // ── Light Theme ─────────────────────────────────────────────────────────
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryDark,
    scaffoldBackgroundColor: lightBg,
    colorScheme: const ColorScheme.light(
      primary: primaryDark,
      secondary: secondaryColor,
      surface: lightSurface,
      onPrimary: Colors.white,
      onSurface: lightTextPrimary,
    ),
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
      displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 32, color: lightTextPrimary),
      titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 18, color: primaryDark),
      bodyMedium: GoogleFonts.outfit(fontSize: 14, color: lightTextMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    ),
    cardTheme: CardTheme(
      color: lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryDark, width: 1.5),
      ),
      hintStyle: const TextStyle(color: lightTextMuted),
    ),
  );
}
