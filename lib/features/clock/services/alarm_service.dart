import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm_model.dart';

/// Service for managing alarms and timers
class AlarmService {
  static const String _alarmsKey = 'saved_alarms';
  static const String _timersKey = 'saved_timers';
  
  List<AlarmModel> _alarms = [];
  List<TimerModel> _timers = [];
  Timer? _activeCountdownTimer;
  
  // Callbacks
  Function(int alarmId)? onAlarmTriggered;
  Function(int timerId)? onTimerComplete;
  Function(TimerModel timer)? onTimerTick;

  /// Initialize the alarm service
  Future<void> init() async {
    await Alarm.init();
    await _loadAlarms();
    await _loadTimers();
    _scheduleAllAlarms();
  }

  /// Get all alarms
  List<AlarmModel> get alarms => List.unmodifiable(_alarms);

  /// Get all timers
  List<TimerModel> get timers => List.unmodifiable(_timers);

  /// Get the next scheduled alarm
  AlarmModel? get nextAlarm {
    final enabledAlarms = _alarms.where((a) => a.enabled).toList();
    if (enabledAlarms.isEmpty) return null;
    
    final now = DateTime.now();
    AlarmModel? next;
    Duration? shortestDuration;
    
    for (final alarm in enabledAlarms) {
      final nextOccurrence = _getNextOccurrence(alarm);
      if (nextOccurrence != null) {
        final duration = nextOccurrence.difference(now);
        if (shortestDuration == null || duration < shortestDuration) {
          shortestDuration = duration;
          next = alarm;
        }
      }
    }
    
    return next;
  }

  /// Get the next occurrence datetime for an alarm
  DateTime? _getNextOccurrence(AlarmModel alarm) {
    final now = DateTime.now();
    var alarmTime = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
    
    if (alarm.repeatDays.isEmpty) {
      // One-time alarm
      if (alarmTime.isBefore(now)) {
        alarmTime = alarmTime.add(const Duration(days: 1));
      }
      return alarmTime;
    }
    
    // Repeating alarm - find next valid day
    for (int i = 0; i < 7; i++) {
      final checkDate = alarmTime.add(Duration(days: i));
      final weekday = (checkDate.weekday - 1) % 7; // Convert to 0=Mon format
      
      if (alarm.repeatDays.contains(weekday)) {
        if (i == 0 && checkDate.isBefore(now)) continue;
        return checkDate;
      }
    }
    
    return null;
  }

  /// Add a new alarm
  Future<AlarmModel> addAlarm({
    required int hour,
    required int minute,
    List<int> repeatDays = const [],
    String label = 'Alarm',
    bool vibrate = true,
  }) async {
    // Use modulo to keep ID within Int32 range for native alarm package
    final id = DateTime.now().millisecondsSinceEpoch % 2147483647;
    final alarm = AlarmModel(
      id: id,
      hour: hour,
      minute: minute,
      repeatDays: repeatDays,
      label: label,
      vibrate: vibrate,
    );
    
    _alarms.add(alarm);
    await _saveAlarms();
    await _scheduleAlarm(alarm);
    
    return alarm;
  }

  /// Update an existing alarm
  Future<void> updateAlarm(AlarmModel alarm) async {
    final index = _alarms.indexWhere((a) => a.id == alarm.id);
    if (index != -1) {
      await Alarm.stop(alarm.id);
      _alarms[index] = alarm;
      await _saveAlarms();
      if (alarm.enabled) {
        await _scheduleAlarm(alarm);
      }
    }
  }

  /// Toggle alarm enabled state
  Future<void> toggleAlarm(int id) async {
    final index = _alarms.indexWhere((a) => a.id == id);
    if (index != -1) {
      final alarm = _alarms[index];
      final updated = alarm.copyWith(enabled: !alarm.enabled);
      await updateAlarm(updated);
    }
  }

  /// Delete an alarm
  Future<void> deleteAlarm(int id) async {
    await Alarm.stop(id);
    _alarms.removeWhere((a) => a.id == id);
    await _saveAlarms();
  }

  /// Schedule an alarm with the native alarm package
  Future<void> _scheduleAlarm(AlarmModel alarm) async {
    if (!alarm.enabled) return;
    
    // Skip alarms with invalid IDs (larger than Int32 max)
    if (alarm.id > 2147483647) {
      debugPrint('Skipping alarm ${alarm.id} - ID too large');
      return;
    }
    
    final nextOccurrence = _getNextOccurrence(alarm);
    if (nextOccurrence == null) return;
    
    final alarmSettings = AlarmSettings(
      id: alarm.id,
      dateTime: nextOccurrence,
      assetAudioPath: 'assets/audio/alarm.mp3', // Default alarm sound
      loopAudio: true,
      vibrate: alarm.vibrate,
      notificationSettings: NotificationSettings(
        title: alarm.label,
        body: 'Alarm - ${alarm.timeString}',
        stopButton: 'Stop',
      ),
    );
    
    await Alarm.set(alarmSettings: alarmSettings);
  }

