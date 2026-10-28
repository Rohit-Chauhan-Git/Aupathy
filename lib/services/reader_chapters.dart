import '../models/novel_model.dart';
import 'lnreader_novel_service.dart';

abstract final class ReaderChapters {
  static List<LnReaderChapter> fromNovel(NovelModel novel) {
    final raw = novel.metadata['lnreaderChapters'];
    if (raw is! List) return const <LnReaderChapter>[];
    return sanitize(
      raw.map((item) {
        if (item is! Map) return null;
        final map = item.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        );
        final path = _text(map['path']);
        if (path == null) return null;
        final rawNumber = map['chapterNumber'];
        return LnReaderChapter(
          name: _text(map['name']) ?? 'Chapter',
          path: path,
          releaseTime: _text(map['releaseTime']),
          chapterNumber: rawNumber is num ? rawNumber.toInt() : null,
          page: _text(map['page']),
        );
      }).whereType<LnReaderChapter>(),
    );
  }

  static List<LnReaderChapter> sanitize(Iterable<LnReaderChapter> chapters) {
    final result = <LnReaderChapter>[];
    final seenPaths = <String>{};
    for (final chapter in chapters) {
      final path = chapter.path.trim();
      if (path.isEmpty || !seenPaths.add(path)) continue;
      final name = chapter.name.trim().isEmpty
          ? 'Chapter ${result.length + 1}'
          : chapter.name.trim();
      result.add(
        LnReaderChapter(
          name: name,
          path: path,
          releaseTime: _text(chapter.releaseTime),
          chapterNumber: chapter.chapterNumber,
          page: _text(chapter.page),
        ),
      );
    }
    return List<LnReaderChapter>.unmodifiable(result);
  }

  static int resolveIndex(
    List<LnReaderChapter> chapters, {
    required int lastReadChapter,
    String? savedPath,
  }) {
    if (chapters.isEmpty) return 0;
    final path = savedPath?.trim();
    if (path != null && path.isNotEmpty) {
      final byPath = chapters.indexWhere((chapter) => chapter.path == path);
      if (byPath >= 0) return byPath;
    }
    if (lastReadChapter > 0) {
      return (lastReadChapter - 1).clamp(0, chapters.length - 1);
    }
    return 0;
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}
