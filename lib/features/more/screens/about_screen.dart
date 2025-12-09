import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sable/core/theme/aeliana_theme.dart';

/// About Screen - App info, version, and credits
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  // Hardcoded version - update when releasing
  static const String _version = '1.0.0';
  static const String _buildNumber = '1';
  
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      appBar: AppBar(
        backgroundColor: AelianaColors.obsidian,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'About',
          style: GoogleFonts.spaceGrotesk(
            color: AelianaColors.hyperGold,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Logo and App Name
            const SizedBox(height: 20),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AelianaColors.hyperGold,
                    AelianaColors.plasmaCyan,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AelianaColors.hyperGold.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '✨',
                  style: TextStyle(fontSize: 48),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'AELIANA',
              style: GoogleFonts.spaceGrotesk(
                color: AelianaColors.hyperGold,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your AI Companion',
              style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version $_version (Build $_buildNumber)',
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Description
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AelianaColors.carbon,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AelianaColors.plasmaCyan.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'Aeliana is your personal AI companion designed to support your emotional wellbeing, help you reflect on your thoughts, and be there whenever you need someone to talk to.',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Links Section
            _buildLinkItem(
              icon: LucideIcons.globe,
              title: 'Visit Website',
              subtitle: 'aeliana.ai',
              onTap: () => _launchUrl('https://aeliana.ai'),
            ),
            const SizedBox(height: 12),
            _buildLinkItem(
              icon: LucideIcons.fileText,
              title: 'Privacy Policy',
              subtitle: 'How we protect your data',
              onTap: () => _launchUrl('https://aeliana.ai/privacy'),
            ),
            const SizedBox(height: 12),
            _buildLinkItem(
              icon: LucideIcons.shield,
              title: 'Terms of Service',
              subtitle: 'Usage guidelines',
              onTap: () => _launchUrl('https://aeliana.ai/terms'),
            ),
            const SizedBox(height: 12),
            _buildLinkItem(
              icon: LucideIcons.mail,
              title: 'Contact Support',
              subtitle: 'support@aeliana.ai',
              onTap: () => _launchUrl('mailto:support@aeliana.ai'),
            ),
            
            const SizedBox(height: 32),
            
            // Credits
            Text(
              'CREDITS',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Created with ❤️ by Aeliana AI, LLC',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '© 2024 Aeliana AI, LLC. All rights reserved.',
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Acknowledgments
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AelianaColors.hyperGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AelianaColors.hyperGold.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(LucideIcons.heart, color: AelianaColors.hyperGold, size: 24),
                  const SizedBox(height: 12),
                  Text(
                    'Thank you for being part of our community. Your wellbeing matters to us.',
                    style: GoogleFonts.inter(
                      color: AelianaColors.hyperGold,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLinkItem({
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
          color: AelianaColors.carbon,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AelianaColors.plasmaCyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AelianaColors.plasmaCyan, size: 20),
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
                      fontSize: 15,
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
            const Icon(LucideIcons.externalLink, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }
}
