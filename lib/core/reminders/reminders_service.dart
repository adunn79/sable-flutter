import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Model for a Reminder
class Reminder {
  final String id;
  final String title;
  final String? notes;
  final DateTime? dueDate;
  final bool isCompleted;
  final int priority;

  Reminder({
    required this.id,
    required this.title,
    this.notes,
    this.dueDate,
    this.isCompleted = false,
    this.priority = 0,
  });

  factory Reminder.fromMap(Map<dynamic, dynamic> map) {
    return Reminder(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Untitled',
      notes: map['notes'] as String?,
      dueDate: map['dueDate'] != null 
          ? DateTime.fromMillisecondsSinceEpoch((map['dueDate'] as double).toInt() * 1000)
          : null,
      isCompleted: map['isCompleted'] as bool? ?? false,
      priority: map['priority'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'notes': notes,
      'dueDate': dueDate?.millisecondsSinceEpoch / 1000,
      'priority': priority,
    };
  }
}

/// Service for handling device reminders integration
/// Uses platform channels to access iOS/macOS EventKit
class RemindersService {
  static const MethodChannel _channel = MethodChannel('com.sable.reminders');

  /// Request reminders permission from the user
  static Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      debugPrint('✅ Reminders permission granted: ${result ?? false}');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Reminders permission request failed: $e');
      return false;
    }
  }

  /// Check if reminders permission has been granted
  static Future<bool> hasPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Reminders permission check failed: $e');
      return false;
    }
  }

  /// Get all active (incomplete) reminders
  static Future<List<Reminder>> getReminders() async {
    try {
      if (!await hasPermission()) {
        debugPrint('⚠️ No reminders permission');
        return [];
      }

      final result = await _channel.invokeMethod<List>('getReminders');
      if (result == null) return [];

      final reminders = result
          .map((item) => Reminder.fromMap(item as Map<dynamic, dynamic>))
          .toList();

      debugPrint('📝 Retrieved ${reminders.length} active reminders');
      return reminders;
    } catch (e) {
      debugPrint('❌ Failed to get reminders: $e');
      return [];
    }
  }

  /// Create a new reminder
  static Future<Reminder?> createReminder({
    required String title,
    String? notes,
    DateTime? dueDate,
    int priority = 0,
  }) async {
    try {
      if (!await hasPermission()) {
        debugPrint('⚠️ Cannot create reminder: no permission');
        return null;
      }

      final args = {
        'title': title,
        'notes': notes,
        'dueDate': dueDate?.millisecondsSinceEpoch / 1000,
        'priority': priority,
      };

      final result = await _channel.invokeMethod<Map>('createReminder', args);
      if (result == null) return null;

      debugPrint('✅ Reminder created: $title');
      return Reminder.fromMap(result);
    } catch (e) {
      debugPrint('❌ Failed to create reminder: $e');
      return null;
    }
  }

  /// Mark a reminder as complete
  static Future<bool> completeReminder(String reminderId) async {
    try {
      if (!await hasPermission()) return false;

      final result = await _channel.invokeMethod<bool>('completeReminder', reminderId);
      
      if (result == true) {
        debugPrint('✅ Reminder completed: $reminderId');
      }
      
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Failed to complete reminder: $e');
      return false;
    }
  }

  /// Get formatted reminders summary for AI context
  static Future<String> getRemindersSummary() async {
    try {
      if (!await hasPermission()) {
        return '[REMINDERS]\nNo reminders access granted.\n[END REMINDERS]';
      }

      final reminders = await getReminders();

      final buffer = StringBuffer();
      buffer.writeln('[REMINDERS]');
      buffer.writeln('Active: ${reminders.length} reminder${reminders.length == 1 ? '' : 's'}');

      if (reminders.isNotEmpty) {
        // Group by due date status
        final overdue = <Reminder>[];
        final dueToday = <Reminder>[];
        final upcoming = <Reminder>[];
        final noDueDate = <Reminder>[];

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        for (final reminder in reminders) {
          if (reminder.dueDate == null) {
            noDueDate.add(reminder);
          } else {
            final dueDay = DateTime(
              reminder.dueDate!.year,
              reminder.dueDate!.month,
              reminder.dueDate!.day,
            );

            if (dueDay.isBefore(today)) {
              overdue.add(reminder);
            } else if (dueDay.isAtSameMomentAs(today)) {
              dueToday.add(reminder);
            } else {
              upcoming.add(reminder);
            }
          }
        }

        buffer.writeln();

        if (overdue.isNotEmpty) {
          buffer.writeln('Overdue:');
          for (final reminder in overdue.take(3)) {
            final days = today.difference(DateTime(
              reminder.dueDate!.year,
              reminder.dueDate!.month,
              reminder.dueDate!.day,
            )).inDays;
            buffer.writeln('- ${reminder.title} ($days day${days == 1 ? '' : 's'} overdue)');
          }
        }

        if (dueToday.isNotEmpty) {
          buffer.writeln('Due today:');
          for (final reminder in dueToday.take(3)) {
            buffer.writeln('- ${reminder.title}');
          }
        }

        if (upcoming.isNotEmpty && upcoming.length <= 5) {
          buffer.writeln('Upcoming:');
          for (final reminder in upcoming) {
            final daysUntil = DateTime(
              reminder.dueDate!.year,
              reminder.dueDate!.month,
              reminder.dueDate!.day,
            ).difference(today).inDays;
            buffer.writeln('- ${reminder.title} (in $daysUntil day${daysUntil == 1 ? '' : 's'})');
          }
        }

        if (noDueDate.isNotEmpty) {
          buffer.writeln('No due date: ${noDueDate.length}');
        }
      }

      buffer.writeln('[END REMINDERS]');
      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Failed to generate reminders summary: $e');
      return '[REMINDERS]\nError loading reminders data.\n[END REMINDERS]';
    }
  }
}
