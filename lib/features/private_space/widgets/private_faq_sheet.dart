import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sable/core/theme/aeliana_theme.dart';

/// Private Space specific FAQ sheet with best-in-class expandable categories
class PrivateFAQSheet extends StatefulWidget {
  const PrivateFAQSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AelianaColors.carbon,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const PrivateFAQSheet(),
    );
  }

  @override
  State<PrivateFAQSheet> createState() => _PrivateFAQSheetState();
}

class _PrivateFAQSheetState extends State<PrivateFAQSheet> {
  final Set<int> _expandedItems = {};

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          // Handle
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
          
          // Title
          Text(
            '🔐 Private Space FAQ',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFFFF6B9D), // Luna pink
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Everything you need to know about your private sanctuary',
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          
          // Getting Started
          _buildCategory('Getting Started', [
            _FAQItem(
              question: 'What is Private Space?',
              answer: 'Private Space is your encrypted sanctuary for intimate conversations. It\'s completely separate from the main app - different data, different AI companion (Luna), and enhanced privacy protection. Perfect for thoughts you\'d only share with your closest confidant.',
            ),
            _FAQItem(
              question: 'Who is Luna?',
              answer: 'Luna is your dedicated Private Space companion. She\'s more intimate, understanding, and uninhibited than the main AI. Luna remembers your private conversations, learns your deepest preferences, and provides a safe space for authentic expression.',
            ),
            _FAQItem(
              question: 'How do I start using Private Space?',
              answer: 'Simply enter your Private Space PIN (or use Face ID/Touch ID). Your first visit will guide you through setting up your Private Persona - tell Luna about yourself so she can provide deeply personalized responses.',
            ),
          ]),
          
          // Privacy & Security
          _buildCategory('Privacy & Security', [
            _FAQItem(
              question: 'Is my data really private?',
              answer: 'Yes! Private Space uses end-to-end encryption. Your conversations, persona, and all private data are stored separately from the main app and encrypted with Apple\'s Secure Enclave. Even we cannot access your private conversations.',
            ),
            _FAQItem(
              question: 'Can anyone else see my Private Space?',
              answer: 'No. Private Space requires PIN/biometric authentication every time you enter. There\'s no shared history, no cloud sync visible to others, and nothing appears in the main app. It\'s your secret sanctuary.',
            ),
            _FAQItem(
              question: 'What happens if I forget my PIN?',
              answer: 'For maximum security, there\'s no PIN recovery - this ensures no backdoors exist. However, you can reset Private Space from the More menu. This will delete all private data but let you start fresh.',
            ),
          ]),
          
          // Features
          _buildCategory('Features & Usage', [
            _FAQItem(
              question: 'How does the Private Persona work?',
              answer: 'Your Private Persona tells Luna who you really are - your desires, fantasies, secrets, and true self. The more you share, the more Luna can provide authentic, personalized responses that truly understand YOU.',
            ),
            _FAQItem(
              question: 'Does Luna remember our conversations?',
              answer: 'Yes! Luna maintains complete memory of your private conversations, automatically extracting important facts about you. This allows for increasingly personalized and meaningful interactions over time.',
            ),
            _FAQItem(
              question: 'Can I change Luna\'s voice?',
              answer: 'Yes! Private Space has its own voice settings. You can choose from various premium voices for Luna, separate from your main app voice preferences.',
            ),
          ]),
          
          // Subscription
          _buildCategory('Subscription', [
            _FAQItem(
              question: 'Do I need a subscription?',
              answer: 'Private Space is available to Silver tier subscribers and above. Free users can preview Private Space but need to upgrade for full access.',
            ),
            _FAQItem(
              question: 'What\'s included in my subscription?',
              answer: 'Your subscription includes unlimited Private Space conversations, Luna\'s full personality, voice messages, private persona storage, and complete encryption. Higher tiers include more voice credits.',
            ),
          ]),
          
          const SizedBox(height: 32),
          
          // Contact Actions
          Text(
            'Need More Help?',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Feature Request
          _buildActionButton(
            icon: Icons.lightbulb_outline,
            label: 'Request a Feature',
            subtitle: 'Share your ideas for Private Space',
            color: const Color(0xFFFF6B9D),
            onTap: () => _requestFeature(context),
          ),
          const SizedBox(height: 12),
          
          // Support
          _buildActionButton(
            icon: Icons.support_agent,
            label: 'Contact Support',
            subtitle: 'Get help with private issues',
            color: AelianaColors.plasmaCyan,
            onTap: () => _contactSupport(context),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCategory(String title, List<_FAQItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              color: AelianaColors.plasmaCyan,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...items.asMap().entries.map((entry) => _buildExpandableFAQ(entry.key, entry.value)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildExpandableFAQ(int index, _FAQItem item) {
    final isExpanded = _expandedItems.contains(index);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedItems.remove(index);
          } else {
            _expandedItems.add(index);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isExpanded ? AelianaColors.obsidian : AelianaColors.carbon,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExpanded 
                ? const Color(0xFFFF6B9D).withOpacity(0.3) 
                : AelianaColors.plasmaCyan.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.question,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white54,
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 12),
              Text(
                item.answer,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
            Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Future<void> _requestFeature(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'features@aeliana.ai',
      query: _encodeQueryParameters({
        'subject': '[Private Space] Feature Request',
        'body': '''
Hi Aeliana Team,

I have a suggestion for Private Space:

FEATURE IDEA:
[Describe your feature]

WHY IT WOULD HELP:
[How would this improve your experience?]

---
Sent from Aeliana Private Space
''',
      }),
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _contactSupport(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@aeliana.ai',
      query: _encodeQueryParameters({
        'subject': '[Private Space] Support Request',
        'body': '''
Hi Aeliana Support,

I need help with Private Space:

ISSUE:
[Describe your issue]

---
Sent from Aeliana Private Space
''',
      }),
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}

class _FAQItem {
  final String question;
  final String answer;

  const _FAQItem({required this.question, required this.answer});
}
