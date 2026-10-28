import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/services/lnreader_manifest_service.dart';

void main() {
  test('parses valid entries and reports invalid ones', () {
    final body = jsonEncode(<Object>[
      <String, Object>{
        'id': 'royalroad',
        'name': 'Royal Road',
        'site': 'https://www.royalroad.com',
        'lang': 'en',
        'version': '1.0.0',
        'url': 'https://example.com/royalroad.js',
        'iconUrl': 'https://example.com/icon.png',
      },
      <String, Object>{
        'id': 'bad-url',
        'name': 'Bad URL',
        'site': 'not a url',
        'lang': 'en',
        'version': '1.0.0',
        'url': 'https://example.com/bad.js',
      },
      'not an object',
    ]);

    final manifest = parseManifest(body);

    expect(manifest.totalEntries, 3);
    expect(manifest.validCount, 1);
    expect(manifest.invalidCount, 2);
    expect(manifest.entries.single.id, 'royalroad');
    expect(manifest.issues.first.index, 1);
    expect(manifest.issues.first.message, contains('site'));
  });

  test('rejects an empty manifest', () {
    expect(
      () => parseManifest('  '),
      throwsA(
        isA<LnReaderManifestParseException>().having(
          (error) => error.message,
          'message',
          contains('empty'),
        ),
      ),
    );
  });

  test('rejects malformed JSON and non-array roots', () {
    expect(
      () => parseManifest('{'),
      throwsA(isA<LnReaderManifestParseException>()),
    );
    expect(
      () => parseManifest('{}'),
      throwsA(
        isA<LnReaderManifestParseException>().having(
          (error) => error.message,
          'message',
          contains('array'),
        ),
      ),
    );
  });

  test('requires non-empty string fields and http(s) URLs', () {
    final missingName = jsonEncode(<Object>[
      <String, Object>{
        'id': 'x',
        'site': 'https://example.com',
        'lang': 'en',
        'version': '1',
        'url': 'https://example.com/x.js',
      },
    ]);
    final nonHttp = jsonEncode(<Object>[
      <String, Object>{
        'id': 'x',
        'name': 'X',
        'site': 'ftp://example.com',
        'lang': 'en',
        'version': '1',
        'url': 'https://example.com/x.js',
      },
    ]);

    expect(parseManifest(missingName).issues.single.message, contains('name'));
    expect(parseManifest(nonHttp).issues.single.message, contains('http'));
  });
}
