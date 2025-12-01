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

import 'package:sable/features/certificate/models/certificate_data.dart';
import 'package:sable/features/certificate/screens/certificate_screen.dart';
import 'package:sable/features/certificate/services/genesis_service.dart';

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
  CertificateData? _certificateData;

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

    // Generate Certificate Data
    if (_userProfile != null) {
      final certificateData = await GenesisService.generateCertificate(
        _userProfile!,
        imageUrl,
      );
      
      setState(() {
        _certificateData = certificateData;
      });
    }

    // Save onboarding completion and user profile
    final stateService = await OnboardingStateService.create();
    
    if (_userProfile != null) {
      await stateService.saveUserProfile(
        name: _userProfile!.name,
        dob: _userProfile!.dateOfBirth,
        location: _userProfile!.location,
        currentLocation: _userProfile!.currentLocation,
        gender: _userProfile!.genderIdentity,
        voiceId: _userProfile!.selectedVoiceId,
      );
    }
    
    await stateService.completeOnboarding();

    // TODO: Save permissions and avatar config if needed

    _nextPage();
  }

  void _handleCertificateComplete() {
    widget.onComplete();
  }

  void _nextPage() {
    if (_currentPage < 5) { // Increased to 5 for certificate screen
      _pageController.nextPage(
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
          if (_certificateData != null)
             CertificateScreen(
               data: _certificateData!,
               onComplete: _handleCertificateComplete,
             ),
        ],
      ),
    );
  }
}
