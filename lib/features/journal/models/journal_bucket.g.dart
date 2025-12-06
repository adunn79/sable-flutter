// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_bucket.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class JournalBucketAdapter extends TypeAdapter<JournalBucket> {
  @override
  final int typeId = 1;

  @override
  JournalBucket read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JournalBucket(
      id: fields[0] as String,
      name: fields[1] as String,
      icon: fields[2] as String,
      colorValue: fields[3] as int,
      isVault: fields[4] as bool,
      avatarAccessDefault: fields[5] as bool,
      createdAt: fields[6] as DateTime?,
      entryCount: fields[7] as int,
      sortOrder: fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, JournalBucket obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.icon)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.isVault)
      ..writeByte(5)
      ..write(obj.avatarAccessDefault)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.entryCount)
      ..writeByte(8)
      ..write(obj.sortOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalBucketAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
