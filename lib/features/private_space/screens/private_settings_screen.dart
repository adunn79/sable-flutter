import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/aeliana_theme.dart';
import '../../../features/settings/widgets/settings_section.dart';
import '../../../features/settings/widgets/promo_code_dialog.dart';
import '../../../core/promo/promo_models.dart'; // For RewardTypeExtension
import '../models/private_user_persona.dart';
import '../widgets/private_avatar_picker.dart';

class PrivateSettingsScreen extends ConsumerStatefulWidget {
  final PrivateUserPersona? currentPersona;
  final Function(PrivateUserPersona) onSave;

  const PrivateSettingsScreen({
    super.key,
    this.currentPersona,
    required this.onSave,
  });

  @override
  ConsumerState<PrivateSettingsScreen> createState() => _PrivateSettingsScreenState();
}

class _PrivateSettingsScreenState extends ConsumerState<PrivateSettingsScreen> {
  // Persona Fields
  late TextEditingController _aliasController;
  late TextEditingController _ageController;
  late TextEditingController _descriptionController;
  String _gender = 'Prefer not to say';
  
  // Personality Tuning
  double _libido = 0.5;
  double _creativity = 0.7;
  double _empathy = 0.8;
  double _humor = 0.6;
  double _intelligence = 0.7;
  
  // Avatar Selection
  String? _selectedAvatarId;

