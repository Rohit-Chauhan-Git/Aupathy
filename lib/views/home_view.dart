import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/novel_model.dart';
import '../models/plugin_model.dart';
import '../services/storage_service.dart';
import '../widgets/empty_state.dart';
import 'reader/reader_view.dart';
import 'novel_library_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key, this.novelsBox, this.pluginsBox});

  /// Optional box overrides for tests. When omitted, the shared
  /// [StorageService] boxes are used.
  final Box<NovelModel>? novelsBox;
  final Box<PluginModel>? pluginsBox;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  void _retry() => setState(() {});

  @override
  Widget build(BuildContext context) {
    Box<NovelModel>? novelsBox;
    try {
      novelsBox = widget.novelsBox ?? StorageService.instance.novelsBox;
      if (!novelsBox.isOpen) {
        throw StateError('The novels box is closed.');
      }
    } catch (_) {
      return _buildScaffold(_LibraryUnavailable(onRetry: _retry));
    }

    return _buildScaffold(
      ValueListenableBuilder<Box<NovelModel>>(
        valueListenable: novelsBox.listenable(),
        builder: (context, box, child) {
          if (!box.isOpen) {
            return _LibraryUnavailable(onRetry: _retry);
          }
          try {
            return NovelLibraryView(
              novels: box.values.toList(growable: false),
              onOpenNovel: (novel) => _openNovel(box, novel),
            );
          } catch (_) {
            return _LibraryUnavailable(onRetry: _retry);
          }
        },
      ),
    );
  }

  void _openNovel(Box<NovelModel> novelsBox, NovelModel novel) {
    Box<PluginModel>? pluginsBox;
    try {
      pluginsBox = widget.pluginsBox ?? StorageService.instance.pluginsBox;
      if (!pluginsBox.isOpen) pluginsBox = null;
    } catch (_) {
      pluginsBox = null;
    }

    PluginModel? plugin;
    if (pluginsBox != null) {
      for (final candidate in pluginsBox.values) {
        if (candidate.id == novel.sourceId &&
            candidate.type == PluginType.source) {
          plugin = candidate;
          break;
        }
      }
    }

    if (plugin == null || !plugin.isInstalled || !plugin.isEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            plugin == null
                ? 'The source plugin for this novel is not installed.'
                : 'The source plugin for this novel is not available.',
          ),
        ),
      );
      return;
    }

    dynamic key;
    for (final candidate in novelsBox.keys) {
      if (novelsBox.get(candidate)?.id == novel.id) {
        key = candidate;
        break;
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ReaderView(
          novel: novel,
          plugin: plugin!,
          novelsBox: novelsBox,
          novelKey: key,
        ),
      ),
    );
  }

  Widget _buildScaffold(Widget body) {
    return Scaffold(body: SafeArea(bottom: false, child: body));
  }
}

class _LibraryUnavailable extends StatelessWidget {
  const _LibraryUnavailable({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Could not load your library',
      message: 'Your local library could not be read. Please try again.',
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}
