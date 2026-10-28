# Project Changelog

## 2026-10-28

### Added

- `lib/models/voice_model.dart` — `VoiceModel` domain model and Hive CE `TypeAdapter` (typeId 0).
- `lib/models/plugin_model.dart` — `PluginModel` domain model, `PluginType` enum, and Hive CE adapter (typeId 1).
- `lib/models/app_settings.dart` — `AppSettings` model with defaults/copyWith and Hive CE adapter (typeId 2).
- `lib/models/novel_model.dart` — `NovelModel` library entry with reading progress and Hive CE adapter (typeId 3).
- `lib/models/hive_adapters.dart` — adapter type IDs and idempotent `registerHiveAdapters()` registration.
- `lib/services/storage_service.dart` — singleton `StorageService` that initializes Hive CE, registers adapters, safely opens the `voices`, `plugins`, `app_settings`, and `novels` boxes (with corrupt-box recovery), and exposes settings persistence.
- `lib/views/home_view.dart` — placeholder library view.
- `lib/widgets/empty_state.dart` — reusable empty-state widget.

### Changed

- `lib/main.dart` — initializes `StorageService` before `runApp`, theme setup, and startup error screen.
- `test/widget_test.dart` — updated smoke test for the new library view.

### Structure

```
lib/
  models/
    app_settings.dart
    hive_adapters.dart
    novel_model.dart
    plugin_model.dart
    voice_model.dart
  services/
    storage_service.dart
  views/
    home_view.dart
  widgets/
    empty_state.dart
  main.dart
```

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — all tests passed.
- `dart format` — normalized `lib/models/novel_model.dart`.

### Clean domain layout

```
lib/
  main.dart
  models/
    app_settings.dart
    hive_adapters.dart
    novel_model.dart
    plugin_model.dart
    voice_model.dart
  services/
    storage_service.dart
  views/
    home_view.dart
  widgets/
    empty_state.dart
```

## 2026-10-28 — Global theme system

### Added

- `lib/theme/app_theme.dart` — global `ThemeData` for the dark slate/blue palette:
  - Deep navy backgrounds (`AppColors.deepNavy`/`navy`), layered card surfaces, indigo/blue accents, and reusable primary/accent/card gradients (`AppGradients`).
  - Typography roles for **Lora** (display/headings), **Nunito** (UI/body), and **Mono** (metadata/captions) via `AppFonts` and a complete `TextTheme`.
  - `AppThemeExtension` exposing gradients and the mono text style to widgets.
  - `AppTheme.highContrastDarkTheme` with a dedicated high-contrast `ColorScheme`.
  - `AppTheme.textScaleBuilder` clamping accessibility text scaling to `0.85–2.0` while preserving system scaling.
  - Component theming for app bars, cards, buttons, inputs, chips, navigation, dialogs, sheets, snackbars, and progress indicators.

### Changed

- `lib/main.dart` — uses `AppTheme.darkTheme`, registers both high-contrast themes, forces dark `ThemeMode`, and applies `AppTheme.textScaleBuilder`.

### Verification

- `dart format lib/theme/app_theme.dart lib/main.dart` — formatted.
- `flutter analyze` — no issues found.
- `flutter test` — all tests passed.

## 2026-10-28 — Hive adapter type fix

### Fixed

- `lib/models/hive_adapters.dart` — adapters are now registered with concrete generic types instead of `TypeAdapter<dynamic>`, which made Hive resolve every model to the first adapter and throw `type 'AppSettings' is not a subtype of type 'VoiceModel'`. Type IDs are asserted to match exactly: VoiceModel 0, PluginModel 1, AppSettings 2, NovelModel 3.
- `lib/services/storage_service.dart` — each box is opened with an explicit generic (`Hive.openBox<VoiceModel>` etc.); `TypeError`/`HiveError` during opening now closes, deletes, and cleanly reopens the affected box.

### Added

- `test/hive_adapters_test.dart` — verifies adapter type IDs and typed read/write round-trips for all four models.

### Verification

- `dart format lib test` — formatted.
- `flutter analyze` — no issues found.
- `flutter test` — all tests passed.
- Debug APK built, installed, and launched on the Android device with no Hive/type errors in logcat.

## 2026-10-28 — Phase 3 novel library UI and widget-test hang fix

### Added

