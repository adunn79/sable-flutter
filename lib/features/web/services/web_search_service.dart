import 'package:flutter/foundation.dart';
import 'package:sable/core/ai/model_orchestrator.dart';
import 'package:sable/core/ai/providers/gemini_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final webSearchServiceProvider = Provider<WebSearchService>((ref) {
  final orchestrator = ref.watch(modelOrchestratorProvider.notifier);
  return WebSearchService(orchestrator);
});

class WebSearchService {
  final ModelOrchestrator _orchestrator;

  WebSearchService(this._orchestrator);

  /// Performs a web search using Gemini Grounding
  Future<String> search(String query) async {
    final geminiProvider = _orchestrator.geminiProvider;
    // Use Gemini 2.5 Flash with new google_search tool
    const modelId = 'gemini-2.5-flash';

    // Use Gemini with Grounding via REST API workaround
    try {
      final response = await geminiProvider.generateResponseWithGrounding(
        prompt: 'Search the web and answer this query: $query',
        modelId: modelId,
      );
      return response;
    } catch (e) {
      return 'I had trouble searching the web for that. ($e)';
    }
  }

  /// Ensures proper spacing between bullet points
  /// Handles both • and * style bullets, and markdown **headers**
  String _formatBulletSpacing(String text) {
    // Split by lines
    final lines = text.split('\n');
    final formatted = <String>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();
      
      // Add the current line
      formatted.add(line);
      
      // Check if this line is a bullet point (• or * at start)
      final isBullet = trimmedLine.startsWith('•') || trimmedLine.startsWith('*');
      
      if (isBullet && i < lines.length - 1) {
        final nextLine = i + 1 < lines.length ? lines[i + 1].trim() : '';
        
        // Check if next line is another bullet
        final nextIsBullet = nextLine.startsWith('•') || nextLine.startsWith('*');
        
        // Check if next line is a header (markdown **HEADER** or emoji)
        final nextIsHeader = nextLine.startsWith('**') ||
            nextLine.contains('📰') ||
            nextLine.contains('🌍') ||
            nextLine.contains('🇺🇸') ||
            nextLine.contains('📍') ||
            nextLine.contains('🌉') ||
            nextLine.contains('💻') ||
            nextLine.contains('🔬');
        
        // Add blank line after bullet UNLESS next is header or already empty
        if (nextLine.isNotEmpty && !nextIsHeader) {
          formatted.add(''); // Always add spacing between bullets
        }
      }
    }
    
    return formatted.join('\n');
  }

  /// Gets news about a specific topic
  Future<String> getNews(String topic) async {
    return search('Latest news about $topic');
  }

  /// Gets events near a location
  Future<String> getLocalEvents(String location) async {
    return search('Events happening in $location today and this week');
  }

  Future<String> getDailyBriefing(List<String> categories) async {
    final topics = categories.isEmpty ? 'business, technology, AI, and geopolitics' : categories.join(', ');
    
    // Enhanced query for comprehensive coverage
    final query = '''
Search for today's top news and provide comprehensive coverage across ALL these categories: $topics.

For EACH category, find 4-5 significant stories from the last 24 hours.
Ensure you use diverse, reputable sources.

FORMATTING RULES:
- Use the exact category headers provided below.
- For each story, provide a single bullet point.
- Start each bullet with "• ".
- Include the source name in parentheses at the end of the bullet, e.g., "(Reuters)".
- Add a blank line between each bullet point.

CATEGORIES:
- WORLD: International news, geopolitics, global markets, major world events
- NATIONAL: US federal government, policy changes, major national stories
- LOCAL (San Francisco Bay Area): SF/Bay Area specific news, local politics, community events
- TECH: Major tech companies, product launches, industry developments, AI breakthroughs
- SCIENCE: Research findings, climate news, health discoveries, space exploration

Provide detailed, factual information for each category. This is for a comprehensive daily briefing.
''';
    
    final result = await search(query);
    // Apply bullet spacing formatting
    final formatted = _formatBulletSpacing(result);
    
    debugPrint('📰 RAW NEWS (before formatting): ${result.substring(0, result.length > 500 ? 500 : result.length)}...');
    debugPrint('✨ FORMATTED NEWS (after spacing): ${formatted.substring(0, formatted.length > 500 ? 500 : formatted.length)}...');
    
    return formatted;
  }
}
