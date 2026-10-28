import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ReadingProgressBar extends StatelessWidget {
  const ReadingProgressBar({
    super.key,
    required this.progress,
    required this.chapterCount,
    required this.lastReadChapter,
  });

  final double progress;
  final int chapterCount;
  final int lastReadChapter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extension = theme.extension<AppThemeExtension>();
    final gradient = extension?.primaryGradient ?? AppGradients.primary;
    final value = progress.clamp(0.0, 1.0);
    final percentage = (value * 100).round();

    final String label;
    if (chapterCount <= 0) {
      label = 'No chapters yet';
    } else if (lastReadChapter <= 0) {
      label = 'Not started';
    } else if (lastReadChapter >= chapterCount) {
      label = 'Completed';
    } else {
      label = 'Chapter $lastReadChapter of $chapterCount';
    }

    return Semantics(
      label: '$label, $percentage percent read',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percentage%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: value > 0 ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(99)),
            child: SizedBox(
              height: 5,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(color: scheme.surfaceContainerHighest),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: gradient),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
