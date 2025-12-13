import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sable/core/theme/aeliana_theme.dart';

/// Help & Support Screen - FAQs, contact options, and troubleshooting
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

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
          'Help & Support',
          style: GoogleFonts.spaceGrotesk(
            color: AelianaColors.hyperGold,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact Section
            _buildSectionHeader('Get in Touch'),
            const SizedBox(height: 12),
            _buildContactCard(
              icon: LucideIcons.mail,
              title: 'Email Support',
              subtitle: 'support@aeliana.ai',
              description: 'We typically respond within 24 hours',
              onTap: () => _launchUrl('mailto:support@aeliana.ai'),
            ),
            const SizedBox(height: 12),
            _buildContactCard(
              icon: LucideIcons.messageCircle,
              title: 'Live Chat',
              subtitle: 'Chat with our team',
              description: 'Available Mon-Fri, 9am-5pm PST',
              onTap: () => _launchUrl('https://aeliana.ai/support'),
            ),
            
            const SizedBox(height: 32),
            
            // FAQ Section
            _buildSectionHeader('Frequently Asked Questions'),
            const SizedBox(height: 12),
            _buildFaqItem(
              question: 'How does Aeliana protect my privacy?',
              answer: 'All conversations are encrypted end-to-end. We never sell your data or share it with third parties. Your private conversations stay private.',
            ),
            _buildFaqItem(
              question: 'What is Private Space?',
              answer: 'Private Space is a premium feature that provides an adults-only sanctuary with dedicated AI companions. It uses separate encryption and is completely isolated from your main conversations.',
            ),
            _buildFaqItem(
              question: 'How do I change my AI companion?',
              answer: 'Go to Settings and tap on your current companion avatar. You can choose from different archetypes or customize your companion\'s appearance.',
            ),
            _buildFaqItem(
              question: 'Why is the AI not responding?',
              answer: 'This can happen due to network issues. Try checking your internet connection and restarting the app. If the problem persists, contact support.',
            ),
            _buildFaqItem(
              question: 'How do I cancel my subscription?',
              answer: 'You can manage your subscription through the App Store (iOS) or Play Store (Android). Go to your account settings in the respective store.',
            ),
            _buildFaqItem(
              question: 'Is my data backed up?',
              answer: 'Your preferences and settings are stored securely. Private Space data is encrypted locally on your device for maximum privacy. iCloud Backup requires a real device with a signed-in Apple ID (not available in Simulator).',
            ),
            _buildFaqItem(
              question: 'Can I use Siri with Aeliana?',
              answer: 'Yes! Aeliana supports Siri Shortcuts. Say "Hey Siri, chat with Aeliana" to open chat, "Hey Siri, show my journal" to open journal, "Hey Siri, mood check" for Vital Balance, or "Hey Siri, add a memory" for quick journal entry. You can customize these in Settings.',
            ),
            _buildFaqItem(
              question: 'How do I use voice commands?',
              answer: 'Tap the microphone button in chat to speak. Long-press the microphone to toggle continuous conversation mode where the AI will listen after each response. You can change voice settings in Settings > Voice.',
            ),
            _buildFaqItem(
              question: 'Why is iCloud Backup showing "Not Available"?',
              answer: 'iCloud Backup requires a real iPhone/iPad with a signed-in Apple ID. It does not work in the iOS Simulator. On a real device, make sure you are signed into iCloud in Settings.',
            ),
            
            const SizedBox(height: 32),
            
            // Troubleshooting Section
            _buildSectionHeader('Troubleshooting'),
            const SizedBox(height: 12),
            _buildTroubleshootItem(
              icon: LucideIcons.wifi,
              title: 'Connection Issues',
              steps: [
                'Check your internet connection',
                'Try switching between WiFi and cellular',
                'Restart the app',
                'Clear app cache in Settings',
              ],
            ),
            const SizedBox(height: 12),
            _buildTroubleshootItem(
              icon: LucideIcons.volume2,
              title: 'Voice Not Working',
              steps: [
                'Check your device volume',
                'Ensure microphone permissions are enabled',
                'Try switching voice engines in Settings',
                'Restart the app',
              ],
            ),
            const SizedBox(height: 12),
            _buildTroubleshootItem(
              icon: LucideIcons.lock,
              title: 'Private Space Access',
              steps: [
                'Ensure you have an active premium subscription',
                'Check that biometric/PIN is set up correctly',
                'Try resetting your PIN in Settings',
                'Contact support if issues persist',
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Emergency Notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crisis Resources',
                          style: GoogleFonts.inter(
                            color: Colors.red,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'If you\'re in crisis, please visit our Emergency page or call your local crisis line.',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
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
  
  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.spaceGrotesk(
        color: AelianaColors.hyperGold,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }
  
  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AelianaColors.carbon,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AelianaColors.plasmaCyan.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AelianaColors.plasmaCyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AelianaColors.plasmaCyan, size: 24),
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
                      color: AelianaColors.plasmaCyan,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 12,
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
  
  Widget _buildFaqItem({
    required String question,
    required String answer,
  }) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 0),
      childrenPadding: const EdgeInsets.only(bottom: 16),
      iconColor: AelianaColors.plasmaCyan,
      collapsedIconColor: Colors.white38,
      title: Text(
        question,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 24),
          child: Text(
            answer,
            style: GoogleFonts.inter(
              color: Colors.white60,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildTroubleshootItem({
    required IconData icon,
    required String title,
    required List<String> steps,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AelianaColors.carbon,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AelianaColors.hyperGold, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.key + 1}.',
                  style: GoogleFonts.inter(
                    color: AelianaColors.plasmaCyan,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.value,
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