  /// Schedule all enabled alarms
  Future<void> _scheduleAllAlarms() async {
    for (final alarm in _alarms.where((a) => a.enabled)) {
      await _scheduleAlarm(alarm);
    }
  }

  /// Snooze an alarm
  Future<void> snoozeAlarm(int id, {int minutes = 5}) async {
    await Alarm.stop(id);
    
    final snoozeTime = DateTime.now().add(Duration(minutes: minutes));
    final alarm = _alarms.firstWhere((a) => a.id == id);
    
    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: snoozeTime,
      assetAudioPath: 'assets/audio/alarm.mp3',
      loopAudio: true,
      vibrate: alarm.vibrate,
      notificationSettings: NotificationSettings(
        title: '${alarm.label} (Snoozed)',
        body: 'Alarm - ${alarm.timeString}',
        stopButton: 'Stop',
      ),
    );
    
    await Alarm.set(alarmSettings: alarmSettings);
  }

  /// Stop an alarm
  Future<void> stopAlarm(int id) async {
    await Alarm.stop(id);
  }

  // ============ TIMER METHODS ============

  /// Start a new countdown timer
  Future<TimerModel> startTimer({
    required int durationSeconds,
    String label = 'Timer',
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch % 2147483647;
    final timer = TimerModel(
      id: id,
      durationSeconds: durationSeconds,
      remainingSeconds: durationSeconds,
      isRunning: true,
      label: label,
      startedAt: DateTime.now(),
    );
    
    _timers.add(timer);
    await _saveTimers();
    _startCountdown(timer);
    
    return timer;
  }

  /// Start countdown for a timer
  void _startCountdown(TimerModel timer) {
    _activeCountdownTimer?.cancel();
    
    int remaining = timer.remainingSeconds;
    
    _activeCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      remaining--;
      
      final index = _timers.indexWhere((tm) => tm.id == timer.id);
      if (index != -1) {
        _timers[index] = _timers[index].copyWith(remainingSeconds: remaining);
        onTimerTick?.call(_timers[index]);
        
        if (remaining <= 0) {
          t.cancel();
          _timers[index] = _timers[index].copyWith(isRunning: false);
          onTimerComplete?.call(timer.id);
          _saveTimers();
        }
      }
    });
  }

  /// Pause a timer
  void pauseTimer(int id) {
    _activeCountdownTimer?.cancel();
    final index = _timers.indexWhere((t) => t.id == id);
    if (index != -1) {
      _timers[index] = _timers[index].copyWith(isRunning: false);
      _saveTimers();
    }
  }

  /// Resume a timer
  void resumeTimer(int id) {
    final index = _timers.indexWhere((t) => t.id == id);
    if (index != -1) {
      _timers[index] = _timers[index].copyWith(isRunning: true);
      _startCountdown(_timers[index]);
      _saveTimers();
    }
  }

  /// Reset a timer
  void resetTimer(int id) {
    _activeCountdownTimer?.cancel();
    final index = _timers.indexWhere((t) => t.id == id);
    if (index != -1) {
      _timers[index] = _timers[index].copyWith(
        remainingSeconds: _timers[index].durationSeconds,
        isRunning: false,
      );
      _saveTimers();
    }
  }

  /// Delete a timer
  Future<void> deleteTimer(int id) async {
    _activeCountdownTimer?.cancel();
    _timers.removeWhere((t) => t.id == id);
    await _saveTimers();
  }

  // ============ PERSISTENCE ============

  Future<void> _loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_alarmsKey);
    if (json != null) {
      final list = jsonDecode(json) as List;
      _alarms = list.map((e) => AlarmModel.fromJson(e)).toList();
    }
  }

  Future<void> _saveAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_alarms.map((a) => a.toJson()).toList());
    await prefs.setString(_alarmsKey, json);
  }

  Future<void> _loadTimers() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_timersKey);
    if (json != null) {
      final list = jsonDecode(json) as List;
      _timers = list.map((e) => TimerModel.fromJson(e)).toList();
    }
  }

  Future<void> _saveTimers() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_timers.map((t) => t.toJson()).toList());
    await prefs.setString(_timersKey, json);
  }

  /// Dispose resources
  void dispose() {
    _activeCountdownTimer?.cancel();
  }
}
