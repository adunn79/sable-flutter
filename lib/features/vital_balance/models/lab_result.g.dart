// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lab_result.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LabResultAdapter extends TypeAdapter<LabResult> {
  @override
  final int typeId = 31;

  @override
  LabResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LabResult(
      id: fields[0] as String,
      testName: fields[1] as String,
      loincCode: fields[2] as String?,
      value: fields[3] as double,
      unit: fields[4] as String,
      referenceRangeLow: fields[5] as double?,
      referenceRangeHigh: fields[6] as double?,
      interpretation: fields[7] as String,
      testDate: fields[8] as DateTime,
      resultDate: fields[9] as DateTime?,
      labName: fields[10] as String?,
      orderingProvider: fields[11] as String?,
      category: fields[12] as String,
      providerNotes: fields[13] as String?,
      userNotes: fields[14] as String?,
      source: fields[15] as String,
      fhirJson: fields[16] as String?,
      createdAt: fields[17] as DateTime?,
      updatedAt: fields[18] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, LabResult obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.testName)
      ..writeByte(2)
      ..write(obj.loincCode)
      ..writeByte(3)
      ..write(obj.value)
      ..writeByte(4)
      ..write(obj.unit)
      ..writeByte(5)
      ..write(obj.referenceRangeLow)
      ..writeByte(6)
      ..write(obj.referenceRangeHigh)
      ..writeByte(7)
      ..write(obj.interpretation)
      ..writeByte(8)
      ..write(obj.testDate)
      ..writeByte(9)
      ..write(obj.resultDate)
      ..writeByte(10)
      ..write(obj.labName)
      ..writeByte(11)
      ..write(obj.orderingProvider)
      ..writeByte(12)
      ..write(obj.category)
      ..writeByte(13)
      ..write(obj.providerNotes)
      ..writeByte(14)
      ..write(obj.userNotes)
      ..writeByte(15)
      ..write(obj.source)
      ..writeByte(16)
      ..write(obj.fhirJson)
      ..writeByte(17)
      ..write(obj.createdAt)
      ..writeByte(18)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
