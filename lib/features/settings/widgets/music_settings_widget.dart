import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/media/unified_music_service.dart';
import 'package:sable/core/media/spotify_service.dart';

/// Music Settings Widget for Settings Screen
/// Allows user to connect/disconnect Spotify and Apple Music
class MusicSettingsWidget extends ConsumerStatefulWidget {
  const MusicSettingsWidget({super.key});

  @override
  ConsumerState<MusicSettingsWidget> createState() => _MusicSettingsWidgetState();
}

class _MusicSettingsWidgetState extends ConsumerState<MusicSettingsWidget> {
  bool _isConnectingSpotify = false;
  bool _isConnectingAppleMusic = false;
  
  @override
  Widget build(BuildContext context) {
    final musicService = ref.watch(unifiedMusicServiceProvider);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AelianaColors.obsidian,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.music, color: AelianaColors.hyperGold, size: 18),
              const SizedBox(width: 8),
              Text(
                'MUSIC INTEGRATION',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Spotify Connection
          _buildServiceRow(
            icon: Icons.music_note,
            iconColor: const Color(0xFF1DB954),
            title: 'Spotify',
            subtitle: musicService.isSpotifyConnected 
                ? 'Connected' 
                : 'Tap to connect',
            isConnected: musicService.isSpotifyConnected,
            isLoading: _isConnectingSpotify,
            onTap: () => _toggleSpotify(musicService),
          ),
          
          const SizedBox(height: 12),
          
          // Apple Music Connection
          _buildServiceRow(
            icon: Icons.music_note,
            iconColor: const Color(0xFFFC3C44),
            title: 'Apple Music',
            subtitle: musicService.isAppleMusicConnected 
                ? 'Connected' 
                : 'Coming soon',
            isConnected: musicService.isAppleMusicConnected,
            isLoading: _isConnectingAppleMusic,
            onTap: () => _showAppleMusicInfo(),
            enabled: false, // Apple Music coming soon
          ),
          
          const SizedBox(height: 16),
          
          // Now Playing Indicator
          if (musicService.currentTrack != null) ...[
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),
            _buildNowPlayingRow(musicService),
          ],
          
          // Music features info
          const SizedBox(height: 12),
          Text(
            'Connected services show music in mini-player and track listening history for your journal.',
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildServiceRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isConnected,
    required bool isLoading,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled && !isLoading ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isConnected 
              ? iconColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isConnected 
                ? iconColor.withValues(alpha: 0.4)
                : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: enabled ? Colors.white : Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: isConnected ? iconColor : Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white54),
                ),
              )
            else
              Icon(
                isConnected ? LucideIcons.check : LucideIcons.chevronRight,
                color: isConnected ? iconColor : Colors.white38,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNowPlayingRow(UnifiedMusicService musicService) {
    final track = musicService.currentTrack!;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AelianaColors.plasmaCyan.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: musicService.currentArtwork != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(musicService.currentArtwork!, fit: BoxFit.cover),
                )
              : const Icon(LucideIcons.music, color: Colors.white38, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Now Playing',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              ),
              Text(
                '${track.name} - ${track.artist}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Icon(
          musicService.isPlaying ? LucideIcons.pause : LucideIcons.play,
          color: AelianaColors.plasmaCyan,
          size: 18,
        ),
      ],
    );
  }
  
  Future<void> _toggleSpotify(UnifiedMusicService musicService) async {
    if (musicService.isSpotifyConnected) {
      await musicService.disconnectSpotify();
    } else {
      setState(() => _isConnectingSpotify = true);
      try {
        await musicService.connectSpotify();
      } finally {
        if (mounted) {
          setState(() => _isConnectingSpotify = false);
        }
      }
    }
  }
  
  void _showAppleMusicInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Apple Music integration coming soon!',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: AelianaColors.obsidian,
      ),
    );
  }
}
