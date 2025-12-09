// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'private_user_persona.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PrivateUserPersonaAdapter extends TypeAdapter<PrivateUserPersona> {
  @override
  final int typeId = 51;

  @override
  PrivateUserPersona read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrivateUserPersona(
      id: fields[0] as String,
      aliasName: fields[1] as String,
      aliasAge: fields[2] as int?,
      aliasGender: fields[3] as String?,
      aliasDescription: fields[4] as String?,
      aliasBackground: fields[5] as String?,
      isActive: fields[6] as bool,
      libido: fields[8] as double,
      creativity: fields[9] as double,
      empathy: fields[10] as double,
      humor: fields[11] as double,
      avatarId: fields[12] as String?,
      intelligence: fields[13] as double,
      createdAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PrivateUserPersona obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.aliasName)
      ..writeByte(2)
      ..write(obj.aliasAge)
      ..writeByte(3)
      ..write(obj.aliasGender)
      ..writeByte(4)
      ..write(obj.aliasDescription)
      ..writeByte(5)
      ..write(obj.aliasBackground)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.libido)
      ..writeByte(9)
      ..write(obj.creativity)
      ..writeByte(10)
      ..write(obj.empathy)
      ..writeByte(11)
      ..write(obj.humor)
      ..writeByte(12)
      ..write(obj.avatarId)
      ..writeByte(13)
      ..write(obj.intelligence);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivateUserPersonaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
