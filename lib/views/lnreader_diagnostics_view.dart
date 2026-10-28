import 'package:flutter/material.dart';

import '../models/lnreader_manifest_entry.dart';
import '../services/lnreader_diagnostic_service.dart';
import '../services/lnreader_http_client.dart';
import '../theme/app_theme.dart';

class LnReaderDiagnosticsView extends StatefulWidget {
  const LnReaderDiagnosticsView({super.key, this.service, this.autoRun = true});

  /// Optional injected service for tests.
  final LnReaderDiagnosticService? service;
  final bool autoRun;

  @override
  State<LnReaderDiagnosticsView> createState() =>
      _LnReaderDiagnosticsViewState();
}

class _LnReaderDiagnosticsViewState extends State<LnReaderDiagnosticsView> {
  late final LnReaderDiagnosticService _service;
  late final bool _ownsService;

  final List<LnReaderDiagnosticStep> _steps = <LnReaderDiagnosticStep>[];
  LnReaderDiagnosticReport? _report;
  bool _running = false;
  String? _selectedPluginId;

  @override
  void initState() {
    super.initState();
    _ownsService = widget.service == null;
    _service =
        widget.service ??
        LnReaderDiagnosticService(httpClient: DioLnReaderHttpClient());
    if (widget.autoRun) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    if (_ownsService) _service.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _report = null;
      _steps.clear();
    });

    final report = await _service.run(
      pluginId: _selectedPluginId,
      onStep: (step) {
        if (!mounted) return;
        setState(() {
          for (var index = 0; index < _steps.length; index++) {
            if (_steps[index].label == step.label) {
              _steps[index] = step;
              return;
            }
          }
          _steps.add(step);
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _running = false;
      _report = report;
      _steps
        ..clear()
        ..addAll(report.steps);
    });
  }

  Future<void> _choosePlugin() async {
    final entries =
        _report?.manifest?.entries ?? const <LnReaderManifestEntry>[];
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Run diagnostics once to load the plugin manifest.'),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<LnReaderManifestEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _PluginPickerSheet(
          entries: entries,
          selectedId: _selectedPluginId ?? _report?.selectedPlugin?.id,
        ),
      ),
    );
    if (selected == null || !mounted) return;

    setState(() => _selectedPluginId = selected.id);
    await _run();
  }

  @override
  Widget build(BuildContext context) {
    final canChoosePlugin = _report?.manifest?.entries.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('LNReader compatibility'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Choose plugin',
            onPressed: _running || !canChoosePlugin ? null : _choosePlugin,
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'Run diagnostics again',
            onPressed: _running ? null : _run,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: <Widget>[
            const _IntroCard(),
            const SizedBox(height: 16),
            if (_running) ...<Widget>[
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
            ],
            for (final step in _steps) ...<Widget>[
              _StepCard(step: step),
              const SizedBox(height: 10),
            ],
            if (_report != null) ...<Widget>[
              const SizedBox(height: 8),
              _ReportSummary(report: _report!),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _running ? null : _run,
              icon: const Icon(Icons.science_outlined),
              label: Text(_running ? 'Running…' : 'Run diagnostics'),
            ),
            if (canChoosePlugin) ...<Widget>[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey<String>('choose-plugin'),
                onPressed: _running ? null : _choosePlugin,
                icon: const Icon(Icons.tune_rounded),
                label: Text(
                  _selectedPluginId == null
                      ? 'Choose a different plugin'
                      : 'Change selected plugin',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.shield_outlined, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sandboxed compatibility probe',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Fetches the official LNReader v3.0.0 manifest and one real plugin '
            'bundle. JavaScript runs in a QuickJS sandbox with stack and time '
            'limits. The bundled QuickJS build does not expose a working memory '
            'limit API. Plugin code can make outbound HTTP requests through the '
            'host bridge and a DOM parser, but has no filesystem or platform '
            'access.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});

  final LnReaderDiagnosticStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _statusColor(step.status, scheme);
    final duration = step.duration;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(_statusIcon(step.status), color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        step.label,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _statusLabel(step.status),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (duration != null) ...<Widget>[
                      const SizedBox(width: 8),
                      Text(
                        '${duration.inMilliseconds} ms',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(step.detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _statusColor(
    LnReaderDiagnosticStatus status,
    ColorScheme scheme,
  ) {
    return switch (status) {
      LnReaderDiagnosticStatus.pass => AppColors.success,
      LnReaderDiagnosticStatus.fail => AppColors.error,
      LnReaderDiagnosticStatus.warning => AppColors.warning,
      LnReaderDiagnosticStatus.running => scheme.primary,
      LnReaderDiagnosticStatus.pending => scheme.onSurfaceVariant,
    };
  }

  static IconData _statusIcon(LnReaderDiagnosticStatus status) {
    return switch (status) {
      LnReaderDiagnosticStatus.pass => Icons.check_circle_rounded,
      LnReaderDiagnosticStatus.fail => Icons.cancel_rounded,
      LnReaderDiagnosticStatus.warning => Icons.warning_amber_rounded,
      LnReaderDiagnosticStatus.running => Icons.sync_rounded,
      LnReaderDiagnosticStatus.pending => Icons.radio_button_unchecked,
    };
  }

  static String _statusLabel(LnReaderDiagnosticStatus status) {
    return switch (status) {
      LnReaderDiagnosticStatus.pass => 'PASS',
      LnReaderDiagnosticStatus.fail => 'FAIL',
      LnReaderDiagnosticStatus.warning => 'WARN',
      LnReaderDiagnosticStatus.running => 'RUNNING',
      LnReaderDiagnosticStatus.pending => 'PENDING',
    };
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.report});

  final LnReaderDiagnosticReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final runtime = report.runtime;
    final selected = report.selectedPlugin;
    final manifest = report.manifest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Report', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (report.manifestError != null) ...<Widget>[
          _InfoPanel(
            title: 'Manifest error',
            child: Text(
              report.manifestError!,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (manifest != null)
          _InfoPanel(
            title: 'Official manifest',
            child: Text(
              '${manifest.validCount} valid entries, '
              '${manifest.invalidCount} invalid, from '
              '${manifest.totalEntries} records.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (selected != null) ...<Widget>[
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Selected plugin',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${selected.name} · v${selected.version}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${selected.id} · ${selected.lang} · ${selected.site}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                SelectableText(selected.url, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ],
        if (runtime != null) ...<Widget>[
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Runtime contract',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _KeyValue(
                  label: 'Engine',
                  value: runtime.engineAvailable
                      ? runtime.engineName
                      : 'unavailable',
                ),
                _KeyValue(
                  label: 'Raw bundle',
                  value: runtime.rawBundleExecuted ? 'executed' : 'failed',
                ),
                _KeyValue(
                  label: 'LNReader init',
                  value: runtime.initializationSucceeded
                      ? 'methods found'
                      : 'failed',
                ),
                _KeyValue(
                  label: 'Search',
                  value: runtime.searchSucceeded
                      ? '${runtime.searchResultCount} results'
                      : 'not successful',
                ),
                if (runtime.exportKeys.isNotEmpty)
                  _KeyValue(
                    label: 'Exports',
                    value: runtime.exportKeys.join(', '),
                  ),
                if (runtime.pluginMethods.isNotEmpty)
                  _KeyValue(
                    label: 'Methods',
                    value: runtime.pluginMethods.entries
                        .map((entry) => '${entry.key}: ${entry.value}')
                        .join(', '),
                  ),
                if (runtime.searchTerm != null)
                  _KeyValue(label: 'Search term', value: runtime.searchTerm!),
              ],
            ),
          ),
          if (runtime.requiredModules.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _InfoPanel(
              title: 'Bundle dependencies',
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final module in runtime.requiredModules)
                    Chip(
                      label: Text(module),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ],
          if (runtime.missingRuntimeApis.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _InfoPanel(
              title: 'Required for compatibility',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final api in runtime.missingRuntimeApis)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $api', style: theme.textTheme.bodySmall),
                    ),
                ],
              ),
            ),
          ],
          if (runtime.searchResults.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _InfoPanel(
              title: 'Live search results',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final result in runtime.searchResults)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(result.name, style: theme.textTheme.bodyMedium),
                          SelectableText(
                            result.path,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (runtime.bundleError != null ||
              runtime.initializationError != null ||
              runtime.searchError != null) ...<Widget>[
            const SizedBox(height: 12),
            _InfoPanel(
              title: 'Diagnostic errors',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (runtime.rawBundleError != null)
                    SelectableText(
                      'Raw: ${runtime.rawBundleError}',
                      style: theme.textTheme.bodySmall,
                    ),
                  if (runtime.bundleError != null)
                    SelectableText(
                      'Bundle: ${runtime.bundleError}',
                      style: theme.textTheme.bodySmall,
                    ),
                  if (runtime.initializationError != null)
                    SelectableText(
                      'Init: ${runtime.initializationError}',
                      style: theme.textTheme.bodySmall,
                    ),
                  if (runtime.searchError != null)
                    SelectableText(
                      'Search: ${runtime.searchError}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ],
        if (manifest != null && manifest.issues.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Rejected manifest entries',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final issue in manifest.issues.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '#${issue.index}: ${issue.message}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (manifest != null && manifest.entries.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _ManifestPreview(entries: manifest.entries),
        ],
        const SizedBox(height: 8),
        Text(
          'A passing search uses the plugin\'s own searchNovels() and a real '
          'HTTP response. Raw bundle execution is expected to fail for '
          'official CommonJS bundles; the LNReader loader is the supported '
          'path.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ManifestPreview extends StatelessWidget {
  const _ManifestPreview({required this.entries});

  final List<LnReaderManifestEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = entries.take(20).toList(growable: false);

    return _InfoPanel(
      title: 'Manifest entries (${preview.length} of ${entries.length})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final entry in preview)
            Padding(
              key: ValueKey<String>('manifest-entry-${entry.id}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${entry.name} · ${entry.id}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    'v${entry.version} · ${entry.lang} · ${entry.site}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          if (entries.length > preview.length)
            Text(
              '… ${entries.length - preview.length} more entries in the '
              'official manifest.',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(label, style: theme.textTheme.labelSmall),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _PluginPickerSheet extends StatefulWidget {
  const _PluginPickerSheet({required this.entries, this.selectedId});

  final List<LnReaderManifestEntry> entries;
  final String? selectedId;

  @override
  State<_PluginPickerSheet> createState() => _PluginPickerSheetState();
}

class _PluginPickerSheetState extends State<_PluginPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.entries
        : widget.entries
              .where((entry) {
                return entry.name.toLowerCase().contains(query) ||
                    entry.id.toLowerCase().contains(query) ||
                    entry.lang.toLowerCase().contains(query);
              })
              .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Choose a plugin',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              key: const ValueKey<String>('plugin-picker-search'),
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search by name, id, or language',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matching plugins.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      final selected = entry.id == widget.selectedId;
                      return ListTile(
                        key: ValueKey<String>('plugin-choice-${entry.id}'),
                        title: Text(entry.name),
                        subtitle: Text(
                          '${entry.id} · v${entry.version} · ${entry.lang}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: selected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
