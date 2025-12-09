import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sable/core/ai/providers/grok_provider.dart';

/// Service for fetching and caching AI-generated top headlines
class HeadlineService {
  static const String _cacheKey = 'cached_headline';
  static const String _cacheTimeKey = 'cached_headline_time';
  static const Duration _cacheDuration = Duration(hours: 6);
  
  /// Get today's top headline (cached for 6 hours)
  static Future<String?> getTopHeadline({bool forceRefresh = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check cache first
      if (!forceRefresh) {
        final cachedHeadline = prefs.getString(_cacheKey);
        final cacheTimeMs = prefs.getInt(_cacheTimeKey);
        
        if (cachedHeadline != null && cacheTimeMs != null) {
          final cacheTime = DateTime.fromMillisecondsSinceEpoch(cacheTimeMs);
          final age = DateTime.now().difference(cacheTime);
          
          if (age < _cacheDuration) {
            debugPrint('📰 Using cached headline (age: ${age.inMinutes}m)');
            return cachedHeadline;
          }
        }
      }
      
      // Fetch fresh headline from AI
      debugPrint('📰 Fetching fresh headline from AI...');
      final headline = await _fetchHeadlineFromAI();
      
      if (headline != null) {
        // Cache the result
        await prefs.setString(_cacheKey, headline);
        await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
        debugPrint('📰 Headline cached: $headline');
      }
      
      return headline;
    } catch (e) {
      debugPrint('📰 Headline fetch error: $e');
      return null;
    }
  }
  
  /// Fetch headline using AI (Grok)
  static Future<String?> _fetchHeadlineFromAI() async {
    try {
      final provider = GrokProvider();
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      final response = await provider.generateResponse(
        prompt: '''Today is $dateStr. What is THE single most significant world news story happening right now? 

Give me ONE headline only - the most important story the world is talking about today.
Format: Just the headline text, nothing else. Keep it under 15 words.
Example: "Major earthquake strikes Japan, triggering tsunami warnings"''',
        systemPrompt: '''You are a concise news headline generator. Your job is to identify the single most significant news story happening in the world right now and summarize it in one short headline. 
- Be accurate and factual
- Focus on truly significant global events
- Never make up news
- Keep headlines short and impactful''',
        modelId: 'grok-2-latest',
      );
      
      // Clean up the response
      String headline = response.trim();
      
      // Remove quotes if present
      if ((headline.startsWith('"') && headline.endsWith('"')) ||
          (headline.startsWith("'") && headline.endsWith("'"))) {
        headline = headline.substring(1, headline.length - 1);
      }
      
      return headline.isNotEmpty ? headline : null;
    } catch (e) {
      debugPrint('📰 AI headline generation failed: $e');
      return null;
    }
  }
  
  /// Clear the headline cache
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
    debugPrint('📰 Headline cache cleared');
  }
  
  /// Get cache age in minutes (for debugging)
  static Future<int?> getCacheAgeMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheTimeMs = prefs.getInt(_cacheTimeKey);
    
    if (cacheTimeMs == null) return null;
    
    final cacheTime = DateTime.fromMillisecondsSinceEpoch(cacheTimeMs);
    return DateTime.now().difference(cacheTime).inMinutes;
  }
}
