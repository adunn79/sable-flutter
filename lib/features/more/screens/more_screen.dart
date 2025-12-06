import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aureal_theme.dart';

/// More screen - provides access to Settings and other options
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => context.go('/chat'),
        ),
        title: Text(
          'More',
          style: GoogleFonts.spaceGrotesk(
            color: AurealColors.hyperGold,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuItem(
            context,
            icon: LucideIcons.settings,
            title: 'Settings',
            subtitle: 'Personalize your experience',
            onTap: () => context.go('/settings'),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: LucideIcons.award,
            title: 'Origin Certificate',
            subtitle: 'View your companion\'s birth certificate',
            onTap: () => context.go('/certificate'),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: LucideIcons.alertCircle,
            title: 'Emergency',
            subtitle: 'Crisis resources and contacts',
            onTap: () => context.go('/emergency'),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: LucideIcons.helpCircle,
            title: 'Help & Support',
            subtitle: 'Get help with the app',
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: LucideIcons.info,
            title: 'About',
            subtitle: 'App version and credits',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AurealColors.hyperGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AurealColors.hyperGold, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }
}
