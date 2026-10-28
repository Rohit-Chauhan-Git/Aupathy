import 'package:flutter/material.dart';
import 'package:hive_ce/hive_ce.dart';

import '../models/novel_model.dart';
import '../models/plugin_model.dart';
import '../services/lnreader_http_client.dart';
import '../services/lnreader_novel_service.dart';
import '../services/lnreader_runtime_probe.dart';
import '../services/storage_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/lnreader_cover.dart';
import 'lnreader_novel_details_view.dart';

class LnReaderSourceSearchView extends StatefulWidget {
  const LnReaderSourceSearchView({
    super.key,
    required this.plugin,
    this.novelsBox,
    this.service,
  });

  final PluginModel plugin;
  final Box<NovelModel>? novelsBox;
  final LnReaderNovelApi? service;

  @override
  State<LnReaderSourceSearchView> createState() =>
      _LnReaderSourceSearchViewState();
}

class _LnReaderSourceSearchViewState extends State<LnReaderSourceSearchView> {
  final TextEditingController _searchController = TextEditingController();
  late final LnReaderNovelApi _service;
  DioLnReaderHttpClient? _ownedClient;

  final List<LnReaderSearchItem> _results = <LnReaderSearchItem>[];
  final Set<String> _paths = <String>{};
  String _query = '';
  String _submittedQuery = '';
  String? _error;
  bool _loading = false;
  bool _loadingMore = false;
  bool _searched = false;
  bool _noMore = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    if (widget.service != null) {
      _service = widget.service!;
    } else {
      final client = DioLnReaderHttpClient();
      _ownedClient = client;
      _service = LnReaderNovelService(
        executorFactory: QuickJsLnReaderPluginExecutorFactory(
          runtimeFactory: QuickJsScriptRuntimeFactory(httpClient: client),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _ownedClient?.close();
    super.dispose();
  }

  Box<NovelModel>? get _novelsBox {
    try {
      final box = widget.novelsBox ?? StorageService.instance.novelsBox;
      return box.isOpen ? box : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _search({bool reset = true}) async {
    if (_loading || _loadingMore) return;
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    if (!reset && _noMore) return;

    final page = reset ? 1 : _page + 1;
    setState(() {
      if (reset) {
        _loading = true;
        _results.clear();
        _paths.clear();
        _searched = false;
        _noMore = false;
        _page = 1;
        _error = null;
      } else {
        _loadingMore = true;
      }
      _query = query;
    });

    try {
      final results = await _service.searchNovels(
        widget.plugin,
        query,
        page: page,
      );
      if (!mounted) return;
      var added = 0;
      setState(() {
        for (final result in results) {
          if (_paths.add(result.path)) {
            _results.add(result);
            added++;
          }
        }
        _submittedQuery = query;
        _page = page;
        _searched = true;
        _loading = false;
        _loadingMore = false;
        _error = null;
        _noMore = results.isEmpty || added == 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error is LnReaderPluginException
            ? error.message
            : 'Search failed: $error';
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _submittedQuery = '';
      _results.clear();
      _paths.clear();
      _searched = false;
      _error = null;
      _noMore = false;
    });
  }

  Future<void> _openNovel(LnReaderSearchItem result) async {
    final box = _novelsBox;
    if (box == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Library storage is unavailable.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LnReaderNovelDetailsView(
          plugin: widget.plugin,
          result: result,
          service: _service,
          novelsBox: box,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.plugin.name),
            Text(
              'v${widget.plugin.version} · ${widget.plugin.lang.toUpperCase()}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: <Widget>[
          if (_query.isNotEmpty || _searched)
            IconButton(
              tooltip: 'Clear search',
              onPressed: _loading ? null : _clearSearch,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: TextField(
                key: const ValueKey<String>('source-search-field'),
                controller: _searchController,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Search ${widget.plugin.name}',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Search',
                          onPressed: _query.trim().isEmpty
                              ? null
                              : () => _search(),
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Searching the source…'),
          ],
        ),
      );
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Search failed',
        message: _error!,
        actionLabel: 'Try again',
        actionIcon: Icons.refresh_rounded,
        onAction: () => _search(),
      );
    }
    if (!_searched) {
      return EmptyState(
        icon: Icons.manage_search_rounded,
        title: 'Find a novel',
        message:
            'Search ${widget.plugin.name} for a title. Results come directly '
            'from the installed LNReader plugin.',
      );
    }
    if (_results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No novels found',
        message: 'No results matched "$_submittedQuery".',
        actionLabel: 'Clear search',
        actionIcon: Icons.close_rounded,
        onAction: _clearSearch,
      );
    }

    return ListView.builder(
      key: const PageStorageKey<String>('lnreader-search-results'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      itemCount: _results.length + 1,
      itemBuilder: (context, index) {
        if (index == _results.length) return _buildFooter();
        final result = _results[index];
        return Padding(
          key: ValueKey<String>('search-result-${result.path}'),
          padding: const EdgeInsets.only(bottom: 10),
          child: _SearchResultCard(
            result: result,
            sourceName: widget.plugin.name,
            onTap: () => _openNovel(result),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    final theme = Theme.of(context);
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_noMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('End of results', style: theme.textTheme.bodySmall),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      child: OutlinedButton.icon(
        key: const ValueKey<String>('load-more-results'),
        onPressed: () => _search(reset: false),
        icon: const Icon(Icons.expand_more_rounded),
        label: const Text('Load more results'),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.result,
    required this.sourceName,
    required this.onTap,
  });

  final LnReaderSearchItem result;
  final String sourceName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final author = result.author?.trim() ?? '';
    final subtitle = author.isEmpty ? sourceName : '$author · $sourceName';

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LnReaderCover(
                url: result.coverUrl,
                title: result.name,
                width: 62,
                height: 86,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      result.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: <Widget>[
                        Icon(Icons.menu_book_rounded, size: 14),
                        SizedBox(width: 4),
                        Text('View details'),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
