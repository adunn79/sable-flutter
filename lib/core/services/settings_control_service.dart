import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';

/// Represents a controllable setting
class SettingDefinition {
  final String key;
  final String title;
  final String subtitle;
  final String section;
  final SettingType type;
  final List<String> keywords; // Additional search keywords
  final bool aiControllable;

  const SettingDefinition({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.section,
    required this.type,
    this.keywords = const [],
    this.aiControllable = true,
  });

  /// Check if this setting matches a search query
  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();
    return title.toLowerCase().contains(lowerQuery) ||
        subtitle.toLowerCase().contains(lowerQuery) ||
        section.toLowerCase().contains(lowerQuery) ||
        keywords.any((k) => k.toLowerCase().contains(lowerQuery));
  }
}

enum SettingType { toggle, slider, selection }

/// Centralized service for managing and controlling settings
class SettingsControlService {
  static final List<SettingDefinition> _allSettings = [
    // FEEDBACK & IMMERSION
    const SettingDefinition(
      key: 'haptics_enabled',
      title: 'Haptic Feedback',
      subtitle: 'Vibrations on interaction',
      section: 'FEEDBACK & IMMERSION',
      type: SettingType.toggle,
      keywords: ['vibration', 'buzz', 'touch'],
    ),
    const SettingDefinition(
      key: 'sounds_enabled',
      title: 'Sound Effects',
      subtitle: 'UI sounds on interaction',
      section: 'FEEDBACK & IMMERSION',
      type: SettingType.toggle,
      keywords: ['audio', 'click', 'beep', 'noise'],
    ),

    // INTELLIGENCE
    const SettingDefinition(
      key: 'persistent_memory_enabled',
      title: 'Persistent Memory',
      subtitle: 'Remember across sessions',
      section: 'INTELLIGENCE',
      type: SettingType.toggle,
      keywords: ['memory', 'remember', 'history', 'context'],
      aiControllable: false, // Sensitive setting
    ),
    const SettingDefinition(
      key: 'apple_intelligence_enabled',
      title: 'Apple Intelligence',
      subtitle: 'On-device AI (Siri, Writing Tools)',
      section: 'INTELLIGENCE',
      type: SettingType.toggle,
      keywords: ['siri', 'apple', 'writing', 'ios'],
      aiControllable: false, // Requires device support
    ),
    const SettingDefinition(
      key: 'zodiac_enabled',
      title: 'Zodiac References',
      subtitle: 'Include zodiac sign in AI context',
      section: 'INTELLIGENCE',
      type: SettingType.toggle,
      keywords: ['horoscope', 'astrology', 'sign', 'star'],
    ),

    // NEWS
    const SettingDefinition(
      key: 'news_enabled',
      title: 'News Updates',
      subtitle: 'Get daily news briefings',
      section: 'NEWS',
      type: SettingType.toggle,
      keywords: ['daily', 'briefing', 'updates', 'headlines'],
    ),
    const SettingDefinition(
      key: 'daily_briefing_trigger',
      title: 'Briefing Schedule',
      subtitle: 'When to show your daily summary',
      section: 'NEWS',
      type: SettingType.selection,
      keywords: ['time', 'schedule', 'when', 'trigger', 'launch', 'morning'],
    ),

    // PERMISSIONS
    const SettingDefinition(
      key: 'permission_gps',
      title: 'Location Access',
      subtitle: 'GPS for weather and local info',
      section: 'PRIVACY FORTRESS',
      type: SettingType.toggle,
      keywords: ['gps', 'location', 'weather', 'map'],
      aiControllable: false, // Privacy sensitive
    ),
    const SettingDefinition(
      key: 'permission_mic',
      title: 'Microphone Access',
      subtitle: 'Voice input capability',
      section: 'PRIVACY FORTRESS',
      type: SettingType.toggle,
      keywords: ['voice', 'audio', 'speak', 'speech'],
      aiControllable: false, // Privacy sensitive
    ),
    const SettingDefinition(
      key: 'permission_camera',
      title: 'Camera Access',
      subtitle: 'Photo and video capture',
      section: 'PRIVACY FORTRESS',
      type: SettingType.toggle,
      keywords: ['photo', 'video', 'picture'],
      aiControllable: false, // Privacy sensitive
    ),

    // DISPLAY
    const SettingDefinition(
      key: 'clock_use_24hour',
      title: '24-Hour Clock',
      subtitle: 'Use 24-hour time format',
      section: 'DISPLAY',
      type: SettingType.toggle,
      keywords: ['time', 'format', 'military'],
    ),
    const SettingDefinition(
      key: 'clock_is_analog',
      title: 'Analog Clock',
      subtitle: 'Show analog clock face',
      section: 'DISPLAY',
      type: SettingType.toggle,
      keywords: ['clock', 'face', 'digital'],
    ),

    // APP LAUNCH
    const SettingDefinition(
      key: 'start_on_last_tab',
      title: 'Resume Last Session',
      subtitle: 'Open app to the last visited screen',
      section: 'APP EXPERIENCE',
      type: SettingType.toggle,
      keywords: ['start', 'launch', 'open', 'resume', 'tab'],
    ),

    // VOICE
    const SettingDefinition(
      key: 'auto_speak',
      title: 'Auto-Speak',
      subtitle: 'Automatically read responses',
      section: 'VOICE',
      type: SettingType.toggle,
      keywords: ['speak', 'read', 'tts', 'text to speech'],
    ),
  ];

  /// Get all setting definitions for search
  static List<SettingDefinition> getAllSettings() => _allSettings;

