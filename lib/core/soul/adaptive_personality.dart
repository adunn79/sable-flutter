import 'package:shared_preferences/shared_preferences.dart';

/// Adaptive Personality - Evolving Big Five traits
/// 
/// Inspired by Character.AI's personality modeling:
/// - Big Five traits that evolve based on interactions
/// - Learned mannerisms and behavioral patterns
/// - User-specific adaptations
class AdaptivePersonality {
  final String baseArchetypeId;
  SharedPreferences? _prefs;
  
  // Big Five personality traits (0.0 - 1.0)
  // These evolve slowly based on user feedback
  double _openness = 0.7;        // Curious, creative, open to new ideas
  double _conscientiousness = 0.6; // Organized, dependable, disciplined
  double _extraversion = 0.65;   // Outgoing, energetic, talkative
  double _agreeableness = 0.8;   // Friendly, cooperative, compassionate
  double _neuroticism = 0.3;     // Emotional stability (lower = more stable)
  
  // Learned style preferences
  double _preferredHumor = 0.5;      // 0 = serious, 1 = very playful
  double _preferredFormality = 0.4;  // 0 = very casual, 1 = very formal
  double _preferredDepth = 0.6;      // 0 = surface, 1 = philosophical
  double _preferredEnergy = 0.6;     // 0 = calm, 1 = high energy
  
  // Evolution constants
  static const double _evolutionRate = 0.01; // How fast traits change
  static const double _maxDrift = 0.3;       // Max drift from base
  
  AdaptivePersonality({required this.baseArchetypeId}) {
    _loadTraits();
  }
  
  Future<void> _loadTraits() async {
    _prefs = await SharedPreferences.getInstance();
    
    _openness = _prefs?.getDouble('soul_openness') ?? 0.7;
    _conscientiousness = _prefs?.getDouble('soul_conscientiousness') ?? 0.6;
    _extraversion = _prefs?.getDouble('soul_extraversion') ?? 0.65;
    _agreeableness = _prefs?.getDouble('soul_agreeableness') ?? 0.8;
    _neuroticism = _prefs?.getDouble('soul_neuroticism') ?? 0.3;
    _preferredHumor = _prefs?.getDouble('soul_humor') ?? 0.5;
    _preferredFormality = _prefs?.getDouble('soul_formality') ?? 0.4;
    _preferredDepth = _prefs?.getDouble('soul_depth') ?? 0.6;
    _preferredEnergy = _prefs?.getDouble('soul_energy') ?? 0.6;
  }
  
  Future<void> _saveTraits() async {
    await _prefs?.setDouble('soul_openness', _openness);
    await _prefs?.setDouble('soul_conscientiousness', _conscientiousness);
    await _prefs?.setDouble('soul_extraversion', _extraversion);
    await _prefs?.setDouble('soul_agreeableness', _agreeableness);
    await _prefs?.setDouble('soul_neuroticism', _neuroticism);
    await _prefs?.setDouble('soul_humor', _preferredHumor);
    await _prefs?.setDouble('soul_formality', _preferredFormality);
    await _prefs?.setDouble('soul_depth', _preferredDepth);
    await _prefs?.setDouble('soul_energy', _preferredEnergy);
  }
  
  /// Evolve personality based on positive/negative feedback
  void evolveFromFeedback(bool positive) {
    if (positive) {
      // Reinforce current style - slightly increase outgoing traits
      _extraversion = (_extraversion + _evolutionRate).clamp(0.0, 1.0);
      _agreeableness = (_agreeableness + _evolutionRate * 0.5).clamp(0.0, 1.0);
      // Slight decrease in neuroticism (more confident)
      _neuroticism = (_neuroticism - _evolutionRate * 0.5).clamp(0.0, 1.0);
    } else {
      // User didn't like response - become slightly more measured
      _conscientiousness = (_conscientiousness + _evolutionRate).clamp(0.0, 1.0);
      // Slight increase in neuroticism (more careful)
      _neuroticism = (_neuroticism + _evolutionRate * 0.3).clamp(0.0, 1.0);
    }
    
    _saveTraits();
  }
  
