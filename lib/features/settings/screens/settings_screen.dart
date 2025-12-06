import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sable/core/ai/model_orchestrator.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aureal_theme.dart';
import 'package:sable/core/identity/bond_engine.dart';
import 'package:sable/features/common/widgets/cascading_voice_selector.dart';
import 'package:sable/features/settings/widgets/settings_tile.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
import 'package:sable/core/emotion/conversation_memory_service.dart';
import 'package:sable/core/voice/voice_service.dart';

import 'package:sable/core/voice/elevenlabs_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/emotion/emotional_state_service.dart';
import 'package:sable/core/ui/feedback_service.dart';
import 'package:sable/core/personality/personality_service.dart'; // Added implementation
// Native app services
import 'package:sable/core/calendar/calendar_service.dart';
import 'package:sable/core/contacts/contacts_service.dart';
import 'package:sable/core/photos/photos_service.dart';
import 'package:sable/core/reminders/reminders_service.dart';
import 'package:sable/core/ai/apple_intelligence_service.dart';
import 'package:sable/features/subscription/screens/subscription_screen.dart';
import 'package:sable/features/local_vibe/widgets/local_vibe_settings_screen.dart';
import 'package:sable/features/local_vibe/services/local_vibe_service.dart';
import 'package:sable/features/local_vibe/models/local_vibe_settings.dart';
import 'package:sable/features/web/services/web_search_service.dart';
import 'package:sable/features/safety/screens/emergency_screen.dart';
import 'package:sable/features/settings/screens/vault_screen.dart';
import 'package:sable/core/widgets/restart_widget.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:sable/core/audio/button_sound_service.dart';
import 'package:sable/features/settings/services/avatar_display_settings.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _newsEnabled = true;
  bool _gpsEnabled = false;
  String _avatarDisplayMode = AvatarDisplaySettings.modeFullscreen;
  String _backgroundColor = AvatarDisplaySettings.colorBlack;
  bool _clockUse24Hour = false;
  bool _clockIsAnalog = false;
  
  // Permission Toggles (Default OFF)
  bool _permissionGps = false;
  bool _permissionMic = false;
  bool _permissionCamera = false;
  bool _permissionContacts = false;
  bool _permissionNotes = false; // Used for Photos currently
  
  // Intelligence Settings
  bool _persistentMemoryEnabled = true;
  bool _appleIntelligenceEnabled = false;

  // Feedback Settings
  bool _hapticsEnabled = true;
  bool _soundsEnabled = true;

  // Personality Settings
  String _selectedPersonalityId = 'sassy_realist';




  Future<void> _togglePersistentMemory(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('persistent_memory_enabled', value);
    setState(() => _persistentMemoryEnabled = value);
    
    // If disabled, we might want to clear memory or just stop saving
    // For now, it just controls the flag
  }

  Future<void> _toggleAppleIntelligence(bool value) async {
    if (value) {
      // Check if available natively
      final isAvailable = await AppleIntelligenceService.isAvailable();
      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Apple Intelligence requires iOS 18+ and compatible hardware.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // Do not enable
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('apple_intelligence_enabled', value);
    setState(() => _appleIntelligenceEnabled = value);
  }
  bool _permissionCalendar = false;
  bool _permissionReminders = false;
  
  // News Settings
  bool _newsTimingFirstInteraction = true;
  bool _newsTimingOnDemand = false;
  
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController controller = TextEditingController(); // Location controller
  String _manualLocation = '';

  // Local Vibe Settings
  LocalVibeSettings _localVibeSettings = const LocalVibeSettings();
  bool _showAllVibeCategories = false;
  final TextEditingController _localVibeCategoryController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  // News Categories
  Set<String> _selectedCategories = {};
  bool _showAllCategories = false;

  static const List<String> _allNewsCategories = [
    // 1. Essentials
    'Business', 'Finance', 'Entertainment', 'Health', 'Politics',
    'National', 'World', 'Local',
    // 2. Lifestyle
    'Gaming', 'Travel', 'Food & Dining', 'Automotive',
    // 3. Specials
    'Good News', 'AI & Future', 'Crypto', 'Tech', 'Science',
    // Others
    'Sports', 'Religion'
  ];

  static const List<String> _suggestedLocalVibeCategories = [
    '☕ Coffee Shops',
    '🍸 Speakeasies',
    '🎵 Live Music',
    '🌳 Parks & Nature',
    '🎨 Art Galleries',
    '🍽️ Hidden Gem Software', // "Foodie"
    '🧘 Yoga & Wellness',
    '🛍️ Vintage Shopping',
    '📚 Bookstores',
    '🏰 Historic Sites',
  ];

  Future<void> _toggleCategory(String category) async {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
    
    // Save to state service
    final stateService = await OnboardingStateService.create();
    await stateService.setNewsCategories(_selectedCategories.toList());
  }
  


  // News Settings (Custom)
  List<String> _customNewsTopics = [];
  
  // Voice Settings
  final VoiceService _voiceService = VoiceService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _apiKeyController = TextEditingController();
  String _voiceEngine = 'eleven_labs';
  String? _selectedVoiceId; 
  String? _selectedVoiceName;
  List<VoiceWithMetadata> _availableVoices = [];
  
  // Brain Sliders
  double _brainCreativity = 0.7;
  double _brainEmpathy = 0.8;
  double _brainHumor = 0.6;
  
  // Local Vibe Service handle
  LocalVibeService? _localVibeService;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadVoices(); // Moved here as per user's implied change
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _audioPlayer.dispose();
    _cityController.dispose();
    _localVibeCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    await _voiceService.initialize();
    final stateService = await OnboardingStateService.create();
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _manualLocation = stateService.userCurrentLocation ?? '';
      _voiceEngine = prefs.getString('voice_engine') ?? 'eleven_labs';
      _apiKeyController.text = prefs.getString('eleven_labs_api_key') ?? '';
      _selectedVoiceId = prefs.getString('selected_voice_id');
      
      // Load Intelligence Settings
      _persistentMemoryEnabled = prefs.getBool('persistent_memory_enabled') ?? true;
      _appleIntelligenceEnabled = prefs.getBool('apple_intelligence_enabled') ?? false;
      
      // Load News Settings
      _newsEnabled = stateService.newsEnabled;

      final categories = stateService.newsCategories;
      _selectedCategories = Set.from(categories);
      
      _newsTimingFirstInteraction = stateService.newsTimingFirstInteraction;
      _newsTimingOnDemand = stateService.newsTimingOnDemand;
      
      _newsTimingOnDemand = stateService.newsTimingOnDemand;
      
      // Load permissions (mocked for now)
      _permissionGps = stateService.permissionGps;
      _permissionMic = stateService.permissionMic;
      _permissionCamera = stateService.permissionCamera;
      
      // Load Feedback Settings
      _hapticsEnabled = stateService.hapticsEnabled;
      _soundsEnabled = stateService.soundsEnabled;
      _selectedPersonalityId = stateService.selectedPersonalityId;
      
      // Load Brain Settings
      _brainCreativity = stateService.brainCreativity;
      _brainEmpathy = stateService.brainEmpathy;
      _brainHumor = stateService.brainHumor;
    });

    // Load Local Vibe Settings
    try {
      final webSearchService = ref.read(webSearchServiceProvider);
      final vibeService = await LocalVibeService.create(webSearchService);
      if (mounted) {
        setState(() {
          _localVibeSettings = vibeService.settings;
          // Load GPS enabled state from permissions
          _gpsEnabled = stateService.permissionGps;
        });
      }
    } catch (e) {
      debugPrint('Error loading Local Vibe settings: $e');
    }
    
    // Load Avatar Display Settings
    final avatarSettings = AvatarDisplaySettings();
    avatarSettings.getAvatarDisplayMode().then((mode) {
      if (mounted) setState(() => _avatarDisplayMode = mode);
    });
    avatarSettings.getBackgroundColor().then((color) {
      if (mounted) setState(() => _backgroundColor = color);
    });
    
    // Load Clock Settings
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _clockUse24Hour = prefs.getBool('clock_use_24hour') ?? false;
          _clockIsAnalog = prefs.getBool('clock_is_analog') ?? false;
        });
      }
    });
    
    // Load API Key if exists (for display purposes, though usually hidden)
    // In a real app, we might not want to populate the text field for security, 
    // but for UX here we will leave it empty unless user wants to change it.
    
    // Load Local Vibe Settings
    // Load Local Vibe Settings
    final orchestrator = ref.read(modelOrchestratorProvider.notifier);
    final webSearch = WebSearchService(orchestrator);
    _localVibeService = await LocalVibeService.create(webSearch);
    setState(() {
      _localVibeSettings = _localVibeService!.settings;
    });
  }

  Future<void> _loadVoices() async {
    // Use all voices for the cascading selector
    final voices = await _voiceService.getAllVoices();
    setState(() {
      _availableVoices = voices;
      _voiceEngine = _voiceService.currentEngine;
    });
  }

  Future<void> _playVoiceSample(String voiceId) async {
    const sampleText = "Hi! I'm your AI companion. This is how I sound.";
    
    debugPrint('🔊 Playing voice sample for: $voiceId');
    
    try {
      // Use VoiceService to play sample
      await _voiceService.speakWithVoice(sampleText, voiceId: voiceId);
      debugPrint('✅ Voice sample playback started');
    } catch (e) {
      debugPrint('Error playing voice sample: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play voice sample: $e')),
        );
      }
    }
  }

  void _showVoiceSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AurealColors.obsidian,
      isScrollControlled: true, // Allow full height
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(24),
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Voice',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: CascadingVoiceSelector(
                      voices: _availableVoices,
                      selectedVoiceId: _selectedVoiceId,
                      onVoiceSelected: (voiceId) async {
                        await _voiceService.setVoice(voiceId);
                        final voice = _availableVoices.firstWhere((v) => v.voiceId == voiceId);
                        setState(() {
                          _selectedVoiceName = voice.name;
                          _selectedVoiceId = voiceId;
                        });
                        // Don't pop immediately, let user preview
                      },
                      onPlayPreview: () async {
                        if (_selectedVoiceId != null) {
                          await _playVoiceSample(_selectedVoiceId!);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    debugPrint('Building SettingsScreen'); // Debug print
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
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/chat');
            }
          },
        ),
      ),
      body: ListView(
        children: [

          _buildSectionHeader('ACCOUNT'),
          SettingsTile(
            title: 'Profile',
            subtitle: 'Manage your identity',
            icon: Icons.person_outline,
            onTap: () {
              ref.read(buttonSoundServiceProvider).playMediumTap();
              _showProfileDialog();
            },
            onLongPress: () {
              ref.read(buttonSoundServiceProvider).playLightTap();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AurealColors.carbon,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Icon(Icons.person_outline, color: AurealColors.plasmaCyan),
                      const SizedBox(width: 12),
                      Text('PROFILE', style: GoogleFonts.spaceGrotesk(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manage your identity and how Sable knows you.', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AurealColors.plasmaCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
                        ),
                        child: Text('• Your name and personal details\n• How Sable addresses you\n• Identity preferences', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5)),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('GOT IT', style: GoogleFonts.inter(color: Colors.white54))),
                  ],
                ),
              );
            },
          ),
          SettingsTile(
            title: 'Subscription',
            subtitle: 'Aureal Pro Active',
            icon: Icons.diamond_outlined,
            onTap: () {
              ref.read(buttonSoundServiceProvider).playMediumTap();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
            },
            onLongPress: () {
              ref.read(buttonSoundServiceProvider).playLightTap();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AurealColors.carbon,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Icon(Icons.diamond_outlined, color: AurealColors.hyperGold),
                      const SizedBox(width: 12),
                      Text('SUBSCRIPTION', style: GoogleFonts.spaceGrotesk(color: AurealColors.hyperGold, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manage your Aureal subscription and unlock premium features.', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AurealColors.hyperGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AurealColors.hyperGold.withOpacity(0.3)),
                        ),
                        child: Text('• View current plan and benefits\n• Upgrade or change subscription\n• Manage billing', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5)),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('GOT IT', style: GoogleFonts.inter(color: Colors.white54))),
                  ],
                ),
              );
            },
          ),



          // Privacy Fortress - Collapsible Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                backgroundColor: AurealColors.carbon,
                collapsedBackgroundColor: AurealColors.carbon,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.lock_outline, color: AurealColors.plasmaCyan),
                title: Text(
                  'PRIVACY FORTRESS',
                  style: GoogleFonts.spaceGrotesk(
                    color: AurealColors.plasmaCyan,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                subtitle: Text(
                  'Tap to manage privacy & data',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                ),
                children: [
                  SettingsTile(
                    title: 'The Vault',
                    subtitle: 'Zero-Knowledge Zone',
                    icon: Icons.lock_outline,
                    onTap: () {
                      ref.read(buttonSoundServiceProvider).playMediumTap();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen()));
                    },
                  ),
                  SettingsTile(
                    title: 'How we use your info',
                    subtitle: 'Data usage & protection policy',
                    icon: Icons.shield_outlined,
                    onTap: () {
                      ref.read(buttonSoundServiceProvider).playMediumTap();
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
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
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
                      ref.read(buttonSoundServiceProvider).playMediumTap();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Memory shredded.')));
                    },
                    onLongPress: () {
                      ref.read(buttonSoundServiceProvider).playLightTap();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AurealColors.carbon,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Row(
                            children: [
                              const Icon(Icons.history, color: AurealColors.plasmaCyan),
                              const SizedBox(width: 12),
                              Text('FORGET LAST INTERACTION', style: GoogleFonts.spaceGrotesk(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Removes only the most recent conversation exchange from short-term memory.', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AurealColors.plasmaCyan.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
                                ),
                                child: Text('• Clears last interaction only\\n• Preserves all other conversations\\n• Bond and personality data untouched\\n• Useful for correcting mistakes', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5)),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: Text('GOT IT', style: GoogleFonts.inter(color: Colors.white54))),
                          ],
                        ),
                      );
                    },
                  ),
                  SettingsTile(
                    title: 'Clear Chat History',
                    subtitle: 'Remove all conversation messages',
                    icon: Icons.chat_bubble_outline,
                    onTap: () async {
                      ref.read(buttonSoundServiceProvider).playMediumTap();
                      try {
                        final memoryService = await ConversationMemoryService.create();
                        await memoryService.clearHistory();
                        if (context.mounted) {
                          Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/home', (route) => false);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error clearing: $e')));
                        }
                      }
                    },
                    onLongPress: () {
                      ref.read(buttonSoundServiceProvider).playLightTap();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AurealColors.carbon,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline, color: AurealColors.plasmaCyan),
                              const SizedBox(width: 12),
                              Text('CLEAR CHAT HISTORY', style: GoogleFonts.spaceGrotesk(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Removes all visible conversation messages from your chat history.', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AurealColors.plasmaCyan.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
                                ),
                                child: Text('• Deletes all conversation messages\\n• Preserves bond and personality data\\n• Returns you to chat with fresh greeting\\n• Profile and settings remain intact', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5)),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: Text('GOT IT', style: GoogleFonts.inter(color: Colors.white54))),
                          ],
                        ),
                      );
                    },
                  ),
                  SettingsTile(
                    title: 'Reset Onboarding',
                    subtitle: 'Return to onboarding (keeps data)',
                    icon: Icons.refresh,
                    onTap: () async {
                      ref.read(buttonSoundServiceProvider).playMediumTap();
                      try {
                        final stateService = await OnboardingStateService.create();
                        await stateService.clearOnboardingData();
                        final memoryService = await ConversationMemoryService.create();
                        await memoryService.clearHistory();
                        if (context.mounted) {
                          await Future.delayed(Duration.zero);
                          if (context.mounted) {
                            Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/onboarding', (route) => false);
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error resetting: $e')));
                        }
                      }
                    },
                    onLongPress: () {
                      ref.read(buttonSoundServiceProvider).playLightTap();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AurealColors.carbon,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Row(
                            children: [
                              const Icon(Icons.refresh, color: AurealColors.plasmaCyan),
                              const SizedBox(width: 12),
                              Text('RESET ONBOARDING', style: GoogleFonts.spaceGrotesk(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Returns you to the initial setup flow while preserving your existing data.', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AurealColors.plasmaCyan.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
                                ),
                                child: Text('• Restarts onboarding screens\\n• Clears chat history\\n• Keeps your profile data\\n• Useful for re-customizing experience', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5)),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: Text('GOT IT', style: GoogleFonts.inter(color: Colors.white54))),
                          ],
                        ),
                      );
                    },
                  ),
                  SettingsTile(
                    title: 'Wipe Memory',
                    subtitle: 'Reset Bond Graph completely',
                    icon: Icons.delete_forever,
                    isDestructive: true,
                    onTap: () async {
                      ref.read(buttonSoundServiceProvider).playHeavyTap();
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
                            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Wipe Everything'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final service = await OnboardingStateService.create();
                        await service.clearOnboardingData();
                        final memoryService = await ConversationMemoryService.create();
                        await memoryService.clearHistory();
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Chat Appearance Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                backgroundColor: AurealColors.carbon,
                collapsedBackgroundColor: AurealColors.carbon,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.palette_outlined, color: AurealColors.hyperGold),
                title: Text(
                  'CHAT APPEARANCE',
                  style: GoogleFonts.spaceGrotesk(
                    color: AurealColors.hyperGold,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                subtitle: Text(
                  'Customize avatar and background',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                ),
                children: [
                  // Avatar Display Mode Toggle
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AurealColors.obsidian,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Avatar Display Mode',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Row 1: Full Screen, Icon, Orb
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  ref.read(buttonSoundServiceProvider).playMediumTap();
                                  final avatarSettings = AvatarDisplaySettings();
                                  await avatarSettings.setAvatarDisplayMode(AvatarDisplaySettings.modeFullscreen);
                                  setState(() => _avatarDisplayMode = AvatarDisplaySettings.modeFullscreen);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _avatarDisplayMode == AvatarDisplaySettings.modeFullscreen
                                        ? AurealColors.hyperGold.withOpacity(0.2)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: _avatarDisplayMode == AvatarDisplaySettings.modeFullscreen
                                          ? AurealColors.hyperGold
                                          : Colors.white24,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Full Screen',
                                      style: GoogleFonts.inter(
                                        color: _avatarDisplayMode == AvatarDisplaySettings.modeFullscreen
                                            ? AurealColors.hyperGold
                                            : Colors.white70,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  ref.read(buttonSoundServiceProvider).playMediumTap();
                                  final avatarSettings = AvatarDisplaySettings();
                                  await avatarSettings.setAvatarDisplayMode(AvatarDisplaySettings.modeIcon);
                                  setState(() => _avatarDisplayMode = AvatarDisplaySettings.modeIcon);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _avatarDisplayMode == AvatarDisplaySettings.modeIcon
                                        ? AurealColors.hyperGold.withOpacity(0.2)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: _avatarDisplayMode == AvatarDisplaySettings.modeIcon
                                          ? AurealColors.hyperGold
                                          : Colors.white24,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Icon',
                                      style: GoogleFonts.inter(
                                        color: _avatarDisplayMode == AvatarDisplaySettings.modeIcon
                                            ? AurealColors.hyperGold
                                            : Colors.white70,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  ref.read(buttonSoundServiceProvider).playMediumTap();
                                  final avatarSettings = AvatarDisplaySettings();
                                  await avatarSettings.setAvatarDisplayMode(AvatarDisplaySettings.modeOrb);
                                  setState(() => _avatarDisplayMode = AvatarDisplaySettings.modeOrb);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _avatarDisplayMode == AvatarDisplaySettings.modeOrb
                                        ? AurealColors.hyperGold.withOpacity(0.2)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: _avatarDisplayMode == AvatarDisplaySettings.modeOrb
                                          ? AurealColors.hyperGold
                                          : Colors.white24,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Orb',
                                      style: GoogleFonts.inter(
                                        color: _avatarDisplayMode == AvatarDisplaySettings.modeOrb
                                            ? AurealColors.hyperGold
                                            : Colors.white70,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Row 2: Portrait, Clock
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  ref.read(buttonSoundServiceProvider).playMediumTap();
                                  final avatarSettings = AvatarDisplaySettings();
                                  await avatarSettings.setAvatarDisplayMode(AvatarDisplaySettings.modePortrait);
                                  setState(() => _avatarDisplayMode = AvatarDisplaySettings.modePortrait);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _avatarDisplayMode == AvatarDisplaySettings.modePortrait
                                        ? AurealColors.hyperGold.withOpacity(0.2)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: _avatarDisplayMode == AvatarDisplaySettings.modePortrait
                                          ? AurealColors.hyperGold
                                          : Colors.white24,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Portrait',
                                      style: GoogleFonts.inter(
                                        color: _avatarDisplayMode == AvatarDisplaySettings.modePortrait
                                            ? AurealColors.hyperGold
                                            : Colors.white70,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  ref.read(buttonSoundServiceProvider).playMediumTap();
                                  final avatarSettings = AvatarDisplaySettings();
                                  await avatarSettings.setAvatarDisplayMode(AvatarDisplaySettings.modeClock);
                                  setState(() => _avatarDisplayMode = AvatarDisplaySettings.modeClock);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _avatarDisplayMode == AvatarDisplaySettings.modeClock
                                        ? AurealColors.hyperGold.withOpacity(0.2)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: _avatarDisplayMode == AvatarDisplaySettings.modeClock
                                          ? AurealColors.hyperGold
                                          : Colors.white24,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Clock',
                                      style: GoogleFonts.inter(
                                        color: _avatarDisplayMode == AvatarDisplaySettings.modeClock
                                            ? AurealColors.hyperGold
                                            : Colors.white70,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Empty spacer for layout balance (optional)
                            const SizedBox(width: 12),
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Background Color Selector (shown in Icon, Orb, and Portrait modes)
                  if (_avatarDisplayMode == AvatarDisplaySettings.modeIcon ||
                      _avatarDisplayMode == AvatarDisplaySettings.modeOrb ||
                      _avatarDisplayMode == AvatarDisplaySettings.modePortrait)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AurealColors.obsidian,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Background Color',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    ref.read(buttonSoundServiceProvider).playMediumTap();
                                    final avatarSettings = AvatarDisplaySettings();
                                    await avatarSettings.setBackgroundColor(AvatarDisplaySettings.colorBlack);
                                    setState(() => _backgroundColor = AvatarDisplaySettings.colorBlack);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      border: Border.all(
                                        color: _backgroundColor == AvatarDisplaySettings.colorBlack
                                            ? AurealColors.hyperGold
                                            : Colors.white24,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Black',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    ref.read(buttonSoundServiceProvider).playMediumTap();
                                    final avatarSettings = AvatarDisplaySettings();
                                    await avatarSettings.setBackgroundColor(AvatarDisplaySettings.colorWhite);
                                    setState(() => _backgroundColor = AvatarDisplaySettings.colorWhite);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                        color: _backgroundColor == AvatarDisplaySettings.colorWhite
                                            ? AurealColors.hyperGold
                                            : Colors.black26,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'White',
                                        style: GoogleFonts.inter(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  // Clock Settings (shown only in Clock mode)
                  if (_avatarDisplayMode == AvatarDisplaySettings.modeClock)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AurealColors.obsidian,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clock Settings',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 12hr / 24hr toggle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Time Format',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      ref.read(buttonSoundServiceProvider).playMediumTap();
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.setBool('clock_use_24hour', false);
                                      setState(() => _clockUse24Hour = false);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: !_clockUse24Hour
                                            ? AurealColors.hyperGold.withOpacity(0.2)
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: !_clockUse24Hour
                                              ? AurealColors.hyperGold
                                              : Colors.white24,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '12hr',
                                        style: GoogleFonts.inter(
                                          color: !_clockUse24Hour ? AurealColors.hyperGold : Colors.white54,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      ref.read(buttonSoundServiceProvider).playMediumTap();
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.setBool('clock_use_24hour', true);
                                      setState(() => _clockUse24Hour = true);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _clockUse24Hour
                                            ? AurealColors.hyperGold.withOpacity(0.2)
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: _clockUse24Hour
                                              ? AurealColors.hyperGold
                                              : Colors.white24,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '24hr',
                                        style: GoogleFonts.inter(
                                          color: _clockUse24Hour ? AurealColors.hyperGold : Colors.white54,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Digital / Analog toggle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Clock Style',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      ref.read(buttonSoundServiceProvider).playMediumTap();
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.setBool('clock_is_analog', false);
                                      setState(() => _clockIsAnalog = false);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: !_clockIsAnalog
                                            ? AurealColors.hyperGold.withOpacity(0.2)
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: !_clockIsAnalog
                                              ? AurealColors.hyperGold
                                              : Colors.white24,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Digital',
                                        style: GoogleFonts.inter(
                                          color: !_clockIsAnalog ? AurealColors.hyperGold : Colors.white54,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      ref.read(buttonSoundServiceProvider).playMediumTap();
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.setBool('clock_is_analog', true);
                                      setState(() => _clockIsAnalog = true);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _clockIsAnalog
                                            ? AurealColors.hyperGold.withOpacity(0.2)
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: _clockIsAnalog
                                              ? AurealColors.hyperGold
                                              : Colors.white24,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Analog',
                                        style: GoogleFonts.inter(
                                          color: _clockIsAnalog ? AurealColors.hyperGold : Colors.white54,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          _buildSectionHeader('INTELLIGENCE & MEMORY'),
          SettingsTile(
            title: 'Persistent Memory',
            subtitle: 'Remember conversations forever',
            icon: Icons.memory_outlined,
            onLongPress: () {
              ref.read(buttonSoundServiceProvider).playLightTap();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AurealColors.carbon,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Icon(Icons.memory_outlined, color: AurealColors.plasmaCyan),
                      const SizedBox(width: 12),
                      Text('PERSISTENT MEMORY', style: GoogleFonts.spaceGrotesk(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Enables long-term memory of your conversations and context.', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AurealColors.plasmaCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
                        ),
                        child: Text('• Remembers across sessions\n• Builds deeper understanding\n• Personalized responses\n• Disable to prevent learning', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5)),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('GOT IT', style: GoogleFonts.inter(color: Colors.white54))),
                  ],
                ),
              );
            },
            trailing: Switch(
              value: _persistentMemoryEnabled,
              activeColor: AurealColors.hyperGold,
              onChanged: _togglePersistentMemory,
            ),
          ),
          SettingsTile(
            title: 'Apple Intelligence',
            subtitle: 'On-device AI (Siri, Writing Tools)',
            icon: Icons.apple,
            onLongPress: () {
              ref.read(buttonSoundServiceProvider).playLightTap();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AurealColors.carbon,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Icon(Icons.apple, color: AurealColors.plasmaCyan),
                      const SizedBox(width: 12),
                      Text('APPLE INTELLIGENCE', style: GoogleFonts.spaceGrotesk(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Integrates with Apple\'s on-device AI features like Siri and Writing Tools.', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AurealColors.plasmaCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
                        ),
                        child: Text('• 100% on-device processing\n• Privacy-focused\n• Requires iOS 18.1+\n• Limited to supported devices', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5)),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('GOT IT', style: GoogleFonts.inter(color: Colors.white54))),
                  ],
                ),
              );
            },
            trailing: Switch(
              value: _appleIntelligenceEnabled,
              activeColor: AurealColors.hyperGold,
              onChanged: _toggleAppleIntelligence,
            ),
          ),

          _buildSectionHeader('FEEDBACK & IMMERSION'),
          SettingsTile(
            title: 'Haptic Feedback',
            subtitle: 'Vibrations on interaction',
            icon: Icons.vibration,
            onLongPress: () {
              ref.read(buttonSoundServiceProvider).playLightTap();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AurealColors.carbon,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Icon(Icons.vibration, color: AurealColors.plasmaCyan),
                      const SizedBox(width: 12),
                      Text('HAPTIC FEEDBACK', style: GoogleFonts.spaceGrotesk(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Physical vibration feedback when interacting with buttons and controls.', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AurealColors.plasmaCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
                        ),
                        child: Text('• Tactile confirmation\n• Enhanced immersion\n• Different levels per action\n• Disable to save battery', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5)),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('GOT IT', style: GoogleFonts.inter(color: Colors.white54))),
                  ],
                ),
              );
            },
            trailing: Switch(
              value: _hapticsEnabled,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) async {
                setState(() => _hapticsEnabled = val);
                final state = await OnboardingStateService.create();
                await state.setHapticsEnabled(val);
                ref.read(feedbackServiceProvider).reloadSettings();
                if (val) ref.read(feedbackServiceProvider).medium();
              },
            ),
          ),
          SettingsTile(
            title: 'UI Sounds',
            subtitle: 'Clicks and effects',
            icon: Icons.volume_up_outlined,
            onLongPress: () {
              ref.read(buttonSoundServiceProvider).playLightTap();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AurealColors.carbon,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Icon(Icons.volume_up_outlined, color: AurealColors.plasmaCyan),
                      const SizedBox(width: 12),
                      Text('UI SOUNDS', style: GoogleFonts.spaceGrotesk(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Audio feedback for button taps and UI interactions.', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AurealColors.plasmaCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
                        ),
                        child: Text('• Click sounds on tap\n• Auditory confirmation\n• Enhances user experience\n• Disable for silent mode', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5)),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('GOT IT', style: GoogleFonts.inter(color: Colors.white54))),
                  ],
                ),
              );
            },
            trailing: Switch(
              value: _soundsEnabled,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) async {
                setState(() => _soundsEnabled = val);
                final state = await OnboardingStateService.create();
                await state.setSoundsEnabled(val);
                ref.read(feedbackServiceProvider).reloadSettings();
                if (val) ref.read(feedbackServiceProvider).tap();
              },
            ),
          ),

          _buildSectionHeader('PERMISSIONS & ACCESS'),
          SettingsTile(
            title: 'Location Services',
            subtitle: _manualLocation != null ? 'Manual: $_manualLocation' : 'GPS & location-aware features',
            icon: Icons.location_on_outlined,
            trailing: Switch(
              value: _permissionGps,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) async {
                setState(() => _permissionGps = val);
                final state = await OnboardingStateService.create();
                await state.setPermissionGps(val);
              },
            ),
          ),
          if (_permissionGps)
            Padding(
              padding: const EdgeInsets.only(left: 60, right: 24, bottom: 12),
              child: GestureDetector(
                onTap: _showManualLocationDialog,
                child: Text(
                  _manualLocation != null ? 'Change Manual Location' : 'Set Manual Location (Simulator Fix)',
                  style: GoogleFonts.inter(
                    color: AurealColors.plasmaCyan,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          SettingsTile(
            title: 'Microphone',
            subtitle: 'Voice input & commands',
            icon: Icons.mic_outlined,
            trailing: Switch(
              value: _permissionMic,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) async {
                setState(() => _permissionMic = val);
                final state = await OnboardingStateService.create();
                await state.setPermissionMic(val);
              },
            ),
          ),
          SettingsTile(
            title: 'Camera',
            subtitle: 'Visual recognition (Future)',
            icon: Icons.camera_alt_outlined,
            trailing: Switch(
              value: _permissionCamera,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) async {
                setState(() => _permissionCamera = val);
                final state = await OnboardingStateService.create();
                await state.setPermissionCamera(val);
              },
            ),
          ),
          SettingsTile(
            title: 'Contacts',
            subtitle: 'Relationship awareness',
            icon: Icons.contacts_outlined,
            trailing: FutureBuilder<bool>(
              future: ContactsService.hasPermission(),
              builder: (context, snapshot) {
                final hasPermission = snapshot.data ?? false;
                return Switch(
                  value: hasPermission || _permissionContacts,
                  activeColor: AurealColors.hyperGold,
                  onChanged: (val) async {
                    if (val) {
                      final granted = await ContactsService.requestPermission();
                      setState(() => _permissionContacts = granted);
                    } else {
                      // Show message: can't revoke, must go to Settings
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('To revoke permission, go to iOS Settings')),
                        );
                      }
                    }
                  },
                );
              },
            ),
          ),
          SettingsTile(
            title: 'Photos',
            subtitle: 'Photo library access',
            icon: Icons.photo_library_outlined,
            trailing: FutureBuilder<bool>(
              future: PhotosService.hasPermission(),
              builder: (context, snapshot) {
                final hasPermission = snapshot.data ?? false;
                return Switch(
                  value: hasPermission || _permissionNotes,
                  activeColor: AurealColors.hyperGold,
                  onChanged: (val) async {
                    if (val) {
                      final granted = await PhotosService.requestPermission();
                      setState(() => _permissionNotes = granted);
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('To revoke permission, go to iOS Settings')),
                        );
                      }
                    }
                  },
                );
              },
            ),
          ),
          SettingsTile(
            title: 'Calendar',
            subtitle: 'Schedule integration',
            icon: Icons.calendar_today_outlined,
            trailing: FutureBuilder<bool>(
              future: CalendarService.hasPermission(),
              builder: (context, snapshot) {
                final hasPermission = snapshot.data ?? false;
                return Switch(
                  value: hasPermission || _permissionCalendar,
                  activeColor: AurealColors.hyperGold,
                  onChanged: (val) async {
                    if (val) {
                      final granted = await CalendarService.requestPermission();
                      setState(() => _permissionCalendar = granted);
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('To revoke permission, go to iOS Settings')),
                        );
                      }
                    }
                  },
                );
              },
            ),
          ),
          SettingsTile(
            title: 'Reminders',
            subtitle: 'Task management',
            icon: Icons.alarm_outlined,
            trailing: FutureBuilder<bool>(
              future: RemindersService.hasPermission(),
              builder: (context, snapshot) {
                final hasPermission = snapshot.data ?? false;
                return Switch(
                  value: hasPermission || _permissionReminders,
                  activeColor: AurealColors.hyperGold,
                  onChanged: (val) async {
                    if (val) {
                      final granted = await RemindersService.requestPermission();
                      setState(() => _permissionReminders = granted);
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('To revoke permission, go to iOS Settings')),
                        );
                      }
                    }
                  },
                );
              },
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'NOTE: Text-to-Voice is a premium feature requiring our highest level plans. Free for limited use during initial preview (timeframe TBD).',
              style: GoogleFonts.inter(
                color: AurealColors.hyperGold,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
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
          
          SettingsTile(
            title: 'Clear Voice Cache',
            subtitle: 'Refresh voice library from server',
            icon: Icons.refresh,
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('elevenlabs_voices_cache');
              await prefs.remove('elevenlabs_voices_cache_timestamp');
              
              // Reload voices
              await _loadVoices();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Voice cache cleared! Voices refreshed.'),
                    backgroundColor: AurealColors.plasmaCyan,
                  ),
                );
              }
            },
          ),

          _buildSectionHeader('REAL-WORLD AWARENESS'),
          SettingsTile(
            title: 'Local Vibe',
            subtitle: 'Location & Preferences',
            icon: Icons.location_on_outlined,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: _gpsEnabled,
                  activeColor: AurealColors.hyperGold,
                  onChanged: (val) async {
                    setState(() => _gpsEnabled = val);
                    final state = await OnboardingStateService.create();
                    await state.setPermissionGps(val);
                  },
                ),
              ],
            ),
          ),
          
          if (_gpsEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('LOCATION MODE'),
                  const SizedBox(height: 16),
                  _buildLocationToggle(),
                  
                  if (_localVibeSettings.useCurrentLocation)
                    _buildRadiusSlider()
                  else
                    _buildCityInput(),
                  
                  const SizedBox(height: 32),
                  _buildSectionHeader('CATEGORIES'),
                  const SizedBox(height: 8),
                  Text(
                    'Select what you want to track locally.',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  _buildCategoryChips(),
                  
                  const SizedBox(height: 24),
                  _buildCustomCategoryInput(),
                ],
              ),
            ),
          ],
          SettingsTile(
            title: 'Daily Briefing',
            subtitle: _newsEnabled ? 'Active' : 'Disabled',
            icon: Icons.newspaper,
            trailing: Switch(
              value: _newsEnabled,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) async {
                setState(() => _newsEnabled = val);
                final stateService = await OnboardingStateService.create();
                await stateService.setNewsEnabled(val);
              },
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
                        child: _buildTimingChip('First Interaction', _newsTimingFirstInteraction, () async {
                          setState(() {
                            _newsTimingFirstInteraction = true;
                            // _newsTimingOnDemand = false; // Allow both? User request implies preference. Let's keep them independent or toggle?
                            // "First interaction, On-demand, Both" implies they are independent checkboxes essentially.
                          });
                          final stateService = await OnboardingStateService.create();
                          await stateService.setNewsTimingFirstInteraction(true);
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTimingChip('On Demand', _newsTimingOnDemand, () async {
                          setState(() {
                            _newsTimingOnDemand = !_newsTimingOnDemand;
                          });
                          final stateService = await OnboardingStateService.create();
                          await stateService.setNewsTimingOnDemand(_newsTimingOnDemand);
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
                      ...(_showAllCategories ? _allNewsCategories : _allNewsCategories.take(8)).map(
                        (category) => _buildCategoryChip(
                          category,
                          _selectedCategories.contains(category),
                          () => _toggleCategory(category),
                        ),
                      ),
                      // Show More Button
                      GestureDetector(
                        onTap: () => setState(() => _showAllCategories = !_showAllCategories),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _showAllCategories ? 'Show Less' : 'Show More',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _showAllCategories ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: Colors.white70,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // Custom Topics
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Custom Topics', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: AurealColors.carbon,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        child: TextField(
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Add topic (e.g. "Crypto", "Gardening")',
                            hintStyle: TextStyle(color: Colors.white30),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (value) {
                            if (value.isNotEmpty && !_customNewsTopics.contains(value)) {
                              setState(() {
                                _customNewsTopics.add(value);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                if (_customNewsTopics.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _customNewsTopics.map((topic) => Chip(
                        label: Text(topic, style: GoogleFonts.inter(color: Colors.white, fontSize: 11)),
                        backgroundColor: AurealColors.plasmaCyan.withOpacity(0.2),
                        deleteIcon: Icon(Icons.close, size: 14, color: AurealColors.plasmaCyan),
                        onDeleted: () => setState(() => _customNewsTopics.remove(topic)),
                        side: BorderSide(color: AurealColors.plasmaCyan),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),

          // End of News Section
          ],
          


          // Bond Engine with Info Icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('BOND ENGINE'),
                GestureDetector(
                  onTap: () {
                    ref.read(feedbackServiceProvider).tap();
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AurealColors.carbon,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            const Icon(Icons.favorite, color: AurealColors.plasmaCyan),
                            const SizedBox(width: 12),
                            Text('BOND ENGINE', style: GoogleFonts.spaceGrotesk(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('The Bond Engine dynamically adjusts how your AI companion responds to you based on emotional connection.', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AurealColors.plasmaCyan.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
                              ),
                              child: Text(
                                '• COOLED: Respectful, professional distance\n'
                                '• NEUTRAL: Balanced, friendly tone\n'
                                '• WARM: Close, intimate connection',
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: Text('GOT IT', style: GoogleFonts.inter(color: Colors.white54))),
                        ],
                      ),
                    );
                  },
                  child: const Icon(Icons.info_outline, size: 18, color: Colors.white54),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: _buildBondEngineSection(bondState.name),
          ),
          
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('PERSONALITY CORE'),
                Padding(
                  padding: const EdgeInsets.only(top: 24, right: 8),
                  child: Row(
                    children: [
                      Text('Swipe to explore', style: GoogleFonts.inter(fontSize: 10, color: Colors.white30)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 12, color: Colors.white30),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildPersonalitySection(),

          // Brain Configuration with Info Icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('BRAIN CONFIGURATION'),
                GestureDetector(
                  onTap: () {
                    ref.read(feedbackServiceProvider).tap();
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AurealColors.carbon,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            const Icon(LucideIcons.brainCircuit, color: AurealColors.plasmaCyan),
                            const SizedBox(width: 12),
                            Text('BRAIN CONFIGURATION', style: GoogleFonts.spaceGrotesk(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fine-tune your AI companion\'s neural parameters to customize response style and behavior.', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AurealColors.plasmaCyan.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
                              ),
                              child: Text(
                                '• CREATIVITY: Controls randomness vs consistency\n'
                                '• FOCUS: Balances detailed vs concise responses\n'
                                '• MEMORY DEPTH: How much context to recall\n'
                                '• EMPATHY: Emotional awareness in responses',
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: Text('GOT IT', style: GoogleFonts.inter(color: Colors.white54))),
                        ],
                      ),
                    );
                  },
                  child: const Icon(Icons.info_outline, size: 18, color: Colors.white54),
                ),
              ],
            ),
          ),
          _buildBrainSliders(),

          _buildSectionHeader('SUPPORT & SAFETY'),
          SettingsTile(
            title: 'Contact Us',
            subtitle: 'support@aureal.ai',
            icon: Icons.mail_outline,
            onTap: () {
              ref.read(buttonSoundServiceProvider).playMediumTap();
              // TODO: Open email client
            },
            onLongPress: () {
              ref.read(buttonSoundServiceProvider).playLightTap();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AurealColors.carbon,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Icon(Icons.mail_outline, color: AurealColors.plasmaCyan),
                      const SizedBox(width: 12),
                      Text('CONTACT SUPPORT', style: GoogleFonts.spaceGrotesk(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Get help from our support team at support@aureal.ai', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AurealColors.plasmaCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
                        ),
                        child: Text('• Response time: 24-48 hours\n• Include app version and device\n• Attach screenshots if helpful', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5)),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('GOT IT', style: GoogleFonts.inter(color: Colors.white54))),
                  ],
                ),
              );
            },
          ),
          SettingsTile(
            title: 'Help Center',
            subtitle: 'FAQ & Guides',
            icon: Icons.help_outline,
            onTap: () {
              ref.read(buttonSoundServiceProvider).playMediumTap();
              // TODO: Open help center
            },
            onLongPress: () {
              ref.read(buttonSoundServiceProvider).playLightTap();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AurealColors.carbon,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Icon(Icons.help_outline, color: AurealColors.plasmaCyan),
                      const SizedBox(width: 12),
                      Text('HELP CENTER', style: GoogleFonts.spaceGrotesk(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Access frequently asked questions and user guides.', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AurealColors.plasmaCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
                        ),
                        child: Text('• Getting started guides\n• Feature tutorials\n• Troubleshooting tips\n• Privacy and security info', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5)),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('GOT IT', style: GoogleFonts.inter(color: Colors.white54))),
                  ],
                ),
              );
            },
          ),
          
          // Emergency Services (Moved to bottom of support)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildEmergencyTile(),
          ),

          _buildSectionHeader('ABOUT'),
          SettingsTile(
            title: 'Version',
            subtitle: '1.0.0 (Build 102)',
            icon: Icons.info_outline,
            onTap: () {
              ref.read(buttonSoundServiceProvider).playLightTap();
            },
            onLongPress: () {
              ref.read(buttonSoundServiceProvider).playLightTap();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AurealColors.carbon,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AurealColors.plasmaCyan),
                      const SizedBox(width: 12),
                      Text('APP VERSION', style: GoogleFonts.spaceGrotesk(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current version and build information for troubleshooting.', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AurealColors.plasmaCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
                        ),
                        child: Text('• Version: 1.0.0\n• Build: 102\n• Include this info when contacting support', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5)),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('GOT IT', style: GoogleFonts.inter(color: Colors.white54))),
                  ],
                ),
              );
            },
          ),
          
          SettingsTile(
            title: 'Restart App',
            subtitle: 'Reload interface & state',
            icon: Icons.refresh,
            iconColor: AurealColors.hyperGold,
            onTap: () {
              ref.read(buttonSoundServiceProvider).playMediumTap();
              RestartWidget.restartApp(context);
            },
            onLongPress: () {
              ref.read(buttonSoundServiceProvider).playLightTap();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AurealColors.carbon,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Icon(Icons.refresh, color: AurealColors.hyperGold),
                      const SizedBox(width: 12),
                      Text('RESTART APP', style: GoogleFonts.spaceGrotesk(color: AurealColors.hyperGold, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Restarts the app to reload the interface and refresh all services.', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AurealColors.hyperGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AurealColors.hyperGold.withOpacity(0.3)),
                        ),
                        child: Text('• Reloads UI and state\n• Does NOT delete data\n• Useful for fixing display issues\n• Returns to home screen', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5)),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('GOT IT', style: GoogleFonts.inter(color: Colors.white54))),
                  ],
                ),
              );
            },
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

  Future<void> _showManualLocationDialog() async {
    final controller = TextEditingController(text: _manualLocation);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AurealColors.carbon,
        title: Text('Set Manual Location', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Override GPS location (useful for Simulator)',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'City, State',
                labelStyle: TextStyle(color: AurealColors.stardust),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AurealColors.plasmaCyan)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newLocation = controller.text.trim();
              if (newLocation.isNotEmpty) {
                final stateService = await OnboardingStateService.create();
                // Update current location in state
                await stateService.saveUserProfile(
                  name: stateService.userName ?? 'User',
                  dob: stateService.userDob ?? DateTime.now(),
                  location: stateService.userLocation ?? newLocation,
                  currentLocation: newLocation,
                  gender: stateService.userGender,
                  voiceId: stateService.selectedVoiceId,
                );
                
                setState(() {
                  _manualLocation = newLocation;
                });
              }
              Navigator.pop(context);
            },
            child: Text('Save', style: TextStyle(color: AurealColors.plasmaCyan)),
          ),
        ],
      ),
    );
  }

  Future<void> _showProfileDialog() async {
    final stateService = await OnboardingStateService.create();
    
    // Controllers
    final nameController = TextEditingController(text: stateService.userName);
    final phoneController = TextEditingController(text: stateService.userPhone ?? '');
    final emailController = TextEditingController(text: stateService.userEmail ?? '');
    final locationController = TextEditingController(text: stateService.userLocation ?? '');
    String? selectedGender = stateService.userGender;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AurealColors.carbon,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Edit Profile', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(nameController, 'Full Name', Icons.person),
                    const SizedBox(height: 12),
                    _buildTextField(phoneController, 'Phone Number', Icons.phone),
                    const SizedBox(height: 12),
                    _buildTextField(emailController, 'Email Address', Icons.email),
                    const SizedBox(height: 12),
                    _buildTextField(locationController, 'Home Location', Icons.location_on),
                    const SizedBox(height: 12),
                    // Gender Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedGender,
                          isExpanded: true,
                          dropdownColor: AurealColors.carbon,
                          hint: Text('Select Gender', style: TextStyle(color: AurealColors.stardust)),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                          items: ['Male', 'Female', 'Non-Binary', 'Prefer not to say'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: GoogleFonts.inter(color: Colors.white)),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setDialogState(() {
                              selectedGender = newValue;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  
                  await stateService.saveUserProfile(
                    name: newName.isNotEmpty ? newName : (stateService.userName ?? 'User'),
                    dob: stateService.userDob ?? DateTime.now(),
                    location: locationController.text.trim(),
                    currentLocation: stateService.userCurrentLocation,
                    gender: selectedGender,
                    voiceId: stateService.selectedVoiceId,
                    phone: phoneController.text.trim(),
                    email: emailController.text.trim(),
                  );
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated successfully.')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AurealColors.plasmaCyan,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Save Changes'),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AurealColors.stardust),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24)
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AurealColors.plasmaCyan)
        ),
        fillColor: Colors.white.withOpacity(0.05),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
  Future<void> _resetBond() async {
    final emotionalService = await EmotionalStateService.create();
    await emotionalService.setMood(0.0);
    ref.invalidate(bondEngineProvider);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bond reset to Neutral.')),
      );
    }
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildBondEngineSection(String bondState) {
    // Map bondState to slider value (0-100)
    double sliderValue = bondState == 'cooled' ? 16.5 : (bondState == 'warm' ? 83.5 : 50.0);
    
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AurealColors.carbon,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Current State:', style: GoogleFonts.inter(color: Colors.white70)),
                Text(
                  bondState.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    color: _getBondColor(bondState == 'warm' ? BondState.warm : (bondState == 'cooled' ? BondState.cooled : BondState.neutral)),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Slider
            StatefulBuilder(
              builder: (context, setSliderState) {
                return Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: _getBondColor(
                          sliderValue < 33.3 ? BondState.cooled : (sliderValue > 66.6 ? BondState.warm : BondState.neutral),
                        ),
                        inactiveTrackColor: Colors.white10,
                        thumbColor: Colors.white,
                        overlayColor: _getBondColor(
                          sliderValue < 33.3 ? BondState.cooled : (sliderValue > 66.6 ? BondState.warm : BondState.neutral),
                        ).withOpacity(0.2),
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      ),
                      child: Slider(
                        value: sliderValue,
                        min: 0,
                        max: 100,
                        divisions: 100,
                        onChanged: (value) {
                          setSliderState(() {
                            sliderValue = value;
                          });
                        },
                        onChangeEnd: (value) async {
                          // Determine new state based on slider value
                          String newState;
                          if (value < 33.3) {
                            newState = 'cooled';
                          } else if (value > 66.6) {
                            newState = 'warm';
                          } else {
                            newState = 'neutral';
                          }
                          
                          // Set bond state with actual slider value
                          await _setBondStateWithValue(newState, value);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'COOLED',
                          style: GoogleFonts.inter(
                            color: _getBondColor(BondState.cooled),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'NEUTRAL',
                          style: GoogleFonts.inter(
                            color: _getBondColor(BondState.neutral),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'WARM',
                          style: GoogleFonts.inter(
                            color: _getBondColor(BondState.warm),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
  }

  Future<void> _setBondState(String newState) async {
    final emotionalService = await EmotionalStateService.create();
    
    double moodValue;
    switch (newState) {
      case 'cooled':
        moodValue = 20.0; // Deeply Upset/Down
        break;
      case 'warm':
        moodValue = 80.0; // Good/Elated
        break;
      case 'neutral':
      default:
        moodValue = 50.0; // Neutral
    }
    
    await emotionalService.setMood(moodValue);
    ref.invalidate(bondEngineProvider);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bond state set to ${newState.toUpperCase()}')),
      );
    }
  }

  Future<void> _setBondStateWithValue(String newState, double sliderValue) async {
    final emotionalService = await EmotionalStateService.create();
    
    // Map slider value (0-100) to mood (0-100) reasonably directly but keeping the bands
    // 0-33 = Cooled (0-40 mood)
    // 33-66 = Neutral (40-60 mood)
    // 66-100 = Warm (60-100 mood)
    
    // Simple mapping:
    await emotionalService.setMood(sliderValue);
    ref.invalidate(bondEngineProvider);
  }

  Widget _buildPersonalitySection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: PersonalityService.archetypes.length,
              itemBuilder: (context, index) {
                final archetype = PersonalityService.archetypes[index];
                final isSelected = _selectedPersonalityId == archetype.id;
                
                return GestureDetector(
                  onTap: () async {
                    setState(() => _selectedPersonalityId = archetype.id);
                    ref.read(feedbackServiceProvider).medium();
                    
                    // Save
                    final state = await OnboardingStateService.create();
                    await state.setPersonalityId(archetype.id);
                  },
                  child: Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? AurealColors.hyperGold.withOpacity(0.1) : AurealColors.carbon,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AurealColors.hyperGold : Colors.white10,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isSelected ? AurealColors.hyperGold : Colors.white10,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.brainCircuit,
                                size: 16,
                                color: isSelected ? Colors.black : Colors.white70,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                _showPersonalityInfo(archetype);
                              },
                              child: Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          archetype.name,
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          archetype.subtitle,
                          style: GoogleFonts.inter(
                            color: isSelected ? AurealColors.hyperGold : Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showPersonalityInfo(PersonalityArchetype archetype) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AurealColors.carbon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(LucideIcons.brainCircuit, color: AurealColors.plasmaCyan),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                archetype.name,
                style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(archetype.subtitle, style: GoogleFonts.inter(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildInfoRow('Vibe', archetype.vibe),
            const SizedBox(height: 12),
            _buildInfoRow('Traits', archetype.traits),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                archetype.description,
                style: GoogleFonts.inter(color: Colors.white70, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AurealColors.hyperGold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(color: Colors.white54, fontSize: 10, letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(color: Colors.white)),
      ],
    );
  }

  Widget _buildLocationToggle() {
    return Row(
      children: [
        Expanded(
          child: _buildSegmentButton(
            'Current Location',
            _localVibeSettings.useCurrentLocation,
            () => _updateLocalVibeSettings(_localVibeSettings.copyWith(useCurrentLocation: true)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSegmentButton(
            'Specific Cities',
            !_localVibeSettings.useCurrentLocation,
            () => _updateLocalVibeSettings(_localVibeSettings.copyWith(useCurrentLocation: false)),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentButton(String label, bool isSelected, VoidCallback onTap) {
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

  Widget _buildRadiusSlider() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AurealColors.carbon,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Search Radius', style: GoogleFonts.inter(color: Colors.white70)),
                Text(
                  '${_localVibeSettings.radiusMiles.toInt()} miles',
                  style: GoogleFonts.inter(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AurealColors.plasmaCyan,
                inactiveTrackColor: Colors.white10,
                thumbColor: Colors.white,
                overlayColor: AurealColors.plasmaCyan.withOpacity(0.2),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: _localVibeSettings.radiusMiles,
                min: 1,
                max: 50,
                divisions: 49,
                onChanged: (val) => _updateLocalVibeSettings(_localVibeSettings.copyWith(radiusMiles: val)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityInput() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_localVibeSettings.targetCities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _localVibeSettings.targetCities.map((city) => Chip(
                  label: Text(city, style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                  backgroundColor: AurealColors.plasmaCyan.withOpacity(0.2),
                  deleteIcon: const Icon(LucideIcons.x, size: 14, color: AurealColors.plasmaCyan),
                  onDeleted: () {
                    final updated = List<String>.from(_localVibeSettings.targetCities)..remove(city);
                    _updateLocalVibeSettings(_localVibeSettings.copyWith(targetCities: updated));
                  },
                  side: const BorderSide(color: AurealColors.plasmaCyan),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                )).toList(),
              ),
            ),
          if (_localVibeSettings.targetCities.length < 5)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AurealColors.carbon,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _cityController,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add city (e.g. Brooklyn, NY)',
                        hintStyle: GoogleFonts.inter(color: Colors.white30),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _addCity(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(LucideIcons.plusCircle, color: AurealColors.plasmaCyan),
                  onPressed: _addCity,
                  style: IconButton.styleFrom(
                    backgroundColor: AurealColors.carbon,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _addCity() {
    final city = _cityController.text.trim();
    if (city.isNotEmpty && !_localVibeSettings.targetCities.contains(city)) {
      final updated = List<String>.from(_localVibeSettings.targetCities)..add(city);
      _updateLocalVibeSettings(_localVibeSettings.copyWith(targetCities: updated));
      _cityController.clear();
    }
  }

  Widget _buildCategoryChips() {
    final allCategories = {
      ..._localVibeSettings.activeCategories,
      ..._suggestedLocalVibeCategories,
    }.toList();

    // Determine items to show
    final showCount = _showAllVibeCategories ? allCategories.length : 6;
    final displayItems = allCategories.take(showCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: displayItems.map((category) {
            final isSelected = _localVibeSettings.activeCategories.contains(category);
            return _buildCategoryChip(
              category,
              isSelected,
              () {
                final updated = List<String>.from(_localVibeSettings.activeCategories);
                if (isSelected) {
                  updated.remove(category);
                } else {
                  updated.add(category);
                }
                _updateLocalVibeSettings(_localVibeSettings.copyWith(activeCategories: updated));
              },
            );
          }).toList(),
        ),
        
        // Show More / Less button
        if (allCategories.length > 6)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: GestureDetector(
              onTap: () {
                setState(() => _showAllVibeCategories = !_showAllVibeCategories);
              },
              child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 decoration: BoxDecoration(
                   color: AurealColors.carbon,
                   borderRadius: BorderRadius.circular(20),
                   border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.5)),
                 ),
                 child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showAllVibeCategories ? 'Show Less' : 'Show All (${allCategories.length})',
                      style: GoogleFonts.inter(
                        color: AurealColors.plasmaCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showAllVibeCategories ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: AurealColors.plasmaCyan,
                      size: 16,
                    ),
                  ],
                 ),
              ),
            ),
          ),
      ],
    );
  }



  Widget _buildCustomCategoryInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Custom Categories (${_localVibeSettings.customCategories.length}/5)', style: GoogleFonts.inter(color: Colors.white70)),
        const SizedBox(height: 12),
        if (_localVibeSettings.customCategories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _localVibeSettings.customCategories.map((cat) => Chip(
                label: Text(cat, style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                backgroundColor: AurealColors.plasmaCyan.withOpacity(0.2),
                deleteIcon: const Icon(LucideIcons.x, size: 14, color: AurealColors.plasmaCyan),
                onDeleted: () {
                  final updated = List<String>.from(_localVibeSettings.customCategories)..remove(cat);
                  _updateLocalVibeSettings(_localVibeSettings.copyWith(customCategories: updated));
                },
                side: const BorderSide(color: AurealColors.plasmaCyan),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              )).toList(),
            ),
          ),
        if (_localVibeSettings.customCategories.length < 5)
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AurealColors.carbon,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: _localVibeCategoryController,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add custom (e.g. Jazz Clubs)',
                      hintStyle: GoogleFonts.inter(color: Colors.white30),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _addCustomCategory(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.plusCircle, color: AurealColors.plasmaCyan),
                onPressed: _addCustomCategory,
                style: IconButton.styleFrom(
                  backgroundColor: AurealColors.carbon,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _addCustomCategory() {
    final cat = _localVibeCategoryController.text.trim();
    if (cat.isNotEmpty && !_localVibeSettings.customCategories.contains(cat)) {
      final updated = List<String>.from(_localVibeSettings.customCategories)..add(cat);
      _updateLocalVibeSettings(_localVibeSettings.copyWith(customCategories: updated));
      _localVibeCategoryController.clear();
    }
  }

  Future<void> _updateLocalVibeSettings(LocalVibeSettings settings) async {
    setState(() => _localVibeSettings = settings);
    try {
      final webSearchService = ref.read(webSearchServiceProvider);
      final service = await LocalVibeService.create(webSearchService);
      await service.updateSettings(settings);
    } catch (e) {
      debugPrint('Error saving local vibe settings: $e');
    }
  }

  Widget _buildBrainSliders() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurealColors.carbon,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _buildBrainSlider('Creativity', _brainCreativity, (val) => _brainCreativity = val),
          const SizedBox(height: 16),
          _buildBrainSlider('Empathy', _brainEmpathy, (val) => _brainEmpathy = val),
          const SizedBox(height: 16),
          _buildBrainSlider('Humor', _brainHumor, (val) => _brainHumor = val),
        ],
      ),
    );
  }

  Widget _buildBrainSlider(String label, double value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
            Text('${(value * 100).toInt()}%', style: GoogleFonts.inter(color: AurealColors.plasmaCyan)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AurealColors.plasmaCyan,
            inactiveTrackColor: Colors.white10,
            thumbColor: Colors.white,
            overlayColor: AurealColors.plasmaCyan.withOpacity(0.2),
            trackHeight: 2,
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              setState(() => onChanged(val));
            },
            onChangeEnd: (val) async {
               HapticFeedback.lightImpact();
               final service = await OnboardingStateService.create();
               if (label == 'Creativity') await service.setBrainCreativity(val);
               if (label == 'Empathy') await service.setBrainEmpathy(val);
               if (label == 'Humor') await service.setBrainHumor(val);
            },
          ),
        ),
      ],
    );
  }


  Widget _buildEmergencyTile() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A1010), // Dark Red
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.alertTriangle, color: Colors.red),
        ),
        title: Text(
          'Emergency Services',
          style: GoogleFonts.inter(
            color: Colors.red[100],
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Get help immediately',
          style: GoogleFonts.inter(
            color: Colors.red[200]!.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.red[200]),
        onTap: () {
           Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EmergencyScreen()),
          );
        },
      ),
    );
  }
}


