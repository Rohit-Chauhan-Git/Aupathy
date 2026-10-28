import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';

import '../models/lnreader_manifest_entry.dart';
import 'lnreader_http_client.dart';
import 'lnreader_runtime_js.dart';

class LnReaderScriptEvaluation {
  const LnReaderScriptEvaluation({
    required this.value,
    required this.isError,
    this.errorMessage,
  });

  final String value;
  final bool isError;
  final String? errorMessage;
}

abstract interface class LnReaderScriptSession {
  LnReaderScriptEvaluation evaluate(String code);

  void drainMicrotasks();

  void dispose();
}

abstract interface class LnReaderScriptRuntimeFactory {
  LnReaderScriptSession create();
}

class QuickJsScriptRuntimeFactory implements LnReaderScriptRuntimeFactory {
  const QuickJsScriptRuntimeFactory({
    required this.httpClient,
    this.stackSize = 512 * 1024,
    this.timeoutMilliseconds = 4000,
  });

  final LnReaderHttpClient httpClient;
  final int stackSize;
  final int timeoutMilliseconds;

  @override
  LnReaderScriptSession create() {
    final runtime = QuickJsRuntime2(
      stackSize: stackSize,
      timeout: timeoutMilliseconds,
    );
    return _QuickJsScriptSession(runtime, httpClient);
  }
}

class _QuickJsScriptSession implements LnReaderScriptSession {
  _QuickJsScriptSession(this._runtime, this._httpClient) {
    _runtime.onMessage('LnReaderHttp', _handleHttpMessage);
  }

  final QuickJsRuntime2 _runtime;
  final LnReaderHttpClient _httpClient;

  Future<Map<String, dynamic>> _handleHttpMessage(dynamic message) async {
    if (message is! Map) {
      throw const LnReaderHttpException('Invalid HTTP bridge request.');
    }
    final data = message.map<String, dynamic>(
      (key, value) => MapEntry(key.toString(), value),
    );
    debugPrint(
      '[LnReaderHttp] ${data['method'] ?? 'GET'} ${data['url'] ?? ''}',
    );
    final url = Uri.tryParse(data['url']?.toString() ?? '');
    if (url == null || !url.hasScheme || url.host.isEmpty) {
      throw LnReaderHttpException('Invalid request URL: ${data['url']}');
    }

    final rawHeaders = data['headers'];
    final headers = <String, String>{};
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        headers[entry.key.toString()] = entry.value.toString();
      }
    }

    try {
      final response = await _httpClient.request(
        url,
        method: data['method']?.toString() ?? 'GET',
        headers: headers,
        body: data['body']?.toString(),
      );
      debugPrint(
        '[LnReaderHttp] ${response.statusCode} ${response.uri} '
        '${response.body.length} bytes',
      );

      return <String, dynamic>{
        'status': response.statusCode,
        'statusText': response.statusMessage,
        'url': response.uri.toString(),
        'redirected': response.redirected,
        'headers': response.headers,
        'body': response.body,
      };
    } catch (error) {
      debugPrint('[LnReaderHttp] bridge failure: $error');
      return <String, dynamic>{
        'status': 599,
        'statusText': 'LNReader bridge error',
        'url': url.toString(),
        'redirected': false,
        'headers': const <String, String>{},
        'body': 'LNReader bridge error: $error',
      };
    }
  }

  @override
  LnReaderScriptEvaluation evaluate(String code) {
    final result = _runtime.evaluate(code);
    return LnReaderScriptEvaluation(
      value: result.stringResult,
      isError: result.isError,
      errorMessage: result.isError ? result.stringResult : null,
    );
  }

  @override
  void drainMicrotasks() {
    _runtime.executePendingJob();
  }

  @override
  void dispose() {
    try {
      _runtime.dispose();
    } catch (_) {
      // A failed probe must not leak an exception during cleanup.
    }
  }
}

class LnReaderSearchResult {
  const LnReaderSearchResult({
    required this.name,
    required this.path,
    this.cover,
  });

  final String name;
  final String path;
  final String? cover;
}

class LnReaderRuntimeProbeResult {
  const LnReaderRuntimeProbeResult({
    required this.engineAvailable,
    required this.engineName,
    this.engineError,
    this.rawBundleExecuted = false,
    this.rawBundleError,
    this.bundleExecuted = false,
    this.bundleError,
    this.requiredModules = const <String>[],
    this.missingModules = const <String>[],
    this.exportKeys = const <String>[],
    this.pluginMethods = const <String, String>{},
    this.pluginId,
    this.pluginName,
    this.pluginSite,
    this.pluginVersion,
    this.initializationSucceeded = false,
    this.initializationError,
    this.searchAttempted = false,
    this.searchSucceeded = false,
    this.searchResultCount,
    this.searchResults = const <LnReaderSearchResult>[],
    this.searchTerm,
    this.searchError,
    this.missingRuntimeApis = const <String>[],
  });

