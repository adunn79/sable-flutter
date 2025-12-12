import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:confetti/confetti.dart';
import '../models/journal_bucket.dart';
import '../services/journal_storage_service.dart';

/// Enhanced Gratitude Mode with 3-field quick entry and streak tracking
class GratitudeModeScreen extends StatefulWidget {
  const GratitudeModeScreen({super.key});

  @override
  State<GratitudeModeScreen> createState() => _GratitudeModeScreenState();
}

class _GratitudeModeScreenState extends State<GratitudeModeScreen> {
  final _gratitude1Controller = TextEditingController();
  final _gratitude2Controller = TextEditingController();
  final _gratitude3Controller = TextEditingController();
  late ConfettiController _confettiController;
  
  int _currentStreak = 0;
  int _longestStreak = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadStreakData();
  }

  @override
  void dispose() {
    _gratitude1Controller.dispose();
    _gratitude2Controller.dispose();
    _gratitude3Controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadStreakData() async {
    // Get all gratitude entries (tagged with 'gratitude')
    final allEntries = JournalStorageService.getAllEntries();
    final gratitudeEntries = allEntries.where((e) => 
      e.tags.contains('gratitude') ||
      e.bucketId == 'gratitude'
    ).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Calculate streaks
    if (gratitudeEntries.isEmpty) {
      setState(() {
        _currentStreak = 0;
        _longestStreak = 0;
      });
      return;
    }

    final sortedDates = gratitudeEntries.map((e) => 
      DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day)
    ).toSet().toList()..sort();

    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 1;

    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 1));

    // Calculate current streak
    if (sortedDates.isNotEmpty) {
      final lastEntry = sortedDates.last;
      final todayDate = DateTime(today.year, today.month, today.day);

      if (lastEntry == todayDate || lastEntry == yesterday) {
        currentStreak = 1;
        for (int i = sortedDates.length - 2; i >= 0; i--) {
          if (sortedDates[i] == sortedDates[i + 1].subtract(const Duration(days: 1))) {
            currentStreak++;
          } else {
            break;
          }
        }
      }
    }

    // Calculate longest streak
    for (int i = 1; i < sortedDates.length; i++) {
      if (sortedDates[i] == sortedDates[i - 1].add(const Duration(days: 1))) {
        tempStreak++;
        longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;
      } else {
        tempStreak = 1;
      }
    }

    setState(() {
      _currentStreak = currentStreak;
      _longestStreak = longestStreak;
    });
  }

  Future<void> _saveGratitudeEntry() async {
    if (_gratitude1Controller.text.trim().isEmpty &&
        _gratitude2Controller.text.trim().isEmpty &&
        _gratitude3Controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in at least one gratitude')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Build entry text
      final buffer = StringBuffer();
      buffer.writeln('🙏 Gratitude Journal\n');

      if (_gratitude1Controller.text.trim().isNotEmpty) {
        buffer.writeln('I\'m grateful for:');
        buffer.writeln(_gratitude1Controller.text.trim());
        buffer.writeln();
      }

      if (_gratitude2Controller.text.trim().isNotEmpty) {
        buffer.writeln('I\'m also grateful for:');
        buffer.writeln(_gratitude2Controller.text.trim());
        buffer.writeln();
      }

      if (_gratitude3Controller.text.trim().isNotEmpty) {
        buffer.writeln('And I\'m grateful for:');
        buffer.writeln(_gratitude3Controller.text.trim());
      }

      // Get or create gratitude bucket
      final buckets = JournalStorageService.getAllBuckets();
      String bucketId = 'gratitude';
      
      if (!buckets.any((b) => b.id == 'gratitude')) {
        // Auto-create gratitude bucket using JournalBucket model
        final gratitudeBucket = JournalBucket(
          id: 'gratitude',
          name: 'Gratitude',
          colorValue: const Color(0xFFB8A9D9).value,
          createdAt: DateTime.now(),
        );
        await gratitudeBucket.save();
      }

      // Create journal entry
      await JournalStorageService.createEntry(
        content: buffer.toString(),
        plainText: buffer.toString(),
        bucketId: bucketId,
        moodScore: 5, // Gratitude typically associated with positive mood
        tags: ['gratitude'],
        isPrivate: false,
      );

      // Reload streak data
      await _loadStreakData();

      // Show celebration if milestone reached
      if (_currentStreak % 7 == 0 || _currentStreak == 30 || _currentStreak == 100) {
        _confettiController.play();
      }

      // Clear fields
      _gratitude1Controller.clear();
      _gratitude2Controller.clear();
      _gratitude3Controller.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ Gratitude saved! 🔥 ${_currentStreak} day streak'),
            backgroundColor: const Color(0xFFB8A9D9),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving gratitude: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Gratitude',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Streak cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStreakCard(
                        '🔥 Current Streak',
                        '$_currentStreak days',
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStreakCard(
                        '🏆 Best Streak',
                        '$_longestStreak days',
                        Colors.amber,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // Instructions
                Text(
                  'What are you grateful for today?',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Take a moment to appreciate three things in your life',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white60,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Gratitude field 1
                _buildGratitudeField(
                  controller: _gratitude1Controller,
                  number: 1,
                  hint: 'Something that made you smile today...',
                ),
                
                const SizedBox(height: 16),
                
                // Gratitude field 2
                _buildGratitudeField(
                  controller: _gratitude2Controller,
                  number: 2,
                  hint: 'A person, experience, or opportunity...',
                ),
                
                const SizedBox(height: 16),
                
                // Gratitude field 3
                _buildGratitudeField(
                  controller: _gratitude3Controller,
                  number: 3,
                  hint: 'Something you might take for granted...',
                ),
                
                const SizedBox(height: 30),
                
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveGratitudeEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB8A9D9),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.heart, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                'Save Gratitude',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          
          // Confetti celebrat ion
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Color(0xFFB8A9D9),
                Color(0xFF5DD9C1),
                Colors.amber,
                Colors.pink,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGratitudeField({
    required TextEditingController controller,
    required int number,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFB8A9D9).withOpacity(0.3),
            const Color(0xFFB8A9D9).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2D3D),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8A9D9).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFB8A9D9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'I\'m grateful for...',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white,
              ),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white30,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }
}
