# On-device AI

Dart execution and output utilities now use MyApps-AI v0.1.0 through thin app
adapters. Native channels now use MyApps-AI v0.2.0's shared plugin; business prompts
remain here. See [shared-ai.md](shared-ai.md).

Since 1.6.0, MyDevice!!!!! can use the device's own language model — Gemini Nano through Android
AICore, or Apple Intelligence's model through the Foundation Models framework — to write a short
**insight card** in two places: the cost picture and a suggestion on the **Financial Overview** page,
and a summary and suggestions about the self-hosting setup on the **Services** Overview. This page
holds the rules, how the code is laid out, what each card is given, how results are cached, and what
still has to be checked on a device.

The model layer is a port of MyDay!!!!!'s (1.5.x), which is itself a port of MyAnime!!!!!'s and
MyNihongo!!!!!'s; the two insight cards and their fact builders are MyDevice's own.

> **Last verified:** 2026-09-28, against MyDay's port and the published libraries.
> **Not verified on a device.** Neither an Android device with AICore nor an Apple device with
> Apple Intelligence has run this code in MyDevice; the [device checklist](#device-checklist) is
> what to do when one is available. The prompts were checked only against a cloud stand-in (see
> [Prompt check](#prompt-check)).

## Policy

Rules 1–3, 7 and 8 are enforced in `OnDeviceAiService` and covered by
`test/on_device_ai_test.dart` and `test/ai_settings_tiles_ui_test.dart`. Rules 4–6 and 9 are
enforced by the insight layer and covered by `test/insight_service_test.dart`,
`test/insight_facts_test.dart`, `test/ai_insights_cache_test.dart` and
`test/ai_insight_card_ui_test.dart`.

1. **Off by default.** `onDeviceAiEnabled` is absent from `storage_config.json` until the user turns
   the switch on.
2. **The switch is a gate.** While it is off, the method channel is never called, not even for
   status, and every card renders nothing.
3. **Status is re-checked before every request.** The system can remove a model between two
   requests.
4. **Generated output is labelled** "Generated on this device — may be wrong".
5. **The page comes first.** A card only adds text under data the page already shows; when the
   model fails, the page is unchanged.
6. **Nothing generated is synced or backed up.** Results live in `ai_insights.json`, which is not
   registered in `lib/app/data_modules.dart`.
7. **Nothing is downloaded on the user's behalf.** On Android the model download starts only from
   the Download button in Settings and is performed by AICore; on Apple platforms the system
   manages the model.
8. **On-device only.** Never Apple's Private Cloud Compute and never any other remote model.
9. **Only computed facts reach the model.** Cards are built from aggregates the app computes; see
   [what each card is given](#what-each-card-is-given). Serial numbers, notes, locations, host
   names, addresses and URLs never reach the model.

Both builds (`FLAVOR=full` and `store`) ship the feature: it makes no network call of its own. On
Windows and Linux the cards are never built, and the Settings section is a single "not available on
this platform" line.

## Layout

| Path | Role |
|---|---|
| `lib/features/ai/services/genai_backend.dart` | The Dart seam: `GenAiStatus`, `GenAiFailure`, `GenAiStatusReport`, `GenAiCoreInfo`, the `GenAiBackend` interface and `MethodChannelGenAiBackend` |
| `lib/features/ai/services/on_device_ai_service.dart` | `OnDeviceAiService`: the switch, status before every use, the single-flight priority queue, the 45-second timeout, lifecycle, busy backoff and the daily quota stop |
| `lib/features/ai/services/output_validation.dart` | Stripping Markdown, the script check, cleaning one sentence, parsing a choice reply |
| `lib/features/ai/services/insight_language.dart` | `InsightLanguage`: the request language for the UI locale, and Chinese variant conversion |
| `lib/features/ai/services/insight_prompts.dart` | `InsightModule`, `InsightFacts`, the versioned instructions and prompt, and the reply parser |
| `lib/features/ai/services/ai_insights_cache.dart` | `AiInsightsCache`: `ai_insights.json`, the per-device cache |
| `lib/features/ai/services/insight_service.dart` | `AiInsightStore`: the fingerprint, cache-or-generate, coalescing, failure handling |
| `lib/features/ai/widgets/ai_insight_card.dart` | `AiInsightCard`: the card and all its states |
| `lib/features/ai/widgets/ai_settings_tiles.dart` | `AiSettingsTiles`: the switch, the status row, the size preference, the notes, technical details (complete and copyable since 1.11.0) and *Clear generated insights* |
| `lib/features/devices/services/finance_insight_facts.dart` | Device finance facts |
| `lib/features/services/services/service_insight_facts.dart` | Services facts |
| `lib/shared/utils/chinese_convert.dart` | Simplified ↔ Traditional conversion, copied from MyDay |
| `packages/myapps_ai/packages/myapps_ai_platform/android/src/main/kotlin/com/yuanzhe/myapps_ai/GenAiChannel.kt` | The Android bridge to ML Kit GenAI |
| `packages/myapps_ai/packages/myapps_ai_platform/` | A local Flutter plugin with one shared Darwin source for iOS and macOS |

The Settings section *On-device AI* sits between *Data* and *Desktop*. The switches are stored as
`onDeviceAiEnabled` and `onDeviceAiPreferFast` in `storage_config.json` (see
[`data-formats.md`](data-formats.md#storage_configjson)), through `DeviceStorage`;
`AppSettingsNotifier` pushes both into `OnDeviceAiService` at startup, and `main()` starts the
service's lifecycle listener.

The channel is `com.yuanzhe.myapps_ai/genai` on all three platforms. Its methods are `status`
(`force`, `preferFast`), `info` (`locale`), `download` (Android only), `generate` (`instructions`,
`prompt`, `maxOutputTokens`, `temperature`, `topK`), `choose` (Apple only; unused by MyDevice but
kept so the plugin matches MyDay's), `prewarm` and `cancel`. `platformMayHaveOnDeviceModel` is true
on Android, iOS and macOS; on every other platform the backend answers `unsupported` without
touching the channel. A `MissingPluginException` on iOS or macOS is reported as `unreachable` with
the detail "channel not registered", never as `unsupported`, so a plugin that failed to register is
noticed.

### Statuses and failures

| Status | Meaning |
|---|---|
| `unsupported` | This platform has no on-device model (Windows, Linux, iOS or macOS before 26) |
| `unavailable` | The system was asked and said no |
| `unreachable` | The system could not be asked at all |
| `notEnabled` | Apple Intelligence is off in system settings |
| `downloadable` | Android: the model can be fetched by AICore |
| `downloading` | The model is being fetched or prepared (Apple's `modelNotReady` too) |
| `available` | Ready |
| `unknown` | A status this build has no name for |

Failures are `unavailable`, `busy`, `failed`, `cancelled`, `tooLong`, `timeout`, `background`,
`quota`, `guardrail` and `unsupportedLanguage`.

### The queue

One request runs at a time. A card generated because its page opened is a **background** request;
the card's refresh button is **interactive** and goes first. Nothing runs unless the app is
`AppLifecycleState.resumed`. After `busy`, background work waits 5 seconds, doubling up to 5
minutes; after `quota`, background work stops for the rest of the day; after `background`, the
queue waits for the next resume.

## Insight cards

Each card is an `AiInsightCard` placed on its page. It renders nothing — including its margin —
while the switch is off or on a platform without a model, so every existing layout is unchanged
then. While the model is not ready (needs a download, Apple Intelligence off, …) it is a one-line
notice with a *Settings* button. Otherwise it shows a header with a refresh button, a thin progress
bar while generating, the lines (older lines dimmed while newer ones are generated), and the label
and time.

| Page | Where | Slots |
|---|---|---|
| Financial Overview | After the daily-cost trend card. Collapsed to one preview line in the stacked layout; full when the summary and the distribution chart sit side by side. | `costSummary`, `costAdvice`, `reviewDevice` under *Costs*; `recurringSummary` under *Recurring Costs*. |
| Services (Overview) | After the warnings card, before *Access paths*. Only when there is at least one service. | `setupSummary`, `warningAdvice`, `exposureAdvice`. |

### What each card is given

Facts are English `- key: value` lines computed by a pure builder, rounded so that a fingerprint
does not change with float noise. The model is asked to answer each numbered question with one
sentence under 30 words in the UI language, using only the facts, writing amounts with the currency
code exactly as given, with no medical, legal or investment advice and no invented numbers. The
prompt is `Facts:`, the lines, `Questions:`, the numbered questions, and then the exact reply
template (`1: <sentence>` …), because a small model keeps to a shape it has just seen far better
than to one described in prose.

The reply parser (`parseInsightReply`) accepts `<number>: <sentence>` with `:`, `：`, `.`, `)` or
`、` as the separator, a number alone on a line followed by its sentence, and — only when nothing
at all is numbered — the first prose lines in order. It drops a line that merely echoes a question,
a line over 200 characters, and a line in the wrong script. Bold and code marks are removed; list
markers are kept.

| Card | Sent | Never sent |
|---|---|---|
| Financial Overview | The date and default currency; device counts by status and how many have cost data; total cost of ownership and total daily cost; cost by category (top 5, positive totals only, as the distribution chart); the three in-service devices with the highest daily cost and the three oldest in service, by name (trimmed to 30 characters) and category; recurring costs on in-service devices — entry and device counts, counts by kind, monthly-billed per month, yearly-billed per year, and the annual total; retired and sold counts and the resale total. If the model declines these or answers nothing usable, a second try sends the same facts naming categories only (`fallbackFacts`). | Serial numbers, notes, location names and coordinates, brand and model, storage serial numbers, recurring cost names |
| Services | The date; service counts by state, kind and runtime (top 5 each); how many devices host services and how many of those are retired or sold; endpoint counts by protocol and scope; the number of distinct listening ports and of definite and potential port conflicts; access paths by access level and hop method, and the average hop count; how many networks endpoints reference; warnings by kind; repeated service names on one device and access paths sharing a final URL | Service, access-path, endpoint and hop names or labels; bind addresses, host names, paths and URLs; port numbers; tags, notes and Compose files |

A `guardrail` refusal is cached as *skipped* so it is not retried until the facts change.

### Language

`InsightLanguage.forLocale` picks the request language from the UI locale: Simplified Chinese
(converted to Simplified), Traditional Chinese (converted to Traditional), Japanese, or English.
When Apple's `supportsLocale` rejects Traditional Chinese, Simplified is requested and converted;
when it rejects any other UI language, the card says the model cannot write in it. A reply line is
kept only when its script matches the UI language (at least 60 % CJK for Chinese and Japanese,
Latin otherwise). Words that may legitimately stay in Latin letters are listed as *quoted terms* and
removed before that check: device names and the currency code on the finance card, and a fixed list
of product and protocol names (`serviceInsightTechTerms` — Caddy, Tailscale Funnel, Docker, LAN,
URL, …) on the services card.

### Prompt check

No device here can run the on-device models, so for 1.6.0 the exact instructions and prompts built
from realistic fixture data (both cards, the finance fallback, in English, Simplified Chinese and
Japanese) were answered by Claude Haiku 4.5 standing in for the model, and every reply was run
through the real `parseInsightReply`. Two changes came out of it:

- The Japanese answers turned `CNY` into `円`. The instructions now require amounts to keep the
  currency code as given.
- Once they did, short Chinese and Japanese sentences with three amounts — or naming Caddy and
  Tailscale Funnel — fell below the 60 % CJK threshold and were dropped. The currency code and the
  tech names became quoted terms.

After that, 52 of 52 answer slots across both rounds were kept. A cloud model is far larger than
Gemini Nano or Apple's on-device model, so this checks the prompt shape and the parser, not the
quality of on-device answers; the facts are capped (top 3 or 5 per line) to stay well inside the
smaller models' input budget.

## Cache and fingerprint

Results are cached in `ai_insights.json` in the app data folder (see
[`data-formats.md`](data-formats.md#ai_insightsjson)). A card is regenerated **only** when its
fingerprint changes. The fingerprint is the SHA-256 of:

- the module,
- `insightPromptVersion` (bump it whenever prompt wording or a builder's output changes),
- the request language tag,
- the local date (so every card is refreshed at most once a day by time alone),
- the model identity (`variant · baseModelName`, or `apple`),
- the canonical facts.

So a card updates when its data changes (a device bought or sold, a cost added, a service or access
path edited), when the day changes, after a model update, or when the UI language changes — and at
no other time. The card arms a timer to the next local midnight so a page left open also updates.

`AiInsightStore` keeps at most one generation per card running or waiting: a request that arrives
meanwhile replaces the pending one, and a result whose facts are no longer current is discarded. A
`failed`, `timeout` or unparseable reply is not cached and is retried only by the refresh button or
by new facts, so it cannot loop; `busy`, `background`, `cancelled` and `unavailable` are retried on
the next page build. The finance card carries `fallbackFacts`: when the model declines the primary
facts (`guardrail`) or returns nothing usable for them, the store sends the fallback once, in the
same run, and caches whatever it yields under the primary fingerprint. *Clear generated insights*
in Settings deletes the file.

## Android: ML Kit GenAI over AICore

- `com.google.mlkit:genai-prompt:1.0.0-beta4`, the same version as MyAnime and MyDay. The
  Structured Output API is **not** used.
- API 26 or later, so the app's `minSdk` is 26 since 1.6.0 (Android 7.0 and 7.1 are dropped). The
  APIs refuse to run on an unlocked bootloader. Input must stay under about 4,000 tokens; both card
  prompts are far below that.
- Inference is allowed only while the app is the top foreground app; background use fails with
  `BACKGROUND_USE_BLOCKED` (→ `background`). AICore enforces a per-app quota: `BUSY` (→ `busy`) and
  `PER_APP_BATTERY_USE_QUOTA_EXCEEDED` (→ `quota`).
- `GenAiChannel.probePrompt` tries all four combinations of `ModelReleaseStage` (STABLE, PREVIEW) and
  `ModelPreference` (FULL, FAST) and keeps the first that serves. Settings offers "Use the faster
  model" only when both sizes are served.
- Instructions are sent as a `SystemInstruction` where the model reports `isSystemPromptAvailable`,
  and prepended to the prompt otherwise.
- Blank text, or a `finishReason` of `OTHER`, is thrown as `guardrail`, as are processing errors
  whose message mentions *safety*, *filter*, *blocked*, *guardrail* or *harmful*; `MAX_TOKENS` is
  logged and the truncated text returned.
- `android/app/proguard-rules.pro` carries the keep rules that R8 needs for ML Kit, and the release
  build type lists it with `proguardFiles`.
- `AndroidManifest.xml` has a `<queries>` entry for `com.google.android.aicore` so `info` can read
  AICore's version.
- `MainActivity` attaches `GenAiChannel` in `configureFlutterEngine` (next to the existing share
  channel) and detaches it in `onDestroy`.
- Core-library desugaring stays off (see [`platform-notes.md`](platform-notes.md)); ML Kit GenAI
  does not need it.
- Log tag: `MyDeviceGenAi`. Exceptions are logged, prompts never are.

## Apple: the Foundation Models framework

- iOS, iPadOS and macOS 26.0 or later. `SystemLanguageModel.default.availability` is `.available`
  or `.unavailable(reason)` with `deviceNotEligible`, `appleIntelligenceNotEnabled` or
  `modelNotReady`; availability also depends on the region.
- A new `LanguageModelSession(instructions:)` per request, so earlier turns cannot leak into later
  answers.
- The listed languages include en-US, ja-JP and zh-CN; Traditional Chinese is not listed, see
  [Language](#language).
- The context window is 4,096 tokens. Background calls are rate limited.
- Errors: `rateLimited` → `quota`, `concurrentRequests` → `busy`, `guardrailViolation` and
  `refusal` → `guardrail`, `unsupportedLanguageOrLocale` → `unsupportedLanguage`,
  `exceededContextWindowSize` → `tooLong`, `assetsUnavailable` → `unavailable`, anything else →
  `failed`.
- CI builds with the `macos-latest` image's default Xcode (26.x).
- No entitlement, `Info.plist` key or usage description is needed, and the Private Cloud Compute
  entitlement is deliberately absent.

### Weak linking

The deployment targets stay iOS 13.0 and macOS 13.0. Every FoundationModels reference is behind
`#if canImport(FoundationModels)` and `@available(iOS 26.0, macOS 26.0, *)`, and the podspec declares
`s.weak_frameworks = 'FoundationModels'`. An app that strong-links the framework will not launch on
iOS 18 or macOS 15 and earlier, so this is **checked, not assumed**: `tool/check_weak_link.sh`
fails a CI build unless every binary that links FoundationModels uses `LC_LOAD_WEAK_DYLIB`, and
also fails when nothing links it (the plugin did not make it into the build). See
[`ci-cd.md`](ci-cd.md).

## Store policy

Google Play's AI-Generated Content policy treats productivity apps that use AI to improve an
existing feature as out of scope; the output is still labelled. Both cards send only neutral
statistics.

## Device checklist

Run this when a device becomes available, and update **Last verified** above.

1. With the switch off, confirm nothing touches the model (logcat tag `MyDeviceGenAi` stays
   silent) and no card appears.
2. Turn the switch on; check the status row, the technical details and, on Android, the AICore
   version and the served and refused variants.
3. Android: Download, with progress in MB; the status becomes available.
4. Open the Financial Overview and the Services Overview; each card generates once, then reopening
   the page shows the cached text without the progress bar.
5. Add a recurring cost or mark a device sold; the finance card regenerates. Edit an access path;
   the services card regenerates.
6. Check all four UI languages; lines arrive in the right script, amounts keep the currency code,
   and Traditional Chinese is converted where the model answers in Simplified.
7. Send the app to the background mid-request; it resumes cleanly.
8. Repeat 2–7 on a **release** build (R8).
9. Apple: turn Apple Intelligence off in system settings; the card and the row say so.
10. Apple: install on an iOS 18 or macOS 15 device, or boot one in a simulator, and confirm the app
    launches.

## How to refresh this page

1. Compare `genai-prompt` against the Google Maven group index
   (`https://dl.google.com/android/maven2/com/google/mlkit/group-index.xml`) and the ML Kit release
   notes, and against MyDay's `doc/en-us/on-device-ai.md`.
2. Re-read the Foundation Models documentation for the current SDK and the runner image's default
   Xcode.
3. After changing any prompt wording or fact builder, bump `insightPromptVersion`.
4. Update **Last verified** and the facts above in both languages.
