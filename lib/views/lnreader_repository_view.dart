import 'package:flutter/material.dart';
import 'package:hive_ce/hive_ce.dart';

import '../models/lnreader_manifest_entry.dart';
import '../models/plugin_model.dart';
import '../services/lnreader_http_client.dart';
import '../services/lnreader_plugin_repository.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/browse_item_card.dart';
import '../widgets/empty_state.dart';

class LnReaderRepositoryView extends StatefulWidget {
  const LnReaderRepositoryView({super.key, this.repository, this.pluginsBox});

  final LnReaderRepositoryApi? repository;
  final Box<PluginModel>? pluginsBox;

  @override
  State<LnReaderRepositoryView> createState() => _LnReaderRepositoryViewState();
}

class _LnReaderRepositoryViewState extends State<LnReaderRepositoryView> {
  late final LnReaderRepositoryApi _repository;
  late final Box<PluginModel> _pluginsBox;
  DioLnReaderHttpClient? _ownedClient;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _installing = <String>{};
  final Set<String> _installedIds = <String>{};

  LnReaderManifest? _manifest;
  String? _error;
  bool _loading = true;
  String _query = '';
  String _language = '';

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) {
      _repository = widget.repository!;
    } else {
      final client = DioLnReaderHttpClient();
      _ownedClient = client;
      _repository = LnReaderPluginRepository(httpClient: client);
    }
    _pluginsBox = widget.pluginsBox ?? StorageService.instance.pluginsBox;
    _reloadInstalled();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _ownedClient?.close();
    super.dispose();
  }

  void _reloadInstalled() {
    _installedIds
      ..clear()
      ..addAll(
        _pluginsBox.values
            .map(
              (plugin) => plugin.metadata[LnReaderPluginRepository.metadataId]
                  ?.toString(),
            )
            .whereType<String>(),
      );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _repository.fetchManifest();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _manifest = result.manifest;
      _error = result.error;
    });
  }

  Future<void> _install(LnReaderManifestEntry entry) async {
    if (_installing.contains(entry.id) || _installedIds.contains(entry.id)) {
      return;
    }
    setState(() => _installing.add(entry.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await _repository.install(entry: entry, box: _pluginsBox);
      if (!mounted) return;
      setState(() => _installedIds.add(entry.id));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Installed ${entry.name} · ${result.bundleBytes} bytes.',
          ),
        ),
      );
    } on LnReaderPluginInstallException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not install ${entry.name}: $error')),
      );
    } finally {
      if (mounted) setState(() => _installing.remove(entry.id));
    }
  }

  List<LnReaderManifestEntry> get _visibleEntries {
    final entries = _manifest?.entries ?? const <LnReaderManifestEntry>[];
    final needle = _query.trim().toLowerCase();
    return entries
        .where((entry) {
          if (_language.isNotEmpty && entry.lang != _language) return false;
          if (needle.isEmpty) return true;
          return <String>[
            entry.name,
            entry.id,
            entry.lang,
            entry.site,
            entry.version,
          ].join(' ').toLowerCase().contains(needle);
        })
        .toList(growable: false);
  }

  List<String> get _languages {
    final values = <String>{
      for (final entry in _manifest?.entries ?? const <LnReaderManifestEntry>[])
        entry.lang,
    }.toList();
    values.sort();
    return values;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LNReader repository'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh repository',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const _RepositoryLoading()
            : _error != null
            ? _RepositoryError(message: _error!, onRetry: _load)
            : _buildCatalog(context),
      ),
    );
  }

  Widget _buildCatalog(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final manifest = _manifest;
    final visible = _visibleEntries;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                manifest == null
                    ? 'Official repository'
                    : '${manifest.validCount} plugins · '
                          '${manifest.invalidCount} rejected · '
                          'v3.0.0',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search repository plugins',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('All languages'),
                      selected: _language.isEmpty,
                      onSelected: (_) => setState(() => _language = ''),
                    ),
                    for (final language in _languages) ...<Widget>[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(language.toUpperCase()),
                        selected: _language == language,
                        onSelected: (_) => setState(() => _language = language),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: visible.isEmpty
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No repository plugins found',
                  message: _query.trim().isEmpty
                      ? 'No plugins match the selected language.'
                      : 'No plugin names, ids, or sites match "$_query".',
                  actionLabel: 'Clear filters',
                  actionIcon: Icons.filter_alt_off_rounded,
                  onAction: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                      _language = '';
                    });
                  },
                )
              : ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final entry = visible[index];
                    return Padding(
                      key: ValueKey<String>('repository-plugin-${entry.id}'),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RepositoryPluginCard(
                        entry: entry,
                        installed: _installedIds.contains(entry.id),
                        installing: _installing.contains(entry.id),
                        onInstall: () => _install(entry),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RepositoryLoading extends StatelessWidget {
  const _RepositoryLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Fetching the official LNReader manifest…'),
        ],
      ),
    );
  }
}

class _RepositoryError extends StatelessWidget {
  const _RepositoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Could not load the repository',
      message: message,
      actionLabel: 'Try again',
      actionIcon: Icons.refresh_rounded,
      onAction: onRetry,
    );
  }
}

class _RepositoryPluginCard extends StatelessWidget {
  const _RepositoryPluginCard({
    required this.entry,
    required this.installed,
    required this.installing,
    required this.onInstall,
  });

  final LnReaderManifestEntry entry;
  final bool installed;
  final bool installing;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final host = Uri.tryParse(entry.site)?.host ?? entry.site;

    return BrowseItemCard(
      leading: const BrowseLeadingIcon(icon: Icons.public_rounded),
      title: entry.name,
      subtitle: 'v${entry.version} · ${entry.lang.toUpperCase()} · $host',
      description: entry.id,
      badges: <Widget>[
        BrowseBadge(label: entry.lang.toUpperCase(), color: scheme.primary),
        BrowseBadge(
          label: installed ? 'Installed' : 'Available',
          icon: installed
              ? Icons.check_circle_rounded
              : Icons.cloud_download_outlined,
          color: installed ? AppColors.success : scheme.onSurfaceVariant,
        ),
      ],
      trailing: installing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              tooltip: installed ? 'Installed' : 'Download ${entry.name}',
              onPressed: installed ? null : onInstall,
              icon: Icon(
                installed ? Icons.check_circle_rounded : Icons.download_rounded,
                color: installed ? AppColors.success : scheme.primary,
              ),
            ),
      onTap: installed ? null : onInstall,
    );
  }
}
