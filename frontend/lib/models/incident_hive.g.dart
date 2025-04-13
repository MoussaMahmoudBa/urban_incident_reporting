// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incident_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IncidentHiveAdapter extends TypeAdapter<IncidentHive> {
  @override
  final int typeId = 0;

  @override
  IncidentHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IncidentHive(
      incidentType: fields[0] as String,
      description: fields[1] as String,
      imagePath: fields[2] as String?,
      audioPath: fields[3] as String?,
      location: fields[4] as String,
      isSynced: fields[5] as bool,
      userId: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, IncidentHive obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.incidentType)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.imagePath)
      ..writeByte(3)
      ..write(obj.audioPath)
      ..writeByte(4)
      ..write(obj.location)
      ..writeByte(5)
      ..write(obj.isSynced)
      ..writeByte(6)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncidentHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
