import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aureal_theme.dart';
import 'package:sable/core/identity/bond_engine.dart';
import 'package:sable/features/settings/widgets/settings_tile.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
import 'package:sable/core/emotion/conversation_memory_service.dart';
import 'package:sable/core/voice/voice_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _newsEnabled = true;
  bool _gpsEnabled = false;
  
  // Permission Toggles (Default OFF)
  bool _permissionGps = false;
  bool _permissionMic = false;
  bool _permissionCamera = false;
  bool _permissionContacts = false;
  bool _permissionNotes = false;
  bool _permissionCalendar = false;
  bool _permissionReminders = false;
  
  // News Settings
  bool _newsTimingFirstInteraction = true;
  bool _newsTimingOnDemand = false;
  bool _categoryLocal = true;
  bool _categoryNational = true;
  bool _categoryWorld = false;
  bool _categorySports = false;
  bool _categoryReligion = false;
  bool _categoryTech = true;
  bool _categoryScience = true;
  
  // Voice Settings
  final VoiceService _voiceService = VoiceService();
  final TextEditingController _apiKeyController = TextEditingController();
  String _voiceEngine = 'system';
  String? _selectedVoiceName;
  List<Map<String, String>> _availableVoices = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _voiceService.initialize();
    _voiceEngine = _voiceService.currentEngine;
    
    // Load API Key if exists (for display purposes, though usually hidden)
    // In a real app, we might not want to populate the text field for security, 
    // but for UX here we will leave it empty unless user wants to change it.
    
    await _loadVoices();
  }

  Future<void> _loadVoices() async {
    final voices = await _voiceService.getAvailableVoices();
    setState(() {
      _availableVoices = voices;
      _voiceEngine = _voiceService.currentEngine;
    });
    
    // Get current voice name
    // This is a bit tricky as we only store ID. We need to find the name.
    // For now, we'll just show "Select Voice" or try to match ID.
  }

  void _showVoiceSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AurealColors.obsidian,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 400,
        child: Column(
          children: [
            Text(
              'Select Voice (${_voiceEngine == 'eleven_labs' ? 'ElevenLabs' : 'System'})',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _availableVoices.isEmpty
                  ? Center(
                      child: Text(
                        _voiceEngine == 'eleven_labs' 
                            ? 'No voices found.\nCheck API Key or internet.' 
                            : 'No system voices found.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _availableVoices.length,
                      itemBuilder: (context, index) {
                        final voice = _availableVoices[index];
                        return ListTile(
                          title: Text(
                            voice['name'] ?? 'Unknown',
                            style: GoogleFonts.inter(color: Colors.white),
                          ),
                          subtitle: Text(
                            voice['locale'] ?? '',
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                          ),
                          onTap: () async {
                            await _voiceService.setVoice(voice['name']!); // Using name as ID for system, ID for ElevenLabs
                            setState(() {
                              _selectedVoiceName = voice['name'];
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bondState = ref.watch(bondEngineProvider);

    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      appBar: AppBar(
        backgroundColor: AurealColors.obsidian,
        title: Text(
          'SETTINGS',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: [
          // Emergency Services (Prominent)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              border: Border.all(color: Colors.red.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SettingsTile(
              title: 'Emergency Services',
              subtitle: 'Get help immediately',
              icon: Icons.emergency,
              iconColor: Colors.red,
              onTap: () {
                // TODO: Implement emergency call/info
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Emergency protocols activated.')),
                );
              },
            ),
          ),

          _buildSectionHeader('ACCOUNT'),
          const SettingsTile(
            title: 'Profile',
            subtitle: 'Manage your identity',
            icon: Icons.person_outline,
          ),
          const SettingsTile(
            title: 'Subscription',
            subtitle: 'Aureal Pro Active',
            icon: Icons.diamond_outlined,
          ),

          _buildSectionHeader('PRIVACY FORTRESS'),
          const SettingsTile(
            title: 'The Vault',
            subtitle: 'Zero-Knowledge Zone',
            icon: Icons.lock_outline,
          ),
          SettingsTile(
            title: 'How we use your info',
            subtitle: 'Data usage & protection policy',
            icon: Icons.shield_outlined,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AurealColors.carbon,
                  title: Text('Data Privacy', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
                  content: Text(
                    'Your data is encrypted locally. We do not sell your personal information. '
                    'Conversations are processed for response generation only and are not stored permanently on our servers without your consent.',
                    style: GoogleFonts.inter(color: AurealColors.stardust),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          SettingsTile(
            title: 'Forget Last Interaction',
            subtitle: 'Remove from short-term memory',
            icon: Icons.history,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Memory shredded.')),
              );
            },
          ),
          SettingsTile(
            title: 'Clear Chat History',
            subtitle: 'Remove all conversation messages',
            icon: Icons.chat_bubble_outline,
            onTap: () async {
              final memoryService = await ConversationMemoryService.create();
              await memoryService.clearHistory();
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat history cleared. Please restart chat.')),
                );
              }
            },
          ),
          SettingsTile(
            title: 'Wipe Memory',
            subtitle: 'Reset Bond Graph completely',
            icon: Icons.delete_forever,
            isDestructive: true,
            onTap: () async {
              // Show confirmation dialog
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AurealColors.carbon,
                  title: Text('Wipe All Data?', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
                  content: Text(
                    'This will completely reset the app and return you to onboarding. All conversation history, profile data, and preferences will be lost.',
                    style: GoogleFonts.inter(color: AurealColors.stardust),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Wipe Everything'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                // Clear all data
                final service = await OnboardingStateService.create();
                await service.clearOnboardingData();
                
                final memoryService = await ConversationMemoryService.create();
                await memoryService.clearHistory();
                
                if (context.mounted) {
                  // Navigate back to splash, which will redirect to onboarding
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                }
              }
            },
          ),

          _buildSectionHeader('PERMISSIONS & ACCESS'),
          SettingsTile(
            title: 'Location Services',
            subtitle: 'GPS & location-aware features',
            icon: Icons.location_on_outlined,
            trailing: Switch(
              value: _permissionGps,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) => setState(() => _permissionGps = val),
            ),
          ),
          SettingsTile(
            title: 'Microphone',
            subtitle: 'Voice input & commands',
            icon: Icons.mic_outlined,
            trailing: Switch(
              value: _permissionMic,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) => setState(() => _permissionMic = val),
            ),
          ),
          SettingsTile(
            title: 'Camera',
            subtitle: 'Visual recognition (Future)',
            icon: Icons.camera_alt_outlined,
            trailing: Switch(
              value: _permissionCamera,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) => setState(() => _permissionCamera = val),
            ),
          ),
          SettingsTile(
            title: 'Contacts',
            subtitle: 'Relationship awareness (Future)',
            icon: Icons.contacts_outlined,
            trailing: Switch(
              value: _permissionContacts,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) => setState(() => _permissionContacts = val),
            ),
          ),
          SettingsTile(
            title: 'Notes',
            subtitle: 'Shared note access (Future)',
            icon: Icons.note_outlined,
            trailing: Switch(
              value: _permissionNotes,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) => setState(() => _permissionNotes = val),
            ),
          ),
          SettingsTile(
            title: 'Calendar',
            subtitle: 'Schedule integration (Future)',
            icon: Icons.calendar_today_outlined,
            trailing: Switch(
              value: _permissionCalendar,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) => setState(() => _permissionCalendar = val),
            ),
          ),
          SettingsTile(
            title: 'Reminders',
            subtitle: 'Task management (Future)',
            icon: Icons.alarm_outlined,
            trailing: Switch(
              value: _permissionReminders,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) => setState(() => _permissionReminders = val),
            ),
          ),

          _buildSectionHeader('VOICE & PERSONALITY'),
          SettingsTile(
            title: 'Voice Engine',
            subtitle: _voiceEngine == 'eleven_labs' ? 'ElevenLabs (High Quality)' : 'System Default',
            icon: Icons.record_voice_over,
            onTap: () async {
              // Toggle engine
              final newEngine = _voiceEngine == 'system' ? 'eleven_labs' : 'system';
              await _voiceService.setVoiceEngine(newEngine);
              setState(() => _voiceEngine = newEngine);
              _loadVoices(); // Reload voices for new engine
            },
            trailing: Switch(
              value: _voiceEngine == 'eleven_labs',
              activeColor: AurealColors.hyperGold,
              onChanged: (val) async {
                final newEngine = val ? 'eleven_labs' : 'system';
                await _voiceService.setVoiceEngine(newEngine);
                setState(() => _voiceEngine = newEngine);
                _loadVoices();
              },
            ),
          ),
          
          if (_voiceEngine == 'eleven_labs') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _apiKeyController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'ElevenLabs API Key',
                  labelStyle: GoogleFonts.inter(color: AurealColors.stardust),
                  hintText: 'Enter your API key',
                  hintStyle: GoogleFonts.inter(color: Colors.white24),
                  filled: true,
                  fillColor: AurealColors.carbon,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.save, color: AurealColors.plasmaCyan),
                    onPressed: () async {
                      await _voiceService.setElevenLabsApiKey(_apiKeyController.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('API Key saved!')),
                      );
                      _loadVoices();
                    },
                  ),
                ),
                obscureText: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(
                'Get a key at elevenlabs.io. Free tier available.',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
              ),
            ),
          ],

          SettingsTile(
            title: 'Voice Selection',
            subtitle: _selectedVoiceName ?? 'Select a voice',
            icon: Icons.graphic_eq,
            onTap: () {
              _showVoiceSelector();
            },
          ),
          
          if (_voiceEngine == 'eleven_labs')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AurealColors.plasmaCyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECOMMENDED VOICES',
                      style: GoogleFonts.spaceGrotesk(
                        color: AurealColors.plasmaCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Bella: Soft, intense, warm (Female)\n• Josh: Deep, calm, reassuring (Male)\n\nTo add more: Go to Voice Library on ElevenLabs website, add to your lab, and they will appear here.',
                      style: GoogleFonts.inter(color: AurealColors.stardust, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          _buildSectionHeader('REAL-WORLD AWARENESS'),
          SettingsTile(
            title: 'Daily Briefing',
            subtitle: _newsEnabled ? 'Active' : 'Disabled',
            icon: Icons.newspaper,
            trailing: Switch(
              value: _newsEnabled,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) => setState(() => _newsEnabled = val),
            ),
          ),
          
          if (_newsEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEWS TIMING',
                    style: GoogleFonts.spaceGrotesk(
                      color: AurealColors.plasmaCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimingChip('First Interaction', _newsTimingFirstInteraction, () {
                          setState(() {
                            _newsTimingFirstInteraction = true;
                            _newsTimingOnDemand = false;
                          });
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTimingChip('On Demand', _newsTimingOnDemand, () {
                          setState(() {
                            _newsTimingFirstInteraction = false;
                            _newsTimingOnDemand = true;
                          });
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEWS CATEGORIES',
                    style: GoogleFonts.spaceGrotesk(
                      color: AurealColors.plasmaCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildCategoryChip('Local', _categoryLocal, () => setState(() => _categoryLocal = !_categoryLocal)),
                      _buildCategoryChip('National', _categoryNational, () => setState(() => _categoryNational = !_categoryNational)),
                      _buildCategoryChip('World', _categoryWorld, () => setState(() => _categoryWorld = !_categoryWorld)),
                      _buildCategoryChip('Sports', _categorySports, () => setState(() => _categorySports = !_categorySports)),
                      _buildCategoryChip('Religion', _categoryReligion, () => setState(() => _categoryReligion = !_categoryReligion)),
                      _buildCategoryChip('Space/Tech', _categoryTech, () => setState(() => _categoryTech = !_categoryTech)),
                      _buildCategoryChip('Science', _categoryScience, () => setState(() => _categoryScience = !_categoryScience)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aureal will fetch top 10 items daily from selected categories',
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
          
          SettingsTile(
            title: 'Local Guide',
            subtitle: 'GPS suggestions',
            icon: Icons.location_on_outlined,
            trailing: Switch(
              value: _gpsEnabled,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) => setState(() => _gpsEnabled = val),
            ),
          ),

          _buildSectionHeader('BOND ENGINE'),
          SettingsTile(
            title: 'Connection Status',
            subtitle: bondState.name.toUpperCase(),
            icon: Icons.favorite_border,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getBondColor(bondState).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _getBondColor(bondState)),
              ),
              child: Text(
                bondState.name.toUpperCase(),
                style: GoogleFonts.inter(
                  color: _getBondColor(bondState),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SettingsTile(
            title: 'Reset Bond',
            subtitle: 'Return to Neutral state',
            icon: Icons.refresh,
            onTap: () {
              ref.read(bondEngineProvider.notifier).resetToNeutral();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bond reset to Neutral.')),
              );
            },
          ),

          _buildSectionHeader('SUPPORT'),
          const SettingsTile(
            title: 'Contact Us',
            subtitle: 'support@aureal.ai',
            icon: Icons.mail_outline,
          ),
          const SettingsTile(
            title: 'Help Center',
            subtitle: 'FAQ & Guides',
            icon: Icons.help_outline,
          ),

          _buildSectionHeader('ABOUT'),
          const SettingsTile(
            title: 'Version',
            subtitle: '1.0.0 (Build 102)',
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Text(
        title,
        style: GoogleFonts.spaceGrotesk(
          color: AurealColors.plasmaCyan,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Color _getBondColor(BondState state) {
    switch (state) {
      case BondState.warm:
        return AurealColors.hyperGold;
      case BondState.neutral:
        return Colors.blue;
      case BondState.cooled:
        return Colors.cyan;
    }
  }

  Widget _buildTimingChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AurealColors.hyperGold.withOpacity(0.2) : AurealColors.carbon,
          border: Border.all(
            color: isSelected ? AurealColors.hyperGold : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: isSelected ? AurealColors.hyperGold : Colors.white,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AurealColors.plasmaCyan.withOpacity(0.2) : AurealColors.carbon,
          border: Border.all(
            color: isSelected ? AurealColors.plasmaCyan : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? AurealColors.plasmaCyan : Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
