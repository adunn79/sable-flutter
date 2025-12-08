import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aureal_theme.dart';
import 'package:sable/core/widgets/restart_widget.dart';
import 'package:sable/features/private_space/services/private_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// More screen - provides access to Settings and other options
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      appBar: AppBar(
        backgroundColor: AurealColors.obsidian,
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

          _buildMenuItem(
            context,
            icon: LucideIcons.sparkles,  // Using sparkles as mask/drama icon isn't available
            title: 'Private Space',
            subtitle: 'Your premium sanctuary 🎭',
            onTap: () => context.go('/private-space'),
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
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: LucideIcons.info,
            title: 'About',
            subtitle: 'App version and credits',
            onTap: () {},
          ),
          
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'DEBUG OPTIONS',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          _buildMenuItem(
            context,
            icon: LucideIcons.refreshCw,
            title: 'Restart App',
            subtitle: 'Reload the application',
            onTap: () => RestartWidget.restartApp(context),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: LucideIcons.trash2,
            title: 'Reset Private Space',
            subtitle: 'COMPLETE data wipe for fresh onboarding',
            onTap: () async {
              // Nuclear option - delete EVERYTHING
              final storage = await PrivateStorageService.getInstance();
              await storage.deleteAllPrivateData();
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🗑️ Private Space COMPLETELY reset! All data deleted. Go to Private Space for fresh onboarding.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: LucideIcons.rotateCcw,
            title: 'Reset to Onboarding',
            subtitle: 'Go to setup (keeps memory)',
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('onboarding_complete', false);
              if (context.mounted) {
                // Navigate to onboarding
                context.go('/onboarding');
              }
            },
          ),
          const SizedBox(height: 24),
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
          color: AurealColors.carbon, // Slate blue
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AurealColors.plasmaCyan.withOpacity(0.15), // Teal border
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AurealColors.plasmaCyan.withOpacity(0.15), // Teal bg
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AurealColors.plasmaCyan, size: 22), // Teal icon
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
