// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vital_reading.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VitalReadingAdapter extends TypeAdapter<VitalReading> {
  @override
  final int typeId = 32;

  @override
  VitalReading read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VitalReading(
      id: fields[0] as String,
      vitalType: fields[1] as String,
      primaryValue: fields[2] as double,
      secondaryValue: fields[3] as double?,
      unit: fields[4] as String,
      timestamp: fields[5] as DateTime,
      context: fields[6] as String?,
      deviceName: fields[7] as String?,
      notes: fields[8] as String?,
      source: fields[9] as String,
      targetValue: fields[10] as double?,
      tags: (fields[11] as List).cast<String>(),
      createdAt: fields[12] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, VitalReading obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.vitalType)
      ..writeByte(2)
      ..write(obj.primaryValue)
      ..writeByte(3)
      ..write(obj.secondaryValue)
      ..writeByte(4)
      ..write(obj.unit)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.context)
      ..writeByte(7)
      ..write(obj.deviceName)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.source)
      ..writeByte(10)
      ..write(obj.targetValue)
      ..writeByte(11)
      ..write(obj.tags)
      ..writeByte(12)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VitalReadingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
