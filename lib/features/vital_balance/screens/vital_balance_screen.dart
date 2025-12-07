import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sable/features/safety/screens/emergency_screen.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';

/// Vital Balance Screen - Health & Wellness Tracking
/// Uses the "Vitality Strategist" personality for AI interactions
class VitalBalanceScreen extends StatefulWidget {
  const VitalBalanceScreen({super.key});

  @override
  State<VitalBalanceScreen> createState() => _VitalBalanceScreenState();
}

class _VitalBalanceScreenState extends State<VitalBalanceScreen> {
  // Soothing color palette for wellness
  static const Color _backgroundStart = Color(0xFF0D1B2A); // Deep navy
  static const Color _backgroundMid = Color(0xFF1B263B);   // Slate blue
  static const Color _backgroundEnd = Color(0xFF0D1B2A);   // Deep navy
  static const Color _accentTeal = Color(0xFF5DD9C1);      // Soothing teal
  static const Color _accentLavender = Color(0xFFB8A9D9);  // Soft lavender
  static const Color _cardColor = Color(0xFF1E2D3D);       // Dark card
  static const Color _warningAmber = Color(0xFFFFB74D);    // Warning color

  // Avatar and privacy state
  String? _avatarUrl;
  String _archetypeId = 'sable';
  bool _keepConversationsPrivate = true; // Default: private
  
  // Weather state
  String _weatherTemp = '--°';
  String _weatherCondition = '';
  
  static const _keyPrivateConversations = 'vital_balance_private_conversations';
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final stateService = await OnboardingStateService.create();
    
    // Get weather from shared prefs (cached by ChatPage)
    final cachedTemp = prefs.getString('cached_weather_temp');
    final cachedCondition = prefs.getString('cached_weather_condition');
    
