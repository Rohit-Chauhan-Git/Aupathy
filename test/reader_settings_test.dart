import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:reader_app/models/app_settings.dart';
import 'package:reader_app/models/hive_adapters.dart';
import 'package:reader_app/services/storage_service.dart';
import 'package:reader_app/views/reader/reader_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<AppSettings> box;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_settings_test_');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    box = await Hive.openBox<AppSettings>('reader_settings');
  });

  setUp(() async {
    await box.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('reader defaults are sensible', () {
    final defaults = AppSettings.defaults();
    expect(defaults.fontSize, greaterThanOrEqualTo(16));
    expect(defaults.lineHeight, greaterThanOrEqualTo(1.4));
    expect(defaults.pageMargin, greaterThan(0));
    expect(defaults.readerParagraphSpacing, greaterThan(0));
    expect(defaults.readerTextAlign, 'left');
    expect(defaults.readerShowProgress, isTrue);
  });

  test('new reader settings survive a Hive reopen', () async {
    final settings = AppSettings.defaults().copyWith(
      readerTheme: ReaderThemeValues.sepia,
      fontFamily: ReaderFonts.nunito,
      fontSize: 23,
      lineHeight: 1.9,
      pageMargin: 34,
      readerParagraphSpacing: 19,
      readerTextAlign: 'justify',
      readerShowProgress: false,
    );
    final persist = await Hive.openBox<AppSettings>('reader_settings_persist');
    await persist.put(StorageService.settingsKey, settings);
    await persist.close();

    final reopened = await Hive.openBox<AppSettings>('reader_settings_persist');
    final stored = reopened.get(StorageService.settingsKey)!;
    expect(stored.readerTheme, ReaderThemeValues.sepia);
    expect(stored.fontFamily, ReaderFonts.nunito);
    expect(stored.fontSize, 23);
    expect(stored.lineHeight, 1.9);
    expect(stored.pageMargin, 34);
    expect(stored.readerParagraphSpacing, 19);
    expect(stored.readerTextAlign, 'justify');
    expect(stored.readerShowProgress, isFalse);
    expect(stored.ttsSpeed, 1.0);
    await reopened.deleteFromDisk();
  });

  test('reader palettes provide readable contrast', () {
    for (final name in ReaderThemeValues.all) {
      final palette = ReaderPalette.resolve(name);
      expect(
        _contrast(palette.text, palette.background),
        greaterThanOrEqualTo(4.5),
        reason: '$name body text contrast',
      );
      expect(
        _contrast(palette.secondaryText, palette.background),
        greaterThanOrEqualTo(3.0),
        reason: '$name secondary text contrast',
      );
      expect(
        _contrast(palette.link, palette.background),
        greaterThanOrEqualTo(3.0),
        reason: '$name link contrast',
      );
    }
  });

  test('font family choices map to readable bundled/fallback families', () {
    expect(ReaderFonts.resolveFamily('lora'), 'Lora');
    expect(ReaderFonts.resolveFamily('nunito'), 'Nunito');
    expect(ReaderFonts.resolveFamily('system'), '');
    expect(ReaderFonts.resolveFamily('default'), 'Lora');
  });
}

double _contrast(Color foreground, Color background) {
  final light = math.max(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  final dark = math.min(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  return (light + 0.05) / (dark + 0.05);
}
