import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents a note from Apple Notes
class Note {
  final String id;
  final String title;
  final String? body;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String? folderName;

  Note({
    required this.id,
    required this.title,
    this.body,
    required this.createdAt,
    required this.modifiedAt,
    this.folderName,
  });

  factory Note.fromMap(Map<dynamic, dynamic> map) => Note(
    id: map['id'] as String,
    title: map['title'] as String,
    body: map['body'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    modifiedAt: DateTime.fromMillisecondsSinceEpoch(map['modifiedAt'] as int),
    folderName: map['folderName'] as String?,
  );

  /// Get a preview of the note body
  String get preview {
    if (body == null || body!.isEmpty) return '';
    final text = body!.replaceAll(RegExp(r'<[^>]*>'), ''); // Strip HTML
    if (text.length <= 100) return text;
    return '${text.substring(0, 100)}...';
  }
}

/// Service for accessing Apple Notes via native Swift channel
/// 
/// NOTE: This requires corresponding Swift code in the iOS Runner to handle
/// the method channel calls. The Swift code needs to use EventKit or 
/// AppleScript to access Notes (Notes.app doesn't have a direct API).
class NotesService {
  static const MethodChannel _channel = MethodChannel('com.sable.notes');
  static bool _permissionDenied = false;

  /// Request permission to access notes
  /// Note: Apple Notes doesn't have explicit permissions like Reminders,
  /// but we may need to prompt for macOS AppleEvent permissions
  static Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      _permissionDenied = !(result ?? false);
      debugPrint('📝 Notes permission granted: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('❌ Notes permission request failed: ${e.message}');
      _permissionDenied = true;
      return false;
    } on MissingPluginException {
      debugPrint('⚠️ Notes channel not implemented on this platform');
      return false;
    }
  }

  /// Check if we have notes access
  static Future<bool> hasPermission() async {
    if (_permissionDenied) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>('hasPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('❌ Notes permission check failed: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Get recent notes
  static Future<List<Note>> getRecentNotes({int limit = 10}) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getRecentNotes',
        {'limit': limit},
      );
      
      if (result != null) {
        return result.map((e) => Note.fromMap(e as Map<dynamic, dynamic>)).toList();
      }
      return [];
    } on PlatformException catch (e) {
      debugPrint('❌ Failed to get notes: ${e.message}');
      return [];
    } on MissingPluginException {
      debugPrint('⚠️ Notes channel not implemented');
      return [];
    }
  }

  /// Search notes by query
  static Future<List<Note>> searchNotes(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'searchNotes',
        {'query': query},
      );
      
      if (result != null) {
        return result.map((e) => Note.fromMap(e as Map<dynamic, dynamic>)).toList();
      }
      return [];
    } on PlatformException catch (e) {
      debugPrint('❌ Failed to search notes: ${e.message}');
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  /// Create a new note
  static Future<Note?> createNote({
    required String title,
    String? body,
    String? folderName,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'createNote',
        {
          'title': title,
          'body': body ?? '',
          'folderName': folderName,
        },
      );
      
      if (result != null) {
        debugPrint('✅ Created note: $title');
        return Note.fromMap(result);
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint('❌ Failed to create note: ${e.message}');
      return null;
    } on MissingPluginException {
      debugPrint('⚠️ Notes channel not implemented');
      return null;
    }
  }

  /// Get today's notes (created or modified today)
  static Future<List<Note>> getTodayNotes() async {
    final notes = await getRecentNotes(limit: 50);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return notes.where((note) {
      final modDate = DateTime(
        note.modifiedAt.year, 
        note.modifiedAt.month, 
        note.modifiedAt.day,
      );
      return modDate.isAtSameMomentAs(today) || modDate.isAfter(today);
    }).toList();
  }

  /// Get notes summary for AI context
  static Future<String> getNotesSummary() async {
    try {
      final hasAccess = await hasPermission();
      if (!hasAccess) {
        return '[NOTES]\nNotes access not available.\n[END NOTES]';
      }

      final recent = await getRecentNotes(limit: 5);
      final today = await getTodayNotes();
      
      final buffer = StringBuffer();
      buffer.writeln('[NOTES]');
      
      if (today.isNotEmpty) {
        buffer.writeln("Today's notes:");
        for (final note in today.take(3)) {
          buffer.writeln('- ${note.title}');
          if (note.preview.isNotEmpty) {
            buffer.writeln('  "${note.preview}"');
          }
        }
      }
      
      if (recent.isNotEmpty && today.isEmpty) {
        buffer.writeln('Recent notes:');
        for (final note in recent.take(3)) {
          buffer.writeln('- ${note.title}');
        }
      }
      
      buffer.writeln('[END NOTES]');
      return buffer.toString();
    } catch (e) {
      return '[NOTES]\nError accessing notes.\n[END NOTES]';
    }
  }

  /// Check if Notes channel is implemented
  static Future<bool> isAvailable() async {
    try {
      await _channel.invokeMethod<bool>('isAvailable');
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return true; // Platform exception means it IS implemented, just errored
    }
  }
}
