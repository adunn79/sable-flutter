import 'package:hive/hive.dart';

part 'lab_result.g.dart';

/// Represents a single lab test result
/// 
/// Designed to match FHIR Observation resource structure for interoperability
@HiveType(typeId: 31)
class LabResult extends HiveObject {
  @HiveField(0)
  final String id;
  
  /// Test name (e.g., "Hemoglobin A1c", "LDL Cholesterol")
  @HiveField(1)
  String testName;
  
  /// LOINC code for standardization (e.g., "4548-4" for HbA1c)
  @HiveField(2)
  String? loincCode;
  
  /// Numeric value
  @HiveField(3)
  double value;
  
  /// Unit of measurement (e.g., "%", "mg/dL", "mmol/L")
  @HiveField(4)
  String unit;
  
  /// Reference range low
  @HiveField(5)
  double? referenceRangeLow;
  
  /// Reference range high
  @HiveField(6)
  double? referenceRangeHigh;
  
  /// Interpretation (normal, high, low, critical)
  @HiveField(7)
  String interpretation;
  
  /// Date the test was performed
  @HiveField(8)
  DateTime testDate;
  
  /// Date result was received
  @HiveField(9)
  DateTime? resultDate;
  
  /// Lab/facility that performed the test
  @HiveField(10)
  String? labName;
  
  /// Ordering provider
  @HiveField(11)
  String? orderingProvider;
  
  /// Category (e.g., "Chemistry", "Hematology", "Lipid Panel")
  @HiveField(12)
  String category;
  
  /// Notes from provider
  @HiveField(13)
  String? providerNotes;
  
  /// User's personal notes
  @HiveField(14)
  String? userNotes;
  
  /// Source of data (manual, ocr, fhir_sync)
  @HiveField(15)
  String source;
  
  /// Raw FHIR JSON if synced from provider
  @HiveField(16)
  String? fhirJson;
  
  @HiveField(17)
  DateTime createdAt;
  
  @HiveField(18)
  DateTime updatedAt;
  
