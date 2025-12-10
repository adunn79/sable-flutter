import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/journal_insights.dart';
import '../services/journal_analysis_service.dart';
import '../services/journal_storage_service.dart';

/// Beautiful AI Insights Dashboard showing journal analytics
class InsightsDashboardScreen extends StatefulWidget {
  const InsightsDashboardScreen({super.key});

  @override
  State<InsightsDashboardScreen> createState() => _InsightsDashboardScreenState();
}

class _InsightsDashboardScreenState extends State<InsightsDashboardScreen> {
  JournalInsights? _insights;
  bool _isLoading = true;
  int _selectedTimeframe = 30; // days

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoading = true);
    
    final entries = JournalStorageService.getAllEntries();
    final insights = await JournalAnalysisService.generateInsights(
      entries: entries,
      daysToAnalyze: _selectedTimeframe,
    );
    
    setState(() {
      _insights = insights;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'AI Insights',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          // Timeframe selector
          PopupMenuButton<int>(
            icon: const Icon(LucideIcons.calendar, color: Color(0xFFB8A9D9)),
            onSelected: (days) {
              setState(() => _selectedTimeframe = days);
              _loadInsights();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 7, child: Text('Last 7 Days')),
              PopupMenuItem(value: 30, child: Text('Last 30 Days')),
              PopupMenuItem(value: 90, child: Text('Last 3 Months')),
              PopupMenuItem(value: 365, child: Text('Last Year')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFB8A9D9)))
          : _insights == null
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadInsights,
                  color: const Color(0xFFB8A9D9),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildWeeklySummaryCard(),
                      const SizedBox(height: 20),
                      _buildMoodTrendsCard(),
                      const SizedBox(height: 20),
                      _buildWritingPatternsCard(),
                      const SizedBox(height: 20),
                      _buildThemesCard(),
                      const SizedBox(height: 20),
                      if (_insights!.correlations.isNotEmpty)
                        _buildCorrelationsCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildWeeklySummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFB8A9D9).withOpacity(0.15),
            const Color(0xFFB8A9D9).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB8A9D9).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sparkles, color: Color(0xFFB8A9D9), size: 24),
              const SizedBox(width: 12),
              Text(
                'AI Summary',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _insights!.weeklySummary,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodTrendsCard() {
    final trends = _insights!.moodTrends;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.trendingUp, color: Color(0xFF5DD9C1), size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Mood Trends',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getTrendColor(trends.trend).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trends.trend.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getTrendColor(trends.trend),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Mood chart
          if (trends.dailyMoods.isNotEmpty) ...[
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: 6,
                  lineBarsData: [
                    LineChartBarData(
                      spots: trends.dailyMoods.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.moodScore);
                      }).toList(),
                      isCurved: true,
                      color: const Color(0xFF5DD9C1),
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: const Color(0xFF5DD9C1),
                            strokeWidth: 2,
                            strokeColor: const Color(0xFF0D1B2A),
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF5DD9C1).withOpacity(0.3),
                            const Color(0xFF5DD9C1).withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Avg This Week',
                trends.weeklyAverage.toStringAsFixed(1),
                LucideIcons.smile,
              ),
              _buildStatItem(
                'Best Day',
                trends.bestDay.substring(0, 3),
                LucideIcons.sun,
              ),
              _buildStatItem(
                _getImprovementLabel(trends.improvement),
                '${trends.improvement >= 0 ? '+' : ''}${trends.improvement.toStringAsFixed(0)}%',
                trends.improvement >= 0 ? LucideIcons.arrowUp : LucideIcons.arrowDown,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWritingPatternsCard() {
    final patterns = _insights!.writingPatterns;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.penTool, color: Colors.amber, size: 24),
              const SizedBox(width: 12),
              Text(
                'Writing Patterns',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Streak info
          Row(
            children: [
              Expanded(
                child: _buildPatternCard(
                  '🔥 Current Streak',
                  '${patterns.currentStreak} days',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPatternCard(
                  '🏆 Longest Streak',
                  '${patterns.longestStreak} days',
                  Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildPatternCard(
                  '📝 Avg Words',
                  patterns.averageWordCount.toStringAsFixed(0),
                  const Color(0xFF5DD9C1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPatternCard(
                  '⏰ Best Time',
                  patterns.bestWritingTime,
                  const Color(0xFFB8A9D9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Consistency bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Consistency',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    '${patterns.consistencyScore.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: patterns.consistencyScore / 100,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5DD9C1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemesCard() {
    final themes = _insights!.themes;
    
    if (themes.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.hash, color: Colors.pink, size: 24),
              const SizedBox(width: 12),
              Text(
                'Top Themes',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: themes.take(10).map((theme) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _getThemeColor(theme.theme).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getThemeColor(theme.theme).withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getThemeEmoji(theme.theme),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      theme.theme,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _getThemeColor(theme.theme),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getThemeColor(theme.theme).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${theme.count}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: _getThemeColor(theme.theme),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrelationsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.lightbulb, color: Colors.yellow, size: 24),
              const SizedBox(width: 12),
              Text(
                'Insights',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ..._insights!.correlations.map((correlation) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.yellow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.yellow.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        correlation.insight,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF5DD9C1), size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  Widget _buildPatternCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.barChart3, size: 64, color: Colors.white30),
          const SizedBox(height: 16),
          Text(
            'No insights yet',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start journaling to see AI insights',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTrendColor(String trend) {
    switch (trend) {
      case 'improving':
        return Colors.green;
      case 'declining':
        return Colors.red;
      default:
        return Colors.amber;
    }
  }

  String _getImprovementLabel(double improvement) {
    if (improvement > 0) return 'Improving';
    if (improvement < 0) return 'Change';
    return 'Stable';
  }

  Color _getThemeColor(String theme) {
    switch (theme) {
      case 'work':
        return Colors.blue;
      case 'family':
        return Colors.pink;
      case 'relationships':
        return Colors.red;
      case 'health':
        return const Color(0xFF5DD9C1);
      case 'anxiety':
        return Colors.orange;
      case 'happiness':
        return Colors.yellow;
      case 'gratitude':
        return const Color(0xFFB8A9D9);
      case 'friends':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  String _getThemeEmoji(String theme) {
    switch (theme) {
      case 'work':
        return '💼';
      case 'family':
        return '👨‍👩‍👧‍👦';
      case 'relationships':
        return '❤️';
      case 'health':
        return '💪';
      case 'anxiety':
        return '😰';
      case 'happiness':
        return '😊';
      case 'gratitude':
        return '🙏';
      case 'friends':
        return '👥';
      default:
        return '📌';
    }
  }
}
