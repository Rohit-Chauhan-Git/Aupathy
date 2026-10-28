import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:reader_app/models/app_settings.dart';
import 'package:reader_app/models/hive_adapters.dart';
import 'package:reader_app/models/novel_model.dart';
import 'package:reader_app/models/plugin_model.dart';
import 'package:reader_app/models/voice_model.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_hive_test_');
    Hive.init(tempDir.path);
    registerHiveAdapters();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('registers the expected adapter type IDs', () {
    expect(Hive.isAdapterRegistered(HiveTypeIds.voice), isTrue);
    expect(Hive.isAdapterRegistered(HiveTypeIds.plugin), isTrue);
    expect(Hive.isAdapterRegistered(HiveTypeIds.appSettings), isTrue);
    expect(Hive.isAdapterRegistered(HiveTypeIds.novel), isTrue);
  });

  test(
    'opens typed boxes and persists every model without type errors',
    () async {
      final voicesBox = await Hive.openBox<VoiceModel>('voices');
      final pluginsBox = await Hive.openBox<PluginModel>('plugins');
      final settingsBox = await Hive.openBox<AppSettings>('app_settings');
      final novelsBox = await Hive.openBox<NovelModel>('novels');

      await voicesBox.put(
        'voice',
        const VoiceModel(id: 1, name: 'Aria', engine: 'sherpa'),
      );
      await pluginsBox.put(
        'plugin',
        const PluginModel(
          id: 2,
          name: 'Source',
          packageName: 'source.plugin',
          version: '1.0.0',
        ),
      );
      await settingsBox.put('settings', const AppSettings(themeMode: 'dark'));
      await novelsBox.put(
        'novel',
        const NovelModel(
          id: 3,
          title: 'The Long Read',
          sourceId: 2,
          sourceName: 'Source',
        ),
      );

      expect(voicesBox.get('voice')?.name, 'Aria');
      expect(pluginsBox.get('plugin')?.name, 'Source');
      expect(settingsBox.get('settings')?.themeMode, 'dark');
      expect(novelsBox.get('novel')?.title, 'The Long Read');
    },
  );
}
