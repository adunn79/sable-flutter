// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HealthEntryAdapter extends TypeAdapter<HealthEntry> {
  @override
  final int typeId = 14;

  @override
  HealthEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HealthEntry(
      id: fields[0] as String,
      type: fields[1] as HealthEntryType,
      content: fields[2] as String,
      timestamp: fields[3] as DateTime,
      moodScore: fields[4] as int?,
      tags: (fields[5] as List).cast<String>(),
      isConfidential: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HealthEntry obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.moodScore)
      ..writeByte(5)
      ..write(obj.tags)
      ..writeByte(6)
      ..write(obj.isConfidential);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HealthEntryTypeAdapter extends TypeAdapter<HealthEntryType> {
  @override
  final int typeId = 13;

  @override
  HealthEntryType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HealthEntryType.mood;
      case 1:
        return HealthEntryType.counseling;
      case 2:
        return HealthEntryType.medication;
      case 3:
        return HealthEntryType.symptom;
      case 4:
        return HealthEntryType.therapy;
      case 5:
        return HealthEntryType.crisis;
      case 6:
        return HealthEntryType.achievement;
      default:
        return HealthEntryType.mood;
    }
  }

  @override
  void write(BinaryWriter writer, HealthEntryType obj) {
    switch (obj) {
      case HealthEntryType.mood:
        writer.writeByte(0);
        break;
      case HealthEntryType.counseling:
        writer.writeByte(1);
        break;
      case HealthEntryType.medication:
        writer.writeByte(2);
        break;
      case HealthEntryType.symptom:
        writer.writeByte(3);
        break;
      case HealthEntryType.therapy:
        writer.writeByte(4);
        break;
      case HealthEntryType.crisis:
        writer.writeByte(5);
        break;
      case HealthEntryType.achievement:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthEntryTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
