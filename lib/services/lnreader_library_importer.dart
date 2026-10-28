import 'package:hive_ce/hive_ce.dart';

import '../models/novel_model.dart';
import '../models/plugin_model.dart';
import 'lnreader_novel_service.dart';
import 'lnreader_plugin_repository.dart';

class LnReaderImportResult {
  const LnReaderImportResult({
    required this.novel,
    required this.key,
    required this.created,
  });

  final NovelModel novel;
  final dynamic key;
  final bool created;
}

class LnReaderLibraryImporter {
  const LnReaderLibraryImporter();

  static const String metadataPluginEntryId = 'lnreaderPluginEntryId';
  static const String metadataPluginId = 'lnreaderPluginId';
  static const String metadataNovelPath = 'lnreaderNovelPath';
  static const String metadataChapters = 'lnreaderChapters';
  static const String metadataImportedAt = 'lnreaderImportedAt';

  Future<LnReaderImportResult> import({
    required Box<NovelModel> box,
    required PluginModel plugin,
    required LnReaderNovelDetails details,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final pluginEntryId =
        plugin.metadata[LnReaderPluginRepository.metadataId]?.toString() ??
        plugin.id.toString();
    final normalizedPath = _normalizePath(details.path);
    final existing = _findExisting(
      box,
      plugin: plugin,
      pluginEntryId: pluginEntryId,
      path: normalizedPath,
      sourceUrl: details.sourceUrl,
    );

    final metadata = <String, dynamic>{
      ...?existing?.novel.metadata,
      metadataPluginEntryId: pluginEntryId,
      metadataPluginId: plugin.id,
      metadataNovelPath: details.path,
      metadataChapters: details.chapters
          .map((chapter) => chapter.toMetadata())
          .toList(growable: false),
      metadataImportedAt: timestamp.toIso8601String(),
    };

    if (existing != null) {
      final current = existing.novel;
      final updated = current.copyWith(
        title: details.name,
        sourceId: plugin.id,
        sourceName: plugin.name,
        author: details.author.trim().isEmpty ? current.author : details.author,
        coverUrl: details.coverUrl?.trim().isNotEmpty == true
            ? details.coverUrl
            : current.coverUrl,
        description: details.summary.trim().isEmpty
            ? current.description
            : details.summary,
        sourceUrl: details.sourceUrl.trim().isEmpty
            ? current.sourceUrl
            : details.sourceUrl,
        status: details.status.trim().isEmpty ? current.status : details.status,
        genres: details.genres.isEmpty ? current.genres : details.genres,
        chapterCount: details.chapters.length,
        metadata: metadata,
      );
      await box.put(existing.key, updated);
      return LnReaderImportResult(
        novel: updated,
        key: existing.key,
        created: false,
      );
    }

    final novel = NovelModel(
      id: _nextNovelId(box),
      title: details.name,
      sourceId: plugin.id,
      sourceName: plugin.name,
      author: details.author,
      coverUrl: details.coverUrl,
      description: details.summary,
      sourceUrl: details.sourceUrl,
      status: details.status,
      genres: details.genres,
      chapterCount: details.chapters.length,
      unreadCount: details.chapters.length,
      dateAdded: timestamp,
      metadata: metadata,
    );
    final key = _newKey(box, plugin.id, normalizedPath);
    await box.put(key, novel);
    return LnReaderImportResult(novel: novel, key: key, created: true);
  }

  _ExistingNovel? _findExisting(
    Box<NovelModel> box, {
    required PluginModel plugin,
    required String pluginEntryId,
    required String path,
    required String sourceUrl,
  }) {
    for (final key in box.keys) {
      final novel = box.get(key);
      if (novel == null) continue;
      final storedEntryId = novel.metadata[metadataPluginEntryId]?.toString();
      final storedPath = novel.metadata[metadataNovelPath]?.toString();
      if (storedPath != null && _normalizePath(storedPath) == path) {
        if (storedEntryId == pluginEntryId ||
            novel.sourceId == plugin.id ||
            storedEntryId == null) {
          return _ExistingNovel(key: key, novel: novel);
        }
      }
      if (sourceUrl.trim().isNotEmpty &&
          novel.sourceUrl.trim() == sourceUrl.trim() &&
          novel.sourceId == plugin.id) {
        return _ExistingNovel(key: key, novel: novel);
      }
    }
    return null;
  }

  int _nextNovelId(Box<NovelModel> box) {
    var maxId = 0;
    for (final novel in box.values) {
      if (novel.id > maxId) maxId = novel.id;
    }
    var candidate = maxId + 1;
    if (candidate <= 0) candidate = 1;
    final used = box.values.map((novel) => novel.id).toSet();
    while (used.contains(candidate)) {
      candidate++;
    }
    return candidate;
  }

  String _newKey(Box<NovelModel> box, int pluginId, String path) {
    var hash = 0x811c9dc5;
    for (final codeUnit in path.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    final base = 'lnreader:$pluginId:$hash';
    var key = base;
    var suffix = 1;
    while (box.containsKey(key)) {
      key = '$base:${suffix++}';
    }
    return key;
  }

  String _normalizePath(String value) {
    return value.trim().replaceAll(RegExp(r'^/+|/+$'), '');
  }
}

class _ExistingNovel {
  const _ExistingNovel({required this.key, required this.novel});

  final dynamic key;
  final NovelModel novel;
}
