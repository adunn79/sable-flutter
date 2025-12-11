import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:ui';
import 'package:sable/core/theme/aeliana_theme.dart';

/// In-app help sheet for Music and Siri features
/// Adversarial design: handles edge cases, confused users, troubleshooting
class FeatureHelpSheet extends StatelessWidget {
  final String feature; // 'music' or 'siri'
  
  const FeatureHelpSheet({super.key, required this.feature});
  
  static void showMusic(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FeatureHelpSheet(feature: 'music'),
    );
  }
  
  static void showSiri(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FeatureHelpSheet(feature: 'siri'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AelianaColors.carbon.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  if (feature == 'music') ..._buildMusicHelp(),
                  if (feature == 'siri') ..._buildSiriHelp(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  List<Widget> _buildMusicHelp() {
    return [
      _buildHeader(LucideIcons.music, 'Music Integration', const Color(0xFF1DB954)),
      const SizedBox(height: 20),
      
      _buildSection('Connect Spotify', [
        _buildStep('1', 'Go to Settings (gear icon)'),
        _buildStep('2', 'Scroll to "MUSIC INTEGRATION"'),
        _buildStep('3', 'Tap "Spotify" to connect'),
        _buildStep('4', 'Authorize in the Spotify app'),
        _buildStep('5', 'Play music → Mini-player appears!'),
      ]),
      
      const SizedBox(height: 20),
      _buildSection('Mini-Player Controls', [
        _buildFeatureItem(LucideIcons.play, 'Tap play/pause to control music'),
        _buildFeatureItem(LucideIcons.skipForward, 'Skip forward/back buttons'),
        _buildFeatureItem(LucideIcons.chevronUp, 'Tap to expand full player'),
        _buildFeatureItem(LucideIcons.music, 'Album art and track info shown'),
      ]),
      
      const SizedBox(height: 20),
      _buildTroubleshootingSection('Troubleshooting', [
        _buildTroubleshootItem(
          'Spotify won\'t connect?',
          'Make sure the Spotify app is installed on your device.',
        ),
        _buildTroubleshootItem(
          'Mini-player not showing?',
          'Music must be actively playing in Spotify.',
        ),
        _buildTroubleshootItem(
          'Want to disconnect?',
          'Settings → MUSIC INTEGRATION → Tap Spotify again.',
        ),
        _buildTroubleshootItem(
          'Controls not working?',
          'Try pausing/playing directly in Spotify first, then retry.',
        ),
      ]),
      
      const SizedBox(height: 20),
      _buildInfoBox(
        'Your listening history is tracked for your journal! '
        '"Most Played Today" will appear in your entries automatically.',
        LucideIcons.book,
      ),
    ];
  }
  
  List<Widget> _buildSiriHelp() {
    return [
      _buildHeader(LucideIcons.mic, 'Siri Shortcuts', AelianaColors.plasmaCyan),
      const SizedBox(height: 20),
      
      _buildSection('Voice Commands', [
        _buildSiriCommand('"Hey Siri, chat with Aeliana"', 'Opens chat'),
        _buildSiriCommand('"Hey Siri, show my journal"', 'Opens journal'),
        _buildSiriCommand('"Hey Siri, bedside clock"', 'Starts clock mode'),
        _buildSiriCommand('"Hey Siri, mood check"', 'Opens Vital Balance'),
        _buildSiriCommand('"Hey Siri, now playing"', 'Shows mini-player'),
        _buildSiriCommand('"Hey Siri, add a memory"', 'Quick journal entry'),
      ]),
      
      const SizedBox(height: 20),
      _buildSection('Setup (if needed)', [
        _buildStep('1', 'Open iOS Settings app'),
        _buildStep('2', 'Tap "Siri & Search"'),
        _buildStep('3', 'Find "Aeliana" in app list'),
        _buildStep('4', 'Enable "Show App" and "Learn from this App"'),
      ]),
      
      const SizedBox(height: 20),
      _buildTroubleshootingSection('Troubleshooting', [
        _buildTroubleshootItem(
          'Siri doesn\'t recognize command?',
          'Try saying "Hey Siri" clearly, then the full phrase.',
        ),
        _buildTroubleshootItem(
          'Shortcuts not appearing?',
          'Go to iOS Settings → Siri & Search → Aeliana and enable all options.',
        ),
        _buildTroubleshootItem(
          '"Hey Siri" not working?',
          'Check iOS Settings → Siri & Search → ensure "Listen for Hey Siri" is ON.',
        ),
        _buildTroubleshootItem(
          'Wrong app opens?',
          'Say "Aeliana" clearly. Siri learns your pronunciation over time.',
        ),
      ]),
      
      const SizedBox(height: 20),
      _buildInfoBox(
        'Siri shortcuts work great while driving, cooking, or multitasking! '
        'Just say the magic words and Aeliana opens right up.',
        LucideIcons.car,
      ),
    ];
  }
  
  Widget _buildHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: AelianaColors.hyperGold,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
  
  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AelianaColors.plasmaCyan.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.spaceGrotesk(
                  color: AelianaColors.plasmaCyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSiriCommand(String command, String result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              command,
              style: GoogleFonts.inter(
                color: AelianaColors.plasmaCyan,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(LucideIcons.arrowRight, color: Colors.white24, size: 14),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              result,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTroubleshootingSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.alertCircle, color: Colors.red.shade300, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.red.shade300,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
  
  Widget _buildTroubleshootItem(String problem, String solution) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            problem,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            solution,
            style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoBox(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AelianaColors.hyperGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AelianaColors.hyperGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AelianaColors.hyperGold, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
