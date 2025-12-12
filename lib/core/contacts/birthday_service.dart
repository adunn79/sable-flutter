import 'package:flutter/foundation.dart';
import 'package:sable/core/contacts/contacts_service.dart' as sable_contacts;

/// Represents a contact's birthday
class ContactBirthday {
  final String name;
  final DateTime birthday;
  final String? phone;
  final int age; // Age they're turning (or current age)

  ContactBirthday({
    required this.name,
    required this.birthday,
    this.phone,
    required this.age,
  });

  /// Days until this birthday from today
  int get daysUntil {
    final now = DateTime.now();
    final thisYearBirthday = DateTime(now.year, birthday.month, birthday.day);
    
    if (thisYearBirthday.isBefore(now)) {
      // Birthday has passed this year, calculate for next year
      final nextYearBirthday = DateTime(now.year + 1, birthday.month, birthday.day);
      return nextYearBirthday.difference(now).inDays;
    }
    return thisYearBirthday.difference(now).inDays;
  }

  bool get isToday => daysUntil == 0;
  bool get isTomorrow => daysUntil == 1;
}

/// Service for extracting and managing birthdays from contacts
class BirthdayService {
  /// Get all contacts with birthdays
  static Future<List<ContactBirthday>> getAllBirthdays() async {
    try {
      if (!await sable_contacts.ContactsService.hasPermission()) {
        debugPrint('⚠️ No contacts permission for birthdays');
        return [];
      }

      final contacts = await sable_contacts.ContactsService.getAllContacts();
      final birthdays = <ContactBirthday>[];

      for (final contact in contacts) {
        if (contact.birthday != null) {
          final now = DateTime.now();
          final bday = contact.birthday!;
          
          // Calculate age
          int age = now.year - bday.year;
          if (now.month < bday.month || 
              (now.month == bday.month && now.day < bday.day)) {
            age--; // Haven't had birthday yet this year
          }

          birthdays.add(ContactBirthday(
            name: contact.displayName ?? 'Unknown',
            birthday: bday,
            phone: sable_contacts.ContactsService.getPhoneNumber(contact),
            age: age + 1, // Age they're turning
          ));
        }
      }

      // Sort by days until birthday
      birthdays.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
      
      debugPrint('🎂 Found ${birthdays.length} contacts with birthdays');
      return birthdays;
    } catch (e) {
      debugPrint('❌ Failed to get birthdays: $e');
      return [];
    }
  }

  /// Get birthdays happening today
  static Future<List<ContactBirthday>> getTodayBirthdays() async {
    final all = await getAllBirthdays();
    return all.where((b) => b.isToday).toList();
  }

  /// Get upcoming birthdays within specified days
  static Future<List<ContactBirthday>> getUpcomingBirthdays({int days = 30}) async {
    final all = await getAllBirthdays();
    return all.where((b) => b.daysUntil <= days).toList();
  }

  /// Get birthdays for a specific date
  static Future<List<ContactBirthday>> getBirthdaysForDate(DateTime date) async {
    final all = await getAllBirthdays();
    return all.where((b) {
      return b.birthday.month == date.month && b.birthday.day == date.day;
    }).toList();
  }

  /// Format birthday summary for AI context
  static Future<String> getBirthdaySummary() async {
    try {
      final today = await getTodayBirthdays();
      final upcoming = await getUpcomingBirthdays(days: 7);
      
      final buffer = StringBuffer();
      buffer.writeln('[BIRTHDAYS]');
      
      if (today.isNotEmpty) {
        buffer.writeln('🎂 TODAY:');
        for (final b in today) {
          buffer.writeln('- ${b.name} is turning ${b.age}!');
        }
      }
      
      final tomorrow = upcoming.where((b) => b.isTomorrow).toList();
      if (tomorrow.isNotEmpty) {
        buffer.writeln('Tomorrow:');
        for (final b in tomorrow) {
          buffer.writeln('- ${b.name} (turning ${b.age})');
        }
      }
      
      final thisWeek = upcoming.where((b) => !b.isToday && !b.isTomorrow).toList();
      if (thisWeek.isNotEmpty) {
        buffer.writeln('This week: ${thisWeek.length} birthday${thisWeek.length == 1 ? '' : 's'}');
      }
      
      buffer.writeln('[END BIRTHDAYS]');
      return buffer.toString();
    } catch (e) {
      return '[BIRTHDAYS]\nError loading birthday data.\n[END BIRTHDAYS]';
    }
  }
}
