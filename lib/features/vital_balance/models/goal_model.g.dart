// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GoalCheckInAdapter extends TypeAdapter<GoalCheckIn> {
  @override
  final int typeId = 21;

  @override
  GoalCheckIn read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GoalCheckIn(
      date: fields[0] as DateTime,
      note: fields[1] as String,
      progressUpdate: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, GoalCheckIn obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.note)
      ..writeByte(2)
      ..write(obj.progressUpdate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalCheckInAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GoalAdapter extends TypeAdapter<Goal> {
  @override
  final int typeId = 22;

  @override
  Goal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Goal(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      createdAt: fields[3] as DateTime,
      targetDate: fields[4] as DateTime,
      status: fields[5] as GoalStatus,
      progressPercent: fields[6] as int,
      checkIns: (fields[7] as List?)?.cast<GoalCheckIn>(),
      aiTip: fields[8] as String?,
      lastCheckInReminder: fields[9] as DateTime?,
      checkInFrequencyDays: fields[10] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Goal obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.targetDate)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.progressPercent)
      ..writeByte(7)
      ..write(obj.checkIns)
      ..writeByte(8)
      ..write(obj.aiTip)
      ..writeByte(9)
      ..write(obj.lastCheckInReminder)
      ..writeByte(10)
      ..write(obj.checkInFrequencyDays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GoalStatusAdapter extends TypeAdapter<GoalStatus> {
  @override
  final int typeId = 20;

  @override
  GoalStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return GoalStatus.active;
      case 1:
        return GoalStatus.completed;
      case 2:
        return GoalStatus.abandoned;
      default:
        return GoalStatus.active;
    }
  }

  @override
  void write(BinaryWriter writer, GoalStatus obj) {
    switch (obj) {
      case GoalStatus.active:
        writer.writeByte(0);
        break;
      case GoalStatus.completed:
        writer.writeByte(1);
        break;
      case GoalStatus.abandoned:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
