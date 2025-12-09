import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aeliana_theme.dart';

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Warning Icon
              const Icon(
                Icons.block,
                color: AelianaColors.plasmaCyan,
                size: 80,
              ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 32),

              // Title
              Text(
                'ACCESS DENIED',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AelianaColors.plasmaCyan,
                  letterSpacing: 3,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 200.ms).fadeIn(duration: 600.ms),

              const SizedBox(height: 24),

              // Message
              Text(
                'This application requires users to be 17 years or older.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AelianaColors.stardust,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 400.ms).fadeIn(duration: 600.ms),

              const SizedBox(height: 16),

              Text(
                'We take age restrictions seriously. This is non-negotiable.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AelianaColors.ghost,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 600.ms).fadeIn(duration: 600.ms),

              const SizedBox(height: 48),

              // Exit Button
              ElevatedButton(
                onPressed: () {
                  // Close the app or go back
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AelianaColors.carbon,
                  foregroundColor: AelianaColors.stardust,
                ),
                child: const Text('GO BACK'),
              ).animate(delay: 800.ms).fadeIn(duration: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}
