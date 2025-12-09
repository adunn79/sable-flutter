import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/aeliana_theme.dart';
import '../../../core/services/recovery_service.dart';

/// Recovery setup screen for onboarding - collects email/phone for PIN reset
class ScreenRecoverySetup extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback? onBack;

  const ScreenRecoverySetup({
    super.key, 
    required this.onComplete,
    this.onBack,
  });

  @override
  State<ScreenRecoverySetup> createState() => _ScreenRecoverySetupState();
}

class _ScreenRecoverySetupState extends State<ScreenRecoverySetup> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _emailVerified = false;
  bool _phoneVerified = false;
  bool _isLoading = false;
  String? _emailError;
  String? _phoneError;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    // Basic phone validation - at least 10 digits
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    return digitsOnly.length >= 10;
  }

  Future<void> _verifyEmail() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter an email');
      return;
    }
    
    if (!_isValidEmail(email)) {
      setState(() => _emailError = 'Please enter a valid email');
      return;
    }

    setState(() {
      _isLoading = true;
      _emailError = null;
    });

    try {
      final recovery = await RecoveryService.create();
      await recovery.setRecoveryEmail(email);
      await recovery.verifyEmail();
      
      setState(() {
        _emailVerified = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _emailError = 'Failed to save email';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyPhone() async {
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      setState(() => _phoneError = 'Please enter a phone number');
      return;
    }
    
    if (!_isValidPhone(phone)) {
      setState(() => _phoneError = 'Please enter a valid phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _phoneError = null;
    });

    try {
      final recovery = await RecoveryService.create();
      await recovery.setRecoveryPhone(phone);
      await recovery.verifyPhone();
      
      setState(() {
        _phoneVerified = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _phoneError = 'Failed to save phone';
        _isLoading = false;
      });
    }
  }

  void _handleContinue() {
    widget.onComplete();
  }

  void _handleSkip() {
    // Show warning dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AelianaColors.carbon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: Colors.orange),
            const SizedBox(width: 12),
            Text(
              'Skip Recovery?',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Without a recovery method, you won\'t be able to reset your PIN if you forget it.\n\nYou can add recovery options later in Settings.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Go Back',
              style: GoogleFonts.inter(color: AelianaColors.plasmaCyan),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onComplete();
            },
            child: Text(
              'Skip Anyway',
              style: GoogleFonts.inter(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyVerified = _emailVerified || _phoneVerified;
    
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back button - always visible and more prominent
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: widget.onBack ?? () => Navigator.maybePop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.arrowLeft, color: Colors.white70, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Back',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Icon - centered
              Center(
                child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AelianaColors.plasmaCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                  child: Icon(
                    LucideIcons.shieldCheck,
                    size: 40,
                    color: AelianaColors.plasmaCyan,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Title - centered
              Center(
                child: Text(
                  'Account Recovery',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                'Your email and phone will only be used to recover your PINs or passwords if you forget them. We will never send marketing or spam.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.white60,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Email field
              _buildInputField(
                controller: _emailController,
                label: 'Email',
                hint: 'your@email.com',
                icon: LucideIcons.mail,
                keyboardType: TextInputType.emailAddress,
                isVerified: _emailVerified,
                error: _emailError,
                onVerify: _verifyEmail,
              ),
              
              const SizedBox(height: 20),
              
              // Phone field
              _buildInputField(
                controller: _phoneController,
                label: 'Phone (Optional)',
                hint: '+1 (555) 123-4567',
                icon: LucideIcons.phone,
                keyboardType: TextInputType.phone,
                isVerified: _phoneVerified,
                error: _phoneError,
                onVerify: _verifyPhone,
                inputFormatters: [_PhoneInputFormatter()],
              ),
              
              const SizedBox(height: 24),
              
              // Info warning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.alertTriangle, color: Colors.orange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Please confirm this information is accurate. You will not be able to recover your account unless we can send password resets to these contacts.',
                        style: GoogleFonts.inter(
                          color: Colors.orange.shade100,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasAnyVerified 
                        ? AelianaColors.plasmaCyan 
                        : Colors.white24,
                    foregroundColor: hasAnyVerified 
                        ? Colors.black 
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    hasAnyVerified ? 'I Have Verified My Email/Phone' : 'Continue Without Recovery',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              if (!hasAnyVerified) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _handleSkip,
                    child: Text(
                      'Skip for now',
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
    required bool isVerified,
    required String? error,
    required VoidCallback onVerify,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AelianaColors.carbon,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: error != null 
                  ? Colors.red.withOpacity(0.5)
                  : isVerified 
                      ? Colors.green.withOpacity(0.5)
                      : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Icon(
                  icon,
                  color: isVerified ? Colors.green : Colors.white38,
                  size: 20,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  enabled: !isVerified,
                  inputFormatters: inputFormatters,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.inter(color: Colors.white24),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              if (isVerified)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(LucideIcons.checkCircle, color: Colors.green, size: 20),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: _isLoading ? null : onVerify,
                    child: Text(
                      'Confirm',
                      style: GoogleFonts.inter(
                        color: AelianaColors.plasmaCyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: GoogleFonts.inter(color: Colors.red, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// Formats phone numbers as +1 (XXX) XXX-XXXX
class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digits
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '');
    }
    
    final buffer = StringBuffer();
    int index = 0;
    
    // Format: +1 (XXX) XXX-XXXX
    if (digitsOnly.length > 0) {
      buffer.write('+1 (');
      final areaCode = digitsOnly.substring(0, digitsOnly.length.clamp(0, 3));
      buffer.write(areaCode);
      index = areaCode.length;
    }
    
    if (digitsOnly.length > 3) {
      buffer.write(') ');
      final prefix = digitsOnly.substring(3, digitsOnly.length.clamp(3, 6));
      buffer.write(prefix);
      index = 3 + prefix.length;
    }
    
    if (digitsOnly.length > 6) {
      buffer.write('-');
      final suffix = digitsOnly.substring(6, digitsOnly.length.clamp(6, 10));
      buffer.write(suffix);
    }
    
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
