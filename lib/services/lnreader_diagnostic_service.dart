import '../models/lnreader_manifest_entry.dart';
import 'lnreader_http_client.dart';
import 'lnreader_manifest_service.dart';
import 'lnreader_runtime_probe.dart';

enum LnReaderDiagnosticStatus { pending, running, pass, fail, warning }

class LnReaderDiagnosticStep {
  const LnReaderDiagnosticStep({
    required this.label,
    required this.status,
    required this.detail,
    this.duration,
  });

  final String label;
  final LnReaderDiagnosticStatus status;
  final String detail;
  final Duration? duration;
}

class LnReaderDiagnosticReport {
  const LnReaderDiagnosticReport({
    required this.steps,
    this.manifest,
    this.selectedPlugin,
    this.runtime,
    this.bundleBytes,
    this.manifestError,
  });

  final List<LnReaderDiagnosticStep> steps;
  final LnReaderManifest? manifest;
  final LnReaderManifestEntry? selectedPlugin;
  final LnReaderRuntimeProbeResult? runtime;
  final int? bundleBytes;
  final String? manifestError;

  LnReaderDiagnosticStatus statusFor(String label) {
    for (final step in steps) {
      if (step.label == label) return step.status;
    }
    return LnReaderDiagnosticStatus.pending;
  }
}

class LnReaderDiagnosticService {
  LnReaderDiagnosticService({
    required this.httpClient,
    LnReaderScriptRuntimeFactory? runtimeFactory,
    this.preferredPluginId = 'royalroad',
  }) : manifestService = LnReaderManifestService(httpClient: httpClient),
       runtimeProbe = LnReaderRuntimeProbe(
         runtimeFactory:
             runtimeFactory ??
             QuickJsScriptRuntimeFactory(httpClient: httpClient),
       );

  static const String manifestStep = 'Manifest retrieval';
  static const String validationStep = 'Manifest validation';
  static const String selectionStep = 'Plugin selection';
  static const String bundleStep = 'Bundle download';
  static const String engineStep = 'JavaScript engine';
  static const String executionStep = 'JavaScript execution';
  static const String initializationStep = 'Plugin initialization';
  static const String searchStep = 'Real searchNovels()';

  final LnReaderHttpClient httpClient;
  final LnReaderManifestService manifestService;
  final LnReaderRuntimeProbe runtimeProbe;
  final String preferredPluginId;

  final List<LnReaderDiagnosticStep> _steps = <LnReaderDiagnosticStep>[];
  void Function(LnReaderDiagnosticStep step)? _onStep;
  LnReaderManifest? _manifest;
  LnReaderManifestEntry? _selected;
  LnReaderRuntimeProbeResult? _runtime;
  int? _bundleBytes;

