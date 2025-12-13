import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sable/core/emotion/location_service.dart';
import 'package:sable/core/emotion/weather_service.dart';
import 'package:sable/src/config/app_config.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Data object representing the user's current physical context
class ExecutionContext {
  final String timeDescription; // "Late Night (3:45 AM)"
  final String? locationDescription; // "San Francisco, CA"
  final String? weatherDescription; // "Raining, 55°F"
  final DateTime timestamp;

  const ExecutionContext({
    required this.timeDescription,
    this.locationDescription,
    this.weatherDescription,
    required this.timestamp,
  });

  /// Returns a natural language string to inject into the AI prompt
  String toNaturalLanguage() {
    final parts = <String>[];
    parts.add('Current time is $timeDescription.');
    
    if (locationDescription != null) {
      parts.add('User is in $locationDescription.');
    }
    
    if (weatherDescription != null) {
      parts.add('Weather is $weatherDescription.');
    }
    
    return parts.join(' ');
  }
}

/// Service to gather context (GPS, Weather, Time)
class ContextEngine {
  
  /// Gathers full context asynchronously.
  /// Fails gracefully if permissions are missing or services fail.
  static Future<ExecutionContext> getContext() async {
    final now = DateTime.now();
    final timeDesc = _getTimeDescription(now);
    
    // Check Privacy Setting
    final prefs = await SharedPreferences.getInstance();

    // Default to ON unless user explicitly disabled it
    final isEnabled = prefs.getBool('context_aware_enabled') ?? true;
    if (!isEnabled) {
      return ExecutionContext(
        timeDescription: timeDesc,
        timestamp: now,
      );
    }
    
    String? locationDesc;
    String? weatherDesc;

    // 1. Get Location
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        // Get City Name
        final apiKey = AppConfig.googleKey;
        if (apiKey.isNotEmpty) {
           locationDesc = await LocationService.getCurrentLocationName(apiKey);
        }
        
        // 2. Get Weather (using coords is faster/more accurate)
        try {
          final weather = await WeatherService.getWeatherByCoords(
            position.latitude, 
            position.longitude
          );
          
          if (weather != null) {
            weatherDesc = '${weather.description}, ${weather.temperature.round()}°F';
          }
        } catch (e) {
          debugPrint('ContextEngine: Weather failed: $e');
        }
      }
    } catch (e) {
      debugPrint('ContextEngine: Location failed: $e');
    }

    return ExecutionContext(
      timeDescription: timeDesc,
      locationDescription: locationDesc,
      weatherDescription: weatherDesc,
      timestamp: now,
    );
  }

  static String _getTimeDescription(DateTime time) {
    final hour = time.hour;
    String period;
    
    if (hour >= 5 && hour < 12) {
      period = 'Morning';
    } else if (hour >= 12 && hour < 17) {
      period = 'Afternoon';
    } else if (hour >= 17 && hour < 21) {
      period = 'Evening';
    } else if (hour >= 21 || hour < 5) {
      period = 'Late Night';
    } else {
      period = 'Night';
    }
    
    final formatted = DateFormat('h:mm a').format(time);
    return '$period ($formatted)';
  }
  
  /// Check if location permission is granted
  static Future<bool> _checkLocationPermission() async {
    try {
      final status = await Permission.location.status;
      return status.isGranted || status.isLimited;
    } catch (e) {
      debugPrint('ContextEngine: Permission check failed: $e');
      return false;
    }
  }
}
