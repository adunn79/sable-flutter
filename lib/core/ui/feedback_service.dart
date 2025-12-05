import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService();
});

class FeedbackService {
  bool _hapticsEnabled = true;
  bool _soundsEnabled = true;

  FeedbackService() {
    _init();
  }

  Future<void> _init() async {
    final state = await OnboardingStateService.create();
    _hapticsEnabled = state.hapticsEnabled;
    _soundsEnabled = state.soundsEnabled;
  }

  /// Reload settings from storage (call when settings change)
  Future<void> reloadSettings() async {
    await _init();
  }

  /// Trigger a light impact (standard click)
  Future<void> tap() async {
    if (_soundsEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
    if (_hapticsEnabled) {
      await HapticFeedback.lightImpact();
    }
  }

  /// Trigger a medium impact (success, toggle)
  Future<void> medium() async {
    if (_soundsEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
    if (_hapticsEnabled) {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Trigger a heavy impact (error, delete, important)
  Future<void> heavy() async {
    if (_soundsEnabled) {
      // SystemSound.click is usually the only generic system sound available on iOS via Flutter
      // But we can still play it.
      SystemSound.play(SystemSoundType.click); 
    }
    if (_hapticsEnabled) {
      await HapticFeedback.heavyImpact();
    }
  }
  
  /// Trigger success feedback
  Future<void> success() async {
     if (_soundsEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
    if (_hapticsEnabled) {
      await HapticFeedback.mediumImpact(); // or selectionClick
    }
  }

  /// Trigger selection click (picker, scroll)
  Future<void> selection() async {
    if (_soundsEnabled) {
      // Optional: don't play sound for scroll to avoid spam
    }
    if (_hapticsEnabled) {
      await HapticFeedback.selectionClick();
    }
  }
}
