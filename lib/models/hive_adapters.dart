import 'package:hive_ce/hive_ce.dart';

import 'app_settings.dart';
import 'novel_model.dart';
import 'plugin_model.dart';
import 'voice_model.dart';

abstract final class HiveTypeIds {
  static const voice = 0;
  static const plugin = 1;
  static const appSettings = 2;
  static const novel = 3;
}

/// Registers every domain adapter with its concrete generic type.
///
/// Avoid registering adapters through a `TypeAdapter<dynamic>` collection:
/// Hive would resolve every model to the first registered adapter and throw
/// errors such as `type 'AppSettings' is not a subtype of type 'VoiceModel'`.
void registerHiveAdapters() {
  _registerAdapter<VoiceModel>(VoiceModelAdapter(), HiveTypeIds.voice);
  _registerAdapter<PluginModel>(PluginModelAdapter(), HiveTypeIds.plugin);
  _registerAdapter<AppSettings>(AppSettingsAdapter(), HiveTypeIds.appSettings);
  _registerAdapter<NovelModel>(NovelModelAdapter(), HiveTypeIds.novel);
}

void _registerAdapter<T>(TypeAdapter<T> adapter, int expectedTypeId) {
  assert(
    adapter.typeId == expectedTypeId,
    '${adapter.runtimeType} must use typeId $expectedTypeId, '
    'but was ${adapter.typeId}.',
  );

  if (!Hive.isAdapterRegistered(expectedTypeId)) {
    Hive.registerAdapter<T>(adapter);
  }
}
