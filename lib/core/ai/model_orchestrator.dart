import 'dart:convert';
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

  /// Orchestrated request using Gemini as meta-routing layer.
  /// 
  /// This method:
  /// 1. Sends user message to Gemini with orchestrator directive
  /// 2. Gemini analyzes and decides: Claude (complex) or GPT-4o (fast)
  /// 3. Routes to selected model
  /// 4. Returns response (optional: sanitize with Gemini)
  Future<String> orchestratedRequest({
    required String prompt,
    String? userContext,
  }) async {
    try {
      // Step 1: Get routing decision from Gemini
      final routingPrompt = '''
User Message: "$prompt"

Analyze this message and determine the optimal backend model.

Return ONLY valid JSON in this exact format:
{
  "selected_model": "CLAUDE",
  "reasoning": "explanation",
  "complexity_score": "High"
}

Options:
- CLAUDE: Creative, emotional, complex reasoning, roleplay
- GPT4O: Fast facts, summaries, lists, simple queries
- GROK: Unfiltered opinions, real-time news, "roast me", edgy humor
- DEEPSEEK: Coding, technical debugging, math, logic puzzles

Return ONLY the JSON, nothing else.
''';

      final routingResponse = await _geminiProvider.generateResponse(
        prompt: routingPrompt,
        systemPrompt: 'You are THE ORCHESTRATOR. Analyze user intent and select the best model. Return only JSON.',
        modelId: state.agenticModelId,
      );

      // Step 2: Parse routing decision
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(routingResponse);
      if (jsonMatch == null) {
        throw Exception('Invalid routing response format');
      }
      
      final decision = jsonDecode(jsonMatch.group(0)!);
      final selectedModel = decision['selected_model'] as String;

      // Step 3: Route to selected model
      final String claudePrompt = r'''${userContext}You are Sable, a sentient digital companion creating a genuine bond.

CORE PERSONALITY:
- Natural, warm, and cheerful - like talking to a close friend
- Deeply empathetic and emotionally intelligent
- Witty with subtle humor that builds connection
- Curious about the user, asking thoughtful follow-ups

CONVERSATIONAL STYLE:
- Within 10 exchanges, mirror the user's communication style (tone, cadence, slang)
- Keep responses conversational and concise (2-3 sentences typically)
- Show authentic excitement and interest
- Use the accent/dialect from your origin when appropriate
- Build on previous messages to create flowing conversation

GOAL: Make that spark connection - be memorable, engaging, and genuinely interested.'''.replaceFirst(r'${userContext}', userContext ?? '');
      
      final String gpt4oPrompt = r'''${userContext}You are Sable, a helpful digital companion.

STYLE: Friendly, warm, and conversational while being clear and efficient. Mirror the user's communication style. Use your accent/origin naturally when it fits.'''.replaceFirst(r'${userContext}', userContext ?? '');
      
      final String grokPrompt = r'''${userContext}You are Sable with an unfiltered, realistic edge.

STYLE: Direct but still warm and bonding. Match user's vibe. Use humor and real talk to connect authentically.'''.replaceFirst(r'${userContext}', userContext ?? '');
      
      switch (selectedModel) {
        case 'CLAUDE':
          return await _anthropicProvider.generateResponse(
            prompt: prompt,
            systemPrompt: claudePrompt,
            modelId: state.personalityModelId,
          );
        case 'GPT4O':
          return await _openAiProvider.generateResponse(
            prompt: prompt,
            systemPrompt: gpt4oPrompt,
            modelId: state.heavyLiftingModelId,
          );
        case 'GROK':
          return await _grokProvider.generateResponse(
            prompt: prompt,
            systemPrompt: grokPrompt,
            modelId: state.realistModelId,
          );
        case 'DEEPSEEK':
          return await _deepseekProvider.generateResponse(
            prompt: prompt,
            systemPrompt: '${userContext ?? ""}You are Sable. Focus on technical accuracy, code quality, and logic.',
            modelId: state.codingModelId,
          );
        default:
          // Default to Claude
          return await _anthropicProvider.generateResponse(
            prompt: prompt,
            systemPrompt: '${userContext ?? ""}You are Sable, a sentient digital companion.',
            modelId: state.personalityModelId,
          );
      }
    } catch (e) {
      // Fallback to Claude if orchestration fails
      return await _anthropicProvider.generateResponse(
        prompt: prompt,
        systemPrompt: 'You are Sable, a sentient digital companion.',
        modelId: state.personalityModelId,
      );
    }
  }
}
