import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sable/core/ai/room_brain/room_brain_base.dart';
import 'package:sable/core/ai/agent_context.dart';

/// Settings Brain - Domain expertise for app configuration
/// Handles: settings changes, privacy controls, feature toggles, data export
class SettingsBrain extends RoomBrain {
  SettingsBrain({
    required super.memorySpine,
    required super.tools,
  });

  @override
  String get domain => 'settings';

  @override
  List<String> get capabilities => [
    'app_configuration',
    'toggle_features',
    'privacy_controls',
    'data_export',
    'preference_management',
  ];

  @override
  bool canHandle(String query) {
    final lowerQuery = query.toLowerCase();
    
    // Settings-related keywords
    final settingsKeywords = [
      'setting',
      'turn off',
      'turn on',
      'enable',
      'disable',
      'notification',
      'privacy',
      'export',
      'delete',
      'change',
      'configure',
      'preference',
    ];
    
    return settingsKeywords.any((kw) => lowerQuery.contains(kw));
  }

  @override
  Future<BrainResponse> processQuery(String query, AgentContext context) async {
    final lowerQuery = query.toLowerCase();

    // Intent detection - Toggle notifications?
    if (_isNotificationToggleIntent(lowerQuery)) {
      debugPrint('🔔 Settings Brain: Notification toggle intent detected');
      
      final wantsOn = lowerQuery.contains('on') || lowerQuery.contains('enable');
      
      // Actually toggle the setting
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', wantsOn);
      
      return BrainResponse.simple(
        wantsOn 
          ? "Done! ✅ I've enabled notifications for you. You'll receive helpful reminders and updates."
          : "Done! ✅ I've turned off notifications. You won't be disturbed.",
      );
    }

    // Intent detection - Privacy mode?
    if (_isPrivacyIntent(lowerQuery)) {
      debugPrint('🔒 Settings Brain: Privacy intent detected');
      
      final prefsState = memorySpine.read('PREFS_STATE');
      final privacyMode = prefsState['privacy_mode'] ?? false;
      
      return BrainResponse.simple(
        "Privacy Mode is currently ${privacyMode ? 'ON 🔒' : 'OFF'}.\n\n"
        "When enabled, I minimize data collection and disable cloud sync. "
        "You can toggle this in Settings → Privacy.",
      );
    }

    // Intent detection - Export data?
    if (_isDataExportIntent(lowerQuery)) {
      debugPrint('📤 Settings Brain: Data export intent detected');
      
      return BrainResponse.simple(
        "You can export all your data (journal entries, chat history, health data) "
        "in Settings → Privacy → Export Data. I'll generate a JSON file for you!",
      );
    }

    // Intent detection - Change character?
    if (_isCharacterChangeIntent(lowerQuery)) {
      debugPrint('🎭 Settings Brain: Character change intent detected');
      
      final prefsState = memorySpine.read('PREFS_STATE');
      final currentChar = prefsState['selected_character'] ?? 'aeliana';
      
      return BrainResponse.simple(
        "You're currently chatting with ${_getCharacterName(currentChar)}! "
        "Want to switch? Options:\n"
        "• Aeliana (warm & visionary)\n"
        "• Sable (professional & crisp)\n"
        "• Marco (protective & brotherly)\n"
        "• Echo (neutral & precise)\n"
        "• Kai (calm & mindful)\n\n"
        "Change in Settings → Personality.",
      );
    }

    // Default: General settings guidance
    return BrainResponse.simple(
      "I can help you configure the app! I can assist with:\n"
      "• Turning features on/off\n"
      "• Privacy settings\n"
      "• Exporting your data\n"
      "• Changing your AI personality\n\n"
      "What would you like to adjust?",
    );
  }

  // ========== INTENT DETECTION ==========

  bool _isNotificationToggleIntent(String query) {
    return query.contains('notification') &&
           (query.contains('turn') || query.contains('enable') || 
            query.contains('disable') || query.contains('off'));
  }

  bool _isPrivacyIntent(String query) {
    return query.contains('privacy') || 
           query.contains('data collection') ||
           query.contains('secure');
  }

  bool _isDataExportIntent(String query) {
    return query.contains('export') || 
           query.contains('download') ||
           (query.contains('my data') && query.contains('get'));
  }

  bool _isCharacterChangeIntent(String query) {
    return (query.contains('change') || query.contains('switch')) &&
           (query.contains('personality') || query.contains('character') || 
            query.contains('voice') || query.contains('companion'));
  }

  // ========== HELPERS ==========

  String _getCharacterName(String id) {
    switch (id.toLowerCase()) {
      case 'aeliana': return 'Aeliana';
      case 'sable': return 'Sable';
      case 'marco': return 'Marco';
      case 'echo': return 'Echo';
      case 'kai': return 'Kai';
      default: return 'Aeliana';
    }
  }
}
