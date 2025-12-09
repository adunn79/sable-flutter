import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Represents an event from an iCal feed
class ICalEvent {
  final String uid;
  final String title;
  final DateTime start;
  final DateTime? end;
  final bool isAllDay;
  final String? description;
  final String? location;
  final String sourceCalendar;

  ICalEvent({
    required this.uid,
    required this.title,
    required this.start,
    this.end,
    this.isAllDay = false,
    this.description,
    this.location,
    required this.sourceCalendar,
  });

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'title': title,
    'start': start.toIso8601String(),
    'end': end?.toIso8601String(),
    'isAllDay': isAllDay,
    'description': description,
    'location': location,
    'sourceCalendar': sourceCalendar,
  };

  factory ICalEvent.fromJson(Map<String, dynamic> json) => ICalEvent(
    uid: json['uid'],
    title: json['title'],
    start: DateTime.parse(json['start']),
    end: json['end'] != null ? DateTime.parse(json['end']) : null,
    isAllDay: json['isAllDay'] ?? false,
    description: json['description'],
    location: json['location'],
    sourceCalendar: json['sourceCalendar'],
  );
}

/// Pre-defined holiday calendar sources
class HolidayCalendar {
  final String id;
  final String name;
  final String url;
  final String emoji;

  const HolidayCalendar({
    required this.id,
    required this.name,
    required this.url,
    required this.emoji,
  });

  static const usHolidays = HolidayCalendar(
    id: 'us_holidays',
    name: 'US Holidays',
    url: 'https://www.google.com/calendar/ical/en.usa%23holiday%40group.v.calendar.google.com/public/basic.ics',
    emoji: '🇺🇸',
  );

  static const ukHolidays = HolidayCalendar(
    id: 'uk_holidays',
    name: 'UK Holidays',
    url: 'https://www.google.com/calendar/ical/en.uk%23holiday%40group.v.calendar.google.com/public/basic.ics',
    emoji: '🇬🇧',
  );

  static const canadaHolidays = HolidayCalendar(
    id: 'canada_holidays',
    name: 'Canadian Holidays',
    url: 'https://www.google.com/calendar/ical/en.canadian%23holiday%40group.v.calendar.google.com/public/basic.ics',
    emoji: '🇨🇦',
  );

  static const jewishHolidays = HolidayCalendar(
    id: 'jewish_holidays',
    name: 'Jewish Holidays',
    url: 'https://www.google.com/calendar/ical/en.jewish%23holiday%40group.v.calendar.google.com/public/basic.ics',
    emoji: '✡️',
  );

  static const islamicHolidays = HolidayCalendar(
    id: 'islamic_holidays',
    name: 'Islamic Holidays',
    url: 'https://www.google.com/calendar/ical/en.islamic%23holiday%40group.v.calendar.google.com/public/basic.ics',
    emoji: '☪️',
  );

  static const hinduHolidays = HolidayCalendar(
    id: 'hindu_holidays',
    name: 'Hindu Holidays',
    url: 'https://www.google.com/calendar/ical/en.hinduism%23holiday%40group.v.calendar.google.com/public/basic.ics',
    emoji: '🕉️',
  );

  static const christianHolidays = HolidayCalendar(
    id: 'christian_holidays',
    name: 'Christian Holidays',
    url: 'https://www.google.com/calendar/ical/en.christian%23holiday%40group.v.calendar.google.com/public/basic.ics',
    emoji: '✝️',
  );

  static List<HolidayCalendar> get all => [
    usHolidays,
    ukHolidays,
    canadaHolidays,
    jewishHolidays,
    islamicHolidays,
    hinduHolidays,
    christianHolidays,
  ];
}

/// Service for managing iCal calendar subscriptions
class ICalSubscriptionService {
  static const _subscribedCalendarsKey = 'subscribed_calendars';
  static const _cachedEventsKey = 'cached_ical_events';
  static const _lastFetchKey = 'ical_last_fetch';

