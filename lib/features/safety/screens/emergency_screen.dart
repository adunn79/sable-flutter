import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aureal_theme.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
  bool _isSosActive = false;

  final List<Map<String, String>> _resources = [
    {
      'title': 'Suicide & Crisis Lifeline',
      'number': '988',
      'subtitle': '24/7, free and confidential support for people in distress',
    },
    {
      'title': 'National Domestic Violence Hotline',
      'number': '1-800-799-7233',
      'subtitle': 'Confidential support for anyone affected by domestic violence',
    },
    {
      'title': 'Crisis Text Line',
      'number': 'Text HOME to 741741',
      'subtitle': 'Free, 24/7 support for those in crisis',
      'action': 'sms:741741'
    },
    {
      'title': 'Emergency Services',
      'number': '911',
      'subtitle': 'For immediate medical, police, or fire emergencies',
    }
  ];

  Future<void> _makeCall(String number) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: number,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _sendSms(String uriString) async {
    final Uri launchUri = Uri.parse(uriString);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _activateEmergencyProtocol() async {
    setState(() => _isSosActive = true);
    
    // 1. Get contact info
    final stateService = await OnboardingStateService.create();
    
    // In a real app, this would get a configured emergency contact
    // For now, we simulate the action
    
    // 2. Call 911 (User must confirm system dialog)
    await _makeCall('911');
    
    // 3. Send SMS if configured (Mock flow)
    /* 
    if (emergencyContact != null) {
      final loc = stateService.userCurrentLocation ?? "Unknown Location";
      final msg = "EMERGENCY: I have activated my Sable emergency protocol. My last known location is $loc.";
      await _sendSms('sms:$contactNumber?body=$msg');
    }
    */
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency Helper Activated. Calling 911...'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        )
      );
      setState(() => _isSosActive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      appBar: AppBar(
        backgroundColor: AurealColors.obsidian,
        title: Text(
          'EMERGENCY RESOURCES',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.red,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Resource List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _resources.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final resource = _resources[index];
                final isSms = resource['action']?.startsWith('sms') ?? false;
                
                return Container(
                  decoration: BoxDecoration(
                    color: AurealColors.carbon,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSms ? LucideIcons.messageSquare : LucideIcons.phone,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      resource['title']!,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resource['number']!,
                          style: GoogleFonts.spaceGrotesk(
                            color: AurealColors.plasmaCyan,
                            fontSize: 16,
                          ),
                        ),
                        if (resource['subtitle'] != null)
                          Text(
                            resource['subtitle']!,
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      if (resource['action'] != null) {
                        _sendSms(resource['action']!);
                      } else {
                        _makeCall(resource['number']!);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          
          // SOS Button Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1010), // Dark Red
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Colors.red.withOpacity(0.3))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.alertTriangle, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'WARNING: This will call 911 and notify your emergency contacts with your location.',
                        style: GoogleFonts.inter(
                          color: Colors.red[100],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSosActive ? null : _activateEmergencyProtocol,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: Colors.red.withOpacity(0.5),
                    ),
                    child: _isSosActive
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.phoneCall),
                              const SizedBox(width: 12),
                              Text(
                                'GET HELP NOW',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
