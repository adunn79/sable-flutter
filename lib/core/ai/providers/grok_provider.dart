import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sable/src/config/app_config.dart';
import 'package:flutter/foundation.dart';
import '../ai_provider_interface.dart';

/// Grok (xAI) provider using OpenAI-compatible API.
/// Personality: Direct, unfiltered, realistic analysis.
class GrokProvider implements AiProviderInterface {
  static const String _baseUrl = 'https://api.x.ai/v1/chat/completions';

  @override
  String get id => 'grok';

  @override
  Future<String> generateResponse({
    required String prompt,
    String? systemPrompt,
    required String modelId,
  }) async {
    final apiKey = AppConfig.grokKey;
    debugPrint('🤖 Grok: API Key present: ${apiKey.isNotEmpty}');
    
    if (apiKey.isEmpty) {
      throw Exception('GROK_API_KEY not configured');
    }

    try {
      final messages = <Map<String, String>>[];
      
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        messages.add({'role': 'system', 'content': systemPrompt});
      }
      
      messages.add({'role': 'user', 'content': prompt});

      debugPrint('🤖 Grok: Calling $modelId with ${messages.length} messages...');
      
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

      debugPrint('🤖 Grok: Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choices = data['choices'] as List?;
        
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'];
          debugPrint('🤖 Grok: Success! Got response');
          return message['content'];
        }
        
        throw Exception('Unexpected response format from Grok API');
      } else {
        debugPrint('🤖 Grok: Error ${response.statusCode}: ${response.body}');
        throw Exception('Grok API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('🤖 Grok: Exception: $e');
      throw Exception('Failed to call Grok API: $e');
    }
  }
}
