import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for managing button tap sounds throughout the app
class ButtonSoundService {
  static final ButtonSoundService _instance = ButtonSoundService._internal();
  factory ButtonSoundService() => _instance;
  ButtonSoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _soundEnabled = true;

  /// Initialize the sound service
  Future<void> initialize() async {
    await _player.setVolume(0.3); // Medium volume for subtle feedback
  }

  /// Enable or disable button sounds
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  /// Play a subtle tap sound using system feedback
  Future<void> playTap() async {
    if (!_soundEnabled) return;
    
    // Use system click sound via haptic feedback
    // This is more reliable than custom audio files and works across platforms
    await HapticFeedback.selectionClick();
  }

  /// Play a light tap sound for secondary actions
  Future<void> playLightTap() async {
    if (!_soundEnabled) return;
    await HapticFeedback.lightImpact();
  }

  /// Play a medium impact sound for primary actions
  Future<void> playMediumTap() async {
    if (!_soundEnabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Play a heavy impact sound for destructive or important actions
  Future<void> playHeavyTap() async {
    if (!_soundEnabled) return;
    await HapticFeedback.heavyImpact();
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _player.dispose();
  }
}

/// Riverpod provider for ButtonSoundService
final buttonSoundServiceProvider = Provider<ButtonSoundService>((ref) {
  final service = ButtonSoundService();
  service.initialize();
  return service;
});
