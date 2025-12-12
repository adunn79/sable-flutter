import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/lab_result.dart';
import '../models/vital_reading.dart';

/// Service for OCR scanning and parsing medical documents
/// 
/// Extracts structured data from:
/// - Lab report images
/// - Vital signs records
/// - Medical summaries
class MedicalDocumentService {
  static final TextRecognizer _textRecognizer = TextRecognizer();
  
  /// Scan a lab report image and extract structured data
  static Future<LabReportScanResult> scanLabReport(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await _textRecognizer.processImage(inputImage);
      
      final rawText = recognized.text;
      debugPrint('📄 Scanned ${rawText.length} characters from lab report');
      
      // Parse the recognized text into structured lab results
      final results = _parseLabResults(rawText);
      
      return LabReportScanResult(
        success: results.isNotEmpty,
        rawText: rawText,
        labResults: results,
        labName: _extractLabName(rawText),
        testDate: _extractDate(rawText),
        patientName: _extractPatientInfo(rawText),
      );
    } catch (e) {
      debugPrint('❌ Lab report scan error: $e');
      return LabReportScanResult(
        success: false,
        rawText: '',
        labResults: [],
        errorMessage: e.toString(),
      );
    }
  }
  
  /// Scan a vital signs record
  static Future<VitalScanResult> scanVitalRecord(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await _textRecognizer.processImage(inputImage);
      
      final rawText = recognized.text;
      final readings = _parseVitalReadings(rawText);
      
      return VitalScanResult(
        success: readings.isNotEmpty,
        rawText: rawText,
        vitalReadings: readings,
        recordDate: _extractDate(rawText),
      );
    } catch (e) {
      debugPrint('❌ Vital record scan error: $e');
      return VitalScanResult(
        success: false,
        rawText: '',
        vitalReadings: [],
        errorMessage: e.toString(),
      );
    }
  }
  
  /// Parse lab results from raw OCR text
  static List<ParsedLabResult> _parseLabResults(String text) {
    final results = <ParsedLabResult>[];
    final lines = text.split('\n');
    
    // Common lab test patterns
    final patterns = {
      // Diabetes
      'hba1c|hemoglobin a1c|glycated hemoglobin': (m, v) => ParsedLabResult(
        testName: 'Hemoglobin A1c',
        value: v,
        unit: '%',
        referenceRange: '4.0 - 5.6',
        category: LabCategories.diabetes,
      ),
      'glucose|blood sugar': (m, v) => ParsedLabResult(
        testName: m.contains('fast') ? 'Fasting Glucose' : 'Blood Glucose',
        value: v,
        unit: 'mg/dL',
        referenceRange: '70 - 100',
        category: LabCategories.diabetes,
      ),
      
      // Lipid Panel
      'total cholesterol': (m, v) => ParsedLabResult(
        testName: 'Total Cholesterol',
        value: v,
        unit: 'mg/dL',
        referenceRange: '< 200',
        category: LabCategories.lipidPanel,
      ),
      'ldl': (m, v) => ParsedLabResult(
        testName: 'LDL Cholesterol',
        value: v,
        unit: 'mg/dL',
        referenceRange: '< 100',
        category: LabCategories.lipidPanel,
      ),
      'hdl': (m, v) => ParsedLabResult(
        testName: 'HDL Cholesterol',
        value: v,
        unit: 'mg/dL',
        referenceRange: '> 40',
        category: LabCategories.lipidPanel,
      ),
      'triglycerides': (m, v) => ParsedLabResult(
        testName: 'Triglycerides',
        value: v,
        unit: 'mg/dL',
        referenceRange: '< 150',
        category: LabCategories.lipidPanel,
      ),
      
      // Kidney
      'creatinine(?!.*clear)': (m, v) => ParsedLabResult(
        testName: 'Creatinine',
        value: v,
        unit: 'mg/dL',
        referenceRange: '0.7 - 1.3',
        category: LabCategories.kidney,
      ),
      'egfr|gfr': (m, v) => ParsedLabResult(
        testName: 'eGFR',
        value: v,
        unit: 'mL/min/1.73m²',
        referenceRange: '> 90',
        category: LabCategories.kidney,
      ),
      'bun|blood urea nitrogen': (m, v) => ParsedLabResult(
        testName: 'BUN',
        value: v,
        unit: 'mg/dL',
        referenceRange: '7 - 20',
        category: LabCategories.kidney,
      ),
      
      // Thyroid
      'tsh': (m, v) => ParsedLabResult(
        testName: 'TSH',
        value: v,
        unit: 'mIU/L',
        referenceRange: '0.4 - 4.0',
        category: LabCategories.thyroid,
      ),
      
      // Hematology
      'hemoglobin(?!.*a1c)': (m, v) => ParsedLabResult(
        testName: 'Hemoglobin',
        value: v,
        unit: 'g/dL',
        referenceRange: '12.0 - 17.5',
        category: LabCategories.hematology,
      ),
      'wbc|white blood': (m, v) => ParsedLabResult(
        testName: 'White Blood Cells',
        value: v,
        unit: 'K/uL',
        referenceRange: '4.5 - 11.0',
        category: LabCategories.hematology,
      ),
      'platelets': (m, v) => ParsedLabResult(
        testName: 'Platelets',
        value: v,
        unit: 'K/uL',
        referenceRange: '150 - 400',
        category: LabCategories.hematology,
      ),
    };
    
    // Value extraction pattern
    final valuePattern = RegExp(r'(\d+\.?\d*)\s*(mg/dl|g/dl|%|k/ul|miu/l|ml/min)?', caseSensitive: false);
    
    for (final line in lines) {
      final lowerLine = line.toLowerCase();
      
      for (final entry in patterns.entries) {
        final testPattern = RegExp(entry.key, caseSensitive: false);
        if (testPattern.hasMatch(lowerLine)) {
          final valueMatch = valuePattern.firstMatch(line);
          if (valueMatch != null) {
            final value = double.tryParse(valueMatch.group(1) ?? '');
            if (value != null) {
              results.add(entry.value(lowerLine, value));
            }
          }
        }
      }
    }
    
    return results;
  }
  
  /// Parse vital signs from raw OCR text
  static List<ParsedVitalReading> _parseVitalReadings(String text) {
    final readings = <ParsedVitalReading>[];
    final lowerText = text.toLowerCase();
    
    // Blood Pressure pattern: 120/80, 120/80 mmHg
    final bpPattern = RegExp(r'(\d{2,3})\s*/\s*(\d{2,3})\s*(mmhg)?');
    final bpMatches = bpPattern.allMatches(lowerText);
    for (final match in bpMatches) {
      final systolic = int.tryParse(match.group(1) ?? '');
      final diastolic = int.tryParse(match.group(2) ?? '');
      if (systolic != null && diastolic != null && 
          systolic >= 60 && systolic <= 250 &&
          diastolic >= 40 && diastolic <= 150) {
        readings.add(ParsedVitalReading(
          vitalType: VitalTypes.bloodPressure,
          primaryValue: systolic.toDouble(),
          secondaryValue: diastolic.toDouble(),
          unit: 'mmHg',
        ));
        break; // Take first valid reading
      }
    }
    
    // Heart Rate pattern
    final hrPattern = RegExp(r'(?:pulse|heart\s*rate|hr)\s*:?\s*(\d{2,3})\s*(?:bpm)?');
    final hrMatch = hrPattern.firstMatch(lowerText);
    if (hrMatch != null) {
      final hr = int.tryParse(hrMatch.group(1) ?? '');
      if (hr != null && hr >= 30 && hr <= 220) {
        readings.add(ParsedVitalReading(
          vitalType: VitalTypes.heartRate,
          primaryValue: hr.toDouble(),
          unit: 'bpm',
        ));
      }
    }
    
    // Weight pattern
    final weightPattern = RegExp(r'weight\s*:?\s*(\d{2,3}\.?\d*)\s*(lbs?|kg)?');
    final weightMatch = weightPattern.firstMatch(lowerText);
    if (weightMatch != null) {
      var weight = double.tryParse(weightMatch.group(1) ?? '');
      if (weight != null) {
        // Convert kg to lbs if needed
        if (weightMatch.group(2)?.toLowerCase().contains('kg') == true) {
          weight = weight * 2.20462;
        }
        if (weight >= 50 && weight <= 500) {
          readings.add(ParsedVitalReading(
            vitalType: VitalTypes.weight,
            primaryValue: weight,
            unit: 'lbs',
          ));
        }
      }
    }
    
    // SpO2 pattern
    final spo2Pattern = RegExp(r'(?:spo2|oxygen|o2\s*sat)\s*:?\s*(\d{2,3})\s*%?');
    final spo2Match = spo2Pattern.firstMatch(lowerText);
    if (spo2Match != null) {
      final spo2 = int.tryParse(spo2Match.group(1) ?? '');
      if (spo2 != null && spo2 >= 70 && spo2 <= 100) {
        readings.add(ParsedVitalReading(
          vitalType: VitalTypes.oxygenSaturation,
          primaryValue: spo2.toDouble(),
          unit: '%',
        ));
      }
    }
    
    return readings;
  }
  
  /// Extract lab/facility name
  static String? _extractLabName(String text) {
    final patterns = [
      RegExp(r'(?:lab(?:oratory)?|quest|labcorp|hospital|medical center)[:\s]*([^\n]+)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0)?.trim();
      }
    }
    return null;
  }
  
  /// Extract date from document
  static DateTime? _extractDate(String text) {
    // Common date patterns
    final patterns = [
      RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})'),
      RegExp(r'(\d{1,2})-(\d{1,2})-(\d{2,4})'),
      RegExp(r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{1,2}),?\s+(\d{4})', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          if (match.groupCount >= 3) {
            final m = int.tryParse(match.group(1) ?? '');
            final d = int.tryParse(match.group(2) ?? '');
            var y = int.tryParse(match.group(3) ?? '');
            if (m != null && d != null && y != null) {
              if (y < 100) y += 2000;
              return DateTime(y, m, d);
            }
          }
        } catch (_) {}
      }
    }
    return null;
  }
  
  /// Extract patient info
  static String? _extractPatientInfo(String text) {
    final pattern = RegExp(r'(?:patient|name)[:\s]*([a-z]+\s+[a-z]+)', caseSensitive: false);
    final match = pattern.firstMatch(text);
    return match?.group(1)?.trim();
  }
  
  /// Clean up resources
  static void dispose() {
    _textRecognizer.close();
  }
}

