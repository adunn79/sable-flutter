import 'package:flutter/foundation.dart';

/// Model for a voice option with metadata
class VoiceOption {
  final String id;
  final String name;
  final String gender; // 'Male', 'Female', 'Neutral'
  final String accent; // 'Australian', 'American', 'British', etc.
  
  const VoiceOption({
    required this.id,
    required this.name,
    required this.gender,
    required this.accent,
  });
}

/// Service to map ElevenLabs voices to locales/accents
class LocaleVoiceService {
  // NOTE: Using the 6 curated voices we have available
  // In a real implementation, you'd want more voices for each region
  static const List<VoiceOption> allVoices = [
    // American Voices
    VoiceOption(
      id: 'TxGEqnHWrfWFTfGW9XjX',
      name: 'Josh',
      gender: 'Male',
      accent: 'American',
    ),
    VoiceOption(
      id: 'ErXwobaYiN019PkySvjV',
      name: 'Antoni',
      gender: 'Male',
      accent: 'American',
    ),
    VoiceOption(
      id: '21m00Tcm4TlvDq8ikWAM',
      name: 'Rachel',
      gender: 'Female',
      accent: 'American',
    ),
    VoiceOption(
      id: 'EXAVITQu4vr4xnSDxMaL',
      name: 'Bella',
      gender: 'Female',
      accent: 'American',
    ),
    VoiceOption(
      id: 'pNInz6obpgDQGcFmaJgB',
      name: 'Adam',
      gender: 'Neutral',
      accent: 'American',
    ),
    VoiceOption(
      id: 'zrHiDhphv9ZnVXBqCLjz',
      name: 'Mimi',
      gender: 'Neutral',
      accent: 'American',
    ),
  ];

  /// Get voices filtered by origin/location
  /// Maps common country/city names to accent categories
  static List<VoiceOption> getVoicesForOrigin(String origin) {
    final originLower = origin.toLowerCase();
    
    String accent = 'American'; // Default
    
    // Determine accent based on origin
    if (originLower.contains('australia')) {
      accent = 'Australian';
    } else if (originLower.contains('united kingdom') || 
               originLower.contains('london') || 
               originLower.contains('manchester') ||
               originLower.contains('scotland') ||
               originLower.contains('wales')) {
      accent = 'British';
    } else if (originLower.contains('united states') ||
               originLower.contains('california') ||
               originLower.contains('new york') ||
               originLower.contains('texas') ||
               originLower.contains('florida')) {
      accent = 'American';
    } else if (originLower.contains('canada')) {
      accent = 'Canadian';
    } else if (originLower.contains('south africa')) {
      accent = 'South African';
    } else if (originLower.contains('india')) {
      accent = 'Indian';
    }
    
    // Filter voices by accent
    final matchingVoices = allVoices.where((v) => v.accent == accent).toList();
    
    // If no voices match (e.g., we don't have Australian voices yet), 
    // fall back to all voices
    if (matchingVoices.isEmpty) {
      debugPrint('⚠️ No voices found for accent: $accent, using all voices');
      return allVoices;
    }
    
    return matchingVoices;
  }

  /// Get a recommended voice based on gender and origin
  static VoiceOption? getRecommendedVoice({
    required String origin,
    String? gender,
  }) {
    final voices = getVoicesForOrigin(origin);
    
    if (gender == null || gender.isEmpty) {
      return voices.isNotEmpty ? voices.first : null;
    }
    
    final genderLower = gender.toLowerCase();
    
    // Try to match gender preference
    final matchingGender = voices.where((v) {
      return v.gender.toLowerCase() == genderLower ||
             (genderLower == 'non-binary' && v.gender == 'Neutral');
    }).toList();
    
    if (matchingGender.isNotEmpty) {
      return matchingGender.first;
    }
    
    // Fallback to first available voice
    return voices.isNotEmpty ? voices.first : null;
  }
}
