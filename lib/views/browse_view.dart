import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/novel_model.dart';
import '../models/plugin_model.dart';
import '../models/source_entry.dart';
import '../models/voice_model.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/library_search_field.dart';
import 'browse/plugins_tab.dart';
import 'browse/sources_tab.dart';
import 'browse/voices_tab.dart';
import 'lnreader_diagnostics_view.dart';
import 'lnreader_source_search_view.dart';
import 'lnreader_repository_view.dart';

/// Browse section with Sources, Plugins, and Voices tabs.
///
/// Catalog data comes from the existing Hive boxes. The LNReader repository
/// performs live manifest and bundle downloads, but novel browsing and voice
/// playback are not wired into this view.
class BrowseView extends StatefulWidget {
  const BrowseView({
    super.key,
    this.pluginsBox,
    this.voicesBox,
    this.novelsBox,
  });

  /// Optional box overrides for tests.
  final Box<PluginModel>? pluginsBox;
  final Box<VoiceModel>? voicesBox;
  final Box<NovelModel>? novelsBox;

  @override
  State<BrowseView> createState() => _BrowseViewState();
}

class _BrowseViewState extends State<BrowseView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  int _tabIndex = 0;
  PluginStatusFilter _pluginFilter = PluginStatusFilter.all;
  String? _voiceLanguage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabIndex == _tabController.index) return;
    setState(() => _tabIndex = _tabController.index);
  }

  void _handleSearchChanged(String value) {
    setState(() => _query = value);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _retry() => setState(() {});

  String get _searchHint {
    return switch (_tabIndex) {
      0 => 'Search sources',
      1 => 'Search plugins',
      _ => 'Search voices',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(bottom: false, child: _buildBody()));
  }

  Widget _buildBody() {
    late final Box<PluginModel> pluginsBox;
    late final Box<VoiceModel> voicesBox;
    late final Box<NovelModel> novelsBox;

    try {
      pluginsBox = widget.pluginsBox ?? StorageService.instance.pluginsBox;
      voicesBox = widget.voicesBox ?? StorageService.instance.voicesBox;
      novelsBox = widget.novelsBox ?? StorageService.instance.novelsBox;
      if (!pluginsBox.isOpen || !voicesBox.isOpen || !novelsBox.isOpen) {
        throw StateError('A Browse storage box is closed.');
      }
    } catch (_) {
      return _BrowseUnavailable(onRetry: _retry);
    }

    final listenable = Listenable.merge(<Listenable>[
      pluginsBox.listenable(),
      voicesBox.listenable(),
      novelsBox.listenable(),
    ]);

    return ListenableBuilder(
      listenable: listenable,
      builder: (context, child) {
        if (!pluginsBox.isOpen || !voicesBox.isOpen || !novelsBox.isOpen) {
          return _BrowseUnavailable(onRetry: _retry);
        }
        try {
          return _buildBrowse(pluginsBox, voicesBox, novelsBox);
        } catch (_) {
          return _BrowseUnavailable(onRetry: _retry);
        }
      },
    );
  }

  Widget _buildBrowse(
    Box<PluginModel> pluginsBox,
    Box<VoiceModel> voicesBox,
    Box<NovelModel> novelsBox,
  ) {
    final plugins = pluginsBox.values.toList(growable: false);
    final voices = voicesBox.values.toList(growable: false);
    final novels = novelsBox.values.toList(growable: false);
    final sources = buildSourceCatalog(plugins: plugins, novels: novels);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: _BrowseHeader(
            sourceCount: sources.length,
            pluginCount: plugins.length,
            voiceCount: voices.length,
            onDiagnostics: _openDiagnostics,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: LibrarySearchField(
            controller: _searchController,
            hintText: _searchHint,
            onChanged: _handleSearchChanged,
            onClear: _clearSearch,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: _BrowseTabBar(controller: _tabController),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: <Widget>[
              SourcesTab(
                sources: sources,
                query: _query,
                onClearSearch: _clearSearch,
                onOpenSource: (source) =>
                    _openSource(pluginsBox, novelsBox, source),
              ),
              PluginsTab(
                plugins: plugins,
                query: _query,
                filter: _pluginFilter,
                onFilterChanged: (filter) {
                  setState(() => _pluginFilter = filter);
                },
                onClearSearch: _clearSearch,
                onEnabledChanged: (plugin, enabled) {
                  _updatePluginEnabled(pluginsBox, plugin, enabled);
                },
                onOpenRepository: () => _openRepository(pluginsBox),
              ),
              VoicesTab(
                voices: voices,
                query: _query,
                languageFilter: _voiceLanguage,
                onLanguageFilterChanged: (language) {
                  setState(() => _voiceLanguage = language);
                },
                onClearSearch: _clearSearch,
                onFavoriteChanged: (voice, favorite) {
                  _updateVoiceFavorite(voicesBox, voice, favorite);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openDiagnostics() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const LnReaderDiagnosticsView(),
      ),
    );
  }

  void _openRepository(Box<PluginModel> pluginsBox) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LnReaderRepositoryView(pluginsBox: pluginsBox),
      ),
    );
  }

  void _openSource(
    Box<PluginModel> pluginsBox,
    Box<NovelModel> novelsBox,
    SourceEntry source,
  ) {
    PluginModel? plugin;
    for (final candidate in pluginsBox.values) {
      if (candidate.id == source.id && candidate.type == PluginType.source) {
        plugin = candidate;
        break;
      }
    }
    if (plugin == null || !plugin.isInstalled || !plugin.isEnabled) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            LnReaderSourceSearchView(plugin: plugin!, novelsBox: novelsBox),
      ),
    );
  }

  Future<void> _updatePluginEnabled(
    Box<PluginModel> box,
    PluginModel plugin,
    bool enabled,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final key = _findKey<PluginModel>(box, (value) => value.id == plugin.id);
      if (key == null) {
        throw StateError('Plugin ${plugin.id} is not stored in the box.');
      }
      await box.put(key, plugin.copyWith(isEnabled: enabled));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update the plugin.')),
      );
    }
  }

  Future<void> _updateVoiceFavorite(
    Box<VoiceModel> box,
    VoiceModel voice,
    bool favorite,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final key = _findKey<VoiceModel>(box, (value) => value.id == voice.id);
      if (key == null) {
        throw StateError('Voice ${voice.id} is not stored in the box.');
      }
      await box.put(key, voice.copyWith(isFavorite: favorite));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update the voice.')),
      );
    }
  }

  Object? _findKey<T>(Box<T> box, bool Function(T value) test) {
    for (final key in box.keys) {
      final value = box.get(key);
      if (value != null && test(value)) return key;
    }
    return null;
  }
}

