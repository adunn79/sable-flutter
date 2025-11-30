import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sable/src/config/app_config.dart';

/// Weather service using OpenWeatherMap API with Google location
class WeatherService {
  // Using OpenWeatherMap API (free tier)
  // You can get an API key at: https://openweathermap.org/api
  static const String _baseUrl = 'api.openweathermap.org';
  
  /// Get weather conditions for a location
  /// Returns a WeatherCondition or null if unable to fetch
  static Future<WeatherCondition?> getWeather(String location) async {
    try {
      // For now, using a simplified approach with hardcoded location
      // In production, you'd use geocoding with Google Maps API
      
      // Check if we have an API key (would need to add to .env)
      // For now, return null and we'll use time-based modifiers
      // TODO: Add OPENWEATHER_API_KEY to .env file
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Get mood modifier based on weather condition
  static double getWeatherMoodModifier(WeatherCondition? weather) {
    if (weather == null) return 0.0;
    
    switch (weather.condition) {
      case WeatherType.sunny:
      case WeatherType.clear:
        return 10.0; // Sunny boosts mood significantly
        
      case WeatherType.partlyCloudy:
        return 3.0; // Slightly positive
        
      case WeatherType.cloudy:
      case WeatherType.overcast:
        return -5.0; // Clouds lower mood a bit
        
      case WeatherType.rainy:
      case WeatherType.drizzle:
        return -8.0; // Rain is more contemplative/lower mood
        
      case WeatherType.storm:
      case WeatherType.thunderstorm:
        return -12.0; // Storms can be anxiety-inducing
        
      case WeatherType.snow:
        return 5.0; // Snow is novel/exciting for some
        
      case WeatherType.fog:
      case WeatherType.mist:
        return -3.0; // Gloomy but not too bad
        
      default:
        return 0.0;
    }
  }
  
  /// Get descriptive text for current weather
  static String getWeatherDescription(WeatherCondition? weather) {
    if (weather == null) return '';
    
    final temp = weather.temperature.round();
    final condition = _getConditionText(weather.condition);
    
    return 'Weather: $condition, ${temp}°F';
  }
  
  static String _getConditionText(WeatherType type) {
    switch (type) {
      case WeatherType.sunny: return 'Sunny';
      case WeatherType.clear: return 'Clear';
      case WeatherType.partlyCloudy: return 'Partly Cloudy';
      case WeatherType.cloudy: return 'Cloudy';
      case WeatherType.overcast: return 'Overcast';
      case WeatherType.rainy: return 'Rainy';
      case WeatherType.drizzle: return 'Drizzle';
      case WeatherType.storm: return 'Stormy';
      case WeatherType.thunderstorm: return 'Thunderstorm';
      case WeatherType.snow: return 'Snowy';
      case WeatherType.fog: return 'Foggy';
      case WeatherType.mist: return 'Misty';
      default: return 'Unknown';
    }
  }
}

/// Weather condition data
class WeatherCondition {
  final WeatherType condition;
  final double temperature; // in Fahrenheit
  final int humidity; // percentage
  final String description;

  WeatherCondition({
    required this.condition,
    required this.temperature,
    required this.humidity,
    required this.description,
  });
}

/// Types of weather conditions
enum WeatherType {
  sunny,
  clear,
  partlyCloudy,
  cloudy,
  overcast,
  rainy,
  drizzle,
  storm,
  thunderstorm,
  snow,
  fog,
  mist,
  unknown,
}
