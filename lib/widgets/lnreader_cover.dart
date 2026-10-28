import 'package:flutter/material.dart';

class LnReaderCover extends StatelessWidget {
  const LnReaderCover({
    super.key,
    required this.url,
    required this.title,
    this.width = 64,
    this.height = 88,
    this.borderRadius = 10,
  });

  final String? url;
  final String title;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.all(Radius.circular(borderRadius));
    final fallback = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: width * 0.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    final value = url?.trim() ?? '';

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: value.isEmpty
            ? fallback
            : Image.network(
                value,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: progress.expectedTotalBytes == null
                              ? null
                              : progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
