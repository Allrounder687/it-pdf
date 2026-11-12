import 'package:flutter/material.dart';

/// Design tokens and theme definitions for IT PDF.
/// Implements a refined, premium desktop design system inspired by
/// Microsoft Fluent 2, Adobe Acrobat Pro, and Foxit PDF Editor.
class AppTheme {
  AppTheme._();

  // Color Palette - Light (Fluent Desktop Neutral)
  static const Color lightBg = Color(0xFFF3F4F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF8F9FA);
  static const Color lightBorder = Color(0xFFE2E5E8);
  static const Color lightBorderSubtle = Color(0xFFECEFF1);
  static const Color lightTextPrimary = Color(0xFF1E2124);
  static const Color lightTextSecondary = Color(0xFF5E6670);
  static const Color lightCanvasBg = Color(0xFFEBECEE);

  // Color Palette - Dark (Graphite Desktop Neutral)
  static const Color darkBg = Color(0xFF1A1D20);
  static const Color darkSurface = Color(0xFF22262A);
  static const Color darkSurfaceVariant = Color(0xFF2B3036);
  static const Color darkBorder = Color(0xFF383E44);
  static const Color darkBorderSubtle = Color(0xFF2E3339);
  static const Color darkTextPrimary = Color(0xFFF2F4F7);
  static const Color darkTextSecondary = Color(0xFF98A2B3);
  static const Color darkCanvasBg = Color(0xFF16181B);

  // Executive Brand Accents (Cobalt & Subtle Functional Tones)
  static const Color primaryBlue = Color(0xFF0F6CBD); // Fluent Signature Cobalt
  static const Color primaryBlueDark = Color(0xFF2886DE);
  static const Color accentSlate = Color(0xFF475569);
  static const Color highlightAmber = Color(0xFFD97706);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color successGreen = Color(0xFF16A34A);

  // Smallpdf-Inspired Expressive Category Palette
  static const Color toolCoral = Color(0xFFE11D48); // Compression & Core
  static const Color toolTeal = Color(0xFF0D9488); // Merge, Split & Pages
  static const Color toolBlue = Color(0xFF0284C7); // Convert & Images
  static const Color toolIndigo = Color(0xFF4F46E5); // Edit & Text Objects
  static const Color toolAmber = Color(0xFFD97706); // Signatures & Forms
  static const Color toolGold = Color(0xFFCA8A04); // Security & Passwords
  static const Color toolViolet = Color(0xFF7C3AED); // AI Assistant & Chat

  // Reader Canvas Themes
  static const Color readerSepiaBg = Color(0xFFFBF0D9);
  static const Color readerSepiaText = Color(0xFF5F4B32);
  static const Color readerNightBg = Color(0xFF0D1117);
  static const Color readerNightText = Color(0xFFC9D1D9);

  /// Light theme definition.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: primaryBlue,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: accentSlate,
        surface: lightSurface,
        surfaceContainerHighest: lightSurfaceVariant,
        error: dangerRed,
        onPrimary: Colors.white,
        onSurface: lightTextPrimary,
        outline: lightBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: lightBorder),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2124),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 11),
        waitDuration: const Duration(milliseconds: 500),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(true),
        trackVisibility: const WidgetStatePropertyAll(false),
        interactive: true,
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.dragged)) {
            return 10.0;
          }
          return 6.0;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return Colors.black.withValues(alpha: 0.7);
          }
          if (states.contains(WidgetState.hovered)) {
            return Colors.black.withValues(alpha: 0.5);
          }
          return Colors.black.withValues(alpha: 0.3);
        }),
      ),
    );
  }

  /// Dark theme definition.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: primaryBlueDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlueDark,
        secondary: accentSlate,
        surface: darkSurface,
        surfaceContainerHighest: darkSurfaceVariant,
        error: dangerRed,
        onPrimary: Colors.white,
        onSurface: darkTextPrimary,
        outline: darkBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: darkBorder),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF2E3339),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: darkBorder),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 11),
        waitDuration: const Duration(milliseconds: 500),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(true),
        trackVisibility: const WidgetStatePropertyAll(false),
        interactive: true,
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.dragged)) {
            return 10.0;
          }
          return 6.0;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return Colors.white.withValues(alpha: 0.7);
          }
          if (states.contains(WidgetState.hovered)) {
            return Colors.white.withValues(alpha: 0.5);
          }
          return Colors.white.withValues(alpha: 0.3);
        }),
      ),
    );
  }
}
