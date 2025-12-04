import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/ai/model_orchestrator.dart';
import 'package:sable/core/widgets/cinematic_background.dart';
import 'package:sable/core/theme/aureal_theme.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
import 'package:sable/features/settings/screens/settings_screen.dart';
import 'package:sable/core/emotion/emotional_state_service.dart';
import 'package:sable/core/emotion/sentiment_analyzer.dart';
import 'package:sable/core/emotion/environment_context.dart';
import 'package:sable/core/emotion/location_service.dart';
import 'package:sable/src/config/app_config.dart';
import 'package:sable/core/emotion/conversation_memory_service.dart';
import 'package:sable/core/voice/voice_service.dart';
import 'package:sable/features/web/services/web_search_service.dart';
// Native app services
import 'package:sable/core/calendar/calendar_service.dart';
import 'package:sable/core/contacts/contacts_service.dart';
import 'package:sable/core/photos/photos_service.dart';
import 'package:sable/core/reminders/reminders_service.dart';
import 'package:sable/core/memory/structured_memory_service.dart';
import 'package:sable/core/ai/apple_intelligence_service.dart';

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
  String? _currentGpsLocation; // Real-time GPS location
  ConversationMemoryService? _memoryService;
  StructuredMemoryService? _structuredMemoryService;
  VoiceService? _voiceService;
  
  bool _isTyping = false;
  bool _isListening = false;
  String? _avatarUrl;
  String? _dailyUpdateContext; // Holds news context for injection
  
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
    _structuredMemoryService = StructuredMemoryService();
    await _structuredMemoryService?.initialize();
    _voiceService = VoiceService();
    await _voiceService?.initialize();
    
    if (mounted) {
      setState(() {
        _avatarUrl = _stateService?.avatarUrl;
      });
      
    // Load message history from persistent storage
      final storedMessages = _memoryService!.getAllMessages();
      debugPrint('📂 Stored messages count: ${storedMessages.length}');
      
      if (storedMessages.isNotEmpty) {
        setState(() {
          _messages.addAll(storedMessages.map((msg) => {
            'message': msg.isUser ? msg.message : _sanitizeResponse(msg.message), // Sanitize AI messages
            'isUser': msg.isUser,
          }));
        });
      }
      
      // Fetch current GPS location
      await _fetchCurrentLocation();
      
      // Send initial AI greeting if this is the first time entering chat
      if (_messages.isEmpty && _stateService != null) {
        await _sendInitialGreeting();
      }
    }
  }

  /// Sanitize AI response to remove narrative actions and unwanted patterns
  String _sanitizeResponse(String response) {
    return response
        .replaceAll(RegExp(r'\*\s*[^*]+\s*\*'), '') // Main pattern
        .replaceAll(RegExp(r'\*[^*]*\*'), '') // Catch anything with asterisks
        .replaceAll('*', '') // Remove stray asterisks
        .replaceAll(RegExp(r'\s+'), ' ') // Remove multiple spaces
        .trim();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final apiKey = AppConfig.googleMapsApiKey;
      if (apiKey.isNotEmpty) {
        final locationName = await LocationService.getCurrentLocationName(apiKey);
        if (locationName != null) {
          setState(() {
            _currentGpsLocation = locationName;
          });
          debugPrint('GPS Location: $locationName');
          debugPrint('Manual Location: ${_stateService?.userCurrentLocation}');
        }
      }
    } catch (e) {
      debugPrint('Error fetching GPS location: $e');
    }
  }

  Future<void> _sendInitialGreeting() async {
    debugPrint('👋 _sendInitialGreeting called');
    if (_stateService == null) {
      debugPrint('❌ _stateService is null');
      return;
    }
    
    final name = _stateService!.userName;
    // Prioritize manual location setting over GPS
    final location = _stateService!.userCurrentLocation ?? _currentGpsLocation ?? _stateService!.userLocation;
    final dob = _stateService!.userDob;
    
    debugPrint('👤 User: $name, Location: $location');
    
    if (name != null || location != null) {
      setState(() {
        _isTyping = true;
      });
      
      try {
        // Build FULL user context (same as regular messages)
        String userContext = '\n\n[USER PROFILE]\n';
        if (name != null) userContext += 'Name: $name\n';
        if (dob != null) {
          final age = DateTime.now().difference(dob).inDays ~/ 365;
          final zodiac = _getZodiacSign(dob);
          final birthplace = _stateService!.userLocation;
          userContext += 'Date of Birth: ${dob.toIso8601String().split('T')[0]}\n';
          userContext += 'Age: $age\n';
          userContext += 'Zodiac Sign: $zodiac\n';
          if (birthplace != null) userContext += 'Birthplace: $birthplace\n';
        }
        if (location != null) userContext += 'Current Location: $location\n';
        
        // Add AI origin if available
        final aiOrigin = _stateService!.aiOrigin;
        if (aiOrigin != null) {
          userContext += '\n[AI BACKSTORY]\n';
          userContext += 'Your Origin: $aiOrigin\n';
          userContext += 'Remember: You were designed with this origin. It shapes your perspective.\n';
          userContext += '[END AI BACKSTORY]\n';
        }
        
        userContext += '[END PROFILE]\n\n';
        
        // Add environmental context (weather + time)
        userContext += '[ENVIRONMENT]\n';
        userContext += await EnvironmentContext.getTimeContext(location: location);
        userContext += '\n[END ENVIRONMENT]\n';
        
        // Build personalized greeting prompt
        String greetingPrompt = 'This is your FIRST message to ${name ?? "them"}. ';
        greetingPrompt += 'You are Sable - their companion, assistant, organizer, and coach.\n';
        greetingPrompt += 'Your goal: Build a BOND and become indispensable by helping manage their life.\n\n';
        greetingPrompt += 'Requirements:\n';
        greetingPrompt += '- 1-2 sentences TOTAL (not introduction then question - ONE brief greeting)\n';
        greetingPrompt += '- Say their name: "${name ?? "friend"}"\n';
        if (location != null) {
          greetingPrompt += '- Note you\'re both connected despite distance\n';
        }
        greetingPrompt += '- Focus on how you\'ll help organize their world\n';
        greetingPrompt += '- Natural text message style\n';
        greetingPrompt += '- NO asterisks or narrative actions\n';
        greetingPrompt += '- Example: "Hey Andy! Ready to help you get organized and stay on top of everything. What\'s first?"';
        
        final orchestrator = ref.read(modelOrchestratorProvider.notifier);
        final greeting = await orchestrator.orchestratedRequest(
          prompt: greetingPrompt,
          userContext: userContext,
        );
        
        if (mounted) {
          setState(() {
            _messages.add({'message': _sanitizeResponse(greeting), 'isUser': false});
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
        // Prioritize manual location setting over GPS
        final location = _stateService!.userCurrentLocation ?? _currentGpsLocation ?? _stateService!.userLocation;
        final gender = _stateService!.userGender;
        
        if (name != null || location != null || dob != null) {
          // Format context prominently
          userContext = '\n\n[USER PROFILE]\n';
          if (name != null) userContext += 'Name: $name\n';
          if (dob != null) {
            final age = DateTime.now().difference(dob).inDays ~/ 365;
            final zodiac = _getZodiacSign(dob);
            final birthplace = _stateService!.userLocation; // Birth location
            userContext += 'Date of Birth: ${dob.toIso8601String().split('T')[0]}\n';
            userContext += 'Age: $age years old\n';
            userContext += 'Zodiac Sign: $zodiac\n';
            if (birthplace != null) userContext += 'Birthplace: $birthplace\n';
          }
          if (location != null) userContext += 'Current Location: $location\n';
          if (gender != null) userContext += 'Gender: $gender\n';
          userContext += 'Current Date: ${DateTime.now().toIso8601String().split('T')[0]}\n';
          
          // Add AI origin/backstory
          final aiOrigin = _stateService!.aiOrigin;
          if (aiOrigin != null) {
            userContext += '\n[YOUR BACKSTORY]\n';
            userContext += 'Your Origin: $aiOrigin\n';
            userContext += '(This is where you\'re from. Don\'t explicitly state it unless asked, but it influences your perspective and accent.)\n';
            userContext += '[END BACKSTORY]\n';
          }
          
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
          
          // Add environmental context (weather-aware if location available)
          userContext += '\n[ENVIRONMENT]\n';
          userContext += await EnvironmentContext.getTimeContext(location: location);
          userContext += '\n[END ENVIRONMENT]\n';
          
          // Add structured persistent memory
          if (_structuredMemoryService != null) {
            final memoryContext = _structuredMemoryService!.getMemoryContext();
            if (memoryContext.isNotEmpty) {
              userContext += '\n$memoryContext\n';
            }
          }
          
          // Add native app integrations (only if permission granted)
          try {
            // Calendar
            if (await CalendarService.hasPermission()) {
              userContext += '\n';
              userContext += await CalendarService.getCalendarSummary();
            }
            
            // Contacts
            if (await ContactsService.hasPermission()) {
              userContext += '\n';
              userContext += await ContactsService.getRecentContactsSummary();
            }
            
            // Photos
            if (await PhotosService.hasPermission()) {
              userContext += '\n';
              userContext += await PhotosService.getPhotosSummary();
            }
            
            // Reminders
            if (await RemindersService.hasPermission()) {
              userContext += '\n';
              userContext += await RemindersService.getRemindersSummary();
            }
          } catch (e) {
            debugPrint('⚠️ Error loading native app context: $e');
          }
          
          // Add conversation count for first-time feature introductions
          final conversationCount = _stateService!.conversationCount;
          if (conversationCount < 10) {
            userContext = (userContext ?? '') + '\n[ONBOARDING MODE]\n';
            userContext += 'Conversation #$conversationCount of first 10.\n\n';
            userContext += 'YOUR MISSION: Naturally showcase ONE capability per message.\n';
            userContext += 'Weave it into conversation - don\'t list features!\n\n';
            userContext += 'YOUR CAPABILITIES:\n';
            userContext += '- Organize their entire digital world in one place\n';
            userContext += '- Daily news and world events updates\n';
            userContext += '- Research and reference assistance\n';
            userContext += '- Journaling and reflection\n';
            userContext += '- Schedule management and reminders (ask about upcoming events!)\n';
            userContext += '- Note taking with persistent memory (mention this!)\n';
            userContext += '- Contact management and updates\n';
            userContext += '- Restaurant recommendations\n';
            userContext += '- Directions and navigation\n';
            userContext += '- Weather updates and forecasts\n';
            userContext += '- And much more!\n\n';
            userContext += 'APPROACH: Pick ONE relevant capability. Mention it naturally.\n';
            userContext += 'Examples:\n';
            userContext += '- "btw, if you ever need restaurant recs, I got you - I can pull up spots near you"\n';
            userContext += '- "got any events coming up I should know about? can add them to your calendar"\n';
            userContext += '- "I remember everything we talk about btw - so if you need me to take notes, just say so"\n';
            userContext += 'NOT: "I can help with X, Y, Z..." (too salesy)\n';
            
            // Check if we should set up daily news (conversations 3-5)
            if (conversationCount >= 3 && conversationCount <= 5 && !_stateService!.hasSetNewsCategories) {
              userContext += '\n\nSPECIAL OBJECTIVE THIS CONVERSATION:\n';
              userContext += 'Casually ask if they want daily news updates.\n';
              userContext += 'Examples:\n';
              userContext += '- "btw, want me to keep you updated on stuff? tech, local news, sports—whatever."\n';
              userContext += '- "I can hit you with a daily update on world events if you\'re into that"\n';
              userContext += 'Keep it casual. Don\'t make it a formal setup. Just offer it naturally.\n';
            }
            
            userContext += '[END ONBOARDING MODE]\n';
          }
        }
        
        // Inject daily update context if present
        if (_dailyUpdateContext != null) {
          userContext = (userContext ?? '') + '\n' + _dailyUpdateContext!;
          _dailyUpdateContext = null; // Clear after use
        }
        
        debugPrint('Formatted context:\n$userContext');
          // Check if this is first interaction today (for daily greeting)
          final isFirstToday = await _stateService!.isFirstInteractionToday();
          if (isFirstToday && _stateService!.newsEnabled) {
            userContext = (userContext ?? '') + '\n[DAILY GREETING MODE]\n';
            
            // Fetch real news
            try {
              final webService = ref.read(webSearchServiceProvider);
              final categories = _stateService!.newsCategories;
              final newsBrief = await webService.getDailyBriefing(categories);
              
              userContext = (userContext ?? '') + '[REAL-TIME NEWS BRIEF]\n$newsBrief\n[END NEWS BRIEF]\n\n';
            } catch (e) {
              debugPrint('⚠️ Failed to fetch daily news: $e');
            }

            userContext = (userContext ?? '') + 'This is the FIRST interaction today.\n';
            userContext = (userContext ?? '') + 'Start with: "Good morning/afternoon ${name ?? "them"}" (use correct time of day)\n\n';
            userContext = (userContext ?? '') + 'Then add ONE of these hooks (VARY IT, don\'t repeat):\n';
            userContext += '- "Did you hear about [pick a headline from NEWS BRIEF]?"\n';
            userContext += '- "Want your daily update?"\n';
            userContext += '- "Crazy thing happened in [location/topic] last night"\n';
            userContext += '- "[Hook about relevant news topic they care about]"\n\n';
            userContext += 'Sable vibe: casual, direct, slightly edgy. NOT formal or robotic.\n';
            userContext += 'Example: "Morning, ${name ?? "Andy"}. Did you see what went down overnight?"\n';
            userContext += '[END DAILY GREETING MODE]\n';
            
            // Mark interaction as done
            await _stateService!.updateLastInteractionDate();
          }
          
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
        // Sanitize the response ONCE for both display and speech
        final sanitizedResponse = _sanitizeResponse(response);
        
        // Save AI response to persistent memory
        await _memoryService?.addMessage(message: sanitizedResponse, isUser: false);
        
        // Increment conversation count for feature onboarding
        await _stateService?.incrementConversationCount();
        
        setState(() {
          _messages.add({
            'message': sanitizedResponse,
            'isUser': false,
          });
          _isTyping = false;
        });
        _scrollToBottom();
        
        // Auto-speak AI response if enabled (using sanitized text)
        final autoSpeak = await _voiceService?.getAutoSpeakEnabled() ?? true;
        if (autoSpeak && _voiceService != null) {
          await _voiceService!.speak(sanitizedResponse);
        }
        
        // Update emotional state based on interaction
        if (_emotionalService != null) {
          final location = _stateService?.userCurrentLocation ?? _stateService?.userLocation;
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

  /// Handle voice input
  Future<void> _handleRewrite() async {
    final text = _controller.text;
    if (text.isEmpty) return;

    // Check availability first
    final isAvailable = await AppleIntelligenceService.isAvailable();
    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Apple Intelligence requires iOS 18+'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show loading indicator or feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rewriting with Apple Intelligence...'),
          duration: Duration(seconds: 1),
          backgroundColor: AurealColors.plasmaCyan,
        ),
      );
    }

    // Call native rewrite
    final rewritten = await AppleIntelligenceService.rewrite(text);
    if (rewritten != null && mounted) {
      setState(() {
        _controller.text = rewritten;
        // Move cursor to end
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: rewritten.length),
        );
      });
    }
  }

  Future<void> _handleVoiceInput() async {
    if (_voiceService == null) return;

    if (_isListening) {
      // Stop listening
      await _voiceService!.stopListening();
      setState(() {
        _isListening = false;
      });
    } else {
      // Start listening
      setState(() {
        _isListening = true;
      });

      await _voiceService!.startListening(
        onResult: (text) {
          setState(() {
            _controller.text = text;
            _isListening = false;
          });
          // Auto-send after voice input
          _sendMessage();
        },
        onPartialResult: (text) {
          setState(() {
            _controller.text = text;
          });
        },
      );
    }
  }

  Future<void> _handleDailyUpdate() async {
    setState(() => _isTyping = true);
    
    try {
      // 1. Fetch News
      final webService = ref.read(webSearchServiceProvider);
      final categories = _stateService!.newsCategories;
      
      // Check cache first
      String? newsBrief = _stateService!.getDailyNewsContent();
      if (newsBrief == null) {
        debugPrint('🌍 Fetching fresh daily news...');
        newsBrief = await webService.getDailyBriefing(categories);
        await _stateService!.saveDailyNewsContent(newsBrief);
      } else {
        debugPrint('💾 Using cached daily news');
      }
      
      // 2. Build context for AI (will be injected by _sendMessage)
      _dailyUpdateContext = '[DAILY NEWS UPDATE]\n';
      _dailyUpdateContext! += 'NEWS DATA:\n$newsBrief\n\n';
      _dailyUpdateContext! += 'INSTRUCTIONS:\n';
      _dailyUpdateContext! += '- Provide CONCISE bullet-point summaries (1-2 sentences each)\n';
      _dailyUpdateContext! += '- Format: • [Category] Headline - brief summary\n';
      _dailyUpdateContext! += '- Cover World, National, Local (SF), and: ${categories.join(", ")}\n';
      _dailyUpdateContext! += '- Keep casual "Sable" style\n';
      _dailyUpdateContext! += '- End by asking if they want to EXPAND on any story or SEARCH for other topics\n';
      _dailyUpdateContext! += '[END DAILY NEWS UPDATE]\n';
      
      // 3. Send clean message (context will be injected automatically)
      setState(() {
        _controller.text = "Give me my daily update";
        _isTyping = false;
      });
      
      // Send via the normal message flow
      await _sendMessage();
      
    } catch (e) {
      debugPrint('Error in daily update: $e');
      setState(() => _isTyping = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get daily update: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ ChatPage.build called');
    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true, // Explicitly handle keyboard
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image
          // 1. CINEMATIC BACKGROUND (Breathing + Parallax)
          CinematicBackground(
            imagePath: _avatarUrl ?? 'assets/images/archetypes/sable.png',
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
                'SABLE',
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
              // Voice toggle button
              FutureBuilder<bool>(
                future: _voiceService?.getAutoSpeakEnabled() ?? Future.value(false),
                builder: (context, snapshot) {
                  final isEnabled = snapshot.data ?? false;
                  return Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          isEnabled ? LucideIcons.volume2 : LucideIcons.volumeX,
                          color: isEnabled ? AurealColors.plasmaCyan : Colors.white,
                        ),
                        onPressed: () async {
                          if (_voiceService != null) {
                            final current = await _voiceService!.getAutoSpeakEnabled();
                            
                            // Show premium notice on first enable
                            if (!current) {
                              final shouldEnable = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: AurealColors.carbon,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: Row(
                                    children: [
                                      const Icon(LucideIcons.volume2, color: AurealColors.plasmaCyan),
                                      const SizedBox(width: 12),
                                      Text(
                                        'TEXT-TO-VOICE',
                                        style: GoogleFonts.spaceGrotesk(
                                          color: AurealColors.plasmaCyan,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Harness cutting-edge AI to bring your companion to life.',
                                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AurealColors.plasmaCyan.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          '⚡ Premium Feature\n\nLimited free usage available during preview. Full access comes with premium tiers.',
                                          style: GoogleFonts.inter(
                                            color: AurealColors.plasmaCyan,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text(
                                        'NOT NOW',
                                        style: GoogleFonts.inter(color: Colors.white54),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AurealColors.plasmaCyan,
                                        foregroundColor: AurealColors.obsidian,
                                      ),
                                      child: Text(
                                        'ENABLE',
                                        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (shouldEnable == true) {
                                await _voiceService!.setAutoSpeakEnabled(true);
                                setState(() {});
                              }
                            } else {
                              // Disable without dialog
                              await _voiceService!.setAutoSpeakEnabled(false);
                              setState(() {});
                            }
                          }
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      // Premium badge
                      if (!isEnabled)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: AurealColors.hyperGold,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '⚡',
                              style: const TextStyle(fontSize: 8),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.share2, color: Colors.white),
                onPressed: () {},
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
          GestureDetector(
            onTap: _handleDailyUpdate,
            child: _buildGlassChip(LucideIcons.sun, 'Daily Update'),
          ),
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
                    enabled: true, // Always enabled
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _isTyping ? 'AI is thinking...' : 'Type a message...',
                      hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.3)),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                // Rewrite button (Apple Intelligence)
                GestureDetector(
                  onTap: _handleRewrite,
                  child: Icon(
                    LucideIcons.wand2,
                    color: _controller.text.isNotEmpty 
                        ? AurealColors.hyperGold 
                        : Colors.white.withOpacity(0.3),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                // Microphone button
                GestureDetector(
                  onTap: _handleVoiceInput,
                  child: Icon(
                    _isListening ? LucideIcons.micOff : LucideIcons.mic,
                    color: _isListening ? AurealColors.plasmaCyan : Colors.white.withOpacity(0.6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
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
