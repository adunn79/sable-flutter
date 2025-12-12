import 'package:flutter/foundation.dart';
import 'package:sable/features/journal/models/journal_entry.dart';
import 'package:sable/features/journal/models/journal_insights.dart';
import 'package:sable/core/ai/providers/gemini_provider.dart';

/// Service for analyzing journal entries and generating insights
class JournalAnalysisService {
  
  /// Generate comprehensive insights from journal entries
  static Future<JournalInsights> generateInsights({
    required List<JournalEntry> entries,
    int daysToAnalyze = 30,
  }) async {
    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(days: daysToAnalyze));
    
    // Filter to recent entries
    final recentEntries = entries
        .where((e) => e.timestamp.isAfter(cutoffDate))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    if (recentEntries.isEmpty) {
      return _emptyInsights();
    }
    
    // Generate all insights in parallel
    final results = await Future.wait([
      _analyzeMoodTrends(recentEntries),
      _analyzeWritingPatterns(recentEntries),
      _extractThemes(recentEntries),
      _analyzeWordFrequency(recentEntries),
      _generateWeeklySummary(recentEntries),
      _findCorrelations(recentEntries),
    ]);
    
    return JournalInsights(
      moodTrends: results[0] as MoodTrends,
      writingPatterns: results[1] as WritingPatterns,
      themes: results[2] as List<ThemeInsight>,
      wordFrequency: results[3] as Map<String, int>,
      weeklySummary: results[4] as String,
      correlations: results[5] as List<Correlation>,
    );
  }
  
  /// Analyze mood trends over time
  static Future<MoodTrends> _analyzeMoodTrends(List<JournalEntry> entries) async {
    // Group by day
    final moodByDay = <DateTime, List<int>>{};
    for (final entry in entries) {
      if (entry.moodScore != null) {
        final day = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
        moodByDay.putIfAbsent(day, () => []).add(entry.moodScore!);
      }
    }
    
    // Calculate daily averages
    final dataPoints = moodByDay.entries.map((e) {
      final avgMood = e.value.reduce((a, b) => a + b) / e.value.length;
      return MoodDataPoint(
        date: e.key,
        moodScore: avgMood,
        entryCount: e.value.length,
      );
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
    
    if (dataPoints.isEmpty) {
      return MoodTrends(
        dailyMoods: [],
        weeklyAverage: 0,
        monthlyAverage: 0,
        improvement: 0,
        bestDay: 'Unknown',
        worstDay: 'Unknown',
        trend: 'stable',
      );
    }
    
    // Calculate averages
    final allScores = dataPoints.map((e) => e.moodScore).toList();
    final monthlyAvg = allScores.reduce((a, b) => a + b) / allScores.length;
    
    // Weekly average (last 7 days)
    final weeklyPoints = dataPoints.where((p) => 
      p.date.isAfter(DateTime.now().subtract(const Duration(days: 7)))
    ).toList();
    final weeklyAvg = weeklyPoints.isEmpty 
        ? monthlyAvg 
        : weeklyPoints.map((e) => e.moodScore).reduce((a, b) => a + b) / weeklyPoints.length;
    
    // Calculate improvement (compare first week vs last week)
    final firstWeekAvg = dataPoints.take(7).map((e) => e.moodScore).reduce((a, b) => a + b) / 7;
    final lastWeekAvg = weeklyAvg;
    final improvement = ((lastWeekAvg - firstWeekAvg) / firstWeekAvg) * 100;
    
    // Find best/worst days of week
    final moodByDayOfWeek = <int, List<double>>{};
    for (final point in dataPoints) {
      moodByDayOfWeek.putIfAbsent(point.date.weekday, () => []).add(point.moodScore);
    }
    
    final dayAverages = moodByDayOfWeek.map((day, scores) => 
      MapEntry(day, scores.reduce((a, b) => a + b) / scores.length)
    );
    
    final bestDayNum = dayAverages.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final worstDayNum = dayAverages.entries.reduce((a, b) => a.value < b.value ? a : b).key;
    
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    // Determine trend
    String trend = 'stable';
    if (improvement > 10) trend = 'improving';
    else if (improvement < -10) trend = 'declining';
    
    return MoodTrends(
      dailyMoods: dataPoints,
      weeklyAverage: weeklyAvg,
      monthlyAverage: monthlyAvg,
      improvement: improvement,
      bestDay: dayNames[bestDayNum - 1],
      worstDay: dayNames[worstDayNum - 1],
      trend: trend,
    );
  }
  
  /// Analyze writing patterns
  static Future<WritingPatterns> _analyzeWritingPatterns(List<JournalEntry> entries) async {
    // Calculate streaks
    final sortedDates = entries.map((e) => 
      DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day)
    ).toSet().toList()..sort();
    
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 1;
    
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 1));
    
    // Calculate current streak
    if (sortedDates.isNotEmpty) {
      final lastEntry = sortedDates.last;
      final todayDate = DateTime(today.year, today.month, today.day);
      
      if (lastEntry == todayDate || lastEntry == yesterday) {
        currentStreak = 1;
        for (int i = sortedDates.length - 2; i >= 0; i--) {
          if (sortedDates[i] == sortedDates[i + 1].subtract(const Duration(days: 1))) {
            currentStreak++;
          } else {
            break;
          }
        }
      }
    }
    
    // Calculate longest streak
    for (int i = 1; i < sortedDates.length; i++) {
      if (sortedDates[i] == sortedDates[i - 1].add(const Duration(days: 1))) {
        tempStreak++;
        longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;
      } else {
        tempStreak = 1;
      }
    }
    
    // Average word count
    final wordCounts = entries.map((e) => e.plainText.split(' ').length).toList();
    final avgWordCount = wordCounts.isEmpty 
        ? 0.0 
        : wordCounts.reduce((a, b) => a + b) / wordCounts.length;
    
    // Best writing time (hour of day)
    final entriesByHour = <int, int>{};
    for (final entry in entries) {
      entriesByHour[entry.timestamp.hour] = (entriesByHour[entry.timestamp.hour] ?? 0) + 1;
    }
    
    final bestHour = entriesByHour.entries.isEmpty 
        ? 20 
        : entriesByHour.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    
    final period = bestHour < 12 ? 'AM' : 'PM';
    final hour12 = bestHour > 12 ? bestHour - 12 : (bestHour == 0 ? 12 : bestHour);
    
    // Entries by day of week
    final entriesByDayOfWeek = <int, int>{};
    for (final entry in entries) {
      entriesByDayOfWeek[entry.timestamp.weekday] = 
          (entriesByDayOfWeek[entry.timestamp.weekday] ?? 0) + 1;
    }
    
    // Consistency score (entries per week)
    final weeks = (entries.last.timestamp.difference(entries.first.timestamp).inDays / 7).ceil();
    final entriesPerWeek = weeks > 0 ? entries.length / weeks : 0;
    final consistencyScore = (entriesPerWeek / 7 * 100).clamp(0, 100).toDouble();
    
    return WritingPatterns(
      totalEntries: entries.length,
      longestStreak: longestStreak,
      currentStreak: currentStreak,
      averageWordCount: avgWordCount,
      bestWritingTime: '$hour12 $period',
      entriesByDayOfWeek: entriesByDayOfWeek,
      consistencyScore: consistencyScore,
    );
  }
  
  /// Extract themes from entries using simple keyword analysis
  static Future<List<ThemeInsight>> _extractThemes(List<JournalEntry> entries) async {
    // Common themes to look for
    final themeKeywords = {
      'work': ['work', 'job', 'career', 'boss', 'meeting', 'project', 'deadline'],
      'family': ['family', 'mom', 'dad', 'sister', 'brother', 'parent', 'child', 'children'],
      'relationships': ['love', 'partner', 'boyfriend', 'girlfriend', 'husband', 'wife', 'relationship'],
      'health': ['health', 'exercise', 'workout', 'gym', 'fitness', 'diet', 'sleep'],
      'anxiety': ['anxiety', 'anxious', 'worry', 'worried', 'stress', 'stressed', 'nervous'],
      'happiness': ['happy', 'joy', 'excited', 'great', 'wonderful', 'amazing', 'fantastic'],
      'gratitude': ['grateful', 'thankful', 'appreciate', 'blessed', 'fortunate'],
      'friends': ['friend', 'friends', 'friendship', 'social'],
    };
    
    final themeCounts = <String, int>{};
    final themeSentiments = <String, List<double>>{};
    
    for (final entry in entries) {
      final text = entry.plainText.toLowerCase();
      
      for (final theme in themeKeywords.keys) {
        final keywords = themeKeywords[theme]!;
        int count = 0;
        
        for (final keyword in keywords) {
          count += keyword.allMatches(text).length;
        }
        
        if (count > 0) {
          themeCounts[theme] = (themeCounts[theme] ?? 0) + count;
          
          // Simple sentiment based on mood score
          if (entry.moodScore != null) {
            final sentiment = (entry.moodScore! - 3) / 2; // Convert 1-5 to -1 to 1
            themeSentiments.putIfAbsent(theme, () => []).add(sentiment);
          }
        }
      }
    }
    
    // Convert to insights
    final insights = themeCounts.entries.map((e) {
      final avgSentiment = themeSentiments[e.key]?.isEmpty ?? true
          ? 0.0
          : themeSentiments[e.key]!.reduce((a, b) => a + b) / themeSentiments[e.key]!.length;
      
      return ThemeInsight(
        theme: e.key,
        count: e.value,
        sentimentScore: avgSentiment,
        relatedWords: themeKeywords[e.key]!.take(3).toList(),
        trend: 'stable', // TODO: Calculate trend by comparing first half vs second half
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    
    return insights.take(8).toList();
  }
  
  /// Analyze word frequency for word cloud
  static Future<Map<String, int>> _analyzeWordFrequency(List<JournalEntry> entries) async {
    final wordCounts = <String, int>{};
    
    // Common stop words to exclude
    final stopWords = {
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'of', 'with', 'by', 'from', 'as', 'is', 'was', 'are', 'were', 'be',
      'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will',
      'would', 'should', 'could', 'may', 'might', 'must', 'can', 'i', 'you',
      'he', 'she', 'it', 'we', 'they', 'my', 'your', 'his', 'her', 'its',
      'our', 'their', 'this', 'that', 'these', 'those', 'am', 'im', 'ive'
    };
    
    for (final entry in entries) {
      final words = entry.plainText
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(RegExp(r'\s+'));
      
      for (final word in words) {
        if (word.length > 3 && !stopWords.contains(word)) {
          wordCounts[word] = (wordCounts[word] ?? 0) + 1;
        }
      }
    }
    
    // Return top 50 words
    final sortedEntries = wordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Map.fromEntries(sortedEntries.take(50));
  }
  
  /// Generate AI-powered weekly summary
  static Future<String> _generateWeeklySummary(List<JournalEntry> entries) async {
    try {
      // Get last 7 days of entries
      final weekEntries = entries.where((e) => 
        e.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7)))
      ).toList();
      
      if (weekEntries.isEmpty) {
        return "You haven't journaled this week. Start writing to see your weekly summary!";
      }
      
      // Combine entry text
      final combinedText = weekEntries
          .map((e) => e.plainText)
          .take(5) // Limit to avoid token limits
          .join('\n\n');
      
      final gemini = GeminiProvider();
      final summary = await gemini.generateResponse(
        prompt: '''Analyze these journal entries from the past week and create a brief, empathetic 2-3 sentence summary highlighting:
1. Main themes or topics
2. Overall emotional tone
3. One key insight or pattern

Entries:
$combinedText

Summary (2-3 sentences, warm and encouraging tone):''',
        systemPrompt: 'You are a supportive journaling coach. Be brief, warm, and insightful.',
        modelId: 'gemini-2.0-flash-exp',
      );
      
      return summary.trim();
    } catch (e) {
      debugPrint('❌ Weekly summary generation failed: $e');
      return "This week you wrote ${entries.length} entries. Keep up the great work!";
    }
  }
  
  /// Find correlations between factors
  static Future<List<Correlation>> _findCorrelations(List<JournalEntry> entries) async {
    final correlations = <Correlation>[];
    
    // Mood vs Day of Week
    final moodByDay = <int, List<int>>{};
    for (final entry in entries) {
      if (entry.moodScore != null) {
        moodByDay.putIfAbsent(entry.timestamp.weekday, () => []).add(entry.moodScore!);
      }
    }
    
    if (moodByDay.isNotEmpty) {
      final dayAverages = moodByDay.map((day, scores) => 
        MapEntry(day, scores.reduce((a, b) => a + b) / scores.length)
      );
      
      final bestDay = dayAverages.entries.reduce((a, b) => a.value > b.value ? a : b);
      final worstDay = dayAverages.entries.reduce((a, b) => a.value < b.value ? a : b);
      
      final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      
      correlations.add(Correlation(
        factor1: 'Mood',
        factor2: 'Day of Week',
        strength: 0.6,
        insight: 'You\'re happiest on ${dayNames[bestDay.key - 1]}s and lowest on ${dayNames[worstDay.key - 1]}s',
      ));
    }
    
    // Mood vs Gratitude practice
    final gratitudeEntries = entries.where((e) => 
      e.tags.any((tag) => tag.toLowerCase().contains('gratitude')) ||
      e.plainText.toLowerCase().contains('grateful') ||
      e.plainText.toLowerCase().contains('thankful')
    ).toList();
    
    if (gratitudeEntries.isNotEmpty) {
      final gratitudeMoodAvg = gratitudeEntries
          .where((e) => e.moodScore != null)
          .map((e) => e.moodScore!)
          .fold<double>(0, (a, b) => a + b) / gratitudeEntries.length;
      
      final nonGratitudeMoodAvg = entries
          .where((e) => !gratitudeEntries.contains(e) && e.moodScore != null)
          .map((e) => e.moodScore!)
          .fold<double>(0, (a, b) => a + b) / entries.length;
      
      if (gratitudeMoodAvg > nonGratitudeMoodAvg) {
        correlations.add(Correlation(
          factor1: 'Gratitude Practice',
          factor2: 'Mood',
          strength: 0.7,
          insight: 'Days with gratitude journaling have ${((gratitudeMoodAvg / nonGratitudeMoodAvg - 1) * 100).toStringAsFixed(0)}% higher mood scores',
        ));
      }
    }
    
    return correlations;
  }
  
  static JournalInsights _emptyInsights() {
    return JournalInsights(
      moodTrends: MoodTrends(
        dailyMoods: [],
        weeklyAverage: 0,
        monthlyAverage: 0,
        improvement: 0,
        bestDay: 'Unknown',
        worstDay: 'Unknown',
        trend: 'stable',
      ),
      writingPatterns: WritingPatterns(
        totalEntries: 0,
        longestStreak: 0,
        currentStreak: 0,
        averageWordCount: 0,
        bestWritingTime: '8 PM',
        entriesByDayOfWeek: {},
        consistencyScore: 0,
      ),
      themes: [],
      wordFrequency: {},
      weeklySummary: 'Start journaling to see insights!',
      correlations: [],
    );
  }
}
