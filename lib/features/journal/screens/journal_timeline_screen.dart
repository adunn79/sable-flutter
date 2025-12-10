import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/journal_storage_service.dart';
import '../services/journal_export_service.dart';
import '../models/journal_entry.dart';
import '../models/journal_bucket.dart';
import '../widgets/avatar_journal_overlay.dart';
import 'journal_editor_screen.dart';
import 'insights_dashboard_screen.dart';
import 'gratitude_mode_screen.dart';
import 'voice_journaling_screen.dart';
import 'journal_calendar_screen.dart';

// Soothing color palette (matching Vital Balance)
const Color _backgroundStart = Color(0xFF0D1B2A); // Deep navy
const Color _backgroundMid = Color(0xFF1B263B);   // Slate blue
const Color _backgroundEnd = Color(0xFF0D1B2A);   // Deep navy
const Color _accentTeal = Color(0xFF5DD9C1);      // Soothing teal
const Color _accentLavender = Color(0xFFB8A9D9);  // Soft lavender
const Color _cardColor = Color(0xFF1E2D3D);       // Dark card

/// Main journal screen showing timeline of entries
class JournalTimelineScreen extends StatefulWidget {
  const JournalTimelineScreen({super.key});

  @override
  State<JournalTimelineScreen> createState() => _JournalTimelineScreenState();
}

class _JournalTimelineScreenState extends State<JournalTimelineScreen> {
  
  List<JournalBucket> _buckets = [];
  List<JournalEntry> _entries = [];
  List<JournalEntry> _onThisDayEntries = []; // Entries from previous years on this date
  String? _selectedBucketId;
  String _searchQuery = '';
  bool _isLoading = true;
  String _archetype = 'sable';
  bool _welcomeBannerDismissed = false;
  bool _welcomeBannerHiddenPermanently = false;
  
  // Search filters
  int? _filterMood;
  String? _filterLocation;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  bool _hasActiveFilters = false;
  
