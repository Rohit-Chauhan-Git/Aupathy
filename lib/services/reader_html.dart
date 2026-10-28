import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

enum ReaderBlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  quote,
  bullet,
  separator,
}

class ReaderSpan {
  const ReaderSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.code = false,
    this.link = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool code;
  final bool link;

  bool sameStyle(ReaderSpan other) {
    return bold == other.bold &&
        italic == other.italic &&
        underline == other.underline &&
        code == other.code &&
        link == other.link;
  }

  ReaderSpan merge(ReaderSpan other) {
    return ReaderSpan(
      '$text${other.text}',
      bold: bold,
      italic: italic,
      underline: underline,
      code: code,
      link: link,
    );
  }
}

class ReaderBlock {
  const ReaderBlock({required this.type, required this.spans});

  final ReaderBlockType type;
  final List<ReaderSpan> spans;

  String get plainText => spans.map((span) => span.text).join().trim();

  bool get isSeparator => type == ReaderBlockType.separator;
}

class ReaderDocument {
  const ReaderDocument(this.blocks);

  final List<ReaderBlock> blocks;

  bool get isEmpty => blocks.every((block) => block.plainText.isEmpty);

  int get characterCount =>
      blocks.fold(0, (total, block) => total + block.plainText.length);

  String get plainText => blocks
      .where((block) => block.plainText.isNotEmpty)
      .map((block) => block.plainText)
      .join('\n\n');
}

/// Converts source HTML into a small, sanitized block model suitable for a
/// reader. Scripts, navigation, advertisements, and source-site chrome are
/// removed before anything reaches the rendering layer.
class ReaderHtmlConverter {
  const ReaderHtmlConverter();

  static const Set<String> _skippedTags = <String>{
    'script',
    'style',
    'nav',
    'header',
    'footer',
    'aside',
    'form',
    'button',
    'input',
    'select',
    'textarea',
    'iframe',
    'noscript',
    'svg',
    'canvas',
    'video',
    'audio',
    'img',
    'source',
    'track',
  };

  static final RegExp _noisyName = RegExp(
    r'(^|[-_\s])(ad|ads|advert|advertisement|promo|share|social|comment|'
    r'comments|navigation|menu|breadcrumb|pagination|related|sidebar|cookie|'
    r'banner)([-_\s]|$)',
    caseSensitive: false,
  );

  ReaderDocument convert(String html) {
    final source = html.trim();
    if (source.isEmpty) return const ReaderDocument(<ReaderBlock>[]);

    dom.Element root;
    try {
      root = html_parser.parse(source).body ?? dom.Element.tag('body');
    } catch (_) {
      return ReaderDocument(<ReaderBlock>[
        ReaderBlock(
          type: ReaderBlockType.paragraph,
          spans: <ReaderSpan>[ReaderSpan(_collapseWhitespace(source))],
        ),
      ]);
    }

    final builder = _BlockBuilder();
    for (final node in root.nodes) {
      _walk(node, const _InlineStyle(), ReaderBlockType.paragraph, builder);
    }
    builder.flush();
    return ReaderDocument(builder.blocks);
  }

  void _walk(
    dom.Node node,
    _InlineStyle style,
    ReaderBlockType blockType,
    _BlockBuilder builder,
  ) {
    if (node is dom.Text) {
      builder.append(_collapseWhitespace(node.data), style);
      return;
    }
    if (node is! dom.Element) return;

    final tag = node.localName?.toLowerCase() ?? '';
    if (_skippedTags.contains(tag) || _isHidden(node)) return;

    switch (tag) {
      case 'br':
        builder.append('\n', style);
        return;
      case 'strong':
      case 'b':
        _walkChildren(node, style.copyWith(bold: true), blockType, builder);
        return;
      case 'em':
      case 'i':
        _walkChildren(node, style.copyWith(italic: true), blockType, builder);
        return;
      case 'u':
        _walkChildren(
          node,
          style.copyWith(underline: true),
          blockType,
          builder,
        );
        return;
      case 's':
      case 'strike':
      case 'del':
        _walkChildren(
          node,
          style.copyWith(underline: true),
          blockType,
          builder,
        );
        return;
      case 'code':
      case 'kbd':
        _walkChildren(node, style.copyWith(code: true), blockType, builder);
        return;
      case 'a':
        _walkChildren(node, style.copyWith(link: true), blockType, builder);
        return;
      case 'h1':
      case 'h2':
      case 'h3':
        final headingType = switch (tag) {
          'h1' => ReaderBlockType.heading1,
          'h2' => ReaderBlockType.heading2,
          _ => ReaderBlockType.heading3,
        };
        builder.flush();
        _walkChildren(node, style, headingType, builder);
        builder.flush(headingType);
        return;
      case 'p':
        builder.flush();
        _walkChildren(node, style, blockType, builder);
        builder.flush(blockType);
        return;
      case 'blockquote':
        builder.flush();
        _walkChildren(node, style, ReaderBlockType.quote, builder);
        builder.flush(ReaderBlockType.quote);
        return;
      case 'li':
        builder.flush();
        _walkChildren(node, style, ReaderBlockType.bullet, builder);
        builder.flush(ReaderBlockType.bullet);
        return;
      case 'hr':
        builder.flush();
        builder.addSeparator();
        return;
      case 'ul':
      case 'ol':
      case 'table':
      case 'tbody':
      case 'thead':
      case 'tr':
        builder.flush();
        _walkChildren(node, style, blockType, builder);
        builder.flush(blockType);
        return;
      case 'td':
      case 'th':
        builder.flush();
        _walkChildren(node, style, blockType, builder);
        builder.flush(blockType);
        return;
      case 'div':
      case 'section':
      case 'article':
      case 'main':
      case 'figure':
        builder.flush();
        _walkChildren(node, style, blockType, builder);
        builder.flush(blockType);
        return;
      default:
        _walkChildren(node, style, blockType, builder);
    }
  }

