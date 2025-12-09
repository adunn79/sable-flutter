import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'bond_engine.g.dart';

/// The emotional connection state between the user and the AI.
enum BondState {
  /// Default state: Affectionate, engaged, proactive.
  warm,

  /// Professional, concise.
  neutral,

  /// Brief, distant, transactional. Triggered by respect violations.
  cooled,
}

@Riverpod(keepAlive: true)
class BondEngine extends _$BondEngine {
  @override
  BondState build() {
    loadBond();
    return BondState.warm;
  }

  /// Triggers the "Respect Protocol" -> transitions to Cooled state.
  /// Should be called when the user violates safety/respect guidelines.
  void triggerRespectProtocol() {
    state = BondState.cooled;
  }

  /// Resets the bond to Neutral.
  /// Useful for professional contexts or manual resets.
  void resetToNeutral() {
    state = BondState.neutral;
  }

  /// Restores the bond to Warm.
  /// Should be called after a cooldown period or positive interaction.
  void restoreWarmth() {
    state = BondState.warm;
  }

  bool get isProactive => state == BondState.warm;

  static const _storageKey = 'bond_score';
  int _score = 50; // Default: Neutral (50/100)

  int get score => _score;

  /// Loads the bond score from storage
  Future<void> loadBond() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _score = prefs.getInt(_storageKey) ?? 50;
      _updateState();
    } catch (e) {
      debugPrint('⚠️ Failed to load bond score: $e');
    }
  }

  /// Process an action that affects the bond
  Future<void> processAction(BondAction action) async {
    final oldState = state;
    
    // Calculate new score
    int impact = 0;
    switch (action) {
      case BondAction.dailyCheckIn:
        impact = 2; // Small consistent boost
        break;
      case BondAction.deepConversation:
        impact = 5; // Meaningful connection
        break;
      case BondAction.vulnerability:
        impact = 8; // Trusting the AI
        break;
      case BondAction.gift:
        impact = 10; // User did something special
        break;
      case BondAction.neglect:
        impact = -1; // Daily decay
        break;
      case BondAction.rudeBehavior:
        impact = -10; // Disrespect
        break;
      case BondAction.harassment:
        impact = -25; // Severe violation
        break;
    }

    _score = (_score + impact).clamp(0, 100);
    await _saveBond();
    _updateState();
    
    // Log significant shifts
    if (state != oldState) {
      debugPrint('💔❤️ Bond State Shift: $oldState -> $state (Score: $_score)');
    }
  }

  void _updateState() {
    if (_score < 30) {
      state = BondState.cooled;
    } else if (_score < 70) {
      state = BondState.neutral;
    } else {
      state = BondState.warm;
    }
  }

  Future<void> _saveBond() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_storageKey, _score);
    } catch (e) {
      debugPrint('⚠️ Failed to save bond score: $e');
    }
  }

  // Legacy/Manual overrides
  void triggerRespectProtocol() => processAction(BondAction.harassment);
  void resetToNeutral() {
     _score = 50;
     _saveBond(); 
     _updateState();
  }
  void restoreWarmth() {
     _score = 75;
     _saveBond();
     _updateState();
  }
}

/// Actions that impact the bond score
enum BondAction {
  dailyCheckIn,
  deepConversation,
  vulnerability,
  gift,
  neglect,
  rudeBehavior,
  harassment
}
