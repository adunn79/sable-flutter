import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/widgets/restart_widget.dart';
import 'package:sable/core/widgets/active_avatar_ring.dart';
import 'package:sable/features/private_space/services/private_storage_service.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'about_screen.dart';
import 'help_support_screen.dart';
import '../widgets/settings_chat_sheet.dart';

/// More screen - provides access to Settings and other options
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  OnboardingStateService? _stateService;
  String? _avatarUrl;
  String _archetypeId = 'aeliana';
  String _userName = 'there';

  @override
  void initState() {
    super.initState();
    _loadAvatarSettings();
  }

  Future<void> _loadAvatarSettings() async {
    final service = await OnboardingStateService.create();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _stateService = service;
      _avatarUrl = service.avatarUrl;
      _archetypeId = service.selectedArchetypeId ?? 'aeliana';
      _userName = prefs.getString('user_name') ?? 'there';
    });
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
          onPressed: () => context.go('/chat'),
        ),
        title: Text(
          'More',
          style: GoogleFonts.spaceGrotesk(
            color: AelianaColors.hyperGold,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // AI Avatar Header
          _buildAvatarHeader(),
          const SizedBox(height: 24),
          _buildMenuItem(
            context,
            icon: LucideIcons.settings,
            title: 'Settings',
            subtitle: 'Personalize your experience',
            onTap: () => context.go('/settings'),
          ),
          const SizedBox(height: 12),
          
          // Clock Mode - Prominent button
          _buildMenuItem(
            context,
            icon: LucideIcons.clock,
            title: 'Clock Mode',
            subtitle: 'Full-screen clock & nightstand display',
            onTap: () => context.go('/clock'),
            highlight: true,
          ),
          const SizedBox(height: 12),
          
          // FAQ
          _buildMenuItem(
            context,
            icon: LucideIcons.helpCircle,
            title: 'FAQ',
            subtitle: 'Frequently asked questions',
            onTap: () => _showFAQ(context),
          ),
          const SizedBox(height: 12),
          
          // Request a Feature
          _buildMenuItem(
            context,
            icon: LucideIcons.lightbulb,
            title: 'Request a Feature',
            subtitle: 'Share your ideas with us',
            onTap: () => _requestFeature(context),
          ),
          const SizedBox(height: 12),

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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: LucideIcons.info,
            title: 'About',
            subtitle: 'App version and credits',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
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

  /// Show comprehensive FAQ dialog
  void _showFAQ(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AelianaColors.carbon,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Frequently Asked Questions',
              style: GoogleFonts.spaceGrotesk(
                color: AelianaColors.hyperGold,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildFAQItem(
              'What is Aeliana?',
              'Aeliana is your intelligent AI companion designed to help you navigate daily life, track wellness, manage your calendar, and provide personalized support. She learns and adapts to your preferences over time.',
            ),
            _buildFAQItem(
              'How does Clock Mode work?',
              'Clock Mode transforms your device into a beautiful bedside clock. It can auto-activate when your device is idle, and supports multiple styles including Digital, Analog, Flip, and Minimal views.',
            ),
            _buildFAQItem(
              'What is Private Space?',
              'Private Space is a premium sanctuary for intimate conversations. It features enhanced privacy, Luna (your private companion), and secure encrypted storage. Requires Silver tier or above.',
            ),
            _buildFAQItem(
              'How do subscriptions work?',
              'We offer Free, Silver, Gold, and Platinum tiers. Higher tiers unlock more voice credits, video features, Private Space access, and premium AI capabilities.',
            ),
            _buildFAQItem(
              'Is my data secure?',
              'Yes! All sensitive data is encrypted using Apple-approved encryption. Your conversations and personal information never leave your device unless you explicitly enable cloud backup.',
            ),
            _buildFAQItem(
              'How do I customize my avatar?',
              'During onboarding, choose from pre-built characters or create a custom AI-generated avatar. You can change your avatar anytime from Settings > Avatar.',
            ),
            _buildFAQItem(
              'What is the Journal feature?',
              'Journal is your private diary with AI assistance. It supports rich text, mood tracking, automatic context capture (weather, location, music), and memory extraction for personalized AI responses.',
            ),
            _buildFAQItem(
              'How do voice features work?',
              'Voice features use premium text-to-speech for natural responses. Enable voice in chat settings. Premium tiers include monthly voice credits.',
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(color: AelianaColors.plasmaCyan),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AelianaColors.obsidian,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AelianaColors.plasmaCyan.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Send feature request email
  Future<void> _requestFeature(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'features@aeliana.ai',
      query: _encodeQueryParameters({
        'subject': '[Aeliana App] Feature Request',
        'body': '''
Hello Aeliana Team,

I would like to request the following feature:

FEATURE DESCRIPTION:
[Please describe your feature idea here]

USE CASE:
[How would this help you?]

PRIORITY:
[Nice to have / Important / Critical]

---
Sent from Aeliana App
User: $_userName
''',
      }),
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open email. Please email features@aeliana.ai directly.'),
          ),
        );
      }
    }
  }

  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }


  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: highlight ? AelianaColors.hyperGold.withOpacity(0.1) : AelianaColors.carbon,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight ? AelianaColors.hyperGold.withOpacity(0.5) : AelianaColors.plasmaCyan.withOpacity(0.15),
            width: highlight ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: highlight ? AelianaColors.hyperGold.withOpacity(0.2) : AelianaColors.plasmaCyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: highlight ? AelianaColors.hyperGold : AelianaColors.plasmaCyan, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: highlight ? AelianaColors.hyperGold : Colors.white,
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
            Icon(LucideIcons.chevronRight, color: highlight ? AelianaColors.hyperGold : Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarHeader() {
    final imagePath = (_avatarUrl != null && _avatarUrl!.isNotEmpty) 
        ? _avatarUrl! 
        : 'assets/images/archetypes/$_archetypeId.png';
    
    return GestureDetector(
      onTap: () => showSettingsChatSheet(context),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AelianaColors.carbon,
              AelianaColors.obsidian,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AelianaColors.plasmaCyan.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            // Avatar with animated ring
            ActiveAvatarRing(
              size: 80,
              isActive: true,  // Always show the ring animation
              showRing: true,
              child: CircleAvatar(
                radius: 32,
                backgroundImage: (imagePath.startsWith('http'))
                    ? NetworkImage(imagePath) as ImageProvider
                    : AssetImage(imagePath),
              ),
            ),
            const SizedBox(width: 16),
            // Text and tap hint
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _archetypeId.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      color: AelianaColors.hyperGold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hey $_userName! Need anything?',
                    style: GoogleFonts.inter(
                      color: AelianaColors.stardust,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to chat →',
                    style: GoogleFonts.inter(
                      color: AelianaColors.plasmaCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
