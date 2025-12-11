import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/services/settings_control_service.dart';
import '../../../src/config/app_config.dart';

/// Response from the Settings Agent
class SettingsAgentResponse {
  final String message;
  final SettingIntent? executedIntent;
  final List<SettingDefinition>? searchResults;
  final SettingsAgentAction action;

  const SettingsAgentResponse({
    required this.message,
    this.executedIntent,
    this.searchResults,
    this.action = SettingsAgentAction.chat,
  });
}

enum SettingsAgentAction {
  chat,           // General conversation
  settingChanged, // A setting was toggled/changed
  searchResults,  // Showing settings search results
  navigate,       // Navigate to a settings section
  error,          // Something went wrong
}

/// Specialized AI brain for controlling app settings
/// Uses Gemini 2.0 Flash for fast response times
class SettingsAgentBrain {
  GenerativeModel? _model;
  ChatSession? _chatSession;
  
  /// Initialize the agent
  Future<void> init() async {
    final apiKey = AppConfig.googleKey;
    if (apiKey.isEmpty) {
      debugPrint('⚠️ SettingsAgentBrain: No Google API key found');
      return;
    }
    
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      systemInstruction: Content.text(_buildSystemPrompt()),
    );
    
    _chatSession = _model!.startChat();
    debugPrint('✅ SettingsAgentBrain initialized');
  }
  
  String _buildSystemPrompt() {
    return '''
You are Aeliana's Settings Assistant - a helpful AI that controls app settings.

YOUR CAPABILITIES:
1. Toggle settings on/off (e.g., "turn on haptic feedback")
2. Search for settings (e.g., "find voice settings")
3. Explain what settings do (e.g., "what does zodiac references mean?")
4. List current settings status

RESPONSE RULES:
- Be concise and friendly
- When changing settings, confirm the action briefly
- For searches, list matching settings
- For explanations, be helpful but brief

AVAILABLE SETTINGS:
${_getSettingsSummary()}

When the user wants to change a setting, respond with the confirmation.
The system will handle the actual setting change.
''';
  }
  
  String _getSettingsSummary() {
    final settings = SettingsControlService.getAllSettings();
    final buffer = StringBuffer();
    
    String currentSection = '';
    for (final setting in settings) {
      if (setting.section != currentSection) {
        currentSection = setting.section;
        buffer.writeln('\n[$currentSection]');
      }
      buffer.writeln('- ${setting.title}: ${setting.subtitle}${setting.aiControllable ? '' : ' (read-only)'}');
    }
    
    return buffer.toString();
  }
  
  /// Process a user command and return the response
  Future<SettingsAgentResponse> processCommand(String input) async {
    if (_model == null) {
      await init();
    }
    
    if (_model == null) {
      return const SettingsAgentResponse(
        message: "I'm having trouble connecting. Please try again.",
        action: SettingsAgentAction.error,
      );
    }
    
    final lowerInput = input.toLowerCase();
    
    // 1. Check for direct setting change intent first
    final settingIntent = SettingsControlService.parseSettingIntent(input);
    if (settingIntent != null) {
      return await _handleSettingChange(settingIntent);
    }
    
    // 2. Check for search/list intent
    if (_isSearchIntent(lowerInput)) {
      return _handleSearch(input);
    }
    
    // 3. Check for status inquiry
    if (_isStatusIntent(lowerInput)) {
      return await _handleStatusInquiry();
    }
    
    // 4. Fall back to AI chat for explanations and general help
    try {
      final response = await _chatSession!.sendMessage(Content.text(input));
      final text = response.text ?? "I'm not sure how to help with that.";
      
      return SettingsAgentResponse(
        message: text,
        action: SettingsAgentAction.chat,
      );
    } catch (e) {
      debugPrint('SettingsAgentBrain error: $e');
      return SettingsAgentResponse(
        message: "Sorry, I had trouble processing that. Try asking about a specific setting.",
        action: SettingsAgentAction.error,
      );
    }
  }
  
  /// Handle a setting change request
  Future<SettingsAgentResponse> _handleSettingChange(SettingIntent intent) async {
    final success = await SettingsControlService.updateSetting(
      intent.settingKey,
      intent.newValue,
    );
    
    if (success) {
      final action = intent.newValue == true ? 'enabled' : 'disabled';
      return SettingsAgentResponse(
        message: "✓ ${intent.settingTitle} has been $action.",
        executedIntent: intent,
        action: SettingsAgentAction.settingChanged,
      );
    } else {
      return SettingsAgentResponse(
        message: "Sorry, I couldn't change ${intent.settingTitle}. It may be a protected setting.",
        action: SettingsAgentAction.error,
      );
    }
  }
  
  /// Handle search for settings
  SettingsAgentResponse _handleSearch(String query) {
    // Extract search term
    final searchPatterns = ['find', 'search', 'where is', 'show me', 'look for'];
    String searchTerm = query.toLowerCase();
    
    for (final pattern in searchPatterns) {
      searchTerm = searchTerm.replaceAll(pattern, '').trim();
    }
    
    final results = SettingsControlService.searchSettings(searchTerm);
    
    if (results.isEmpty) {
      return SettingsAgentResponse(
        message: "I couldn't find any settings matching '$searchTerm'. Try different words.",
        action: SettingsAgentAction.searchResults,
      );
    }
    
    final buffer = StringBuffer("Found ${results.length} setting(s):\n");
    for (final setting in results) {
      buffer.writeln("• ${setting.title} - ${setting.subtitle}");
    }
    
    return SettingsAgentResponse(
      message: buffer.toString(),
      searchResults: results,
      action: SettingsAgentAction.searchResults,
    );
  }
  
  /// Handle status inquiry (what's enabled/disabled)
  Future<SettingsAgentResponse> _handleStatusInquiry() async {
    final settings = SettingsControlService.getAllSettings();
    final enabledSettings = <String>[];
    final disabledSettings = <String>[];
    
    for (final setting in settings) {
      if (setting.type == SettingType.toggle) {
        final value = await SettingsControlService.getSettingValue(setting.key);
        if (value == true) {
          enabledSettings.add(setting.title);
        } else {
          disabledSettings.add(setting.title);
        }
      }
    }
    
    final buffer = StringBuffer();
    buffer.writeln("📱 **Settings Status**\n");
    buffer.writeln("✅ **Enabled:** ${enabledSettings.join(', ')}");
    buffer.writeln("\n❌ **Disabled:** ${disabledSettings.join(', ')}");
    
    return SettingsAgentResponse(
      message: buffer.toString(),
      action: SettingsAgentAction.chat,
    );
  }
  
  bool _isSearchIntent(String input) {
    final searchPatterns = ['find', 'search', 'where is', 'where\'s', 'show me', 'look for', 'list'];
    return searchPatterns.any((p) => input.contains(p));
  }
  
  bool _isStatusIntent(String input) {
    final statusPatterns = ['what\'s on', 'what is on', 'what\'s enabled', 'show status', 
                            'current settings', 'what settings', 'list enabled'];
    return statusPatterns.any((p) => input.contains(p));
  }
  
  /// Reset the chat session
  void resetConversation() {
    if (_model != null) {
      _chatSession = _model!.startChat();
    }
  }
}