- `lib/views/novel_library_view.dart` — responsive library presentation with heading, collection summary, search, result counts, empty/no-results states, and an adaptive grid.
- `lib/widgets/novel_card.dart` — reusable novel card with cover fallback, favorite/download indicators, metadata, and reading progress.
- `lib/widgets/reading_progress_bar.dart` — gradient progress bar with chapter and percentage labels.
- `lib/widgets/library_search_field.dart` — reusable search field with a clear action.
- `test/home_view_test.dart` — coverage for empty library, Hive-backed rendering, progress/metadata, search filtering, clearing search, and storage-error handling.

### Changed

- `lib/views/home_view.dart` — resolves the `StorageService` novels box, listens for Hive changes via `box.listenable()`, and handles unavailable/closed storage with a retryable error state.
- `lib/widgets/empty_state.dart` — gradient icon treatment and optional action button support.
- `test/widget_test.dart` — verifies the app degrades gracefully when storage is unavailable.

### Fixed

- `test/home_view_test.dart` — the second widget test hung at `await novelsBox.putAll(...)`. `testWidgets` bodies run in a FakeAsync zone, so Hive's real disk I/O future never completed. The seed writes are now wrapped in `tester.runAsync()`, and the initial unbounded `pumpAndSettle()` was replaced with bounded `pump()` calls. Production widgets required no fix.

### Verification

- `flutter test test/home_view_test.dart --plain-name "renders novels, reading progress, and filters search results" -r expanded` — passed.
- `flutter test test/home_view_test.dart -r expanded` — 3 tests passed.
- `flutter test -r expanded` — all 6 tests passed.
- `flutter analyze` — no issues found.
- `dart format lib test` — completed with no remaining changes.

## 2026-10-28 — Phase 5 Browse: Sources, Plugins, and Voices

### Added

- `lib/views/browse_view.dart` — Browse section with a search field, a three-tab shell (Sources, Plugins, Voices), reactive Hive data, retryable storage-error state, and persisted plugin/voice actions.
- `lib/views/browse/sources_tab.dart` — source catalog cards with language, host, install/enable status, library usage counts, search, source details sheet, and empty/no-results states.
- `lib/views/browse/plugins_tab.dart` — installed and uninstalled plugin list, type/language/version metadata, search, All/Installed/Not-installed filters, and an enable switch for installed plugins.
- `lib/views/browse/voices_tab.dart` — voice catalog cards with engine, language, locale, gender, sample rate, install status, language filters, search, and a persisted favorite toggle.
- `lib/models/source_entry.dart` — non-Hive `SourceEntry` view model plus `buildSourceCatalog()`, which joins source plugins with source references already present in the library and marks library-only sources honestly.
- `lib/widgets/browse_item_card.dart` — reusable Browse card, badge, and gradient leading-icon widgets.
- `test/browse_view_test.dart` — coverage for tab switching, search and no-results states, clearing search, plugin/voice rendering, plugin status filters, persisted enable/favorite updates, query preservation across tabs, storage-error handling, small-screen large-text layout, and MainShell Browse navigation.

### Changed

- `lib/views/main_shell.dart` — Browse now hosts the real `BrowseView`; optional plugin/voice box overrides were added for tests while Library, History, and More behavior is preserved.
- `lib/widgets/library_search_field.dart` — added an optional `hintText` (default unchanged) so Browse can describe the active tab.
- `lib/widgets/empty_state.dart` — empty states are now scrollable, preventing overflow when Browse tabs have limited vertical space or large accessibility text.
- `PROJECT_CHANGELOG.md` — appended this Phase 5 entry.

### Persistence and model notes

- No Hive type IDs, adapters, or serialized field formats were changed.
- Plugin enablement and voice favorites are persisted through the existing typed Hive boxes and `copyWith`.
- Sources are derived at read time; no new Hive box was introduced.
- Voice binaries remain separate from Hive metadata (`VoiceModel.modelPath` is untouched).

### Verification

- `dart format lib test` — completed; 27 files formatted with no errors.
- `flutter analyze` — no issues found.
- `flutter test -r expanded` — all 35 tests passed.
- `flutter build apk --debug` — succeeded: `build/app/outputs/flutter-apk/app-debug.apk`.
- Android device verification (Motorola Moto G54 5G, `ZD222HJ8W7`, Android 13 / API 33):
  - `flutter devices` and `adb devices` both detected the physical device.
  - Debug APK installed with `adb install -r` and launched via `am start`.
  - Library still renders its empty state; Browse opens with Sources, Plugins, and Voices tabs.
  - All three tabs were opened on-device and showed their honest empty states; search input and clear control worked.
  - No fatal Flutter, Android runtime, or Hive errors were found in logcat.

