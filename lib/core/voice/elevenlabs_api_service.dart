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
      debugPrint('❌ No ElevenLabs API key found');
      throw Exception('ElevenLabs API key not configured');
    }
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/voices'),
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final voicesJson = data['voices'] as List<dynamic>;
        final voices = voicesJson
            .map((v) => VoiceWithMetadata.fromJson(v as Map<String, dynamic>))
            .toList();
        
        // Cache the results
        await _cacheVoices(voices);
        
        debugPrint('✅ Fetched ${voices.length} voices from ElevenLabs API');
        return voices;
      } else {
        debugPrint('❌ ElevenLabs API error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch voices: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching voices: $e');
      rethrow;
    }
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
