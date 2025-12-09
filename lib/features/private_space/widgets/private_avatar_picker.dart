import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/aeliana_theme.dart';

/// Private Space avatar data
/// NEVER visible in main app archetype picker
class PrivateAvatar {
  final String id;
  final String name;
  final String gender; // 'female', 'male', 'non-binary'
  final String emoji;
  final String tagline;
  final String description;
  final Color accentColor;
  final String? imagePath; // Photorealistic avatar image

  const PrivateAvatar({
    required this.id,
    required this.name,
    required this.gender,
    required this.emoji,
    required this.tagline,
    required this.description,
    required this.accentColor,
    this.imagePath,
  });

  static const List<PrivateAvatar> all = [
    PrivateAvatar(
      id: 'luna',
      name: 'Luna',
      gender: 'female',
      emoji: '🌙',
      tagline: 'Mysterious & Alluring',
      description: 'A moonlit enchantress with an air of mystery. Luna speaks in whispers and knows the secrets of the night.',
      accentColor: Color(0xFF9C6ADE),
      imagePath: 'assets/private_avatars/luna.png',
    ),
    PrivateAvatar(
      id: 'dante',
      name: 'Dante',
      gender: 'male',
      emoji: '🔥',
      tagline: 'Bold & Passionate',
      description: 'Confident and intense, Dante brings fire and depth to every conversation. A romantic soul with poetic tendencies.',
      accentColor: Color(0xFFE85D4C),
      imagePath: 'assets/private_avatars/dante.png',
    ),
    PrivateAvatar(
      id: 'storm',
      name: 'Storm',
      gender: 'non-binary',
      emoji: '⚡',
      tagline: 'Fierce & Electric',
      description: 'Untamed energy wrapped in enigma. Storm defies expectations and brings electric intensity to every moment.',
      accentColor: Color(0xFF4ECDC4),
      imagePath: 'assets/private_avatars/storm.png',
    ),
  ];

  static PrivateAvatar? getById(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Widget to pick a Private Space avatar
class PrivateAvatarPicker extends StatelessWidget {
  final String? selectedAvatarId;
  final Function(PrivateAvatar) onSelect;

  const PrivateAvatarPicker({
    super.key,
    this.selectedAvatarId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Companion',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select a companion or design your own (coming soon)',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 16),
        ...PrivateAvatar.all.map((avatar) => _buildAvatarCard(avatar)),
        const SizedBox(height: 8),
        // Design Your Own (Coming Soon)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AelianaColors.carbon.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white24,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white10,
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: Center(
                  child: Icon(LucideIcons.plus, color: Colors.white38, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Design Your Own',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AelianaColors.hyperGold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Coming Soon',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AelianaColors.hyperGold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create a custom companion with your own style preferences',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarCard(PrivateAvatar avatar) {
    final isSelected = selectedAvatarId == avatar.id;

    return GestureDetector(
      onTap: () => onSelect(avatar),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? avatar.accentColor.withOpacity(0.15)
              : AelianaColors.carbon,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? avatar.accentColor 
                : AelianaColors.plasmaCyan.withOpacity(0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Avatar photo or emoji fallback
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatar.accentColor.withOpacity(0.2),
                border: Border.all(
                  color: avatar.accentColor.withOpacity(0.5),
                  width: 2,
                ),
                image: avatar.imagePath != null
                    ? DecorationImage(
                        image: AssetImage(avatar.imagePath!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: avatar.imagePath == null
                  ? Center(child: Text(avatar.emoji, style: const TextStyle(fontSize: 28)))
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        avatar.name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: avatar.accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          avatar.gender,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: avatar.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    avatar.tagline,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: avatar.accentColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    avatar.description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Selection indicator
            if (isSelected)
              Icon(LucideIcons.check, color: avatar.accentColor, size: 24),
          ],
        ),
      ),
    );
  }
}
