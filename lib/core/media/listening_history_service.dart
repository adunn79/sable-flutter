import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../media/unified_music_service.dart';

/// Listening history entry for journal integration
class ListeningEntry {
  final String trackName;
  final String artistName;
  final String? albumName;
  final String source; // 'spotify' or 'apple_music'
  final DateTime playedAt;
  int playCount;
  
  ListeningEntry({
    required this.trackName,
    required this.artistName,
    this.albumName,
    required this.source,
    required this.playedAt,
    this.playCount = 1,
  });
  
  String get id => '${trackName}_$artistName'.toLowerCase().replaceAll(' ', '_');
  
  Map<String, dynamic> toJson() => {
    'trackName': trackName,
    'artistName': artistName,
    'albumName': albumName,
    'source': source,
    'playedAt': playedAt.toIso8601String(),
    'playCount': playCount,
  };
  
  factory ListeningEntry.fromJson(Map<String, dynamic> json) => ListeningEntry(
    trackName: json['trackName'] as String,
    artistName: json['artistName'] as String,
    albumName: json['albumName'] as String?,
    source: json['source'] as String,
    playedAt: DateTime.parse(json['playedAt'] as String),
    playCount: json['playCount'] as int? ?? 1,
  );
  
  factory ListeningEntry.fromTrackInfo(TrackInfo track) => ListeningEntry(
    trackName: track.name,
    artistName: track.artist,
    albumName: track.album,
    source: track.source.name,
    playedAt: DateTime.now(),
  );
}

/// Daily listening summary
class DailyListeningSummary {
  final DateTime date;
  final List<ListeningEntry> entries;
  final Duration totalListeningTime;
  
  DailyListeningSummary({
    required this.date,
    required this.entries,
    this.totalListeningTime = Duration.zero,
  });
  
  /// Get top N most played tracks for the day
  List<ListeningEntry> get topTracks {
    final sortedEntries = List<ListeningEntry>.from(entries)
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    return sortedEntries.take(5).toList();
  }
  
  /// Get unique artists count
  int get uniqueArtists => entries.map((e) => e.artistName).toSet().length;
  
  /// Get total tracks played
  int get totalTracks => entries.fold(0, (sum, e) => sum + e.playCount);
}

/// Service to track listening history for journal integration
class ListeningHistoryService {
  static ListeningHistoryService? _instance;
  static ListeningHistoryService get instance => _instance ??= ListeningHistoryService._();
  
  ListeningHistoryService._();
  
  Box<dynamic>? _historyBox;
  Timer? _pollingTimer;
  TrackInfo? _lastTrack;
  final UnifiedMusicService _musicService = UnifiedMusicService.instance;
  
  static const String _boxName = 'listening_history';
  
  /// Initialize the service
  Future<void> initialize() async {
    try {
      _historyBox = await Hive.openBox(_boxName);
      _startPolling();
      debugPrint('🎵 ListeningHistory: Initialized with ${_historyBox?.length ?? 0} days of history');
    } catch (e) {
      debugPrint('🎵 ListeningHistory: Init error: $e');
    }
  }
  
  /// Start polling for currently playing track
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _captureCurrentTrack());
  }
  
  /// Capture the currently playing track
  Future<void> _captureCurrentTrack() async {
    final track = _musicService.currentTrack;
    if (track == null || !_musicService.isPlaying) return;
    
    // Skip if same track as last capture
    if (_lastTrack != null && _isSameTrack(track, _lastTrack!)) return;
    
    _lastTrack = track;
    await _recordTrack(track);
    debugPrint('🎵 ListeningHistory: Recorded "${track.name}" by ${track.artist}');
  }
  
  bool _isSameTrack(TrackInfo a, TrackInfo b) {
    return a.name == b.name && a.artist == b.artist;
  }
  
  /// Record a track to history
  Future<void> _recordTrack(TrackInfo track) async {
    if (_historyBox == null) return;
    
    final today = _dateKey(DateTime.now());
    final dayData = _historyBox!.get(today, defaultValue: <String, dynamic>{}) as Map<dynamic, dynamic>;
    
    // Convert to mutable map
    final entries = Map<String, dynamic>.from(dayData);
    
    final entry = ListeningEntry.fromTrackInfo(track);
    final existingJson = entries[entry.id];
    
    if (existingJson != null) {
      // Increment play count
      final existing = ListeningEntry.fromJson(Map<String, dynamic>.from(existingJson as Map));
      existing.playCount++;
      entries[entry.id] = existing.toJson();
    } else {
      // New track
      entries[entry.id] = entry.toJson();
    }
    
    await _historyBox!.put(today, entries);
  }
  
  /// Get listening summary for a specific date
  DailyListeningSummary getSummaryForDate(DateTime date) {
    if (_historyBox == null) {
      return DailyListeningSummary(date: date, entries: []);
    }
    
    final key = _dateKey(date);
    final dayData = _historyBox!.get(key, defaultValue: <String, dynamic>{}) as Map<dynamic, dynamic>;
    
    final entries = <ListeningEntry>[];
    for (final entryJson in dayData.values) {
      try {
        entries.add(ListeningEntry.fromJson(Map<String, dynamic>.from(entryJson as Map)));
      } catch (e) {
        // Skip malformed entries
      }
    }
    
    return DailyListeningSummary(date: date, entries: entries);
  }
  
  /// Get today's listening summary
  DailyListeningSummary get todaySummary => getSummaryForDate(DateTime.now());
  
  /// Get "Most Played Today" for journal
  List<ListeningEntry> get mostPlayedToday => todaySummary.topTracks;
  
  /// Format date as YYYY-MM-DD key
  String _dateKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  
  /// Dispose resources
  void dispose() {
    _pollingTimer?.cancel();
  }
}
