import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/goal_model.dart';

/// Service for managing user goals with Hive persistence (encrypted)
class GoalsService {
  static const String _boxName = 'goals_box_encrypted';
  static const String _maxGoalsKey = 'max_goals_limit';
  static const String _encryptionKeyName = 'goals_encryption_key';
  static const int _defaultMaxGoals = 6;
  
  static Box<Goal>? _box;
  static final _uuid = const Uuid();

  /// Get or create encryption key
  static Future<List<int>> _getOrCreateEncryptionKey() async {
    String? keyString;
    final useFallback = Platform.isMacOS || Platform.isLinux;
    
    if (useFallback) {
      final prefs = await SharedPreferences.getInstance();
      keyString = prefs.getString(_encryptionKeyName);
      if (keyString == null) {
        final key = Hive.generateSecureKey();
        keyString = base64Encode(key);
        await prefs.setString(_encryptionKeyName, keyString);
      }
    } else {
      const secureStorage = FlutterSecureStorage();
      try {
        keyString = await secureStorage.read(key: _encryptionKeyName);
        if (keyString == null) {
          final key = Hive.generateSecureKey();
          keyString = base64Encode(key);
          await secureStorage.write(key: _encryptionKeyName, value: keyString);
        }
      } catch (e) {
        final prefs = await SharedPreferences.getInstance();
        keyString = prefs.getString(_encryptionKeyName);
        if (keyString == null) {
          final key = Hive.generateSecureKey();
          keyString = base64Encode(key);
          await prefs.setString(_encryptionKeyName, keyString);
        }
      }
    }
    return base64Decode(keyString!);
  }

  /// Initialize Hive box for goals (encrypted)
  static Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    
    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(20)) {
      Hive.registerAdapter(GoalStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(21)) {
      Hive.registerAdapter(GoalCheckInAdapter());
    }
    if (!Hive.isAdapterRegistered(22)) {
      Hive.registerAdapter(GoalAdapter());
    }
    
    final encryptionKey = await _getOrCreateEncryptionKey();
    _box = await Hive.openBox<Goal>(
      _boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
    debugPrint('✅ GoalsService initialized with ${_box!.length} goals (ENCRYPTED)');
  }

  /// Get maximum number of goals allowed (user-configurable)
  static Future<int> getMaxGoals() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_maxGoalsKey) ?? _defaultMaxGoals;
  }

  /// Set maximum number of goals
  static Future<void> setMaxGoals(int max) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxGoalsKey, max.clamp(1, 20));
  }

  /// Get all goals
  static List<Goal> getAllGoals() {
    if (_box == null) return [];
    return _box!.values.toList();
  }

  /// Get only active goals
  static List<Goal> getActiveGoals() {
    return getAllGoals().where((g) => g.status == GoalStatus.active).toList();
  }

  /// Get goals that need check-in reminders
  static List<Goal> getGoalsNeedingReminder() {
    return getActiveGoals().where((g) => g.needsCheckInReminder).toList();
  }

  /// Check if user can add more goals
  static Future<bool> canAddGoal() async {
    final maxGoals = await getMaxGoals();
    final activeCount = getActiveGoals().length;
    return activeCount < maxGoals;
  }

  /// Add a new goal
  static Future<Goal?> addGoal({
    required String title,
    required String description,
    required DateTime targetDate,
    int checkInFrequencyDays = 3,
    String? aiTip,
  }) async {
    if (!await canAddGoal()) {
      debugPrint('⚠️ Cannot add goal: max limit reached');
      return null;
    }

    final goal = Goal(
      id: _uuid.v4(),
      title: title,
      description: description,
      createdAt: DateTime.now(),
      targetDate: targetDate,
      checkInFrequencyDays: checkInFrequencyDays,
      aiTip: aiTip,
    );

    await _box?.put(goal.id, goal);
    debugPrint('✅ Goal added: ${goal.title}');
    return goal;
  }

  /// Update an existing goal
  static Future<void> updateGoal(Goal goal) async {
    await _box?.put(goal.id, goal);
    debugPrint('✅ Goal updated: ${goal.title}');
  }

  /// Delete a goal
  static Future<void> deleteGoal(String goalId) async {
    await _box?.delete(goalId);
    debugPrint('🗑️ Goal deleted: $goalId');
  }

  /// Mark goal as completed
  static Future<void> completeGoal(String goalId) async {
    final goal = _box?.get(goalId);
    if (goal != null) {
      final updated = goal.copyWith(
        status: GoalStatus.completed,
        progressPercent: 100,
      );
      await updateGoal(updated);
    }
  }

  /// Mark goal as abandoned
  static Future<void> abandonGoal(String goalId) async {
    final goal = _box?.get(goalId);
    if (goal != null) {
      final updated = goal.copyWith(status: GoalStatus.abandoned);
      await updateGoal(updated);
    }
  }

  /// Add a check-in to a goal
  static Future<void> addCheckIn({
    required String goalId,
    required String note,
    required int progressPercent,
  }) async {
    final goal = _box?.get(goalId);
    if (goal == null) return;

    final checkIn = GoalCheckIn(
      date: DateTime.now(),
      note: note,
      progressUpdate: progressPercent,
    );

    final updatedCheckIns = [...goal.checkIns, checkIn];
    final updated = goal.copyWith(
      checkIns: updatedCheckIns,
      progressPercent: progressPercent,
      lastCheckInReminder: DateTime.now(),
    );

    await updateGoal(updated);
    debugPrint('✅ Check-in added to goal: ${goal.title} ($progressPercent%)');
  }

  /// Update goal's AI tip
  static Future<void> updateAiTip(String goalId, String tip) async {
    final goal = _box?.get(goalId);
    if (goal != null) {
      final updated = goal.copyWith(aiTip: tip);
      await updateGoal(updated);
    }
  }

  /// Get goal by ID
  static Goal? getGoal(String goalId) {
    return _box?.get(goalId);
  }

  /// Clear all goals (for testing)
  static Future<void> clearAll() async {
    await _box?.clear();
    debugPrint('🗑️ All goals cleared');
  }
}
