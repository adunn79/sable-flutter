import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
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
  final _nameFocusNode = FocusNode();
  DateTime? _selectedDate;
  String? _genderIdentity;

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
    _nameFocusNode.dispose();
    super.dispose();
  }



  void _selectDate() {
    // Show Cupertino date picker in a bottom sheet
    // Default to ~30 years ago for better UX
    final initialDate = _selectedDate ?? DateTime(1990, 6, 15);
    DateTime tempDate = initialDate;
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 350,
        decoration: BoxDecoration(
          color: AelianaColors.carbon,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header with Done button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: AelianaColors.obsidian,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Cancel', style: GoogleFonts.inter(color: AelianaColors.ghost)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(
                    'Birthday',
                    style: GoogleFonts.spaceGrotesk(
                      color: AelianaColors.plasmaCyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Done', style: GoogleFonts.inter(color: AelianaColors.plasmaCyan, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      setState(() => _selectedDate = tempDate);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            // Date picker with reduced scroll sensitivity
            Expanded(
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Brightness.dark,
                  primaryColor: AelianaColors.plasmaCyan,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: GoogleFonts.inter(
                      color: AelianaColors.stardust,
                      fontSize: 20,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  minimumYear: 1920,
                  maximumYear: DateTime.now().year,
                  maximumDate: DateTime.now(), // Block ALL future dates for birthday
                  backgroundColor: AelianaColors.carbon,
                  onDateTimeChanged: (date) => tempDate = date,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleContinue() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
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

                InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: AelianaColors.carbon,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedDate != null
                            ? AelianaColors.plasmaCyan
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate != null
                              ? '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}'
                              : 'Select date of birth',
                          style: GoogleFonts.inter(
                            color: _selectedDate != null
                                ? AelianaColors.stardust
                                : AelianaColors.ghost.withOpacity(0.5),
                          ),
                        ),
                        const Icon(Icons.calendar_today,
                            color: AelianaColors.plasmaCyan, size: 20),
                      ],
                    ),
                  ),
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
