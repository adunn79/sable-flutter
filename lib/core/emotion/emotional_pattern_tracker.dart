import 'package:flutter/foundation.dart';
import 'package:sable/features/journal/models/journal_entry.dart';
import 'package:sable/features/journal/services/journal_storage_service.dart';
import 'package:sable/core/memory/unified_memory_service.dart';

/// Emotional Pattern Tracker for Phase 2: Memory Spine & Intelligence
/// Detects recurring emotional cycles, triggers, and patterns
class EmotionalPatternTracker {
  static final EmotionalPatternTracker _instance = EmotionalPatternTracker._internal();
  factory EmotionalPatternTracker() => _instance;
  EmotionalPatternTracker._internal();

  final UnifiedMemoryService _memoryService = UnifiedMemoryService();

  bool _initialized = false;
  List<EmotionalPattern> _cachedPatterns = [];
  DateTime? _lastAnalysis;
  static const _cacheExpiry = Duration(hours: 1);

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    
    await JournalStorageService.initialize();
    await _memoryService.initialize();
    _initialized = true;
    
    debugPrint('✅ EmotionalPatternTracker initialized');
  }

  /// Detect recurring emotional patterns
  Future<List<EmotionalPattern>> detectPatterns() async {
    if (!_initialized) await initialize();

    // Use cache if recent
    if (_cachedPatterns.isNotEmpty && 
        _lastAnalysis != null &&
        DateTime.now().difference(_lastAnalysis!) < _cacheExpiry) {
      return _cachedPatterns;
    }

    final patterns = <EmotionalPattern>[];

    try {
      final entries = JournalStorageService.getAllEntries();
      if (entries.length < 7) {
        return []; // Need at least a week of data
      }

      // 1. Day-of-week patterns
      patterns.addAll(_analyzeDayOfWeekPatterns(entries));

      // 2. Time-of-day patterns
      patterns.addAll(_analyzeTimeOfDayPatterns(entries));

      // 3. Activity-based patterns
      patterns.addAll(_analyzeActivityPatterns(entries));

      // 4. Streak patterns (journaling effect)
      patterns.addAll(_analyzeJournalingEffects(entries));

      // Sort by confidence
      patterns.sort((a, b) => b.confidence.compareTo(a.confidence));

      _cachedPatterns = patterns;
      _lastAnalysis = DateTime.now();

      return patterns;
    } catch (e) {
      debugPrint('❌ Pattern detection error: $e');
      return [];
    }
  }

  /// Get patterns formatted for AI context
  Future<String> getPatternsContext() async {
    final patterns = await detectPatterns();
    if (patterns.isEmpty) return '';

    final buffer = StringBuffer('[EMOTIONAL PATTERNS DETECTED]\n');
    
    for (final pattern in patterns.take(5)) {
      buffer.writeln('- ${pattern.description} (${(pattern.confidence * 100).toStringAsFixed(0)}% confidence)');
    }
    
    buffer.writeln('[END PATTERNS]');
    return buffer.toString();
  }

  /// Predict emotional state based on patterns
  /// Returns expected mood score (1-5) and confidence
  Future<MoodPrediction> predictMood({DateTime? forTime}) async {
    final patterns = await detectPatterns();
    if (patterns.isEmpty) {
      return MoodPrediction(predictedMood: 3.0, confidence: 0.0, basedOn: []);
    }

    final targetTime = forTime ?? DateTime.now();
    double weightedMood = 0;
    double totalWeight = 0;
    final usedPatterns = <EmotionalPattern>[];

    for (final pattern in patterns) {
      if (pattern.appliesTo(targetTime)) {
        weightedMood += pattern.averageMood * pattern.confidence;
        totalWeight += pattern.confidence;
        usedPatterns.add(pattern);
      }
    }

    if (totalWeight == 0) {
      return MoodPrediction(predictedMood: 3.0, confidence: 0.0, basedOn: []);
    }

    return MoodPrediction(
      predictedMood: weightedMood / totalWeight,
      confidence: (totalWeight / patterns.length).clamp(0.0, 1.0),
      basedOn: usedPatterns,
    );
  }

  /// Analyze day-of-week patterns (e.g., "You tend to feel stressed on Mondays")
  List<EmotionalPattern> _analyzeDayOfWeekPatterns(List<JournalEntry> entries) {
    final patterns = <EmotionalPattern>[];
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    // Group by day of week
    final moodByDay = <int, List<int>>{};
    for (final entry in entries) {
      if (entry.moodScore != null) {
        moodByDay.putIfAbsent(entry.timestamp.weekday, () => []).add(entry.moodScore!);
      }
    }

    if (moodByDay.isEmpty) return patterns;

    // Calculate overall average
    final allMoods = entries.where((e) => e.moodScore != null).map((e) => e.moodScore!);
    final overallAvg = allMoods.isEmpty ? 3.0 : allMoods.reduce((a, b) => a + b) / allMoods.length;

    // Find significant deviations
    for (final entry in moodByDay.entries) {
      if (entry.value.length >= 2) { // Need at least 2 data points
        final dayAvg = entry.value.reduce((a, b) => a + b) / entry.value.length;
        final deviation = dayAvg - overallAvg;
        
        if (deviation.abs() > 0.5) { // Significant deviation
          final dayName = dayNames[entry.key - 1];
          final direction = deviation > 0 ? 'better' : 'lower';
          
          patterns.add(EmotionalPattern(
            type: PatternType.dayOfWeek,
            description: 'Your mood tends to be $direction on ${dayName}s',
            averageMood: dayAvg,
            confidence: (entry.value.length / 10).clamp(0.3, 0.9),
            triggeredBy: dayName,
            dayOfWeek: entry.key,
          ));
        }
      }
    }

    return patterns;
  }

  /// Analyze time-of-day patterns
  List<EmotionalPattern> _analyzeTimeOfDayPatterns(List<JournalEntry> entries) {
    final patterns = <EmotionalPattern>[];
    
    // Group by time period (morning, afternoon, evening, night)
    final moodByPeriod = <String, List<int>>{};
    
    for (final entry in entries) {
      if (entry.moodScore != null) {
        final hour = entry.timestamp.hour;
        String period;
        if (hour >= 5 && hour < 12) {
          period = 'morning';
        } else if (hour >= 12 && hour < 17) {
          period = 'afternoon';
        } else if (hour >= 17 && hour < 21) {
          period = 'evening';
        } else {
          period = 'night';
        }
        moodByPeriod.putIfAbsent(period, () => []).add(entry.moodScore!);
      }
    }

    // Find the best time of day
    if (moodByPeriod.length >= 2) {
      final averages = moodByPeriod.map((period, moods) {
        final avg = moods.reduce((a, b) => a + b) / moods.length;
        return MapEntry(period, avg);
      });

      final best = averages.entries.reduce((a, b) => a.value > b.value ? a : b);
      final worst = averages.entries.reduce((a, b) => a.value < b.value ? a : b);

      if (best.value - worst.value > 0.5) {
        patterns.add(EmotionalPattern(
          type: PatternType.timeOfDay,
          description: 'You tend to feel best in the ${best.key}',
          averageMood: best.value,
          confidence: 0.7,
          triggeredBy: best.key,
        ));
      }
    }

    return patterns;
  }

  /// Analyze activity-based patterns (from tagged people, locations, etc.)
  List<EmotionalPattern> _analyzeActivityPatterns(List<JournalEntry> entries) {
    final patterns = <EmotionalPattern>[];
    
    // Analyze based on tags
    final moodByTag = <String, List<int>>{};
    
    for (final entry in entries) {
      if (entry.moodScore != null) {
        for (final tag in entry.tags) {
          moodByTag.putIfAbsent(tag.toLowerCase(), () => []).add(entry.moodScore!);
        }
      }
    }

    // Find tags with positive correlation
    for (final entry in moodByTag.entries) {
      if (entry.value.length >= 3) {
        final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
        
        if (avg >= 4.0) {
          patterns.add(EmotionalPattern(
            type: PatternType.activity,
            description: 'You tend to feel happier when "${entry.key}" is involved',
            averageMood: avg,
            confidence: (entry.value.length / 15).clamp(0.3, 0.8),
            triggeredBy: entry.key,
          ));
        }
      }
    }

    return patterns;
  }

  /// Analyze the effect of journaling streaks on mood
  List<EmotionalPattern> _analyzeJournalingEffects(List<JournalEntry> entries) {
    final patterns = <EmotionalPattern>[];
    
    // Compare mood when journaling consistently vs not
    final sortedEntries = entries.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    int consecutiveDays = 0;
    DateTime? lastDate;
    final streakMoods = <int>[];
    final nonStreakMoods = <int>[];

    for (final entry in sortedEntries) {
      final entryDate = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      
      if (lastDate != null) {
        if (entryDate.difference(lastDate!).inDays == 1) {
          consecutiveDays++;
        } else {
          consecutiveDays = 1;
        }
      } else {
        consecutiveDays = 1;
      }
      
      if (entry.moodScore != null) {
        if (consecutiveDays >= 3) {
          streakMoods.add(entry.moodScore!);
        } else {
          nonStreakMoods.add(entry.moodScore!);
        }
      }
      
      lastDate = entryDate;
    }

    if (streakMoods.length >= 3 && nonStreakMoods.length >= 3) {
      final streakAvg = streakMoods.reduce((a, b) => a + b) / streakMoods.length;
      final nonStreakAvg = nonStreakMoods.reduce((a, b) => a + b) / nonStreakMoods.length;

      if (streakAvg > nonStreakAvg + 0.3) {
        patterns.add(EmotionalPattern(
          type: PatternType.habit,
          description: 'Your mood improves when you journal consistently for 3+ days',
          averageMood: streakAvg,
          confidence: 0.75,
          triggeredBy: 'consistent journaling',
        ));
      }
    }

    return patterns;
  }
}

