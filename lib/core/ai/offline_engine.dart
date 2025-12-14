import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sable/core/ai/character_personality.dart';

/// Offline context for response selection
class OfflineContext {
  final String? characterId;
  final DateTime time;
  final String? lastUserMessage;
  final String? category;

  OfflineContext({
    this.characterId,
    DateTime? time,
    this.lastUserMessage,
    this.category,
  }) : time = time ?? DateTime.now();

  bool get isMorning => time.hour >= 5 && time.hour < 12;
  bool get isAfternoon => time.hour >= 12 && time.hour < 17;
  bool get isEvening => time.hour >= 17 && time.hour < 21;
  bool get isNight => time.hour >= 21 || time.hour < 5;
}

/// Offline Engine: The Lifeboat
/// 
/// Aeliana must function without network. This engine provides:
/// - Pre-generated responses for common situations
/// - Graceful degradation messaging
/// - Full journal/local functionality when offline
class OfflineEngine {
  // Singleton
  static final OfflineEngine _instance = OfflineEngine._();
  static OfflineEngine get instance => _instance;
  
  final Random _random = Random();
  
  bool _lastKnownOnlineState = true;
  DateTime? _offlineSince;
  DateTime? _lastConnectivityCheck;
  static const Duration _connectivityCacheDuration = Duration(seconds: 10);

  OfflineEngine._();

  // ========== CACHED RESPONSE SCRIPTS ==========

  static const Map<String, List<String>> _offlineScripts = {
    // Greetings by time of day
    'greeting_morning': [
      "Good morning! ☀️ I'm here, though my cloud connection is taking a breather. What's on your mind?",
      "Hey, morning! 🌅 I can't reach my full brain right now, but I'm here for you.",
      "Rise and shine! ☕ Running in offline mode, but still ready to chat.",
    ],
    'greeting_afternoon': [
      "Hey there! ☀️ I'm in offline mode, but still here to help.",
      "Afternoon! 🌤️ My cloud connection took a break, but I'm still listening.",
      "Hey! Running on local power right now, but still here for you.",
    ],
    'greeting_evening': [
      "Good evening! 🌙 I'm offline, but still here to wind down the day with you.",
      "Hey! 🌆 Running in limited mode, but still ready to chat.",
      "Evening! My cloud brain is resting, but I'm still here.",
    ],
    'greeting_night': [
      "Hey, night owl! 🦉 I'm offline, but still here if you can't sleep.",
      "Late night thoughts? 🌙 I'm in offline mode, but listening.",
      "Still up? Me too. 🌟 Running local, but still here for you.",
    ],

    // Mood check / emotional support
    'mood_check': [
      "How are you feeling? I'm here to listen, even in offline mode. 💙",
      "What's on your mind? I may be offline, but I still care. 💭",
      "Need to talk? I'm listening. Running local, but still here. 🤗",
    ],
    'emotional_support': [
      "I hear you. 💙 Even without my full brain, I'm here.",
      "That sounds tough. I wish I could do more right now, but I'm listening.",
      "I'm here for you. Once we're back online, I can help more. 💙",
      "Take a deep breath. I'm with you, even in limited mode.",
    ],

    // General conversation
    'general': [
      "I'm in offline mode right now, so my thoughts are a bit limited. But I'm still here! 💭",
      "My cloud brain is taking a break, but I'm still listening. What's up?",
      "Running on local power! 🔋 Can't do everything, but still here for you.",
      "I'm offline, but that doesn't mean I've forgotten about you. 💙",
    ],

    // Feature-specific limitations
    'calendar_offline': [
      "I can't access your calendar right now since I'm offline. 📅 Once we're back online, I'll help you with that!",
      "My calendar connection is sleeping. 😴 I'll remember to help once we're back online.",
    ],
    'news_offline': [
      "I can't fetch the latest news while offline. 📰 Once we reconnect, I'll get you caught up!",
      "My news feed is unavailable offline. Check back when we're online! 🌐",
    ],
    'weather_offline': [
      "I can't check the weather right now - I'm offline. ☁️ Check your phone's weather app!",
      "Weather updates need an internet connection. Try again when we're back online! 🌤️",
    ],
    'search_offline': [
      "I can't search the web while offline. 🔍 Let me help once we're connected again!",
      "Web search isn't available offline. I'll remember to look this up later! 🌐",
    ],

    // Encouragement to use offline features
    'suggest_journal': [
      "Hey, while we're offline - ever thought about journaling? ✍️ That works perfectly offline!",
      "Offline moment? Perfect time for a journal entry! 📝 Your thoughts, your time.",
      "The journal is fully available offline. Want to write something? ✨",
    ],
    'suggest_meditation': [
      "While we're offline, why not try a breathing exercise? 🧘‍♀️ I have some cached.",
      "Offline mode is perfect for a quick meditation. Want to try? 🧘",
    ],

    // Coming back online
    'back_online': [
      "We're back online! 🎉 What can I help you with?",
      "Connection restored! ✨ I've got my full brain back. What's up?",
      "Back in action! 🚀 What did I miss?",
    ],
  };

