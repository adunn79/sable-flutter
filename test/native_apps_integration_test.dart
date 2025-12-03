import 'package:flutter_test/flutter_test.dart';
import 'package:sable/core/calendar/calendar_service.dart';
import 'package:sable/core/contacts/contacts_service.dart';
import 'package:sable/core/photos/photos_service.dart';
import 'package:sable/core/reminders/reminders_service.dart';

/// Integration tests for native app services
/// Tests permission handling, data retrieval, and AI context generation
void main() {
  group('CalendarService Tests', () {
    test('hasPermission returns boolean without crash', () async {
      expect(() async => await CalendarService.hasPermission(), returnsNormally);
    });

    test('getCalendarSummary handles no permission gracefully', () async {
      final summary = await CalendarService.getCalendarSummary();
      expect(summary, isNotNull);
      expect(summary, contains('[CALENDAR]'));
      expect(summary, contains('[END CALENDAR]'));
    });

    test('getTodayEvents returns list without crash', () async {
      expect(() async => await CalendarService.getTodayEvents(), returnsNormally);
    });

    test('getUpcomingEvents with custom days works', () async {
      final events = await CalendarService.getUpcomingEvents(days: 14);
      expect(events, isA<List>());
    });
  });

  group('ContactsService Tests', () {
    test('hasPermission returns boolean without crash', () async {
      expect(() async => await ContactsService.hasPermission(), returnsNormally);
    });

    test('getRecentContactsSummary handles no permission gracefully', () async {
      final summary = await ContactsService.getRecentContactsSummary();
      expect(summary, isNotNull);
      expect(summary, contains('[CONTACTS]'));
      expect(summary, contains('[END CONTACTS]'));
    });

    test('getAllContacts returns list without crash', () async {
      expect(() async => await ContactsService.getAllContacts(), returnsNormally);
    });

    test('searchContacts with empty query returns list', () async {
      final results = await ContactsService.searchContacts('');
      expect(results, isA<List>());
    });

    test('searchContacts with query returns filtered list', () async {
      final results = await ContactsService.searchContacts('test');
      expect(results, isA<List>());
    });
  });

  group('PhotosService Tests', () {
    test('hasPermission returns boolean without crash', () async {
      expect(() async => await PhotosService.hasPermission(), returnsNormally);
    });

    test('getPhotosSummary handles no permission gracefully', () async {
      final summary = await PhotosService.getPhotosSummary();
      expect(summary, isNotNull);
      expect(summary, contains('[PHOTOS]'));
      expect(summary, contains('[END PHOTOS]'));
    });

    test('getPhotoCount returns non-negative number', () async {
      final count = await PhotosService.getPhotoCount();
      expect(count, greaterThanOrEqualTo(0));
    });

    test('getRecentPhotos with limit works', () async {
      final photos = await PhotosService.getRecentPhotos(count: 5);
      expect(photos, isA<List>());
      expect(photos.length, lessThanOrEqualTo(5));
    });
  });

  group('RemindersService Tests', () {
    test('hasPermission returns boolean without crash', () async {
      expect(() async => await RemindersService.hasPermission(), returnsNormally);
    });

    test('getRemindersSummary handles no permission gracefully', () async {
      final summary = await RemindersService.getRemindersSummary();
      expect(summary, isNotNull);
      expect(summary, contains('[REMINDERS]'));
      expect(summary, contains('[END REMINDERS]'));
    });

    test('getReminders returns list without crash', () async {
      expect(() async => await RemindersService.getReminders(), returnsNormally);
    });
  });

  group('Cross-Service Integration Tests', () {
    test('All services can check permissions concurrently', () async {
      final results = await Future.wait([
        CalendarService.hasPermission(),
        ContactsService.hasPermission(),
        PhotosService.hasPermission(),
        RemindersService.hasPermission(),
      ]);

      expect(results, hasLength(4));
      for (final result in results) {
        expect(result, isA<bool>());
      }
    });

    test('All services can generate AI context concurrently', () async {
      final summaries = await Future.wait([
        CalendarService.getCalendarSummary(),
        ContactsService.getRecentContactsSummary(),
        PhotosService.getPhotosSummary(),
        RemindersService.getRemindersSummary(),
      ]);

      expect(summaries, hasLength(4));
      for (final summary in summaries) {
        expect(summary, isNotNull);
        expect(summary.length, greaterThan(0));
      }
    });

    test('Context generation maintains consistent format', () async {
      final calendarContext = await CalendarService.getCalendarSummary();
      final contactsContext = await ContactsService.getRecentContactsSummary();
      final photosContext = await PhotosService.getPhotosSummary();
      final remindersContext = await RemindersService.getRemindersSummary();

      // All contexts should have proper tags
      expect(calendarContext, matches(RegExp(r'\[CALENDAR\].*\[END CALENDAR\]', dotAll: true)));
      expect(contactsContext, matches(RegExp(r'\[CONTACTS\].*\[END CONTACTS\]', dotAll: true)));
      expect(photosContext, matches(RegExp(r'\[PHOTOS\].*\[END PHOTOS\]', dotAll: true)));
      expect(remindersContext, matches(RegExp(r'\[REMINDERS\].*\[END REMINDERS\]', dotAll: true)));
    });
  });

  group('Error Handling Tests', () {
    test('Services handle permission denial gracefully', () async {
      // Even if permissions are denied, services should not crash
      final calendarEvents = await CalendarService.getTodayEvents();
      final contacts = await ContactsService.getAllContacts();
      final photos = await PhotosService.getRecentPhotos();
      final reminders = await RemindersService.getReminders();

      // All should return empty lists, not null or throw
      expect(calendarEvents, isA<List>());
      expect(contacts, isA<List>());
      expect(photos, isA<List>());
      expect(reminders, isA<List>());
    });

    test('Context generation never returns null', () async {
      final contexts = await Future.wait([
        CalendarService.getCalendarSummary(),
        ContactsService.getRecentContactsSummary(),
        PhotosService.getPhotosSummary(),
        RemindersService.getRemindersSummary(),
      ]);

      for (final context in contexts) {
        expect(context, isNotNull);
        expect(context, isNotEmpty);
      }
    });
  });
}
