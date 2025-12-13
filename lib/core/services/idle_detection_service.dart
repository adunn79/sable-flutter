import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for detecting user inactivity and triggering clock mode
/// Implements best-in-class idle detection similar to iOS StandBy mode
class IdleDetectionService {
  static IdleDetectionService? _instance;
  
  Timer? _idleTimer;
  bool _isEnabled = true;
  int _timeoutMinutes = 2;
  bool _isClockModeActive = false;
  String? _lastScreenRoute;
  
  VoidCallback? onIdleTriggered;
  VoidCallback? onActiveTriggered;
  
  // Singleton
  static Future<IdleDetectionService> getInstance() async {
    _instance ??= IdleDetectionService._();
    await _instance!._loadPreferences();
    return _instance!;
  }
  
  IdleDetectionService._();
  
  // Getters
  bool get isEnabled => _isEnabled;
  int get timeoutMinutes => _timeoutMinutes;
  bool get isClockModeActive => _isClockModeActive;
  String? get lastScreenRoute => _lastScreenRoute;
  
  // Settings
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('clock_auto_idle_enabled', enabled);
    
    if (enabled) {
      resetIdleTimer();
    } else {
      _idleTimer?.cancel();
      _idleTimer = null;
    }
    debugPrint('⏰ IdleDetection: ${enabled ? "Enabled" : "Disabled"}');
  }
  
  Future<void> setTimeoutMinutes(int minutes) async {
    _timeoutMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('clock_idle_timeout_minutes', minutes);
    
    // Reset timer with new duration
    if (_isEnabled) {
      resetIdleTimer();
    }
    debugPrint('⏰ IdleDetection: Timeout set to $minutes minutes');
  }
  
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('clock_auto_idle_enabled') ?? true; // Default ON at startup
    _timeoutMinutes = prefs.getInt('clock_idle_timeout_minutes') ?? 10; // Default 10 minutes
    debugPrint('⏰ IdleDetection: Loaded - enabled=$_isEnabled, timeout=$_timeoutMinutes min');
  }
  
  /// Call this on any user interaction to reset the idle timer
  void resetIdleTimer() {
    if (!_isEnabled || _isClockModeActive) return;
    
    _idleTimer?.cancel();
    _idleTimer = Timer(Duration(minutes: _timeoutMinutes), _onIdleTimeout);
  }
  
  /// Called when idle timeout is reached
  void _onIdleTimeout() {
    if (!_isEnabled || _isClockModeActive) return;
    
    debugPrint('⏰ IdleDetection: Timeout reached - triggering clock mode');
    _isClockModeActive = true;
    onIdleTriggered?.call();
  }
  
  /// Save the current screen route before entering clock mode
  void saveLastRoute(String route) {
    _lastScreenRoute = route;
    debugPrint('⏰ IdleDetection: Saved last route = $route');
  }
  
  /// Called when user exits clock mode (tap, movement, etc.)
  void exitClockMode() {
    _isClockModeActive = false;
    resetIdleTimer();
    onActiveTriggered?.call();
    debugPrint('⏰ IdleDetection: Exited clock mode');
  }
  
  /// Temporarily pause idle detection (e.g., during video playback)
  void pauseDetection() {
    _idleTimer?.cancel();
    _idleTimer = null;
    debugPrint('⏰ IdleDetection: Paused');
  }
  
  /// Resume idle detection
  void resumeDetection() {
    if (_isEnabled && !_isClockModeActive) {
      resetIdleTimer();
      debugPrint('⏰ IdleDetection: Resumed');
    }
  }
  
  /// Dispose of resources
  void dispose() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _instance = null;
  }
}
