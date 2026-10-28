import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:reader_app/models/hive_adapters.dart';
import 'package:reader_app/models/novel_model.dart';
import 'package:reader_app/models/plugin_model.dart';
import 'package:reader_app/services/lnreader_library_importer.dart';
import 'package:reader_app/services/lnreader_novel_service.dart';
import 'package:reader_app/services/lnreader_plugin_repository.dart';

const _plugin = PluginModel(
  id: 7,
  name: 'Atsumaru',
  packageName: 'lnreader.atsumaru',
  version: '1.0.1',
  baseUrl: 'https://atsu.moe',
  isInstalled: true,
  metadata: <String, dynamic>{
    LnReaderPluginRepository.metadataId: 'atsumaru',
    LnReaderPluginRepository.metadataBundleSource: 'plugin-source',
  },
);

const _otherPlugin = PluginModel(
  id: 9,
  name: 'Other Source',
  packageName: 'lnreader.other',
  version: '1.0.0',
  baseUrl: 'https://other.example',
  isInstalled: true,
  metadata: <String, dynamic>{
    LnReaderPluginRepository.metadataId: 'other',
    LnReaderPluginRepository.metadataBundleSource: 'other-source',
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<NovelModel> novelsBox;
  const importer = LnReaderLibraryImporter();

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('lnreader_import_test_');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    novelsBox = await Hive.openBox<NovelModel>('import_novels');
  });

  setUp(() async {
    await novelsBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('imports a novel into the existing Hive library', () async {
    final timestamp = DateTime(2026, 10, 28, 12);
    final result = await importer.import(
      box: novelsBox,
      plugin: _plugin,
      details: _details(chapters: 3),
      now: timestamp,
    );

    expect(result.created, isTrue);
    expect(novelsBox.length, 1);
    final stored = novelsBox.get(result.key);
    expect(stored, isNotNull);
    expect(stored!.id, 1);
    expect(stored.title, 'Shadow Slave');
    expect(stored.sourceId, 7);
    expect(stored.sourceName, 'Atsumaru');
    expect(stored.author, 'Guiltythree');
    expect(stored.coverUrl, 'https://cdn.example/shadow.jpg');
    expect(stored.description, 'A real synopsis.');
    expect(stored.sourceUrl, 'https://atsu.moe/title/8kL3');
    expect(stored.status, 'Ongoing');
    expect(stored.genres, <String>['Fantasy', 'Action']);
    expect(stored.chapterCount, 3);
    expect(stored.unreadCount, 3);
    expect(stored.dateAdded, timestamp);
    expect(stored.lastReadChapter, 0);
    expect(
      stored.metadata[LnReaderLibraryImporter.metadataPluginEntryId],
      'atsumaru',
    );
    expect(stored.metadata[LnReaderLibraryImporter.metadataNovelPath], '8kL3');
    final chapters = stored.metadata[LnReaderLibraryImporter.metadataChapters];
    expect(chapters, isA<List<dynamic>>());
    expect(chapters, hasLength(3));
    expect(
      (chapters as List<dynamic>).first,
      containsPair('path', '8kL3/ch-1'),
    );
  });

  test(
    'updates an existing novel without duplicating or losing progress',
    () async {
      final first = await importer.import(
        box: novelsBox,
        plugin: _plugin,
        details: _details(chapters: 2),
        now: DateTime(2026, 1, 1),
      );
      await novelsBox.put(
        first.key,
        first.novel.copyWith(
          lastReadChapter: 1,
          unreadCount: 1,
          isFavorite: true,
          lastReadAt: DateTime(2026, 2, 1),
          metadata: <String, dynamic>{
            ...first.novel.metadata,
            'custom': 'kept',
          },
        ),
      );

      final second = await importer.import(
        box: novelsBox,
        plugin: _plugin,
        details: _details(
          path: '/8kL3/',
          title: 'Shadow Slave: Updated',
          chapters: 4,
          author: 'Updated Author',
        ),
        now: DateTime(2026, 3, 1),
      );

      expect(second.created, isFalse);
      expect(second.key, first.key);
      expect(novelsBox.length, 1);
      final stored = novelsBox.get(first.key)!;
      expect(stored.id, first.novel.id);
      expect(stored.title, 'Shadow Slave: Updated');
      expect(stored.author, 'Updated Author');
      expect(stored.chapterCount, 4);
      expect(stored.lastReadChapter, 1);
      expect(stored.unreadCount, 1);
      expect(stored.isFavorite, isTrue);
      expect(stored.dateAdded, DateTime(2026, 1, 1));
      expect(stored.lastReadAt, DateTime(2026, 2, 1));
      expect(stored.metadata['custom'], 'kept');
      expect(
        stored.metadata[LnReaderLibraryImporter.metadataChapters],
        hasLength(4),
      );
    },
  );

  test('handles unavailable optional metadata safely', () async {
    final result = await importer.import(
      box: novelsBox,
      plugin: _plugin,
      details: const LnReaderNovelDetails(
        name: 'Minimal Novel',
        path: 'minimal',
        sourceUrl: 'https://atsu.moe/title/minimal',
        chapters: <LnReaderChapter>[],
      ),
    );

    final stored = novelsBox.get(result.key)!;
    expect(stored.author, '');
    expect(stored.coverUrl, isNull);
    expect(stored.description, '');
    expect(stored.status, 'unknown');
    expect(stored.genres, isEmpty);
    expect(stored.chapterCount, 0);
    expect(stored.sourceUrl, 'https://atsu.moe/title/minimal');
  });

  test('keeps the same path from another plugin as a separate novel', () async {
    await importer.import(
      box: novelsBox,
      plugin: _plugin,
      details: _details(chapters: 2),
    );
    await importer.import(
      box: novelsBox,
      plugin: _otherPlugin,
      details: _details(
        chapters: 2,
        sourceUrl: 'https://other.example/title/8kL3',
      ),
    );

    expect(novelsBox.length, 2);
    expect(novelsBox.values.map((novel) => novel.sourceId).toSet(), <int>{
      7,
      9,
    });
  });

  test('persists imported novels after reopening the Hive box', () async {
    final box = await Hive.openBox<NovelModel>('import_persist');
    await box.clear();
    await importer.import(
      box: box,
      plugin: _plugin,
      details: _details(chapters: 2),
    );
    await box.close();

    final reopened = await Hive.openBox<NovelModel>('import_persist');
    expect(reopened.length, 1);
    final novel = reopened.values.single;
    expect(novel.title, 'Shadow Slave');
    expect(novel.chapterCount, 2);
    expect(
      novel.metadata[LnReaderLibraryImporter.metadataChapters],
      hasLength(2),
    );
    await reopened.deleteFromDisk();
  });
}

LnReaderNovelDetails _details({
  String path = '8kL3',
  String title = 'Shadow Slave',
  int chapters = 2,
  String author = 'Guiltythree',
  String sourceUrl = 'https://atsu.moe/title/8kL3',
}) {
  return LnReaderNovelDetails(
    name: title,
    path: path,
    sourceUrl: sourceUrl,
    coverUrl: 'https://cdn.example/shadow.jpg',
    summary: 'A real synopsis.',
    author: author,
    genres: const <String>['Fantasy', 'Action'],
    status: 'Ongoing',
    chapters: <LnReaderChapter>[
      for (var index = 1; index <= chapters; index++)
        LnReaderChapter(
          name: 'Chapter $index',
          path: '8kL3/ch-$index',
          chapterNumber: index,
        ),
    ],
  );
}
