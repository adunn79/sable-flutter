import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/widgets/restart_widget.dart';
import 'package:sable/core/widgets/active_avatar_ring.dart';
import 'package:sable/core/backup/icloud_backup_service.dart';
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
          
          // iCloud Recovery - Prominent for returning users
          _buildMenuItem(
            context,
            icon: LucideIcons.cloudDownload,
            title: 'Restore from iCloud',
            subtitle: 'Recover your data from backup',
            onTap: () => _showRestoreDialog(context),
            highlight: true,
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
        initialChildSize: 0.85,
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
              'Help & FAQ',
              style: GoogleFonts.spaceGrotesk(
                color: AelianaColors.hyperGold,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Everything you need to know about Aeliana',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            // GETTING STARTED
            _buildFAQCategory('Getting Started'),
            _buildFAQItem(
              'What is Aeliana?',
              'Aeliana is your intelligent AI companion designed to help you navigate daily life, track wellness, manage your calendar, and provide personalized support. She learns and adapts to your preferences over time, becoming more helpful the more you interact.',
            ),
            _buildFAQItem(
              'How do I get started?',
              'Simply complete the onboarding flow: tell Aeliana your name, select your avatar, and grant permissions for features you want (calendar, contacts, etc.). You can always change settings later from the More menu.',
            ),
            _buildFAQItem(
              'Can I change my avatar later?',
              'Yes! Go to Settings > Avatar to select a new pre-made character or generate a custom AI avatar. Your conversation history and memories are preserved when you switch.',
            ),
            _buildFAQItem(
              'What can I ask Aeliana?',
              'Anything! Ask about weather, news, calendar events, set reminders, get wellness tips, journal your thoughts, or just chat. Aeliana can also search the web, control music, and integrate with your native apps.',
            ),
            
            // CORE FEATURES
            _buildFAQCategory('Core Features'),
            _buildFAQItem(
              'How does the Chat work?',
              'Chat is your main interaction with Aeliana. Type or use voice input to communicate. Aeliana remembers your conversations, learns your preferences, and provides personalized responses based on context.',
            ),
            _buildFAQItem(
              'What is the Calendar integration?',
              'Aeliana can read your device calendars, help create events, detect conflicts, and remind you of upcoming appointments. Say "Create an event" or "What\'s on my calendar today?" to get started.',
            ),
            _buildFAQItem(
              'How does the Journal work?',
              'Journal is your private diary with AI assistance. It supports mood tracking, automatic context capture (weather, location, music), and memory extraction. Your journal entries help Aeliana understand you better.',
            ),
            _buildFAQItem(
              'What is Vital Balance?',
              'Vital Balance is your wellness dashboard. Track mood, energy, sleep, and health metrics. Your Wellness Coach provides personalized tips and insights based on your patterns.',
            ),
            _buildFAQItem(
              'How does Clock Mode work?',
              'Clock Mode transforms your device into a beautiful bedside clock. It supports Digital, Analog, Flip, and Minimal styles. Set it on your nightstand for a sleek always-on display.',
            ),
            _buildFAQItem(
              'What is Private Space?',
              'Private Space is a premium encrypted sanctuary for intimate conversations with Luna, your private companion. It has enhanced privacy, separate data storage, and requires PIN/biometric access.',
            ),
            
            // VOICE FEATURES
            _buildFAQCategory('Voice Features'),
            _buildFAQItem(
              'How do voice features work?',
              'Enable voice from the chat header (speaker icon). Aeliana uses premium text-to-speech with cultural-appropriate voices for each personality. Voice credits are included based on your subscription tier.',
            ),
            _buildFAQItem(
              'Can I talk to Aeliana (speech-to-text)?',
              'Yes! Tap the microphone icon in chat to speak your message. This requires microphone permission, which you can grant from Settings > Privacy.',
            ),
            _buildFAQItem(
              'How do I change Aeliana\'s voice?',
              'Each avatar has a culturally-appropriate default voice. Custom voice selection is available in Settings > Voice for premium subscribers.',
            ),
            
            // PRIVACY & SECURITY
            _buildFAQCategory('Privacy & Security'),
            _buildFAQItem(
              'Is my data secure?',
              'Yes! All sensitive data is encrypted using Apple-approved encryption. Your conversations and personal information are stored locally on your device. Private Space uses additional encryption.',
            ),
            _buildFAQItem(
              'Does Aeliana store my conversations in the cloud?',
              'By default, no. All data stays on your device. If you enable iCloud Backup, encrypted backups are stored securely in your iCloud account - only you can access them.',
            ),
            _buildFAQItem(
              'What permissions does Aeliana need?',
              'Optional: Calendar (for events), Contacts (for people context), Location (for weather/local info), Microphone (for voice input), Photos (for journal). All are optional - the app works without them.',
            ),
            _buildFAQItem(
              'How do I delete my data?',
              'Go to Settings > Privacy > Delete All Data to permanently erase all app data. For Private Space, use More > Reset Private Space. This cannot be undone.',
            ),
            
            // SUBSCRIPTION
            _buildFAQCategory('Subscription & Billing'),
            _buildFAQItem(
              'What subscription tiers are available?',
              'Free: Basic features, limited voice. Silver: Unlimited chat, 50 voice credits/mo, Private Space access. Gold: 150 voice/mo, video responses. Platinum: Unlimited everything, priority support.',
            ),
            _buildFAQItem(
              'How do I upgrade my subscription?',
              'Go to Settings > Subscription to view plans and upgrade. Subscriptions are managed through Apple\'s App Store and renew automatically unless cancelled.',
            ),
            _buildFAQItem(
              'How do I cancel my subscription?',
              'Open Settings app > Your Name > Subscriptions > Aeliana > Cancel. You\'ll retain access until the end of your billing period.',
            ),
            _buildFAQItem(
              'What are voice credits?',
              'Voice credits let Aeliana speak responses aloud. Each spoken response uses 1 credit. Free users get 5/day, paid tiers get 50-unlimited/month.',
            ),
            
            // TROUBLESHOOTING
            _buildFAQCategory('Troubleshooting'),
            _buildFAQItem(
              'Aeliana isn\'t responding - what do I do?',
              'Check your internet connection first. Try restarting the app from More > Restart App. If issues persist, contact support@aeliana.ai.',
            ),
            _buildFAQItem(
              'Voice isn\'t playing on my iPad',
              'Ensure volume is up and not in silent mode. Try tapping the speaker icon in chat to toggle voice on/off. Check that voice is enabled in Settings.',
            ),
            _buildFAQItem(
              'Calendar events aren\'t showing',
              'Make sure Calendar permission is granted in Settings > Privacy. Pull down to refresh in the Calendar tab. Try restarting the app.',
            ),
            _buildFAQItem(
              'How do I report a bug?',
              'Email bugs@aeliana.ai with a description of the issue, your device model, and iOS version. Screenshots help! We respond within 24 hours.',
            ),
            
            const SizedBox(height: 24),
            
            // Support links
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _requestFeature(context);
                    },
                    icon: const Icon(LucideIcons.lightbulb, size: 18),
                    label: const Text('Request Feature'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AelianaColors.hyperGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse('mailto:support@aeliana.ai');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    icon: const Icon(LucideIcons.mail, size: 18),
                    label: const Text('Email Support'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AelianaColors.plasmaCyan,
                      side: BorderSide(color: AelianaColors.plasmaCyan),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(color: Colors.white54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFAQCategory(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          color: AelianaColors.plasmaCyan,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
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

  /// Show iCloud restore dialog
  Future<void> _showRestoreDialog(BuildContext context) async {
    // Check if iCloud is available
    final isAvailable = await iCloudBackupService.isAvailable();
    final statusMessage = await iCloudBackupService.getAccountStatusMessage();
    final lastBackup = await iCloudBackupService.getLastBackupTime();
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AelianaColors.carbon,
        title: Text(
          'Restore from iCloud',
          style: GoogleFonts.spaceGrotesk(
            color: AelianaColors.hyperGold,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAvailable ? LucideIcons.checkCircle : LucideIcons.alertCircle,
                  color: isAvailable ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusMessage,
                    style: GoogleFonts.inter(color: Colors.white70),
                  ),
                ),
              ],
            ),
            if (lastBackup != null) ...[
              const SizedBox(height: 12),
              Text(
                'Last backup: ${_formatDate(lastBackup)}',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'This will restore your journals, memories, and settings from your iCloud backup. Current data will be replaced.',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          if (isAvailable)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _performRestore(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AelianaColors.hyperGold,
                foregroundColor: Colors.black,
              ),
              child: Text('Restore', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.month}/${date.day}/${date.year}';
  }
  
  Future<void> _performRestore(BuildContext context) async {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AelianaColors.carbon,
        content: Row(
          children: [
            const CircularProgressIndicator(color: AelianaColors.plasmaCyan),
            const SizedBox(width: 16),
            Text('Restoring...', style: GoogleFonts.inter(color: Colors.white)),
          ],
        ),
      ),
    );
    
    try {
      final result = await iCloudBackupService.performFullRestore();
      if (context.mounted) Navigator.pop(context); // Close progress
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success 
              ? '✅ Restore complete! Restart app to see changes.'
              : '❌ Restore failed: ${result.message}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Close progress
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
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
