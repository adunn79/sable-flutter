import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/widgets/active_avatar_ring.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SettingsHeader extends StatelessWidget {
  final String userName;
  final String? avatarUrl; // AI companion's avatar URL
  final String? userPhotoUrl; // User's uploaded photo URL
  final String archetypeId; // For AI fallback asset
  final bool isPremium;
  final VoidCallback onEditProfile;
  final VoidCallback? onUserPhotoTap; // Callback for user photo upload

  const SettingsHeader({
    super.key,
    required this.userName,
    this.avatarUrl,
    this.userPhotoUrl,
    required this.archetypeId,
    required this.isPremium,
    required this.onEditProfile,
    this.onUserPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    // Get safe area padding to avoid notch/status bar
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Column(
      children: [
        // Account for status bar + extra padding
        SizedBox(height: topPadding + 20),
        
        // Side-by-side avatars showing companionship
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // User's avatar (left) - tappable for upload
            Column(
              children: [
                GestureDetector(
                  onTap: onUserPhotoTap,
                  child: Stack(
                    children: [
                      _buildUserAvatar(),
                      // Camera icon overlay
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AelianaColors.hyperGold,
                            shape: BoxShape.circle,
                            border: Border.all(color: AelianaColors.carbon, width: 2),
                          ),
                          child: const Icon(LucideIcons.camera, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  userName.isNotEmpty ? userName : 'You',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            
            // Connection indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Icon(Icons.favorite, color: AelianaColors.hyperGold.withOpacity(0.6), size: 16),
                  const SizedBox(height: 4),
                  Container(
                    width: 40,
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AelianaColors.hyperGold.withOpacity(0.3),
                          AelianaColors.plasmaCyan.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // AI Companion's avatar (right)
            Column(
              children: [
                _buildCompanionAvatar(),
                const SizedBox(height: 8),
                Text(
                  _getCompanionName(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AelianaColors.plasmaCyan,
                  ),
                ),
                // Pronunciation for Aeliana
                if (archetypeId.toLowerCase() == 'aeliana')
                  Text(
                    '(Ay-lee-AH-na)',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AelianaColors.ghost,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Premium badge
        if (isPremium)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AelianaColors.hyperGold,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'PLUS MEMBER',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        
        // Edit Button
        TextButton(
          onPressed: onEditProfile,
          child: Text(
            'Edit Profile',
            style: GoogleFonts.inter(
              color: AelianaColors.plasmaCyan,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserAvatar() {
    final initials = _getInitials(userName);
    
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AelianaColors.hyperGold, width: 2),
        boxShadow: [
          BoxShadow(
            color: AelianaColors.hyperGold.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: _buildUserImage(initials),
      ),
    );
  }

  Widget _buildUserImage(String initials) {
    if (userPhotoUrl == null || userPhotoUrl!.isEmpty) {
      return _buildInitialsPlaceholder(initials);
    }
    
    // Check if it's a local file path or network URL
    if (userPhotoUrl!.startsWith('http')) {
      return Image.network(
        userPhotoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _buildInitialsPlaceholder(initials),
      );
    } else {
      // Local file path
      return Image.file(
        File(userPhotoUrl!),
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _buildInitialsPlaceholder(initials),
      );
    }
  }

  Widget _buildInitialsPlaceholder(String initials) {
    return Container(
      color: AelianaColors.carbon,
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AelianaColors.hyperGold,
          ),
        ),
      ),
    );
  }

  Widget _buildCompanionAvatar() {
    return ActiveAvatarRing(
      size: 84, // Slightly larger to accommodate ring
      isActive: false, // Settings screen doesn't have active state
      showRing: true,
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: (avatarUrl != null && avatarUrl!.startsWith('http'))
              ? Image.network(
                  avatarUrl!, 
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => _buildFallbackAsset(),
                )
              : _buildFallbackAsset(),
        ),
      ),
    );
  }

  Widget _buildFallbackAsset() {
    final safeArch = archetypeId.toLowerCase().isNotEmpty ? archetypeId.toLowerCase() : 'sable';
    return Image.asset(
      'assets/images/archetypes/$safeArch.png',
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Container(
        color: AelianaColors.carbon,
        child: Center(
          child: Icon(Icons.person, color: AelianaColors.plasmaCyan, size: 32),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _getCompanionName() {
    // Capitalize first letter of archetype ID as companion name
    if (archetypeId.isEmpty) return 'Companion';
    return archetypeId[0].toUpperCase() + archetypeId.substring(1).toLowerCase();
  }
}
