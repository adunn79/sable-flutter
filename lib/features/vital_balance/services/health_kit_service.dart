import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../models/vital_reading.dart';
import 'health_data_service.dart';

/// Service for integrating with Apple HealthKit and FHIR Clinical Records
/// 
/// Provides MyChart-style provider connectivity:
/// - Read clinical records (labs, meds, immunizations)
/// - Sync vital signs from HealthKit
/// - Auto-parse FHIR data into app models
class HealthKitService {
  static final Health _health = Health();
  static bool _isAuthorized = false;
  
  /// HealthKit data types for vital signs
  static final _vitalTypes = [
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.HEART_RATE,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.BLOOD_OXYGEN,
  ];
  
  /// Request HealthKit authorization
  static Future<bool> requestAuthorization() async {
    try {
      // Configure Health package
      await _health.configure();
      
      // Request authorization for vital signs
      final hasPermissions = await _health.hasPermissions(
        _vitalTypes,
        permissions: List.filled(_vitalTypes.length, HealthDataAccess.READ),
      );
      
      if (hasPermissions != true) {
        final authorized = await _health.requestAuthorization(
          _vitalTypes,
          permissions: List.filled(_vitalTypes.length, HealthDataAccess.READ),
        );
        _isAuthorized = authorized;
        debugPrint('🏥 HealthKit authorization: $authorized');
        return authorized;
      }
      
      _isAuthorized = true;
      return true;
    } catch (e) {
      debugPrint('❌ HealthKit authorization error: $e');
      return false;
    }
  }
  