  /// Get list of subscribed calendar IDs
  static Future<List<String>> getSubscribedCalendars() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_subscribedCalendarsKey) ?? [];
  }

  /// Subscribe to a calendar
  static Future<void> subscribe(String calendarId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_subscribedCalendarsKey) ?? [];
    if (!current.contains(calendarId)) {
      current.add(calendarId);
      await prefs.setStringList(_subscribedCalendarsKey, current);
      // Fetch events for the new calendar
      await _fetchAndCacheCalendar(calendarId);
    }
  }

  /// Unsubscribe from a calendar
  static Future<void> unsubscribe(String calendarId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_subscribedCalendarsKey) ?? [];
    current.remove(calendarId);
    await prefs.setStringList(_subscribedCalendarsKey, current);
    // Remove cached events for this calendar
    await _removeCachedEvents(calendarId);
  }

  /// Fetch all subscribed calendar events
  static Future<List<ICalEvent>> getAllSubscribedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cachedEventsKey);
    
    if (cachedJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        return decoded.map((e) => ICalEvent.fromJson(e)).toList();
      } catch (e) {
        debugPrint('❌ Error decoding cached events: $e');
      }
    }
    return [];
  }

  /// Get events for a specific date range
  static Future<List<ICalEvent>> getEventsForRange(DateTime start, DateTime end) async {
    final allEvents = await getAllSubscribedEvents();
    return allEvents.where((event) {
      return event.start.isAfter(start.subtract(const Duration(days: 1))) &&
             event.start.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  /// Get today's holiday events
  static Future<List<ICalEvent>> getTodayHolidays() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return getEventsForRange(today, tomorrow);
  }

  /// Refresh all subscribed calendars
  static Future<void> refreshAll() async {
    final subscribed = await getSubscribedCalendars();
    for (final calendarId in subscribed) {
      await _fetchAndCacheCalendar(calendarId);
    }
  }

  /// Parse iCal format
  static List<ICalEvent> _parseICal(String icalData, String sourceCalendar) {
    final events = <ICalEvent>[];
    final lines = icalData.split('\n');
    
    String? uid;
    String? summary;
    DateTime? dtStart;
    DateTime? dtEnd;
    bool isAllDay = false;
    String? description;
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
        isAllDay = false;
        description = null;
        location = null;
      } else if (line == 'END:VEVENT' && inEvent) {
        if (uid != null && summary != null && dtStart != null) {
          events.add(ICalEvent(
            uid: uid,
            title: summary,
            start: dtStart,
            end: dtEnd,
            isAllDay: isAllDay,
            description: description,
            location: location,
            sourceCalendar: sourceCalendar,
          ));
        }
        inEvent = false;
      } else if (inEvent) {
        if (line.startsWith('UID:')) {
          uid = line.substring(4);
        } else if (line.startsWith('SUMMARY:')) {
          summary = line.substring(8);
        } else if (line.startsWith('DTSTART;VALUE=DATE:')) {
          isAllDay = true;
          dtStart = _parseDate(line.substring(19));
        } else if (line.startsWith('DTSTART:')) {
          dtStart = _parseDateTime(line.substring(8));
        } else if (line.startsWith('DTEND;VALUE=DATE:')) {
          dtEnd = _parseDate(line.substring(17));
        } else if (line.startsWith('DTEND:')) {
          dtEnd = _parseDateTime(line.substring(6));
        } else if (line.startsWith('DESCRIPTION:')) {
          description = line.substring(12);
        } else if (line.startsWith('LOCATION:')) {
          location = line.substring(9);
        }
      }
    }
    
    return events;
  }

  static DateTime? _parseDate(String dateStr) {
    try {
      // Format: YYYYMMDD
      if (dateStr.length >= 8) {
        return DateTime(
          int.parse(dateStr.substring(0, 4)),
          int.parse(dateStr.substring(4, 6)),
          int.parse(dateStr.substring(6, 8)),
        );
      }
    } catch (e) {
      debugPrint('Error parsing date: $dateStr');
    }
    return null;
  }

  static DateTime? _parseDateTime(String dtStr) {
    try {
      // Format: YYYYMMDDTHHMMSSZ or YYYYMMDDTHHMMSS
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

  static Future<void> _fetchAndCacheCalendar(String calendarId) async {
    try {
      final calendar = HolidayCalendar.all.firstWhere(
        (c) => c.id == calendarId,
        orElse: () => throw Exception('Calendar not found: $calendarId'),
      );

      final response = await http.get(Uri.parse(calendar.url));
      if (response.statusCode == 200) {
        final events = _parseICal(response.body, calendar.name);
        
        // Merge with existing cached events
        final allEvents = await getAllSubscribedEvents();
        allEvents.removeWhere((e) => e.sourceCalendar == calendar.name);
        allEvents.addAll(events);
        
        // Save to cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _cachedEventsKey,
          jsonEncode(allEvents.map((e) => e.toJson()).toList()),
        );
        await prefs.setString(_lastFetchKey, DateTime.now().toIso8601String());
        
        debugPrint('📅 Cached ${events.length} events from ${calendar.name}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching calendar $calendarId: $e');
    }
  }

  static Future<void> _removeCachedEvents(String calendarId) async {
    try {
      final calendar = HolidayCalendar.all.firstWhere(
        (c) => c.id == calendarId,
        orElse: () => throw Exception('Calendar not found'),
      );
      
      final allEvents = await getAllSubscribedEvents();
      allEvents.removeWhere((e) => e.sourceCalendar == calendar.name);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cachedEventsKey,
        jsonEncode(allEvents.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('❌ Error removing cached events: $e');
    }
  }
}
