import 'package:intl/intl.dart';
import '../calendar/calendar_service.dart';
import 'tool_registry.dart';

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
          );
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

  // TODO: Implement update/delete/get calendar events
  // These require additions to CalendarService first
}
