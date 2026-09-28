# lib/features/ai/services/insight_language.dart

`InsightLanguage`: which language an insight card asks the on-device model to write in, and how
each validated reply line is post-processed. A port of MyAnime!!!!!'s `ReasonLanguage`. The card
([`ai_insight_card.md`](../widgets/ai_insight_card.md)) picks the language from the UI locale; the
store ([`insight_service.md`](insight_service.md)) puts the locale tag into the fingerprint and runs
[`finish`](#finish) on every kept line. Chinese conversion is delegated to
[`ChineseConvert`](../../../shared/utils/chinese_convert.md). See
[On-device AI — Language](../../../../on-device-ai.md#language).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`InsightLanguage` (constructor)](#insightlanguage-new) | const constructor (`InsightLanguage`) | A | Create an insight language. |
| [`forLocale`](#forlocale) | static method (`InsightLanguage`) | A | Pick the request language for the UI locale, or null when the model cannot write it. |
| [`finish`](#finish) | method (`InsightLanguage`) | A | Convert a validated line to the UI's Chinese variant. |

`grep -c 'Purpose:' lib/features/ai/services/insight_language.dart` reports 3, matching the three
rows above exactly. The five fields (`localeTag`, `name`, `code`, `toTraditional`,
`toSimplified`) carry one-line doc comments without `Purpose:` and are not rows. All three
declarations are public and Tier A.

## Documentation

### `const InsightLanguage(this.localeTag, this.name, this.code, {this.toTraditional = false, this.toSimplified = false})` <a id="insightlanguage-new"></a>
- **Kind:** const constructor of `InsightLanguage`
- **Source:** `lib/features/ai/services/insight_language.dart` (line 28)
- **Purpose:** Create an immutable request language.
- **Inputs:** `localeTag` — the tag stated in the instructions (`zh_CN`, `zh_TW`, `ja_JP`,
  `en_US`); `name` — the English language name used in the instructions; `code` — `en`, `ja` or
  `zh`, for the script check; `toTraditional` / `toSimplified` — which Chinese conversion
  [`finish`](#finish) applies (both default `false`).
- **Returns:** A new `InsightLanguage`.
- **Side effects:** None.
- **Algorithm:** Plain field-initializing const constructor.
- **Usage:** Only the five `const InsightLanguage(...)` values inside [`forLocale`](#forlocale);
  tests build their own.
- **Notes:** Nothing stops both conversion flags being true; `finish` would then apply only
  `toTraditional`.

### `static InsightLanguage? forLocale(Locale locale, {bool? localeSupported})` <a id="forlocale"></a>
- **Kind:** static method of `InsightLanguage`
- **Source:** `lib/features/ai/services/insight_language.dart` (line 46)
- **Purpose:** Pick the language a card is requested in for the current UI locale.
- **Inputs:** `locale` — the UI locale; `localeSupported` — Apple's `supportsLocale` answer for
  that locale (from `GenAiCoreInfo.localeSupported`), `null` when unknown (Android, or before
  `info` has answered).
- **Returns:** `InsightLanguage?` — `null` when the model cannot write in the UI language, so the
  card says so instead of generating.
- **Side effects:** None.
- **Algorithm:**
  1. `traditional` is true when the language is `zh` and the country is `TW` or `HK`, or the
     script is `Hant`.
  2. If `localeSupported == false` and the locale is not Traditional Chinese, return `null`.
  3. Otherwise switch on the language code:
     - Traditional Chinese with `localeSupported == false` → `zh_CN` / "Simplified Chinese" /
       `zh`, `toTraditional: true` (ask for Simplified, convert to Traditional);
     - Traditional Chinese otherwise → `zh_TW` / "Traditional Chinese" / `zh`,
       `toTraditional: true`;
     - any other `zh` → `zh_CN` / "Simplified Chinese" / `zh`, `toSimplified: true`;
     - `ja` → `ja_JP` / "Japanese" / `ja`;
     - anything else → `en_US` / "English" / `en`.
- **Usage:**
  ```dart
  final language = InsightLanguage.forLocale(
    Localizations.localeOf(context),
    localeSupported: ai.coreInfo?.localeSupported,
  );
  ```
  (`lib/features/ai/widgets/ai_insight_card.dart`, `build`; a `null` result means no request is
  built.)
- **Notes:** Chinese output is always converted to the UI's variant, so a reply in the other
  variant is repaired rather than discarded. Hong Kong locales are requested as `zh_TW`. Any
  unrecognised language falls back to English, since the app itself only ships en, ja, zh and
  zh_TW.

### `String finish(String text)` <a id="finish"></a>
- **Kind:** method of `InsightLanguage`
- **Source:** `lib/features/ai/services/insight_language.dart` (line 84)
- **Purpose:** Post-process one validated reply line.
- **Inputs:** `text` — a line already accepted by `parseInsightReply`.
- **Returns:** `String` — converted to Traditional or Simplified Chinese when the matching flag is
  set, otherwise `text` unchanged.
- **Side effects:** None.
- **Algorithm:** `toTraditional` → `ChineseConvert.toTraditional(text)`; else `toSimplified` →
  `ChineseConvert.toSimplified(text)`; else return `text`.
- **Usage:** `for (final n in numbers) request.language.finish(parsed[n]!)`
  (`lib/features/ai/services/insight_service.dart`, `AiInsightStore._run`).
- **Notes:** Runs after the script check, so conversion never decides whether a line is kept.
  Japanese and English lines pass through untouched.
