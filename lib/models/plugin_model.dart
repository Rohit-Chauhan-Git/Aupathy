import 'package:hive_ce/hive_ce.dart';

enum PluginType { source, tts, extension }

class PluginModel {
  const PluginModel({
    required this.id,
    required this.name,
    required this.packageName,
    required this.version,
    this.description = '',
    this.iconUrl,
    this.baseUrl,
    this.lang = 'en',
    this.type = PluginType.source,
    this.isEnabled = true,
    this.isInstalled = false,
    this.isPinned = false,
    this.lastUpdated,
    this.metadata = const {},
  });

  final int id;
  final String name;
  final String packageName;
  final String version;
  final String description;
  final String? iconUrl;
  final String? baseUrl;
  final String lang;
  final PluginType type;
  final bool isEnabled;
  final bool isInstalled;
  final bool isPinned;
  final DateTime? lastUpdated;
  final Map<String, dynamic> metadata;

  bool get isSource => type == PluginType.source;

  PluginModel copyWith({
    int? id,
    String? name,
    String? packageName,
    String? version,
    String? description,
    String? iconUrl,
    String? baseUrl,
    String? lang,
    PluginType? type,
    bool? isEnabled,
    bool? isInstalled,
    bool? isPinned,
    DateTime? lastUpdated,
    Map<String, dynamic>? metadata,
  }) {
    return PluginModel(
      id: id ?? this.id,
      name: name ?? this.name,
      packageName: packageName ?? this.packageName,
      version: version ?? this.version,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      baseUrl: baseUrl ?? this.baseUrl,
      lang: lang ?? this.lang,
      type: type ?? this.type,
      isEnabled: isEnabled ?? this.isEnabled,
      isInstalled: isInstalled ?? this.isInstalled,
      isPinned: isPinned ?? this.isPinned,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      metadata: metadata ?? this.metadata,
    );
  }
}

class PluginModelAdapter extends TypeAdapter<PluginModel> {
  @override
  final int typeId = 1;

  @override
  PluginModel read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
    };
    final typeIndex = fields[9] as int? ?? 0;
    return PluginModel(
      id: fields[0] as int,
      name: fields[1] as String,
      packageName: fields[2] as String,
      version: fields[3] as String,
      description: fields[4] as String? ?? '',
      iconUrl: fields[5] as String?,
      baseUrl: fields[6] as String?,
      lang: fields[7] as String? ?? 'en',
      type: typeIndex >= 0 && typeIndex < PluginType.values.length
          ? PluginType.values[typeIndex]
          : PluginType.source,
      isEnabled: fields[8] as bool? ?? true,
      isInstalled: fields[10] as bool? ?? false,
      isPinned: fields[11] as bool? ?? false,
      lastUpdated: fields[12] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fields[12] as int),
      metadata: Map<String, dynamic>.from(
        fields[13] as Map? ?? const <String, dynamic>{},
      ),
    );
  }

  @override
  void write(BinaryWriter writer, PluginModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.packageName)
      ..writeByte(3)
      ..write(obj.version)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.iconUrl)
      ..writeByte(6)
      ..write(obj.baseUrl)
      ..writeByte(7)
      ..write(obj.lang)
      ..writeByte(8)
      ..write(obj.isEnabled)
      ..writeByte(9)
      ..write(obj.type.index)
      ..writeByte(10)
      ..write(obj.isInstalled)
      ..writeByte(11)
      ..write(obj.isPinned)
      ..writeByte(12)
      ..write(obj.lastUpdated?.millisecondsSinceEpoch)
      ..writeByte(13)
      ..write(obj.metadata);
  }
}
