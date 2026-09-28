import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/app/data_modules.dart';
import 'package:my_device/features/ai/services/ai_insights_cache.dart';
import 'package:my_device/features/ai/services/insight_prompts.dart';
import 'package:my_device/features/devices/services/device_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Purpose: Build one cache entry.
/// Inputs: `fingerprint`.
/// Returns: `AiInsightEntry`.
/// Side effects: None.
/// Notes: Test helper.
AiInsightEntry _entry(String fingerprint) => AiInsightEntry(
  fingerprint: fingerprint,
  lines: const ['One.', 'Two.'],
  slots: const ['trend', 'advice'],
  status: AiInsightStatus.ok,
  generatedAt: DateTime.utc(2026, 9, 28, 1, 2, 3),
  model: 'stable/full · nano-v3',
  language: 'zh_CN',
  promptVersion: insightPromptVersion,
);

/// Purpose: Test the device-local insight cache file.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates temporary files under the test temp directory.
/// Notes: Path provider is faked so app storage stays inside the sandbox.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mydevice_ai_cache_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    await DeviceStorage.writeConfig({});
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('absent file loads as empty', () async {
    final loaded = await AiInsightsCache.load();
    expect(loaded.entries, isEmpty);
  });

  test('round-trips under the app data folder, atomically', () async {
    await AiInsightsCache.save(
      AiInsights({
        InsightModule.services: _entry('w'),
        InsightModule.deviceFinance: _entry('f'),
      }),
    );
    final file = await AiInsightsCache.file();
    expect(
      p.dirname(file.path),
      (await DeviceStorage.getAppDir()).path,
    );
    expect(p.basename(file.path), 'ai_insights.json');
    final raw = jsonDecode(await file.readAsString()) as Map;
    expect(raw['version'], 1);
    expect((raw['insights'] as Map).keys, ['deviceFinance', 'services']);
    expect(
      (raw['insights'] as Map)['deviceFinance']['generatedAt'],
      '2026-09-28T01:02:03.000Z',
    );
    final loaded = await AiInsightsCache.load();
    expect(loaded.entries[InsightModule.services]!.fingerprint, 'w');
    expect(loaded.entries[InsightModule.deviceFinance]!.slots, ['trend', 'advice']);
    final leftovers = file.parent
        .listSync()
        .where((e) => p.basename(e.path).contains('.tmp'))
        .toList();
    expect(leftovers, isEmpty);
  });

  test('malformed entries and unreadable files read as empty', () async {
    final file = await AiInsightsCache.file();
    await file.writeAsString(
      jsonEncode({
        'version': 1,
        'insights': {
          'legacyModule': {'fingerprint': 1},
          'services': _entry('w').toJson(),
          'unknownModule': _entry('x').toJson(),
        },
      }),
    );
    final loaded = await AiInsightsCache.load();
    expect(loaded.entries.keys, [InsightModule.services]);

    await file.writeAsString('{not json');
    expect((await AiInsightsCache.load()).entries, isEmpty);
  });

  test('clear deletes the file', () async {
    await AiInsightsCache.save(AiInsights({InsightModule.deviceFinance: _entry('t')}));
    await AiInsightsCache.clear();
    expect(await (await AiInsightsCache.file()).exists(), isFalse);
  });

  test('is never a synced or backed-up data module', () {
    expect(
      deviceModuleRegistry.modules.map((m) => m.fileName),
      isNot(contains(AiInsightsCache.fileName)),
    );
  });
}

class _FakePathProvider extends PathProviderPlatform {
  final String documentsPath;

  /// Purpose: Create a fake path provider for tests.
  /// Inputs: `documentsPath`.
  /// Returns: A new `_FakePathProvider` instance.
  /// Side effects: None.
  /// Notes: Only the documents path is needed.
  _FakePathProvider(this.documentsPath);

  /// Purpose: Return the fake application documents directory.
  /// Inputs: None.
  /// Returns: `Future<String?>`.
  /// Side effects: None.
  /// Notes: None.
  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}
