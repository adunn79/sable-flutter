import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/media/listening_history_service.dart';

/// Listening History Widget for Journal Timeline
/// Shows "Most Played Today" in a compact, visually appealing format
class ListeningHistoryWidget extends StatefulWidget {
  final DateTime date;
  
  const ListeningHistoryWidget({
    super.key,
    required this.date,
  });

  @override
  State<ListeningHistoryWidget> createState() => _ListeningHistoryWidgetState();
}

class _ListeningHistoryWidgetState extends State<ListeningHistoryWidget> {
  late DailyListeningSummary _summary;
  
  @override
  void initState() {
    super.initState();
    _loadSummary();
  }
  
  void _loadSummary() {
    _summary = ListeningHistoryService.instance.getSummaryForDate(widget.date);
  }
  
  @override
  Widget build(BuildContext context) {
    if (_summary.entries.isEmpty) return const SizedBox.shrink();
    
    final topTracks = _summary.topTracks.take(3).toList();
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1DB954).withValues(alpha: 0.15),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1DB954).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                LucideIcons.music2,
                color: const Color(0xFF1DB954),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Most Played Today',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_summary.totalTracks} plays',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Top tracks
          ...topTracks.asMap().entries.map((entry) {
            final index = entry.key;
            final track = entry.value;
            return _buildTrackRow(index + 1, track);
          }),
          
          // Summary
          if (_summary.uniqueArtists > 1) ...[
            const SizedBox(height: 8),
            Text(
              '${_summary.uniqueArtists} different artists',
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildTrackRow(int rank, ListeningEntry track) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: rank == 1 
                  ? AelianaColors.hyperGold.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: GoogleFonts.spaceGrotesk(
                  color: rank == 1 ? AelianaColors.hyperGold : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // Track info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.trackName,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  track.artistName,
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Play count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${track.playCount}x',
              style: GoogleFonts.inter(
                color: const Color(0xFF1DB954),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact version for inline display
class ListeningHistoryChip extends StatelessWidget {
  final DateTime date;
  
  const ListeningHistoryChip({super.key, required this.date});
  
  @override
  Widget build(BuildContext context) {
    final summary = ListeningHistoryService.instance.getSummaryForDate(date);
    if (summary.entries.isEmpty) return const SizedBox.shrink();
    
    final topTrack = summary.topTracks.isNotEmpty ? summary.topTracks.first : null;
    if (topTrack == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1DB954).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1DB954).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.music,
            color: const Color(0xFF1DB954),
            size: 12,
          ),
          const SizedBox(width: 6),
          Text(
            '${topTrack.trackName} - ${topTrack.artistName}',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
