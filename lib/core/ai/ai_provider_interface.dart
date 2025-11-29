/// Abstract interface for AI Model Providers.
abstract class AiProviderInterface {
  /// The unique identifier for this provider (e.g., 'anthropic', 'google', 'openai').
  String get id;

  /// Generates a response from the AI model.
  /// 
  /// [prompt] - The user's input or system instruction.
  /// [systemPrompt] - Optional system-level instructions (e.g., persona).
  /// [modelId] - Specific model ID to use (e.g., 'claude-3-5-sonnet').
  Future<String> generateResponse({
    required String prompt,
    String? systemPrompt,
    required String modelId,
  });
}
