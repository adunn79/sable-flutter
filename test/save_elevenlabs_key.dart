import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Script to save ElevenLabs API key to SharedPreferences
/// Run with: flutter run test/save_elevenlabs_key.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  const apiKey = 'efc8679e5462be20df0d65399a8e511a6017106f5137a915';
  
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('eleven_labs_api_key', apiKey);
  await prefs.setString('voice_engine_type', 'eleven_labs');
  
  print('✅ ElevenLabs API key saved to SharedPreferences');
  print('✅ Voice engine set to: eleven_labs');
  print('');
  print('Key saved: ${apiKey.substring(0, 10)}...');
}
