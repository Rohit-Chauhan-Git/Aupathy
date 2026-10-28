import 'package:hive_ce/hive_ce.dart';

class VoiceModel {
  const VoiceModel({
    required this.id,
    required this.name,
    required this.engine,
    this.language = 'en',
    this.locale,
    this.gender = 'neutral',
    this.sampleRate = 22050,
    this.pitch = 1.0,
    this.speed = 1.0,
    this.isInstalled = false,
    this.isFavorite = false,
    this.modelPath,
    this.metadata = const {},
  });

  final int id;
  final String name;
  final String engine;
  final String language;
  final String? locale;
  final String gender;
  final int sampleRate;
  final double pitch;
  final double speed;
  final bool isInstalled;
  final bool isFavorite;
  final String? modelPath;
  final Map<String, dynamic> metadata;

  VoiceModel copyWith({
    int? id,
    String? name,
    String? engine,
    String? language,
    String? locale,
    String? gender,
    int? sampleRate,
    double? pitch,
    double? speed,
    bool? isInstalled,
    bool? isFavorite,
    String? modelPath,
    Map<String, dynamic>? metadata,
  }) {
    return VoiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      engine: engine ?? this.engine,
      language: language ?? this.language,
      locale: locale ?? this.locale,
      gender: gender ?? this.gender,
      sampleRate: sampleRate ?? this.sampleRate,
      pitch: pitch ?? this.pitch,
      speed: speed ?? this.speed,
      isInstalled: isInstalled ?? this.isInstalled,
      isFavorite: isFavorite ?? this.isFavorite,
      modelPath: modelPath ?? this.modelPath,
      metadata: metadata ?? this.metadata,
    );
  }
}

class VoiceModelAdapter extends TypeAdapter<VoiceModel> {
  @override
  final int typeId = 0;

  @override
  VoiceModel read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
    };
    return VoiceModel(
      id: fields[0] as int,
      name: fields[1] as String,
      engine: fields[2] as String,
      language: fields[3] as String? ?? 'en',
      locale: fields[4] as String?,
      gender: fields[5] as String? ?? 'neutral',
      sampleRate: fields[6] as int? ?? 22050,
      pitch: (fields[7] as num?)?.toDouble() ?? 1.0,
      speed: (fields[8] as num?)?.toDouble() ?? 1.0,
      isInstalled: fields[9] as bool? ?? false,
      isFavorite: fields[10] as bool? ?? false,
      modelPath: fields[11] as String?,
      metadata: Map<String, dynamic>.from(
        fields[12] as Map? ?? const <String, dynamic>{},
      ),
    );
  }

  @override
  void write(BinaryWriter writer, VoiceModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.engine)
      ..writeByte(3)
      ..write(obj.language)
      ..writeByte(4)
      ..write(obj.locale)
      ..writeByte(5)
      ..write(obj.gender)
      ..writeByte(6)
      ..write(obj.sampleRate)
      ..writeByte(7)
      ..write(obj.pitch)
      ..writeByte(8)
      ..write(obj.speed)
      ..writeByte(9)
      ..write(obj.isInstalled)
      ..writeByte(10)
      ..write(obj.isFavorite)
      ..writeByte(11)
      ..write(obj.modelPath)
      ..writeByte(12)
      ..write(obj.metadata);
  }
}
