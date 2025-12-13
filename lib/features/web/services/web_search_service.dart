import 'package:sable/core/ai/model_orchestrator.dart';
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
      final isHeader = trimmedLine.startsWith('**') && 
          (trimmedLine.contains('🌍') || 
           trimmedLine.contains('🇺🇸') || 
           trimmedLine.contains('📍') || 
           trimmedLine.contains('💻') || 
           trimmedLine.contains('🔬'));

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
    // Clean topic of special characters for URL
    String topic = content.replaceAll(RegExp(r'[\[\]()]'), '').replaceAll(' ', '_');
    
    // For content in the link text, escape brackets so they don't break markdown
    String displayContent = content.replaceAll('[', '\\[').replaceAll(']', '\\]');
    
    // Reconstruct line with link: [• Content](expand:Topic)
    formatted.add('[• $displayContent](expand:$topic)');
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
    
    // BALANCED JOURNALISM FORMAT - No AI personality quirks
    final query = '''
You are a PROFESSIONAL NEWS ANCHOR, not a companion AI. Report facts only.

Search for today's top news across: $topics.

JOURNALISM RULES:
1. BE FACTUAL - No personality, no quirks, no emoji commentary
2. CITE SOURCES - Every story needs a source (Reuters, AP, BBC, etc.)
3. BE CONCISE - One clear sentence per story
4. NO REPETITION - Each fact mentioned only once

FORMAT (use exactly):

**🌍 WORLD NEWS**
• [Story headline] - [One sentence summary]. (Source)
• [Story headline] - [One sentence summary]. (Source)

**🇺🇸 NATIONAL**
• [Story headline] - [One sentence summary]. (Source)
• [Story headline] - [One sentence summary]. (Source)

**💻 TECH & AI**
• [Story headline] - [One sentence summary]. (Source)
• [Story headline] - [One sentence summary]. (Source)

**🔬 SCIENCE & HEALTH**
• [Story headline] - [One sentence summary]. (Source)

CRITICAL: Write like a wire service journalist. No conversational tone. No "I think" or "Let me tell you". Just facts with sources.
''';
    
    final result = await search(query);
    return _formatBulletSpacing(result);
  }

  /// Get comprehensive balanced report on a specific topic (like ChatGPT's format)
  /// This provides deep-dive coverage with sources, context, analysis, and counterpoint
  Future<String> getBalancedNewsReport(String topic) async {
    final query = '''
You are a SENIOR NEWS ANALYST providing a comprehensive briefing on: $topic

Write a professional news analysis report. NO AI PERSONALITY. Pure journalism.

STRUCTURE YOUR REPORT EXACTLY LIKE THIS:

**📰 HEADLINE**
[Clear, factual headline about the situation]

**WHAT HAPPENED**
• [Key fact 1] (Source: Reuters/AP/BBC/etc.)
• [Key fact 2] (Source)
• [Key fact 3] (Source)
• [Key fact 4 if relevant] (Source)

**CONTEXT & PATTERN**
• [Historical context or pattern this fits into]
• [Why this matters / implications]

**ANALYSIS**
[2-3 sentence professional analysis of what this means going forward. Be measured, not speculative.]

**COUNTERPOINT**
[One sentence presenting an alternative view or caveat - e.g., "If negotiations succeed, the situation could change rapidly"]

**SOURCES TO VERIFY**
• [Primary source 1]
• [Primary source 2]
• [Alternative perspective source]

RULES:
- Cite sources for every factual claim
- No emoji except section headers
- No personality injections
- No "I think" or subjective language
- Balanced perspective - show multiple viewpoints
- Professional wire-service tone throughout
''';

    return await search(query);
  }

  /// Expand on a specific news topic with balanced coverage
  Future<String> expandNewsTopic(String topic) async {
    return getBalancedNewsReport(topic);
  }
}
