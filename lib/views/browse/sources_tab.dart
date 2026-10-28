import 'package:flutter/material.dart';

import '../../models/source_entry.dart';
import '../../theme/app_theme.dart';
import '../../widgets/browse_item_card.dart';
import '../../widgets/empty_state.dart';

class SourcesTab extends StatelessWidget {
  const SourcesTab({
    super.key,
    required this.sources,
    required this.query,
    required this.onClearSearch,
    this.onOpenSource,
  });

  final List<SourceEntry> sources;
  final String query;
  final VoidCallback onClearSearch;
  final ValueChanged<SourceEntry>? onOpenSource;

  List<SourceEntry> get _visibleSources {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return sources;
    return sources
        .where((source) {
          final searchable = <String>[
            source.name,
            source.language,
            source.description,
            source.baseUrl ?? '',
          ].join(' ').toLowerCase();
          return searchable.contains(needle);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return const _SourcesScrollView(
        child: EmptyState(
          icon: Icons.public_off_rounded,
          title: 'No sources available',
          message:
              'Source plugins and novels from your library will appear here. '
              'Browsing external sources is not available yet.',
        ),
      );
    }

    final visible = _visibleSources;
    if (visible.isEmpty) {
      return _SourcesScrollView(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No sources found',
          message:
              'No source names, languages, or descriptions match "$query".',
          actionLabel: 'Clear search',
          actionIcon: Icons.close_rounded,
          onAction: onClearSearch,
        ),
      );
    }

    return CustomScrollView(
      key: const PageStorageKey<String>('browse-sources'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              title: query.trim().isEmpty ? 'Source catalog' : 'Search results',
              count: visible.length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final source = visible[index];
              return Padding(
                key: ValueKey<String>('source-${source.id}-${source.name}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: _SourceCard(
                  source: source,
                  onTap: () {
                    if (source.hasPlugin &&
                        source.isInstalled &&
                        source.isEnabled &&
                        onOpenSource != null) {
                      onOpenSource!(source);
                    } else {
                      _showSourceDetails(context, source);
                    }
                  },
                ),
              );
            }, childCount: visible.length),
          ),
        ),
      ],
    );
  }

  void _showSourceDetails(BuildContext context, SourceEntry source) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _SourceDetailsSheet(source: source),
    );
  }
}

class _SourcesScrollView extends StatelessWidget {
  const _SourcesScrollView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey<String>('browse-sources'),
      slivers: <Widget>[
        SliverFillRemaining(hasScrollBody: false, child: child),
      ],
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

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source, required this.onTap});

  final SourceEntry source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final metadata = <String>[
      source.languageLabel,
      if (source.host.isNotEmpty) source.host,
    ].join(' · ');

    final badges = <Widget>[
      if (source.hasPlugin)
        BrowseBadge(
          label: source.isInstalled ? 'Installed' : 'Not installed',
          icon: source.isInstalled
              ? Icons.check_circle_rounded
              : Icons.cloud_off_rounded,
          color: source.isInstalled
              ? AppColors.success
              : scheme.onSurfaceVariant,
        )
      else
        const BrowseBadge(
          label: 'From library',
          icon: Icons.library_books_rounded,
          color: AppColors.blueBright,
        ),
      if (source.hasPlugin && source.isInstalled && !source.isEnabled)
        const BrowseBadge(
          label: 'Disabled',
          icon: Icons.pause_circle_outline_rounded,
          color: AppColors.warning,
        ),
      if (source.recentNovelCount > 0)
        BrowseBadge(
          label: source.recentNovelCount == 1
              ? '1 novel'
              : '${source.recentNovelCount} novels',
          icon: Icons.menu_book_rounded,
          color: AppColors.indigoBright,
        ),
    ];

    return BrowseItemCard(
      leading: const BrowseLeadingIcon(icon: Icons.public_rounded),
      title: source.name,
      subtitle: metadata,
      description: source.description,
      badges: badges,
      trailing: Icon(
        Icons.info_outline_rounded,
        size: 20,
        color: scheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

class _SourceDetailsSheet extends StatelessWidget {
  const _SourceDetailsSheet({required this.source});

  final SourceEntry source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(source.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              source.languageLabel,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
            ),
            if (source.description.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(source.description, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            _DetailRow(label: 'Status', value: _statusLabel()),
            if (source.baseUrl?.trim().isNotEmpty == true)
              _DetailRow(label: 'Base URL', value: source.baseUrl!.trim()),
            _DetailRow(
              label: 'Library',
              value: source.recentNovelCount == 1
                  ? '1 novel'
                  : '${source.recentNovelCount} novels',
            ),
            if (source.lastUsedAt != null)
              _DetailRow(
                label: 'Last used',
                value: _formatDate(source.lastUsedAt!),
              ),
            const SizedBox(height: 20),
            Text(_availabilityMessage(), style: theme.textTheme.bodySmall),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel() {
    if (!source.hasPlugin) return 'Referenced by your library';
    if (!source.isInstalled) return 'Plugin not installed';
    return source.isEnabled ? 'Installed and enabled' : 'Installed, disabled';
  }

  String _availabilityMessage() {
    if (!source.hasPlugin) {
      return 'This source is referenced by novels in your Library. Install a '
          'source plugin to search it.';
    }
    if (!source.isInstalled) {
      return 'Install this source plugin from the LNReader repository before '
          'searching for novels.';
    }
    if (!source.isEnabled) {
      return 'This source is disabled. Enable it in Plugins to search for '
          'novels.';
    }
    return 'Search this source from its catalog card.';
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
