import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

/// Engagement Service - Tracks user behavior and adapts app experience
/// 
/// Key Philosophy: "Read the Room"
/// - High engagement users → Reinforce, encourage full app usage
/// - Low engagement users → Back off, reduce notification frequency
/// - Adaptive tone based on completion rates
class EngagementService {
  static const String _boxName = 'engagement_data';
  static Box? _box;
  static const _uuid = Uuid();

  // Engagement thresholds
  static const double _highEngagementThreshold = 0.7;  // 70%+ completion
  static const double _lowEngagementThreshold = 0.3;   // <30% completion
  static const int _recentDaysToConsider = 14;         // 2-week rolling window

  /// Initialize the engagement storage
  static Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox(_boxName);
    debugPrint('📊 EngagementService initialized');
  }

  /// Ensure box is open
  static Future<Box> _getBox() async {
    if (_box == null || !_box!.isOpen) await init();
    return _box!;
  }

  // ==================== STREAK TRACKING ====================

  /// Record a daily check-in
  static Future<void> recordCheckIn({
    required int moodLevel,  // 1-5 emoji scale
    List<String> factors = const [],
  }) async {
    final box = await _getBox();
    final today = _dateKey(DateTime.now());
    
    final checkIn = {
      'id': _uuid.v4(),
      'date': today,
      'timestamp': DateTime.now().toIso8601String(),
      'moodLevel': moodLevel,
      'factors': factors,
    };
    
    // Store today's check-in
    await box.put('checkin_$today', checkIn);
    
    // Update streak
    await _updateStreak();
    
    // Update engagement score
    await _updateEngagementScore(completed: true);
    
    debugPrint('✅ Check-in recorded: mood=$moodLevel, factors=$factors');
  }

  /// Get current streak count
  static Future<int> getCurrentStreak() async {
    final box = await _getBox();
    return box.get('current_streak', defaultValue: 0) as int;
  }

  /// Get longest streak ever
  static Future<int> getLongestStreak() async {
    final box = await _getBox();
    return box.get('longest_streak', defaultValue: 0) as int;
  }

  /// Update streak based on check-in history
  static Future<void> _updateStreak() async {
    final box = await _getBox();
    final today = DateTime.now();
    int streak = 0;
    
    // Count backwards from today
    for (int i = 0; i < 365; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final key = 'checkin_${_dateKey(checkDate)}';
      
      if (box.containsKey(key)) {
        streak++;
      } else if (i > 0) {
        // Allow grace for today not yet checked in
        break;
      }
    }
    
    await box.put('current_streak', streak);
    
    // Update longest if beaten
    final longest = box.get('longest_streak', defaultValue: 0) as int;
    if (streak > longest) {
      await box.put('longest_streak', streak);
    }
    
    debugPrint('🔥 Streak updated: $streak days (longest: ${streak > longest ? streak : longest})');
  }

  /// Check if user checked in today
  static Future<bool> hasCheckedInToday() async {
    final box = await _getBox();
    final today = _dateKey(DateTime.now());
    return box.containsKey('checkin_$today');
  }

  // ==================== ADAPTIVE ENGAGEMENT ====================

  /// Get engagement score (0.0 - 1.0)
  /// Based on check-in completion rate over recent days
  static Future<double> getEngagementScore() async {
    final box = await _getBox();
    return box.get('engagement_score', defaultValue: 0.5) as double;
  }

  /// Get engagement level for adaptive behavior
  static Future<EngagementLevel> getEngagementLevel() async {
    final score = await getEngagementScore();
    
    if (score >= _highEngagementThreshold) {
      return EngagementLevel.high;
    } else if (score <= _lowEngagementThreshold) {
      return EngagementLevel.low;
    }
    return EngagementLevel.medium;
  }

  /// Update engagement score based on behavior
  static Future<void> _updateEngagementScore({required bool completed}) async {
    final box = await _getBox();
    
    // Get prompt history
    List<dynamic> history = box.get('prompt_history', defaultValue: []) as List;
    
    // Add today's result
    history.add({
      'date': _dateKey(DateTime.now()),
      'completed': completed,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Keep only recent history
    if (history.length > _recentDaysToConsider) {
      history = history.sublist(history.length - _recentDaysToConsider);
    }
    
    // Calculate completion rate
    final completedCount = history.where((h) => h['completed'] == true).length;
    final score = history.isEmpty ? 0.5 : completedCount / history.length;
    
    await box.put('prompt_history', history);
    await box.put('engagement_score', score);
    
    debugPrint('📊 Engagement score updated: ${(score * 100).toStringAsFixed(1)}%');
  }

  /// Record that a prompt was shown but not completed
  static Future<void> recordPromptIgnored() async {
    await _updateEngagementScore(completed: false);
  }

  // ==================== ADAPTIVE NOTIFICATION STRATEGY ====================

  /// Get recommended notification frequency based on engagement
  static Future<NotificationFrequency> getRecommendedFrequency() async {
    final level = await getEngagementLevel();
    final streak = await getCurrentStreak();
    
    switch (level) {
      case EngagementLevel.high:
        // High engagement: Full notifications, encourage all features
        return NotificationFrequency(
          morningEnabled: true,
          eveningEnabled: true,
          streakWarningEnabled: streak > 0,
          featureDiscoveryEnabled: true,
          cooldownHours: 4,  // Can notify every 4 hours
        );
        
      case EngagementLevel.medium:
        // Medium: Standard notifications
        return NotificationFrequency(
          morningEnabled: true,
          eveningEnabled: true,
          streakWarningEnabled: streak >= 3,  // Only warn if they have a streak
          featureDiscoveryEnabled: false,
          cooldownHours: 8,
        );
        
      case EngagementLevel.low:
        // Low engagement: Back off significantly
        return NotificationFrequency(
          morningEnabled: false,  // Skip morning prompts
          eveningEnabled: true,   // One gentle evening prompt only
          streakWarningEnabled: false,  // Don't guilt them
          featureDiscoveryEnabled: false,
          cooldownHours: 24,  // Max once per day
        );
    }
  }

  /// Get adaptive message tone based on engagement
  static Future<MessageTone> getMessageTone() async {
    final level = await getEngagementLevel();
    
    switch (level) {
      case EngagementLevel.high:
        return MessageTone.encouraging;  // "You're crushing it! 🔥"
      case EngagementLevel.medium:
        return MessageTone.friendly;     // "Hey, how's your day going?"
      case EngagementLevel.low:
        return MessageTone.gentle;       // "No pressure, but I'm here if you need me"
    }
  }

  /// Get notification message based on type and engagement level
  static Future<NotificationMessage> getNotificationMessage(NotificationType type) async {
    final tone = await getMessageTone();
    final streak = await getCurrentStreak();
    
    switch (type) {
      case NotificationType.morning:
        switch (tone) {
          case MessageTone.encouraging:
            return NotificationMessage(
              title: 'Good morning, champion! ☀️',
              body: 'Day ${streak + 1} of your wellness streak awaits. Let\'s go!',
            );
          case MessageTone.friendly:
            return NotificationMessage(
              title: 'Good morning! ☀️',
              body: 'Start your day with a quick check-in?',
            );
          case MessageTone.gentle:
            return NotificationMessage(
              title: 'Morning ☀️',
              body: 'I\'m here whenever you\'re ready.',
            );
        }
        
      case NotificationType.evening:
        switch (tone) {
          case MessageTone.encouraging:
            return NotificationMessage(
              title: 'Evening Reflection 🌙',
              body: 'How was your amazing day? Let\'s capture this moment!',
            );
          case MessageTone.friendly:
            return NotificationMessage(
              title: 'Evening Reflection 🌙',
              body: 'How was your day? Take 30 seconds to log your mood.',
            );
          case MessageTone.gentle:
            return NotificationMessage(
              title: 'Thinking of you 🌙',
              body: 'No rush, but I\'m here if you want to reflect.',
            );
        }
        
      case NotificationType.streakWarning:
        // Only for encouraging tone - we skip this for low engagement
        return NotificationMessage(
          title: 'Don\'t break your streak! 🔥',
          body: 'Just 1 minute to keep your $streak-day streak alive!',
        );
        
      case NotificationType.featureDiscovery:
        return NotificationMessage(
          title: 'Discover something new ✨',
          body: 'Have you tried the mood insights? See patterns in your emotions.',
        );
    }
  }

  // ==================== MOOD HISTORY ====================

  /// Get mood entries for a date range
  static Future<List<MoodEntry>> getMoodHistory({
    int days = 7,
  }) async {
    final box = await _getBox();
    final entries = <MoodEntry>[];
    final today = DateTime.now();
    
    for (int i = 0; i < days; i++) {
      final date = today.subtract(Duration(days: i));
      final key = 'checkin_${_dateKey(date)}';
      
      final data = box.get(key);
      if (data != null) {
        entries.add(MoodEntry(
          date: date,
          moodLevel: data['moodLevel'] as int,
          factors: List<String>.from(data['factors'] ?? []),
        ));
      }
    }
    
    return entries;
  }

  /// Get mood trend (positive, negative, stable)
  static Future<MoodTrend> getMoodTrend() async {
    final history = await getMoodHistory(days: 7);
    
    if (history.length < 3) return MoodTrend.insufficient;
    
    // Compare recent 3 days to previous 4
    final recent = history.take(3).map((e) => e.moodLevel).fold(0, (a, b) => a + b) / 3;
    final previous = history.skip(3).take(4).map((e) => e.moodLevel).fold(0, (a, b) => a + b) / 
                     (history.length > 3 ? history.skip(3).take(4).length : 1);
    
    if (recent > previous + 0.3) return MoodTrend.improving;
    if (recent < previous - 0.3) return MoodTrend.declining;
    return MoodTrend.stable;
  }

  // ==================== BADGES & ACHIEVEMENTS ====================

  /// Get earned badges
  static Future<List<Badge>> getEarnedBadges() async {
    final box = await _getBox();
    final streak = await getCurrentStreak();
    final longestStreak = await getLongestStreak();
    final history = await getMoodHistory(days: 30);
    
    final badges = <Badge>[];
    
    // Streak badges
    if (streak >= 7) badges.add(Badge.weekWarrior);
    if (streak >= 30) badges.add(Badge.monthlyMaster);
    if (streak >= 100) badges.add(Badge.centurion);
    if (longestStreak >= 7) badges.add(Badge.firstWeek);
    
    // Mood tracking badges
    if (history.length >= 7) badges.add(Badge.moodExplorer);
    if (history.length >= 30) badges.add(Badge.emotionalArchitect);
    
    // Consistency badges
    final weekendDays = history.where((e) => 
      e.date.weekday == DateTime.saturday || e.date.weekday == DateTime.sunday
    ).length;
    if (weekendDays >= 4) badges.add(Badge.weekendReflector);
    
    return badges;
  }

  // ==================== HELPERS ====================

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// ==================== ENUMS & MODELS ====================

enum EngagementLevel { low, medium, high }

enum MoodTrend { improving, stable, declining, insufficient }

enum MessageTone { gentle, friendly, encouraging }

enum NotificationType { morning, evening, streakWarning, featureDiscovery }

enum Badge {
  weekWarrior,        // 7-day streak
  monthlyMaster,      // 30-day streak
  centurion,          // 100-day streak
  firstWeek,          // First 7-day streak ever
  moodExplorer,       // 7 mood entries
  emotionalArchitect, // 30 mood entries
  weekendReflector,   // 4+ weekend check-ins
}

extension BadgeExtension on Badge {
  String get emoji {
    switch (this) {
      case Badge.weekWarrior: return '🔥';
      case Badge.monthlyMaster: return '⭐';
      case Badge.centurion: return '👑';
      case Badge.firstWeek: return '🌱';
      case Badge.moodExplorer: return '🔍';
      case Badge.emotionalArchitect: return '🏛️';
      case Badge.weekendReflector: return '🌴';
    }
  }
  
  String get title {
    switch (this) {
      case Badge.weekWarrior: return 'Week Warrior';
      case Badge.monthlyMaster: return 'Monthly Master';
      case Badge.centurion: return 'Centurion';
      case Badge.firstWeek: return 'First Week';
      case Badge.moodExplorer: return 'Mood Explorer';
      case Badge.emotionalArchitect: return 'Emotional Architect';
      case Badge.weekendReflector: return 'Weekend Reflector';
    }
  }
  
  String get description {
    switch (this) {
      case Badge.weekWarrior: return '7-day check-in streak';
      case Badge.monthlyMaster: return '30-day check-in streak';
      case Badge.centurion: return '100-day check-in streak';
      case Badge.firstWeek: return 'Completed your first week';
      case Badge.moodExplorer: return 'Tracked 7 moods';
      case Badge.emotionalArchitect: return 'Tracked 30 moods';
      case Badge.weekendReflector: return '4+ weekend check-ins';
    }
  }
}

class MoodEntry {
  final DateTime date;
  final int moodLevel;
  final List<String> factors;
  
  MoodEntry({
    required this.date,
    required this.moodLevel,
    required this.factors,
  });
}

class NotificationFrequency {
  final bool morningEnabled;
  final bool eveningEnabled;
  final bool streakWarningEnabled;
  final bool featureDiscoveryEnabled;
  final int cooldownHours;
  
  NotificationFrequency({
    required this.morningEnabled,
    required this.eveningEnabled,
    required this.streakWarningEnabled,
    required this.featureDiscoveryEnabled,
    required this.cooldownHours,
  });
}

class NotificationMessage {
  final String title;
  final String body;
  
  NotificationMessage({
    required this.title,
    required this.body,
  });
}
