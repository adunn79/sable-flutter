import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
import 'package:sable/features/onboarding/services/avatar_generation_service.dart';
import 'package:sable/features/onboarding/models/avatar_config.dart';
import 'package:sable/features/settings/screens/avatar_gallery_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dialog shown when user's age has changed significantly (±5 years)
/// Offers options to regenerate avatar, keep current, or browse gallery
class AvatarRegenerationDialog extends StatefulWidget {
  final OnboardingStateService stateService;
  final int ageDirection; // 1 = older, -1 = younger
  final int currentAge;
  final int previousAge;
  final VoidCallback? onComplete;

  const AvatarRegenerationDialog({
    super.key,
    required this.stateService,
    required this.ageDirection,
    required this.currentAge,
    required this.previousAge,
    this.onComplete,
  });

  /// Show the dialog if regeneration should be prompted
  static Future<void> checkAndShow(BuildContext context) async {
    final stateService = await OnboardingStateService.create();
    
    if (!stateService.shouldPromptAvatarRegeneration()) return;
    
    final ageDirection = stateService.getAgeDirection();
    final currentAge = stateService.getCurrentAge();
    final previousAge = stateService.avatarGeneratedAge;
    
    if (currentAge == null || previousAge == null) return;
    
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AvatarRegenerationDialog(
          stateService: stateService,
          ageDirection: ageDirection,
          currentAge: currentAge,
          previousAge: previousAge,
        ),
      );
    }
  }

  @override
  State<AvatarRegenerationDialog> createState() => _AvatarRegenerationDialogState();
}

class _AvatarRegenerationDialogState extends State<AvatarRegenerationDialog> {
  bool _isGenerating = false;
  String? _newAvatarUrl;
  final AvatarGenerationService _generationService = AvatarGenerationService();

  String get _title => widget.ageDirection > 0 
      ? "You've Grown! 🎂" 
      : "Fresh New Look! ✨";

  String get _subtitle => widget.ageDirection > 0
      ? "Your companion can mature with you."
      : "Your companion can match your new vibe.";

  String get _ageChangeText {
    final diff = (widget.currentAge - widget.previousAge).abs();
    return widget.ageDirection > 0
        ? "You're now $diff years older since your avatar was created."
        : "Your profile shows you're $diff years younger now.";
  }

