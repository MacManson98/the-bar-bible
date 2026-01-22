import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const primaryDark = Color(0xFF1A1A1A);
  static const primaryBlack = Color(0xFF000000);
  static const accentGold = Color(0xFFD4AF37);
  static const accentRed = Color(0xFF8B0000);
  static const surfaceDark = Color(0xFF2A2A2A);
  static const surfaceLight = Color(0xFF3A3A3A);
  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFFB0B0B0);
  
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    
    colorScheme: const ColorScheme.dark(
      primary: accentGold,
      secondary: accentRed,
      surface: surfaceDark,
      onPrimary: primaryDark,
      onSecondary: textPrimary,
      onSurface: textPrimary,
    ),
    
    scaffoldBackgroundColor: primaryDark,
    
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryBlack,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
    
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: surfaceLight, width: 1),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: surfaceLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: surfaceLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentGold, width: 2),
      ),
      hintStyle: const TextStyle(color: textSecondary),
      prefixIconColor: textSecondary,
    ),
    
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: 0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: textSecondary,
      ),
    ),
    
    chipTheme: ChipThemeData(
      backgroundColor: surfaceDark,
      selectedColor: accentGold,
      labelStyle: const TextStyle(color: textPrimary),
      side: const BorderSide(color: surfaceLight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    
    dividerColor: surfaceLight,
    
    iconTheme: const IconThemeData(
      color: accentGold,
    ),
  );
  
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    
    colorScheme: const ColorScheme.light(
      primary: primaryDark,
      secondary: accentGold,
      surface: Colors.white,
      onPrimary: textPrimary,
      onSecondary: primaryDark,
      onSurface: primaryDark,
    ),
    
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: primaryDark,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: primaryDark),
    ),
    
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentGold, width: 2),
      ),
    ),
    
    iconTheme: const IconThemeData(
      color: accentGold,
    ),
  );
}