  final bool engineAvailable;
  final String engineName;
  final String? engineError;

  /// Raw execution without a CommonJS module loader. Official bundles are
  /// expected to fail here because they require LNReader modules.
  final bool rawBundleExecuted;
  final String? rawBundleError;

  /// Execution through the LNReader-compatible module loader and host bridge.
  final bool bundleExecuted;
  final String? bundleError;

  final List<String> requiredModules;
  final List<String> missingModules;
  final List<String> exportKeys;
  final Map<String, String> pluginMethods;
  final String? pluginId;
  final String? pluginName;
  final String? pluginSite;
  final String? pluginVersion;

  final bool initializationSucceeded;
  final String? initializationError;

  final bool searchAttempted;
  final bool searchSucceeded;
  final int? searchResultCount;
  final List<LnReaderSearchResult> searchResults;
  final String? searchTerm;
  final String? searchError;

  final List<String> missingRuntimeApis;
}

class LnReaderRuntimeProbe {
  const LnReaderRuntimeProbe({required this.runtimeFactory});

  final LnReaderScriptRuntimeFactory runtimeFactory;

  Future<LnReaderRuntimeProbeResult> run({
    required LnReaderManifestEntry plugin,
    required String bundleSource,
    String searchTerm = 'shadow',
    Duration searchTimeout = const Duration(seconds: 30),
  }) async {
    final requiredModules = extractRequiredModules(bundleSource);
    LnReaderScriptSession? session;

    try {
      session = runtimeFactory.create();
    } catch (error) {
      return LnReaderRuntimeProbeResult(
        engineAvailable: false,
        engineName: 'flutter_js QuickJS',
        engineError: 'JavaScript runtime could not start: $error',
        requiredModules: requiredModules,
        missingRuntimeApis: <String>[
          'A working flutter_js QuickJS runtime',
          ...requiredModules.map((module) => 'LNReader module "$module"'),
        ],
      );
    }

    try {
      final sanity = session.evaluate('1 + 1');
      if (sanity.isError || sanity.value.trim() != '2') {
        return LnReaderRuntimeProbeResult(
          engineAvailable: false,
          engineName: 'flutter_js QuickJS',
          engineError:
              'JavaScript engine sanity check failed: '
              '${sanity.errorMessage ?? sanity.value}',
          requiredModules: requiredModules,
        );
      }

      final raw = _runRawBundle(session, bundleSource);
      final runtime = _installRuntime(session);
      var loaded = const _LoadedPluginResult(
        executed: false,
        error: 'LNReader runtime prelude did not run.',
      );
      if (runtime.installed) {
        session.evaluate(
          'globalThis.__lnreaderPluginId = ${jsonEncode(plugin.id)};',
        );
        loaded = _loadPlugin(session, bundleSource);
      }

      _SearchProbeResult? search;
      if (loaded.initializationSucceeded) {
        search = await _runSearchProbe(
          session,
          searchTerm,
          timeout: searchTimeout,
        );
      }

      final missingApis = <String>[];
      for (final module in loaded.missingModules) {
        missingApis.add('LNReader module "$module"');
      }
      final combinedError = <String?>[
        runtime.error,
        loaded.error,
        loaded.initializationError,
        search?.error,
      ].whereType<String>().join('\n');
      if (combinedError.contains('LNREADER_CHEERIO_UNAVAILABLE')) {
        missingApis.add('cheerio DOM implementation');
      }
      if (combinedError.contains('LNREADER_MISSING_MODULE:')) {
        for (final match in RegExp(
          r'LNREADER_MISSING_MODULE:([^\s]+)',
        ).allMatches(combinedError)) {
          missingApis.add('LNReader module "${match.group(1)}"');
        }
      }

      return LnReaderRuntimeProbeResult(
        engineAvailable: true,
        engineName: 'flutter_js QuickJS',
        rawBundleExecuted: raw.executed,
        rawBundleError: raw.error,
        bundleExecuted: runtime.installed && loaded.executed,
        bundleError: runtime.error ?? loaded.error,
        requiredModules: requiredModules,
        missingModules: loaded.missingModules,
        exportKeys: loaded.exportKeys,
        pluginMethods: loaded.methods,
        pluginId: loaded.id,
        pluginName: loaded.name,
        pluginSite: loaded.site,
        pluginVersion: loaded.version,
        initializationSucceeded: loaded.initializationSucceeded,
        initializationError: loaded.initializationError,
        searchAttempted: search?.attempted ?? false,
        searchSucceeded: search?.succeeded ?? false,
        searchResultCount: search?.resultCount,
        searchResults: search?.results ?? const <LnReaderSearchResult>[],
        searchTerm: search?.attempted == true ? searchTerm : null,
        searchError: search?.error,
        missingRuntimeApis: missingApis.toSet().toList()..sort(),
      );
    } catch (error) {
      return LnReaderRuntimeProbeResult(
        engineAvailable: true,
        engineName: 'flutter_js QuickJS',
        engineError: 'Runtime probe failed: $error',
        requiredModules: requiredModules,
      );
    } finally {
      session.dispose();
    }
  }

