import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'bond_engine.dart';

part 'emotional_state.g.dart';

/// The current visible emotion of the AI.
enum Emotion {
  happy,
  sad,
  mad,
  tired,
  neutral,
}

@Riverpod(keepAlive: true)
class EmotionalState extends _$EmotionalState {
  @override
  Emotion build() {
    return Emotion.neutral;
  }

  /// Updates the current emotion.
  /// If the emotion is [Emotion.mad], it automatically triggers the
  /// Bond Engine's respect protocol (Cooled state).
  void setEmotion(Emotion emotion) {
    state = emotion;

    if (emotion == Emotion.mad) {
      ref.read(bondEngineProvider.notifier).triggerRespectProtocol();
    }
  }

  /// Resets emotion to neutral.
  void reset() {
    state = Emotion.neutral;
  }
}
