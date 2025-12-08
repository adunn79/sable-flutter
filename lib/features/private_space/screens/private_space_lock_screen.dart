import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:local_auth/local_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/aureal_theme.dart';
import '../../../features/subscription/services/subscription_service.dart';
import '../widgets/private_avatar_picker.dart';
import 'private_space_age_gate.dart';
import 'private_avatar_customize_screen.dart';

/// PIN/Biometric lock screen for Private Space
/// Includes decoy mode: 3 wrong attempts → redirect to main chat silently
class PrivateSpaceLockScreen extends StatefulWidget {
  final Widget child;

  const PrivateSpaceLockScreen({super.key, required this.child});

  @override
  State<PrivateSpaceLockScreen> createState() => _PrivateSpaceLockScreenState();
}

class _PrivateSpaceLockScreenState extends State<PrivateSpaceLockScreen> {
  final _localAuth = LocalAuthentication();
  String _enteredPin = '';
  String _savedPin = '';
  bool _isUnlocked = false;
  bool _isSettingPin = false;
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _canUseBiometric = false;
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _error;
  int _wrongAttempts = 0;
  bool _ageConfirmed = false;
  bool _isPremium = false;
  bool _isLoading = true;
  bool _avatarSelected = false;  // NEW: Track if avatar was selected

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check premium status
    final subscriptionService = await SubscriptionService.create();
    _isPremium = subscriptionService.currentTier != SubscriptionTier.free;
    
    // Load Private Space specific settings (separate from Journal)
    _savedPin = prefs.getString('private_space_pin') ?? '';
    _pinEnabled = prefs.getBool('private_space_pin_enabled') ?? false;
    _biometricEnabled = prefs.getBool('private_space_biometric_enabled') ?? false;
    _ageConfirmed = prefs.getBool('private_space_age_confirmed') ?? false;
    _avatarSelected = prefs.getString('private_space_avatar') != null;  // Check if avatar selected

    // Check biometric capability
    try {
      _canUseBiometric = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (e) {
      _canUseBiometric = false;
    }

    setState(() => _isLoading = false);

    // PIN is MANDATORY - only auto-unlock if PIN is already set AND enabled
    // (This handles the case where user disabled PIN in settings after initial setup)
    if (_pinEnabled && _ageConfirmed && _isPremium && _avatarSelected) {
      // PIN exists, try biometric first
      if (_biometricEnabled && _canUseBiometric) {
        await _authenticateWithBiometric();
      }
      // Otherwise, will show PIN entry screen via build()
      return;
    }
    
    // If PIN NOT set yet, build() will show the setup screen
  }

