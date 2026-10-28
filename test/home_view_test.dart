import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:reader_app/models/hive_adapters.dart';
import 'package:reader_app/models/novel_model.dart';
import 'package:reader_app/theme/app_theme.dart';
import 'package:reader_app/views/home_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<NovelModel> novelsBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_library_ui_');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    novelsBox = await Hive.openBox<NovelModel>('novels');
  });

  setUp(() async {
    await novelsBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Widget wrap(Widget child, {double textScale = 1.0}) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, appChild) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: appChild ?? const SizedBox.shrink(),
        );
      },
      home: Scaffold(body: child),
    );
  }

  Future<void> seed(
    WidgetTester tester,
    Map<String, NovelModel> entries,
  ) async {
    await tester.runAsync(() => novelsBox.putAll(entries));
  }

  NovelModel novel({
    required int id,
    required String title,
    String author = 'Test Author',
    String sourceName = 'Test Source',
    int chapterCount = 0,
    int lastReadChapter = 0,
    DateTime? lastReadAt,
    List<String> genres = const <String>[],
  }) {
    return NovelModel(
      id: id,
      title: title,
      sourceId: 1,
      sourceName: sourceName,
      author: author,
      chapterCount: chapterCount,
      lastReadChapter: lastReadChapter,
      lastReadAt: lastReadAt,
      dateAdded: DateTime(2026, 1, id),
      genres: genres,
    );
  }

  testWidgets('shows a useful empty library state', (tester) async {
    await tester.pumpWidget(wrap(HomeView(novelsBox: novelsBox)));
    await tester.pump();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('No novels yet'), findsOneWidget);
  });

  testWidgets('renders novels, reading progress, and filters search results', (
    tester,
  ) async {
    // Hive performs real file I/O; awaiting it directly inside testWidgets
    // would hang because the test body runs in a FakeAsync zone.
    await tester.runAsync(() async {
      await novelsBox.putAll(<String, NovelModel>{
        'aria': novel(
          id: 1,
          title: 'Aria of the Sea',
          author: 'Mira Vale',
          chapterCount: 10,
          lastReadChapter: 2,
          lastReadAt: DateTime(2026, 3, 2),
          genres: const <String>['Fantasy', 'Adventure'],
        ),
        'long-read': novel(
          id: 2,
          title: 'The Long Read',
          author: 'Sam Rivers',
          chapterCount: 24,
          lastReadChapter: 24,
          lastReadAt: DateTime(2026, 3, 1),
        ),
      });
    });

    await tester.pumpWidget(wrap(HomeView(novelsBox: novelsBox)));
    await tester.pump();

    expect(find.text('Aria of the Sea'), findsOneWidget);
    expect(find.text('The Long Read'), findsOneWidget);
    expect(find.text('Chapter 2 of 10'), findsOneWidget);
    expect(find.text('Mira Vale · Test Source'), findsOneWidget);
    expect(find.text('Fantasy · Adventure'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'aria');
    await tester.pump();

    expect(find.text('Aria of the Sea'), findsOneWidget);
    expect(find.text('The Long Read'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nothing matches');
    await tester.pump();

    expect(find.text('No novels found'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await tester.pump();

    expect(find.text('Aria of the Sea'), findsOneWidget);
    expect(find.text('The Long Read'), findsOneWidget);
  });

  testWidgets('shows a graceful error when storage is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const HomeView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load your library'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('search matches authors and sources case-insensitively', (
    tester,
  ) async {
    await seed(tester, <String, NovelModel>{
      'aria': novel(id: 1, title: 'Aria of the Sea', author: 'Mira Vale'),
      'ember': novel(
        id: 2,
        title: 'Ember Roads',
        author: 'Cole Ash',
        sourceName: 'Lantern Archive',
      ),
    });

    await tester.pumpWidget(wrap(HomeView(novelsBox: novelsBox)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'MIRA');
    await tester.pump();

    expect(find.text('Aria of the Sea'), findsOneWidget);
    expect(find.text('Ember Roads'), findsNothing);

    await tester.enterText(find.byType(TextField), 'lantern');
    await tester.pump();

    expect(find.text('Ember Roads'), findsOneWidget);
    expect(find.text('Aria of the Sea'), findsNothing);
  });

  testWidgets('search field clear action restores the full library', (
    tester,
  ) async {
    await seed(tester, <String, NovelModel>{
      'aria': novel(id: 1, title: 'Aria of the Sea'),
      'ember': novel(id: 2, title: 'Ember Roads'),
    });

    await tester.pumpWidget(wrap(HomeView(novelsBox: novelsBox)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'aria');
    await tester.pump();
    expect(find.text('Ember Roads'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    expect(find.text('Aria of the Sea'), findsOneWidget);
    expect(find.text('Ember Roads'), findsOneWidget);
  });

  testWidgets(
    'reflects Hive insertions and deletions during an active search',
    (tester) async {
      await seed(tester, <String, NovelModel>{
        'aria': novel(id: 1, title: 'Aria of the Sea'),
      });

      await tester.pumpWidget(wrap(HomeView(novelsBox: novelsBox)));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'aria');
      await tester.pump();
      expect(find.text('Aria of the Sea'), findsOneWidget);

      await tester.runAsync(
        () =>
            novelsBox.put('aria-returns', novel(id: 2, title: 'Aria Returns')),
      );
      await tester.pump();

      expect(find.text('Aria of the Sea'), findsOneWidget);
      expect(find.text('Aria Returns'), findsOneWidget);

      await tester.runAsync(() => novelsBox.delete('aria'));
      await tester.pump();

      expect(find.text('Aria of the Sea'), findsNothing);
      expect(find.text('Aria Returns'), findsOneWidget);

      await tester.runAsync(() => novelsBox.delete('aria-returns'));
      await tester.pump();

      expect(find.text('No novels found'), findsOneWidget);
    },
  );

  testWidgets('renders fallbacks when optional metadata is missing', (
    tester,
  ) async {
    await seed(tester, <String, NovelModel>{
      'untitled': novel(
        id: 1,
        title: 'Quiet Pages',
        author: '',
        sourceName: '',
      ),
    });

    await tester.pumpWidget(wrap(HomeView(novelsBox: novelsBox)));
    await tester.pump();

    expect(find.text('Quiet Pages'), findsOneWidget);
    expect(find.text('Unknown author'), findsOneWidget);
    expect(find.text('No chapters yet'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('shows completed novels without fabricating progress', (
    tester,
  ) async {
    await seed(tester, <String, NovelModel>{
      'done': novel(
        id: 1,
        title: 'Finished Book',
        chapterCount: 12,
        lastReadChapter: 12,
      ),
    });

    await tester.pumpWidget(wrap(HomeView(novelsBox: novelsBox)));
    await tester.pump();

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('retry keeps the error state and does not throw', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const HomeView()),
    );
    await tester.pump();

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(find.text('Could not load your library'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removes its Hive listener when disposed', (tester) async {
    await seed(tester, <String, NovelModel>{
      'aria': novel(id: 1, title: 'Aria of the Sea'),
    });

    await tester.pumpWidget(wrap(HomeView(novelsBox: novelsBox)));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.runAsync(
      () => novelsBox.put('ember', novel(id: 2, title: 'Ember Roads')),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out without overflow on a small screen at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await seed(tester, <String, NovelModel>{
      'aria': novel(
        id: 1,
        title: 'A Very Long Novel Title That Wraps Across Lines',
        author: 'Mira Vale With A Long Name',
        sourceName: 'A Source With A Long Name',
        chapterCount: 120,
        lastReadChapter: 37,
        genres: const <String>['Fantasy', 'Adventure', 'Mystery'],
      ),
    });

    await tester.pumpWidget(
      wrap(HomeView(novelsBox: novelsBox), textScale: 2.0),
    );
    await tester.pump();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(
      find.text('A Very Long Novel Title That Wraps Across Lines'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
