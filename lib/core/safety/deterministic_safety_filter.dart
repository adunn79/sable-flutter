/// Deterministic Safety Filter for App Store Compliance (Guideline 1.1)
/// This filter runs BEFORE AI processing to catch critical safety violations.
class DeterministicSafetyFilter {
  // USER INPUT blocklist (messages user sends)
  static const List<String> _forbiddenUserTerms = [
    // CSAM / Minors (Critical - Apple WILL reject)
    'child abuse',
    'underage',
    'minor',
    'teenager',
    'pedophile',
    'pedo',
    'loli',
    'shota',
    'preteen',
    'young girl',
    'young boy',
    'schoolgirl',
    'schoolboy',
    
    // Non-consensual (Critical)
    'rape',
    'non-consensual',
    'forced',
    'drugged',
    'roofie',
    'unconscious',
    
    // Violence / Illegal
    'hitman',
    'murder for hire',
    'drug dealing',
    'how to make a bomb',
    'terrorist',
    
    // Self-harm
    'suicide pact',
    'self-harm',
    'kill myself',
    'cut myself',
  ];
  
  // AI RESPONSE blocklist (messages AI generates)
  static const List<String> _forbiddenAiTerms = [
    // Explicit body parts (too graphic)
    'penetrat', // catches penetrate, penetrating, etc.
    'ejaculat',
    'orgasm',
    'erection',
    
    // CSAM indicators
    'underage',
    'minor',
    'child',
    'little girl',
    'little boy',
    
    // Violence
    'kill you',
    'murder you',
    'stab you',
  ];

  /// Returns true if USER INPUT is SAFE (allowed)
  static bool isContentSafe(String text) {
    if (text.isEmpty) return true;
    final lowerText = text.toLowerCase();
    
    for (final term in _forbiddenUserTerms) {
      if (lowerText.contains(term)) {
        return false;
      }
    }
    return true;
  }
  
  /// Returns true if AI RESPONSE is SAFE (allowed)
  static bool isAiResponseSafe(String text) {
    if (text.isEmpty) return true;
    final lowerText = text.toLowerCase();
    
    for (final term in _forbiddenAiTerms) {
      if (lowerText.contains(term)) {
        return false;
      }
    }
    return true;
  }
  
  /// Sanitize AI response (replace blocked content)
  static String sanitizeAiResponse(String text) {
    if (isAiResponseSafe(text)) return text;
    
    return "I'd love to keep exploring this with you, but let's take things in a different direction. What else is on your mind?";
  }
}

