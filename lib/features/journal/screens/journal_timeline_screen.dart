import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/journal_storage_service.dart';
import '../models/journal_entry.dart';
import '../models/journal_bucket.dart';
import '../widgets/avatar_journal_overlay.dart';
import 'journal_editor_screen.dart';

/// Main journal screen showing timeline of entries
class JournalTimelineScreen extends StatefulWidget {
  const JournalTimelineScreen({super.key});

  @override
  State<JournalTimelineScreen> createState() => _JournalTimelineScreenState();
}

class _JournalTimelineScreenState extends State<JournalTimelineScreen> {
  List<JournalBucket> _buckets = [];
  List<JournalEntry> _entries = [];
  String? _selectedBucketId;
  String _searchQuery = '';
  bool _isLoading = true;
  String _archetype = 'sable';
  
  @override
  void initState() {
    super.initState();
    _loadArchetype();
    _loadData();
  }
  
  Future<void> _loadArchetype() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _archetype = prefs.getString('selected_archetype_id') ?? 'sable';
    });
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _buckets = JournalStorageService.getAllBuckets();
    
    if (_selectedBucketId != null) {
      _entries = JournalStorageService.getEntriesForBucket(_selectedBucketId!);
    } else {
      _entries = JournalStorageService.getAllEntries();
    }
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      _entries = _entries.where((e) =>
        e.plainText.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        e.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()))
      ).toList();
    }
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _openEditor({String? entryId}) async {
    final bucketId = _selectedBucketId ?? _buckets.first.id;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEditorScreen(
          entryId: entryId,
          bucketId: bucketId,
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
          color: Colors.grey[900],
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
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // No back button - bottom nav handles this
        title: GestureDetector(
          onTap: _showBucketPicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (currentBucket != null) ...[
                Text(currentBucket.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
              ],
              Text(
                currentBucket?.name ?? 'All Entries',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(LucideIcons.chevronDown, color: Colors.white60, size: 18),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          // Streak counter
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '${JournalStorageService.getCurrentStreak()}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Welcome banner for new users
              if (_entries.length <= 2)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.withOpacity(0.2), Colors.blue.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          const Text(
                            'Welcome to Your Journal',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to write an entry. ${_archetype[0].toUpperCase()}${_archetype.substring(1)} can help with prompts and reflection!',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildFeatureChip('🎤 Voice dictate'),
                          _buildFeatureChip('👁️ Privacy control'),
                          _buildFeatureChip('📊 Mood tracking'),
                        ],
                      ),
                    ],
                  ),
                ),
              
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _loadData();
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search entries...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    prefixIcon: Icon(LucideIcons.search, color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
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
          
          // Avatar overlay
          AvatarJournalOverlay(
            isPrivate: false,
            archetype: _archetype,
            onSparkTap: null, // No spark on timeline
            onAvatarTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Hi! Tap + to start journaling. I can help with prompts! 💜'),
                  backgroundColor: Colors.purple[800],
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: Colors.white,
        child: const Icon(LucideIcons.plus, color: Colors.black),
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
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty)
            TextButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Write your first entry'),
            ),
        ],
      ),
    );
  }
  
  Widget _buildEntryCard(JournalEntry entry) {
    final bucket = JournalStorageService.getBucket(entry.bucketId);
    final dateFormat = DateFormat('MMM d, y • h:mm a');
    
    return GestureDetector(
      onTap: () => _openEditor(entryId: entry.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                
                // Date
                Expanded(
                  child: Text(
                    dateFormat.format(entry.timestamp),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ),
                
                // Privacy indicator
                if (entry.isPrivate)
                  Icon(LucideIcons.eyeOff, size: 14, color: Colors.red.withOpacity(0.7)),
                
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
              style: const TextStyle(
                color: Colors.white,
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
                    borderRadius: BorderRadius.circular(10),
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
          ],
        ),
      ),
    );
  }
}
