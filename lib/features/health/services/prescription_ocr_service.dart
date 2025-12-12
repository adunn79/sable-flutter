import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import '../models/prescription.dart';

/// OCR Service for scanning prescription labels
/// 
/// Uses Google ML Kit for on-device text recognition.
/// All processing happens locally - images are never uploaded.
class PrescriptionOcrService {
  static final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  
  /// Extract prescription data from image
  static Future<PrescriptionScanResult> scanPrescriptionLabel(
    Uint8List imageBytes,
  ) async {
    try {
      // Create input image from bytes
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: const Size(1920, 1080), // Will be adjusted by ML Kit
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: 1920 * 4,
        ),
      );
      
      // Perform text recognition
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      debugPrint('📷 OCR found ${recognizedText.blocks.length} text blocks');
      
      // Extract all text
      final fullText = recognizedText.text;
      final lines = fullText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      
      // Parse prescription fields from recognized text
      return _parseRecognizedText(lines, fullText);
    } catch (e) {
      debugPrint('❌ OCR Error: $e');
      return PrescriptionScanResult(
        success: false,
        errorMessage: 'Failed to scan label: $e',
      );
    }
  }
  
  /// Parse recognized text to extract prescription fields
  static PrescriptionScanResult _parseRecognizedText(
    List<String> lines,
    String fullText,
  ) {
    String? medicationName;
    String? strength;
    String? directions;
    String? pharmacyName;
    String? pharmacyAddress;
    String? pharmacyPhone;
    String? rxNumber;
    String? prescriberName;
    String? ndcNumber;
    int? refillsRemaining;
    int? quantityDispensed;
    DateTime? dateFilled;
    
    final lowerText = fullText.toLowerCase();
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lowerLine = line.toLowerCase();
      
      // Extract Rx Number
      if (lowerLine.contains('rx') || lowerLine.contains('rx#') || lowerLine.contains('rx:')) {
        final rxMatch = RegExp(r'rx[#:\s]*(\d+)', caseSensitive: false).firstMatch(line);
        if (rxMatch != null) {
          rxNumber = rxMatch.group(1);
        }
      }
      
      // Extract Phone Number
      final phoneMatch = RegExp(r'\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}').firstMatch(line);
      if (phoneMatch != null && pharmacyPhone == null) {
        pharmacyPhone = phoneMatch.group(0);
      }
      
      // Extract NDC Number (10-digit format: ####-####-## or ##########)
      final ndcMatch = RegExp(r'\d{4,5}-\d{3,4}-\d{1,2}|\b\d{10,11}\b').firstMatch(line);
      if (ndcMatch != null && lowerLine.contains('ndc')) {
        ndcNumber = ndcMatch.group(0);
      }
      
      // Extract Quantity
      if (lowerLine.contains('qty') || lowerLine.contains('quantity')) {
        final qtyMatch = RegExp(r'qty[:\s]*(\d+)', caseSensitive: false).firstMatch(line);
        if (qtyMatch != null) {
          quantityDispensed = int.tryParse(qtyMatch.group(1)!);
        }
      }
      
      // Extract Refills
      if (lowerLine.contains('refill')) {
        final refillMatch = RegExp(r'refill[s]?[:\s]*(\d+)', caseSensitive: false).firstMatch(line);
        if (refillMatch != null) {
          refillsRemaining = int.tryParse(refillMatch.group(1)!);
        }
      }
      
      // Extract Date (MM/DD/YYYY or MM-DD-YYYY)
      final dateMatch = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})').firstMatch(line);
      if (dateMatch != null && dateFilled == null) {
        final month = int.tryParse(dateMatch.group(1)!);
        final day = int.tryParse(dateMatch.group(2)!);
        var year = int.tryParse(dateMatch.group(3)!);
        if (month != null && day != null && year != null) {
          if (year < 100) year += 2000;
          dateFilled = DateTime(year, month, day);
        }
      }
      
      // Extract Directions (usually starts with "Take", "Use", "Apply")
      if (lowerLine.startsWith('take ') || 
          lowerLine.startsWith('use ') || 
          lowerLine.startsWith('apply ') ||
          lowerLine.startsWith('inject ') ||
          lowerLine.startsWith('inhale ')) {
        directions = line;
      }
      
      // Extract Doctor/Prescriber (look for "Dr." or "MD" or "Prescriber")
      if (lowerLine.contains('dr.') || 
          lowerLine.contains('m.d.') || 
          lowerLine.contains('md') ||
          lowerLine.contains('prescriber')) {
        final drMatch = RegExp(r'(?:dr\.?\s*|prescriber[:\s]*)?([A-Za-z\s]+(?:M\.?D\.?)?)', caseSensitive: false).firstMatch(line);
        if (drMatch != null) {
          prescriberName = drMatch.group(1)?.trim();
        }
      }
      
      // Extract Pharmacy Name (usually first few lines, often in caps)
      if (i < 3 && pharmacyName == null) {
        if (lowerLine.contains('pharmacy') || 
            lowerLine.contains('walgreens') || 
            lowerLine.contains('cvs') ||
            lowerLine.contains('rite aid') ||
            lowerLine.contains('costco') ||
            lowerLine.contains('walmart')) {
          pharmacyName = line;
        }
      }
    }
    
    // Try to find medication name (usually the largest/boldest text, often in caps)
    // Heuristic: look for drug-like names (ends in common suffixes)
    final drugSuffixes = ['in', 'ol', 'ide', 'ate', 'ine', 'one', 'am', 'il', 'an', 'um'];
    for (final line in lines) {
      if (medicationName != null) break;
      
      final words = line.split(RegExp(r'\s+'));
      for (final word in words) {
        final cleanWord = word.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
        if (cleanWord.length > 4) {
          for (final suffix in drugSuffixes) {
            if (cleanWord.endsWith(suffix)) {
              medicationName = word;
              
              // Try to find strength next to medication name
              final strengthMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(mg|mcg|ml|g|%)', caseSensitive: false).firstMatch(line);
              if (strengthMatch != null) {
                strength = strengthMatch.group(0);
              }
              break;
            }
          }
        }
      }
    }
    
    // If no medication found, try first capitalized word that's not pharmacy
    if (medicationName == null) {
      for (final line in lines.skip(2)) { // Skip first 2 lines (usually pharmacy)
        final words = line.split(RegExp(r'\s+'));
        for (final word in words) {
          if (word.length > 3 && word == word.toUpperCase() && !RegExp(r'\d').hasMatch(word)) {
            medicationName = word;
            break;
          }
        }
        if (medicationName != null) break;
      }
    }
    
    return PrescriptionScanResult(
      success: true,
      medicationName: medicationName,
      strength: strength,
      directions: directions,
      pharmacyName: pharmacyName,
      pharmacyAddress: pharmacyAddress,
      pharmacyPhone: pharmacyPhone,
      rxNumber: rxNumber,
      ndcNumber: ndcNumber,
      prescriberName: prescriberName,
      refillsRemaining: refillsRemaining,
      quantityDispensed: quantityDispensed,
      dateFilled: dateFilled,
      rawText: fullText,
    );
  }
  
  /// Scan from file path
  static Future<PrescriptionScanResult> scanFromFile(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      return scanPrescriptionLabel(bytes);
    } catch (e) {
      return PrescriptionScanResult(
        success: false,
        errorMessage: 'Failed to read image file: $e',
      );
    }
  }
  
  /// Clean up resources
  static void dispose() {
    _textRecognizer.close();
  }
}

