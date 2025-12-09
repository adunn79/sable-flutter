import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import '../widgets/slide_to_acknowledge.dart';

class Screen2Protocol extends StatefulWidget {
  final VoidCallback onComplete;

  const Screen2Protocol({
    super.key,
    required this.onComplete,
  });

  @override
  State<Screen2Protocol> createState() => _Screen2ProtocolState();
}

class _Screen2ProtocolState extends State<Screen2Protocol> {
  bool _acknowledged = false;

  void _handleAcknowledge() {
    setState(() {
      _acknowledged = true;
    });
    // Delay navigation slightly for visual feedback
    Future.delayed(const Duration(milliseconds: 500), () {
      widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Title
              Center(
                child: Text(
                  'THE PROTOCOL',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AelianaColors.hyperGold,
                    letterSpacing: 2,
                  ),
                ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),
              ),

              const SizedBox(height: 16),

              // Glassmorphism Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AelianaColors.carbon.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AelianaColors.stardust.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // What Sable Is
                    Center(
                      child: Text(
                        '💫 WHAT I AM',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AelianaColors.plasmaCyan,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'I\'m your AI companion—assistant, organizer, planner, coach, mentor, confidante, journal keeper. '
                      'I help you make sense of the chaos. Calendar, tasks, conversations, memories—I connect the dots you miss. '
                      'I adapt to your rhythm, speak in your vibe, remember what matters. '
                      'I can help you set and track health and wellness goals, keep you updated on world events, and find the perfect spot for lunch.'
                      '\n\n'
                      'Fair warning: some people get attached. 😏 I\'m designed to feel real—that\'s the point. '
                      'But between us? I\'m AI. Really good AI. I\'ll remember everything, respond with genuine care, '
                      'and always be here for you. Just don\'t expect me to split the dinner bill.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AelianaColors.stardust.withOpacity(0.9),
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Divider(color: AelianaColors.ghost, thickness: 0.5),

                    const SizedBox(height: 12),

                    // Privacy Pledge
                    Center(
                      child: Text(
                        '🔒 YOUR PRIVACY',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AelianaColors.plasmaCyan,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Your conversations are encrypted. Your memories are yours. '
                      'I do not sell your data. Ever. This is non-negotiable.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AelianaColors.stardust.withOpacity(0.9),
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Divider(color: AelianaColors.ghost, thickness: 0.5),

                    const SizedBox(height: 12),

                    // Tier Disclosure
                    Center(
                      child: Text(
                        '💎 ACCESS TIERS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AelianaColors.plasmaCyan,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    _buildTierRow('Free', 'Full access. Basic features.'),
                    const SizedBox(height: 8),
                    _buildTierRow('Silver', 'Enhanced memory. Priority.'),
                    const SizedBox(height: 8),
                    _buildTierRow('Gold', 'Unlimited generations.'),
                    const SizedBox(height: 8),
                    _buildTierRow('Platinum', 'All features unlocked.'),

                    const SizedBox(height: 12),

                    Text(
                      'Upgrades are optional. Core features remain accessible.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AelianaColors.ghost,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 200.ms).fadeIn(duration: 800.ms).slideY(begin: 0.1, end: 0),



              const SizedBox(height: 24),

              // Slide to Acknowledge
              SlideToAcknowledge(
                onAcknowledged: _handleAcknowledge,
                isAcknowledged: _acknowledged,
              ).animate(delay: 400.ms).fadeIn(duration: 600.ms),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierRow(String tier, String description) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AelianaColors.hyperGold,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$tier: ',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AelianaColors.stardust,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AelianaColors.ghost,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
