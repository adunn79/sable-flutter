import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:ui';
import '../media/unified_music_service.dart';
import '../theme/aeliana_theme.dart';

/// Floating mini-player widget with glassmorphism design
/// Shows above navigation bar when music is playing
class MiniPlayerWidget extends ConsumerStatefulWidget {
  final VoidCallback? onTap;
  
  const MiniPlayerWidget({
    super.key,
    this.onTap,
  });

  @override
  ConsumerState<MiniPlayerWidget> createState() => _MiniPlayerWidgetState();
}

class _MiniPlayerWidgetState extends ConsumerState<MiniPlayerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final musicService = ref.watch(unifiedMusicServiceProvider);
    final track = musicService.currentTrack;
    
    // Don't show if no track
    if (track == null) {
      return const SizedBox.shrink();
    }
    
    return GestureDetector(
      onTap: widget.onTap ?? () => _showFullPlayer(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: AelianaColors.obsidian.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getSourceColor(track.source).withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getSourceColor(track.source).withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Album Art
                  _buildAlbumArt(track, musicService.currentArtwork),
                  
                  // Track Info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Source indicator
                              _buildSourceBadge(track.source),
                              const SizedBox(width: 6),
                              // Track name
                              Expanded(
                                child: Text(
                                  track.name,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            style: GoogleFonts.inter(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Controls
                  _buildControls(musicService),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAlbumArt(TrackInfo track, Uint8List? artworkBytes) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        gradient: LinearGradient(
          colors: [
            _getSourceColor(track.source).withOpacity(0.5),
            _getSourceColor(track.source).withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        child: artworkBytes != null
            ? Image.memory(
                artworkBytes,
                fit: BoxFit.cover,
              )
            : Center(
                child: Icon(
                  LucideIcons.music,
                  color: Colors.white60,
                  size: 24,
                ),
              ),
      ),
    );
  }
  
  Widget _buildSourceBadge(MusicSource source) {
    String label;
    Color color;
    
    switch (source) {
      case MusicSource.spotify:
        label = '♪';
        color = const Color(0xFF1DB954); // Spotify green
        break;
      case MusicSource.appleMusic:
        label = '♫';
        color = const Color(0xFFFC3C44); // Apple Music red
        break;
      default:
        label = '♪';
        color = AelianaColors.plasmaCyan;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10),
      ),
    );
  }
  
  Widget _buildControls(UnifiedMusicService musicService) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Previous
          IconButton(
            icon: const Icon(LucideIcons.skipBack, size: 18),
            color: Colors.white70,
            onPressed: () => musicService.skipPrevious(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          
          // Play/Pause
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = musicService.isPlaying
                  ? 1.0 + (_pulseController.value * 0.05)
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getSourceColor(musicService.currentTrack?.source ?? MusicSource.none),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  musicService.isPlaying
                      ? LucideIcons.pause
                      : LucideIcons.play,
                  size: 18,
                ),
                color: Colors.white,
                onPressed: () => musicService.togglePlayPause(),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          
          // Next
          IconButton(
            icon: const Icon(LucideIcons.skipForward, size: 18),
            color: Colors.white70,
            onPressed: () => musicService.skipNext(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
  
  Color _getSourceColor(MusicSource source) {
    switch (source) {
      case MusicSource.spotify:
        return const Color(0xFF1DB954); // Spotify green
      case MusicSource.appleMusic:
        return const Color(0xFFFC3C44); // Apple Music red
      default:
        return AelianaColors.plasmaCyan;
    }
  }
  
  void _showFullPlayer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FullMusicPlayerSheet(),
    );
  }
}

/// Full-screen music player sheet
class FullMusicPlayerSheet extends ConsumerWidget {
  const FullMusicPlayerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicService = ref.watch(unifiedMusicServiceProvider);
    final track = musicService.currentTrack;
    
    if (track == null) {
      return const SizedBox.shrink();
    }
    
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AelianaColors.carbon,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Large album art
              Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _getSourceColor(track.source).withOpacity(0.3),
                        blurRadius: 40,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: musicService.currentArtwork != null
                        ? Image.memory(
                            musicService.currentArtwork!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: AelianaColors.obsidian,
                            child: Icon(
                              LucideIcons.music,
                              size: 80,
                              color: Colors.white30,
                            ),
                          ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Track info
              Text(
                track.name,
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                track.artist,
                style: GoogleFonts.inter(
                  color: Colors.white60,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              if (track.album != null) ...[
                const SizedBox(height: 2),
                Text(
                  track.album!,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Progress bar
              _buildProgressBar(track, musicService),
              
              const SizedBox(height: 24),
              
              // Main controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(
                      LucideIcons.shuffle, 
                      size: 24,
                      color: musicService.shuffleEnabled 
                        ? _getSourceColor(track.source)
                        : Colors.white54,
                    ),
                    onPressed: () => musicService.toggleShuffle(),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.skipBack, size: 32),
                    color: Colors.white,
                    onPressed: () => musicService.skipPrevious(),
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _getSourceColor(track.source),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        musicService.isPlaying
                            ? LucideIcons.pause
                            : LucideIcons.play,
                        size: 36,
                      ),
                      color: Colors.white,
                      onPressed: () => musicService.togglePlayPause(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.skipForward, size: 32),
                    color: Colors.white,
                    onPressed: () => musicService.skipNext(),
                  ),
                  IconButton(
                    icon: Icon(
                      _getRepeatIcon(musicService.repeatMode),
                      size: 24,
                      color: musicService.repeatMode != RepeatMode.off
                        ? _getSourceColor(track.source)
                        : Colors.white54,
                    ),
                    onPressed: () => musicService.toggleRepeat(),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Source indicator
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getSourceColor(track.source).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getSourceColor(track.source).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getSourceLabel(track.source),
                        style: GoogleFonts.inter(
                          color: _getSourceColor(track.source),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildProgressBar(TrackInfo track, UnifiedMusicService musicService) {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: _getSourceColor(track.source),
            inactiveTrackColor: Colors.white24,
            thumbColor: _getSourceColor(track.source),
          ),
          child: Slider(
            value: track.progress.clamp(0.0, 1.0),
            onChanged: (value) => musicService.seekToPercent(value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                track.formattedPosition,
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              Text(
                track.formattedDuration,
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Color _getSourceColor(MusicSource source) {
    switch (source) {
      case MusicSource.spotify:
        return const Color(0xFF1DB954);
      case MusicSource.appleMusic:
        return const Color(0xFFFC3C44);
      default:
        return AelianaColors.plasmaCyan;
    }
  }
  
  String _getSourceLabel(MusicSource source) {
    switch (source) {
      case MusicSource.spotify:
        return 'Playing on Spotify';
      case MusicSource.appleMusic:
        return 'Playing on Apple Music';
      default:
        return 'Now Playing';
    }
  }
  
  IconData _getRepeatIcon(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.track:
        return LucideIcons.repeat1; // Single track repeat
      case RepeatMode.context:
        return LucideIcons.repeat; // Playlist/album repeat
      case RepeatMode.off:
        return LucideIcons.repeat;
    }
  }
}