### Remaining limitations / Phase 6 candidates

- Source browsing/opening is UI-only and requires a real source execution integration.
- Plugin download, install, update, and execution are not implemented; only local metadata and enablement are managed.
- Voice download, installation, preview, and TTS playback are not implemented; only catalog metadata and favorites are managed.
- History and More remain placeholders.
- Library-to-source deep links and source detail actions should be added together with source execution.

## 2026-10-28 — Phase 6 LNReader compatibility diagnostics

### Added

- `lib/models/lnreader_manifest_entry.dart` — validated LNReader manifest entry model, manifest summary, and rejected-entry issues.
- `lib/services/lnreader_http_client.dart` — injectable HTTP client with response-size cap, request timeouts, and readable network/HTTP errors.
- `lib/services/lnreader_manifest_service.dart` — fetches and parses the official LNReader v3.0.0 plugin manifest, rejecting malformed entries without discarding valid ones.
- `lib/services/lnreader_runtime_probe.dart` — QuickJS sandbox probe with stack/time limits, raw bundle execution, limited non-networking module shims, plugin export inspection, and a real `searchNovels()` call.
- `lib/services/lnreader_diagnostic_service.dart` — orchestrates manifest retrieval/validation, plugin selection, bundle download, engine startup, execution, initialization, and search steps with live PASS/FAIL/WARN reporting.
- `lib/views/lnreader_diagnostics_view.dart` — diagnostic screen showing live steps, manifest counts, selected plugin, runtime contract, dependencies, missing capabilities, rejected entries, and a manifest preview.
- `test/lnreader_manifest_test.dart` — manifest parsing, invalid-entry, malformed-JSON, and URL validation coverage.
- `test/lnreader_diagnostic_test.dart` — service failure/fallback/engine tests plus diagnostic-screen widget coverage.

### Changed

- `lib/views/browse_view.dart` — added a science icon in the Browse header that opens the diagnostics screen.
- `lib/services/lnreader_http_client.dart` — handles the Dio `transformTimeout` error type.
- `PROJECT_CHANGELOG.md` — appended this Phase 6 entry.

### Device-verified behavior

- Manifest: HTTP 200, 327 raw entries, 326 valid; the `komga` entry is rejected because its `site` is not an http(s) URL.
- Selected plugin: Royal Road (`royalroad`) v2.3.3, 14,087-byte bundle downloaded.
- QuickJS engine starts and passes the sanity check.
- Raw bundle execution fails honestly on `require()`; shimmed initialization finds `searchNovels`, `parseNovel`, `parseChapter`, and `popularNovels`, but is reported as WARN rather than compatibility.
- Real `searchNovels()` is attempted and fails with `LNREADER_FETCH_API_UNAVAILABLE`; no results are fabricated.
- No fatal Flutter, Android, or Hive errors appeared in logcat.

### Runtime notes and limitations

- The bundled `flutter_js` 0.8.7 QuickJS library lacks the `jsSetMemoryLimit` symbol on Android; the probe therefore does not request a memory limit and the UI states this limitation. Stack and timeout limits remain enabled.
- The diagnostic shims are intentionally non-networking and do not implement `fetchApi`, cheerio, or htmlparser2. The report lists the missing capabilities required for actual plugin execution.
- This phase verifies compatibility; it does not add source browsing, plugin installation, chapter downloading, or TTS execution.

### Verification

- `dart format lib test` — completed with no remaining changes.
- `flutter analyze` — no issues found.
- `flutter test -r expanded` — all 47 tests passed.
- `flutter run -d ZD222HJ8W7 --no-resident` — rebuilt, installed in ~10 seconds, and launched successfully.
- Android device: Motorola Moto G54 5G (`ZD222HJ8W7`), Android 13 / API 33.

## 2026-10-28 — Phase 7 LNReader repository, installation, and live plugin runtime

### Added

