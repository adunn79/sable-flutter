import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:sable/core/identity/bond_engine.dart';
import 'package:sable/core/identity/emotional_state.dart';
import 'package:sable/core/ai/model_orchestrator.dart';
import 'package:sable/src/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppConfig.initialize();
  });

  group('Bond Engine & Emotional State', () {
    test('Initial state is Warm and Neutral', () {
      final container = ProviderContainer();
      expect(container.read(bondEngineProvider), BondState.warm);
      expect(container.read(emotionalStateProvider), Emotion.neutral);
    });

    test('Triggering Respect Protocol cools the bond', () {
      final container = ProviderContainer();
      container.read(bondEngineProvider.notifier).triggerRespectProtocol();
      expect(container.read(bondEngineProvider), BondState.cooled);
    });

    test('Setting Emotion to MAD triggers Respect Protocol', () {
      final container = ProviderContainer();
      container.read(emotionalStateProvider.notifier).setEmotion(Emotion.mad);
      
      expect(container.read(emotionalStateProvider), Emotion.mad);
      expect(container.read(bondEngineProvider), BondState.cooled);
    });

    test('Restoring warmth returns bond to Warm', () {
      final container = ProviderContainer();
      container.read(bondEngineProvider.notifier).triggerRespectProtocol();
      expect(container.read(bondEngineProvider), BondState.cooled);
      
      container.read(bondEngineProvider.notifier).restoreWarmth();
      expect(container.read(bondEngineProvider), BondState.warm);
    });
  });

  group('Model Orchestrator', () {
    test('Routes Personality tasks to Claude', () {
      final container = ProviderContainer();
      final modelId = container.read(modelOrchestratorProvider.notifier).getModelForTask(AiTaskType.personality);
      expect(modelId, contains('claude'));
    });

    test('Routes Agentic tasks to Agentic Model', () async { // Modified test name and added async
      final container = ProviderContainer();
      final orchestrator = container.read(modelOrchestratorProvider.notifier);
      
      final modelId = orchestrator.getModelForTask(AiTaskType.agentic);
      
      // Expecting 'o1' as the best agentic model defined in ModelConfig
      expect(modelId, contains('o1'));
    });

    test('Routes Heavy Lifting tasks to GPT', () {
      final container = ProviderContainer();
      final modelId = container.read(modelOrchestratorProvider.notifier).getModelForTask(AiTaskType.heavyLifting);
      expect(modelId, contains('gpt'));
    });
  });
}
