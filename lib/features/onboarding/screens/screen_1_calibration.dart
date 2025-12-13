import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/ui/safe_snackbar.dart';
import '../models/user_profile.dart';

class Screen1Calibration extends StatefulWidget {
  final Function(UserProfile) onComplete;

  const Screen1Calibration({
    super.key,
    required this.onComplete,
  });

  @override
  State<Screen1Calibration> createState() => _Screen1CalibrationState();
}

class _Screen1CalibrationState extends State<Screen1Calibration> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  final _nameFocusNode = FocusNode();
  DateTime? _selectedDate;
  String? _genderIdentity;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    // iPad keyboard fix: explicitly request focus after frame render
    // This is more reliable than autofocus on iOS/iPadOS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_nameFocusNode.hasFocus) {
          _nameFocusNode.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }



  /// Parse date from text input (MM/DD/YY or MM/DD/YYYY format)
  void _parseDate(String text) {
    setState(() {
      _dateError = null;
      _selectedDate = null;
    });
    
    if (text.isEmpty) return;
    
    // Remove any non-digit characters and reformat
    final cleanText = text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Try to parse different formats
    DateTime? parsed;
    
    if (cleanText.length >= 6) {
      try {
        final month = int.parse(cleanText.substring(0, 2));
        final day = int.parse(cleanText.substring(2, 4));
        int year;
        
        if (cleanText.length >= 8) {
          // Full year: MMDDYYYY
          year = int.parse(cleanText.substring(4, 8));
        } else {
          // Short year: MMDDYY
          year = int.parse(cleanText.substring(4, 6));
          // Assume 1900s for years > 30, 2000s for years <= 30
          year = year > 30 ? 1900 + year : 2000 + year;
        }
        
        // Validate ranges
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31 && year >= 1920 && year <= DateTime.now().year) {
          parsed = DateTime(year, month, day);
          
          // Verify it's not in the future
          if (parsed.isAfter(DateTime.now())) {
            setState(() => _dateError = 'Date cannot be in the future');
            return;
          }
          
          setState(() {
            _selectedDate = parsed;
            _dateError = null;
          });
        } else {
          setState(() => _dateError = 'Invalid date');
        }
      } catch (e) {
        setState(() => _dateError = 'Invalid date format');
      }
    }
  }
  
  /// Format date controller text with slashes as user types
  void _formatDateInput(String text) {
    // Remove all non-digits
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    
    String formatted = '';
    for (int i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) formatted += '/';
      formatted += digits[i];
    }
    
    // Update controller if different
    if (formatted != text) {
      _dateController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    
    // Try to parse the date
    _parseDate(formatted);
  }

  void _handleContinue() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedDate == null) {
        SafeSnackBar.show(
          context,
          SnackBar(
            content: Text('Please select your date of birth',
                style: GoogleFonts.inter()),
            backgroundColor: AelianaColors.plasmaCyan,
          ),
        );
        return;
      }

      final profile = UserProfile(
        name: _nameController.text.trim(),
        dateOfBirth: _selectedDate!,
        location: '', // Removed birthplace field
        currentLocation: null, // Will be set by GPS later
        genderIdentity: _genderIdentity,
        selectedVoiceId: null, // Will be set on avatar screen
      );

      // Check age requirement
      if (!profile.isOver17()) {
        Navigator.of(context).pushReplacementNamed('/access-denied');
        return;
      }

      widget.onComplete(profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Title
                Center(
                  child: Text(
                    'THE CALIBRATION',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AelianaColors.plasmaCyan,
                      letterSpacing: 2,
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),

                const SizedBox(height: 12),

                Text(
                  'This helps me get to know you right away. It\'s part of our bonding—understanding who you are and how to connect with you.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AelianaColors.ghost,
                    height: 1.5,
                  ),
                ).animate(delay: 200.ms).fadeIn(duration: 600.ms),

                const SizedBox(height: 48),

                // Name Field
                Text(
                  'What do they call you?',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AelianaColors.ghost,
                    letterSpacing: 1,
                  ),
                ).animate(delay: 400.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 8),

                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  autofocus: true,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  enableInteractiveSelection: true,
                  style: GoogleFonts.inter(color: AelianaColors.stardust),
                  decoration: const InputDecoration(
                    hintText: 'Enter your name',
                  ),
                  onTap: () {
                    // Explicitly request focus for iOS 26 keyboard
                    if (!_nameFocusNode.hasFocus) {
                      _nameFocusNode.requestFocus();
                    }
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ).animate(delay: 500.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 32),

                // Date of Birth
                Row(
                  children: [
                    Text(
                      'When did you begin?',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AelianaColors.ghost,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AelianaColors.carbon,
                            title: Text(
                              'Date of Birth',
                              style: GoogleFonts.spaceGrotesk(
                                color: AelianaColors.plasmaCyan,
                              ),
                            ),
                            content: Text(
                              'What is your date of birth',
                              style: GoogleFonts.inter(
                                color: AelianaColors.stardust,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Got it',
                                  style: GoogleFonts.inter(
                                    color: AelianaColors.plasmaCyan,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AelianaColors.plasmaCyan.withOpacity(0.6),
                      ),
                    ),
                  ],
                ).animate(delay: 800.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 8),

                // Simple date text field (MM/DD/YYYY)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _dateController,
                      keyboardType: TextInputType.number,
                      onChanged: _formatDateInput,
                      style: GoogleFonts.inter(
                        color: AelianaColors.stardust,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'MM/DD/YYYY',
                        hintStyle: GoogleFonts.inter(
                          color: AelianaColors.ghost.withOpacity(0.5),
                        ),
                        filled: true,
                        fillColor: AelianaColors.carbon,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _selectedDate != null
                                ? AelianaColors.plasmaCyan
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AelianaColors.plasmaCyan,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        suffixIcon: _selectedDate != null
                            ? const Icon(
                                Icons.check_circle,
                                color: AelianaColors.plasmaCyan,
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                    if (_dateError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _dateError!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ).animate(delay: 900.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 32),

                // Gender (Optional)
                Row(
                  children: [
                    Text(
                      'How do you identify? (Optional)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AelianaColors.ghost,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AelianaColors.carbon,
                            title: Text(
                              'Identity',
                              style: GoogleFonts.spaceGrotesk(
                                color: AelianaColors.plasmaCyan,
                              ),
                            ),
                            content: Text(
                              'This helps the avatar address you correctly. It is completely optional.',
                              style: GoogleFonts.inter(
                                color: AelianaColors.stardust,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Got it',
                                  style: GoogleFonts.inter(
                                    color: AelianaColors.plasmaCyan,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AelianaColors.plasmaCyan.withOpacity(0.6),
                      ),
                    ),
                  ],
                ).animate(delay: 1000.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  value: _genderIdentity,
                  dropdownColor: AelianaColors.carbon,
                  decoration: const InputDecoration(
                    hintText: 'Select or skip',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Non-binary', child: Text('Non-binary')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                    DropdownMenuItem(value: 'Prefer not to say', child: Text('Prefer not to say')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _genderIdentity = value;
                    });
                  },
                  style: GoogleFonts.inter(color: AelianaColors.stardust),
                ).animate(delay: 1100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 48),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleContinue,
                    child: const Text('BEGIN CONNECTION'),
                  ),
                ).animate(delay: 1200.ms).fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
