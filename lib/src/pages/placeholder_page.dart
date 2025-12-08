import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/aureal_theme.dart';

class PlaceholderPage extends StatelessWidget {
  final String title;

  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      appBar: AppBar(
        backgroundColor: AurealColors.obsidian,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: Colors.white.withOpacity(0.8)),
          onPressed: () {
            // Pages accessed from More menu go back to More
            if (title == 'Emergency') {
              context.go('/more');
            } else {
              context.go('/chat');
            }
          },
        ),
        title: Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon with glow
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AurealColors.plasmaCyan.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Icon(
                LucideIcons.sparkles,
                size: 64,
                color: AurealColors.plasmaCyan,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Coming Soon',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: AurealColors.plasmaCyan,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AurealColors.carbon,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AurealColors.plasmaCyan.withOpacity(0.2),
                ),
              ),
              child: Text(
                'This feature is being crafted with care ✨',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
