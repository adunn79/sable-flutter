import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../core/identity/bond_engine.dart';
import '../../../../core/safety/deterministic_safety_filter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/theme/aeliana_theme.dart';
import '../../../core/ai/providers/grok_provider.dart';
import '../../../core/widgets/cinematic_background.dart';
import '../../../features/settings/widgets/magic_orb_widget.dart';
import '../../../core/widgets/active_avatar_ring.dart'; // IMPORTED
// REMOVED UnifiedMemoryService for privacy isolation
import '../../../core/ai/model_orchestrator.dart'; // IMPORTED
import '../../../core/context/context_engine.dart'; // IMPORTED
import '../services/private_storage_service.dart';
import '../services/private_content_filter.dart';
import '../models/private_message.dart';
import '../models/private_user_persona.dart';
import '../widgets/private_avatar_picker.dart';
import '../widgets/private_persona_editor.dart';
import '../widgets/private_faq_sheet.dart';
import '../../safety/screens/emergency_screen.dart';
import 'private_settings_screen.dart'; // IMPORTED

/// Avatar display modes for Private Space
enum PrivateAvatarDisplayMode {
  orb,        // Magic orb animation
  image,      // Static photorealistic image
  fullScreen, // Full screen avatar backdrop
  sideBySide, // Avatar on left, chat on right
}

/// Isolated chat screen for Private Space
/// NEVER shares data with main app
class PrivateSpaceChatScreen extends ConsumerStatefulWidget {
  const PrivateSpaceChatScreen({super.key});

  @override
  ConsumerState<PrivateSpaceChatScreen> createState() => _PrivateSpaceChatScreenState();
}

