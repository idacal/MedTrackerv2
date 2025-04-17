// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExamCategoryAdapter extends TypeAdapter<ExamCategory> {
  @override
  final int typeId = 0;

  @override
  ExamCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExamCategory(
      name: fields[0] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ExamCategory obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.parameterListHive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ParameterAdapter extends TypeAdapter<Parameter> {
  @override
  final int typeId = 1;

  @override
  Parameter read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Parameter(
      name: fields[0] as String,
      valor: fields[1] as double?,
      rangoReferencia: (fields[2] as List?)?.cast<double?>(),
      referenciaOriginal: fields[3] as String?,
      fecha: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Parameter obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.valor)
      ..writeByte(2)
      ..write(obj.rangoReferencia)
      ..writeByte(3)
      ..write(obj.referenciaOriginal)
      ..writeByte(4)
      ..write(obj.fecha);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParameterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ParameterStatusAdapter extends TypeAdapter<ParameterStatus> {
  @override
  final int typeId = 2;

  @override
  ParameterStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ParameterStatus.normal;
      case 1:
        return ParameterStatus.vigilar;
      case 2:
        return ParameterStatus.atencion;
      case 3:
        return ParameterStatus.indeterminate;
      default:
        return ParameterStatus.normal;
    }
  }

  @override
  void write(BinaryWriter writer, ParameterStatus obj) {
    switch (obj) {
      case ParameterStatus.normal:
        writer.writeByte(0);
        break;
      case ParameterStatus.vigilar:
        writer.writeByte(1);
        break;
      case ParameterStatus.atencion:
        writer.writeByte(2);
        break;
      case ParameterStatus.indeterminate:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParameterStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
