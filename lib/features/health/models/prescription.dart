import 'package:hive/hive.dart';

part 'prescription.g.dart';

/// Represents a prescription medication captured from bottle label
/// 
/// All data is stored locally on device with encryption.
/// Never synced to cloud - user controls sharing via PDF export.
@HiveType(typeId: 30)
class Prescription extends HiveObject {
  /// Unique identifier
  @HiveField(0)
  final String id;
  
  // ==================== MEDICATION INFO ====================
  
  /// Generic medication name (e.g., "Metformin HCL")
  @HiveField(1)
  String medicationName;
  
  /// Brand name if applicable (e.g., "Glucophage")
  @HiveField(2)
  String? brandName;
  
  /// Strength/dosage (e.g., "500mg", "10mg/5ml")
  @HiveField(3)
  String strength;
  
  /// Form of medication
  @HiveField(4)
  String dosageForm; // Tablet, Capsule, Liquid, Injection, etc.
  
  // ==================== PHARMACY INFO ====================
  
  /// Pharmacy name (e.g., "CVS Pharmacy #4521")
  @HiveField(5)
  String? pharmacyName;
  
  /// Pharmacy street address
  @HiveField(6)
  String? pharmacyAddress;
  
  /// Pharmacy phone number
  @HiveField(7)
  String? pharmacyPhone;
  
  /// Prescription/Rx number
  @HiveField(8)
  String? rxNumber;
  
  /// National Drug Code (NDC) - 10-digit unique identifier
  @HiveField(9)
  String? ndcNumber;
  
  // ==================== PRESCRIBER INFO ====================
  
  /// Prescribing doctor's name
  @HiveField(10)
  String? prescriberName;
  
  /// DEA number (for controlled substances)
  @HiveField(11)
  String? prescriberDEA;
  
  // ==================== DIRECTIONS ====================
  
  /// Directions for use (e.g., "Take 1 tablet twice daily")
  @HiveField(12)
  String directions;
  
  /// Special instructions (e.g., "Take with food")
  @HiveField(13)
  String? specialInstructions;
  
  /// Warning labels (e.g., "May cause drowsiness")
  @HiveField(14)
  List<String> warnings;
  
  // ==================== DATES ====================
  
  /// Date prescription was filled
  @HiveField(15)
  DateTime? dateFilled;
  
  /// Expiration/Beyond-use date
  @HiveField(16)
  DateTime? expirationDate;
  
  /// Number of refills remaining
  @HiveField(17)
  int refillsRemaining;
  
  /// Date of last refill
  @HiveField(18)
  DateTime? lastRefillDate;
  
  // ==================== QUANTITY ====================
  
  /// Quantity dispensed
  @HiveField(19)
  int? quantityDispensed;
  
  /// Days supply
  @HiveField(20)
  int? daysSupply;
  
  // ==================== USER DATA ====================
  
  /// User's personal notes
  @HiveField(21)
  String? notes;
  
  /// Is reminder enabled for this medication
  @HiveField(22)
  bool reminderEnabled;
  
  /// Scheduled times for doses (hour and minute stored as ISO strings)
  @HiveField(23)
  List<String> scheduledTimes;
  
  /// Is this medication currently active (being taken)
  @HiveField(24)
  bool isActive;
  
  /// Photo of the label (base64 encoded, optional)
  @HiveField(25)
  String? labelPhotoBase64;
  
  /// Date this record was created
  @HiveField(26)
  DateTime createdAt;
  
  /// Date this record was last updated
  @HiveField(27)
  DateTime updatedAt;
  
