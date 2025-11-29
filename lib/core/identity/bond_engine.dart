import 'package:riverpod_annotation/riverpod_annotation.dart';

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

  /// Checks if the current state allows for proactive engagement.
  bool get isProactive => state == BondState.warm;
}