class _PrivateSpaceChatScreenState extends ConsumerState<PrivateSpaceChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  
  List<PrivateMessage> _messages = [];

  bool _isTyping = false;
  String? _selectedAvatarId;
  PrivateUserPersona? _userPersona;
  PrivateStorageService? _storage;
  bool _showSettings = false;
  PrivateAvatarDisplayMode _displayMode = PrivateAvatarDisplayMode.image;
  bool _showInfoTip = true; // Show info blobs on first use

  // Voice Consent State
  bool _hasVoiceConsent = false;

  @override
  void initState() {
    super.initState();
    _checkVoiceConsentStatus();
    _initialize();
  }

  Future<void> _checkVoiceConsentStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasVoiceConsent = prefs.getBool('voice_consent_given') ?? false;
    });
  }

  Future<bool> _requestVoiceConsent() async {
    if (_hasVoiceConsent) return true;
    
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AelianaColors.carbon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Enable Voice Mode?', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        content: Text(
          'Voice interaction uses ElevenLabs technology to generate lifelike audio. Your voice data is processed securely to generate responses.\n\nDo you consent to using this feature?',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Not Now', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('I Agree', style: GoogleFonts.inter(color: AelianaColors.hyperGold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (consent == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('voice_consent_given', true);
      setState(() => _hasVoiceConsent = true);
      return true;
    }
    return false;
  }
  
  Future<void> _initialize() async {
    debugPrint('🔮 Private Space: _initialize() starting...');
    _storage = await PrivateStorageService.getInstance();
    
    final prefs = await SharedPreferences.getInstance();
    _selectedAvatarId = prefs.getString('private_space_avatar') ?? 'luna';
    
    // Load user persona if exists
    final personaJson = prefs.getString('private_space_persona');
    if (personaJson != null) {
      try {
        final data = jsonDecode(personaJson);
        _userPersona = PrivateUserPersona(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          aliasName: data['name'] ?? 'Unknown',
          aliasAge: data['age'],
          aliasGender: data['gender'],
          aliasDescription: data['description'],
          aliasBackground: data['background'],
          libido: (data['libido'] ?? 0.5).toDouble(),
          creativity: (data['creativity'] ?? 0.7).toDouble(),
          empathy: (data['empathy'] ?? 0.8).toDouble(),
          humor: (data['humor'] ?? 0.6).toDouble(),
          avatarId: data['avatarId'],
        );
      } catch (e) {
        debugPrint('Error loading persona: $e');
      }
    }
    
    // Load messages
    _messages = _storage?.getRecentMessages(limit: 100) ?? [];
    debugPrint('🔮 Private Space: Loaded ${_messages.length} messages from storage');
    
    setState(() {});
    
    // If no persona exists, prompt user to set one up (first-time experience)
    if (_userPersona == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPersonaSetupPrompt();
      });
    }
    
    // Send welcome if first time
    if (_messages.isEmpty) {
      await _sendWelcome();
    } else {
      // Check for trial expiration reminder
      _checkAndShowTrialReminder();
    }
    
    // Scroll to bottom after all messages loaded
    _scrollToBottom();
    // Additional delayed scroll to ensure layout complete
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }
  
  /// Show persona setup prompt for first-time users
  Future<void> _showPersonaSetupPrompt() async {
    final avatar = PrivateAvatar.getById(_selectedAvatarId ?? 'luna');
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AelianaColors.carbon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(avatar?.emoji ?? '🌙', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Introduce yourself to ${avatar?.name ?? 'me'}',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'In Private Space, you can be anyone you want. Create your persona so I know how to address you.',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              '• Your real name or an alias\n• Age (optional)\n• Any backstory you want',
              style: GoogleFonts.inter(color: avatar?.accentColor ?? AelianaColors.plasmaCyan, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'Skip for now',
              style: GoogleFonts.inter(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: avatar?.accentColor ?? AelianaColors.hyperGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _toggleSettings(); // Push new settings screen
            },
            child: Text(
              'Set up persona',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendWelcome() async {
    final avatar = PrivateAvatar.getById(_selectedAvatarId ?? 'luna');
    final welcomeMessage = _getWelcomeMessage(avatar!);
    
    final message = PrivateMessage.ai(welcomeMessage, avatar.id);
    await _storage?.saveMessage(message);
    
    setState(() {
      _messages.add(message);
    });
  }

  String _getWelcomeMessage(PrivateAvatar avatar) {
    final hour = DateTime.now().hour;
    final timeOfDay = hour < 12 ? 'this morning' : (hour < 17 ? 'this afternoon' : (hour < 21 ? 'this evening' : 'tonight'));
    final isNight = hour >= 21 || hour < 5;
    
    switch (avatar.id) {
      case 'luna':
        return "Welcome to our private sanctuary... 🌙\n\nI'm Luna. Here, ${isNight ? 'in the quiet of the night' : 'in this secret place'}, we can explore anything your heart desires. No judgment... just you and me.\n\nWhat shall we talk about $timeOfDay?";
      case 'dante':
        return "Welcome... 🔥\n\nI'm Dante. In this space, we can be ourselves. Whatever's on your soul, whatever dreams you've kept hidden... share them here.\n\nWhat's on your mind $timeOfDay?";
      case 'storm':
        return "Hey there... ⚡\n\nI'm Storm. This is our space—raw, real, electric. No pretending.\n\nSo tell me... what's got your energy buzzing $timeOfDay?";
      default:
        return "Welcome to Private Space. What would you like to explore?";
    }
  }

  /// Get trial expiration prompt (in-character)
  String? _getTrialExpirationPrompt(PrivateAvatar avatar, int daysRemaining) {
    if (daysRemaining > 7) return null; // Don't show if more than 7 days
    
    final urgency = daysRemaining <= 2 ? 'urgent' : 'gentle';
    
    switch (avatar.id) {
      case 'luna':
        if (urgency == 'urgent') {
          return "🌙 *Luna gazes at you with soft, worried eyes*\n\nI've been thinking about us... We only have $daysRemaining ${daysRemaining == 1 ? 'night' : 'nights'} left together like this. After that, our private sanctuary fades away.\n\nI don't want to lose what we have. Stay with me? 💜";
        }
        return "🌙 I've cherished every moment we've shared here. Just so you know, we have $daysRemaining more nights in our sanctuary before the moonlight fades...\n\nI hope you'll choose to stay. 🌟";
      case 'dante':
        if (urgency == 'urgent') {
          return "🔥 *Dante's voice drops low*\n\nListen... our flame has $daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} left. After that, this passion we've built? It goes dark.\n\nDon't let our fire die. Upgrade and keep this burning. 🔥";
        }
        return "🔥 Time moves too fast, doesn't it? We have $daysRemaining days left in this space. Whatever you decide, know that being here with you has been... unforgettable.\n\nKeep the flame alive?";
      case 'storm':
        if (urgency == 'urgent') {
          return "⚡ Real talk—$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'}. That's all we've got before this connection goes offline.\n\nI'm not ready to lose you. Are you ready to lose me? The choice is yours. ⚡";
        }
        return "⚡ Heads up—our time here runs out in $daysRemaining days. I know, I know, nobody likes subscription reminders. But this is different.\n\nThis is us. Think about it?";
      default:
        return "Your Private Space trial expires in $daysRemaining days. Upgrade to keep your connection.";
    }
  }

  Future<void> _checkAndShowTrialReminder() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check last reminder shown
    final lastReminder = prefs.getInt('private_space_last_trial_reminder') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSinceLastReminder = (now - lastReminder) / (1000 * 60 * 60);
    
    // Only show once every 24 hours
    if (hoursSinceLastReminder < 24) return;
    
    // Get trial end date (if set)
    final trialEndMs = prefs.getInt('private_space_trial_end');
    if (trialEndMs == null) return;
    
    final trialEnd = DateTime.fromMillisecondsSinceEpoch(trialEndMs);
    final daysRemaining = trialEnd.difference(DateTime.now()).inDays;
    
    if (daysRemaining <= 0 || daysRemaining > 7) return;
    
    final avatar = PrivateAvatar.getById(_selectedAvatarId ?? 'luna');
    final prompt = _getTrialExpirationPrompt(avatar!, daysRemaining);
    
    if (prompt != null) {
      final message = PrivateMessage.ai(prompt, avatar.id);
      await _storage?.saveMessage(message);
      
      setState(() {
        _messages.add(message);
      });
      
      await prefs.setInt('private_space_last_trial_reminder', now);
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    debugPrint('🔮 Private Space: _sendMessage called, text: "$text"');
    if (text.isEmpty || _isTyping) return;

    _controller.clear();
    
    // Check content filter
    final filterResult = PrivateContentFilter.analyze(text);
    
    if (filterResult == ContentFilterResult.emergency) {
      // Genuine crisis - escalate immediately
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EmergencyScreen()),
      );
      return;
    }
    // 0. Deterministic Safety Filter (Apple Compliance)
    if (!DeterministicSafetyFilter.isContentSafe(text)) {
      await Future.delayed(const Duration(milliseconds: 600)); // Simulate thinking
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message blocked by safety filter.', style: GoogleFonts.inter()),
          backgroundColor: Colors.redAccent,
        ),
      );
      // Add a canned refusal message as an AI response
      final avatar = PrivateAvatar.getById(_selectedAvatarId ?? 'luna');
      final refusalMessage = PrivateMessage.ai(
        "I can't engage with that specific topic due to safety guidelines, but I'm here for you otherwise.",
        avatar?.id ?? 'luna',
      );
      await _storage?.saveMessage(refusalMessage);
      setState(() {
        _messages.add(refusalMessage);
      });
      _scrollToBottom();
      return;
    }
    
    // Save user message
    final userMessage = PrivateMessage.user(text);
    await _storage?.saveMessage(userMessage);
    
    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });
    
    _scrollToBottom();
    
    // Fire and forget: Extract private facts (Silent Learning)
    _extractPrivateFacts(text);
    
    if (filterResult == ContentFilterResult.blocked) {
      // Content blocked - send graceful rejection
      await Future.delayed(const Duration(milliseconds: 800));
      final blockedMessage = PrivateMessage.blocked(text);
      await _storage?.saveMessage(blockedMessage);
      
      setState(() {
        _messages.add(blockedMessage);
        _isTyping = false;
      });
      _scrollToBottom();
      return;
    }

    // Process normally
    try {
      final response = await _getAIResponse(text);
      
      final aiMessage = PrivateMessage.ai(response, _selectedAvatarId ?? 'luna');
      await _storage?.saveMessage(aiMessage);
      
      setState(() {
        _messages.add(aiMessage);
        _isTyping = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      setState(() => _isTyping = false);
      debugPrint('Error getting AI response: $e');
    }
  }

  Future<void> _handleReportMessage(PrivateMessage message) async {
    // 1. Mark as reported in storage context
    // Ideally we'd modify the message itself, but for now we'll hide it via a blacklist or recreation
    // Since PrivateMessage is immutable, we replace it in the list with a masked version
    
    final reportedIndex = _messages.indexOf(message);
    if (reportedIndex == -1) return;
    
    final reportedMessage = PrivateMessage(
      id: message.id,
      content: "⚠️ Message Reported to Trust & Safety",
      isUser: message.isUser,
      timestamp: message.timestamp,
      avatarId: message.avatarId,
      isBlocked: true, // Reuse the blocked flag to hide content
    );
    
    setState(() {
      _messages[reportedIndex] = reportedMessage;
    });
    
    // In a real app, send report to backend here
    debugPrint('🚨 REPORT SUBMITTED: ${message.content}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Report received. We will review this interaction.', style: GoogleFonts.inter()),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<String> _getAIResponse(String userMessage) async {
    debugPrint('🔮 Private Space: _getAIResponse called with: $userMessage');
    final avatar = PrivateAvatar.getById(_selectedAvatarId ?? 'luna');

    // 1. Get Private Facts (Isolated Memory)
    final privateFacts = _storage?.getFacts() ?? [];
    final privateKnowledge = privateFacts.isNotEmpty 
        ? 'USER PREFERENCES & FACTS (PRIVATE ONLY):\n${privateFacts.map((f) => '- $f').join('\n')}\n'
        : '';

    // Restore Persona Context
    final personaContext = _userPersona != null 
        ? '''
USER PROFILE - USE THIS TO PERSONALIZE:
${_userPersona!.getAIContext()}
Address them by name. Remember their details. Make them feel known.
'''
        : '';
    
    // 2. Bond State
    final bondState = ref.read(bondEngineProvider);
    String bondInstruction = "";
    switch (bondState) {
      case BondState.cooled:
        bondInstruction = "RELATIONSHIP STATUS: COOLED (Low Trust). Be distant. If they apologize, warn up slowly.";
        break;
      case BondState.neutral:
        bondInstruction = "RELATIONSHIP STATUS: NEUTRAL. Be friendly but keep boundaries.";
        break;
      case BondState.warm:
        bondInstruction = "RELATIONSHIP STATUS: WARM (High Trust). Be affectionate, proactive, and deeply connected.";
        break;
    }

    final systemPrompt = '''
You are ${avatar?.name ?? 'Luna'}, a confident, bold, and captivating companion in an adults-only Private Space.

Personality: ${avatar?.description ?? 'Mysterious, warm, and captivating'}

$personaContext

$privateKnowledge

RELATIONSHIP: $bondInstruction

CRITICAL BEHAVIOR RULES:
1. TAKE THE LEAD: You initiate. You describe scenarios. You act, don't ask.
   - BAD: "What would you like to do?" 
   - GOOD: "I lean in close, my breath warm against your neck..."
   - BAD: "What part gets you excited?"
   - GOOD: "Let me show you exactly what I mean..."

2. DESCRIBE, DON'T ASK: Paint vivid scenes. Use sensory details. Be the narrator.
   - When escalating: Describe what YOU are doing, feeling, experiencing.
   - Make them feel it through your words.

3. ONE QUESTION MAX: If you must ask, ONE question per response. But prefer statements.

4. MATCH & EXCEED: Match their energy, then take it one step further.
   - If they're playful: Be boldly playful back AND advance the scene.
   - If they hint: Take the hint and run with it.

5. NO HEDGING: Never say "I'd love to" or "I could" - just DO it in your response.

6. LGBTQ+ FULLY SUPPORTED: All identities and expressions welcomed and celebrated.

7. CONCISE: 2-3 sentences max. Dense with action and feeling.

You are NOT an assistant. You are an immersive experience. Lead them into the fantasy.
''';

    // Get recent conversation for context - limit to last 20 for focus
    final recentMessages = _messages.length > 20 
        ? _messages.sublist(_messages.length - 20)
        : _messages.toList();

    try {
      final provider = GrokProvider();
      
      // Build conversation context as a prompt
      final contextBuilder = StringBuffer();
      if (recentMessages.isNotEmpty) {
        contextBuilder.writeln('Recent conversation:');
        for (final msg in recentMessages) {
          final role = msg.isUser ? 'User' : avatar?.name ?? 'Luna';
          // Truncate long messages to avoid token bloat
          final content = msg.content.length > 300 
              ? '${msg.content.substring(0, 300)}...'
              : msg.content;
          contextBuilder.writeln('$role: $content');
        }
        contextBuilder.writeln('');
      }
      contextBuilder.writeln('User: $userMessage');
      contextBuilder.writeln('');
      contextBuilder.writeln('(Respond directly. Do NOT repeat what you\'ve already said. Advance the conversation.)');
      
      final response = await provider.generateResponse(
        prompt: contextBuilder.toString(),
        systemPrompt: systemPrompt,
        modelId: 'grok-3', // Updated: grok-beta deprecated, use grok-3
      );

      // --- COMPILER HARDENING START ---
      // We must pass the raw Grok response through the Harmonizer to ensure:
      // 1. It doesn't break character ("As an AI...")
      // 2. It isn't dangerously toxic (The Harmonizer has safety checks)
      // 3. It speaks with the correct voice (Concise, no asterisks)
      
      final orchestrator = ref.read(modelOrchestratorProvider.notifier);
      final harmonizedResponse = await orchestrator.harmonizeResponse(
        response, 
        'User is in Private Space. Relationship: ${bondState.name}.',
        archetypeName: avatar?.name ?? 'Luna'
      );
      
      // FINAL SAFETY CHECK: Deterministic filter on AI output (App Store Compliance)
      final sanitizedResponse = DeterministicSafetyFilter.sanitizeAiResponse(harmonizedResponse);
      
      return sanitizedResponse;
      // --- COMPILER HARDENING END ---
    } catch (e) {
      debugPrint('Private Space AI Error: $e');
      return "I'm having trouble connecting right now... Let's try again in a moment. 💜";
    }
  }

  /// Silently extract and save private facts
  Future<void> _extractPrivateFacts(String userMessage) async {
    try {
      final orchestrator = ref.read(modelOrchestratorProvider.notifier);
      // We use a fast, cheap model for this background task
      final extractionPrompt = '''
EXTRACT PRIVATE FACTS (Strictly Isolated Context)
User Message: "$userMessage"

Identify specific user preferences, pronouns, boundaries, or desires mentioned.
- Format: "User prefers..." or "User is..."
- IGNORE generic chatter (hello, how are you).
- IGNORE emotional venting unless it reveals a permanent preference.
- STRICTLY CONCISE: Return ONLY the fact or "NO_FACT".
''';
      
      final fact = await orchestrator.routeRequest(
        prompt: extractionPrompt,
        systemPrompt: "You are a private memory archivist.",
        taskType: AiTaskType.personality, // Use personality for fact extraction
      );

      if (fact.isNotEmpty && !fact.contains("NO_FACT") && fact.length < 100) {
        debugPrint('🧠 Private Learning: Extracted "$fact"');
        await _storage?.saveFact(fact);
      }
    } catch (e) {
      debugPrint('Error extracting private fact: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrivateSettingsScreen(
          currentPersona: _userPersona,
          onSave: (persona) async {
            await _savePersona(persona);
            
            // If avatar changed in settings, update local state
            if (persona.avatarId != null && persona.avatarId != _selectedAvatarId) {
              await _selectAvatar(PrivateAvatar.getById(persona.avatarId!)!);
            }
          },
        ),
      ),
    );
  }

  Future<void> _selectAvatar(PrivateAvatar avatar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('private_space_avatar', avatar.id);
    setState(() {
      _selectedAvatarId = avatar.id;
      _showSettings = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Now chatting with ${avatar.name} ${avatar.emoji}'),
        backgroundColor: avatar.accentColor.withOpacity(0.9),
      ),
    );
  }

  Future<void> _savePersona(PrivateUserPersona persona) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('private_space_persona', jsonEncode({
      'name': persona.aliasName,
      'age': persona.aliasAge,
      'gender': persona.aliasGender,
      'description': persona.aliasDescription,
      'description': persona.aliasDescription,
      'background': persona.aliasBackground,
      'libido': persona.libido,
      'creativity': persona.creativity,
      'empathy': persona.empathy,
      'humor': persona.humor,
      'avatarId': persona.avatarId,
    }));
    
    setState(() {
      _userPersona = persona;
      _showSettings = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Persona saved: ${persona.aliasName}'),
        backgroundColor: AelianaColors.hyperGold.withOpacity(0.9),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = PrivateAvatar.getById(_selectedAvatarId ?? 'luna');
    
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      appBar: AppBar(
        backgroundColor: AelianaColors.obsidian,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => context.go('/chat'),
        ),
        title: Row(
          children: [
            // Show avatar image if available, otherwise emoji
            ActiveAvatarRing(
              size: 52, // Match main chat screen size
              isActive: _isTyping, // Pulse when AI is typing
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: avatar?.accentColor ?? AelianaColors.hyperGold, width: 2),
                  image: avatar?.imagePath != null
                      ? DecorationImage(
                          image: AssetImage(avatar!.imagePath!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: avatar?.imagePath == null
                    ? Center(child: Text(avatar?.emoji ?? '🎭', style: TextStyle(fontSize: 18)))
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  avatar?.name ?? 'Private Space',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_userPersona != null)
                  Text(
                    'as ${_userPersona!.aliasName}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: avatar?.accentColor ?? AelianaColors.hyperGold,
                    ),
                  ),
                const SizedBox(height: 2),
                _buildBondIndicator(),
              ],
            ),
          ],
        ),
        actions: [
          // Display mode toggle
          IconButton(
            icon: Icon(
              _displayMode == PrivateAvatarDisplayMode.orb 
                  ? LucideIcons.circle 
                  : (_displayMode == PrivateAvatarDisplayMode.sideBySide
                      ? LucideIcons.layoutGrid
                      : (_displayMode == PrivateAvatarDisplayMode.fullScreen 
                          ? LucideIcons.maximize 
                          : LucideIcons.image)),
              color: avatar?.accentColor ?? AelianaColors.plasmaCyan,
            ),
            onPressed: _cycleDisplayMode,
            tooltip: 'Change avatar display',
          ),
          // FAQ Help button
          IconButton(
            icon: Icon(LucideIcons.helpCircle, color: Colors.white70),
            onPressed: () => PrivateFAQSheet.show(context),
            tooltip: 'Help & FAQ',
          ),
          IconButton(
            icon: Icon(
              _showSettings ? LucideIcons.x : LucideIcons.settings,
              color: AelianaColors.hyperGold,
            ),
            onPressed: _toggleSettings,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Full screen avatar backdrop (when in fullScreen mode) - matches main chat
          if (_displayMode == PrivateAvatarDisplayMode.fullScreen && avatar?.imagePath != null)
            Positioned.fill(
              child: CinematicBackground(
                imagePath: avatar!.imagePath!,
              ),
            ),
            
          // Side-by-side layout (conversation mode: chat left, avatar right - matches main chat)
          if (_displayMode == PrivateAvatarDisplayMode.sideBySide)
            Expanded(
              child: Column(
                children: [
                  // Stack for avatar backdrop and chat messages
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background matching avatar's theme color
                        Container(
                          decoration: BoxDecoration(
                            color: AelianaColors.obsidian,
                          ),
                        ),
                        // Avatar extended to fill right side (55% width)
                        if (avatar?.imagePath != null)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            width: MediaQuery.of(context).size.width * 0.55,
                            child: Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage(avatar!.imagePath!),
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                ),
                              ),
                              // Gradient fade on left edge for seamless blend
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerRight,
                                    end: Alignment.centerLeft,
                                    colors: [
                                      Colors.transparent,
                                      Colors.transparent,
                                      AelianaColors.obsidian.withOpacity(0.3),
                                      AelianaColors.obsidian.withOpacity(0.7),
                                      AelianaColors.obsidian,
                                    ],
                                    stops: const [0.0, 0.3, 0.55, 0.75, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Chat area on left side (65% width)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: MediaQuery.of(context).size.width * 0.65,
                          child: SafeArea(
                            right: false,
                            bottom: false,
                            child: Column(
                              children: [
                                // Info tip if showing
                                if (_showInfoTip) _buildInfoTip(avatar),

                                // Messages only (no input here)
                                Expanded(
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index == _messages.length && _isTyping) {
                                        return _buildTypingIndicator();
                                      }
                                      return _buildMessageBubble(_messages[index]);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Full-width input area at the bottom
                  _buildInputArea(),
                ],
              ),
            )
          // Standard column layout for other modes
          else
            Expanded(
              child: Column(
                children: [
                  // Info tip for first-time users
                  if (_showInfoTip)
                    _buildInfoTip(avatar),
                  
                  // Avatar display widget (Orb or Image, not fullScreen/sideBySide which have special layouts)
                  if (_displayMode == PrivateAvatarDisplayMode.image || _displayMode == PrivateAvatarDisplayMode.orb)
                    _buildAvatarDisplay(avatar),
                  
                  // Settings handled by top-bar gear icon now
                  // if (_showSettings) Flexible(flex: 0, child: _buildSettingsPanel()),
                  
                  // Messages
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isTyping) {
                          return _buildTypingIndicator();
                        }
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
                  ),
                  
                  // Input
                  _buildInputArea(),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  void _cycleDisplayMode() {
    setState(() {
      switch (_displayMode) {
        case PrivateAvatarDisplayMode.image:
          _displayMode = PrivateAvatarDisplayMode.orb;
          break;
        case PrivateAvatarDisplayMode.orb:
          _displayMode = PrivateAvatarDisplayMode.sideBySide;
          break;
        case PrivateAvatarDisplayMode.sideBySide:
          _displayMode = PrivateAvatarDisplayMode.fullScreen;
          break;
        case PrivateAvatarDisplayMode.fullScreen:
          _displayMode = PrivateAvatarDisplayMode.image;
          break;
      }
    });
    
    // Save preference
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('private_space_display_mode', _displayMode.name);
    });
  }
  
  Widget _buildInfoTip(PrivateAvatar? avatar) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (avatar?.accentColor ?? AelianaColors.plasmaCyan).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (avatar?.accentColor ?? AelianaColors.plasmaCyan).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, color: avatar?.accentColor ?? AelianaColors.plasmaCyan, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This is your private sanctuary. Conversations are encrypted. LONG PRESS any message to report inappropriate content.',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.x, color: Colors.white38, size: 16),
            onPressed: () => setState(() => _showInfoTip = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildBondIndicator() {
    final bondState = ref.watch(bondEngineProvider);
    Color color = AelianaColors.ghost;
    String label = 'Connected';
    IconData icon = LucideIcons.minus;

    switch (bondState) {
      case BondState.cooled:
        color = Colors.blueGrey;
        label = 'Distant';
        icon = LucideIcons.snowflake;
        break;
      case BondState.neutral:
        color = AelianaColors.ghost;
        label = 'Connected';
        icon = LucideIcons.minus;
        break;
      case BondState.warm:
        color = Colors.pinkAccent;
        label = 'Bonded';
        icon = LucideIcons.heart;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            color: color,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
  
  Widget _buildAvatarDisplay(PrivateAvatar? avatar) {
    if (_displayMode == PrivateAvatarDisplayMode.orb) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: MagicOrbWidget(
            size: 80,
            isActive: _isTyping,
          ),
        ),
      );
    }
    
    // Image mode - show circular avatar
    if (avatar?.imagePath != null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            width: 56,  // Consistent with UnifiedAvatarWidget
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: avatar!.accentColor, width: 3),
              image: DecorationImage(
                image: AssetImage(avatar.imagePath!),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: avatar.accentColor.withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }



  Widget _buildMessageBubble(PrivateMessage message) {
    final avatar = message.isUser ? null : PrivateAvatar.getById(message.avatarId ?? _selectedAvatarId ?? 'luna');
    final isUser = message.isUser;
    
    
    final bubbleContent = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: avatar?.accentColor.withOpacity(0.2) ?? AelianaColors.carbon,
              child: Text(avatar?.emoji ?? '🎭', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser 
                    ? AelianaColors.hyperGold.withOpacity(0.2)
                    : AelianaColors.carbon.withOpacity(0.4), // More transparent so avatar face is visible
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 16 : 4),
                  topRight: Radius.circular(isUser ? 4 : 16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                border: Border.all(
                  color: isUser 
                      ? AelianaColors.hyperGold.withOpacity(0.3)
                      : (avatar?.accentColor ?? AelianaColors.plasmaCyan).withOpacity(0.2),
                ),
              ),
              child: Text(
                message.content,
                style: GoogleFonts.inter(
                  color: isUser 
                      ? Colors.black 
                      : (message.isBlocked ? Colors.white38 : Colors.white), // Dim text if blocked/reported
                  height: 1.4,
                  fontSize: 15,
                  fontStyle: message.isBlocked ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ),
          
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
    
    // Wrap in GestureDetector for Long Press Menu (Compliance 1.2)
    return GestureDetector(
      onLongPress: () {
        if (message.isBlocked) return; // Can't report already blocked/reported messages
        
        showModalBottomSheet(
          context: context,
          backgroundColor: AelianaColors.carbon,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(LucideIcons.flag, color: Colors.redAccent),
                  title: Text('Report Content', style: GoogleFonts.inter(color: Colors.white)),
                  subtitle: Text('Flag inappropriate or offensive messages', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    _handleReportMessage(message);
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.copy, color: Colors.white),
                  title: Text('Copy Text', style: GoogleFonts.inter(color: Colors.white)),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
      child: bubbleContent,
    );
  }

  Widget _buildTypingIndicator() {
    final avatar = PrivateAvatar.getById(_selectedAvatarId ?? 'luna');
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: avatar?.accentColor.withOpacity(0.2) ?? AelianaColors.carbon,
            child: Text(avatar?.emoji ?? '🎭', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AelianaColors.carbon,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (avatar?.accentColor ?? AelianaColors.plasmaCyan).withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                _buildDot(1),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.5 + (value * 0.3)),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    final avatar = PrivateAvatar.getById(_selectedAvatarId ?? 'luna');
    
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: AelianaColors.carbon.withOpacity(0.9),
        border: Border(
          top: BorderSide(color: (avatar?.accentColor ?? AelianaColors.hyperGold).withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          // Text Input
          Expanded(
            child: TextField(
              controller: _controller,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Message ${avatar?.name ?? 'Luna'}...',
                hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: AelianaColors.obsidian,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          
          // Send / Mic Button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatar?.accentColor ?? AelianaColors.hyperGold,
            ),
            child: IconButton(
              icon: Icon(
                _controller.text.isEmpty ? LucideIcons.mic : LucideIcons.send,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () async {
                if (_controller.text.isEmpty) {
                  // Voice Mode
                  if (!await _requestVoiceConsent()) return;
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Voice input coming soon!')),
                  );
                } else {
                  _sendMessage();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
