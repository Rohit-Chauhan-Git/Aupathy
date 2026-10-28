import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:reader_app/models/hive_adapters.dart';
import 'package:reader_app/models/novel_model.dart';
import 'package:reader_app/models/plugin_model.dart';
import 'package:reader_app/services/lnreader_library_importer.dart';
import 'package:reader_app/services/lnreader_novel_service.dart';
import 'package:reader_app/services/lnreader_plugin_repository.dart';
import 'package:reader_app/theme/app_theme.dart';
import 'package:reader_app/views/lnreader_source_search_view.dart';

const _plugin = PluginModel(
  id: 7,
  name: 'Atsumaru',
  packageName: 'lnreader.atsumaru',
  version: '1.0.1',
  baseUrl: 'https://atsu.moe',
  lang: 'English',
  isInstalled: true,
  metadata: <String, dynamic>{
    LnReaderPluginRepository.metadataId: 'atsumaru',
    LnReaderPluginRepository.metadataBundleSource: 'plugin-source',
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<NovelModel> novelsBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('lnreader_flow_test_');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    novelsBox = await Hive.openBox<NovelModel>('flow_novels');
  });

  setUp(() async {
    await novelsBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Widget app(LnReaderNovelApi api) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: LnReaderSourceSearchView(
        plugin: _plugin,
        novelsBox: novelsBox,
        service: api,
      ),
    );
  }

  testWidgets('searches, opens details, and imports into the Library', (
    tester,
  ) async {
    final api = _FakeNovelApi();
    await tester.pumpWidget(app(api));
    await tester.pump();

    expect(find.text('Find a novel'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('source-search-field')),
      'shadow',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Shadow Slave'), findsOneWidget);
    expect(find.text('Atsumaru'), findsWidgets);
    expect(find.text('Load more results'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('load-more-results')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.lastPage, 2);
    expect(find.text('End of results'), findsOneWidget);
    expect(find.text('Shadow Slave'), findsOneWidget);

    await tester.tap(find.text('Shadow Slave'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('A real synopsis.'), findsOneWidget);
    expect(find.text('Guiltythree'), findsOneWidget);
    expect(find.text('Chapters'), findsOneWidget);
    expect(find.text('Chapter 1'), findsWidgets);
    expect(find.text('Add to Library'), findsOneWidget);

    final import = find.byKey(const ValueKey<String>('import-novel'));
    await tester.ensureVisible(import);
    await tester.runAsync(() async {
      await tester.tap(import);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(novelsBox.length, 1);
    final stored = novelsBox.values.single;
    expect(stored.title, 'Shadow Slave');
    expect(stored.chapterCount, 2);
    expect(
      stored.metadata[LnReaderLibraryImporter.metadataChapters],
      hasLength(2),
    );
    expect(find.text('Update library entry'), findsOneWidget);
    expect(find.textContaining('Added Shadow Slave'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(import);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(novelsBox.length, 1);
  });

  testWidgets('shows an honest empty state for no results', (tester) async {
    final api = _FakeNovelApi(searchResults: const <LnReaderSearchItem>[]);
    await tester.pumpWidget(app(api));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey<String>('source-search-field')),
      'nothing',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No novels found'), findsOneWidget);
    expect(find.text('No results matched "nothing".'), findsOneWidget);
  });

  testWidgets('shows a retryable error state when the source fails', (
    tester,
  ) async {
    final api = _FakeNovelApi(
      searchError: const LnReaderPluginException(
        'Royal Road is showing a bot check. HTTP 403.',
      ),
    );
    await tester.pumpWidget(app(api));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey<String>('source-search-field')),
      'shadow',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Search failed'), findsOneWidget);
    expect(find.textContaining('bot check'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    api.searchError = null;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Shadow Slave'), findsOneWidget);
  });
}

class _FakeNovelApi implements LnReaderNovelApi {
  _FakeNovelApi({
    this.searchResults = const <LnReaderSearchItem>[
      LnReaderSearchItem(
        name: 'Shadow Slave',
        path: '8kL3',
        author: 'Guiltythree',
      ),
    ],
    this.searchError,
  });

  final List<LnReaderSearchItem> searchResults;
  LnReaderPluginException? searchError;
  int lastPage = 0;
  String? lastQuery;

  @override
  Future<List<LnReaderSearchItem>> searchNovels(
    PluginModel plugin,
    String query, {
    int page = 1,
  }) async {
    lastPage = page;
    lastQuery = query;
    if (searchError != null) throw searchError!;
    return page == 1 ? searchResults : const <LnReaderSearchItem>[];
  }

  @override
  Future<LnReaderNovelDetails> parseNovel(
    PluginModel plugin,
    String path,
  ) async {
    return LnReaderNovelDetails(
      name: 'Shadow Slave',
      path: path,
      sourceUrl: 'https://atsu.moe/title/8kL3',
      summary: 'A real synopsis.',
      author: 'Guiltythree',
      genres: const <String>['Fantasy', 'Action'],
      status: 'Ongoing',
      chapters: const <LnReaderChapter>[
        LnReaderChapter(name: 'Chapter 1', path: '8kL3/ch-1', chapterNumber: 1),
        LnReaderChapter(name: 'Chapter 2', path: '8kL3/ch-2', chapterNumber: 2),
      ],
    );
  }

  @override
  Future<LnReaderChapterContent> parseChapter(
    PluginModel plugin,
    String path,
  ) async {
    return LnReaderChapterContent(path: path, html: '<p>Chapter text.</p>');
  }
}
