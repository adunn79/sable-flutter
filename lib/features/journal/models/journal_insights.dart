import 'package:sable/features/journal/models/journal_entry.dart';

/// Insights generated from journal analysis
class JournalInsights {
  final MoodTrends moodTrends;
  final WritingPatterns writingPatterns;
  final List<ThemeInsight> themes;
  final Map<String, int> wordFrequency;
  final String weeklySummary;
  final List<Correlation> correlations;

  const JournalInsights({
    required this.moodTrends,
    required this.writingPatterns,
    required this.themes,
    required this.wordFrequency,
    required this.weeklySummary,
    required this.correlations,
  });
}

/// Mood trend analysis
class MoodTrends {
  final List<MoodDataPoint> dailyMoods;
  final double weeklyAverage;
  final double monthlyAverage;
  final double improvement; // Percentage change
  final String bestDay; // Day of week with highest mood
  final String worstDay; // Day of week with lowest mood
  final String trend; // "improving", "stable", "declining"

  const MoodTrends({
    required this.dailyMoods,
    required this.weeklyAverage,
    required this.monthlyAverage,
    required this.improvement,
    required this.bestDay,
    required this.worstDay,
    required this.trend,
  });
}

class MoodDataPoint {
  final DateTime date;
  final double moodScore; // 1-5
  final int entryCount;

  const MoodDataPoint({
    required this.date,
    required this.moodScore,
    required this.entryCount,
  });
}

/// Writing pattern analysis
class WritingPatterns {
  final int totalEntries;
  final int longestStreak;
  final int currentStreak;
  final double averageWordCount;
  final String bestWritingTime; // e.g., "9 PM"
  final Map<int, int> entriesByDayOfWeek; // 0=Monday, 6=Sunday
  final double consistencyScore; // 0-100

  const WritingPatterns({
    required this.totalEntries,
    required this.longestStreak,
    required this.currentStreak,
    required this.averageWordCount,
    required this.bestWritingTime,
    required this.entriesByDayOfWeek,
    required this.consistencyScore,
  });
}

/// Theme extracted from entries
class ThemeInsight {
  final String theme;
  final int count;
  final double sentimentScore; // -1 to 1
  final List<String> relatedWords;
  final String trend; // "increasing", "stable", "decreasing"

  const ThemeInsight({
    required this.theme,
    required this.count,
    required this.sentimentScore,
    required this.relatedWords,
    required this.trend,
  });
}

/// Correlation between factors
class Correlation {
  final String factor1;
  final String factor2;
  final double strength; // 0-1
  final String insight;

  const Correlation({
    required this.factor1,
    required this.factor2,
    required this.strength,
    required this.insight,
  });
}
