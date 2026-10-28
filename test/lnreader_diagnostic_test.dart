import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/models/lnreader_manifest_entry.dart';
import 'package:reader_app/services/lnreader_diagnostic_service.dart';
import 'package:reader_app/services/lnreader_http_client.dart';
import 'package:reader_app/services/lnreader_manifest_service.dart';
import 'package:reader_app/services/lnreader_runtime_probe.dart';
import 'package:reader_app/theme/app_theme.dart';
import 'package:reader_app/views/lnreader_diagnostics_view.dart';

const _atsumaru = LnReaderManifestEntry(
  id: 'atsumaru',
  name: 'Atsumaru',
  site: 'https://atsu.moe',
  lang: 'en',
  version: '1.0.1',
  url: 'https://example.com/atsumaru.js',
);

const _royalRoad = LnReaderManifestEntry(
  id: 'royalroad',
  name: 'Royal Road',
  site: 'https://www.royalroad.com',
  lang: 'en',
  version: '1.0.0',
  url: 'https://example.com/royalroad.js',
);

void main() {
  group('LnReaderDiagnosticService', () {
    test('runs every step through the LNReader runtime', () async {
      final http = _FakeHttpClient(
        manifest: _manifestJson(),
        bundle: 'function royalroad() { return require("@libs/fetch"); }',
      );
      final factory = _FakeRuntimeFactory();
      final service = LnReaderDiagnosticService(
        httpClient: http,
        runtimeFactory: factory,
      );

      final report = await service.run();

      expect(
        report.statusFor(LnReaderDiagnosticService.manifestStep),
        LnReaderDiagnosticStatus.pass,
      );
      expect(
        report.statusFor(LnReaderDiagnosticService.validationStep),
        LnReaderDiagnosticStatus.warning,
      );
      expect(
        report.statusFor(LnReaderDiagnosticService.bundleStep),
        LnReaderDiagnosticStatus.pass,
      );
      expect(
        report.statusFor(LnReaderDiagnosticService.engineStep),
        LnReaderDiagnosticStatus.pass,
      );
      expect(
        report.statusFor(LnReaderDiagnosticService.executionStep),
        LnReaderDiagnosticStatus.pass,
      );
      expect(
        report.statusFor(LnReaderDiagnosticService.initializationStep),
        LnReaderDiagnosticStatus.pass,
      );
      expect(
        report.statusFor(LnReaderDiagnosticService.searchStep),
        LnReaderDiagnosticStatus.pass,
      );

      expect(report.selectedPlugin?.id, 'royalroad');
      expect(report.bundleBytes, greaterThan(0));
      expect(report.runtime?.rawBundleExecuted, isFalse);
      expect(report.runtime?.bundleExecuted, isTrue);
      expect(report.runtime?.initializationSucceeded, isTrue);
      expect(report.runtime?.searchSucceeded, isTrue);
      expect(report.runtime?.searchResultCount, 2);
      expect(report.runtime?.searchResults.first.name, 'Shadow Slave');
      expect(report.runtime?.missingRuntimeApis, isEmpty);
      expect(http.requests, hasLength(2));
      expect(http.requests.first, LnReaderManifestService.manifestUri);
      expect(factory.sessions.single.disposed, isTrue);
    });

    test('stops after an HTTP manifest failure', () async {
      final http = _FakeHttpClient(
        manifest: 'unavailable',
        manifestStatus: 503,
      );
      final factory = _FakeRuntimeFactory();
      final service = LnReaderDiagnosticService(
        httpClient: http,
        runtimeFactory: factory,
      );

      final report = await service.run();

      expect(
        report.statusFor(LnReaderDiagnosticService.manifestStep),
        LnReaderDiagnosticStatus.fail,
      );
      expect(
        report.statusFor(LnReaderDiagnosticService.bundleStep),
        LnReaderDiagnosticStatus.fail,
      );
      expect(report.steps.last.detail, contains('Blocked'));
      expect(http.requests, hasLength(1));
      expect(factory.sessions, isEmpty);
    });

    test(
      'reports a manifest parsing error without downloading a bundle',
      () async {
        final http = _FakeHttpClient(manifest: 'not-json');
        final factory = _FakeRuntimeFactory();
        final service = LnReaderDiagnosticService(
          httpClient: http,
          runtimeFactory: factory,
        );

        final report = await service.run();

        expect(
          report.statusFor(LnReaderDiagnosticService.manifestStep),
          LnReaderDiagnosticStatus.fail,
        );
        expect(report.manifestError, contains('valid JSON'));
        expect(http.requests, hasLength(1));
      },
    );

    test(
      'reports an unavailable JavaScript engine and blocks later probes',
      () async {
        final http = _FakeHttpClient(
          manifest: _manifestJson(),
          bundle: 'plugin',
        );
        final factory = _FakeRuntimeFactory(fail: true);
        final service = LnReaderDiagnosticService(
          httpClient: http,
          runtimeFactory: factory,
        );

        final report = await service.run();

        expect(
          report.statusFor(LnReaderDiagnosticService.engineStep),
          LnReaderDiagnosticStatus.fail,
        );
        expect(
          report.statusFor(LnReaderDiagnosticService.executionStep),
          LnReaderDiagnosticStatus.fail,
        );
        expect(
          report.statusFor(LnReaderDiagnosticService.searchStep),
          LnReaderDiagnosticStatus.fail,
        );
        expect(
          report.steps.last.detail,
          contains('Blocked by JavaScript engine'),
        );
        expect(report.runtime?.engineAvailable, isFalse);
      },
    );

    test('uses an explicitly requested plugin id', () async {
      final http = _FakeHttpClient(
        manifest: jsonEncode(<Object>[
          <String, Object>{
            'id': 'royalroad',
            'name': 'Royal Road',
            'site': 'https://www.royalroad.com',
            'lang': 'en',
            'version': '1',
            'url': 'https://example.com/royalroad.js',
          },
          <String, Object>{
            'id': 'atsumaru',
            'name': 'Atsumaru',
            'site': 'https://atsu.moe',
            'lang': 'en',
            'version': '1',
            'url': 'https://example.com/atsumaru.js',
          },
        ]),
        bundle: 'plugin',
      );
      final service = LnReaderDiagnosticService(
        httpClient: http,
        runtimeFactory: _FakeRuntimeFactory(),
      );

      final report = await service.run(pluginId: 'atsumaru');

      expect(report.selectedPlugin?.id, 'atsumaru');
      expect(http.requests.last.toString(), 'https://example.com/atsumaru.js');
    });

    test(
      'falls back to the first plugin when the preferred id is absent',
      () async {
        final http = _FakeHttpClient(
          manifest: jsonEncode(<Object>[
            <String, Object>{
              'id': 'other',
              'name': 'Other',
              'site': 'https://other.example',
              'lang': 'en',
              'version': '2',
              'url': 'https://example.com/other.js',
            },
          ]),
          bundle: 'plugin',
        );
        final service = LnReaderDiagnosticService(
          httpClient: http,
          runtimeFactory: _FakeRuntimeFactory(),
        );

        final report = await service.run();

        expect(report.selectedPlugin?.id, 'other');
        expect(http.requests.last.toString(), 'https://example.com/other.js');
      },
    );

    test('extracts required CommonJS modules in stable order', () {
      final modules = extractRequiredModules(
        'require("@libs/fetch"); require("cheerio"); '
        'require("@libs/fetch"); require("dayjs")',
      );
      expect(modules, <String>['@libs/fetch', 'cheerio', 'dayjs']);
    });
  });

  group('LnReaderDiagnosticsView', () {
    testWidgets('shows live statuses and the completed report', (tester) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _FakeDiagnosticService();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: LnReaderDiagnosticsView(service: service, autoRun: false),
        ),
      );

      expect(find.text('LNReader compatibility'), findsOneWidget);
      expect(find.text('Run diagnostics'), findsOneWidget);

      await tester.tap(find.text('Run diagnostics'));
      await tester.pumpAndSettle();

      expect(find.text('PASS'), findsWidgets);
      expect(find.text('WARN'), findsWidgets);
      expect(find.text('FAIL'), findsNothing);
      expect(find.textContaining('Royal Road · v1.0.0'), findsOneWidget);
      expect(find.text('Live search results'), findsOneWidget);
      expect(find.text('Shadow Slave'), findsOneWidget);
      expect(find.text('Runtime contract'), findsOneWidget);
      expect(find.textContaining('Manifest entries'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('manifest-entry-royalroad')),
        findsOneWidget,
      );
    });

    testWidgets('chooses another manifest plugin and reruns', (tester) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _FakeDiagnosticService();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: LnReaderDiagnosticsView(service: service),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('choose-plugin')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a plugin'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('plugin-picker-search')),
        'atsu',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('plugin-choice-atsumaru')),
      );
      await tester.pumpAndSettle();

      expect(service.runCount, 2);
      expect(service.requestedPluginIds.last, 'atsumaru');
    });

    testWidgets('auto-runs diagnostics when opened', (tester) async {
      final service = _FakeDiagnosticService();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: LnReaderDiagnosticsView(service: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(service.runCount, 1);
      expect(find.text('PASS'), findsWidgets);
    });
  });
}

