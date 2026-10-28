import 'package:flutter/material.dart';

import '../../services/lnreader_novel_service.dart';

Future<int?> showReaderChapterList({
  required BuildContext context,
  required List<LnReaderChapter> chapters,
  required int currentIndex,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) =>
        _ChapterListSheet(chapters: chapters, currentIndex: currentIndex),
  );
}

class _ChapterListSheet extends StatefulWidget {
  const _ChapterListSheet({required this.chapters, required this.currentIndex});

  final List<LnReaderChapter> chapters;
  final int currentIndex;

  @override
  State<_ChapterListSheet> createState() => _ChapterListSheetState();
}

class _ChapterListSheetState extends State<_ChapterListSheet> {
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _scrollController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: widget.currentIndex * 66.0,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<MapEntry<int, LnReaderChapter>> get _visible {
    final query = _query.trim().toLowerCase();
    final entries = <MapEntry<int, LnReaderChapter>>[];
    for (var index = 0; index < widget.chapters.length; index++) {
      final chapter = widget.chapters[index];
      if (query.isEmpty ||
          chapter.name.toLowerCase().contains(query) ||
          chapter.chapterNumber?.toString().contains(query) == true) {
        entries.add(MapEntry<int, LnReaderChapter>(index, chapter));
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visible;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        key: const ValueKey<String>('chapter-list-sheet'),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text('Chapters', style: theme.textTheme.titleLarge),
                ),
                Text(
                  '${widget.chapters.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
            child: TextField(
              key: const ValueKey<String>('chapter-list-search'),
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Find a chapter',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear chapter search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      widget.chapters.isEmpty
                          ? 'No chapters are available.'
                          : 'No chapters match "$_query".',
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                : ListView.builder(
                    key: const ValueKey<String>('chapter-list'),
                    controller: _query.isEmpty ? _scrollController : null,
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    itemCount: visible.length,
                    itemBuilder: (context, position) {
                      final entry = visible[position];
                      return _ChapterTile(
                        index: entry.key,
                        chapter: entry.value,
                        isCurrent: entry.key == widget.currentIndex,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.index,
    required this.chapter,
    required this.isCurrent,
  });

  final int index;
  final LnReaderChapter chapter;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final number = chapter.chapterNumber;
    final subtitle = <String>[
      if (number != null) 'Chapter $number',
      if (chapter.releaseTime?.trim().isNotEmpty == true)
        chapter.releaseTime!.trim(),
    ].join(' · ');

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Material(
          color: isCurrent
              ? scheme.primary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: InkWell(
            key: ValueKey<String>('chapter-list-item-$index'),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            onTap: () => Navigator.of(context).pop(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isCurrent
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          chapter.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isCurrent
                                ? scheme.primary
                                : scheme.onSurface,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
