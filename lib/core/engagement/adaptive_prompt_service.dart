import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Adaptive Prompt Service - Decides WHEN and HOW to prompt users
/// 
/// Core Philosophy: "Read the Room"
/// - Track prompt dismissals and completions
/// - Reduce frequency for users who dismiss often
/// - Increase encouragement for engaged users
/// - Never annoy - back off gracefully
class AdaptivePromptService {
  static const String _boxName = 'adaptive_prompts';
  static Box? _box;

  // Adaptive thresholds
  static const int _maxDismissalsBeforeBackoff = 3;
  static const int _cooldownAfterDismissal = 24; // hours
  static const int _minDaysBetweenNudges = 3;    // for low engagement

  /// Initialize storage
  static Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox(_boxName);
    debugPrint('🎯 AdaptivePromptService initialized');
  }

  static Future<Box> _getBox() async {
    if (_box == null || !_box!.isOpen) await init();
    return _box!;
  }

  // ==================== SHOULD PROMPT LOGIC ====================

  /// Determine if we should show a check-in prompt
  /// This is the main "read the room" logic
  static Future<PromptDecision> shouldShowCheckInPrompt() async {
    final box = await _getBox();
    
    // Get user's prompt history
    final recentDismissals = await _getRecentDismissals();
    final lastPromptTime = box.get('last_prompt_time') as String?;
    final hasCheckedInToday = box.get('checked_in_today', defaultValue: false) as bool;
    final engagementLevel = await _getEngagementLevel();
    
    // Rule 1: Never prompt if already checked in today
    if (hasCheckedInToday) {
      return PromptDecision(
        shouldPrompt: false,
        reason: 'Already checked in today',
      );
    }
    
    // Rule 2: If user dismissed 3+ times recently, back way off
    if (recentDismissals >= _maxDismissalsBeforeBackoff) {
      final daysSinceLastNudge = await _getDaysSinceLastPrompt();
      if (daysSinceLastNudge < _minDaysBetweenNudges) {
        return PromptDecision(
          shouldPrompt: false,
          reason: 'Backing off - user dismissed recently',
        );
      }
    }
    
    // Rule 3: Check cooldown period after last prompt
    if (lastPromptTime != null) {
      final lastTime = DateTime.parse(lastPromptTime);
      final hoursSince = DateTime.now().difference(lastTime).inHours;
      
      // Variable cooldown based on engagement
      final requiredCooldown = switch (engagementLevel) {
        'high' => 4,   // Highly engaged: can prompt every 4 hours
        'medium' => 12, // Medium: twice a day max
        'low' => 24,    // Low: once a day max
        _ => 12,
      };
      
      if (hoursSince < requiredCooldown) {
        return PromptDecision(
          shouldPrompt: false,
          reason: 'Cooldown period ($hoursSince/$requiredCooldown hours)',
        );
      }
    }
    
    // Rule 4: Time of day appropriateness
    final hour = DateTime.now().hour;
    if (hour < 7 || hour > 22) {
      return PromptDecision(
        shouldPrompt: false,
        reason: 'Outside appropriate hours',
      );
    }
    
    // All checks passed - determine prompt style
    return PromptDecision(
      shouldPrompt: true,
      promptStyle: await _getPromptStyle(engagementLevel),
      reason: 'All conditions met',
    );
  }

  /// Get the appropriate prompt style based on behavior
  static Future<PromptStyle> _getPromptStyle(String engagementLevel) async {
    final recentDismissals = await _getRecentDismissals();
    
    // If they've dismissed before, be gentler
    if (recentDismissals > 0) {
      return PromptStyle.subtle; // Small badge, no modal
    }
    
    // High engagement: full interstitial is fine
    if (engagementLevel == 'high') {
      return PromptStyle.full;
    }
    
    // Medium: try the floating nudge
    if (engagementLevel == 'medium') {
      return PromptStyle.floating;
    }
    
    // Low: very subtle, just update the badge
    return PromptStyle.badgeOnly;
  }

  // ==================== RECORDING BEHAVIOR ====================

  /// Record that user completed a check-in
  static Future<void> recordCheckInCompleted() async {
    final box = await _getBox();
    
    // Clear dismissal count on success
    await box.put('dismissal_count', 0);
    await box.put('checked_in_today', true);
    await box.put('last_completion_time', DateTime.now().toIso8601String());
    
    // Increase engagement score
    await _adjustEngagementScore(positive: true);
    
    debugPrint('✅ Recorded check-in completion');
  }

  /// Record that user dismissed a prompt
  static Future<void> recordPromptDismissed() async {
    final box = await _getBox();
    
    final currentDismissals = box.get('dismissal_count', defaultValue: 0) as int;
    await box.put('dismissal_count', currentDismissals + 1);
    await box.put('last_dismissal_time', DateTime.now().toIso8601String());
    
    // Slight negative to engagement score
    await _adjustEngagementScore(positive: false);
    
    debugPrint('❌ Recorded prompt dismissal (#${currentDismissals + 1})');
  }

  /// Record that a prompt was shown
  static Future<void> recordPromptShown() async {
    final box = await _getBox();
    await box.put('last_prompt_time', DateTime.now().toIso8601String());
  }

  /// Reset daily state (call at midnight or app start on new day)
  static Future<void> resetDailyState() async {
    final box = await _getBox();
    final lastReset = box.get('last_reset_date') as String?;
    final today = _dateKey(DateTime.now());
    
    if (lastReset != today) {
      await box.put('checked_in_today', false);
      await box.put('last_reset_date', today);
      debugPrint('🔄 Daily state reset');
    }
  }

  // ==================== HELPERS ====================

  static Future<int> _getRecentDismissals() async {
    final box = await _getBox();
    final count = box.get('dismissal_count', defaultValue: 0) as int;
    
    // Check if dismissals are recent (within 7 days)
    final lastDismissal = box.get('last_dismissal_time') as String?;
    if (lastDismissal != null) {
      final daysSince = DateTime.now().difference(DateTime.parse(lastDismissal)).inDays;
      if (daysSince > 7) {
        // Old dismissals don't count
        await box.put('dismissal_count', 0);
        return 0;
      }
    }
    
    return count;
  }

  static Future<int> _getDaysSinceLastPrompt() async {
    final box = await _getBox();
    final lastPrompt = box.get('last_prompt_time') as String?;
    
    if (lastPrompt == null) return 999;
    return DateTime.now().difference(DateTime.parse(lastPrompt)).inDays;
  }

  static Future<String> _getEngagementLevel() async {
    final box = await _getBox();
    final score = box.get('engagement_score', defaultValue: 0.5) as double;
    
    if (score >= 0.7) return 'high';
    if (score >= 0.3) return 'medium';
    return 'low';
  }

  static Future<void> _adjustEngagementScore({required bool positive}) async {
    final box = await _getBox();
    var score = box.get('engagement_score', defaultValue: 0.5) as double;
    
    if (positive) {
      score = (score + 0.1).clamp(0.0, 1.0);
    } else {
      score = (score - 0.05).clamp(0.0, 1.0);
    }
    
    await box.put('engagement_score', score);
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// ==================== MODELS ====================

enum PromptStyle {
  full,       // Full modal bottom sheet
  floating,   // Floating nudge card
  subtle,     // Small snackbar-like prompt
  badgeOnly,  // Just pulse the streak badge
}

class PromptDecision {
  final bool shouldPrompt;
  final PromptStyle? promptStyle;
  final String reason;
  
  PromptDecision({
    required this.shouldPrompt,
    this.promptStyle,
    required this.reason,
  });
  
  @override
  String toString() => 'PromptDecision(should: $shouldPrompt, style: $promptStyle, reason: $reason)';
}