  Future<LnReaderDiagnosticReport> run({
    void Function(LnReaderDiagnosticStep step)? onStep,
    String? pluginId,
  }) async {
    _steps.clear();
    _onStep = onStep;
    _manifest = null;
    _selected = null;
    _runtime = null;
    _bundleBytes = null;

    final manifestStopwatch = _start(manifestStep);
    LnReaderManifestFetchResult manifestResult;
    try {
      manifestResult = await manifestService.fetch();
    } catch (error) {
      manifestResult = LnReaderManifestFetchResult(
        error: 'Manifest request failed: $error',
      );
    }
    if (!manifestResult.isSuccess) {
      _finish(
        manifestStep,
        LnReaderDiagnosticStatus.fail,
        manifestResult.error ?? 'Manifest retrieval failed.',
        manifestStopwatch,
      );
      _addBlockedSteps('Manifest could not be retrieved.');
      return _report(manifestError: manifestResult.error);
    }

    _manifest = manifestResult.manifest;
    final manifest = _manifest!;
    _finish(
      manifestStep,
      LnReaderDiagnosticStatus.pass,
      'HTTP ${manifestResult.statusCode} · '
      '${manifest.totalEntries} raw entries.',
      manifestStopwatch,
    );

    final validationStopwatch = _start(validationStep);
    if (manifest.entries.isEmpty) {
      _finish(
        validationStep,
        LnReaderDiagnosticStatus.fail,
        'No valid manifest entries. ${manifest.invalidCount} rejected.',
        validationStopwatch,
      );
      _addBlockedSteps('Manifest contained no usable plugins.');
      return _report(manifest: manifest, manifestError: 'No valid entries.');
    }

    final issueSummary = manifest.issues.isEmpty
        ? 'All entries passed required-field validation.'
        : '${manifest.invalidCount} invalid entries rejected. '
              'First issue: ${manifest.issues.first.message}';
    _finish(
      validationStep,
      manifest.issues.isEmpty
          ? LnReaderDiagnosticStatus.pass
          : LnReaderDiagnosticStatus.warning,
      '${manifest.validCount} valid of ${manifest.totalEntries} entries. '
      '$issueSummary',
      validationStopwatch,
    );

    _selected = _selectPlugin(manifest.entries, pluginId: pluginId);
    _addStep(
      LnReaderDiagnosticStep(
        label: selectionStep,
        status: LnReaderDiagnosticStatus.pass,
        detail:
            '${_selected!.name} (${_selected!.id}) '
            'v${_selected!.version} · ${_selected!.lang}.',
      ),
    );

    final bundleStopwatch = _start(bundleStep);
    LnReaderHttpResponse? bundleResponse;
    try {
      bundleResponse = await httpClient.get(Uri.parse(_selected!.url));
    } catch (error) {
      _finish(
        bundleStep,
        LnReaderDiagnosticStatus.fail,
        'Bundle download failed: $error',
        bundleStopwatch,
      );
      _addBlockedRuntimeSteps('Bundle download failed.');
      return _report(manifest: manifest, selectedPlugin: _selected);
    }

    if (bundleResponse.statusCode < 200 || bundleResponse.statusCode >= 300) {
      _finish(
        bundleStep,
        LnReaderDiagnosticStatus.fail,
        'Plugin bundle request returned HTTP ${bundleResponse.statusCode}.',
        bundleStopwatch,
      );
      _addBlockedRuntimeSteps('Bundle download failed.');
      return _report(manifest: manifest, selectedPlugin: _selected);
    }
    if (bundleResponse.body.trim().isEmpty) {
      _finish(
        bundleStep,
        LnReaderDiagnosticStatus.fail,
        'The plugin bundle was empty.',
        bundleStopwatch,
      );
      _addBlockedRuntimeSteps('Bundle download failed.');
      return _report(manifest: manifest, selectedPlugin: _selected);
    }

    final bundleSource = bundleResponse.body;
    _bundleBytes = bundleSource.length;
    _finish(
      bundleStep,
      LnReaderDiagnosticStatus.pass,
      'Downloaded ${bundleSource.length} bytes from '
      '${bundleResponse.uri.host}.',
      bundleStopwatch,
    );

    final engineStopwatch = _start(engineStep);
    final probe = await runtimeProbe.run(
      plugin: _selected!,
      bundleSource: bundleSource,
    );
    _runtime = probe;

    if (!probe.engineAvailable) {
      _finish(
        engineStep,
        LnReaderDiagnosticStatus.fail,
        probe.engineError ?? 'JavaScript runtime unavailable.',
        engineStopwatch,
      );
      _finish(
        executionStep,
        LnReaderDiagnosticStatus.fail,
        'Blocked by JavaScript engine failure.',
        null,
      );
      _finish(
        initializationStep,
        LnReaderDiagnosticStatus.fail,
        'Blocked by JavaScript engine failure.',
        null,
      );
      _finish(
        searchStep,
        LnReaderDiagnosticStatus.fail,
        'Blocked by JavaScript engine failure.',
        null,
      );
      return _report(
        manifest: manifest,
        selectedPlugin: _selected,
        runtime: probe,
        bundleBytes: _bundleBytes,
      );
    }

    _finish(
      engineStep,
      LnReaderDiagnosticStatus.pass,
      '${probe.engineName} started; sanity check returned 2.',
      engineStopwatch,
    );

    _addStep(
      LnReaderDiagnosticStep(
        label: executionStep,
        status: probe.bundleExecuted
            ? LnReaderDiagnosticStatus.pass
            : LnReaderDiagnosticStatus.fail,
        detail: probe.bundleExecuted
            ? 'Executed through the LNReader module loader. Exports: '
                  '${probe.exportKeys.join(', ')}.'
            : (probe.bundleError ??
                  'Bundle execution failed in the LNReader runtime.'),
      ),
    );

    _addStep(
      LnReaderDiagnosticStep(
        label: initializationStep,
        status: probe.initializationSucceeded
            ? LnReaderDiagnosticStatus.pass
            : LnReaderDiagnosticStatus.fail,
        detail: probe.initializationSucceeded
            ? 'Plugin initialized as ${probe.pluginName ?? probe.pluginId} '
                  'v${probe.pluginVersion ?? '?'} with '
                  'searchNovels/parseNovel.'
            : (probe.initializationError ?? 'Plugin initialization failed.'),
      ),
    );

    _addStep(
      LnReaderDiagnosticStep(
        label: searchStep,
        status: probe.searchAttempted
            ? (probe.searchSucceeded
                  ? LnReaderDiagnosticStatus.pass
                  : LnReaderDiagnosticStatus.fail)
            : LnReaderDiagnosticStatus.fail,
        detail: !probe.searchAttempted
            ? 'Not attempted: '
                  '${probe.searchError ?? 'plugin is not initialized.'}'
            : probe.searchSucceeded
            ? 'searchNovels() returned ${probe.searchResultCount} results.'
            : (probe.searchError ??
                  'searchNovels() did not return a valid result list.'),
      ),
    );

    return _report(
      manifest: manifest,
      selectedPlugin: _selected,
      runtime: probe,
      bundleBytes: _bundleBytes,
    );
  }

