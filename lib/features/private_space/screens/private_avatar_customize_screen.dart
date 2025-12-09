import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/voice/voice_service.dart';
import 'package:sable/core/voice/elevenlabs_api_service.dart';
import 'package:sable/features/common/widgets/cascading_voice_selector.dart';
import 'package:sable/features/onboarding/models/avatar_config.dart';
import 'package:sable/features/onboarding/services/avatar_generation_service.dart';
import '../widgets/private_avatar_picker.dart';

/// Private Space Avatar Customization Screen
/// Isolated from main app - settings stored separately with 'private_space_' prefix
class PrivateAvatarCustomizeScreen extends StatefulWidget {
  final PrivateAvatar selectedAvatar;
  final VoidCallback onComplete;
  
  const PrivateAvatarCustomizeScreen({
    super.key,
    required this.selectedAvatar,
    required this.onComplete,
  });
  
  @override
  State<PrivateAvatarCustomizeScreen> createState() => _PrivateAvatarCustomizeScreenState();
}

class _PrivateAvatarCustomizeScreenState extends State<PrivateAvatarCustomizeScreen> {
  final AvatarGenerationService _avatarService = AvatarGenerationService();
  final VoiceService _voiceService = VoiceService();
  
  // Avatar customization fields - PRIVATE SPACE ISOLATED
  int _apparentAge = 28;
  String _origin = 'United States, California';
  String _race = 'Sable (Synthetic Human)';
  String _gender = 'Female';
  String _build = 'Athletic';
  String _skinTone = 'Golden/Tan';
  String? _selectedVoiceId;
  List<VoiceWithMetadata> _availableVoices = [];
  bool _isLoadingVoices = false;
  bool _isGenerating = false;
  bool _showAdvanced = false;
  
  @override
  void initState() {
    super.initState();
    _initFromSelectedAvatar();
    _loadVoices();
  }
  
  void _initFromSelectedAvatar() {
    // Set defaults based on selected avatar
    switch (widget.selectedAvatar.id) {
      case 'luna':
        _gender = 'Female';
        _race = 'Caucasian / White';
        _apparentAge = 26;
        break;
      case 'dante':
        _gender = 'Male';
        _race = 'Black / African American';
        _apparentAge = 32;
        break;
      case 'storm':
        _gender = 'Non-binary';
        _race = 'Mixed Heritage';
        _apparentAge = 25;
        break;
    }
    setState(() {});
  }
  
