# lib/features/devices/services/device_search_service.dart

`DeviceSearchService` fetches device specifications from online databases and reports, per source,
whether that fetch actually worked. It owns the HTTP plumbing and source dispatch only; all markup
parsing lives in [`device_search_parsers.md`](device_search_parsers.md) so it can be tested without
a network. Results flow to the user through
[`../views/device_search_dialog.md`](../views/device_search_dialog.md), which lets the user tick
which fields to apply.

See [Online Search and Presets](../../../../features/online-search-and-presets.md#device-spec-search--device_search_servicedart)
for the concept overview this page verifies against source.

## Sources

| Source | Covers | Search endpoint | Notes |
|---|---|---|---|
| Notebookcheck | Laptops, tablets, phones, smartwatches | `GET Laptop-Search.8223.0.html?model=` | Device pages carry a full spec table. |
| PhoneDB | Phones, at SKU level | `POST index.php?m=device&s=list` with `search_exp` | Loose full-text matching; needs a relevance gate. |

**GSMArena was removed.** It answers every request with a Cloudflare Turnstile challenge served as
HTTP 200, which no HTTP-only client can pass. Because the old code checked only the status code and
then failed to match its row pattern, it returned an empty list — indistinguishable from "this
device does not exist". That silent failure is the reason the outcome reporting below exists.

Two PhoneDB endpoint details are load-bearing and non-obvious: its `filter=` and `model=` query
parameters are **ignored** and return the site's "latest devices" list regardless of the query, so
the only working text search is the `search_exp` POST. And when it does not carry a model, it falls
back to a loose match rather than returning nothing — a search for `Galaxy Z Fold8` yields roughly
120 unrelated Galaxy phones — which is why every result passes through `isRelevant`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `DeviceSearchStatus` | enum | A | Why a source returned what it did. |
| `DeviceSourceOutcome` | class | B | The outcome of querying one source. |
| [`DeviceSourceOutcome`](#devicesourceoutcome-new) | constructor | A | Record how one source responded. |
| [`DeviceSourceOutcome.failed`](#outcome-failed) | getter | A | Report failure as distinct from finding nothing. |
| `DeviceSearchResponse` | class | B | Merged results plus per-source outcomes. |
| [`DeviceSearchResponse`](#devicesearchresponse-new) | constructor | A | Hold results and outcomes. |
| [`DeviceSearchResponse.failures`](#failures) | getter | A | List the sources that failed. |
| [`DeviceSearchResponse.allSourcesFailed`](#allsourcesfailed) | getter | A | Report that no source succeeded. |
| `DeviceSearchResult` | class | B | One result from an online database. |
| `DeviceSearchResult` | constructor | B | Create a result instance. |
| [`withDetail`](#withdetail) | method | A | Merge scraped detail fields onto a result. |
| `_SourceResponse` | private class | B | One source's contribution before merging. |
| `_SourceResponse` / `.failed` | private constructors | B | Build a source contribution. |
| `DeviceSearchService` | class | B | The service itself; static-only. |
| `userAgent` / `_timeout` / `_maxResultsPerSource` | static consts | B | Shared request configuration. |
| [`headers`](#headers) | static method | A | Build the headers every scraped request sends. |
| [`search`](#search) | static method | A | Search every enabled source. |
| [`fetchDetail`](#fetchdetail) | static method | A | Fetch the full detail page for a result. |
| [`_classifyError`](#_classifyerror) | private static method | A | Classify a transport-level failure. |
| [`_searchNotebookcheck`](#_searchnotebookcheck) | private static method | A | Search Notebookcheck. |
| [`_fetchNotebookcheckDetail`](#_fetchnotebookcheckdetail) | private static method | A | Read a Notebookcheck device page. |
| [`_jsonLdImage`](#_jsonldimage) | private static method | A | Pull a product image URL from JSON-LD. |
| [`_searchPhonedb`](#_searchphonedb) | private static method | A | Search PhoneDB. |
| [`_fetchPhonedbDetail`](#_fetchphonedbdetail) | private static method | A | Read a PhoneDB datasheet page. |

Row count (24) exceeds `grep -c 'Purpose:' device_search_service.dart` (15): the enum, the four
class declarations, the three plain constructors and the three static consts carry ordinary `///`
descriptions or none, rather than full `Purpose:` blocks. They are indexed here per the tiering
rule that every declaration appears in the table.

## Documentation

### `enum DeviceSearchStatus`
- **Kind:** top-level enum.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 16).
- **Purpose:** Say why a source returned what it did.
- **Values:**
  - `ok` — the source answered and its markup parsed. `resultCount` may still be 0 when the device
    genuinely is not in that database.
  - `blocked` — a bot-wall or challenge page was served instead of content.
  - `unreachable` — DNS, socket, timeout or a non-200, non-403 status.
  - `markupChanged` — the source answered, but none of the structures the parser anchors on were
    present, so the scraper needs updating.
- **Notes:** The whole point is that these four are no longer interchangeable. Retrying helps for
  `unreachable`, never for `blocked` or `markupChanged`, and is pointless for an `ok` with no
  results. Note that `ok` with `resultCount == 0` is deliberately **not** a failure — a zero-match
  search page is recognised via `isNotebookcheckSearchPage` / `isPhonedbResultsPage`.

### `const DeviceSourceOutcome({...})` <a id="devicesourceoutcome-new"></a>
- **Kind:** constructor of `DeviceSourceOutcome`.
- **Source:** line 43.
- **Purpose:** Record how one source responded to a query.
- **Inputs:** `source` name, `status`, and `resultCount`.
- **Returns:** A new `DeviceSourceOutcome`.
- **Side effects:** None.
- **Notes:** None.

### `bool get failed` <a id="outcome-failed"></a>
- **Kind:** getter of `DeviceSourceOutcome`.
- **Source:** line 54.
- **Purpose:** Report whether this source failed rather than simply found nothing.
- **Returns:** `true` for every status other than `ok`.
- **Side effects:** None.
- **Notes:** An `ok` outcome with `resultCount == 0` is not a failure.

### `const DeviceSearchResponse({...})` <a id="devicesearchresponse-new"></a>
- **Kind:** constructor of `DeviceSearchResponse`.
- **Source:** line 67.
- **Purpose:** Hold the merged results and the per-source outcomes.
- **Inputs:** `results`, `outcomes`.
- **Side effects:** None.
- **Notes:** None.

### `List<DeviceSourceOutcome> get failures` <a id="failures"></a>
- **Kind:** getter of `DeviceSearchResponse`.
- **Source:** line 74.
- **Purpose:** List the sources that failed.
- **Returns:** The outcomes whose status is not `ok`.
- **Side effects:** None.
- **Notes:** Used by the dialog to explain an empty or partial result list.

### `bool get allSourcesFailed` <a id="allsourcesfailed"></a>
- **Kind:** getter of `DeviceSearchResponse`.
- **Source:** line 83.
- **Purpose:** Report whether every queried source failed.
- **Returns:** `true` when at least one source was queried and none succeeded.
- **Side effects:** None.
- **Notes:** This is what lets the dialog say "no source could be reached" instead of "no results
  found" — the distinction the user needs to know whether retrying is worthwhile.

### `DeviceSearchResult withDetail({...})` <a id="withdetail"></a>
- **Kind:** method of `DeviceSearchResult`.
- **Source:** line 135.
- **Purpose:** Merge freshly scraped detail fields onto this result.
- **Inputs:** Any detail field; omitted fields keep their existing value.
- **Returns:** A new `DeviceSearchResult` with `detailFetched` set to `true`.
- **Side effects:** None.
- **Notes:** Every field is null-coalesced, so a detail page that omits a field never wipes a value
  already parsed from the search row. Notebookcheck rows carry GPU, CPU and screen inline; the
  detail page sometimes omits `Released` entirely (Apple pages do), and that must not clear
  anything.

### `static Map<String, String> headers({String accept = 'text/html'})` <a id="headers"></a>
- **Kind:** static method of `DeviceSearchService`.
- **Source:** line 204.
- **Purpose:** Build the headers every scraped request sends.
- **Inputs:** `accept` — the `Accept` header value.
- **Returns:** A header map with the user agent, accept and accept-language.
- **Side effects:** None.
- **Notes:** Centralised so the user agent cannot drift between the page fetch and any follow-up
  request for a resource discovered on that page.

### `static Future<DeviceSearchResponse> search(String query)` <a id="search"></a>
- **Kind:** static method of `DeviceSearchService`.
- **Source:** line 217.
- **Purpose:** Search every enabled source for devices matching a query.
- **Inputs:** `query` — the user's search text.
- **Returns:** `Future<DeviceSearchResponse>` with merged results and one outcome per source.
- **Side effects:** Issues HTTP requests to Notebookcheck and PhoneDB.
- **Algorithm:** 1. Return an empty response immediately when `AppFlavor.isStore`, or when the
  trimmed query is empty. 2. Open one `http.Client`. 3. Query both sources concurrently with
  `Future.wait`. 4. Concatenate their results and pair each with a `DeviceSourceOutcome`.
  5. Close the client in a `finally`.
- **Usage:**
  ```dart
  final response = await DeviceSearchService.search('Galaxy Z Fold8');
  if (response.allSourcesFailed) { /* show why, per source */ }
  ```
- **Notes:** One shared client for the fan-out, rather than a bare static `http.get` per call as
  before. A failing source never prevents the other from returning results, because each source
  function catches its own transport errors and reports them as a status instead of throwing.

### `static Future<DeviceSearchResult> fetchDetail(DeviceSearchResult result)` <a id="fetchdetail"></a>
- **Kind:** static method of `DeviceSearchService`.
- **Source:** line 259.
- **Purpose:** Fetch the full detail page for a result the user selected.
- **Inputs:** `result` — a result previously returned by [`search`](#search).
- **Returns:** `Future<DeviceSearchResult>`, enriched when the fetch succeeded.
- **Side effects:** Issues one HTTP request to the result's source.
- **Notes:** Returns the input unchanged for store builds, a result with no `sourceUrl`, an unknown
  source, or any thrown error. **Adding a source without adding a `case` here silently skips detail
  fetching for it** — the dispatch is the one place that has to be kept in step with `search`.

### `static DeviceSearchStatus _classifyError(Object error)` <a id="_classifyerror"></a>
- **Kind:** private static method.
- **Source:** line 288.
- **Purpose:** Classify a transport-level failure.
- **Inputs:** `error` — the thrown object.
- **Returns:** The matching `DeviceSearchStatus`.
- **Side effects:** None.
- **Notes:** Currently every recognised network fault and every unrecognised error alike map to
  `unreachable`. The branch is kept explicit so a future distinction (for example, treating a
  handshake failure differently) has an obvious home.

### `static Future<_SourceResponse> _searchNotebookcheck(...)` <a id="_searchnotebookcheck"></a>
- **Kind:** private static method.
- **Source:** line 306.
- **Purpose:** Search Notebookcheck's device database.
- **Inputs:** `client`, `query`.
- **Returns:** `Future<_SourceResponse>` with results and a status.
- **Side effects:** Issues one HTTP GET.
- **Algorithm:** 1. GET `Laptop-Search.8223.0.html?model=<query>`. 2. Map 403 to `blocked` and any
  other non-200 to `unreachable`. 3. Run `looksBlocked` on the body. 4. Match result rows
  (`<tr class="odd|even">`); if there are none, return `ok` when `isNotebookcheckSearchPage` says
  the page rendered, otherwise `markupChanged`. 5. For each row, take the link and title, run the
  title through `cleanDeviceName`, drop it if `isReviewArticle` or not `isRelevant`, deduplicate on
  the lowercased name, and parse the inline specs after the `<br/>`. 6. Cap at 8 results.
- **Notes:** The hyphenated `Laptop-Search` path is deliberate; the underscored `Laptop_Search`
  form 301-redirects. The `cleanDeviceName`-before-`isReviewArticle` order is the fix for the bug
  that discarded every current device: Notebookcheck titles its canonical pages
  `<name> - Reviews and Specs`, so filtering on the raw title dropped `Samsung Galaxy Z Fold8` while
  keeping the older, bare-titled `Samsung Galaxy Z Fold7`.

### `static Future<DeviceSearchResult> _fetchNotebookcheckDetail(...)` <a id="_fetchnotebookcheckdetail"></a>
- **Kind:** private static method.
- **Source:** line 421.
- **Purpose:** Read a Notebookcheck device page for full specs and an image.
- **Inputs:** `client`, `result`.
- **Returns:** `Future<DeviceSearchResult>`.
- **Side effects:** Issues one HTTP GET.
- **Algorithm:** Parse the page with `parseNotebookcheckSpecs`, then map its labels:

  | Block label | Field | Parser |
  |---|---|---|
  | `Processor` | `chipset` | `parseChipName` |
  | `Graphics adapter` | `gpuName` | `parseChipName` |
  | `Memory` | `ram` | `parseCapacity` |
  | `Storage` | `storage` | `parseCapacity` |
  | `Display` | `screenSize`, `screenResolutionW/H` | `parseScreenSize`, `parseResolution` |
  | `Battery` | `battery` | `parseBattery` |
  | `Operating System` | `os` | verbatim |
  | `Released` | `releaseDate` | `parseUsDate` |

- **Notes:** Reading the spec table is the entire point of this fetch. The previous implementation
  extracted only the JSON-LD image and discarded the table, so RAM, storage, battery, OS and release
  date never reached the user from this source at all. Not every page has every block — Apple pages
  omit `Released` — and a missing block simply leaves the field null.

### `static String? _jsonLdImage(String html)` <a id="_jsonldimage"></a>
- **Kind:** private static method.
- **Source:** line 459.
- **Purpose:** Pull a product image URL out of a page's JSON-LD blocks.
- **Inputs:** `html` — the full page markup.
- **Returns:** The image URL, or null.
- **Side effects:** None.
- **Algorithm:** Iterate `<script type="application/ld+json">` blocks, decode each in a `try`, take
  the first whose `@type` is `Product`, accept `image` as either an object with a `url` or a bare
  string, and filter the result through `isLikelyDeviceImage`.
- **Notes:** A page carries several JSON-LD blocks, including an `Article` one; only `Product`
  holds the device photo. Malformed blocks are skipped rather than aborting the scan.

### `static Future<_SourceResponse> _searchPhonedb(...)` <a id="_searchphonedb"></a>
- **Kind:** private static method.
- **Source:** line 494.
- **Purpose:** Search PhoneDB's device database.
- **Inputs:** `client`, `query`.
- **Returns:** `Future<_SourceResponse>` with results and a status.
- **Side effects:** Issues one HTTP POST.
- **Algorithm:** 1. POST `search_exp=<query>` to `index.php?m=device&s=list`. 2. Map 403 to
  `blocked`, other non-200 to `unreachable`, and run `looksBlocked`. 3. Split on
  `<div class="content_block">`; with no blocks, return `ok` when `isPhonedbResultsPage` says the
  page rendered, otherwise `markupChanged`. 4. Per block, read the anchor's `title` (which holds the
  **full** name; the visible link text is truncated with `..`), clean it, apply the review and
  relevance gates, deduplicate on the cleaned name, and pick up the thumbnail. 5. Cap at 8.
- **Notes:** Deduplicating on the cleaned name is what collapses the many region and capacity SKUs
  of one phone — PhoneDB lists `Galaxy Z Fold7` separately for 256GB, 512GB and 1TB in several
  regions — into a single row. The relevance gate is not optional here: without it an unknown model
  fills all 8 slots with unrelated phones.

### `static Future<DeviceSearchResult> _fetchPhonedbDetail(...)` <a id="_fetchphonedbdetail"></a>
- **Kind:** private static method.
- **Source:** line 585.
- **Purpose:** Read a PhoneDB datasheet page for full specs.
- **Inputs:** `client`, `result`.
- **Returns:** `Future<DeviceSearchResult>`.
- **Side effects:** Issues one HTTP GET.
- **Algorithm:** Parse with `parsePhonedbSpecs`, then map:

  | Datasheet label | Field | Parser |
  |---|---|---|
  | `CPU` | `chipset` | `parseChipName` |
  | `Graphical Controller` | `gpuName` | `parseChipName` |
  | `RAM Capacity (converted)` | `ram` | `parseCapacity` |
  | `Non-volatile Memory Capacity (converted)` | `storage` | `parseCapacity` |
  | `Display Diagonal` | `screenSize` | `parseScreenSizeMm` |
  | `Resolution` | `screenResolutionW/H` | `parseResolution` |
  | `Nominal Battery Capacity` | `battery` | `parseBattery` |
  | `Operating System` | `os` | verbatim |
  | `Released` | `releaseDate` | `parseReleaseDate` |

- **Notes:** PhoneDB gives the diagonal in **millimetres** and capacities in **binary** units, so
  both go through converting parsers rather than the inch/decimal ones used for Notebookcheck. The
  search thumbnail is reused as the image, since the datasheet has no larger product photo.

## Related

- [`device_search_parsers.md`](device_search_parsers.md) — all markup parsing, unit-tested against fixtures.
- [`../views/device_search_dialog.md`](../views/device_search_dialog.md) — the two-phase UI and field toggles.
- [`chip_search_service.md`](chip_search_service.md) — the CPU/GPU sibling feature.
- [`preset_service.md`](preset_service.md) — the offline bundled-template counterpart.
- [Online Search and Presets](../../../../features/online-search-and-presets.md)
