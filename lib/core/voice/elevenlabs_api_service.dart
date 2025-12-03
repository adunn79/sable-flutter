import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Model for a voice with full metadata from ElevenLabs API
class VoiceWithMetadata {
  final String voiceId;
  final String name;
  final String? gender; // Extracted from labels
  final List<String> accents; // Extracted from labels (e.g., ['Russian', 'Eastern European'])
  final String? previewUrl;
  final Map<String, dynamic> labels; // Full labels object from API
  
  VoiceWithMetadata({
    required this.voiceId,
    required this.name,
    this.gender,
    required this.accents,
    this.previewUrl,
    required this.labels,
  });
  
  factory VoiceWithMetadata.fromJson(Map<String, dynamic> json) {
    // Extract accents and gender from labels
    final labels = json['labels'] as Map<String, dynamic>? ?? {};
    final accents = <String>[];
    String? gender;
    
    // Parse labels to extract accent and gender info
    labels.forEach((key, value) {
      final keyLower = key.toLowerCase();
      final valueLower = value.toString().toLowerCase();
      
      // Extract gender
      if (keyLower == 'gender' || keyLower.contains('gender')) {
        gender = value.toString();
      }
      
      // Extract accents/regions
      if (keyLower == 'accent' || keyLower.contains('accent') || 
          keyLower == 'region' || keyLower.contains('nationality')) {
        accents.add(value.toString());
      }
      
      // Also check common accent keywords in value
      final accentKeywords = ['american', 'british', 'australian', 'russian', 
                               'french', 'german', 'italian', 'spanish', 'indian',
                               'canadian', 'irish', 'south african'];
      for (final keyword in accentKeywords) {
        if (valueLower.contains(keyword) && !accents.contains(value.toString())) {
          accents.add(value.toString());
        }
      }
    });
    
    // Fallback: if no accents found, try to infer from description or name
    if (accents.isEmpty) {
      final description = json['description']?.toString().toLowerCase() ?? '';
      if (description.contains('russian')) accents.add('Russian');
      else if (description.contains('british')) accents.add('British');
      else if (description.contains('australian')) accents.add('Australian');
      else accents.add('American'); // Default
    }
    
    return VoiceWithMetadata(
      voiceId: json['voice_id'] as String,
      name: json['name'] as String,
      gender: gender,
      accents: accents,
      previewUrl: json['preview_url'] as String?,
      labels: labels,
    );
  }
}

/// Service to interact with ElevenLabs API for voice catalog
class ElevenLabsApiService {
  static const String _baseUrl = 'https://api.elevenlabs.io/v1';
  static const String _cacheKey = 'elevenlabs_voices_cache';
  static const String _cacheTimestampKey = 'elevenlabs_voices_cache_timestamp';
  static const Duration _cacheDuration = Duration(hours: 24);
  
  /// Fetch all available voices from ElevenLabs API
  /// Uses 24-hour cache to reduce API calls
  Future<List<VoiceWithMetadata>> getAllVoices() async {
    // Check cache first
    final cachedVoices = await _getCachedVoices();
    if (cachedVoices != null) {
      debugPrint('✅ Using cached voices (${cachedVoices.length} voices)');
      return cachedVoices;
    }
    
    // Fetch from API
    debugPrint('🌐 Fetching voices from ElevenLabs API...');
    
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('eleven_labs_api_key');
    
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('❌ No ElevenLabs API key found in SharedPreferences');
      // Try to get from AppConfig directly as fallback
      // Note: This requires importing AppConfig, which might cause circular dependency if not careful.
      // For now, just log the error.
      throw Exception('ElevenLabs API key not configured');
    } else {
      debugPrint('🔑 API Key found (starts with: ${apiKey.substring(0, 5)}...)');
    }
    
    try {
      final uri = Uri.parse('$_baseUrl/voices');
      debugPrint('📡 Requesting: $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
        },
      );
      
