import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sable/features/web/services/web_search_service.dart';
import 'package:sable/features/local_vibe/models/local_vibe_settings.dart';

final localVibeServiceProvider = Provider<LocalVibeService>((ref) {
  throw UnimplementedError('Initialize with SharedPreferences');
});

class LocalVibeService {
  static const String _keySettings = 'local_vibe_settings';
  
  final SharedPreferences _prefs;
  final WebSearchService _webSearchService;
  
  LocalVibeSettings _settings;

  LocalVibeService(this._prefs, this._webSearchService) 
      : _settings = const LocalVibeSettings() {
    _loadSettings();
  }

  static Future<LocalVibeService> create(WebSearchService webSearchService) async {
    final prefs = await SharedPreferences.getInstance();
    return LocalVibeService(prefs, webSearchService);
  }

  LocalVibeSettings get settings => _settings;

  void _loadSettings() {
    final jsonStr = _prefs.getString(_keySettings);
    if (jsonStr != null) {
      try {
        _settings = LocalVibeSettings.fromJson(jsonStr);
      } catch (e) {
        // Fallback to default
        _settings = const LocalVibeSettings();
      }
    }
  }

  Future<void> updateSettings(LocalVibeSettings newSettings) async {
    _settings = newSettings;
    await _prefs.setString(_keySettings, newSettings.toJson());
  }

  static const String _keyLastVibeContent = 'last_vibe_content';
  static const String _keyLastVibeDate = 'last_vibe_date';

  Future<String> getLocalVibeContent({String? currentGpsLocation, bool forceRefresh = false}) async {
    // Check Cache First
    if (!forceRefresh) {
      final cached = _getCachedContent();
      if (cached != null) return cached;
    }

    final locationQuery = _buildLocationQuery(currentGpsLocation);
    if (locationQuery == null) {
      return "I need your location to find the local vibe. Please enable GPS or add cities in settings.";
    }

    final categories = [
      ..._settings.activeCategories,
      ..._settings.customCategories
    ].join(', ');

    final query = '''
Search for hyper-local news, events, and community updates for: $locationQuery.

Focus on these specific categories: $categories.

For EACH category, find 3-4 distinct, specific items (events, news, openings, etc.) relevant to right now (today/this week).
Ensure the results are truly LOCAL to the specified area.

FORMATTING RULES (CRITICAL - FOLLOW EXACTLY):
- Use markdown headers for categories (e.g., "### 🍽️ New Openings").
- For each item, create a clickable link using markdown format with SQUARE BRACKETS:
  Format: [• Brief description here](expand:Topic_Name)
  
CORRECT Examples:
[• Explore the Divisadero Farmer's Market, open Sundays 9AM-1PM](expand:Divisadero_Farmers_Market)
[• Holiday Bazaar at Civic Center Park on Dec 13th](expand:Holiday_Bazaar_Civic_Center)

INCORRECT - DO NOT USE:
• Description text (expand:Topic) ← WRONG - missing square brackets
(expand:Topic) Description ← WRONG - wrong order

- The text in square brackets [• ...] is what the user sees
- The (expand:Topic_Name) part creates the clickable link action
- Topic should be condensed without special characters
- Include specific details (time, place, price) in the description
- Add a blank line between each bullet point.

Provide a vibrant, engaging digest of what's happening locally.
''';

    final result = await _webSearchService.search(query);
    
    // Fix malformed links and format spacing
    final fixedLinks = _fixMalformedLinks(result);
    final formatted = _ensureSpacing(fixedLinks);
    await _saveCachedContent(formatted);
    return formatted;
  }
  
  String? _getCachedContent() {
    final storedDate = _prefs.getString(_keyLastVibeDate);
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    if (storedDate == today) {
      return _prefs.getString(_keyLastVibeContent);
    }
    return null;
  }

  Future<void> _saveCachedContent(String content) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _prefs.setString(_keyLastVibeContent, content);
    await _prefs.setString(_keyLastVibeDate, today);
  }

  /// Clear cached Local Vibe content to force refresh
  Future<void> clearCache() async {
    await _prefs.remove(_keyLastVibeContent);
    await _prefs.remove(_keyLastVibeDate);
  }

  String? _buildLocationQuery(String? currentGpsLocation) {
    if (_settings.useCurrentLocation) {
      if (currentGpsLocation != null) {
        return 'within ${_settings.radiusMiles} miles of $currentGpsLocation';
      }
      return null; // GPS needed but not provided
    } else {
      if (_settings.targetCities.isEmpty) return null;
      return _settings.targetCities.join(', ');
    }
  }

  String _ensureSpacing(String text) {
    // Simple spacer that ensures blank lines between bullets
    final lines = text.split('\n');
    final formatted = <String>[];
    
    for (var line in lines) {
      if (line.trim().startsWith('•') || line.trim().startsWith('*')) {
        formatted.add(''); // Add spacing before bullet
        formatted.add(line);
      } else {
        formatted.add(line);
      }
    }
    return formatted.join('\n').replaceAll('\n\n\n', '\n\n'); // Remove triple newlines
  }

  String _fixMalformedLinks(String text) {
    // Fix pattern: [• Description] (expand:Topic) -> [• Description](expand:Topic)
    // Also fix: • Description (expand:Topic) -> [• Description](expand:Topic)
    
    var fixed = text;
    
    // Pattern 1: [• text] (expand:topic) with space before parenthesis
    fixed = fixed.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\s+\(expand:([^)]+)\)'),
      (match) => '[${match.group(1)}](expand:${match.group(2)})',
    );
    
    // Pattern 2: • text (expand:topic) without square brackets
    fixed = fixed.replaceAllMapped(
      RegExp(r'(•[^(]+)\s*\(expand:([^)]+)\)'),
      (match) {
        final text = match.group(1)!.trim();
        final topic = match.group(2)!.trim();
        return '[$text](expand:$topic)';
      },
    );
    
    return fixed;
  }
}

