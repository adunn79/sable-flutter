import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sable/core/emotion/emotional_state_service.dart';

void main() {
  test('Reset Emotional State', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = EmotionalStateService(prefs);
    
    await service.resetEmotionalState();
    
    // Set to neutral/good baseline
    await service.setMood(60.0);
    await service.updateEnergy(0); // Reset energy to baseline
    
    debugPrint('✅ Emotional state reset to Neutral (60.0)');
  });
}
