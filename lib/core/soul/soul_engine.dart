import 'package:flutter/foundation.dart';
import 'room_reading_engine.dart';
import 'adaptive_personality.dart';
import 'feedback_learning.dart';
import 'boundary_service.dart';
import 'grounding_service.dart';
import 'speed_optimizer.dart';
import '../emotion/emotional_state_service.dart';
import '../emotion/emotional_pattern_tracker.dart';
import '../memory/unified_memory_service.dart';
import '../personality/personality_service.dart';

/// Soul Engine - The beating heart of Aeliana's personality
/// 
/// This is the main orchestrator that combines all soul components:
/// - RoomReadingEngine: Understands context and user emotional state
/// - AdaptivePersonality: Evolving Big Five traits
/// - FeedbackLearning: Learns from user reactions
/// - BoundaryService: Maintains healthy boundaries
/// - GroundingService: Prevents hallucinations
/// - SpeedOptimizer: Ensures sub-second responses
class SoulEngine {
  // Core services
  final EmotionalStateService emotionalService;
  final UnifiedMemoryService memoryService;
  final String archetypeId;
  
  // Soul components
  late final RoomReadingEngine roomReader;
  late final AdaptivePersonality personality;
  late final FeedbackLearning feedbackLearner;
  late final BoundaryService boundaries;
  late final GroundingService grounder;
  late final SpeedOptimizer speedOpt;
  late final EmotionalPatternTracker emotionalPatterns;
  
  // Cached context for speed
  String? _cachedPersonalityPrompt;
  DateTime? _lastCacheTime;
  static const _cacheExpiry = Duration(minutes: 5);
  
  SoulEngine({
    required this.emotionalService,
    required this.memoryService,
    required this.archetypeId,
  }) {
    _initializeComponents();
  }
  
  void _initializeComponents() {
    roomReader = RoomReadingEngine(emotionalService: emotionalService);
    personality = AdaptivePersonality(baseArchetypeId: archetypeId);
    feedbackLearner = FeedbackLearning();
    boundaries = BoundaryService();
    grounder = GroundingService(memoryService: memoryService);
    speedOpt = SpeedOptimizer();
    emotionalPatterns = EmotionalPatternTracker();
  }
  
