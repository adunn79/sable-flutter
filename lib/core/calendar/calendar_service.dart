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
      
      // If cached says yes, trust it - the 401 errors in simulator are often false negatives
      // The cache is only set when requestPermission() explicitly returns true
      if (cached) {
        debugPrint('📅 Trusting cached permission (simulator workaround)');
        return true;
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

  /// Check for calendar conflicts in a time window
  /// Returns list of conflicting events (empty if none)
  /// [bufferMinutes] adds padding before/after to prevent back-to-back events
  static Future<List<Event>> checkConflicts({
    required DateTime start,
    required DateTime end,
    int bufferMinutes = 15,
  }) async {
    try {
      if (!await hasPermission()) return [];
      
      // Expand window by buffer on both ends
      final windowStart = start.subtract(Duration(minutes: bufferMinutes));
      final windowEnd = end.add(Duration(minutes: bufferMinutes));
      
      final events = await getEventsInRange(windowStart, windowEnd);
      
      // Filter to only truly overlapping events (not just buffer-adjacent)
      return events.where((event) {
        if (event.start == null || event.end == null) return false;
        final eventStart = event.start!;
        final eventEnd = event.end!;
        
        // True overlap: event starts before our end AND event ends after our start
        return eventStart.isBefore(end) && eventEnd.isAfter(start);
      }).toList();
    } catch (e) {
      debugPrint('❌ Failed to check conflicts: $e');
      return [];
    }
  }

  /// Check if a specific time slot is completely free
  static Future<bool> isTimeFree(DateTime start, DateTime end) async {
    final conflicts = await checkConflicts(start: start, end: end, bufferMinutes: 0);
    return conflicts.isEmpty;
  }

  /// Suggest alternative times when a conflict is detected
  /// Returns up to 3 alternative time slots CLOSE to the original requested time
  static Future<List<DateTime>> suggestAlternativeTimes({
    required DateTime originalStart,
    required int durationMinutes,
    int maxSuggestions = 3,
  }) async {
    try {
      if (!await hasPermission()) return [];
      
      final suggestions = <DateTime>[];
      final dayStart = DateTime(originalStart.year, originalStart.month, originalStart.day, 6, 0);
      final dayEnd = DateTime(originalStart.year, originalStart.month, originalStart.day, 23, 0);
      
      // Fetch all events for the day
      final dayEvents = await getEventsInRange(dayStart, dayEnd);
      
      // Sort by start time
      dayEvents.sort((a, b) => (a.start ?? dayStart).compareTo(b.start ?? dayStart));
      
      // Search around the original time - check times before AND after
      // Start with times AFTER the original, then check before
      final checkOffsets = [30, 60, 90, -30, 120, -60, 150, -90, 180, -120];
      
      for (final offsetMinutes in checkOffsets) {
        if (suggestions.length >= maxSuggestions) break;
        
        final checkTime = originalStart.add(Duration(minutes: offsetMinutes));
        
        // Skip if outside reasonable hours
        if (checkTime.isBefore(dayStart) || checkTime.isAfter(dayEnd)) continue;
        
        final checkEnd = checkTime.add(Duration(minutes: durationMinutes));
        
        // Skip if extends past end of day
        if (checkEnd.isAfter(dayEnd.add(const Duration(hours: 1)))) continue;
        
        // Check if slot is free
        final hasConflict = dayEvents.any((event) {
          if (event.start == null || event.end == null) return false;
          return event.start!.isBefore(checkEnd) && event.end!.isAfter(checkTime);
        });
        
        if (!hasConflict) {
          suggestions.add(checkTime);
        }
      }
      
      // Sort suggestions by how close they are to original time
      suggestions.sort((a, b) {
        final diffA = (a.difference(originalStart).inMinutes).abs();
        final diffB = (b.difference(originalStart).inMinutes).abs();
        return diffA.compareTo(diffB);
      });
      
      return suggestions.take(maxSuggestions).toList();
    } catch (e) {
      debugPrint('❌ Failed to suggest alternative times: $e');
      return [];
    }
  }

  /// Update an existing calendar event
  static Future<Event?> updateEvent({
    required String calendarId,
    required String eventId,
    String? newTitle,
    DateTime? newStart,
    DateTime? newEnd,
    String? newLocation,
    String? newDescription,
  }) async {
    try {
      if (!await hasPermission()) return null;
      
      // First retrieve the existing event
      final calendars = await getCalendars();
      Event? existingEvent;
      
      for (final calendar in calendars) {
        if (calendar.id == calendarId) {
          final result = await _deviceCalendarPlugin.retrieveEvents(
            calendarId,
            RetrieveEventsParams(
              eventIds: [eventId],
            ),
          );
          if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
            existingEvent = result.data!.first;
            break;
          }
        }
      }
      
      if (existingEvent == null) {
        debugPrint('⚠️ Event not found for update: $eventId');
        return null;
      }
      
      // Create timezone location for updated times
      final offset = (newStart ?? existingEvent.start)?.timeZoneOffset ?? Duration.zero;
      final tzLocation = tz.timeZoneDatabase.locations.values.firstWhere(
        (loc) {
          final now = tz.TZDateTime.now(loc);
          return now.timeZoneOffset == offset;
        },
        orElse: () => tz.UTC,
      );
      
      // Apply updates
      if (newTitle != null) existingEvent.title = newTitle;
      if (newLocation != null) existingEvent.location = newLocation;
      if (newDescription != null) existingEvent.description = newDescription;
      
      if (newStart != null) {
        existingEvent.start = tz.TZDateTime(
          tzLocation,
          newStart.year, newStart.month, newStart.day,
          newStart.hour, newStart.minute, newStart.second,
        );
      }
      
      if (newEnd != null) {
        existingEvent.end = tz.TZDateTime(
          tzLocation,
          newEnd.year, newEnd.month, newEnd.day,
          newEnd.hour, newEnd.minute, newEnd.second,
        );
      }
      
      // Save the updated event
      final result = await _deviceCalendarPlugin.createOrUpdateEvent(existingEvent);
      
      if (result?.isSuccess == true) {
        debugPrint('✅ Event updated: ${existingEvent.title}');
        return existingEvent;
      } else {
        debugPrint('❌ Failed to update event: ${result?.errors.map((e) => e.errorMessage).join(', ')}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error updating event: $e');
      return null;
    }
  }

  /// Search for events by title (fuzzy match)
  /// Returns events from the last 7 days through next 30 days matching the title
  static Future<List<Event>> searchEventsByTitle(String query) async {
    try {
      if (!await hasPermission()) return [];
      
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 7));
      final end = now.add(const Duration(days: 30));
      
      final allEvents = await getEventsInRange(start, end);
      
      // Fuzzy match on title
      final lowerQuery = query.toLowerCase();
      return allEvents.where((event) {
        final title = event.title?.toLowerCase() ?? '';
        return title.contains(lowerQuery) || 
               lowerQuery.split(' ').any((word) => title.contains(word));
      }).toList();
    } catch (e) {
      debugPrint('❌ Failed to search events: $e');
      return [];
    }
  }

  /// Get a specific event by ID
  static Future<Event?> getEventById(String calendarId, String eventId) async {
    try {
      if (!await hasPermission()) return null;
      
      final result = await _deviceCalendarPlugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(eventIds: [eventId]),
      );
      
      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        return result.data!.first;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Failed to get event: $e');
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
