import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Service for handling device calendar integration
/// Provides permission management, event fetching, and AI context formatting
class CalendarService {
  static final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  static const String _permissionCacheKey = 'calendar_permission_granted';
  
  /// Request calendar permission from the user
  static Future<bool> requestPermission() async {
    try {
      final permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      final granted = permissionsGranted.isSuccess && permissionsGranted.data == true;
      debugPrint('📅 Calendar permission granted: $granted');
      
      if (granted) {
        // Cache the permission state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_permissionCacheKey, true);
        debugPrint('📅 Permission cached to SharedPreferences');
      }
      
      return granted;
    } catch (e) {
      debugPrint('❌ Calendar permission request failed: $e');
      return false;
    }
  }
  
  /// Check if calendar permission has been granted
  /// Uses both device check AND cached value to work around iOS simulator bugs
  static Future<bool> hasPermission() async {
    try {
      // First check device calendar plugin
      final permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      final hasIt = permissionsGranted.isSuccess && permissionsGranted.data == true;
      debugPrint('📅 Calendar hasPermission check: plugin=$hasIt');
      
      if (hasIt) return true;
      
      // Fallback: check cached value (works around iOS simulator reset bug)
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getBool(_permissionCacheKey) ?? false;
      debugPrint('📅 Calendar hasPermission cached: $cached');
      
      // If cached says yes, try to verify by attempting to get calendars
      if (cached) {
        try {
          final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
          if (calendarsResult.isSuccess && calendarsResult.data != null && calendarsResult.data!.isNotEmpty) {
            debugPrint('📅 Permission verified via calendar retrieval');
            return true;
          }
        } catch (e) {
          debugPrint('📅 Calendar verification failed: $e');
        }
      }
      
      return hasIt;
    } catch (e) {
      debugPrint('❌ Calendar permission check failed: $e');
      return false;
    }
  }
  
  /// Get all calendars from the device
  /// Works around iOS simulator permission bug by trying direct retrieval
  static Future<List<Calendar>> getCalendars() async {
    try {
      // First, try direct retrieval (works around permission check bug)
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getBool(_permissionCacheKey) ?? false;
      
      if (cached) {
        debugPrint('📅 Cached permission found, trying direct calendar retrieval...');
        try {
          final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
          if (calendarsResult.isSuccess && calendarsResult.data != null) {
            debugPrint('📅 Direct retrieval succeeded: ${calendarsResult.data!.length} calendars');
            return calendarsResult.data!;
          }
        } catch (e) {
          debugPrint('📅 Direct retrieval failed: $e');
          // Clear cached permission if retrieval fails with 401
          if (e.toString().contains('401')) {
            debugPrint('📅 Clearing cached permission due to 401 error');
            await prefs.setBool(_permissionCacheKey, false);
          }
        }
      }
      
      // Standard path: check permission, then retrieve
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
  
  /// Create a new calendar event with optional invitees, recurrence, and reminders
  static Future<Event?> createEvent({
    required String title,
    String? description,
    String? location,
    required DateTime start,
    required DateTime end,
    bool allDay = false,
    List<Attendee>? attendees,
    RecurrenceRule? recurrenceRule,
    List<Reminder>? reminders,
    String? url,
    Availability? availability,
  }) async {
    try {
      debugPrint('📅 createEvent called: $title at $start');
      
      // Check permission, request if needed
      var hasPerm = await hasPermission();
      debugPrint('📅 Initial hasPermission: $hasPerm');
      
      if (!hasPerm) {
        debugPrint('📅 No permission, requesting...');
        hasPerm = await requestPermission();
        debugPrint('📅 After request: $hasPerm');
      }
      
      if (!hasPerm) {
        debugPrint('⚠️ Cannot create event: no calendar permission after request');
        return null;
      }
      
      final calendars = await getCalendars();
      debugPrint('📅 Found ${calendars.length} calendars');
      if (calendars.isEmpty) {
        debugPrint('⚠️ No calendars available');
        return null;
      }
      
      // Use first writable calendar (typically the default calendar)
      final calendar = calendars.firstWhere((c) => c.isReadOnly == false, orElse: () => calendars.first);
      
      // Create a timezone location matching the device's offset
      // This ensures the event displays at the correct local time
      final offset = start.timeZoneOffset;
      
      // Try to find a matching timezone in the database
      final tzLocation = tz.timeZoneDatabase.locations.values.firstWhere(
        (loc) {
          final now = tz.TZDateTime.now(loc);
          return now.timeZoneOffset == offset;
        },
        orElse: () => tz.UTC, // Fallback to UTC if no match
      );
      
      debugPrint('📍 Using timezone: ${tzLocation.name} (offset: ${offset.inHours}h)');
      
      final event = Event(
        calendar.id,
        title: title,
        description: description,
        location: location,
        start: tz.TZDateTime(
          tzLocation,
          start.year,
          start.month,
          start.day,
          start.hour,
          start.minute,
          start.second,
          start.millisecond,
          start.microsecond,
        ),
        end: tz.TZDateTime(
          tzLocation,
          end.year,
          end.month,
          end.day,
          end.hour,
          end.minute,
          end.second,
          end.millisecond,
          end.microsecond,
        ),
        allDay: allDay,
        attendees: attendees,
        recurrenceRule: recurrenceRule,
        reminders: reminders,
        url: url != null ? Uri.parse(url) : null,
      );
      
      // Set availability if provided (it's not nullable in the Event constructor)
      if (availability != null) {
        event.availability = availability;
      }
      
      final createResult = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      
      if (createResult?.isSuccess == true) {
        debugPrint('✅ Event created: $title');
        // Return the created event (might need to fetch it back to get ID, but for now return this)
        // actually device_calendar returns the ID string in data.
        if (createResult!.data != null) {
          event.eventId = createResult.data;
        }
        return event;
      } else {
        debugPrint('❌ Failed to create event: ${createResult?.errors.map((e) => e.errorMessage).join(', ')}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error creating event: $e');
      return null;
    }
  }

  /// Delete a calendar event
  static Future<bool> deleteEvent(String calendarId, String eventId) async {
    try {
      if (!await hasPermission()) return false;
      
      final result = await _deviceCalendarPlugin.deleteEvent(calendarId, eventId);
      return result.isSuccess && result.data == true;
    } catch (e) {
      debugPrint('❌ Failed to delete event: $e');
      return false;
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
