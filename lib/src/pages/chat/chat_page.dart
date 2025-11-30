import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/ai/model_orchestrator.dart';
import 'package:sable/core/theme/aureal_theme.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
import 'package:sable/features/settings/screens/settings_screen.dart';
import 'package:sable/core/emotion/emotional_state_service.dart';
import 'package:sable/core/emotion/sentiment_analyzer.dart';
import 'package:sable/core/emotion/environment_context.dart';
import 'package:sable/core/emotion/conversation_memory_service.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  OnboardingStateService? _stateService;
  EmotionalStateService? _emotionalService;
  ConversationMemoryService? _memoryService;
  
  bool _isTyping = false;
  String? _avatarUrl;
  
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    _stateService = await OnboardingStateService.create();
    _emotionalService = await EmotionalStateService.create();
    _memoryService = await ConversationMemoryService.create();
    
    if (mounted) {
      setState(() {
        _avatarUrl = _stateService?.avatarUrl;
      });
      
      // Load message history from persistent storage
      final storedMessages = _memoryService!.getAllMessages();
      if (storedMessages.isNotEmpty) {
        setState(() {
          _messages.addAll(storedMessages.map((msg) => {
            'message': msg.message,
            'isUser': msg.isUser,
          }));
        });
      }
      
      // Send initial AI greeting if this is the first time entering chat
      if (_messages.isEmpty && _stateService != null) {
        await _sendInitialGreeting();
      }
    }
  }

  Future<void> _sendInitialGreeting() async {
    if (_stateService == null) return;
    
    final name = _stateService!.userName;
    final location = _stateService!.userLocation;
    final dob = _stateService!.userDob;
    
    if (name != null || location != null) {
      setState(() {
        _isTyping = true;
      });
      
      try {
        // Build personalized greeting prompt
        String greetingPrompt = 'Generate a warm, personalized greeting for the user. ';
        if (name != null) greetingPrompt += 'Their name is $name. ';
        if (location != null) greetingPrompt += 'They are in $location. ';
        if (dob != null) {
          final zodiac = _getZodiacSign(dob);
          greetingPrompt += 'Their zodiac sign is $zodiac. ';
        }
        greetingPrompt += 'Mention the current date (${DateTime.now().toString().split(' ')[0]}) and express excitement to get to know them better. Keep it natural, friendly, and conversational (2-3 sentences max).';
        
        final orchestrator = ref.read(modelOrchestratorProvider.notifier);
        final greeting = await orchestrator.orchestratedRequest(
          prompt: greetingPrompt,
          userContext: 'This is your first message to the user.',
        );
        
        if (mounted) {
          setState(() {
            _messages.add({'message': greeting, 'isUser': false});
            _isTyping = false;
          });
          _scrollToBottom();
        }
      } catch (e) {
        debugPrint('Error generating initial greeting: $e');
        if (mounted) {
          setState(() {
            _isTyping = false;
          });
        }
      }
    }
  }

  String _getZodiacSign(DateTime date) {
    final day = date.day;
    final month = date.month;
    
    if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) return 'Aquarius';
    if ((month == 2 && day >= 19) || (month == 3 && day <= 20)) return 'Pisces';
    if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) return 'Aries';
    if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) return 'Taurus';
    if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) return 'Gemini';
    if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) return 'Cancer';
    if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) return 'Leo';
    if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) return 'Virgo';
    if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) return 'Libra';
    if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) return 'Scorpio';
    if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) return 'Sagittarius';
    return 'Capricorn';
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Save user message to persistent memory
    await _memoryService?.addMessage(message: text, isUser: true);
    
    setState(() {
      _messages.add({'message': text, 'isUser': true});
      _isTyping = true;
      _controller.clear();
    });
    _scrollToBottom();

    // Analyze sentiment of user message
    final sentiment = SentimentAnalyzer.analyze(text);
    debugPrint('Sentiment: ${sentiment.polarity}, Mistreatment: ${sentiment.isMistreatment}, Positive: ${sentiment.isPositive}');


    try {
      // Build comprehensive user context string
      String? userContext;
      if (_stateService != null) {
        final name = _stateService!.userName;
        final dob = _stateService!.userDob;
        final location = _stateService!.userLocation;
        final gender = _stateService!.userGender;
        
        if (name != null || location != null || dob != null) {
          // Format context prominently
          userContext = '\n\n[USER PROFILE]\n';
          if (name != null) userContext += 'Name: $name\n';
          if (dob != null) {
            final age = DateTime.now().difference(dob).inDays ~/ 365;
            final zodiac = _getZodiacSign(dob);
            userContext += 'Date of Birth: ${dob.toIso8601String().split('T')[0]} (Age: $age, Zodiac: $zodiac)\n';
          }
          if (location != null) userContext += 'Location: $location\n';
          if (gender != null) userContext += 'Gender: $gender\n';
          userContext += 'Current Date: ${DateTime.now().toIso8601String().split('T')[0]}\n';
          userContext += '[END PROFILE]\n';
          
          // Add conversation history (last 20 messages) from persistent storage
          if (_memoryService != null) {
            userContext += '\n';
            userContext += _memoryService!.getConversationContext(messageCount: 20);
          }
          
          // Add emotional state context
          if (_emotionalService != null) {
            userContext += '\n';
            userContext += _emotionalService!.getEmotionalContext();
          }
          
          // Add environmental context
          userContext += '\n[ENVIRONMENT]\n';
          userContext += await EnvironmentContext.getTimeContext(location: location);
          userContext += '\n[END ENVIRONMENT]\n';
          
          // Add companion's origin for accent/personality
          userContext += '\n[YOUR IDENTITY]\nOrigin: ${_avatarUrl != null ? "Neo-Kyoto, Sector 7" : "Unknown"}\n';
          
          debugPrint('Formatted context:\n$userContext');
        } else {
          debugPrint('WARNING: No user data found in OnboardingStateService!');
        }
      } else {
        debugPrint('ERROR: _stateService is null!');
      }

      // Use orchestrated routing - Gemini decides Claude vs GPT-4o
      final orchestrator = ref.read(modelOrchestratorProvider.notifier);
      final response = await orchestrator.orchestratedRequest(
        prompt: text,
        userContext: userContext,
      );

      if (mounted) {
        // Save AI response to persistent memory
        await _memoryService?.addMessage(message: response, isUser: false);
        
        setState(() {
          _messages.add({
            'message': response,
            'isUser': false,
          });
          _isTyping = false;
        });
        _scrollToBottom();
        
        // Update emotional state based on interaction
        if (_emotionalService != null) {
          final location = _stateService?.userLocation;
          final environmentMod = await EnvironmentContext.getMoodModifier(location: location);
          await _emotionalService!.updateMood(
            sentimentScore: sentiment.polarity,
            environmentalModifier: environmentMod,
            isMistreatment: sentiment.isMistreatment,
            isPositive: sentiment.isPositive,
          );
          
          // Update energy based on time of day
          final energyMod = EnvironmentContext.getEnergyModifier();
          await _emotionalService!.updateEnergy(energyMod);
          
          debugPrint('Updated mood: ${_emotionalService!.mood}, relationship: ${_emotionalService!.userRelationship}');
        }
      }
    } catch (e) {
      debugPrint('Chat Error: $e'); // Added debug print
      if (mounted) {
        setState(() {
          _messages.add({
            'message': "I'm having trouble connecting right now. Please try again. ($e)", // Show error for debugging
            'isUser': false
          });
          _isTyping = false;
        });
        _scrollToBottom();
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image
          if (_avatarUrl != null && _avatarUrl!.startsWith('http'))
            Image.network(
              _avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildDefaultBackground(),
            )
          else if (_avatarUrl != null && _avatarUrl!.startsWith('assets'))
            Image.asset(
              _avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildDefaultBackground(),
            )
          else
            _buildDefaultBackground(),

          // 2. Gradient Overlay (for readability)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.9),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // 3. Content
          SafeArea(
            top: false, // Disable top SafeArea to handle it manually with padding
            child: Column(
              children: [
                const SizedBox(height: 60), // Added manual spacing for header
                _buildHeader(),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(
                        msg['message'] as String,
                        msg['isUser'] as bool,
                      );
                    },
                  ),
                ),
                if (_isTyping)
                  Padding(
                    padding: const EdgeInsets.only(left: 24, bottom: 8),
                    child: Text(
                      'Sable is thinking...',
                      style: GoogleFonts.inter(
                        color: AurealColors.ghost,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                _buildFloatingChips(),
                const SizedBox(height: 8),
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultBackground() {
    return Image.asset(
      'assets/images/archetypes/sable.png', // Fallback
      fit: BoxFit.cover,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(LucideIcons.brainCircuit, color: Colors.white), // Brain icon
            onPressed: () {},
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          Row(
            children: [
              const Icon(LucideIcons.triangle, color: AurealColors.hyperGold, size: 16),
              const SizedBox(width: 8),
              Text(
                'AUREAL',
                style: GoogleFonts.spaceGrotesk(
                  color: AurealColors.hyperGold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.share2, color: Colors.white),
                onPressed: () {},
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.settings, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildGlassChip(LucideIcons.sun, 'Daily Update'),
          const SizedBox(width: 12),
          _buildGlassChip(LucideIcons.book, 'Journal'),
          const SizedBox(width: 12),
          _buildGlassChip(LucideIcons.activity, 'Vital Balance'),
        ],
      ),
    );
  }

  Widget _buildGlassChip(IconData icon, String label) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String message, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: const BoxConstraints(maxWidth: 300),
        padding: isUser ? const EdgeInsets.all(12) : null,
        decoration: isUser 
            ? BoxDecoration(
                color: AurealColors.carbon.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16).copyWith(bottomRight: Radius.zero),
                border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
              )
            : null,
        child: isUser 
            ? Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white, // Changed from ghost to white
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.left,
              )
            : Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.3)),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: const Icon(LucideIcons.sparkles, color: AurealColors.plasmaCyan, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
