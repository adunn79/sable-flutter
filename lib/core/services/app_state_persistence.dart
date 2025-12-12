// App State Persistence Service
// Saves and restores chat state when app is backgrounded/foregrounded

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStatePersistence with WidgetsBindingObserver {
  static AppStatePersistence? _instance;
  static AppStatePersistence get instance => _instance ??= AppStatePersistence._();
  
  AppStatePersistence._();
  
  static const _chatStateKey = 'persisted_chat_state';
  static const _lastActiveTimeKey = 'last_active_time';
  static const _stateExpiryMinutes = 30; // Restore state if backgrounded < 30 mins
  
  VoidCallback? onBackground;
  VoidCallback? onForeground;
  
  /// Initialize the observer
  void initialize({VoidCallback? onBackground, VoidCallback? onForeground}) {
    this.onBackground = onBackground;
    this.onForeground = onForeground;
    WidgetsBinding.instance.addObserver(this);
    debugPrint('📱 App lifecycle observer initialized');
  }
  
  /// Dispose the observer
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      debugPrint('📱 App backgrounded');
      onBackground?.call();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App foregrounded');
      onForeground?.call();
    }
  }
  
  /// Save current chat state
  Future<void> saveChatState({
    required String currentRoute,
    required List<Map<String, dynamic>> recentMessages,
    String? inputText,
    Map<String, dynamic>? additionalState,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final state = {
        'route': currentRoute,
        'messages': recentMessages.take(10).toList(), // Keep last 10 messages
        'input_text': inputText,
        'additional': additionalState,
        'saved_at': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(_chatStateKey, jsonEncode(state));
      await prefs.setString(_lastActiveTimeKey, DateTime.now().toIso8601String());
      
      debugPrint('💾 Chat state saved (${recentMessages.length} messages)');
    } catch (e) {
      debugPrint('⚠️ Failed to save chat state: $e');
    }
  }
  
  /// Restore chat state if available and not expired
  Future<Map<String, dynamic>?> restoreChatState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final stateJson = prefs.getString(_chatStateKey);
      final lastActiveStr = prefs.getString(_lastActiveTimeKey);
      
      if (stateJson == null || lastActiveStr == null) {
        return null;
      }
      
      final lastActive = DateTime.tryParse(lastActiveStr);
      if (lastActive == null) return null;
      
      // Check if state expired (> 30 minutes old)
      final minutesSinceActive = DateTime.now().difference(lastActive).inMinutes;
      if (minutesSinceActive > _stateExpiryMinutes) {
        debugPrint('⏰ Chat state expired ($minutesSinceActive mins old)');
        await clearChatState();
        return null;
      }
      
      final state = jsonDecode(stateJson) as Map<String, dynamic>;
      debugPrint('💾 Chat state restored ($minutesSinceActive mins old)');
      
      return state;
    } catch (e) {
      debugPrint('⚠️ Failed to restore chat state: $e');
      return null;
    }
  }
  
  /// Clear saved chat state
  Future<void> clearChatState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatStateKey);
    debugPrint('🗑️ Chat state cleared');
  }
  
  /// Update last active time (call on any user interaction)
  Future<void> updateLastActiveTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastActiveTimeKey, DateTime.now().toIso8601String());
  }
  
  /// Check if we should restore state
  Future<bool> shouldRestoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActiveStr = prefs.getString(_lastActiveTimeKey);
    
    if (lastActiveStr == null) return false;
    
    final lastActive = DateTime.tryParse(lastActiveStr);
    if (lastActive == null) return false;
    
    final minutesSinceActive = DateTime.now().difference(lastActive).inMinutes;
    return minutesSinceActive <= _stateExpiryMinutes;
  }
}