    if (!mounted) return;
    setState(() {
      _avatarUrl = stateService.avatarUrl;
      _archetypeId = stateService.selectedArchetypeId;
      _keepConversationsPrivate = prefs.getBool(_keyPrivateConversations) ?? true;
      if (cachedTemp != null) _weatherTemp = cachedTemp;
      if (cachedCondition != null) _weatherCondition = cachedCondition;
    });
  }
  
  Future<void> _togglePrivacy(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPrivateConversations, value);
    if (!mounted) return;
    setState(() => _keepConversationsPrivate = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _backgroundStart,
              _backgroundMid,
              _backgroundEnd,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    // Weather on the left (bold)
                    Text(
                      _weatherTemp,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (_weatherCondition.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        _weatherCondition,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Title on the right
                    Text(
                      'Vital Balance',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // User's avatar
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Your companion is in Wellness Coach mode'),
                            backgroundColor: _cardColor,
                          ),
                        );
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_accentTeal, _accentLavender],
                          ),
                          border: Border.all(color: _accentTeal, width: 2),
                        ),
                        child: ClipOval(
                          child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                              ? Image.network(
                                  _avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                                )
                              : _buildDefaultAvatar(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Medical Disclaimer
                      _buildDisclaimer(),
                      
                      const SizedBox(height: 16),
                      
                      // Privacy Settings
                      _buildPrivacySettings(),
                      
                      const SizedBox(height: 20),
                      
                      // Wellness Quote Card
                      _buildWellnessCard(),
                      
                      const SizedBox(height: 20),
                      
                      // Wellness Coach Chat
                      _buildWellnessChat(),
                      
                      const SizedBox(height: 24),
                      
                      // Metrics Section Header
                      _buildSectionHeader('Today\'s Metrics', LucideIcons.activity),
                      
                      const SizedBox(height: 16),
                      
                      // Metrics Grid
                      _buildMetricsGrid(),
                      
                      const SizedBox(height: 24),
                      
                      // Coming Soon Features
                      _buildSectionHeader('Coming Soon', LucideIcons.sparkles),
                      
                      const SizedBox(height: 16),
                      
                      _buildComingSoonList(),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Medical Disclaimer Banner
  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _warningAmber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _warningAmber.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: _warningAmber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Important Disclaimer',
                  style: GoogleFonts.spaceGrotesk(
                    color: _warningAmber,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'This app and its AI companion are not medical professionals, licensed counselors, or qualified to diagnose or treat mental health disorders. This tool is for wellness tracking only.',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'If you are in crisis or need immediate help, please seek professional care.',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          // Quick action buttons
          Row(
            children: [
              Expanded(
                child: _buildEmergencyButton(
                  icon: LucideIcons.shieldAlert,
                  label: 'Crisis Resources',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmergencyScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEmergencyButton(
                  icon: LucideIcons.phone,
                  label: 'Alert Contact',
                  onTap: () {
                    // TODO: Implement notify emergency contact
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Emergency contact notification coming soon'),
                        backgroundColor: _cardColor,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.red[300], size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.red[300],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWellnessCard() {
    // Dynamic daily quotes - rotates based on day of year
    final dailyQuotes = [
      "Every small step counts. Your wellness journey is uniquely yours.",
      "You are stronger than you know. Take it one moment at a time.",
      "Today is a new opportunity to prioritize your mental health.",
      "Self-care isn't selfish. It's necessary for a balanced life.",
      "Progress, not perfection. You're doing better than you think.",
      "Your feelings are valid. Take time to honor them today.",
      "Rest is productive. Give yourself permission to recharge.",
      "You deserve the same kindness you give to others.",
      "Small acts of self-love create big changes over time.",
      "Healing isn't linear. Be patient with yourself.",
      "Your mental health matters. Check in with yourself today.",
      "You are worthy of peace, joy, and good mental health.",
      "Take a deep breath. You've got this.",
      "It's okay to ask for help. Strength comes in many forms.",
      "Celebrate your wins today, no matter how small.",
      "Your thoughts don't define you. You're more than your mind.",
      "Today, choose one thing that brings you calm.",
      "You are enough, exactly as you are right now.",
      "Be gentle with yourself. Growth takes time.",
      "Your well-being is the foundation for everything else.",
      "Finding balance is a daily practice, not a destination.",
      "You matter. Your health matters. Take care of you.",
      "A moment of calm can change your entire day.",
      "Trust your journey. Every step forward counts.",
      "You're allowed to set boundaries and protect your peace.",
      "Gratitude transforms ordinary days into blessings.",
      "Your body does amazing things. Thank it with rest and care.",
      "Hope is always available. Reach for it today.",
      "Connection heals. Reach out to someone you trust.",
      "You survived 100% of your hardest days. Keep going.",
    ];
    
    // Get quote based on day of year for consistency throughout the day
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final todaysQuote = dailyQuotes[dayOfYear % dailyQuotes.length];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentTeal.withOpacity(0.2),
            _accentLavender.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentTeal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.quote, color: _accentTeal, size: 24),
              const SizedBox(width: 12),
              Text(
                'Your Coach Says',
                style: GoogleFonts.inter(
                  color: _accentTeal,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"$todaysQuote"',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWellnessChat() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentTeal.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with avatar
          Row(
            children: [
              // User's avatar - wellness coach mode
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_accentTeal, _accentLavender],
                  ),
                  border: Border.all(color: _accentTeal, width: 2),
                ),
                child: ClipOval(
                  child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                      ? Image.network(
                          _avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                        )
                      : _buildDefaultAvatar(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Wellness Coach',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Vitality Strategist Mode',
                      style: GoogleFonts.inter(
                        color: _accentTeal,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.sparkles, color: _accentTeal, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          
          // Quick prompts
          Text(
            'Quick check-in:',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickPrompt('How\'s my energy?', LucideIcons.zap),
              _buildQuickPrompt('Sleep tips', LucideIcons.moon),
              _buildQuickPrompt('Stress relief', LucideIcons.heart),
              _buildQuickPrompt('Mood boost', LucideIcons.smile),
            ],
          ),
          const SizedBox(height: 16),
          
          // Chat input
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _accentTeal.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Ask about your wellness...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (text) {
                      if (text.isNotEmpty) {
                        _startWellnessChat(text);
                      }
                    },
                  ),
                ),
                IconButton(
                  onPressed: () => _startWellnessChat('General wellness check'),
                  icon: Icon(LucideIcons.send, color: _accentTeal),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickPrompt(String label, IconData icon) {
    return GestureDetector(
      onTap: () => _startWellnessChat(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _accentTeal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accentTeal.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _accentTeal, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: _accentTeal,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _startWellnessChat(String prompt) {
    // Navigate to main chat with wellness context
    // The chat will use Vitality Strategist personality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting wellness chat: "$prompt"'),
        backgroundColor: _cardColor,
      ),
    );
    // TODO: Navigate to dedicated wellness chat screen or open chat overlay
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _accentTeal, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildMetricCard('Sleep', '-- hrs', LucideIcons.moon, _accentLavender),
        _buildMetricCard('Energy', '--/10', LucideIcons.zap, const Color(0xFFFFC857)),
        _buildMetricCard('Stress', '--/10', LucideIcons.brain, const Color(0xFFFF6B6B)),
        _buildMetricCard('Weight', '-- lbs', LucideIcons.scale, _accentTeal),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: accentColor, size: 24),
              IconButton(
                icon: Icon(LucideIcons.plus, color: Colors.white54, size: 20),
                onPressed: () {
                  // TODO: Add metric entry
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonList() {
    final features = [
      ('Sleep Quality Tracking', LucideIcons.bedDouble),
      ('Pain Level Monitor', LucideIcons.thermometer),
      ('Prescription Reminders', LucideIcons.pill),
      ('Medical Team Contacts', LucideIcons.stethoscope),
    ];

    return Column(
      children: features.map((feature) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _cardColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Icon(feature.$2, color: _accentTeal.withOpacity(0.6), size: 20),
              const SizedBox(width: 14),
              Text(
                feature.$1,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentLavender.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'SOON',
                  style: GoogleFonts.inter(
                    color: _accentLavender,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  /// Default avatar fallback
  Widget _buildDefaultAvatar() {
    return Container(
      color: _cardColor,
      child: Center(
        child: Icon(LucideIcons.heartPulse, color: _accentTeal, size: 22),
      ),
    );
  }

  /// Privacy settings toggle
  Widget _buildPrivacySettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentLavender.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.shieldOff, color: _accentLavender, size: 20),
              const SizedBox(width: 10),
              Text(
                'Privacy Settings',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Privacy toggle
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keep conversations private',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _keepConversationsPrivate
                          ? 'Health chats stay in this tab only'
                          : 'May be referenced in main chat',
                      style: GoogleFonts.inter(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _keepConversationsPrivate,
                onChanged: _togglePrivacy,
                activeColor: _accentTeal,
                activeTrackColor: _accentTeal.withOpacity(0.3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
