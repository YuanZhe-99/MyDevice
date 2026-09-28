import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_insights_cache.dart';
import 'genai_backend.dart';
import 'insight_language.dart';
import 'insight_prompts.dart';
import 'on_device_ai_service.dart';

/// Where a card is in its life cycle.
enum AiInsightPhase {
  /// Nothing requested yet, or the model cannot run right now.
  idle,

  /// A generation is queued or running.
  generating,

  /// [AiInsightState.entry] matches the current facts.
  ready,

  /// The last attempt failed; see [AiInsightState.failure].
  failed,
}

/// What a card shows.
@immutable
class AiInsightState {
  /// The phase.
  final AiInsightPhase phase;

  /// The entry to show: current when [stale] is false, else the previous one.
  final AiInsightEntry? entry;

  /// Why the last attempt failed, when [phase] is `failed`.
  final GenAiFailure? failure;

  /// Whether [entry] belongs to older facts.
  final bool stale;

  /// Purpose: Create a card state.
  /// Inputs: see fields.
  /// Returns: A new `AiInsightState`.
  /// Side effects: None.
  /// Notes: None.
  const AiInsightState({
    this.phase = AiInsightPhase.idle,
    this.entry,
    this.failure,
    this.stale = false,
  });
}

/// One card's request: its facts and the language to answer in.
class AiInsightRequest {
  /// The app-computed facts.
  final InsightFacts facts;

  /// The reply language.
  final InsightLanguage language;

  /// Local time the facts were computed for; its date is fingerprinted.
  final DateTime now;

  /// A plainer second try, or null: sent once when the model declines
  /// [facts] or returns nothing usable for them. The finance card passes a
  /// version without device names. Not part of the fingerprint.
  final InsightFacts? fallbackFacts;

  /// Purpose: Create a request.
  /// Inputs: see fields.
  /// Returns: A new `AiInsightRequest`.
  /// Side effects: None.
  /// Notes: `fallbackFacts` must carry the same module and the same slot
  /// ids in the same order as `facts`, so the card's sections still apply.
  const AiInsightRequest({
    required this.facts,
    required this.language,
    required this.now,
    this.fallbackFacts,
  });
}

/// Purpose: Name the model a status report describes.
/// Inputs: `report`.
/// Returns: `String` — e.g. `stable/full · nano-v3`, or `apple`.
/// Side effects: None.
/// Notes: Same rule as MyAnime!!!!!; a model update changes fingerprints.
String modelIdentityOf(GenAiStatusReport report) {
  final parts = [?report.variant, ?report.baseModelName];
  return parts.isEmpty ? 'apple' : parts.join(' · ');
}

/// Purpose: Fingerprint one card request.
/// Inputs: `request`, `model` — from [modelIdentityOf].
/// Returns: `String` — hex SHA-256.
/// Side effects: None.
/// Notes: Covers the module, the prompt version, the language, the local
/// date, the model and the
/// facts. A change to any of them regenerates the card; nothing else does.
String insightFingerprint(AiInsightRequest request, String model) {
  final text = [
    request.facts.module.name,
    'prompt:$insightPromptVersion',
    'language:${request.language.localeTag}',
    'date:${factDate(request.now)}',
    'model:$model',
    request.facts.canonical(),
  ].join('\n');
  return sha256.convert(utf8.encode(text)).toString();
}

/// Owns the insight cards: the cache, what each card shows, and when to run
/// the model.
///
/// At most one generation per module runs or waits in the model queue; a
/// request that arrives meanwhile replaces the pending one, so rapid data
/// changes (ticking off several tasks) cost at most one extra run.
class AiInsightStore extends ChangeNotifier {
  /// Purpose: Create the store.
  /// Inputs: `ai` — the model service; `load`/`save`/`clear` — cache I/O,
  /// injectable for tests; `clock` — UTC clock for `generatedAt`.
  /// Returns: A new `AiInsightStore`.
  /// Side effects: None until first use.
  /// Notes: Defaults use `OnDeviceAiService.instance` and `AiInsightsCache`.
  AiInsightStore({
    OnDeviceAiService? ai,
    Future<AiInsights> Function()? load,
    Future<void> Function(AiInsights insights)? save,
    Future<void> Function()? clear,
    DateTime Function()? clock,
  }) : _aiOverride = ai,
       _load = load ?? AiInsightsCache.load,
       _save = save ?? AiInsightsCache.save,
       _clear = clear ?? AiInsightsCache.clear,
       _clock = clock ?? DateTime.now;

