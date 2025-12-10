import 'package:device_calendar/device_calendar.dart';
import 'package:intl/intl.dart';
import '../calendar/calendar_service.dart';
import '../ai/tool_registry.dart';

/// AI Tools for calendar event management
class CalendarTools {
  /// Create a calendar event
  /// Returns JSON with success/failure and event details
  static Future<ToolResult> createCalendarEvent(Map<String, dynamic> params) async {
    final title = params['title'] as String;
    final startTimeStr = params['startTime'] as String;
    final startTime = DateTime.parse(startTimeStr);
    final description = params['description'] as String?;
    final location = params['location'] as String?;
    final endTime = params['endTime'] != null 
      ? DateTime.parse(params['endTime'] as String)
      : null;
    final allDay = params['allDay'] as bool? ?? false;
    try {
      // Check permissions first
      if (!await CalendarService.hasPermission()) {
        final granted = await CalendarService.requestPermission();
        if (!granted) {
          return ToolResult.error(
          'Calendar permission denied',
          userMessage: 'I don\'t have permission to access your calendar. You can grant access in Settings > Aeliana > Calendar.',
          };
        }
      }

      // Set end time if not provided (1 hour after start)
      final eventEnd = endTime ?? startTime.add(const Duration(hours: 1));

      // Create the event
      final event = await CalendarService.createEvent(
        title: title,
        description: description,
        location: location,
        start: startTime,
        end: eventEnd,
        allDay: allDay,
      );

      if (event == null) {
        return ToolResult.error(
          'Failed to create calendar event',
          userMessage: 'I couldn\'t create the calendar event. Make sure you have a calendar set up on your device.',
        );
      }

      // Format success message
      final dateFormatter = DateFormat('EEEE, MMM d');
      final timeFormatter = DateFormat('h:mm a');
      final dateStr = dateFormatter.format(startTime);
      final timeStr = allDay ? 'All day' : timeFormatter.format(startTime);
      
      final locationPart = location != null ? ' at $location' : '';
      final message = '✅ Event "$title" created for $dateStr at $timeStr$locationPart';

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

  /// Update an existing calendar event
  static Future<Map<String, dynamic>> updateCalendarEvent({
    required String eventId,
    String? title,
    String? description,
    String? location,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      if (!await CalendarService.hasPermission()) {
        return {
          'success': false,
          'error': 'Calendar permission denied',
          'user_message': 'I don\'t have permission to access your calendar.',
        };
      }

      final event = await CalendarService.updateEvent(
        eventId: eventId,
        title: title,
        description: description,
        location: location,
        start: startTime,
        end: endTime,
      );

      if (event == null) {
        return {
          'success': false,
          'error': 'Failed to update calendar event',
          'user_message': 'I couldn\'t update that calendar event.',
        };
      }

      return {
        'success': true,
        'event_id': eventId,
        'message': 'Event updated successfully',
        'user_message': '✅ Calendar event updated',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error updating event: $e',
        'user_message': 'I encountered an error while updating the event.',
      };
    }
  }

  /// Delete a calendar event
  static Future<Map<String, dynamic>> deleteCalendarEvent({
    required String eventId,
  }) async {
    try {
      if (!await CalendarService.hasPermission()) {
        return {
          'success': false,
          'error': 'Calendar permission denied',
          'user_message': 'I don\'t have permission to access your calendar.',
        };
      }

      final success = await CalendarService.deleteEvent(eventId);

      if (!success) {
        return {
          'success': false,
          'error': 'Failed to delete calendar event',
          'user_message': 'I couldn\'t delete that calendar event.',
        };
      }

      return {
        'success': true,
        'event_id': eventId,
        'message': 'Event deleted successfully',
        'user_message': '✅ Calendar event deleted',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error deleting event: $e',
        'user_message': 'I encountered an error while deleting the event.',
      };
    }
  }

  /// Get events for a specific date range
  static Future<Map<String, dynamic>> getCalendarEvents({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      if (!await CalendarService.hasPermission()) {
        return {
          'success': false,
          'error': 'Calendar permission denied',
          'user_message': 'I don\'t have permission to access your calendar.',
        };
      }

      final events = await CalendarService.getEvents(startDate, endDate);

      if (events.isEmpty) {
        return {
          'success': true,
          'events': [],
          'count': 0,
          'message': 'No events found for this date range',
          'user_message': 'You have no events scheduled for that time period.',
        };
      }

      // Format events for AI consumption
      final formattedEvents = events.map((e) {
        return {
          'event_id': e.eventId,
          'title': e.title,
          'description': e.description,
          'location': e.location,
          'start': e.start?.toIso8601String(),
          'end': e.end?.toIso8601String(),
          'all_day': e.allDay ?? false,
        };
      }).toList();

      return {
        'success': true,
        'events': formattedEvents,
        'count': events.length,
        'message': 'Found ${events.length} event(s)',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error fetching events: $e',
        'user_message': 'I encountered an error while checking your calendar.',
      };
    }
  }
}
