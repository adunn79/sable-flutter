import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sable/core/calendar/calendar_service.dart';
import '../models/permissions_config.dart';

class Screen15Permissions extends StatefulWidget {
  final Function(PermissionsConfig) onComplete;

  const Screen15Permissions({
    super.key,
    required this.onComplete,
  });

  @override
  State<Screen15Permissions> createState() => _Screen15PermissionsState();
}

class _Screen15PermissionsState extends State<Screen15Permissions> with WidgetsBindingObserver {
  bool _gpsEnabled = false;
  bool _webAccessEnabled = false;
  bool _calendarEnabled = false;
  bool _micEnabled = false;
  bool _cameraEnabled = false;
  bool _contactsEnabled = false;
  bool _photosEnabled = false;
  bool _healthEnabled = false;
  bool _remindersEnabled = false;
  bool _speechEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    // Re-verify all currently enabled permissions
    if (_calendarEnabled) {
       final status = await Permission.calendarFullAccess.status;
       if (!status.isGranted) setState(() => _calendarEnabled = false);
    }
    
    // Check others if they were supposed to be enabled, or just check general status
    // For specific toggles user is interacting with, the toggle handler manages it,
    // but globally syncing is good practice.
    // For now, let's focus on the critical ones if they were just changed in settings.
  }

  Future<void> _loadCurrentPermissions() async {
    // All permissions default to false - user must explicitly opt in
    // Even if OS permissions are already granted, we want user to consciously enable
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Show dialog guiding user to Settings when permission is permanently denied
  Future<void> _showSettingsDialog(String permissionName) async {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AelianaColors.carbon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '$permissionName Permission Required',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This permission was previously denied. Please enable it in your device Settings to use this feature.',
          style: GoogleFonts.inter(color: AelianaColors.ghost),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'LATER',
              style: GoogleFonts.spaceGrotesk(color: AelianaColors.ghost),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(
              'OPEN SETTINGS',
              style: GoogleFonts.spaceGrotesk(color: AelianaColors.plasmaCyan),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCalendarToggle(bool value) async {
    if (value) {
      final granted = await CalendarService.requestPermission();
      setState(() {
        _calendarEnabled = granted;
      });
    } else {
      setState(() {
        _calendarEnabled = false;
      });
    }
  }

  Future<void> _handleMicToggle(bool value) async {
    if (value) {
      PermissionStatus status = await Permission.microphone.status;
      
      if (status.isPermanentlyDenied || status.isDenied) {
        // Try requesting
        status = await Permission.microphone.request();
      }
      
      debugPrint('🎤 Microphone permission status: $status');
      
      if (status.isGranted) {
        setState(() => _micEnabled = true);
      } else if (status.isPermanentlyDenied) {
        // If it returns permanently denied immediately (simulators often do this if denied once)
        // Show dialog and wait for lifecycle resume to reassign
        _showSettingsDialog('Microphone');
        // We set it to true temporarily to show intent, but it will flip back if check fails? 
        // Better: keep it off until verified. 
        // The Lifecycle observer isn't specific to this permission, so let's rely on user
        // coming back and toggling again, OR checking on resume.
        // Actually best UX: User clicks -> Dialog -> Goes to Settings -> Comes back.
        // We need to know which one they were trying to enable.
      }
    } else {
      setState(() {
        _micEnabled = false;
      });
    }
  }

  Future<void> _handleCameraToggle(bool value) async {
    if (value) {
      final status = await Permission.camera.request();
      debugPrint('📷 Camera permission status: $status');
      if (status.isPermanentlyDenied) {
        _showSettingsDialog('Camera');
      }
      setState(() {
        _cameraEnabled = status.isGranted;
      });
    } else {
      setState(() {
        _cameraEnabled = false;
      });
    }
  }

  Future<void> _handleContactsToggle(bool value) async {
    if (value) {
      final status = await Permission.contacts.request();
      debugPrint('👥 Contacts permission status: $status');
      if (status.isPermanentlyDenied) {
        _showSettingsDialog('Contacts');
      }
      setState(() {
        _contactsEnabled = status.isGranted;
      });
    } else {
      setState(() {
        _contactsEnabled = false;
      });
    }
  }

  Future<void> _handlePhotosToggle(bool value) async {
    if (value) {
      final result = await PhotoManager.requestPermissionExtend();
      debugPrint('📸 Photos permission status: $result');
      if (result == PermissionState.denied) {
        _showSettingsDialog('Photos');
      }
      setState(() {
        _photosEnabled = result.isAuth;
      });
    } else {
      setState(() {
        _photosEnabled = false;
      });
    }
  }

  Future<void> _handleHealthToggle(bool value) async {
    if (value) {
      // HealthKit requires special handling - request through permission_handler
      // Note: Actual HealthKit authorization is done through health package when accessing data
      final status = await Permission.sensors.request();
      debugPrint('❤️ Health/Sensors permission status: $status');
      setState(() {
        _healthEnabled = status.isGranted || value; // Keep enabled as HealthKit auth happens at data access
      });
    } else {
      setState(() {
        _healthEnabled = false;
      });
    }
  }

  Future<void> _handleRemindersToggle(bool value) async {
    if (value) {
      final status = await Permission.reminders.request();
      debugPrint('✅ Reminders permission status: $status');
      if (status.isPermanentlyDenied) {
        _showSettingsDialog('Reminders');
      }
      setState(() {
        _remindersEnabled = status.isGranted;
      });
    } else {
      setState(() {
        _remindersEnabled = false;
      });
    }
  }

  Future<void> _handleSpeechToggle(bool value) async {
    if (value) {
      // Check status first
      var status = await Permission.speech.status;
      
      if (!status.isGranted) {
        status = await Permission.speech.request();
      }
      
      debugPrint('🗣️ Speech recognition permission status: $status');
      
      if (status.isGranted) {
        setState(() => _speechEnabled = true);
      } else if (status.isPermanentlyDenied) {
        _showSettingsDialog('Speech Recognition');
      }
    } else {
      setState(() {
        _speechEnabled = false;
      });
    }
  }

  void _handleContinue() {
    final config = PermissionsConfig(
      gpsEnabled: _gpsEnabled,
      webAccessEnabled: _webAccessEnabled,
      calendarEnabled: _calendarEnabled,
      micEnabled: _micEnabled,
      cameraEnabled: _cameraEnabled,
      contactsEnabled: _contactsEnabled,
      photosEnabled: _photosEnabled,
      healthEnabled: _healthEnabled,
      remindersEnabled: _remindersEnabled,
      speechEnabled: _speechEnabled,
    );
    widget.onComplete(config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Title
                    Center(
                      child: Text(
                        'ENHANCE THE CONNECTION',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AelianaColors.plasmaCyan,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),

                    const SizedBox(height: 8),

                    Text(
                      'Grant me context about your world. These permissions are optional, but recommended for a richer experience.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AelianaColors.ghost,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ).animate(delay: 200.ms).fadeIn(duration: 600.ms),

                    const SizedBox(height: 24),

                    // Core Permissions Section
                    _buildSectionHeader('Core Integrations', 300),

                    // GPS Access Card
                    _buildPermissionCard(
                      icon: Icons.location_on_outlined,
                      title: 'Location Awareness',
                      description: 'GPS access for locational context and nearby recommendations.',
                      value: _gpsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _gpsEnabled = value;
                        });
                      },
                      delay: 350,
                    ),

                    // Calendar Access Card
                    _buildPermissionCard(
                      icon: Icons.calendar_month_outlined,
                      title: 'Calendar Access',
                      description: 'Create events, check availability, and scheduling assistance.',
                      value: _calendarEnabled,
                      onChanged: _handleCalendarToggle,
                      delay: 400,
                    ),

                    // Web Access Card
                    _buildPermissionCard(
                      icon: Icons.public_outlined,
                      title: 'World Event Awareness',
                      description: 'Web access to stay informed about global events.',
                      value: _webAccessEnabled,
                      onChanged: (value) {
                        setState(() {
                          _webAccessEnabled = value;
                        });
                      },
                      delay: 450,
                    ),

                    const SizedBox(height: 16),
                    _buildSectionHeader('Media & Communication', 500),

                    // Microphone Card
                    _buildPermissionCard(
                      icon: Icons.mic_outlined,
                      title: 'Voice Input',
                      description: 'Talk to Aeliana using voice commands.',
                      value: _micEnabled,
                      onChanged: _handleMicToggle,
                      delay: 550,
                    ),

                    // Camera Card
                    _buildPermissionCard(
                      icon: Icons.camera_alt_outlined,
                      title: 'Camera Access',
                      description: 'Capture moments and scan documents.',
                      value: _cameraEnabled,
                      onChanged: _handleCameraToggle,
                      delay: 600,
                    ),

                    // Speech Recognition Card
                    _buildPermissionCard(
                      icon: Icons.record_voice_over_outlined,
                      title: 'Speech Recognition',
                      description: 'Enhanced voice-to-text for dictation.',
                      value: _speechEnabled,
                      onChanged: _handleSpeechToggle,
                      delay: 650,
                    ),

                    const SizedBox(height: 16),
                    _buildSectionHeader('Personal Data', 700),

                    // Contacts Card
                    _buildPermissionCard(
                      icon: Icons.contacts_outlined,
                      title: 'People Search',
                      description: 'Find contact info and enhance conversations.',
                      value: _contactsEnabled,
                      onChanged: _handleContactsToggle,
                      delay: 750,
                    ),

                    // Photos Card
                    _buildPermissionCard(
                      icon: Icons.photo_library_outlined,
                      title: 'Photo Library',
                      description: 'Access photos for memories and journals.',
                      value: _photosEnabled,
                      onChanged: _handlePhotosToggle,
                      delay: 800,
                    ),

                    // Reminders Card
                    _buildPermissionCard(
                      icon: Icons.task_alt_outlined,
                      title: 'Reminders Sync',
                      description: 'Sync with iOS Reminders app.',
                      value: _remindersEnabled,
                      onChanged: _handleRemindersToggle,
                      delay: 850,
                    ),

                    const SizedBox(height: 16),
                    _buildSectionHeader('Wellness', 900),

                    // Health Card
                    _buildPermissionCard(
                      icon: Icons.favorite_outline,
                      title: 'Vital Balance',
                      description: 'Connect with Apple Health for wellness tracking.',
                      value: _healthEnabled,
                      onChanged: _handleHealthToggle,
                      delay: 950,
                    ),

                    const SizedBox(height: 24),

                    // Information Note - Made prominent
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AelianaColors.plasmaCyan.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AelianaColors.plasmaCyan.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.settings_outlined,
                            color: AelianaColors.plasmaCyan,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You can change these permissions anytime in Settings. Your privacy is always protected.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AelianaColors.stardust,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 1000.ms).fadeIn(duration: 600.ms),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Continue Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleContinue,
                  child: const Text('CONTINUE'),
                ),
              ),
            ).animate(delay: 1100.ms).fadeIn(duration: 600.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int delay) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AelianaColors.ghost.withOpacity(0.7),
          letterSpacing: 2,
        ),
      ),
    ).animate(delay: delay.ms).fadeIn(duration: 400.ms);
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    required int delay,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: value
            ? AelianaColors.plasmaCyan.withOpacity(0.05)
            : AelianaColors.carbon.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? AelianaColors.plasmaCyan.withOpacity(0.3)
              : AelianaColors.ghost.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: value ? AelianaColors.plasmaCyan : AelianaColors.ghost,
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: value ? AelianaColors.plasmaCyan : AelianaColors.stardust,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AelianaColors.ghost.withOpacity(0.8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AelianaColors.plasmaCyan,
            activeTrackColor: AelianaColors.plasmaCyan.withOpacity(0.3),
            inactiveThumbColor: AelianaColors.ghost,
            inactiveTrackColor: AelianaColors.carbon,
          ),
        ],
      ),
    ).animate(delay: delay.ms).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }
}