class _BrowseHeader extends StatelessWidget {
  const _BrowseHeader({
    required this.sourceCount,
    required this.pluginCount,
    required this.voiceCount,
    required this.onDiagnostics,
  });

  final int sourceCount;
  final int pluginCount;
  final int voiceCount;
  final VoidCallback onDiagnostics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extension = theme.extension<AppThemeExtension>();
    final gradient = extension?.primaryGradient ?? AppGradients.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'DISCOVER',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 6),
              Text('Browse', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                '${_count(sourceCount, 'source')} · '
                '${_count(pluginCount, 'plugin')} · '
                '${_count(voiceCount, 'voice')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          tooltip: 'LNReader diagnostics',
          onPressed: onDiagnostics,
          icon: const Icon(Icons.science_outlined),
        ),
        const SizedBox(width: 10),
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
            Icons.explore_rounded,
            size: 27,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  String _count(int value, String singular) {
    return value == 1 ? '1 $singular' : '$value ${singular}s';
  }
}

class _BrowseTabBar extends StatelessWidget {
  const _BrowseTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.18),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.45)),
        ),
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: theme.textTheme.labelLarge,
        unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        splashBorderRadius: const BorderRadius.all(Radius.circular(10)),
        tabs: const <Widget>[
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Sources', textAlign: TextAlign.center),
            ),
          ),
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Plugins', textAlign: TextAlign.center),
            ),
          ),
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Voices', textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowseUnavailable extends StatelessWidget {
  const _BrowseUnavailable({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Could not load Browse',
      message: 'Your local plugin, voice, and library data could not be read.',
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}
