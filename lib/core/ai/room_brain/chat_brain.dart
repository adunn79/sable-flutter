import 'package:flutter/foundation.dart';
import 'package:sable/core/ai/room_brain/room_brain_base.dart';
import 'package:sable/core/ai/agent_context.dart';
import 'package:sable/core/ai/memory_spine.dart';
import 'package:sable/core/ai/tool_registry.dart';

/// Chat Brain - Domain expertise for main chat tab
/// Handles: general conversation, calendar, tasks, web search, context synthesis
class ChatBrain extends RoomBrain {
  ChatBrain({
    required super.memorySpine,
    required super.tools,
  });

  @override
  String get domain => 'chat';

  @override
  List<String> get capabilities => [
    'general_conversation',
    'create_calendar_event',
    'update_calendar_event',
    'delete_calendar_event',
    'task_management',
    'web_search',
    'context_synthesis',
  ];

  @override
  bool canHandle(String query) {
    // Chat brain handles everything except domain-specific queries
    // This is the "default" brain
    return true;
  }

  @override
  Future<BrainResponse> processQuery(String query, AgentContext context) async {
    final lowerQuery = query.toLowerCase();

    // Intent detection - Calendar related?
    if (_isCalendarCreateIntent(lowerQuery)) {
      debugPrint('🗓️ Chat Brain: Calendar creation intent detected');
      
      // Parse calendar details from query
      final calendarParams = await _parseCalendarIntent(query);
      
      if (calendarParams != null) {
        return BrainResponse.withToolCall(
          toolName: 'create_calendar_event',
          params: calendarParams,
        );
      } else {
        return BrainResponse.simple(
          "I'd love to add that to your calendar! Could you give me a bit more detail? "
          "Like: 'Add dinner at Yang's tomorrow at 7pm' or 'Meeting with Sarah on Friday at 2pm'",
        );
      }
    }

    // Intent detection - Calendar update?
    if (_isCalendarUpdateIntent(lowerQuery)) {
      debugPrint('🗓️ Chat Brain: Calendar update intent detected');
      // TODO: Implement calendar update flow
      return BrainResponse.simple(
        "I can help you update calendar events! This feature is coming soon.",
      );
    }

    // Intent detection - Calendar delete?
    if (_isCalendarDeleteIntent(lowerQuery)) {
      debugPrint('🗓️ Chat Brain: Calendar delete intent detected');
      // TODO: Implement calendar delete flow
      return BrainResponse.simple(
        "I can help you remove calendar events! This feature is coming soon.",
      );
    }

    // Default: General conversation
    // For now, return simple acknowledgment
    // TODO: Route to ModelOrchestrator for AI response
    return BrainResponse.simple(
      "I'm learning your needs. This is where I'd have a contextual conversation! "
      "(Full AI integration coming next)",
    );
  }

  // ========== INTENT DETECTION ==========

  bool _isCalendarCreateIntent(String query) {
    final createKeywords = [
      'add',
      'create',
      'schedule',
      'book',
      'make a',
      'set up',
      'plan',
      'put on my calendar',
      'remind me',
    ];

    final calendarKeywords = [
      'dinner',
      'lunch',
      'meeting',
      'appointment',
      'event',
      'calendar',
      'tomorrow',
      'tonight',
      'at',
      'pm',
      'am',
      'reminder',
      'call',
      'visit',
    ];
    
    // Check if query has BOTH a creation verb AND an event indicator
    final hasCreateWord = createKeywords.any((kw) => query.contains(kw));
    final hasEventWord = eventIndicators.any((kw) => query.contains(kw));
    
    // OR if it mentions time/date (strong signal)
    final hasTimeReference = query.contains('tomorrow') ||
                            query.contains('today') ||
                            query.contains('pm') ||
                            query.contains('am') ||
                            query.contains('at ') ||
                            query.contains('on monday') ||
                            query.contains('on tuesday') ||
                            query.contains('next week');
    
    return (hasCreateWord && hasEventWord) || (hasCreateWord && hasTimeReference);
  }

  bool _isCalendarUpdateIntent(String query) {
    return query.contains('change') || 
           query.contains('update') || 
           query.contains('move') ||
           query.contains('reschedule');
  }

  bool _isCalendarDeleteIntent(String query) {
    return (query.contains('cancel') || query.contains('delete') || query.contains('remove')) &&
           (query.contains('event') || query.contains('meeting') || query.contains('appointment'));
  }

  // ========== CALENDAR PARSING ==========

  Future<Map<String, dynamic>?> _parseCalendarIntent(String query) async {
    // Simple regex-based parsing for now
    // TODO: Use NLP/LLM for better parsing
    
    try {
      // Extract title (everything before time indicator)
      String? title;
      DateTime? startTime;
      String? location;

      // Try to find title and location
      final titleMatch = RegExp(r'(?:add|create|schedule|book)\s+(.+?)(?:\s+(?:at|on|tomorrow|tonight|for))', 
        caseSensitive: false).firstMatch(query);
      
      if (titleMatch != null) {
        title = titleMatch.group(1)?.trim();
      }

      // Try to find time
      // Pattern: "tomorrow at 7pm" or "tonight at 8" or "Friday at 2pm"
      final timePatterns = [
        RegExp(r'tomorrow\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false),
        RegExp(r'tonight\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false),
        RegExp(r'at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false),
      ];

      for (final pattern in timePatterns) {
        final match = pattern.firstMatch(query.toLowerCase());
        if (match != null) {
          int hour = int.parse(match.group(1)!);
          int minute = int.tryParse(match.group(2) ?? '0') ?? 0;
          String? ampm = match.group(3);

          // Handle AM/PM
          if (ampm != null) {
            if (ampm == 'pm' && hour < 12) hour += 12;
            if (ampm == 'am' && hour == 12) hour = 0;
          } else {
            // Default: if hour < 8, assume PM (dinner time)
            if (hour < 8) hour += 12;
          }

          // Determine date
          DateTime baseDate;
          if (query.toLowerCase().contains('tomorrow')) {
            baseDate = DateTime.now().add(const Duration(days: 1));
          } else if (query.toLowerCase().contains('tonight')) {
            baseDate = DateTime.now();
          } else {
            // Default to today if time hasn't passed, otherwise tomorrow
            final now = DateTime.now();
            final candidateTime = DateTime(now.year, now.month, now.day, hour, minute);
            baseDate = candidateTime.isBefore(now) 
              ? now.add(const Duration(days: 1))
              : now;
          }

          startTime = DateTime(
            baseDate.year,
            baseDate.month,
            baseDate.day,
            hour,
            minute,
          );
          break;
        }
      }

      // Try to find location
      final locationMatch = RegExp(r'at\s+([A-Z][a-zA-Z\s]+?)(?:\s+(?:in|on|for|tomorrow|tonight))', 
        caseSensitive: true).firstMatch(query);
      if (locationMatch != null) {
        location = locationMatch.group(1)?.trim();
      }

      // Must have at least title and time
      if (title != null && startTime != null) {
        debugPrint('📅 Parsed calendar event: $title at $startTime ${location != null ? "in $location" : ""}');
        
        return {
          'title': title,
          'startTime': startTime.toIso8601String(),
          'location': location,
        };
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error parsing calendar intent: $e');
      return null;
    }
  }
}
