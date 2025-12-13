import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Represents a health metric that can be tracked
class HealthMetric {
  final String id;
  final String name;
  final String unit;
  final String iconName; // Helper to map to UI icons
  final double? minValue;
  final double? maxValue;
  final bool isDefault;

  HealthMetric({
    required this.id,
    required this.name,
    required this.unit,
    required this.iconName,
    this.minValue,
    this.maxValue,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unit': unit,
    'iconName': iconName,
    'minValue': minValue,
    'maxValue': maxValue,
    'isDefault': isDefault,
  };

  factory HealthMetric.fromJson(Map<String, dynamic> json) {
    return HealthMetric(
      id: json['id'],
      name: json['name'],
      unit: json['unit'],
      iconName: json['iconName'],
      minValue: json['minValue']?.toDouble(),
      maxValue: json['maxValue']?.toDouble(),
      isDefault: json['isDefault'] ?? false,
    );
  }
}

/// A specific data entry for a metric
class MetricEntry {
  final String metricId;
  final double value;
  final DateTime timestamp;
  final String? note;

  MetricEntry({
    required this.metricId,
    required this.value,
    required this.timestamp,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'metricId': metricId,
    'value': value,
    'timestamp': timestamp.toIso8601String(),
    'note': note,
  };

  factory MetricEntry.fromJson(Map<String, dynamic> json) {
    return MetricEntry(
      metricId: json['metricId'],
      value: json['value'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      note: json['note'],
    );
  }
}

class VitalBalanceService {
  static const String _keyMetrics = 'vb_metrics_definitions';
  static const String _keyEntriesPrefix = 'vb_entries_';
  static const String _keyProfile = 'vb_health_profile';

  /// Initial list of popular metrics
  static final List<HealthMetric> _defaultMetrics = [
    HealthMetric(id: 'sleep', name: 'Sleep', unit: 'hrs', iconName: 'moon', isDefault: true),
    HealthMetric(id: 'sleep_quality', name: 'Sleep Quality', unit: '/10', iconName: 'sparkles', minValue: 0, maxValue: 10, isDefault: true),
    HealthMetric(id: 'energy', name: 'Energy', unit: '/10', iconName: 'zap', minValue: 0, maxValue: 10, isDefault: true),
    HealthMetric(id: 'mood', name: 'Mood', unit: '/10', iconName: 'smile', minValue: 0, maxValue: 10, isDefault: true),
    HealthMetric(id: 'stress', name: 'Stress', unit: '/10', iconName: 'brain', minValue: 0, maxValue: 10, isDefault: true),
    HealthMetric(id: 'weight', name: 'Weight', unit: 'lbs', iconName: 'scale', isDefault: true),
    HealthMetric(id: 'bp_sys', name: 'BP (Sys)', unit: 'mmHg', iconName: 'heart_pulse', isDefault: true),
    HealthMetric(id: 'bp_dia', name: 'BP (Dia)', unit: 'mmHg', iconName: 'heart_pulse', isDefault: true),
    HealthMetric(id: 'water', name: 'Water', unit: 'oz', iconName: 'droplets', isDefault: true),
    HealthMetric(id: 'pain', name: 'Pain', unit: '/10', iconName: 'flame', minValue: 0, maxValue: 10, isDefault: true),
    HealthMetric(id: 'steps', name: 'Steps', unit: 'steps', iconName: 'footprints', isDefault: true),
    HealthMetric(id: 'heart_rate', name: 'Heart Rate', unit: 'bpm', iconName: 'heart_pulse', isDefault: true),
    HealthMetric(id: 'meditation', name: 'Meditation', unit: 'min', iconName: 'sparkles', isDefault: true),
  ];

  /// Get icon data from string name - Premium, distinctive icons
  static IconData getIconData(String name) {
    switch (name) {
      case 'moon': return LucideIcons.bedDouble; // Sleep icon - bed for sleep
      case 'cloud_moon': return LucideIcons.cloudMoon; // Dreams icon
      case 'zap': return LucideIcons.battery; // Energy as battery
      case 'smile': return LucideIcons.smile; // Classic smile for mood
      case 'brain': return LucideIcons.brain; // Simple brain for stress
      case 'scale': return LucideIcons.scale; // Weight scale
      case 'droplet': return LucideIcons.glassWater; // Glass of water
      case 'droplets': return LucideIcons.glassWater;
      case 'thermometer': return LucideIcons.activity; // Pain as pulse
      case 'flame': return LucideIcons.activity;
      case 'footprints': return LucideIcons.footprints; // Steps
      case 'heart': return LucideIcons.heartPulse; // Heart rate
      case 'heart_pulse': return LucideIcons.heartPulse;
      case 'flower': return LucideIcons.wind; // Meditation as breath
      case 'sparkles': return LucideIcons.sparkles; // Sleep quality / meditation sparkles
      default: return LucideIcons.activity;
    }
  }

  /// Get all active metrics (defaults + user added)
  static Future<List<HealthMetric>> getMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_keyMetrics);
    
    if (jsonStr == null) {
      // First run: save defaults
      await _saveMetrics(_defaultMetrics);
      return _defaultMetrics;
    }

    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      final storedMetrics = list.map((e) => HealthMetric.fromJson(e)).toList();
      
      // Ensure specific default metrics exist (like BP) if they were added later
      bool addedNew = false;
      for (var def in _defaultMetrics) {
        if (!storedMetrics.any((m) => m.id == def.id)) {
           storedMetrics.add(def);
           addedNew = true;
        }
      }
      if (addedNew) await _saveMetrics(storedMetrics);
      
      return storedMetrics;
    } catch (e) {
      debugPrint('Error parsing metrics: $e');
      return _defaultMetrics;
    }
  }