      debugPrint('📥 Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final voicesJson = data['voices'] as List<dynamic>;
        debugPrint('📦 Received ${voicesJson.length} voices from API');
        
        final List<VoiceWithMetadata> allVoices = voicesJson
            .map((v) => VoiceWithMetadata.fromJson(v as Map<String, dynamic>))
            .toList();
        
        // Filter out child voices and any age-related labels
        final List<VoiceWithMetadata> voices = allVoices.where((voice) {
          // Check age label
          final age = voice.labels['age']?.toString().toLowerCase();
          if (age != null && (age.contains('child') || age.contains('young') || age.contains('kid'))) {
            return false;
          }
          
          // Check use case label
          final useCase = voice.labels['use_case']?.toString().toLowerCase();
          if (useCase != null && useCase.contains('child')) {
            return false;
          }
          
          // Check description
          final description = voice.labels['description']?.toString().toLowerCase();
          if (description != null && (description.contains('child') || description.contains('kid'))) {
            return false;
          }
          
          // Check voice name
          if (voice.name.toLowerCase().contains('child')) {
            return false;
          }
          
          return true;
        }).toList();
        
        debugPrint('🚫 Filtered out ${allVoices.length - voices.length} child/age-restricted voices');
        debugPrint('✅ ${voices.length} adult voices available');
        
        // Cache the results
        await _cacheVoices(voices);
        
        debugPrint('✅ Parsed and cached ${voices.length} voices');
        debugPrint('✅ Parsed and cached ${voices.length} voices');
        
        // Deduplicate voices by ID as a safety measure
        final seenIds = <String>{};
        final uniqueVoices = voices.where((v) => seenIds.add(v.voiceId)).toList();
        
        return uniqueVoices;
      } else {
        debugPrint('❌ ElevenLabs API error: ${response.statusCode} - ${response.body}');
        debugPrint('⚠️ Falling back to curated voice list');
        return _getFallbackVoices();
      }
    } catch (e) {
      debugPrint('❌ Error fetching voices: $e');
      debugPrint('⚠️ Falling back to curated voice list');
      return _getFallbackVoices();
    }
  }

  /// Fallback list of voices when API fails (e.g. permission issues)
  /// COMPREHENSIVE LIBRARY FOR MONETIZATION STRATEGY
  List<VoiceWithMetadata> _getFallbackVoices() {
    return [
      // === AMERICAN VOICES ===
      VoiceWithMetadata(
        voiceId: '21m00Tcm4TlvDq8ikWAM',
        name: 'Rachel',
        gender: 'female',
        accents: ['American'],
        labels: {'accent': 'american', 'gender': 'female', 'region': 'usa'},
        previewUrl: 'https://storage.googleapis.com/eleven-public-prod/premade/voices/21m00Tcm4TlvDq8ikWAM/df6788f9-5c96-470d-8312-aab3b3d8f50a.mp3',
      ),
      VoiceWithMetadata(
        voiceId: 'EXAVITQu4vr4xnSDxMaL',
        name: 'Bella',
        gender: 'female',
        accents: ['American'],
        labels: {'accent': 'american', 'gender': 'female', 'region': 'usa'},
        previewUrl: 'https://storage.googleapis.com/eleven-public-prod/premade/voices/EXAVITQu4vr4xnSDxMaL/0436532f-230b-4727-9a91-7d338088bc94.mp3',
      ),
      VoiceWithMetadata(
        voiceId: 'TxGEqnHWrfWFTfGW9XjX',
        name: 'Josh',
        gender: 'male',
        accents: ['American'],
        labels: {'accent': 'american', 'gender': 'male', 'region': 'usa'},
        previewUrl: 'https://storage.googleapis.com/eleven-public-prod/premade/voices/TxGEqnHWrfWFTfGW9XjX/6d14d546-1533-4078-a2bd-1e9655d543d5.mp3',
      ),
      VoiceWithMetadata(
        voiceId: 'pNInz6obpgDQGcFmaJgB',
        name: 'Adam',
        gender: 'male',
        accents: ['American'],
        labels: {'accent': 'american', 'gender': 'male', 'region': 'usa'},
        previewUrl: 'https://storage.googleapis.com/eleven-public-prod/premade/voices/pNInz6obpgDQGcFmaJgB/5c41b82c-441d-4721-a52a-70d4f3bcf310.mp3',
      ),
      VoiceWithMetadata(
        voiceId: 'ErXwobaYiN019PkySvjV',
        name: 'Antoni',
        gender: 'male',
        accents: ['American'],
        labels: {'accent': 'american', 'gender': 'male', 'region': 'usa'},
        previewUrl: 'https://storage.googleapis.com/eleven-public-prod/premade/voices/ErXwobaYiN019PkySvjV/38d64495-241f-4129-ad9a-313143399e53.mp3',
      ),
      
      // === BRITISH VOICES ===
      VoiceWithMetadata(
        voiceId: 'XB0fDUnXU5powFXDhCwa',
        name: 'Charlotte',
        gender: 'female',
        accents: ['British', 'European'],
        labels: {'accent': 'british', 'gender': 'female', 'region': 'uk'},
        previewUrl: 'https://storage.googleapis.com/eleven-public-prod/premade/voices/XB0fDUnXU5powFXDhCwa/942356dc-f10d-4d89-bda5-4f8505ee038b.mp3',
      ),
      VoiceWithMetadata(
        voiceId: 'VR6AewLTigWG4xSOukaG',
        name: 'Arnold',
        gender: 'male',
        accents: ['British', 'European'],
        labels: {'accent': 'british', 'gender': 'male', 'region': 'uk'},
        previewUrl: null,
      ),
      VoiceWithMetadata(
        voiceId: 'ThT5KcBeYPX3keUQqHPh',
        name: 'Dorothy',
        gender: 'female',
        accents: ['British', 'European'],
        labels: {'accent': 'british', 'gender': 'female', 'region': 'uk'},
        previewUrl: null,
      ),
      VoiceWithMetadata(
        voiceId: 'N2lVS1w4EtoT3dr4eOWO',
        name: 'Callum',
        gender: 'male',
        accents: ['British', 'European'],
        labels: {'accent': 'british', 'gender': 'male', 'region': 'uk'},
        previewUrl: null,
      ),
      VoiceWithMetadata(
        voiceId: 'onwK4e9ZLuTAKqWW03F9',
        name: 'Daniel',
        gender: 'male',
        accents: ['British', 'European'],
        labels: {'accent': 'british', 'gender': 'male', 'region': 'uk'},
        previewUrl: null,
      ),
      
      // === AUSTRALIAN VOICES ===
      VoiceWithMetadata(
        voiceId: 'IKne3meq5aSn9XLyUdCD',
        name: 'Charlie',
        gender: 'male',
        accents: ['Australian', 'European'],
        labels: {'accent': 'australian', 'gender': 'male', 'region': 'australia'},
        previewUrl: 'https://storage.googleapis.com/eleven-public-prod/premade/voices/IKne3meq5aSn9XLyUdCD/8f10ccaa-0c95-48d3-9c68-8a8c0143c5db.mp3',
      ),
      
      // === IRISH VOICES ===
      VoiceWithMetadata(
        voiceId: 'bVMeCyTHy58xNoL34h3p',
        name: 'Jeremy',
        gender: 'male',
        accents: ['Irish', 'European'],
        labels: {'accent': 'irish', 'gender': 'male', 'region': 'ireland'},
        previewUrl: null,
      ),
      
      // === RUSSIAN/SCANDINAVIAN VOICES ===
      VoiceWithMetadata(
        voiceId: 'XrExE9yKIg1WjnnlVkGX',
        name: 'Matilda',
        gender: 'female',
        accents: ['Swedish', 'European'],
        labels: {'accent': 'swedish', 'gender': 'female', 'region': 'sweden'},
        previewUrl: null,
      ),
      VoiceWithMetadata(
        voiceId: 'SOYHLrjzK2X1ezoPC6cr',
        name: 'Freya',
        gender: 'female',
        accents: ['Swedish', 'European'],
        labels: {'accent': 'swedish', 'gender': 'female', 'region': 'sweden'},
        previewUrl: null,
      ),
      VoiceWithMetadata(
        voiceId: 'ODq5zmih8GrVes37Dizd',
        name: 'Patrick',
        gender: 'male',
        accents: ['European', 'Russian'],
        labels: {'accent': 'european', 'gender': 'male', 'region': 'russia'},
        previewUrl: null,
      ),
      
      // === FRENCH VOICES ===
      VoiceWithMetadata(
        voiceId: 'T558JOxAYVRUXPcjLmWL',
        name: 'Serena',
        gender: 'female',
        accents: ['French', 'European'],
        labels: {'accent': 'french', 'gender': 'female', 'region': 'france'},
        previewUrl: null,
      ),
      VoiceWithMetadata(
        voiceId: 'ZQe5CZNOzWyzPSCn5a3c',
        name: 'Liam',
        gender: 'male',
        accents: ['French', 'European'],
        labels: {'accent': 'french', 'gender': 'male', 'region': 'france'},
        previewUrl: null,
      ),
      
      // === ITALIAN VOICES ===
      VoiceWithMetadata(
        voiceId: 'MF3mGyEYCl7XYWbV9V6O',
        name: 'Elli',
        gender: 'female',
        accents: ['Italian', 'European'],
        labels: {'accent': 'italian', 'gender': 'female', 'region': 'italy'},
        previewUrl: null,
      ),
      
      // === SPANISH VOICES ===
      VoiceWithMetadata(
        voiceId: 'GBv7mTt0atIp3Br8iCZE',
        name: 'Thomas',
        gender: 'male',
        accents: ['Spanish', 'European'],
        labels: {'accent': 'spanish', 'gender': 'male', 'region': 'spain'},
        previewUrl: null,
      ),
      
      // === ADDITIONAL VOICES ===
      VoiceWithMetadata(
        voiceId: 'cgSgspJ2msm6clMCkdW9',
        name: 'Jessica',
        gender: 'female',
        accents: ['American', 'European'],
        labels: {'accent': 'american', 'gender': 'female', 'region': 'usa'},
        previewUrl: null,
      ),
      VoiceWithMetadata(
        voiceId: 'FGY2WhTYpPnrIDTdsKH5',
        name: 'Laura',
        gender: 'female',
        accents: ['American'],
        labels: {'accent': 'american', 'gender': 'female', 'region': 'usa'},
        previewUrl: null,
      ),
      VoiceWithMetadata(
        voiceId: 'pqHfZKP75CvOlQylNhV4',
        name: 'Bill',
        gender: 'male',
        accents: ['American'],
        labels: {'accent': 'american', 'gender': 'male', 'region': 'usa'},
        previewUrl: null,
      ),
    ];
  }

  
  /// Get cached voices if available and not expired
  Future<List<VoiceWithMetadata>?> _getCachedVoices() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check timestamp
    final timestamp = prefs.getInt(_cacheTimestampKey);
    if (timestamp == null) return null;
    
    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    
    if (now.difference(cacheTime) > _cacheDuration) {
      debugPrint('⏰ Voice cache expired');
      return null;
    }
    
    // Get cached data
    final cachedJson = prefs.getString(_cacheKey);
    if (cachedJson == null) return null;
    
    try {
      final List<dynamic> voicesJson = jsonDecode(cachedJson);
      return voicesJson
          .map((v) => VoiceWithMetadata.fromJson(v as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error parsing cached voices: $e');
      return null;
    }
  }
  
  /// Cache voices for 24 hours
  Future<void> _cacheVoices(List<VoiceWithMetadata> voices) async {
    final prefs = await SharedPreferences.getInstance();
    
    final voicesJson = voices.map((v) => {
      'voice_id': v.voiceId,
      'name': v.name,
      'labels': v.labels,
      'preview_url': v.previewUrl,
    }).toList();
    
    await prefs.setString(_cacheKey, jsonEncode(voicesJson));
    await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    
    debugPrint('💾 Cached ${voices.length} voices');
  }
  
  /// Clear voice cache (useful for debugging or forcing refresh)
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimestampKey);
    debugPrint('🗑️ Voice cache cleared');
  }
}