- `lib/services/lnreader_plugin_repository.dart` — official LNReader repository client with manifest loading, search/filter helpers, bundle download and installation into the existing plugins Hive box, installed lookup, and stable integer plugin IDs.
- `lib/views/lnreader_repository_view.dart` — live repository catalog with manifest refresh, plugin search, language filtering, install state, and install actions.
- `test/lnreader_repository_test.dart` — repository load/filter/install/error coverage.
- LNReader plugin selection in `lib/views/lnreader_diagnostics_view.dart` — after the manifest loads, users can search all 326 valid plugins, select one, and rerun diagnostics against that bundle.
- Runtime support in `lib/services/lnreader_runtime_js.dart` for official CommonJS bundles: module loader, `@libs/fetch`, `@libs/filterInputs`, `@libs/novelStatus`, `@libs/isAbsoluteUrl`, `@libs/defaultCover`, `@libs/storage`, `htmlparser2`-compatible parsing, URL/encoding helpers, and the `LnReaderHttp` host bridge.
- Real search result previews and runtime errors in the diagnostics report.

### Changed

- `lib/services/lnreader_runtime_probe.dart` — executes bundles through the LNReader module loader, checks the exported plugin contract, performs a real `searchNovels()` call with microtask pumping and timeout handling, and reports missing modules/APIs.
- `lib/services/lnreader_diagnostic_service.dart` — supports an explicit `pluginId`, performs live bundle/init/search steps, and reports PASS only when the corresponding operation actually succeeds.
- `lib/services/lnreader_diagnostic_service.dart` / `lib/views/lnreader_diagnostics_view.dart` — execution, initialization, and search now have independent pass/fail semantics instead of treating initialization as a warning.
- `lib/views/browse/plugins_tab.dart` and `lib/views/browse_view.dart` — added the official repository entry and navigation.
- `test/lnreader_diagnostic_test.dart` and `test/browse_view_test.dart` — updated for live runtime semantics, plugin selection, and repository entry coverage.
- `PROJECT_CHANGELOG.md` — appended this Phase 7 entry.

### Persistence and compatibility notes

- No Hive type IDs, adapters, boxes, or serialized field formats were changed.
- Installed LNReader bundles reuse the existing `PluginModel` and store repository metadata under `metadata` keys `lnreaderId`, `lnreaderBundleUrl`, `lnreaderBundleSource`, `lnreaderSite`, and `lnreaderVersion`.
- `LnReaderManifestEntry` remains a transport-only model and is not stored in Hive.
- No new package dependency was introduced for this phase.

### Device-verified behavior

- Repository loaded the live official manifest: HTTP 200, 327 raw entries, 326 valid, 1 rejected (`komga` has a non-http(s) `site`).
- Royal Road v2.3.3 installed from the repository (14,087-byte bundle); Plugins showed 1 plugin and Sources showed 1 source.
- Diagnostics executed the Royal Road bundle through the LNReader loader and initialized `searchNovels`, `parseNovel`, `parseChapter`, and `popularNovels`.
- Royal Road search reached the real endpoint but was blocked by Cloudflare with HTTP 403 (`cf-mitigated: challenge`); the plugin's own bot-check error is reported honestly.
- Selected Atsumaru v1.0.1 through the new plugin picker and ran a real `searchNovels("shadow")`: 20 live results, including `Shadow Slave`, `My Living Shadow System Devours To Make Me Stronger`, `The Eminence in Shadow`, and `Empire of Shadows`.
- This confirms the full pipeline: official manifest → bundle download → QuickJS load → plugin initialization → real HTTP request → plugin parsing → live result list.

### Remaining limitations

- Royal Road search requires passing Cloudflare's browser challenge; no WebView cookie/challenge handoff is implemented, so Royal Road live search is still blocked externally.
- `cheerio`, `dayjs`, and some other LNReader modules are not implemented, so plugins requiring them cannot complete all operations.
- The HTTP response cap is 4 MB; Novel Bin's search index currently exceeds it.
- This phase verifies search execution and installation. Novel detail/chapter parsing, library import, and source browsing UI are not wired yet.

### Verification

- `dart format lib test` — completed with no remaining changes.
- `flutter analyze` — no issues found.
- `flutter test -r compact` — all 55 tests passed.
- `flutter build apk --debug` — succeeded: `build/app/outputs/flutter-apk/app-debug.apk`.
- APK installed and launched on Motorola Moto G54 5G (`ZD222HJ8W7`, Android 13 / API 33).

## 2026-10-28 — Phase 8 LNReader discovery and Library import

### Added