String _manifestJson() {
  return jsonEncode(<Object>[
    <String, Object>{
      'id': 'royalroad',
      'name': 'Royal Road',
      'site': 'https://www.royalroad.com',
      'lang': 'en',
      'version': '1.0.0',
      'url': 'https://example.com/royalroad.js',
    },
    <String, Object>{
      'id': 'invalid',
      'name': 'Invalid',
      'site': 'not a url',
      'lang': 'en',
      'version': '1.0.0',
      'url': 'https://example.com/invalid.js',
    },
  ]);
}

class _FakeHttpClient implements LnReaderHttpClient {
  _FakeHttpClient({
    required this.manifest,
    this.manifestStatus = 200,
    this.bundle = '',
  });

  final String manifest;
  final int manifestStatus;
  final String bundle;
  final List<Uri> requests = <Uri>[];
  bool closed = false;

  @override
  Future<LnReaderHttpResponse> get(Uri uri) => request(uri);

  @override
  Future<LnReaderHttpResponse> request(
    Uri uri, {
    String method = 'GET',
    Map<String, String> headers = const <String, String>{},
    String? body,
  }) async {
    requests.add(uri);
    if (uri == LnReaderManifestService.manifestUri) {
      return LnReaderHttpResponse(
        statusCode: manifestStatus,
        body: manifest,
        uri: uri,
      );
    }
    return LnReaderHttpResponse(statusCode: 200, body: bundle, uri: uri);
  }

