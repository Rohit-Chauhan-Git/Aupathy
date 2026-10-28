import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/models/novel_model.dart';
import 'package:reader_app/theme/app_theme.dart';
import 'package:reader_app/widgets/reading_progress_bar.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: Center(child: child)),
    );
  }

  NovelModel novel({int chapterCount = 0, int lastReadChapter = 0}) {
    return NovelModel(
      id: 1,
      title: 'Test Novel',
      sourceId: 1,
      sourceName: 'Test Source',
      chapterCount: chapterCount,
      lastReadChapter: lastReadChapter,
    );
  }

  group('NovelModel progress', () {
    test('treats a zero chapter count as unknown', () {
      final model = novel(chapterCount: 0, lastReadChapter: 5);
      expect(model.readingProgress, 0);
      expect(model.isCompleted, isFalse);
      expect(model.isInProgress, isFalse);
    });

    test('clamps out-of-range values', () {
      expect(novel(chapterCount: 10, lastReadChapter: 20).readingProgress, 1.0);
      expect(novel(chapterCount: 10, lastReadChapter: -3).readingProgress, 0.0);
    });

    test('reports completed and in-progress states', () {
      expect(novel(chapterCount: 10, lastReadChapter: 10).isCompleted, isTrue);
      expect(novel(chapterCount: 10, lastReadChapter: 20).isCompleted, isTrue);
      expect(novel(chapterCount: 10, lastReadChapter: 4).isInProgress, isTrue);
      expect(novel(chapterCount: 10, lastReadChapter: 0).isInProgress, isFalse);
    });
  });

  group('ReadingProgressBar labels', () {
    testWidgets('shows a safe label when chapters are unknown', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ReadingProgressBar(
            progress: 0,
            chapterCount: 0,
            lastReadChapter: 0,
          ),
        ),
      );

      expect(find.text('No chapters yet'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('handles invalid chapter counts', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ReadingProgressBar(
            progress: 0,
            chapterCount: -4,
            lastReadChapter: 2,
          ),
        ),
      );

      expect(find.text('No chapters yet'), findsOneWidget);
    });

    testWidgets('shows not started for unread novels', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ReadingProgressBar(
            progress: 0,
            chapterCount: 10,
            lastReadChapter: 0,
          ),
        ),
      );

      expect(find.text('Not started'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('shows chapter progress for partially read novels', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const ReadingProgressBar(
            progress: 0.2,
            chapterCount: 10,
            lastReadChapter: 2,
          ),
        ),
      );

      expect(find.text('Chapter 2 of 10'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
    });

    testWidgets('shows completed for fully read novels', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ReadingProgressBar(
            progress: 1,
            chapterCount: 10,
            lastReadChapter: 10,
          ),
        ),
      );

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('clamps out-of-range progress safely', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ReadingProgressBar(
            progress: 4.5,
            chapterCount: 10,
            lastReadChapter: 40,
          ),
        ),
      );

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          const ReadingProgressBar(
            progress: -2,
            chapterCount: 10,
            lastReadChapter: -1,
          ),
        ),
      );

      expect(find.text('Not started'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });
  });
}
