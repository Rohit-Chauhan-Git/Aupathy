import 'dart:async';

import 'package:hive_ce/hive_ce.dart';

import '../models/novel_model.dart';

class ReaderPosition {
  const ReaderPosition({
    required this.chapterIndex,
    required this.chapterPath,
    required this.scrollOffset,
    required this.scrollFraction,
  });

  final int chapterIndex;
  final String chapterPath;
  final double scrollOffset;
  final double scrollFraction;

  ReaderPosition copyWith({
    int? chapterIndex,
    String? chapterPath,
    double? scrollOffset,
    double? scrollFraction,
  }) {
    return ReaderPosition(
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterPath: chapterPath ?? this.chapterPath,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      scrollFraction: scrollFraction ?? this.scrollFraction,
    );
  }
}

abstract final class ReaderProgressMath {
  static double chapterFraction({
    required double offset,
    required double maxExtent,
    required bool hasContent,
  }) {
    if (!hasContent) return 0;
    if (maxExtent <= 0) return 1;
    return (offset / maxExtent).clamp(0.0, 1.0);
  }

  static double novelProgress({
    required int chapterIndex,
    required double chapterFraction,
    required int chapterCount,
  }) {
    if (chapterCount <= 0 || chapterIndex < 0) return 0;
    final value =
        (chapterIndex + chapterFraction.clamp(0.0, 1.0)) / chapterCount;
    return value.clamp(0.0, 1.0);
  }

  static int percent(double value) => (value.clamp(0.0, 1.0) * 100).round();
}

/// Debounces reader-position writes while serializing Hive updates so an
/// older chapter can never finish after the chapter the user just selected.
class ReaderProgressStore {
  ReaderProgressStore({
    required this.box,
    required this.key,
    required this.fallbackNovel,
    this.debounce = const Duration(milliseconds: 800),
  });

  static const String metadataChapterIndex = 'readerChapterIndex';
  static const String metadataChapterPath = 'readerChapterPath';
  static const String metadataScrollOffset = 'readerScrollOffset';
  static const String metadataScrollFraction = 'readerScrollFraction';
  static const String metadataUpdatedAt = 'readerUpdatedAt';

  final Box<NovelModel> box;
  final dynamic key;
  final NovelModel fallbackNovel;
  final Duration debounce;

  Timer? _timer;
  ReaderPosition? _pending;
  Future<void> _writeQueue = Future<void>.value();
  bool _disposed = false;

  ReaderPosition? get pending => _pending;

  void record(ReaderPosition position) {
    if (_disposed) return;
    _pending = position;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      final value = _pending;
      if (value != null) _enqueue(value);
    });
  }

  Future<void> saveNow(ReaderPosition position) {
    if (_disposed) return Future<void>.value();
    _pending = position;
    _timer?.cancel();
    _timer = null;
    return _enqueue(position);
  }

  Future<void> flush() {
    final value = _pending;
    if (value == null) return _writeQueue;
    _pending = null;
    _timer?.cancel();
    _timer = null;
    return _enqueue(value);
  }

  Future<void> _enqueue(ReaderPosition position) {
    _writeQueue = _writeQueue.then((_) => _write(position)).catchError((
      Object error,
      StackTrace stack,
    ) {
      // A failed progress write must never crash reading or block later saves.
    });
    return _writeQueue;
  }

  Future<void> _write(ReaderPosition position) async {
    if (!box.isOpen) return;
    final current = box.get(key) ?? fallbackNovel;
    final chapterCount = current.chapterCount;
    final chapterRead = (position.chapterIndex + 1)
        .clamp(0, chapterCount)
        .toInt();
    final now = DateTime.now();
    final metadata = <String, dynamic>{
      ...current.metadata,
      metadataChapterIndex: position.chapterIndex,
      metadataChapterPath: position.chapterPath,
      metadataScrollOffset: position.scrollOffset,
      metadataScrollFraction: position.scrollFraction,
      metadataUpdatedAt: now.toIso8601String(),
    };
    final updated = current.copyWith(
      lastReadChapter: chapterRead,
      lastReadAt: now,
      unreadCount: (chapterCount - chapterRead).clamp(0, chapterCount).toInt(),
      metadata: metadata,
    );
    await box.put(key, updated);
  }

  void dispose() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    final value = _pending;
    _pending = null;
    if (value != null) {
      _enqueue(value);
    }
    _disposed = true;
  }
}
