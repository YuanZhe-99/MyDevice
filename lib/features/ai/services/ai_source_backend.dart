import 'dart:io';

import 'package:myapps_ai/myapps_ai.dart';
import 'package:myapps_ai_models/myapps_ai_models.dart';
import 'package:myapps_ai_sources/myapps_ai_sources.dart';
import 'package:myapps_data/myapps_data.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/data_modules.dart';
import 'genai_backend.dart' show MethodChannelGenAiBackend;

export 'package:myapps_ai_sources/myapps_ai_sources.dart' show AiSourceRouter;

/// Purpose: Create the app's AI source router over MyDevice storage.
/// Inputs: Optional [storage] and [system] for tests.
/// Returns: The router.
/// Side effects: Reads the app version in the background for technical
/// details.
/// Notes: Model files live in `<app dir>/ai_models`, outside sync and
/// backups; the choices stay in this device's configuration. MyDevice has no
/// online sources.
AiSourceRouter createAiSourceRouter({
  StorageAdapter? storage,
  CapabilityGenAiBackend? system,
}) {
  final s = storage ?? const DeviceStorageAdapter();
  final appInfo = <String, String>{};
  PackageInfo.fromPlatform()
      .then((i) => appInfo['app'] = 'MyDevice ${i.version}+${i.buildNumber}')
      .catchError((_) => appInfo['app'] = 'MyDevice');
  return AiSourceRouter(
    store: CallbackAiSourceStore(
      readConfig: s.readConfig,
      writeConfig: s.writeConfig,
    ),
    system: system ?? MethodChannelGenAiBackend(),
    models: CallbackModelStorageRoot(
      () async => Directory('${(await s.getAppDir()).path}/ai_models'),
    ),
    appInfo: appInfo,
  );
}
