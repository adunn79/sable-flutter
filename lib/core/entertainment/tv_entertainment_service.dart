import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a TV Show, Movie, or Entertainment Event
class EntertainmentEvent {
  final String id;
  final String title;
  final String type; // 'Movie', 'TV', 'Game'
  final DateTime releaseDate;
  final String? network; // 'HBO', 'Netflix', 'Theaters'
  final String description;
  final String emoji;

  EntertainmentEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.releaseDate,
    this.network,
    required this.description,
    required this.emoji,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'releaseDate': releaseDate.toIso8601String(),
    'network': network,
    'description': description,
    'emoji': emoji,
  };

  factory EntertainmentEvent.fromJson(Map<String, dynamic> json) => EntertainmentEvent(
    id: json['id'],
    title: json['title'],
    type: json['type'],
    releaseDate: DateTime.parse(json['releaseDate']),
    network: json['network'],
    description: json['description'],
    emoji: json['emoji'],
  );
}

/// Service for tracking entertainment releases
class TvEntertainmentService {
  static const _subscribedShowsKey = 'subscribed_entertainment_ids';
  
  /// Curated list of upcoming "Hyper-Culture" releases
  /// In a real app, this would come from TMDB or similar API
  static final List<EntertainmentEvent> _globalCatalog = [
    // December 2025 (Simulated Future Data)
    EntertainmentEvent(
      id: 'show_squid_game_2',
      title: 'Squid Game: Season 2',
      type: 'TV',
      releaseDate: DateTime(2025, 12, 26),
      network: 'Netflix',
      description: 'The games continue. Stakes are higher than ever.',
      emoji: '🦑',
    ),
    EntertainmentEvent(
      id: 'movie_avatar_3',
      title: 'Avatar: Fire and Ash',
      type: 'Movie',
      releaseDate: DateTime(2025, 12, 19),
      network: 'Theaters',
      description: 'Return to Pandora. Fire Na\'vi confirmed.',
      emoji: '🔥',
    ),
    EntertainmentEvent(
      id: 'show_white_lotus_3',
      title: 'The White Lotus: Thailand',
      type: 'TV',
      releaseDate: DateTime(2025, 11, 10), // Passed, but demonstrative
      network: 'HBO',
      description: 'Checking into the third season.',
      emoji: '🌺',
    ),
    EntertainmentEvent(
      id: 'show_stranger_things_5',
      title: 'Stranger Things 5',
      type: 'TV',
      releaseDate: DateTime.now().add(const Duration(days: 2)), // Mock: Releases "soon"
      network: 'Netflix',
      description: 'The final chapter begins.',
      emoji: '🚲',
    ),
     EntertainmentEvent(
      id: 'show_mandalorian_movie',
      title: 'The Mandalorian & Grogu',
      type: 'Movie',
      releaseDate: DateTime.now().add(const Duration(days: 5)), 
      network: 'Theaters',
      description: 'This is the way. To the big screen.',
      emoji: '🛡️',
    ),
  ];

  /// Get subscriptions
  static Future<List<String>> getSubscribedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_subscribedShowsKey) ?? [];
  }

  /// Subscribe
  static Future<void> subscribe(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_subscribedShowsKey) ?? [];
    if (!current.contains(id)) {
      current.add(id);
      await prefs.setStringList(_subscribedShowsKey, current);
    }
  }

  /// Unsubscribe
  static Future<void> unsubscribe(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_subscribedShowsKey) ?? [];
    current.remove(id);
    await prefs.setStringList(_subscribedShowsKey, current);
  }

  /// Get releases for a specific date (if subscribed)
  /// If [subscribedOnly] is false, shows ALL releases (for discovery)
  static Future<List<EntertainmentEvent>> getReleasesForDate(DateTime date, {bool subscribedOnly = true}) async {
    final subscribed = await getSubscribedIds();
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _globalCatalog.where((e) {
      final isSameDay = e.releaseDate.isAfter(startOfDay.subtract(const Duration(seconds: 1))) && 
                        e.releaseDate.isBefore(endOfDay.add(const Duration(seconds: 1)));
      if (!isSameDay) return false;
      if (subscribedOnly && !subscribed.contains(e.id)) return false;
      return true;
    }).toList();
  }

  /// Get upcoming releases (next 30 days)
  static Future<List<EntertainmentEvent>> getUpcomingReleases({bool subscribedOnly = true}) async {
    final subscribed = await getSubscribedIds();
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 30));

    return _globalCatalog.where((e) {
      final isUpcoming = e.releaseDate.isAfter(now) && e.releaseDate.isBefore(cutoff);
      if (!isUpcoming) return false;
      if (subscribedOnly && !subscribed.contains(e.id)) return false;
      return true;
    }).toList()..sort((a, b) => a.releaseDate.compareTo(b.releaseDate));
  }
  
  /// Get full catalog for discovery
  static List<EntertainmentEvent> getCatalog() {
    return _globalCatalog;
  }
}
