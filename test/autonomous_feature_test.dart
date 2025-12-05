import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sable/core/personality/personality_service.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
import 'package:sable/core/ui/feedback_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Mock WebSearchService for caching tests if needed, 
// using simple maps for this test scope.

void main() {
  group('Autonomous Feature Tests', () {
    
    // ============================================
    // 1. PERSONALITY ARCHETYPES
    // ============================================
    test('Personality Service returns correct archetypes', () {
      final realist = PersonalityService.getById('sassy_realist');
      expect(realist.name, equals('The Sassy Realist'));
      expect(realist.traits, contains('Sarcastic'));
      
      final mentor = PersonalityService.getById('gentle_mentor');
      expect(mentor.name, equals('The Gentle Mentor'));
      
      // Default fallback
      final unknown = PersonalityService.getById('unknown_id');
      expect(unknown.id, equals('sassy_realist')); // Default
    });

    test('OnboardingStateService persists personality selection', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = OnboardingStateService(prefs);

      // Default
      expect(service.selectedPersonalityId, equals('sassy_realist'));

      // Set new
      await service.setPersonalityId('devoted_partner');
      expect(service.selectedPersonalityId, equals('devoted_partner'));
      
      // Verify persistence
      expect(prefs.getString('selected_personality_id'), equals('devoted_partner'));
    });

    // ============================================
    // 2. FEEDBACK & SETTINGS
    // ============================================
    test('Feedback Settings persist correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = OnboardingStateService(prefs);

      // Default
      expect(service.hapticsEnabled, isTrue);
      expect(service.soundsEnabled, isTrue);

      // Change
      await service.setHapticsEnabled(false);
      await service.setSoundsEnabled(false);

      expect(service.hapticsEnabled, isFalse);
      expect(service.soundsEnabled, isFalse);
    });

    // ============================================
    // 3. CACHING LOGIC (Daily Update)
    // ============================================
    test('Daily Update Caching Logic (simulated)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = OnboardingStateService(prefs);

      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // Initially empty
      expect(service.getDailyNewsContent(), isNull);

      // Save content
      const content = "Test Daily Briefing Content";
      await service.saveDailyNewsContent(content);

      // Retrieve content
      expect(service.getDailyNewsContent(), equals(content));
      
      // Verify date storage
      expect(prefs.getString('daily_news_date'), equals(today));
    });
    
    // ============================================
    // 4. INTEGRATION: Context Injection Logic
    // ============================================
    test('Context Injection Logic builds correct string', () {
      String? userContext = 'User is in New York.';
      final archetype = PersonalityService.getById('intellectual_analyst');
      
      // Simulate the injection logic from ChatPage
      userContext = (userContext ?? '') + '\n\n[PERSONALITY CORE: ACTIVE]\n';
      userContext += archetype.promptInstruction;
      userContext += '\n[END PERSONALITY CORE]\n';
      
      expect(userContext, contains('[PERSONALITY CORE: ACTIVE]'));
      expect(userContext, contains('You are "The Intellectual Analyst"'));
      expect(userContext, contains('optimization'));
    });
  });
}
