import 'package:flutter/material.dart';

import '../models/novel_model.dart';
import '../theme/app_theme.dart';
import 'reading_progress_bar.dart';

class NovelCard extends StatelessWidget {
  const NovelCard({super.key, required this.novel, this.onTap});

  final NovelModel novel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extension = theme.extension<AppThemeExtension>();
    final cardGradient = extension?.cardGradient ?? AppGradients.card;
    final byline = novel.author.trim().isEmpty
        ? 'Unknown author'
        : novel.author.trim();
    final metadata = novel.sourceName.trim().isEmpty
        ? byline
        : '$byline · ${novel.sourceName.trim()}';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                NovelCover(
                  title: novel.title,
                  coverUrl: novel.coverUrl,
                  isFavorite: novel.isFavorite,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              novel.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          if (novel.isDownloaded) ...<Widget>[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.download_done_rounded,
                              size: 16,
                              color: scheme.primary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        metadata,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (novel.genres.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          novel.genres.take(2).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      ReadingProgressBar(
                        progress: novel.readingProgress,
                        chapterCount: novel.chapterCount,
                        lastReadChapter: novel.lastReadChapter,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NovelCover extends StatelessWidget {
  const NovelCover({
    super.key,
    required this.title,
    this.coverUrl,
    this.isFavorite = false,
    this.width = 92,
    this.height = 126,
  });

  final String title;
  final String? coverUrl;
  final bool isFavorite;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = coverUrl?.trim();

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              child: url == null || url.isEmpty
                  ? _CoverFallback(title: title)
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) {
                        return _CoverFallback(title: title);
                      },
                    ),
            ),
          ),
          if (isFavorite)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.accent),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _initialsFor(title),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _initialsFor(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2);
    final initials = words
        .map((word) => String.fromCharCode(word.runes.first).toUpperCase())
        .join();
    return initials.isEmpty ? '?' : initials;
  }
}