  _RawBundleResult _runRawBundle(LnReaderScriptSession session, String source) {
    final code =
        '''
(function () {
  var module = { exports: {} };
  var exports = module.exports;
  function require(name) {
    throw new Error('LNREADER_MISSING_MODULE:' + name);
  }
  try {
    eval(${jsonEncode(source)});
    globalThis.__lnreaderRaw = JSON.stringify({
      ok: true,
      keys: Object.keys(module.exports)
    });
  } catch (error) {
    globalThis.__lnreaderRaw = JSON.stringify({
      ok: false,
      error: String(error && (error.message || error.stack || error)),
      missing: String(error && (error.message || error.stack || error))
    });
  }
})();
globalThis.__lnreaderRaw;
''';
    final result = session.evaluate(code);
    final decoded = _decodeMap(result.value);
    if (decoded == null) {
      return _RawBundleResult(
        executed: false,
        error: result.errorMessage ?? 'Raw bundle probe returned no data.',
      );
    }
    final ok = decoded['ok'] == true;
    return _RawBundleResult(
      executed: ok,
      error: ok ? null : decoded['error']?.toString(),
    );
  }

  _RuntimeInstallResult _installRuntime(LnReaderScriptSession session) {
    final result = session.evaluate(lnReaderRuntimePrelude);
    if (result.isError) {
      return _RuntimeInstallResult(
        installed: false,
        error: result.errorMessage ?? 'LNReader runtime prelude failed.',
      );
    }
    final installed =
        result.value.contains('lnreader-runtime-ready') ||
        result.value.contains('lnreader-runtime-already-installed');
    return _RuntimeInstallResult(
      installed: installed,
      error: installed ? null : 'LNReader runtime prelude returned no status.',
    );
  }

  _LoadedPluginResult _loadPlugin(
    LnReaderScriptSession session,
    String source,
  ) {
    final result = session.evaluate(
      'globalThis.__lnreaderLoadPlugin(${jsonEncode(source)});',
    );
    final decoded = _decodeMap(result.value);
    if (decoded == null) {
      return _LoadedPluginResult(
        executed: false,
        error: result.errorMessage ?? 'Plugin initialization returned no data.',
      );
    }

    final methods = <String, String>{};
    final rawMethods = decoded['methods'];
    if (rawMethods is Map) {
      for (final entry in rawMethods.entries) {
        methods[entry.key.toString()] = entry.value.toString();
      }
    }
    final exportKeys = <String>[];
    final rawKeys = decoded['keys'];
    if (rawKeys is List) {
      exportKeys.addAll(rawKeys.map((value) => value.toString()));
    }
    final missingModules = <String>[];
    final rawMissing = decoded['missingModules'];
    if (rawMissing is List) {
      missingModules.addAll(rawMissing.map((value) => value.toString()));
    }

    final executed = decoded['ok'] == true;
    final methodsFound =
        methods['searchNovels'] == 'function' &&
        methods['parseNovel'] == 'function';
    final hasCandidate = decoded['hasCandidate'] == true;
    return _LoadedPluginResult(
      executed: executed,
      error: executed ? null : decoded['error']?.toString(),
      exportKeys: exportKeys,
      methods: methods,
      missingModules: missingModules,
      id: _stringOrNull(decoded['id']),
      name: _stringOrNull(decoded['name']),
      site: _stringOrNull(decoded['site']),
      version: _stringOrNull(decoded['version']),
      initializationSucceeded: executed && hasCandidate && methodsFound,
      initializationError: !executed
          ? decoded['error']?.toString()
          : methodsFound && hasCandidate
          ? null
          : 'Expected exports.default with searchNovels() and parseNovel().',
    );
  }

