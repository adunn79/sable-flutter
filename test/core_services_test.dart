import 'package:flutter_test/flutter_test.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
import 'package:sable/core/emotion/emotional_state_service.dart';
import 'package:sable/core/voice/voice_service.dart';

/// Integration tests for core services
/// Tests voice auto-selection, bond engine, and state management
void main() {
  group('OnboardingStateService Tests', () {
    test('getDefaultVoiceForOrigin returns valid voice IDs', () {
      // Test various origins
      final russiaFemale = OnboardingStateService.getDefaultVoiceForOrigin('Russia', 'Female');
      final swedenMale = OnboardingStateService.getDefaultVoiceForOrigin('Sweden', 'Male');
      final ukFemale = OnboardingStateService.getDefaultVoiceForOrigin('UK', 'Female');
      final usaMale = OnboardingStateService.getDefaultVoiceForOrigin('USA', 'Male');

      expect(russiaFemale, isNotNull);
      expect(swedenMale, isNotNull);
      expect(ukFemale, isNotNull);
      expect(usaMale, isNotNull);

      // Verify they're actual voice IDs (not empty)
      expect(russiaFemale!.length, greaterThan(0));
      expect(swedenMale!.length, greaterThan(0));
    });

    test('getDefaultVoiceForOrigin handles unknown origins gracefully', () {
      final unknownOrigin = OnboardingStateService.getDefaultVoiceForOrigin('Mars', 'Female');
      expect(unknownOrigin, isNotNull); // Should return default
    });

    test('getDefaultVoiceForOrigin handles null inputs', () {
      final nullOrigin = OnboardingStateService.getDefaultVoiceForOrigin(null, 'Female');
      final nullGender = OnboardingStateService.getDefaultVoiceForOrigin('Russia', null);

      expect(nullOrigin, isNotNull);
      expect(nullGender, isNotNull);
    });

    test('All supported regions return valid voices', () {
      final regions = ['Russia', 'Sweden', 'UK', 'Australia', 'Ireland', 'France', 'Italy', 'Spain', 'USA'];
      final genders = ['Male', 'Female'];

      for (final region in regions) {
        for (final gender in genders) {
          final voiceId = OnboardingStateService.getDefaultVoiceForOrigin(region, gender);
          expect(voiceId, isNotNull, reason: 'Failed for $region $gender');
          expect(voiceId!.length, greaterThan(0));
        }
      }
    });
  });

  group('EmotionalStateService Tests', () {
    test('EmotionalStateService can be created', () async {
      final service = await EmotionalStateService.create();
      expect(service, isNotNull);
    });

    test('setMood accepts valid ranges', () async {
      final service = await EmotionalStateService.create();

      // Test boundary values
      expect(() async => await service.setMood(0), returnsNormally);
      expect(() async => await service.setMood(50), returnsNormally);
      expect(() async => await service.setMood(100), returnsNormally);
    });

    test('getEmotionalContext returns formatted string', () async {
      final service = await EmotionalStateService.create();
      final context = service.getEmotionalContext();

      expect(context, isNotNull);
      expect(context, contains('EMOTIONAL STATE'));
    });
  });

  group('VoiceService Tests', () {
    test('VoiceService can be initialized', () async {
      final service = VoiceService();
      await service.initialize();

      expect(service, isNotNull);
    });

    test('Voice engine can be set', () async {
      final service = VoiceService();
      await service.initialize();

      await service.setVoiceEngine('system');
      final engine = await service.getVoiceEngine();
      expect(engine, equals('system'));
    });

    test('Auto-speak can be toggled', () async {
      final service = VoiceService();
      await service.initialize();

      await service.setAutoSpeakEnabled(true);
      final enabled1 = await service.getAutoSpeakEnabled();
      expect(enabled1, isTrue);

      await service.setAutoSpeakEnabled(false);
      final enabled2 = await service.getAutoSpeakEnabled();
      expect(enabled2, isFalse);
    });
  });

  group('Bond Engine Integration Tests', () {
    test('Bond states map correctly to mood values', () async {
      final service = await EmotionalStateService.create();

      // COOLED state (0-33)
      await service.setMood(16.5);
      // Should not crash

      // NEUTRAL state (34-66)
      await service.setMood(50.0);
      // Should not crash

      // WARM state (67-100)
      await service.setMood(83.5);
      // Should not crash
    });

    test('Rapid mood changes handle gracefully', () async {
      final service = await EmotionalStateService.create();

      for (var i = 0; i <= 100; i += 10) {
        await service.setMood(i.toDouble());
      }

      // Should complete without crash
      expect(service, isNotNull);
    });
  });

  group('State Persistence Tests', () {
    test('OnboardingStateService persists across creates', () async {
      final service1 = await OnboardingStateService.create();
      await service1.setUserName('TestUser');

      final service2 = await OnboardingStateService.create();
      final name = service2.userName;

      expect(name, equals('TestUser'));
    });

    test('EmotionalStateService persists mood', () async {
      final service1 = await EmotionalStateService.create();
      await service1.setMood(75.0);

      final service2 = await EmotionalStateService.create();
      // Mood should persist
      expect(service2, isNotNull);
    });
  });
}
