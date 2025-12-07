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
    );
  }

  @override
  void write(BinaryWriter writer, ExtractedMemory obj) {
    writer
      ..writeByte(7)
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
      ..write(obj.importance);
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
