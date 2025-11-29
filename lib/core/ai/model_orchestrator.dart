import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'model_orchestrator.g.dart';

/// Types of tasks the AI can perform, requiring different models.
enum AiTaskType {
  /// Core persona, emotional intelligence, chat.
  /// Best Model: Claude 3.5 Sonnet / 4.5
  personality,

  /// Complex actions, tool use, Google integrations.
  /// Best Model: Gemini 1.5 Pro / 3.0
  agentic,

  /// Heavy logic, reasoning, coding, data processing.
  /// Best Model: GPT-4o / o1
  heavyLifting,
}

/// Configuration for model IDs.
class ModelConfig {
  final String personalityModelId;
  final String agenticModelId;
  final String heavyLiftingModelId;

  const ModelConfig({
    this.personalityModelId = 'claude-3-5-sonnet-20240620',
    this.agenticModelId = 'gemini-1.5-pro',
    this.heavyLiftingModelId = 'gpt-4o',
  });
}

@Riverpod(keepAlive: true)
class ModelOrchestrator extends _$ModelOrchestrator {
  @override
  ModelConfig build() {
    // In the future, load this from remote config or settings
    return const ModelConfig();
  }

  /// Returns the best model ID for the given task type.
  String getModelForTask(AiTaskType task) {
    switch (task) {
      case AiTaskType.personality:
        return state.personalityModelId;
      case AiTaskType.agentic:
        return state.agenticModelId;
      case AiTaskType.heavyLifting:
        return state.heavyLiftingModelId;
    }
  }

  /// Simulates routing a request to the correct provider.
  /// In a real implementation, this would call the specific AiProvider.
  Future<String> routeRequest({
    required String prompt,
    required AiTaskType taskType,
    String? systemPrompt,
  }) async {
    final modelId = getModelForTask(taskType);
    
    // TODO: Integrate actual providers here.
    // For now, we return a simulated response to verify routing logic.
    return '[ROUTER] Routed task "$taskType" to model "$modelId".\nResponse: Simulated output for $prompt';
  }
}
