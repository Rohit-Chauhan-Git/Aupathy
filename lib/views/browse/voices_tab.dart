import 'package:flutter/material.dart';

import '../../models/voice_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/browse_item_card.dart';
import '../../widgets/empty_state.dart';

class VoicesTab extends StatelessWidget {
  const VoicesTab({
    super.key,
    required this.voices,
    required this.query,
    required this.languageFilter,
    required this.onLanguageFilterChanged,
    required this.onClearSearch,
    this.onFavoriteChanged,
  });

  final List<VoiceModel> voices;
  final String query;
  final String? languageFilter;
  final ValueChanged<String?> onLanguageFilterChanged;
  final VoidCallback onClearSearch;
  final void Function(VoiceModel voice, bool favorite)? onFavoriteChanged;

  List<String> get _languages {
    final values = voices
        .map((voice) => voice.language.trim())
        .where((language) => language.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  List<VoiceModel> get _visibleVoices {
    final needle = query.trim().toLowerCase();
    final filtered = voices.where((voice) {
      if (languageFilter != null &&
          voice.language.trim().toLowerCase() !=
              languageFilter!.trim().toLowerCase()) {
        return false;
      }
      if (needle.isEmpty) return true;
      final searchable = <String>[
        voice.name,
        voice.engine,
        voice.language,
        voice.locale ?? '',
        voice.gender,
        voice.sampleRate.toString(),
      ].join(' ').toLowerCase();
      return searchable.contains(needle);
    }).toList();

    filtered.sort((a, b) {
      if (a.isInstalled != b.isInstalled) return a.isInstalled ? -1 : 1;
      if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    if (voices.isEmpty) {
      return const _VoicesScrollView(
        child: EmptyState(
          icon: Icons.graphic_eq_rounded,
          title: 'No voices available',
          message:
              'Voice catalog entries will appear here. Voice model installation '
              'and audio preview are not available yet.',
        ),
      );
    }

    final visible = _visibleVoices;
    final hasQuery = query.trim().isNotEmpty;
    final languages = _languages;

    if (visible.isEmpty) {
      return _VoicesScrollView(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No voices found',
          message: hasQuery
              ? 'No voice names, engines, or languages match "$query".'
              : 'No voices match the selected language.',
          actionLabel: hasQuery ? 'Clear search' : 'Show all voices',
          actionIcon: hasQuery ? Icons.close_rounded : Icons.filter_alt_off,
          onAction: hasQuery
              ? onClearSearch
              : () => onLanguageFilterChanged(null),
        ),
      );
    }

    return CustomScrollView(
      key: const PageStorageKey<String>('browse-voices'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: <Widget>[
        if (languages.length > 1)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _LanguageFilters(
                languages: languages,
                selected: languageFilter,
                onChanged: onLanguageFilterChanged,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              title: hasQuery ? 'Search results' : 'Voices',
              count: visible.length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final voice = visible[index];
              return Padding(
                key: ValueKey<String>('voice-${voice.id}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: _VoiceCard(
                  voice: voice,
                  onFavoriteChanged: onFavoriteChanged == null
                      ? null
                      : (favorite) => onFavoriteChanged!(voice, favorite),
                ),
              );
            }, childCount: visible.length),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
          sliver: SliverToBoxAdapter(child: _VoiceNotice()),
        ),
      ],
    );
  }
}

class _VoicesScrollView extends StatelessWidget {
  const _VoicesScrollView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey<String>('browse-voices'),
      slivers: <Widget>[
        SliverFillRemaining(hasScrollBody: false, child: child),
      ],
    );
  }
}

class _LanguageFilters extends StatelessWidget {
  const _LanguageFilters({
    required this.languages,
    required this.selected,
    required this.onChanged,
  });

  final List<String> languages;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          ChoiceChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          for (final language in languages) ...<Widget>[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(language.toUpperCase()),
              selected: selected?.toLowerCase() == language.toLowerCase(),
              onSelected: (_) => onChanged(language),
            ),
          ],
        ],
      ),
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

class _VoiceCard extends StatelessWidget {
  const _VoiceCard({required this.voice, this.onFavoriteChanged});

  final VoiceModel voice;
  final ValueChanged<bool>? onFavoriteChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metadata = <String>[
      voice.engine,
      voice.locale?.trim().isNotEmpty == true
          ? voice.locale!.trim()
          : voice.language.toUpperCase(),
      _capitalize(voice.gender),
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return BrowseItemCard(
      leading: BrowseLeadingIcon(
        icon: Icons.graphic_eq_rounded,
        gradient: AppGradients.accent,
      ),
      title: voice.name,
      subtitle: metadata,
      badges: <Widget>[
        if (voice.language.trim().isNotEmpty)
          BrowseBadge(
            label: voice.language.toUpperCase(),
            color: scheme.primary,
          ),
        BrowseBadge(
          label: voice.isInstalled ? 'Installed' : 'Not installed',
          icon: voice.isInstalled
              ? Icons.check_circle_rounded
              : Icons.cloud_off_rounded,
          color: voice.isInstalled
              ? AppColors.success
              : scheme.onSurfaceVariant,
        ),
        BrowseBadge(label: '${voice.sampleRate} Hz', icon: Icons.speed_rounded),
      ],
      trailing: onFavoriteChanged == null
          ? null
          : IconButton(
              tooltip: voice.isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
              onPressed: () => onFavoriteChanged!(!voice.isFavorite),
              icon: Icon(
                voice.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: voice.isFavorite
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
            ),
    );
  }

  String _capitalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }
}

class _VoiceNotice extends StatelessWidget {
  const _VoiceNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Voice preview and model downloads are not available yet. '
              'Catalog metadata and favorites are stored locally.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
