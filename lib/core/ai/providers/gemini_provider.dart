import 'dart:convert';
import 'package:http/http.dart' as http;
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
    List<Tool>? tools,
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
        tools: tools,
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

  /// Generates a response using Google Search Grounding via REST API.
  /// This is a workaround until the Dart SDK supports Grounding.
  Future<String> generateResponseWithGrounding({
    required String prompt,
    String? systemPrompt,
    required String modelId,
  }) async {
    final apiKey = dotenv.env['GOOGLE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GOOGLE_API_KEY not found in environment variables');
    }

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$apiKey');

    final headers = {'Content-Type': 'application/json'};

    final Map<String, dynamic> body = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'tools': [
        {
          'google_search': {}
        }
      ]
    };

    if (systemPrompt != null) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemPrompt}
        ]
      };
    }

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        // Extract text from candidates
        if (jsonResponse['candidates'] != null &&
            (jsonResponse['candidates'] as List).isNotEmpty) {
          final candidate = jsonResponse['candidates'][0];
          if (candidate['content'] != null &&
              candidate['content']['parts'] != null &&
              (candidate['content']['parts'] as List).isNotEmpty) {
            final text = candidate['content']['parts'][0]['text'];
            
            // Check for grounding metadata (citations)
            // We could process this to add citations, but for now just return the text
            // The model usually includes citations in the text or we can append them
            
            return text;
          }
        }
        throw Exception('Empty response structure from Gemini API');
      } else {
        throw Exception('Gemini API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to call Gemini API with Grounding: $e');
    }
  }
}