  LnReaderManifestEntry _selectPlugin(
    List<LnReaderManifestEntry> entries, {
    String? pluginId,
  }) {
    final selectedId = pluginId ?? preferredPluginId;
    for (final entry in entries) {
      if (entry.id == selectedId) return entry;
    }
    return entries.first;
  }

  Stopwatch _start(String label) {
    final stopwatch = Stopwatch()..start();
    _addStep(
      LnReaderDiagnosticStep(
        label: label,
        status: LnReaderDiagnosticStatus.running,
        detail: 'Running…',
      ),
    );
    return stopwatch;
  }

  void _finish(
    String label,
    LnReaderDiagnosticStatus status,
    String detail,
    Stopwatch? stopwatch,
  ) {
    stopwatch?.stop();
    final step = LnReaderDiagnosticStep(
      label: label,
      status: status,
      detail: detail,
      duration: stopwatch?.elapsed,
    );
    for (var index = _steps.length - 1; index >= 0; index--) {
      if (_steps[index].label == label) {
        _steps[index] = step;
        _onStep?.call(step);
        return;
      }
    }
    _addStep(step);
  }

  void _addBlockedSteps(String reason) {
    _finish(
      validationStep,
      LnReaderDiagnosticStatus.fail,
      'Blocked: $reason',
      null,
    );
    _addBlockedRuntimeSteps(reason);
  }

  void _addBlockedRuntimeSteps(String reason) {
    for (final label in <String>[
      bundleStep,
      engineStep,
      executionStep,
      initializationStep,
      searchStep,
    ]) {
      _finish(label, LnReaderDiagnosticStatus.fail, 'Blocked: $reason', null);
    }
  }

  void _addStep(LnReaderDiagnosticStep step) {
    _steps.add(step);
    _onStep?.call(step);
  }

  LnReaderDiagnosticReport _report({
    LnReaderManifest? manifest,
    LnReaderManifestEntry? selectedPlugin,
    LnReaderRuntimeProbeResult? runtime,
    int? bundleBytes,
    String? manifestError,
  }) {
    return LnReaderDiagnosticReport(
      steps: List<LnReaderDiagnosticStep>.unmodifiable(_steps),
      manifest: manifest ?? _manifest,
      selectedPlugin: selectedPlugin ?? _selected,
      runtime: runtime ?? _runtime,
      bundleBytes: bundleBytes ?? _bundleBytes,
      manifestError: manifestError,
    );
  }

  void dispose() {
    httpClient.close();
  }
}
