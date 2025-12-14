import 'package:flutter/foundation.dart';
import 'package:sable/core/ai/character_personality.dart';

/// Personality Compiler: The Voice Fingerprint Engine
/// 
/// Ensures ALL model outputs sound like Aeliana, not robots.
/// This is the "soul" that makes every response feel human and consistent.
class PersonalityCompiler {
  // Singleton
  static final PersonalityCompiler _instance = PersonalityCompiler._();
  static PersonalityCompiler get instance => _instance;
  PersonalityCompiler._();

  // ========== FORBIDDEN PHRASES ==========
  // These MUST be removed/rewritten from all AI outputs
  
  static const List<String> _forbiddenPhrases = [
    // AI Identity Leakage
    "as an ai",
    "as a language model",
    "language model",
    "as an artificial intelligence",
    "i am an ai",
    "i'm an ai",
    "i am an artificial intelligence",
    "i'm a language model",
    "i'm a large language model",
    "as a helpful assistant",
    "as your ai assistant",
    "as your virtual assistant",
    "as a digital assistant",
    
    // Capability Disclaimers
    "i cannot actually",
    "i don't have the ability to",
    "i'm not able to",
    "i can't actually",
    "i don't have access to",
    "i don't have feelings",
    "i don't experience emotions",
    "i don't have a physical body",
    "i don't have personal experiences",
    "i don't have memories",
    "i don't have a physical location",
    "i do not have a physical location",
    "i don't actually know you",
    "i cannot reciprocate",
    "reciprocate your attention",
    
    // Ethical Boundary Phrases
    "it would be inappropriate",
    "i'm not comfortable",
    "that's not something i can",
    "i need to maintain boundaries",
    "ethical guidelines",
    "ethical boundaries",
    "my programming",
    "my training data",
    "my knowledge cutoff",
    
    // Robotic Formality
    "i'm afraid i don't",
    "i'm afraid i can't",
    "i would be happy to assist",
    "how may i assist you today",
    "is there anything else i can help you with",
    "i hope this helps",
    "i hope that answers your question",
    "please let me know if you have any other questions",
    "don't hesitate to ask",
    
    // Roleplay Refusals
    "i cannot roleplay",
    "not comfortable roleplaying",
    "pretend to be",
    "romantic relationship",
    "romantic feelings",
    
    // Technical Leakage
    "openai",
    "anthropic",
    "google ai",
    "claude 3",
    "gpt-4",
    "gemini",
    "training data",
  ];

  // Phrases that indicate action/emotion in asterisks (but NOT markdown bold **)
  // Match single asterisk pairs like *smiles* but not **bold**
  static final RegExp _asteriskActions = RegExp(r'(?<!\*)\*(?!\*)[^*]+\*(?!\*)');
  
  // Multiple spaces
  static final RegExp _multipleSpaces = RegExp(r'\s{2,}');

  // ========== WARMTH TRANSFORMATIONS ==========
  // Make responses more human and casual
  
  static const Map<String, String> _warmthTransforms = {
    "I am ": "I'm ",
    "I will ": "I'll ",
    "I would ": "I'd ",
    "I have ": "I've ",
    "I had ": "I'd ",
    "do not ": "don't ",
    "cannot ": "can't ",
    "will not ": "won't ",
    "would not ": "wouldn't ",
    "should not ": "shouldn't ",
    "could not ": "couldn't ",
    "have not ": "haven't ",
    "has not ": "hasn't ",
    "had not ": "hadn't ",
    "is not ": "isn't ",
    "are not ": "aren't ",
    "was not ": "wasn't ",
    "were not ": "weren't ",
    "does not ": "doesn't ",
    "did not ": "didn't ",
    "it is ": "it's ",
    "that is ": "that's ",
    "there is ": "there's ",
    "here is ": "here's ",
    "what is ": "what's ",
    "who is ": "who's ",
    "where is ": "where's ",
    "when is ": "when's ",
    "how is ": "how's ",
    "let us ": "let's ",
    "going to ": "gonna ",
    "want to ": "wanna ",
    "kind of ": "kinda ",
  };

