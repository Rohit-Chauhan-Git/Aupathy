import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:reader_app/models/hive_adapters.dart';
import 'package:reader_app/models/novel_model.dart';
import 'package:reader_app/services/reader_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<NovelModel> box;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_progress_test_');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    box = await Hive.openBox<NovelModel>('progress_novels');
  });

  setUp(() async {
    await box.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  NovelModel novel() {
    return NovelModel(
      id: 3,
      title: 'Shadow Slave',
      sourceId: 7,
      sourceName: 'Atsumaru',
      chapterCount: 10,
      lastReadChapter: 2,
      isFavorite: true,
      dateAdded: DateTime(2026, 1, 1),
      metadata: <String, dynamic>{'custom': 'kept'},
    );
  }

  ReaderProgressStore store(Duration debounce) {
    return ReaderProgressStore(
      box: box,
      key: 'novel-key',
      fallbackNovel: novel(),
      debounce: debounce,
    );
  }

  ReaderPosition position(
    int index, {
    String? path,
    double fraction = 0.25,
    double offset = 120,
  }) {
    return ReaderPosition(
      chapterIndex: index,
      chapterPath: path ?? 'chapter-$index',
      scrollOffset: offset,
      scrollFraction: fraction,
    );
  }

  test('calculates chapter and novel progress safely', () {
    expect(
      ReaderProgressMath.chapterFraction(
        offset: 50,
        maxExtent: 200,
        hasContent: true,
      ),
      0.25,
    );
    expect(
      ReaderProgressMath.chapterFraction(
        offset: 0,
        maxExtent: 0,
        hasContent: true,
      ),
      1,
    );
    expect(
      ReaderProgressMath.chapterFraction(
        offset: 0,
        maxExtent: 200,
        hasContent: false,
      ),
      0,
    );
    expect(
      ReaderProgressMath.novelProgress(
        chapterIndex: 2,
        chapterFraction: 0.5,
        chapterCount: 10,
      ),
      0.25,
    );
    expect(
      ReaderProgressMath.novelProgress(
        chapterIndex: 0,
        chapterFraction: 0,
        chapterCount: 0,
      ),
      0,
    );
    expect(ReaderProgressMath.percent(0.333), 33);
  });

  test('debounces position writes and persists resume metadata', () async {
    final progress = store(const Duration(milliseconds: 40));
    await box.put('novel-key', novel());

    progress.record(position(3, path: 'chapter-3'));
    expect(box.get('novel-key')!.lastReadChapter, 2);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(box.get('novel-key')!.lastReadChapter, 2);

    await Future<void>.delayed(const Duration(milliseconds: 120));
    final saved = box.get('novel-key')!;
    expect(saved.lastReadChapter, 4);
    expect(saved.lastReadAt, isNotNull);
    expect(saved.unreadCount, 6);
    expect(saved.isFavorite, isTrue);
    expect(saved.dateAdded, DateTime(2026, 1, 1));
    expect(saved.metadata['custom'], 'kept');
    expect(
      saved.metadata[ReaderProgressStore.metadataChapterPath],
      'chapter-3',
    );
    expect(saved.metadata[ReaderProgressStore.metadataChapterIndex], 3);
    expect(saved.metadata[ReaderProgressStore.metadataScrollFraction], 0.25);
    progress.dispose();
  });

  test('flush writes immediately and clears the pending debounce', () async {
    final progress = store(const Duration(minutes: 1));
    await box.put('novel-key', novel());

    progress.record(position(1, path: 'chapter-1'));
    await progress.flush();

    expect(box.get('novel-key')!.lastReadChapter, 2);
    expect(
      box.get('novel-key')!.metadata[ReaderProgressStore.metadataChapterPath],
      'chapter-1',
    );
    progress.dispose();
  });

  test('a newer chapter wins after rapid changes', () async {
    final progress = store(const Duration(milliseconds: 30));
    await box.put('novel-key', novel());

    progress.record(position(0, path: 'old-chapter'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await progress.saveNow(position(5, path: 'new-chapter'));
    await Future<void>.delayed(const Duration(milliseconds: 80));

    final saved = box.get('novel-key')!;
    expect(saved.lastReadChapter, 6);
    expect(
      saved.metadata[ReaderProgressStore.metadataChapterPath],
      'new-chapter',
    );
    expect(saved.metadata[ReaderProgressStore.metadataScrollFraction], 0.25);
    progress.dispose();
  });

  test('dispose flushes the latest position without stale overwrite', () async {
    final progress = store(const Duration(minutes: 1));
    await box.put('novel-key', novel());

    progress.record(position(8, path: 'last-chapter', fraction: 0.8));
    progress.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    final saved = box.get('novel-key')!;
    expect(saved.lastReadChapter, 9);
    expect(
      saved.metadata[ReaderProgressStore.metadataChapterPath],
      'last-chapter',
    );
    expect(saved.metadata[ReaderProgressStore.metadataScrollFraction], 0.8);
  });
}
