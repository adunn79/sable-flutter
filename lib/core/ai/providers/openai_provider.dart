import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../ai_provider_interface.dart';

/// OpenAI GPT provider using dart_openai package.
class OpenAiProvider implements AiProviderInterface {
  OpenAiProvider() {
    _initializeOpenAI();
  }

  void _initializeOpenAI() {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OPENAI_API_KEY not found in environment variables');
    }
    OpenAI.apiKey = apiKey;
  }

  @override
  String get id => 'openai';

  @override
  Future<String> generateResponse({
    required String prompt,
    String? systemPrompt,
    required String modelId,
  }) async {
    try {
      final messages = <OpenAIChatCompletionChoiceMessageModel>[];

      // Add system message if provided
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        messages.add(
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(systemPrompt)],
          ),
        );
      }

      // Add user message
      messages.add(
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt)],
        ),
      );

      final chatCompletion = await OpenAI.instance.chat.create(
        model: modelId,
        messages: messages,
      );

      final response = chatCompletion.choices.first.message.content;
      if (response != null && response.isNotEmpty) {
        // Extract text from content items
        final textContent = response
            .whereType<OpenAIChatCompletionChoiceMessageContentItemModel>()
            .map((item) => item.text ?? '')
            .join('');
        
        if (textContent.isNotEmpty) {
          return textContent;
        }
      }

      throw Exception('Empty response from OpenAI API');
    } catch (e) {
      throw Exception('Failed to call OpenAI API: $e');
    }
  }
}
