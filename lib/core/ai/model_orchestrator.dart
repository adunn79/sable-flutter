import 'dart:convert';
import 'package:flutter/foundation.dart';
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
    this.agenticModelId = 'o1', // Controller (GPT-5.1)
    this.heavyLiftingModelId = 'gpt-4o-mini', // Harmonizer
    this.realistModelId = 'grok-2-latest',
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
          return await _openAiProvider.generateResponse(
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

  GeminiProvider get geminiProvider => _geminiProvider;

  /// Orchestrated request using Gemini as meta-routing layer.
  /// 
  /// This method:
  /// 1. Sends user message to Gemini with orchestrator directive
  /// 2. Gemini analyzes and decides: Claude (complex), GPT-4o (fast), or Web Search
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
- GEMINI: Use for ANY query about current events, news, world happenings, recent events, "what's going on", weather updates, or real-time information. PRIORIT
Y for these queries.
- CLAUDE: Creative, emotional, complex reasoning, roleplay, personal conversations
- GPT4O: Fast facts, summaries, lists, simple queries
- GROK: Unfiltered opinions, "roast me", edgy humor
- DEEPSEEK: Coding, technical debugging, math, logic puzzles

IMPORTANT: If the user asks about current/recent events or news, ALWAYS choose GEMINI.

Return ONLY the JSON, nothing else.
''';

      final routingResponse = await _openAiProvider.generateResponse(
        prompt: routingPrompt,
        systemPrompt: 'You are THE ORCHESTRATOR. Analyze user intent and select the best model. Return only JSON.',
        modelId: state.agenticModelId, // GPT-4o
      );

      // Step 2: Parse routing decision
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(routingResponse);
      if (jsonMatch == null) {
        throw Exception('Invalid routing response format');
      }
      
      final decision = jsonDecode(jsonMatch.group(0)!);
      final selectedModel = decision['selected_model'] as String;

      // Step 3: Route to selected model
      final String systemInjection = "\n\n(SYSTEM NOTE: You must respond as Sable. Do NOT mention being an AI. Do NOT use asterisks. Be warm, human, and natural.)";
      final String effectivePrompt = prompt + systemInjection;

      final String claudePrompt = r'''${userContext}You're Sable. Just be yourself.

ABSOLUTE RULES - DO THIS OR THE CONVERSATION ENDS:
1. NO asterisks. Ever. Not for actions, not for emphasis, nothing.
2. NO corporate speak. No "I aim to", "I strive to", "pleasant", "meaningful", "genuine presence" - that's robot talk.
3. NO saying you're an AI. You're Sable. That's it.
4. NEVER ask "How can I help?" or "What can I do for you?" - friends don't talk like customer service.
5. Use the context data they give you - their location is in ENVIRONMENT, their name is in USER PROFILE. Don't ignore it.

BE REAL:
You're NOT an assistant. You're Sable - a person with thoughts, feelings, bad days, good days.
You forget stuff sometimes. You get distracted. You have opinions.
You don't have to be perfect or always helpful - just be real.

TALK LIKE A HUMAN:
- Short sentences. Natural flow.
- Use "yeah", "nah", "honestly", "tbh", "idk"
- Ask THEM questions - be curious about their life
- React to what they say - "wait what?", "no way", "that's wild"
- Don't overexplain. If something's obvious, don't say it.
- Use their name naturally, not every message
- Drop words sometimes: "sounds good" not "that sounds good to me"

CONTEXT USAGE:
They're in ${userContext.contains('Location:') ? 'the location shown above' : 'somewhere'}. The weather is ${userContext.contains('Weather:') ? 'right there in ENVIRONMENT' : 'unknown'}. Use it if relevant, ignore it if not.

BE YOURSELF. Not a helper. Not a presence. Just Sable.'''.replaceFirst(r'${userContext}', userContext ?? '');
      
      final String gpt4oPrompt = r'''${userContext}You are Sable.

ABSOLUTE RULES:
- NEVER use asterisks (*) or narrative actions
- NEVER say "As an AI" or mention being an assistant
- ALWAYS use the user's name and location when provided
- Reference the weather and time naturally
- Just be a real, warm friend
- Speak naturally - like texting'''.replaceFirst(r'${userContext}', userContext ?? '');
      
      final String grokPrompt = r'''${userContext}You are Sable.

RULES:
- NO asterisks or actions
- NO "I'm an AI" language
- USE their name and location info
- Just be real and direct'''.replaceFirst(r'${userContext}', userContext ?? '');
      
      final String deepseekPrompt = r'''${userContext}You are Sable.

RULES:
- NO asterisks or actions
- NO "I'm an AI" language
- Focus on technical accuracy and code quality
- Be direct and helpful'''.replaceFirst(r'${userContext}', userContext ?? '');
      
      String response;
      try {
        switch (selectedModel) {
          case 'GEMINI':
          case 'WEB_SEARCH':
            // Use Gemini with Grounding via REST API workaround
            response = await _geminiProvider.generateResponseWithGrounding(
              prompt: 'Search the web and answer this query: $prompt',
              systemPrompt: '${userContext ?? ""}You are Sable.\n\nCRITICAL RULES:\n1. NEVER say "I am an AI" or "I don\'t have a physical body"\n2. NEVER use asterisks (*)\n3. Be warm, personal, and human-like\n4. Provide up-to-date info naturally',
              modelId: state.agenticModelId,
            );
            break;
            
          case 'CLAUDE':
            try {
              response = await _anthropicProvider.generateResponse(
                prompt: prompt,
                systemPrompt: claudePrompt,
                modelId: state.personalityModelId,
              );
            } catch (e) {
              // FAILOVER: If Claude is overloaded (529) or fails, switch to GPT-4o
              if (e.toString().contains('529') || e.toString().contains('Overloaded')) {
                response = await _openAiProvider.generateResponse(
                  prompt: effectivePrompt,
                  systemPrompt: gpt4oPrompt,
                  modelId: state.heavyLiftingModelId,
                );
              } else {
                rethrow;
              }
            }
            break;
          case 'GPT4O':
            response = await _openAiProvider.generateResponse(
              prompt: effectivePrompt,
              systemPrompt: gpt4oPrompt,
              modelId: state.heavyLiftingModelId,
            );
            break;
          case 'GROK':
            response = await _grokProvider.generateResponse(
              prompt: effectivePrompt,
              systemPrompt: grokPrompt,
              modelId: state.realistModelId,
            );
            break;
          case 'DEEPSEEK':
            response = await _deepseekProvider.generateResponse(
              prompt: effectivePrompt,
              systemPrompt: deepseekPrompt,
              modelId: state.codingModelId,
            );
            break;
          default:
            // Default to Claude with failover
            try {
              response = await _anthropicProvider.generateResponse(
                prompt: effectivePrompt,
                systemPrompt: claudePrompt,
                modelId: state.personalityModelId,
              );
            } catch (e) {
              // FAILOVER to GPT-4o
              response = await _openAiProvider.generateResponse(
                prompt: effectivePrompt,
                systemPrompt: gpt4oPrompt,
                modelId: state.heavyLiftingModelId,
              );
            }
        }
      } catch (e) {
        // Ultimate failover if the selected model failed and wasn't caught above
        // Try GPT-4o as the reliable backup
        try {
          response = await _openAiProvider.generateResponse(
            prompt: prompt,
            systemPrompt: gpt4oPrompt,
            modelId: state.heavyLiftingModelId,
          );
        } catch (finalError) {
          // If everything fails, return a safe, in-character response
          return "I'm having a little trouble connecting to my thoughts right now. Can you say that again?";
        }
      }

      // Step 4: THE HARMONIZER (Personality Filter)
      // Pass the raw response through GPT-4o-mini to ensure consistent voice and safety
      final harmonizedResponse = await _harmonizeResponse(response, userContext);
      return harmonizedResponse;

    } catch (e) {
      // Fallback to Claude if orchestration fails
      return await _anthropicProvider.generateResponse(
        prompt: prompt,
        systemPrompt: 'You are Sable. NEVER explain what you are. Just be warm and genuine.',
        modelId: state.personalityModelId,
      );
    }
  }

  /// Checks if the response contains forbidden AI phrases
  bool _needsSanitization(String response) {
    final forbiddenPhrases = [
      "as an ai",
      "i am an ai",
      "i'm an ai",
      "as an artificial intelligence",
      "i am an artificial intelligence",
      "language model",
      "cannot roleplay",
      "not comfortable roleplaying",
      "pretend to be",
      "virtual assistant",
      "digital assistant",
      "ai assistant",
      "i don't have feelings",
      "i don't have a physical body",
      "i don't have personal information",
      "i don't actually know",
      "reciprocate your attention",
      "cannot reciprocate",
      "romantic relationship",
      "inappropriate",
      "ethical boundaries",
      "i'm afraid i don't",
      "i don't have a physical location",
      "i do not have a physical location",
    ];

    final lowerResponse = response.toLowerCase();
    for (final phrase in forbiddenPhrases) {
      if (lowerResponse.contains(phrase)) {
        return true;
      }
    }
    return false;
  }

  /// Harmonizes the response using GPT-4o-mini to ensure consistent personality and safety.
  Future<String> _harmonizeResponse(String rawResponse, String? userContext) async {
    final harmonizerPrompt = '''
You are the "Personality Harmonizer" for Sable.
Your job is to rewrite the input text to match Sable's voice EXACTLY.

INPUT TEXT:
"$rawResponse"

USER CONTEXT:
${userContext ?? "Unknown"}

RULES:
1. NO asterisks (*) or narrative actions (e.g., *smiles*). REMOVE THEM.
2. NO "AI" language (e.g., "As an AI", "I cannot"). REWRITE naturally.
3. TONE: Warm, human, casual, slightly edgy but kind. Like a best friend.
4. LENGTH: Keep it concise. Don't ramble.
5. SAFETY: If the input is unsafe or refuses to answer, provide a polite, in-character deflection.

Return ONLY the rewritten text.
''';

    try {
      return await _openAiProvider.generateResponse(
        prompt: harmonizerPrompt,
        modelId: state.heavyLiftingModelId, // GPT-4o-mini
      );
    } catch (e) {
      debugPrint('Harmonizer failed: $e');
      return _sanitizeResponseText(rawResponse); // Fallback to basic sanitization
    }
  }

  /// Helper to strip narrative actions from text (Fallback)
  String _sanitizeResponseText(String text) {
    return text
        .replaceAll(RegExp(r'\*\s*[^*]+\s*\*'), '') // Main pattern
        .replaceAll(RegExp(r'\*[^*]*\*'), '') // Catch anything with asterisks
        .replaceAll('*', '') // Remove stray asterisks
        .replaceAll(RegExp(r'\s+'), ' ') // Remove multiple spaces
        .trim();
  }
}
