import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A class that holds the premium visual design tokens, colors,
/// and themes for the RoomieSpend application in a modern light fintech style.
class AppTheme {
  AppTheme._();

  // Premium Fintech Light Color Palette
  static const Color backgroundLight = Color(0xFFFAFAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  
  static const Color primaryPurple = Color(0xFF6C63FF);
  static const Color secondaryViolet = Color(0xFF8B7CFF);
  static const Color lightPurpleContainer = Color(0xFFF3F1FF);
  static const Color successGreen = Color(0xFF22C55E);
  static const Color errorRed = Color(0xFFEF4444);

  static const Color textPrimary = Color(0xFF1E1B4B);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const Color borderLight = Color(0xFFE5E7EB);

  // Background Gradients
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF6F4FF),
      Color(0xFFFAFAFC),
    ],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient logoGlowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF8B7CFF), // Secondary Purple
      Color(0xFF6C63FF), // Primary Purple
      Color(0xFFA59DFF), // Light purple highlight
    ],
  );

  static const LinearGradient glassCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1AFFFFFF),
      Color(0x05FFFFFF),
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryPurple,
      secondaryViolet,
    ],
  );

  static const LinearGradient cyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      secondaryViolet,
      Color(0xFFA59DFF),
    ],
  );

  /// Generates the Light Material 3 theme configuration.
  /// Uses Google Fonts "Outfit" for consistent premium typography.
  static ThemeData get lightTheme {
    // Base Outfit text theme — applies the font family to all styles
    final outfitTextTheme = GoogleFonts.outfitTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      primaryColor: primaryPurple,
      colorScheme: const ColorScheme.light(
        primary: primaryPurple,
        secondary: secondaryViolet,
        surface: surfaceLight,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      textTheme: outfitTextTheme.copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