  // Weather
  String? _weatherTemp;
  
  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadData();
  }
  
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _archetype = prefs.getString('selected_archetype_id') ?? 'sable';
      _welcomeBannerHiddenPermanently = prefs.getBool('journal_welcome_hidden') ?? false;
      _weatherTemp = prefs.getString('cached_weather_temp');
    });
  }
  
  Future<void> _dismissWelcomeBanner({bool permanently = false}) async {
    setState(() => _welcomeBannerDismissed = true);
    if (permanently) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('journal_welcome_hidden', true);
      setState(() => _welcomeBannerHiddenPermanently = true);
    }
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _buckets = JournalStorageService.getAllBuckets();
    
    // Load "On This Day" entries from previous years
    _onThisDayEntries = JournalStorageService.getOnThisDayEntries();
    
    if (_selectedBucketId != null) {
      _entries = JournalStorageService.getEntriesForBucket(_selectedBucketId!);
    } else {
      _entries = JournalStorageService.getAllEntries();
    }
    
    // Apply text search filter
    if (_searchQuery.isNotEmpty) {
      _entries = _entries.where((e) =>
        e.plainText.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        e.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase())) ||
        (e.location?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }
    
    // Apply date range filter
    if (_filterStartDate != null) {
      _entries = _entries.where((e) => 
        e.timestamp.isAfter(_filterStartDate!) || 
        e.timestamp.isAtSameMomentAs(_filterStartDate!)
      ).toList();
    }
    if (_filterEndDate != null) {
      _entries = _entries.where((e) => 
        e.timestamp.isBefore(_filterEndDate!.add(const Duration(days: 1)))
      ).toList();
    }
    
    // Apply mood filter
    if (_filterMood != null) {
      _entries = _entries.where((e) => e.moodScore == _filterMood).toList();
    }
    
    // Apply location filter
    if (_filterLocation != null && _filterLocation!.isNotEmpty) {
      _entries = _entries.where((e) => 
        e.location?.toLowerCase().contains(_filterLocation!.toLowerCase()) ?? false
      ).toList();
    }
    
    // Update active filters flag
    _hasActiveFilters = _filterMood != null || 
        _filterLocation != null || 
        _filterStartDate != null || 
        _filterEndDate != null;
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _openEditor({String? entryId, String? aiPrompt}) async {
    final bucketId = _selectedBucketId ?? _buckets.first.id;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEditorScreen(
          entryId: entryId,
          bucketId: bucketId,
          aiPrompt: aiPrompt,
        ),
      ),
    );
    
    if (result == true) {
      _loadData();
    }
  }
  
  void _showBucketPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Journal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            // All entries option
            ListTile(
              leading: const Icon(LucideIcons.bookOpen, color: Colors.white70),
              title: const Text('All Entries', style: TextStyle(color: Colors.white)),
              selected: _selectedBucketId == null,
              selectedTileColor: Colors.white.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () {
                setState(() => _selectedBucketId = null);
                Navigator.pop(ctx);
                _loadData();
              },
            ),
            const Divider(color: Colors.white24),
            // Bucket list
            ..._buckets.map((bucket) => ListTile(
              leading: Text(bucket.icon, style: const TextStyle(fontSize: 24)),
              title: Text(bucket.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                '${bucket.entryCount} entries${bucket.isVault ? ' • Private' : ''}',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
              selected: _selectedBucketId == bucket.id,
              selectedTileColor: Colors.white.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              trailing: bucket.isVault 
                  ? const Icon(LucideIcons.lock, color: Colors.red, size: 18)
                  : null,
              onTap: () {
                setState(() => _selectedBucketId = bucket.id);
                Navigator.pop(ctx);
                _loadData();
              },
            )),
          ],
        ),
      ),
    );
  }
  
  void _showJournalHelp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📓 Journal Guide',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildHelpRow('👆 Tap entry', 'Open and edit'),
              _buildHelpRow('👆🏻 Hold entry', 'Show options menu (hide, delete)'),
              _buildHelpRow('👈 Swipe left', 'Delete entry'),
              _buildHelpRow('🔒 Private toggle', 'Hide from AI assistant'),
              _buildHelpRow('❌ Hidden entries', 'Apps in timeline but dimmed'),
              _buildHelpRow('🏷️ Tags', 'Organize with #hashtags'),
              _buildHelpRow('📍 Location', 'Auto-captured when saving'),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it!', style: TextStyle(color: Colors.cyan, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHelpRow(String icon, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(icon, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          Expanded(
            child: Text(desc, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ),
        ],
      ),
    );
  }
  String _getMoodEmoji(int? score) {
    if (score == null) return '';
    return ['😢', '😔', '😐', '🙂', '😊'][score - 1];
  }
  
  @override
  Widget build(BuildContext context) {
    final currentBucket = _selectedBucketId != null 
        ? _buckets.firstWhere((b) => b.id == _selectedBucketId)
        : null;
    
    return Scaffold(
      backgroundColor: _backgroundStart,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _backgroundStart,
              _backgroundMid,
              _backgroundEnd,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Header - matching Vital Balance style
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Icon + Title (tappable for bucket picker)
                        GestureDetector(
                          onTap: _showBucketPicker,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.bookOpen, color: _accentTeal, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                currentBucket?.name ?? 'Journal',
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(LucideIcons.chevronDown, color: Colors.white60, size: 16),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Insights button
                        IconButton(
                          icon: const Icon(LucideIcons.barChart3, color: Color(0xFFB8A9D9), size: 20),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const InsightsDashboardScreen()),
                            );
                          },
                          tooltip: 'AI Insights',
                        ),
                        const SizedBox(width: 8),
                        // Streak badge (compact)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                '${JournalStorageService.getCurrentStreak()}',
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.orange,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Weather badge
                        if (_weatherTemp != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.cloudSun, color: _accentTeal, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  _weatherTemp!.split(' ').first,
                                  style: GoogleFonts.spaceGrotesk(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 8),
                        // Help button
                        IconButton(
                          icon: Icon(LucideIcons.helpCircle, color: Colors.white38, size: 20),
                          onPressed: _showJournalHelp,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Welcome banner (simplified)
                  if (!_welcomeBannerDismissed && !_welcomeBannerHiddenPermanently)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _accentTeal.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.sparkles, color: _accentTeal, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tap + to write. Swipe entries to delete.',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _dismissWelcomeBanner(permanently: true),
                            child: Icon(LucideIcons.x, color: Colors.white38, size: 16),
                          ),
                        ],
                      ),
                    ),
              
              // Search bar with filter button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                          _loadData();
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search entries, tags, locations...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          prefixIcon: Icon(LucideIcons.search, color: _accentTeal.withOpacity(0.5)),
                          filled: true,
                          fillColor: _cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showFilters,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _hasActiveFilters ? _accentTeal.withOpacity(0.3) : _cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: _hasActiveFilters ? Border.all(color: _accentTeal) : null,
                        ),
                        child: Icon(
                          LucideIcons.slidersHorizontal,
                          color: _hasActiveFilters ? _accentTeal : Colors.white.withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Active filter chips
              if (_hasActiveFilters)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (_filterMood != null)
                        _buildFilterChip('Mood: ${['😢', '😔', '😐', '🙂', '😊'][_filterMood! - 1]}', () {
                          setState(() => _filterMood = null);
                          _loadData();
                        }),
                      if (_filterStartDate != null)
                        _buildFilterChip('From: ${_filterStartDate!.month}/${_filterStartDate!.day}', () {
                          setState(() => _filterStartDate = null);
                          _loadData();
                        }),
                      if (_filterEndDate != null)
                        _buildFilterChip('To: ${_filterEndDate!.month}/${_filterEndDate!.day}', () {
                          setState(() => _filterEndDate = null);
                          _loadData();
                        }),
                      if (_filterLocation != null)
                        _buildFilterChip('📍 $_filterLocation', () {
                          setState(() => _filterLocation = null);
                          _loadData();
                        }),
                      GestureDetector(
                        onTap: _clearFilters,
                        child: Text('Clear all', style: TextStyle(color: _accentTeal, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              // "On This Day" memories card
              if (_onThisDayEntries.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.withOpacity(0.15), Colors.orange.withOpacity(0.08)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'On This Day',
                              style: TextStyle(
                                color: Colors.amber[200],
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Text(
                            '${_onThisDayEntries.length} ${_onThisDayEntries.length == 1 ? 'memory' : 'memories'}',
                            style: TextStyle(color: Colors.amber.withOpacity(0.6), fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Show first entry preview
                      GestureDetector(
                        onTap: () => _openEditor(entryId: _onThisDayEntries.first.id),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (_onThisDayEntries.first.moodScore != null)
                                    Text(_getMoodEmoji(_onThisDayEntries.first.moodScore), style: const TextStyle(fontSize: 18)),
                                  if (_onThisDayEntries.first.moodScore != null)
                                    const SizedBox(width: 8),
                                  Text(
                                    DateFormat('MMMM d, y').format(_onThisDayEntries.first.timestamp),
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _onThisDayEntries.first.plainText.length > 120 
                                  ? '${_onThisDayEntries.first.plainText.substring(0, 120)}...'
                                  : _onThisDayEntries.first.plainText,
                                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_onThisDayEntries.length > 1) ...[
                        const SizedBox(height: 8),
                        Text(
                          '+ ${_onThisDayEntries.length - 1} more from past years',
                          style: TextStyle(color: Colors.amber.withOpacity(0.5), fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              
              // Entries list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _entries.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _entries.length,
                            itemBuilder: (context, index) => _buildEntryCard(_entries[index]),
                          ),
              ),
            ],
          ),
          
          // Avatar overlay - positioned bottom-right to not cover text
          Positioned(
            bottom: 80, // Lower position to avoid overlapping empty state text
            right: 16,
            child: SizedBox(
              width: 100,
              height: 100,
              child: AvatarJournalOverlay(
                isPrivate: false,
                archetype: _archetype,
                onSparkTap: null, // No spark on timeline
                onAvatarTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hi! Tap + to start journaling. I can help with prompts! 💜'),
                      backgroundColor: _accentLavender.withOpacity(0.9),
                    ),
                  );
                },
              ),
            ),
          ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: _accentTeal,
        child: const Icon(LucideIcons.plus, color: Colors.black),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _backgroundStart,
          border: Border(top: BorderSide(color: _accentTeal.withOpacity(0.2))),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(LucideIcons.layoutList, 'Timeline', true, () {}),
              _buildNavItem(LucideIcons.calendar, 'Calendar', false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const JournalCalendarScreen()),
                ).then((_) => _loadData());
              }),
              _buildNavItem(LucideIcons.folderOpen, 'Buckets', false, _showBucketPicker),
              _buildNavItem(LucideIcons.settings, 'Settings', false, _showJournalSettings),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showJournalSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⚙️ Journal Settings',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(LucideIcons.lock, color: _accentTeal),
                title: const Text('Journal PIN', style: TextStyle(color: Colors.white)),
                subtitle: Text('Change or remove PIN lock', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                trailing: const Icon(LucideIcons.chevronRight, color: Colors.white30),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPinSettings();
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.fingerprint, color: Colors.cyan),
                title: const Text('Biometric Unlock', style: TextStyle(color: Colors.white)),
                subtitle: Text('Use Face ID / Touch ID', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                trailing: const Icon(LucideIcons.chevronRight, color: Colors.white30),
                onTap: () async {
                  Navigator.pop(ctx);
                  final prefs = await SharedPreferences.getInstance();
                  final enabled = prefs.getBool('journal_biometric_enabled') ?? false;
                  await prefs.setBool('journal_biometric_enabled', !enabled);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(!enabled ? '✅ Biometric unlock enabled' : '❌ Biometric unlock disabled')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.folderPlus, color: Colors.amber),
                title: const Text('Manage Buckets', style: TextStyle(color: Colors.white)),
                subtitle: Text('Create, edit, delete journals', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                trailing: const Icon(LucideIcons.chevronRight, color: Colors.white30),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBucketPicker();
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.download, color: Colors.green),
                title: const Text('Export Journal', style: TextStyle(color: Colors.white)),
                subtitle: Text('Save a backup of your entries', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                trailing: const Icon(LucideIcons.chevronRight, color: Colors.white30),
                onTap: () {
                  Navigator.pop(ctx);
                  _showExportDialog();
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showPinSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔐 PIN Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(LucideIcons.keyRound, color: _accentTeal),
              title: const Text('Change PIN', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('journal_pin');
                await prefs.setBool('journal_pin_enabled', false);
                await prefs.setBool('journal_pin_prompted', false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN removed. You can set a new one when you next open the journal.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.unlock, color: Colors.red),
              title: const Text('Remove PIN', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('journal_pin');
                await prefs.setBool('journal_pin_enabled', false);
                await prefs.setBool('journal_pin_prompted', true); // Don't ask again
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('❌ Journal PIN removed')),
                );
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showExportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.download, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Export Journal',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_entries.length} entries will be exported',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 20),
            // PDF option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.fileText, color: Colors.red, size: 20),
              ),
              title: const Text('PDF Document', style: TextStyle(color: Colors.white)),
              subtitle: Text('Beautiful formatted export with cover page', 
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              trailing: const Icon(LucideIcons.chevronRight, color: Colors.white30),
              onTap: () async {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text('Creating PDF...'),
                      ],
                    ),
                    duration: Duration(seconds: 10),
                  ),
                );
                try {
                  await JournalExportService.exportToPdf(entries: _entries);
                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 8),
            // Text option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.fileType, color: Colors.blue, size: 20),
              ),
              title: const Text('Plain Text', style: TextStyle(color: Colors.white)),
              subtitle: Text('Simple text file format', 
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              trailing: const Icon(LucideIcons.chevronRight, color: Colors.white30),
              onTap: () async {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Creating text export...')),
                );
                try {
                  await JournalExportService.exportToText(entries: _entries);
                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🔍 Search Filters',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              // Mood filter
              const Text('Filter by Mood', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (i) {
                  final mood = i + 1;
                  final emoji = ['😢', '😔', '😐', '🙂', '😊'][i];
                  final isSelected = _filterMood == mood;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _filterMood = isSelected ? null : mood);
                      _loadData();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? _accentTeal.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: _accentTeal) : null,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 20),
              
              // Date range
              const Text('Date Range', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _filterStartDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _filterStartDate = date);
                          _loadData();
                        }
                      },
                      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white30)),
                      child: Text(
                        _filterStartDate != null 
                          ? '${_filterStartDate!.month}/${_filterStartDate!.day}/${_filterStartDate!.year}'
                          : 'Start Date',
                        style: TextStyle(color: _filterStartDate != null ? Colors.white : Colors.white54),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('to', style: TextStyle(color: Colors.white30)),
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _filterEndDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _filterEndDate = date);
                          _loadData();
                        }
                      },
                      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white30)),
                      child: Text(
                        _filterEndDate != null 
                          ? '${_filterEndDate!.month}/${_filterEndDate!.day}/${_filterEndDate!.year}'
                          : 'End Date',
                        style: TextStyle(color: _filterEndDate != null ? Colors.white : Colors.white54),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Location filter
              const Text('Filter by Location', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) {
                  setState(() => _filterLocation = value.isEmpty ? null : value);
                  _loadData();
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter city or location...',
                  hintStyle: TextStyle(color: Colors.white30),
                  prefixIcon: Icon(LucideIcons.mapPin, color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _clearFilters();
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white30)),
                      child: const Text('Clear All', style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _loadData(); // Apply filters
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: _accentTeal),
                      child: const Text('Apply', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _clearFilters() {
    setState(() {
      _filterMood = null;
      _filterLocation = null;
      _filterStartDate = null;
      _filterEndDate = null;
    });
    _loadData();
  }
  
  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _accentTeal.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentTeal.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(LucideIcons.x, size: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: isActive ? Colors.white : Colors.white.withOpacity(0.4)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeatureChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.bookOpen, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No entries match your search'
                  : 'No journal entries yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (_searchQuery.isEmpty) ...[
              Text(
                'Let me help you explore what\'s on your mind.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // AI-assisted button (primary)
              GestureDetector(
                onTap: _showAIJournalConversation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_accentTeal, _accentLavender]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.sparkles, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Let\'s Talk First',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Quick add button (secondary)
              GestureDetector(
                onTap: () => _openEditor(),
                child: Text(
                  'or start writing now →',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7), 
                    fontSize: 14, 
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// AI-assisted journal conversation
  void _showAIJournalConversation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AIJournalChatSheet(
        onStartWriting: (prompt) {
          Navigator.pop(ctx);
          _openEditor(aiPrompt: prompt);
        },
      ),
    );
  }
  
  Widget _buildEntryCard(JournalEntry entry) {
    final bucket = JournalStorageService.getBucket(entry.bucketId);
    final dateFormat = DateFormat('MMM d, y • h:mm a');
    
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => _confirmDelete(entry),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(LucideIcons.trash2, color: Colors.red, size: 24),
      ),
      child: GestureDetector(
        onTap: () => _openEditor(entryId: entry.id),
        onLongPress: () => _showEntryOptions(entry),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: entry.isHidden ? Colors.grey.withOpacity(0.1) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: entry.isHidden ? Colors.grey.withOpacity(0.3) : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Mood emoji
                  if (entry.moodScore != null)
                    Text(_getMoodEmoji(entry.moodScore), style: const TextStyle(fontSize: 20)),
                  if (entry.moodScore != null) const SizedBox(width: 8),
                  
                  // Date and location
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateFormat.format(entry.timestamp),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                        if (entry.location != null && entry.location!.isNotEmpty)
                          Text(
                            '📍 ${entry.location}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Hidden indicator
                  if (entry.isHidden)
                    Icon(LucideIcons.eyeOff, size: 14, color: Colors.grey.withOpacity(0.7)),
                    
                  // Privacy indicator
                  if (entry.isPrivate && !entry.isHidden) ...[
                    const SizedBox(width: 4),
                    Icon(LucideIcons.lock, size: 14, color: Colors.red.withOpacity(0.7)),
                  ],
                  
                  // Bucket indicator
                  if (bucket != null && _selectedBucketId == null) ...[
                    const SizedBox(width: 8),
                    Text(bucket.icon, style: const TextStyle(fontSize: 14)),
                  ],
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Preview text
              Text(
                entry.plainText.length > 150 
                    ? '${entry.plainText.substring(0, 150)}...'
                    : entry.plainText,
                style: TextStyle(
                  color: entry.isHidden ? Colors.grey : Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Tags
              if (entry.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: entry.tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  )).toList(),
                ),
              ],
              
              // P1+ Context Metadata Icons
              if (entry.nowPlayingTrack != null || 
                  (entry.taggedPeople.isNotEmpty) || 
                  entry.topHeadline != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Now Playing indicator
                    if (entry.nowPlayingTrack != null)
                      _buildContextIcon(LucideIcons.music, Colors.green, 
                        '${entry.nowPlayingTrack}${entry.nowPlayingArtist != null ? " - ${entry.nowPlayingArtist}" : ""}'),
                    // Tagged People indicator
                    if (entry.taggedPeople.isNotEmpty)
                      _buildContextIcon(LucideIcons.users, Colors.blue, 
                        entry.taggedPeople.length == 1 
                          ? entry.taggedPeople.first 
                          : '${entry.taggedPeople.length} people'),
                    // Headline indicator
                    if (entry.topHeadline != null)
                      _buildContextIcon(LucideIcons.newspaper, Colors.orange, 'News context'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  /// Build a compact context indicator icon with tooltip
  Widget _buildContextIcon(IconData icon, Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 12, color: color),
      ),
    );
  }
  
  Future<bool> _confirmDelete(JournalEntry entry) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Delete Entry?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete this journal entry.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await JournalStorageService.deleteEntry(entry.id);
              Navigator.pop(ctx, true);
              _loadData(); // Refresh list
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }
  
  void _showEntryOptions(JournalEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                entry.isHidden ? LucideIcons.eye : LucideIcons.eyeOff,
                color: Colors.white70,
              ),
              title: Text(
                entry.isHidden ? 'Unhide Entry' : 'Hide Entry',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                entry.isHidden ? 'Show in timeline' : 'Hide from timeline view',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await JournalStorageService.updateEntry(
                  entry.copyWith(isHidden: !entry.isHidden),
                );
                _loadData();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.edit, color: Colors.white70),
              title: const Text('Edit Entry', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _openEditor(entryId: entry.id);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: Colors.red),
              title: const Text('Delete Entry', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await _confirmDelete(entry);
                if (confirmed) _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// AI-assisted journal conversation sheet
class _AIJournalChatSheet extends StatefulWidget {
  final Function(String prompt) onStartWriting;
  
  const _AIJournalChatSheet({required this.onStartWriting});
  
  @override
  State<_AIJournalChatSheet> createState() => _AIJournalChatSheetState();
}

class _AIJournalChatSheetState extends State<_AIJournalChatSheet> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isThinking = false;
  String? _suggestedPrompt;
  
  @override
  void initState() {
    super.initState();
    // Start with an AI greeting
    _messages.add({
      'role': 'ai',
      'text': 'Hey! 💜 What\'s on your mind today? I can help you explore your thoughts before you start writing.\n\nTell me anything—how you\'re feeling, what happened today, or something you\'ve been thinking about.',
    });
  }
  
  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isThinking = true;
    });
    _controller.clear();
    
    // Simulate AI processing (in production, use ModelOrchestrator)
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Generate contextual response
    String response;
    if (_messages.length <= 2) {
      response = 'That\'s interesting. Tell me more—what specifically about that is on your mind?';
    } else if (_messages.length <= 4) {
      response = 'I hear you. It sounds like there\'s a lot there. Would you like to explore how this makes you feel, or dive into the details?';
    } else {
      // After enough context, suggest a writing prompt
      response = 'Thanks for sharing all that with me. Based on what you\'ve said, here\'s a thought to start your entry:\n\n"${_generatePrompt(text)}"\n\nReady to start writing? 📝';
      _suggestedPrompt = _generatePrompt(text);
    }
    
    if (mounted) {
      setState(() {
        _messages.add({'role': 'ai', 'text': response});
        _isThinking = false;
      });
    }
  }
  
  String _generatePrompt(String lastMessage) {
    // Create a starter prompt based on the conversation
    final lowerText = lastMessage.toLowerCase();
    if (lowerText.contains('feel') || lowerText.contains('emotion')) {
      return 'Today I\'m processing some feelings about...';
    } else if (lowerText.contains('work') || lowerText.contains('job')) {
      return 'At work, I\'ve been noticing that...';
    } else if (lowerText.contains('friend') || lowerText.contains('relationship')) {
      return 'I\'ve been thinking about my relationship with...';
    } else if (lowerText.contains('stress') || lowerText.contains('anxiety')) {
      return 'Something that\'s been weighing on me is...';
    } else if (lowerText.contains('grateful') || lowerText.contains('happy')) {
      return 'Today I\'m feeling grateful for...';
    } else {
      return 'What\'s been on my mind lately is...';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D), // _cardColor
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(LucideIcons.sparkles, color: const Color(0xFF5DD9C1), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Let\'s Talk First',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(LucideIcons.x, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isThinking) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Text('💭 Thinking...', style: TextStyle(color: const Color(0xFF5DD9C1), fontStyle: FontStyle.italic)),
                      ],
                    ),
                  );
                }
                
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? const Color(0xFF5DD9C1).withOpacity(0.3) : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        msg['text'] ?? '',
                        style: TextStyle(color: Colors.white, height: 1.4),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Start writing button (when prompt is ready)
          if (_suggestedPrompt != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GestureDetector(
                onTap: () => widget.onStartWriting(_suggestedPrompt!),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [const Color(0xFF5DD9C1), const Color(0xFFB8A9D9)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.pencil, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('Start Writing Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          
          // Input area
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Share what\'s on your mind...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                IconButton(
                  icon: Icon(LucideIcons.send, color: const Color(0xFF5DD9C1)),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
