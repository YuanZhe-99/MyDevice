import 'dart:convert';
import 'dart:io';

import 'package:myapps_data/myapps_data.dart'
    show AtomicWriteQueue, atomicWriteString;
import 'package:path/path.dart' as p;

import '../../devices/services/device_storage.dart';
import 'insight_prompts.dart';

/// Whether a cached insight holds text or records a refusal.
enum AiInsightStatus {
  /// The model answered; `lines` holds the text.
  ok,

  /// The model refused (guardrail) or cannot write this language; kept so
  /// the same facts are not retried until they change.
  skipped,
}

/// One cached card.
class AiInsightEntry {
  /// Hex SHA-256 of everything the card depends on.
  final String fingerprint;

  /// The validated sentences, in slot order; empty for [AiInsightStatus.skipped].
  final List<String> lines;

  /// Slot id of each entry in [lines] (e.g. `flowSummary`), so a card can put a
  /// line under the right section when an earlier slot was dropped.
  final List<String> slots;

  /// Text or refusal.
  final AiInsightStatus status;

  /// When it was generated, in UTC.
  final DateTime generatedAt;

  /// The model identity it was generated with, for diagnostics.
  final String? model;

  /// The request language tag, e.g. `zh_CN`.
  final String language;

  /// `insightPromptVersion` at generation time.
  final int promptVersion;

  /// Purpose: Create a cache entry.
  /// Inputs: see fields.
  /// Returns: A new `AiInsightEntry`.
  /// Side effects: None.
  /// Notes: `slots` defaults to empty (no section grouping).
  AiInsightEntry({
    required this.fingerprint,
    required this.lines,
    List<String>? slots,
    required this.status,
    required this.generatedAt,
    this.model,
    required this.language,
    required this.promptVersion,
  }) : slots = slots ?? const [];

  /// Purpose: Serialize the entry.
  /// Inputs: None.
  /// Returns: A JSON map.
  /// Side effects: None.
  /// Notes: `generatedAt` is written in UTC.
  Map<String, dynamic> toJson() => {
    'fingerprint': fingerprint,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'language': language,
    'lines': lines,
    if (model != null) 'model': model,
    'promptVersion': promptVersion,
    'slots': slots,
    'status': status.name,
  };

  /// Purpose: Parse an entry.
  /// Inputs: `json`.
  /// Returns: `AiInsightEntry?` — null when malformed.
  /// Side effects: None.
  /// Notes: Tolerant: a bad entry is dropped, not fatal.
  static AiInsightEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final fingerprint = json['fingerprint'];
    final lines = json['lines'];
    final status = AiInsightStatus.values
        .where((s) => s.name == json['status'])
        .firstOrNull;
    final generatedAt = DateTime.tryParse('${json['generatedAt']}');
    if (fingerprint is! String ||
        lines is! List ||
        status == null ||
        generatedAt == null) {
      return null;
    }
    final text = [for (final l in lines) '$l'];
    final rawSlots = json['slots'];
    final slots = rawSlots is List
        ? [for (final s in rawSlots) '$s']
        : null;
    return AiInsightEntry(
      fingerprint: fingerprint,
      lines: text,
      slots: slots != null && slots.length == text.length ? slots : null,
      status: status,
      generatedAt: generatedAt.toUtc(),
      model: json['model'] is String ? json['model'] as String : null,
      language: json['language'] is String ? json['language'] as String : '',
      promptVersion: json['promptVersion'] is int
          ? json['promptVersion'] as int
          : 0,
    );
  }
}

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
    final keys = entries.keys.toList()..sort((a, b) => a.name.compareTo(b.name));
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
