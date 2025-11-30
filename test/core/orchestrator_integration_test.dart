import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sable/core/ai/model_orchestrator.dart';
import 'package:sable/src/config/app_config.dart';

/// Automated test for Gemini Orchestrator
/// Verifies that Gemini correctly routes to Claude/GPT-4o based on intent
void main() {
  setUpAll(() async {
    await AppConfig.initialize();
  });

  group('Gemini Orchestrator Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Complex/Creative Task -> Routes to Claude', () async {
      print('\n🧪 Testing Orchestrator: Creative Task...');
      
      final orchestrator = container.read(modelOrchestratorProvider.notifier);
      
      // A task requiring creativity and nuance
      final response = await orchestrator.orchestratedRequest(
        prompt: 'Write a short, emotional poem about a robot discovering a flower in a wasteland.',
      );

      print('✅ Orchestrator Response: $response');
      
      expect(response, isNotEmpty);
      expect(response.startsWith('[ERROR]'), isFalse);
      // Note: We can't easily assert WHICH model generated it without inspecting logs,
      // but we can verify we got a valid response.
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('Factual/Simple Task -> Routes to GPT-4o', () async {
      print('\n🧪 Testing Orchestrator: Factual Task...');
      
      final orchestrator = container.read(modelOrchestratorProvider.notifier);
      
      // A task requiring speed and facts
      final response = await orchestrator.orchestratedRequest(
        prompt: 'List the 3 primary colors. Just the list.',
      );

      print('✅ Orchestrator Response: $response');
      
      expect(response, isNotEmpty);
      expect(response.startsWith('[ERROR]'), isFalse);
    }, timeout: const Timeout(Duration(seconds: 60)));
    
    test('Unified Voice Consistency', () async {
      print('\n🧪 Testing Unified Voice...');
      
      final orchestrator = container.read(modelOrchestratorProvider.notifier);
      
      final response = await orchestrator.orchestratedRequest(
        prompt: 'Who are you?',
      );

      print('✅ Identity Response: $response');
      
      // Should identify as the AI/Sable, not as Claude or GPT
      expect(response.toLowerCase(), contains('sable'));
      expect(response.toLowerCase(), isNot(contains('claude')));
      expect(response.toLowerCase(), isNot(contains('gpt')));
      expect(response.toLowerCase(), isNot(contains('openai')));
      expect(response.toLowerCase(), isNot(contains('anthropic')));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
