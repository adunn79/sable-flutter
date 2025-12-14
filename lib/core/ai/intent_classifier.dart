import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'providers/gemini_provider.dart';
import 'latency_monitor.dart';

/// Intent types for routing to the optimal AI model
enum IntentType {
  /// Emotional support, bonding, personal conversations
  /// Best Model: Claude
  bonding,

  /// Spicy, edgy, roast-me humor
  /// Best Model: Grok (with safety filter)
  spicy,

  /// Memory recall, past conversations, "remember when"
  /// Best Model: Gemini (long context)
  deepRecall,

  /// Technical, coding, debugging, math
  /// Best Model: DeepSeek
  technical,

  /// Quick facts, simple queries, lists
  /// Best Model: GPT-4o
  quickFacts,

  /// Current events, news, real-time info
  /// Best Model: Gemini + Grounding
  currentEvents,

  /// Deep research, thorough analysis
  /// Best Model: Gemini + Grounding (extended)
  deepResearch,

  /// Fact checking, claim verification
  /// Best Model: Gemini + Grounding
  factCheck,

  /// Settings or app control intent
  /// Best Model: Local (no AI needed)
  settingsControl,

  /// Calendar operations
  /// Best Model: GPT-4o (tool use)
  calendar,

  /// Default fallback
  /// Best Model: Claude
  general,
}

/// Result of intent classification
class IntentResult {
  final IntentType intent;
  final double confidence;
  final String suggestedModel;
  final int latencyMs;
  final String? reasoning;

  const IntentResult({
    required this.intent,
    required this.confidence,
    required this.suggestedModel,
    required this.latencyMs,
    this.reasoning,
  });

  @override
  String toString() =>
      'IntentResult($intent, confidence: ${(confidence * 100).toStringAsFixed(1)}%, '
      'model: $suggestedModel, latency: ${latencyMs}ms)';
}

/// Fast intent classification for optimal model routing
/// Target: <400ms classification time
class IntentClassifier {
  final GeminiProvider _geminiProvider;
  static const String _classificationModel = 'gemini-2.0-flash';
  
  // Singleton pattern
  static IntentClassifier? _instance;
  static IntentClassifier get instance {
    _instance ??= IntentClassifier._();
    return _instance!;
  }

  IntentClassifier._() : _geminiProvider = GeminiProvider();

