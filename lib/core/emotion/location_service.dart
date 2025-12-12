import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

/// Service for getting user's current location via GPS
class LocationService {
  /// Get current GPS position
  /// Returns null if permission denied or location unavailable
  static Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check permission status - DO NOT re-request if denied
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        // Permission not granted - return null without prompting
        // User must grant permission in onboarding or settings
        return null;
      }

      // Get current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get location as city name using Google Geocoding API
  static Future<String?> getCurrentLocationName(String apiKey) async {
    try {
      final position = await getCurrentPosition();
      if (position == null) return null;

      // Use Google Geocoding API to get city name
      final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$apiKey';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
          // Extract city from address components
          final components = data['results'][0]['address_components'] as List;
          for (var component in components) {
            final types = component['types'] as List;
            if (types.contains('locality')) {
              return component['long_name'];
            }
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
