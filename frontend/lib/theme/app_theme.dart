import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primaryColor = Color(0xFF4CAF50); // Vibrant Green
  static const secondaryColor = Color(0xFF2E7D32); // Darker Green
  static const accentColor = Color(0xFFFF9800); // Pulse Orange for highlights
  static const backgroundColor = Color(0xFF121212); // Deep Black
  static const surfaceColor = Color(0xFF1E1E1E); // Elevated Surface

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColor,
      onPrimary: Colors.white,
    ),
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.outfit(
        fontWeight: FontWeight.bold,
        fontSize: 32,
        color: Colors.white,
      ),
      titleLarge: GoogleFonts.outfit(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: primaryColor,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
      ),
    ),
    cardTheme: CardTheme(
      color: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
    ),
  );
}