  @override
  void initState() {
    super.initState();
    final p = widget.currentPersona;
    
    _aliasController = TextEditingController(text: p?.aliasName ?? '');
    _ageController = TextEditingController(text: p?.aliasAge?.toString() ?? '21'); // Private default: 21
    _descriptionController = TextEditingController(text: p?.aliasDescription ?? '');
    _gender = p?.aliasGender ?? 'Prefer not to say';
    
    _libido = p?.libido ?? 0.5;
    _creativity = p?.creativity ?? 0.7;
    _empathy = p?.empathy ?? 0.8;
    _humor = p?.humor ?? 0.6;
    _intelligence = p?.intelligence ?? 0.35; // Private default: 35% (-10% from main)
    
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedAvatarId = prefs.getString('private_space_avatar') ?? 'luna';
      // If persona has an avatar ID set, prefer that
      if (widget.currentPersona?.avatarId != null) {
        _selectedAvatarId = widget.currentPersona!.avatarId;
      }
    });
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _ageController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  void _save() {
    if (_aliasController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alias name is required')),
      );
      return;
    }
    
    final newPersona = widget.currentPersona?.copyWith(
      aliasName: _aliasController.text.trim(),
      aliasAge: int.tryParse(_ageController.text.trim()),
      aliasGender: _gender,
      aliasDescription: _descriptionController.text.trim(),
      libido: _libido,
      creativity: _creativity,
      empathy: _empathy,
      humor: _humor,
      avatarId: _selectedAvatarId,
      intelligence: _intelligence,
    ) ?? PrivateUserPersona(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Should rarely happen as we usually pass a persona or create one
      aliasName: _aliasController.text.trim(),
      aliasAge: int.tryParse(_ageController.text.trim()),
      aliasGender: _gender,
      aliasDescription: _descriptionController.text.trim(),
      libido: _libido,
      creativity: _creativity,
      empathy: _empathy,
      humor: _humor,
      avatarId: _selectedAvatarId,
      intelligence: _intelligence,
    );
    
    widget.onSave(newPersona);
    Navigator.pop(context);
  }

  Widget _buildSliderRow(String label, double value, Function(double) onChanged, {Color? activeColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              Text('${(value * 100).toInt()}%', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: activeColor ?? AelianaColors.hyperGold,
            inactiveTrackColor: Colors.white10,
            thumbColor: Colors.white,
            trackHeight: 4,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: value,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      appBar: AppBar(
        backgroundColor: AelianaColors.obsidian,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Private Space Settings',
          style: GoogleFonts.spaceGrotesk(
            color: AelianaColors.hyperGold,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save', style: GoogleFonts.inter(color: AelianaColors.plasmaCyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'ISOLATED SETTINGS',
                style: GoogleFonts.inter(
                  color: Colors.white30,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // 1. Identity Section
            SettingsSection(
              title: null, // Custom implementation above
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Private Persona', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _aliasController,
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Alias / Name',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          prefixIcon: const Icon(LucideIcons.user, color: Colors.white54, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.inter(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Age (Optional)',
                                labelStyle: const TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _gender,
                                  dropdownColor: AelianaColors.carbon,
                                  icon: const Icon(LucideIcons.chevronDown, color: Colors.white54, size: 18),
                                  style: GoogleFonts.inter(color: Colors.white),
                                  onChanged: (val) => setState(() => _gender = val!),
                                  items: ['Male', 'Female', 'Non-binary', 'Prefer not to say', 'Other']
                                      .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Description field
                      TextField(
                        controller: _descriptionController,
                        style: GoogleFonts.inter(color: Colors.white),
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Brief Description (Optional)',
                          hintText: 'e.g., "Adventurous spirit who loves late nights..."',
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          prefixIcon: const Icon(LucideIcons.fileText, color: Colors.white54, size: 18),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            
            // 2. Avatar Selection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('COMPANION AVATAR', style: GoogleFonts.inter(color: AelianaColors.hyperGold, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: PrivateAvatar.all.length,
                itemBuilder: (context, index) {
                  final avatar = PrivateAvatar.all[index];
                  final isSelected = avatar.id == _selectedAvatarId;
                  
                  return GestureDetector(
                    onTap: () async {
                      setState(() => _selectedAvatarId = avatar.id);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('private_space_avatar', avatar.id);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? avatar.accentColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: avatar.accentColor, width: 2) : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: avatar.imagePath != null 
                                  ? DecorationImage(image: AssetImage(avatar.imagePath!), fit: BoxFit.cover)
                                  : null,
                              color: Colors.black26,
                            ),
                            child: avatar.imagePath == null 
                                ? Center(child: Text(avatar.emoji, style: const TextStyle(fontSize: 20)))
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            avatar.name,
                            style: GoogleFonts.spaceGrotesk(
                              color: isSelected ? avatar.accentColor : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 3. Intimacy & Personality Tuning
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                 children: [
                   const Icon(LucideIcons.flame, color: Colors.pinkAccent, size: 18),
                   const SizedBox(width: 8),
                   Text('INTIMACY & DRIVE', style: GoogleFonts.inter(color: Colors.pinkAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                 ],
              ),
            ),
            const SizedBox(height: 8),
            _buildSliderRow(
              'Libido / Passion Level', 
              _libido, 
              (v) => setState(() => _libido = v),
              activeColor: Colors.pinkAccent
            ),
            
            const SizedBox(height: 24),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('COMPANION PERSONALITY (Local)', style: GoogleFonts.inter(color: AelianaColors.hyperGold, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            _buildSliderRow('Intelligence', _intelligence, (v) => setState(() => _intelligence = v), activeColor: AelianaColors.plasmaCyan),
            _buildSliderRow('Creativity', _creativity, (v) => setState(() => _creativity = v)),
            _buildSliderRow('Empathy', _empathy, (v) => setState(() => _empathy = v)),
            _buildSliderRow('Humor', _humor, (v) => setState(() => _humor = v)),
            
            const SizedBox(height: 40),
            
            // Promo Code Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('REWARDS', style: GoogleFonts.inter(color: AelianaColors.hyperGold, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () async {
                  final result = await PromoCodeDialog.show(context, isPrivateSpace: true);
                  if (result != null && result.success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🎉 ${result.rewardGranted?.displayName ?? "Reward"} applied!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AelianaColors.hyperGold.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.gift, color: AelianaColors.hyperGold, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Redeem Private Code',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Icon(LucideIcons.chevronRight, color: Colors.white38, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            Center(
              child: Text(
                'Private Space settings are completely isolated.\nWhat happens here, stays here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white30, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
