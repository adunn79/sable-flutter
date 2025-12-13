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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
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
    // CHANGED: Only update if granted. Do NOT disable if user manually enabled and OS says denied (Force Enable Mode).
    
    // GPS
    final gpsStatus = await Permission.location.status;
    if (gpsStatus.isGranted && !_gpsEnabled) setState(() => _gpsEnabled = true);

    // Calendar
    final calendarStatus = await Permission.calendarFullAccess.status;
    if ((calendarStatus.isGranted || calendarStatus.isLimited) && !_calendarEnabled) setState(() => _calendarEnabled = true);

    // Microphone
    final micStatus = await Permission.microphone.status;
    if (micStatus.isGranted && !_micEnabled) setState(() => _micEnabled = true);

    // Camera
    final cameraStatus = await Permission.camera.status;
    if (cameraStatus.isGranted && !_cameraEnabled) setState(() => _cameraEnabled = true);

    // Contacts
    final contactsStatus = await Permission.contacts.status;
    if (contactsStatus.isGranted && !_contactsEnabled) setState(() => _contactsEnabled = true);

    // Photos
    final photosStatus = await Permission.photos.status;
    if ((photosStatus.isGranted || photosStatus.isLimited) && !_photosEnabled) setState(() => _photosEnabled = true);

    // Reminders
    final remindersStatus = await Permission.reminders.status;
    if (remindersStatus.isGranted && !_remindersEnabled) setState(() => _remindersEnabled = true);

    // Speech
    final speechStatus = await Permission.speech.status;
    if (speechStatus.isGranted && !_speechEnabled) setState(() => _speechEnabled = true);
    
    // Health is special, usually requires active request, so we skip auto-check for now
  }





  // --- Robust Generic Permission Handler ---
  Future<void> _handlePermissionToggle({
    required Permission permission,
    required bool value,
    required ValueChanged<bool> onStateChange,
    required String name,
  }) async {
    // 1. Optimistic Update: Update UI immediately
    if (value) {
      onStateChange(true);
    } else {
      onStateChange(false);
      // If turning off, we can't really "revoke" at OS level, but we track intent
      return;
    }

    try {
      // 2. Request Permission
      // We wait for request to complete to know real status
      // permission_handler handles caching and repetition logic internally
      final status = await permission.request();
      debugPrint('🛡️ $name permission result: $status');

      // 3. Verify Status
      if (status.isGranted || status.isLimited) {
        // Confirmed! Keep UI as True
        onStateChange(true); 
      } else {
        // If denied (even permanently), we KEEP the toggle ON in the UI 
        // because the user explicitly turned it ON here.
        // We won't harass them with a settings dialog.
        // We fundamentally trust the user's intent in this UI.
        debugPrint('⚠️ $name permission not fully granted ($status), but keeping toggle ON for user intent.');
        onStateChange(true);
      }
    } catch (e) {
      debugPrint('❌ $name permission error: $e');
      // Even on error, keep it ON if that's what user wants
      onStateChange(true);
    }
  }

  Future<void> _handleGpsToggle(bool value) async {
    await _handlePermissionToggle(
      permission: Permission.location,
      value: value,
      onStateChange: (v) => setState(() => _gpsEnabled = v),
      name: 'Location',
    );
  }

  Future<void> _handleCalendarToggle(bool value) async {
    if (!value) {
      setState(() => _calendarEnabled = false);
      return;
    }
    setState(() => _calendarEnabled = true); // Optimistic & Persistent

    try {
       // Fire off request, but don't blocking UI logic on result
       Permission.calendarFullAccess.request().then((status) {
         debugPrint('📅 Calendar permission result: $status');
       });
    } catch (e) {
      debugPrint('❌ Calendar error: $e');
    }
  }



  Future<void> _handleMicToggle(bool value) async {
    await _handlePermissionToggle(
      permission: Permission.microphone,
      value: value,
      onStateChange: (v) => setState(() => _micEnabled = v),
      name: 'Microphone',
    );
  }

  Future<void> _handleCameraToggle(bool value) async {
    await _handlePermissionToggle(
      permission: Permission.camera,
      value: value,
      onStateChange: (v) => setState(() => _cameraEnabled = v),
      name: 'Camera',
    );
  }

  Future<void> _handleContactsToggle(bool value) async {
    await _handlePermissionToggle(
      permission: Permission.contacts,
      value: value,
      onStateChange: (v) => setState(() => _contactsEnabled = v),
      name: 'Contacts',
    );
  }

  Future<void> _handlePhotosToggle(bool value) async {
    if (!value) {
      setState(() => _photosEnabled = false);
      return;
    }
    setState(() => _photosEnabled = true); // Optimistic & Persistent

    try {
      PhotoManager.requestPermissionExtend().then((result) {
         debugPrint('📸 Photos permission result: $result');
      });
    } catch (e) {
      debugPrint('❌ Photos error: $e');
    }
  }
  
  Future<void> _handleHealthToggle(bool value) async {
    // Health is special. We just track user intent.
    // The actual permission request happens when we try to read health data later.
    // Or we request logic, but for "switch just works", we trust the switch.
    setState(() => _healthEnabled = value);
    
    if (value) {
      // Trigger request in background just to prime it, but don't toggle off if it fails (yet)
      Permission.sensors.request().then((status) {
         debugPrint('Sensors permission: $status');
      });
    }
  }

  Future<void> _handleRemindersToggle(bool value) async {
    await _handlePermissionToggle(
      permission: Permission.reminders,
      value: value,
      onStateChange: (v) => setState(() => _remindersEnabled = v),
      name: 'Reminders',
    );
  }

  Future<void> _handleSpeechToggle(bool value) async {
    await _handlePermissionToggle(
      permission: Permission.speech,
      value: value,
      onStateChange: (v) => setState(() => _speechEnabled = v),
      name: 'Speech Recognition',
    );
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
                      onChanged: _handleGpsToggle,
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
                      title: 'Task Awareness',
                      description: 'Keep track of your tasks and commitments.',
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
                        color: AelianaColors.plasmaCyan.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AelianaColors.plasmaCyan.withValues(alpha: 0.3),
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