  /// The app-wide store.
  static AiInsightStore instance = AiInsightStore();

  /// Purpose: Replace the app-wide store.
  /// Inputs: `store`.
  /// Returns: None.
  /// Side effects: Swaps [instance].
  /// Notes: Tests only.
  @visibleForTesting
  static void setInstanceForTest(AiInsightStore store) => instance = store;

  final OnDeviceAiService? _aiOverride;
  final Future<AiInsights> Function() _load;
  final Future<void> Function(AiInsights insights) _save;
  final Future<void> Function() _clear;
  final DateTime Function() _clock;

  AiInsights? _cache;
  Future<AiInsights>? _loading;
  final _states = <InsightModule, AiInsightState>{};
  final _running = <InsightModule, String>{};
  final _pending = <InsightModule, (AiInsightRequest, bool)>{};
  final _latest = <InsightModule, String>{};

  /// Purpose: Resolve the model service.
  /// Inputs: None.
  /// Returns: The injected service, else the current singleton.
  /// Side effects: None.
  /// Notes: Read on every use so `OnDeviceAiService.setInstanceForTest`
  /// takes effect without rebuilding the store.
  OnDeviceAiService get _ai => _aiOverride ?? OnDeviceAiService.instance;

  /// Purpose: Read a card's state.
  /// Inputs: `module`.
  /// Returns: `AiInsightState`.
  /// Side effects: None.
  /// Notes: Idle until [ensure] runs for the module.
  AiInsightState stateOf(InsightModule module) =>
      _states[module] ?? const AiInsightState();

  /// Purpose: Load the cache once.
  /// Inputs: None.
  /// Returns: `Future<AiInsights>`.
  /// Side effects: Reads local storage on first call.
  /// Notes: Internal helper used within this file only.
  Future<AiInsights> _cached() {
    final c = _cache;
    if (c != null) return Future.value(c);
    return _loading ??= _load().catchError((Object _) => AiInsights()).then((value) {
      _cache ??= value;
      _loading = null;
      return _cache!;
    });
  }

  /// Purpose: Make a card current: show the cached entry when it matches,
  /// otherwise generate.
  /// Inputs: `request`; `force` — regenerate even when the cache matches
  /// (the card's refresh button).
  /// Returns: `Future<void>` — completes when this call's work is done.
  /// Side effects: May run the model, write `ai_insights.json`, notify.
  /// Notes: Does nothing but show cached text while the model cannot run.
  /// Page opens use background priority; a forced refresh is interactive.
  Future<void> ensure(AiInsightRequest request, {bool force = false}) async {
    final module = request.facts.module;
    final cache = await _cached();
    final fingerprint = insightFingerprint(
      request,
      modelIdentityOf(_ai.report),
    );
    final entry = cache.entries[module];
    if (!force && entry != null && entry.fingerprint == fingerprint) {
      _latest[module] = fingerprint;
      _pending.remove(module);
      _set(module, AiInsightState(phase: AiInsightPhase.ready, entry: entry));
      return;
    }
    if (!_ai.canGenerate) {
      _set(
        module,
        AiInsightState(entry: entry, stale: entry != null),
      );
      return;
    }
    if (!force && _latest[module] == fingerprint) {
      // Already running, queued, or failed for these exact facts; a failure
      // is retried only by the refresh button or a change in the facts.
      return;
    }
    _latest[module] = fingerprint;
    if (_running.containsKey(module)) {
      _pending[module] = (request, force);
      _set(
        module,
        AiInsightState(
          phase: AiInsightPhase.generating,
          entry: stateOf(module).entry ?? entry,
          stale: true,
        ),
      );
      return;
    }
    await _run(request, fingerprint, force);
  }

