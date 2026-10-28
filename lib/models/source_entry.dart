import 'novel_model.dart';
import 'plugin_model.dart';

/// Read-only view of a source available to the reader.
///
/// Sources are not a persisted Hive type. They are derived from installed
/// source plugins and from source references already present in the library.
class SourceEntry {
  const SourceEntry({
    required this.id,
    required this.name,
    this.language = '',
    this.description = '',
    this.baseUrl,
    this.isInstalled = false,
    this.isEnabled = false,
    this.hasPlugin = false,
    this.recentNovelCount = 0,
    this.lastUsedAt,
  });

  final int id;
  final String name;
  final String language;
  final String description;
  final String? baseUrl;
  final bool isInstalled;
  final bool isEnabled;
  final bool hasPlugin;
  final int recentNovelCount;
  final DateTime? lastUsedAt;

  String get host {
    final uri = Uri.tryParse(baseUrl?.trim() ?? '');
    if (uri == null || uri.host.isEmpty) return '';
    return uri.host;
  }

  String get languageLabel {
    final value = language.trim();
    return value.isEmpty ? 'Unknown language' : value.toUpperCase();
  }
}

/// Builds the source catalog from source plugins plus library source metadata.
///
/// No network integrations are implied: this only joins data that is already
/// stored locally. A source that only appears in the library is still real
/// data, but it is marked as [SourceEntry.hasPlugin] = false.
List<SourceEntry> buildSourceCatalog({
  required List<PluginModel> plugins,
  required List<NovelModel> novels,
}) {
  final entries = <SourceEntry>[];
  final matchedNovelIndexes = <int>{};

  for (final plugin in plugins.where(
    (item) => item.type == PluginType.source,
  )) {
    final related = <NovelModel>[];
    for (var index = 0; index < novels.length; index++) {
      final novel = novels[index];
      if (_matchesPlugin(novel, plugin)) {
        related.add(novel);
        matchedNovelIndexes.add(index);
      }
    }

    entries.add(
      SourceEntry(
        id: plugin.id,
        name: plugin.name,
        language: plugin.lang,
        description: plugin.description,
        baseUrl: plugin.baseUrl,
        isInstalled: plugin.isInstalled,
        isEnabled: plugin.isEnabled,
        hasPlugin: true,
        recentNovelCount: related.length,
        lastUsedAt: _latestUse(related),
      ),
    );
  }

  final libraryGroups = <String, List<NovelModel>>{};
  for (var index = 0; index < novels.length; index++) {
    if (matchedNovelIndexes.contains(index)) continue;
    final novel = novels[index];
    final name = novel.sourceName.trim();
    if (name.isEmpty && novel.sourceId == 0) continue;
    final key = novel.sourceId != 0
        ? 'id:${novel.sourceId}'
        : 'name:${name.toLowerCase()}';
    libraryGroups.putIfAbsent(key, () => <NovelModel>[]).add(novel);
  }

  for (final group in libraryGroups.values) {
    final first = group.first;
    final name = first.sourceName.trim().isEmpty
        ? 'Source ${first.sourceId}'
        : first.sourceName.trim();
    entries.add(
      SourceEntry(
        id: first.sourceId,
        name: name,
        hasPlugin: false,
        recentNovelCount: group.length,
        lastUsedAt: _latestUse(group),
      ),
    );
  }

  entries.sort((a, b) {
    final aDate = a.lastUsedAt;
    final bDate = b.lastUsedAt;
    if (aDate != null && bDate != null) {
      final byDate = bDate.compareTo(aDate);
      if (byDate != 0) return byDate;
    } else if (aDate != null) {
      return -1;
    } else if (bDate != null) {
      return 1;
    }
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (byName != 0) return byName;
    return a.id.compareTo(b.id);
  });

  return entries;
}

bool _matchesPlugin(NovelModel novel, PluginModel plugin) {
  if (novel.sourceId != 0 && novel.sourceId == plugin.id) return true;
  final sourceName = novel.sourceName.trim();
  if (sourceName.isEmpty) return false;
  return sourceName.toLowerCase() == plugin.name.trim().toLowerCase();
}

DateTime? _latestUse(List<NovelModel> novels) {
  DateTime? latest;
  for (final novel in novels) {
    final date = novel.lastReadAt ?? novel.dateAdded;
    if (date == null) continue;
    if (latest == null || date.isAfter(latest)) latest = date;
  }
  return latest;
}
