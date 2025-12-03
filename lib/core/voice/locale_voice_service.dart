import 'package:flutter/foundation.dart';
import 'elevenlabs_api_service.dart';

/// Service to map voices to locales/accents using ElevenLabs API
class LocaleVoiceService {
  static final ElevenLabsApiService _apiService = ElevenLabsApiService();
  
  /// Get voices filtered by origin/location
  /// Fetches from ElevenLabs API and filters by accent
  static Future<List<VoiceWithMetadata>> getVoicesForOrigin(String origin) async {
    final originLower = origin.toLowerCase();
    
    // Determine target accent based on origin
    String targetAccent = _mapOriginToAccent(originLower);
    
    debugPrint('🎤 Looking for $targetAccent accent voices for origin: $origin');
    
    try {
      // Fetch all voices from API
      final allVoices = await _apiService.getAllVoices();
      
      // Filter voices by accent
      final matchingVoices = allVoices.where((voice) {
        // Check if any of the voice's accents match the target
        return voice.accents.any((accent) => 
          accent.toLowerCase().contains(targetAccent.toLowerCase())
        );
      }).toList();
      
      // If no voices match, return all voices as fallback
      if (matchingVoices.isEmpty) {
        debugPrint('⚠️ No $targetAccent voices found, showing all ${allVoices.length} voices');
        return allVoices;
      }
      
      debugPrint('✅ Found ${matchingVoices.length} $targetAccent voices');
      return matchingVoices;
    } catch (e) {
      debugPrint('❌ Error fetching voices: $e');
      // Return empty list on error - UI should handle gracefully
      return [];
    }
  }
  
  /// Map origin string to accent category
  static String _mapOriginToAccent(String originLower) {
    // Russia
    if (originLower.contains('russia') || 
        originLower.contains('moscow') || 
        originLower.contains('saint petersburg') ||
        originLower.contains('st petersburg')) {
      return 'Russian';
    }
    
    // Australia
    if (originLower.contains('australia') ||
        originLower.contains('sydney') ||
        originLower.contains('melbourne')) {
      return 'Australian';
    }
    
    // United Kingdom
    if (originLower.contains('united kingdom') || 
        originLower.contains('uk') ||
        originLower.contains('england') ||
        originLower.contains('london') || 
        originLower.contains('manchester') ||
        originLower.contains('scotland') ||
        originLower.contains('wales') ||
        originLower.contains('ireland')) {
      return 'British';
    }
    
    // United States
    if (originLower.contains('united states') ||
        originLower.contains('usa') ||
        originLower.contains('america') ||
        originLower.contains('california') ||
        originLower.contains('new york') ||
        originLower.contains('texas') ||
        originLower.contains('florida')) {
      return 'American';
    }
    
    // Canada
    if (originLower.contains('canada') ||
        originLower.contains('toronto') ||
        originLower.contains('vancouver')) {
      return 'Canadian';
    }
    
    // France
    if (originLower.contains('france') || originLower.contains('paris')) {
      return 'French';
    }
    
    // Germany
    if (originLower.contains('germany') || originLower.contains('berlin')) {
      return 'German';
    }
    
    // Italy
    if (originLower.contains('italy') || originLower.contains('rome')) {
      return 'Italian';
    }
    
    // Spain
    if (originLower.contains('spain') || originLower.contains('madrid')) {
      return 'Spanish';
    }
    
    // India
    if (originLower.contains('india') || originLower.contains('mumbai')) {
      return 'Indian';
    }
    
    // South Africa
    if (originLower.contains('south africa') || originLower.contains('cape town')) {
      return 'South African';
    }
    
    // Scandinavia / Northern Europe
    if (originLower.contains('sweden') || 
        originLower.contains('stockholm') ||
        originLower.contains('norway') ||
        originLower.contains('oslo') ||
        originLower.contains('denmark') ||
        originLower.contains('copenhagen') ||
        originLower.contains('finland') ||
        originLower.contains('helsinki')) {
      return 'Swedish'; // Or 'European' if specific accents aren't available
    }
    
    // Netherlands
    if (originLower.contains('netherlands') || originLower.contains('amsterdam')) {
      return 'Dutch';
    }
    
    // Default to American
    return 'American';
  }
  
  /// Get a recommended voice based on gender and origin
  static Future<VoiceWithMetadata?> getRecommendedVoice({
    required String origin,
    String? gender,
  }) async {
    final voices = await getVoicesForOrigin(origin);
    
    if (voices.isEmpty) return null;
    
    if (gender == null || gender.isEmpty) {
      return voices.first;
    }
    
    final genderLower = gender.toLowerCase();
    
    // Try to match gender preference
    final matchingGender = voices.where((v) {
      final voiceGender = v.gender?.toLowerCase() ?? '';
      return voiceGender.contains(genderLower) ||
             (genderLower.contains('non-binary') && voiceGender.contains('neutral'));
    }).toList();
    
    if (matchingGender.isNotEmpty) {
      return matchingGender.first;
    }
    
    // Fallback to first available voice
    return voices.first;
  }
  
  /// Clear the voice cache (useful for refreshing or debugging)
  static Future<void> clearCache() async {
    await _apiService.clearCache();
  }
}