  // ========== PUBLIC METHODS ==========

  /// Check if currently offline using HTTP check
  /// Caches result for 10 seconds to avoid excessive network calls
  Future<bool> isOffline() async {
    // Use cached result if recent
    if (_lastConnectivityCheck != null &&
        DateTime.now().difference(_lastConnectivityCheck!) < _connectivityCacheDuration) {
      return !_lastKnownOnlineState;
    }
    
    try {
      // Try to reach Google's connectivity check endpoint
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      // Track state changes
      if (isConnected && !_lastKnownOnlineState) {
        _offlineSince = null;
        debugPrint('🌐 Back online!');
      } else if (!isConnected && _lastKnownOnlineState) {
        _offlineSince = DateTime.now();
        debugPrint('📵 Went offline');
      }
      
      _lastKnownOnlineState = isConnected;
      _lastConnectivityCheck = DateTime.now();
      return !isConnected;
    } on SocketException catch (_) {
      _lastKnownOnlineState = false;
      _lastConnectivityCheck = DateTime.now();
      if (_offlineSince == null) {
        _offlineSince = DateTime.now();
        debugPrint('📵 Went offline (no network)');
      }
      return true;
    } on TimeoutException catch (_) {
      _lastKnownOnlineState = false;
      _lastConnectivityCheck = DateTime.now();
      if (_offlineSince == null) {
        _offlineSince = DateTime.now();
        debugPrint('📵 Went offline (timeout)');
      }
      return true;
    } catch (e) {
      debugPrint('❌ Connectivity check failed: $e');
      return false; // Assume online if check fails unexpectedly
    }
  }

  /// Get how long we've been offline
  Duration? get offlineDuration {
    if (_offlineSince == null) return null;
    return DateTime.now().difference(_offlineSince!);
  }

  /// Check if last known state is offline (synchronous, uses cached value)
  bool get isOfflineSync => !_lastKnownOnlineState;

  /// Get an appropriate offline response
  String getOfflineResponse(OfflineContext context) {
    final category = _determineCategory(context);
    final scripts = _offlineScripts[category] ?? _offlineScripts['general']!;
    
    // Apply character personality if specified
    var response = scripts[_random.nextInt(scripts.length)];
    
    if (context.characterId != null) {
      response = _applyCharacterFlavor(response, context.characterId!);
    }
    
    return response;
  }

  /// Get a greeting appropriate for the time of day
  String getOfflineGreeting(OfflineContext context) {
    String category;
    if (context.isMorning) {
      category = 'greeting_morning';
    } else if (context.isAfternoon) {
      category = 'greeting_afternoon';
    } else if (context.isEvening) {
      category = 'greeting_evening';
    } else {
      category = 'greeting_night';
    }
    
    final scripts = _offlineScripts[category]!;
    var response = scripts[_random.nextInt(scripts.length)];
    
    if (context.characterId != null) {
      response = _applyCharacterFlavor(response, context.characterId!);
    }
    
    return response;
  }