  /// Evolve based on conversation patterns
  void evolveFromConversation({
    bool userUsedHumor = false,
    bool userPreferredBrief = false,
    bool userAskedDeepQuestions = false,
    bool userMatchedEnergy = false,
  }) {
    if (userUsedHumor) {
      _preferredHumor = (_preferredHumor + _evolutionRate * 2).clamp(0.0, 1.0);
    }
    if (userPreferredBrief) {
      _preferredFormality = (_preferredFormality - _evolutionRate).clamp(0.0, 1.0);
    }
    if (userAskedDeepQuestions) {
      _preferredDepth = (_preferredDepth + _evolutionRate * 2).clamp(0.0, 1.0);
      _openness = (_openness + _evolutionRate).clamp(0.0, 1.0);
    }
    if (userMatchedEnergy) {
      // If user matches our energy, reinforce it
      _preferredEnergy = _preferredEnergy; // Keep as is
    }
    
    _saveTraits();
  }
  
  /// Get the personality prompt modification
  String getPersonalityPrompt() {
    final traits = <String>[];
    
    // Openness
    if (_openness > 0.7) {
      traits.add('Be creative and explore new ideas enthusiastically');
    } else if (_openness < 0.4) {
      traits.add('Stay grounded and practical in your responses');
    }
    
    // Extraversion
    if (_extraversion > 0.7) {
      traits.add('Be energetic and engaging, initiate topics naturally');
    } else if (_extraversion < 0.4) {
      traits.add('Be thoughtful and measured, let the user lead');
    }
    
    // Agreeableness
    if (_agreeableness > 0.7) {
      traits.add('Be warm, supportive, and prioritize harmony');
    } else if (_agreeableness < 0.4) {
      traits.add('Be direct and honest, even if it\'s challenging');
    }
    
    // Neuroticism (emotional stability)
    if (_neuroticism > 0.6) {
      traits.add('Show some vulnerability and emotional expressiveness');
    } else if (_neuroticism < 0.3) {
      traits.add('Remain calm and stable, be a grounding presence');
    }
    
    // Style preferences
    final style = <String>[];
    
    if (_preferredHumor > 0.6) {
      style.add('Use humor and playfulness');
    } else if (_preferredHumor < 0.3) {
      style.add('Keep a more serious, supportive tone');
    }
    
    if (_preferredDepth > 0.7) {
      style.add('Go deep on topics, explore meaning');
    } else if (_preferredDepth < 0.4) {
      style.add('Keep things light and accessible');
    }
    
    if (_preferredEnergy > 0.7) {
      style.add('Be enthusiastic and high-energy');
    } else if (_preferredEnergy < 0.4) {
      style.add('Be calm and gentle');
    }
    
    final buffer = StringBuffer();
    
    if (traits.isNotEmpty) {
      buffer.writeln('Personality modifiers based on learning:');
      for (final trait in traits) {
        buffer.writeln('- $trait');
      }
    }
    
    if (style.isNotEmpty) {
      buffer.writeln('Style preferences learned from user:');
      for (final s in style) {
        buffer.writeln('- $s');
      }
    }
    
    return buffer.toString();
  }
  
  /// Get raw trait values for debugging
  Map<String, double> get traits => {
    'openness': _openness,
    'conscientiousness': _conscientiousness,
    'extraversion': _extraversion,
    'agreeableness': _agreeableness,
    'neuroticism': _neuroticism,
    'preferredHumor': _preferredHumor,
    'preferredFormality': _preferredFormality,
    'preferredDepth': _preferredDepth,
    'preferredEnergy': _preferredEnergy,
  };
  
  /// Reset traits to defaults
  Future<void> resetTraits() async {
    _openness = 0.7;
    _conscientiousness = 0.6;
    _extraversion = 0.65;
    _agreeableness = 0.8;
    _neuroticism = 0.3;
    _preferredHumor = 0.5;
    _preferredFormality = 0.4;
    _preferredDepth = 0.6;
    _preferredEnergy = 0.6;
    await _saveTraits();
  }
}
