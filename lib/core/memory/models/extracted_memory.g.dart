// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'extracted_memory.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExtractedMemoryAdapter extends TypeAdapter<ExtractedMemory> {
  @override
  final int typeId = 12;

  @override
  ExtractedMemory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExtractedMemory(
      id: fields[0] as String,
      content: fields[1] as String,
      category: fields[2] as MemoryCategory,
      extractedAt: fields[3] as DateTime,
      sourceMessageId: fields[4] as String?,
      tags: (fields[5] as List).cast<String>(),
      importance: fields[6] as int,
      locationName: fields[7] as String?,
      latitude: fields[8] as double?,
      longitude: fields[9] as double?,
      weather: fields[10] as String?,
      energyLevel: fields[11] as int?,
      vibeColor: fields[12] as String?,
      ambientDescription: fields[13] as String?,
      taggedPeople: (fields[14] as List).cast<String>(),
      isGroupActivity: fields[15] as bool,
      nowPlayingTrack: fields[16] as String?,
      nowPlayingService: fields[17] as String?,
      attachedPhotoPaths: (fields[18] as List).cast<String>(),
      topHeadline: fields[19] as String?,
      onThisDay: fields[20] as String?,
      sleepHours: fields[21] as int?,
      stepCount: fields[22] as int?,
      oneSentenceSummary: fields[23] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ExtractedMemory obj) {
    writer
      ..writeByte(24)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.content)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.extractedAt)
      ..writeByte(4)
      ..write(obj.sourceMessageId)
      ..writeByte(5)
      ..write(obj.tags)
      ..writeByte(6)
      ..write(obj.importance)
      ..writeByte(7)
      ..write(obj.locationName)
      ..writeByte(8)
      ..write(obj.latitude)
      ..writeByte(9)
      ..write(obj.longitude)
      ..writeByte(10)
      ..write(obj.weather)
      ..writeByte(11)
      ..write(obj.energyLevel)
      ..writeByte(12)
      ..write(obj.vibeColor)
      ..writeByte(13)
      ..write(obj.ambientDescription)
      ..writeByte(14)
      ..write(obj.taggedPeople)
      ..writeByte(15)
      ..write(obj.isGroupActivity)
      ..writeByte(16)
      ..write(obj.nowPlayingTrack)
      ..writeByte(17)
      ..write(obj.nowPlayingService)
      ..writeByte(18)
      ..write(obj.attachedPhotoPaths)
      ..writeByte(19)
      ..write(obj.topHeadline)
      ..writeByte(20)
      ..write(obj.onThisDay)
      ..writeByte(21)
      ..write(obj.sleepHours)
      ..writeByte(22)
      ..write(obj.stepCount)
      ..writeByte(23)
      ..write(obj.oneSentenceSummary);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractedMemoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MemoryCategoryAdapter extends TypeAdapter<MemoryCategory> {
  @override
  final int typeId = 11;

  @override
  MemoryCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MemoryCategory.people;
      case 1:
        return MemoryCategory.preferences;
      case 2:
        return MemoryCategory.dates;
      case 3:
        return MemoryCategory.life;
      case 4:
        return MemoryCategory.emotional;
      case 5:
        return MemoryCategory.goals;
      case 6:
        return MemoryCategory.misc;
      default:
        return MemoryCategory.people;
    }
  }

  @override
  void write(BinaryWriter writer, MemoryCategory obj) {
    switch (obj) {
      case MemoryCategory.people:
        writer.writeByte(0);
        break;
      case MemoryCategory.preferences:
        writer.writeByte(1);
        break;
      case MemoryCategory.dates:
        writer.writeByte(2);
        break;
      case MemoryCategory.life:
        writer.writeByte(3);
        break;
      case MemoryCategory.emotional:
        writer.writeByte(4);
        break;
      case MemoryCategory.goals:
        writer.writeByte(5);
        break;
      case MemoryCategory.misc:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
