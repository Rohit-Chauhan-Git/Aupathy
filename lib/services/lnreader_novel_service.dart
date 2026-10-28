import 'dart:async';
import 'dart:convert';

import '../models/plugin_model.dart';
import 'lnreader_plugin_repository.dart';
import 'lnreader_runtime_js.dart';
import 'lnreader_runtime_probe.dart';

class LnReaderPluginException implements Exception {
  const LnReaderPluginException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class LnReaderSearchItem {
  const LnReaderSearchItem({
    required this.name,
    required this.path,
    this.coverUrl,
    this.author,
  });

  final String name;
  final String path;
  final String? coverUrl;
  final String? author;
}

class LnReaderChapter {
  const LnReaderChapter({
    required this.name,
    required this.path,
    this.releaseTime,
    this.chapterNumber,
    this.page,
  });

  final String name;
  final String path;
  final String? releaseTime;
  final int? chapterNumber;
  final String? page;

  Map<String, dynamic> toMetadata() {
    return <String, dynamic>{
      'name': name,
      'path': path,
      if (releaseTime != null) 'releaseTime': releaseTime,
      if (chapterNumber != null) 'chapterNumber': chapterNumber,
      if (page != null) 'page': page,
    };
  }
}

class LnReaderNovelDetails {
  const LnReaderNovelDetails({
    required this.name,
    required this.path,
    required this.sourceUrl,
    this.coverUrl,
    this.summary = '',
    this.author = '',
    this.genres = const <String>[],
    this.status = 'unknown',
    this.chapters = const <LnReaderChapter>[],
  });

  final String name;
  final String path;
  final String sourceUrl;
  final String? coverUrl;
  final String summary;
  final String author;
  final List<String> genres;
  final String status;
  final List<LnReaderChapter> chapters;
}

class LnReaderChapterContent {
  const LnReaderChapterContent({required this.path, required this.html});

  final String path;
  final String html;

  int get characterCount => html.length;
}

abstract interface class LnReaderNovelApi {
  Future<List<LnReaderSearchItem>> searchNovels(
    PluginModel plugin,
    String query, {
    int page = 1,
  });

  Future<LnReaderNovelDetails> parseNovel(PluginModel plugin, String path);

  Future<LnReaderChapterContent> parseChapter(PluginModel plugin, String path);
}

abstract interface class LnReaderPluginExecutor {
  Future<Object?> invoke(String method, List<Object?> args);

  Future<String?> resolveUrl(String path);

  void dispose();
}

abstract interface class LnReaderPluginExecutorFactory {
  Future<LnReaderPluginExecutor> open(PluginModel plugin);
}

class LnReaderNovelService implements LnReaderNovelApi {
  LnReaderNovelService({
    required this.executorFactory,
    this.searchTimeout = const Duration(seconds: 30),
  });

  final LnReaderPluginExecutorFactory executorFactory;
  final Duration searchTimeout;

  @override
  Future<List<LnReaderSearchItem>> searchNovels(
    PluginModel plugin,
    String query, {
    int page = 1,
  }) async {
    _validatePlugin(plugin);
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      throw const LnReaderPluginException('Enter a search term.');
    }
    if (page < 1) {
      throw const LnReaderPluginException('Search page must be at least 1.');
    }

    final executor = await _open(plugin);
    try {
      final result = await executor
          .invoke('searchNovels', <Object?>[normalizedQuery, page])
          .timeout(searchTimeout);
      if (result is! List) {
        throw const LnReaderPluginException(
          'The plugin returned an invalid search response.',
        );
      }
      return _mapSearchResults(result);
    } on TimeoutException {
      throw LnReaderPluginException(
        'The plugin did not finish searching within '
        '${searchTimeout.inSeconds} seconds.',
      );
    } finally {
      executor.dispose();
    }
  }

  @override
  Future<LnReaderNovelDetails> parseNovel(
    PluginModel plugin,
    String path,
  ) async {
    _validatePlugin(plugin);
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      throw const LnReaderPluginException('The novel path is missing.');
    }

