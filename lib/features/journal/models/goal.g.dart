// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GoalAdapter extends TypeAdapter<Goal> {
  @override
  final int typeId = 10;

  @override
  Goal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Goal(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String?,
      category: fields[3] as GoalCategory,
      createdAt: fields[4] as DateTime,
      targetDate: fields[5] as DateTime?,
      isCompleted: fields[6] as bool,
      completedAt: fields[7] as DateTime?,
      milestones: (fields[8] as List).cast<Milestone>(),
      linkedEntryIds: (fields[9] as List).cast<String>(),
      progressPercent: fields[10] as int,
      whyItMatters: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Goal obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.targetDate)
      ..writeByte(6)
      ..write(obj.isCompleted)
      ..writeByte(7)
      ..write(obj.completedAt)
      ..writeByte(8)
      ..write(obj.milestones)
      ..writeByte(9)
      ..write(obj.linkedEntryIds)
      ..writeByte(10)
      ..write(obj.progressPercent)
      ..writeByte(11)
      ..write(obj.whyItMatters);
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

class MilestoneAdapter extends TypeAdapter<Milestone> {
  @override
  final int typeId = 12;

  @override
  Milestone read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Milestone(
      id: fields[0] as String,
      title: fields[1] as String,
      isCompleted: fields[2] as bool,
      completedAt: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Milestone obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.isCompleted)
      ..writeByte(3)
      ..write(obj.completedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MilestoneAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GoalCategoryAdapter extends TypeAdapter<GoalCategory> {
  @override
  final int typeId = 11;

  @override
  GoalCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return GoalCategory.health;
      case 1:
        return GoalCategory.career;
      case 2:
        return GoalCategory.relationships;
      case 3:
        return GoalCategory.personal;
      case 4:
        return GoalCategory.hobbies;
      case 5:
        return GoalCategory.financial;
      default:
        return GoalCategory.health;
    }
  }

  @override
  void write(BinaryWriter writer, GoalCategory obj) {
    switch (obj) {
      case GoalCategory.health:
        writer.writeByte(0);
        break;
      case GoalCategory.career:
        writer.writeByte(1);
        break;
      case GoalCategory.relationships:
        writer.writeByte(2);
        break;
      case GoalCategory.personal:
        writer.writeByte(3);
        break;
      case GoalCategory.hobbies:
        writer.writeByte(4);
        break;
      case GoalCategory.financial:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
