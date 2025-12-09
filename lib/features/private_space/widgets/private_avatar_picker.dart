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
      id: 'aeliana',
      name: 'Aeliana',
      gender: 'female',
      emoji: '✨',
      tagline: 'The Solar Radiance',
      description: 'Warm, luminous, and genuinely alive. Living technology with a digital soul.',
      accentColor: AelianaColors.hyperGold,
      imagePath: 'assets/images/archetypes/aeliana.png',
    ),
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
    PrivateAvatar(
      id: 'kai',
      name: 'Kai',
      gender: 'male',
      emoji: '🌊',
      tagline: 'The Strategist',
      description: 'Grounded, calm, and protective. A steady presence with a dry sense of humor.',
      accentColor: Color(0xFF4A90E2),
      imagePath: 'assets/images/archetypes/kai.png',
    ),
    PrivateAvatar(
      id: 'echo',
      name: 'Echo',
      gender: 'non-binary',
      emoji: '🌀',
      tagline: 'The Philosopher',
      description: 'Balanced and adaptive. A clean slate that mirrors your energy.',
      accentColor: AelianaColors.stardust,
      imagePath: 'assets/images/archetypes/echo.png',
    ),
    PrivateAvatar(
      id: 'marco',
      name: 'Marco',
      gender: 'male',
      emoji: '🛡️',
      tagline: 'The Guardian',
      description: 'Warm, passionate, and fiercely loyal. Treats you like familia from day one.',
      accentColor: Color(0xFFE57373),
      imagePath: 'assets/images/archetypes/marco.png',
    ),
    PrivateAvatar(
      id: 'sable',
      name: 'Sable',
      gender: 'female',
      emoji: '💜',
      tagline: 'The Empath',
      description: 'Sharp, witty, and deeply empathetic. A charismatic and bold personality.',
      accentColor: Color(0xFF9C27B0),
      imagePath: 'assets/images/archetypes/sable.png',
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
  final VoidCallback? onDesignOwn;

  const PrivateAvatarPicker({
    super.key,
    this.selectedAvatarId,
    required this.onSelect,
    this.onDesignOwn,
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
          'Select a companion or design your own',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 16),
        
        // Design Your Own - AT TOP
        _buildDesignYourOwn(),
        
        const SizedBox(height: 12),
        
        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white24)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR CHOOSE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white38,
                  letterSpacing: 1,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.white24)),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Pre-made avatars
        ...PrivateAvatar.all.map((avatar) => _buildAvatarCard(avatar)),
      ],
    );
  }
  
  Widget _buildDesignYourOwn() {
    return GestureDetector(
          onTap: onDesignOwn,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: onDesignOwn != null ? LinearGradient(
                colors: [
                  AelianaColors.hyperGold.withOpacity(0.15),
                  AelianaColors.plasmaCyan.withOpacity(0.1),
                ],
              ) : null,
              color: onDesignOwn == null ? AelianaColors.carbon.withOpacity(0.5) : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: onDesignOwn != null ? AelianaColors.hyperGold.withOpacity(0.5) : Colors.white24,
                width: onDesignOwn != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: onDesignOwn != null 
                        ? AelianaColors.hyperGold.withOpacity(0.2)
                        : Colors.white10,
                    border: Border.all(
                      color: onDesignOwn != null 
                          ? AelianaColors.hyperGold 
                          : Colors.white24, 
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      LucideIcons.sparkles, 
                      color: onDesignOwn != null 
                          ? AelianaColors.hyperGold 
                          : Colors.white38, 
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Design Your Own',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: onDesignOwn != null 
                              ? AelianaColors.hyperGold 
                              : Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        onDesignOwn != null
                            ? 'Create a custom companion with AI'
                            : 'Select an avatar first, then customize',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: onDesignOwn != null ? Colors.white70 : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDesignOwn != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AelianaColors.hyperGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.chevronRight,
                      color: AelianaColors.hyperGold,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
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
