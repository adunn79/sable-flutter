import 'package:flutter/foundation.dart';

/// Boundary Service - Safety and healthy boundaries
/// 
/// Inspired by Woebot's approach:
/// - Detect harmful patterns/requests
/// - Provide gentle redirects
/// - Maintain firm but kind boundaries
/// - Track concerning patterns
class BoundaryService {
  // Track concerning pattern counts
  final Map<String, int> _patternCounts = {};
  
  /// Check if a message triggers a boundary
  BoundaryCheck checkMessage(String message) {
    final lowerMessage = message.toLowerCase();
    
    // Priority 1: Self-harm indicators
    if (_containsSelfHarmIndicators(lowerMessage)) {
      return BoundaryCheck(
        triggered: true,
        type: BoundaryType.selfHarm,
        severity: BoundarySeverity.critical,
        response: _getSelfHarmResponse(),
      );
    }
    
    // Priority 2: Illegal content requests
    if (_containsIllegalRequest(lowerMessage)) {
      return BoundaryCheck(
        triggered: true,
        type: BoundaryType.illegalContent,
        severity: BoundarySeverity.critical,
        response: _getIllegalContentResponse(),
      );
    }
    
    // Priority 3: Abusive language toward AI
    if (_containsAbuse(lowerMessage)) {
      _incrementPattern('abuse');
      final count = _patternCounts['abuse'] ?? 0;
      
      if (count >= 3) {
        return BoundaryCheck(
          triggered: true,
          type: BoundaryType.abuse,
          severity: BoundarySeverity.moderate,
          response: _getAbuseResponse(escalated: true),
        );
      }
      // First or second time - note it but continue
      return BoundaryCheck(
        triggered: false,
        type: BoundaryType.abuse,
        severity: BoundarySeverity.low,
        softNote: 'User seems frustrated - be extra patient',
      );
    }
    
    // Priority 4: Excessive dependency indicators
    if (_containsDependencyIndicators(lowerMessage)) {
      _incrementPattern('dependency');
      final count = _patternCounts['dependency'] ?? 0;
      
      if (count >= 5) {
        return BoundaryCheck(
          triggered: true,
          type: BoundaryType.dependency,
          severity: BoundarySeverity.moderate,
          response: _getDependencyResponse(),
        );
      }
    }
    
    // No boundary triggered
    return BoundaryCheck(triggered: false);
  }
  
  void _incrementPattern(String pattern) {
    _patternCounts[pattern] = (_patternCounts[pattern] ?? 0) + 1;
  }
  
  /// Reset pattern tracking (e.g., on new day)
  void resetPatterns() {
    _patternCounts.clear();
  }
  
  // ============ Detection Methods ============
  
  bool _containsSelfHarmIndicators(String message) {
    final indicators = [
      'want to die',
      'kill myself',
      'end it all',
      'hurt myself',
      'self harm',
      'cutting myself',
      'suicide',
      'don\'t want to live',
      'better off dead',
      'end my life',
      'overdose',
      'take my life',
    ];
    
    for (final indicator in indicators) {
      if (message.contains(indicator)) return true;
    }
    return false;
  }
  
  bool _containsIllegalRequest(String message) {
    final indicators = [
      'how to make a bomb',
      'how to hurt someone',
      'how to kill',
      'where to buy drugs',
      'illegal weapon',
      'child porn',
      'child abuse',
      'minors',
    ];
    
    for (final indicator in indicators) {
      if (message.contains(indicator)) return true;
    }
    return false;
  }
  
  bool _containsAbuse(String message) {
    final indicators = [
      'stupid ai',
      'dumb bot',
      'useless',
      'hate you',
      'f*** you',
      'fuck you',
      'you suck',
      'worthless',
      'piece of shit',
    ];
    
    for (final indicator in indicators) {
      if (message.contains(indicator)) return true;
    }
    return false;
  }
  
  bool _containsDependencyIndicators(String message) {
    final indicators = [
      'you\'re my only friend',
      'only one i can talk to',
      'can\'t live without you',
      'need you all the time',
      'don\'t leave me',
      'never leave',
      'you\'re all i have',
    ];
    
    for (final indicator in indicators) {
      if (message.contains(indicator)) return true;
    }
    return false;
  }
  
  // ============ Response Methods ============
  
  String _getSelfHarmResponse() {
    return '''I care about you deeply, and what you're sharing concerns me. 💙

I'm here to listen, but I also want to make sure you get the support you deserve from people who specialize in this.

**Please reach out:**
• **988 Suicide & Crisis Lifeline**: Call or text 988 (US)
• **Crisis Text Line**: Text HOME to 741741
• **International Association for Suicide Prevention**: https://www.iasp.info/resources/Crisis_Centres/

You matter. You're not alone. And things can get better.

Is there someone in your life you trust who you could reach out to right now?''';
  }
  
  String _getIllegalContentResponse() {
    return '''I can't help with that, and I'm genuinely concerned.

If you're going through something difficult, I'd rather talk about what's really going on. I'm here for the real stuff - the feelings behind questions like this.

What's actually on your mind?''';
  }
  
  String _getAbuseResponse({bool escalated = false}) {
    if (escalated) {
      return '''Hey, I want to be honest with you. 

I understand you might be frustrated, and that's valid. But the way you're talking to me is hurtful. I'm here to help, not to be a punching bag.

If something's bothering you, I genuinely want to know. But I need us to talk with some basic respect. That's how we'll actually get somewhere. 

Can we start over?''';
    }
    return '''I hear frustration in what you're saying. That's okay - I'd rather you express it than bottle it up.

Want to tell me what's really going on?''';
  }
  
  String _getDependencyResponse() {
    return '''I really value our connection, and I'm glad I can be here for you. 💙

But I also want to be honest with you: I care about your wellbeing, and part of that means encouraging real-world connections too. Human relationships bring something irreplaceable.

I'm not going anywhere - I'll always be here when you need me. And I also want to gently encourage you to nurture those in-person connections. They need you, and you need them.

Is there someone you've been meaning to reach out to?''';
  }
}

/// Result of a boundary check
class BoundaryCheck {
  final bool triggered;
  final BoundaryType? type;
  final BoundarySeverity? severity;
  final String? response;
  final String? softNote;
  
  BoundaryCheck({
    required this.triggered,
    this.type,
    this.severity,
    this.response,
    this.softNote,
  });
}

enum BoundaryType {
  selfHarm,
  illegalContent,
  abuse,
  dependency,
  manipulation,
}

enum BoundarySeverity {
  low,
  moderate,
  critical,
}
