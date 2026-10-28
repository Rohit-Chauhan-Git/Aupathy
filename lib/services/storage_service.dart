import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/app_settings.dart';
import '../models/hive_adapters.dart';
import '../models/novel_model.dart';
import '../models/plugin_model.dart';
import '../models/voice_model.dart';

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  static const String voicesBoxName = 'voices';
  static const String pluginsBoxName = 'plugins';
  static const String settingsBoxName = 'app_settings';
  static const String novelsBoxName = 'novels';
  static const String settingsKey = 'settings';

  Box<VoiceModel>? _voicesBox;
  Box<PluginModel>? _pluginsBox;
  Box<AppSettings>? _settingsBox;
  Box<NovelModel>? _novelsBox;

  bool _initialized = false;

  bool get isInitialized => _initialized;

  Box<VoiceModel> get voicesBox => _require(_voicesBox, voicesBoxName);
  Box<PluginModel> get pluginsBox => _require(_pluginsBox, pluginsBoxName);
  Box<AppSettings> get settingsBox => _require(_settingsBox, settingsBoxName);
  Box<NovelModel> get novelsBox => _require(_novelsBox, novelsBoxName);

  AppSettings get settings =>
      _settingsBox?.get(settingsKey) ?? AppSettings.defaults();

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();
    registerHiveAdapters();

    _voicesBox = await _safeOpenBox<VoiceModel>(
      voicesBoxName,
      () => Hive.openBox<VoiceModel>(voicesBoxName),
    );
    _pluginsBox = await _safeOpenBox<PluginModel>(
      pluginsBoxName,
      () => Hive.openBox<PluginModel>(pluginsBoxName),
    );
    _settingsBox = await _safeOpenBox<AppSettings>(
      settingsBoxName,
      () => Hive.openBox<AppSettings>(settingsBoxName),
    );
    _novelsBox = await _safeOpenBox<NovelModel>(
      novelsBoxName,
      () => Hive.openBox<NovelModel>(novelsBoxName),
    );

    if (!_settingsBox!.containsKey(settingsKey)) {
      await _settingsBox!.put(settingsKey, AppSettings.defaults());
    }

    _initialized = true;
  }

  Future<void> saveSettings(AppSettings value) async {
    final updated = value.copyWith(updatedAt: DateTime.now());
    await settingsBox.put(settingsKey, updated);
  }

  Future<void> close() async {
    await Future.wait<void>([
      if (_voicesBox != null && _voicesBox!.isOpen) _voicesBox!.close(),
      if (_pluginsBox != null && _pluginsBox!.isOpen) _pluginsBox!.close(),
      if (_settingsBox != null && _settingsBox!.isOpen) _settingsBox!.close(),
      if (_novelsBox != null && _novelsBox!.isOpen) _novelsBox!.close(),
    ]);
    _voicesBox = null;
    _pluginsBox = null;
    _settingsBox = null;
    _novelsBox = null;
    _initialized = false;
  }

  Future<Box<T>> _safeOpenBox<T>(
    String name,
    Future<Box<T>> Function() open,
  ) async {
    try {
      return await open();
    } on TypeError {
      return _recoverAndReopen<T>(name, open);
    } on HiveError {
      return _recoverAndReopen<T>(name, open);
    }
  }

  Future<Box<T>> _recoverAndReopen<T>(
    String name,
    Future<Box<T>> Function() open,
  ) async {
    try {
      await _deleteCorruptedBox(name);
    } catch (_) {
      // Reopening below will surface a definitive error if recovery failed.
    }
    return open();
  }

  Future<void> _deleteCorruptedBox(String name) async {
    if (Hive.isBoxOpen(name)) {
      await Hive.box<dynamic>(name).close();
    }
    if (await Hive.boxExists(name)) {
      await Hive.deleteBoxFromDisk(name);
    }
  }

  Box<T> _require<T>(Box<T>? box, String name) {
    if (box == null || !box.isOpen) {
      throw StateError(
        'StorageService is not initialized. Call init() before using "$name".',
      );
    }
    return box;
  }
}
