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

  /// Ensures proper spacing between bullet points and makes them interactive
  /// Handles both • and * style bullets, and markdown **headers**
  /// Wraps bullet content in [Text](expand:Topic) links
  String _formatBulletSpacing(String text) {
    // Split by lines
    final lines = text.split('\n');
    final formatted = <String>[];
    
    String? currentBullet;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();
      
      if (trimmedLine.isEmpty) continue;
      
      // Check if this line is a bullet point (• or * at start)
      final isBullet = trimmedLine.startsWith('•') || trimmedLine.startsWith('*');
      
      // Check if this line is a header
      final isHeader = trimmedLine.startsWith('**') ||
          trimmedLine.contains('📰') ||
          trimmedLine.contains('🌍') ||
          trimmedLine.contains('🇺🇸') ||
          trimmedLine.contains('📍') ||
          trimmedLine.contains('🌉') ||
          trimmedLine.contains('💻') ||
          trimmedLine.contains('🔬');

      if (isHeader) {
        // Flush pending bullet if any
        if (currentBullet != null) {
          _addFormattedBullet(formatted, currentBullet);
          currentBullet = null;
          formatted.add(''); // Spacing after bullet
        }
        formatted.add(line);
        continue;
      }

      if (isBullet) {
        // Flush previous bullet
        if (currentBullet != null) {
          _addFormattedBullet(formatted, currentBullet);
          formatted.add(''); // Spacing between bullets
        }
        // Start new bullet
        currentBullet = trimmedLine.substring(1).trim();
      } else {
        // Continuation of previous bullet or just text
        if (currentBullet != null) {
          currentBullet += ' ' + trimmedLine;
        } else {
          // Just a loose line? Add it.
          formatted.add(line);
        }
      }
    }
    
    // Flush last bullet
    if (currentBullet != null) {
      _addFormattedBullet(formatted, currentBullet);
    }
    
    return formatted.join('\n');
  }

  void _addFormattedBullet(List<String> formatted, String content) {
    // Use the full content as the topic to ensure the AI has full context
    // We clean it of brackets/parentheses to avoid breaking the markdown link syntax
    String topic = content.replaceAll(RegExp(r'[\[\]()]'), '');
    
    // Reconstruct line with link: [• Content](expand:Topic)
    formatted.add('[• $content](expand:$topic)');
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
    return _formatBulletSpacing(result);
  }
}
