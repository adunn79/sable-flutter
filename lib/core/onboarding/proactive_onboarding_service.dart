import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Proactive Onboarding Service
/// 
/// Tracks user's journey through the first 7 days to:
/// - Build bond through progressive questions
/// - Introduce features at the right moments
/// - Track what the AI has learned about the user

class ProactiveOnboardingService {
  static ProactiveOnboardingService? _instance;
  final SharedPreferences _prefs;

  ProactiveOnboardingService._(this._prefs);

  static Future<ProactiveOnboardingService> create() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = ProactiveOnboardingService._(prefs);
    }
    return _instance!;
  }

  // ==================== FIRST INTERACTION ====================

  /// Get when user first opened the app
  DateTime? get firstInteractionDate {
    final timestamp = _prefs.getInt('first_interaction_timestamp');
    return timestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  /// Record first interaction if not already set
  Future<void> recordFirstInteractionIfNeeded() async {
    if (firstInteractionDate == null) {
      await _prefs.setInt(
        'first_interaction_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  /// Days since first interaction (for trial tracking)
  int get daysSinceFirstInteraction {
    final first = firstInteractionDate;
    if (first == null) return 0;
    return DateTime.now().difference(first).inDays;
  }

  /// Is user in trial period? (first 7 days)
  bool get isInTrialPeriod => daysSinceFirstInteraction < 7;

  /// Trial days remaining
  int get trialDaysRemaining => (7 - daysSinceFirstInteraction).clamp(0, 7);

  // ==================== FEATURE DISCOVERY ====================

  /// Features the user has been introduced to
  Set<String> get discoveredFeatures {
    final list = _prefs.getStringList('discovered_features') ?? [];
    return list.toSet();
  }

  /// Mark a feature as discovered/introduced
  Future<void> markFeatureDiscovered(String featureId) async {
    final features = discoveredFeatures;
    features.add(featureId);
    await _prefs.setStringList('discovered_features', features.toList());
  }

  /// Check if feature has been introduced
  bool hasDiscoveredFeature(String featureId) {
    return discoveredFeatures.contains(featureId);
  }

  /// Feature IDs for tracking
  static const String featureVoiceChat = 'voice_chat';
  static const String featureJournal = 'journal';
  static const String featureCalendar = 'calendar';
  static const String featureHealth = 'health';
  static const String featurePrivateSpace = 'private_space';
  static const String featureCustomization = 'customization';
  static const String featureReminders = 'reminders';

  /// Get next feature to introduce based on day
  String? getNextFeatureToIntroduce() {
    final day = daysSinceFirstInteraction;
    final discovered = discoveredFeatures;

    // Day 1-2: Voice chat
    if (day <= 2 && !discovered.contains(featureVoiceChat)) {
      return featureVoiceChat;
    }
    // Day 2-3: Journal
    if (day >= 2 && day <= 4 && !discovered.contains(featureJournal)) {
      return featureJournal;
    }
    // Day 3-4: Calendar
    if (day >= 3 && day <= 5 && !discovered.contains(featureCalendar)) {
      return featureCalendar;
    }
    // Day 4-5: Health
    if (day >= 4 && day <= 6 && !discovered.contains(featureHealth)) {
      return featureHealth;
    }
    // Day 5-6: Private Space
    if (day >= 5 && !discovered.contains(featurePrivateSpace)) {
      return featurePrivateSpace;
    }
    // Day 6-7: Customization
    if (day >= 6 && !discovered.contains(featureCustomization)) {
      return featureCustomization;
    }

    return null;
  }

  /// Get natural introduction text for a feature
  String getFeatureIntroduction(String featureId) {
    switch (featureId) {
      case featureVoiceChat:
        return "By the way, you can talk to me out loud if you prefer - just tap the mic. Some people find it easier than typing.";
      case featureJournal:
        return "I keep a journal tab where you can write down thoughts - and I can help you process them if you want. It's all private.";
      case featureCalendar:
        return "I noticed you mentioned plans - I can actually add things to your calendar directly from our chat. Just say the word.";
      case featureHealth:
        return "If you ever want me to keep an eye on your wellness data - sleep, activity, that kind of thing - I can do that too. Just let me know.";
      case featurePrivateSpace:
        return "There's also a more... personal space in the app. Fully encrypted, completely private. For when you want to chat without any filters.";
      case featureCustomization:
        return "Oh, and you can change my look and voice if you want. Some people like to make their companion their own.";
      case featureReminders:
        return "I'm pretty good at reminding you about things if you need. Just tell me what and when.";
      default:
        return "";
    }
  }

  // ==================== QUESTIONS ASKED ====================

  /// Questions already asked (to avoid repetition)
  Set<String> get askedQuestions {
    final list = _prefs.getStringList('asked_questions') ?? [];
    return list.toSet();
  }

  /// Mark a question as asked
  Future<void> markQuestionAsked(String question) async {
    final questions = askedQuestions;
    questions.add(question);
    await _prefs.setStringList('asked_questions', questions.toList());
  }

  // ==================== LEARNED FACTS ====================

  /// Facts learned about the user
  Map<String, dynamic> get learnedFacts {
    final json = _prefs.getString('learned_facts');
    if (json == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(json));
    } catch (e) {
      return {};
    }
  }

  /// Store a learned fact
  Future<void> learnFact(String key, dynamic value) async {
    final facts = learnedFacts;
    facts[key] = value;
    await _prefs.setString('learned_facts', jsonEncode(facts));
  }

  /// Common fact keys
  static const String factName = 'name';
  static const String factLocation = 'location';
  static const String factJob = 'job';
  static const String factMorningPerson = 'morning_person';
  static const String factCoffeeOrTea = 'coffee_or_tea';
  static const String factHobbies = 'hobbies';
  static const String factGoals = 'goals';

  // ==================== INTERACTION STREAK ====================

  /// Current interaction streak (consecutive days)
  int get interactionStreak => _prefs.getInt('interaction_streak') ?? 0;

  /// Last interaction date
  DateTime? get lastInteractionDate {
    final timestamp = _prefs.getInt('last_interaction_timestamp');
    return timestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  /// Update streak based on today's interaction
  Future<void> recordDailyInteraction() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = lastInteractionDate;

    if (last == null) {
      // First ever interaction
      await _prefs.setInt('interaction_streak', 1);
    } else {
      final lastDay = DateTime(last.year, last.month, last.day);
      final daysDiff = today.difference(lastDay).inDays;

      if (daysDiff == 0) {
        // Same day, no change
      } else if (daysDiff == 1) {
        // Consecutive day, increment streak
        await _prefs.setInt('interaction_streak', interactionStreak + 1);
      } else {
        // Streak broken, reset
        await _prefs.setInt('interaction_streak', 1);
      }
    }

    await _prefs.setInt('last_interaction_timestamp', now.millisecondsSinceEpoch);
  }

  // ==================== BOND LEVEL ====================

  /// Calculate bond level (0-100) based on engagement metrics
  int get bondLevel {
    int level = 0;

    // Base: Days of interaction (+10 per day, max 70)
    level += (daysSinceFirstInteraction * 10).clamp(0, 70);

    // Bonus: Facts learned (+5 each, max 20)
    level += (learnedFacts.length * 5).clamp(0, 20);

    // Bonus: Streak (+2 per day, max 10)
    level += (interactionStreak * 2).clamp(0, 10);

    return level.clamp(0, 100);
  }

  /// Human-readable bond stage
  String get bondStage {
    if (bondLevel < 20) return 'Acquaintance';
    if (bondLevel < 40) return 'Getting Familiar';
    if (bondLevel < 60) return 'Building Trust';
    if (bondLevel < 80) return 'Close Connection';
    return 'Deep Bond';
  }

  // ==================== GREETING CONTEXT ====================

  /// Get greeting context for the AI based on current state
  String getGreetingContext() {
    final buffer = StringBuffer();
    final day = daysSinceFirstInteraction;
    final hour = DateTime.now().hour;

    buffer.writeln('ONBOARDING CONTEXT:');
    buffer.writeln('- Day $day of relationship (${isInTrialPeriod ? "trial period" : "past trial"})');
    buffer.writeln('- Bond level: $bondLevel/100 ($bondStage)');
    buffer.writeln('- Interaction streak: $interactionStreak days');

    // Time of day context
    if (hour >= 5 && hour < 12) {
      buffer.writeln('- Time: Morning - consider a gentle energy check');
    } else if (hour >= 12 && hour < 17) {
      buffer.writeln('- Time: Afternoon');
    } else if (hour >= 17 && hour < 21) {
      buffer.writeln('- Time: Evening - consider a reflection prompt');
    } else {
      buffer.writeln('- Time: Night - be calm and brief');
    }

    // Feature introduction opportunity
    final nextFeature = getNextFeatureToIntroduce();
    if (nextFeature != null) {
      buffer.writeln('- Opportunity to naturally introduce: $nextFeature');
    }

    // Known facts
    final facts = learnedFacts;
    if (facts.isNotEmpty) {
      buffer.writeln('- Known facts about user:');
      facts.forEach((key, value) {
        buffer.writeln('  • $key: $value');
      });
    }

    return buffer.toString();
  }
}
