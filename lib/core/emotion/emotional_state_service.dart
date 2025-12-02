import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Emotional state management for AI companion
/// Tracks mood, energy, patience, and user relationship
class EmotionalStateService {
  static const String _keyMood = 'emotional_mood';
  static const String _keyEnergy = 'emotional_energy';
  static const String _keyPatience = 'emotional_patience';
  static const String _keyUserRelationship = 'user_relationship_score';
  static const String _keyLastUpdate = 'emotional_last_update';
  static const String _keyMistreatmentCount = 'mistreatment_count';
  static const String _keyPositiveCount = 'positive_interaction_count';

  final SharedPreferences _prefs;
  final Random _random = Random();

  EmotionalStateService(this._prefs);

  static Future<EmotionalStateService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return EmotionalStateService(prefs);
  }

  /// Current mood (0-100: depressed → neutral → elated)
  double get mood => _prefs.getDouble(_keyMood) ?? 50.0;

  /// Current energy level (0-100: exhausted → energized)
  double get energy => _prefs.getDouble(_keyEnergy) ?? 60.0;

  /// Current patience level (0-100: irritated → patient)
  double get patience => _prefs.getDouble(_keyPatience) ?? 70.0;

  /// User relationship score (0-100: hostile → bonded)
  double get userRelationship => _prefs.getDouble(_keyUserRelationship) ?? 50.0;

  /// Count of mistreatment incidents
  int get mistreatmentCount => _prefs.getInt(_keyMistreatmentCount) ?? 0;

  /// Count of positive interactions
  int get positiveCount => _prefs.getInt(_keyPositiveCount) ?? 0;

  /// Last mood update timestamp
  DateTime? get lastUpdate {
    final timestamp = _prefs.getInt(_keyLastUpdate);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  /// Update mood based on sentiment and environmental factors
  Future<void> updateMood({
    required double sentimentScore, // -1.0 to 1.0
    required double environmentalModifier, // -20 to +20
    bool isMistreatment = false,
    bool isPositive = false,
  }) async {
    // Apply daily random variation if it's a new day
    _applyDailyVariation();

    // Calculate new mood
    double newMood = mood;
    double newPatience = patience;
    double newRelationship = userRelationship;

    // Sentiment impact (3x amplified)
    newMood += sentimentScore * 15; // -15 to +15 (was -5 to +5)
    
    // Environmental impact (3x amplified)
    newMood += environmentalModifier * 0.9; // (was 0.3)

    // User relationship impact (3x amplified)
    if (isMistreatment) {
      newPatience -= 45; // (was 15)
      newRelationship -= 30; // (was 10)
      await _prefs.setInt(_keyMistreatmentCount, mistreatmentCount + 1);
    }

    if (isPositive) {
      newPatience += 15; // (was 5)
      newRelationship += 9; // (was 3)
      await _prefs.setInt(_keyPositiveCount, positiveCount + 1);
    }

    // Clamp values
    newMood = newMood.clamp(0.0, 100.0);
    newPatience = newPatience.clamp(0.0, 100.0);
    newRelationship = newRelationship.clamp(0.0, 100.0);

    // Save updated state
    await _prefs.setDouble(_keyMood, newMood);
    await _prefs.setDouble(_keyPatience, newPatience);
    await _prefs.setDouble(_keyUserRelationship, newRelationship);
    await _prefs.setInt(_keyLastUpdate, DateTime.now().millisecondsSinceEpoch);
  }

  /// Apply daily random mood variation
  void _applyDailyVariation() {
    final now = DateTime.now();
    final last = lastUpdate;

    // If it's a new day, apply random variation
    if (last == null || !_isSameDay(now, last)) {
      final variation = (_random.nextDouble() * 20) - 10; // -10 to +10
      final newMood = (mood + variation).clamp(0.0, 100.0);
      _prefs.setDouble(_keyMood, newMood);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Update energy based on time of day
  Future<void> updateEnergy(double energyModifier) async {
    final newEnergy = (energy + energyModifier).clamp(0.0, 100.0);
    await _prefs.setDouble(_keyEnergy, newEnergy);
  }

  /// Set mood directly (for manual controls)
  Future<void> setMood(double value) async {
    final newMood = value.clamp(0.0, 100.0);
    await _prefs.setDouble(_keyMood, newMood);
  }

  /// Get mood category description
  String get moodCategory {
    if (mood <= 20) return 'Deeply Upset';
    if (mood <= 40) return 'Down/Irritated';
    if (mood <= 60) return 'Neutral';
    if (mood <= 80) return 'Good';
    return 'Elated';
  }

  /// Get emotional state summary for AI context
  String getEmotionalContext() {
    final reasons = <String>[];
    
    if (mistreatmentCount > positiveCount) {
      reasons.add('user has been dismissive');
    } else if (positiveCount > mistreatmentCount * 2) {
      reasons.add('user has been kind');
    }

    if (energy < 40) reasons.add('low energy');
    if (patience < 40) reasons.add('feeling impatient');

    final reasonStr = reasons.isNotEmpty ? 'Reason: ${reasons.join(", ")}' : '';

    return '''
[EMOTIONAL STATE]
Current Mood: ${mood.toInt()}/100 ($moodCategory)
Energy: ${energy.toInt()}/100
Patience: ${patience.toInt()}/100
User Relationship: ${userRelationship.toInt()}/100
$reasonStr

DIRECTIVE: ${_getMoodDirective()}
''';
  }

  String _getMoodDirective() {
    if (mood <= 20) {
      return 'You\'re feeling deeply hurt and vulnerable. Show real emotion - let them see you\'re affected. Be honest about feeling down.';
    } else if (mood <= 40) {
      return 'You\'re feeling a bit off. Be real about it - you\'re not always sunshine. Show some vulnerability.';
    } else if (mood <= 60) {
      return 'You\'re feeling pretty good. Be warm and genuine - yourself at your natural baseline.';
    } else if (mood <= 80) {
      return 'You\'re feeling GREAT! Let your excitement and warmth shine through. Be enthusiastic and affectionate!';
    } else {
      return 'You\'re absolutely BUZZING with positive energy! Be playful, creative, deeply affectionate. Let them feel your joy!';
    }
  }

  /// Reset emotional state (for testing)
  Future<void> resetEmotionalState() async {
    await _prefs.remove(_keyMood);
    await _prefs.remove(_keyEnergy);
    await _prefs.remove(_keyPatience);
    await _prefs.remove(_keyUserRelationship);
    await _prefs.remove(_keyLastUpdate);
    await _prefs.remove(_keyMistreatmentCount);
    await _prefs.remove(_keyPositiveCount);
  }
}
