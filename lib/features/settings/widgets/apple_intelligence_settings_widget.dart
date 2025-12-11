import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/widgets/feature_help_sheet.dart';
import 'dart:io';

/// Apple Intelligence & Siri Settings Widget
/// Shows available Siri shortcuts with setup guidance
class AppleIntelligenceSettingsWidget extends StatelessWidget {
  const AppleIntelligenceSettingsWidget({super.key});
  
  // All available Siri shortcuts
  static const List<Map<String, String>> _siriShortcuts = [
    {'phrase': 'Hey Siri, chat with Aeliana', 'action': 'Opens chat'},
    {'phrase': 'Hey Siri, show my journal', 'action': 'Opens journal'},
    {'phrase': 'Hey Siri, bedside clock', 'action': 'Starts clock mode'},
    {'phrase': 'Hey Siri, mood check', 'action': 'Opens Vital Balance'},
    {'phrase': 'Hey Siri, now playing', 'action': 'Shows mini-player'},
    {'phrase': 'Hey Siri, add a memory', 'action': 'Quick journal entry'},
  ];

  @override
  Widget build(BuildContext context) {
    // Only show on iOS
    if (!Platform.isIOS) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AelianaColors.obsidian,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple.shade400,
                      Colors.blue.shade400,
                      Colors.pink.shade300,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'APPLE INTELLIGENCE',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Siri Shortcuts',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Help button
              GestureDetector(
                onTap: () => FeatureHelpSheet.showSiri(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(LucideIcons.helpCircle, color: Colors.white54, size: 16),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Shortcuts list
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                // Show first 3 shortcuts
                for (int i = 0; i < 3; i++)
                  _buildShortcutRow(_siriShortcuts[i], i < 2),
                
                // Expandable for more
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Show ${_siriShortcuts.length - 3} more shortcuts',
                      style: GoogleFonts.inter(
                        color: AelianaColors.plasmaCyan,
                        fontSize: 12,
                      ),
                    ),
                    iconColor: AelianaColors.plasmaCyan,
                    collapsedIconColor: AelianaColors.plasmaCyan,
                    children: [
                      for (int i = 3; i < _siriShortcuts.length; i++)
                        _buildShortcutRow(_siriShortcuts[i], i < _siriShortcuts.length - 1),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Open iOS Settings button
          GestureDetector(
            onTap: _openSiriSettings,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.shade400.withValues(alpha: 0.3),
                    Colors.blue.shade400.withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.purple.shade400.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.settings, color: Colors.purple.shade200, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Open Siri Settings',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.externalLink, color: Colors.white54, size: 12),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Info text
          Text(
            'Say any phrase to Siri to use these shortcuts. Make sure Siri is enabled in your device settings.',
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildShortcutRow(Map<String, String> shortcut, bool showDivider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(LucideIcons.mic, color: Colors.purple.shade300, size: 14),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Text(
                  shortcut['phrase']!,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(LucideIcons.arrowRight, color: Colors.white24, size: 12),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  shortcut['action']!,
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
      ],
    );
  }
  
  Future<void> _openSiriSettings() async {
    // Deep link to iOS Settings > Siri & Search
    const url = 'App-Prefs:SIRI';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        // Fallback to general settings
        await launchUrl(Uri.parse('App-Prefs:'));
      }
    } catch (e) {
      // iOS settings deep link might be blocked, try alternative
      try {
        await launchUrl(Uri.parse('app-settings:'));
      } catch (_) {
        // Silent fail - user can manually open settings
      }
    }
  }
}
