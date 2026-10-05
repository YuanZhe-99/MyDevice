# lib/features/ai/widgets/ai_insight_card.dart

Shared implementation now lives in MyApps-AI v0.4.1; this page describes the app adapter.

`AiInsightCard`, the on-device AI insight card placed on the
[Financial overview](../../devices/views/device_finance_overview_page.md) page and the
[Services Overview](../../services/views/service_list_page.md), plus `AiInsightSection` (a titled group of lines) and the `AiInsightRequestBuilder` callback
type. The card renders nothing unless the platform can have an on-device model and the user turned
on-device AI on; otherwise it builds its request from the page's already-loaded data, asks
[`AiInsightStore`](../services/insight_service.md) to make itself current, and renders the store's
state: a one-line notice when the model is not ready, a progress bar while generating, the lines
(dimmed while stale), a failure hint, and the "generated on this device" label with the time. It
also re-arms a timer to the next local midnight so a page left open updates when its fingerprint
changes by time alone. Facts and slots come from
[`insight_prompts.dart`](../services/insight_prompts.md), the cache entry shape from
[`ai_insights_cache.dart`](../services/ai_insights_cache.md), and the model status from
[`OnDeviceAiService`](../services/on_device_ai_service.md). See
[On-device AI — Insight cards](../../../../on-device-ai.md#insight-cards).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`AiInsightSection` (constructor)](#aiinsightsection-new) | const constructor (`AiInsightSection`) | A | Create a titled group of slot ids. |
| `AiInsightRequestBuilder` | top-level `typedef` (function type) | B | Callback that builds a card's request for a language and time, or null. |
| [`AiInsightCard` (constructor)](#aiinsightcard-new) | const constructor (`AiInsightCard`) | A | Create an insight card. |
| `createState` | method (`AiInsightCard`) | B | Create the state object. |
| `dispose` | method (`_AiInsightCardState`) | B | Cancel the boundary timer and remove the service listener. |
| [`_onServiceChanged`](#_onservicechanged) | method (`_AiInsightCardState`) | A | Rebuild when the model becomes usable. |
| [`_listenTo`](#_listento) | method (`_AiInsightCardState`) | A | Follow the right `OnDeviceAiService` instance. |
| [`_armBoundaryTimer`](#_armboundarytimer) | method (`_AiInsightCardState`) | A | Rebuild at the next moment the facts change by time alone. |
| [`_scheduleEnsure`](#_scheduleensure) | method (`_AiInsightCardState`) | A | Ask the store to make this card current after the frame. |
| `_statusLabel` | method (`_AiInsightCardState`) | B | Word a `GenAiStatus` with the Settings rows' strings. |
| [`build`](#build) | method (`_AiInsightCardState`) | A | Build the card, a one-line notice, or an empty box. |
| `_notice` | method (`_AiInsightCardState`) | B | Build the one-line notice card with an optional action. |
| [`_card`](#_card) | method (`_AiInsightCardState`) | A | Build the insight card proper. |

`grep -c 'Purpose:' lib/features/ai/widgets/ai_insight_card.dart` reports 12, matching the twelve
`Purpose:`-documented declarations above. Eight are Tier A: the two public constructors and every
method with real branching or lifecycle logic. `createState`, `dispose`, `_statusLabel` (a
one-to-one `switch`) and `_notice` (fixed layout) are Tier B widget boilerplate.

**Reconciliation:** 13 rows against 12 `Purpose:` blocks. The extra row is
`AiInsightRequestBuilder`, a real top-level `typedef` that carries a plain `///` description but no
`Purpose:` block. The classes `AiInsightSection`, `AiInsightCard` and `_AiInsightCardState` and the
fields are not rows, as on the other pages.

## Documentation

### `const AiInsightSection(this.title, this.slotIds)` <a id="aiinsightsection-new"></a>
- **Kind:** const constructor of `AiInsightSection`
- **Source:** `lib/features/ai/widgets/ai_insight_card.dart` (line 29)
- **Purpose:** Create a titled group of insight lines inside a card.
- **Inputs:** `title` — the section heading; `slotIds` — the slot ids whose lines belong here.
- **Returns:** A new `AiInsightSection`.
- **Side effects:** None.
- **Algorithm:** Plain field-initializing const constructor.
- **Usage:**
  ```dart
  AiInsightSection(l10n.aiFinanceRecurring, const {
    'recurringSummary',
  }),
  ```
  (`lib/features/devices/views/device_finance_overview_page.dart`, `build`; the same card groups
  `costSummary`/`costAdvice`/`reviewDevice` under `aiFinanceCosts`. The Services card passes no
  sections.)
- **Notes:** Lines whose slot is in no section are shown first, ungrouped. A section with no lines
  in the current entry is skipped, heading included.

### `const AiInsightCard({super.key, required this.module, required this.buildRequest, this.sections = const [], this.compact = false, this.footnote, this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8)})` <a id="aiinsightcard-new"></a>
- **Kind:** const constructor of `AiInsightCard` (a `ConsumerStatefulWidget`)
- **Source:** `lib/features/ai/widgets/ai_insight_card.dart` (line 72)
- **Purpose:** Create an insight card for one module.
- **Inputs:** `module` — which card (`InsightModule`); `buildRequest` — an
  `AiInsightRequestBuilder` that turns the page's loaded data into an `AiInsightRequest`, or null
  when there is nothing to talk about; `sections` — optional grouping of lines by slot id;
  `compact` — collapsible, collapsed by default to one preview line; `footnote` — optional muted
  note under the lines; `margin` — outer margin.
- **Returns:** A new `AiInsightCard`.
- **Side effects:** None.
- **Algorithm:** Plain field-initializing const constructor.
- **Usage:**
  ```dart
  AiInsightCard(
    module: InsightModule.services,
    margin: const EdgeInsets.only(top: 16),
    buildRequest: (language, now) {
      final facts = buildServiceInsightFacts(
        now: now,
        services: _services,
        routes: _routes,
        devices: _devices,
        networks: _networks,
      );
      return facts == null
          ? null
          : AiInsightRequest(facts: facts, language: language, now: now);
    },
  ),
  ```
  (`lib/features/services/views/service_list_page.dart`, `_buildOverview`.) The Financial overview
  passes `compact: !sideBySide`, two `sections` and a `fallbackFacts` request. No MyDevice caller
  passes `footnote`.
- **Notes:** Cheap to rebuild: `buildRequest` runs on every build, but the store fingerprints the
  request and compares it with the cache before anything runs.

### `void _onServiceChanged()` <a id="_onservicechanged"></a>
- **Kind:** private method of `_AiInsightCardState`
- **Source:** `lib/features/ai/widgets/ai_insight_card.dart` (line 116)
- **Purpose:** Rebuild the card when the model becomes usable after the page opened.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** May call `setState`; updates `_couldGenerate`.
- **Algorithm:** Read `canGenerate` from the listened service; call `setState` only on a
  `false` → `true` transition while mounted; store the new value.
- **Usage:** Registered as the `OnDeviceAiService` listener by `_listenTo`; removed in `dispose`.
- **Notes:** Covers the status probe finishing after the first build: the rebuild re-runs
  `buildRequest` and `_scheduleEnsure`, which the earlier build skipped because the store could not
  generate. Other service changes only repaint through the `ListenableBuilder` in `build`.

### `void _listenTo(OnDeviceAiService ai)` <a id="_listento"></a>
- **Kind:** private method of `_AiInsightCardState`
- **Source:** `lib/features/ai/widgets/ai_insight_card.dart` (line 127)
- **Purpose:** Keep the listener on the `OnDeviceAiService` instance the provider currently returns.
- **Inputs:** `ai` — the watched service.
- **Returns:** None.
- **Side effects:** Moves `_onServiceChanged` from the old instance to the new one; resets
  `_couldGenerate`.
- **Algorithm:** Return when `ai` is the instance already listened to; otherwise remove the
  listener from the old one, add it to `ai`, and seed `_couldGenerate` from `ai.canGenerate`.
- **Usage:** Called at the top of `build`, before the enabled/platform gate.
- **Notes:** Handles a provider override (tests) or a rebuilt provider. Listening costs nothing
  while AI is off: the service never calls the channel then.

### `void _armBoundaryTimer(DateTime now)` <a id="_armboundarytimer"></a>
- **Kind:** private method of `_AiInsightCardState`
- **Source:** `lib/features/ai/widgets/ai_insight_card.dart` (line 140)
- **Purpose:** Rebuild at the next moment the card's facts change by time alone.
- **Inputs:** `now` — the build time.
- **Returns:** None.
- **Side effects:** Cancels and re-arms the one-shot `_boundaryTimer`.
- **Algorithm:**
  1. Cancel any previous timer.
  2. Take the next local midnight.
  3. Arm a timer for it plus one second; on fire, `setState` while mounted.
- **Usage:** Called on every enabled `build`.
- **Notes:** The one-second slack makes sure the fingerprint's local date has moved on when the
  rebuild runs; service days and daily costs in the facts follow that date. MyDay also arms 12:00
  and 18:00 for its Todo card; MyDevice has no time-of-day card, so midnight is the only boundary.
  The timer is not cancelled when the switch is turned off; its later `setState` is harmless.

### `void _scheduleEnsure(AiInsightStore store)` <a id="_scheduleensure"></a>
- **Kind:** private method of `_AiInsightCardState`
- **Source:** `lib/features/ai/widgets/ai_insight_card.dart` (line 153)
- **Purpose:** Ask the store to make this card current after the frame.
- **Inputs:** `store` — the `AiInsightStore`.
- **Returns:** None.
- **Side effects:** Registers one post-frame callback that calls `store.ensure(request)`
  (unawaited).
- **Algorithm:** Return when a callback is already scheduled; otherwise set `_ensureScheduled` and
  add a post-frame callback that clears the flag, reads the latest `_request`, and calls
  `ensure` when mounted and the request is non-null.
- **Usage:** Called from `build` whenever a request was built.
- **Notes:** Several builds in one frame produce one `ensure` call with the last request. Running
  after the frame keeps store notifications out of the build phase. `ensure` without `force`
  answers from the cache when the fingerprint matches.

### `Widget build(BuildContext context)` <a id="build"></a>
- **Kind:** method of `_AiInsightCardState` (override)
- **Source:** `lib/features/ai/widgets/ai_insight_card.dart` (line 188)
- **Purpose:** Build the card, a one-line notice, or an empty box.
- **Inputs:** `context`.
- **Returns:** `Widget`.
- **Side effects:** Rebuilds `_request`; re-arms the boundary timer; schedules `ensure`.
- **Algorithm:**
  1. Watch `appSettingsProvider`, `onDeviceAiServiceProvider` and `aiInsightStoreProvider`;
     `_listenTo(ai)`.
  2. When `platformMayHaveOnDeviceModel` is false or `onDeviceAiEnabled` is off, clear `_request`
     and return `SizedBox.shrink()`.
  3. `_armBoundaryTimer(now)`; pick the language with `InsightLanguage.forLocale(locale,
     localeSupported: ai.coreInfo?.localeSupported)`; build `_request` with
     `widget.buildRequest(language, now)` unless the language is null; schedule `ensure` when a
     request exists.
  4. Return a `ListenableBuilder` over the service and the store that shows: nothing for status
     `unsupported`; a notice with the status label and a *Settings* button (`context.go('/settings')`)
     for any other non-`available` status; the "language unsupported" notice when the language is
     null; nothing when the request is null; otherwise `_card`.
- **Usage:** Flutter framework; runs when the page rebuilds (its data changed), when settings or the
  locale change, at a time boundary, and when the model becomes usable.
- **Notes:** The not-ready notice is shown even when `buildRequest` would return null (for example
  the Services Overview with no services), because the status check comes before the request check.

### `Widget _card(BuildContext context, AppLocalizations l10n, AiInsightStore store, AiInsightRequest request)` <a id="_card"></a>
- **Kind:** private method of `_AiInsightCardState`
- **Source:** `lib/features/ai/widgets/ai_insight_card.dart` (line 271)
- **Purpose:** Build the insight card proper from the store's state for this module.
- **Inputs:** `context`, `l10n`, `store`, `request`.
- **Returns:** `Widget` — a `Card`.
- **Side effects:** None while building; the refresh button calls
  `store.ensure(request, force: true)` and, when `compact`, tapping the header toggles `_expanded`.
- **Algorithm:**
  1. Read `store.stateOf(module)`; `generating` = phase `generating`; `dim` = generating or stale.
  2. Header: icon and title (no subtitle; MyDay's Todo time-of-day subtitle was not ported); a
     refresh button disabled while generating; an expand arrow when `compact`.
  3. Body: a *skipped* entry shows the skipped message. An entry with lines pairs line *i* with
     slot *i* (`''` when missing), dims them at 60 % alpha when `dim`, and shows either the first
     line on one ellipsized row (compact and collapsed) or the unsectioned lines as bullets
     followed by each non-empty section's heading and bullets. With no entry and no failure it
     shows `aiGenerating` ("Thinking…").
  4. When the phase is `failed`: the quota hint, the foreground hint, or the generic failure text.
  5. When details are shown (not compact, or expanded): the footnote if there is an entry, and for
     an `ok` entry the label "Generated on this device — may be wrong" with the local generation
     time.
  6. A 2-pixel slot holds a `LinearProgressIndicator` while generating, so the layout does not jump.
- **Usage:** Called only from `build`'s `ListenableBuilder` when the model is available and a request
  exists.
- **Notes:** Older lines stay visible (dimmed) while newer ones are generated. The collapsed
  preview takes the first line whatever its section.