- `lib/services/lnreader_novel_service.dart` — typed search/details/chapter API over the installed LNReader bundle, with validation, timeouts, malformed-response handling, URL resolution, and chapter-content retrieval.
- `lib/services/lnreader_library_importer.dart` — duplicate-safe import/update into the existing `NovelModel` Hive box, preserving IDs, progress, favorite/download state, date added, and unrelated metadata while storing normalized chapter lists under `metadata["lnreaderChapters"]`.
- `lib/views/lnreader_source_search_view.dart` — live installed-source search with loading, empty, error/retry, result, and pagination states.
- `lib/views/lnreader_novel_details_view.dart` — live cover, metadata, synopsis, genres, status, chapter count, and Add/Update Library action.
- `lib/widgets/lnreader_cover.dart` — cover loading/fallback widget with no network image errors leaking into the UI.
- `test/lnreader_library_importer_test.dart` — new import, duplicate update/progress preservation, optional fields, per-plugin separation, and reopen/persistence tests.
- `test/lnreader_discovery_flow_test.dart` — fake-API widget coverage for search → details → chapters → import/update, plus empty and retryable error states.
- `test/lnreader_live_plugin_test.dart` — live Atsumaru integration test for real search, novel parsing, chapter list, and chapter content. It is skipped by default and run with `LNREADER_LIVE_TESTS=1` plus `LD_LIBRARY_PATH` for `flutter_js` on Linux.
- `test/fixtures/atsumaru.js` — the official Atsumaru v1.0.1 bundle used by the live integration test.

### Changed

- `lib/views/browse/sources_tab.dart` and `lib/views/browse_view.dart` — installed and enabled LNReader sources now open their real search screen; unavailable sources explain why they cannot open.
- Source cards in Browse show how many imported novels belong to each installed source.
- `PROJECT_CHANGELOG.md` — appended this Phase 8 entry.

### Persistence and compatibility notes

- No Hive type IDs, adapters, boxes, or existing `NovelModel` fields were changed.
- Imported chapters reuse the existing `NovelModel.metadata` map under `lnreaderChapters`; plugin identity and source paths are stored as metadata only.
- Duplicate detection uses plugin identity plus a normalized novel path/source URL, so re-import updates the same Hive key instead of creating a second entry.
- Reader/TTS playback, downloads, History, and More remain out of scope for this phase; chapter content is exposed at the service boundary for the Reader phase.

### Live integration result

- Real Atsumaru plugin run: `searchNovels("shadow")` returned 20 results.
- Parsed `Shadow Slave` (`8kL3`) with 3,228 chapters.
- Fetched "Chapter 1: Nightmare Begins" as 11,143 characters of real chapter content.
- Royal Road remains externally blocked by Cloudflare, and unsupported modules (`cheerio`, `dayjs`) still limit some plugins; failures are reported rather than hidden.

### Verification

- `dart format lib test` — 48 files checked, no changes.
- `flutter analyze` — no issues found.
- `flutter test -r expanded` — 78 passed, 1 live test skipped by default.
- `LNREADER_LIVE_TESTS=1 LD_LIBRARY_PATH=... flutter test test/lnreader_live_plugin_test.dart` — live Atsumaru search/details/chapter test passed.
- `flutter build apk --debug` — succeeded: `build/app/outputs/flutter-apk/app-debug.apk`.
- Android device (Motorola Moto G54 5G, `ZD222HJ8W7`, Android 13 / API 33):
  - Installed Atsumaru from the official repository (7,247-byte bundle).
  - Searched `shadow` from the Browse source and got live results.
  - Opened `Shadow Slave`, loaded real synopsis/genres/status and 3,228 chapters.
  - Added it to the Library; the action changed to Update library entry.
  - Library shows `1 novel`, `Shadow Slave`, source `Atsumaru`, with genres and 0% progress.
  - No fatal Flutter, Android, or Hive errors appeared in logcat.

## 2026-10-28 — Reader engine and reading experience

### Added

