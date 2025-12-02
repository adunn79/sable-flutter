import 'package:flutter_test/flutter_test.dart';
import 'package:sable/core/voice/voice_service.dart';

/// Manual test to verify voice list contains ONLY 6 ElevenLabs voices
void main() {
  test('VoiceService should return only 6 ElevenLabs voices', () async {
    final voiceService = VoiceService();
    await voiceService.initialize();
    
    // Get curated voices
    final voices = await voiceService.getCuratedVoices();
    
    // Verify count
    expect(voices.length, 6, reason: 'Should have exactly 6 voices');
    
    // Verify names
    final expectedNames = [
      'Josh (Male)',
      'Antoni (Male)',
      'Rachel (Female)',
      'Bella (Female)',
      'Adam (Neutral)',
      'Mimi (Neutral)',
    ];
    
    final actualNames = voices.map((v) => v['name']).toList();
    expect(actualNames, containsAll(expectedNames), 
      reason: 'Should contain all 6 ElevenLabs voices');
    
    // Verify NO system voice names
    final systemVoiceNames = ['Samantha', 'Albert', 'Daniel', 'Karen', 'Junior'];
    for (final voice in voices) {
      final name = voice['name'] ?? '';
      for (final systemName in systemVoiceNames) {
        expect(name.contains(systemName), false,
          reason: 'Should NOT contain system voice: $systemName');
      }
    }
    
    // Verify engine
    expect(voiceService.currentEngine, 'eleven_labs',
      reason: 'Engine should be set to eleven_labs');
    
    print('✅ All voice list checks passed!');
    print('Voice count: ${voices.length}');
    print('Voices: ${voices.map((v) => v['name']).join(', ')}');
  });
}
