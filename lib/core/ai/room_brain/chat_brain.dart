import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sable/core/ai/room_brain/room_brain_base.dart';
import 'package:sable/core/ai/agent_context.dart';
import 'package:sable/core/ai/memory_spine.dart';
import 'package:sable/core/ai/tool_registry.dart';
import 'package:sable/core/ai/providers/gemini_provider.dart';
import 'package:sable/core/calendar/calendar_service.dart';
import 'package:intl/intl.dart';

/// Calendar event creation stages for multi-turn conversation
enum CalendarEventStage {
  askingTime,       // Need time if not provided
  askingLocation,   // Asking for location (prioritized for meals)
  askingCity,       // Asking for city when venue provided without address
  askingDuration,   // Asking for duration
  askingInvites,    // Asking about invitees
  askingNotes,      // Asking for notes/description
  askingAlert,      // Asking about reminder
  conflictDetected, // Conflict found, asking user how to proceed
  ready,            // All info gathered, ready to create
}

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
    return true;
  }

  // ========== SKIP/CANCEL DETECTION ==========
  
  bool _isSkipResponse(String query) {
    final skipPhrases = [
      'skip', 'no', 'nope', 'none', 'nothing', 'nah',
      "that's it", "thats it", "that's all", "thats all",
      "i'm good", "im good", "all good", "we're good",
      'done', 'next', 'move on', 'no thanks',
    ];
    final lower = query.toLowerCase().trim();
    return skipPhrases.any((phrase) => lower == phrase || lower.startsWith('$phrase '));
  }

  bool _isCancelResponse(String query) {
    final cancelPhrases = [
      'cancel', 'never mind', 'nevermind', 'forget it',
      'stop', 'abort', 'quit', 'exit', "don't", 'dont',
      'actually no', 'changed my mind',
    ];
    final lower = query.toLowerCase().trim();
    return cancelPhrases.any((phrase) => lower.contains(phrase));
  }

  // ========== MAIN QUERY PROCESSOR ==========

  @override
  Future<BrainResponse> processQuery(String query, AgentContext context) async {
    final lowerQuery = query.toLowerCase().trim();
    
    debugPrint('🧠 ChatBrain.processQuery: "$query"');

    // ===== CHECK FOR PENDING CALENDAR EVENT =====
    final pendingEvent = memorySpine.read('PENDING_CALENDAR_EVENT');
    if (pendingEvent.isNotEmpty) {
      debugPrint('📅 Active calendar flow - stage: ${pendingEvent['stage']}');
      return await _handleCalendarFlowResponse(query, pendingEvent);
    }

    // ===== INTENT DETECTION =====
    // Check delete/update FIRST since "delete my dinner" contains "dinner" which would match create
    if (_isCalendarDeleteIntent(lowerQuery)) {
      debugPrint('🗑️ Calendar delete intent detected');
      return await _initiateCalendarDelete(query);
    }

    if (_isCalendarUpdateIntent(lowerQuery)) {
      debugPrint('📝 Calendar update intent detected');
      return await _initiateCalendarUpdate(query);
    }

    if (_isCalendarCreateIntent(lowerQuery)) {
      debugPrint('🗓️ Calendar creation intent detected');
      return await _initiateCalendarFlow(query);
    }

    // Default: Pass to orchestrator for general AI conversation
    return BrainResponse.delegateToOrchestrator();
  }

  // ========== CALENDAR FLOW INITIATION ==========

  Future<BrainResponse> _initiateCalendarFlow(String query) async {
    // Parse all available information from the query
    final parsed = await _parseCalendarIntent(query);
    
    if (parsed == null) {
      return BrainResponse.simple(
        "I'd love to add that to your calendar! Could you give me more detail? "
        "Like: 'Dinner at Yang's tomorrow at 7pm' or 'Meeting with Sarah on Friday at 2pm'",
      );
    }

    debugPrint('📅 Parsed event: $parsed');

    // Check what's missing and determine next stage
    final title = parsed['title'] as String?;
    final startTime = parsed['startTime'] as String?;
    final location = parsed['location'] as String?;
    
    // Must have title and time to proceed
    if (title == null || title.isEmpty) {
      return BrainResponse.simple("What would you like to call this event?");
    }
    
    if (startTime == null) {
      // Store what we have and ask for time
      parsed['stage'] = CalendarEventStage.askingTime.name;
      await memorySpine.write('PENDING_CALENDAR_EVENT', parsed);
      return BrainResponse.simple("What time should I schedule '$title'?");
    }

    // Determine if this is a meal event (prioritize location)
    final isMealEvent = RegExp(r'\b(dinner|lunch|breakfast|brunch)\b', caseSensitive: false).hasMatch(title);
    
    if (isMealEvent && location == null) {
      // Ask for location first for meal events
      parsed['stage'] = CalendarEventStage.askingLocation.name;
      await memorySpine.write('PENDING_CALENDAR_EVENT', parsed);
      return BrainResponse.simple("Where will $title be?");
    }
    
    // If location is a venue/restaurant name without city, ask for city
    if (isMealEvent && location != null && !_hasAddressOrCity(location)) {
      parsed['stage'] = CalendarEventStage.askingCity.name;
      await memorySpine.write('PENDING_CALENDAR_EVENT', parsed);
      return BrainResponse.simple("What city is $location in?");
    }

    // For non-meal events or if location is provided, ask about invites
    if (parsed['invitees'] == null) {
      parsed['stage'] = CalendarEventStage.askingInvites.name;
      await memorySpine.write('PENDING_CALENDAR_EVENT', parsed);
      return BrainResponse.simple("Want to invite anyone?");
    }

    // All required info present - create the event
    return await _createCalendarEvent(parsed);
  }

  // ========== CALENDAR UPDATE FLOW ==========

  Future<BrainResponse> _initiateCalendarUpdate(String query) async {
    debugPrint('📝 Initiating calendar update: $query');
    
    try {
      // Use LLM to parse the update request
      final gemini = GeminiProvider();
      final now = DateTime.now();
      
      final prompt = '''Parse this calendar update request and return JSON.

User request: "$query"
Current date: ${now.toIso8601String()}

Extract:
- The event being updated (search term to find it)
- What changes are being made (new time, new date, new location, new title)

Return ONLY valid JSON:
{
  "searchTerm": "string to find the event (e.g. 'dinner', 'meeting with John')",
  "newTime": "HH:MM in 24h format (if changing time)",
  "newDate": "YYYY-MM-DD (if changing date)",
  "newLocation": "new location (if changing)",
  "newTitle": "new title (if changing)"
}

Examples:
- "move dinner to 8pm" → {"searchTerm": "dinner", "newTime": "20:00"}
- "change meeting to Friday" → {"searchTerm": "meeting", "newDate": "next Friday as YYYY-MM-DD"}
- "reschedule lunch with Sarah to noon" → {"searchTerm": "lunch with Sarah", "newTime": "12:00"}

Return ONLY JSON.''';

      final response = await gemini.generateResponse(
        prompt: prompt,
        modelId: 'gemini-2.0-flash',
      );
      
      // Parse JSON
      String jsonStr = response.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'^```\w*\n?'), '').replaceFirst(RegExp(r'\n?```$'), '');
      }
      
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final searchTerm = parsed['searchTerm'] as String?;
      
      if (searchTerm == null || searchTerm.isEmpty) {
        return BrainResponse.simple("Which event would you like to update?");
      }
      
      // Search for matching events
      final matches = await CalendarService.searchEventsByTitle(searchTerm);
      
      if (matches.isEmpty) {
        return BrainResponse.simple(
          "I couldn't find any events matching \"$searchTerm\". "
          "Could you be more specific about which event you want to update?"
        );
      }
      
      if (matches.length > 1) {
        // Multiple matches - ask for clarification
        final eventList = matches.take(3).map((e) {
          final time = e.start != null ? DateFormat('E M/d h:mm a').format(e.start!) : 'No time';
          return '• ${e.title} ($time)';
        }).join('\n');
        
        return BrainResponse.simple(
          "I found multiple events. Which one?\n$eventList"
        );
      }
      
      // Single match - apply the update
      final event = matches.first;
      DateTime? newStart = event.start;
      DateTime? newEnd = event.end;
      
      // Apply new time
      if (parsed['newTime'] != null) {
        final timeParts = (parsed['newTime'] as String).split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        
        final currentDate = event.start ?? now;
        newStart = DateTime(currentDate.year, currentDate.month, currentDate.day, hour, minute);
        
        // Preserve duration
        if (event.start != null && event.end != null) {
          final duration = event.end!.difference(event.start!);
          newEnd = newStart.add(duration);
        } else {
          newEnd = newStart.add(const Duration(hours: 1));
        }
      }
      
      // Apply new date
      if (parsed['newDate'] != null) {
        final dateParts = (parsed['newDate'] as String).split('-');
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);
        
        final currentTime = newStart ?? event.start ?? now;
        newStart = DateTime(year, month, day, currentTime.hour, currentTime.minute);
        
        if (newEnd != null) {
          final duration = newEnd.difference(event.start ?? now);
          newEnd = newStart.add(duration);
        }
      }
      
      // Perform the update
      final updated = await CalendarService.updateEvent(
        calendarId: event.calendarId!,
        eventId: event.eventId!,
        newStart: newStart,
        newEnd: newEnd,
        newTitle: parsed['newTitle'] as String?,
        newLocation: parsed['newLocation'] as String?,
      );
      
      if (updated != null) {
        final newTimeStr = newStart != null 
          ? DateFormat('E M/d h:mm a').format(newStart)
          : 'unchanged';
        return BrainResponse.simple(
          "✅ Updated ${event.title} to $newTimeStr"
        );
      } else {
        return BrainResponse.simple(
          "I couldn't update that event. Please try again."
        );
      }
    } catch (e) {
      debugPrint('❌ Calendar update failed: $e');
      return BrainResponse.simple(
        "I had trouble understanding that update request. "
        "Try something like \"move dinner to 8pm\" or \"change meeting to Friday\"."
      );
    }
  }

  // ========== CALENDAR DELETE FLOW ==========

  Future<BrainResponse> _initiateCalendarDelete(String query) async {
    debugPrint('🗑️ Initiating calendar delete: $query');
    
    try {
      // Use LLM to parse the delete request
      final gemini = GeminiProvider();
      
      final prompt = '''Parse this calendar delete/cancel request and return JSON.

User request: "$query"

Extract the event to delete (search term).

Return ONLY valid JSON:
{
  "searchTerm": "string to find the event (e.g. 'dinner', 'meeting', '7pm appointment')"
}

Examples:
- "cancel my dinner" → {"searchTerm": "dinner"}
- "delete the meeting tomorrow" → {"searchTerm": "meeting"}
- "remove my 7pm appointment" → {"searchTerm": "7pm appointment"}

Return ONLY JSON.''';

      final response = await gemini.generateResponse(
        prompt: prompt,
        modelId: 'gemini-2.0-flash',
      );
      
      // Parse JSON
      String jsonStr = response.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'^```\w*\n?'), '').replaceFirst(RegExp(r'\n?```$'), '');
      }
      
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final searchTerm = parsed['searchTerm'] as String?;
      
      if (searchTerm == null || searchTerm.isEmpty) {
        return BrainResponse.simple("Which event would you like to cancel?");
      }
      
      // Search for matching events
      final matches = await CalendarService.searchEventsByTitle(searchTerm);
      
      if (matches.isEmpty) {
        return BrainResponse.simple(
          "I couldn't find any events matching \"$searchTerm\". "
          "Could you be more specific?"
        );
      }
      
      if (matches.length > 1) {
        // Multiple matches - ask for clarification
        final eventList = matches.take(3).map((e) {
          final time = e.start != null ? DateFormat('E M/d h:mm a').format(e.start!) : 'No time';
          return '• ${e.title} ($time)';
        }).join('\n');
        
        return BrainResponse.simple(
          "I found multiple events. Which one should I cancel?\n$eventList"
        );
      }
      
      // Single match - delete it
      final event = matches.first;
      final success = await CalendarService.deleteEvent(
        event.calendarId!,
        event.eventId!,
      );
      
      if (success) {
        return BrainResponse.simple("✅ Cancelled ${event.title}");
      } else {
        return BrainResponse.simple(
          "I couldn't cancel that event. Please try again."
        );
      }
    } catch (e) {
      debugPrint('❌ Calendar delete failed: $e');
      return BrainResponse.simple(
        "I had trouble understanding that. "
        "Try something like \"cancel my dinner\" or \"delete the meeting tomorrow\"."
      );
    }
  }

  Future<BrainResponse> _handleCalendarFlowResponse(String query, Map<String, dynamic> pendingEvent) async {
    // Check for cancel
    if (_isCancelResponse(query)) {
      await memorySpine.write('PENDING_CALENDAR_EVENT', {});
      return BrainResponse.simple("No problem, cancelled! Let me know if you need anything else.");
    }

    final stage = pendingEvent['stage'] as String?;
    debugPrint('📅 Handling response for stage: $stage');

    switch (stage) {
      case 'askingTime':
        return await _handleTimeResponse(query, pendingEvent);
      case 'askingLocation':
        return await _handleLocationResponse(query, pendingEvent);
      case 'askingCity':
        return await _handleCityResponse(query, pendingEvent);
      case 'askingDuration':
        return await _handleDurationResponse(query, pendingEvent);
      case 'askingInvites':
        return await _handleInvitesResponse(query, pendingEvent);
      case 'askingNotes':
        return await _handleNotesResponse(query, pendingEvent);
      case 'askingAlert':
        return await _handleAlertResponse(query, pendingEvent);
      case 'conflictDetected':
        return await _handleConflictResponse(query, pendingEvent);
      default:
        // Unknown stage - try to create with what we have
        await memorySpine.write('PENDING_CALENDAR_EVENT', {});
        return await _createCalendarEvent(pendingEvent);
    }
  }

  Future<BrainResponse> _handleTimeResponse(String query, Map<String, dynamic> event) async {
    // Try to parse time from response
    final timeMatch = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false).firstMatch(query);
    
    if (timeMatch != null) {
      int hour = int.parse(timeMatch.group(1)!);
      int minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      String? ampm = timeMatch.group(3);
      
      // Determine if this is a meal event (which typically happens in PM)
      final title = event['title'] as String? ?? '';
      final isMealEvent = RegExp(r'\b(dinner|lunch|breakfast|brunch)\b', caseSensitive: false).hasMatch(title);
      final isDinner = title.toLowerCase().contains('dinner');
      
      if (ampm != null) {
        // Explicit AM/PM provided
        if (ampm.toLowerCase() == 'pm' && hour < 12) hour += 12;
        if (ampm.toLowerCase() == 'am' && hour == 12) hour = 0;
      } else {
        // No AM/PM specified - infer based on context
        if (isDinner) {
          // Dinner is always evening/night: assume PM for hours 5-11
          if (hour >= 5 && hour <= 11) {
            hour += 12;
          }
        } else if (isMealEvent && title.toLowerCase().contains('lunch')) {
          // Lunch is typically 11 AM - 2 PM
          if (hour >= 11 && hour <= 12) {
            // Keep as-is (could be 11am or 12pm)
          } else if (hour >= 1 && hour <= 2) {
            hour += 12; // 1pm, 2pm
          }
        } else {
          // For general events, assume PM for common business/evening hours
          if (hour >= 1 && hour <= 11) {
            hour += 12; // Default to PM for any hour 1-11 without AM/PM
          }
        }
      }
      
      final now = DateTime.now();
      final eventDate = DateTime(now.year, now.month, now.day + 1, hour, minute);
      event['startTime'] = eventDate.toIso8601String();
      
      // Move to next stage
      return await _advanceToNextStage(event, CalendarEventStage.askingTime);
    }
    
    return BrainResponse.simple("I didn't catch the time. Could you say something like '7pm' or '2:30pm'?");
  }

  Future<BrainResponse> _handleLocationResponse(String query, Map<String, dynamic> event) async {
    if (!_isSkipResponse(query)) {
      event['location'] = query.trim();
    }
    return await _advanceToNextStage(event, CalendarEventStage.askingLocation);
  }

  Future<BrainResponse> _handleCityResponse(String query, Map<String, dynamic> event) async {
    if (!_isSkipResponse(query)) {
      // Append city to existing location
      final currentLocation = event['location'] as String?;
      final city = query.trim();
      if (currentLocation != null && currentLocation.isNotEmpty) {
        event['location'] = '$currentLocation, $city';
      } else {
        event['location'] = city;
      }
    }
    return await _advanceToNextStage(event, CalendarEventStage.askingCity);
  }

  /// Check if location string appears to have an address or city
  bool _hasAddressOrCity(String location) {
    final lower = location.toLowerCase();
    
    // Check for common city indicators
    final cityIndicators = [
      ',',  // "Restaurant, San Francisco"
      'street', 'st.', 'st ', 'ave', 'avenue', 'blvd', 'boulevard', 'road', 'rd',
      'ca', 'wa', 'ny', 'tx', 'fl', 'il', // State abbreviations
      'california', 'washington', 'seattle', 'portland', 'san francisco', 
      'new york', 'los angeles', 'chicago', 'boston', 'denver', 'austin',
      'downtown', 'uptown', 'midtown',
    ];
    
    for (final indicator in cityIndicators) {
      if (lower.contains(indicator)) {
        return true;
      }
    }
    
    // Check for ZIP code pattern
    if (RegExp(r'\d{5}').hasMatch(location)) {
      return true;
    }
    
    return false;
  }

  Future<BrainResponse> _handleDurationResponse(String query, Map<String, dynamic> event) async {
    if (!_isSkipResponse(query)) {
      // Parse duration - handle various formats
      int minutes = 0;
      final lowerQuery = query.toLowerCase();
      
      // Handle "X and a half hours" or "X 1/2 hours" or "X.5 hours"
      final fractionalHourMatch = RegExp(r'(\d+)\s*(?:and\s*a?\s*)?(?:1/2|\.5|half)\s*(?:hour|hr)', caseSensitive: false).firstMatch(query);
      if (fractionalHourMatch != null) {
        minutes = int.parse(fractionalHourMatch.group(1)!) * 60 + 30;
      }
      
      // Handle "1 1/2 hours" format (space between number and fraction)
      if (minutes == 0) {
        final spaceFractionMatch = RegExp(r'(\d+)\s+1/2\s*(?:hour|hr)', caseSensitive: false).firstMatch(query);
        if (spaceFractionMatch != null) {
          minutes = int.parse(spaceFractionMatch.group(1)!) * 60 + 30;
        }
      }
      
      // Handle "half hour" or "half an hour"
      if (minutes == 0 && lowerQuery.contains('half') && (lowerQuery.contains('hour') || lowerQuery.contains('hr'))) {
        minutes = 30;
      }
      
      // Handle regular hours (must come after fractional to not override)
      if (minutes == 0) {
        final hourMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hour|hr)', caseSensitive: false).firstMatch(query);
        if (hourMatch != null) {
          final hours = double.parse(hourMatch.group(1)!);
          minutes = (hours * 60).round();
        }
      }
      
      // Handle minutes
      final minMatch = RegExp(r'(\d+)\s*(?:min|minute)', caseSensitive: false).firstMatch(query);
      if (minMatch != null) {
        // If we already have hours, add minutes; otherwise just use minutes
        if (minutes > 0) {
          minutes += int.parse(minMatch.group(1)!);
        } else {
          minutes = int.parse(minMatch.group(1)!);
        }
      }
      
      // Try just a number (assume hours)
      if (minutes == 0) {
        final numMatch = RegExp(r'^(\d+(?:\.\d+)?)$').firstMatch(query.trim());
        if (numMatch != null) {
          final value = double.parse(numMatch.group(1)!);
          minutes = (value * 60).round();
        }
      }
      
      if (minutes > 0) event['durationMinutes'] = minutes;
    }
    return await _advanceToNextStage(event, CalendarEventStage.askingDuration);
  }

  Future<BrainResponse> _handleInvitesResponse(String query, Map<String, dynamic> event) async {
    if (!_isSkipResponse(query)) {
      // Strip leading affirmative words like "yes", "yeah", "sure", etc.
      var cleanedQuery = query
          .replaceFirst(RegExp(r'^(yes|yeah|yep|yup|sure|ok|okay)\s*,?\s*', caseSensitive: false), '')
          .trim();
      
      // Extract names - simple comma/and split
      final names = cleanedQuery
          .replaceAll(RegExp(r'\band\b', caseSensitive: false), ',')
          .split(',')
          .map((n) => n.trim())
          .where((n) => n.isNotEmpty)
          .toList();
      if (names.isNotEmpty) event['invitees'] = names;
    }
    return await _advanceToNextStage(event, CalendarEventStage.askingInvites);
  }

  Future<BrainResponse> _handleNotesResponse(String query, Map<String, dynamic> event) async {
    if (!_isSkipResponse(query)) {
      event['notes'] = query.trim();
    }
    return await _advanceToNextStage(event, CalendarEventStage.askingNotes);
  }

  Future<BrainResponse> _handleAlertResponse(String query, Map<String, dynamic> event) async {
    if (!_isSkipResponse(query)) {
      // Parse reminder time
      final minMatch = RegExp(r'(\d+)\s*(?:min|minute)', caseSensitive: false).firstMatch(query);
      final hourMatch = RegExp(r'(\d+)\s*(?:hour|hr)', caseSensitive: false).firstMatch(query);
      
      int alertMinutes = 0;
      if (minMatch != null) alertMinutes = int.parse(minMatch.group(1)!);
      if (hourMatch != null) alertMinutes += int.parse(hourMatch.group(1)!) * 60;
      
      // Common phrases
      if (query.toLowerCase().contains('day before')) alertMinutes = 24 * 60;
      if (query.toLowerCase().contains('hour before')) alertMinutes = 60;
      
      // If user just says "yes" or similar affirmative, default to 15 minutes
      if (alertMinutes == 0 && RegExp(r'^(yes|yeah|yep|yup|sure|ok|okay|please)$', caseSensitive: false).hasMatch(query.trim())) {
        alertMinutes = 15; // Default 15 minutes before
      }
      
      if (alertMinutes > 0) event['alertMinutes'] = alertMinutes;
    }
    return await _advanceToNextStage(event, CalendarEventStage.askingAlert);
  }

  // ========== STAGE ADVANCEMENT ==========

  Future<BrainResponse> _advanceToNextStage(Map<String, dynamic> event, CalendarEventStage currentStage) async {
    final title = event['title'] as String? ?? 'Event';
    final isMealEvent = RegExp(r'\b(dinner|lunch|breakfast|brunch)\b', caseSensitive: false).hasMatch(title);
    
    // Define the flow order based on event type
    // Meal events: location → city → duration → invites → alert
    // Other events: duration → invites → alert  
    final stages = isMealEvent
        ? [CalendarEventStage.askingTime, CalendarEventStage.askingLocation, CalendarEventStage.askingCity, CalendarEventStage.askingDuration, CalendarEventStage.askingInvites, CalendarEventStage.askingAlert]
        : [CalendarEventStage.askingTime, CalendarEventStage.askingDuration, CalendarEventStage.askingInvites, CalendarEventStage.askingAlert];
    
    var currentIndex = stages.indexOf(currentStage);
    
    // Find next stage that still needs information
    while (currentIndex >= 0 && currentIndex < stages.length - 1) {
      currentIndex++;
      final nextStage = stages[currentIndex];
      
      // Skip stages where we already have info
      if (_shouldSkipStage(nextStage, event)) {
        continue;
      }
      
      // This stage needs input
      event['stage'] = nextStage.name;
      await memorySpine.write('PENDING_CALENDAR_EVENT', event);
      return _getQuestionForStage(nextStage, event);
    }
    
    // No more optional stages - check for conflicts before creating
    return await _checkAndHandleConflicts(event);
  }

  /// Check if we should skip a stage because info is already present
  bool _shouldSkipStage(CalendarEventStage stage, Map<String, dynamic> event) {
    switch (stage) {
      case CalendarEventStage.askingLocation:
        return event['location'] != null && (event['location'] as String).isNotEmpty;
      case CalendarEventStage.askingCity:
        // Skip city if location already has city or address
        final location = event['location'] as String?;
        return location == null || location.isEmpty || _hasAddressOrCity(location);
      case CalendarEventStage.askingDuration:
        return event['durationMinutes'] != null;
      case CalendarEventStage.askingInvites:
        return event['invitees'] != null;
      case CalendarEventStage.askingAlert:
        return event['alertMinutes'] != null;
      default:
        return false;
    }
  }

  BrainResponse _getQuestionForStage(CalendarEventStage stage, Map<String, dynamic> event) {
    final title = event['title'] as String? ?? 'this';
    final isMealEvent = RegExp(r'\b(dinner|lunch|breakfast|brunch)\b', caseSensitive: false).hasMatch(title);
    
    switch (stage) {
      case CalendarEventStage.askingTime:
        return BrainResponse.simple("What time should I schedule $title?");
      case CalendarEventStage.askingLocation:
        // More natural question based on event type
        if (isMealEvent) {
          return BrainResponse.simple("What restaurant?");
        }
        return BrainResponse.simple("Where will this be?");
      case CalendarEventStage.askingCity:
        final location = event['location'] as String? ?? 'it';
        return BrainResponse.simple("What city is $location in?");
      case CalendarEventStage.askingDuration:
        return BrainResponse.simple("How long will it be?");
      case CalendarEventStage.askingInvites:
        if (isMealEvent) {
          return BrainResponse.simple("Who's joining you?");
        }
        return BrainResponse.simple("Want to invite anyone?");
      case CalendarEventStage.askingNotes:
        return BrainResponse.simple("Any notes to add?");
      case CalendarEventStage.askingAlert:
        return BrainResponse.simple("Want a reminder before?");
      case CalendarEventStage.conflictDetected:
        return BrainResponse.simple("Conflict detected. Create anyway, suggest different time, or cancel?");
      case CalendarEventStage.ready:
        return BrainResponse.simple("Ready to create!");
    }
  }

  // ========== CONFLICT DETECTION & RESOLUTION ==========

  /// Check for conflicts before creating event
  Future<BrainResponse> _checkAndHandleConflicts(Map<String, dynamic> event) async {
    debugPrint('🔍 Checking for calendar conflicts...');
    
    try {
      final startTime = DateTime.parse(event['startTime'] as String);
      final durationMinutes = event['durationMinutes'] as int? ?? 60;
      final endTime = startTime.add(Duration(minutes: durationMinutes));
      
      final conflicts = await CalendarService.checkConflicts(
        start: startTime,
        end: endTime,
        bufferMinutes: 5, // Smaller buffer for conflict detection
      );
      
      if (conflicts.isNotEmpty) {
        debugPrint('⚠️ Found ${conflicts.length} conflict(s)');
        
        // Format conflict summary
        final conflictSummary = conflicts.map((e) {
          final time = e.start != null 
            ? DateFormat('h:mm a').format(e.start!)
            : 'unknown time';
          return '${e.title ?? "Untitled"} at $time';
        }).join(', ');
        
        // Store conflict info and ask user
        event['conflicts'] = conflicts.map((e) => e.title ?? 'Untitled').toList();
        event['stage'] = CalendarEventStage.conflictDetected.name;
        await memorySpine.write('PENDING_CALENDAR_EVENT', event);
        
        return BrainResponse.simple(
          "Heads up - you have $conflictSummary around that time. "
          "Want me to create it anyway, suggest a different time, or skip?"
        );
      }
      
      debugPrint('✅ No conflicts found');
    } catch (e) {
      debugPrint('⚠️ Conflict check failed: $e - proceeding with creation');
    }
    
    // No conflicts - proceed with creation
    await memorySpine.write('PENDING_CALENDAR_EVENT', {});
    return await _createCalendarEvent(event);
  }

  /// Handle user response to conflict detection
  Future<BrainResponse> _handleConflictResponse(String query, Map<String, dynamic> event) async {
    final lower = query.toLowerCase().trim();
    
    // Check for explicit "create anyway" intent - need clear "anyway" or "create" keywords
    if (lower.contains('anyway') || lower.contains('create it') || 
        lower.contains('go ahead') || lower.contains('do it') ||
        lower.contains('just create') || lower.contains('make it')) {
      debugPrint('📅 User chose to create despite conflict');
      await memorySpine.write('PENDING_CALENDAR_EVENT', {});
      return await _createCalendarEvent(event);
    }
    
    // Check for "cancel/skip" intent
    if (lower.contains('skip') || lower.contains('cancel') || lower.contains('nevermind') || 
        lower.contains('never mind') || lower.contains('forget it') || lower == 'no') {
      await memorySpine.write('PENDING_CALENDAR_EVENT', {});
      return BrainResponse.simple("No problem, cancelled!");
    }
    
    // For "suggest alternative" intent or ambiguous "yes" - default to suggesting times
    // This is the most helpful action when there's a conflict
    if (lower.contains('different') || lower.contains('suggest') || 
        lower.contains('another') || lower.contains('alternative') ||
        lower.contains('yes') || lower.contains('sure') || lower.contains('ok')) {
      debugPrint('📅 User wants alternative time suggestions');
      
      try {
        final startTime = DateTime.parse(event['startTime'] as String);
        final durationMinutes = event['durationMinutes'] as int? ?? 60;
        
        final suggestions = await CalendarService.suggestAlternativeTimes(
          originalStart: startTime,
          durationMinutes: durationMinutes,
        );
        
        if (suggestions.isNotEmpty) {
          final suggestionText = suggestions.take(3).map((time) {
            return DateFormat('h:mm a').format(time);
          }).join(', ');
          
          event['stage'] = CalendarEventStage.askingTime.name;
          await memorySpine.write('PENDING_CALENDAR_EVENT', event);
          
          return BrainResponse.simple(
            "Here are some free times: $suggestionText. Which works better?"
          );
        } else {
          return BrainResponse.simple(
            "Hmm, looks like your calendar is pretty packed that day. "
            "Want me to create it anyway or try a different day?"
          );
        }
      } catch (e) {
        debugPrint('⚠️ Failed to suggest alternatives: $e');
        return BrainResponse.simple(
          "I couldn't find alternatives. Want me to create the event anyway?"
        );
      }
    }
    
    // Unclear response - ask again with clearer options
    return BrainResponse.simple(
      "Should I suggest a different time, or create it anyway despite the overlap?"
    );
  }

  // ========== EVENT CREATION ==========

  Future<BrainResponse> _createCalendarEvent(Map<String, dynamic> event) async {
    debugPrint('🎯 Creating calendar event: $event');
    
    // Build enhanced title - include restaurant for meal events
    String title = event['title'] as String? ?? 'Event';
    final location = event['location'] as String?;
    final isMealEvent = RegExp(r'\b(dinner|lunch|breakfast|brunch)\b', caseSensitive: false).hasMatch(title);
    
    // For meals, add venue to title if we have location
    if (isMealEvent && location != null && location.isNotEmpty) {
      // Extract just the venue name (before comma if there is one)
      final venueParts = location.split(',');
      final venueName = venueParts.first.trim();
      
      // Only add if title doesn't already contain the venue
      if (!title.toLowerCase().contains(venueName.toLowerCase())) {
        // Capitalize the title word
        title = '${title[0].toUpperCase()}${title.substring(1)} at $venueName';
      }
    }
    
    // Add invitees to title if present
    final invitees = event['invitees'] as List?;
    if (invitees != null && invitees.isNotEmpty && invitees.length <= 2) {
      // Only add for small groups to keep title concise
      if (!title.toLowerCase().contains('with')) {
        if (invitees.length == 1) {
          title = '$title with ${invitees.first}';
        } else {
          title = '$title with ${invitees.first} & ${invitees.last}';
        }
      }
    }
    
    // Build tool params
    final params = <String, dynamic>{
      'title': title,
      'startTime': event['startTime'],
    };
    
    if (location != null) params['location'] = location;
    
    // Generate AI description from event context
    final description = await _generateEventDescription(event);
    if (description.isNotEmpty) {
      params['description'] = description;
    }
    
    // Calculate end time if duration provided
    if (event['durationMinutes'] != null) {
      final start = DateTime.parse(event['startTime'] as String);
      final end = start.add(Duration(minutes: event['durationMinutes'] as int));
      params['endTime'] = end.toIso8601String();
    }
    
    return BrainResponse.withToolCall(
      toolName: 'create_calendar_event',
      params: params,
    );
  }

  /// Generate a contextual description using AI
  Future<String> _generateEventDescription(Map<String, dynamic> event) async {
    try {
      final title = event['title'] as String? ?? 'Event';
      final location = event['location'] as String?;
      final invitees = event['invitees'] as List?;
      final alertMinutes = event['alertMinutes'] as int?;
      final durationMinutes = event['durationMinutes'] as int?;
      final notes = event['notes'] as String?;
      
      // Build context for the AI
      final contextBuffer = StringBuffer();
      contextBuffer.writeln('Event: $title');
      if (location != null) contextBuffer.writeln('Location: $location');
      if (invitees != null && invitees.isNotEmpty) {
        contextBuffer.writeln('Attending: ${invitees.join(", ")}');
      }
      if (durationMinutes != null) {
        final hours = durationMinutes ~/ 60;
        final mins = durationMinutes % 60;
        if (hours > 0 && mins > 0) {
          contextBuffer.writeln('Duration: $hours hour${hours > 1 ? "s" : ""} $mins min');
        } else if (hours > 0) {
          contextBuffer.writeln('Duration: $hours hour${hours > 1 ? "s" : ""}');
        } else {
          contextBuffer.writeln('Duration: $mins minutes');
        }
      }
      if (alertMinutes != null && alertMinutes > 0) {
        contextBuffer.writeln('Reminder: $alertMinutes minutes before');
      }
      if (notes != null) contextBuffer.writeln('Notes: $notes');
      
      // Detect event type for richer description
      final isMealEvent = RegExp(r'\b(dinner|lunch|breakfast|brunch)\b', caseSensitive: false).hasMatch(title);
      final isMeetingEvent = RegExp(r'\b(meeting|call|interview|appointment)\b', caseSensitive: false).hasMatch(title);
      
      String additionalContext = '';
      if (isMealEvent && location != null) {
        additionalContext = 'This is a meal at $location. Add something inviting about the occasion.';
      } else if (isMeetingEvent) {
        additionalContext = 'This is a professional meeting. Keep it brief and action-oriented.';
      }
      
      final prompt = '''Generate a helpful calendar event description based on this info:

${contextBuffer.toString()}

$additionalContext

Guidelines:
- Write 2-3 short, conversational sentences
- If there are invitees, mention looking forward to seeing them
- If there's a location, add context about it
- If it's a meal, make it sound inviting (e.g., "Looking forward to a nice dinner at...")
- If there's a reminder set, don't mention it in the description
- Don't just repeat the title - add value
- If minimal info, add friendly context like "Enjoy!" or tips relevant to the event type

Write the description directly, no quotes or labels:''';

      final gemini = GeminiProvider();
      final response = await gemini.generateResponse(
        prompt: prompt,
        modelId: 'gemini-2.0-flash',
      );
      
      final description = response.trim();
      
      // Ensure we always have a description
      if (description.isEmpty || description.length < 10) {
        return _generateFallbackDescription(event);
      }
      
      return description;
    } catch (e) {
      debugPrint('⚠️ Failed to generate AI description: $e');
      return _generateFallbackDescription(event);
    }
  }

  /// Fallback description when AI fails
  String _generateFallbackDescription(Map<String, dynamic> event) {
    final title = event['title'] as String? ?? 'Event';
    final location = event['location'] as String?;
    final invitees = event['invitees'] as List?;
    
    final parts = <String>[];
    
    // Add invitees
    if (invitees != null && invitees.isNotEmpty) {
      if (invitees.length == 1) {
        parts.add('With ${invitees.first}.');
      } else {
        parts.add('With ${invitees.sublist(0, invitees.length - 1).join(", ")} and ${invitees.last}.');
      }
    }
    
    // Add contextual message based on event type
    final isMealEvent = RegExp(r'\b(dinner|lunch|breakfast|brunch)\b', caseSensitive: false).hasMatch(title);
    
    if (isMealEvent && location != null) {
      parts.add('Looking forward to a great meal at $location!');
    } else if (isMealEvent) {
      parts.add('Enjoy your meal!');
    } else if (location != null) {
      parts.add('Taking place at $location.');
    }
    
    // Always add something if empty
    if (parts.isEmpty) {
      if (isMealEvent) {
        parts.add('Bon appétit! 🍽️');
      } else {
        parts.add('Created with Sable. ✨');
      }
    }
    
    return parts.join(' ');
  }

  // ========== INTENT DETECTION ==========

  bool _isCalendarCreateIntent(String query) {
    // STRICT calendar creation phrases - must be explicit
    final explicitCalendarPhrases = [
      'schedule a',
      'schedule an',
      'schedule my',
      'add to calendar',
      'add to my calendar',
      'put on my calendar',
      'put on calendar',
      'create an event',
      'create event',
      'create a meeting',
      'book a',
      'book an',
      'set up a meeting',
      'remind me to',
      'set a reminder',
    ];
    
    // Check for explicit phrases first (high confidence)
    final hasExplicitPhrase = explicitCalendarPhrases.any((phrase) => query.contains(phrase));
    if (hasExplicitPhrase) {
      debugPrint('🔍 Calendar intent: explicit phrase match');
      return true;
    }
    
    // Meal/event words that strongly indicate calendar intent when paired with time
    final mealEventWords = ['dinner', 'lunch', 'breakfast', 'brunch', 'meeting', 'appointment'];
    final hasMealEvent = mealEventWords.any((kw) => query.contains(kw));
    
    // Strong time indicators (not just "at" which is too common)
    final hasStrongTimeRef = query.contains(' tomorrow') ||
                             query.contains(' tonight') ||
                             query.contains(' on monday') ||
                             query.contains(' on tuesday') ||
                             query.contains(' on wednesday') ||
                             query.contains(' on thursday') ||
                             query.contains(' on friday') ||
                             query.contains(' on saturday') ||
                             query.contains(' on sunday') ||
                             query.contains(' next week') ||
                             query.contains(' this weekend') ||
                             RegExp(r'\b\d{1,2}:\d{2}\b').hasMatch(query) ||  // Time like 7:30
                             RegExp(r'\bat \d{1,2}(?::\d{2})?\s*(pm|am)?\b').hasMatch(query);  // "at 7pm"
    
    // Only trigger if meal/event + strong time reference
    final result = hasMealEvent && hasStrongTimeRef;
    
    debugPrint('🔍 Calendar intent: hasMealEvent=$hasMealEvent, hasStrongTimeRef=$hasStrongTimeRef, result=$result');
    
    return result;
  }

  bool _isCalendarUpdateIntent(String query) {
    final hasUpdateWord = query.contains('change') || query.contains('update') || 
                          query.contains('move') || query.contains('reschedule');
    final hasEventWord = query.contains('event') || query.contains('meeting') || query.contains('appointment') ||
                         query.contains('dinner') || query.contains('lunch') || query.contains('breakfast') ||
                         query.contains('brunch') || query.contains('call');
    return hasUpdateWord && hasEventWord;
  }

  bool _isCalendarDeleteIntent(String query) {
    final hasDeleteWord = query.contains('cancel') || query.contains('delete') || query.contains('remove');
    final hasEventWord = query.contains('event') || query.contains('meeting') || query.contains('appointment') ||
                         query.contains('dinner') || query.contains('lunch') || query.contains('breakfast') ||
                         query.contains('brunch') || query.contains('call');
    return hasDeleteWord && hasEventWord;
  }

  // ========== CALENDAR PARSING ==========

  Future<Map<String, dynamic>?> _parseCalendarIntent(String query) async {
    // First try LLM for robust natural language understanding (Fantastical-style)
    final llmResult = await _parseCalendarIntentWithLLM(query);
    if (llmResult != null) {
      return llmResult;
    }
    
    // Fall back to regex parsing if LLM fails
    debugPrint('⚠️ LLM parsing failed, falling back to regex');
    return await _parseCalendarIntentWithRegex(query);
  }

  /// LLM-powered calendar intent parsing for robust natural language understanding
  Future<Map<String, dynamic>?> _parseCalendarIntentWithLLM(String query) async {
    try {
      final gemini = GeminiProvider();
      final now = DateTime.now();
      
      final prompt = '''You are a calendar parsing assistant. Parse this natural language request and return ONLY valid JSON.

User request: "$query"

Current date/time: ${now.toIso8601String()}
Current day: ${DateFormat('EEEE').format(now)}

Rules:
- Extract the event title (remove temporal words like "tomorrow", "at 7pm", days of week)
- Parse any time mentioned (convert to 24-hour format)
- Parse date references ("tomorrow", "next Friday", "December 15th", "in 2 hours")
- Extract location if mentioned ("at restaurant", "in downtown", "at 123 Main St")
- Extract invitees if mentioned ("with John", "with Sarah and Mike")
- Extract duration if mentioned ("for 2 hours", "1 hour meeting")

Return ONLY this JSON structure (omit fields not found):
{
  "title": "Clean event title without temporal words",
  "date": "YYYY-MM-DD",
  "time": "HH:MM",
  "location": "location string",
  "invitees": ["name1", "name2"],
  "durationMinutes": 60
}

Examples:
- "dinner with Sarah tomorrow at 7pm" → {"title": "Dinner with Sarah", "date": "tomorrow's date", "time": "19:00"}
- "1 hour meeting next Friday at 2:30pm" → {"title": "Meeting", "date": "next Friday's date", "time": "14:30", "durationMinutes": 60}
- "lunch at Nobu on Dec 15 at noon" → {"title": "Lunch", "date": "2024-12-15", "time": "12:00", "location": "Nobu"}

Return ONLY the JSON, no explanation.''';

      final response = await gemini.generateResponse(
        prompt: prompt,
        modelId: 'gemini-2.0-flash',
      );
      
      debugPrint('🤖 LLM parse response: $response');
      
      // Extract JSON from response (handle markdown code blocks)
      String jsonStr = response.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'^```\w*\n?'), '').replaceFirst(RegExp(r'\n?```$'), '');
      }
      
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      // Convert to our expected format
      final result = <String, dynamic>{};
      
      // Title
      if (parsed['title'] != null) {
        result['title'] = parsed['title'];
      }
      
      // Start time - combine date and time
      if (parsed['date'] != null || parsed['time'] != null) {
        DateTime startTime;
        
        if (parsed['date'] != null && parsed['time'] != null) {
          // Both date and time provided
          final dateParts = (parsed['date'] as String).split('-');
          final timeParts = (parsed['time'] as String).split(':');
          startTime = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
        } else if (parsed['time'] != null) {
          // Time only - use today or tomorrow
          final timeParts = (parsed['time'] as String).split(':');
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          startTime = DateTime(now.year, now.month, now.day, hour, minute);
          if (startTime.isBefore(now)) {
            startTime = startTime.add(const Duration(days: 1));
          }
        } else {
          // Date only - use noon as default
          final dateParts = (parsed['date'] as String).split('-');
          startTime = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
            12, 0,
          );
        }
        
        result['startTime'] = startTime.toIso8601String();
      }
      
      // Location
      if (parsed['location'] != null) {
        result['location'] = parsed['location'];
      }
      
      // Invitees
      if (parsed['invitees'] != null && (parsed['invitees'] as List).isNotEmpty) {
        result['invitees'] = parsed['invitees'];
      }
      
      // Duration
      if (parsed['durationMinutes'] != null) {
        result['durationMinutes'] = parsed['durationMinutes'];
      }
      
      if (result.containsKey('title')) {
        debugPrint('✅ LLM parsed: $result');
        return result;
      }
      
      return null;
    } catch (e) {
      debugPrint('⚠️ LLM calendar parsing failed: $e');
      return null;
    }
  }

  /// Regex-based fallback for calendar intent parsing
  Future<Map<String, dynamic>?> _parseCalendarIntentWithRegex(String query) async {
    try {
      String? title;
      DateTime? startTime;
      String? location;

      // Extract title - improved to handle day-of-week patterns like "Saturday"
      final titlePattern = RegExp(
        r'(?:add|create|schedule|book|put)\s+(?:an?\s+)?'
        r'(?:(dinner|lunch|breakfast|brunch|meeting|appointment|appt|call|event|interview)\s*)?'
        r'(.*?)'
        r'\s+(?:tonight|tomorrow|this|next|sunday|monday|tuesday|wednesday|thursday|friday|saturday|at\s+\d)',
        caseSensitive: false,
      );
      final titleMatch = titlePattern.firstMatch(query);
      
      if (titleMatch != null) {
        final eventType = titleMatch.group(1)?.trim();
        final details = titleMatch.group(2)?.trim();
        
        if (eventType != null && eventType.isNotEmpty) {
          final capitalizedType = eventType[0].toUpperCase() + eventType.substring(1).toLowerCase();
          if (details != null && details.isNotEmpty) {
            title = '$capitalizedType $details';
          } else {
            title = capitalizedType;
          }
        } else if (details != null && details.isNotEmpty) {
          title = details;
        }
        
        // Clean up title
        title = title?.replaceAll(RegExp(r'\s+(night|evening|afternoon|morning)$', caseSensitive: false), '');
        title = title?.replaceAll(RegExp(r'\s+in\s+[a-zA-Z\s,]+$', caseSensitive: false), '');
        title = title?.replaceAll(RegExp(r'\s+(sunday|monday|tuesday|wednesday|thursday|friday|saturday)$', caseSensitive: false), '');
        title = title?.replaceAll(RegExp(r'\s+(this|next|tonight|tomorrow)$', caseSensitive: false), '');
        title = title?.trim();
      }
      
      // Fallback for just event type
      if (title == null || title.isEmpty) {
        final simplePattern = RegExp(
          r'(?:add|create|schedule)\s+(?:an?\s+)?(dinner|lunch|breakfast|brunch|meeting|appointment|call)',
          caseSensitive: false,
        );
        final simpleMatch = simplePattern.firstMatch(query);
        if (simpleMatch != null) {
          final eventType = simpleMatch.group(1)!;
          title = eventType[0].toUpperCase() + eventType.substring(1).toLowerCase();
        }
      }
      
      // Extract location
      final locationPattern = RegExp(r'in\s+([a-zA-Z\s,]+?)(?:\s+(?:at|with|on|to|$))', caseSensitive: false);
      final locationMatch = locationPattern.firstMatch(query);
      if (locationMatch != null) {
        location = locationMatch.group(1)?.trim();
      }

      // Parse date
      DateTime? baseDate;
      final now = DateTime.now();
      
      final dayOfWeekPattern = RegExp(
        r'(this|next)?\s*(sunday|monday|tuesday|wednesday|thursday|friday|saturday)',
        caseSensitive: false,
      );
      final dayMatch = dayOfWeekPattern.firstMatch(query.toLowerCase());
      
      if (dayMatch != null) {
        final dayName = dayMatch.group(2)!;
        final modifier = dayMatch.group(1);
        final dayMap = {
          'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4,
          'friday': 5, 'saturday': 6, 'sunday': 7,
        };
        final targetWeekday = dayMap[dayName]!;
        int daysUntil = targetWeekday - now.weekday;
        if (daysUntil <= 0 || modifier == 'next') {
          daysUntil += 7;
        }
        baseDate = now.add(Duration(days: daysUntil));
      } else if (query.toLowerCase().contains('tomorrow')) {
        baseDate = now.add(const Duration(days: 1));
      } else if (query.toLowerCase().contains('tonight')) {
        baseDate = now;
      }

      // Parse time
      final timePatterns = [
        RegExp(r'at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false),
        RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)', caseSensitive: false),
      ];

      for (final pattern in timePatterns) {
        final match = pattern.firstMatch(query.toLowerCase());
        if (match != null) {
          int hour = int.parse(match.group(1)!);
          int minute = int.tryParse(match.group(2) ?? '0') ?? 0;
          String? ampm = match.group(3);

          if (ampm != null) {
            if (ampm == 'pm' && hour < 12) hour += 12;
            if (ampm == 'am' && hour == 12) hour = 0;
          } else if (hour >= 5 && hour <= 11) {
            hour += 12;
          }

          if (baseDate == null) {
            final candidateTime = DateTime(now.year, now.month, now.day, hour, minute);
            baseDate = candidateTime.isBefore(now) 
              ? now.add(const Duration(days: 1))
              : now;
          }

          startTime = DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
          break;
        }
      }

      if (title != null && title.isNotEmpty) {
        return {
          'title': title,
          if (startTime != null) 'startTime': startTime.toIso8601String(),
          if (location != null) 'location': location,
        };
      }

      return null;
    } catch (e) {
      debugPrint('❌ Regex calendar parsing failed: $e');
      return null;
    }
  }
}
