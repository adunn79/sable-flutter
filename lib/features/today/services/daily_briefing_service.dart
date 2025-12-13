import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:sable/core/ai/model_orchestrator.dart';
import 'package:sable/core/ai/providers/gemini_provider.dart';
import 'package:sable/core/emotion/weather_service.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:sable/core/reminders/reminders_service.dart' as reminders_svc;
import 'package:sable/core/contacts/birthday_service.dart';
import 'package:sable/core/calendar/moon_phase_service.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';

/// Models the result of a daily briefing generation
class DailyBriefing {
  final String text;
  final String vibe; // e.g. "Busy", "Chill", "Adventure"
  final DateTime timestamp;

  DailyBriefing({
    required this.text,
    required this.vibe,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'vibe': vibe,
    'timestamp': timestamp.toIso8601String(),
  };

  factory DailyBriefing.fromJson(Map<String, dynamic> json) {
    return DailyBriefing(
      text: json['text'] as String,
      vibe: json['vibe'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Service to generate an AI-powered daily briefing summary
class DailyBriefingService {
  static const String _storageKey = 'daily_briefing_cache';
  
  // Singleton
  static final DailyBriefingService _instance = DailyBriefingService._internal();
  factory DailyBriefingService() => _instance;
  DailyBriefingService._internal();

  /// Get the current briefing, generating a new one if cache is stale (older than 4 hours or different day)
  /// or if forceRefresh is true.
  Future<DailyBriefing?> getBriefing({
    required List<Event> events,
    required List<reminders_svc.Reminder> tasks,
    String? location,
    String? weatherTemp,
    String? weatherCondition,
    required MoonPhase moonPhase,
    required List<ContactBirthday> birthdays,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_storageKey);
    
    if (cachedJson != null && !forceRefresh) {
      try {
        final cached = DailyBriefing.fromJson(jsonDecode(cachedJson));
        final now = DateTime.now();
        
        // Check if cache is from today and recently generated (< 4 hours)
        final isSameDay = cached.timestamp.year == now.year && 
                          cached.timestamp.month == now.month && 
                          cached.timestamp.day == now.day;
        final isRecent = now.difference(cached.timestamp).inHours < 4;
        
        if (isSameDay && isRecent) {
          debugPrint('🧠 DailyBriefing: Using cached briefing.');
          return cached;
        }
      } catch (e) {
        debugPrint('❌ DailyBriefing: Cache parse error: $e');
      }
    }
    
    // Generate new briefing
    return await _generateBriefing(
      events: events,
      tasks: tasks,
      location: location,
      weatherTemp: weatherTemp,
      weatherCondition: weatherCondition,
      moonPhase: moonPhase,
      birthdays: birthdays,
    );
  }

  Future<DailyBriefing?> _generateBriefing({
    required List<Event> events,
    required List<reminders_svc.Reminder> tasks,
    String? location,
    String? weatherTemp,
    String? weatherCondition,
    required MoonPhase moonPhase,
    required List<ContactBirthday> birthdays,
  }) async {
    try {
      debugPrint('🧠 DailyBriefing: Generating new briefing...');
      
      // 1. Get User/Persona Context
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_name') ?? 'User';
      final stateService = await OnboardingStateService.create();
      final archetypeId = stateService.selectedArchetypeId ?? 'sable';
      final archetypeCapitalized = archetypeId[0].toUpperCase() + archetypeId.substring(1);

      // 2. Build Context String
      final sb = StringBuffer();
      
      sb.writeln('DATE: ${DateFormat('EEEE, MMMM d, y').format(DateTime.now())}');
      if (location != null) sb.writeln('LOCATION: $location');
      if (weatherTemp != null && weatherCondition != null) {
        sb.writeln('WEATHER: $weatherTemp, $weatherCondition');
      }
      sb.writeln('MOON PHASE: ${MoonPhaseService.getPhaseName(moonPhase)}');
      
      sb.writeln('\nEVENTS (${events.length}):');
      if (events.isEmpty) {
        sb.writeln('- No events scheduled.');
      } else {
        for (var e in events) {
          final time = e.allDay == true ? 'All Day' : DateFormat('h:mm a').format(e.start!);
          sb.writeln('- $time: ${e.title}');
        }
      }
      
      final dueTasks = tasks.where((t) => !t.isCompleted && 
        (t.dueDate == null || t.dueDate!.isBefore(DateTime.now().add(const Duration(days: 1)))))
        .toList();
        
      sb.writeln('\nTASKS DUE SOON (${dueTasks.length}):');
       if (dueTasks.isEmpty) {
        sb.writeln('- No pending tasks.');
      } else {
        for (var t in dueTasks.take(5)) {
          sb.writeln('- ${t.title}');
        }
      }
      
      if (birthdays.isNotEmpty) {
        sb.writeln('\nBIRTHDAYS TODAY: ${birthdays.map((b) => "${b.name} (${b.age})").join(", ")}');
      }

      // 3. Construct Prompt
      final systemPrompt = '''
You are $archetypeCapitalized, an elite AI executive assistant and close friend to $userName.
Your goal is to provide a "Daily Briefing" - a short, synthesized summary of the day.

RULES:
1. Be concise (1-3 sentences max).
2. Be "Hyper-Human": warm, witty, maybe a little sassy if appropriate for the vibe.
3. SYNTHESIZE: Don't just list items. Connect the dots. (e.g., "Busy morning with meetings, but clear skies later for that run.")
4. HIGHLIGHT: Pick the most innovative/important/fun thing to mention.
5. VIBE CHECK: End with a 1-word "Vibe Label" in brackets, e.g. [Start] Text... [End][Busy] or [Chill] or [Focused].
''';

      final userPrompt = '''
Here is my context for today:
${sb.toString()}

Give me my briefing.
''';

      // 4. Call AI (Using Gemini Flash for speed)
      final gemini = GeminiProvider();
      final responseToken = await gemini.generateResponse(
        prompt: userPrompt,
        systemPrompt: systemPrompt,
        modelId: 'gemini-2.0-flash-exp', // Fast model
      );
      
      // 5. Parse Response
      // Expected format: "Here is your summary... [Vibe]"
      String text = responseToken.trim();
      String vibe = 'Balanced';
      
      // Extract Vibe from brackets at end
      final vibeRegex = RegExp(r'\[([a-zA-Z\s]+)\]$');
      final match = vibeRegex.firstMatch(text);
      if (match != null) {
        vibe = match.group(1)?.trim() ?? 'Balanced';
        text = text.substring(0, match.start).trim();
      }
      
      // Remove any lingering [Start]/[End] tags if model adds them
      text = text.replaceAll('[Start]', '').replaceAll('[End]', '').trim();
      
      // 6. Save to Cache
      final briefing = DailyBriefing(
        text: text,
        vibe: vibe,
        timestamp: DateTime.now(),
      );
      
      await prefs.setString(_storageKey, jsonEncode(briefing.toJson()));
      
      return briefing;
      
    } catch (e) {
      debugPrint('❌ DailyBriefing: Generation failed: $e');
      return null;
    }
  }
}
