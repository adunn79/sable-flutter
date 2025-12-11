import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:local_auth/local_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/recovery_service.dart';
/// PIN lock screen for Vital Balance access
/// Protects sensitive health data with password/biometric authentication
class VitalBalanceLockScreen extends StatefulWidget {
  final Widget child; // The protected Vital Balance screen
  
  const VitalBalanceLockScreen({super.key, required this.child});

  @override
  State<VitalBalanceLockScreen> createState() => _VitalBalanceLockScreenState();
}

class _VitalBalanceLockScreenState extends State<VitalBalanceLockScreen> {
  final _localAuth = LocalAuthentication();
  
  // Track disposal to prevent setState after dispose
  bool _disposed = false;
  
  // Soothing color palette (matching Vital Balance)
  static const Color _backgroundStart = Color(0xFF0D1B2A);
  static const Color _accentTeal = Color(0xFF5DD9C1);
  static const Color _accentLavender = Color(0xFFB8A9D9);
  
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
  bool _wasPrompted = false;
  
  // Preference keys for Vital Balance (separate from Journal)
  static const _keyPin = 'vital_balance_pin';
  static const _keyPinEnabled = 'vital_balance_pin_enabled';
  static const _keyBiometricEnabled = 'vital_balance_biometric_enabled';
  static const _keyPrompted = 'vital_balance_pin_prompted';
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    
    _savedPin = prefs.getString(_keyPin) ?? '';
    _pinEnabled = prefs.getBool(_keyPinEnabled) ?? false;
    _biometricEnabled = prefs.getBool(_keyBiometricEnabled) ?? false;
    _wasPrompted = prefs.getBool(_keyPrompted) ?? false;
    
    // Check if device supports biometrics
    try {
      if (!_disposed) {
        _canUseBiometric = await _localAuth.canCheckBiometrics || 
                           await _localAuth.isDeviceSupported();
      }
    } catch (e) {
      _canUseBiometric = false;
    }
    
    if (_disposed || !mounted) return;
    setState(() {});
    
    // If PIN not enabled, go straight to content
    if (!_pinEnabled) {
      if (!_disposed && mounted) setState(() => _isUnlocked = true);
      return;
    }
    