/// Result from scanning a prescription label
class PrescriptionScanResult {
  final bool success;
  final String? errorMessage;
  
  // Extracted fields
  final String? medicationName;
  final String? strength;
  final String? directions;
  final String? pharmacyName;
  final String? pharmacyAddress;
  final String? pharmacyPhone;
  final String? rxNumber;
  final String? ndcNumber;
  final String? prescriberName;
  final int? refillsRemaining;
  final int? quantityDispensed;
  final DateTime? dateFilled;
  
  // Raw OCR output for user review
  final String? rawText;
  
  const PrescriptionScanResult({
    required this.success,
    this.errorMessage,
    this.medicationName,
    this.strength,
    this.directions,
    this.pharmacyName,
    this.pharmacyAddress,
    this.pharmacyPhone,
    this.rxNumber,
    this.ndcNumber,
    this.prescriberName,
    this.refillsRemaining,
    this.quantityDispensed,
    this.dateFilled,
    this.rawText,
  });
  
  /// Check if we got useful data
  bool get hasData => medicationName != null || directions != null || pharmacyName != null;
  
  /// Convert to prescription (user should verify/edit before saving)
  Prescription toPrescription({required String id}) {
    return Prescription(
      id: id,
      medicationName: medicationName ?? 'Unknown Medication',
      strength: strength ?? '',
      directions: directions ?? '',
      pharmacyName: pharmacyName,
      pharmacyAddress: pharmacyAddress,
      pharmacyPhone: pharmacyPhone,
      rxNumber: rxNumber,
      ndcNumber: ndcNumber,
      prescriberName: prescriberName,
      refillsRemaining: refillsRemaining ?? 0,
      quantityDispensed: quantityDispensed,
      dateFilled: dateFilled,
    );
  }
}
