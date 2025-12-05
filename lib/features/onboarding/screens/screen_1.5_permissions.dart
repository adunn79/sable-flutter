import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aureal_theme.dart';
import 'package:geolocator/geolocator.dart';
import '../models/permissions_config.dart';
import '../services/onboarding_state_service.dart';

class Screen15Permissions extends StatefulWidget {
  final Function(PermissionsConfig) onComplete;

  const Screen15Permissions({
    super.key,
    required this.onComplete,
  });

  @override
  State<Screen15Permissions> createState() => _Screen15PermissionsState();
}

class _Screen15PermissionsState extends State<Screen15Permissions> {
  bool _gpsEnabled = false;
  bool _webAccessEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentPermissions();
  }

  Future<void> _loadCurrentPermissions() async {
    // Check GPS permission
    final gpsStatus = await Geolocator.checkPermission();
    final hasGps = gpsStatus == LocationPermission.always ||
        gpsStatus == LocationPermission.whileInUse;

    // Web access defaults to false - user must opt in
    // This is just a preference toggle
    final hasWeb = false;

    if (mounted) {
      setState(() {
        _gpsEnabled = hasGps;
        _webAccessEnabled = hasWeb;
        _isLoading = false;
      });
    }
  }

  void _handleContinue() {
    final config = PermissionsConfig(
      gpsEnabled: _gpsEnabled,
      webAccessEnabled: _webAccessEnabled,
    );
    widget.onComplete(config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),

                    // Title
                    Text(
                      'ENHANCE THE CONNECTION',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AurealColors.plasmaCyan,
                        letterSpacing: 2,
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),

                    const SizedBox(height: 12),

                    Text(
                      'Grant me context about your world. These permissions are optional, but recommended for a richer experience.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AurealColors.ghost,
                        height: 1.5,
                      ),
                    ).animate(delay: 200.ms).fadeIn(duration: 600.ms),

                    const SizedBox(height: 48),

                    // GPS Access Card
                    _buildPermissionCard(
                      icon: Icons.location_on_outlined,
                      title: 'Location Awareness',
                      description: 'Allow GPS access for locational context, nearby recommendations, and personalized suggestions.',
                      value: _gpsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _gpsEnabled = value;
                        });
                      },
                      delay: 400,
                    ),

                    const SizedBox(height: 16),

                    // Web Access Card
                    _buildPermissionCard(
                      icon: Icons.public_outlined,
                      title: 'World Event Awareness',
                      description: 'Allow web access once daily to stay informed about global events and news.',
                      value: _webAccessEnabled,
                      onChanged: (value) {
                        setState(() {
                          _webAccessEnabled = value;
                        });
                      },
                      delay: 600,
                    ),

                    const SizedBox(height: 32),

                    // Information Note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AurealColors.carbon.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AurealColors.ghost.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AurealColors.plasmaCyan,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You can change these permissions anytime in Settings. Your privacy is always protected.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AurealColors.ghost,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 800.ms).fadeIn(duration: 600.ms),
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
            ).animate(delay: 1000.ms).fadeIn(duration: 600.ms),
          ],
        ),
      ),
    );
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: value
            ? AurealColors.plasmaCyan.withOpacity(0.05)
            : AurealColors.carbon.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? AurealColors.plasmaCyan.withOpacity(0.3)
              : AurealColors.ghost.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: value ? AurealColors.plasmaCyan : AurealColors.ghost,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: value ? AurealColors.plasmaCyan : AurealColors.stardust,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AurealColors.ghost,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  value ? 'ENABLED' : 'DISABLED',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: value ? AurealColors.plasmaCyan : AurealColors.ghost.withOpacity(0.5),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AurealColors.plasmaCyan,
            activeTrackColor: AurealColors.plasmaCyan.withOpacity(0.3),
            inactiveThumbColor: AurealColors.ghost,
            inactiveTrackColor: AurealColors.carbon,
          ),
        ],
      ),
    ).animate(delay: delay.ms).fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }
}
