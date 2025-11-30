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
    final modelId = _orchestrator.state.agenticModelId;

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

  /// Gets news about a specific topic
  Future<String> getNews(String topic) async {
    return search('Latest news about $topic');
  }

  /// Gets events near a location
  Future<String> getLocalEvents(String location) async {
    return search('Events happening in $location today and this week');
  }
}
