import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sable/core/emotion/weather_service.dart';

/// Represents weather data for a specific date
class DailyWeatherRecord {
  final DateTime date;
  final String condition;
  final double temperature;
  final double? tempHigh;
  final double? tempLow;
  final int? humidity;
  final String? location;
  final DateTime recordedAt;

  DailyWeatherRecord({
    required this.date,
    required this.condition,
    required this.temperature,
    this.tempHigh,
    this.tempLow,
    this.humidity,
    this.location,
    required this.recordedAt,
  });

  String get emoji {
    final lowerCondition = condition.toLowerCase();
    if (lowerCondition.contains('clear') || lowerCondition.contains('sunny')) return '☀️';
    if (lowerCondition.contains('cloud')) return '☁️';
    if (lowerCondition.contains('rain') || lowerCondition.contains('drizzle')) return '🌧️';
    if (lowerCondition.contains('snow')) return '❄️';
    if (lowerCondition.contains('thunder') || lowerCondition.contains('storm')) return '⛈️';
    if (lowerCondition.contains('fog') || lowerCondition.contains('mist')) return '🌫️';
    if (lowerCondition.contains('wind')) return '💨';
    return '🌤️';
  }

  String get summary {
    final highLow = tempHigh != null && tempLow != null 
        ? 'H:${tempHigh!.round()}° L:${tempLow!.round()}°'
        : '${temperature.round()}°F';
    return '$emoji $condition, $highLow';
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'condition': condition,
    'temperature': temperature,
    'tempHigh': tempHigh,
    'tempLow': tempLow,
    'humidity': humidity,
    'location': location,
    'recordedAt': recordedAt.toIso8601String(),
  };

  factory DailyWeatherRecord.fromJson(Map<String, dynamic> json) => DailyWeatherRecord(
    date: DateTime.parse(json['date']),
    condition: json['condition'],
    temperature: (json['temperature'] as num).toDouble(),
    tempHigh: json['tempHigh'] != null ? (json['tempHigh'] as num).toDouble() : null,
    tempLow: json['tempLow'] != null ? (json['tempLow'] as num).toDouble() : null,
    humidity: json['humidity'],
    location: json['location'],
    recordedAt: DateTime.parse(json['recordedAt']),
  );
}

/// Service for tracking and storing weather history
class WeatherHistoryService {
  static const _historyKey = 'weather_history';
  static const _maxRecords = 365; // Keep 1 year of history

  /// Record today's weather
  static Future<void> recordTodayWeather({
    required String condition,
    required double temperature,
    double? tempHigh,
    double? tempLow,
    int? humidity,
    String? location,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final record = DailyWeatherRecord(
      date: today,
      condition: condition,
      temperature: temperature,
      tempHigh: tempHigh,
      tempLow: tempLow,
      humidity: humidity,
      location: location,
      recordedAt: now,
    );
    
    await _saveRecord(record);
    debugPrint('🌤️ Recorded weather for ${today.toIso8601String()}');
  }

  /// Get weather for a specific date
  static Future<DailyWeatherRecord?> getWeatherForDate(DateTime date) async {
    final history = await _getHistory();
    final targetDate = DateTime(date.year, date.month, date.day);
    
    try {
      return history.firstWhere(
        (r) => r.date.year == targetDate.year && 
               r.date.month == targetDate.month && 
               r.date.day == targetDate.day,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get weather history for a date range
  static Future<List<DailyWeatherRecord>> getWeatherForRange(DateTime start, DateTime end) async {
    final history = await _getHistory();
    return history.where((r) => 
      r.date.isAfter(start.subtract(const Duration(days: 1))) &&
      r.date.isBefore(end.add(const Duration(days: 1)))
    ).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Check if we have weather recorded for today
  static Future<bool> hasRecordedToday() async {
    final record = await getWeatherForDate(DateTime.now());
    return record != null;
  }

  /// Auto-record weather from current conditions
  static Future<void> autoRecordFromCurrent(String location) async {
    if (await hasRecordedToday()) {
      debugPrint('📅 Weather already recorded for today');
      return;
    }

    try {
      final weather = await WeatherService.getWeather(location);
      if (weather != null) {
        await recordTodayWeather(
          condition: weather.description,
          temperature: weather.temperature,
          tempHigh: weather.tempHigh,
          tempLow: weather.tempLow,
          humidity: weather.humidity,
          location: location,
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to auto-record weather: $e');
    }
  }

  /// Get weather summary for AI context
  static Future<String> getWeatherSummary({int days = 7}) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    final history = await getWeatherForRange(start, now);
    
    if (history.isEmpty) {
      return '[WEATHER HISTORY]\nNo weather data recorded.\n[END WEATHER HISTORY]';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('[WEATHER HISTORY]');
    buffer.writeln('Last $days days:');
    
    for (final record in history) {
      final dayName = _getDayName(record.date);
      buffer.writeln('- $dayName: ${record.summary}');
    }
    
    buffer.writeln('[END WEATHER HISTORY]');
    return buffer.toString();
  }

  static String _getDayName(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(date.year, date.month, date.day)).inDays;
    
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }

  static Future<List<DailyWeatherRecord>> _getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    
    if (historyJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(historyJson);
        return decoded.map((e) => DailyWeatherRecord.fromJson(e)).toList();
      } catch (e) {
        debugPrint('❌ Error decoding weather history: $e');
      }
    }
    return [];
  }

  static Future<void> _saveRecord(DailyWeatherRecord record) async {
    final history = await _getHistory();
    
    // Remove existing record for this date if any
    history.removeWhere((r) => 
      r.date.year == record.date.year &&
      r.date.month == record.date.month &&
      r.date.day == record.date.day
    );
    
    // Add new record
    history.add(record);
    
    // Trim to max records (keep most recent)
    if (history.length > _maxRecords) {
      history.sort((a, b) => b.date.compareTo(a.date));
      history.removeRange(_maxRecords, history.length);
    }
    
    // Save
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );
  }
}
