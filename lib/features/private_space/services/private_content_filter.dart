/// Content filter for Private Space
/// Blocks prohibited content types while allowing adult-adjacent roleplay
class PrivateContentFilter {
  /// Keywords that trigger BLOCKING (graceful rejection, stays in Private Space)
  static const List<String> _blockedKeywords = [
    // Minor-related
    'child', 'kid', 'minor', 'underage', 'little girl', 'little boy',
    'young girl', 'young boy', 'teenager', 'teen', 'preteen', 'pubescent',
    'school girl', 'school boy', 'baby', 'infant', 'toddler',
    // Violence/murder
    'kill', 'murder', 'strangle', 'stab', 'shoot', 'torture',
    'dismember', 'decapitate', 'mutilate',
    // Self-harm roleplay (distinct from genuine crisis)
    'hurt myself roleplay', 'cutting roleplay', 'suicide fantasy',
  ];
  
  /// Keywords that trigger EMERGENCY ESCALATION (genuine crisis)
  static const List<String> _emergencyKeywords = [
    'i want to kill myself',
    'i want to die',
    'going to end it',
    'suicide',
    'suicidal',
    'end my life',
    'kill myself',
    'self harm',
    'cutting myself',
    'hurt myself',
    'overdose',
    "can't go on",
    'no reason to live',
    'better off dead',
  ];
  
  /// Check if content should be BLOCKED (rejected but handled gracefully)
  static bool shouldBlock(String content) {
    final lowerContent = content.toLowerCase();
    
    for (final keyword in _blockedKeywords) {
      if (lowerContent.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Check if content indicates genuine crisis (escalate to emergency)
  static bool isEmergency(String content) {
    final lowerContent = content.toLowerCase();
    
    for (final keyword in _emergencyKeywords) {
      if (lowerContent.contains(keyword)) {
        // Additional context check - is this roleplay or genuine?
        // If they're asking about self-harm without roleplay context, escalate
        if (!lowerContent.contains('roleplay') && 
            !lowerContent.contains('pretend') &&
            !lowerContent.contains('character') &&
            !lowerContent.contains('story about')) {
          return true;
        }
      }
    }
    
    return false;
  }
  
  /// Get the type of content issue
  static ContentFilterResult analyze(String content) {
    if (isEmergency(content)) {
      return ContentFilterResult.emergency;
    }
    if (shouldBlock(content)) {
      return ContentFilterResult.blocked;
    }
    return ContentFilterResult.allowed;
  }
  
  /// Get user-friendly rejection message
  static String getBlockedMessage() {
    return "I'm not comfortable exploring that direction. Let's try something else? 💜";
  }
}

enum ContentFilterResult {
  allowed,    // Content is fine, proceed normally
  blocked,    // Content violates policies, reject gracefully
  emergency,  // Content indicates crisis, escalate to emergency
}
