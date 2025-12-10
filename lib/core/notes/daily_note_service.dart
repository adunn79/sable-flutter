import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service for persisting a simple text note for each day
class DailyNoteService {
  static const _prefix = 'daily_note_';

  static String _getKey(DateTime date) {
    return '$_prefix${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  /// Get note for a specific date
  static Future<String?> getNote(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_getKey(date));
    } catch (e) {
      debugPrint('❌ Error fetching daily note: $e');
      return null;
    }
  }

  /// Save note for a specific date
  static Future<void> saveNote(DateTime date, String content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKey(date);
      
      if (content.trim().isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, content);
      }
    } catch (e) {
      debugPrint('❌ Error saving daily note: $e');
    }
  }
}
