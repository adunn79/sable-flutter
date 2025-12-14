import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../calendar/calendar_service.dart';
import 'tool_registry.dart';

/// AI Tools for calendar event management
class CalendarTools {
  /// Create a calendar event
  /// Returns JSON with success/failure and event details
  static Future<ToolResult> createCalendarEvent(Map<String, dynamic> params) async {
    debugPrint('🗓️ CalendarTools.createCalendarEvent called with: $params');
    final title = params['title'] as String;
    final startTimeStr = params['startTime'] as String;
    final startTime = DateTime.parse(startTimeStr);
    final description = params['description'] as String?;
    final location = params['location'] as String?;
    final endTime = params['endTime'] != null 
      ? DateTime.parse(params['endTime'] as String)
      : null;
    final allDay = params['allDay'] as bool? ?? false;
    
    // Location is optional for all events including meals
    // User can add location in original request or skip it
    
    try {
      // Check permissions first
      debugPrint('🗓️ Checking calendar permission...');
      if (!await CalendarService.hasPermission()) {
        debugPrint('🗓️ No permission, requesting...');
        final granted = await CalendarService.requestPermission();
        if (!granted) {
          debugPrint('❌ Calendar permission denied');
          return ToolResult.error(
          'Calendar permission denied',
          userMessage: 'I don\'t have permission to access your calendar. You can grant access in Settings > Aeliana > Calendar.',
          );
        }
      }
      debugPrint('✅ Calendar permission OK');

      // Set end time if not provided (1 hour after start)
      final eventEnd = endTime ?? startTime.add(const Duration(hours: 1));

      // Create the event
      debugPrint('🗓️ Creating event: $title at $startTime (IsUTC: ${startTime.isUtc}, TZ: ${startTime.timeZoneName})');
      final event = await CalendarService.createEvent(
        title: title,
        description: description,
        location: location,
        start: startTime,
        end: eventEnd,
        allDay: allDay,
      );

      if (event == null) {
        debugPrint('❌ CalendarService.createEvent returned null');
        return ToolResult.error(
          'Failed to create calendar event',
          userMessage: 'I couldn\'t create the calendar event. Make sure you have a calendar set up on your device.',
        );
      }
      debugPrint('✅ Event created successfully: ${event.eventId}');

      // Format rich success message
      final dateFormatter = DateFormat('EEEE, MMM d');
      final timeFormatter = DateFormat('h:mm a');
      final endTimeFormatter = DateFormat('h:mm a');
      final dateStr = dateFormatter.format(startTime);
      final startTimeStr = allDay ? 'All day' : timeFormatter.format(startTime);
      final endTimeStr = endTimeFormatter.format(eventEnd);
      
      // Build detailed message
      final buffer = StringBuffer();
      buffer.writeln('✅ Created: $title');
      buffer.writeln('📅 $dateStr at $startTimeStr - $endTimeStr');
      if (location != null && location.isNotEmpty) {
        buffer.writeln('📍 $location');
      }
      if (description != null && description.isNotEmpty) {
        buffer.writeln('📝 $description');
      }
      
      final message = buffer.toString().trim();

      return ToolResult.success(
        {
          'event_id': event.eventId,
          'title': title,
          'start': startTime.toIso8601String(),
          'end': eventEnd.toIso8601String(),
          'location': location,
          'all_day': allDay,
        },
        userMessage: message,
      );
    } catch (e) {
      return ToolResult.error(
        'Error creating calendar event: $e',
        userMessage: 'I encountered an error while creating the calendar event. Please try again.',
      );
    }
  }
  /// Get calendar events in a date range
  /// Returns list of events with their details
  static Future<ToolResult> getCalendarEvents(Map<String, dynamic> params) async {
    debugPrint('🗓️ CalendarTools.getCalendarEvents called with: $params');
    
    try {
      // Check permissions first
      if (!await CalendarService.hasPermission()) {
        final granted = await CalendarService.requestPermission();
        if (!granted) {
          return ToolResult.error(
            'Calendar permission denied',
            userMessage: 'I need calendar access to see your events.',
          );
        }
      }

      // Parse date range
      final startStr = params['startDate'] as String?;
      final endStr = params['endDate'] as String?;
      
      final start = startStr != null 
          ? DateTime.parse(startStr) 
          : DateTime.now().subtract(const Duration(days: 1));
      final end = endStr != null 
          ? DateTime.parse(endStr) 
          : DateTime.now().add(const Duration(days: 7));

      // Get events
      final events = await CalendarService.getEventsInRange(start, end);
      
      if (events.isEmpty) {
        return ToolResult.success(
          {'events': [], 'count': 0},
          userMessage: 'No events found in that time range. 📅',
        );
      }

      // Format events for response
      final eventList = events.map((e) => {
        'id': e.eventId,
        'title': e.title,
        'start': e.start?.toIso8601String(),
        'end': e.end?.toIso8601String(),
        'location': e.location,
        'all_day': e.allDay,
      }).toList();

      final dateFormatter = DateFormat('MMM d');
      return ToolResult.success(
        {'events': eventList, 'count': events.length},
        userMessage: 'Found ${events.length} events from ${dateFormatter.format(start)} to ${dateFormatter.format(end)}.',
      );
    } catch (e) {
      return ToolResult.error(
        'Error getting calendar events: $e',
        userMessage: 'I had trouble accessing your calendar.',
      );
    }
  }

