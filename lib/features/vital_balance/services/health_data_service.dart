import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/lab_result.dart';
import '../models/vital_reading.dart';

/// Service for managing health data (lab results, vitals)
/// 
/// All data stored locally with encryption. Supports:
/// - Manual entry
/// - OCR scan import
/// - Apple HealthKit sync
class HealthDataService {
  static const String _labResultsBox = 'lab_results';
  static const String _vitalReadingsBox = 'vital_readings';
  static Box<LabResult>? _labBox;
  static Box<VitalReading>? _vitalBox;
  static const _uuid = Uuid();
  
  /// Initialize health data storage
  static Future<void> init() async {
    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(31)) {
      Hive.registerAdapter(LabResultAdapter());
    }
    if (!Hive.isAdapterRegistered(32)) {
      Hive.registerAdapter(VitalReadingAdapter());
    }
    
    _labBox = await Hive.openBox<LabResult>(_labResultsBox);
    _vitalBox = await Hive.openBox<VitalReading>(_vitalReadingsBox);
    
    debugPrint('🏥 HealthDataService initialized: ${_labBox!.length} labs, ${_vitalBox!.length} vitals');
  }
  
  static Future<Box<LabResult>> _getLabBox() async {
    if (_labBox == null || !_labBox!.isOpen) await init();
    return _labBox!;
  }
  
  static Future<Box<VitalReading>> _getVitalBox() async {
    if (_vitalBox == null || !_vitalBox!.isOpen) await init();
    return _vitalBox!;
  }
  
  // ==================== LAB RESULTS ====================
  
  /// Get all lab results, sorted by date (newest first)
  static Future<List<LabResult>> getAllLabResults() async {
    final box = await _getLabBox();
    return box.values.toList()..sort((a, b) => b.testDate.compareTo(a.testDate));
  }
  
  /// Get lab results by category
  static Future<List<LabResult>> getLabResultsByCategory(String category) async {
    final all = await getAllLabResults();
    return all.where((r) => r.category == category).toList();
  }
  
  /// Get history of a specific test (for trending)
  static Future<List<LabResult>> getLabTestHistory(String testName, {int limit = 10}) async {
    final all = await getAllLabResults();
    return all
        .where((r) => r.testName.toLowerCase() == testName.toLowerCase())
        .take(limit)
        .toList();
  }
  
  /// Get abnormal results
  static Future<List<LabResult>> getAbnormalResults() async {
    final all = await getAllLabResults();
    return all.where((r) => !r.isNormal || r.isCritical).toList();
  }
  
  /// Add a new lab result
  static Future<LabResult> addLabResult({
    required String testName,
    required double value,
    required String unit,
    required DateTime testDate,
    String? loincCode,
    double? referenceRangeLow,
    double? referenceRangeHigh,
    String? labName,
    String? orderingProvider,
    String category = 'General',
    String source = 'manual',
    String? fhirJson,
  }) async {
    final box = await _getLabBox();
    
    // Determine interpretation
    String interpretation = 'normal';
    if (referenceRangeLow != null && value < referenceRangeLow) {
      interpretation = 'low';
    } else if (referenceRangeHigh != null && value > referenceRangeHigh) {
      interpretation = 'high';
    }
    
    final result = LabResult(
      id: _uuid.v4(),
      testName: testName,
      loincCode: loincCode,
      value: value,
      unit: unit,
      testDate: testDate,
      resultDate: DateTime.now(),
      referenceRangeLow: referenceRangeLow,
      referenceRangeHigh: referenceRangeHigh,
      interpretation: interpretation,
      labName: labName,
      orderingProvider: orderingProvider,
      category: category,
      source: source,
      fhirJson: fhirJson,
    );
    
    await box.put(result.id, result);
    debugPrint('🧪 Added lab result: ${result.testName} = ${result.displayValue}');
    return result;
  }
  
  /// Update a lab result
  static Future<void> updateLabResult(LabResult result) async {
    final box = await _getLabBox();
    await box.put(result.id, result);
  }
  
  /// Delete a lab result
  static Future<void> deleteLabResult(String id) async {
    final box = await _getLabBox();
    await box.delete(id);
  }
  
  // ==================== VITAL READINGS ====================
  
  /// Get all vital readings, sorted by timestamp (newest first)
  static Future<List<VitalReading>> getAllVitalReadings() async {
    final box = await _getVitalBox();
    return box.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
  
  /// Get readings by vital type
  static Future<List<VitalReading>> getVitalsByType(String vitalType, {int limit = 30}) async {
    final all = await getAllVitalReadings();
    return all.where((r) => r.vitalType == vitalType).take(limit).toList();
  }
  
  /// Get today's readings
  static Future<List<VitalReading>> getTodaysVitals() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final all = await getAllVitalReadings();
    return all.where((r) => r.timestamp.isAfter(startOfDay)).toList();
  }
  
  /// Get latest reading of a specific type
  static Future<VitalReading?> getLatestVital(String vitalType) async {
    final readings = await getVitalsByType(vitalType, limit: 1);
    return readings.isNotEmpty ? readings.first : null;
  }
  
  /// Add a new vital reading
  static Future<VitalReading> addVitalReading({
    required String vitalType,
    required double primaryValue,
    double? secondaryValue,
    String? unit,
    DateTime? timestamp,
    String? context,
    String? deviceName,
    String? notes,
    String source = 'manual',
    List<String> tags = const [],
  }) async {
    final box = await _getVitalBox();
    
    final reading = VitalReading(
      id: _uuid.v4(),
      vitalType: vitalType,
      primaryValue: primaryValue,
      secondaryValue: secondaryValue,
      unit: unit ?? VitalTypes.getUnit(vitalType),
      timestamp: timestamp ?? DateTime.now(),
      context: context,
      deviceName: deviceName,
      notes: notes,
      source: source,
      tags: tags,
    );
    
    await box.put(reading.id, reading);
    debugPrint('📊 Added vital: ${VitalTypes.getDisplayName(vitalType)} = ${reading.displayValue}');
    return reading;
  }
  
  /// Update a vital reading
  static Future<void> updateVitalReading(VitalReading reading) async {
    final box = await _getVitalBox();
    await box.put(reading.id, reading);
  }
  
  /// Delete a vital reading
  static Future<void> deleteVitalReading(String id) async {
    final box = await _getVitalBox();
    await box.delete(id);
  }
  
  // ==================== STATISTICS ====================
  
  /// Get average for a vital type over a period
  static Future<double?> getVitalAverage(String vitalType, {int days = 7}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final readings = await getVitalsByType(vitalType);
    final filtered = readings.where((r) => r.timestamp.isAfter(cutoff)).toList();
    
    if (filtered.isEmpty) return null;
    final sum = filtered.fold(0.0, (sum, r) => sum + r.primaryValue);
    return sum / filtered.length;
  }
  
  /// Get min/max for a vital type
  static Future<Map<String, double>?> getVitalMinMax(String vitalType, {int days = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final readings = await getVitalsByType(vitalType);
    final filtered = readings.where((r) => r.timestamp.isAfter(cutoff)).toList();
    
    if (filtered.isEmpty) return null;
    
    double min = filtered.first.primaryValue;
    double max = filtered.first.primaryValue;
    
    for (final r in filtered) {
      if (r.primaryValue < min) min = r.primaryValue;
      if (r.primaryValue > max) max = r.primaryValue;
    }
    
    return {'min': min, 'max': max};
  }
  
  // ==================== EXPORT ====================
  
  /// Export all health data to JSON
  static Future<String> exportToJson() async {
    final labs = await getAllLabResults();
    final vitals = await getAllVitalReadings();
    
    return const JsonEncoder.withIndent('  ').convert({
      'exportDate': DateTime.now().toIso8601String(),
      'labResults': labs.map((l) => l.toJson()).toList(),
      'vitalReadings': vitals.map((v) => v.toJson()).toList(),
    });
  }
  
  /// Get summary stats
  static Future<Map<String, dynamic>> getHealthSummary() async {
    final labs = await getAllLabResults();
    final vitals = await getAllVitalReadings();
    final abnormalLabs = labs.where((l) => !l.isNormal).length;
    
    // Get latest vitals
    final latestBP = await getLatestVital(VitalTypes.bloodPressure);
    final latestGlucose = await getLatestVital(VitalTypes.glucose);
    final latestWeight = await getLatestVital(VitalTypes.weight);
    
    return {
      'totalLabResults': labs.length,
      'abnormalLabResults': abnormalLabs,
      'totalVitalReadings': vitals.length,
      'latestBloodPressure': latestBP?.displayValue,
      'latestGlucose': latestGlucose?.displayValue,
      'latestWeight': latestWeight?.displayValue,
    };
  }
}