  /// Get settings matching a search query
  static List<SettingDefinition> searchSettings(String query) {
    if (query.isEmpty) return _allSettings;
    return _allSettings.where((s) => s.matchesSearch(query)).toList();
  }

  /// Get sections with their settings filtered by search
  static Map<String, List<SettingDefinition>> getSettingsBySection(String query) {
    final filtered = searchSettings(query);
    final grouped = <String, List<SettingDefinition>>{};
    for (final setting in filtered) {
      grouped.putIfAbsent(setting.section, () => []).add(setting);
    }
    return grouped;
  }

  /// Get a setting's current value
  static Future<dynamic> getSettingValue(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final stateService = await OnboardingStateService.create();

    switch (key) {
      case 'haptics_enabled':
        return stateService.hapticsEnabled;
      case 'sounds_enabled':
        return stateService.soundsEnabled;
      case 'zodiac_enabled':
        return stateService.zodiacEnabled;
      case 'news_enabled':
        return stateService.newsEnabled;
      case 'persistent_memory_enabled':
        return prefs.getBool('persistent_memory_enabled') ?? true;
      case 'apple_intelligence_enabled':
        return prefs.getBool('apple_intelligence_enabled') ?? false;
      case 'permission_gps':
        return stateService.permissionGps;
      case 'permission_mic':
        return stateService.permissionMic;
      case 'permission_camera':
        return stateService.permissionCamera;
      case 'clock_use_24hour':
        return prefs.getBool('clock_use_24hour') ?? false;
      case 'clock_is_analog':
        return prefs.getBool('clock_is_analog') ?? false;
      case 'auto_speak':
        return prefs.getBool('auto_speak') ?? true;
      case 'daily_briefing_trigger':
        return prefs.getString('daily_briefing_trigger') ?? 'time';
      default:
        return null;
    }
  }

  /// Update a setting's value
  /// Returns true if successful, false if setting not found or not AI-controllable
  static Future<bool> updateSetting(String key, dynamic value) async {
    // Find the setting definition
    final setting = _allSettings.firstWhere(
      (s) => s.key == key,
      orElse: () => const SettingDefinition(
        key: '',
        title: '',
        subtitle: '',
        section: '',
        type: SettingType.toggle,
        aiControllable: false,
      ),
    );

    if (setting.key.isEmpty) {
      debugPrint('Setting not found: $key');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final stateService = await OnboardingStateService.create();

    try {
      switch (key) {
        case 'haptics_enabled':
          await stateService.setHapticsEnabled(value as bool);
          break;
        case 'sounds_enabled':
          await stateService.setSoundsEnabled(value as bool);
          break;
        case 'zodiac_enabled':
          await stateService.setZodiacEnabled(value as bool);
          break;
        case 'news_enabled':
          await stateService.setNewsEnabled(value as bool);
          break;
        case 'persistent_memory_enabled':
          await prefs.setBool('persistent_memory_enabled', value as bool);
          break;
        case 'apple_intelligence_enabled':
          await prefs.setBool('apple_intelligence_enabled', value as bool);
          break;
        case 'clock_use_24hour':
          await prefs.setBool('clock_use_24hour', value as bool);
          break;
        case 'clock_is_analog':
          await prefs.setBool('clock_is_analog', value as bool);
          break;
        case 'auto_speak':
          await prefs.setBool('auto_speak', value as bool);
          break;
        case 'daily_briefing_trigger':
          await prefs.setString('daily_briefing_trigger', value as String);
          break;
        case 'start_on_last_tab':
          await prefs.setBool('start_on_last_tab', value as bool);
          break;
        default:
          debugPrint('Unhandled setting update: $key');
          return false;
      }
      debugPrint('✅ Setting updated: $key = $value');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to update setting $key: $e');
      return false;
    }
  }

  /// Parse natural language intent to find setting and desired value
  /// Returns null if no valid setting command detected
  static SettingIntent? parseSettingIntent(String message) {
    final lowerMessage = message.toLowerCase();

    // Check for enable/disable patterns
    final enablePatterns = ['turn on', 'enable', 'activate', 'switch on', 'start'];
    final disablePatterns = ['turn off', 'disable', 'deactivate', 'switch off', 'stop'];

    bool? desiredValue;
    String? matchedPattern;

    for (final pattern in enablePatterns) {
      if (lowerMessage.contains(pattern)) {
        desiredValue = true;
        matchedPattern = pattern;
        break;
      }
    }
    if (desiredValue == null) {
      for (final pattern in disablePatterns) {
        if (lowerMessage.contains(pattern)) {
          desiredValue = false;
          matchedPattern = pattern;
          break;
        }
      }
    }

    if (desiredValue == null || matchedPattern == null) return null;

    // Find which setting is being referenced
    for (final setting in _allSettings) {
      if (!setting.aiControllable) continue;

      // Check if the message mentions this setting
      final titleWords = setting.title.toLowerCase().split(' ');
      final keywordMatches = setting.keywords.any((k) => lowerMessage.contains(k.toLowerCase()));
      final titleMatch = titleWords.any((word) => word.length > 3 && lowerMessage.contains(word));

      if (keywordMatches || titleMatch) {
        return SettingIntent(
          settingKey: setting.key,
          settingTitle: setting.title,
          newValue: desiredValue,
        );
      }
    }

    return null;
  }
}

/// Represents a parsed setting change intent
class SettingIntent {
  final String settingKey;
  final String settingTitle;
  final dynamic newValue;

  const SettingIntent({
    required this.settingKey,
    required this.settingTitle,
    required this.newValue,
  });
}