- `lib/services/reader_html.dart` — sanitizing HTML-to-block conversion for real LNReader chapter HTML. Removes scripts, styles, navigation, footer/ad/share/comment clutter, and supports headings, paragraphs, emphasis, links, breaks, quotes, bullets, and separators.
- `lib/services/reader_chapters.dart` — chapter-list deserialization from `NovelModel.metadata`, path deduplication, source-order preservation, and resume-index resolution by saved path first and `lastReadChapter` second.
- `lib/services/reader_progress.dart` — `ReaderPosition`, chapter/novel progress math, and a debounced, serialized `ReaderProgressStore` with stale-write protection.
- `lib/views/reader/reader_view.dart` — real reader with loading/error/retry states, sanitized block rendering, selectable text, lazy list rendering, chapter cache, previous/next navigation, TOC, settings, tap-to-toggle chrome, and lifecycle/back/close saves.
- `lib/views/reader/reader_theme.dart` — dark/light/sepia reader palettes, contrast-safe reader colors, bundled font mapping, alignment, and paragraph styling.
- `lib/views/reader/reader_settings_sheet.dart` — live appearance/theme, font family, font size, line height, paragraph spacing, side margins, alignment, progress visibility, and reset controls.
- `lib/views/reader/chapter_list_sheet.dart` — lazy searchable chapter list with current-chapter highlighting and direct selection.
- `lib/views/novel_library_view.dart` / `lib/views/home_view.dart` / `lib/views/main_shell.dart` — Library novel cards now open the Reader through the installed source plugin.
- `test/reader_html_test.dart`, `test/reader_progress_test.dart`, `test/reader_settings_test.dart`, and `test/reader_view_test.dart` — reader conversion, progress debounce/stale writes, settings persistence/contrast, and full widget-flow coverage.
- `test/fixtures/reader_chapter.html` — formatted public-domain-style chapter fixture with real HTML noise.

### Changed

- `lib/models/app_settings.dart` — appended backward-compatible fields at adapter indices 14–16: `readerParagraphSpacing` (default `12.0`), `readerTextAlign` (default `left`), and `readerShowProgress` (default `true`). Existing reader theme/font/size/line-height/margin fields are reused.
- `lib/views/reader/chapter_list_sheet.dart` — removed the fixed 66 px row extent so large text can grow without overflowing.
- `test/lnreader_live_plugin_test.dart` — live chapter coverage now also converts real Atsumaru HTML into reader blocks and checks sanitized plain text.

### Persistence and compatibility notes

- No Hive adapter type IDs or existing serialized field meanings were changed. `AppSettings` remains type ID 2; the new fields are appended only.
- Reading position is stored in existing `NovelModel.metadata` under `readerChapterIndex`, `readerChapterPath`, `readerScrollOffset`, `readerScrollFraction`, and `readerUpdatedAt`, avoiding adapter changes.
- `NovelModel.lastReadChapter` retains its existing meaning (chapters read); the current zero-based chapter index is persisted as `lastReadChapter = index + 1`.
- Progress writes are debounced and serialized. Chapter switches do not wait for disk writes before loading.
- Reader appearance is independent from the app theme and persists through the existing settings box.
- No TTS playback, voice downloads, Cloudflare bypass, downloads, History, or More features were added.

### Verification

- `dart format lib test` — 59 files checked, no changes.
- `flutter analyze` — no issues found.
- `flutter test -r expanded` — 101 passed, 1 live test skipped by default.
- `LNREADER_LIVE_TESTS=1 LD_LIBRARY_PATH=/home/rohit/.pub-cache/hosted/pub.dev/flutter_js-0.8.7/linux/shared flutter test test/lnreader_live_plugin_test.dart` — passed against live Atsumaru: 20 search results, `Shadow Slave` with 3,228 chapters, real chapter 1 content (11,143 chars), and non-empty sanitized reader blocks.
- `flutter build apk --debug` — succeeded: `build/app/outputs/flutter-apk/app-debug.apk`.

### Device-verified behavior

- Installed and launched on Motorola Moto G54 5G (`ZD222HJ8W7`, Android 13 / API 33).
- Opened `Shadow Slave` from the Library and rendered real chapter 1 content with cleaned formatting.
- Scrolled to 9% chapter progress; chapter 2 then saved as `Chapter 2 of 3228` in the Library.
- Reopened the novel and restored chapter 2 at the saved 2% scroll position.
- Opened Reader Settings: switched to Sepia, increased font size, and closed the sheet; the reader updated immediately.
- Left and reopened the novel: Sepia, larger font, chapter 2, and scroll position were all restored.
- Opened the TOC: chapter 2 was highlighted as current; selecting chapter 3 loaded its real content.
- Returned to the Library and verified search for `shadow` still filters correctly; Browse and Library navigation remain functional.
