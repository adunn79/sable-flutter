import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sable/src/config/app_config.dart';
import '../models/avatar_config.dart';

class AvatarGenerationService {
  static const String _falApiEndpoint = 'https://fal.run/fal-ai/flux/dev';

  /// Generate avatar image using fal.ai API
  /// Returns the URL of the generated image
  Future<String> generateAvatarImage(AvatarConfig config) async {
    final apiKey = AppConfig.falKey;
    
    if (apiKey.isEmpty) {
      throw Exception('FAL_API_KEY not configured in .env file');
    }

    try {
      final prompt = config.toPrompt();
      
      final response = await http.post(
        Uri.parse(_falApiEndpoint),
        headers: {
          'Authorization': 'Key $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'prompt': prompt,
          'image_size': 'square',
          'num_inference_steps': 28,
          'guidance_scale': 3.5,
          'num_images': 1,
          'enable_safety_checker': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // fal.ai returns images array
        if (data['images'] != null && (data['images'] as List).isNotEmpty) {
          final imageData = (data['images'] as List).first as Map<String, dynamic>;
          return imageData['url'] as String;
        } else {
          throw Exception('No image returned from API');
        }
      } else {
        throw Exception('API request failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to generate avatar: $e');
    }
  }

  /// Validate that API is accessible (for testing)
  Future<bool> validateApiKey() async {
    final apiKey = AppConfig.falKey;
    if (apiKey.isEmpty) return false;

    try {
      // Simple health check - attempt to call with minimal data
      final response = await http.get(
        Uri.parse(_falApiEndpoint),
        headers: {
          'Authorization': 'Key $apiKey',
        },
      ).timeout(const Duration(seconds: 5));

      // Any response (including 4xx) means the API is reachable
      return response.statusCode != 401; // 401 = bad key
    } catch (e) {
      return false;
    }
  }
}