  /// Purpose: Generate one card and then any request that replaced it.
  /// Inputs: `request`, `fingerprint`, `force`.
  /// Returns: `Future<void>`.
  /// Side effects: Runs the model; writes the cache; notifies.
  /// Notes: Internal helper used within this file only. A result whose
  /// fingerprint is no longer the latest is discarded.
  Future<void> _run(
    AiInsightRequest request,
    String fingerprint,
    bool force,
  ) async {
    final module = request.facts.module;
    final cache = await _cached();
    final previous = cache.entries[module];
    _running[module] = fingerprint;
    _set(
      module,
      AiInsightState(
        phase: AiInsightPhase.generating,
        entry: previous,
        stale: previous != null,
      ),
    );
    final model = modelIdentityOf(_ai.report);
    AiInsightState next;
    try {
      final (facts, parsed) = await _answer(request, force);
      if (parsed.isEmpty) {
        next = AiInsightState(
          phase: AiInsightPhase.failed,
          entry: previous,
          failure: GenAiFailure.failed,
          stale: previous != null,
        );
      } else {
        final numbers = parsed.keys.toList()..sort();
        final entry = AiInsightEntry(
          fingerprint: fingerprint,
          lines: [
            for (final n in numbers) request.language.finish(parsed[n]!),
          ],
          slots: [for (final n in numbers) facts.slots[n - 1].id],
          status: AiInsightStatus.ok,
          generatedAt: _clock().toUtc(),
          model: model,
          language: request.language.localeTag,
          promptVersion: insightPromptVersion,
        );
        next = AiInsightState(phase: AiInsightPhase.ready, entry: entry);
        await _store(module, entry, fingerprint);
      }
    } on GenAiException catch (e) {
      if (e.failure == GenAiFailure.guardrail ||
          e.failure == GenAiFailure.unsupportedLanguage) {
        final entry = AiInsightEntry(
          fingerprint: fingerprint,
          lines: const [],
          status: AiInsightStatus.skipped,
          generatedAt: _clock().toUtc(),
          model: model,
          language: request.language.localeTag,
          promptVersion: insightPromptVersion,
        );
        next = AiInsightState(
          phase: AiInsightPhase.ready,
          entry: entry,
          failure: e.failure,
        );
        await _store(module, entry, fingerprint);
      } else {
        next = AiInsightState(
          phase: AiInsightPhase.failed,
          entry: previous,
          failure: e.failure,
          stale: previous != null,
        );
      }
    } catch (_) {
      next = AiInsightState(
        phase: AiInsightPhase.failed,
        entry: previous,
        failure: GenAiFailure.failed,
        stale: previous != null,
      );
    }
    _running.remove(module);
    final pending = _pending.remove(module);
    if (pending != null) {
      final (req, f) = pending;
      final fp = insightFingerprint(req, modelIdentityOf(_ai.report));
      _latest[module] = fp;
      final cached = (await _cached()).entries[module];
      if (!f && cached != null && cached.fingerprint == fp) {
        // The facts went back to what is already cached (a task ticked and
        // unticked again).
        _set(module, AiInsightState(phase: AiInsightPhase.ready, entry: cached));
        return;
      }
      if (_ai.canGenerate) {
        await _run(req, fp, f);
        return;
      }
      // Not run: forget it so the next page build asks again.
      _latest.remove(module);
      final shown = next.entry ?? previous;
      _set(module, AiInsightState(entry: shown, stale: shown != null));
      return;
    }
    if (_latest[module] == fingerprint) {
      _set(module, next);
      // A transient failure is retried on the next page build; a real one
      // only by the refresh button or new facts, so it cannot loop.
      if (next.phase == AiInsightPhase.failed &&
          const {
            GenAiFailure.busy,
            GenAiFailure.background,
            GenAiFailure.cancelled,
            GenAiFailure.unavailable,
          }.contains(next.failure)) {
        _latest.remove(module);
      }
    }
  }

