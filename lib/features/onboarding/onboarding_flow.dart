import 'package:flutter/material.dart';
import 'models/user_profile.dart';
import 'models/avatar_config.dart';
import 'models/permissions_config.dart';
import 'services/onboarding_state_service.dart';
import 'screens/screen_1_calibration.dart';
import 'screens/screen_1.5_permissions.dart';
import 'screens/screen_2_protocol.dart';
import 'screens/screen_3_archetype.dart';
import 'screens/screen_4_customize.dart';
import 'screens/screen_recovery_setup.dart';

class OnboardingFlow extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingFlow({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  UserProfile? _userProfile;
  PermissionsConfig? _permissionsConfig;
  String? _selectedArchetype;
  AvatarConfig? _avatarConfig;
  String? _avatarImageUrl;


  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleScreen1Complete(UserProfile profile) {
    setState(() {
      _userProfile = profile;
    });
    _nextPage();
  }

  void _handlePermissionsComplete(PermissionsConfig config) {
    setState(() {
      _permissionsConfig = config;
    });
    _nextPage();
  }

  void _handleScreen2Complete() {
    _nextPage();
  }

  void _handleScreen3Complete(String archetype) {
    setState(() {
      _selectedArchetype = archetype;
    });
    _nextPage();
  }

  Future<void> _handleScreen4Complete(AvatarConfig config, String imageUrl) async {
    setState(() {
      _avatarConfig = config;
      _avatarImageUrl = imageUrl;
    });

    // Save onboarding completion and user profile
    final stateService = await OnboardingStateService.create();
    
    if (_userProfile != null) {
      // Auto-select voice based on origin if not already selected
      String? voiceToSave = _avatarConfig?.selectedVoiceId;
      if (voiceToSave == null && _avatarConfig?.origin != null) {
        voiceToSave = OnboardingStateService.getDefaultVoiceForOrigin(
          _avatarConfig!.origin,
          _avatarConfig!.gender,
        );
      }
      
      await stateService.saveUserProfile(
        name: _userProfile!.name,
        dob: _userProfile!.dateOfBirth,
        location: _userProfile!.location,
        currentLocation: _userProfile!.currentLocation,
        gender: _userProfile!.genderIdentity,
        voiceId: voiceToSave,
        aiOrigin: _avatarConfig?.origin,
      );
    }
    
    // Save selected archetype/personality
    if (_selectedArchetype != null) {
      await stateService.setArchetypeId(_selectedArchetype!);
    }
    
    await stateService.completeOnboarding();

    // Move to recovery setup screen
    _nextPage();
  }

  void _handleRecoveryComplete() {
    // Go to main app after recovery setup
    widget.onComplete();
  }



  void _nextPage() {
    if (_currentPage < 5) { // 6 screens total (0-5)
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Prevent manual swiping
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: [
          Screen1Calibration(
            onComplete: _handleScreen1Complete,
          ),
          Screen2Protocol(
            onComplete: _handleScreen2Complete,
          ),
          Screen15Permissions(
            onComplete: _handlePermissionsComplete,
          ),
          Screen3Archetype(
            onComplete: _handleScreen3Complete,
          ),
          if (_selectedArchetype != null)
            Screen4Customize(
              archetype: _selectedArchetype!,
              onComplete: _handleScreen4Complete,
            ),
          ScreenRecoverySetup(
            onComplete: _handleRecoveryComplete,
            onBack: _previousPage,
          ),
        ],
      ),
    );
  }
}
