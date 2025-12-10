import 'package:hive_flutter/hive_flutter.dart';

/// Memory Spine - Shared state accessible by all Room Brains
/// This is the "nervous system" connecting all domain expertise
class MemorySpine {
  // Singleton instance
  static final MemorySpine _instance = MemorySpine._internal();
  factory MemorySpine() => _instance;
  MemorySpine._internal();

  late Box<Map<dynamic, dynamic>> _stateBox;
  bool _initialized = false;

  /// Initialize the memory spine
  Future<void> initialize() async {
    if (_initialized) return;
    
    _stateBox = await Hive.openBox<Map<dynamic, dynamic>>('memory_spine');
    _initialized = true;
    
    // Initialize state layers if they don't exist
    if (!_stateBox.containsKey('CORE_IDENTITY')) {
      _stateBox.put('CORE_IDENTITY', <String, dynamic>{});
    }
    if (!_stateBox.containsKey('HEALTH_STATE')) {
      _stateBox.put('HEALTH_STATE', <String, dynamic>{});
    }
    if (!_stateBox.containsKey('TIME_STATE')) {
      _stateBox.put('TIME_STATE', <String, dynamic>{});
    }
    if (!_stateBox.containsKey('PREFS_STATE')) {
      _stateBox.put('PREFS_STATE', <String, dynamic>{});
    }
    if (!_stateBox.containsKey('JOURNAL_STATE')) {
      _stateBox.put('JOURNAL_STATE', <String, dynamic>{});
    }
  }

  /// Read from a state layer
  Map<String, dynamic> read(String key) {
    if (!_initialized) {
      throw Exception('MemorySpine not initialized. Call initialize() first.');
    }
    
    final data = _stateBox.get(key);
    if (data == null) return {};
    
    return Map<String, dynamic>.from(data);
  }

  /// Write to a state layer
  /// Only specified agents can write to certain layers (enforced by caller)
  Future<void> write(String key, Map<String, dynamic> value) async {
    if (!_initialized) {
      throw Exception('MemorySpine not initialized. Call initialize() first.');
    }
    
    await _stateBox.put(key, value);
  }

  /// Update a specific field within a state layer
  Future<void> updateField(String stateKey, String fieldKey, dynamic value) async {
    final current = read(stateKey);
    current[fieldKey] = value;
    await write(stateKey, current);
  }

  /// Get a specific field from a state layer
  dynamic getField(String stateKey, String fieldKey) {
    final state = read(stateKey);
    return state[fieldKey];
  }

  /// Clear all state (for testing/reset)
  Future<void> clear() async {
    if (!_initialized) return;
    await _stateBox.clear();
    
    // Reinitialize empty state layers
    await _stateBox.put('CORE_IDENTITY', <String, dynamic>{});
    await _stateBox.put('HEALTH_STATE', <String, dynamic>{});
    await _stateBox.put('TIME_STATE', <String, dynamic>{});
    await _stateBox.put('PREFS_STATE', <String, dynamic>{});
    await _stateBox.put('JOURNAL_STATE', <String, dynamic>{});
  }
}

/// State layer definitions for type safety

class CoreIdentity {
  final String name;
  final int? age;
  final String? location;
  final List<String> values;
  final String? biography;

  CoreIdentity({
    required this.name,
    this.age,
    this.location,
    this.values = const [],
    this.biography,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'age': age,
    'location': location,
    'values': values,
    'biography': biography,
  };

  factory CoreIdentity.fromMap(Map<String, dynamic> map) => CoreIdentity(
    name: map['name'] ?? '',
    age: map['age'],
    location: map['location'],
    values: List<String>.from(map['values'] ?? []),
    biography: map['biography'],
  );
}

class HealthState {
  final double? hrv;  // Heart rate variability
  final double? sleepHours;
  final int? moodScore;  // 1-5
  final int? steps;
  final DateTime? lastUpdated;

  HealthState({
    this.hrv,
    this.sleepHours,
    this.moodScore,
    this.steps,
    this.lastUpdated,
  });

  Map<String, dynamic> toMap() => {
    'hrv': hrv,
    'sleep_hours': sleepHours,
    'mood_score': moodScore,
    'steps': steps,
    'last_updated': lastUpdated?.toIso8601String(),
  };

  factory HealthState.fromMap(Map<String, dynamic> map) => HealthState(
    hrv: map['hrv']?.toDouble(),
    sleepHours: map['sleep_hours']?.toDouble(),
    moodScore: map['mood_score'],
    steps: map['steps'],
    lastUpdated: map['last_updated'] != null 
      ? DateTime.parse(map['last_updated']) 
      : null,
  );
}

class TimeState {
  final List<String> upcomingEventIds;  // Next 24h
  final List<String> deadlineIds;  // Within 48h
  final String? focusTimeStart;  // HH:mm
  final String? focusTimeEnd;  // HH:mm

  TimeState({
    this.upcomingEventIds = const [],
    this.deadlineIds = const [],
    this.focusTimeStart,
    this.focusTimeEnd,
  });

  Map<String, dynamic> toMap() => {
    'upcoming_events': upcomingEventIds,
    'deadlines': deadlineIds,
    'focus_time_start': focusTimeStart,
    'focus_time_end': focusTimeEnd,
  };

  factory TimeState.fromMap(Map<String, dynamic> map) => TimeState(
    upcomingEventIds: List<String>.from(map['upcoming_events'] ?? []),
    deadlineIds: List<String>.from(map['deadlines'] ?? []),
    focusTimeStart: map['focus_time_start'],
    focusTimeEnd: map['focus_time_end'],
  );
}

class PrefsState {
  final bool notificationsEnabled;
  final bool privacyMode;
  final String? selectedCharacter;  // "aeliana", "marco", etc.

  PrefsState({
    this.notificationsEnabled = true,
    this.privacyMode = false,
    this.selectedCharacter,
  });

  Map<String, dynamic> toMap() => {
    'notifications_enabled': notificationsEnabled,
    'privacy_mode': privacyMode,
    'selected_character': selectedCharacter,
  };

  factory PrefsState.fromMap(Map<String, dynamic> map) => PrefsState(
    notificationsEnabled: map['notifications_enabled'] ?? true,
    privacyMode: map['privacy_mode'] ?? false,
    selectedCharacter: map['selected_character'],
  );
}

class JournalState {
  final int totalEntries;
  final int currentStreak;
  final double? averageMood;
  final List<String> recentTags;

  JournalState({
    this.totalEntries = 0,
    this.currentStreak = 0,
    this.averageMood,
    this.recentTags = const [],
  });

  Map<String, dynamic> toMap() => {
    'total_entries': totalEntries,
    'current_streak': currentStreak,
    'average_mood': averageMood,
    'recent_tags': recentTags,
  };

  factory JournalState.fromMap(Map<String, dynamic> map) => JournalState(
    totalEntries: map['total_entries'] ?? 0,
    currentStreak: map['current_streak'] ?? 0,
    averageMood: map['average_mood']?.toDouble(),
    recentTags: List<String>.from(map['recent_tags'] ?? []),
  );
}
