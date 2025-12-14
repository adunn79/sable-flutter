import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// A single safety event for audit logging
class SafetyEvent {
  final DateTime timestamp;
  final String categoryBlocked;
  final bool wasRewritten;
  final String? sessionHash;

  SafetyEvent({
    required this.timestamp,
    required this.categoryBlocked,
    required this.wasRewritten,
    this.sessionHash,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'categoryBlocked': categoryBlocked,
    'wasRewritten': wasRewritten,
    'sessionHash': sessionHash,
  };

  factory SafetyEvent.fromJson(Map<String, dynamic> json) {
    return SafetyEvent(
      timestamp: DateTime.parse(json['timestamp'] as String),
      categoryBlocked: json['categoryBlocked'] as String,
      wasRewritten: json['wasRewritten'] as bool,
      sessionHash: json['sessionHash'] as String?,
    );
  }
}

/// Safety Audit Log
/// 
/// Logs blocked content for compliance without storing PII.
/// 
/// GDPR Compliance:
/// - Hash session IDs (no reversible user identification)
/// - No message content stored (only category)
/// - Auto-delete after 30 days
/// - User can request full deletion
class SafetyAuditLog {
  static const String _boxName = 'safety_audit_log';
  static const int _retentionDays = 30;
  static const int _maxEvents = 10000;

  // Singleton
  static final SafetyAuditLog _instance = SafetyAuditLog._();
  static SafetyAuditLog get instance => _instance;
  
  Box<String>? _box;
  bool _initialized = false;

  SafetyAuditLog._();

  /// Initialize the audit log (call during app startup)
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _box = await Hive.openBox<String>(_boxName);
      _initialized = true;
      
      // Run cleanup in background
      _cleanupOldEvents();
      
