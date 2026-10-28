import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:reader_app/models/app_settings.dart';
import 'package:reader_app/models/hive_adapters.dart';
import 'package:reader_app/models/novel_model.dart';
import 'package:reader_app/models/plugin_model.dart';
import 'package:reader_app/services/lnreader_library_importer.dart';
import 'package:reader_app/services/lnreader_novel_service.dart';
import 'package:reader_app/services/lnreader_plugin_repository.dart';
import 'package:reader_app/services/reader_progress.dart';
import 'package:reader_app/services/storage_service.dart';
import 'package:reader_app/theme/app_theme.dart';
import 'package:reader_app/views/reader/reader_theme.dart';
import 'package:reader_app/views/reader/reader_view.dart';

const _plugin = PluginModel(
  id: 7,
  name: 'Atsumaru',
  packageName: 'lnreader.atsumaru',
  version: '1.0.1',
  baseUrl: 'https://atsu.moe',
  isInstalled: true,
  metadata: <String, dynamic>{
    LnReaderPluginRepository.metadataId: 'atsumaru',
    LnReaderPluginRepository.metadataBundleSource: 'bundle',
  },
);

const _chapters = <LnReaderChapter>[
  LnReaderChapter(name: 'Chapter One', path: 'novel/ch-1', chapterNumber: 1),
  LnReaderChapter(
    name: 'Chapter Two: A Long Road',
    path: 'novel/ch-2',
    chapterNumber: 2,
  ),
  LnReaderChapter(
    name: 'Chapter Three: The Return',
    path: 'novel/ch-3',
    chapterNumber: 3,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<NovelModel> novelsBox;
  late Box<AppSettings> settingsBox;
  late String fixtureHtml;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_view_test_');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    novelsBox = await Hive.openBox<NovelModel>('reader_novels');
    settingsBox = await Hive.openBox<AppSettings>('reader_settings_box');
    fixtureHtml = await File('test/fixtures/reader_chapter.html')
        .readAsString();
  });

  setUp(() async {
    await novelsBox.clear();
    await settingsBox.clear();
    await novelsBox.put('novel-key', _novel());
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  _MemoryProgressStore memoryProgress() {
    return _MemoryProgressStore(
      box: novelsBox,
      key: 'novel-key',
      fallbackNovel: novelsBox.get('novel-key')!,
    );
  }

  Widget app(
    _FakeReaderApi api, {
    ReaderProgressStore? progressStore,
    _SettingsRecorder? settingsRecorder,
    Duration progressDebounce = const Duration(milliseconds: 30),
  }) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        return AppTheme.textScaleBuilder(context, child);
      },
      home: ReaderView(
        novel: novelsBox.get('novel-key')!,
        plugin: _plugin,
        novelsBox: novelsBox,
        settingsBox: settingsBox,
        novelKey: null,
        api: api,
        progressDebounce: progressDebounce,
        settingsDebounce: const Duration(milliseconds: 30),
        progressStore: progressStore,
        persistChapterList: false,
        persistSettings: settingsRecorder?.save,
      ),
    );
  }

  Future<void> pumpReader(
    WidgetTester tester,
    _FakeReaderApi api, {
    ReaderProgressStore? progressStore,
  }) async {
    await tester.pumpWidget(
      app(api, progressStore: progressStore ?? memoryProgress()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
  }

  String selectableText(WidgetTester tester) {
    final widgets = tester.widgetList<SelectableText>(
      find.byType(SelectableText),
    );
    return widgets
        .map((widget) => widget.textSpan?.toPlainText() ?? widget.data ?? '')
        .join('\n');
  }

  Future<void> allowIo(WidgetTester tester, [int ms = 90]) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration(milliseconds: ms));
    });
    await tester.pump();
  }

  testWidgets('shows loading then renders sanitized real chapter content', (
    tester,
  ) async {
    final gate = Completer<LnReaderChapterContent>();
    final api = _FakeReaderApi(
      onChapter: (path) => path == 'novel/ch-1'
          ? gate.future
          : Future<LnReaderChapterContent>.value(
              LnReaderChapterContent(path: path, html: '<p>Other</p>'),
            ),
    );

    await tester.pumpWidget(app(api, progressStore: memoryProgress()));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('reader-loading')),
      findsOneWidget,
    );

    gate.complete(
      LnReaderChapterContent(path: 'novel/ch-1', html: fixtureHtml),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const ValueKey<String>('reader-loading')), findsNothing);
    expect(find.text('Chapter One'), findsWidgets);
    final text = selectableText(tester);
    expect(text, contains('Alice was beginning to get very tired'));
    expect(text, isNot(contains('<p>')));
    expect(text, isNot(contains('window.tracker')));
    expect(text, isNot(contains('Buy coins now')));
    expect(
      find.byKey(const ValueKey<String>('reader-top-bar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('reader-bottom-bar')),
      findsOneWidget,
    );
  });

  testWidgets('shows a retryable error and then recovers', (tester) async {
    var fail = true;
    final api = _FakeReaderApi(
      onChapter: (path) {
        if (fail) {
          throw const LnReaderPluginException('Source unavailable.');
        }
        return Future<LnReaderChapterContent>.value(
          LnReaderChapterContent(path: path, html: fixtureHtml),
        );
      },
    );

    await pumpReader(tester, api);
    expect(find.byKey(const ValueKey<String>('reader-error')), findsOneWidget);
    expect(find.textContaining('Source unavailable.'), findsOneWidget);

    fail = false;
    await tester.tap(find.byKey(const ValueKey<String>('reader-retry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const ValueKey<String>('reader-error')), findsNothing);
    expect(selectableText(tester), contains('Alice was beginning'));
  });

  testWidgets('navigates previous and next chapters and persists position', (
    tester,
  ) async {
    final api = _FakeReaderApi();
    final progress = memoryProgress();
    await pumpReader(tester, api, progressStore: progress);

    expect(find.text('Chapter One'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey<String>('reader-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await allowIo(tester);

    expect(find.text('Chapter Two: A Long Road'), findsWidgets);
    expect(api.requestedPaths, contains('novel/ch-2'));

    await tester.tap(find.byKey(const ValueKey<String>('reader-previous')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await allowIo(tester);

    expect(find.text('Chapter One'), findsWidgets);
    expect(progress.saved?.chapterIndex, 0);
  });

  testWidgets('opens the chapter list, highlights current, and selects', (
    tester,
  ) async {
    final api = _FakeReaderApi();
    await pumpReader(tester, api);

    await tester.tap(find.byKey(const ValueKey<String>('reader-toc')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chapter-list-sheet')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('chapter-list-item-0')),
        matching: find.byIcon(Icons.menu_book_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('chapter-list-item-2')));
    await tester.pumpAndSettle();
    await allowIo(tester);

    expect(find.text('Chapter Three: The Return'), findsWidgets);
    expect(api.requestedPaths, contains('novel/ch-3'));
  });

  testWidgets('applies and persists reader appearance and typography', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await settingsBox.put(
        StorageService.settingsKey,
        AppSettings.defaults().copyWith(fontSize: 18, readerTheme: 'dark'),
      );
    });
    final api = _FakeReaderApi();
    final recorder = _SettingsRecorder();
    await tester.pumpWidget(
      app(api, progressStore: memoryProgress(), settingsRecorder: recorder),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(find.byKey(const ValueKey<String>('reader-settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('reader-theme-sepia')));
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey<String>('reader-font-size')),
      const Offset(140, 0),
    );
    await tester.pump();

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await allowIo(tester);

    final surface = tester.widget<ColoredBox>(
      find.byKey(const ValueKey<String>('reader-surface')),
    );
    expect(surface.color, ReaderPalette.resolve('sepia').background);

    final firstSelectable = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .first;
    expect(firstSelectable.textSpan?.style?.fontSize, greaterThan(18));

    final stored = recorder.saved!;
    expect(stored.readerTheme, 'sepia');
    expect(stored.fontSize, greaterThan(18));
  });

  testWidgets('restores saved chapter and scroll position and saves next', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await novelsBox.put(
        'novel-key',
        _novel(
          lastReadChapter: 2,
          metadata: <String, dynamic>{
            ..._chapterMetadata(),
            ReaderProgressStore.metadataChapterPath: 'novel/ch-2',
            ReaderProgressStore.metadataChapterIndex: 1,
            ReaderProgressStore.metadataScrollFraction: 0.55,
            ReaderProgressStore.metadataScrollOffset: 300.0,
          },
        ),
      );
    });
    final api = _FakeReaderApi(longChapters: true);
    final progress = memoryProgress();
    await tester.pumpWidget(app(api, progressStore: progress));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('Chapter Two: A Long Road'), findsWidgets);
    final list = tester.widget<ListView>(
      find.byKey(const ValueKey<String>('reader-content-novel/ch-2')),
    );
    expect(list.controller!.offset, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey<String>('reader-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await allowIo(tester, 120);
    await allowIo(tester, 120);

    expect(progress.saved?.chapterIndex, 2);
    expect(progress.saved?.chapterPath, 'novel/ch-3');
  });

  testWidgets('reset restores reader defaults', (tester) async {
    await tester.runAsync(() async {
      await settingsBox.put(
        StorageService.settingsKey,
        AppSettings.defaults().copyWith(
          readerTheme: 'sepia',
          fontSize: 26,
          readerTextAlign: 'justify',
          readerShowProgress: false,
        ),
      );
    });
    final api = _FakeReaderApi();
    final recorder = _SettingsRecorder();
    await tester.pumpWidget(
      app(api, progressStore: memoryProgress(), settingsRecorder: recorder),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(find.byKey(const ValueKey<String>('reader-settings')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('reader-reset-defaults')),
    );
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await allowIo(tester);

    final defaults = AppSettings.defaults();
    final stored = recorder.saved!;
    expect(stored.readerTheme, defaults.readerTheme);
    expect(stored.fontSize, defaults.fontSize);
    expect(stored.readerTextAlign, defaults.readerTextAlign);
    expect(stored.readerShowProgress, defaults.readerShowProgress);
  });

  testWidgets('fits a small screen at large text scale without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _FakeReaderApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          );
        },
        home: ReaderView(
          novel: novelsBox.get('novel-key')!,
          plugin: _plugin,
          novelsBox: novelsBox,
          settingsBox: settingsBox,
          novelKey: null,
          api: api,
          progressDebounce: const Duration(milliseconds: 30),
          progressStore: memoryProgress(),
          persistChapterList: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('Chapter One'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey<String>('reader-toc')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden chrome can be restored with a content tap and back', (
    tester,
  ) async {
    final api = _FakeReaderApi();
    await pumpReader(tester, api);

    await tester.tapAt(const Offset(180, 400));
    await tester.pump(const Duration(milliseconds: 200));

    final topBar = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byKey(const ValueKey<String>('reader-top-bar')),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(topBar.ignoring, isTrue);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(const Offset(790, 300));
    await tester.pump(const Duration(milliseconds: 200));
    final restored = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byKey(const ValueKey<String>('reader-top-bar')),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(restored.ignoring, isFalse);
  });
}

class _SettingsRecorder {
  AppSettings? saved;

  Future<void> save(AppSettings settings) async {
    saved = settings;
  }
}

class _MemoryProgressStore extends ReaderProgressStore {
  _MemoryProgressStore({
    required super.box,
    required super.key,
    required super.fallbackNovel,
  });

  ReaderPosition? saved;

  @override
  void record(ReaderPosition position) {
    saved = position;
  }

  @override
  Future<void> saveNow(ReaderPosition position) async {
    saved = position;
  }

  @override
  Future<void> flush() async {}

  @override
  void dispose() {}
}

NovelModel _novel({int lastReadChapter = 0, Map<String, dynamic>? metadata}) {
  return NovelModel(
    id: 1,
    title: 'The Reading Room',
    sourceId: 7,
    sourceName: 'Atsumaru',
    author: 'Test Author',
    chapterCount: _chapters.length,
    lastReadChapter: lastReadChapter,
    dateAdded: DateTime(2026, 1, 1),
    metadata: metadata ?? _chapterMetadata(),
  );
}

Map<String, dynamic> _chapterMetadata() {
  return <String, dynamic>{
    LnReaderLibraryImporter.metadataNovelPath: 'novel',
    LnReaderLibraryImporter.metadataChapters: _chapters
        .map((chapter) => chapter.toMetadata())
        .toList(growable: false),
  };
}

class _FakeReaderApi implements LnReaderNovelApi {
  _FakeReaderApi({this.onChapter, this.longChapters = false});

  final Future<LnReaderChapterContent> Function(String path)? onChapter;
  final bool longChapters;
  final List<String> requestedPaths = <String>[];

  @override
  Future<List<LnReaderSearchItem>> searchNovels(
    PluginModel plugin,
    String query, {
    int page = 1,
  }) async {
    return const <LnReaderSearchItem>[];
  }

  @override
  Future<LnReaderNovelDetails> parseNovel(
    PluginModel plugin,
    String path,
  ) async {
    return LnReaderNovelDetails(
      name: 'The Reading Room',
      path: path,
      sourceUrl: 'https://atsu.moe/title/novel',
      chapters: _chapters,
    );
  }

  @override
  Future<LnReaderChapterContent> parseChapter(
    PluginModel plugin,
    String path,
  ) async {
    requestedPaths.add(path);
    if (onChapter != null) return onChapter!(path);
    final repeated = longChapters ? 24 : 1;
    final body = List<String>.filled(repeated, _fixtureBody).join();
    return LnReaderChapterContent(path: path, html: '<h2>$path</h2>$body');
  }
}

const _fixtureBody = '''
<p>Alice was beginning to get very tired of sitting by her sister on the bank.</p>
<p>She had peeped into the book her sister was reading, but it had no pictures or conversations in it.</p>
<p>Suddenly a <strong>White Rabbit</strong> with pink eyes ran close by her.</p>
<p>“Curiouser and curiouser!” cried Alice, as the long road opened ahead.</p>
<p>In another moment down went Alice after it, never once considering how in the world she was to get out again.</p>
''';
