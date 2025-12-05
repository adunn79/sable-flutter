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

  Future<String> getLocalVibeContent({String? currentGpsLocation}) async {
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

FORMATTING RULES:
- Use markdown headers for categories (e.g., "### 🍽️ New Openings").
- For each item, provide a single bullet point starting with "• ".
- Include specific details (time, place, price) where applicable.
- Add a blank line between each bullet point.
- Wrap the bullet content in a link like this: [• Content](expand:Topic) so I can click it.

Provide a vibrant, engaging digest of what's happening locally.
''';

    final result = await _webSearchService.search(query);
    
    // We can reuse the formatter from WebSearchService if we make it public, 
    // or just rely on the prompt to format it mostly right, and then apply a simple pass.
    // For now, let's assume the prompt does a good job, but we might need to ensure spacing.
    return _ensureSpacing(result);
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
}
