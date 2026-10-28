import 'package:hive_ce/hive_ce.dart';

import '../models/lnreader_manifest_entry.dart';
import '../models/plugin_model.dart';
import 'lnreader_http_client.dart';
import 'lnreader_manifest_service.dart';

class LnReaderPluginInstallResult {
  const LnReaderPluginInstallResult({
    required this.entry,
    required this.plugin,
    required this.bundleBytes,
  });

  final LnReaderManifestEntry entry;
  final PluginModel plugin;
  final int bundleBytes;
}

class LnReaderPluginInstallException implements Exception {
  const LnReaderPluginInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class LnReaderRepositoryApi {
  Future<LnReaderManifestFetchResult> fetchManifest();

  bool isInstalled(Box<PluginModel> box, String entryId);

  Future<LnReaderPluginInstallResult> install({
    required LnReaderManifestEntry entry,
    required Box<PluginModel> box,
  });
}

/// Fetches the official LNReader manifest and installs source bundles into the
/// existing plugin box. Installed bundle source is kept in plugin metadata so
/// no additional Hive type or box is required.
class LnReaderPluginRepository implements LnReaderRepositoryApi {
  LnReaderPluginRepository({
    required this.httpClient,
    LnReaderManifestService? manifestService,
  }) : manifestService =
           manifestService ?? LnReaderManifestService(httpClient: httpClient);

  static const String metadataId = 'lnreaderId';
  static const String metadataBundleUrl = 'lnreaderBundleUrl';
  static const String metadataBundleSource = 'lnreaderBundleSource';
  static const String metadataSite = 'lnreaderSite';
  static const String metadataVersion = 'lnreaderVersion';

  final LnReaderHttpClient httpClient;
  final LnReaderManifestService manifestService;

  @override
  Future<LnReaderManifestFetchResult> fetchManifest() {
    return manifestService.fetch();
  }

  @override
  bool isInstalled(Box<PluginModel> box, String entryId) {
    return _findInstalled(box, entryId) != null;
  }

  @override
  Future<LnReaderPluginInstallResult> install({
    required LnReaderManifestEntry entry,
    required Box<PluginModel> box,
  }) async {
    LnReaderHttpResponse response;
    try {
      response = await httpClient.get(Uri.parse(entry.url));
    } on LnReaderHttpException catch (error) {
      throw LnReaderPluginInstallException(
        'Could not download ${entry.name}: ${error.message}',
      );
    } catch (error) {
      throw LnReaderPluginInstallException(
        'Could not download ${entry.name}: $error',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LnReaderPluginInstallException(
        '${entry.name} bundle returned HTTP ${response.statusCode}.',
      );
    }
    final source = response.body;
    if (source.trim().isEmpty) {
      throw LnReaderPluginInstallException(
        '${entry.name} returned an empty plugin bundle.',
      );
    }

    final existing = _findInstalled(box, entry.id);
    final pluginId = existing?.plugin.id ?? _nextPluginId(entry.id, box);
    final plugin = PluginModel(
      id: pluginId,
      name: entry.name,
      packageName: 'lnreader.${entry.id}',
      version: entry.version,
      description: 'LNReader source for ${entry.site}',
      baseUrl: entry.site,
      lang: entry.lang,
      type: PluginType.source,
      isEnabled: existing?.plugin.isEnabled ?? true,
      isInstalled: true,
      isPinned: existing?.plugin.isPinned ?? false,
      lastUpdated: DateTime.now(),
      metadata: <String, dynamic>{
        metadataId: entry.id,
        metadataBundleUrl: entry.url,
        metadataBundleSource: source,
        metadataSite: entry.site,
        metadataVersion: entry.version,
      },
    );

    final key = existing?.key ?? pluginId;
    try {
      await box.put(key, plugin);
    } catch (error) {
      throw LnReaderPluginInstallException(
        'Could not save ${entry.name}: $error',
      );
    }

    return LnReaderPluginInstallResult(
      entry: entry,
      plugin: plugin,
      bundleBytes: source.length,
    );
  }

  _InstalledPlugin? _findInstalled(Box<PluginModel> box, String entryId) {
    for (final key in box.keys) {
      final plugin = box.get(key);
      if (plugin == null) continue;
      if (plugin.metadata[metadataId]?.toString() == entryId) {
        return _InstalledPlugin(key: key, plugin: plugin);
      }
    }
    return null;
  }

  int _nextPluginId(String entryId, Box<PluginModel> box) {
    final usedIds = <int>{for (final plugin in box.values) plugin.id};
    var candidate = stableLnReaderPluginId(entryId);
    while (usedIds.contains(candidate) || box.containsKey(candidate)) {
      candidate = candidate >= 0x7ffffffe ? 1 : candidate + 1;
    }
    return candidate;
  }
}

int stableLnReaderPluginId(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

class _InstalledPlugin {
  const _InstalledPlugin({required this.key, required this.plugin});

  final dynamic key;
  final PluginModel plugin;
}
