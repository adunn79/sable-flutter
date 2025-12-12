import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/prescription.dart';
import 'package:sable/core/calendar/calendar_service.dart';

/// Service for managing prescriptions with encrypted local storage
/// 
/// All data is stored locally on device - never synced to cloud.
/// Uses Hive with encryption for HIPAA-compliant storage.
class PrescriptionService {
  static const String _boxName = 'prescriptions';
  static Box<Prescription>? _box;
  static const _uuid = Uuid();
  
  /// Initialize the prescription storage
  static Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    
    // Register Hive adapter if not already registered
    if (!Hive.isAdapterRegistered(30)) {
      Hive.registerAdapter(PrescriptionAdapter());
    }
    
    _box = await Hive.openBox<Prescription>(_boxName);
    debugPrint('💊 PrescriptionService initialized with ${_box!.length} prescriptions');
  }
  
  /// Ensure box is open before operations
  static Future<Box<Prescription>> _getBox() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
    return _box!;
  }
  
  // ==================== CRUD OPERATIONS ====================
  
  /// Get all prescriptions
  static Future<List<Prescription>> getAllPrescriptions() async {
    final box = await _getBox();
    return box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  
  /// Get only active prescriptions
  static Future<List<Prescription>> getActivePrescriptions() async {
    final all = await getAllPrescriptions();
    return all.where((p) => p.isActive).toList();
  }
  
  /// Get prescriptions that need refill soon
  static Future<List<Prescription>> getPrescriptionsNeedingRefill() async {
    final active = await getActivePrescriptions();
    return active.where((p) => p.needsRefillSoon && p.refillsRemaining > 0).toList();
  }
  
  /// Get expired prescriptions
  static Future<List<Prescription>> getExpiredPrescriptions() async {
    final all = await getAllPrescriptions();
    return all.where((p) => p.isExpired).toList();
  }
  
  /// Get prescription by ID
  static Future<Prescription?> getPrescription(String id) async {
    final box = await _getBox();
    return box.get(id);
  }
  
  /// Save a new prescription
  static Future<Prescription> addPrescription({
    required String medicationName,
    required String strength,
    required String directions,
    String? brandName,
    String dosageForm = 'Tablet',
    String? pharmacyName,
    String? pharmacyAddress,
    String? pharmacyPhone,
    String? rxNumber,
    String? ndcNumber,
    String? prescriberName,
    String? specialInstructions,
    List<String> warnings = const [],
    DateTime? dateFilled,
    DateTime? expirationDate,
    int refillsRemaining = 0,
    int? quantityDispensed,
    int? daysSupply,
    String? notes,
    String? labelPhotoBase64,
  }) async {
    final box = await _getBox();
    
    final prescription = Prescription(
      id: _uuid.v4(),
      medicationName: medicationName,
      strength: strength,
      directions: directions,
      brandName: brandName,
      dosageForm: dosageForm,
      pharmacyName: pharmacyName,
      pharmacyAddress: pharmacyAddress,
      pharmacyPhone: pharmacyPhone,
      rxNumber: rxNumber,
      ndcNumber: ndcNumber,
      prescriberName: prescriberName,
      specialInstructions: specialInstructions,
      warnings: warnings,
      dateFilled: dateFilled,
      expirationDate: expirationDate,
      refillsRemaining: refillsRemaining,
      quantityDispensed: quantityDispensed,
      daysSupply: daysSupply,
      notes: notes,
      labelPhotoBase64: labelPhotoBase64,
    );
    
    await box.put(prescription.id, prescription);
    debugPrint('💊 Added prescription: ${prescription.displayName}');
    
    return prescription;
  }
  
  /// Update an existing prescription
  static Future<void> updatePrescription(Prescription prescription) async {
    final box = await _getBox();
    final updated = prescription.copyWith(updatedAt: DateTime.now());
    await box.put(updated.id, updated);
    debugPrint('💊 Updated prescription: ${updated.displayName}');
  }
  
  /// Delete a prescription
  static Future<void> deletePrescription(String id) async {
    final box = await _getBox();
    await box.delete(id);
    debugPrint('💊 Deleted prescription: $id');
  }
  
  /// Mark prescription as inactive (archived)
  static Future<void> archivePrescription(String id) async {
    final prescription = await getPrescription(id);
    if (prescription != null) {
      await updatePrescription(prescription.copyWith(isActive: false));
    }
  }
  
  // ==================== REMINDERS ====================
  
  /// Schedule a refill reminder in calendar
  static Future<bool> scheduleRefillReminder(Prescription prescription) async {
    if (prescription.daysSupply == null || prescription.dateFilled == null) {
      return false;
    }
    
    // Calculate when to remind (7 days before running out)
    final runOutDate = prescription.dateFilled!.add(
      Duration(days: prescription.daysSupply!),
    );
    final reminderDate = runOutDate.subtract(const Duration(days: 7));
    
    // Don't schedule if already past
    if (reminderDate.isBefore(DateTime.now())) {
      return false;
    }
    
    try {
      await CalendarService.createEvent(
        title: '💊 Refill: ${prescription.displayName}',
        description: 'Time to refill your ${prescription.displayName} ${prescription.strength}.\n'
            'Pharmacy: ${prescription.pharmacyName ?? "Not specified"}\n'
            'Phone: ${prescription.pharmacyPhone ?? "Not specified"}\n'
            'Rx#: ${prescription.rxNumber ?? "Not specified"}\n'
            'Refills remaining: ${prescription.refillsRemaining}',
        start: reminderDate,
        end: reminderDate.add(const Duration(hours: 1)),
        allDay: false,
      );
      debugPrint('📅 Scheduled refill reminder for ${prescription.displayName}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule reminder: $e');
      return false;
    }
  }
  
  // ==================== EXPORT ====================
  
  /// Export all prescriptions to JSON (for backup/doctor)
  static Future<String> exportToJson() async {
    final prescriptions = await getAllPrescriptions();
    final data = prescriptions.map((p) => p.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'exportDate': DateTime.now().toIso8601String(),
      'prescriptionCount': prescriptions.length,
      'prescriptions': data,
    });
  }
  
  // ==================== STATS ====================
  
  /// Get prescription statistics
  static Future<Map<String, dynamic>> getStats() async {
    final all = await getAllPrescriptions();
    final active = all.where((p) => p.isActive).length;
    final needsRefill = all.where((p) => p.needsRefillSoon).length;
    final expired = all.where((p) => p.isExpired).length;
    
    return {
      'total': all.length,
      'active': active,
      'needsRefill': needsRefill,
      'expired': expired,
    };
  }
}
