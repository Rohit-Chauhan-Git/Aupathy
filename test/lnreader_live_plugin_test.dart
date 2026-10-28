import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/models/plugin_model.dart';
import 'package:reader_app/services/lnreader_http_client.dart';
import 'package:reader_app/services/lnreader_novel_service.dart';
import 'package:reader_app/services/lnreader_plugin_repository.dart';
import 'package:reader_app/services/lnreader_runtime_probe.dart';
import 'package:reader_app/services/reader_html.dart';

void main() {
  final liveEnabled = Platform.environment['LNREADER_LIVE_TESTS'] == '1';
  late PluginModel plugin;
  late DioLnReaderHttpClient http;
  late LnReaderNovelService service;

  setUpAll(() async {
    final source = await File('test/fixtures/atsumaru.js').readAsString();
    plugin = PluginModel(
      id: 1,
      name: 'Atsumaru',
      packageName: 'lnreader.atsumaru',
      version: '1.0.1',
      baseUrl: 'https://atsu.moe',
      lang: 'English',
      isInstalled: true,
      metadata: <String, dynamic>{
        LnReaderPluginRepository.metadataId: 'atsumaru',
        LnReaderPluginRepository.metadataSite: 'https://atsu.moe',
        LnReaderPluginRepository.metadataVersion: '1.0.1',
        LnReaderPluginRepository.metadataBundleSource: source,
      },
    );
    http = DioLnReaderHttpClient(timeout: const Duration(seconds: 30));
    service = LnReaderNovelService(
      executorFactory: QuickJsLnReaderPluginExecutorFactory(
        runtimeFactory: QuickJsScriptRuntimeFactory(httpClient: http),
        callTimeout: const Duration(seconds: 60),
      ),
      searchTimeout: const Duration(seconds: 60),
    );
  });

  tearDownAll(() {
    http.close();
  });

  test(
    'searches, parses details, and fetches real chapter content',
    skip: liveEnabled
        ? false
        : 'Set LNREADER_LIVE_TESTS=1 and LD_LIBRARY_PATH to the flutter_js '
              'Linux shared library to run this live Atsumaru test.',
    () async {
      final results = await service.searchNovels(plugin, 'shadow');
      expect(results, isNotEmpty);
      expect(
        results.any((result) => result.name.toLowerCase().contains('shadow')),
        isTrue,
      );

      final selected = results.firstWhere(
        (result) => result.name.toLowerCase() == 'shadow slave',
        orElse: () => results.first,
      );
      final details = await service.parseNovel(plugin, selected.path);
      expect(details.name, isNotEmpty);
      expect(details.chapters, isNotEmpty);
      expect(details.sourceUrl, startsWith('http'));

      final chapter = details.chapters.first;
      final content = await service.parseChapter(plugin, chapter.path);
      expect(content.path, chapter.path);
      expect(content.html.trim(), isNotEmpty);
      expect(content.characterCount, greaterThan(0));

      final document = const ReaderHtmlConverter().convert(content.html);
      expect(document.blocks, isNotEmpty);
      final plainText = document.plainText;
      expect(plainText.trim(), isNotEmpty);
      expect(plainText, isNot(contains('<script')));
      expect(plainText, isNot(contains('<p>')));

      // ignore: avoid_print
      print(
        'Live Atsumaru: ${results.length} results; '
        '"${details.name}" with ${details.chapters.length} chapters; '
        'chapter "${chapter.name}" is ${content.characterCount} chars.',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
