import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AurealColors {
  // Unified Sable Design Language (Vital Balance palette)
  static const Color obsidian = Color(0xFF0D1B2A);      // Deep navy background
  static const Color plasmaCyan = Color(0xFF5DD9C1);    // Soft teal accent
  static const Color hyperGold = Color(0xFFB8A9D9);     // Lavender accent
  static const Color carbon = Color(0xFF1E2D3D);        // Slate blue card
  static const Color stardust = Color(0xFFF2F2F2);      // Light text
  static const Color ghost = Color(0xFFA0A0A0);         // Muted text
  
  // Additional Sable palette colors
  static const Color backgroundMid = Color(0xFF1B263B); // Mid gradient
  static const Color warningAmber = Color(0xFFFFB74D);  // Warning/attention
}

class AurealTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AurealColors.obsidian,
      primaryColor: AurealColors.hyperGold,
      
      // Color Scheme Definition
      colorScheme: const ColorScheme.dark(
        primary: AurealColors.hyperGold,
        secondary: AurealColors.plasmaCyan,
        surface: AurealColors.carbon,
        onPrimary: AurealColors.obsidian, // Text on Gold buttons
        onSurface: AurealColors.stardust,
      ),

      // Typography
      textTheme: TextTheme(
        displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 57, 
          fontWeight: FontWeight.bold, 
          color: AurealColors.stardust
        ),
        displayMedium: GoogleFonts.spaceGrotesk(
          fontSize: 45, 
          fontWeight: FontWeight.w600, 
          color: AurealColors.stardust
        ),
        headlineSmall: GoogleFonts.spaceGrotesk(
          fontSize: 24, 
          fontWeight: FontWeight.w600, 
          color: AurealColors.plasmaCyan
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16, 
          color: AurealColors.stardust
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, 
          color: AurealColors.ghost
        ),
      ),

      // Component Styles
      appBarTheme: const AppBarTheme(
        backgroundColor: AurealColors.obsidian,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AurealColors.stardust),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AurealColors.hyperGold,
          foregroundColor: AurealColors.obsidian,
          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AurealColors.carbon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AurealColors.plasmaCyan, width: 1),
        ),
        hintStyle: GoogleFonts.inter(color: AurealColors.ghost),
      ),
    );
  }
}
