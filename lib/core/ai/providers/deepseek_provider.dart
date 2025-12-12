import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sable/src/config/app_config.dart';
import '../ai_provider_interface.dart';

/// DeepSeek AI provider using OpenAI-compatible API.
/// Specialization: Technical tasks, code generation, debugging.
class DeepSeekProvider implements AiProviderInterface {
  static const String _baseUrl = 'https://api.deepseek.com/v1/chat/completions';

  @override
  String get id => 'deepseek';

  @override
  Future<String> generateResponse({
    required String prompt,
    String? systemPrompt,
    required String modelId,
  }) async {
    final apiKey = AppConfig.deepseekKey;
    if (apiKey.isEmpty) {
      throw Exception('DEEPSEEK_API_KEY not configured');
    }

    try {
      final messages = <Map<String, String>>[];
      
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        messages.add({'role': 'system', 'content': systemPrompt});
      }
      
      messages.add({'role': 'user', 'content': prompt});

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': modelId,
          'messages': messages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choices = data['choices'] as List?;
        
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'];
          return message['content'];
        }
        
        throw Exception('Unexpected response format from DeepSeek API');
      } else {
        throw Exception('DeepSeek API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to call DeepSeek API: $e');
    }
  }
}
