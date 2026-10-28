import 'package:flutter/material.dart';

import '../../models/plugin_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/browse_item_card.dart';
import '../../widgets/empty_state.dart';

enum PluginStatusFilter { all, installed, notInstalled }

class PluginsTab extends StatelessWidget {
  const PluginsTab({
    super.key,
    required this.plugins,
    required this.query,
    required this.filter,
    required this.onFilterChanged,
    required this.onClearSearch,
    this.onEnabledChanged,
    this.onOpenRepository,
  });

  final List<PluginModel> plugins;
  final String query;
  final PluginStatusFilter filter;
  final ValueChanged<PluginStatusFilter> onFilterChanged;
  final VoidCallback onClearSearch;
  final void Function(PluginModel plugin, bool enabled)? onEnabledChanged;
  final VoidCallback? onOpenRepository;

  List<PluginModel> get _visiblePlugins {
    final needle = query.trim().toLowerCase();
    final filtered = plugins.where((plugin) {
      final matchesFilter = switch (filter) {
        PluginStatusFilter.all => true,
        PluginStatusFilter.installed => plugin.isInstalled,
        PluginStatusFilter.notInstalled => !plugin.isInstalled,
      };
      if (!matchesFilter) return false;
      if (needle.isEmpty) return true;
      final searchable = <String>[
        plugin.name,
        plugin.packageName,
        plugin.description,
        plugin.version,
        plugin.lang,
        switch (plugin.type) {
          PluginType.source => 'Source',
          PluginType.tts => 'Text-to-speech',
          PluginType.extension => 'Extension',
        },
      ].join(' ').toLowerCase();
      return searchable.contains(needle);
    }).toList();

    filtered.sort((a, b) {
      if (a.isInstalled != b.isInstalled) return a.isInstalled ? -1 : 1;
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    if (plugins.isEmpty) {
      return CustomScrollView(
        key: const PageStorageKey<String>('browse-plugins'),
        slivers: <Widget>[
          if (onOpenRepository != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _RepositoryEntry(onTap: onOpenRepository!),
              ),
            ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.extension_off_rounded,
              title: 'No plugins installed',
              message:
                  'Installed source, text-to-speech, and extension plugins '
                  'will appear here. Browse the official LNReader repository '
                  'to download a source plugin.',
            ),
          ),
        ],
      );
    }

    final visible = _visiblePlugins;
    final hasQuery = query.trim().isNotEmpty;

    if (visible.isEmpty) {
      return _PluginsScrollView(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No plugins found',
          message: hasQuery
              ? 'No plugin names, packages, or languages match "$query".'
              : 'No plugins match the selected status filter.',
          actionLabel: hasQuery ? 'Clear search' : 'Show all plugins',
          actionIcon: hasQuery ? Icons.close_rounded : Icons.filter_alt_off,
          onAction: hasQuery
              ? onClearSearch
              : () => onFilterChanged(PluginStatusFilter.all),
        ),
      );
    }

    return CustomScrollView(
      key: const PageStorageKey<String>('browse-plugins'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: <Widget>[
        if (onOpenRepository != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            sliver: SliverToBoxAdapter(
              child: _RepositoryEntry(onTap: onOpenRepository!),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _PluginFilters(filter: filter, onChanged: onFilterChanged),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              title: hasQuery ? 'Search results' : 'Plugins',
              count: visible.length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final plugin = visible[index];
              return Padding(
                key: ValueKey<String>('plugin-${plugin.id}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: _PluginCard(
                  plugin: plugin,
                  onEnabledChanged: onEnabledChanged == null
                      ? null
                      : (enabled) => onEnabledChanged!(plugin, enabled),
                ),
              );
            }, childCount: visible.length),
          ),
        ),
      ],
    );
  }
}

class _RepositoryEntry extends StatelessWidget {
  const _RepositoryEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.cloud_download_rounded,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'LNReader repository',
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      'Official v3.0.0 source plugins',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PluginsScrollView extends StatelessWidget {
  const _PluginsScrollView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey<String>('browse-plugins'),
      slivers: <Widget>[
        SliverFillRemaining(hasScrollBody: false, child: child),
      ],
    );
  }
}

class _PluginFilters extends StatelessWidget {
  const _PluginFilters({required this.filter, required this.onChanged});

  final PluginStatusFilter filter;
  final ValueChanged<PluginStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _FilterChip(
            label: 'All',
            selected: filter == PluginStatusFilter.all,
            onSelected: () => onChanged(PluginStatusFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Installed',
            selected: filter == PluginStatusFilter.installed,
            onSelected: () => onChanged(PluginStatusFilter.installed),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Not installed',
            selected: filter == PluginStatusFilter.notInstalled,
            onSelected: () => onChanged(PluginStatusFilter.notInstalled),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$count',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PluginCard extends StatelessWidget {
  const _PluginCard({required this.plugin, this.onEnabledChanged});

  final PluginModel plugin;
  final ValueChanged<bool>? onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metadata = <String>[
      plugin.packageName,
      'v${plugin.version}',
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return BrowseItemCard(
      leading: BrowseLeadingIcon(
        icon: _typeIcon(plugin.type),
        gradient: _typeGradient(plugin.type),
      ),
      title: plugin.name,
      subtitle: metadata,
      description: plugin.description,
      badges: <Widget>[
        BrowseBadge(label: _typeLabel(plugin.type), color: scheme.primary),
        if (plugin.lang.trim().isNotEmpty)
          BrowseBadge(label: plugin.lang.toUpperCase()),
        BrowseBadge(
          label: plugin.isInstalled ? 'Installed' : 'Not installed',
          icon: plugin.isInstalled
              ? Icons.check_circle_rounded
              : Icons.cloud_off_rounded,
          color: plugin.isInstalled
              ? AppColors.success
              : scheme.onSurfaceVariant,
        ),
        if (plugin.isInstalled && !plugin.isEnabled)
          const BrowseBadge(
            label: 'Disabled',
            icon: Icons.pause_circle_outline_rounded,
            color: AppColors.warning,
          ),
        if (plugin.isPinned)
          const BrowseBadge(
            label: 'Pinned',
            icon: Icons.push_pin_rounded,
            color: AppColors.indigoBright,
          ),
      ],
      trailing: plugin.isInstalled && onEnabledChanged != null
          ? Tooltip(
              message: plugin.isEnabled ? 'Disable plugin' : 'Enable plugin',
              child: Switch(
                value: plugin.isEnabled,
                onChanged: onEnabledChanged,
              ),
            )
          : null,
    );
  }

  String _typeLabel(PluginType type) {
    return switch (type) {
      PluginType.source => 'Source',
      PluginType.tts => 'Text-to-speech',
      PluginType.extension => 'Extension',
    };
  }

  IconData _typeIcon(PluginType type) {
    return switch (type) {
      PluginType.source => Icons.public_rounded,
      PluginType.tts => Icons.record_voice_over_rounded,
      PluginType.extension => Icons.extension_rounded,
    };
  }

  Gradient _typeGradient(PluginType type) {
    return switch (type) {
      PluginType.source => AppGradients.primary,
      PluginType.tts => AppGradients.accent,
      PluginType.extension => AppGradients.cardHighlight,
    };
  }
}
