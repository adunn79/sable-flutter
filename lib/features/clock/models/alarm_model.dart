import 'dart:convert';

/// Represents a single alarm
class AlarmModel {
  final int id;
  final int hour;
  final int minute;
  final List<int> repeatDays; // 0=Mon, 1=Tue, ... 6=Sun, empty = one-time
  final bool enabled;
  final String label;
  final bool vibrate;
  final bool snoozeEnabled;
  final int snoozeDuration; // minutes

  AlarmModel({
    required this.id,
    required this.hour,
    required this.minute,
    this.repeatDays = const [],
    this.enabled = true,
    this.label = 'Alarm',
    this.vibrate = true,
    this.snoozeEnabled = true,
    this.snoozeDuration = 5,
  });

  /// Get the time as a formatted string (e.g., "7:30 AM")
  String get timeString {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final ampm = hour < 12 ? 'AM' : 'PM';
    return '$h:${minute.toString().padLeft(2, '0')} $ampm';
  }

  /// Get the time as 24hr string (e.g., "07:30")
  String get time24String {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Get repeat days as readable string
  String get repeatString {
    if (repeatDays.isEmpty) return 'Once';
    if (repeatDays.length == 7) return 'Every day';
    if (repeatDays.length == 5 && 
        repeatDays.contains(0) && repeatDays.contains(1) &&
        repeatDays.contains(2) && repeatDays.contains(3) &&
        repeatDays.contains(4)) {
      return 'Weekdays';
    }
    if (repeatDays.length == 2 && 
        repeatDays.contains(5) && repeatDays.contains(6)) {
      return 'Weekends';
    }
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return repeatDays.map((d) => days[d]).join(', ');
  }

  AlarmModel copyWith({
    int? id,
    int? hour,
    int? minute,
    List<int>? repeatDays,
    bool? enabled,
    String? label,
    bool? vibrate,
    bool? snoozeEnabled,
    int? snoozeDuration,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDays: repeatDays ?? this.repeatDays,
      enabled: enabled ?? this.enabled,
      label: label ?? this.label,
      vibrate: vibrate ?? this.vibrate,
      snoozeEnabled: snoozeEnabled ?? this.snoozeEnabled,
      snoozeDuration: snoozeDuration ?? this.snoozeDuration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'repeatDays': repeatDays,
      'enabled': enabled,
      'label': label,
      'vibrate': vibrate,
      'snoozeEnabled': snoozeEnabled,
      'snoozeDuration': snoozeDuration,
    };
  }

  factory AlarmModel.fromJson(Map<String, dynamic> json) {
    return AlarmModel(
      id: json['id'] as int,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      repeatDays: List<int>.from(json['repeatDays'] ?? []),
      enabled: json['enabled'] as bool? ?? true,
      label: json['label'] as String? ?? 'Alarm',
      vibrate: json['vibrate'] as bool? ?? true,
      snoozeEnabled: json['snoozeEnabled'] as bool? ?? true,
      snoozeDuration: json['snoozeDuration'] as int? ?? 5,
    );
  }
}

/// Represents a countdown timer
class TimerModel {
  final int id;
  final int durationSeconds;
  final int remainingSeconds;
  final bool isRunning;
  final String label;
  final DateTime? startedAt;

  TimerModel({
    required this.id,
    required this.durationSeconds,
    this.remainingSeconds = 0,
    this.isRunning = false,
    this.label = 'Timer',
    this.startedAt,
  });

  /// Get remaining time as formatted string (e.g., "05:30")
  String get remainingString {
    final mins = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  /// Get duration as formatted string
  String get durationString {
    if (durationSeconds >= 3600) {
      final hrs = durationSeconds ~/ 3600;
      final mins = (durationSeconds % 3600) ~/ 60;
      return '$hrs hr ${mins > 0 ? '$mins min' : ''}';
    }
    return '${durationSeconds ~/ 60} min';
  }

  TimerModel copyWith({
    int? id,
    int? durationSeconds,
    int? remainingSeconds,
    bool? isRunning,
    String? label,
    DateTime? startedAt,
  }) {
    return TimerModel(
      id: id ?? this.id,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      label: label ?? this.label,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'durationSeconds': durationSeconds,
      'remainingSeconds': remainingSeconds,
      'isRunning': isRunning,
      'label': label,
      'startedAt': startedAt?.toIso8601String(),
    };
  }

  factory TimerModel.fromJson(Map<String, dynamic> json) {
    return TimerModel(
      id: json['id'] as int,
      durationSeconds: json['durationSeconds'] as int,
      remainingSeconds: json['remainingSeconds'] as int? ?? 0,
      isRunning: json['isRunning'] as bool? ?? false,
      label: json['label'] as String? ?? 'Timer',
      startedAt: json['startedAt'] != null 
          ? DateTime.parse(json['startedAt']) 
          : null,
    );
  }
}