  Prescription({
    required this.id,
    required this.medicationName,
    this.brandName,
    required this.strength,
    this.dosageForm = 'Tablet',
    this.pharmacyName,
    this.pharmacyAddress,
    this.pharmacyPhone,
    this.rxNumber,
    this.ndcNumber,
    this.prescriberName,
    this.prescriberDEA,
    required this.directions,
    this.specialInstructions,
    this.warnings = const [],
    this.dateFilled,
    this.expirationDate,
    this.refillsRemaining = 0,
    this.lastRefillDate,
    this.quantityDispensed,
    this.daysSupply,
    this.notes,
    this.reminderEnabled = false,
    this.scheduledTimes = const [],
    this.isActive = true,
    this.labelPhotoBase64,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
  
  /// Create a copy with updated fields
  Prescription copyWith({
    String? id,
    String? medicationName,
    String? brandName,
    String? strength,
    String? dosageForm,
    String? pharmacyName,
    String? pharmacyAddress,
    String? pharmacyPhone,
    String? rxNumber,
    String? ndcNumber,
    String? prescriberName,
    String? prescriberDEA,
    String? directions,
    String? specialInstructions,
    List<String>? warnings,
    DateTime? dateFilled,
    DateTime? expirationDate,
    int? refillsRemaining,
    DateTime? lastRefillDate,
    int? quantityDispensed,
    int? daysSupply,
    String? notes,
    bool? reminderEnabled,
    List<String>? scheduledTimes,
    bool? isActive,
    String? labelPhotoBase64,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Prescription(
      id: id ?? this.id,
      medicationName: medicationName ?? this.medicationName,
      brandName: brandName ?? this.brandName,
      strength: strength ?? this.strength,
      dosageForm: dosageForm ?? this.dosageForm,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      pharmacyAddress: pharmacyAddress ?? this.pharmacyAddress,
      pharmacyPhone: pharmacyPhone ?? this.pharmacyPhone,
      rxNumber: rxNumber ?? this.rxNumber,
      ndcNumber: ndcNumber ?? this.ndcNumber,
      prescriberName: prescriberName ?? this.prescriberName,
      prescriberDEA: prescriberDEA ?? this.prescriberDEA,
      directions: directions ?? this.directions,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      warnings: warnings ?? this.warnings,
      dateFilled: dateFilled ?? this.dateFilled,
      expirationDate: expirationDate ?? this.expirationDate,
      refillsRemaining: refillsRemaining ?? this.refillsRemaining,
      lastRefillDate: lastRefillDate ?? this.lastRefillDate,
      quantityDispensed: quantityDispensed ?? this.quantityDispensed,
      daysSupply: daysSupply ?? this.daysSupply,
      notes: notes ?? this.notes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      scheduledTimes: scheduledTimes ?? this.scheduledTimes,
      isActive: isActive ?? this.isActive,
      labelPhotoBase64: labelPhotoBase64 ?? this.labelPhotoBase64,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
  
  /// Display name (brand name if available, otherwise generic)
  String get displayName => brandName ?? medicationName;
  
  /// Full description (name + strength)
  String get fullDescription => '$displayName $strength';
  
  /// Check if prescription is expired
  bool get isExpired {
    if (expirationDate == null) return false;
    return DateTime.now().isAfter(expirationDate!);
  }
  
  /// Check if refill is needed soon (within 7 days of running out)
  bool get needsRefillSoon {
    if (daysSupply == null || dateFilled == null) return false;
    final runOutDate = dateFilled!.add(Duration(days: daysSupply!));
    final warningDate = runOutDate.subtract(const Duration(days: 7));
    return DateTime.now().isAfter(warningDate) && !isExpired;
  }
  
  /// Days until medication runs out
  int? get daysUntilEmpty {
    if (daysSupply == null || dateFilled == null) return null;
    final runOutDate = dateFilled!.add(Duration(days: daysSupply!));
    return runOutDate.difference(DateTime.now()).inDays;
  }
  
  /// Convert to JSON for export
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicationName': medicationName,
      'brandName': brandName,
      'strength': strength,
      'dosageForm': dosageForm,
      'pharmacyName': pharmacyName,
      'pharmacyAddress': pharmacyAddress,
      'pharmacyPhone': pharmacyPhone,
      'rxNumber': rxNumber,
      'ndcNumber': ndcNumber,
      'prescriberName': prescriberName,
      'directions': directions,
      'specialInstructions': specialInstructions,
      'warnings': warnings,
      'dateFilled': dateFilled?.toIso8601String(),
      'expirationDate': expirationDate?.toIso8601String(),
      'refillsRemaining': refillsRemaining,
      'quantityDispensed': quantityDispensed,
      'daysSupply': daysSupply,
      'notes': notes,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Dosage form options
class DosageForms {
  static const tablet = 'Tablet';
  static const capsule = 'Capsule';
  static const liquid = 'Liquid';
  static const injection = 'Injection';
  static const cream = 'Cream';
  static const ointment = 'Ointment';
  static const patch = 'Patch';
  static const drops = 'Drops';
  static const inhaler = 'Inhaler';
  static const spray = 'Spray';
  static const suppository = 'Suppository';
  static const powder = 'Powder';
  
  static const List<String> all = [
    tablet, capsule, liquid, injection, cream,
    ointment, patch, drops, inhaler, spray,
    suppository, powder,
  ];
}
