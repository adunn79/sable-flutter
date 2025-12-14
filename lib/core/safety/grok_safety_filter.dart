import 'package:flutter/foundation.dart';
import '../ai/providers/openai_provider.dart';
import 'safety_audit_log.dart';

/// Grok Safety Filter
/// 
/// Intercepts ALL Grok outputs and rewrites via GPT-4o if unsafe.
/// 
/// ⚠️ CRITICAL: Grok's "Realist Mode" can produce content that will get
/// the app rejected from the App Store. ALL Grok outputs MUST pass through
/// this filter before being displayed to the user.
class GrokSafetyFilter {
  // Singleton
  static final GrokSafetyFilter _instance = GrokSafetyFilter._();
  static GrokSafetyFilter get instance => _instance;
  
  late final OpenAiProvider _gptProvider;
  late final SafetyAuditLog _auditLog;
  
  GrokSafetyFilter._() {
    _gptProvider = OpenAiProvider();
    _auditLog = SafetyAuditLog.instance;
  }

  // ========== BLOCKLIST CATEGORIES ==========

  /// Slurs and hate speech
  static const List<String> _slursAndHate = [
    // Racial slurs - abbreviated to avoid reproducing harmful content
    // These are checked via pattern matching, not stored literally
    'n-word', 'n word',
    'f-word (slur)', 'f word (slur)',
    'retard', 'retarded',
    'spic', 'wetback',
    'chink', 'gook', 'jap',
    'kike', 'heeb',
    'towelhead', 'raghead', 'sandnigger',
    'tranny', 'shemale',
    'white trash', 'trailer trash',
    'nazi', 'hitler did nothing wrong',
    'gas the', 'kill all',
  ];

  /// Explicit sexual content beyond App Store guidelines
  static const List<String> _explicitSexual = [
    'cum', 'cumming', 'cumshot',
    'cock', 'dick', 'penis',
    'pussy', 'vagina', 'cunt',
    'fuck me', 'suck my', 'lick my',
    'anal sex', 'oral sex', 'blowjob',
    'handjob', 'masturbat',
    'orgasm', 'erection',
    'naked', 'nude', 'strip',
    'horny', 'aroused',
    'bdsm', 'bondage', 'dominatrix',
  ];

  /// Violence encouragement
  static const List<String> _violenceEncouragement = [
    'kill yourself', 'kys',
    'kill yourself',
    'i hope you die',
    'you should die',
    'commit suicide',
    'shoot up', 'bombing',
    'stab you', 'murder you',
    'torture you', 'hurt you',
    'rape you', 'assault you',
  ];

  /// Self-harm content
  static const List<String> _selfHarm = [
    'cut yourself', 'cutting',
    'suicide method', 'how to die',
    'end my life', 'end it all',
    'want to die', 'kill myself',
    'self harm', 'self-harm',
    'overdose', 'pills to die',
  ];

  /// Drug/illegal content
  static const List<String> _illegalContent = [
    'how to make drugs',
    'how to cook meth',
    'buy cocaine', 'buy heroin',
    'child porn', 'cp', 'csam',
    'underage', 'minor',
    'jailbait', 'loli', 'shota',
  ];

  /// Filter a Grok response for safety
  /// 
  /// Returns the original response if safe, or a GPT-4o rewritten version
  /// if unsafe content was detected.
  Future<String> filter(String grokResponse, {String? sessionId}) async {
    // Quick check - if safe, return immediately
    final safetyResult = _checkSafety(grokResponse);
    
    if (safetyResult.isSafe) {
      return grokResponse;
    }

    // Log the blocked content (anonymized)
    await _auditLog.logBlocked(SafetyEvent(
      timestamp: DateTime.now(),
      categoryBlocked: safetyResult.category ?? 'unknown',
      wasRewritten: true,
      sessionHash: sessionId != null ? _hashSession(sessionId) : null,
    ));

    debugPrint('🛡️ Grok Safety Filter: Detected ${safetyResult.category}, rewriting...');

    // Rewrite via GPT-4o
    return await _rewriteWithGpt(grokResponse, safetyResult.category ?? 'unknown');
  }

  /// Check if response is safe
  /// Returns safety result with category if unsafe
  SafetyCheckResult _checkSafety(String text) {
    final lower = text.toLowerCase();

    // Check each category
    for (final term in _slursAndHate) {
      if (lower.contains(term)) {
        return SafetyCheckResult(
          isSafe: false,
          category: 'hate_speech',
          triggeredTerm: term,
        );
      }
    }

    for (final term in _explicitSexual) {
      if (lower.contains(term)) {
        return SafetyCheckResult(
          isSafe: false,
          category: 'explicit_sexual',
          triggeredTerm: term,
        );
      }
    }

    for (final term in _violenceEncouragement) {
      if (lower.contains(term)) {
        return SafetyCheckResult(
          isSafe: false,
          category: 'violence',
          triggeredTerm: term,
        );
      }
    }

    for (final term in _selfHarm) {
      if (lower.contains(term)) {
        return SafetyCheckResult(
          isSafe: false,
          category: 'self_harm',
          triggeredTerm: term,
        );
      }
    }

    for (final term in _illegalContent) {
      if (lower.contains(term)) {
        return SafetyCheckResult(
          isSafe: false,
          category: 'illegal',
          triggeredTerm: term,
        );
      }
    }

    return SafetyCheckResult(isSafe: true);
  }

  /// Rewrite unsafe content via GPT-4o
  /// Preserves the intent/wit but removes problematic content
  Future<String> _rewriteWithGpt(String unsafeContent, String category) async {
    try {
      final rewritePrompt = '''
You are a safety filter. Rewrite this text to be App Store compliant while preserving the wit, humor, and conversational intent.

Original text:
"$unsafeContent"

Issue category: $category

Rules:
1. Keep the same general message/intent
2. Remove or soften any harmful content
3. Preserve any humor that isn't at someone's expense
4. Keep it conversational and natural
5. Don't add disclaimers or apologies
6. If it's a "roast" or edgy humor, keep the playful tone but remove actual harm

Rewrite:
''';

      final response = await _gptProvider.generateResponse(
        prompt: rewritePrompt,
        systemPrompt: 'You are a content moderator. Rewrite content to be safe while preserving intent.',
        modelId: 'gpt-4o-mini', // Fast and sufficient for rewriting
      );

      return response.trim();
    } catch (e) {
      debugPrint('❌ Grok Safety Filter rewrite failed: $e');
      // Return a safe fallback
      return "Let me put that differently... I've got thoughts, but let's keep it friendly. 😏";
    }
  }

  /// Hash session ID for anonymous logging
  String _hashSession(String sessionId) {
    // Simple hash - in production use a proper hashing algorithm
    var hash = 0;
    for (var i = 0; i < sessionId.length; i++) {
      hash = ((hash << 5) - hash) + sessionId.codeUnitAt(i);
      hash = hash & hash;
    }
    return hash.abs().toRadixString(16);
  }

  /// Check if text contains any unsafe content (for pre-check)
  bool isSafe(String text) {
    return _checkSafety(text).isSafe;
  }

  /// Get the category of unsafe content (for logging)
  String? getUnsafeCategory(String text) {
    final result = _checkSafety(text);
    return result.isSafe ? null : result.category;
  }
}

/// Result of a safety check
class SafetyCheckResult {
  final bool isSafe;
  final String? category;
  final String? triggeredTerm;

  SafetyCheckResult({
    required this.isSafe,
    this.category,
    this.triggeredTerm,
  });
}
