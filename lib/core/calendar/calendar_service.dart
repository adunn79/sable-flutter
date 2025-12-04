import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

/// Service for handling device calendar integration
/// Provides permission management, event fetching, and AI context formatting
class CalendarService {
  static final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  
  /// Request calendar permission from the user
  static Future<bool> requestPermission() async {
    try {
      final permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      debugPrint('📅 Calendar permission granted: ${permissionsGranted.isSuccess && permissionsGranted.data == true}');
      return permissionsGranted.isSuccess && permissionsGranted.data == true;
    } catch (e) {
      debugPrint('❌ Calendar permission request failed: $e');
      return false;
    }
  }
  
  /// Check if calendar permission has been granted
  static Future<bool> hasPermission() async {
    try {
      final permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      return permissionsGranted.isSuccess && permissionsGranted.data == true;
    } catch (e) {
      debugPrint('❌ Calendar permission check failed: $e');
      return false;
    }
  }
  
  /// Get all calendars from the device
  static Future<List<Calendar>> getCalendars() async {
    try {
      if (!await hasPermission()) {
        debugPrint('⚠️ No calendar permission');
        return [];
      }
      
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        return calendarsResult.data!;
      }
      return [];
    } catch (e) {
      debugPrint('❌ Failed to get calendars: $e');
      return [];
    }
  }
  
  /// Get today's events across all calendars
  static Future<List<Event>> getTodayEvents() async {
    try {
      if (!await hasPermission()) return [];
      
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      
      return await getEventsInRange(startOfDay, endOfDay);
    } catch (e) {
      debugPrint('❌ Failed to get today\'s events: $e');
      return [];
    }
  }
  
  /// Get upcoming events for the next N days
  static Future<List<Event>> getUpcomingEvents({int days = 7}) async {
    try {
      if (!await hasPermission()) return [];
      
      final now = DateTime.now();
      final endDate = now.add(Duration(days: days));
      
      return await getEventsInRange(now, endDate);
    } catch (e) {
      debugPrint('❌ Failed to get upcoming events: $e');
      return [];
    }
  }
  
  /// Get events in a specified date range
  static Future<List<Event>> getEventsInRange(DateTime start, DateTime end) async {
    try {
      if (!await hasPermission()) return [];
      
      final calendars = await getCalendars();
      final allEvents = <Event>[];
      
      for (final calendar in calendars) {
        if (calendar.id == null) continue;
        
        final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
          calendar.id!,
          RetrieveEventsParams(startDate: start, endDate: end),
        );
        
        if (eventsResult.isSuccess && eventsResult.data != null) {
          allEvents.addAll(eventsResult.data!);
        }
      }
      
      // Sort by start time
      allEvents.sort((a, b) {
        if (a.start == null && b.start == null) return 0;
        if (a.start == null) return 1;
        if (b.start == null) return -1;
        return a.start!.compareTo(b.start!);
      });
      
      return allEvents;
    } catch (e) {
      debugPrint('❌ Failed to get events in range: $e');
      return [];
    }
  }
  
  /// Create a new calendar event
  static Future<Event?> createEvent({
    required String title,
    String? description,
    String? location,
    required DateTime start,
    required DateTime end,
    bool allDay = false,
  }) async {
    try {
      if (!await hasPermission()) {
        debugPrint('⚠️ Cannot create event: no calendar permission');
        return null;
      }
      
      final calendars = await getCalendars();
      if (calendars.isEmpty) {
        debugPrint('⚠️ No calendars available');
        return null;
      }
      
      // Use first calendar (typically the default calendar)
      final calendar = calendars.first;
      
      final event = Event(
        calendar.id,
        title: title,
        description: description,
        location: location,
        start: tz.TZDateTime.from(start, tz.local),
        end: tz.TZDateTime.from(end, tz.local),
        allDay: allDay,
      );
      
      final createResult = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      
      if (createResult?.isSuccess == true) {
        debugPrint('✅ Event created: $title');
        return event;
      } else {
        debugPrint('❌ Failed to create event');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error creating event: $e');
      return null;
    }
  }
  
  /// Get formatted calendar summary for AI context
  static Future<String> getCalendarSummary() async {
    try {
      if (!await hasPermission()) {
        return '[CALENDAR]\nNo calendar access granted.\n[END CALENDAR]';
      }
      
      final todayEvents = await getTodayEvents();
      final upcomingEvents = await getUpcomingEvents(days: 7);
      
      final buffer = StringBuffer();
      buffer.writeln('[CALENDAR]');
      
      // Today's events
      buffer.writeln('Today: ${todayEvents.length} event${todayEvents.length == 1 ? '' : 's'}');
      if (todayEvents.isNotEmpty) {
        for (final event in todayEvents.take(5)) {  // Limit to 5 events
          final timeStr = _formatEventTime(event);
          buffer.writeln('- $timeStr: ${event.title ?? 'Untitled'}');
        }
      }
      
      // Upcoming events summary
      buffer.writeln();
      buffer.writeln('This Week: ${upcomingEvents.length} event${upcomingEvents.length == 1 ? '' : 's'}');
      
      // Group by day
      final eventsByDay = <String, int>{};
      for (final event in upcomingEvents) {
        if (event.start != null) {
          final dayKey = _formatDay(event.start!);
          eventsByDay[dayKey] = (eventsByDay[dayKey] ?? 0) + 1;
        }
      }
      
      // Show busy days
      eventsByDay.forEach((day, count) {
        if (count > 2) {
          buffer.writeln('- $day: Busy ($count events)');
        } else if (count > 0) {
          buffer.writeln('- $day: $count event${count == 1 ? '' : 's'}');
        }
      });
      
      if (eventsByDay.isEmpty) {
        buffer.writeln('- Nothing scheduled');
      }
      
      buffer.writeln('[END CALENDAR]');
      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Failed to generate calendar summary: $e');
      return '[CALENDAR]\nError loading calendar data.\n[END CALENDAR]';
    }
  }
  
  /// Format event time for display
  static String _formatEventTime(Event event) {
    if (event.allDay == true) {
      return 'All day';
    }
    
    if (event.start == null) {
      return 'No time';
    }
    
    final hour = event.start!.hour;
    final minute = event.start!.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final minuteStr = minute.toString().padLeft(2, '0');
    
    // Duration
    String duration = '';
    if (event.end != null) {
      final durationMinutes = event.end!.difference(event.start!).inMinutes;
      if (durationMinutes < 60) {
        duration = ' (${durationMinutes}min)';
      } else {
        final hours = durationMinutes ~/ 60;
        duration = ' (${hours}hr${hours > 1 ? 's' : ''})';
      }
    }
    
    return '$hour12:$minuteStr $period$duration';
  }
  
  /// Format day for grouping
  static String _formatDay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);
    
    final difference = eventDay.difference(today).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference < 7) {
      final weekday = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return weekday[date.weekday - 1];
    }
    
    return '${date.month}/${date.day}';
  }
}
