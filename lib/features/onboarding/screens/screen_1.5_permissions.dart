import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
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
    // Both permissions default to false - user must explicitly opt in
    // Even if OS permissions are already granted, we want user to consciously enable
    final hasGps = false;
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
                    const SizedBox(height: 40),

                    // Title
                    Center(
                      child: Text(
                        'ENHANCE THE CONNECTION',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AelianaColors.plasmaCyan,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),

                    const SizedBox(height: 12),

                    Text(
                      'Grant me context about your world. These permissions are optional, but recommended for a richer experience.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AelianaColors.ghost,
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
                        color: AelianaColors.carbon.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AelianaColors.ghost.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AelianaColors.plasmaCyan,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You can change these permissions anytime in Settings. Your privacy is always protected.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AelianaColors.ghost,
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
            ? AelianaColors.plasmaCyan.withOpacity(0.05)
            : AelianaColors.carbon.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? AelianaColors.plasmaCyan.withOpacity(0.3)
              : AelianaColors.ghost.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: value ? AelianaColors.plasmaCyan : AelianaColors.ghost,
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
                    color: value ? AelianaColors.plasmaCyan : AelianaColors.stardust,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AelianaColors.ghost,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  value ? 'ENABLED' : 'DISABLED',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: value ? AelianaColors.plasmaCyan : AelianaColors.ghost.withOpacity(0.5),
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
            activeColor: AelianaColors.plasmaCyan,
            activeTrackColor: AelianaColors.plasmaCyan.withOpacity(0.3),
            inactiveThumbColor: AelianaColors.ghost,
            inactiveTrackColor: AelianaColors.carbon,
          ),
        ],
      ),
    ).animate(delay: delay.ms).fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }
}
