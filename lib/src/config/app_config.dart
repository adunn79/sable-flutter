import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration class for managing API keys and environment variables
/// All getters are safe - they return empty string if dotenv is not initialized
class AppConfig {
  static bool _initialized = false;
  
  /// Safe accessor for dotenv - returns null if not initialized
  static String? _safeGet(String key) {
    if (!_initialized) return null;
    try {
      return dotenv.env[key];
    } catch (e) {
      return null;
    }
  }
  
  // OpenAI (The Arbiter)
  static String get openAiKey => _safeGet('OPENAI_API_KEY') ?? '';

  // Anthropic / Claude (The Soul)
  static String get anthropicKey => _safeGet('ANTHROPIC_API_KEY') ?? '';

  // Google / Gemini (The Agent)
  static String get googleKey => _safeGet('GOOGLE_API_KEY') ?? '';

  // Google Maps & Weather
  static String get googleMapsKey => _safeGet('GOOGLE_MAPS_API_KEY') ?? '';
  static String get googleMapsApiKey => googleMapsKey; // Alias for consistency

  // Mapbox SDK
  static String get mapboxKey => _safeGet('MAPBOX_API_KEY') ?? '';

  // Fal Image Generation
  static String get falKey => _safeGet('FAL_API_KEY') ?? '';

  // Pinecone
  static String get pineconeKey => _safeGet('PINECONE_API_KEY') ?? '';

  // ElevenLabs (Voice)
  static String get elevenLabsKey => _safeGet('ELEVEN_LABS_API_KEY') ?? '';

  // Grok / xAI (The Realist)
  static String get grokKey => _safeGet('GROK_API_KEY') ?? '';

  // DeepSeek (The Coder)
  static String get deepseekKey => _safeGet('DEEPSEEK_API_KEY') ?? '';

  /// Initialize the environment configuration
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await dotenv.load(fileName: '.env');
      _initialized = true;
      debugPrint('🔑 AppConfig initialized: Grok API key present: ${grokKey.isNotEmpty}');
    } catch (e) {
      debugPrint('⚠️ AppConfig: Failed to load .env file: $e');
      _initialized = true; // Mark as initialized to prevent retry loops
    }
  }

  /// Check if config was initialized
  static bool get isInitialized => _initialized;

  /// Check if all required keys are present
  static bool get isConfigured {
    return openAiKey.isNotEmpty &&
        anthropicKey.isNotEmpty &&
        googleKey.isNotEmpty;
  }
}
