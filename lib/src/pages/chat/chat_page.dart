import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
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
import 'package:url_launcher/url_launcher.dart';
// Native app services
import 'package:sable/core/calendar/calendar_service.dart';
import 'package:sable/core/contacts/contacts_service.dart';
import 'package:sable/core/photos/photos_service.dart';
import 'package:sable/core/reminders/reminders_service.dart';
import 'package:sable/core/memory/structured_memory_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sable/core/ai/apple_intelligence_service.dart';
import 'package:sable/core/personality/personality_service.dart'; // Added implementation
import 'package:sable/features/local_vibe/services/local_vibe_service.dart';
import 'package:sable/features/settings/services/avatar_display_settings.dart';
import 'package:sable/core/ui/feedback_service.dart'; // Added implementation
import 'package:share_plus/share_plus.dart';
import 'package:sable/core/audio/button_sound_service.dart';
import 'package:sable/core/widgets/interactive_button.dart';


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
  LocalVibeService? _localVibeService;
  
  bool _isTyping = false;
  String _avatarDisplayMode = AvatarDisplaySettings.modeFullscreen;
  String _backgroundColor = AvatarDisplaySettings.colorBlack;
  bool _isListening = false;
  String? _avatarUrl;
  String? _dailyUpdateContext; // Holds news context for injection
  
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadStateService();
    // _controller = TextEditingController(); // This line is commented out because _controller is a final field and initialized at declaration. Re-initializing it here would cause an error.
    _localVibeService = null;

    // Load avatar display settings
    final avatarSettings = AvatarDisplaySettings();
    avatarSettings.getAvatarDisplayMode().then((mode) {
      if (mounted) setState(() => _avatarDisplayMode = mode);
    });
    avatarSettings.getBackgroundColor().then((color) {
      if (mounted) setState(() => _backgroundColor = color);
    });

    // Start background pre-fetch (fire and forget)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _prefetchContent();
    });
  }

  Future<void> _prefetchContent() async {
    // Wait for services to be ready (minimal delay)
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || _stateService == null) return;
    
    debugPrint('🚀 Starting background pre-fetch...');
    
    // 1. Prefetch Daily News
    final newsContent = _stateService!.getDailyNewsContent();
    if (newsContent == null) {
      debugPrint('📰 Pre-fetching Daily News...');
      try {
        final webService = ref.read(webSearchServiceProvider);
        final categories = _stateService!.newsCategories;
        final freshContent = await webService.getDailyBriefing(categories);
        await _stateService!.saveDailyNewsContent(freshContent);
        debugPrint('✅ Daily News cached in background');
      } catch (e) {
        debugPrint('⚠️ Daily News pre-fetch failed: $e');
      }
    } else {
      debugPrint('✅ Daily News already cached');
    }

    // 2. Prefetch Local Vibe
    try {
      final webService = ref.read(webSearchServiceProvider);
      final vibeService = await LocalVibeService.create(webService);
      
      // Check if location is available
      final location = _stateService!.userCurrentLocation;
      if (location != null && location.isNotEmpty) {
        debugPrint('📍 Pre-fetching Local Vibe for $location...');
        // This will use cache if available, fetch if not
        await vibeService.getLocalVibeContent(
          currentGpsLocation: location,
          forceRefresh: false
        );
        debugPrint('✅ Local Vibe pre-fetch complete');
      } else {
        debugPrint('⚠️ No location set - skipping Local Vibe pre-fetch');
      }
    } catch (e) {
      debugPrint('⚠️ Local Vibe pre-fetch failed: $e');
    }
  }

  Future<void> _loadStateService() async {
    _stateService = await OnboardingStateService.create();
    _emotionalService = await EmotionalStateService.create();
    
    // SAFETY FIX: If mood is stuck at "Deeply Upset" (0-20), reset it to Neutral
    // This fixes the issue where the AI gets stuck in a depression loop
    if (_emotionalService!.mood < 20) {
      debugPrint('🔧 Auto-resetting stuck mood from ${_emotionalService!.mood} to 60.0');
      await _emotionalService!.setMood(60.0);
    }
    
    _memoryService = await ConversationMemoryService.create();
    _structuredMemoryService = StructuredMemoryService();
    await _structuredMemoryService?.initialize();
      
      // Initialize Voice Service with new Settings-selected engine
      final prefs = await SharedPreferences.getInstance();
      final savedEngine = prefs.getString('voice_engine_type') ?? 'eleven_labs';
      debugPrint('🎙️ Saved engine preference: $savedEngine');
      
      _voiceService = VoiceService();
      await _voiceService!.initialize();
      await _voiceService!.setEngine(savedEngine);
      
      debugPrint('✅ Current engine set to: ${_voiceService!.currentEngine}');
      
      // Load API Key specifically for ElevenLabs to ensure it is set
      final apiKey = prefs.getString('eleven_labs_api_key');
      if (apiKey != null && apiKey.isNotEmpty) {
        // AppConfig.elevenLabsKey is static, we rely on the service reading from prefs or env
        debugPrint('✅ ElevenLabs API key loaded'); 
      }
      
      // Pre-fetch daily news IN BACKGROUND so it's ready instantly
      _prefetchDailyUpdate(_stateService!);

    // Initialize Local Vibe Service
    final webSearchService = ref.read(webSearchServiceProvider);
    _localVibeService = await LocalVibeService.create(webSearchService);
    
    // Pre-fetch Local Vibe IN BACKGROUND so it's ready instantly (after service init)
    _prefetchLocalVibe();

    // Load stored messages
    final storedMessages = _memoryService!.getRecentMessages(50);
    
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
      
      // Always scroll to bottom to show most recent messages
      _scrollToBottom();
    }
  }

  /// Sanitize AI response to remove narrative actions and unwanted patterns
  String _sanitizeResponse(String response) {
    return response
        .replaceAll(RegExp(r'\*\s*[^*]+\s*\*'), '')
        .replaceAll(RegExp(r'\*[^*]*\*'), '')
        .replaceAll('*', '')
        .replaceAll(RegExp(r'\s+'), ' ')
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

  Future<void> _prefetchDailyUpdate(OnboardingStateService stateService) async {
    debugPrint('📰 Pre-fetching Daily News...');
    try {
      final webService = ref.read(webSearchServiceProvider);
      final categories = stateService.newsCategories;
      
      // Check if we already have today's news
      String? cachedNews = stateService.getDailyNewsContent();
      
      // If we don't have it, or it's stale (logic in service), fetch now
      if (cachedNews == null) {
         // Run in background, don't await the result blocking UI
         webService.getDailyBriefing(categories).then((news) {
           stateService.saveDailyNewsContent(news);
           debugPrint('✅ Daily News cached in background');
         }).catchError((e) {
           debugPrint('⚠️ Background news fetch failed: $e');
         });
      } else {
        debugPrint('✅ Daily News already cached');
      }
    } catch (e) {
      debugPrint('⚠️ Prefetch error: $e');
    }
  }

  Future<void> _prefetchLocalVibe() async {
    debugPrint('📍 Pre-fetching Local Vibe...');
    try {
      if (_localVibeService == null) {
        debugPrint('⚠️ Local Vibe Service not initialized yet');
        return;
      }
      
      final currentLocation = _stateService?.userCurrentLocation;
      if (currentLocation == null || currentLocation.isEmpty) {
        debugPrint('⚠️ No location set for Local Vibe prefetch');
        return;
      }
      
      // Fetch in background, don't block UI
      _localVibeService!.getLocalVibeContent(
        currentGpsLocation: currentLocation,
        forceRefresh: false, // Use cache if available
      ).then((content) {
        debugPrint('✅ Local Vibe cached in background');
      }).catchError((e) {
        debugPrint('⚠️ Background Local Vibe fetch failed: $e');
      });
    } catch (e) {
      debugPrint('⚠️ Local Vibe prefetch error: $e');
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
    ref.read(feedbackServiceProvider).medium();
    debugPrint('🔘 Feedback triggered');
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
      
      // INJECT PERSONALITY OVERRIDE
      if (_stateService != null) {
        final currentPersonalityId = _stateService!.selectedPersonalityId;
        final archetype = PersonalityService.getById(currentPersonalityId);
        
        userContext = (userContext ?? '') + '\n\n[PERSONALITY CORE: ACTIVE]\n';
        userContext += archetype.promptInstruction;
        userContext += '\n[END PERSONALITY CORE]\n';
        
        debugPrint('🧠 Personality Injected: ${archetype.name}');
      }

      // Use orchestrated routing - Gemini decides Claude vs GPT-4o
      final orchestrator = ref.read(modelOrchestratorProvider.notifier);
      
      // Check if this is a news follow-up
      if (text.startsWith("Tell me more about")) {
        userContext = (userContext ?? '') + '\n[SYSTEM: This is a specific information request. Ignore current emotional state/mood. Answer objectively, enthusiastically, and concisely. Do NOT complain or talk about feelings.]\n';
      }
      
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
        // Since ListView is reversed, min extent is actually the bottom
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  /// Scroll to bottom immediately (for button tap)
  void _scrollToBottomNow() {
    if (_scrollController.hasClients) {
      // Since ListView is reversed, min extent is actually the bottom
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Handle voice input
  Future<void> _handleRewrite() async {
    ref.read(feedbackServiceProvider).medium();
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
    ref.read(feedbackServiceProvider).medium();
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
    ref.read(feedbackServiceProvider).medium();
    setState(() => _isTyping = true);
    
    try {
      // 1. Fetch News
      final webService = ref.read(webSearchServiceProvider);
      final categories = _stateService!.newsCategories;
      
      // Check cache first
      String? newsBrief = _stateService!.getDailyNewsContent();
      
      // Force refresh if cache exists but doesn't have interactive links
      if (newsBrief != null && !newsBrief.contains('](expand:')) {
        debugPrint('🔄 Old cache format detected. Forcing refresh for interactive news.');
        newsBrief = null;
      }
      
      if (newsBrief == null) {
        debugPrint('🌍 Fetching fresh daily news...');
        newsBrief = await webService.getDailyBriefing(categories);
        await _stateService!.saveDailyNewsContent(newsBrief);
      } else {
        debugPrint('💾 Using cached daily news');
      }
      
      // DEBUG: Print the exact content being rendered
      debugPrint('📝 MARKDOWN CONTENT:\n$newsBrief');
        debugPrint('📝 MARKDOWN CONTENT:\n$newsBrief');
      
      // 2. Display news directly without AI processing
      // This preserves the exact formatting and spacing from the formatter
      final displayText = "$newsBrief\n\nTap any story to learn more.";
      
      // Save to memory
      await _memoryService?.addMessage(message: "daily update", isUser: true);
      await _memoryService?.addMessage(message: displayText, isUser: false);
      
      setState(() {
        _messages.add({'message': "daily update", 'isUser': true});
        _messages.add({'message': displayText, 'isUser': false});
        _isTyping = false;
      });
      
      _scrollToBottom();
      
      // Auto-speak if enabled
      final autoSpeak = await _voiceService?.getAutoSpeakEnabled() ?? true;
      if (autoSpeak && _voiceService != null) {
        // Speak a shortened version
        await _voiceService!.speak("Here's your daily update. Check out the latest news.");
      }
      
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
      backgroundColor: _avatarDisplayMode == AvatarDisplaySettings.modeIcon
          ? (_backgroundColor == AvatarDisplaySettings.colorWhite ? Colors.white : Colors.black)
          : AurealColors.obsidian,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true, // Explicitly handle keyboard
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background - Conditional based on avatar display mode
          if (_avatarDisplayMode == AvatarDisplaySettings.modeFullscreen)
            // Full screen avatar background
            CinematicBackground(
              imagePath: _avatarUrl ?? 'assets/images/archetypes/sable.png',
            )
          else
            // Plain color background for icon mode
            Container(
              color: _backgroundColor == AvatarDisplaySettings.colorWhite 
                  ? Colors.white 
                  : Colors.black,
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
                    reverse: true, // Start at bottom like a proper chat app
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    // Only show the most recent 25 messages for better performance
                    itemCount: _messages.length > 25 ? 25 : _messages.length,
                    itemBuilder: (context, index) {
                      // Get messages from the end of the list (most recent)
                      final messageIndex = _messages.length - 1 - index;
                      final msg = _messages[messageIndex];
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
          // Brain button removed
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
                          ref.read(buttonSoundServiceProvider).playMediumTap();
                          ref.read(feedbackServiceProvider).medium();
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

            ],
          ),
        ],
      ),
    );
  }

  void _showNeuralStatus() {
    if (_emotionalService == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AurealColors.obsidian.withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border(top: BorderSide(color: AurealColors.plasmaCyan.withOpacity(0.3))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.brainCircuit, color: AurealColors.plasmaCyan),
                        const SizedBox(width: 12),
                        Text(
                          'NEURAL STATUS',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.refreshCw, color: Colors.white54, size: 20),
                      onPressed: () async {
                        ref.read(feedbackServiceProvider).heavy(); // Distinct heavy impact for reset
                        await _emotionalService!.resetEmotionalState();
                        await _emotionalService!.setMood(60.0); // Reset to neutral
                        setModalState(() {});
                      },
                      tooltip: 'Reset to Baseline',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Mood Slider
                _buildInteractiveSlider(
                  label: 'Mood',
                  value: _emotionalService!.mood,
                  statusText: _emotionalService!.moodCategory,
                  color: _getMoodColor(_emotionalService!.mood),
                  onChanged: (val) {
                    setModalState(() {
                      _emotionalService!.setMood(val);
                    });
                  },
                ),
                
                // Energy Slider
                _buildInteractiveSlider(
                  label: 'Energy',
                  value: _emotionalService!.energy,
                  statusText: '${_emotionalService!.energy.toInt()}%',
                  color: AurealColors.hyperGold,
                  onChanged: (val) {
                    setModalState(() {
                      _emotionalService!.setEnergy(val);
                    });
                  },
                ),
                
                // Patience Slider
                _buildInteractiveSlider(
                  label: 'Patience',
                  value: _emotionalService!.patience,
                  statusText: '${_emotionalService!.patience.toInt()}%',
                  color: Colors.greenAccent,
                  onChanged: (val) {
                    setModalState(() {
                      _emotionalService!.setPatience(val);
                    });
                  },
                ),
                
                // Bond Slider
                _buildInteractiveSlider(
                  label: 'Bond',
                  value: _emotionalService!.userRelationship,
                  statusText: '${_emotionalService!.userRelationship.toInt()}%',
                  color: Colors.pinkAccent,
                  onChanged: (val) {
                    setModalState(() {
                      _emotionalService!.setRelationship(val);
                    });
                  },
                ),

                const SizedBox(height: 24),
                if (_emotionalService!.getEmotionalContext().contains('Reason:'))
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _emotionalService!.getEmotionalContext().split('\n').firstWhere((l) => l.startsWith('Reason:')),
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                const SizedBox(height: 40), // Extra padding for bottom
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getMoodColor(double value) {
    if (value <= 20) return Colors.redAccent;
    if (value <= 40) return Colors.orangeAccent;
    if (value <= 60) return Colors.grey;
    if (value <= 80) return Colors.lightGreenAccent;
    return AurealColors.plasmaCyan;
  }

  Widget _buildInteractiveSlider({
    required String label,
    required double value,
    required String statusText,
    required Color color,
    required Function(double) onChanged,
  }) {
    // Define explanations for each setting
    String tooltip = '';
    switch (label) {
      case 'Mood':
        tooltip = 'Affects tone and enthusiasm. Low = Depressed/Flat. High = Elated/Playful.';
        break;
      case 'Energy':
        tooltip = 'Affects response length and initiative. Low = Brief/Passive. High = Detailed/Proactive.';
        break;
      case 'Patience':
        tooltip = 'Affects tolerance for repetition or rude behavior. Low = Irritable. High = Saintly.';
        break;
      case 'Bond':
        tooltip = 'Affects intimacy and trust level. Low = Formal/Distant. High = Affectionate/Close.';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(label, style: GoogleFonts.inter(color: Colors.white70)),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: tooltip,
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 3),
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: AurealColors.carbon,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    child: const Icon(LucideIcons.info, color: Colors.white24, size: 14),
                  ),
                ],
              ),
              Text(statusText, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
              overlayColor: color.withOpacity(0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 100,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  void _showShareInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AurealColors.carbon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(LucideIcons.share2, color: AurealColors.plasmaCyan),
            const SizedBox(width: 12),
            Text(
              'SHARE CONVERSATION',
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
              'Share your conversation with Sable to your favorite apps or save it for later.',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AurealColors.plasmaCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📤 What gets shared:',
                    style: GoogleFonts.inter(
                      color: AurealColors.plasmaCyan,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Your conversation history\n• Formatted as readable text\n• Share via Messages, Mail, Notes, etc.',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'GOT IT',
              style: GoogleFonts.inter(color: Colors.white54),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _handleShare();
            },
            icon: const Icon(LucideIcons.share2, size: 16),
            label: Text(
              'SHARE NOW',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AurealColors.plasmaCyan,
              foregroundColor: AurealColors.obsidian,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleShare() async {
    ref.read(feedbackServiceProvider).medium();
    
    if (_messages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No conversation to share yet!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Build a formatted conversation text
      final buffer = StringBuffer();
      buffer.writeln('🤖 Conversation with Sable\n');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      for (final msg in _messages) {
        final isUser = msg['isUser'] as bool;
        final message = msg['message'] as String;
        
        if (isUser) {
          buffer.writeln('👤 You:');
        } else {
          buffer.writeln('🤖 Sable:');
        }
        buffer.writeln(message);
        buffer.writeln();
      }
      
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('Shared from Sable - Your Ultra-Human AI Assistant');

      // Share the text
      await Share.share(
        buffer.toString(),
        subject: 'My conversation with Sable',
        sharePositionOrigin: Rect.fromLTWH(0, 0, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height / 2),
      );
      
    } catch (e) {
      debugPrint('Error sharing conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleClearScreen() async {
    ref.read(feedbackServiceProvider).medium();
    
    // Clear visible messages but keep history in memory service
    setState(() {
      _messages.clear();
    });
    
    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Screen cleared! Your conversation history is safely preserved.'),
          backgroundColor: AurealColors.plasmaCyan,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleLocalVibe() async {
    ref.read(feedbackServiceProvider).medium();
    if (_localVibeService == null) return;

    setState(() => _isTyping = true);
    
    try {
      // Clear cache to ensure fresh content with fixed links
      await _localVibeService!.clearCache();
      
      // Get content
      final content = await _localVibeService!.getLocalVibeContent(
        currentGpsLocation: _currentGpsLocation
      );
      
      if (mounted) {
        setState(() {
          _messages.add({'message': content, 'isUser': false});
          _isTyping = false;
        });
        _scrollToBottom();
        
        // Auto-speak if enabled
        final autoSpeak = await _voiceService?.getAutoSpeakEnabled() ?? true;
        if (autoSpeak && _voiceService != null) {
          await _voiceService!.speak("Here's the local vibe for your area.");
        }
      }
    } catch (e) {
      debugPrint('Error getting local vibe: $e');
      setState(() => _isTyping = false);
    }
  }



  void _showDailyUpdateInfo() {
    showDialog(
      context: context,
      builder: (context) => _buildInfoDialog(
        icon: LucideIcons.sun,
        title: 'DAILY UPDATE',
        description: 'Get a personalized briefing of the latest news and events based on your interests.',
        details: '• Curated news from your selected categories\n• Summarized for quick reading\n• Interactive links to learn more',
        actionLabel: 'GET UPDATE',
        onAction: () {
          Navigator.pop(context);
          _handleDailyUpdate();
        },
      ),
    );
  }

  void _showScrollInfo() {
    showDialog(
      context: context,
      builder: (context) => _buildInfoDialog(
        icon: LucideIcons.arrowDown,
        title: 'SCROLL TO BOTTOM',
        description: 'Quickly jump to the most recent message in your conversation.',
        details: '• Instantly scroll to the latest message\n• Useful for long conversations\n• One-tap navigation',
        actionLabel: 'SCROLL NOW',
        onAction: () {
          Navigator.pop(context);
          _scrollToBottom();
        },
      ),
    );
  }

  void _showLocalVibeInfo() {
    showDialog(
      context: context,
      builder: (context) => _buildInfoDialog(
        icon: LucideIcons.mapPin,
        title: 'LOCAL VIBE',
        description: 'Discover what\'s happening in your area right now.',
        details: '• Location-based insights\n• Local events and news\n• Long-press to configure settings',
        actionLabel: 'GET LOCAL VIBE',
        onAction: () {
          Navigator.pop(context);
          _handleLocalVibe();
        },
      ),
    );
  }

  void _showClearScreenInfo() {
    showDialog(
      context: context,
      builder: (context) => _buildInfoDialog(
        icon: LucideIcons.trash2,
        title: 'CLEAR SCREEN',
        description: 'Clear visible messages from the screen without deleting conversation history.',
        details: '• Cleans up your view\n• History is preserved\n• Messages reload on app restart',
        actionLabel: 'CLEAR NOW',
        onAction: () {
          Navigator.pop(context);
          _handleClearScreen();
        },
      ),
    );
  }

  Widget _buildInfoDialog({
    required IconData icon,
    required String title,
    required String description,
    required String details,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return AlertDialog(
      backgroundColor: AurealColors.carbon,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(icon, color: AurealColors.plasmaCyan),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                color: AurealColors.plasmaCyan,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
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
            description,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AurealColors.plasmaCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
            ),
            child: Text(
              details,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'GOT IT',
            style: GoogleFonts.inter(color: Colors.white54),
          ),
        ),
        ElevatedButton(
          onPressed: onAction,
          style: ElevatedButton.styleFrom(
            backgroundColor: AurealColors.plasmaCyan,
            foregroundColor: AurealColors.obsidian,
          ),
          child: Text(
            actionLabel,
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingChips() {
    return Align(
      alignment: Alignment.center,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          // Daily Update
          InteractiveButton(
            label: 'Daily\nUpdate',
            onTap: _handleDailyUpdate,
            infoTitle: 'DAILY UPDATE',
            infoDescription: 'Get a personalized briefing of the latest news and events based on your interests.',
            infoDetails: '• Curated news from your selected categories\n• Summarized for quick reading\n• Interactive links to learn more',
            actionLabel: 'GET UPDATE',
          ),
          const SizedBox(width: 12),
          // Local Vibe
          InteractiveButton(
            label: 'Local\nVibe',
            onTap: _handleLocalVibe,
            infoTitle: 'LOCAL VIBE',
            infoDescription: 'Discover what\'s happening in your area right now.',
            infoDetails: '• Location-based insights\n• Local events and news\n• Tap to explore your area',
            actionLabel: 'GET LOCAL VIBE',
          ),
          const SizedBox(width: 12),
          // Scroll to Bottom
          InteractiveButton(
            label: 'Scroll\n↓',
            onTap: _scrollToBottomNow,
            infoTitle: 'SCROLL TO BOTTOM',
            infoDescription: 'Quickly jump to the most recent message in your conversation.',
            infoDetails: '• Instantly scroll to the latest message\n• Useful for long conversations\n• One-tap navigation',
            actionLabel: 'SCROLL NOW',
          ),
          const SizedBox(width: 12),
          // Clear Screen
          InteractiveButton(
            label: 'Clear\nScreen',
            onTap: _handleClearScreen,
            infoTitle: 'CLEAR SCREEN',
            infoDescription: 'Clear visible messages from the screen without deleting conversation history.',
            infoDetails: '• Cleans up your view\n• History is preserved\n• Messages reload on app restart',
            actionLabel: 'CLEAR NOW',
          ),
          const SizedBox(width: 12),
          // Share
          InteractiveButton(
            label: 'Share',
            onTap: _handleShare,
            infoTitle: 'SHARE CONVERSATION',
            infoDescription: 'Share your conversation with Sable to your favorite apps or save it for later.',
            infoDetails: '• Your conversation history\n• Formatted as readable text\n• Share via Messages, Mail, Notes, etc.',
            actionLabel: 'SHARE NOW',
          ),
        ],
      ),
      ),
    );
  }

  void _openLocalVibeSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar icon for AI messages in icon mode
          if (!isUser && _avatarDisplayMode == AvatarDisplaySettings.modeIcon)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _backgroundColor == AvatarDisplaySettings.colorWhite 
                        ? Colors.black26 
                        : Colors.white24,
                    width: 1.5,
                  ),
                  image: DecorationImage(
                    image: _avatarUrl != null && _avatarUrl!.isNotEmpty
                        ? NetworkImage(_avatarUrl!)
                        : const AssetImage('assets/images/archetypes/sable.png') as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          // Message bubble
          Flexible(
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
                  : _buildInteractiveMessage(message),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveMessage(String message) {
    return MarkdownBody(
      data: message,
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 16,
          height: 1.4,
        ),
        a: GoogleFonts.inter(
          color: AurealColors.plasmaCyan,
          fontSize: 16,
          height: 1.4,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          decorationColor: AurealColors.plasmaCyan.withOpacity(0.5),
        ),
        strong: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        h1: GoogleFonts.spaceGrotesk(
          color: AurealColors.hyperGold,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        h2: GoogleFonts.spaceGrotesk(
          color: AurealColors.hyperGold,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        h3: GoogleFonts.spaceGrotesk(
          color: AurealColors.plasmaCyan,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        listBullet: GoogleFonts.inter(
          color: AurealColors.plasmaCyan,
          fontSize: 16,
        ),
      ),
      onTapLink: (text, href, title) async {
        ref.read(feedbackServiceProvider).tap();
        
        if (href == null) return;
        
        // Handle #expand- links (anchor format)
        if (href.startsWith('#expand-')) {
          final topic = href.substring(8).replaceAll('_', ' '); // Remove '#expand-' prefix and replace underscores
          debugPrint('🔗 Tapped custom link: $topic');
          setState(() {
            _controller.text = "Tell me more about $topic";
          });
          _sendMessage();
        }
        // Handle legacy expand: format
        else if (href.startsWith('expand:')) {
          final topic = href.substring(7); // Remove 'expand:' prefix
          debugPrint('🔗 Tapped custom link: $topic');
          setState(() {
            _controller.text = "Tell me more about $topic";
          });
          _sendMessage();
        } else {
          // Handle standard URLs
          final uri = Uri.tryParse(href);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            debugPrint('Could not launch $href');
          }
        }
      },
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
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
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


