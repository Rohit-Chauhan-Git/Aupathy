import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../models/app_settings.dart';
import '../../models/novel_model.dart';
import '../../models/plugin_model.dart';
import '../../services/lnreader_http_client.dart';
import '../../services/lnreader_library_importer.dart';
import '../../services/lnreader_novel_service.dart';
import '../../services/lnreader_runtime_probe.dart';
import '../../services/reader_chapters.dart';
import '../../services/reader_html.dart';
import '../../services/reader_progress.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import 'chapter_list_sheet.dart';
import 'reader_settings_sheet.dart';
import 'reader_theme.dart';

class ReaderView extends StatefulWidget {
  const ReaderView({
    super.key,
    required this.novel,
    required this.plugin,
    required this.novelsBox,
    this.novelKey,
    this.settingsBox,
    this.api,
    this.progressDebounce = const Duration(milliseconds: 800),
    this.settingsDebounce = const Duration(milliseconds: 400),
    this.progressStore,
    this.persistChapterList = true,
    this.persistSettings,
  });

  final NovelModel novel;
  final PluginModel plugin;
  final Box<NovelModel> novelsBox;
  final dynamic novelKey;
  final Box<AppSettings>? settingsBox;
  final LnReaderNovelApi? api;
  final Duration progressDebounce;
  final Duration settingsDebounce;
  final ReaderProgressStore? progressStore;
  final bool persistChapterList;
  final Future<void> Function(AppSettings settings)? persistSettings;

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> with WidgetsBindingObserver {
  static const int _maxCachedChapters = 6;
  static const double _visibleTopPadding = 82;
  static const double _hiddenTopPadding = 24;
  static const double _visibleBottomPadding = 168;
  static const double _hiddenBottomPadding = 36;

  late LnReaderNovelApi _api;
  DioLnReaderHttpClient? _ownedClient;
  late NovelModel _novel;
  dynamic _novelKey;

  Box<AppSettings>? _settingsBox;
  AppSettings _settings = AppSettings.defaults();
  Timer? _settingsTimer;
  AppSettings? _pendingSettings;

  final ReaderHtmlConverter _converter = const ReaderHtmlConverter();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _chapterProgress = ValueNotifier<double>(0);
  final LinkedHashMap<String, ReaderDocument> _chapterCache =
      LinkedHashMap<String, ReaderDocument>();

  ReaderProgressStore? _progressStore;
  List<LnReaderChapter> _chapters = const <LnReaderChapter>[];
  int _currentIndex = 0;
  ReaderDocument? _document;

  String? _fatalError;
  String? _chapterError;
  int? _failedIndex;
  bool _loading = true;
  bool _chromeVisible = true;
  bool _restoringPosition = false;

  int _requestId = 0;
  double _restoreFraction = 0;
  double _restoreOffset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _novel = widget.novel;
    _novelKey = widget.novelKey ?? _findNovelKey(widget.novel.id);
    _loadSettings();
    if (widget.api != null) {
      _api = widget.api!;
    } else {
      final client = DioLnReaderHttpClient();
      _ownedClient = client;
      _api = LnReaderNovelService(
        executorFactory: QuickJsLnReaderPluginExecutorFactory(
          runtimeFactory: QuickJsScriptRuntimeFactory(httpClient: client),
        ),
      );
    }
    _scrollController.addListener(_handleScroll);
    unawaited(_loadInitial());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_savePositionNow());
      _flushSettingsNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _requestId++;
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _chapterProgress.dispose();
    _settingsTimer?.cancel();
    _flushSettingsNow(disposeAfter: true);
    _progressStore?.dispose();
    _ownedClient?.close();
    super.dispose();
  }

  dynamic _findNovelKey(int id) {
    for (final key in widget.novelsBox.keys) {
      if (widget.novelsBox.get(key)?.id == id) return key;
    }
    return null;
  }

  void _loadSettings() {
    try {
      final box = widget.settingsBox ?? StorageService.instance.settingsBox;
      _settingsBox = box.isOpen ? box : null;
      _settings =
          _settingsBox?.get(StorageService.settingsKey) ??
          AppSettings.defaults();
    } catch (_) {
      _settingsBox = null;
      _settings = AppSettings.defaults();
    }
  }

  LnReaderChapter? get _currentChapter {
    if (_currentIndex < 0 || _currentIndex >= _chapters.length) return null;
    return _chapters[_currentIndex];
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _fatalError = null;
      _chapterError = null;
      _failedIndex = null;
    });

    try {
      var chapters = ReaderChapters.fromNovel(_novel);
      if (chapters.isEmpty) {
        final path = _novel.metadata[LnReaderLibraryImporter.metadataNovelPath]
            ?.toString()
            .trim();
        if (path == null || path.isEmpty) {
          throw const LnReaderPluginException(
            'This novel does not include a chapter list. Re-import it from '
            'its source and try again.',
          );
        }
        final details = await _api.parseNovel(widget.plugin, path);
        chapters = ReaderChapters.sanitize(details.chapters);
        if (chapters.isNotEmpty) {
          await _persistChapterList(chapters);
        }
      }
      if (chapters.isEmpty) {
        throw const LnReaderPluginException(
          'The source did not return any chapters for this novel.',
        );
      }

      final savedPath = _novel.metadata[ReaderProgressStore.metadataChapterPath]
          ?.toString();
      final savedFraction =
          (_novel.metadata[ReaderProgressStore.metadataScrollFraction] as num?)
              ?.toDouble();
      final savedOffset =
          (_novel.metadata[ReaderProgressStore.metadataScrollOffset] as num?)
              ?.toDouble();
      final index = ReaderChapters.resolveIndex(
        chapters,
        lastReadChapter: _novel.lastReadChapter,
        savedPath: savedPath,
      );

      if (!mounted) return;
      _chapters = chapters;
      _currentIndex = index;
      _restoreFraction = (savedFraction ?? 0).clamp(0.0, 1.0);
      _restoreOffset = (savedOffset ?? 0).clamp(0.0, double.infinity);
      _progressStore =
          widget.progressStore ??
          (_novelKey == null
              ? null
              : ReaderProgressStore(
                  box: widget.novelsBox,
                  key: _novelKey!,
                  fallbackNovel: _novel,
                  debounce: widget.progressDebounce,
                ));
      await _loadChapter(index, restorePosition: true, initial: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _fatalError = _messageFor(error);
      });
    }
  }

  Future<void> _persistChapterList(List<LnReaderChapter> chapters) async {
    if (!widget.persistChapterList) return;
    final key = _novelKey;
    if (key == null || !widget.novelsBox.isOpen) return;
    final current = widget.novelsBox.get(key) ?? _novel;
    final updated = current.copyWith(
      chapterCount: chapters.length,
      metadata: <String, dynamic>{
        ...current.metadata,
        LnReaderLibraryImporter.metadataChapters: chapters
            .map((chapter) => chapter.toMetadata())
            .toList(growable: false),
      },
    );
    await widget.novelsBox.put(key, updated);
    _novel = updated;
  }

  Future<void> _loadChapter(
    int index, {
    bool restorePosition = false,
    bool initial = false,
  }) async {
    if (index < 0 || index >= _chapters.length) return;
    if (_loading && !initial) return;

    final chapter = _chapters[index];
    final request = ++_requestId;
    final cached = _chapterCache.remove(chapter.path);
    if (cached != null) {
      _chapterCache[chapter.path] = cached;
      if (!initial) unawaited(_savePositionNow());
      if (!mounted || request != _requestId) return;
      _applyChapter(index, cached, restorePosition: restorePosition);
      return;
    }

    if (!initial) unawaited(_savePositionNow());
    if (!mounted || request != _requestId) return;

    setState(() {
      _loading = true;
      _chapterError = null;
      _failedIndex = null;
    });

    try {
      final content = await _api.parseChapter(widget.plugin, chapter.path);
      if (!mounted || request != _requestId) return;
      final document = _converter.convert(content.html);
      if (document.isEmpty) {
        throw const LnReaderPluginException(
          'The source returned no readable chapter content.',
        );
      }
      _cacheChapter(chapter.path, document);
      _applyChapter(index, document, restorePosition: restorePosition);
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _loading = false;
        _chapterError = _messageFor(error);
        _failedIndex = index;
      });
    }
  }

  void _cacheChapter(String path, ReaderDocument document) {
    _chapterCache.remove(path);
    _chapterCache[path] = document;
    while (_chapterCache.length > _maxCachedChapters) {
      _chapterCache.remove(_chapterCache.keys.first);
    }
  }

  void _applyChapter(
    int index,
    ReaderDocument document, {
    required bool restorePosition,
  }) {
    setState(() {
      _currentIndex = index;
      _document = document;
      _loading = false;
      _chapterError = null;
      _failedIndex = null;
      _fatalError = null;
    });
    _chapterProgress.value = 0;
    final request = _requestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || request != _requestId) return;
      if (restorePosition) {
        _restoreScroll(request);
      } else {
        _jumpToTop();
        _updateProgressFromScroll();
        unawaited(_savePositionNow());
      }
    });
  }

  void _jumpToTop() {
    if (!_scrollController.hasClients) return;
    _restoringPosition = true;
    _scrollController.jumpTo(0);
    _restoringPosition = false;
  }

  void _restoreScroll(int request) {
    if (!mounted || request != _requestId) return;
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final target = _restoreFraction > 0
        ? _restoreFraction * maxExtent
        : _restoreOffset;
    _restoringPosition = true;
    _scrollController.jumpTo(target.clamp(0.0, maxExtent));
    _restoringPosition = false;
    _updateProgressFromScroll();
    unawaited(_savePositionNow());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || request != _requestId) return;
      if (!_scrollController.hasClients || _restoreFraction <= 0) return;
      final refinedMax = _scrollController.position.maxScrollExtent;
      final refined = (_restoreFraction * refinedMax).clamp(0.0, refinedMax);
      if ((refined - _scrollController.offset).abs() > 2) {
        _restoringPosition = true;
        _scrollController.jumpTo(refined);
        _restoringPosition = false;
        _updateProgressFromScroll();
      }
    });
  }

  void _handleScroll() {
    if (_restoringPosition || _document == null) return;
    _updateProgressFromScroll();
  }

  void _updateProgressFromScroll() {
    if (!_scrollController.hasClients || _document == null) return;
    final position = _scrollController.position;
    final fraction = ReaderProgressMath.chapterFraction(
      offset: position.pixels,
      maxExtent: position.maxScrollExtent,
      hasContent: true,
    );
    if ((fraction - _chapterProgress.value).abs() > 0.0005) {
      _chapterProgress.value = fraction;
    }
    final chapter = _currentChapter;
    if (chapter == null) return;
    _progressStore?.record(
      ReaderPosition(
        chapterIndex: _currentIndex,
        chapterPath: chapter.path,
        scrollOffset: position.pixels,
        scrollFraction: fraction,
      ),
    );
  }

  Future<void> _savePositionNow() async {
    final store = _progressStore;
    final chapter = _currentChapter;
    if (store == null || chapter == null) return;
    var offset = 0.0;
    var fraction = _chapterProgress.value;
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      offset = position.pixels;
      fraction = ReaderProgressMath.chapterFraction(
        offset: offset,
        maxExtent: position.maxScrollExtent,
        hasContent: _document != null,
      );
    }
    await store.saveNow(
      ReaderPosition(
        chapterIndex: _currentIndex,
        chapterPath: chapter.path,
        scrollOffset: offset,
        scrollFraction: fraction,
      ),
    );
  }

  void _toggleChrome() {
    final wasVisible = _chromeVisible;
    final previousOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    setState(() => _chromeVisible = !_chromeVisible);

    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final delta = _visibleTopPadding - _hiddenTopPadding;
      final target = wasVisible
          ? (previousOffset - delta)
          : (previousOffset + delta);
      _scrollController.jumpTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    });
  }

  void _navigate(int delta) {
    if (_loading || delta == 0) return;
    final target = _currentIndex + delta;
    if (target < 0 || target >= _chapters.length) return;
    unawaited(_loadChapter(target));
  }

  Future<void> _retryChapter() async {
    final index = _failedIndex ?? _currentIndex;
    if (_chapters.isEmpty) {
      await _loadInitial();
      return;
    }
    await _loadChapter(index);
  }

  Future<void> _openChapterList() async {
    final selected = await showReaderChapterList(
      context: context,
      chapters: _chapters,
      currentIndex: _currentIndex,
    );
    if (!mounted || selected == null || selected == _currentIndex) return;
    await _loadChapter(selected);
  }

  Future<void> _openSettings() async {
    await showReaderSettingsSheet(
      context: context,
      settings: _settings,
      onChanged: _applySettings,
      onReset: _resetSettings,
    );
    if (!mounted) return;
    _flushSettingsNow();
  }

  void _applySettings(AppSettings settings) {
    if (!mounted) return;
    setState(() => _settings = settings);
    _pendingSettings = settings;
    _settingsTimer?.cancel();
    _settingsTimer = Timer(widget.settingsDebounce, _flushSettingsNow);
  }

  void _resetSettings() {
    final defaults = AppSettings.defaults();
    _applySettings(
      _settings.copyWith(
        readerTheme: defaults.readerTheme,
        fontFamily: defaults.fontFamily,
        fontSize: defaults.fontSize,
        lineHeight: defaults.lineHeight,
        pageMargin: defaults.pageMargin,
        readerParagraphSpacing: defaults.readerParagraphSpacing,
        readerTextAlign: defaults.readerTextAlign,
        readerShowProgress: defaults.readerShowProgress,
      ),
    );
  }

  void _flushSettingsNow({bool disposeAfter = false}) {
    _settingsTimer?.cancel();
    _settingsTimer = null;
    final value = _pendingSettings;
    _pendingSettings = null;
    if (value == null || _settingsBox == null) return;
    unawaited(_saveSettings(value));
    if (disposeAfter) return;
  }

  Future<void> _saveSettings(AppSettings value) async {
    final persisted = value.copyWith(updatedAt: DateTime.now());
    final persist = widget.persistSettings;
    if (persist != null) {
      try {
        await persist(persisted);
      } catch (_) {
        // Reader settings remain applied in memory if persistence fails.
      }
      return;
    }
    final box = _settingsBox;
    if (box == null || !box.isOpen) return;
    try {
      await box.put(StorageService.settingsKey, persisted);
    } catch (_) {
      // Reader settings remain applied in memory even if persistence fails.
    }
  }

  String _messageFor(Object error) {
    if (error is LnReaderPluginException) return error.message;
    return 'Could not load this chapter: $error';
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.resolve(_settings.readerTheme);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: palette.overlayStyle,
      child: Scaffold(
        backgroundColor: palette.background,
        body: PopScope(
          canPop: _chromeVisible,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              setState(() => _chromeVisible = true);
              return;
            }
            unawaited(_savePositionNow());
            _flushSettingsNow();
          },
          child: SafeArea(
            bottom: false,
            child: ColoredBox(
              key: const ValueKey<String>('reader-surface'),
              color: palette.background,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: _buildBody(palette)),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildTopBar(palette),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildBottomBar(palette),
                  ),
                  if (!_chromeVisible && _settings.readerShowProgress)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ValueListenableBuilder<double>(
                        valueListenable: _chapterProgress,
                        builder: (context, value, child) {
                          return LinearProgressIndicator(
                            minHeight: 2,
                            value: value,
                            backgroundColor: palette.border.withValues(
                              alpha: 0.5,
                            ),
                            color: palette.accent,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ReaderPalette palette) {
    final document = _document;
    if (document == null) {
      if (_loading) return _ReaderLoading(palette: palette);
      if (_fatalError != null || _chapterError != null) {
        return _ReaderMessage(
          key: const ValueKey<String>('reader-error'),
          palette: palette,
          icon: Icons.cloud_off_rounded,
          title: 'Could not open this book',
          message:
              _fatalError ?? _chapterError ?? 'The chapter is unavailable.',
          actionLabel: 'Try again',
          actionKey: const ValueKey<String>('reader-retry'),
          onAction: _retryChapter,
        );
      }
      if (_chapters.isEmpty) {
        return _ReaderMessage(
          palette: palette,
          icon: Icons.menu_book_rounded,
          title: 'No chapters available',
          message: 'The source did not provide any chapters for this novel.',
          actionLabel: 'Try again',
          onAction: _loadInitial,
        );
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _toggleChrome,
      child: Stack(
        children: <Widget>[
          if (document != null) _buildChapterContent(palette, document),
          if (_loading && document != null)
            const Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_chapterError != null && document != null)
            Positioned(
              top: 76,
              left: 12,
              right: 12,
              child: _ChapterErrorBanner(
                palette: palette,
                message: _chapterError!,
                onRetry: _retryChapter,
                onDismiss: () => setState(() => _chapterError = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChapterContent(ReaderPalette palette, ReaderDocument document) {
    final topPadding = _chromeVisible ? _visibleTopPadding : _hiddenTopPadding;
    final bottomPadding = _chromeVisible
        ? _visibleBottomPadding
        : _hiddenBottomPadding;
    final chapter = _currentChapter;
    final textStyle = readerTextStyle(_settings, palette);
    final alignment = readerTextAlign(_settings);
    final headingFamily = ReaderFonts.resolveFamily(_settings.fontFamily);
    final maxWidth = 760.0;

    return ListView.builder(
      key: ValueKey<String>('reader-content-${chapter?.path ?? ''}'),
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        _settings.pageMargin,
        topPadding,
        _settings.pageMargin,
        bottomPadding,
      ),
      itemCount: document.blocks.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: _ChapterHeading(
                key: const ValueKey<String>('reader-chapter-heading'),
                novelTitle: _novel.title,
                chapterTitle: chapter?.name ?? 'Chapter',
                palette: palette,
                textStyle: textStyle,
                headingFamily: headingFamily,
                paragraphSpacing: _settings.readerParagraphSpacing,
              ),
            ),
          );
        }
        final block = document.blocks[index - 1];
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: _ReaderBlockView(
              key: ValueKey<String>('reader-block-${index - 1}'),
              block: block,
              palette: palette,
              textStyle: textStyle,
              alignment: alignment,
              paragraphSpacing: _settings.readerParagraphSpacing,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(ReaderPalette palette) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      offset: _chromeVisible ? Offset.zero : const Offset(0, -1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: _chromeVisible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !_chromeVisible,
          child: Container(
            key: const ValueKey<String>('reader-top-bar'),
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.98),
              border: Border(bottom: BorderSide(color: palette.border)),
            ),
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
            child: Row(
              children: <Widget>[
                IconButton(
                  key: const ValueKey<String>('reader-back'),
                  tooltip: 'Back to library',
                  color: palette.text,
                  onPressed: () {
                    unawaited(_savePositionNow());
                    _flushSettingsNow();
                    Navigator.of(context).maybePop();
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _novel.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: palette.secondaryText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentChapter?.name ?? 'Chapter',
                        key: const ValueKey<String>('reader-chapter-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: palette.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('reader-toc'),
                  tooltip: 'Chapter list',
                  color: palette.text,
                  onPressed: _chapters.isEmpty ? null : _openChapterList,
                  icon: const Icon(Icons.format_list_bulleted_rounded),
                ),
                IconButton(
                  key: const ValueKey<String>('reader-settings'),
                  tooltip: 'Reader settings',
                  color: palette.text,
                  onPressed: _openSettings,
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ReaderPalette palette) {
    final hasPrevious = _currentIndex > 0;
    final hasNext = _currentIndex < _chapters.length - 1;
    final chapterName = _currentChapter?.name ?? 'Chapter';

    return AnimatedSlide(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      offset: _chromeVisible ? Offset.zero : const Offset(0, 1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: _chromeVisible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !_chromeVisible,
          child: Container(
            key: const ValueKey<String>('reader-bottom-bar'),
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.98),
              border: Border(top: BorderSide(color: palette.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        IconButton(
                          key: const ValueKey<String>('reader-previous'),
                          tooltip: 'Previous chapter',
                          color: palette.text,
                          onPressed: hasPrevious && !_loading
                              ? () => _navigate(-1)
                              : null,
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                _chapters.isEmpty
                                    ? 'No chapters'
                                    : 'Chapter ${_currentIndex + 1} of '
                                          '${_chapters.length}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: palette.secondaryText,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                chapterName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: palette.text),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const ValueKey<String>('reader-next'),
                          tooltip: 'Next chapter',
                          color: palette.text,
                          onPressed: hasNext && !_loading
                              ? () => _navigate(1)
                              : null,
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    if (_settings.readerShowProgress)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                        child: ValueListenableBuilder<double>(
                          valueListenable: _chapterProgress,
                          builder: (context, fraction, child) {
                            final chapterPercent = ReaderProgressMath.percent(
                              fraction,
                            );
                            final novelPercent = ReaderProgressMath.percent(
                              ReaderProgressMath.novelProgress(
                                chapterIndex: _currentIndex,
                                chapterFraction: fraction,
                                chapterCount: _chapters.length,
                              ),
                            );
                            return Column(
                              children: <Widget>[
                                ClipRRect(
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(99),
                                  ),
                                  child: LinearProgressIndicator(
                                    minHeight: 4,
                                    value: fraction,
                                    backgroundColor: palette.border.withValues(
                                      alpha: 0.6,
                                    ),
                                    color: palette.accent,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: <Widget>[
                                    IconButton(
                                      key: const ValueKey<String>(
                                        'reader-toc-bottom',
                                      ),
                                      tooltip: 'Chapter list',
                                      visualDensity: VisualDensity.compact,
                                      color: palette.secondaryText,
                                      onPressed: _chapters.isEmpty
                                          ? null
                                          : _openChapterList,
                                      icon: const Icon(
                                        Icons.format_list_bulleted_rounded,
                                        size: 18,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '$chapterPercent% chapter · '
                                        '$novelPercent% novel',
                                        key: const ValueKey<String>(
                                          'reader-progress-label',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: palette.secondaryText,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 40),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderLoading extends StatelessWidget {
  const _ReaderLoading({required this.palette});

  final ReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey<String>('reader-loading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(color: palette.accent),
          const SizedBox(height: 16),
          Text(
            'Opening chapter…',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: palette.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _ReaderMessage extends StatelessWidget {
  const _ReaderMessage({
    super.key,
    required this.palette,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.actionKey,
  });

  final ReaderPalette palette;
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: const BorderRadius.all(Radius.circular(24)),
                border: Border.all(color: palette.border),
              ),
              child: Icon(icon, size: 34, color: palette.accent),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: palette.text),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.secondaryText, height: 1.55),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              key: actionKey,
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.accent,
                side: BorderSide(color: palette.border),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterErrorBanner extends StatelessWidget {
  const _ChapterErrorBanner({
    required this.palette,
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  final ReaderPalette palette;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey<String>('reader-inline-error'),
      color: palette.surface,
      elevation: 4,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.text),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
            IconButton(
              tooltip: 'Dismiss error',
              onPressed: onDismiss,
              color: palette.secondaryText,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterHeading extends StatelessWidget {
  const _ChapterHeading({
    super.key,
    required this.novelTitle,
    required this.chapterTitle,
    required this.palette,
    required this.textStyle,
    required this.headingFamily,
    required this.paragraphSpacing,
  });

  final String novelTitle;
  final String chapterTitle;
  final ReaderPalette palette;
  final TextStyle textStyle;
  final String headingFamily;
  final double paragraphSpacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: paragraphSpacing + 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            novelTitle.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.secondaryText,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            chapterTitle,
            style: textStyle.copyWith(
              fontFamily: headingFamily.isEmpty ? null : headingFamily,
              fontSize: textStyle.fontSize! * 1.48,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 18),
          Divider(color: palette.border, height: 1),
          SizedBox(height: paragraphSpacing + 6),
        ],
      ),
    );
  }
}

class _ReaderBlockView extends StatelessWidget {
  const _ReaderBlockView({
    super.key,
    required this.block,
    required this.palette,
    required this.textStyle,
    required this.alignment,
    required this.paragraphSpacing,
  });

  final ReaderBlock block;
  final ReaderPalette palette;
  final TextStyle textStyle;
  final TextAlign alignment;
  final double paragraphSpacing;

  @override
  Widget build(BuildContext context) {
    if (block.isSeparator) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: paragraphSpacing + 4),
        child: Divider(color: palette.border, height: 1),
      );
    }

    final isHeading =
        block.type == ReaderBlockType.heading1 ||
        block.type == ReaderBlockType.heading2 ||
        block.type == ReaderBlockType.heading3;
    final scale = switch (block.type) {
      ReaderBlockType.heading1 => 1.4,
      ReaderBlockType.heading2 => 1.22,
      ReaderBlockType.heading3 => 1.1,
      _ => 1.0,
    };
    final style = isHeading
        ? textStyle.copyWith(
            fontSize: textStyle.fontSize! * scale,
            height: 1.3,
            fontWeight: FontWeight.w600,
          )
        : textStyle;
    final spans = _buildSpans(block, style);
    final text = SelectableText.rich(
      TextSpan(style: style, children: spans),
      textAlign: isHeading ? TextAlign.left : alignment,
      textScaler: MediaQuery.textScalerOf(context),
    );

    final content = block.type == ReaderBlockType.bullet
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '•',
                style: style.copyWith(
                  color: palette.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: text),
            ],
          )
        : text;

    if (block.type == ReaderBlockType.quote) {
      return Container(
        margin: EdgeInsets.only(bottom: paragraphSpacing),
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: palette.accent, width: 3)),
        ),
        child: content,
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: paragraphSpacing),
      child: content,
    );
  }

  List<TextSpan> _buildSpans(ReaderBlock block, TextStyle baseStyle) {
    return block.spans
        .map((span) {
          var style = baseStyle;
          if (span.bold) style = style.copyWith(fontWeight: FontWeight.w700);
          if (span.italic) style = style.copyWith(fontStyle: FontStyle.italic);
          if (span.underline || span.link) {
            style = style.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: span.link ? palette.link : null,
            );
          }
          if (span.code) {
            style = style.copyWith(
              fontFamily: AppFonts.mono,
              fontFamilyFallback: AppFonts.monoFallback,
              fontSize: (style.fontSize ?? _settingsFontSize) * 0.92,
              backgroundColor: palette.surface,
            );
          }
          if (span.link) style = style.copyWith(color: palette.link);
          return TextSpan(text: span.text, style: style);
        })
        .toList(growable: false);
  }

  double get _settingsFontSize => textStyle.fontSize ?? 18;
}