  static Future<void> _saveMetrics(List<HealthMetric> metrics) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonStr = jsonEncode(metrics.map((e) => e.toJson()).toList());
    await prefs.setString(_keyMetrics, jsonStr);
  }

  /// Get Health Profile (Age, Sex, Race, etc.)
  static Future<Map<String, String>> getProfile() async {
     final prefs = await SharedPreferences.getInstance();
     final String? jsonStr = prefs.getString(_keyProfile);
     if (jsonStr == null) return {};
     try {
       return Map<String, String>.from(jsonDecode(jsonStr));
     } catch (e) {
       return {};
     }
  }

  /// Update Health Profile
  static Future<void> updateProfile(Map<String, String> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, jsonEncode(profile));
  }

  /// Add a new custom metric
  static Future<void> addMetric(String name, String unit) async {
    final metrics = await getMetrics();
    final newId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final newMetric = HealthMetric(
      id: newId, 
      name: name, 
      unit: unit, 
      iconName: 'activity' // Default icon for custom
    );
    metrics.add(newMetric);
    await _saveMetrics(metrics);
  }
  
  /// Delete a metric (and its history ideally, but we'll leave history for safety)
  static Future<void> deleteMetric(String id) async {
    final metrics = await getMetrics();
    metrics.removeWhere((m) => m.id == id);
    await _saveMetrics(metrics);
  }

  /// Add a data entry
  static Future<void> addEntry(String metricId, double value) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyEntriesPrefix$metricId';
    
    // Get existing
    List<MetricEntry> entries = await getEntries(metricId);
    
    // Add new
    entries.add(MetricEntry(
      metricId: metricId,
      value: value,
      timestamp: DateTime.now(),
    ));
    
    // Sort
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first
    
    // Save
    final jsonStr = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(key, jsonStr);
  }

  /// Get entries for a metric
  static Future<List<MetricEntry>> getEntries(String metricId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyEntriesPrefix$metricId';
    final String? jsonStr = prefs.getString(key);
    
    if (jsonStr == null) return [];
    
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => MetricEntry.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get latest value for a metric formatted as string
  static Future<String> getLatestValueFormatted(HealthMetric metric) async {
    final entries = await getEntries(metric.id);
    if (entries.isEmpty) return '-- ${metric.unit}';
    
    // For cumulative metrics (Water, Steps), sum today's values
    if (metric.id == 'water' || metric.id == 'steps') {
      final now = DateTime.now();
      final todayEntries = entries.where((e) => 
        e.timestamp.year == now.year && 
        e.timestamp.month == now.month && 
        e.timestamp.day == now.day
      );
      
      if (todayEntries.isEmpty) return '-- ${metric.unit}';
      
      double sum = 0;
      for (var e in todayEntries) {
        sum += e.value;
      }
      
      String valStr = sum.toString();
      if (valStr.endsWith('.0')) valStr = valStr.substring(0, valStr.length - 2);
      return '$valStr ${metric.unit}';
    }

    // For others, return latest
    final latest = entries.first;
    String valStr = latest.value.toString();
    if (valStr.endsWith('.0')) valStr = valStr.substring(0, valStr.length - 2);
    
    return '$valStr ${metric.unit}';
  }
}
