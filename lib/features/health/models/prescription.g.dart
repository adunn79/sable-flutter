// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prescription.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PrescriptionAdapter extends TypeAdapter<Prescription> {
  @override
  final int typeId = 30;

  @override
  Prescription read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Prescription(
      id: fields[0] as String,
      medicationName: fields[1] as String,
      brandName: fields[2] as String?,
      strength: fields[3] as String,
      dosageForm: fields[4] as String,
      pharmacyName: fields[5] as String?,
      pharmacyAddress: fields[6] as String?,
      pharmacyPhone: fields[7] as String?,
      rxNumber: fields[8] as String?,
      ndcNumber: fields[9] as String?,
      prescriberName: fields[10] as String?,
      prescriberDEA: fields[11] as String?,
      directions: fields[12] as String,
      specialInstructions: fields[13] as String?,
      warnings: (fields[14] as List).cast<String>(),
      dateFilled: fields[15] as DateTime?,
      expirationDate: fields[16] as DateTime?,
      refillsRemaining: fields[17] as int,
      lastRefillDate: fields[18] as DateTime?,
      quantityDispensed: fields[19] as int?,
      daysSupply: fields[20] as int?,
      notes: fields[21] as String?,
      reminderEnabled: fields[22] as bool,
      scheduledTimes: (fields[23] as List).cast<String>(),
      isActive: fields[24] as bool,
      labelPhotoBase64: fields[25] as String?,
      createdAt: fields[26] as DateTime?,
      updatedAt: fields[27] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Prescription obj) {
    writer
      ..writeByte(28)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.medicationName)
      ..writeByte(2)
      ..write(obj.brandName)
      ..writeByte(3)
      ..write(obj.strength)
      ..writeByte(4)
      ..write(obj.dosageForm)
      ..writeByte(5)
      ..write(obj.pharmacyName)
      ..writeByte(6)
      ..write(obj.pharmacyAddress)
      ..writeByte(7)
      ..write(obj.pharmacyPhone)
      ..writeByte(8)
      ..write(obj.rxNumber)
      ..writeByte(9)
      ..write(obj.ndcNumber)
      ..writeByte(10)
      ..write(obj.prescriberName)
      ..writeByte(11)
      ..write(obj.prescriberDEA)
      ..writeByte(12)
      ..write(obj.directions)
      ..writeByte(13)
      ..write(obj.specialInstructions)
      ..writeByte(14)
      ..write(obj.warnings)
      ..writeByte(15)
      ..write(obj.dateFilled)
      ..writeByte(16)
      ..write(obj.expirationDate)
      ..writeByte(17)
      ..write(obj.refillsRemaining)
      ..writeByte(18)
      ..write(obj.lastRefillDate)
      ..writeByte(19)
      ..write(obj.quantityDispensed)
      ..writeByte(20)
      ..write(obj.daysSupply)
      ..writeByte(21)
      ..write(obj.notes)
      ..writeByte(22)
      ..write(obj.reminderEnabled)
      ..writeByte(23)
      ..write(obj.scheduledTimes)
      ..writeByte(24)
      ..write(obj.isActive)
      ..writeByte(25)
      ..write(obj.labelPhotoBase64)
      ..writeByte(26)
      ..write(obj.createdAt)
      ..writeByte(27)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrescriptionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