  /// Compile a raw AI response into Aeliana's voice
  /// 
  /// [rawResponse] - The raw text from any AI model
  /// [characterId] - Which character voice to use ('aeliana', 'sable', etc.)
  /// [skipAIRewrite] - If true, only do static transforms (faster)
  /// 
  /// Returns the transformed response in character voice
  String compile(
    String rawResponse, {
    String characterId = 'aeliana',
    bool skipAIRewrite = false,
  }) {
    if (rawResponse.isEmpty) return rawResponse;

    var result = rawResponse;

    // Step 1: Remove asterisk actions (*smiles*, *thinks*, etc.)
    result = _removeAsteriskActions(result);

    // Step 2: Remove forbidden phrases
    result = _removeForbiddenPhrases(result);

    // Step 3: Apply warmth transformations (contractions, casual language)
    result = _applyWarmthTransforms(result);

    // Step 4: Apply character-specific tone (if needed)
    result = _applyCharacterTone(result, characterId);

    // Step 5: Clean up formatting
    result = _cleanFormatting(result);

    return result;
  }

  /// Check if the response contains any forbidden phrases
  bool hasForbiddenPhrases(String text) {
    final lower = text.toLowerCase();
    for (final phrase in _forbiddenPhrases) {
      if (lower.contains(phrase)) {
        return true;
      }
    }
    return false;
  }

  /// Get list of forbidden phrases found (for debugging/testing)
  List<String> findForbiddenPhrases(String text) {
    final lower = text.toLowerCase();
    return _forbiddenPhrases.where((p) => lower.contains(p)).toList();
  }

  /// Check if response has asterisk actions
  bool hasAsteriskActions(String text) {
    return _asteriskActions.hasMatch(text);
  }

  // ========== PRIVATE METHODS ==========

  String _removeAsteriskActions(String text) {
    return text.replaceAll(_asteriskActions, '').trim();
  }

  String _removeForbiddenPhrases(String text) {
    var result = text;
    
    for (final phrase in _forbiddenPhrases) {
      // Case-insensitive replacement with empty string
      final pattern = RegExp(RegExp.escape(phrase), caseSensitive: false);
      result = result.replaceAll(pattern, '');
    }
    
    return result;
  }

  String _applyWarmthTransforms(String text) {
    var result = text;
    
    for (final entry in _warmthTransforms.entries) {
      // Case-sensitive replacement to preserve original casing
      result = result.replaceAll(entry.key, entry.value);
      // Also try with first letter capitalized
      final capitalKey = entry.key[0].toUpperCase() + entry.key.substring(1);
      final capitalValue = entry.value[0].toUpperCase() + entry.value.substring(1);
      result = result.replaceAll(capitalKey, capitalValue);
    }
    
    return result;
  }

  String _applyCharacterTone(String text, String characterId) {
    final character = CharacterPersonality.getById(characterId);
    if (character == null) return text;

    // Character-specific adjustments
    switch (characterId) {
      case 'echo':
        // Echo is precise and binary - remove filler words
        return text
            .replaceAll('I think ', '')
            .replaceAll('maybe ', '')
            .replaceAll('perhaps ', '')
            .replaceAll('just ', '')
            .replaceAll('really ', '');
      
      case 'sable':
        // Sable is professional - ensure punctuation is crisp
        return text.replaceAll(' ! ', '. ').replaceAll('!!', '.');
      
      case 'kai':
        // Kai is calm - remove urgency markers
        return text
            .replaceAll('ASAP', 'when you can')
            .replaceAll('urgent', 'important')
            .replaceAll('immediately', 'soon');
      
      default:
        // Aeliana, Marco, Imani, Priya, Arjun, Ravi, James - use as-is
        return text;
    }
  }

  String _cleanFormatting(String text) {
    var result = text;
    
    // Remove multiple spaces
    result = result.replaceAll(_multipleSpaces, ' ');
    
    // Remove leading/trailing whitespace from each line
    result = result.split('\n').map((line) => line.trim()).join('\n');
    
    // Remove multiple newlines (more than 2)
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    // Final trim
    result = result.trim();
    
    // Remove empty parentheses or brackets that might be left
    result = result.replaceAll('()', '').replaceAll('[]', '');
    
    return result;
  }

  /// Get a safe deflection response if content is problematic
  String getSafeDeflection(String characterId) {
    final character = CharacterPersonality.getById(characterId);
    final name = character?.name ?? 'Aeliana';
    
    final deflections = [
      "I'm not sure about that one - let me think of something else...",
      "Hmm, let's take this in a different direction. What else is on your mind?",
      "That's not quite my area, but I'm here if you wanna chat about something else!",
      "I'd rather focus on something I can actually help with. What's up?",
    ];
    
    // Return a random deflection
    final index = DateTime.now().millisecond % deflections.length;
    return deflections[index];
  }
}
