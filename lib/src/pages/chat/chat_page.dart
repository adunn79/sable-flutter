import 'dart:async';
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
import 'package:sable/core/memory/unified_memory_service.dart';
import 'package:sable/core/memory/memory_extraction_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sable/core/ai/apple_intelligence_service.dart';
import 'package:sable/core/personality/personality_service.dart'; // Added implementation
import 'package:sable/features/local_vibe/services/local_vibe_service.dart';
import 'package:sable/features/settings/services/avatar_display_settings.dart';
import 'package:sable/features/settings/widgets/magic_orb_widget.dart';
import 'package:sable/core/emotion/weather_service.dart';
import 'package:sable/features/clock/widgets/clock_face_widget.dart';
import 'package:sable/features/clock/screens/clock_mode_screen.dart';
import 'package:sable/core/ui/feedback_service.dart'; // Added implementation
import 'package:share_plus/share_plus.dart';
import 'package:sable/core/audio/button_sound_service.dart';
import 'package:sable/core/widgets/interactive_button.dart';


class ChatPage extends ConsumerStatefulWidget {
  final String? initialPrompt;
  const ChatPage({super.key, this.initialPrompt});

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
  UnifiedMemoryService? _unifiedMemoryService;
  MemoryExtractionService? _memoryExtractionService;
  VoiceService? _voiceService;
  LocalVibeService? _localVibeService;
  
  bool _isTyping = false;
  String _avatarDisplayMode = AvatarDisplaySettings.modeFullscreen;
  String _backgroundColor = AvatarDisplaySettings.colorBlack;
  bool _isListening = false;
  String? _avatarUrl;
  String? _dailyUpdateContext; // Holds news context for injection
  String _companionName = 'SABLE'; // Default archetype name, loaded from prefs
  String _archetypeId = 'sable'; // Lowercase archetype ID for image path
  bool _clockUse24Hour = false;
  bool _clockIsAnalog = false;
  
  // Clock mode dimming
  bool _clockDimmed = false;
  Timer? _clockDimTimer;
  bool _showChatOverClock = false; // Temporarily show chat even when in clock mode
  
  // Weather display in header
  String? _weatherTemp;
  String? _weatherCondition;
  String? _weatherHighLow;
  
