import 'dart:convert';
import 'package:sable/core/memory/unified_memory_service.dart';
import 'package:sable/core/memory/models/extracted_memory.dart';
import 'package:sable/core/memory/models/chat_message.dart';
import 'package:sable/core/ai/model_orchestrator.dart';

/// Memory Extraction Service
/// Uses AI to identify key facts from conversations and store them
class MemoryExtractionService {
  final UnifiedMemoryService _memoryService;
  final ModelOrchestrator _orchestrator;
  
  int _messagesSinceLastExtraction = 0;
  static const int _extractionInterval = 10; // Extract every 10 messages
  
  MemoryExtractionService({
    required UnifiedMemoryService memoryService,
    required ModelOrchestrator orchestrator,
  }) : _memoryService = memoryService, _orchestrator = orchestrator;
  
  /// Called after each message - triggers extraction when threshold reached
  Future<void> onMessageAdded() async {
    _messagesSinceLastExtraction++;
    
    if (_messagesSinceLastExtraction >= _extractionInterval) {
      await extractMemories();
      _messagesSinceLastExtraction = 0;
    }
  }
  
  /// Force extraction now
  Future<void> extractMemories() async {
    try {
      print('🧠 Starting memory extraction...');
      
      // Get recent messages for analysis
      final recentMessages = _memoryService.getRecentChatMessages(20);
      if (recentMessages.isEmpty) {
        print('⚠️ No messages to extract from');
        return;
      }
      
      // Build conversation text
      final conversationText = _buildConversationText(recentMessages);
      
      // Get existing memories to avoid duplicates
      final existingMemories = _memoryService.getAllMemories()
          .map((m) => m.content.toLowerCase())
          .toList();
      
      // Ask AI to extract facts
      final extractedFacts = await _askAIToExtract(conversationText, existingMemories);
      
      // Store extracted memories
      for (var fact in extractedFacts) {
        await _memoryService.addMemory(
          content: fact['content'] as String,
          category: _parseCategory(fact['category'] as String),
          importance: (fact['importance'] as int?) ?? 3,
          tags: List<String>.from(fact['tags'] ?? []),
        );
      }
      
      print('✅ Extracted ${extractedFacts.length} new memories');
      
    } catch (e) {
      print('❌ Memory extraction error: $e');
    }
  }
  
  String _buildConversationText(List<ChatMessage> messages) {
    final buffer = StringBuffer();
    for (var msg in messages) {
      final speaker = msg.isUser ? 'User' : 'Assistant';
      buffer.writeln('$speaker: ${msg.message}');
    }
    return buffer.toString();
  }
  
  Future<List<Map<String, dynamic>>> _askAIToExtract(
    String conversation,
    List<String> existingMemories,
  ) async {
    final prompt = '''
Analyze this conversation and extract NEW key facts about the user.
Only extract information that would be useful to remember for future conversations.

EXISTING KNOWN FACTS (do not repeat these):
${existingMemories.take(20).join('\n')}

CONVERSATION:
$conversation

Extract facts in these categories:
- people: Names and relationships (family, friends, coworkers)
- preferences: Likes, dislikes, favorites
- dates: Birthdays, anniversaries, important dates
- life: Job, hobbies, living situation, pets
- emotional: Emotional patterns, triggers, coping mechanisms
- goals: Goals, dreams, aspirations

Return ONLY a JSON array with this format (no other text):
[
  {"content": "User's mom's name is Sarah", "category": "people", "importance": 4, "tags": ["family", "mom"]},
  {"content": "User loves Italian food", "category": "preferences", "importance": 3, "tags": ["food"]}
]

If no new facts found, return: []
''';

    try {
      final response = await _orchestrator.routeRequest(
        prompt: prompt,
        taskType: AiTaskType.agentic,
        systemPrompt: 'You are a fact extraction assistant. Only return valid JSON arrays.',
      );
      
      // Parse JSON response
      final jsonStr = _extractJsonFromResponse(response);
      if (jsonStr.isEmpty || jsonStr == '[]') return [];
      
      final List<dynamic> parsed = jsonDecode(jsonStr);
      return parsed.cast<Map<String, dynamic>>();
      
    } catch (e) {
      print('❌ AI extraction failed: $e');
      return [];
    }
  }
  
  String _extractJsonFromResponse(String response) {
    // Find JSON array in response
    final startIndex = response.indexOf('[');
    final endIndex = response.lastIndexOf(']');
    
    if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
      return '[]';
    }
    
    return response.substring(startIndex, endIndex + 1);
  }
  
  MemoryCategory _parseCategory(String category) {
    switch (category.toLowerCase()) {
      case 'people': return MemoryCategory.people;
      case 'preferences': return MemoryCategory.preferences;
      case 'dates': return MemoryCategory.dates;
      case 'life': return MemoryCategory.life;
      case 'emotional': return MemoryCategory.emotional;
      case 'goals': return MemoryCategory.goals;
      default: return MemoryCategory.misc;
    }
  }
}