  /// Purpose: Run the model once for one facts value and parse the reply.
  /// Inputs: `facts`, `language`, `force` — interactive priority when true.
  /// Returns: `Future<Map<int, String>>` — slot number to sentence; empty
  /// when nothing in the reply was usable.
  /// Side effects: Runs the model.
  /// Notes: Internal helper used within this file only. Throws
  /// `GenAiException` as the service does.
  Future<Map<int, String>> _generateParsed(
    InsightFacts facts,
    InsightLanguage language,
    bool force,
  ) async {
    final reply = await _ai.generate(
      instructions: insightInstructions(language),
      prompt: insightPrompt(facts),
      maxOutputTokens: insightMaxOutputTokens,
      priority: force ? AiPriority.interactive : AiPriority.background,
    );
    return parseInsightReply(
      reply,
      facts.slots.length,
      language.code,
      quotedTerms: facts.quotedTerms,
      asks: [for (final s in facts.slots) s.ask],
    );
  }

  /// Purpose: Answer a request, trying its fallback facts once if needed.
  /// Inputs: `request`, `force`.
  /// Returns: `Future<(InsightFacts, Map<int, String>)>` — the facts that
  /// were actually answered and the parsed reply, which may be empty.
  /// Side effects: Runs the model once or twice.
  /// Notes: Internal helper used within this file only. The fallback runs
  /// when the first reply is refused (guardrail) or parses to nothing, and
  /// only when the request carries one. A guardrail on the fallback itself
  /// propagates, so it is cached as skipped like any other refusal.
  Future<(InsightFacts, Map<int, String>)> _answer(
    AiInsightRequest request,
    bool force,
  ) async {
    final primary = request.facts;
    final fallback = request.fallbackFacts;
    try {
      final parsed = await _generateParsed(primary, request.language, force);
      if (parsed.isNotEmpty || fallback == null) return (primary, parsed);
    } on GenAiException catch (e) {
      if (e.failure != GenAiFailure.guardrail || fallback == null) rethrow;
    }
    return (fallback, await _generateParsed(fallback, request.language, force));
  }

  /// Purpose: Put an entry into the cache and persist it.
  /// Inputs: `module`, `entry`, `fingerprint`.
  /// Returns: `Future<void>`.
  /// Side effects: Writes `ai_insights.json`.
  /// Notes: Skipped when newer facts have arrived meanwhile. A failed write is
  /// ignored: the card still shows the text, it just regenerates next time.
  Future<void> _store(
    InsightModule module,
    AiInsightEntry entry,
    String fingerprint,
  ) async {
    if (_latest[module] != fingerprint) return;
    final cache = await _cached();
    cache.entries[module] = entry;
    try {
      await _save(cache);
    } catch (_) {}
  }

  /// Purpose: Forget every generated insight.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Deletes `ai_insights.json`; resets every card; notifies.
  /// Notes: Settings' "Clear generated insights". Cards regenerate the next
  /// time their page builds.
  Future<void> clearAll() async {
    _cache = AiInsights();
    _states.clear();
    _latest.clear();
    _pending.clear();
    try {
      await _clear();
    } catch (_) {}
    notifyListeners();
  }

  /// Purpose: Update one card's state and notify.
  /// Inputs: `module`, `state`.
  /// Returns: None.
  /// Side effects: Notifies listeners.
  /// Notes: Internal helper used within this file only.
  void _set(InsightModule module, AiInsightState state) {
    _states[module] = state;
    notifyListeners();
  }
}

/// A plain `Provider` over the singleton, like `onDeviceAiServiceProvider`,
/// so tests can override it; widgets listen to the store itself.
final aiInsightStoreProvider = Provider<AiInsightStore>(
  (ref) => AiInsightStore.instance,
);
