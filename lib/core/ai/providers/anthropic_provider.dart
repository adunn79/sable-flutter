import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../ai_provider_interface.dart';

/// Anthropic Claude provider using HTTP API.
class AnthropicProvider implements AiProviderInterface {
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _apiVersion = '2023-06-01';

  @override
  String get id => 'anthropic';

  @override
  Future<String> generateResponse({
    required String prompt,
    String? systemPrompt,
    required String modelId,
  }) async {
    final apiKey = dotenv.env['ANTHROPIC_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('ANTHROPIC_API_KEY not found in environment variables');
    }

    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': _apiVersion,
    };

    final body = {
      'model': modelId,
      'max_tokens': 1024,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
    };

    // Add system prompt if provided
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['system'] = systemPrompt;
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'] as List;
        if (content.isNotEmpty && content[0]['type'] == 'text') {
          return content[0]['text'] as String;
        }
        throw Exception('Unexpected response format from Anthropic API');
      } else {
        throw Exception(
            'Anthropic API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to call Anthropic API: $e');
    }
  }
}
