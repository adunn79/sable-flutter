import 'package:flutter/foundation.dart';
import 'package:sable/core/memory/unified_memory_service.dart';
import 'package:sable/core/memory/models/extracted_memory.dart';
import 'package:sable/core/ai/providers/gemini_provider.dart';
import 'package:sable/features/journal/models/journal_entry.dart';
import 'package:sable/features/journal/services/journal_storage_service.dart';

/// Personalized Prompt Service for Phase 2: Memory Spine & Intelligence
/// Generates contextual, RAG-based journal prompts based on user's history
class PersonalizedPromptService {
  static final PersonalizedPromptService _instance = PersonalizedPromptService._internal();
  factory PersonalizedPromptService() => _instance;
  PersonalizedPromptService._internal();

  final UnifiedMemoryService _memoryService = UnifiedMemoryService();
  final GeminiProvider _gemini = GeminiProvider();

  bool _initialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    
    await _memoryService.initialize();
    await JournalStorageService.initialize();
    _initialized = true;
    
    debugPrint('✅ PersonalizedPromptService initialized');
  }

  /// Generate a personalized "Spark" prompt based on user's history
  /// These are the thought-starters shown to encourage journaling
  Future<String> generateSparkPrompt() async {
    if (!_initialized) await initialize();

    try {
      // Get recent journal entries
      final entries = JournalStorageService.getAllEntries();
      final recentEntries = entries
          .take(10)
          .map((e) => e.plainText)
          .join('\n---\n');

      // Get user's memories for context
      final memories = _memoryService.getAllMemories();
      final topMemories = memories
          .take(5)
          .map((m) => m.content)
          .join('\n');

      // Generate personalized prompt via Gemini
      final prompt = await _gemini.generateResponse(
        prompt: '''Based on this user's recent journal entries and memories, generate ONE thoughtful journaling prompt.

RECENT ENTRIES:
$recentEntries

KEY MEMORIES:
$topMemories

Requirements:
1. Be specific and personal - reference something from their entries or memories
2. Be warm and encouraging, not clinical
3. Encourage deeper reflection
4. Keep it to 1-2 sentences max
5. Don't repeat topics they've already thoroughly explored
6. Could be a follow-up question, a new angle, or an invitation to explore adjacent topics

Generate just the prompt, nothing else:''',
        systemPrompt: 'You are a thoughtful journaling coach who creates personalized prompts.',
        modelId: 'gemini-2.0-flash-exp',
      );

      return prompt.trim();
    } catch (e) {
      debugPrint('❌ Spark prompt generation failed: $e');
      return _getRandomFallbackPrompt();
    }
  }

  /// Generate a "Continue the Story" prompt that builds on recent patterns
  Future<String> generateContinuationPrompt() async {
    if (!_initialized) await initialize();

    try {
      final entries = JournalStorageService.getAllEntries();
      if (entries.isEmpty) {
        return "What's on your mind today?";
      }

      // Find recurring themes
      final themes = _extractRecurringThemes(entries.take(20).toList());
      
      if (themes.isNotEmpty) {
        final topTheme = themes.entries.first.key;
        return _generateThemeFollowUp(topTheme);
      }

      return _getRandomFallbackPrompt();
    } catch (e) {
      debugPrint('❌ Continuation prompt generation failed: $e');
      return _getRandomFallbackPrompt();
    }
  }

  /// Generate a follow-up prompt based on a specific recent entry
  Future<String> generateFollowUpPrompt(JournalEntry entry) async {
    try {
      final prompt = await _gemini.generateResponse(
        prompt: '''Generate a thoughtful follow-up question based on this journal entry:

"${entry.plainText}"

Requirements:
1. Ask about something specific from the entry
2. Encourage deeper reflection
3. Be warm and supportive
4. One sentence only

Follow-up question:''',
        systemPrompt: 'You are a supportive journaling coach.',
        modelId: 'gemini-2.0-flash-exp',
      );

      return prompt.trim();
    } catch (e) {
      return "How are you feeling about this now?";
    }
  }

  /// Generate prompts related to a specific memory
  Future<List<String>> generateMemoryExplorationPrompts(ExtractedMemory memory) async {
    try {
      final prompt = await _gemini.generateResponse(
        prompt: '''Generate 3 thoughtful journaling prompts to help explore this memory:

Memory: "${memory.content}"
Category: ${memory.category.name}

Requirements:
1. Each prompt should explore a different angle (emotional, practical, future)
2. Be specific to the memory content
3. Keep each prompt to 1 sentence
4. Be warm and encouraging

Return exactly 3 prompts, one per line:''',
        systemPrompt: 'You are a supportive journaling coach.',
        modelId: 'gemini-2.0-flash-exp',
      );

      return prompt.trim().split('\n').take(3).toList();
    } catch (e) {
      return [
        "How does this memory make you feel?",
        "What would you do differently?",
        "How has this shaped who you are today?",
      ];
    }
  }

  /// Get today's recommended prompt based on patterns
  Future<String> getTodaysPrompt() async {
    final now = DateTime.now();
    final hour = now.hour;
    final dayOfWeek = now.weekday;

    // Time-based prompt selection
    if (hour >= 6 && hour < 10) {
      return await _generateMorningPrompt();
    } else if (hour >= 18 && hour < 22) {
      return await _generateEveningPrompt();
    } else if (dayOfWeek == 7 || dayOfWeek == 6) {
      return await _generateWeekendPrompt();
    }

    return await generateSparkPrompt();
  }

  Future<String> _generateMorningPrompt() async {
    return await generateSparkPrompt();
  }

  Future<String> _generateEveningPrompt() async {
    try {
      final entries = JournalStorageService.getAllEntries();
      final recentEntry = entries.isNotEmpty ? entries.first.plainText : '';

      final prompt = await _gemini.generateResponse(
        prompt: '''Generate an evening reflection prompt for journaling.

Today's earlier entry (if any): "$recentEntry"

Requirements:
1. Encourage reflection on the day
2. Ask about wins, challenges, or gratitude
3. Be warm and cozy in tone
4. One sentence only

Evening prompt:''',
        systemPrompt: 'You are a supportive evening journaling coach.',
        modelId: 'gemini-2.0-flash-exp',
      );

      return prompt.trim();
    } catch (e) {
      return "What's one thing that made you smile today?";
    }
  }

  Future<String> _generateWeekendPrompt() async {
    return "Looking back at your week, what are you most grateful for?";
  }

  /// Extract recurring themes from entries
  Map<String, int> _extractRecurringThemes(List<JournalEntry> entries) {
    final themeKeywords = {
      'work': ['work', 'job', 'career', 'project', 'meeting'],
      'relationships': ['family', 'friend', 'partner', 'love'],
      'health': ['exercise', 'sleep', 'health', 'fitness'],
      'growth': ['learn', 'goal', 'improve', 'growth'],
      'stress': ['stress', 'anxiety', 'worry', 'overwhelm'],
    };

    final themeCounts = <String, int>{};

    for (final entry in entries) {
      final text = entry.plainText.toLowerCase();
      for (final theme in themeKeywords.keys) {
        for (final keyword in themeKeywords[theme]!) {
          if (text.contains(keyword)) {
            themeCounts[theme] = (themeCounts[theme] ?? 0) + 1;
            break; // Count each theme once per entry
          }
        }
      }
    }

    // Sort by count descending
    final sorted = themeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Map.fromEntries(sorted);
  }

  /// Generate a follow-up based on a recurring theme
  String _generateThemeFollowUp(String theme) {
    final themePrompts = {
      'work': "Last week you mentioned work quite a bit. What's one thing you'd change about your work-life balance?",
      'relationships': "Relationships seem to be on your mind. Who has made a positive impact on you recently?",
      'health': "You've been thinking about health. What's one small step you could take today?",
      'growth': "You're focused on growth. What's one thing you've learned recently that stuck with you?",
      'stress': "Stress has come up a few times. What usually helps you decompress?",
    };

    return themePrompts[theme] ?? _getRandomFallbackPrompt();
  }

  String _getRandomFallbackPrompt() {
    final prompts = [
      "What's something you're looking forward to?",
      "What made you smile today?",
      "What's on your mind right now?",
      "What would make today great?",
      "What are you grateful for?",
      "What's a challenge you're working through?",
      "What brought you joy recently?",
      "How are you really feeling today?",
      "What's something you learned this week?",
      "What's a small win you want to celebrate?",
    ];

    final index = DateTime.now().millisecondsSinceEpoch % prompts.length;
    return prompts[index];
  }
}