  // Voice mute toggle
  bool _isMuted = false;
  bool _isAvatarSettingsLoaded = false;
  
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    // Handle initial prompt if provided
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.text = widget.initialPrompt!;
        _sendMessage();
      });
    }
    _loadStateService();
    // _controller = TextEditingController(); // This line is commented out because _controller is a final field and initialized at declaration. Re-initializing it here would cause an error.
    _localVibeService = null;

    // Fast-load avatar settings to prevent flash of wrong image
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        final savedAvatarUrl = prefs.getString('avatar_url');
        final savedArchetypeId = prefs.getString('selected_archetype_id');
          if (savedAvatarUrl != null || savedArchetypeId != null) {
            setState(() {
              if (savedAvatarUrl != null) _avatarUrl = savedAvatarUrl;
              if (savedArchetypeId != null) _archetypeId = savedArchetypeId.toLowerCase();
              _isAvatarSettingsLoaded = true;
            });
          } else {
            // No custom settings found, mark as loaded with defaults
            setState(() => _isAvatarSettingsLoaded = true);
          }
      }
    });

    // Load avatar display settings
    final avatarSettings = AvatarDisplaySettings();
    avatarSettings.getAvatarDisplayMode().then((mode) {
      if (mounted) setState(() => _avatarDisplayMode = mode);
    });
    avatarSettings.getBackgroundColor().then((color) {
      if (mounted) setState(() => _backgroundColor = color);
    });
    
    // Load clock settings
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _clockUse24Hour = prefs.getBool('clock_use_24hour') ?? false;
          _clockIsAnalog = prefs.getBool('clock_is_analog') ?? false;
        });
      }
    });

    // Start background pre-fetch (fire and forget)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _prefetchContent();
      _fetchWeather(); // Fetch weather for header display
      
      // Start periodic check for Daily Briefing (e.g. for Overnight mode)
      // Check every 10 minutes
      Timer.periodic(const Duration(minutes: 10), (timer) {
        if (mounted) _prefetchContent();
      });
    });
  }
  
  /// Fetch current weather for header display
  Future<void> _fetchWeather() async {
    try {
      String? location;
      
      // Try GPS location first
      final apiKey = AppConfig.googleMapsApiKey;
      if (apiKey.isNotEmpty) {
        location = await LocationService.getCurrentLocationName(apiKey);
        debugPrint('📍 Weather: Got GPS location: $location');
      }
      
      // Fallback to saved userLocation
      if (location == null && _stateService != null) {
        location = _stateService!.userLocation;
        debugPrint('📍 Weather: Using saved location: $location');
      }
      
      if (location == null || !mounted) {
        debugPrint('⚠️ Weather: No location available');
        return;
      }
      
      // Fetch weather for location
      final weather = await WeatherService.getWeather(location);
      if (weather != null && mounted) {
        debugPrint('🌤️ Weather: ${weather.temperature}° ${weather.description}');
        setState(() {
          _weatherTemp = '${weather.temperature.round()}°';
          _weatherCondition = weather.description;
          if (weather.tempHigh != null && weather.tempLow != null) {
            _weatherHighLow = 'H:${weather.tempHigh!.round()}° L:${weather.tempLow!.round()}°';
          }
        });
        // Cache weather for other screens (e.g. Vital Balance)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_weather_temp', _weatherTemp!);
        await prefs.setString('cached_weather_condition', _weatherCondition ?? '');
      } else {
        debugPrint('⚠️ Weather: Fetch returned null');
      }
    } catch (e) {
      debugPrint('❌ Weather fetch error: $e');
    }
  }

  Future<bool> _shouldFetchDailyUpdate(SharedPreferences prefs) async {
    final lastRunDate = prefs.getString('daily_briefing_last_run_date');
    final now = DateTime.now();
    final today = "${now.year}-${now.month}-${now.day}";
    
    // If already run today, skip
    if (lastRunDate == today) {
        debugPrint('📅 Daily Briefing already generated for today ($today)');
        return false;
    }
    
    // Get Trigger Mode
    final trigger = prefs.getString('daily_briefing_trigger') ?? 'time';
    debugPrint('🕒 Checking Daily Briefing Trigger: $trigger');
    
    if (trigger == 'launch') {
        // Run immediately on first launch
        return true;
    } else if (trigger == 'overnight') {
        // Run if it's past 4:00 AM
        return now.hour >= 4;
    } else {
        // Specific Time (default)
        // Parse saved time string "HH:mm" or default to 8:00
        // Since we didn't save the time string properly in SettingsScreen yet (it just saves to stateService or nothing?), 
        // we might fallback to 8am. 
        // Wait, SettingsScreen uses `stateService.setBriefingTime` but that might just be local.
        // Let's check OnboardingStateService for briefing time.
        // For now, let's assume default 8am if not found.
        if (_stateService != null) {
            // Need to parse "TimeOfDay(08:00)" string? Or formatted?
             // Simplification: Check if hour >= 8
             return now.hour >= 8; 
        }
        return now.hour >= 8;
    }
  }

  Future<void> _prefetchContent() async {
    // Wait for services to be ready (minimal delay)
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || _stateService == null) return;
    
    // Check Smart Scheduling Trigger
    final prefs = await SharedPreferences.getInstance();
    final shouldFetch = await _shouldFetchDailyUpdate(prefs);
    
    if (!shouldFetch) {
        debugPrint('⏭️ Skipping Daily Briefing pre-fetch (Condition not met)');
        // Ensure we still load *cached* content if available
        return;
    }
    
    debugPrint('🚀 Starting background pre-fetch...');
    
    // 1. Prefetch Daily News/Briefing
    final newsContent = _stateService!.getDailyNewsContent();
    // Force refresh if shouldFetch is true, regardless of if we have *something* (maybe old?)
    // Actually, shouldFetch checks 'daily_briefing_last_run_date'.
    // If newsContent is null, we definitely fetch.
    // If we have content but 'last_run_date' wasn't set (legacy), we set it now? 
    // Or we overwrite?
    
    // Let's assume we fetch if shouldFetch is true.
    debugPrint('📰 Pre-fetching Daily News...');
    try {
        final webService = ref.read(webSearchServiceProvider);
        final categories = _stateService!.newsCategories;
        final freshContent = await webService.getDailyBriefing(categories);
        await _stateService!.saveDailyNewsContent(freshContent);
        
        // Mark as run for today
        final now = DateTime.now();
        final today = "${now.year}-${now.month}-${now.day}";
        await prefs.setString('daily_briefing_last_run_date', today);
        
        debugPrint('✅ Daily News cached in background');
    } catch (e) {
        debugPrint('⚠️ Daily News pre-fetch failed: $e');
    }

    // 2. Prefetch Local Vibe (after fetching GPS location)
    try {
      final webService = ref.read(webSearchServiceProvider);
      final vibeService = await LocalVibeService.create(webService);
      
      // Get location from stored setting OR fetch from GPS
      String? location = _stateService!.userCurrentLocation;
      
      // If no stored location, try to fetch GPS location
      if (location == null || location.isEmpty) {
        try {
          final apiKey = AppConfig.googleMapsApiKey;
          if (apiKey.isNotEmpty) {
            final gpsLocation = await LocationService.getCurrentLocationName(apiKey);
            if (gpsLocation != null) {
              location = gpsLocation;
              _currentGpsLocation = gpsLocation;
              debugPrint('📍 GPS location fetched: $location');
            }
          }
        } catch (e) {
          debugPrint('⚠️ GPS fetch failed: $e');
        }
      }
      
      if (location != null && location.isNotEmpty) {
        debugPrint('📍 Pre-fetching Local Vibe for $location...');
        await vibeService.getLocalVibeContent(
          currentGpsLocation: location,
          forceRefresh: false
        );
        debugPrint('✅ Local Vibe pre-fetch complete');
      } else {
        debugPrint('⚠️ No location available - skipping Local Vibe pre-fetch');
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
    
    // Initialize enhanced AI memory system
    _unifiedMemoryService = UnifiedMemoryService();
    await _unifiedMemoryService?.initialize();
    debugPrint('🧠 Unified Memory Service initialized');
    
    // Initialize memory extraction (AI learns about user from conversation)
    final orchestrator = ref.read(modelOrchestratorProvider.notifier);
    _memoryExtractionService = MemoryExtractionService(
      memoryService: _unifiedMemoryService!,
      orchestrator: orchestrator,
    );
    debugPrint('🧠 Memory Extraction Service initialized');
      
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
      
      // Load companion archetype name
      final archetypeId = _stateService!.selectedArchetypeId;
      if (mounted) {
        setState(() {
          _archetypeId = archetypeId.toLowerCase();
          _companionName = _getArchetypeDisplayName(archetypeId);
        });
      }

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

  /// Map archetype ID to display name
  String _getArchetypeDisplayName(String archetypeId) {
    switch (archetypeId.toLowerCase()) {
      case 'sable':
        return 'SABLE';
      case 'kai':
        return 'KAI';
      case 'echo':
        return 'ECHO';
      default:
        return archetypeId.toUpperCase();
    }
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
          final birthplace = _stateService!.userLocation;
          userContext += 'Date of Birth: ${dob.toIso8601String().split('T')[0]}\n';
          userContext += 'Age: $age\n';
          // Only include zodiac if enabled in settings
          if (_stateService!.zodiacEnabled) {
            final zodiac = _getZodiacSign(dob);
            userContext += 'Zodiac Sign: $zodiac\n';
          }
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
        greetingPrompt += 'You are $_companionName - their companion, assistant, organizer, and coach.\n';
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
          archetypeName: _companionName,
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
      
      // Try manual location first, then fall back to GPS
      String? location = _stateService?.userCurrentLocation;
      
      // If no manual location, use GPS location
      if (location == null || location.isEmpty) {
        location = _currentGpsLocation;
      }
      
      // If still no location, try to fetch GPS now
      if (location == null || location.isEmpty) {
        try {
          final apiKey = AppConfig.googleMapsApiKey;
          if (apiKey.isNotEmpty) {
            location = await LocationService.getCurrentLocationName(apiKey);
            if (location != null) {
              _currentGpsLocation = location;
              debugPrint('📍 GPS location fetched for prefetch: $location');
            }
          }
        } catch (e) {
          debugPrint('⚠️ GPS fetch for prefetch failed: $e');
        }
      }
      
      if (location == null || location.isEmpty) {
        debugPrint('⚠️ No location available for Local Vibe prefetch');
        return;
      }
      
      // Fetch in background, don't block UI
      _localVibeService!.getLocalVibeContent(
        currentGpsLocation: location,
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

    // Save user message to persistent memory (both old and new services)
    await _memoryService?.addMessage(message: text, isUser: true);
    await _unifiedMemoryService?.addChatMessage(
      message: text,
      isUser: true,
      emotionalContext: null,
    );
    
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
            final birthplace = _stateService!.userLocation; // Birth location
            userContext += 'Date of Birth: ${dob.toIso8601String().split('T')[0]}\n';
            userContext += 'Age: $age years old\n';
            // Only include zodiac if enabled in settings
            if (_stateService!.zodiacEnabled) {
              final zodiac = _getZodiacSign(dob);
              userContext += 'Zodiac Sign: $zodiac\n';
            }
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
          
          // Add AI-extracted user knowledge (enhanced memory)
          if (_unifiedMemoryService != null) {
            final extractedMemoryContext = _unifiedMemoryService!.getMemoryContext();
            if (extractedMemoryContext.isNotEmpty) {
              userContext += '\n$extractedMemoryContext\n';
            }
          }
          
          // Add wellness tracking status for gentle reminders
          try {
            final prefs = await SharedPreferences.getInstance();
            final lastWellnessUpdate = prefs.getString('last_wellness_update_date');
            final now = DateTime.now();
            final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            
            if (lastWellnessUpdate == null || lastWellnessUpdate != today) {
              // Calculate days since last update
              int daysSinceUpdate = 0;
              if (lastWellnessUpdate != null) {
                try {
                  final lastDate = DateTime.parse(lastWellnessUpdate);
                  daysSinceUpdate = now.difference(lastDate).inDays;
                } catch (_) {}
              }
              
              userContext += '\n[WELLNESS AWARENESS]\n';
              if (daysSinceUpdate >= 3) {
                userContext += 'IMPORTANT: User has NOT logged wellness metrics in $daysSinceUpdate days.\n';
                userContext += 'If conversation naturally allows, GENTLY remind them:\n';
                userContext += '- "Hey, I noticed you haven\'t checked in with Vital Balance in a few days - how are you feeling?"\n';
                userContext += '- Only mention ONCE per session, don\'t nag\n';
              } else if (daysSinceUpdate >= 1) {
                userContext += 'User last logged wellness $daysSinceUpdate day(s) ago.\n';
                userContext += 'Low priority - only mention if discussing health/mood naturally.\n';
              }
              userContext += 'Wellness features are in the Vital Balance section (tap heart icon).\n\n';
              userContext += 'MENTAL HEALTH ROUTING (CRITICAL):\n';
              userContext += '- You do NOT have access to the user\'s mental health data (mood, stress, anxiety, etc.)\n';
              userContext += '- If user discusses mental health, depression, anxiety, stress, sleep issues, or emotional struggles:\n';
              userContext += '  • Acknowledge their feelings briefly and with compassion\n';
              userContext += '  • Then REDIRECT: "For deeper support, check out Vital Balance (heart icon) - our wellness coach specializes in this"\n';
              userContext += '- You are NOT the mental health AI partner. The Vital Balance wellness coach handles those conversations.\n';
              userContext += '- Never guess or assume mental health details. Refer them to the right place.\n';
              userContext += '[END WELLNESS AWARENESS]\n';
            }
          } catch (e) {
            debugPrint('⚠️ Wellness status check failed: $e');
          }

          // Add native app integrations (only if permission granted)
          try {
            // Calendar
            if (await CalendarService.hasPermission()) {
              userContext = (userContext ?? '') + '\n';
              userContext = (userContext ?? '') + await CalendarService.getCalendarSummary();
            }
            
            // Contacts
            if (await ContactsService.hasPermission()) {
              userContext = (userContext ?? '') + '\n';
              userContext = (userContext ?? '') + await ContactsService.getRecentContactsSummary();
            }
            
            // Photos
            if (await PhotosService.hasPermission()) {
              userContext = (userContext ?? '') + '\n';
              userContext = (userContext ?? '') + await PhotosService.getPhotosSummary();
            }
            
            // Reminders
            if (await RemindersService.hasPermission()) {
              userContext = (userContext ?? '') + '\n';
              userContext = (userContext ?? '') + await RemindersService.getRemindersSummary();
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

      // CRITICAL: Override archetype identity and prevent hallucination
      userContext = (userContext ?? '') + '\n\n[CRITICAL SYSTEM OVERRIDE]\n';
      userContext += 'YOUR TRUE IDENTITY: You are $_companionName.\n';
      userContext += 'IGNORE any other names in conversation history. You ARE $_companionName. Never refer to yourself as any other name.\n\n';
      userContext += 'ANTI-HALLUCINATION RULES (CRITICAL):\n';
      userContext += '- NEVER invent or assume details about the user\'s life, preferences, activities, or plans\n';
      userContext += '- NEVER reference movies, shows, hobbies, or plans unless the user mentioned them in THIS conversation\n';
      userContext += '- If you don\'t know something, ASK—don\'t guess or make up details\n';
      userContext += '- Only reference information explicitly provided in [USER PROFILE], [CONVERSATION HISTORY], or [EXTRACTED MEMORIES]\n';
      userContext += '- It\'s better to say "tell me more" than to assume and be wrong\n';
      userContext += '[END OVERRIDE]\n\n';

      // Use orchestrated routing - Gemini decides Claude vs GPT-4o
      final orchestrator = ref.read(modelOrchestratorProvider.notifier);
      
      // Check if this is a news follow-up
      if (text.startsWith("Tell me more about")) {
        userContext = (userContext ?? '') + '\n[SYSTEM: This is a specific information request. Ignore current emotional state/mood. Answer objectively, enthusiastically, and concisely. Do NOT complain or talk about feelings.]\n';
      }
      
      final response = await orchestrator.orchestratedRequest(
        prompt: text,
        userContext: userContext,
        archetypeName: _companionName,
      );

      if (mounted) {
        // Sanitize the response ONCE for both display and speech
        final sanitizedResponse = _sanitizeResponse(response);
        
        // Save AI response to persistent memory (both old and new services)
        await _memoryService?.addMessage(message: sanitizedResponse, isUser: false);
        await _unifiedMemoryService?.addChatMessage(
          message: sanitizedResponse,
          isUser: false,
          emotionalContext: null,
        );
        
        // Trigger AI memory extraction in background (learns about user)
        _memoryExtractionService?.onMessageAdded();
        
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
        
        // Auto-speak AI response if not muted (mute button is the quick toggle)
        debugPrint('🔊 Voice debug: _isMuted=$_isMuted, voiceService=${_voiceService != null}');
        if (!_isMuted && _voiceService != null) {
          debugPrint('🔊 Attempting to speak response...');
          await _voiceService!.speak(sanitizedResponse);
          debugPrint('🔊 Speak completed');
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
        // Show typing indicator ONLY when fetching fresh data
        setState(() => _isTyping = true);
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
    
    // Determine theme brightness based on background color
    final isLightBackground = (_avatarDisplayMode == AvatarDisplaySettings.modeIcon || 
                               _avatarDisplayMode == AvatarDisplaySettings.modeOrb ||
                               _avatarDisplayMode == AvatarDisplaySettings.modePortrait) && 
                              _backgroundColor == AvatarDisplaySettings.colorWhite;
    
    // Debug print for Avatar Troubleshooting

    
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: isLightBackground ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
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
              _isAvatarSettingsLoaded
                  ? CinematicBackground(
                      imagePath: _stateService?.avatarUrl ?? 'assets/images/archetypes/$_archetypeId.png',
                    )
                  : const SizedBox()
            else if (_avatarDisplayMode == AvatarDisplaySettings.modeOrb)
              // Magic orb mode - orb at top 20% of screen
              Container(
                color: _backgroundColor == AvatarDisplaySettings.colorWhite 
                    ? Colors.white 
                    : Colors.black,
                child: Column(
                  children: [
                    // Top 22% for the orb
                    Container(
                      height: MediaQuery.of(context).size.height * 0.22,
                      alignment: Alignment.center,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 120),
                          child: MagicOrbWidget(
                            size: 145,
                            isActive: _isTyping || _isListening,
                          ),
                        ),
                      ),
                    ),
                    // Rest of the screen
                    Expanded(child: Container()),
                  ],
                ),
              )
            else if (_avatarDisplayMode == AvatarDisplaySettings.modePortrait)
              // Portrait mode - high-quality avatar at top 30%
              Container(
                color: _backgroundColor == AvatarDisplaySettings.colorWhite 
                    ? Colors.white 
                    : Colors.black,
                child: Column(
                  children: [
                    // Top 30% for the avatar portrait
                    Container(
                      height: MediaQuery.of(context).size.height * 0.32,
                      width: double.infinity,
                      decoration: _isAvatarSettingsLoaded
                          ? BoxDecoration(
                              image: DecorationImage(
                                image: (_stateService?.avatarUrl != null &&
                                        _stateService!.avatarUrl!.startsWith('http'))
                                    ? NetworkImage(_stateService!.avatarUrl!) as ImageProvider
                                    : AssetImage(_stateService?.avatarUrl ??
                                        'assets/images/archetypes/$_archetypeId.png'),
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                              ),
                            )
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              (_backgroundColor == AvatarDisplaySettings.colorWhite 
                                  ? Colors.white 
                                  : Colors.black).withOpacity(0.8),
                              _backgroundColor == AvatarDisplaySettings.colorWhite 
                                  ? Colors.white 
                                  : Colors.black,
                            ],
                            stops: const [0.0, 0.5, 0.85, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Rest of the screen
                    Expanded(child: Container()),
                  ],
                ),
              )
            else if (_avatarDisplayMode == AvatarDisplaySettings.modeClock && !_showChatOverClock)
              // Clock mode - avatar with clock face
              Builder(
                builder: (context) {
                  // Start/reset dim timer when in clock mode
                  _clockDimTimer?.cancel();
                  _clockDimTimer = Timer(const Duration(minutes: 1), () {
                    if (mounted && _avatarDisplayMode == AvatarDisplaySettings.modeClock) {
                      setState(() => _clockDimmed = true);
                    }
                  });
                  
                  return GestureDetector(
                    onTap: () {
                      if (_clockDimmed) {
                        // Wake up from dim
                        setState(() => _clockDimmed = false);
                        return;
                      }
                      // Open full screen clock mode
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ClockModeScreen(
                            archetypeId: _archetypeId,
                            onExit: () => Navigator.of(context).pop(),
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        // Clock display
                        AnimatedOpacity(
                          opacity: _clockDimmed ? 0.3 : 1.0,
                          duration: const Duration(seconds: 2),
                          child: Container(
                            color: Colors.black,
                            child: OrientationBuilder(
                              builder: (context, orientation) {
                            if (orientation == Orientation.landscape) {
                              // Landscape: Avatar left 50%, Clock right 50%
                              return Row(
                                children: [
                                  // Left 50% - Avatar
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        image: DecorationImage(
                                          image: AssetImage('assets/images/archetypes/$_archetypeId.png'),
                                          fit: BoxFit.cover,
                                          alignment: Alignment.center,
                                        ),
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.8),
                                            ],
                                            stops: const [0.5, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Right 50% - Clock
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 16, right: 48),
                                      child: Center(
                                        child: ClockFaceWidget(
                                          isAnalog: _clockIsAnalog,
                                          use24Hour: _clockUse24Hour,
                                          size: 252,
                                          primaryColor: Colors.white,
                                          secondaryColor: Colors.white70,
                                          weatherTemp: _weatherTemp,
                                          weatherCondition: _weatherCondition,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              // Portrait: Avatar top, Clock bottom
                              return Column(
                                children: [
                                  // Top for the avatar 
                                  Container(
                                    height: MediaQuery.of(context).size.height * 0.35,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: AssetImage('assets/images/archetypes/$_archetypeId.png'),
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                      ),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.8),
                                            Colors.black,
                                          ],
                                          stops: const [0.0, 0.5, 0.85, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Clock display
                                  Expanded(
                                    child: Center(
                                      child: ClockFaceWidget(
                                        isAnalog: _clockIsAnalog,
                                        use24Hour: _clockUse24Hour,
                                        size: 288,
                                        primaryColor: Colors.white,
                                        secondaryColor: Colors.white70,
                                        weatherTemp: _weatherTemp,
                                        weatherCondition: _weatherCondition,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                      ),
                    ),

                  ],
                ),
              );
                },
              )
            else if (_avatarDisplayMode == AvatarDisplaySettings.modeConversation)
              // Conversation mode - gradient background, chat on left, avatar figure on right
              Stack(
                fit: StackFit.expand,
                children: [
                  // Background matching avatar's jacket color for seamless blend
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF2a3038), // Dark charcoal grey matching jacket
                    ),
                  ),
                  // Avatar extended to fill right side
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: MediaQuery.of(context).size.width * 0.65, // 65% width - extends further
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/images/archetypes/$_archetypeId.png'),
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                      // Very gradual fade on left edge - starts at 60%
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.transparent,
                              const Color(0xFF2a3038).withOpacity(0.3),
                              const Color(0xFF2a3038).withOpacity(0.7),
                              const Color(0xFF2a3038),
                            ],
                            stops: const [0.0, 0.3, 0.5, 0.65, 0.8, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Chat area overlay on left side
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: MediaQuery.of(context).size.width * 0.65, // 65% for chat
                    child: SafeArea(
                      right: false,
                      child: Column(
                        children: [
                          // No spacing - KAI at very top
                          // Header with name and weather
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(LucideIcons.triangle, color: AurealColors.hyperGold, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      _companionName,
                                      style: GoogleFonts.spaceGrotesk(
                                        color: AurealColors.hyperGold,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                // Weather under companion name
                                if (_weatherTemp != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          LucideIcons.cloudSun,
                                          color: Colors.white.withOpacity(0.8),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _weatherTemp!,
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (_weatherCondition != null) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            _weatherCondition!,
                                            style: GoogleFonts.inter(
                                              color: Colors.white.withOpacity(0.75),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                        if (_weatherHighLow != null) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            _weatherHighLow!,
                                            style: GoogleFonts.inter(
                                              color: Colors.white.withOpacity(0.6),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Messages
                          Expanded(
                            child: Padding(
                              // Keep text below avatar face/orb in all modes
                              padding: EdgeInsets.only(
                                top: _avatarDisplayMode == AvatarDisplaySettings.modeOrb
                                    ? 0 // Text moved up
                                    : 0, // Text moved up
                              ),
                              child: ListView.builder(
                                controller: _scrollController,
                                reverse: true,
                                // Internal padding: bottom for input area, top small
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
                                itemCount: _messages.length > 25 ? 25 : _messages.length,
                              itemBuilder: (context, index) {
                                final messageIndex = _messages.length - 1 - index;
                                final msg = _messages[messageIndex];
                                final isUser = msg['isUser'] as bool;
                                final message = msg['message'] as String;
                                
                                // Conversation mode: glassy pill-shaped bubbles
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(32),
                                      child: BackdropFilter(
                                        // REMOVED BLUR completely for maximum visibility
                                        filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context).size.width * 0.55,
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: isUser 
                                                  ? [
                                                      AurealColors.plasmaCyan.withOpacity(0.08), // Extremely transparent
                                                      AurealColors.plasmaCyan.withOpacity(0.04),
                                                    ]
                                                  : [
                                                      Colors.white.withOpacity(0.08),  // More transparent for AI
                                                      Colors.white.withOpacity(0.04),  // More transparent for AI
                                                    ],
                                            ),
                                            borderRadius: BorderRadius.circular(32),
                                            border: Border.all(
                                              color: isUser 
                                                  ? AurealColors.plasmaCyan.withOpacity(0.5)
                                                  : Colors.white.withOpacity(0.25),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: (isUser ? AurealColors.plasmaCyan : Colors.white).withOpacity(0.1),
                                                blurRadius: 16,
                                                spreadRadius: 0,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            message,
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 15,
                                              height: 1.5,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                          // Typing indicator removed - shown in input box instead
                          // Remove input from here - it will be full width
                        ],
                      ),
                    ),
                  ),
                  // Full-width input area at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: _buildInputArea(),
                    ),
                  ),
                ],
              )
            else
              // Plain color background for icon mode
              Container(
                color: _backgroundColor == AvatarDisplaySettings.colorWhite 
                    ? Colors.white 
                    : Colors.black,
              ),

            // 3. Content - Hide when in clock or conversation mode (unless temporarily showing chat)
            if (_avatarDisplayMode != AvatarDisplaySettings.modeClock && 
                _avatarDisplayMode != AvatarDisplaySettings.modeConversation || 
                _showChatOverClock)
            SafeArea(
              top: false, // Disable top SafeArea to handle it manually with padding
              child: Column(
                children: [
                  const SizedBox(height: 60), // Added manual spacing for header
                  _buildHeader(),
                  Expanded(
                    child: Padding(
                      // Keep text below avatar face/orb in all modes
                      padding: EdgeInsets.only(
                        top: _avatarDisplayMode == AvatarDisplaySettings.modeOrb
                            ? 0 // Text moved up
                            : 0, // Text moved up
                      ),
                      child: ListView.builder(
                        controller: _scrollController,
                        reverse: true, // Start at bottom like a proper chat app
                        // Internal padding: bottom for input area, top small
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
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
                ),

                  // Show "Back to Clock" button when chat is shown over clock mode
                  if (_showChatOverClock && _avatarDisplayMode == AvatarDisplaySettings.modeClock)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () => setState(() => _showChatOverClock = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.clock, color: Colors.cyan, size: 16),
                              const SizedBox(width: 8),
                              Text('Back to Clock', style: TextStyle(color: Colors.cyan, fontSize: 14)),
                            ],
                          ),
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
          // Left side: Name + Weather
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar name
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.triangle, color: AurealColors.hyperGold, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _companionName,
                    style: GoogleFonts.spaceGrotesk(
                      color: AurealColors.hyperGold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              // Weather next to name
              if (_weatherTemp != null) ...[
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.cloudSun,
                        color: Colors.white.withOpacity(0.8),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _weatherTemp!,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_weatherHighLow != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          _weatherHighLow!,
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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
    return SizedBox(
      height: 60, // Fixed height for chips
      child: Align(
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
          // Avatar for AI messages - only in Icon mode (orb shows at top, fullscreen has avatar background)
          if (!isUser && _avatarDisplayMode == AvatarDisplaySettings.modeIcon)
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 4),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFF06B6D4), // Cyan
                      Color(0xFF8B5CF6), // Purple
                      Color(0xFFF59E0B), // Amber
                      Color(0xFF10B981), // Emerald
                      Color(0xFF06B6D4), // Back to cyan
                    ],
                    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0F172A),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        backgroundImage: (_stateService?.avatarUrl != null && _stateService!.avatarUrl!.startsWith('http'))
                            ? NetworkImage(_stateService!.avatarUrl!) as ImageProvider
                            : AssetImage(_stateService?.avatarUrl ?? 'assets/images/archetypes/$_archetypeId.png'),
                        onBackgroundImageError: (_, __) {},
                        child: (_stateService?.avatarUrl != null) 
                            ? null // Don't show icon if we have a custom avatar
                            : const Icon(LucideIcons.sparkles, size: 24, color: Colors.black),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Message bubble
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.all(12),
              decoration: isUser 
                  ? BoxDecoration(
                      color: Colors.white.withOpacity(0.15), // Light semi-transparent
                      borderRadius: BorderRadius.circular(16).copyWith(bottomRight: Radius.zero),
                      border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
                    )
                  : BoxDecoration(
                      color: Colors.white.withOpacity(0.1), // Very light semi-transparent for AI
                      borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: Radius.zero),
                    ),
              child: isUser 
                  ? Text(
                      message,
                      style: GoogleFonts.inter(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Colors.black,
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
    // FIX: Calculate isDark based on actual background settings
    final isLightBackground = (_avatarDisplayMode == AvatarDisplaySettings.modeIcon || 
                               _avatarDisplayMode == AvatarDisplaySettings.modeOrb ||
                               _avatarDisplayMode == AvatarDisplaySettings.modePortrait) && 
                              _backgroundColor == AvatarDisplaySettings.colorWhite;
    final isDark = !isLightBackground;
    final textColor = isDark ? Colors.white : Colors.black;
    final strongColor = isDark ? Colors.white : Colors.black;

    return MarkdownBody(
      data: message,
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.inter(
          color: textColor,
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
          color: strongColor,
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

  void _showInputIconsHelp(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AurealColors.carbon : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(LucideIcons.info, color: AurealColors.plasmaCyan, size: 20),
            const SizedBox(width: 12),
            Text(
              'INPUT CONTROLS',
              style: GoogleFonts.spaceGrotesk(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIconHelpRow(LucideIcons.wand2, AurealColors.hyperGold, 'Rewrite', 
              'Use Apple Intelligence to improve your text', isDark),
            const SizedBox(height: 12),
            _buildIconHelpRow(LucideIcons.mic, isDark ? Colors.white70 : Colors.grey[700]!, 'Voice Input', 
              'Speak your message instead of typing', isDark),
            const SizedBox(height: 12),
            _buildIconHelpRow(LucideIcons.volume2, isDark ? Colors.white70 : Colors.grey[700]!, 'Mute/Unmute', 
              'Toggle voice responses on or off', isDark),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'GOT IT',
              style: GoogleFonts.spaceGrotesk(
                color: AurealColors.plasmaCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconHelpRow(IconData icon, Color iconColor, String title, String description, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white60 : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildInputArea() {
  // FIX: Calculate isDark based on actual background settings, not inherited Theme
  // This ensures icons adapt correctly even if parent Theme context is mismatched
  final isLightBackground = (_avatarDisplayMode == AvatarDisplaySettings.modeIcon || 
                             _avatarDisplayMode == AvatarDisplaySettings.modeOrb ||
                             _avatarDisplayMode == AvatarDisplaySettings.modePortrait) && 
                            _backgroundColor == AvatarDisplaySettings.colorWhite;
  final isDark = !isLightBackground;
  
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Text field - now full width
              TextField(
                controller: _controller,
                enabled: true,
                style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black),
                cursorColor: isDark ? Colors.white : Colors.black,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.transparent,
                  hintText: _isTyping ? '$_companionName thinking...' : 'Type a message...',
                  hintStyle: GoogleFonts.inter(
                    color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
              const SizedBox(height: 8),
              // Icons row - now below text field
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rewrite button (Apple Intelligence)
                  GestureDetector(
                    onTap: _handleRewrite,
                    child: Icon(
                      LucideIcons.wand2,
                      color: _controller.text.isNotEmpty 
                          ? AurealColors.hyperGold 
                          : (isDark ? Colors.white70 : Colors.grey[700]),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Microphone button
                  GestureDetector(
                    onTap: _handleVoiceInput,
                    child: Icon(
                      _isListening ? LucideIcons.micOff : LucideIcons.mic,
                      color: _isListening 
                          ? AurealColors.plasmaCyan 
                          : (isDark ? Colors.white70 : Colors.grey[700]),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Mute button
                  GestureDetector(
                    onTap: () {
                      setState(() => _isMuted = !_isMuted);
                    },
                    child: Icon(
                      _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                      color: _isMuted 
                          ? Colors.red 
                          : (isDark ? Colors.white70 : Colors.grey[700]),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 32), // Extra space before info
                  // Info button - explains icons
                  GestureDetector(
                    onTap: () => _showInputIconsHelp(isDark),
                    child: Icon(
                      LucideIcons.info,
                      color: isDark ? Colors.white38 : Colors.grey[500],
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
