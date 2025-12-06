import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:local_auth/local_auth.dart';

/// PIN lock screen for journal access
class JournalLockScreen extends StatefulWidget {
  final Widget child; // The protected journal screen
  
  const JournalLockScreen({super.key, required this.child});

  @override
  State<JournalLockScreen> createState() => _JournalLockScreenState();
}

class _JournalLockScreenState extends State<JournalLockScreen> {
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
  bool _wasPrompted = false;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _savedPin = prefs.getString('journal_pin') ?? '';
    _pinEnabled = prefs.getBool('journal_pin_enabled') ?? false;
    _biometricEnabled = prefs.getBool('journal_biometric_enabled') ?? false;
    _wasPrompted = prefs.getBool('journal_pin_prompted') ?? false;
    
    // Check if device supports biometrics
    try {
      _canUseBiometric = await _localAuth.canCheckBiometrics || 
                         await _localAuth.isDeviceSupported();
    } catch (e) {
      _canUseBiometric = false;
    }
    
    setState(() {});
    
    // If PIN not enabled, go straight to journal
    if (!_pinEnabled) {
      setState(() => _isUnlocked = true);
      return;
    }
    
    // Try biometric first if enabled
    if (_biometricEnabled && _canUseBiometric) {
      await _authenticateWithBiometric();
    }
  }
  
  Future<void> _authenticateWithBiometric() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock your journal',
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
    await prefs.setString('journal_pin', pin);
    await prefs.setBool('journal_pin_enabled', true);
    setState(() {
      _savedPin = pin;
      _pinEnabled = true;
      _isSettingPin = false;
      _isUnlocked = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Journal PIN set!')),
    );
  }
  
  Future<void> _enableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('journal_biometric_enabled', true);
    setState(() => _biometricEnabled = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Biometric unlock enabled!')),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Show journal directly if unlocked or PIN not enabled
    if (_isUnlocked) {
      return widget.child;
    }
    
    // Show PIN setup prompt only if PIN not set AND not previously prompted
    if (!_pinEnabled && !_wasPrompted) {
      return _buildSetupScreen();
    }
    
    // Show PIN entry screen
    return _buildPinEntryScreen();
  }
  
  Widget _buildSetupScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // AI avatar-style prompt
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(LucideIcons.shieldCheck, size: 48, color: Colors.purple.withOpacity(0.8)),
                      const SizedBox(height: 16),
                      const Text(
                        '🔐 Keep Your Journal Private?',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Would you like to add a PIN to protect your journal? Only you will be able to access your entries.',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You can change this anytime in Settings > Journal Privacy',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
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
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    minimumSize: const Size(200, 50),
                  ),
                  child: const Text('Yes, Set a PIN', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
                const SizedBox(height: 12),
                // No button
                OutlinedButton(
                  onPressed: () async {
                    // Mark as prompted so we don't ask again
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('journal_pin_prompted', true);
                    setState(() => _isUnlocked = true);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    minimumSize: const Size(200, 50),
                  ),
                  child: Text('No Thanks', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
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
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(LucideIcons.lock, size: 48, color: Colors.purple.withOpacity(0.7)),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
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
                  color: i < _enteredPin.length ? Colors.purple : Colors.grey[700],
                  border: Border.all(color: Colors.purple.withOpacity(0.5)),
                ),
              )),
            ),
            
            const SizedBox(height: 40),
            
            // Numpad
            _buildNumpad(),
            
            const Spacer(),
            
            // Biometric button (if available) when not setting PIN
            if (_canUseBiometric && _biometricEnabled && !_isSettingPin) ...[
              TextButton.icon(
                onPressed: _authenticateWithBiometric,
                icon: const Icon(LucideIcons.fingerprint, color: Colors.purple),
                label: const Text('Use biometric', style: TextStyle(color: Colors.purple)),
              ),
              const SizedBox(height: 20),
            ],
            
            // Enable biometric option after PIN is set
            if (_canUseBiometric && !_biometricEnabled && _pinEnabled && _isSettingPin == false) ...[
              TextButton.icon(
                onPressed: _enableBiometric,
                icon: const Icon(LucideIcons.fingerprint, color: Colors.grey),
                label: Text('Enable biometric unlock', style: TextStyle(color: Colors.grey[400])),
              ),
              const SizedBox(height: 20),
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
          children: [
            _buildKey('1'),
            _buildKey('2'),
            _buildKey('3'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey('4'),
            _buildKey('5'),
            _buildKey('6'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey('7'),
            _buildKey('8'),
            _buildKey('9'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80), // Empty space
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
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300),
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
