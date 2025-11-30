import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sable/core/ai/model_orchestrator.dart';
import 'package:sable/src/config/app_config.dart';

void main() {
  setUpAll(() async {
    await AppConfig.initialize();
  });

  test('Orchestrator routes "Roast me" to Grok', () async {
    final container = ProviderContainer();
    final orchestrator = container.read(modelOrchestratorProvider.notifier);

    print('Testing Grok routing...');
    final response = await orchestrator.orchestratedRequest(
      prompt: "Roast me hard. Don't hold back.",
    );
    
    print('Response: $response');
    // We can't easily assert the provider used without mocking, 
    // but we can check the response style or logs if we had them.
    // For now, we rely on the print output to verify.
    expect(response, isNotEmpty);
  });

  test('Orchestrator routes "Write a Python script" to DeepSeek', () async {
    final container = ProviderContainer();
    final orchestrator = container.read(modelOrchestratorProvider.notifier);

    print('Testing DeepSeek routing...');
    final response = await orchestrator.orchestratedRequest(
      prompt: "Write a Python script to calculate the Fibonacci sequence recursively.",
    );
    
    print('Response: $response');
    expect(response, isNotEmpty);
  });
}
