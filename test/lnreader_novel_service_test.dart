import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/models/plugin_model.dart';
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

void main() {
  group('LnReaderNovelService search', () {
    test('maps real plugin search fields and skips malformed rows', () async {
      final factory = _FakeExecutorFactory(
        result: <Object?>[
          <String, Object?>{
            'name': 'Shadow Slave',
            'path': '8kL3',
            'cover': 'https://cdn.example/shadow.jpg',
            'author': 'Guiltythree',
          },
          <String, Object?>{'name': 'Missing path'},
          <String, Object?>{'name': '', 'path': 'empty-name'},
          'not a map',
          <String, Object?>{'name': 'Second', 'path': 'ZJQK'},
        ],
      );
      final service = LnReaderNovelService(executorFactory: factory);

      final results = await service.searchNovels(_plugin, 'shadow', page: 3);

      expect(factory.openCount, 1);
      expect(factory.executor.methods, <String>['searchNovels']);
      expect(factory.executor.args, <Object?>['shadow', 3]);
      expect(results, hasLength(2));
      expect(results.first.name, 'Shadow Slave');
      expect(results.first.path, '8kL3');
      expect(results.first.coverUrl, 'https://cdn.example/shadow.jpg');
      expect(results.first.author, 'Guiltythree');
      expect(results.last.coverUrl, isNull);
      expect(factory.executor.disposed, isTrue);
    });

    test('returns an empty list for empty plugin results', () async {
      final service = LnReaderNovelService(
        executorFactory: _FakeExecutorFactory(result: <Object?>[]),
      );

      final results = await service.searchNovels(_plugin, 'nothing');

      expect(results, isEmpty);
    });

    test('rejects malformed search responses', () async {
      final service = LnReaderNovelService(
        executorFactory: _FakeExecutorFactory(result: 'not a list'),
      );

      await expectLater(
        service.searchNovels(_plugin, 'shadow'),
        throwsA(
          isA<LnReaderPluginException>().having(
            (error) => error.message,
            'message',
            contains('invalid search response'),
          ),
        ),
      );
    });

    test('preserves plugin HTTP and access errors', () async {
      final service = LnReaderNovelService(
        executorFactory: _FakeExecutorFactory(
          error: const LnReaderPluginException(
            'Royal Road is showing a bot check. HTTP 403.',
          ),
        ),
      );

      await expectLater(
        service.searchNovels(_plugin, 'shadow'),
        throwsA(
          isA<LnReaderPluginException>().having(
            (error) => error.message,
            'message',
            contains('bot check'),
          ),
        ),
      );
    });

    test('times out a plugin that never settles', () async {
      final service = LnReaderNovelService(
        executorFactory: _FakeExecutorFactory(
          result: <Object?>[],
          delay: const Duration(seconds: 1),
        ),
        searchTimeout: const Duration(milliseconds: 20),
      );

      await expectLater(
        service.searchNovels(_plugin, 'shadow'),
        throwsA(
          isA<LnReaderPluginException>().having(
            (error) => error.message,
            'message',
            contains('did not finish searching'),
          ),
        ),
      );
    });

    test('rejects empty queries before opening the plugin', () async {
      final factory = _FakeExecutorFactory(result: <Object?>[]);
      final service = LnReaderNovelService(executorFactory: factory);

      await expectLater(
        service.searchNovels(_plugin, '   '),
        throwsA(isA<LnReaderPluginException>()),
      );
      expect(factory.openCount, 0);
    });
  });

  group('LnReaderNovelService plugin validation', () {
    test('rejects disabled plugins', () async {
      final service = LnReaderNovelService(
        executorFactory: _FakeExecutorFactory(result: <Object?>[]),
      );

      await expectLater(
        service.searchNovels(_plugin.copyWith(isEnabled: false), 'shadow'),
        throwsA(
          isA<LnReaderPluginException>().having(
            (error) => error.message,
            'message',
            contains('disabled'),
          ),
        ),
      );
    });

    test('rejects uninstalled plugins', () async {
      final service = LnReaderNovelService(
        executorFactory: _FakeExecutorFactory(result: <Object?>[]),
      );

      await expectLater(
        service.searchNovels(_plugin.copyWith(isInstalled: false), 'shadow'),
        throwsA(
          isA<LnReaderPluginException>().having(
            (error) => error.message,
            'message',
            contains('not installed'),
          ),
        ),
      );
    });

    test('rejects plugins without a stored bundle', () async {
      final service = LnReaderNovelService(
        executorFactory: _FakeExecutorFactory(result: <Object?>[]),
      );
      const missingBundle = PluginModel(
        id: 7,
        name: 'Atsumaru',
        packageName: 'lnreader.atsumaru',
        version: '1.0.1',
        isInstalled: true,
      );

      await expectLater(
        service.searchNovels(missingBundle, 'shadow'),
        throwsA(
          isA<LnReaderPluginException>().having(
            (error) => error.message,
            'message',
            contains('no installed bundle'),
          ),
        ),
      );
    });
  });

  group('LnReaderNovelService novel details', () {
    test('maps details, resolves the URL, and parses chapters', () async {
      final factory = _FakeExecutorFactory(
        result: <String, Object?>{
          'name': 'Shadow Slave',
          'cover': 'https://cdn.example/shadow.jpg',
          'summary': 'A real synopsis.',
          'author': 'Guiltythree',
          'genres': 'Fantasy, Action; Adventure',
          'status': 'Ongoing',
          'chapters': <Object?>[
            <String, Object?>{
              'name': 'Chapter 1',
              'path': '8kL3/aaa',
              'releaseTime': '2020-01-01',
              'chapterNumber': 1,
            },
            <String, Object?>{
              'name': 'Chapter 2',
              'path': '8kL3/bbb',
              'chapterNumber': 2.0,
              'page': 'Volume 1',
            },
            <String, Object?>{'name': 'Malformed'},
          ],
        },
        resolvedUrl: 'https://atsu.moe/title/8kL3',
      );
      final service = LnReaderNovelService(executorFactory: factory);

      final details = await service.parseNovel(_plugin, '/8kL3/');

      expect(details.name, 'Shadow Slave');
      expect(details.path, '/8kL3/');
      expect(details.sourceUrl, 'https://atsu.moe/title/8kL3');
      expect(details.author, 'Guiltythree');
      expect(details.genres, <String>['Fantasy', 'Action', 'Adventure']);
      expect(details.status, 'Ongoing');
      expect(details.chapters, hasLength(2));
      expect(details.chapters.first.name, 'Chapter 1');
      expect(details.chapters.first.releaseTime, '2020-01-01');
      expect(details.chapters.last.chapterNumber, 2);
      expect(details.chapters.last.page, 'Volume 1');
      expect(factory.executor.methods, <String>['parseNovel']);
      expect(factory.executor.args, <Object?>['/8kL3/']);
      expect(factory.executor.resolvedPaths, <String>['/8kL3/']);
    });

    test(
      'falls back to the plugin base URL when resolveUrl is absent',
      () async {
        final factory = _FakeExecutorFactory(
          result: <String, Object?>{
            'name': 'Shadow Slave',
            'chapters': <Object?>[],
          },
        );
        final service = LnReaderNovelService(executorFactory: factory);

        final details = await service.parseNovel(_plugin, 'novel/1');

        expect(details.sourceUrl, 'https://atsu.moe/novel/1');
        expect(details.status, 'unknown');
        expect(details.chapters, isEmpty);
      },
    );

    test('rejects details without a title', () async {
      final service = LnReaderNovelService(
        executorFactory: _FakeExecutorFactory(
          result: <String, Object?>{'chapters': <Object?>[]},
        ),
      );

      await expectLater(
        service.parseNovel(_plugin, '8kL3'),
        throwsA(
          isA<LnReaderPluginException>().having(
            (error) => error.message,
            'message',
            contains('novel title'),
          ),
        ),
      );
    });

    test('rejects a malformed chapter list', () async {
      final service = LnReaderNovelService(
        executorFactory: _FakeExecutorFactory(
          result: <String, Object?>{
            'name': 'Shadow Slave',
            'chapters': 'not a list',
          },
        ),
      );

      await expectLater(
        service.parseNovel(_plugin, '8kL3'),
        throwsA(
          isA<LnReaderPluginException>().having(
            (error) => error.message,
            'message',
            contains('invalid chapter list'),
          ),
        ),
      );
    });
  });

  group('LnReaderNovelService chapter content', () {
    test('returns real plugin chapter HTML', () async {
      final factory = _FakeExecutorFactory(result: '<p>Chapter text.</p>');
      final service = LnReaderNovelService(executorFactory: factory);

      final content = await service.parseChapter(_plugin, '8kL3/aaa');

      expect(content.path, '8kL3/aaa');
      expect(content.html, '<p>Chapter text.</p>');
      expect(content.characterCount, 20);
      expect(factory.executor.methods, <String>['parseChapter']);
      expect(factory.executor.args, <Object?>['8kL3/aaa']);
    });

    test('rejects empty chapter content', () async {
      final service = LnReaderNovelService(
        executorFactory: _FakeExecutorFactory(result: '  '),
      );

      await expectLater(
        service.parseChapter(_plugin, '8kL3/aaa'),
        throwsA(
          isA<LnReaderPluginException>().having(
            (error) => error.message,
            'message',
            contains('no chapter content'),
          ),
        ),
      );
    });
  });
}

