import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/media/unified_music_service.dart';

/// Now Playing Chip for Chat Screens
/// Compact display of currently playing music with tap to expand
class NowPlayingChip extends ConsumerWidget {
  final VoidCallback? onTap;
  
  const NowPlayingChip({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicService = ref.watch(unifiedMusicServiceProvider);
    final track = musicService.currentTrack;
    
    if (track == null || !musicService.isPlaying) {
      return const SizedBox.shrink();
    }
    
    final sourceColor = _getSourceColor(track.source);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              sourceColor.withValues(alpha: 0.25),
              sourceColor.withValues(alpha: 0.1),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sourceColor.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated music icon
            _AnimatedMusicIcon(color: sourceColor),
            const SizedBox(width: 8),
            
            // Track info
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    track.artist,
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Source badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: sourceColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getSourceLabel(track.source),
                style: GoogleFonts.inter(
                  color: sourceColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getSourceColor(MusicSource source) {
    switch (source) {
      case MusicSource.spotify:
        return const Color(0xFF1DB954);
      case MusicSource.appleMusic:
        return const Color(0xFFFC3C44);
      case MusicSource.none:
        return AelianaColors.plasmaCyan;
      default:
        return Colors.white70;
    }
  }
  
  String _getSourceLabel(MusicSource source) {
    switch (source) {
      case MusicSource.spotify:
        return 'Spotify';
      case MusicSource.appleMusic:
        return 'Apple';
      case MusicSource.none:
        return 'Playing';
      default:
        return 'Music';
    }
  }
}

/// Animated music icon with pulsing effect
class _AnimatedMusicIcon extends StatefulWidget {
  final Color color;
  
  const _AnimatedMusicIcon({required this.color});

  @override
  State<_AnimatedMusicIcon> createState() => _AnimatedMusicIconState();
}

class _AnimatedMusicIconState extends State<_AnimatedMusicIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Icon(
            LucideIcons.music,
            color: widget.color,
            size: 14,
          ),
        );
      },
    );
  }
}

/// Inline version for chat messages
class NowPlayingInline extends ConsumerWidget {
  const NowPlayingInline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicService = ref.watch(unifiedMusicServiceProvider);
    final track = musicService.currentTrack;
    
    if (track == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.music,
            color: Colors.white38,
            size: 10,
          ),
          const SizedBox(width: 4),
          Text(
            'Listening to ${track.name}',
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
