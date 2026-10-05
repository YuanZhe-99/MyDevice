import 'package:myapps_ai/myapps_ai.dart' show AiInsightEntry;
import 'dart:convert';
import 'dart:io';

import 'package:myapps_data/myapps_data.dart'
    show AtomicWriteQueue, atomicWriteString;
import 'package:path/path.dart' as p;

import '../../devices/services/device_storage.dart';
import 'insight_prompts.dart';

export 'package:myapps_ai/myapps_ai.dart' show AiInsightEntry, AiInsightStatus;

/// Every cached card, keyed by module.
class AiInsights {
  /// The entries.
  final Map<InsightModule, AiInsightEntry> entries;

  /// Purpose: Create a cache value.
  /// Inputs: `entries`.
  /// Returns: A new `AiInsights`.
  /// Side effects: None.
  /// Notes: Copies the map.
  AiInsights([Map<InsightModule, AiInsightEntry>? entries])
    : entries = {...?entries};

  /// Purpose: Serialize the cache file.
  /// Inputs: None.
  /// Returns: A JSON map with sorted module keys.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() {
    final keys = entries.keys.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return {
      'version': 1,
      'insights': {for (final k in keys) k.name: entries[k]!.toJson()},
    };
  }

  /// Purpose: Parse the cache file.
  /// Inputs: `json`.
  /// Returns: `AiInsights` — empty when malformed.
  /// Side effects: None.
  /// Notes: Unknown modules and malformed entries are dropped.
  factory AiInsights.fromJson(Object? json) {
    final out = <InsightModule, AiInsightEntry>{};
    if (json is Map && json['insights'] is Map) {
      final map = json['insights'] as Map;
      for (final module in InsightModule.values) {
        final entry = AiInsightEntry.fromJson(map[module.name]);
        if (entry != null) out[module] = entry;
      }
    }
    return AiInsights(out);
  }
}

/// The device-local insight cache, `ai_insights.json` in the app data folder.
///
/// Deliberately **not** a registered data module: it is never synced, never
/// in a backup bundle or ZIP export, and has no preservation schema. Unlike the
/// data files, an unreadable cache reads as empty — it is rebuildable, and
/// losing it only costs one regeneration per card.
class AiInsightsCache {
  /// Purpose: Prevent instantiation; the cache is static.
  /// Inputs: None.
  /// Returns: Never used.
  /// Side effects: None.
  /// Notes: None.
  AiInsightsCache._();

  /// The cache file name.
  static const fileName = 'ai_insights.json';

  static final _queue = AtomicWriteQueue();

  /// Purpose: Resolve the cache file.
  /// Inputs: None.
  /// Returns: `Future<File>` under `DeviceStorage.getAppDir()`.
  /// Side effects: May create the app directory.
  /// Notes: Goes through the storage hub so custom paths work.
  static Future<File> file() async =>
      File(p.join((await DeviceStorage.getAppDir()).path, fileName));

  /// Purpose: Read the cache.
  /// Inputs: None.
  /// Returns: `Future<AiInsights>` — empty when absent or unreadable.
  /// Side effects: Reads local storage.
  /// Notes: Never throws; see the class note on why.
  static Future<AiInsights> load() async {
    try {
      final f = await file();
      if (!await f.exists()) return AiInsights();
      return AiInsights.fromJson(jsonDecode(await f.readAsString()));
    } catch (_) {
      return AiInsights();
    }
  }

  /// Purpose: Write the cache atomically.
  /// Inputs: `insights`.
  /// Returns: `Future<void>`.
  /// Side effects: Replaces `ai_insights.json` through a serialized queue.
  /// Notes: Never notifies auto-sync.
  static Future<void> save(AiInsights insights) => _queue.enqueue(() async {
    await atomicWriteString(
      await file(),
      const JsonEncoder.withIndent('  ').convert(insights.toJson()),
    );
  });

  /// Purpose: Delete the cache.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Removes `ai_insights.json` if present.
  /// Notes: Serialized with writes.
  static Future<void> clear() => _queue.enqueue(() async {
    final f = await file();
    if (await f.exists()) await f.delete();
  });
}
