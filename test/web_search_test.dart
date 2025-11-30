import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sable/core/ai/model_orchestrator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  test('Web Search Integration Test', () async {
    // Load .env
    await dotenv.load(fileName: ".env");
    
    final container = ProviderContainer();
    final orchestrator = container.read(modelOrchestratorProvider.notifier);
    
    // Test query that requires search
    final query = "What is the latest news about SpaceX Starship?";
    print('Testing query: $query');
    
    try {
      final response = await orchestrator.orchestratedRequest(
        prompt: query,
        userContext: 'User is testing web search.',
      );
      
      print('Response: $response');
      
      // Verify response contains relevant info (heuristic)
      expect(response.isNotEmpty, true);
      // We can't strictly assert content without mocking, but if it returns text it's a good sign
      // If it failed, it would throw or return an error message
    } catch (e) {
      print('Error: $e');
      fail('Web search failed: $e');
    }
  });
}
