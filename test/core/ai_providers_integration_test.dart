import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sable/core/ai/model_orchestrator.dart';
import 'package:sable/src/config/app_config.dart';

/// Automated test for AI provider integration
/// Tests all 5 providers: Anthropic (Claude), Google (Gemini), OpenAI (GPT), Grok (xAI), DeepSeek
void main() {
  setUpAll(() async {
    // Initialize app config to load .env variables
    await AppConfig.initialize();
  });

  group('AI Provider Integration Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Anthropic (Claude) - Personality Provider', () async {
      print('\n🧪 Testing Anthropic Claude API...');
      
      final orchestrator = container.read(modelOrchestratorProvider.notifier);
      
      final response = await orchestrator.routeRequest(
        prompt: 'Say hello in exactly 5 words.',
        taskType: AiTaskType.personality,
      );

      print('✅ Anthropic Response: $response');
      
      expect(response, isNotEmpty);
      expect(response.startsWith('[ERROR]'), isFalse,
          reason: 'Anthropic API should not return an error');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('Google (Gemini) - Agentic Provider', () async {
      print('\n🧪 Testing Google Gemini API...');
      
      final orchestrator = container.read(modelOrchestratorProvider.notifier);
      
      final response = await orchestrator.routeRequest(
        prompt: 'What is 2+2? Answer with just the number.',
        taskType: AiTaskType.agentic,
      );

      print('✅ Gemini Response: $response');
      
      expect(response, isNotEmpty);
      expect(response.startsWith('[ERROR]'), isFalse,
          reason: 'Gemini API should not return an error');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('OpenAI (GPT-4o) - Heavy Lifting Provider', () async {
      print('\n🧪 Testing OpenAI GPT-4o API...');
      
      final orchestrator = container.read(modelOrchestratorProvider.notifier);
      
      final response = await orchestrator.routeRequest(
        prompt: 'List 3 prime numbers separated by commas.',
        taskType: AiTaskType.heavyLifting,
      );

      print('✅ OpenAI Response: $response');
      
      expect(response, isNotEmpty);
      expect(response.startsWith('[ERROR]'), isFalse,
          reason: 'OpenAI API should not return an error');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('Grok (xAI) - Realist Provider', () async {
      print('\n🧪 Testing Grok (xAI) API...');
      
      final orchestrator = container.read(modelOrchestratorProvider.notifier);
      
      final response = await orchestrator.routeRequest(
        prompt: 'What is the meaning of life? Be direct and honest in one sentence.',
        taskType: AiTaskType.realist,
      );

      print('✅ Grok Response: $response');
      
      expect(response, isNotEmpty);
      expect(response.startsWith('[ERROR]'), isFalse,
          reason: 'Grok API should not return an error');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('DeepSeek - Coding Provider', () async {
      print('\n🧪 Testing DeepSeek AI API...');
      
      final orchestrator = container.read(modelOrchestratorProvider.notifier);
      
      final response = await orchestrator.routeRequest(
        prompt: 'Write a Python function that adds two numbers. Just the code, no explanation.',
        taskType: AiTaskType.coding,
      );

      print('✅ DeepSeek Response: $response');
      
      expect(response, isNotEmpty);
      expect(response.startsWith('[ERROR]'), isFalse,
          reason: 'DeepSeek API should not return an error');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}

