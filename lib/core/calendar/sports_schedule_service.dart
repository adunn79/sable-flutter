import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a sports team
class SportsTeam {
  final String id;
  final String name;
  final String league;
  final String emoji;
  final String? icalUrl;

  const SportsTeam({
    required this.id,
    required this.name,
    required this.league,
    required this.emoji,
    this.icalUrl,
  });
}

/// Sports leagues
enum SportsLeague {
  nfl,
  nba,
  mlb,
  nhl,
  f1,
  premierLeague,
  laLiga,
  mls,
}

/// Represents a sports event/game
class SportsEvent {
  final String id;
  final String title;
  final DateTime start;
  final DateTime? end;
  final String team;
  final String league;
  final String? opponent;
  final String? venue;
  final bool isHomeGame;

  SportsEvent({
    required this.id,
    required this.title,
    required this.start,
    this.end,
    required this.team,
    required this.league,
    this.opponent,
    this.venue,
    this.isHomeGame = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start': start.toIso8601String(),
    'end': end?.toIso8601String(),
    'team': team,
    'league': league,
    'opponent': opponent,
    'venue': venue,
    'isHomeGame': isHomeGame,
  };

  factory SportsEvent.fromJson(Map<String, dynamic> json) => SportsEvent(
    id: json['id'],
    title: json['title'],
    start: DateTime.parse(json['start']),
    end: json['end'] != null ? DateTime.parse(json['end']) : null,
    team: json['team'],
    league: json['league'],
    opponent: json['opponent'],
    venue: json['venue'],
    isHomeGame: json['isHomeGame'] ?? false,
  );
}

/// Service for managing sports schedule subscriptions
class SportsScheduleService {
  static const _subscribedTeamsKey = 'subscribed_sports_teams';
  static const _cachedGamesKey = 'cached_sports_games';

  /// Popular teams with their iCal URLs (when available)
  /// Note: Many of these require API integrations for real-time data
  static const List<SportsTeam> popularTeams = [
    // NFL
    SportsTeam(id: 'nfl_49ers', name: 'San Francisco 49ers', league: 'NFL', emoji: '🏈'),
    SportsTeam(id: 'nfl_chiefs', name: 'Kansas City Chiefs', league: 'NFL', emoji: '🏈'),
    SportsTeam(id: 'nfl_cowboys', name: 'Dallas Cowboys', league: 'NFL', emoji: '🏈'),
    SportsTeam(id: 'nfl_packers', name: 'Green Bay Packers', league: 'NFL', emoji: '🏈'),
    SportsTeam(id: 'nfl_eagles', name: 'Philadelphia Eagles', league: 'NFL', emoji: '🏈'),
    
    // NBA
    SportsTeam(id: 'nba_warriors', name: 'Golden State Warriors', league: 'NBA', emoji: '🏀'),
    SportsTeam(id: 'nba_lakers', name: 'Los Angeles Lakers', league: 'NBA', emoji: '🏀'),
    SportsTeam(id: 'nba_celtics', name: 'Boston Celtics', league: 'NBA', emoji: '🏀'),
    SportsTeam(id: 'nba_bulls', name: 'Chicago Bulls', league: 'NBA', emoji: '🏀'),
    SportsTeam(id: 'nba_knicks', name: 'New York Knicks', league: 'NBA', emoji: '🏀'),
    
    // F1 (has public iCal)
    SportsTeam(
      id: 'f1_calendar', 
      name: 'Formula 1', 
      league: 'F1', 
      emoji: '🏎️',
      icalUrl: 'https://files-f1.motorsportcalendars.com/f1-calendar_p1_p2_p3_q_sr_gp.ics',
    ),
    
    // Premier League
    SportsTeam(id: 'epl_arsenal', name: 'Arsenal', league: 'Premier League', emoji: '⚽'),
    SportsTeam(id: 'epl_mancity', name: 'Manchester City', league: 'Premier League', emoji: '⚽'),
    SportsTeam(id: 'epl_liverpool', name: 'Liverpool', league: 'Premier League', emoji: '⚽'),
    SportsTeam(id: 'epl_chelsea', name: 'Chelsea', league: 'Premier League', emoji: '⚽'),
    SportsTeam(id: 'epl_manu', name: 'Manchester United', league: 'Premier League', emoji: '⚽'),
  ];

  /// Get list of teams for a specific league
  static List<SportsTeam> getTeamsForLeague(String league) {
    return popularTeams.where((t) => t.league == league).toList();
  }

  /// Get all available leagues
  static List<String> getAvailableLeagues() {
    return popularTeams.map((t) => t.league).toSet().toList();
  }

