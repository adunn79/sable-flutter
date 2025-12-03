import 'package:flutter_test/flutter_test.dart';
import 'package:sable/core/voice/elevenlabs_api_service.dart';

/// Quick script to clear the ElevenLabs voice cache
/// Run with: flutter test test/clear_voice_cache.dart
void main() {
  test('Clear voice cache', () async {
    final service = ElevenLabsApiService();
    await service.clearCache();
    print('✅ Voice cache cleared successfully');
    print('The app will re-fetch voices from the API on next load');
  });
}