  /// Process an incoming user message and prepare the AI context
  /// This is the main entry point for soul-driven responses
  Future<SoulContext> processMessage(String userMessage) async {
    final stopwatch = Stopwatch()..start();
    
    // 1. Read the room - understand user state
    final roomReading = await roomReader.readRoom(
      message: userMessage,
      timeOfDay: DateTime.now(),
    );
    debugPrint('🧠 Room reading: ${roomReading.summary} (${stopwatch.elapsedMilliseconds}ms)');
    
    // 2. Check boundaries first
    final boundaryCheck = boundaries.checkMessage(userMessage);
    if (boundaryCheck.triggered) {
      debugPrint('⚠️ Boundary triggered: ${boundaryCheck.type}');
      return SoulContext(
        personalityPrompt: '',
        groundedContext: '',
        styleModifiers: {},
        boundaryResponse: boundaryCheck.response,
        processingTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
    
    // 3. Get adaptive personality prompt (cached for speed)
    final personalityPrompt = await _getPersonalityPrompt(roomReading);
    debugPrint('🎭 Personality loaded (${stopwatch.elapsedMilliseconds}ms)');
    
    // 4. Get grounded context (memories, facts)
    final groundedContext = await grounder.getGroundedContext(userMessage);
    debugPrint('📚 Grounding complete (${stopwatch.elapsedMilliseconds}ms)');
    
    // 5. Calculate style modifiers
    final styleModifiers = _calculateStyleModifiers(roomReading);
    
    stopwatch.stop();
    debugPrint('⚡ Soul processing complete: ${stopwatch.elapsedMilliseconds}ms');
    
    return SoulContext(
      personalityPrompt: personalityPrompt,
      groundedContext: groundedContext,
      styleModifiers: styleModifiers,
      roomReading: roomReading,
      processingTimeMs: stopwatch.elapsedMilliseconds,
    );
  }
  
  /// Record user feedback on a response
  void recordFeedback(String messageId, bool positive) {
    feedbackLearner.recordFeedback(messageId, positive);
    
    // Also update emotional state
    emotionalService.updateMood(
      sentimentScore: positive ? 0.3 : -0.3,
      environmentalModifier: 0,
      isPositive: positive,
    );
    
    // Evolve personality slightly
    personality.evolveFromFeedback(positive);
  }
  
  /// Get the complete AI system prompt including soul context
  Future<String> getCompleteSystemPrompt(String userMessage) async {
    final context = await processMessage(userMessage);
    
    if (context.boundaryResponse != null) {
      return context.boundaryResponse!;
    }
    
    final buffer = StringBuffer();
    
    // Base personality
    buffer.writeln(context.personalityPrompt);
    buffer.writeln();
    
    // Emotional state
    buffer.writeln(emotionalService.getEmotionalContext());
    
    // Grounded memories
    if (context.groundedContext.isNotEmpty) {
      buffer.writeln('[RELEVANT MEMORIES]');
      buffer.writeln(context.groundedContext);
      buffer.writeln();
    }
    
    // Style modifiers
    if (context.roomReading != null) {
      buffer.writeln('[RESPONSE STYLE GUIDANCE]');
      if (context.roomReading!.userSeemsSad) {
        buffer.writeln('- User seems down. Be extra warm and supportive.');
      }
      if (context.roomReading!.userSeemsUrgent) {
        buffer.writeln('- User seems rushed. Be concise and direct.');
      }
      if (context.roomReading!.isLateNight) {
        buffer.writeln('- It\'s late. Be calming and gentle.');
      }
      if (context.roomReading!.userSeemsExcited) {
        buffer.writeln('- User is excited! Match their energy!');
      }
    }
    
    return buffer.toString();
  }
  
  Future<String> _getPersonalityPrompt(RoomReading reading) async {
    // Check cache
    if (_cachedPersonalityPrompt != null && 
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheExpiry) {
      return _cachedPersonalityPrompt!;
    }
    
    // Get base archetype
    final archetype = PersonalityService.getById(archetypeId);
    
    // Get adaptive modifiers
    final adaptivePrompt = personality.getPersonalityPrompt();
    
    // Combine
    final prompt = '''
${archetype.promptInstruction}

[ADAPTIVE TRAITS]
$adaptivePrompt

[LEARNED PREFERENCES]
${feedbackLearner.getPreferenceSummary()}
''';
    
    _cachedPersonalityPrompt = prompt;
    _lastCacheTime = DateTime.now();
    
    return prompt;
  }
  
  Map<String, double> _calculateStyleModifiers(RoomReading reading) {
    return {
      'warmth': reading.userSeemsSad ? 1.3 : 1.0,
      'conciseness': reading.userSeemsUrgent ? 1.5 : 1.0,
      'energy': reading.isLateNight ? 0.7 : (reading.userSeemsExcited ? 1.3 : 1.0),
      'humor': reading.userSeemsDown ? 0.5 : 1.0,
    };
  }
  
  /// Prefetch context for faster response (call on app open)
  Future<void> prefetchContext() async {
    debugPrint('🚀 Prefetching soul context...');
    final stopwatch = Stopwatch()..start();
    
    // Warm up caches
    await _getPersonalityPrompt(RoomReading.neutral());
    await grounder.prefetch();
    
    debugPrint('✅ Soul prefetch complete: ${stopwatch.elapsedMilliseconds}ms');
  }
}

/// Context generated by the Soul Engine for a response
class SoulContext {
  final String personalityPrompt;
  final String groundedContext;
  final Map<String, double> styleModifiers;
  final RoomReading? roomReading;
  final String? boundaryResponse;
  final int processingTimeMs;
  
  SoulContext({
    required this.personalityPrompt,
    required this.groundedContext,
    required this.styleModifiers,
    this.roomReading,
    this.boundaryResponse,
    required this.processingTimeMs,
  });
}
