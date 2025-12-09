import 'package:device_calendar/device_calendar.dart';
import 'package:sable/core/calendar/calendar_service.dart';

/// Service to detect travel-related events (Flights, Hotels, Trips)
class TravelService {
  static const List<String> _travelKeywords = [
    'flight',
    'airline',
    'fly to',
    'departing',
    'arriving',
    'airport',
    'hotel',
    'airbnb',
    'reservation',
    'train to',
    'trip to',
    'stay at',
    'check-in',
    'check-out',
  ];

  /// Get travel events for a specific date
  static Future<List<Event>> getTravelEvents(DateTime date) async {
    // Get all events for the day
    // We use the CalendarService directly to respect permissions and existing logic
    final events = await CalendarService.getEventsInRange(
      DateTime(date.year, date.month, date.day),
      DateTime(date.year, date.month, date.day, 23, 59, 59),
    );
    
    return events.where((event) => _isTravelEvent(event)).toList();
  }
  
  /// Check if an event is travel-related
  static bool _isTravelEvent(Event event) {
    if (event.title == null) return false;
    
    final text = '${event.title} ${event.description ?? ""} ${event.location ?? ""}'.toLowerCase();
    
    for (final keyword in _travelKeywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Get a travel summary string for specific events
  static String getTravelSummary(Event event) {
    final title = event.title?.toLowerCase() ?? '';
    if (title.contains('flight')) return 'Flight';
    if (title.contains('hotel') || title.contains('airbnb') || title.contains('stay')) return 'Lodging';
    if (title.contains('train')) return 'Train';
    return 'Trip';
  }
  
  /// Get appropriate icon for the event
  static String getTravelIcon(Event event) {
    final summary = getTravelSummary(event);
    switch (summary) {
      case 'Flight': return '✈️';
      case 'Lodging': return '🏨';
      case 'Train': return '🚆';
      default: return '🧳';
    }
  }
}
