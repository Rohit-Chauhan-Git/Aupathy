import 'package:flutter/material.dart';
import 'package:hive_ce/hive_ce.dart';

import '../models/novel_model.dart';
import '../models/plugin_model.dart';
import '../services/lnreader_http_client.dart';
import '../services/lnreader_library_importer.dart';
import '../services/lnreader_novel_service.dart';
import '../services/lnreader_runtime_probe.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/lnreader_cover.dart';

class LnReaderNovelDetailsView extends StatefulWidget {
  const LnReaderNovelDetailsView({
    super.key,
    required this.plugin,
    required this.result,
    this.service,
    this.novelsBox,
    this.importer = const LnReaderLibraryImporter(),
  });

  final PluginModel plugin;
  final LnReaderSearchItem result;
  final LnReaderNovelApi? service;
  final Box<NovelModel>? novelsBox;
  final LnReaderLibraryImporter importer;

  @override
  State<LnReaderNovelDetailsView> createState() =>
      _LnReaderNovelDetailsViewState();
}

class _LnReaderNovelDetailsViewState extends State<LnReaderNovelDetailsView> {
  late final LnReaderNovelApi _service;
  DioLnReaderHttpClient? _ownedClient;

  LnReaderNovelDetails? _details;
  String? _error;
  bool _loading = true;
  bool _importing = false;
  LnReaderImportResult? _importResult;

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
    _load();
  }

  @override
  void dispose() {
    _ownedClient?.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await _service.parseNovel(
        widget.plugin,
        widget.result.path,
      );
      if (!mounted) return;
      setState(() {
        _details = details;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is LnReaderPluginException
            ? error.message
            : 'Could not load the novel: $error';
      });
    }
  }

  Future<void> _import() async {
    final details = _details;
    if (details == null || _importing) return;
    final box = _novelsBox;
    if (box == null) {
      _showMessage('Library storage is unavailable.');
      return;
    }

    setState(() => _importing = true);
    try {
      final result = await widget.importer.import(
        box: box,
        plugin: widget.plugin,
        details: details,
      );
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importResult = result;
      });
      _showMessage(
        result.created
            ? 'Added ${details.name} to your Library.'
            : 'Updated ${details.name} in your Library.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _importing = false);
      _showMessage('Could not import the novel: $error');
    }
  }

  Box<NovelModel>? get _novelsBox {
    try {
      final box = widget.novelsBox ?? StorageService.instance.novelsBox;
      return box.isOpen ? box : null;
    } catch (_) {
      return null;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.result.name),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reload novel details',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(bottom: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Loading novel details…'),
          ],
        ),
      );
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load this novel',
        message: _error!,
        actionLabel: 'Try again',
        actionIcon: Icons.refresh_rounded,
        onAction: _load,
      );
    }
    final details = _details;
    if (details == null) {
      return EmptyState(
        icon: Icons.auto_stories_outlined,
        title: 'No novel details',
        message: 'The plugin returned no details for this novel.',
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    return CustomScrollView(
      key: const PageStorageKey<String>('lnreader-novel-details'),
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _NovelHeader(
              plugin: widget.plugin,
              details: details,
              importing: _importing,
              imported: _importResult != null,
              onImport: _import,
            ),
          ),
        ),
        if (details.summary.trim().isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _SectionPanel(
                title: 'Synopsis',
                child: SelectableText(
                  details.summary,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        if (details.genres.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _SectionPanel(
                title: 'Genres',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final genre in details.genres)
                      Chip(
                        label: Text(genre),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Chapters',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${details.chapters.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (details.chapters.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: _ChaptersUnavailable(),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final chapter = details.chapters[index];
                return _ChapterTile(chapter: chapter, index: index);
              }, childCount: details.chapters.length),
            ),
          ),
      ],
    );
  }
}

class _NovelHeader extends StatelessWidget {
  const _NovelHeader({
    required this.plugin,
    required this.details,
    required this.importing,
    required this.imported,
    required this.onImport,
  });

  final PluginModel plugin;
  final LnReaderNovelDetails details;
  final bool importing;
  final bool imported;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final host = Uri.tryParse(details.sourceUrl)?.host ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LnReaderCover(
              url: details.coverUrl,
              title: details.name,
              width: 112,
              height: 158,
              borderRadius: 14,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(details.name, style: theme.textTheme.titleLarge),
                  if (details.author.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(details.author, style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      Chip(
                        label: Text(plugin.name),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(details.status),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (host.isNotEmpty)
                        Chip(
                          label: Text(host),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${details.chapters.length} chapters',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey<String>('import-novel'),
            onPressed: importing ? null : onImport,
            icon: importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    imported ? Icons.sync_rounded : Icons.library_add_rounded,
                  ),
            label: Text(
              importing
                  ? 'Importing…'
                  : imported
                  ? 'Update library entry'
                  : 'Add to Library',
            ),
          ),
        ),
        if (details.sourceUrl.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          SelectableText(details.sourceUrl, style: theme.textTheme.labelSmall),
        ],
      ],
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.chapter, required this.index});

  final LnReaderChapter chapter;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = chapter.chapterNumber;
    final details = <String>[
      if (number != null) 'Chapter $number',
      if (chapter.releaseTime?.trim().isNotEmpty == true)
        chapter.releaseTime!.trim(),
    ].join(' · ');

    return Padding(
      key: ValueKey<String>('chapter-${chapter.path}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 34,
              child: Text(
                '${index + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(chapter.name, style: theme.textTheme.bodyMedium),
                  if (details.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(details, style: theme.textTheme.labelSmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChaptersUnavailable extends StatelessWidget {
  const _ChaptersUnavailable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'The plugin did not return a chapter list for this novel.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