  @override
  void close() {
    closed = true;
  }
}

class _FakeRuntimeFactory implements LnReaderScriptRuntimeFactory {
  _FakeRuntimeFactory({this.fail = false});

  final bool fail;
  final List<_FakeSession> sessions = <_FakeSession>[];

  @override
  LnReaderScriptSession create() {
    if (fail) throw StateError('QuickJS unavailable in test');
    final session = _FakeSession();
    sessions.add(session);
    return session;
  }
}

class _FakeSession implements LnReaderScriptSession {
  bool disposed = false;

  @override
  LnReaderScriptEvaluation evaluate(String code) {
    if (code.trim() == '1 + 1') {
      return const LnReaderScriptEvaluation(value: '2', isError: false);
    }
    if (code.contains('__lnreaderRaw')) {
      return LnReaderScriptEvaluation(
        value: jsonEncode(<String, Object>{
          'ok': false,
          'error': 'LNREADER_MISSING_MODULE:@libs/fetch',
        }),
        isError: false,
      );
    }
    if (code.contains('__lnreaderRuntimeInstalled')) {
      return const LnReaderScriptEvaluation(
        value: 'lnreader-runtime-ready',
        isError: false,
      );
    }
    if (code.contains('__lnreaderLoadPlugin(')) {
      return LnReaderScriptEvaluation(
        value: jsonEncode(<String, Object?>{
          'ok': true,
          'keys': <String>['default'],
          'methods': <String, String>{
            'searchNovels': 'function',
            'parseNovel': 'function',
            'parseChapter': 'function',
            'popularNovels': 'function',
          },
          'id': 'royalroad',
          'name': 'Royal Road',
          'site': 'https://www.royalroad.com',
          'version': '1.0.0',
          'hasCandidate': true,
          'missingModules': <String>[],
        }),
        isError: false,
      );
    }
    if (code.contains('JSON.stringify(globalThis.__lnreaderSearch)')) {
      return LnReaderScriptEvaluation(
        value: jsonEncode(<String, Object>{
          'status': 'fulfilled',
          'count': 2,
          'results': <Map<String, String>>[
            <String, String>{
              'name': 'Shadow Slave',
              'path': '/fiction/106700-shadow-slave',
              'cover': 'https://example.com/cover.jpg',
            },
            <String, String>{
              'name': 'Second Result',
              'path': '/fiction/2-second-result',
              'cover': '',
            },
          ],
        }),
        isError: false,
      );
    }
    if (code.contains('__lnreaderSearch')) {
      return const LnReaderScriptEvaluation(
        value: '{"status":"pending"}',
        isError: false,
      );
    }
    return const LnReaderScriptEvaluation(value: 'undefined', isError: false);
  }

