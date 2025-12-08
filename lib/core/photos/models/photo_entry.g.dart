// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PhotoEntryAdapter extends TypeAdapter<PhotoEntry> {
  @override
  final int typeId = 60;

  @override
  PhotoEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PhotoEntry(
      id: fields[0] as String,
      originalPath: fields[1] as String,
      privatePath: fields[2] as String?,
      thumbnailPath: fields[3] as String?,
      isPrivate: fields[4] as bool,
      createdAt: fields[5] as DateTime,
      takenAt: fields[6] as DateTime?,
      location: fields[7] as String?,
      caption: fields[8] as String?,
      tags: (fields[9] as List?)?.cast<String>(),
      linkedJournalId: fields[10] as String?,
      aiDescription: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PhotoEntry obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.originalPath)
      ..writeByte(2)
      ..write(obj.privatePath)
      ..writeByte(3)
      ..write(obj.thumbnailPath)
      ..writeByte(4)
      ..write(obj.isPrivate)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.takenAt)
      ..writeByte(7)
      ..write(obj.location)
      ..writeByte(8)
      ..write(obj.caption)
      ..writeByte(9)
      ..write(obj.tags)
      ..writeByte(10)
      ..write(obj.linkedJournalId)
      ..writeByte(11)
      ..write(obj.aiDescription);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