  /// Get subscribed team IDs
  static Future<List<String>> getSubscribedTeams() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_subscribedTeamsKey) ?? [];
  }

  /// Subscribe to a team
  static Future<void> subscribe(String teamId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_subscribedTeamsKey) ?? [];
    if (!current.contains(teamId)) {
      current.add(teamId);
      await prefs.setStringList(_subscribedTeamsKey, current);
      
      // Fetch schedule if team has iCal URL
      final team = popularTeams.firstWhere(
        (t) => t.id == teamId,
        orElse: () => SportsTeam(id: teamId, name: 'Unknown', league: 'Unknown', emoji: '🏆'),
      );
      if (team.icalUrl != null) {
        await _fetchTeamSchedule(team);
      }
    }
  }

  /// Unsubscribe from a team
  static Future<void> unsubscribe(String teamId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_subscribedTeamsKey) ?? [];
    current.remove(teamId);
    await prefs.setStringList(_subscribedTeamsKey, current);
  }

  /// Get all subscribed team events
  static Future<List<SportsEvent>> getUpcomingGames({int days = 30}) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cachedGamesKey);
    
    if (cachedJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        final events = decoded.map((e) => SportsEvent.fromJson(e)).toList();
        
        // Filter for upcoming only
        final now = DateTime.now();
        final cutoff = now.add(Duration(days: days));
        return events.where((e) => 
          e.start.isAfter(now) && e.start.isBefore(cutoff)
        ).toList()..sort((a, b) => a.start.compareTo(b.start));
      } catch (e) {
        debugPrint('❌ Error decoding cached games: $e');
      }
    }
    return [];
  }

  /// Get games for today
  static Future<List<SportsEvent>> getTodayGames() async {
    final all = await getUpcomingGames();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    return all.where((e) => 
      e.start.isAfter(today) && e.start.isBefore(tomorrow)
    ).toList();
  }

  /// Refresh schedules for all subscribed teams
  static Future<void> refreshAll() async {
    final subscribedIds = await getSubscribedTeams();
    for (final teamId in subscribedIds) {
      final team = popularTeams.firstWhere(
        (t) => t.id == teamId,
        orElse: () => SportsTeam(id: teamId, name: 'Unknown', league: 'Unknown', emoji: '🏆'),
      );
      if (team.icalUrl != null) {
        await _fetchTeamSchedule(team);
      }
    }
  }

  static Future<void> _fetchTeamSchedule(SportsTeam team) async {
    if (team.icalUrl == null) return;
    
    try {
      final response = await http.get(Uri.parse(team.icalUrl!));
      if (response.statusCode == 200) {
        final events = _parseICal(response.body, team);
        
        // Merge with existing cached events
        final prefs = await SharedPreferences.getInstance();
        final cachedJson = prefs.getString(_cachedGamesKey);
        List<SportsEvent> allEvents = [];
        
        if (cachedJson != null) {
          try {
            final List<dynamic> decoded = jsonDecode(cachedJson);
            allEvents = decoded.map((e) => SportsEvent.fromJson(e)).toList();
          } catch (_) {}
        }
        
        // Remove old events for this team
        allEvents.removeWhere((e) => e.team == team.name);
        allEvents.addAll(events);
        
        // Save
        await prefs.setString(
          _cachedGamesKey,
          jsonEncode(allEvents.map((e) => e.toJson()).toList()),
        );
        
        debugPrint('🏆 Cached ${events.length} games for ${team.name}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching ${team.name} schedule: $e');
    }
  }

  static List<SportsEvent> _parseICal(String icalData, SportsTeam team) {
    final events = <SportsEvent>[];
    final lines = icalData.split('\n');
    
    String? uid;
    String? summary;
    DateTime? dtStart;
    DateTime? dtEnd;
    String? location;
    bool inEvent = false;

    for (var line in lines) {
      line = line.trim();
      
      if (line == 'BEGIN:VEVENT') {
        inEvent = true;
        uid = null;
        summary = null;
        dtStart = null;
        dtEnd = null;
        location = null;
      } else if (line == 'END:VEVENT' && inEvent) {
        if (uid != null && summary != null && dtStart != null) {
          events.add(SportsEvent(
            id: uid,
            title: summary,
            start: dtStart,
            end: dtEnd,
            team: team.name,
            league: team.league,
            venue: location,
          ));
        }
        inEvent = false;
      } else if (inEvent) {
        if (line.startsWith('UID:')) {
          uid = line.substring(4);
        } else if (line.startsWith('SUMMARY:')) {
          summary = line.substring(8);
        } else if (line.startsWith('DTSTART:')) {
          dtStart = _parseDateTime(line.substring(8));
        } else if (line.startsWith('DTEND:')) {
          dtEnd = _parseDateTime(line.substring(6));
        } else if (line.startsWith('LOCATION:')) {
          location = line.substring(9);
        }
      }
    }
    
    return events;
  }

  static DateTime? _parseDateTime(String dtStr) {
    try {
      if (dtStr.length >= 15) {
        return DateTime(
          int.parse(dtStr.substring(0, 4)),
          int.parse(dtStr.substring(4, 6)),
          int.parse(dtStr.substring(6, 8)),
          int.parse(dtStr.substring(9, 11)),
          int.parse(dtStr.substring(11, 13)),
          int.parse(dtStr.substring(13, 15)),
        );
      }
    } catch (e) {
      debugPrint('Error parsing datetime: $dtStr');
    }
    return null;
  }
}
