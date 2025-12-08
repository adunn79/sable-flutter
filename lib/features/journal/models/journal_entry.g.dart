// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class JournalEntryAdapter extends TypeAdapter<JournalEntry> {
  @override
  final int typeId = 0;

  @override
  JournalEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JournalEntry(
      id: fields[0] as String,
      content: fields[1] as String,
      plainText: fields[2] as String,
      timestamp: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime?,
      bucketId: fields[5] as String,
      tags: (fields[6] as List).cast<String>(),
      moodScore: fields[7] as int?,
      isPrivate: fields[8] as bool,
      location: fields[9] as String?,
      latitude: fields[10] as double?,
      longitude: fields[11] as double?,
      weather: fields[12] as String?,
      mediaUrls: (fields[13] as List).cast<String>(),
      embeddingRef: fields[14] as String?,
      isSynced: fields[15] as bool,
      firestoreId: fields[16] as String?,
      isHidden: fields[17] as bool,
      stepCount: fields[18] as int?,
      nowPlayingTrack: fields[19] as String?,
      nowPlayingArtist: fields[20] as String?,
      weightLbs: fields[21] as double?,
      heartRate: fields[22] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, JournalEntry obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.content)
      ..writeByte(2)
      ..write(obj.plainText)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.bucketId)
      ..writeByte(6)
      ..write(obj.tags)
      ..writeByte(7)
      ..write(obj.moodScore)
      ..writeByte(8)
      ..write(obj.isPrivate)
      ..writeByte(9)
      ..write(obj.location)
      ..writeByte(10)
      ..write(obj.latitude)
      ..writeByte(11)
      ..write(obj.longitude)
      ..writeByte(12)
      ..write(obj.weather)
      ..writeByte(13)
      ..write(obj.mediaUrls)
      ..writeByte(14)
      ..write(obj.embeddingRef)
      ..writeByte(15)
      ..write(obj.isSynced)
      ..writeByte(16)
      ..write(obj.firestoreId)
      ..writeByte(17)
      ..write(obj.isHidden)
      ..writeByte(18)
      ..write(obj.stepCount)
      ..writeByte(19)
      ..write(obj.nowPlayingTrack)
      ..writeByte(20)
      ..write(obj.nowPlayingArtist)
      ..writeByte(21)
      ..write(obj.weightLbs)
      ..writeByte(22)
      ..write(obj.heartRate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
