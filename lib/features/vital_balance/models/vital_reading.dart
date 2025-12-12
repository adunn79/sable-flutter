import 'package:hive/hive.dart';

part 'vital_reading.g.dart';

/// Represents a vital sign reading (BP, glucose, weight, etc.)
/// 
/// Designed for tracking the "Big 3" chronic conditions:
/// - Diabetes (glucose)
/// - Hypertension (blood pressure)
/// - Heart Disease (heart rate, BP, cholesterol)
@HiveType(typeId: 32)
class VitalReading extends HiveObject {
  @HiveField(0)
  final String id;
  
  /// Type of vital sign
  @HiveField(1)
  String vitalType; // blood_pressure, glucose, weight, heart_rate, etc.
  
  /// Primary value (systolic for BP, glucose level, weight)
  @HiveField(2)
  double primaryValue;
  
  /// Secondary value (diastolic for BP, null for others)
  @HiveField(3)
  double? secondaryValue;
  
  /// Unit of measurement
  @HiveField(4)
  String unit;
  
  /// When the reading was taken
  @HiveField(5)
  DateTime timestamp;
  
  /// Context (fasting, post-meal, resting, etc.)
  @HiveField(6)
  String? context;
  
  /// Device used for measurement (if any)
  @HiveField(7)
  String? deviceName;
  
  /// User notes
  @HiveField(8)
  String? notes;
  
  /// Source (manual, healthkit, device_sync)
  @HiveField(9)
  String source;
  
  /// Target/goal value if set
  @HiveField(10)
  double? targetValue;
  
  /// Tags for filtering
  @HiveField(11)
  List<String> tags;
  
  @HiveField(12)
  DateTime createdAt;
  
  VitalReading({
    required this.id,
    required this.vitalType,
    required this.primaryValue,
    this.secondaryValue,
    required this.unit,
    required this.timestamp,
    this.context,
    this.deviceName,
    this.notes,
    this.source = 'manual',
    this.targetValue,
    this.tags = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  
  /// Display value based on type
  String get displayValue {
    if (vitalType == VitalTypes.bloodPressure && secondaryValue != null) {
      return '${primaryValue.toInt()}/${secondaryValue!.toInt()} $unit';
    }
    final formatted = primaryValue.truncateToDouble() == primaryValue 
        ? primaryValue.toInt().toString() 
        : primaryValue.toStringAsFixed(1);
    return '$formatted $unit';
  }
  
  /// Get status color category based on value
  String get status {
    switch (vitalType) {
      case VitalTypes.bloodPressure:
        return _getBloodPressureStatus();
      case VitalTypes.glucose:
        return _getGlucoseStatus();
      case VitalTypes.heartRate:
        return _getHeartRateStatus();
      default:
        return 'normal';
    }
  }
  
  String _getBloodPressureStatus() {
    final systolic = primaryValue;
    final diastolic = secondaryValue ?? 80;
    
    if (systolic >= 180 || diastolic >= 120) return 'critical';
    if (systolic >= 140 || diastolic >= 90) return 'high';
    if (systolic >= 130 || diastolic >= 80) return 'elevated';
    if (systolic < 90 || diastolic < 60) return 'low';
    return 'normal';
  }
  
  String _getGlucoseStatus() {
    final isFasting = context?.toLowerCase().contains('fasting') ?? false;
    
    if (primaryValue < 54) return 'critical';
    if (primaryValue < 70) return 'low';
    if (isFasting) {
      if (primaryValue > 125) return 'high';
      if (primaryValue > 100) return 'elevated';
    } else {
      if (primaryValue > 200) return 'high';
      if (primaryValue > 140) return 'elevated';
    }
    return 'normal';
  }
  
  String _getHeartRateStatus() {
    if (primaryValue < 40 || primaryValue > 180) return 'critical';
    if (primaryValue < 50 || primaryValue > 100) return 'elevated';
    return 'normal';
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'vitalType': vitalType,
    'primaryValue': primaryValue,
    'secondaryValue': secondaryValue,
    'unit': unit,
    'timestamp': timestamp.toIso8601String(),
    'context': context,
    'deviceName': deviceName,
    'notes': notes,
    'source': source,
    'tags': tags,
  };
  
  VitalReading copyWith({
    String? id,
    String? vitalType,
    double? primaryValue,
    double? secondaryValue,
    String? unit,
    DateTime? timestamp,
    String? context,
    String? deviceName,
    String? notes,
    String? source,
    double? targetValue,
    List<String>? tags,
  }) {
    return VitalReading(
      id: id ?? this.id,
      vitalType: vitalType ?? this.vitalType,
      primaryValue: primaryValue ?? this.primaryValue,
      secondaryValue: secondaryValue ?? this.secondaryValue,
      unit: unit ?? this.unit,
      timestamp: timestamp ?? this.timestamp,
      context: context ?? this.context,
      deviceName: deviceName ?? this.deviceName,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      targetValue: targetValue ?? this.targetValue,
      tags: tags ?? this.tags,
      createdAt: createdAt,
    );
  }
}

/// Vital sign types
class VitalTypes {
  static const bloodPressure = 'blood_pressure';
  static const glucose = 'glucose';
  static const heartRate = 'heart_rate';
  static const weight = 'weight';
  static const height = 'height';
  static const temperature = 'temperature';
  static const oxygenSaturation = 'oxygen_saturation';
  static const respiratoryRate = 'respiratory_rate';
  
  static const List<String> all = [
    bloodPressure, glucose, heartRate, weight,
    height, temperature, oxygenSaturation, respiratoryRate,
  ];
  
  static String getDisplayName(String type) {
    switch (type) {
      case bloodPressure: return 'Blood Pressure';
      case glucose: return 'Blood Glucose';
      case heartRate: return 'Heart Rate';
      case weight: return 'Weight';
      case height: return 'Height';
      case temperature: return 'Temperature';
      case oxygenSaturation: return 'SpO2';
      case respiratoryRate: return 'Respiratory Rate';
      default: return type;
    }
  }
  
  static String getUnit(String type) {
    switch (type) {
      case bloodPressure: return 'mmHg';
      case glucose: return 'mg/dL';
      case heartRate: return 'bpm';
      case weight: return 'lbs';
      case height: return 'in';
      case temperature: return '°F';
      case oxygenSaturation: return '%';
      case respiratoryRate: return '/min';
      default: return '';
    }
  }
  
  static String getIcon(String type) {
    switch (type) {
      case bloodPressure: return '❤️';
      case glucose: return '🩸';
      case heartRate: return '💓';
      case weight: return '⚖️';
      case height: return '📏';
      case temperature: return '🌡️';
      case oxygenSaturation: return '🫁';
      case respiratoryRate: return '💨';
      default: return '📊';
    }
  }
}

/// Glucose reading contexts
class GlucoseContext {
  static const fasting = 'Fasting';
  static const beforeMeal = 'Before Meal';
  static const afterMeal = 'After Meal (2h)';
  static const bedtime = 'Bedtime';
  static const random = 'Random';
  
  static const List<String> all = [fasting, beforeMeal, afterMeal, bedtime, random];
}

/// Blood pressure reading positions
class BpContext {
  static const sitting = 'Sitting';
  static const standing = 'Standing';
  static const lying = 'Lying Down';
  static const leftArm = 'Left Arm';
  static const rightArm = 'Right Arm';
  
  static const List<String> all = [sitting, standing, lying, leftArm, rightArm];
}