/// Result of scanning a lab report
class LabReportScanResult {
  final bool success;
  final String rawText;
  final List<ParsedLabResult> labResults;
  final String? labName;
  final DateTime? testDate;
  final String? patientName;
  final String? errorMessage;
  
  const LabReportScanResult({
    required this.success,
    required this.rawText,
    required this.labResults,
    this.labName,
    this.testDate,
    this.patientName,
    this.errorMessage,
  });
}

/// Parsed lab result from OCR
class ParsedLabResult {
  final String testName;
  final double value;
  final String unit;
  final String? referenceRange;
  final String category;
  
  const ParsedLabResult({
    required this.testName,
    required this.value,
    required this.unit,
    this.referenceRange,
    this.category = 'General',
  });
}

/// Result of scanning vital signs
class VitalScanResult {
  final bool success;
  final String rawText;
  final List<ParsedVitalReading> vitalReadings;
  final DateTime? recordDate;
  final String? errorMessage;
  
  const VitalScanResult({
    required this.success,
    required this.rawText,
    required this.vitalReadings,
    this.recordDate,
    this.errorMessage,
  });
}

/// Parsed vital reading from OCR
class ParsedVitalReading {
  final String vitalType;
  final double primaryValue;
  final double? secondaryValue;
  final String unit;
  
  const ParsedVitalReading({
    required this.vitalType,
    required this.primaryValue,
    this.secondaryValue,
    required this.unit,
  });
}