  int get _remainingRegens => 2 - widget.stateService.regenerationCountThisYear;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AelianaColors.carbon,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 340),
        child: _isGenerating 
            ? _buildGeneratingState()
            : _newAvatarUrl != null 
                ? _buildCompareState()
                : _buildPromptState(),
      ),
    );
  }

  Widget _buildPromptState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AelianaColors.plasmaCyan.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.ageDirection > 0 ? LucideIcons.cake : LucideIcons.sparkles,
            color: AelianaColors.plasmaCyan,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        
        // Title
        Text(
          _title,
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        // Subtitle
        Text(
          _subtitle,
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        
        // Age change info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.info, color: AelianaColors.plasmaCyan, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _ageChangeText,
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Remaining regens
        Text(
          '$_remainingRegens regeneration${_remainingRegens == 1 ? '' : 's'} remaining this year',
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 24),
        
        // Action buttons
        Column(
          children: [
            // Regenerate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleRegenerate,
                icon: const Icon(LucideIcons.wand2, size: 18),
                label: const Text('Generate New Avatar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AelianaColors.plasmaCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Browse gallery button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleBrowseGallery,
                icon: const Icon(LucideIcons.image, size: 18),
                label: const Text('Browse Gallery'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Keep current button
            TextButton(
              onPressed: _handleKeepCurrent,
              child: Text(
                'Keep Current Avatar',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGeneratingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: AelianaColors.plasmaCyan),
        const SizedBox(height: 24),
        Text(
          'Creating your new avatar...',
          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'This may take a moment',
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildCompareState() {
    final currentAvatar = widget.stateService.avatarUrl;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Compare Avatars',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Side by side comparison
        Row(
          children: [
            // Old avatar
            Expanded(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildAvatarImage(currentAvatar, 'Previous'),
                  ),
                  const SizedBox(height: 8),
                  Text('Previous', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // New avatar
            Expanded(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AelianaColors.plasmaCyan, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _buildAvatarImage(_newAvatarUrl, 'New'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('New', style: GoogleFonts.inter(color: AelianaColors.plasmaCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Accept new
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _acceptNewAvatar(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AelianaColors.plasmaCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Use New Avatar'),
          ),
        ),
        const SizedBox(height: 12),
        
        // Keep old
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _keepOldAvatar(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Keep Previous'),
          ),
        ),
        const SizedBox(height: 8),
        
        Text(
          'Both avatars saved to gallery',
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildAvatarImage(String? url, String label) {
    if (url == null) {
      return Container(
        height: 120,
        color: Colors.black26,
        child: const Center(child: Icon(LucideIcons.user, color: Colors.white24)),
      );
    }
    
    return url.startsWith('assets/')
        ? Image.asset(url, height: 120, fit: BoxFit.cover)
        : Image.network(
            url, 
            height: 120, 
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 120,
              color: Colors.black26,
              child: const Center(child: Icon(LucideIcons.imageOff, color: Colors.white24)),
            ),
          );
  }

  Future<void> _handleRegenerate() async {
    setState(() => _isGenerating = true);
    
    try {
      // Get current avatar config
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('avatar_config');
      
      AvatarConfig config;
      if (configJson != null) {
        config = AvatarConfig.fromJsonString(configJson);
        // Update apparent age to current age
        config = config.copyWith(apparentAge: widget.currentAge);
      } else {
        // Default config with current age
        config = AvatarConfig(
          archetype: widget.stateService.selectedArchetypeId ?? 'sable',
          gender: 'Female',
          apparentAge: widget.currentAge,
          origin: widget.stateService.aiOrigin ?? 'United States',
          race: 'Caucasian',
          build: 'Athletic',
          skinTone: 'Fair',
          eyeColor: 'Blue',
          hairStyle: 'Default',
          fashionAesthetic: 'Casual',
          distinguishingMark: 'None',
        );
      }
      
      final newUrl = await _generationService.generateAvatarImage(config);
      
      // Save old avatar to gallery before replacing
      final oldUrl = widget.stateService.avatarUrl;
      if (oldUrl != null) {
        await widget.stateService.addToAvatarGallery(oldUrl, archetypeId: config.archetype.toLowerCase());
      }
      
      // Save new avatar to gallery
      await widget.stateService.addToAvatarGallery(newUrl, archetypeId: config.archetype.toLowerCase());
      
      // Increment generation count
      await widget.stateService.incrementRegenerationCount();
      
      setState(() {
        _isGenerating = false;
        _newAvatarUrl = newUrl;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate avatar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handleBrowseGallery() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AvatarGalleryScreen()),
    );
    widget.stateService.dismissAvatarRegenerationPrompt();
  }

  void _handleKeepCurrent() {
    Navigator.pop(context);
    widget.stateService.dismissAvatarRegenerationPrompt();
    widget.onComplete?.call();
  }

  Future<void> _acceptNewAvatar() async {
    await widget.stateService.saveAvatarUrl(_newAvatarUrl!);
    await widget.stateService.setAvatarGeneratedAge(widget.currentAge);
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✨ Avatar updated!'), backgroundColor: Colors.green),
      );
    }
    widget.onComplete?.call();
  }

  Future<void> _keepOldAvatar() async {
    // New avatar is already saved to gallery, just dismiss
    await widget.stateService.dismissAvatarRegenerationPrompt();
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New avatar saved to gallery'), backgroundColor: Colors.blue),
      );
    }
    widget.onComplete?.call();
  }
}
