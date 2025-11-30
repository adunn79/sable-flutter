import 'package:flutter_test/flutter_test.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
import 'package:sable/src/config/app_config.dart';

/// Manual test to save user data directly to SharedPreferences
void main() {
  test('Manual Save User Data', () async {
    await AppConfig.initialize();
    
    final service = await OnboardingStateService.create();
    
    // Save test user data
    await service.saveUserProfile(
      name: 'Andrew',
      dob: DateTime(1990, 1, 1), // Change to your actual birth date
      location: 'San Francisco, CA', // Change to your actual location
      gender: 'Male', // Change to your actual gender
    );
    
    // Verify it was saved
    print('Saved user data:');
    print('Name: ${service.userName}');
    print('DOB: ${service.userDob}');
    print('Location: ${service.userLocation}');
    print('Gender: ${service.userGender}');
    
    expect(service.userName, 'Andrew');
  });
}