class _FakeExecutorFactory implements LnReaderPluginExecutorFactory {
  _FakeExecutorFactory({
    this.result,
    this.error,
    this.resolvedUrl,
    this.delay = Duration.zero,
  });

  final Object? result;
  final Object? error;
  final String? resolvedUrl;
  final Duration delay;
  int openCount = 0;
  late _FakeExecutor executor;

  @override
  Future<LnReaderPluginExecutor> open(PluginModel plugin) async {
    openCount++;
    executor = _FakeExecutor(
      result: result,
      error: error,
      resolvedUrl: resolvedUrl,
      delay: delay,
    );
    return executor;
  }
}

class _FakeExecutor implements LnReaderPluginExecutor {
  _FakeExecutor({
    this.result,
    this.error,
    this.resolvedUrl,
    this.delay = Duration.zero,
  });

  final Object? result;
  final Object? error;
  final String? resolvedUrl;
  final Duration delay;
  final List<String> methods = <String>[];
  final List<String> resolvedPaths = <String>[];
  Object? args;
  bool disposed = false;

  @override
  Future<Object?> invoke(String method, List<Object?> args) async {
    methods.add(method);
    this.args = args;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<String?> resolveUrl(String path) async {
    resolvedPaths.add(path);
    return resolvedUrl;
  }

  @override
  void dispose() {
    disposed = true;
  }
}
