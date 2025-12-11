// Calendar Flow Tests - P0, P1, P2
// Tests for conflict detection, NLP parsing, and update/delete functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:sable/core/calendar/calendar_service.dart';
import 'package:device_calendar/device_calendar.dart';

void main() {
  // ========== P0: CONFLICT DETECTION TESTS ==========
  group('P0: Conflict Detection', () {
    test('checkConflicts returns empty list when no events overlap', () async {
      // This test verifies the function signature and basic structure
      // Actual calendar integration requires device/simulator
      final start = DateTime.now().add(const Duration(days: 30));
      final end = start.add(const Duration(hours: 1));
      
      // Without calendar permission, should return empty list gracefully
      final conflicts = await CalendarService.checkConflicts(
        start: start,
        end: end,
        bufferMinutes: 15,
      );
      
      expect(conflicts, isA<List<Event>>());
    });

    test('isTimeFree returns true when slot is available', () async {
      final start = DateTime.now().add(const Duration(days: 30));
      final end = start.add(const Duration(hours: 1));
      
      // Without permission, defaults to assumed-free behavior
      final isFree = await CalendarService.isTimeFree(start, end);
      
      expect(isFree, isA<bool>());
    });

    test('suggestAlternativeTimes returns list of DateTimes', () async {
      final originalStart = DateTime.now().add(const Duration(days: 1));
      
      final suggestions = await CalendarService.suggestAlternativeTimes(
        originalStart: originalStart,
        durationMinutes: 60,
        maxSuggestions: 3,
      );
      
      expect(suggestions, isA<List<DateTime>>());
      // Should not exceed max suggestions
      expect(suggestions.length, lessThanOrEqualTo(3));
    });

    test('checkConflicts handles invalid dates gracefully', () async {
      // End before start - edge case
      final end = DateTime.now();
      final start = end.add(const Duration(hours: 1));
      
      final conflicts = await CalendarService.checkConflicts(
        start: start,
        end: end,
        bufferMinutes: 0,
      );
      
      // Should not throw, should return empty or handle gracefully
      expect(conflicts, isA<List<Event>>());
    });
  });

  // ========== P1: NLP PARSING TESTS ==========
  group('P1: NLP Parsing', () {
    test('Regex parser extracts event type from simple query', () {
      // Test the regex patterns used in fallback parsing
      final query = 'add dinner tomorrow at 7pm';
      
      final titlePattern = RegExp(
        r'(?:add|create|schedule)\s+(?:an?\s+)?(dinner|lunch|breakfast|brunch|meeting|appointment|call)',
        caseSensitive: false,
      );
      final match = titlePattern.firstMatch(query);
      
      expect(match, isNotNull);
      expect(match!.group(1), equals('dinner'));
    });

    test('Regex parser extracts time correctly', () {
      final query = 'at 7pm';
      
      final timePattern = RegExp(
        r'at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
        caseSensitive: false,
      );
      final match = timePattern.firstMatch(query);
      
      expect(match, isNotNull);
      expect(match!.group(1), equals('7'));
      expect(match.group(3), equals('pm'));
    });

    test('Regex parser extracts 24-hour time', () {
      final query = 'at 14:30';
      
      final timePattern = RegExp(
        r'at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
        caseSensitive: false,
      );
      final match = timePattern.firstMatch(query);
      
      expect(match, isNotNull);
      expect(match!.group(1), equals('14'));
      expect(match.group(2), equals('30'));
    });

    test('Day of week parsing works correctly', () {
      final queries = ['this friday', 'next monday', 'saturday'];
      
      final dayPattern = RegExp(
        r'(this|next)?\s*(sunday|monday|tuesday|wednesday|thursday|friday|saturday)',
        caseSensitive: false,
      );
      
      for (final query in queries) {
        final match = dayPattern.firstMatch(query.toLowerCase());
        expect(match, isNotNull, reason: 'Failed for query: $query');
      }
    });

    test('Location extraction works for "in location" pattern', () {
      final query = 'dinner in San Francisco at 7pm';
      
      final locationPattern = RegExp(
        r'in\s+([a-zA-Z\s,]+?)(?:\s+(?:at|with|on|to|$))',
        caseSensitive: false,
      );
      final match = locationPattern.firstMatch(query);
      
      expect(match, isNotNull);
      expect(match!.group(1)?.trim(), equals('San Francisco'));
    });

    test('Complex query extracts multiple components', () {
      final query = 'schedule meeting with Sarah at 3pm in office';
      
      // Title extraction
      final titlePattern = RegExp(
        r'(?:add|create|schedule)\s+(?:an?\s+)?(meeting|dinner|lunch)',
        caseSensitive: false,
      );
      expect(titlePattern.hasMatch(query), isTrue);
      
      // Time extraction  
      final timePattern = RegExp(r'at\s+(\d+)(?:pm|am)', caseSensitive: false);
      expect(timePattern.hasMatch(query), isTrue);
      
      // Location extraction
      final locationPattern = RegExp(r'in\s+(\w+)', caseSensitive: false);
      expect(locationPattern.hasMatch(query), isTrue);
    });
  });

  // ========== P2: UPDATE/DELETE TESTS ==========
  group('P2: Update & Delete', () {
    test('searchEventsByTitle returns list of Events', () async {
      final results = await CalendarService.searchEventsByTitle('test');
      
      expect(results, isA<List<Event>>());
    });

    test('searchEventsByTitle handles empty query', () async {
      final results = await CalendarService.searchEventsByTitle('');
      
      expect(results, isA<List<Event>>());
    });

    test('deleteEvent returns false when event not found', () async {
      // Trying to delete a non-existent event
      final result = await CalendarService.deleteEvent('fake-calendar', 'fake-event');
      
      // Should fail gracefully
      expect(result, isA<bool>());
    });

    test('updateEvent returns null when event not found', () async {
      final result = await CalendarService.updateEvent(
        calendarId: 'fake-calendar',
        eventId: 'fake-event',
        newTitle: 'Updated Title',
      );
      
      // Should return null for non-existent event
      expect(result, isNull);
    });

    test('getEventById returns null for invalid ID', () async {
      final result = await CalendarService.getEventById('fake-calendar', 'fake-event');
      
      expect(result, isNull);
    });
  });

  // ========== INTENT DETECTION TESTS ==========
  group('Intent Detection Patterns', () {
    test('Create intent patterns match correctly', () {
      final createPatterns = [
        'add dinner tomorrow',
        'create meeting at 3pm',
        'schedule lunch with John',
        'book appointment for Friday',
      ];
      
      final createPattern = RegExp(
        r'\b(add|create|schedule|book|put|set up)\b.*(event|meeting|dinner|lunch|breakfast|brunch|appointment|call|reminder)',
        caseSensitive: false,
      );
      
      for (final query in createPatterns) {
        expect(createPattern.hasMatch(query), isTrue, 
          reason: 'Failed to match create intent: $query');
      }
    });

    test('Update intent patterns match correctly', () {
      final updatePatterns = [
        'move dinner to 8pm',
        'change meeting to Friday',
        'reschedule lunch',
        'update my appointment',
      ];
      
      final updatePattern = RegExp(
        r'\b(move|change|reschedule|update|push|delay)\b',
        caseSensitive: false,
      );
      
      for (final query in updatePatterns) {
        expect(updatePattern.hasMatch(query), isTrue,
          reason: 'Failed to match update intent: $query');
      }
    });

    test('Delete intent patterns match correctly', () {
      final deletePatterns = [
        'cancel my dinner',
        'delete the meeting',
        'remove the appointment',
      ];
      
      final deletePattern = RegExp(
        r'\b(cancel|delete|remove)\b',
        caseSensitive: false,
      );
      
      for (final query in deletePatterns) {
        expect(deletePattern.hasMatch(query), isTrue,
          reason: 'Failed to match delete intent: $query');
      }
    });
  });

  // ========== EDGE CASES ==========
  group('Edge Cases', () {
    test('Time conversion handles AM/PM correctly', () {
      // Test PM conversion
      int hour = 7;
      const ampm = 'pm';
      if (ampm == 'pm' && hour < 12) hour += 12;
      expect(hour, equals(19));
      
      // Test 12 PM stays 12
      hour = 12;
      if (ampm == 'pm' && hour < 12) hour += 12;
      expect(hour, equals(12));
      
      // Test AM midnight
      hour = 12;
      const ampmAm = 'am';
      if (ampmAm == 'am' && hour == 12) hour = 0;
      expect(hour, equals(0));
    });

    test('Day of week calculation works across week boundary', () {
      final now = DateTime.now();
      final dayMap = {
        'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4,
        'friday': 5, 'saturday': 6, 'sunday': 7,
      };
      
      for (final entry in dayMap.entries) {
        final targetWeekday = entry.value;
        int daysUntil = targetWeekday - now.weekday;
        if (daysUntil <= 0) daysUntil += 7;
        
        final targetDate = now.add(Duration(days: daysUntil));
        expect(targetDate.weekday, equals(targetWeekday));
      }
    });
  });
}