  /// Classify user intent for optimal model routing
  /// Returns IntentResult with classification and latency tracking
  Future<IntentResult> classify(String userMessage) async {
    final requestId = 'intent_${DateTime.now().millisecondsSinceEpoch}';
    LatencyMonitor.instance.startTimer(requestId, 'intent_classifier');
    
    try {
      // Quick pattern matching for obvious intents (no AI needed)
      final quickResult = _quickPatternMatch(userMessage);
      if (quickResult != null) {
        final latency = LatencyMonitor.instance.endTimer(requestId);
        debugPrint('⚡ Quick intent match: ${quickResult.intent} (${latency}ms)');
        return IntentResult(
          intent: quickResult.intent,
          confidence: quickResult.confidence,
          suggestedModel: quickResult.suggestedModel,
          latencyMs: latency,
          reasoning: 'Pattern match',
        );
      }

      // AI-based classification for complex intents
      final classificationPrompt = '''
Classify this user message for optimal AI model routing.

User Message: "$userMessage"

Return ONLY valid JSON in this exact format:
{
  "intent": "INTENT_TYPE",
  "confidence": 0.95,
  "reasoning": "brief explanation"
}

Intent Types (choose ONE):
- BONDING: Emotional support, personal chat, feelings, relationships, "how are you", "I'm feeling..."
- SPICY: Edgy humor, "roast me", controversial opinions, playful sarcasm
- DEEP_RECALL: Memory questions, "remember when", "what did I say about", past conversations
- TECHNICAL: Code, debugging, math, logic puzzles, "how do I code", "fix this"
- QUICK_FACTS: Simple questions, definitions, "what is", "who is", lists, trivia
- CURRENT_EVENTS: News, "what's happening", recent events, weather, stocks
- DEEP_RESEARCH: "Tell me more", "dig deeper", thorough analysis, research requests
- FACT_CHECK: "Is it true that", verify claims, debunk
- CALENDAR: Schedule, events, "add to calendar", "what's on my calendar"
- GENERAL: Anything else

Return ONLY the JSON, nothing else.
''';

      final response = await _geminiProvider.generateResponse(
        prompt: classificationPrompt,
        systemPrompt: 'You are a fast intent classifier. Respond only with JSON.',
        modelId: _classificationModel,
      );

      final latency = LatencyMonitor.instance.endTimer(requestId);

      // Parse response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch == null) {
        debugPrint('⚠️ Intent classifier: Invalid JSON response');
        return _fallbackResult(latency);
      }

      final parsed = jsonDecode(jsonMatch.group(0)!);
      final intentStr = (parsed['intent'] as String).toUpperCase();
      final confidence = (parsed['confidence'] as num?)?.toDouble() ?? 0.8;
      final reasoning = parsed['reasoning'] as String?;

      final intent = _parseIntentType(intentStr);
      final model = _getModelForIntent(intent);

      debugPrint('🎯 Intent classified: $intent (${(confidence * 100).toStringAsFixed(0)}%) → $model (${latency}ms)');

      return IntentResult(
        intent: intent,
        confidence: confidence,
        suggestedModel: model,
        latencyMs: latency,
        reasoning: reasoning,
      );
    } catch (e) {
      debugPrint('❌ Intent classification error: $e');
      final latency = LatencyMonitor.instance.endTimer(requestId);
      return _fallbackResult(latency);
    }
  }

  /// Quick pattern matching for obvious intents (no AI call needed)
  IntentResult? _quickPatternMatch(String message) {
    final lower = message.toLowerCase().trim();

    // Settings control patterns
    if (_matchesAny(lower, [
      'turn on', 'turn off', 'enable', 'disable',
      'enable dark mode', 'disable notifications',
    ])) {
      return const IntentResult(
        intent: IntentType.settingsControl,
        confidence: 0.95,
        suggestedModel: 'local',
        latencyMs: 1,
      );
    }

    // Calendar patterns
    if (_matchesAny(lower, [
      'add to calendar', 'schedule', 'create event',
      "what's on my calendar", 'my schedule', 'upcoming events',
      'remind me', 'set a reminder',
    ])) {
      return const IntentResult(
        intent: IntentType.calendar,
        confidence: 0.90,
        suggestedModel: 'GPT4O',
        latencyMs: 1,
      );
    }

    // Current events patterns
    if (_matchesAny(lower, [
      'news', "what's happening", "today's headlines",
      'current events', 'latest on', 'breaking',
    ])) {
      return const IntentResult(
        intent: IntentType.currentEvents,
        confidence: 0.90,
        suggestedModel: 'GEMINI',
        latencyMs: 1,
      );
    }

    // Deep research patterns
    if (_matchesAny(lower, [
      'tell me more', 'dig deeper', 'more details',
      'explain further', 'research this', 'elaborate',
    ])) {
      return const IntentResult(
        intent: IntentType.deepResearch,
        confidence: 0.90,
        suggestedModel: 'DEEP_RESEARCH',
        latencyMs: 1,
      );
    }

    // Roast/spicy patterns
    if (_matchesAny(lower, [
      'roast me', 'be mean', 'no filter', 'grok mode',
      'unfiltered', 'tell it like it is',
    ])) {
      return const IntentResult(
        intent: IntentType.spicy,
        confidence: 0.90,
        suggestedModel: 'GROK',
        latencyMs: 1,
      );
    }

    // Technical patterns
    if (_matchesAny(lower, [
      'code', 'debug', 'programming', 'function',
      'algorithm', 'syntax', 'compile', 'typescript', 'python',
      'javascript', 'dart', 'flutter', 'swift',
    ])) {
      return const IntentResult(
        intent: IntentType.technical,
        confidence: 0.85,
        suggestedModel: 'DEEPSEEK',
        latencyMs: 1,
      );
    }

    // Fact check patterns
    if (_matchesAny(lower, [
      'is it true', 'fact check', 'verify',
      'is this real', 'debunk', 'actually true',
    ])) {
      return const IntentResult(
        intent: IntentType.factCheck,
        confidence: 0.90,
        suggestedModel: 'FACT_CHECK',
        latencyMs: 1,
      );
    }

    // Memory/recall patterns
    if (_matchesAny(lower, [
      'remember when', 'what did i say', 'last time',
      'we talked about', 'you mentioned', 'recall',
    ])) {
      return const IntentResult(
        intent: IntentType.deepRecall,
        confidence: 0.85,
        suggestedModel: 'GEMINI',
        latencyMs: 1,
      );
    }

    // Emotional/bonding patterns (very common, check last)
    if (_matchesAny(lower, [
      'how are you', "i'm feeling", 'i feel',
      "i'm sad", "i'm happy", "i'm stressed",
      'need to talk', 'having a hard time', 'anxious',
      'love you', 'miss you', 'thank you',
    ])) {
      return const IntentResult(
        intent: IntentType.bonding,
        confidence: 0.85,
        suggestedModel: 'CLAUDE',
        latencyMs: 1,
      );
    }

    return null; // No quick match, use AI classification
  }

  bool _matchesAny(String text, List<String> patterns) {
    for (final pattern in patterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  IntentType _parseIntentType(String str) {
    switch (str) {
      case 'BONDING':
        return IntentType.bonding;
      case 'SPICY':
        return IntentType.spicy;
      case 'DEEP_RECALL':
        return IntentType.deepRecall;
      case 'TECHNICAL':
        return IntentType.technical;
      case 'QUICK_FACTS':
        return IntentType.quickFacts;
      case 'CURRENT_EVENTS':
        return IntentType.currentEvents;
      case 'DEEP_RESEARCH':
        return IntentType.deepResearch;
      case 'FACT_CHECK':
        return IntentType.factCheck;
      case 'CALENDAR':
        return IntentType.calendar;
      case 'SETTINGS_CONTROL':
        return IntentType.settingsControl;
      default:
        return IntentType.general;
    }
  }

  String _getModelForIntent(IntentType intent) {
    switch (intent) {
      case IntentType.bonding:
        return 'CLAUDE';
      case IntentType.spicy:
        return 'GROK';
      case IntentType.deepRecall:
        return 'GEMINI';
      case IntentType.technical:
        return 'DEEPSEEK';
      case IntentType.quickFacts:
        return 'GPT4O';
      case IntentType.currentEvents:
        return 'GEMINI';
      case IntentType.deepResearch:
        return 'DEEP_RESEARCH';
      case IntentType.factCheck:
        return 'FACT_CHECK';
      case IntentType.settingsControl:
        return 'LOCAL';
      case IntentType.calendar:
        return 'GPT4O';
      case IntentType.general:
        return 'CLAUDE';
    }
  }

  IntentResult _fallbackResult(int latency) {
    return IntentResult(
      intent: IntentType.general,
      confidence: 0.5,
      suggestedModel: 'CLAUDE',
      latencyMs: latency,
      reasoning: 'Fallback due to classification error',
    );
  }
}