  LabResult({
    required this.id,
    required this.testName,
    this.loincCode,
    required this.value,
    required this.unit,
    this.referenceRangeLow,
    this.referenceRangeHigh,
    this.interpretation = 'normal',
    required this.testDate,
    this.resultDate,
    this.labName,
    this.orderingProvider,
    this.category = 'General',
    this.providerNotes,
    this.userNotes,
    this.source = 'manual',
    this.fhirJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
  
  /// Check if value is within normal range
  bool get isNormal {
    if (referenceRangeLow != null && value < referenceRangeLow!) return false;
    if (referenceRangeHigh != null && value > referenceRangeHigh!) return false;
    return true;
  }
  
  /// Check if value is critically abnormal
  bool get isCritical => interpretation == 'critical';
  
  /// Get display range string
  String get referenceRangeDisplay {
    if (referenceRangeLow != null && referenceRangeHigh != null) {
      return '${referenceRangeLow!.toStringAsFixed(1)} - ${referenceRangeHigh!.toStringAsFixed(1)} $unit';
    }
    if (referenceRangeLow != null) return '> ${referenceRangeLow!.toStringAsFixed(1)} $unit';
    if (referenceRangeHigh != null) return '< ${referenceRangeHigh!.toStringAsFixed(1)} $unit';
    return 'N/A';
  }
  
  /// Get formatted value with unit
  String get displayValue => '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)} $unit';
  
  /// Convert to JSON for export
  Map<String, dynamic> toJson() => {
    'id': id,
    'testName': testName,
    'loincCode': loincCode,
    'value': value,
    'unit': unit,
    'referenceRangeLow': referenceRangeLow,
    'referenceRangeHigh': referenceRangeHigh,
    'interpretation': interpretation,
    'testDate': testDate.toIso8601String(),
    'resultDate': resultDate?.toIso8601String(),
    'labName': labName,
    'orderingProvider': orderingProvider,
    'category': category,
    'source': source,
  };
  
  LabResult copyWith({
    String? id,
    String? testName,
    String? loincCode,
    double? value,
    String? unit,
    double? referenceRangeLow,
    double? referenceRangeHigh,
    String? interpretation,
    DateTime? testDate,
    DateTime? resultDate,
    String? labName,
    String? orderingProvider,
    String? category,
    String? providerNotes,
    String? userNotes,
    String? source,
    String? fhirJson,
  }) {
    return LabResult(
      id: id ?? this.id,
      testName: testName ?? this.testName,
      loincCode: loincCode ?? this.loincCode,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      referenceRangeLow: referenceRangeLow ?? this.referenceRangeLow,
      referenceRangeHigh: referenceRangeHigh ?? this.referenceRangeHigh,
      interpretation: interpretation ?? this.interpretation,
      testDate: testDate ?? this.testDate,
      resultDate: resultDate ?? this.resultDate,
      labName: labName ?? this.labName,
      orderingProvider: orderingProvider ?? this.orderingProvider,
      category: category ?? this.category,
      providerNotes: providerNotes ?? this.providerNotes,
      userNotes: userNotes ?? this.userNotes,
      source: source ?? this.source,
      fhirJson: fhirJson ?? this.fhirJson,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Common lab test categories
class LabCategories {
  static const chemistry = 'Chemistry';
  static const hematology = 'Hematology';
  static const lipidPanel = 'Lipid Panel';
  static const metabolicPanel = 'Metabolic Panel';
  static const thyroid = 'Thyroid';
  static const diabetes = 'Diabetes';
  static const liver = 'Liver Function';
  static const kidney = 'Kidney Function';
  static const cardiac = 'Cardiac Markers';
  static const urinalysis = 'Urinalysis';
  
  static const List<String> all = [
    chemistry, hematology, lipidPanel, metabolicPanel,
    thyroid, diabetes, liver, kidney, cardiac, urinalysis,
  ];
}

/// Common LOINC codes for frequently tracked tests
class CommonLabTests {
  /// Diabetes
  static const hemoglobinA1c = {'name': 'Hemoglobin A1c', 'loinc': '4548-4', 'unit': '%', 'low': 4.0, 'high': 5.6};
  static const fastingGlucose = {'name': 'Fasting Glucose', 'loinc': '1558-6', 'unit': 'mg/dL', 'low': 70.0, 'high': 100.0};
  
  /// Lipid Panel
  static const totalCholesterol = {'name': 'Total Cholesterol', 'loinc': '2093-3', 'unit': 'mg/dL', 'low': 0.0, 'high': 200.0};
  static const ldlCholesterol = {'name': 'LDL Cholesterol', 'loinc': '2089-1', 'unit': 'mg/dL', 'low': 0.0, 'high': 100.0};
  static const hdlCholesterol = {'name': 'HDL Cholesterol', 'loinc': '2085-9', 'unit': 'mg/dL', 'low': 40.0, 'high': 200.0};
  static const triglycerides = {'name': 'Triglycerides', 'loinc': '2571-8', 'unit': 'mg/dL', 'low': 0.0, 'high': 150.0};
  
  /// Kidney
  static const creatinine = {'name': 'Creatinine', 'loinc': '2160-0', 'unit': 'mg/dL', 'low': 0.7, 'high': 1.3};
  static const egfr = {'name': 'eGFR', 'loinc': '33914-3', 'unit': 'mL/min/1.73m²', 'low': 90.0, 'high': 999.0};
  
  /// Thyroid
  static const tsh = {'name': 'TSH', 'loinc': '3016-3', 'unit': 'mIU/L', 'low': 0.4, 'high': 4.0};
  
  /// Hematology
  static const hemoglobin = {'name': 'Hemoglobin', 'loinc': '718-7', 'unit': 'g/dL', 'low': 12.0, 'high': 17.5};
  static const wbc = {'name': 'White Blood Cells', 'loinc': '6690-2', 'unit': 'K/uL', 'low': 4.5, 'high': 11.0};
  static const platelets = {'name': 'Platelets', 'loinc': '777-3', 'unit': 'K/uL', 'low': 150.0, 'high': 400.0};
  
  static const List<Map<String, dynamic>> all = [
    hemoglobinA1c, fastingGlucose,
    totalCholesterol, ldlCholesterol, hdlCholesterol, triglycerides,
    creatinine, egfr, tsh,
    hemoglobin, wbc, platelets,
  ];
}
