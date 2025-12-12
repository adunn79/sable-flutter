import 'package:flutter/foundation.dart';
import 'package:sable/core/ai/room_brain/room_brain_base.dart';
import 'package:sable/core/ai/agent_context.dart';

/// Journal Brain - Domain expertise for journaling
/// Handles: journaling help, mood analysis, prompts, templates, insights
class JournalBrain extends RoomBrain {
  JournalBrain({
    required super.memorySpine,
    required super.tools,
  });

  @override
  String get domain => 'journal';

  @override
  List<String> get capabilities => [
    'journaling_assistance',
    'create_journal_entry',
    'analyze_mood_trends',
    'suggest_prompts',
    'generate_insights',
    'mood_tracking',
  ];

  @override
  bool canHandle(String query) {
    final lowerQuery = query.toLowerCase();
    
    // Journal-related keywords
    final journalKeywords = [
      'journal',
      'write',
      'mood',
      'feeling',
      'grateful',
      'reflect',
      'thought',
      'diary',
      'entry',
      'template',
      'prompt',
    ];
    
    return journalKeywords.any((kw) => lowerQuery.contains(kw));
  }

  @override
  Future<BrainResponse> processQuery(String query, AgentContext context) async {
    final lowerQuery = query.toLowerCase();

    // Intent detection - Create journal entry?
    if (_isCreateEntryIntent(lowerQuery)) {
      debugPrint('📝 Journal Brain: Create entry intent detected');
      
      // For now, just provide guidance (actual tool implementation would create entry)
      return BrainResponse.simple(
        "I can help you journal! Tell me what's on your mind and I'll help you capture it. "
        "Or would you like a prompt to get started?",
      );
    }

    // Intent detection - Mood analysis?
    if (_isMoodAnalysisIntent(lowerQuery)) {
      debugPrint('📊 Journal Brain: Mood analysis intent detected');
      
      // Check Memory Spine for journal state
      final journalState = memorySpine.read('JOURNAL_STATE');
      final averageMood = journalState['average_mood'];
      final totalEntries = journalState['total_entries'] ?? 0;
      
      if (totalEntries > 0 && averageMood != null) {
        return BrainResponse.simple(
          "Based on your $totalEntries journal entries, your average mood has been ${_describeMood(averageMood)}. "
          "I see you're maintaining a ${journalState['current_streak'] ?? 0}-day streak! 🌟",
        );
      } else {
        return BrainResponse.simple(
          "You haven't logged any journal entries yet. Start journaling to track your mood trends over time!",
        );
      }
    }

    // Intent detection - Prompt suggestion?
    if (_isPromptSuggestionIntent(lowerQuery)) {
      debugPrint('💡 Journal Brain: Prompt suggestion intent detected');
      
      return BrainResponse.simple(
        _getJournalPrompt(),
      );
    }

    // Default: General journaling guidance
    return BrainResponse.simple(
      "I'm here to help with your journaling! I can suggest prompts, track your mood, "
      "or help you reflect on your thoughts. What would you like to explore?",
    );
  }

  // ========== INTENT DETECTION ==========

  bool _isCreateEntryIntent(String query) {
    return query.contains('create') || 
           query.contains('write') || 
           query.contains('new entry') ||
           query.contains('start journal');
  }

  bool _isMoodAnalysisIntent(String query) {
    return (query.contains('mood') || query.contains('feeling')) &&
           (query.contains('trend') || query.contains('how') || query.contains('been'));
  }

  bool _isPromptSuggestionIntent(String query) {
    return query.contains('prompt') || 
           query.contains('what should') ||
           query.contains('help me') ||
           query.contains('suggest');
  }

  // ========== HELPERS ==========

  String _describeMood(double moodScore) {
    if (moodScore >= 4.0) return 'joyful and positive';
    if (moodScore >= 3.5) return 'good and content';
    if (moodScore >= 2.5) return 'balanced and steady';
    if (moodScore >= 2.0) return 'a bit low, but managing';
    return 'challenging, but you are reflecting';
  }

  String _getJournalPrompt() {
    final prompts = [
      "What made you smile today, even if just for a moment?",
      "Describe a challenge you faced today and how you handled it.",
      "What are you grateful for right now?",
      "If today had a color, what would it be and why?",
      "What's one thing you learned about yourself today?",
      "Write about someone who made your day better.",
      "What would you tell your younger self about today?",
      "Describe your ideal tomorrow. What does it look like?",
    ];
    
    return prompts[DateTime.now().millisecond % prompts.length];
  }
}