  Future<void> _authenticateWithBiometric() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock Private Space',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (authenticated) {
        setState(() => _isUnlocked = true);
      }
    } catch (e) {
      debugPrint('Biometric auth error: $e');
    }
  }

  void _onKeyPress(String key) {
    HapticFeedback.lightImpact();
    setState(() => _error = null);

    if (key == 'delete') {
      if (_enteredPin.isNotEmpty) {
        setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
      }
      return;
    }

    if (_enteredPin.length < 4) {
      setState(() => _enteredPin += key);
    }

    // Check when 4 digits entered
    if (_enteredPin.length == 4) {
      if (_isSettingPin) {
        if (!_isConfirming) {
          // First entry - save and ask for confirmation
          setState(() {
            _confirmPin = _enteredPin;
            _enteredPin = '';
            _isConfirming = true;
          });
        } else {
          // Confirmation entry
          if (_enteredPin == _confirmPin) {
            _savePin(_enteredPin);
          } else {
            setState(() {
              _error = 'PINs do not match';
              _enteredPin = '';
              _confirmPin = '';
              _isConfirming = false;
            });
          }
        }
      } else {
        // Verifying existing PIN
        if (_enteredPin == _savedPin) {
          setState(() {
            _isUnlocked = true;
            _wrongAttempts = 0;
          });
        } else {
          _wrongAttempts++;
          
          // DECOY MODE: 3 wrong attempts → silently redirect to main chat
          if (_wrongAttempts >= 3) {
            context.go('/chat');
            return;
          }
          
          setState(() {
            _error = 'Incorrect PIN';
            _enteredPin = '';
          });
        }
      }
    }
  }

  Future<void> _savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('private_space_pin', pin);
    await prefs.setBool('private_space_pin_enabled', true);
    await prefs.setBool('private_space_age_confirmed', true);  // Save age confirmation
    setState(() {
      _savedPin = pin;
      _pinEnabled = true;
      _isSettingPin = false;
      // DON'T unlock yet - need avatar selection first!
      // _isUnlocked = true;  <-- REMOVED: Let build flow continue to avatar selection
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ PIN set! Now choose your companion...'),
          backgroundColor: AurealColors.hyperGold.withOpacity(0.9),
        ),
      );
    }
  }

  Future<void> _enableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('private_space_biometric_enabled', true);
    setState(() => _biometricEnabled = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Biometric unlock enabled!'),
          backgroundColor: AurealColors.hyperGold.withOpacity(0.9),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔐 LockScreen build: isLoading=$_isLoading, isPremium=$_isPremium, ageConfirmed=$_ageConfirmed, isUnlocked=$_isUnlocked, isSettingPin=$_isSettingPin, pinEnabled=$_pinEnabled, avatarSelected=$_avatarSelected');
    
    if (_isLoading) {
      debugPrint('🔐 → Showing LOADING');
      return Scaffold(
        backgroundColor: AurealColors.obsidian,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    // Premium check
    if (!_isPremium) {
      debugPrint('🔐 → Showing PAYWALL');
      return _buildPaywall();
    }
    
    // Age gate check
    if (!_ageConfirmed) {
      debugPrint('🔐 → Showing AGE GATE');
      return PrivateSpaceAgeGate(
        onConfirmed: () => setState(() => _ageConfirmed = true),
        onDeclined: () => context.go('/chat'),
      );
    }

    // Unlocked - show content
    if (_isUnlocked) {
      debugPrint('🔐 → UNLOCKED - showing child');
      return widget.child;
    }

    // Setting PIN - show PIN entry screen
    if (_isSettingPin) {
      debugPrint('🔐 → Showing PIN ENTRY (setting)');
      return _buildPinEntryScreen();
    }

    // First time - PIN setup is REQUIRED (can disable in settings later)
    if (!_pinEnabled) {
      debugPrint('🔐 → Showing PIN SETUP');
      return _buildSetupScreen();
    }

    // Avatar selection required after PIN setup
    if (!_avatarSelected) {
      debugPrint('🔐 → Showing AVATAR SELECTION');
      return _buildAvatarOnboarding();
    }

    // Show PIN entry for existing PIN
    debugPrint('🔐 → Showing PIN ENTRY (existing)');
    return _buildPinEntryScreen();
  }

  Widget _buildPaywall() {
    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => context.go('/chat'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎭', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 24),
              Text(
                'Private Space',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Premium Feature',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AurealColors.hyperGold,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AurealColors.carbon,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AurealColors.hyperGold.withOpacity(0.3)),
                ),
                child: Text(
                  'Upgrade to Silver or higher to unlock your private sanctuary with Luna, Dante, and Storm.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AurealColors.hyperGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('View Plans', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetupScreen() {
    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AurealColors.carbon,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AurealColors.hyperGold.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text('🎭', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),
                      Text(
                        'Secure Your Private Space',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Set a PIN to protect your private conversations. This is separate from your Journal PIN.',
                        style: GoogleFonts.inter(
                          color: Colors.grey[400],
                          fontSize: 14,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => setState(() => _isSettingPin = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AurealColors.hyperGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    minimumSize: const Size(200, 50),
                  ),
                  child: Text('Create PIN', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 16),
                Text(
                  'A PIN is required to access Private Space',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarOnboarding() {
    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => context.go('/chat'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('🎭', style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                'Choose Your Companion',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Select who you\'d like to explore this private sanctuary with',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Avatar picker
              PrivateAvatarPicker(
                selectedAvatarId: null,
                onSelect: (avatar) {
                  // Navigate to customization screen BEFORE unlocking
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PrivateAvatarCustomizeScreen(
                        selectedAvatar: avatar,
                        onComplete: () async {
                          // Save avatar and unlock after customization
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('private_space_avatar', avatar.id);
                          
                          if (mounted) {
                            Navigator.pop(context); // Close customize screen
                            setState(() {
                              _avatarSelected = true;
                              _isUnlocked = true;
                            });
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinEntryScreen() {
    final title = _isSettingPin
        ? (_isConfirming ? 'Confirm Your PIN' : 'Create Your PIN')
        : 'Enter PIN';

    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text('🎭', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(_error!, style: GoogleFonts.inter(color: Colors.red, fontSize: 14)),
            const SizedBox(height: 24),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _enteredPin.length ? AurealColors.hyperGold : Colors.grey[700],
                    border: Border.all(color: AurealColors.hyperGold.withOpacity(0.5)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
            _buildNumpad(),
            const Spacer(),

            // Biometric button
            if (_canUseBiometric && _biometricEnabled && !_isSettingPin) ...[
              TextButton.icon(
                onPressed: _authenticateWithBiometric,
                icon: Icon(LucideIcons.fingerprint, color: AurealColors.hyperGold),
                label: Text('Use biometric', style: GoogleFonts.inter(color: AurealColors.hyperGold)),
              ),
              const SizedBox(height: 20),
            ],

            // Enable biometric option
            if (_canUseBiometric && !_biometricEnabled && _pinEnabled && !_isSettingPin) ...[
              TextButton.icon(
                onPressed: _enableBiometric,
                icon: Icon(LucideIcons.fingerprint, color: Colors.grey),
                label: Text('Enable biometric unlock', style: GoogleFonts.inter(color: Colors.grey[400])),
              ),
              const SizedBox(height: 20),
            ],

            // Forgot PIN recovery (only show if PIN is enabled and not setting new PIN)
            if (_pinEnabled && !_isSettingPin && _canUseBiometric) ...[
              TextButton(
                onPressed: _recoverPin,
                child: Text(
                  'Forgot PIN? Verify with biometric',
                  style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  /// PIN recovery using biometric authentication
  Future<void> _recoverPin() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verify your identity to reset PIN',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      
      if (authenticated) {
        // Reset PIN and show setup screen
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('private_space_pin');
        await prefs.setBool('private_space_pin_enabled', false);
        
        setState(() {
          _savedPin = '';
          _pinEnabled = false;
          _isSettingPin = false;
          _enteredPin = '';
          _wrongAttempts = 0;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ PIN reset. Please set a new PIN.'),
              backgroundColor: AurealColors.hyperGold.withOpacity(0.9),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Biometric recovery error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Biometric verification failed. Please try again.'),
            backgroundColor: Colors.red.withOpacity(0.9),
          ),
        );
      }
    }
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_buildKey('1'), _buildKey('2'), _buildKey('3')],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_buildKey('4'), _buildKey('5'), _buildKey('6')],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_buildKey('7'), _buildKey('8'), _buildKey('9')],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            _buildKey('0'),
            _buildDeleteKey(),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String digit) {
    return GestureDetector(
      onTap: () => _onKeyPress(digit),
      child: Container(
        width: 70,
        height: 70,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AurealColors.carbon,
          border: Border.all(color: AurealColors.hyperGold.withOpacity(0.2)),
        ),
        child: Center(
          child: Text(
            digit,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return GestureDetector(
      onTap: () => _onKeyPress('delete'),
      child: SizedBox(
        width: 80,
        height: 70,
        child: Center(
          child: Icon(LucideIcons.delete, color: Colors.white.withOpacity(0.5), size: 24),
        ),
      ),
    );
  }
}
