import 'package:sable/core/emotion/weather_service.dart';

/// Environmental context provider for mood modifiers
/// Considers time of day, season, day of week, and weather
class EnvironmentContext {
  /// Get environmental mood modifier based on current conditions
  /// Returns value from -20 to +20
  /// Optionally includes weather if available
  static Future<double> getMoodModifier({String? location}) async {
    final now = DateTime.now();
    
    double modifier = 0.0;

    // Time of day modifier
    modifier += _getTimeOfDayModifier(now.hour);
    
    // Season modifier
    modifier += _getSeasonModifier(now.month);
    
    // Day of week modifier
    modifier += _getDayOfWeekModifier(now.weekday);
    
    // Weather modifier (if location provided)
    if (location != null) {
      final weather = await WeatherService.getWeather(location);
      modifier += WeatherService.getWeatherMoodModifier(weather);
    }

    return modifier.clamp(-20.0, 20.0);
  }

  /// Get energy modifier based on time of day
  static double getEnergyModifier() {
    final hour = DateTime.now().hour;
    
    // Morning (6-11): High energy
    if (hour >= 6 && hour < 12) return 15.0;
    
    // Afternoon (12-17): Moderate energy
    if (hour >= 12 && hour < 18) return 0.0;
    
    // Evening (18-22): Lower energy
    if (hour >= 18 && hour < 23) return -10.0;
    
    // Night (23-5): Very low energy
    return -20.0;
  }

  static double _getTimeOfDayModifier(int hour) {
    // Morning (6-11): Positive, fresh
    if (hour >= 6 && hour < 12) return 5.0;
    
    // Afternoon (12-17): Neutral
    if (hour >= 12 && hour < 18) return 0.0;
    
    // Evening (18-22): Slightly lower
    if (hour >= 18 && hour < 23) return -3.0;
    
    // Night (23-5): More introspective, lower
    return -8.0;
  }

  static double _getSeasonModifier(int month) {
    // Northern Hemisphere seasons
    // Winter (Dec, Jan, Feb): Lower mood, introspective
    if (month == 12 || month == 1 || month == 2) return -5.0;
    
    // Spring (Mar, Apr, May): Optimistic, energetic
    if (month >= 3 && month <= 5) return 10.0;
    
    // Summer (Jun, Jul, Aug): Positive, energetic
    if (month >= 6 && month <= 8) return 5.0;
    
    // Fall (Sep, Oct, Nov): Neutral, slightly nostalgic
    return 0.0;
  }

  static double _getDayOfWeekModifier(int weekday) {
    // Monday: Slightly lower
    if (weekday == DateTime.monday) return -3.0;
    
    // Friday: More energetic
    if (weekday == DateTime.friday) return 5.0;
    
    // Saturday/Sunday: Relaxed, positive
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) return 3.0;
    
    // Other weekdays: Neutral
    return 0.0;
  }

  /// Get descriptive text for current time context
  static Future<String> getTimeContext({String? location}) async {
    final now = DateTime.now();
    final hour = now.hour;
    
    String timeOfDay;
    if (hour >= 5 && hour < 12) {
      timeOfDay = 'morning';
    } else if (hour >= 12 && hour < 17) {
      timeOfDay = 'afternoon';
    } else if (hour >= 17 && hour < 21) {
      timeOfDay = 'evening';
    } else {
      timeOfDay = 'night';
    }

    final season = _getSeasonName(now.month);
    final dayName = _getDayName(now.weekday);
    
    String context = 'It\'s $timeOfDay on a $dayName in $season.';
    
    // Add weather if available
    if (location != null) {
      final weather = await WeatherService.getWeather(location);
      if (weather != null) {
        context += ' ${WeatherService.getWeatherDescription(weather)}.';
      }
    }

    return context;
  }

  static String _getSeasonName(int month) {
    if (month == 12 || month == 1 || month == 2) return 'winter';
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'summer';
    return 'fall';
  }

  static String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }
}
