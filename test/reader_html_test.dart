import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/services/reader_html.dart';

void main() {
  const converter = ReaderHtmlConverter();

  test('converts the chapter fixture into readable blocks', () async {
    final html = await File('test/fixtures/reader_chapter.html').readAsString();
    final document = converter.convert(html);

    expect(document.isEmpty, isFalse);
    expect(document.characterCount, greaterThan(500));
    expect(document.blocks.first.type, ReaderBlockType.heading2);
    expect(
      document.plainText,
      contains('Alice was beginning to get very tired'),
    );
    expect(document.plainText, contains('Curiouser and curiouser!'));
    expect(document.plainText, contains('& the adventure began.'));
    expect(document.plainText, isNot(contains('window.tracker')));
    expect(document.plainText, isNot(contains('Home')));
    expect(document.plainText, isNot(contains('Buy coins now')));
    expect(document.plainText, isNot(contains('Copyright notice')));
    expect(document.plainText, isNot(contains('Share this chapter')));
    expect(document.plainText, isNot(contains('Source Site')));
  });

  test(
    'preserves emphasis, links, line breaks, quotes, and separators',
    () async {
      final document = converter.convert(
        '<h1>Title</h1><p>A <em>quiet</em> <strong>night</strong> '
        '<a href="/x">link</a>.<br>Next line.</p>'
        '<blockquote>Quoted</blockquote><hr><p>End</p>',
      );

      expect(document.blocks.map((block) => block.type), <ReaderBlockType>[
        ReaderBlockType.heading1,
        ReaderBlockType.paragraph,
        ReaderBlockType.quote,
        ReaderBlockType.separator,
        ReaderBlockType.paragraph,
      ]);
      final paragraph = document.blocks[1];
      expect(
        paragraph.spans.any((span) => span.text == 'quiet' && span.italic),
        isTrue,
      );
      expect(
        paragraph.spans.any((span) => span.text == 'night' && span.bold),
        isTrue,
      );
      expect(
        paragraph.spans.any((span) => span.text == 'link' && span.link),
        isTrue,
      );
      expect(paragraph.plainText, contains('Next line.'));
    },
  );

  test('handles empty and whitespace-only content', () {
    expect(converter.convert('').isEmpty, isTrue);
    expect(converter.convert('   \n\t ').isEmpty, isTrue);
    expect(converter.convert('<script>alert(1)</script>').isEmpty, isTrue);
  });

  test('recovers usable text from malformed HTML', () {
    final document = converter.convert('<p>Hello <strong>world');
    expect(document.isEmpty, isFalse);
    expect(document.plainText, contains('Hello world'));
  });

  test('keeps div-based paragraphs separate', () {
    final document = converter.convert(
      '<div>First paragraph</div><div>Second paragraph</div>',
    );
    expect(document.blocks, hasLength(2));
    expect(document.plainText, 'First paragraph\n\nSecond paragraph');
  });
}