  Future<void> _loadVoices() async {
    setState(() => _isLoadingVoices = true);
    try {
      await _voiceService.initialize();
      final voices = await _voiceService.getAllVoices();
      if (mounted) {
        setState(() {
          _availableVoices = voices;
          _isLoadingVoices = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading voices: $e');
      if (mounted) setState(() => _isLoadingVoices = false);
    }
  }
  
  Future<void> _saveAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save avatar config to PRIVATE SPACE isolated storage
    final config = AvatarConfig(
      archetype: widget.selectedAvatar.name,
      gender: _gender,
      apparentAge: _apparentAge,
      origin: _origin,
      race: _race,
      build: _build,
      skinTone: _skinTone,
      eyeColor: 'Default',
      hairStyle: 'Default',
      fashionAesthetic: 'Casual',
      distinguishingMark: 'None',
      selectedVoiceId: _selectedVoiceId,
    );
    
    // Store with private_space_ prefix for isolation
    await prefs.setString('private_space_avatar_config', config.toJsonString());
    await prefs.setString('private_space_avatar', widget.selectedAvatar.id);
    
    // Store voice separately for easy access
    if (_selectedVoiceId != null) {
      await prefs.setString('private_space_voice_id', _selectedVoiceId!);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ ${widget.selectedAvatar.name} is ready for you!'),
          backgroundColor: widget.selectedAvatar.accentColor.withOpacity(0.9),
        ),
      );
    }
    
    widget.onComplete();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Customize ${widget.selectedAvatar.name}',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Preview
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.selectedAvatar.accentColor,
                            width: 3,
                          ),
                          image: widget.selectedAvatar.imagePath != null
                              ? DecorationImage(
                                  image: AssetImage(widget.selectedAvatar.imagePath!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: widget.selectedAvatar.imagePath == null
                            ? Center(child: Text(widget.selectedAvatar.emoji, style: const TextStyle(fontSize: 48)))
                            : null,
                      ).animate().scale(delay: 100.ms, duration: 400.ms),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Name
                    Center(
                      child: Text(
                        widget.selectedAvatar.name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: widget.selectedAvatar.accentColor,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Center(
                      child: Text(
                        widget.selectedAvatar.tagline,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white60,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Quick Customize Section
                    _buildSectionHeader('Basic Settings'),
                    const SizedBox(height: 16),
                    
                    // Age Slider
                    _buildLabel('Apparent Age: $_apparentAge'),
                    Slider(
                      value: _apparentAge.toDouble(),
                      min: 21,
                      max: 55,
                      divisions: 34,
                      activeColor: widget.selectedAvatar.accentColor,
                      inactiveColor: AelianaColors.carbon,
                      onChanged: (value) => setState(() => _apparentAge = value.toInt()),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Race/Ethnicity
                    _buildLabel('Race / Ethnicity'),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: _race,
                      items: [
                        'Sable (Synthetic Human)',
                        'Caucasian / White',
                        'Black / African American',
                        'Asian',
                        'Latino / Hispanic',
                        'Native American / Indigenous',
                        'Middle Eastern',
                        'South Asian (Indian)',
                        'Pacific Islander',
                        'Mixed Heritage',
                      ],
                      onChanged: (v) => setState(() => _race = v ?? _race),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Voice Selection
                    _buildSectionHeader('Voice'),
                    const SizedBox(height: 16),
                    _buildVoiceSelection(),
                    
                    const SizedBox(height: 24),
                    
                    // Advanced Options (collapsed)
                    GestureDetector(
                      onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                      child: Row(
                        children: [
                          Icon(
                            _showAdvanced ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                            color: AelianaColors.hyperGold,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Advanced Options',
                            style: GoogleFonts.spaceGrotesk(
                              color: AelianaColors.hyperGold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    if (_showAdvanced) ...[
                      const SizedBox(height: 16),
                      
                      // Origin/Accent
                      _buildLabel('Origin (Accent)'),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        value: _origin,
                        items: [
                          'United States, California',
                          'United States, New York',
                          'United Kingdom, London',
                          'Ireland, Dublin',
                          'France, Paris',
                          'Germany, Berlin',
                          'Russia, Moscow',
                          'Japan, Tokyo',
                          'South Korea, Seoul',
                          'Australia, Sydney',
                          'Brazil, São Paulo',
                          'India, Mumbai',
                        ],
                        onChanged: (v) => setState(() => _origin = v ?? _origin),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Build
                      _buildLabel('Build'),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        value: _build,
                        items: ['Petite', 'Athletic', 'Curvy', 'Lean/Tall', 'Average'],
                        onChanged: (v) => setState(() => _build = v ?? _build),
                      ),
                    ],
                    
                    const SizedBox(height: 100), // Space for button
                  ],
                ),
              ),
            ),
            
            // Continue Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AelianaColors.obsidian,
                border: Border(top: BorderSide(color: AelianaColors.carbon)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveAndContinue,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: widget.selectedAvatar.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Continue to Chat',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.spaceGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AelianaColors.hyperGold,
        letterSpacing: 1.5,
      ),
    );
  }
  
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: Colors.white70,
      ),
    );
  }
  
  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AelianaColors.carbon,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AelianaColors.ghost.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          dropdownColor: AelianaColors.carbon,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          icon: const Icon(Icons.keyboard_arrow_down, color: AelianaColors.ghost),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
  
  Widget _buildVoiceSelection() {
    if (_isLoadingVoices) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AelianaColors.plasmaCyan),
        ),
      );
    }
    
    if (_availableVoices.isEmpty) {
      return _buildVoiceFallback('Loading voices... Check your connection.');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CascadingVoiceSelector(
          voices: _availableVoices,
          selectedVoiceId: _selectedVoiceId,
          onVoiceSelected: (voiceId) => setState(() => _selectedVoiceId = voiceId),
          onPlayPreview: () async {
            if (_selectedVoiceId != null) {
              await _voiceService.setVoice(_selectedVoiceId!);
              await _voiceService.speak("Hello, I'm excited to explore this private sanctuary with you.");
            }
          },
        ),
        const SizedBox(height: 12),
        // Skip option
        GestureDetector(
          onTap: () => setState(() => _selectedVoiceId = null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _selectedVoiceId == null 
                  ? widget.selectedAvatar.accentColor.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _selectedVoiceId == null 
                    ? widget.selectedAvatar.accentColor 
                    : Colors.white24,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedVoiceId == null ? LucideIcons.checkCircle : LucideIcons.circle,
                  color: _selectedVoiceId == null 
                      ? widget.selectedAvatar.accentColor 
                      : Colors.white38,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Use app default voice (can change in settings)',
                    style: GoogleFonts.inter(
                      color: _selectedVoiceId == null ? Colors.white : Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildVoiceFallback(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AelianaColors.carbon,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            '✓ Will use app default voice.\nYou can change voice anytime in Settings.',
            style: GoogleFonts.inter(
              color: widget.selectedAvatar.accentColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
