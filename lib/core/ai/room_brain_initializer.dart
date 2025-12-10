import 'package:flutter/foundation.dart';
import 'package:sable/core/ai/tool_registry.dart';
import 'package:sable/core/ai/calendar_tools.dart';
import 'package:sable/core/ai/memory_spine.dart';

/// Initializes the Room Brain system
/// Call this once during app startup
class RoomBrainInitializer {
  static bool _initialized = false;

  /// Initialize Memory Spine and register all tools
  static Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('🧠 Initializing Room Brain System...');

    try {
      // 1. Initialize Memory Spine
      final memorySpine = MemorySpine();
      await memorySpine.initialize();
      debugPrint('✅ Memory Spine initialized');

      // 2. Create Tool Registry
      final toolRegistry = ToolRegistry();

      // 3. Register Calendar Tools
      toolRegistry.register(
        createTool(
          name: 'create_calendar_event',
          description: 'Creates a new calendar event with title, time, and optional location',
          schema: {
            'title': {'type': 'string', 'required': true},
            'startTime': {'type': 'string', 'format': 'iso8601', 'required': true},
            'endTime': {'type': 'string', 'format': 'iso8601', 'required': false},
            'location': {'type': 'string', 'required': false},
            'description': {'type': 'string', 'required': false},
            'allDay': {'type': 'boolean', 'required': false},
          },
          allowedBrains: ['chat'], // Only Chat Brain can create calendar events
          function: CalendarTools.createCalendarEvent,
        ),
      );

      debugPrint('✅ Calendar tools registered');

      // TODO: Register more tools as we build them
      // - Journal tools
      // - Health tools
      // - Settings tools

      _initialized = true;
      debugPrint('🎉 Room Brain System ready!');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize Room Brain System: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Get the global Tool Registry instance
  static ToolRegistry getToolRegistry() {
    if (!_initialized) {
      throw Exception('Room Brain System not initialized. Call initialize() first.');
    }
    return ToolRegistry();
  }

  /// Get the global Memory Spine instance
  static MemorySpine getMemorySpine() {
    if (!_initialized) {
      throw Exception('Room Brain System not initialized. Call initialize() first.');
    }
    return MemorySpine();
  }
}