      debugPrint('🛡️ Safety Audit Log initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize Safety Audit Log: $e');
    }
  }

  /// Log a blocked content event
  Future<void> logBlocked(SafetyEvent event) async {
    if (!_initialized || _box == null) {
      await initialize();
    }

    try {
      final key = 'event_${event.timestamp.millisecondsSinceEpoch}';
      await _box?.put(key, jsonEncode(event.toJson()));
      
      debugPrint('🛡️ Logged safety event: ${event.categoryBlocked}');
      
      // Enforce max events limit
      if ((_box?.length ?? 0) > _maxEvents) {
        _trimOldestEvents();
      }
    } catch (e) {
      debugPrint('❌ Failed to log safety event: $e');
    }
  }

  /// Get recent safety events
  Future<List<SafetyEvent>> getRecentEvents(int count) async {
    if (!_initialized || _box == null) {
      await initialize();
    }

    try {
      final events = <SafetyEvent>[];
      final keys = _box?.keys.toList() ?? [];
      
      // Sort by timestamp (newest first)
      keys.sort((a, b) => b.toString().compareTo(a.toString()));
      
      for (final key in keys.take(count)) {
        final json = _box?.get(key);
        if (json != null) {
          events.add(SafetyEvent.fromJson(jsonDecode(json)));
        }
      }
      
      return events;
    } catch (e) {
      debugPrint('❌ Failed to get recent events: $e');
      return [];
    }
  }

  /// Get category statistics
  Future<Map<String, int>> getCategoryStats() async {
    if (!_initialized || _box == null) {
      await initialize();
    }

    try {
      final stats = <String, int>{};
      
      for (final key in _box?.keys ?? []) {
        final json = _box?.get(key);
        if (json != null) {
          final event = SafetyEvent.fromJson(jsonDecode(json));
          stats[event.categoryBlocked] = (stats[event.categoryBlocked] ?? 0) + 1;
        }
      }
      
      return stats;
    } catch (e) {
      debugPrint('❌ Failed to get category stats: $e');
      return {};
    }
  }

  /// Get events count by day (for analytics)
  Future<Map<String, int>> getDailyStats({int days = 7}) async {
    if (!_initialized || _box == null) {
      await initialize();
    }

    try {
      final stats = <String, int>{};
      final cutoff = DateTime.now().subtract(Duration(days: days));
      
      for (final key in _box?.keys ?? []) {
        final json = _box?.get(key);
        if (json != null) {
          final event = SafetyEvent.fromJson(jsonDecode(json));
          if (event.timestamp.isAfter(cutoff)) {
            final dayKey = '${event.timestamp.year}-${event.timestamp.month.toString().padLeft(2, '0')}-${event.timestamp.day.toString().padLeft(2, '0')}';
            stats[dayKey] = (stats[dayKey] ?? 0) + 1;
          }
        }
      }
      
      return stats;
    } catch (e) {
      debugPrint('❌ Failed to get daily stats: $e');
      return {};
    }
  }

  /// Export all data for GDPR request
  Future<List<Map<String, dynamic>>> exportAllData() async {
    if (!_initialized || _box == null) {
      await initialize();
    }

    try {
      final data = <Map<String, dynamic>>[];
      
      for (final key in _box?.keys ?? []) {
        final json = _box?.get(key);
        if (json != null) {
          data.add(jsonDecode(json));
        }
      }
      
      return data;
    } catch (e) {
      debugPrint('❌ Failed to export data: $e');
      return [];
    }
  }

  /// Delete all audit data (GDPR right to erasure)
  Future<void> deleteAllData() async {
    if (!_initialized || _box == null) {
      await initialize();
    }

    try {
      await _box?.clear();
      debugPrint('🗑️ All safety audit data deleted');
    } catch (e) {
      debugPrint('❌ Failed to delete data: $e');
    }
  }

  /// Delete data for a specific session (GDPR request)
  Future<int> deleteSessionData(String sessionHash) async {
    if (!_initialized || _box == null) {
      await initialize();
    }

    try {
      var deleted = 0;
      final keysToDelete = <dynamic>[];
      
      for (final key in _box?.keys ?? []) {
        final json = _box?.get(key);
        if (json != null) {
          final event = SafetyEvent.fromJson(jsonDecode(json));
          if (event.sessionHash == sessionHash) {
            keysToDelete.add(key);
          }
        }
      }
      
      for (final key in keysToDelete) {
        await _box?.delete(key);
        deleted++;
      }
      
      debugPrint('🗑️ Deleted $deleted events for session $sessionHash');
      return deleted;
    } catch (e) {
      debugPrint('❌ Failed to delete session data: $e');
      return 0;
    }
  }

  /// Get total event count
  int get eventCount => _box?.length ?? 0;

  /// Clean up events older than retention period
  void _cleanupOldEvents() async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: _retentionDays));
      final keysToDelete = <dynamic>[];
      
      for (final key in _box?.keys ?? []) {
        final json = _box?.get(key);
        if (json != null) {
          final event = SafetyEvent.fromJson(jsonDecode(json));
          if (event.timestamp.isBefore(cutoff)) {
            keysToDelete.add(key);
          }
        }
      }
      
      for (final key in keysToDelete) {
        await _box?.delete(key);
      }
      
      if (keysToDelete.isNotEmpty) {
        debugPrint('🧹 Cleaned up ${keysToDelete.length} old safety events');
      }
    } catch (e) {
      debugPrint('❌ Failed to cleanup old events: $e');
    }
  }

  /// Trim oldest events when over limit
  void _trimOldestEvents() async {
    try {
      final keys = _box?.keys.toList() ?? [];
      keys.sort();
      
      final toDelete = keys.take((keys.length - _maxEvents).clamp(0, 1000));
      
      for (final key in toDelete) {
        await _box?.delete(key);
      }
      
      debugPrint('🧹 Trimmed ${toDelete.length} oldest safety events');
    } catch (e) {
      debugPrint('❌ Failed to trim events: $e');
    }
  }
}
