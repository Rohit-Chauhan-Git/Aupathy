import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:reader_app/models/hive_adapters.dart';
import 'package:reader_app/models/lnreader_manifest_entry.dart';
import 'package:reader_app/models/plugin_model.dart';
import 'package:reader_app/services/lnreader_http_client.dart';
import 'package:reader_app/services/lnreader_manifest_service.dart';
import 'package:reader_app/services/lnreader_plugin_repository.dart';
import 'package:reader_app/theme/app_theme.dart';
import 'package:reader_app/views/lnreader_repository_view.dart';

const _royalRoad = LnReaderManifestEntry(
  id: 'royalroad',
  name: 'Royal Road',
  site: 'https://www.royalroad.com/',
  lang: 'en',
  version: '2.3.3',
  url: 'https://example.com/royalroad.js',
);

const _novelFull = LnReaderManifestEntry(
  id: 'novelfull',
  name: 'Novel Full',
  site: 'https://novelfull.com/',
  lang: 'en',
  version: '1.2.0',
  url: 'https://example.com/novelfull.js',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<PluginModel> pluginsBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('lnreader_repo_test_');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    pluginsBox = await Hive.openBox<PluginModel>('repo_plugins');
  });

  setUp(() async {
    await pluginsBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('LnReaderPluginRepository', () {
    test('installs a bundle into the existing plugin box', () async {
      final http = _FakeHttpClient(bundle: 'exports.default = {};');
      final repository = LnReaderPluginRepository(httpClient: http);

      final result = await repository.install(
        entry: _royalRoad,
        box: pluginsBox,
      );

      expect(result.bundleBytes, 21);
      expect(result.plugin.id, stableLnReaderPluginId('royalroad'));
      expect(result.plugin.isInstalled, isTrue);
      expect(result.plugin.baseUrl, _royalRoad.site);
      expect(
        result.plugin.metadata[LnReaderPluginRepository.metadataId],
        'royalroad',
      );
      expect(
        result.plugin.metadata[LnReaderPluginRepository.metadataBundleSource],
        'exports.default = {};',
      );
      expect(repository.isInstalled(pluginsBox, 'royalroad'), isTrue);
      expect(pluginsBox.length, 1);
    });

    test('reinstalling updates the same plugin key', () async {
      final repository = LnReaderPluginRepository(
        httpClient: _FakeHttpClient(bundle: 'first'),
      );
      final first = await repository.install(
        entry: _royalRoad,
        box: pluginsBox,
      );
      await pluginsBox.put(
        first.plugin.id,
        first.plugin.copyWith(isEnabled: false),
      );

      final updatedRepository = LnReaderPluginRepository(
        httpClient: _FakeHttpClient(bundle: 'second'),
      );
      final second = await updatedRepository.install(
        entry: _royalRoad,
        box: pluginsBox,
      );

      expect(second.plugin.id, first.plugin.id);
      expect(second.plugin.isEnabled, isFalse);
      expect(pluginsBox.length, 1);
      expect(
        second.plugin.metadata[LnReaderPluginRepository.metadataBundleSource],
        'second',
      );
    });

    test('reports an HTTP bundle failure without writing a plugin', () async {
      final repository = LnReaderPluginRepository(
        httpClient: _FakeHttpClient(bundle: 'missing', statusCode: 404),
      );

      await expectLater(
        repository.install(entry: _royalRoad, box: pluginsBox),
        throwsA(isA<LnReaderPluginInstallException>()),
      );
      expect(pluginsBox.isEmpty, isTrue);
    });

    test('uses different ids for different manifest entries', () {
      expect(
        stableLnReaderPluginId('royalroad'),
        isNot(stableLnReaderPluginId('novelfull')),
      );
    });
  });

  group('LnReaderRepositoryView', () {
    testWidgets('loads, filters, and installs repository plugins', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _FakeRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: LnReaderRepositoryView(
            repository: repository,
            pluginsBox: pluginsBox,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LNReader repository'), findsOneWidget);
      expect(find.text('Royal Road'), findsOneWidget);
      expect(find.text('Novel Full'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'royal');
      await tester.pump();
      expect(find.text('Royal Road'), findsOneWidget);
      expect(find.text('Novel Full'), findsNothing);

      await tester.tap(find.byTooltip('Download Royal Road'));
      await tester.pumpAndSettle();

      expect(repository.installCount, 1);
      expect(find.textContaining('Installed Royal Road'), findsOneWidget);
      expect(find.byTooltip('Installed'), findsWidgets);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('shows an error when the manifest cannot load', (tester) async {
      final repository = _FakeRepository(error: 'Network unavailable.');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: LnReaderRepositoryView(
            repository: repository,
            pluginsBox: pluginsBox,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load the repository'), findsOneWidget);
      expect(find.text('Network unavailable.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}

class _FakeHttpClient implements LnReaderHttpClient {
  _FakeHttpClient({required this.bundle, this.statusCode = 200});

  final String bundle;
  final int statusCode;

  @override
  Future<LnReaderHttpResponse> get(Uri uri) => request(uri);

  @override
  Future<LnReaderHttpResponse> request(
    Uri uri, {
    String method = 'GET',
    Map<String, String> headers = const <String, String>{},
    String? body,
  }) async {
    return LnReaderHttpResponse(statusCode: statusCode, body: bundle, uri: uri);
  }

  @override
  void close() {}
}

class _FakeRepository implements LnReaderRepositoryApi {
  _FakeRepository({this.error});

  final String? error;
  int installCount = 0;

  @override
  Future<LnReaderManifestFetchResult> fetchManifest() async {
    if (error != null) {
      return LnReaderManifestFetchResult(error: error);
    }
    return LnReaderManifestFetchResult(
      manifest: const LnReaderManifest(
        entries: <LnReaderManifestEntry>[_royalRoad, _novelFull],
        issues: <LnReaderManifestIssue>[],
        totalEntries: 2,
      ),
      statusCode: 200,
      uri: LnReaderManifestService.manifestUri,
    );
  }

  @override
  bool isInstalled(Box<PluginModel> box, String entryId) {
    return box.values.any(
      (plugin) =>
          plugin.metadata[LnReaderPluginRepository.metadataId] == entryId,
    );
  }

  @override
  Future<LnReaderPluginInstallResult> install({
    required LnReaderManifestEntry entry,
    required Box<PluginModel> box,
  }) async {
    installCount++;
    final plugin = PluginModel(
      id: stableLnReaderPluginId(entry.id),
      name: entry.name,
      packageName: 'lnreader.${entry.id}',
      version: entry.version,
      baseUrl: entry.site,
      lang: entry.lang,
      isInstalled: true,
      metadata: <String, dynamic>{
        LnReaderPluginRepository.metadataId: entry.id,
      },
    );
    return LnReaderPluginInstallResult(
      entry: entry,
      plugin: plugin,
      bundleBytes: 120,
    );
  }
}