  void _walkChildren(
    dom.Element element,
    _InlineStyle style,
    ReaderBlockType blockType,
    _BlockBuilder builder,
  ) {
    for (final child in element.nodes) {
      _walk(child, style, blockType, builder);
    }
  }

  bool _isHidden(dom.Element element) {
    if (element.attributes.containsKey('hidden')) return true;
    if (element.attributes['aria-hidden']?.toLowerCase() == 'true') {
      return true;
    }
    final className = element.attributes['class'] ?? '';
    final id = element.attributes['id'] ?? '';
    return _noisyName.hasMatch(className) || _noisyName.hasMatch(id);
  }

  String _collapseWhitespace(String value) {
    return value.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _InlineStyle {
  const _InlineStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.code = false,
    this.link = false,
  });

  final bool bold;
  final bool italic;
  final bool underline;
  final bool code;
  final bool link;

  _InlineStyle copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? code,
    bool? link,
  }) {
    return _InlineStyle(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      code: code ?? this.code,
      link: link ?? this.link,
    );
  }
}

class _BlockBuilder {
  final List<ReaderBlock> blocks = <ReaderBlock>[];
  final List<ReaderSpan> _spans = <ReaderSpan>[];

  void append(String text, _InlineStyle style) {
    if (text.isEmpty) return;
    final span = ReaderSpan(
      text,
      bold: style.bold,
      italic: style.italic,
      underline: style.underline,
      code: style.code,
      link: style.link,
    );
    if (_spans.isNotEmpty && _spans.last.sameStyle(span)) {
      _spans[_spans.length - 1] = _spans.last.merge(span);
    } else {
      _spans.add(span);
    }
  }

  void flush([ReaderBlockType type = ReaderBlockType.paragraph]) {
    if (_spans.isEmpty) return;
    final cleaned = <ReaderSpan>[];
    for (final span in _spans) {
      final text = span.text
          .replaceAll(RegExp(r'[ \t]+'), ' ')
          .replaceAll(RegExp(r' *\n *'), '\n');
      if (text.isEmpty) continue;
      cleaned.add(
        ReaderSpan(
          text,
          bold: span.bold,
          italic: span.italic,
          underline: span.underline,
          code: span.code,
          link: span.link,
        ),
      );
    }
    _spans.clear();

    if (cleaned.isEmpty) return;
    _trimEdges(cleaned);
    if (cleaned.isEmpty || cleaned.every((span) => span.text.trim().isEmpty)) {
      return;
    }
    blocks.add(ReaderBlock(type: type, spans: cleaned));
  }

  void addSeparator() {
    flush();
    if (blocks.isNotEmpty && blocks.last.isSeparator) return;
    blocks.add(const ReaderBlock(type: ReaderBlockType.separator, spans: []));
  }

  void _trimEdges(List<ReaderSpan> spans) {
    final first = spans.first;
    final trimmedStart = first.text.replaceFirst(RegExp(r'^\s+'), '');
    spans[0] = ReaderSpan(
      trimmedStart,
      bold: first.bold,
      italic: first.italic,
      underline: first.underline,
      code: first.code,
      link: first.link,
    );
    final last = spans.last;
    final trimmedEnd = last.text.replaceFirst(RegExp(r'\s+$'), '');
    spans[spans.length - 1] = ReaderSpan(
      trimmedEnd,
      bold: last.bold,
      italic: last.italic,
      underline: last.underline,
      code: last.code,
      link: last.link,
    );
    spans.removeWhere((span) => span.text.isEmpty);
  }
}
