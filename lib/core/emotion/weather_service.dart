import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sable/src/config/app_config.dart';

/// Weather service using OpenWeatherMap API with Google location
class WeatherService {
  // Using Open-Meteo API (free, no key required)
  static const String _baseUrl = 'api.open-meteo.com';
  
  /// Get weather conditions for a location
  /// Returns a WeatherCondition or null if unable to fetch
  static Future<WeatherCondition?> getWeather(String location) async {
    try {
      // First, we need coordinates for the location name
      // We can use the LocationService's geocoding if we had it exposed, 
      // but for now let's assume 'location' might be a city name.
      // Open-Meteo requires lat/long.
      
      // Since we don't have a direct city-to-latlong here without another API call,
      // and we want to be robust, let's rely on the fact that we usually get
      // coordinates from the device GPS in LocationService.
      
      // However, this method takes a String location name.
      // To fix this properly without adding more API keys, we should
      // ideally pass lat/long to this service.
      
      // For now, let's try to geocode the city name using a free geocoding API
      // or just fail gracefully if we can't.
      
      // BETTER APPROACH: Use the device's current position directly if available.
      // But this method signature takes a String.
      
      // Let's use the Open-Meteo Geocoding API to get coords for the city name
      final geoUrl = Uri.https(
        'geocoding-api.open-meteo.com',
        '/v1/search',
        {'name': location, 'count': '1', 'language': 'en', 'format': 'json'},
      );
      
      final geoResponse = await http.get(geoUrl);
      if (geoResponse.statusCode != 200) return null;
      
      final geoData = jsonDecode(geoResponse.body);
      if (geoData['results'] == null || (geoData['results'] as List).isEmpty) return null;
      
      final lat = geoData['results'][0]['latitude'];
      final lon = geoData['results'][0]['longitude'];
      
      // Now fetch weather with daily forecast for high/low
      final url = Uri.https(
        _baseUrl,
        '/v1/forecast',
        {
          'latitude': '$lat',
          'longitude': '$lon',
          'current': 'temperature_2m,weather_code,relative_humidity_2m',
          'daily': 'temperature_2m_max,temperature_2m_min,weather_code',
          'timezone': 'auto',
          'temperature_unit': 'fahrenheit',
        },
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];
        final daily = data['daily'];
        
        final temp = (current['temperature_2m'] as num).toDouble();
        final humidity = (current['relative_humidity_2m'] as num).toInt();
        final code = current['weather_code'] as int;
        
        // Get today's high/low
        double? tempHigh;
        double? tempLow;
        if (daily != null && daily['temperature_2m_max'] != null) {
          tempHigh = (daily['temperature_2m_max'][0] as num?)?.toDouble();
          tempLow = (daily['temperature_2m_min'][0] as num?)?.toDouble();
        }
        
        return WeatherCondition(
          condition: _mapWmoCode(code),
          temperature: temp,
          humidity: humidity,
          description: _getWmoDescription(code),
          tempHigh: tempHigh,
          tempLow: tempLow,
        );
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }


  /// Map WMO Weather Code to WeatherType
  static WeatherType _mapWmoCode(int code) {
    if (code == 0) return WeatherType.clear;
    if (code == 1 || code == 2 || code == 3) return WeatherType.partlyCloudy;
    if (code == 45 || code == 48) return WeatherType.fog;
    if (code >= 51 && code <= 55) return WeatherType.drizzle;
    if (code >= 61 && code <= 65) return WeatherType.rainy;
    if (code >= 71 && code <= 77) return WeatherType.snow;
    if (code >= 80 && code <= 82) return WeatherType.rainy;
    if (code >= 85 && code <= 86) return WeatherType.snow;
    if (code >= 95 && code <= 99) return WeatherType.thunderstorm;
    return WeatherType.unknown;
  }

  static String _getWmoDescription(int code) {
    if (code == 0) return 'Clear sky';
    if (code == 1) return 'Mainly clear';
    if (code == 2) return 'Partly cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45) return 'Fog';
    if (code == 48) return 'Depositing rime fog';
    if (code == 51) return 'Light drizzle';
    if (code == 53) return 'Moderate drizzle';
    if (code == 55) return 'Dense drizzle';
    if (code == 61) return 'Slight rain';
    if (code == 63) return 'Moderate rain';
    if (code == 65) return 'Heavy rain';
    if (code == 71) return 'Slight snow fall';
    if (code == 73) return 'Moderate snow fall';
    if (code == 75) return 'Heavy snow fall';
    if (code == 95) return 'Thunderstorm';
    return 'Unknown';
  }
  
  /// Map OpenWeatherMap condition to our WeatherType
  static WeatherType _mapWeatherType(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return WeatherType.clear;
      case 'clouds':
        return WeatherType.cloudy;
      case 'rain':
      case 'drizzle':
        return WeatherType.rainy;
      case 'thunderstorm':
        return WeatherType.thunderstorm;
      case 'snow':
        return WeatherType.snow;
      case 'mist':
      case 'fog':
        return WeatherType.fog;
      default:
        return WeatherType.unknown;
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
  final double? tempHigh; // Daily high temp
  final double? tempLow; // Daily low temp
  final String? alert; // Weather alert (if any)

  WeatherCondition({
    required this.condition,
    required this.temperature,
    required this.humidity,
    required this.description,
    this.tempHigh,
    this.tempLow,
    this.alert,
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
