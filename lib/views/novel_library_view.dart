import 'package:flutter/material.dart';

import '../models/novel_model.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/library_search_field.dart';
import '../widgets/novel_card.dart';

class NovelLibraryView extends StatefulWidget {
  const NovelLibraryView({super.key, required this.novels, this.onOpenNovel});

  final List<NovelModel> novels;
  final ValueChanged<NovelModel>? onOpenNovel;

  @override
  State<NovelLibraryView> createState() => _NovelLibraryViewState();
}

class _NovelLibraryViewState extends State<NovelLibraryView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<NovelModel> get _visibleNovels {
    final query = _query.trim().toLowerCase();
    final matches = widget.novels.where((novel) {
      if (query.isEmpty) return true;
      final searchable = <String>[
        novel.title,
        novel.author,
        novel.sourceName,
        ...novel.genres,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();

    matches.sort(_compareNovels);
    return matches;
  }

  int _compareNovels(NovelModel a, NovelModel b) {
    final aDate = a.lastReadAt ?? a.dateAdded;
    final bDate = b.lastReadAt ?? b.dateAdded;
    if (aDate != null && bDate != null) {
      final byDate = bDate.compareTo(aDate);
      if (byDate != 0) return byDate;
    } else if (aDate != null) {
      return -1;
    } else if (bDate != null) {
      return 1;
    }
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleNovels = _visibleNovels;
    final hasQuery = _query.trim().isNotEmpty;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final cardExtent = 156.0 + (textScale - 1).clamp(0.0, 1.0) * 104.0;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _LibraryHeader(novels: widget.novels),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: LibrarySearchField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
            ),
          ),
        ),
        if (widget.novels.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      hasQuery ? 'Search results' : 'All novels',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${visibleNovels.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (visibleNovels.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: hasQuery
                  ? Icons.search_off_rounded
                  : Icons.auto_stories_outlined,
              title: hasQuery ? 'No novels found' : 'Your library is empty',
              message: hasQuery
                  ? 'No titles, authors, or sources match your search.'
                  : 'Add a novel source plugin and import your first novel. '
                        'Your reading progress will appear here.',
              actionLabel: hasQuery ? 'Clear search' : null,
              actionIcon: hasQuery ? Icons.close_rounded : null,
              onAction: hasQuery ? _clearSearch : null,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 460,
                mainAxisExtent: cardExtent,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final novel = visibleNovels[index];
                return NovelCard(
                  novel: novel,
                  onTap: widget.onOpenNovel == null
                      ? null
                      : () => widget.onOpenNovel!(novel),
                );
              }, childCount: visibleNovels.length),
            ),
          ),
      ],
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.novels});

  final List<NovelModel> novels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extension = theme.extension<AppThemeExtension>();
    final gradient = extension?.primaryGradient ?? AppGradients.primary;
    final total = novels.length;
    final inProgress = novels.where((novel) => novel.isInProgress).length;
    final totalLabel = total == 1 ? '1 novel' : '$total novels';
    final summary = total == 0
        ? 'No novels yet'
        : '$totalLabel · $inProgress in progress';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'YOUR COLLECTION',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 6),
              Text('Library', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(summary, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            size: 27,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
