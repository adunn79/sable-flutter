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
  bool _shareLocation = false;
  List<Map<String, String>> _emergencyContacts = [];

  final List<Map<String, String>> _resources = [
    {
      'title': 'Suicide & Crisis Lifeline',
      'number': '988',
      'subtitle': '24/7, free and confidential support',
      'action': 'tel:988'
    },
    {
      'title': 'National Domestic Violence Hotline',
      'number': '1-800-799-7233',
      'subtitle': 'Confidential support for domestic violence',
      'action': 'tel:18007997233'
    },
    {
      'title': 'National Human Trafficking Hotline',
      'number': '1-888-373-7888',
      'subtitle': 'Support for victims of trafficking',
      'action': 'tel:18883737888'
    },
    {
      'title': 'RAINN (Sexual Assault)',
      'number': '1-800-656-HOPE',
      'subtitle': 'National Sexual Assault Hotline',
      'action': 'tel:18006564673'
    },
    {
      'title': 'Childhelp National Child Abuse Hotline',
      'number': '1-800-4-A-CHILD',
      'subtitle': 'Crisis intervention for child abuse',
      'action': 'tel:18004224453'
    },
    {
      'title': 'Crisis Text Line',
      'number': 'Text HOME to 741741',
      'subtitle': 'Free, 24/7 support via text',
      'action': 'sms:741741'
    },
    {
      'title': 'Emergency Services',
      'number': '911',
      'subtitle': 'Immediate medical, police, fire',
      'action': 'tel:911'
    }
  ];

  Future<void> _makeCall(String uriString) async {
    final Uri launchUri = Uri.parse(uriString);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _addContact() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AurealColors.carbon,
        title: Text('Add Emergency Contact', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.white54)),
            ),
            TextField(
              controller: phoneController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                setState(() {
                  _emergencyContacts.add({
                    'name': nameController.text,
                    'phone': phoneController.text,
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _activateEmergencyProtocol() async {
    setState(() => _isSosActive = true);
    
    // Simulate notifying contacts
    if (_emergencyContacts.isNotEmpty) {
      final message = _shareLocation 
          ? "EMERGENCY: I need help! My location: 37.7749° N, 122.4194° W (Simulated)" 
          : "EMERGENCY: I need help! (Location hidden)";
      
      // In a real app, use background_sms or similar
      debugPrint("Sending SMS to contacts: $message");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notifying ${_emergencyContacts.length} contacts...')),
        );
      }
    }

    // Call 911
    await _makeCall('tel:911');
    
    if (mounted) {
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
          'EMERGENCY CENTER',
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('CRISIS RESOURCES'),
                ..._resources.map((resource) => _buildResourceTile(resource)),
                
                const SizedBox(height: 24),
                _buildSectionHeader('EMERGENCY CONTACTS'),
                if (_emergencyContacts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'No emergency contacts set. Add trusted people to notify them when you trigger an SOS.',
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                ..._emergencyContacts.asMap().entries.map((entry) {
                   final index = entry.key;
                   final contact = entry.value;
                   return Container(
                     margin: const EdgeInsets.only(bottom: 8),
                     decoration: BoxDecoration(
                       color: AurealColors.carbon,
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: Colors.white12),
                     ),
                     child: ListTile(
                       leading: const Icon(LucideIcons.user, color: Colors.white),
                       title: Text(contact['name']!, style: const TextStyle(color: Colors.white)),
                       subtitle: Text(contact['phone']!, style: const TextStyle(color: Colors.white54)),
                       trailing: IconButton(
                         icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 18),
                         onPressed: () {
                           setState(() => _emergencyContacts.removeAt(index));
                         },
                       ),
                     ),
                   );
                }),
                
                OutlinedButton.icon(
                  onPressed: _addContact,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Emergency Contact'),
                  style: OutlinedButton.styleFrom(foregroundColor: AurealColors.plasmaCyan),
                ),
                
                const SizedBox(height: 24),
                _buildSectionHeader('SOS SETTINGS'),
                SwitchListTile(
                  value: _shareLocation,
                  onChanged: (val) => setState(() => _shareLocation = val),
                  activeColor: Colors.red,
                  title: Text('Share GPS Location', style: GoogleFonts.inter(color: Colors.white)),
                  subtitle: Text(
                    'Include your coordinates when notifying contacts',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          
          // SOS Footer
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1010),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Colors.red.withOpacity(0.3))),
            ),
            child: Column(
              children: [
                Text(
                  _shareLocation 
                      ? 'WARNING: Pressing below calls 911 AND texts your location to contacts.'
                      : 'WARNING: Pressing below calls 911 AND notifies contacts (Location hidden).',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.red[100], fontSize: 13),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSosActive ? null : _activateEmergencyProtocol,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
    );
  }

  Widget _buildResourceTile(Map<String, String> resource) {
    final isSms = resource['action']?.startsWith('sms') ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AurealColors.carbon,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
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
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resource['number']!,
              style: GoogleFonts.spaceGrotesk(color: AurealColors.plasmaCyan, fontSize: 16),
            ),
            if (resource['subtitle'] != null)
              Text(
                resource['subtitle']!,
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
              ),
          ],
        ),
        onTap: () => _makeCall(resource['action']!),
      ),
    );
  }
}