    final executor = await _open(plugin);
    try {
      final result = await executor
          .invoke('parseNovel', <Object?>[normalizedPath])
          .timeout(searchTimeout);
      if (result is! Map) {
        throw const LnReaderPluginException(
          'The plugin returned an invalid novel response.',
        );
      }
      final novel = result.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
      final name = _string(novel['name']);
      if (name == null) {
        throw const LnReaderPluginException(
          'The plugin response did not contain a novel title.',
        );
      }
      final chapters = _mapChapters(novel['chapters']);
      final resolvedUrl = await executor.resolveUrl(normalizedPath);
      return LnReaderNovelDetails(
        name: name,
        path: normalizedPath,
        sourceUrl:
            _string(resolvedUrl) ?? _joinUrl(plugin.baseUrl, normalizedPath),
        coverUrl: _string(novel['cover']),
        summary: _string(novel['summary']) ?? '',
        author: _string(novel['author']) ?? '',
        genres: _genres(novel['genres']),
        status: _string(novel['status']) ?? 'unknown',
        chapters: chapters,
      );
    } on TimeoutException {
      throw LnReaderPluginException(
        'The plugin did not finish loading the novel within '
        '${searchTimeout.inSeconds} seconds.',
      );
    } finally {
      executor.dispose();
    }
  }

  @override
  Future<LnReaderChapterContent> parseChapter(
    PluginModel plugin,
    String path,
  ) async {
    _validatePlugin(plugin);
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      throw const LnReaderPluginException('The chapter path is missing.');
    }

    final executor = await _open(plugin);
    try {
      final result = await executor
          .invoke('parseChapter', <Object?>[normalizedPath])
          .timeout(searchTimeout);
      if (result is! String || result.trim().isEmpty) {
        throw const LnReaderPluginException(
          'The plugin returned no chapter content.',
        );
      }
      return LnReaderChapterContent(path: normalizedPath, html: result);
    } on TimeoutException {
      throw LnReaderPluginException(
        'The plugin did not finish loading the chapter within '
        '${searchTimeout.inSeconds} seconds.',
      );
    } finally {
      executor.dispose();
    }
  }

  Future<LnReaderPluginExecutor> _open(PluginModel plugin) async {
    try {
      return await executorFactory.open(plugin);
    } on LnReaderPluginException {
      rethrow;
    } catch (error) {
      throw LnReaderPluginException(
        'Could not start ${plugin.name}: $error',
        cause: error,
      );
    }
  }

  void _validatePlugin(PluginModel plugin) {
    if (!plugin.isInstalled) {
      throw LnReaderPluginException('${plugin.name} is not installed.');
    }
    if (!plugin.isEnabled) {
      throw LnReaderPluginException('${plugin.name} is disabled.');
    }
    final source =
        plugin.metadata[LnReaderPluginRepository.metadataBundleSource];
    if (source is! String || source.trim().isEmpty) {
      throw LnReaderPluginException(
        '${plugin.name} has no installed bundle. Reinstall the plugin.',
      );
    }
  }

  List<LnReaderSearchItem> _mapSearchResults(List<Object?> raw) {
    final results = <LnReaderSearchItem>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
      final name = _string(map['name']);
      final path = _string(map['path']);
      if (name == null || path == null) continue;
      results.add(
        LnReaderSearchItem(
          name: name,
          path: path,
          coverUrl: _string(map['cover']),
          author: _string(map['author']),
        ),
      );
    }
    return results;
  }

  List<LnReaderChapter> _mapChapters(Object? raw) {
    if (raw == null) return const <LnReaderChapter>[];
    if (raw is! List) {
      throw const LnReaderPluginException(
        'The plugin returned an invalid chapter list.',
      );
    }
    final chapters = <LnReaderChapter>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
      final name = _string(map['name']);
      final path = _string(map['path']);
      if (name == null || path == null) continue;
      final rawNumber = map['chapterNumber'];
      chapters.add(
        LnReaderChapter(
          name: name,
          path: path,
          releaseTime: _string(map['releaseTime']),
          chapterNumber: rawNumber is num ? rawNumber.toInt() : null,
          page: _string(map['page']),
        ),
      );
    }
    return chapters;
  }

  List<String> _genres(Object? raw) {
    if (raw is String) {
      return raw
          .split(RegExp(r'[,;]'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }
    if (raw is List) {
      final genres = <String>[];
      for (final value in raw) {
        if (value is String && value.trim().isNotEmpty) {
          genres.add(value.trim());
        } else if (value is Map) {
          final name = _string(value['name']);
          if (name != null) genres.add(name);
        }
      }
      return genres;
    }
    return const <String>[];
  }

  String? _string(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  String _joinUrl(String? baseUrl, String path) {
    final base = baseUrl?.trim() ?? '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (base.isEmpty) return path;
    if (path.startsWith('/')) return '$base$path';
    return '$base/$path';
  }
}

class QuickJsLnReaderPluginExecutorFactory
    implements LnReaderPluginExecutorFactory {
  const QuickJsLnReaderPluginExecutorFactory({
    required this.runtimeFactory,
    this.callTimeout = const Duration(seconds: 30),
  });

  final LnReaderScriptRuntimeFactory runtimeFactory;
  final Duration callTimeout;

  @override
  Future<LnReaderPluginExecutor> open(PluginModel plugin) async {
    final source =
        plugin.metadata[LnReaderPluginRepository.metadataBundleSource];
    if (source is! String || source.trim().isEmpty) {
      throw LnReaderPluginException(
        '${plugin.name} has no installed bundle. Reinstall the plugin.',
      );
    }

    final session = runtimeFactory.create();
    try {
      final sanity = session.evaluate('1 + 1');
      if (sanity.isError || sanity.value.trim() != '2') {
        throw LnReaderPluginException(
          'The JavaScript engine failed its sanity check.',
        );
      }

      final prelude = session.evaluate(lnReaderRuntimePrelude);
      if (prelude.isError || !prelude.value.contains('lnreader-runtime')) {
        throw LnReaderPluginException(
          prelude.errorMessage ?? 'The LNReader runtime could not start.',
        );
      }

      final pluginId = plugin.metadata[LnReaderPluginRepository.metadataId];
      session.evaluate(
        'globalThis.__lnreaderPluginId = ${jsonEncode(pluginId?.toString() ?? '')};',
      );
      final loaded = session.evaluate(
        'globalThis.__lnreaderLoadPlugin(${jsonEncode(source)});',
      );
      final decoded = _decodeMap(loaded.value);
      if (loaded.isError || decoded == null || decoded['ok'] != true) {
        final missing = decoded?['missingModules'];
        final suffix = missing is List && missing.isNotEmpty
            ? ' Missing modules: ${missing.join(', ')}.'
            : '';
        throw LnReaderPluginException(
          '${decoded?['error'] ?? loaded.errorMessage ?? 'Plugin initialization failed.'}$suffix',
        );
      }

      final methods = <String>{};
      final rawMethods = decoded['methods'];
      if (rawMethods is Map) {
        for (final entry in rawMethods.entries) {
          if (entry.value == 'function') {
            methods.add(entry.key.toString());
          }
        }
      }
      return _QuickJsPluginExecutor(
        session: session,
        methods: methods,
        callTimeout: callTimeout,
      );
    } catch (_) {
      session.dispose();
      rethrow;
    }
  }
}

class _QuickJsPluginExecutor implements LnReaderPluginExecutor {
  _QuickJsPluginExecutor({
    required this._session,
    required this.methods,
    required this.callTimeout,
  });

  final LnReaderScriptSession _session;
  final Set<String> methods;
  final Duration callTimeout;
  bool _disposed = false;

  @override
  Future<Object?> invoke(String method, List<Object?> args) async {
    if (_disposed) {
      throw const LnReaderPluginException('The plugin session is closed.');
    }
    if (!methods.contains(method)) {
      throw LnReaderPluginException('The plugin does not implement $method().');
    }

    final result = _session.evaluate('''
(function () {
  var plugin = globalThis.__lnreaderPlugin;
  var methodName = ${jsonEncode(method)};
  if (!plugin || typeof plugin[methodName] !== 'function') {
    globalThis.__lnreaderCall = {
      status: 'unavailable',
      error: 'The plugin does not implement ' + methodName + '().'
    };
    return;
  }
  globalThis.__lnreaderCall = { status: 'pending' };
  try {
    Promise.resolve(plugin[methodName].apply(plugin, ${jsonEncode(args)}))
      .then(function (value) {
        try {
          var serialized = JSON.stringify(value);
          globalThis.__lnreaderCall = {
            status: 'fulfilled',
            result: serialized === undefined ? 'null' : serialized
          };
        } catch (serializationError) {
          globalThis.__lnreaderCall = {
            status: 'rejected',
            error: globalThis.__lnreaderErrorText(serializationError)
          };
        }
      })
      .catch(function (error) {
        globalThis.__lnreaderCall = {
          status: 'rejected',
          error: globalThis.__lnreaderErrorText(error)
        };
      });
  } catch (error) {
    globalThis.__lnreaderCall = {
      status: 'rejected',
      error: globalThis.__lnreaderErrorText(error)
    };
  }
})();
''');
    if (result.isError) {
      throw LnReaderPluginException(
        result.errorMessage ?? 'The plugin call failed.',
      );
    }

    final deadline = DateTime.now().add(callTimeout);
    while (DateTime.now().isBefore(deadline)) {
      _session.drainMicrotasks();
      final state = _decodeMap(
        _session.evaluate('JSON.stringify(globalThis.__lnreaderCall)').value,
      );
      final status = state?['status']?.toString();
      if (status == 'fulfilled') {
        final serialized = state?['result'];
        if (serialized is! String) {
          throw const LnReaderPluginException(
            'The plugin returned an invalid result.',
          );
        }
        try {
          return jsonDecode(serialized);
        } on FormatException catch (error) {
          throw LnReaderPluginException(
            'The plugin returned malformed data: $error',
          );
        }
      }
      if (status == 'rejected' || status == 'unavailable') {
        throw LnReaderPluginException(
          state?['error']?.toString() ?? 'The plugin call failed.',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    throw LnReaderPluginException(
      'The plugin did not respond within ${callTimeout.inSeconds} seconds.',
    );
  }

  @override
  Future<String?> resolveUrl(String path) async {
    if (_disposed) return null;
    final result = _session.evaluate('''
(function () {
  var plugin = globalThis.__lnreaderPlugin;
  if (!plugin || typeof plugin.resolveUrl !== 'function') return '';
  try {
    return String(plugin.resolveUrl(${jsonEncode(path)}));
  } catch (error) {
    return '';
  }
})();
''');
    if (result.isError) return null;
    final value = result.value.trim();
    return value.isEmpty || value == 'undefined' ? null : value;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _session.dispose();
  }
}

Map<String, dynamic>? _decodeMap(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == 'undefined' || trimmed == 'null') {
    return null;
  }
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) {
      return decoded.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
  } on FormatException {
    return null;
  }
  return null;
}
