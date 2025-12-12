import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:confetti/confetti.dart';
import 'package:sable/core/engagement/engagement_service.dart';

/// Daily Check-in Bottom Sheet
/// 
/// Combines:
/// - Streak counter with celebration
/// - Mood selector (5 emojis)
/// - Contributing factor tags
class DailyCheckInSheet extends StatefulWidget {
  final VoidCallback? onComplete;
  
  const DailyCheckInSheet({super.key, this.onComplete});

  @override
  State<DailyCheckInSheet> createState() => _DailyCheckInSheetState();

  /// Show the check-in sheet
  static Future<void> show(BuildContext context, {VoidCallback? onComplete}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DailyCheckInSheet(onComplete: onComplete),
    );
  }
}

class _DailyCheckInSheetState extends State<DailyCheckInSheet> {
  int? _selectedMood;
  final Set<String> _selectedFactors = {};
  int _currentStreak = 0;
  bool _isLoading = true;
  bool _hasAlreadyCheckedIn = false;
  late ConfettiController _confettiController;

  final List<_MoodOption> _moods = [
    _MoodOption(emoji: '😢', label: 'Rough', value: 1, color: Colors.blue),
    _MoodOption(emoji: '😕', label: 'Meh', value: 2, color: Colors.indigo),
    _MoodOption(emoji: '😐', label: 'Okay', value: 3, color: Colors.grey),
    _MoodOption(emoji: '🙂', label: 'Good', value: 4, color: Colors.teal),
    _MoodOption(emoji: '😊', label: 'Great', value: 5, color: AelianaColors.plasmaCyan),
  ];

  final List<_FactorOption> _factors = [
    _FactorOption(emoji: '😴', label: 'Sleep', id: 'sleep'),
    _FactorOption(emoji: '🏃', label: 'Exercise', id: 'exercise'),
    _FactorOption(emoji: '💼', label: 'Work', id: 'work'),
    _FactorOption(emoji: '👥', label: 'Social', id: 'social'),
    _FactorOption(emoji: '🌤️', label: 'Weather', id: 'weather'),
    _FactorOption(emoji: '🍎', label: 'Nutrition', id: 'nutrition'),
    _FactorOption(emoji: '🧘', label: 'Mindfulness', id: 'mindfulness'),
    _FactorOption(emoji: '💊', label: 'Health', id: 'health'),
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadData();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await EngagementService.init();
    final streak = await EngagementService.getCurrentStreak();
    final hasCheckedIn = await EngagementService.hasCheckedInToday();
    
    if (mounted) {
      setState(() {
        _currentStreak = streak;
        _hasAlreadyCheckedIn = hasCheckedIn;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveCheckIn() async {
    if (_selectedMood == null) return;
    
    HapticFeedback.mediumImpact();
    
    await EngagementService.recordCheckIn(
      moodLevel: _selectedMood!,
      factors: _selectedFactors.toList(),
    );
    
    // Update streak display
    final newStreak = await EngagementService.getCurrentStreak();
    
    if (mounted) {
      setState(() {
        _currentStreak = newStreak;
        _hasAlreadyCheckedIn = true;
      });
      
      // Celebrate!
      _confettiController.play();
      
      // Show success and close after delay
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.pop(context);
        widget.onComplete?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        Container(
          margin: const EdgeInsets.only(top: 50),
          decoration: BoxDecoration(
            color: AelianaColors.obsidian,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
          ),
        ),
        
        // Confetti overlay
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: [
              AelianaColors.plasmaCyan,
              AelianaColors.hyperGold,
              Colors.purple,
              Colors.pink,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Text(
            _hasAlreadyCheckedIn ? 'Great job today! ✨' : 'Daily Check-in',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          // Streak counter
          _buildStreakCounter(),
          const SizedBox(height: 28),
          
          if (!_hasAlreadyCheckedIn) ...[
            // Mood selector
            Text(
              'How are you feeling?',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            _buildMoodSelector(),
            const SizedBox(height: 24),
            
            // Factor tags
            if (_selectedMood != null) ...[
              Text(
                'What\'s affecting your mood?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 12),
              _buildFactorTags(),
              const SizedBox(height: 24),
            ],
            
            // Save button
            _buildSaveButton(),
          ] else ...[
            // Already checked in message
            _buildSuccessMessage(),
          ],
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStreakCounter() {
    final isNewStreak = _currentStreak == 1 && _hasAlreadyCheckedIn;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '🔥',
            style: TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_currentStreak Day${_currentStreak != 1 ? 's' : ''}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AelianaColors.hyperGold,
                ),
              ),
              Text(
                isNewStreak ? 'You started a streak!' : 'Keep the fire going!',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoodSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _moods.map((mood) {
        final isSelected = _selectedMood == mood.value;
        
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedMood = mood.value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected 
                  ? mood.color.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected 
                    ? mood.color 
                    : Colors.white12,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: mood.color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ] : null,
            ),
            child: Column(
              children: [
                Text(
                  mood.emoji,
                  style: TextStyle(
                    fontSize: isSelected ? 32 : 28,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mood.label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isSelected ? mood.color : Colors.white38,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFactorTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _factors.map((factor) {
        final isSelected = _selectedFactors.contains(factor.id);
        
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isSelected) {
                _selectedFactors.remove(factor.id);
              } else {
                _selectedFactors.add(factor.id);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AelianaColors.plasmaCyan.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected 
                    ? AelianaColors.plasmaCyan 
                    : Colors.white12,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(factor.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  factor.label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isSelected ? AelianaColors.plasmaCyan : Colors.white54,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveButton() {
    final canSave = _selectedMood != null;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canSave ? _saveCheckIn : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AelianaColors.plasmaCyan,
          disabledBackgroundColor: Colors.white12,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          'Save Check-in',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: canSave ? Colors.black : Colors.white38,
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.checkCircle, color: Colors.green, size: 48),
          const SizedBox(height: 12),
          Text(
            'You\'ve already checked in today!',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Come back tomorrow to keep your streak',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodOption {
  final String emoji;
  final String label;
  final int value;
  final Color color;
  
  _MoodOption({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });
}

class _FactorOption {
  final String emoji;
  final String label;
  final String id;
  
  _FactorOption({
    required this.emoji,
    required this.label,
    required this.id,
  });
}