  Future<_SearchProbeResult?> _runSearchProbe(
    LnReaderScriptSession session,
    String term, {
    required Duration timeout,
  }) async {
    final startCode =
        '''
(function () {
  var plugin = globalThis.__lnreaderPlugin;
  if (!plugin || typeof plugin.searchNovels !== 'function') {
    globalThis.__lnreaderSearch = {
      status: 'unavailable',
      error: 'Plugin candidate does not expose searchNovels().'
    };
    return;
  }
  globalThis.__lnreaderSearch = { status: 'pending' };
  try {
    Promise.resolve(plugin.searchNovels(${jsonEncode(term)}, 1)).then(
      function (results) {
        var list = Array.isArray(results) ? results : [];
        var previews = list.slice(0, 12).map(function (item) {
          return {
            name: item && typeof item.name === 'string' ? item.name : '',
            path: item && typeof item.path === 'string' ? item.path : '',
            cover: item && typeof item.cover === 'string' ? item.cover : ''
          };
        });
        globalThis.__lnreaderSearch = {
          status: 'fulfilled',
          count: list.length,
          results: previews
        };
      }
    ).catch(function (error) {
      globalThis.__lnreaderSearch = {
        status: 'rejected',
        error: globalThis.__lnreaderErrorText(error)
      };
    });
  } catch (error) {
    globalThis.__lnreaderSearch = {
      status: 'threw',
      error: globalThis.__lnreaderErrorText(error)
    };
  }
})();
globalThis.__lnreaderSearch;
''';

    final first = _decodeMap(session.evaluate(startCode).value);
    final firstStatus = first?['status']?.toString();
    if (firstStatus == 'unavailable') {
      return _SearchProbeResult(
        attempted: false,
        succeeded: false,
        error: first?['error']?.toString(),
      );
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      session.drainMicrotasks();
      final settled = _decodeMap(
        session.evaluate('JSON.stringify(globalThis.__lnreaderSearch)').value,
      );
      final status = settled?['status']?.toString();
      if (status != null && status != 'pending') {
        return _decodeSearchResult(settled!);
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }

    return _SearchProbeResult(
      attempted: true,
      succeeded: false,
      error: 'searchNovels() timed out after ${timeout.inSeconds} seconds.',
    );
  }

  _SearchProbeResult _decodeSearchResult(Map<String, dynamic> decoded) {
    final status = decoded['status']?.toString();
    final countValue = decoded['count'];
    final count = countValue is num ? countValue.toInt() : null;
    final results = <LnReaderSearchResult>[];
    final rawResults = decoded['results'];
    if (rawResults is List) {
      for (final raw in rawResults) {
        if (raw is! Map) continue;
        final name = _stringOrNull(raw['name']);
        final path = _stringOrNull(raw['path']);
        if (name == null || path == null) continue;
        results.add(
          LnReaderSearchResult(
            name: name,
            path: path,
            cover: _stringOrNull(raw['cover']),
          ),
        );
      }
    }
    final succeeded = status == 'fulfilled' && count != null && count >= 0;
    return _SearchProbeResult(
      attempted: true,
      succeeded: succeeded,
      resultCount: count,
      results: results,
      error: succeeded
          ? null
          : (decoded['error']?.toString() ??
                'searchNovels() did not settle to a result list.'),
    );
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

  String? _stringOrNull(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }
}

List<String> extractRequiredModules(String source) {
  final modules = <String>{};
  final pattern = RegExp(r'''require\(\s*['"]([^'"]+)['"]\s*\)''');
  for (final match in pattern.allMatches(source)) {
    modules.add(match.group(1)!);
  }
  final result = modules.toList()..sort();
  return result;
}

class _RawBundleResult {
  const _RawBundleResult({required this.executed, this.error});

  final bool executed;
  final String? error;
}

class _RuntimeInstallResult {
  const _RuntimeInstallResult({required this.installed, this.error});

  final bool installed;
  final String? error;
}

class _LoadedPluginResult {
  const _LoadedPluginResult({
    required this.executed,
    this.error,
    this.exportKeys = const <String>[],
    this.methods = const <String, String>{},
    this.missingModules = const <String>[],
    this.id,
    this.name,
    this.site,
    this.version,
    this.initializationSucceeded = false,
    this.initializationError,
  });

  final bool executed;
  final String? error;
  final List<String> exportKeys;
  final Map<String, String> methods;
  final List<String> missingModules;
  final String? id;
  final String? name;
  final String? site;
  final String? version;
  final bool initializationSucceeded;
  final String? initializationError;
}

class _SearchProbeResult {
  const _SearchProbeResult({
    required this.attempted,
    required this.succeeded,
    this.resultCount,
    this.results = const <LnReaderSearchResult>[],
    this.error,
  });

  final bool attempted;
  final bool succeeded;
  final int? resultCount;
  final List<LnReaderSearchResult> results;
  final String? error;
}
