import 'package:flutter/material.dart' hide Badge;
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/engagement/engagement_service.dart';

/// Streak Badge Widget - Shows current streak in a compact format
/// 
/// Use in ChatPage header or as floating chip
class StreakBadge extends StatefulWidget {
  final VoidCallback? onTap;
  final bool compact;
  
  const StreakBadge({
    super.key,
    this.onTap,
    this.compact = false,
  });

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge> {
  int _streak = 0;
  bool _checkedInToday = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    await EngagementService.init();
    final streak = await EngagementService.getCurrentStreak();
    final checkedIn = await EngagementService.hasCheckedInToday();
    
    if (mounted) {
      setState(() {
        _streak = streak;
        _checkedInToday = checkedIn;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(width: 60, height: 32);
    }

    if (widget.compact) {
      return _buildCompact();
    }
    return _buildFull();
  }

  Widget _buildCompact() {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _checkedInToday 
              ? AelianaColors.hyperGold.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _checkedInToday 
                ? AelianaColors.hyperGold.withValues(alpha: 0.5)
                : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔥', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              '$_streak',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _checkedInToday 
                    ? AelianaColors.hyperGold 
                    : Colors.white70,
              ),
            ),
            if (!_checkedInToday) ...[
              const SizedBox(width: 4),
              Icon(
                LucideIcons.alertCircle,
                size: 12,
                color: Colors.orange,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFull() {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AelianaColors.hyperGold.withValues(alpha: 0.2),
              Colors.orange.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AelianaColors.hyperGold.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔥', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_streak Day${_streak != 1 ? 's' : ''}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AelianaColors.hyperGold,
                  ),
                ),
                Text(
                  _checkedInToday ? '✓ Checked in today' : 'Tap to check in',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _checkedInToday ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Mood Trend Widget - Shows recent mood trend
class MoodTrendWidget extends StatefulWidget {
  const MoodTrendWidget({super.key});

  @override
  State<MoodTrendWidget> createState() => _MoodTrendWidgetState();
}

class _MoodTrendWidgetState extends State<MoodTrendWidget> {
  MoodTrend _trend = MoodTrend.insufficient;
  List<MoodEntry> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await EngagementService.init();
    final trend = await EngagementService.getMoodTrend();
    final history = await EngagementService.getMoodHistory(days: 7);
    
    if (mounted) {
      setState(() {
        _trend = trend;
        _history = history;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _trendIcon,
                color: _trendColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Mood Trend',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Mini mood chart
          SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final dayIndex = 6 - index;
                final entry = dayIndex < _history.length ? _history[dayIndex] : null;
                
                return _buildMoodBar(entry);
              }),
            ),
          ),
          const SizedBox(height: 8),
          
          // Trend message
          Text(
            _trendMessage,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodBar(MoodEntry? entry) {
    if (entry == null) {
      return Container(
        width: 32,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }
    
    final height = (entry.moodLevel / 5) * 40;
    final color = _moodColor(entry.moodLevel);
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 32,
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Color _moodColor(int level) {
    switch (level) {
      case 1: return Colors.blue;
      case 2: return Colors.indigo;
      case 3: return Colors.grey;
      case 4: return Colors.teal;
      case 5: return AelianaColors.plasmaCyan;
      default: return Colors.grey;
    }
  }

  IconData get _trendIcon {
    switch (_trend) {
      case MoodTrend.improving: return LucideIcons.trendingUp;
      case MoodTrend.declining: return LucideIcons.trendingDown;
      case MoodTrend.stable: return LucideIcons.minus;
      case MoodTrend.insufficient: return LucideIcons.helpCircle;
    }
  }

  Color get _trendColor {
    switch (_trend) {
      case MoodTrend.improving: return Colors.green;
      case MoodTrend.declining: return Colors.orange;
      case MoodTrend.stable: return Colors.grey;
      case MoodTrend.insufficient: return Colors.grey;
    }
  }

  String get _trendMessage {
    switch (_trend) {
      case MoodTrend.improving: return 'Your mood is trending up! Keep it going 🌟';
      case MoodTrend.declining: return 'Things have been tough. We\'re here for you 💙';
      case MoodTrend.stable: return 'Staying steady this week';
      case MoodTrend.insufficient: return 'Check in more to see your trends';
    }
  }
}

/// Badges Display Widget
class BadgesDisplay extends StatefulWidget {
  const BadgesDisplay({super.key});

  @override
  State<BadgesDisplay> createState() => _BadgesDisplayState();
}

class _BadgesDisplayState extends State<BadgesDisplay> {
  List<Badge> _badges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    await EngagementService.init();
    final badges = await EngagementService.getEarnedBadges();
    
    if (mounted) {
      setState(() {
        _badges = badges;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Badges',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _badges.map((badge) => _buildBadge(badge)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(Badge badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AelianaColors.hyperGold.withValues(alpha: 0.2),
            Colors.orange.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AelianaColors.hyperGold.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(badge.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            badge.title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AelianaColors.hyperGold,
            ),
          ),
        ],
      ),
    );
  }
}