  /// Update an existing calendar event
  static Future<ToolResult> updateCalendarEvent(Map<String, dynamic> params) async {
    debugPrint('🗓️ CalendarTools.updateCalendarEvent called with: $params');
    
    final eventId = params['eventId'] as String?;
    final calendarId = params['calendarId'] as String?;
    
    if (eventId == null || eventId.isEmpty) {
      return ToolResult.error(
        'Missing event ID',
        userMessage: 'I need to know which event to update.',
      );
    }
    
    if (calendarId == null || calendarId.isEmpty) {
      return ToolResult.error(
        'Missing calendar ID',
        userMessage: 'I need to know which calendar the event is on.',
      );
    }

    try {
      // Check permissions first
      if (!await CalendarService.hasPermission()) {
        final granted = await CalendarService.requestPermission();
        if (!granted) {
          return ToolResult.error(
            'Calendar permission denied',
            userMessage: 'I need calendar access to update events.',
          );
        }
      }

      // Build update parameters
      final title = params['title'] as String?;
      final startTimeStr = params['startTime'] as String?;
      final endTimeStr = params['endTime'] as String?;
      final location = params['location'] as String?;
      final description = params['description'] as String?;

      final updatedEvent = await CalendarService.updateEvent(
        calendarId: calendarId,
        eventId: eventId,
        newTitle: title,
        newStart: startTimeStr != null ? DateTime.parse(startTimeStr) : null,
        newEnd: endTimeStr != null ? DateTime.parse(endTimeStr) : null,
        newLocation: location,
        newDescription: description,
      );

      if (updatedEvent != null) {
        return ToolResult.success(
          {'event_id': eventId, 'updated': true},
          userMessage: '✅ Event updated successfully!',
        );
      } else {
        return ToolResult.error(
          'Failed to update event',
          userMessage: 'I couldn\'t update that event. It may have been deleted.',
        );
      }
    } catch (e) {
      return ToolResult.error(
        'Error updating calendar event: $e',
        userMessage: 'I had trouble updating the event.',
      );
    }
  }

  /// Delete a calendar event
  static Future<ToolResult> deleteCalendarEvent(Map<String, dynamic> params) async {
    debugPrint('🗓️ CalendarTools.deleteCalendarEvent called with: $params');
    
    final eventId = params['eventId'] as String?;
    final calendarId = params['calendarId'] as String?;
    
    if (eventId == null || eventId.isEmpty) {
      return ToolResult.error(
        'Missing event ID',
        userMessage: 'I need to know which event to delete.',
      );
    }
    
    if (calendarId == null || calendarId.isEmpty) {
      return ToolResult.error(
        'Missing calendar ID',
        userMessage: 'I need to know which calendar the event is on.',
      );
    }

    try {
      // Check permissions first
      if (!await CalendarService.hasPermission()) {
        final granted = await CalendarService.requestPermission();
        if (!granted) {
          return ToolResult.error(
            'Calendar permission denied',
            userMessage: 'I need calendar access to delete events.',
          );
        }
      }

      final success = await CalendarService.deleteEvent(calendarId, eventId);

      if (success) {
        return ToolResult.success(
          {'event_id': eventId, 'deleted': true},
          userMessage: '🗑️ Event deleted.',
        );
      } else {
        return ToolResult.error(
          'Failed to delete event',
          userMessage: 'I couldn\'t delete that event. It may already be gone.',
        );
      }
    } catch (e) {
      return ToolResult.error(
        'Error deleting calendar event: $e',
        userMessage: 'I had trouble deleting the event.',
      );
    }
  }

  /// Check for calendar conflicts in a time range
  static Future<ToolResult> getCalendarConflicts(Map<String, dynamic> params) async {
    debugPrint('🗓️ CalendarTools.getCalendarConflicts called with: $params');
    
    final startTimeStr = params['startTime'] as String;
    final endTimeStr = params['endTime'] as String?;
    
    final start = DateTime.parse(startTimeStr);
    final end = endTimeStr != null 
        ? DateTime.parse(endTimeStr) 
        : start.add(const Duration(hours: 1));

    try {
      // Check permissions first
      if (!await CalendarService.hasPermission()) {
        final granted = await CalendarService.requestPermission();
        if (!granted) {
          return ToolResult.error(
            'Calendar permission denied',
            userMessage: 'I need calendar access to check for conflicts.',
          );
        }
      }

      // Get events in the proposed time range
      final conflicts = await CalendarService.getEventsInRange(start, end);
      
      if (conflicts.isEmpty) {
        return ToolResult.success(
          {'has_conflicts': false, 'conflicts': []},
          userMessage: 'No conflicts - that time is free! ✅',
        );
      }

      // Format conflicts
      final conflictList = conflicts.map((e) => {
        'title': e.title,
        'start': e.start?.toIso8601String(),
        'end': e.end?.toIso8601String(),
      }).toList();

      final timeFormatter = DateFormat('h:mm a');
      final conflictNames = conflicts.map((e) => e.title).join(', ');
      
      return ToolResult.success(
        {'has_conflicts': true, 'conflicts': conflictList, 'count': conflicts.length},
        userMessage: '⚠️ Conflict detected: $conflictNames at ${timeFormatter.format(start)}',
      );
    } catch (e) {
      return ToolResult.error(
        'Error checking calendar conflicts: $e',
        userMessage: 'I had trouble checking for conflicts.',
      );
    }
  }
}