/// Represents a detected emotional pattern
class EmotionalPattern {
  final PatternType type;
  final String description;
  final double averageMood;
  final double confidence;
  final String triggeredBy;
  final int? dayOfWeek; // 1-7 for day patterns
  final String? timeOfDay; // morning, afternoon, evening, night

  EmotionalPattern({
    required this.type,
    required this.description,
    required this.averageMood,
    required this.confidence,
    required this.triggeredBy,
    this.dayOfWeek,
    this.timeOfDay,
  });

  /// Check if this pattern applies to a given time
  bool appliesTo(DateTime time) {
    switch (type) {
      case PatternType.dayOfWeek:
        return dayOfWeek == time.weekday;
      case PatternType.timeOfDay:
        final hour = time.hour;
        if (triggeredBy == 'morning') return hour >= 5 && hour < 12;
        if (triggeredBy == 'afternoon') return hour >= 12 && hour < 17;
        if (triggeredBy == 'evening') return hour >= 17 && hour < 21;
        if (triggeredBy == 'night') return hour >= 21 || hour < 5;
        return false;
      default:
        return true; // Other patterns always apply
    }
  }
}

/// Type of emotional pattern
enum PatternType {
  dayOfWeek,
  timeOfDay,
  activity,
  habit,
  social,
  seasonal,
}

/// Prediction result
class MoodPrediction {
  final double predictedMood;
  final double confidence;
  final List<EmotionalPattern> basedOn;

  MoodPrediction({
    required this.predictedMood,
    required this.confidence,
    required this.basedOn,
  });
}
