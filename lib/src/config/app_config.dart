import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration class for managing API keys and environment variables
class AppConfig {
  // OpenAI (The Arbiter)
  static String get openAiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  // Anthropic / Claude (The Soul)
  static String get anthropicKey => dotenv.env['ANTHROPIC_API_KEY'] ?? '';

  // Google / Gemini (The Agent)
  static String get googleKey => dotenv.env['GOOGLE_API_KEY'] ?? '';

  // Google Maps & Weather
  static String get googleMapsKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  static String get googleMapsApiKey => googleMapsKey; // Alias for consistency

  // Mapbox SDK
  static String get mapboxKey => dotenv.env['MAPBOX_API_KEY'] ?? '';

  // Fal Image Generation
  static String get falKey => dotenv.env['FAL_API_KEY'] ?? '';

  // Pinecone
  static String get pineconeKey => dotenv.env['PINECONE_API_KEY'] ?? '';

  // ElevenLabs (Voice)
  static String get elevenLabsKey => dotenv.env['ELEVEN_LABS_API_KEY'] ?? '';


  /// Initialize the environment configuration
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
  }

  /// Check if all required keys are present
  static bool get isConfigured {
    return openAiKey.isNotEmpty &&
        anthropicKey.isNotEmpty &&
        googleKey.isNotEmpty;
  }
}
