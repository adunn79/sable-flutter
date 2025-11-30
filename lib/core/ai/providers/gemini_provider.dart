import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../ai_provider_interface.dart';

/// Google Gemini provider using official SDK (v1beta API).
class GeminiProvider implements AiProviderInterface {
  @override
  String get id => 'google';

  @override
  Future<String> generateResponse({
    required String prompt,
    String? systemPrompt,
    required String modelId,
  }) async {
    final apiKey = dotenv.env['GOOGLE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GOOGLE_API_KEY not found in environment variables');
    }

    try {
      final model = GenerativeModel(
        model: modelId,
        apiKey: apiKey,
        systemInstruction: systemPrompt != null
            ? Content.system(systemPrompt)
            : null,
      );

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!;
      }

      throw Exception('Empty response from Gemini API');
    } catch (e) {
      throw Exception('Failed to call Gemini API: $e');
    }
  }
}
