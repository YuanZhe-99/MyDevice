# lib/features/ai/services/ai_insights_cache.dart

AiInsightEntry and AiInsightStatus below are now shared re-exports from MyApps-AI
v0.3.0. Module containers and disk I/O stay local; JSON format is unchanged.

The device-local cache of generated insight cards, `ai_insights.json` in the app data folder:
the `AiInsightEntry` model (one card), the `AiInsights` container (one entry per `InsightModule`),
and the static `AiInsightsCache` that reads, writes and deletes the file. It is deliberately
**not** a registered data module: never synced, never in a backup bundle or ZIP export, and with no
preservation schema. Unlike the data files, an unreadable cache reads as empty, because it is
rebuildable and losing it costs only one regeneration per card. Unlike MyAnime!!!!!'s file of the
same name, it is keyed by module rather than by record and has no pruning. The only consumer is
[`AiInsightStore`](insight_service.md). See
[On-device AI — Cache and fingerprint](../../../../on-device-ai.md#cache-and-fingerprint) and
[Data Formats — `ai_insights.json`](../../../../data-formats.md#ai_insightsjson).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AiInsightStatus` (enum) | enum | B | `ok` (text) / `skipped` (refusal or unsupported language, kept so it is not retried). |
| [`AiInsightEntry` (constructor)](#aiinsightentry-new) | constructor (`AiInsightEntry`) | A | Create a cache entry. |
| [`AiInsightEntry.toJson`](#aiinsightentry-tojson) | method (`AiInsightEntry`) | A | Serialize the entry. |
| [`AiInsightEntry.fromJson`](#aiinsightentry-fromjson) | static method (`AiInsightEntry`) | A | Parse an entry tolerantly; null when malformed. |
| [`AiInsights` (constructor)](#aiinsights-new) | constructor (`AiInsights`) | A | Create a cache value, copying the map. |
| [`AiInsights.toJson`](#aiinsights-tojson) | method (`AiInsights`) | A | Serialize the cache file with sorted module keys. |
| [`AiInsights.fromJson`](#aiinsights-fromjson) | factory constructor (`AiInsights`) | A | Parse the cache file; empty when malformed. |
| `AiInsightsCache._` | private constructor (`AiInsightsCache`) | B | Prevent instantiation; the cache is static. |
| [`file`](#file) | static method (`AiInsightsCache`) | A | Resolve `ai_insights.json` under the app directory. |
| [`load`](#load) | static method (`AiInsightsCache`) | A | Read the cache; empty when absent or unreadable. |
| [`save`](#save) | static method (`AiInsightsCache`) | A | Write the cache atomically through a serialized queue. |
| [`clear`](#clear) | static method (`AiInsightsCache`) | A | Delete the cache file. |

`grep -c 'Purpose:' lib/features/ai/services/ai_insights_cache.dart` reports 11, matching the
eleven non-enum rows above.

**Reconciliation:** the table has 12 rows against 11 `Purpose:` blocks. The extra row is the
`AiInsightStatus` enum, a real top-level declaration documented only by a plain doc comment. The
static fields `AiInsightsCache.fileName` (`'ai_insights.json'`) and the private
`AiInsightsCache._queue` (an `AtomicWriteQueue`), and the entry and container fields, are not rows.

## Documentation

### `AiInsightEntry({required this.fingerprint, required this.lines, List<String>? slots, required this.status, required this.generatedAt, this.model, required this.language, required this.promptVersion})` <a id="aiinsightentry-new"></a>
- **Kind:** constructor of `AiInsightEntry`
- **Source:** `lib/features/ai/services/ai_insights_cache.dart` (line 53)
- **Purpose:** Create one cached card.
- **Inputs:** `fingerprint` — hex SHA-256 of everything the card depends on; `lines` — the
  validated sentences in slot order (empty for `skipped`); `slots` — the slot id of each line;
  `status`; `generatedAt` — UTC; `model` — model identity, for diagnostics; `language` — the
  request tag, e.g. `zh_CN`; `promptVersion` — `insightPromptVersion` at generation time.
- **Returns:** A new `AiInsightEntry`.
- **Side effects:** None.
- **Algorithm:** Field initialization; `slots` defaults to `const []` when `null`.
- **Usage:** `AiInsightStore._run` (`lib/features/ai/services/insight_service.dart`) builds an `ok`
  entry from the parsed reply and a `skipped` entry on a guardrail or unsupported-language
  failure.
- **Notes:** `slots` lets a card place a line under the right section when an earlier slot was
  dropped; an empty `slots` means no section grouping. The constructor does not check that `slots`
  and `lines` have the same length (`fromJson` does).

### `Map<String, dynamic> toJson()` <a id="aiinsightentry-tojson"></a>
- **Kind:** method of `AiInsightEntry`
- **Source:** `lib/features/ai/services/ai_insights_cache.dart` (line 69)
- **Purpose:** Serialize the entry.
- **Inputs:** None.
- **Returns:** A JSON map with keys `fingerprint`, `generatedAt`, `language`, `lines`, `model` (only
  when non-null), `promptVersion`, `slots`, `status`, in that order.
- **Side effects:** None.
- **Algorithm:** Map literal; `generatedAt.toUtc().toIso8601String()`; `status.name`.
- **Usage:** `entries[k]!.toJson()` in [`AiInsights.toJson`](#aiinsights-tojson).
- **Notes:** `generatedAt` is always written in UTC.

### `static AiInsightEntry? fromJson(Object? json)` <a id="aiinsightentry-fromjson"></a>
- **Kind:** static method of `AiInsightEntry`
- **Source:** `lib/features/ai/services/ai_insights_cache.dart` (line 85)
- **Purpose:** Parse one entry, tolerating damage.
- **Inputs:** `json` — any decoded JSON value.
- **Returns:** `AiInsightEntry?` — `null` when `json` is not a map, or `fingerprint` is not a
  string, `lines` is not a list, `status` is not a known `AiInsightStatus` name, or `generatedAt`
  does not parse.
- **Side effects:** None.
- **Algorithm:**
  1. Validate the four required fields as above.
  2. Stringify every element of `lines`.
  3. Stringify `slots` when it is a list, and keep it only when its length equals the line count;
     otherwise pass `null` (no grouping).
  4. Convert `generatedAt` to UTC; `model` only when a string; `language` defaults to `''`;
     `promptVersion` defaults to `0` when not an `int`.
- **Usage:** `final entry = AiInsightEntry.fromJson(map[module.name]);` in
  [`AiInsights.fromJson`](#aiinsights-fromjson).
- **Notes:** A bad entry is dropped, not fatal. Old files without `slots` still load.

### `AiInsights([Map<InsightModule, AiInsightEntry>? entries])` <a id="aiinsights-new"></a>
- **Kind:** constructor of `AiInsights`
- **Source:** `lib/features/ai/services/ai_insights_cache.dart` (line 129)
- **Purpose:** Create a cache value.
- **Inputs:** `entries` — optional; `null` means empty.
- **Returns:** A new `AiInsights` whose `entries` is a fresh mutable copy (`{...?entries}`).
- **Side effects:** None.
- **Algorithm:** Spread-copy into a new map.
- **Usage:** `return AiInsights();` in [`load`](#load) when the file is missing or unreadable;
  `_cache = AiInsights();` in `AiInsightStore.clearAll`.
- **Notes:** `entries` is mutable; `AiInsightStore._store` writes into it in place before saving.

### `Map<String, dynamic> toJson()` <a id="aiinsights-tojson"></a>
- **Kind:** method of `AiInsights`
- **Source:** `lib/features/ai/services/ai_insights_cache.dart` (line 137)
- **Purpose:** Serialize the whole cache file.
- **Inputs:** None.
- **Returns:** `{"version": 1, "insights": {<module name>: <entry>, ...}}` with module keys sorted
  by name.
- **Side effects:** None.
- **Algorithm:** Sort the keys by `name`, then build the map with each entry's `toJson()`.
- **Usage:** `insights.toJson()` in [`save`](#save).
- **Notes:** Sorted keys keep the file byte-stable for equal content.

### `factory AiInsights.fromJson(Object? json)` <a id="aiinsights-fromjson"></a>
- **Kind:** factory constructor of `AiInsights`
- **Source:** `lib/features/ai/services/ai_insights_cache.dart` (line 150)
- **Purpose:** Parse the cache file.
- **Inputs:** `json` — the decoded file.
- **Returns:** `AiInsights` — empty when `json` is not a map or has no `insights` map.
- **Side effects:** None.
- **Algorithm:** For each `InsightModule` value, parse `insights[module.name]` with
  `AiInsightEntry.fromJson` and keep non-null results.
- **Usage:** `return AiInsights.fromJson(jsonDecode(await f.readAsString()));` in
  [`load`](#load).
- **Notes:** Unknown module keys and malformed entries are dropped. The `version` field is not
  checked.

### `static Future<File> file()` <a id="file"></a>
- **Kind:** static method of `AiInsightsCache`
- **Source:** `lib/features/ai/services/ai_insights_cache.dart` (line 187)
- **Purpose:** Resolve the cache file.
- **Inputs:** None.
- **Returns:** `Future<File>` — `<app dir>/ai_insights.json`.
- **Side effects:** May create the app directory (through
  [`DeviceStorage.getAppDir`](../../devices/services/device_storage.md#getappdir)).
- **Algorithm:** `File(p.join((await DeviceStorage.getAppDir()).path, fileName))`.
- **Usage:** Inside [`load`](#load), [`save`](#save) and [`clear`](#clear); tests read it with
  `await AiInsightsCache.file()` (`test/ai_insights_cache_test.dart`).
- **Notes:** Goes through the storage hub so a custom storage path works.

### `static Future<AiInsights> load()` <a id="load"></a>
- **Kind:** static method of `AiInsightsCache`
- **Source:** `lib/features/ai/services/ai_insights_cache.dart` (line 195)
- **Purpose:** Read the cache.
- **Inputs:** None.
- **Returns:** `Future<AiInsights>` — empty when the file is absent or cannot be read or decoded.
- **Side effects:** Reads local storage.
- **Algorithm:** Inside `try`: resolve the file; return empty if it does not exist; otherwise
  `AiInsights.fromJson(jsonDecode(...))`. Any exception returns an empty `AiInsights`.
- **Usage:** The default `load` of `AiInsightStore` (`_load = load ?? AiInsightsCache.load`,
  `lib/features/ai/services/insight_service.dart`).
- **Notes:** Never throws. This is a deliberate exception to the "corrupt data files raise typed
  exceptions" rule: the file holds no user data and is rebuilt on demand.

### `static Future<void> save(AiInsights insights)` <a id="save"></a>
- **Kind:** static method of `AiInsightsCache`
- **Source:** `lib/features/ai/services/ai_insights_cache.dart` (line 210)
- **Purpose:** Write the cache atomically.
- **Inputs:** `insights`.
- **Returns:** `Future<void>` — completes when this write has run.
- **Side effects:** Replaces `ai_insights.json`.
- **Algorithm:** Enqueue on the class's `AtomicWriteQueue`; inside, encode
  `insights.toJson()` with two-space indentation and write it with
  `atomicWriteString` from `package:myapps_data` (see
  `packages/myapps_data/doc/en-us/functions/src/storage/atomic_io.md`). MyDay goes through its
  `DataFileSafety.atomicWriteString`; MyDevice has no such wrapper and calls the package directly.
- **Usage:** The default `save` of `AiInsightStore`, called from `AiInsightStore._store`.
- **Notes:** Never notifies auto-sync. Errors propagate to the caller; `_store` swallows them.

### `static Future<void> clear()` <a id="clear"></a>
- **Kind:** static method of `AiInsightsCache`
- **Source:** `lib/features/ai/services/ai_insights_cache.dart` (line 222)
- **Purpose:** Delete the cache.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Removes `ai_insights.json` if present.
- **Algorithm:** Enqueue on the same queue as [`save`](#save); delete the file when it exists.
- **Usage:** The default `clear` of `AiInsightStore`, called from `AiInsightStore.clearAll` (the
  Settings action *Clear generated insights*).
- **Notes:** Serialized with writes, so a save already queued cannot recreate the file after the
  delete.
