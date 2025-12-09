import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AelianaColors {
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

class AelianaTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AelianaColors.obsidian,
      primaryColor: AelianaColors.hyperGold,
      
      // Color Scheme Definition
      colorScheme: const ColorScheme.dark(
        primary: AelianaColors.hyperGold,
        secondary: AelianaColors.plasmaCyan,
        surface: AelianaColors.carbon,
        onPrimary: AelianaColors.obsidian, // Text on Gold buttons
        onSurface: AelianaColors.stardust,
      ),

      // Typography
      textTheme: TextTheme(
        displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 57, 
          fontWeight: FontWeight.bold, 
          color: AelianaColors.stardust
        ),
        displayMedium: GoogleFonts.spaceGrotesk(
          fontSize: 45, 
          fontWeight: FontWeight.w600, 
          color: AelianaColors.stardust
        ),
        headlineSmall: GoogleFonts.spaceGrotesk(
          fontSize: 24, 
          fontWeight: FontWeight.w600, 
          color: AelianaColors.plasmaCyan
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16, 
          color: AelianaColors.stardust
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, 
          color: AelianaColors.ghost
        ),
      ),

      // Component Styles
      appBarTheme: const AppBarTheme(
        backgroundColor: AelianaColors.obsidian,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AelianaColors.stardust),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AelianaColors.hyperGold,
          foregroundColor: AelianaColors.obsidian,
          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AelianaColors.carbon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AelianaColors.plasmaCyan, width: 1),
        ),
        hintStyle: GoogleFonts.inter(color: AelianaColors.ghost),
      ),
    );
  }
}
