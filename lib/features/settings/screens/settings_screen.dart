import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sable/core/services/settings_control_service.dart';
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
import 'package:sable/features/settings/widgets/settings_header.dart';
import 'package:sable/features/settings/widgets/settings_section.dart';
import 'package:sable/features/settings/widgets/settings_tile.dart';
import 'package:sable/core/personality/personality_service.dart';
import 'package:image_picker/image_picker.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _userName = '';
  // Subscription check
  bool _isPremium = false; // TODO: Hook up to real subscription state

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
  bool _zodiacEnabled = false; // Default OFF

  // Feedback Settings
  bool _hapticsEnabled = true;
  bool _soundsEnabled = true;

  // Personality Settings
  String _selectedPersonalityId = 'sassy_realist';
  
  // Avatar Selection
  String _selectedArchetypeId = 'sable';
  int _companionAge = 25; // Default age, range 18-65+
  String? _userPhotoUrl; // User's uploaded profile photo
  
  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';




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

  Future<void> _toggleZodiac(bool value) async {
    final stateService = await OnboardingStateService.create();
    await stateService.setZodiacEnabled(value);
    setState(() => _zodiacEnabled = value);
  }
  bool _permissionCalendar = false;
  bool _permissionReminders = false;
  
  // News Settings
  bool _newsTimingFirstInteraction = true;
  bool _newsTimingOnDemand = false;
  
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController controller = TextEditingController(); // Location controller
  String _manualLocation = '';

  bool _startOnLastTab = false;
  
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
  bool _showNewsOptions = false;
  TimeOfDay _briefingTime = const TimeOfDay(hour: 8, minute: 0);


  Future<void> _selectBriefingTime() async {
    // Premium Cupertino-style picker
    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => Container(
        height: 250,
        color: AurealColors.carbon,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
                  onPressed: () => Navigator.of(modalContext).pop(),
                ),
                CupertinoButton(
                  child: Text('Done', style: GoogleFonts.inter(color: AurealColors.hyperGold, fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.of(modalContext).pop(),
                ),
              ],
            ),
            Expanded(
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: DateTime(2022, 1, 1, _briefingTime.hour, _briefingTime.minute),
                  onDateTimeChanged: (DateTime newTime) {
                    if (mounted) {
                      setState(() {
                        _briefingTime = TimeOfDay(hour: newTime.hour, minute: newTime.minute);
                      });
                    }
                  },
                  backgroundColor: AurealColors.carbon,
                ),
              ),
            ),
          ],
        ),
      ),
    );
     // Note: Saving happens in real-time in the picker or could be moved to 'Done'
     // Just ensuring the state is updated is enough for the UI to reflect it.
     // Actual persistence can happen here if needed:
     final stateService = await OnboardingStateService.create();
     // stateService.setBriefingTime(_briefingTime.format(context));
  }

  void _addCustomTopic() {
    final topic = _topicController.text.trim();
    if (topic.isNotEmpty && _customNewsTopics.length < 5 && !_customNewsTopics.contains(topic)) {
      setState(() {
        _customNewsTopics.add(topic);
        _topicController.clear();
      });
      // Save logic would go here
    }
  }
  
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
  double _userBond = 0.5; // 0=Cooled, 0.5=Neutral, 1.0=Warm
  double _brainIntelligence = 0.5; // Default baseline, can go up to 1.0 for genius level
  
  // Local Vibe Service handle
  LocalVibeService? _localVibeService;
  
  // Custom Avatar Handling
  String? _customAvatarUrl;
  String? _savedAvatarArchetype;

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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    await _voiceService.initialize();
    final stateService = await OnboardingStateService.create();
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _userName = prefs.getString('user_name') ?? '';
      _isPremium = prefs.getBool('is_premium') ?? false; 
      _manualLocation = stateService.userCurrentLocation ?? '';
      _voiceEngine = prefs.getString('voice_engine') ?? 'eleven_labs';
      _apiKeyController.text = prefs.getString('eleven_labs_api_key') ?? '';
      _selectedVoiceId = prefs.getString('selected_voice_id');
      
      // Load Custom Avatar Info
      _customAvatarUrl = stateService.avatarUrl;
      // We assume the stored archetype at load time is the one the avatar belongs to
      _savedAvatarArchetype = stateService.selectedArchetypeId;

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
      _selectedArchetypeId = stateService.selectedArchetypeId;
      _companionAge = stateService.companionAge;
      _zodiacEnabled = stateService.zodiacEnabled;
      
      // Load user photo path
      _userPhotoUrl = prefs.getString('user_photo_path');
      
      // Load Brain Settings
      _brainCreativity = stateService.brainCreativity;
      _brainEmpathy = stateService.brainEmpathy;
      _brainHumor = stateService.brainHumor;
      
      // Load Bond value
      _userBond = prefs.getDouble('user_bond') ?? 0.5;
      
      // Load Intelligence value
      _brainIntelligence = prefs.getDouble('brain_intelligence') ?? 0.5;
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
    return Scaffold(
      backgroundColor: AurealColors.obsidian, 
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          children: [
             // 1. Header
             SettingsHeader(
               userName: _userName,
               avatarUrl: _customAvatarUrl,
               userPhotoUrl: _userPhotoUrl,
               archetypeId: _selectedArchetypeId, 
               isPremium: _isPremium,
               onEditProfile: _showProfileDialog,
               onUserPhotoTap: _pickUserPhoto,
             ),
             
             // 2. Intelligence
             SettingsSection(
               title: 'Companion Intelligence',
               children: [
                 SettingsTile(
                   icon: LucideIcons.sparkles,
                   title: 'Archetype',
                   value: PersonalityService.getById(_selectedArchetypeId).name,
                   onTap: _showArchetypeSelector,
                 ),
                 SettingsTile(
                   icon: LucideIcons.mic,
                   title: 'Voice',
                   value: _selectedVoiceName ?? 'Default',
                   onTap: _showVoiceSelector,
                 ),
                 SettingsTile(
                   icon: LucideIcons.cake,
                   title: 'Companion Age',
                   value: _companionAge >= 65 ? '65+' : '$_companionAge',
                   onTap: _showAgePicker,
                 ),
               ],
             ),
             
             // Personality Tuning
              Padding(
               padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
               child: Align(
                 alignment: Alignment.centerLeft,
                 child: Text(
                    'PERSONALITY TUNING',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AurealColors.ghost),
                 ),
               ),
             ),
             SettingsSection(
                children: [
                   _buildSliderRow('Creativity', _brainCreativity, (v) {
                       setState(() => _brainCreativity = v);
                       OnboardingStateService.create().then((s) => s.setBrainCreativity(v));
                   }),
                   _buildSliderRow('Empathy', _brainEmpathy, (v) {
                       setState(() => _brainEmpathy = v);
                       OnboardingStateService.create().then((s) => s.setBrainEmpathy(v));
                   }),
                    _buildSliderRow('Humor', _brainHumor, (v) {
                       setState(() => _brainHumor = v);
                       OnboardingStateService.create().then((s) => s.setBrainHumor(v));
                   }),
                   _buildBondSliderRow(),
                   _buildIntelligenceSliderRow(),
                ]
             ),
             
             // 3. Daily Life
             SettingsSection(
               title: 'Daily Life',
               children: [
                 SettingsTile(
                   icon: LucideIcons.sun,
                   title: 'Daily Briefing',
                   trailing: Switch(
                     value: _newsEnabled,
                     onChanged: (val) {
                       setState(() => _newsEnabled = val);
                       OnboardingStateService.create().then((s) => s.setNewsEnabled(val));
                     },
                     activeColor: AurealColors.hyperGold,
                   ),
                 ),
                  if (_newsEnabled) ...[
                     SettingsTile(
                       icon: LucideIcons.clock,
                       title: 'Import Time',
                       subtitle: 'Set when news is imported for AI availability',
                       value: _briefingTime.format(context), 
                       onTap: _selectBriefingTime,
                     ),
                     SettingsTile(
                        icon: LucideIcons.sliders,
                        title: 'Customize Content',
                        subtitle: '${_selectedCategories.length + _customNewsTopics.length} topics selected',
                        trailing: Icon(
                          _showNewsOptions ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                          color: Colors.white54,
                          size: 20,
                        ),
                        onTap: () => setState(() => _showNewsOptions = !_showNewsOptions),
                     ),
                     if (_showNewsOptions)
                     Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            Text(
                              'Scope & Reach',
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                _buildScopeChip('World', _selectedCategories.contains('World')),
                                _buildScopeChip('National', _selectedCategories.contains('National')),
                                _buildScopeChip('Regional', _selectedCategories.contains('Local')), 
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Content Focus',
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _allNewsCategories
                                .where((c) => !['World', 'National', 'Local'].contains(c))
                                .map((category) {
                                final isSelected = _selectedCategories.contains(category);
                                return GestureDetector(
                                  onTap: () => _toggleCategory(category),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AurealColors.hyperGold.withOpacity(0.2) : AurealColors.obsidian,
                                      border: Border.all(
                                        color: isSelected ? AurealColors.hyperGold : Colors.white24,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      category,
                                      style: GoogleFonts.inter(
                                        color: isSelected ? AurealColors.hyperGold : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Custom Topics (${_customNewsTopics.length}/5)',
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            if (_customNewsTopics.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _customNewsTopics.map((topic) => Chip(
                                    label: Text(topic, style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                                    backgroundColor: AurealColors.hyperGold.withOpacity(0.2),
                                    deleteIcon: const Icon(LucideIcons.x, size: 14, color: AurealColors.hyperGold),
                                    onDeleted: () {
                                      setState(() {
                                        _customNewsTopics.remove(topic);
                                      });
                                    },
                                    side: const BorderSide(color: AurealColors.hyperGold),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  )).toList(),
                                ),
                              ),
                            if (_customNewsTopics.length < 5)
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: AurealColors.obsidian,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white24),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      alignment: Alignment.centerLeft,
                                      child: TextField(
                                        controller: _topicController,
                                        style: GoogleFonts.inter(color: Colors.white),
                                        decoration: InputDecoration(
                                          hintText: 'Add topic (e.g. SpaceX)',
                                          hintStyle: GoogleFonts.inter(color: Colors.white30),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onSubmitted: (_) => _addCustomTopic(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(LucideIcons.plusCircle, color: AurealColors.hyperGold),
                                    onPressed: _addCustomTopic,
                                    style: IconButton.styleFrom(
                                      backgroundColor: AurealColors.obsidian,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      side: const BorderSide(color: Colors.white24),
                                    ),
                                  ),
                                ],
                              ),
                             const SizedBox(height: 12),
                              Center(
                                child: TextButton(
                                  onPressed: () => setState(() => _showNewsOptions = false),
                                  child: Text('CLOSE OPTIONS', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                                ),
                              ),
                          ],
                        ),
                     ),
                  ],
                  SettingsTile(
                     icon: LucideIcons.mapPin, 
                     title: 'Local Vibe',
                     subtitle: _localVibeSettings.useCurrentLocation 
                         ? 'Current Location (${_localVibeSettings.radiusMiles.toInt()}mi)' 
                         : (_localVibeSettings.targetCities.isNotEmpty 
                             ? _localVibeSettings.targetCities.join(', ') 
                             : 'Not Configured'),
                     onTap: () {
                        if (_localVibeService != null) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => LocalVibeSettingsScreen(service: _localVibeService!)));
                        }
                     },
                   ),
                ],
              ),
              
              // 4. App Experience
              SettingsSection(
                title: 'App Experience',
                children: [
                   SettingsTile(
                     icon: LucideIcons.logIn,
                     title: 'Resume Last Session',
                     subtitle: 'Open app to the last visited screen',
                     trailing: Switch(
                       value: _startOnLastTab,
                       onChanged: (val) {
                         setState(() => _startOnLastTab = val);
                         SettingsControlService.updateSetting('start_on_last_tab', val);
                       },
                       activeColor: AurealColors.hyperGold,
                     ),
                   ),
                   SettingsTile(
                     icon: LucideIcons.lock,
                     title: 'Persistent Memory',
                     subtitle: 'Allow Sable to remember context',
                     trailing: Switch(
                       value: _persistentMemoryEnabled,
                       onChanged: _togglePersistentMemory,
                       activeColor: AurealColors.hyperGold,
                     ),
                   ),
                   SettingsTile(
                     icon: LucideIcons.vibrate,
                     title: 'Haptics',
                     trailing: Switch(
                       value: _hapticsEnabled,
                       onChanged: (v) => setState(() => _hapticsEnabled = v), 
                       activeColor: AurealColors.hyperGold,
                     ),
                   ),
                   SettingsTile(
                     icon: LucideIcons.volume2, 
                     title: 'Sounds',
                     trailing: Switch(
                       value: _soundsEnabled,
                       onChanged: (v) => setState(() => _soundsEnabled = v), 
                       activeColor: AurealColors.hyperGold,
                     ),
                   ),
                ],
              ),
 
              // 5. Account
              SettingsSection(
                 title: 'Account',
                 children: [
                   if (!_isPremium)
                   SettingsTile(
                     icon: LucideIcons.crown,
                     title: 'Upgrade to Sable+',
                     subtitle: 'Unlock unlimited voices & features',
                     iconColor: Colors.purpleAccent,
                     onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                     },
                   ),
                   SettingsTile(
                     icon: LucideIcons.shieldAlert, 
                     title: 'Emergency SOS',
                     iconColor: Colors.red,
                     onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyScreen())); 
                     },
                   ),
                   SettingsTile(
                      icon: LucideIcons.trash2,
                      title: 'Delete Account',
                      isDestructive: true,
                      onTap: () {
                         _showDeleteAccountConfirmation();
                      },
                   ),
                 ],
              ),

             // 6. Debug / Advanced
             SettingsSection(
               title: 'Advanced',
               children: [
                 SettingsTile(
                   icon: LucideIcons.refreshCw,
                   title: 'Restart App',
                   subtitle: 'Reload the application',
                   onTap: () => RestartWidget.restartApp(context),
                 ),
                 SettingsTile(
                   icon: LucideIcons.rotateCcw,
                   title: 'Reset to Onboarding',
                   subtitle: 'Go to setup (keeps memory)',
                   onTap: () async {
                     final prefs = await SharedPreferences.getInstance();
                     await prefs.setBool('onboarding_complete', false);
                     if (context.mounted) {
                       context.go('/onboarding');
                     }
                   },
                 ),
               ],
             ),
             
             // Version
             const SizedBox(height: 32),
             Center(
               child: Text(
                 'Sable v1.0.0 (Build 142)',
                 style: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        // Map 'Regional' label to 'Local' category tag
        final category = label == 'Regional' ? 'Local' : label;
        _toggleCategory(category);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AurealColors.hyperGold.withOpacity(0.2) : AurealColors.obsidian,
          border: Border.all(
            color: isSelected ? AurealColors.hyperGold : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? AurealColors.hyperGold : Colors.white70,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow(String label, double value, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             children: [
               Text(label, style: GoogleFonts.inter(color: AurealColors.stardust, fontSize: 15, fontWeight: FontWeight.w500)),
               const Spacer(),
               Text('${(value * 100).toInt()}%', style: GoogleFonts.inter(color: AurealColors.ghost, fontSize: 13)),
             ],
           ),
           SliderTheme(
             data: SliderThemeData(
               trackHeight: 2,
               thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
               overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
               activeTrackColor: AurealColors.hyperGold,
               inactiveTrackColor: Colors.white10,
               thumbColor: Colors.white,
             ),
             child: Slider(
               value: value,
               onChanged: onChanged,
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildBondSliderRow() {
    String bondLabel = _userBond < 0.33 ? 'Cooled' : (_userBond > 0.66 ? 'Warm' : 'Neutral');
    Color bondColor = _userBond < 0.33 
        ? Colors.blue[300]! 
        : (_userBond > 0.66 ? Colors.orange[300]! : Colors.grey);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             children: [
               Text('User Bond', style: GoogleFonts.inter(color: AurealColors.stardust, fontSize: 15, fontWeight: FontWeight.w500)),
               const Spacer(),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                 decoration: BoxDecoration(
                   color: bondColor.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Text(
                   bondLabel.toUpperCase(),
                   style: GoogleFonts.inter(color: bondColor, fontSize: 11, fontWeight: FontWeight.bold),
                 ),
               ),
             ],
           ),
           SliderTheme(
             data: SliderThemeData(
               trackHeight: 2,
               thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
               overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
               activeTrackColor: bondColor,
               inactiveTrackColor: Colors.white10,
               thumbColor: Colors.white,
             ),
             child: Slider(
               value: _userBond,
               onChanged: (v) async {
                 setState(() => _userBond = v);
                 final prefs = await SharedPreferences.getInstance();
                 await prefs.setDouble('user_bond', v);
               },
             ),
           ),
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text('Cooled', style: GoogleFonts.inter(color: Colors.blue[200], fontSize: 10)),
               Text('Neutral', style: GoogleFonts.inter(color: Colors.grey, fontSize: 10)),
               Text('Warm', style: GoogleFonts.inter(color: Colors.orange[200], fontSize: 10)),
             ],
           ),
        ],
      ),
    );
  }

  Widget _buildIntelligenceSliderRow() {
    // Intelligence ranges from 0.5 (baseline) to 1.0 (genius)
    // Display as percentage where 0.5 = 50% (Average) and 1.0 = 100% (Genius)
    int displayPercent = ((_brainIntelligence - 0.5) * 200).round(); // 0-100% based on range
    String levelLabel = displayPercent < 25 ? 'Average' 
        : (displayPercent < 50 ? 'Sharp' 
        : (displayPercent < 75 ? 'Brilliant' : 'Genius'));
    Color levelColor = displayPercent < 25 ? Colors.grey 
        : (displayPercent < 50 ? Colors.green[300]! 
        : (displayPercent < 75 ? Colors.purple[300]! : AurealColors.hyperGold));
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             children: [
               Text('Intelligence', style: GoogleFonts.inter(color: AurealColors.stardust, fontSize: 15, fontWeight: FontWeight.w500)),
               const Spacer(),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                 decoration: BoxDecoration(
                   color: levelColor.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Icon(LucideIcons.brain, size: 12, color: levelColor),
                     const SizedBox(width: 4),
                     Text(
                       levelLabel.toUpperCase(),
                       style: GoogleFonts.inter(color: levelColor, fontSize: 11, fontWeight: FontWeight.bold),
                     ),
                   ],
                 ),
               ),
             ],
           ),
           SliderTheme(
             data: SliderThemeData(
               trackHeight: 2,
               thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
               overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
               activeTrackColor: levelColor,
               inactiveTrackColor: Colors.white10,
               thumbColor: Colors.white,
             ),
             child: Slider(
               value: _brainIntelligence,
               min: 0.5,
               max: 1.0,
               onChanged: (v) async {
                 setState(() => _brainIntelligence = v);
                 final prefs = await SharedPreferences.getInstance();
                 await prefs.setDouble('brain_intelligence', v);
               },
             ),
           ),
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text('Average', style: GoogleFonts.inter(color: Colors.grey, fontSize: 10)),
               Text('Genius', style: GoogleFonts.inter(color: AurealColors.hyperGold, fontSize: 10)),
             ],
           ),
           // Warning for high intelligence settings
           if (_brainIntelligence > 0.75)
             Padding(
               padding: const EdgeInsets.only(top: 8),
               child: Row(
                 children: [
                   Icon(LucideIcons.alertTriangle, size: 12, color: Colors.orange[300]),
                   const SizedBox(width: 6),
                   Expanded(
                     child: Text(
                       'Higher intelligence may add thinking time to responses',
                       style: GoogleFonts.inter(color: Colors.orange[300], fontSize: 11, fontStyle: FontStyle.italic),
                     ),
                   ),
                 ],
               ),
             ),
        ],
      ),
    );
  }

  void _pickUserPhoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AurealColors.carbon,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Update Profile Photo',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AurealColors.plasmaCyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LucideIcons.camera, color: AurealColors.plasmaCyan),
              ),
              title: Text('Take Photo', style: GoogleFonts.inter(color: Colors.white)),
              subtitle: Text('Use camera', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: ImageSource.camera);
                if (image != null && mounted) {
                  setState(() => _userPhotoUrl = image.path);
                  // Save to preferences
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('user_photo_path', image.path);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Profile photo updated!')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AurealColors.hyperGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LucideIcons.image, color: AurealColors.hyperGold),
              ),
              title: Text('Choose from Library', style: GoogleFonts.inter(color: Colors.white)),
              subtitle: Text('Select existing photo', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                if (image != null && mounted) {
                  setState(() => _userPhotoUrl = image.path);
                  // Save to preferences
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('user_photo_path', image.path);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Profile photo updated!')),
                    );
                  }
                }
              },
            ),
            if (_userPhotoUrl != null) ...[
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.trash2, color: Colors.red),
                ),
                title: Text('Remove Photo', style: GoogleFonts.inter(color: Colors.white)),
                subtitle: Text('Use initials instead', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  setState(() => _userPhotoUrl = null);
                  Navigator.pop(context);
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showAgePicker() {
    int tempAge = _companionAge;
    showModalBottomSheet(
      context: context,
      backgroundColor: AurealColors.carbon,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Companion Age',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set your companion\'s apparent age (18+)',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Text(
                tempAge >= 65 ? '65+' : '$tempAge',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AurealColors.plasmaCyan,
                ),
              ),
              const SizedBox(height: 16),
              Slider(
                value: tempAge.toDouble(),
                min: 18,
                max: 65,
                divisions: 47,
                activeColor: AurealColors.plasmaCyan,
                inactiveColor: Colors.white12,
                label: tempAge >= 65 ? '65+' : '$tempAge',
                onChanged: (value) {
                  setModalState(() => tempAge = value.round());
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('18', style: GoogleFonts.inter(color: Colors.white54)),
                  Text('65+', style: GoogleFonts.inter(color: Colors.white54)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final stateService = await OnboardingStateService.create();
                    await stateService.setCompanionAge(tempAge);
                    setState(() => _companionAge = tempAge);
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AurealColors.plasmaCyan,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Save',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showArchetypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AurealColors.carbon,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Choose Archetype',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select your companion\'s personality',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: PersonalityService.archetypes.length,
                itemBuilder: (context, index) {
                  final archetype = PersonalityService.archetypes[index];
                  final isSelected = archetype.id.toLowerCase() == _selectedArchetypeId.toLowerCase();
                  return GestureDetector(
                    onTap: () async {
                      final stateService = await OnboardingStateService.create();
                      await stateService.setArchetypeId(archetype.id);
                      setState(() {
                        _selectedArchetypeId = archetype.id;
                      });
                      if (mounted) Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? AurealColors.plasmaCyan.withOpacity(0.15) : Colors.black26,
                        border: Border.all(
                          color: isSelected ? AurealColors.plasmaCyan : Colors.white12,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: AurealColors.plasmaCyan.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ] : null,
                      ),
                      child: Row(
                        children: [
                          // Checkmark indicator
                          if (isSelected) ...[
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AurealColors.plasmaCyan,
                              ),
                              child: const Icon(LucideIcons.check, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  archetype.name,
                                  style: GoogleFonts.spaceGrotesk(
                                    color: isSelected ? AurealColors.plasmaCyan : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  archetype.subtitle,
                                  style: GoogleFonts.inter(
                                    color: AurealColors.plasmaCyan,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  archetype.vibe,
                                  style: GoogleFonts.inter(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {List<String> keywords = const []}) {
    // If searching, check if title or keywords match
    if (_searchQuery.isNotEmpty) {
      final matches = title.toLowerCase().contains(_searchQuery) ||
          keywords.any((k) => k.toLowerCase().contains(_searchQuery));
      if (!matches) return const SizedBox.shrink();
    }
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

  /// Check if a setting tile should be visible based on search
  bool _matchesSearch(String title, String subtitle, {List<String> keywords = const []}) {
    if (_searchQuery.isEmpty) return true;
    final lowerTitle = title.toLowerCase();
    final lowerSubtitle = subtitle.toLowerCase();
    return lowerTitle.contains(_searchQuery) ||
        lowerSubtitle.contains(_searchQuery) ||
        keywords.any((k) => k.toLowerCase().contains(_searchQuery));
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

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AurealColors.carbon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: Colors.red[400], size: 24),
            const SizedBox(width: 12),
            Text(
              'Delete Account',
              style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is PERMANENT and cannot be undone.',
              style: GoogleFonts.inter(color: Colors.red[300], fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Deleting your account will:',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text('• Erase all conversation history', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
            Text('• Remove all stored memories', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
            Text('• Delete your journal entries', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
            Text('• Clear all preferences and settings', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 16),
            Text(
              'Your emergency contacts and health data will also be deleted.',
              style: GoogleFonts.inter(color: Colors.orange[300], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteAccount();
            },
            child: Text('Continue', style: GoogleFonts.inter(color: Colors.red[400], fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AurealColors.carbon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Are you absolutely sure?',
          style: GoogleFonts.spaceGrotesk(color: Colors.red[400], fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Type "DELETE" to confirm permanent account deletion.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Implement actual account deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deletion is not yet implemented.')),
              );
            },
            child: Text('DELETE MY ACCOUNT', style: GoogleFonts.inter(color: Colors.red[400], fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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

  Widget _buildDayChip(String day, bool isActive) {
    return GestureDetector(
      onTap: () {
        ref.read(buttonSoundServiceProvider).playMediumTap();
        // TODO: Toggle day active state
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? AurealColors.hyperGold.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: isActive ? AurealColors.hyperGold : Colors.white24,
            width: 1.5,
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            day,
            style: GoogleFonts.inter(
              color: isActive ? AurealColors.hyperGold : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
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


