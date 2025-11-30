import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../ai_provider_interface.dart';

/// Google Gemini provider using HTTP API (v1 stable).
class GeminiProvider implements AiProviderInterface {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1/models';

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
      final url = '$_baseUrl/$modelId:generateContent?key=$apiKey';
      
      final body = {
        'contents': [
          {
            'parts': [
              {'text': systemPrompt != null ? '$systemPrompt\n\n$prompt' : prompt}
            ]
          }
        ],
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String;
          }
        }
        
        throw Exception('Unexpected response format from Gemini API');
      } else {
        throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to call Gemini API: $e');
    }
  }
}
