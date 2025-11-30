import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'providers/anthropic_provider.dart';
import 'providers/gemini_provider.dart';
import 'providers/openai_provider.dart';
import 'providers/grok_provider.dart';
import 'providers/deepseek_provider.dart';

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

  /// Direct, unfiltered, realistic analysis.
  /// Best Model: Grok
  realist,

  /// Technical tasks, code generation, debugging.
  /// Best Model: DeepSeek
  coding,
}

/// Configuration for model IDs.
class ModelConfig {
  final String personalityModelId;
  final String agenticModelId;
  final String heavyLiftingModelId;
  final String realistModelId;
  final String codingModelId;

  const ModelConfig({
    this.personalityModelId = 'claude-3-haiku-20240307',
    this.agenticModelId = 'gemini-2.0-flash',
    this.heavyLiftingModelId = 'gpt-4o',
    this.realistModelId = 'grok-3',
    this.codingModelId = 'deepseek-chat',
  });
}

@Riverpod(keepAlive: true)
class ModelOrchestrator extends _$ModelOrchestrator {
  // AI Provider instances
  late final AnthropicProvider _anthropicProvider;
  late final GeminiProvider _geminiProvider;
  late final OpenAiProvider _openAiProvider;
  late final GrokProvider _grokProvider;
  late final DeepSeekProvider _deepseekProvider;

  @override
  ModelConfig build() {
    // Initialize providers
    _anthropicProvider = AnthropicProvider();
    _geminiProvider = GeminiProvider();
    _openAiProvider = OpenAiProvider();
    _grokProvider = GrokProvider();
    _deepseekProvider = DeepSeekProvider();

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
      case AiTaskType.realist:
        return state.realistModelId;
      case AiTaskType.coding:
        return state.codingModelId;
    }
  }

  /// Routes a request to the correct AI provider based on task type.
  Future<String> routeRequest({
    required String prompt,
    required AiTaskType taskType,
    String? systemPrompt,
  }) async {
    final modelId = getModelForTask(taskType);

    try {
      switch (taskType) {
        case AiTaskType.personality:
          return await _anthropicProvider.generateResponse(
            prompt: prompt,
            systemPrompt: systemPrompt,
            modelId: modelId,
          );
        case AiTaskType.agentic:
          return await _geminiProvider.generateResponse(
            prompt: prompt,
            systemPrompt: systemPrompt,
            modelId: modelId,
          );
        case AiTaskType.heavyLifting:
          return await _openAiProvider.generateResponse(
            prompt: prompt,
            systemPrompt: systemPrompt,
            modelId: modelId,
          );
        case AiTaskType.realist:
          return await _grokProvider.generateResponse(
            prompt: prompt,
            systemPrompt: systemPrompt,
            modelId: modelId,
          );
        case AiTaskType.coding:
          return await _deepseekProvider.generateResponse(
            prompt: prompt,
            systemPrompt: systemPrompt,
            modelId: modelId,
          );
      }
    } catch (e) {
      return '[ERROR] Failed to get response from ${taskType.name} provider: $e';
    }
  }
}