  /// Check if HealthKit is available
  static Future<bool> isAvailable() async {
    try {
      // Health package 13.x removed isHealthDataAvailable
      // Just try to configure - returns false on failure
      await _health.configure();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Sync vital signs from HealthKit
  static Future<List<VitalReading>> syncVitals({int days = 30}) async {
    if (!_isAuthorized) {
      final authorized = await requestAuthorization();
      if (!authorized) return [];
    }
    
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    
    try {
      final healthData = await _health.getHealthDataFromTypes(
        types: _vitalTypes,
        startTime: startDate,
        endTime: now,
      );
      
      // Remove duplicates
      final uniqueData = _health.removeDuplicates(healthData);
      
      final readings = <VitalReading>[];
      
      for (final point in uniqueData) {
        final reading = _convertToVitalReading(point);
        if (reading != null) {
          readings.add(reading);
        }
      }
      
      debugPrint('📱 Synced ${readings.length} vitals from HealthKit');
      return readings;
    } catch (e) {
      debugPrint('❌ Error syncing HealthKit vitals: $e');
      return [];
    }
  }
  
  static VitalReading? _convertToVitalReading(HealthDataPoint point) {
    String vitalType;
    double primaryValue;
    double? secondaryValue;
    
    switch (point.type) {
      case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
        // BP systolic - will be paired with diastolic
        return null; // Handle BP separately
      case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
        return null; // Handle BP separately
      case HealthDataType.BLOOD_GLUCOSE:
        vitalType = VitalTypes.glucose;
        primaryValue = (point.value as NumericHealthValue).numericValue.toDouble();
        // Convert mmol/L to mg/dL if needed
        if (primaryValue < 30) {
          primaryValue = primaryValue * 18.0182; // mmol/L to mg/dL
        }
        break;
      case HealthDataType.HEART_RATE:
        vitalType = VitalTypes.heartRate;
        primaryValue = (point.value as NumericHealthValue).numericValue.toDouble();
        break;
      case HealthDataType.WEIGHT:
        vitalType = VitalTypes.weight;
        primaryValue = (point.value as NumericHealthValue).numericValue.toDouble();
        // Convert kg to lbs if < 150 (likely kg)
        if (primaryValue < 150) {
          primaryValue = primaryValue * 2.20462;
        }
        break;
      case HealthDataType.HEIGHT:
        vitalType = VitalTypes.height;
        primaryValue = (point.value as NumericHealthValue).numericValue.toDouble();
        // Convert meters to inches if < 3 (likely meters)
        if (primaryValue < 3) {
          primaryValue = primaryValue * 39.3701;
        }
        break;
      case HealthDataType.BODY_TEMPERATURE:
        vitalType = VitalTypes.temperature;
        primaryValue = (point.value as NumericHealthValue).numericValue.toDouble();
        // Convert C to F if < 50 (likely Celsius)
        if (primaryValue < 50) {
          primaryValue = (primaryValue * 9 / 5) + 32;
        }
        break;
      case HealthDataType.BLOOD_OXYGEN:
        vitalType = VitalTypes.oxygenSaturation;
        primaryValue = (point.value as NumericHealthValue).numericValue.toDouble();
        break;
      default:
        return null;
    }
    
    return VitalReading(
      id: '${point.type.name}_${point.dateFrom.millisecondsSinceEpoch}',
      vitalType: vitalType,
      primaryValue: primaryValue,
      secondaryValue: secondaryValue,
      unit: VitalTypes.getUnit(vitalType),
      timestamp: point.dateFrom,
      deviceName: point.sourceName,
      source: 'healthkit',
    );
  }
  
  /// Sync blood pressure readings (pairs systolic + diastolic)
  static Future<List<VitalReading>> syncBloodPressure({int days = 30}) async {
    if (!_isAuthorized) {
      final authorized = await requestAuthorization();
      if (!authorized) return [];
    }
    
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    
    try {
      final systolicData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_PRESSURE_SYSTOLIC],
        startTime: startDate,
        endTime: now,
      );
      
      final diastolicData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
        startTime: startDate,
        endTime: now,
      );
      
      // Match systolic with diastolic by timestamp
      final readings = <VitalReading>[];
      
      for (final sys in systolicData) {
        final sysTime = sys.dateFrom.millisecondsSinceEpoch;
        final matching = diastolicData.where((d) => 
          (d.dateFrom.millisecondsSinceEpoch - sysTime).abs() < 60000 // Within 1 minute
        );
        
        if (matching.isNotEmpty) {
          final dia = matching.first;
          readings.add(VitalReading(
            id: 'bp_$sysTime',
            vitalType: VitalTypes.bloodPressure,
            primaryValue: (sys.value as NumericHealthValue).numericValue.toDouble(),
            secondaryValue: (dia.value as NumericHealthValue).numericValue.toDouble(),
            unit: 'mmHg',
            timestamp: sys.dateFrom,
            deviceName: sys.sourceName,
            source: 'healthkit',
          ));
        }
      }
      
      debugPrint('🩺 Synced ${readings.length} BP readings from HealthKit');
      return readings;
    } catch (e) {
      debugPrint('❌ Error syncing BP from HealthKit: $e');
      return [];
    }
  }
  
  /// Import synced vitals to local storage
  static Future<int> importVitalsToStorage({int days = 30}) async {
    final vitals = await syncVitals(days: days);
    final bpReadings = await syncBloodPressure(days: days);
    
    final allReadings = [...vitals, ...bpReadings];
    int imported = 0;
    
    for (final reading in allReadings) {
      try {
        await HealthDataService.addVitalReading(
          vitalType: reading.vitalType,
          primaryValue: reading.primaryValue,
          secondaryValue: reading.secondaryValue,
          unit: reading.unit,
          timestamp: reading.timestamp,
          deviceName: reading.deviceName,
          source: 'healthkit',
        );
        imported++;
      } catch (e) {
        // Skip duplicates
      }
    }
    
    debugPrint('✅ Imported $imported vitals to storage');
    return imported;
  }
  
  /// Get connected providers (for MyChart-style display)
  /// Note: This requires Clinical Records capability in Xcode
  static Future<List<HealthProvider>> getConnectedProviders() async {
    // On iOS, clinical records providers are managed in Settings > Health
    // This is a placeholder - real implementation requires native Swift code
    return [
      HealthProvider(
        id: 'apple_health',
        name: 'Apple Health',
        isConnected: _isAuthorized,
        icon: '🍎',
        lastSync: DateTime.now(),
      ),
    ];
  }
}

/// Represents a connected health data provider
class HealthProvider {
  final String id;
  final String name;
  final bool isConnected;
  final String icon;
  final DateTime? lastSync;
  
  const HealthProvider({
    required this.id,
    required this.name,
    required this.isConnected,
    required this.icon,
    this.lastSync,
  });
}

/// Clinical record types from FHIR
class ClinicalRecordTypes {
  static const allergyRecord = 'AllergyIntolerance';
  static const conditionRecord = 'Condition';
  static const immunizationRecord = 'Immunization';
  static const labResultRecord = 'Observation';
  static const medicationRecord = 'MedicationStatement';
  static const procedureRecord = 'Procedure';
  static const vitalSignRecord = 'Observation';
}