  @override
  void drainMicrotasks() {}

  @override
  void dispose() {
    disposed = true;
  }
}

class _FakeDiagnosticService extends LnReaderDiagnosticService {
  _FakeDiagnosticService() : super(httpClient: _FakeHttpClient(manifest: '[]'));

  int runCount = 0;
  final List<String?> requestedPluginIds = <String?>[];

  @override
  Future<LnReaderDiagnosticReport> run({
    void Function(LnReaderDiagnosticStep step)? onStep,
    String? pluginId,
  }) async {
    runCount++;
    requestedPluginIds.add(pluginId);
    const steps = <LnReaderDiagnosticStep>[
      LnReaderDiagnosticStep(
        label: LnReaderDiagnosticService.manifestStep,
        status: LnReaderDiagnosticStatus.pass,
        detail: 'HTTP 200 · 2 raw entries.',
      ),
      LnReaderDiagnosticStep(
        label: LnReaderDiagnosticService.validationStep,
        status: LnReaderDiagnosticStatus.warning,
        detail: '1 valid of 2 entries.',
      ),
      LnReaderDiagnosticStep(
        label: LnReaderDiagnosticService.selectionStep,
        status: LnReaderDiagnosticStatus.pass,
        detail: 'Royal Road (royalroad) v1.0.0 · en.',
      ),
      LnReaderDiagnosticStep(
        label: LnReaderDiagnosticService.bundleStep,
        status: LnReaderDiagnosticStatus.pass,
        detail: 'Downloaded 120 bytes.',
      ),
      LnReaderDiagnosticStep(
        label: LnReaderDiagnosticService.engineStep,
        status: LnReaderDiagnosticStatus.pass,
        detail: 'QuickJS started.',
      ),
      LnReaderDiagnosticStep(
        label: LnReaderDiagnosticService.executionStep,
        status: LnReaderDiagnosticStatus.pass,
        detail: 'Executed through the LNReader module loader.',
      ),
      LnReaderDiagnosticStep(
        label: LnReaderDiagnosticService.initializationStep,
        status: LnReaderDiagnosticStatus.pass,
        detail: 'Plugin initialized with searchNovels/parseNovel.',
      ),
      LnReaderDiagnosticStep(
        label: LnReaderDiagnosticService.searchStep,
        status: LnReaderDiagnosticStatus.pass,
        detail: 'searchNovels() returned 2 results.',
      ),
    ];
    for (final step in steps) {
      onStep?.call(step);
    }
    return const LnReaderDiagnosticReport(
      steps: steps,
      manifest: LnReaderManifest(
        entries: <LnReaderManifestEntry>[_royalRoad, _atsumaru],
        issues: <LnReaderManifestIssue>[
          LnReaderManifestIssue(index: 1, message: 'Invalid site URL.'),
        ],
        totalEntries: 2,
      ),
      selectedPlugin: _royalRoad,
      runtime: LnReaderRuntimeProbeResult(
        engineAvailable: true,
        engineName: 'QuickJS',
        rawBundleExecuted: false,
        rawBundleError: 'LNREADER_MISSING_MODULE:@libs/fetch',
        bundleExecuted: true,
        initializationSucceeded: true,
        searchAttempted: true,
        searchSucceeded: true,
        searchResultCount: 2,
        searchResults: <LnReaderSearchResult>[
          LnReaderSearchResult(
            name: 'Shadow Slave',
            path: '/fiction/106700-shadow-slave',
          ),
        ],
        requiredModules: <String>['@libs/fetch'],
        missingRuntimeApis: <String>[],
      ),
      bundleBytes: 120,
    );
  }
}
