import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aureal_theme.dart';
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
  final _locationController = TextEditingController();
  DateTime? _selectedDate;
  String? _genderIdentity;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }



  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AurealColors.plasmaCyan,
              onPrimary: AurealColors.obsidian,
              surface: AurealColors.carbon,
              onSurface: AurealColors.stardust,
            ),
            dialogBackgroundColor: AurealColors.carbon,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _handleContinue() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select your date of birth',
                style: GoogleFonts.inter()),
            backgroundColor: AurealColors.plasmaCyan,
          ),
        );
        return;
      }

      final profile = UserProfile(
        name: _nameController.text.trim(),
        dateOfBirth: _selectedDate!,
        location: _locationController.text.trim(),
        genderIdentity: _genderIdentity,
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
      backgroundColor: AurealColors.obsidian,
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
                Text(
                  'THE CALIBRATION',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AurealColors.plasmaCyan,
                    letterSpacing: 2,
                  ),
                ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),

                const SizedBox(height: 12),

                Text(
                  'This helps me get to know you right away. It\'s part of our bonding—understanding who you are, where you come from, and how to connect with you.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AurealColors.ghost,
                    height: 1.5,
                  ),
                ).animate(delay: 200.ms).fadeIn(duration: 600.ms),

                const SizedBox(height: 48),

                // Name Field
                Text(
                  'What do they call you?',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AurealColors.ghost,
                    letterSpacing: 1,
                  ),
                ).animate(delay: 400.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 8),

                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.inter(color: AurealColors.stardust),
                  decoration: const InputDecoration(
                    hintText: 'Enter your name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ).animate(delay: 500.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 32),

                // Location Field
                Row(
                  children: [
                    Text(
                      'Where were you born?',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AurealColors.ghost,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AurealColors.carbon,
                            title: Text(
                              'About Location',
                              style: GoogleFonts.spaceGrotesk(
                                color: AurealColors.plasmaCyan,
                              ),
                            ),
                            content: Text(
                              'This helps the avatar know a little about you. You can skip this if you like.',
                              style: GoogleFonts.inter(
                                color: AurealColors.stardust,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Got it',
                                  style: GoogleFonts.inter(
                                    color: AurealColors.plasmaCyan,
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
                        color: AurealColors.plasmaCyan.withOpacity(0.6),
                      ),
                    ),
                  ],
                ).animate(delay: 600.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 8),

                TextFormField(
                  controller: _locationController,
                  style: GoogleFonts.inter(color: AurealColors.stardust),
                  decoration: const InputDecoration(
                    hintText: 'City, Country',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Birth location is required';
                    }
                    return null;
                  },
                ).animate(delay: 700.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 32),

                // Date of Birth
                Row(
                  children: [
                    Text(
                      'When did you begin?',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AurealColors.ghost,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AurealColors.carbon,
                            title: Text(
                              'Date of Birth',
                              style: GoogleFonts.spaceGrotesk(
                                color: AurealColors.plasmaCyan,
                              ),
                            ),
                            content: Text(
                              'What is your date of birth',
                              style: GoogleFonts.inter(
                                color: AurealColors.stardust,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Got it',
                                  style: GoogleFonts.inter(
                                    color: AurealColors.plasmaCyan,
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
                        color: AurealColors.plasmaCyan.withOpacity(0.6),
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
                      color: AurealColors.carbon,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedDate != null
                            ? AurealColors.plasmaCyan
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate != null
                              ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                              : 'Select date of birth',
                          style: GoogleFonts.inter(
                            color: _selectedDate != null
                                ? AurealColors.stardust
                                : AurealColors.ghost.withOpacity(0.5),
                          ),
                        ),
                        const Icon(Icons.calendar_today,
                            color: AurealColors.plasmaCyan, size: 20),
                      ],
                    ),
                  ),
                ).animate(delay: 900.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 32),

                // Gender (Optional)
                Text(
                  'How do you identify? (Optional)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AurealColors.ghost,
                    letterSpacing: 1,
                  ),
                ).animate(delay: 1000.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  value: _genderIdentity,
                  dropdownColor: AurealColors.carbon,
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
                  style: GoogleFonts.inter(color: AurealColors.stardust),
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