    // Don't auto-trigger biometric on init - let user tap button instead
    // This prevents crashes when navigating away during auth
  }
  
  Future<void> _authenticateWithBiometric() async {
    if (_disposed) return;
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock your Vital Balance',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (!_disposed && authenticated && mounted) {
        setState(() => _isUnlocked = true);
      }
    } catch (e) {
      // Ignore errors if widget was disposed during auth
      if (!_disposed) {
        debugPrint('Biometric auth error: $e');
      }
    }
  }
  
  void _onKeyPress(String key) {
    if (_disposed) return;
    HapticFeedback.lightImpact();
    if (!mounted) return;
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
          setState(() {
            _confirmPin = _enteredPin;
            _enteredPin = '';
            _isConfirming = true;
          });
        } else {
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
        if (_enteredPin == _savedPin) {
          setState(() => _isUnlocked = true);
        } else {
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
    if (_disposed) return;
    await prefs.setString(_keyPin, pin);
    await prefs.setBool(_keyPinEnabled, true);
    if (_disposed || !mounted) return;
    setState(() {
      _savedPin = pin;
      _pinEnabled = true;
      _isSettingPin = false;
      _isUnlocked = true;
    });
    if (!_disposed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Vital Balance PIN set!')),
      );
    }
  }
  
  Future<void> _enableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    await prefs.setBool(_keyBiometricEnabled, true);
    if (_disposed || !mounted) return;
    setState(() => _biometricEnabled = true);
    if (!_disposed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Biometric unlock enabled!')),
      );
    }
  }
  
  Future<void> _showForgotPinDialog() async {
    final recovery = await RecoveryService.create();
    
    if (!recovery.hasVerifiedRecoveryMethod) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: Colors.orange),
              const SizedBox(width: 12),
              Text('No Recovery Set', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'You haven\'t set up a recovery method. Without it, you cannot reset your PIN.\n\nYou can add recovery options in Settings after resetting the app.',
            style: GoogleFonts.inter(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: GoogleFonts.inter(color: _accentTeal)),
            ),
          ],
        ),
      );
      return;
    }
    
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    
    if (!mounted) return;
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(LucideIcons.shieldCheck, color: _accentTeal),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Verify Identity', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your recovery email or phone to reset your PIN:',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (recovery.isEmailVerified) ...[
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Email',
                  hintStyle: GoogleFonts.inter(color: Colors.white38),
                  prefixIcon: Icon(LucideIcons.mail, color: _accentTeal.withOpacity(0.7)),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (recovery.isPhoneVerified) ...[
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Phone',
                  hintStyle: GoogleFonts.inter(color: Colors.white38),
                  prefixIcon: Icon(LucideIcons.phone, color: _accentTeal.withOpacity(0.7)),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final isVerified = recovery.verifyIdentity(
                email: emailController.text.trim().isNotEmpty ? emailController.text.trim() : null,
                phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
              );
              Navigator.pop(context, isVerified);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentTeal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Verify', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (verified == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPin);
      await prefs.setBool(_keyPinEnabled, false);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ PIN reset! Set a new PIN to protect your health data.')),
      );
      
      setState(() {
        _savedPin = '';
        _pinEnabled = false;
        _enteredPin = '';
        _isSettingPin = true;
      });
    } else if (verified == false) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Verification failed. Email or phone does not match.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isUnlocked) {
      return widget.child;
    }
    
    if (!_pinEnabled && !_wasPrompted) {
      return _buildSetupScreen();
    }
    
    return _buildPinEntryScreen();
  }
  
  Widget _buildSetupScreen() {
    return Scaffold(
      backgroundColor: _backgroundStart,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Health-focused prompt
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_accentTeal.withOpacity(0.1), _accentLavender.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accentTeal.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(LucideIcons.shieldCheck, size: 48, color: _accentTeal),
                      const SizedBox(height: 16),
                      Text(
                        '🔐 Protect Your Health Data?',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Would you like to add a PIN to protect your vital statistics and health conversations? Your wellness data stays private.',
                        style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You can change this anytime in Settings',
                        style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Yes button
                ElevatedButton(
                  onPressed: () => setState(() => _isSettingPin = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentTeal,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    minimumSize: const Size(200, 50),
                  ),
                  child: Text('Yes, Set a PIN', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 12),
                // No button
                OutlinedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(_keyPrompted, true);
                    setState(() => _isUnlocked = true);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    minimumSize: const Size(200, 50),
                  ),
                  child: Text('No Thanks', style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 16)),
                ),
              ],
            ),
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
      backgroundColor: _backgroundStart,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(LucideIcons.heartPulse, size: 48, color: _accentTeal),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14)),
            const SizedBox(height: 24),
            
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _enteredPin.length ? _accentTeal : Colors.grey[700],
                  border: Border.all(color: _accentTeal.withOpacity(0.5)),
                ),
              )),
            ),
            
            const SizedBox(height: 40),
            
            // Numpad
            _buildNumpad(),
            
            const Spacer(),
            
            // Biometric button
            if (_canUseBiometric && _biometricEnabled && !_isSettingPin) ...[
              TextButton.icon(
                onPressed: _authenticateWithBiometric,
                icon: Icon(LucideIcons.fingerprint, color: _accentTeal),
                label: Text('Use biometric', style: TextStyle(color: _accentTeal)),
              ),
              const SizedBox(height: 20),
            ],
            
            // Enable biometric option
            if (_canUseBiometric && !_biometricEnabled && _pinEnabled && _isSettingPin == false) ...[
              TextButton.icon(
                onPressed: _enableBiometric,
                icon: const Icon(LucideIcons.fingerprint, color: Colors.grey),
                label: Text('Enable biometric unlock', style: TextStyle(color: Colors.grey[400])),
              ),
              const SizedBox(height: 8),
            ],
            
            // Forgot PIN link
            if (!_isSettingPin && _pinEnabled) ...[
              TextButton(
                onPressed: _showForgotPinDialog,
                child: Text(
                  'Forgot PIN?',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
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
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: _accentTeal.withOpacity(0.2)),
        ),
        child: Center(
          child: Text(
            digit,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300),
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
