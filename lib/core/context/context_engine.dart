import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:battery_plus/battery_plus.dart';
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
  
  // NEW: Battery & Device State
  final int? batteryLevel; // 0-100
  final BatteryState? batteryState; // charging, discharging, full, etc.
  final bool? isLowPowerMode;
  final String? nowPlayingTrack; // Current music

  const ExecutionContext({
    required this.timeDescription,
    this.locationDescription,
    this.weatherDescription,
    required this.timestamp,
    this.batteryLevel,
    this.batteryState,
    this.isLowPowerMode,
    this.nowPlayingTrack,
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
    
    // Battery context - helps AI understand user's situation
    if (batteryLevel != null) {
      String batteryDesc;
      if (batteryLevel! <= 10) {
        batteryDesc = 'critically low ($batteryLevel%)';
      } else if (batteryLevel! <= 20) {
        batteryDesc = 'low ($batteryLevel%)';
      } else if (batteryLevel! >= 95) {
        batteryDesc = 'fully charged';
      } else {
        batteryDesc = 'at $batteryLevel%';
      }
      
      if (batteryState == BatteryState.charging) {
        parts.add('Device is charging, battery $batteryDesc.');
      } else if (batteryLevel! <= 20) {
        parts.add('Device battery is $batteryDesc - consider being concise.');
      }
    }
    
    if (isLowPowerMode == true) {
      parts.add('Device is in low power mode.');
    }
    
    if (nowPlayingTrack != null && nowPlayingTrack!.isNotEmpty) {
      parts.add('User is listening to: $nowPlayingTrack.');
    }
    
    return parts.join(' ');
  }
  
  /// Get a short status for UI display
  String get batteryStatus {
    if (batteryLevel == null) return '';
    final charging = batteryState == BatteryState.charging ? '⚡' : '';
    return '$charging${batteryLevel}%';
  }
}

/// Service to gather context (GPS, Weather, Time, Battery)
class ContextEngine {
  static final Battery _battery = Battery();
  
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
    int? batteryLevel;
    BatteryState? batteryState;
    bool? isLowPowerMode;

    // 1. Get Battery State (fast, no permissions needed)
    try {
      batteryLevel = await _battery.batteryLevel;
      batteryState = await _battery.batteryState;
      isLowPowerMode = await _battery.isInBatterySaveMode;
    } catch (e) {
      debugPrint('ContextEngine: Battery check failed: $e');
    }

    // 2. Get Location
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        // Get City Name
        final apiKey = AppConfig.googleKey;
        if (apiKey.isNotEmpty) {
           locationDesc = await LocationService.getCurrentLocationName(apiKey);
        }
        
        // 3. Get Weather (using coords is faster/more accurate)
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
      batteryLevel: batteryLevel,
      batteryState: batteryState,
      isLowPowerMode: isLowPowerMode,
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

