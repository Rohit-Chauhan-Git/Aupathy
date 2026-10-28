import 'package:hive_ce/hive_ce.dart';

class NovelModel {
  const NovelModel({
    required this.id,
    required this.title,
    required this.sourceId,
    required this.sourceName,
    this.author = '',
    this.coverUrl,
    this.description = '',
    this.sourceUrl = '',
    this.status = 'unknown',
    this.genres = const [],
    this.chapterCount = 0,
    this.lastReadChapter = 0,
    this.unreadCount = 0,
    this.lastReadAt,
    this.dateAdded,
    this.isFavorite = false,
    this.isDownloaded = false,
    this.metadata = const {},
  });

  final int id;
  final String title;
  final int sourceId;
  final String sourceName;
  final String author;
  final String? coverUrl;
  final String description;
  final String sourceUrl;
  final String status;
  final List<String> genres;
  final int chapterCount;
  final int lastReadChapter;
  final int unreadCount;
  final DateTime? lastReadAt;
  final DateTime? dateAdded;
  final bool isFavorite;
  final bool isDownloaded;
  final Map<String, dynamic> metadata;

  /// Fraction of the novel that has been read, always within 0.0–1.0.
  ///
  /// A missing or invalid chapter count is treated as unknown (0%).
  double get readingProgress {
    if (chapterCount <= 0) return 0;
    return (lastReadChapter / chapterCount).clamp(0.0, 1.0);
  }

  /// Whether the novel has a known chapter count and has been fully read.
  bool get isCompleted => chapterCount > 0 && lastReadChapter >= chapterCount;

  /// Whether reading has started but the novel is not complete yet.
  bool get isInProgress =>
      chapterCount > 0 && lastReadChapter > 0 && !isCompleted;

  NovelModel copyWith({
    int? id,
    String? title,
    int? sourceId,
    String? sourceName,
    String? author,
    String? coverUrl,
    String? description,
    String? sourceUrl,
    String? status,
    List<String>? genres,
    int? chapterCount,
    int? lastReadChapter,
    int? unreadCount,
    DateTime? lastReadAt,
    DateTime? dateAdded,
    bool? isFavorite,
    bool? isDownloaded,
    Map<String, dynamic>? metadata,
  }) {
    return NovelModel(
      id: id ?? this.id,
      title: title ?? this.title,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      status: status ?? this.status,
      genres: genres ?? this.genres,
      chapterCount: chapterCount ?? this.chapterCount,
      lastReadChapter: lastReadChapter ?? this.lastReadChapter,
      unreadCount: unreadCount ?? this.unreadCount,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      dateAdded: dateAdded ?? this.dateAdded,
      isFavorite: isFavorite ?? this.isFavorite,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      metadata: metadata ?? this.metadata,
    );
  }
}

class NovelModelAdapter extends TypeAdapter<NovelModel> {
  @override
  final int typeId = 3;

  @override
  NovelModel read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
    };
    DateTime? dateFrom(int key) {
      final value = fields[key] as int?;
      return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
    }

    return NovelModel(
      id: fields[0] as int,
      title: fields[1] as String,
      sourceId: fields[2] as int? ?? 0,
      sourceName: fields[3] as String? ?? '',
      author: fields[4] as String? ?? '',
      coverUrl: fields[5] as String?,
      description: fields[6] as String? ?? '',
      sourceUrl: fields[7] as String? ?? '',
      status: fields[8] as String? ?? 'unknown',
      genres: List<String>.from(fields[9] as List? ?? const []),
      chapterCount: fields[10] as int? ?? 0,
      lastReadChapter: fields[11] as int? ?? 0,
      unreadCount: fields[12] as int? ?? 0,
      lastReadAt: dateFrom(13),
      dateAdded: dateFrom(14),
      isFavorite: fields[15] as bool? ?? false,
      isDownloaded: fields[16] as bool? ?? false,
      metadata: Map<String, dynamic>.from(
        fields[17] as Map? ?? const <String, dynamic>{},
      ),
    );
  }

  @override
  void write(BinaryWriter writer, NovelModel obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.sourceId)
      ..writeByte(3)
      ..write(obj.sourceName)
      ..writeByte(4)
      ..write(obj.author)
      ..writeByte(5)
      ..write(obj.coverUrl)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.sourceUrl)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.genres)
      ..writeByte(10)
      ..write(obj.chapterCount)
      ..writeByte(11)
      ..write(obj.lastReadChapter)
      ..writeByte(12)
      ..write(obj.unreadCount)
      ..writeByte(13)
      ..write(obj.lastReadAt?.millisecondsSinceEpoch)
      ..writeByte(14)
      ..write(obj.dateAdded?.millisecondsSinceEpoch)
      ..writeByte(15)
      ..write(obj.isFavorite)
      ..writeByte(16)
      ..write(obj.isDownloaded)
      ..writeByte(17)
      ..write(obj.metadata);
  }
}
