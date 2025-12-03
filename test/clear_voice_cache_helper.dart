import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple script to clear voice cache
/// Run this in the Flutter app's main() during development
Future<void> clearVoiceCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('elevenlabs_voices_cache');
  await prefs.remove('elevenlabs_voices_cache_timestamp');
  debugPrint('✅ Voice cache cleared - app will re-fetch voices on next load');
}