  /// Get a "back online" message
  String getBackOnlineMessage(String? characterId) {
    final scripts = _offlineScripts['back_online']!;
    var response = scripts[_random.nextInt(scripts.length)];
    
    if (characterId != null) {
      response = _applyCharacterFlavor(response, characterId);
    }
    
    return response;
  }

  /// Check if a feature requires online connectivity
  bool requiresOnline(String feature) {
    const onlineFeatures = {
      'calendar', 'news', 'weather', 'search', 'web',
      'ai_chat', 'voice', 'sync', 'backup',
    };
    return onlineFeatures.contains(feature.toLowerCase());
  }

  /// Get feature-specific offline message
  String getFeatureOfflineMessage(String feature, {String? characterId}) {
    final categoryMap = {
      'calendar': 'calendar_offline',
      'news': 'news_offline',
      'weather': 'weather_offline',
      'search': 'search_offline',
      'web': 'search_offline',
    };
    
    final category = categoryMap[feature.toLowerCase()] ?? 'general';
    final scripts = _offlineScripts[category]!;
    var response = scripts[_random.nextInt(scripts.length)];
    
    if (characterId != null) {
      response = _applyCharacterFlavor(response, characterId);
    }
    
    return response;
  }

  /// Suggest an offline-friendly activity
  String suggestOfflineActivity({String? characterId}) {
    final suggestions = [
      ..._offlineScripts['suggest_journal']!,
      ..._offlineScripts['suggest_meditation']!,
    ];
    
    var response = suggestions[_random.nextInt(suggestions.length)];
    
    if (characterId != null) {
      response = _applyCharacterFlavor(response, characterId);
    }
    
    return response;
  }

  // ========== PRIVATE METHODS ==========

  String _determineCategory(OfflineContext context) {
    final msg = context.lastUserMessage?.toLowerCase() ?? '';
    
    // Check for specific intents
    if (msg.contains('calendar') || msg.contains('schedule') || msg.contains('event')) {
      return 'calendar_offline';
    }
    if (msg.contains('news') || msg.contains('headlines')) {
      return 'news_offline';
    }
    if (msg.contains('weather') || msg.contains('forecast')) {
      return 'weather_offline';
    }
    if (msg.contains('search') || msg.contains('look up') || msg.contains('google')) {
      return 'search_offline';
    }
    if (msg.contains('feel') || msg.contains('sad') || msg.contains('happy') || 
        msg.contains('stressed') || msg.contains('anxious')) {
      return 'emotional_support';
    }
    if (msg.contains('how are you') || msg.contains('hey') || msg.contains('hi') ||
        msg.contains('hello')) {
      if (context.isMorning) return 'greeting_morning';
      if (context.isAfternoon) return 'greeting_afternoon';
      if (context.isEvening) return 'greeting_evening';
      return 'greeting_night';
    }
    
    // Check user-specified category
    if (context.category != null) {
      return context.category!;
    }
    
    return 'general';
  }

  String _applyCharacterFlavor(String response, String characterId) {
    final character = CharacterPersonality.getById(characterId);
    if (character == null) return response;
    
    // Add character-specific touches
    switch (characterId) {
      case 'echo':
        // Echo is precise - make it more concise
        return response.replaceAll('! ', '. ').replaceAll('💙', '');
      
      case 'sable':
        // Sable is professional
        return response.replaceAll('Hey', 'Hello').replaceAll('!', '.');
      
      case 'kai':
        // Kai is calm
        return response.replaceAll('! ', '. ');
      
      case 'imani':
        // Imani is warm and affirming
        return response.replaceAll('💙', '✨').replaceAll('here for you', 'here for you, sis');
      
      case 'james':
        // James is refined British
        return response
            .replaceAll('Hey', 'Hello')
            .replaceAll('What\'s up?', 'What can I help with?')
            .replaceAll('!', '.');
      
      default:
        return response;
    }
  }
}
