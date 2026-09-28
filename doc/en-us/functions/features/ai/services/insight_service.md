# lib/features/ai/services/insight_service.dart

`AiInsightStore`, the owner of the insight cards: it computes each request's fingerprint, shows the
cached entry when the fingerprint matches, otherwise runs the on-device model through
[`OnDeviceAiService`](on_device_ai_service.md), parses and stores the reply in
[`ai_insights.json`](ai_insights_cache.md), and tells the card
([`ai_insight_card.md`](../widgets/ai_insight_card.md)) what to show. At most one generation per
module runs or waits: a request that arrives meanwhile replaces the pending one, and a result whose
fingerprint is no longer the latest is discarded. A request may carry plainer `fallbackFacts`
(from MyDay v1.5.1), which the store sends once when the model declines the primary facts or
returns nothing parseable for them. Prompts and parsing come from
[`insight_prompts.md`](insight_prompts.md); failure codes and the status report from
[`genai_backend.md`](genai_backend.md). See
[On-device AI — Cache and fingerprint](../../../../on-device-ai.md#cache-and-fingerprint).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AiInsightPhase` (enum) | enum | B | `idle` / `generating` / `ready` / `failed`: where a card is in its life cycle. |
| [`AiInsightState` (constructor)](#aiinsightstate-new) | const constructor (`AiInsightState`) | A | Create what a card shows. |
| [`AiInsightRequest` (constructor)](#aiinsightrequest-new) | const constructor (`AiInsightRequest`) | A | Create one card's request: facts, language, time, optional fallback facts. |
| [`modelIdentityOf`](#modelidentityof) | top-level function | A | Name the model a status report describes. |
| [`insightFingerprint`](#insightfingerprint) | top-level function | A | Fingerprint one card request (hex SHA-256). |
| [`AiInsightStore` (constructor)](#aiinsightstore-new) | constructor (`AiInsightStore`) | A | Create the store with injectable service, cache I/O and clock. |
| `setInstanceForTest` | static method (`AiInsightStore`) | B | Replace the app-wide `instance`; tests only. |
| `_ai` | private getter (`AiInsightStore`) | B | The injected service, else the current `OnDeviceAiService.instance`. |
| [`stateOf`](#stateof) | method (`AiInsightStore`) | A | Read a card's state. |
| [`_cached`](#_cached) | private method (`AiInsightStore`) | A | Load the cache once and share it. |
| [`ensure`](#ensure) | method (`AiInsightStore`) | A | Make a card current: cached entry or a generation. |
| [`_run`](#_run) | private method (`AiInsightStore`) | A | Generate one card, then any request that replaced it. |
| [`_generateParsed`](#_generateparsed) | private method (`AiInsightStore`) | A | Run the model once for one facts value and parse the reply. |
| [`_answer`](#_answer) | private method (`AiInsightStore`) | A | Answer a request, trying its fallback facts once if needed. |
| [`_store`](#_store) | private method (`AiInsightStore`) | A | Put an entry into the cache and persist it. |
| [`clearAll`](#clearall) | method (`AiInsightStore`) | A | Forget every generated insight. |
| `_set` | private method (`AiInsightStore`) | B | Update one card's state and notify listeners. |
| `aiInsightStoreProvider` | top-level variable (`Provider`) | B | A plain `Provider` over `AiInsightStore.instance`, overridable in tests. |

`grep -c 'Purpose:' lib/features/ai/services/insight_service.dart` reports 16, matching the
sixteen rows above other than `AiInsightPhase` and `aiInsightStoreProvider`.

**Reconciliation:** the table has 18 rows against 16 `Purpose:` blocks. The two extra rows are
real top-level declarations with only a plain doc comment: the `AiInsightPhase` enum and the
`aiInsightStoreProvider` provider. The static field `AiInsightStore.instance`, the private state
maps (`_states`, `_running`, `_pending`, `_latest`) and the value-class fields are not rows.

## Documentation

### `const AiInsightState({this.phase = AiInsightPhase.idle, this.entry, this.failure, this.stale = false})` <a id="aiinsightstate-new"></a>
- **Kind:** const constructor of `AiInsightState` (`@immutable`)
- **Source:** `lib/features/ai/services/insight_service.dart` (line 49)
- **Purpose:** Create the value a card renders.
- **Inputs:** `phase` (default `idle`); `entry` — the entry to show; `failure` — why the last
  attempt failed, or for a `ready` skipped entry why it was skipped; `stale` — whether `entry`
  belongs to older facts (default `false`).
- **Returns:** A new `AiInsightState`.
- **Side effects:** None.
- **Algorithm:** Plain field-initializing const constructor.
- **Usage:** `_set(module, AiInsightState(phase: AiInsightPhase.ready, entry: entry));`
  (`ensure`, same file); `const AiInsightState()` is the default of [`stateOf`](#stateof).
- **Notes:** None.

### `const AiInsightRequest({required this.facts, required this.language, required this.now, this.fallbackFacts})` <a id="aiinsightrequest-new"></a>
- **Kind:** const constructor of `AiInsightRequest`
- **Source:** `lib/features/ai/services/insight_service.dart` (line 79)
- **Purpose:** Create one card's request.
- **Inputs:** `facts` — from a `*_insight_facts.dart` builder; `language` — the reply language;
  `now` — local time the facts were computed for; `fallbackFacts` — a plainer second try, or null:
  sent once by [`_answer`](#_answer) when the model declines `facts` with `guardrail` or
  returns nothing parseable for them.
- **Returns:** A new `AiInsightRequest`.
- **Side effects:** None.
- **Algorithm:** Plain field-initializing const constructor.
- **Usage:**
  ```dart
  AiInsightRequest(
    facts: full,
    language: language,
    now: now,
    fallbackFacts: facts(names: false),
  )
  ```
  (`lib/features/devices/views/device_finance_overview_page.dart`, the finance card's
  `buildRequest`, where `facts(names: …)` wraps `buildDeviceFinanceInsightFacts(..., includeNames:
  names)`; the Services Overview in `lib/features/services/views/service_list_page.dart` passes
  `facts`, `language` and `now` only, with no fallback.)
- **Notes:** Only the date of `now` enters the fingerprint. `fallbackFacts` is not part of the
  fingerprint at all, and must carry the same module and the same slot ids in the same order as
  `facts`, so the card's sections still apply to whichever facts were answered.

### `String modelIdentityOf(GenAiStatusReport report)` <a id="modelidentityof"></a>
- **Kind:** top-level function
- **Source:** `lib/features/ai/services/insight_service.dart` (line 92)
- **Purpose:** Name the model a status report describes.
- **Inputs:** `report` — the service's current status report.
- **Returns:** `String` — the non-null `variant` and `baseModelName` joined with `' · '` (e.g.
  `stable/full · nano-v3`), or `apple` when both are null.
- **Side effects:** None.
- **Algorithm:** Build `[?report.variant, ?report.baseModelName]` with null-aware elements; join,
  or return `apple` when empty.
- **Usage:** `modelIdentityOf(_ai.report)` in [`ensure`](#ensure) and [`_run`](#_run).
- **Notes:** Same rule as MyAnime!!!!!. Because the identity is fingerprinted, a model update
  regenerates every card; on Apple platforms the identity is constant.

### `String insightFingerprint(AiInsightRequest request, String model)` <a id="insightfingerprint"></a>
- **Kind:** top-level function
- **Source:** `lib/features/ai/services/insight_service.dart` (line 104)
- **Purpose:** Fingerprint one card request.
- **Inputs:** `request`; `model` — from [`modelIdentityOf`](#modelidentityof).
- **Returns:** `String` — lowercase hex SHA-256.
- **Side effects:** None.
- **Algorithm:** Join with `\n`: the module name, `prompt:<insightPromptVersion>`,
  `language:<localeTag>`, `date:<factDate(now)>`, `model:<model>`, and
  `request.facts.canonical()`; hash the UTF-8 bytes with `sha256`.
- **Usage:** `final fingerprint = insightFingerprint(request, modelIdentityOf(_ai.report));`
  ([`ensure`](#ensure)); also for a pending request in [`_run`](#_run).
- **Notes:** Covers the module, prompt version, language, local date, model and facts. A change to any of them regenerates the card; nothing else
  does.

### `AiInsightStore({OnDeviceAiService? ai, Future<AiInsights> Function()? load, Future<void> Function(AiInsights insights)? save, Future<void> Function()? clear, DateTime Function()? clock})` <a id="aiinsightstore-new"></a>
- **Kind:** constructor of `AiInsightStore` (extends `ChangeNotifier`)
- **Source:** `lib/features/ai/services/insight_service.dart` (line 129)
- **Purpose:** Create the store.
- **Inputs:** `ai` — the model service (default: `OnDeviceAiService.instance`, resolved on every
  use); `load` / `save` / `clear` — cache I/O (default: `AiInsightsCache.load` / `.save` /
  `.clear`); `clock` — clock for `generatedAt` (default `DateTime.now`, converted to UTC at use).
- **Returns:** A new `AiInsightStore`.
- **Side effects:** None until first use; the cache is loaded lazily.
- **Algorithm:** Store each override or its default in a final field.
- **Usage:** `static AiInsightStore instance = AiInsightStore();` (same file);
  `test/insight_service_test.dart` passes an `OnDeviceAiService` over a fake backend, in-memory
  cache I/O and a fixed UTC clock.
- **Notes:** Leaving `ai` null (rather than capturing the singleton) lets
  `OnDeviceAiService.setInstanceForTest` take effect without rebuilding the store.

### `AiInsightState stateOf(InsightModule module)` <a id="stateof"></a>
- **Kind:** method of `AiInsightStore`
- **Source:** `lib/features/ai/services/insight_service.dart` (line 178)
- **Purpose:** Read a card's current state.
- **Inputs:** `module`.
- **Returns:** The stored `AiInsightState`, or `const AiInsightState()` (idle, no entry).
- **Side effects:** None.
- **Algorithm:** Map lookup with a default.
- **Usage:** `final state = store.stateOf(widget.module);`
  (`lib/features/ai/widgets/ai_insight_card.dart`, the card body builder).
- **Notes:** Idle until [`ensure`](#ensure) has run for the module, and again after
  [`clearAll`](#clearall).

### `Future<AiInsights> _cached()` <a id="_cached"></a>
- **Kind:** private method of `AiInsightStore`
- **Source:** `lib/features/ai/services/insight_service.dart` (line 186)
- **Purpose:** Load the cache once and share it.
- **Inputs:** None.
- **Returns:** `Future<AiInsights>` — the in-memory cache.
- **Side effects:** Calls the injected `load` on first use.
- **Algorithm:** Return `_cache` when set. Otherwise start (or reuse)
  `_loading = _load().catchError(=> AiInsights()).then(...)`, which sets `_cache ??= value`, clears
  `_loading` and returns `_cache`.
- **Usage:** First line of [`ensure`](#ensure), [`_run`](#_run) and [`_store`](#_store).
- **Notes:** Concurrent first calls share one load. `_cache ??=` keeps an empty cache that
  [`clearAll`](#clearall) installed while the load was in flight. If the injected `load` throws, the
  cache starts empty instead of failing every later call; the default
  `AiInsightsCache.load` never throws.

### `Future<void> ensure(AiInsightRequest request, {bool force = false})` <a id="ensure"></a>
- **Kind:** method of `AiInsightStore`
- **Source:** `lib/features/ai/services/insight_service.dart` (line 204)
- **Purpose:** Make a card current: show the cached entry when it matches, otherwise generate.
- **Inputs:** `request`; `force` — regenerate even when the cache matches (the card's refresh
  button).
- **Returns:** `Future<void>` — completes when this call's work is done (including a generation it
  started, but not one it only queued).
- **Side effects:** May run the model, write `ai_insights.json`, and notify listeners.
- **Algorithm:**
  1. Load the cache; compute the fingerprint with the current model identity.
  2. Not forced and the cached entry's fingerprint matches → record it as latest, drop any pending
     request, set `ready` with that entry, return.
  3. `!_ai.canGenerate` → set `idle` with the cached entry (marked `stale` when there is one),
     return.
  4. Not forced and `_latest` already equals this fingerprint → return (already running, queued or
     failed for these exact facts).
  5. Record the fingerprint as latest. If a generation for the module is running, store
     `(request, force)` as the pending request (replacing any earlier one), set `generating` with
     the shown entry marked stale, return.
  6. Otherwise `await _run(request, fingerprint, force)`.
- **Usage:** `unawaited(store.ensure(request));` (post-frame, on every card build) and
  `unawaited(store.ensure(request, force: true))` (the refresh button), both in
  `lib/features/ai/widgets/ai_insight_card.dart`.
- **Notes:** While the model cannot run, only cached text is shown. A forced refresh runs at
  `AiPriority.interactive`; page opens run at `background`. A cached `skipped` entry counts as a
  match, so a refusal is not retried until the facts change or the user refreshes.

### `Future<void> _run(AiInsightRequest request, String fingerprint, bool force)` <a id="_run"></a>
- **Kind:** private method of `AiInsightStore`
- **Source:** `lib/features/ai/services/insight_service.dart` (line 252)
- **Purpose:** Generate one card, then any request that replaced it meanwhile.
- **Inputs:** `request`; `fingerprint` — already computed by the caller; `force` — selects the
  priority.
- **Returns:** `Future<void>`.
- **Side effects:** Runs the model (once or twice); may write the cache; notifies listeners.
- **Algorithm:**
  1. Mark the module running; set `generating` with the previously cached entry (stale when
     present).
  2. `final (facts, parsed) = await _answer(request, force)` ([`_answer`](#_answer)): the model
     runs for the primary facts and, when it declines them or returns nothing parseable and the
     request has `fallbackFacts`, once more for those; `facts` is whichever value was answered.
  3. `parsed` empty → `failed` with `GenAiFailure.failed` (not cached). Otherwise build an `ok`
     entry: lines in slot-number order passed through `language.finish`, the matching slot ids
     taken from `facts.slots[n - 1].id`, UTC `generatedAt`, model, language tag and prompt version;
     state `ready`; [`_store`](#_store) it.
  4. `GenAiException` with `guardrail` or `unsupportedLanguage` → build a `skipped` entry (no
     lines), state `ready` carrying the failure, and store it. Any other `GenAiException` →
     `failed` with its failure. Any other exception → `failed` with `GenAiFailure.failed`.
  5. Clear the running mark. If a pending request exists: recompute its fingerprint, make it
     latest; if not forced and the cache already matches it, set `ready` with that entry; else if
     the model can run, recurse into `_run` with it; else forget the latest fingerprint and set
     `idle` with the best entry available (stale).
  6. No pending request: only if this fingerprint is still the latest, publish the new state; and
     if it is a `failed` state with `busy`, `background`, `cancelled` or `unavailable`, forget the
     latest fingerprint so the next page build retries.
- **Usage:** Called only from [`ensure`](#ensure) and recursively from itself.
- **Notes:** A result whose fingerprint is no longer the latest is neither stored nor shown. A
  `failed`, `timeout`, `tooLong`, `quota` or unparseable result keeps its fingerprint as latest,
  so it is retried only by the refresh button or new facts and cannot loop. When a pending request
  replaces the run, the run's own state is never published. The entry is fingerprinted and cached
  under the primary facts even when the fallback facts were the ones answered.

### `Future<Map<int, String>> _generateParsed(InsightFacts facts, InsightLanguage language, bool force)` <a id="_generateparsed"></a>
- **Kind:** private method of `AiInsightStore`
- **Source:** `lib/features/ai/services/insight_service.dart` (line 377)
- **Purpose:** Run the model once for one facts value and parse the reply.
- **Inputs:** `facts`; `language`; `force` — interactive priority when true, background otherwise.
- **Returns:** `Future<Map<int, String>>` — slot number to sentence, from
  [`parseInsightReply`](insight_prompts.md#parseinsightreply); empty when nothing in the reply was
  usable.
- **Side effects:** Runs the model.
- **Algorithm:** `_ai.generate(instructions: insightInstructions(language), prompt:
  insightPrompt(facts), maxOutputTokens: insightMaxOutputTokens, priority:
  interactive|background)`, then `parseInsightReply(reply, facts.slots.length, language.code,
  quotedTerms: facts.quotedTerms, asks: [for (final s in facts.slots) s.ask])`.
- **Usage:** Called once or twice per generation by [`_answer`](#_answer).
- **Notes:** Split out of [`_run`](#_run) (in MyDay v1.5.1) so it can run for either facts
  value. Throws `GenAiException` as the service does; nothing is caught here.

### `Future<(InsightFacts, Map<int, String>)> _answer(AiInsightRequest request, bool force)` <a id="_answer"></a>
- **Kind:** private method of `AiInsightStore`
- **Source:** `lib/features/ai/services/insight_service.dart` (line 406)
- **Purpose:** Answer a request, trying its fallback facts once if needed.
- **Inputs:** `request`; `force` — passed through to [`_generateParsed`](#_generateparsed).
- **Returns:** `Future<(InsightFacts, Map<int, String>)>` — the facts that were actually answered
  and the parsed reply, which may be empty.
- **Side effects:** Runs the model once or twice.
- **Algorithm:**
  1. `_generateParsed(request.facts, ...)`. If the result is non-empty, or the request has no
     `fallbackFacts`, return `(request.facts, parsed)`.
  2. If that call threw a `GenAiException`, rethrow it unless its failure is `guardrail` and a
     fallback exists.
  3. Otherwise (empty parse or guardrail, and a fallback exists) return
     `(fallback, await _generateParsed(fallback, ...))`.
- **Usage:** `final (facts, parsed) = await _answer(request, force);` in [`_run`](#_run).
- **Notes:** Added in MyDay v1.5.1 for its Todo card, whose titled facts the on-device model
  declined or answered with nothing usable. In MyDevice only the finance card passes a fallback: the
  same facts with categories in place of device names. The fallback is tried at most once, and
  only for a `guardrail` refusal or an empty parse — `unsupportedLanguage`, `busy`, `timeout` and
  the rest propagate unchanged. A guardrail from the fallback itself propagates too, so `_run`
  caches it as `skipped` like any other refusal.

### `Future<void> _store(InsightModule module, AiInsightEntry entry, String fingerprint)` <a id="_store"></a>
- **Kind:** private method of `AiInsightStore`
- **Source:** `lib/features/ai/services/insight_service.dart` (line 427)
- **Purpose:** Put an entry into the cache and persist it.
- **Inputs:** `module`, `entry`, `fingerprint`.
- **Returns:** `Future<void>`.
- **Side effects:** Mutates the in-memory cache; writes `ai_insights.json` through the injected
  `save`.
- **Algorithm:** Return when `_latest[module] != fingerprint`; otherwise set
  `cache.entries[module] = entry` and `await _save(cache)`, swallowing any error.
- **Usage:** `await _store(module, entry, fingerprint);` in [`_run`](#_run) for `ok` and `skipped`
  entries.
- **Notes:** Skipped when newer facts have arrived meanwhile. A failed write is ignored: the card
  still shows the text and simply regenerates next time the app starts.

### `Future<void> clearAll()` <a id="clearall"></a>
- **Kind:** method of `AiInsightStore`
- **Source:** `lib/features/ai/services/insight_service.dart` (line 446)
- **Purpose:** Forget every generated insight.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Replaces the in-memory cache with an empty one; clears every card state, the
  latest fingerprints and the pending requests; deletes `ai_insights.json` through the injected
  `clear` (errors swallowed); notifies listeners.
- **Algorithm:** Reset the fields, `await _clear()` in a `try`, `notifyListeners()`.
- **Usage:** `await ref.read(aiInsightStoreProvider).clearAll();`
  (`lib/features/ai/widgets/ai_settings_tiles.dart`, *Clear generated insights*).
- **Notes:** `_running` is not cleared: a generation in flight finishes, but because its
  fingerprint is no longer the latest its result is neither stored nor shown. Cards regenerate the
  next time their page builds.
