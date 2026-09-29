# lib/features/devices/services/device_search_service.dart

`DeviceSearchService` fetches device specifications from online databases and reports, per source,
whether that fetch actually worked. It owns the HTTP plumbing, the source registry and source
dispatch only; all markup, wikitext and tech-specs parsing lives in
[`device_search_parsers.md`](device_search_parsers.md) so it can be tested without a network.
Results flow to the user through
[`../views/device_search_dialog.md`](../views/device_search_dialog.md), which lets the user tick
which fields to apply.

See [Online Search and Presets](../../../../features/online-search-and-presets.md#device-spec-search--device_search_servicedart)
for the concept overview this page verifies against source. `test/device_search_sources_test.dart`
covers the registry, the Apple family match and the two public mappers against saved fixtures;
`tool/check_sources.dart` and `tool/test_live.dart` exercise the live sources.

## Sources

| Source | Covers | Search endpoint | Notes |
|---|---|---|---|
| Apple | Apple products only (iPhone, iPad, Mac, Apple Watch, AirPods) | `GET support.apple.com/en-us/docs/<family>` | Queried only when [`appleFamiliesFor`](#applefamiliesfor) matches; detail comes from the product's tech specs page. |
| Notebookcheck | Laptops, tablets, phones, smartwatches | `GET Laptop-Search.8223.0.html?model=` | Device pages carry a full spec table. |
| PhoneDB | Phones, at SKU level | `POST index.php?m=device&s=list` with `search_exp` | Loose full-text matching; needs a relevance gate. |
| Wikipedia | Anything with its own article (consoles, handhelds, ...) | MediaWiki API `action=query&list=search` | Fallback source: queried only when every other source found nothing; detail is read from the article's infobox. |

The four sources live in one **source registry**, [`_sources`](#_sources). Each entry names the
source, can be switched off, can be marked as a fallback source, says which queries it applies to,
and supplies its search and detail functions. [`search`](#search) and [`fetchDetail`](#fetchdetail)
both dispatch through it, so adding a source is one registry entry.

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
| [`DeviceSearchStatus`](#devicesearchstatus) | enum | A | Why a source returned what it did. |
| `DeviceSourceOutcome` | class | B | The outcome of querying one source. |
| [`DeviceSourceOutcome`](#devicesourceoutcome-new) | constructor | A | Record how one source responded. |
| [`DeviceSourceOutcome.failed`](#outcome-failed) | getter | A | Report failure as distinct from finding nothing. |
| `DeviceSearchResponse` | class | B | Merged results plus per-source outcomes. |
| [`DeviceSearchResponse`](#devicesearchresponse-new) | constructor | A | Hold results and outcomes. |
| [`DeviceSearchResponse.failures`](#failures) | getter | A | List the sources that failed. |
| [`DeviceSearchResponse.allSourcesFailed`](#allsourcesfailed) | getter | A | Report that no source succeeded. |
| `DeviceSearchResult` | class | B | One result from an online database. |
| `DeviceSearchResult` | constructor | B | Create a result as a source's search step parsed it; `detailFetched` starts false. |
| [`withDetail`](#withdetail) | method | A | Merge scraped detail fields onto a result. |
| `_Source` | private class | B | One source as the registry describes it. |
| [`_Source`](#_source-new) | private constructor | A | Describe one source for the registry. |
| `_anyQuery` | private function | B | The `appliesTo` of general-purpose sources; accepts every query. |
| `_SourceResponse` | private class | B | One source's contribution before merging. |
| `_SourceResponse` / `.failed` | private constructors | B | Build a source contribution; `.failed` carries a status and no results. |
| `DeviceSearchService` | class | B | The service itself; static-only. |
| [`userAgent`](#useragent) | static const | A | The honest client name sent with every request. |
| `_timeout` / `_maxResultsPerSource` | static consts | B | 15-second request timeout; at most 8 results per source. |
| [`_sources`](#_sources) | private static final | A | The source registry, in result order. |
| [`sourceNames`](#sourcenames) | static getter | A | List the enabled sources. |
| [`headers`](#headers) | static method | A | Build the headers every scraped request sends. |
| [`search`](#search) | static method | A | Search every enabled source that applies. |
| [`fetchDetail`](#fetchdetail) | static method | A | Fetch the full detail page for a result. |
| [`_classifyError`](#_classifyerror) | private static method | A | Classify a transport-level failure. |
| [`_searchNotebookcheck`](#_searchnotebookcheck) | private static method | A | Search Notebookcheck. |
| [`_fetchNotebookcheckDetail`](#_fetchnotebookcheckdetail) | private static method | A | Read a Notebookcheck device page. |
| [`_jsonLdImage`](#_jsonldimage) | private static method | A | Pull a product image URL from JSON-LD. |
| [`_searchPhonedb`](#_searchphonedb) | private static method | A | Search PhoneDB. |
| [`_fetchPhonedbDetail`](#_fetchphonedbdetail) | private static method | A | Read a PhoneDB datasheet page. |
| `_appleFamilies` | private static const | B | Product word to Apple Support docs family (`macbook` → `mac`, ...). |
| [`appleFamiliesFor`](#applefamiliesfor) | static method | A | Tell which Apple docs families a query asks about. |
| [`_searchApple`](#_searchapple) | private static method | A | Search Apple Support's docs indexes. |
| [`_fetchAppleDetail`](#_fetchappledetail) | private static method | A | Read an Apple product's tech specs page. |
| [`withAppleSpecs`](#withapplespecs) | static method | A | Map a parsed tech specs page onto a result. |
| `_wikipediaApi` | private static const | B | The English Wikipedia MediaWiki API endpoint. |
| [`_searchWikipedia`](#_searchwikipedia) | private static method | A | Search English Wikipedia. |
| [`_fetchWikipediaDetail`](#_fetchwikipediadetail) | private static method | A | Read a Wikipedia article's infobox and lead image. |
| [`withWikipediaInfobox`](#withwikipediainfobox) | static method | A | Map an infobox onto a result. |

Row count (39) exceeds `grep -c 'Purpose:' device_search_service.dart` (28). The 28 `Purpose:`
blocks fill 27 rows, because the two `_SourceResponse` constructors share one row. The other 12
rows are declarations that carry an ordinary `///` description or none rather than a `Purpose:`
block: the enum, the six class declarations, and the five static constants and fields (`userAgent`,
`_timeout` / `_maxResultsPerSource` as one row, `_sources`, `_appleFamilies`, `_wikipediaApi`). They
are indexed here per the tiering rule that every declaration appears in the table.

## Documentation

### `enum DeviceSearchStatus` <a id="devicesearchstatus"></a>
- **Kind:** top-level enum.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 16).
- **Purpose:** Say why a source returned what it did.
- **Values:**
  - `ok` — the source answered and its markup parsed. `resultCount` may still be 0 when the device
    genuinely is not in that database.
  - `blocked` — a bot-wall or challenge page was served instead of content, or HTTP 403.
  - `unreachable` — DNS, socket, timeout or a non-200, non-403 status.
  - `markupChanged` — the source answered, but none of the structures the parser anchors on were
    present, so the scraper needs updating. For Wikipedia, JSON that does not decode or lacks
    `query.search`.
- **Notes:** The whole point is that these four are no longer interchangeable. Retrying helps for
  `unreachable`, never for `blocked` or `markupChanged`, and is pointless for an `ok` with no
  results. Note that `ok` with `resultCount == 0` is deliberately **not** a failure — a zero-match
  search page is recognised via `isNotebookcheckSearchPage` / `isPhonedbResultsPage` /
  `isAppleDocsIndexPage`.

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
  found" — the distinction the user needs to know whether retrying is worthwhile. Only sources that
  were actually queried have an outcome: a source whose `appliesTo` rejected the query is absent,
  and the Wikipedia fallback source appears only when it ran.

### `DeviceSearchResult withDetail({...})` <a id="withdetail"></a>
- **Kind:** method of `DeviceSearchResult`.
- **Source:** line 141.
- **Purpose:** Merge freshly scraped detail fields onto this result.
- **Inputs:** Any detail field; omitted fields keep their existing value.
- **Returns:** A new `DeviceSearchResult` with `detailFetched` set to `true`.
- **Side effects:** None.
- **Notes:** Every field is null-coalesced, so a detail page that omits a field never wipes a value
  already parsed from the search row. Notebookcheck rows carry GPU, CPU and screen inline; the
  detail page sometimes omits `Released` entirely (Apple pages do), and that must not clear
  anything. `source`, `sourceUrl`, `name`, `brand`, `model` and `thumbnailUrl` cannot be changed
  here, which is why [`withWikipediaInfobox`](#withwikipediainfobox) rebuilds the result first.

### `const _Source({...})` <a id="_source-new"></a>
- **Kind:** private constructor of `_Source`.
- **Source:** line 203.
- **Purpose:** Describe one device-search source for the source registry.
- **Inputs:** `name` — the source name, also written into every result's `source`; `enabled`
  (default `true`); `fallback` (default `false`); `appliesTo` — whether the source can answer a
  query; `search` and `detail` — the source's search and detail functions.
- **Returns:** A new `_Source` instance.
- **Side effects:** None.
- **Notes:** `enabled: false` keeps the code, parsers and tests but stops querying the source — the
  switch for a source that starts blocking or changes beyond repair. A fallback source is queried
  only when every other source found nothing, so a broad source cannot bury exact answers under
  product-line articles. A source that does not apply is neither queried nor reported. The `name`
  must equal the `source` string the search function writes into its results, because
  [`fetchDetail`](#fetchdetail) finds the detail function by that string; a mismatch silently skips
  detail fetching.

### `static const userAgent` <a id="useragent"></a>
- **Kind:** static const of `DeviceSearchService`.
- **Source:** line 262.
- **Purpose:** The user agent sent with every request: `MyDevice (+https://github.com/YuanZhe-99/MyDevice)`.
- **Notes:** An honest client name, not a browser's. Cloudflare, in front of Notebookcheck, rejects
  a Chrome user agent that arrives over a non-Chrome TLS handshake with HTTP 403 — the previous
  spoofed Chrome string is what made the search look dead in 1.6.0. MediaWiki's API policy also asks
  for an identifying agent.

### `static final List<_Source> _sources` <a id="_sources"></a>
- **Kind:** private static final of `DeviceSearchService`.
- **Source:** line 265.
- **Purpose:** The source registry: every source, in the order results are listed.
- **Notes:** Current entries, all enabled:

  | Name | `appliesTo` | Fallback | Search / detail |
  |---|---|---|---|
  | `Apple` | `appleFamiliesFor(q).isNotEmpty` | no | [`_searchApple`](#_searchapple) / [`_fetchAppleDetail`](#_fetchappledetail) |
  | `Notebookcheck` | `_anyQuery` | no | [`_searchNotebookcheck`](#_searchnotebookcheck) / [`_fetchNotebookcheckDetail`](#_fetchnotebookcheckdetail) |
  | `PhoneDB` | `_anyQuery` | no | [`_searchPhonedb`](#_searchphonedb) / [`_fetchPhonedbDetail`](#_fetchphonedbdetail) |
  | `Wikipedia` | `_anyQuery` | yes | [`_searchWikipedia`](#_searchwikipedia) / [`_fetchWikipediaDetail`](#_fetchwikipediadetail) |

  The Apple entry is not `const` because its `appliesTo` is a closure.

### `static List<String> get sourceNames` <a id="sourcenames"></a>
- **Kind:** static getter of `DeviceSearchService`.
- **Source:** line 302.
- **Purpose:** List the sources a search can query.
- **Inputs:** None.
- **Returns:** The names of the enabled sources, in result order.
- **Side effects:** None.
- **Notes:** Used by `test/device_search_sources_test.dart` and by `tool/test_live.dart`. It lists
  enabled sources whether or not they apply to a particular query.

### `static Map<String, String> headers({String accept = 'text/html'})` <a id="headers"></a>
- **Kind:** static method of `DeviceSearchService`.
- **Source:** line 316.
- **Purpose:** Build the headers every scraped request sends.
- **Inputs:** `accept` — the `Accept` header value (the Wikipedia calls pass `application/json`).
- **Returns:** A header map with the [`userAgent`](#useragent), accept and accept-language.
- **Side effects:** None.
- **Notes:** Centralised so the user agent cannot drift between the page fetch and any follow-up
  request for a resource discovered on that page.

### `static Future<DeviceSearchResponse> search(String query)` <a id="search"></a>
- **Kind:** static method of `DeviceSearchService`.
- **Source:** line 331.
- **Purpose:** Search every enabled source that applies to a query.
- **Inputs:** `query` — the user's search text.
- **Returns:** `Future<DeviceSearchResponse>` with merged results and one outcome per queried source.
- **Side effects:** Issues HTTP requests to the sources in [`_sources`](#_sources).
- **Algorithm:** 1. Return an empty response immediately when `AppFlavor.isStore`, or when the
  trimmed query is empty. 2. Open one `http.Client`. 3. Run the non-fallback sources: keep those
  that are enabled and whose `appliesTo` accepts the trimmed query, query them concurrently with
  `Future.wait`, and append their results and a `DeviceSourceOutcome` each, in registry order.
  4. If that produced no results, run the fallback sources the same way. 5. Close the client in a
  `finally`.
- **Usage:**
  ```dart
  final response = await DeviceSearchService.search('Galaxy Z Fold8');
  if (response.allSourcesFailed) { /* show why, per source */ }
  ```
- **Notes:** One shared client for the fan-out. A failing source never prevents another from
  returning results, because each source function catches its own transport errors and reports them
  as a status instead of throwing. The fallback step runs whenever the first step found nothing —
  whether the other sources answered `ok` with no matches or all failed — so Wikipedia can still
  answer when the other sources are blocked.

### `static Future<DeviceSearchResult> fetchDetail(DeviceSearchResult result)` <a id="fetchdetail"></a>
- **Kind:** static method of `DeviceSearchService`.
- **Source:** line 378.
- **Purpose:** Fetch the full detail page for a result the user selected.
- **Inputs:** `result` — a result previously returned by [`search`](#search).
- **Returns:** `Future<DeviceSearchResult>`, enriched when the fetch succeeded.
- **Side effects:** Issues one or two HTTP requests to the result's source.
- **Algorithm:** Look up the enabled registry entry whose `name` equals `result.source` and call its
  `detail` function over a fresh client, closed in a `finally`.
- **Notes:** Returns the input unchanged for store builds, a result with no `sourceUrl`, an unknown
  or disabled source, or any thrown error. The registry replaced the former `switch`, so a new
  source no longer needs a separate `case` here — but its search function must write the registry
  name into `source` (see [`_Source`](#_source-new)).

### `static DeviceSearchStatus _classifyError(Object error)` <a id="_classifyerror"></a>
- **Kind:** private static method.
- **Source:** line 404.
- **Purpose:** Classify a transport-level failure.
- **Inputs:** `error` — the thrown object.
- **Returns:** The matching `DeviceSearchStatus`.
- **Side effects:** None.
- **Notes:** Currently every recognised network fault and every unrecognised error alike map to
  `unreachable`. The branch is kept explicit so a future distinction (for example, treating a
  handshake failure differently) has an obvious home.

### `static Future<_SourceResponse> _searchNotebookcheck(...)` <a id="_searchnotebookcheck"></a>
- **Kind:** private static method.
- **Source:** line 422.
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
- **Source:** line 537.
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
- **Source:** line 575.
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
- **Source:** line 610.
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
- **Source:** line 701.
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

### `static Set<String> appleFamiliesFor(String query)` <a id="applefamiliesfor"></a>
- **Kind:** static method of `DeviceSearchService`.
- **Source:** line 751.
- **Purpose:** Tell which Apple Support documentation families a query asks about.
- **Inputs:** `query` — the user's search text.
- **Returns:** The `docs/<family>` segments to read (`iphone`, `ipad`, `mac`, `watch`, `airpods`);
  empty for a non-Apple query.
- **Side effects:** None.
- **Algorithm:** Split the lowercased query into runs of letters, de-duplicate them, and map each
  through `_appleFamilies` (`iphone`, `ipad`, `mac` / `macbook` / `imac`, `watch`, `airpods`).
  `watch` counts only when the query also contains the word `apple`.
- **Usage:**
  ```dart
  DeviceSearchService.appleFamiliesFor('MacBook Pro 14'); // {'mac'}
  DeviceSearchService.appleFamiliesFor('Apple');          // {}
  DeviceSearchService.appleFamiliesFor('Galaxy Watch 7'); // {}
  ```
- **Notes:** Keyed on the product word, not on "Apple", so "Apple Watch" and "MacBook Pro" both
  work and a bare "Apple" does not fetch every index. Because only letters count, `iPhone16` still
  matches `iphone`. "Watch" on its own is not Apple's: it needs "Apple" in the query too, so
  `Galaxy Watch 7` returns an empty set and the Apple source is not queried at all.

### `static Future<_SourceResponse> _searchApple(...)` <a id="_searchapple"></a>
- **Kind:** private static method.
- **Source:** line 774.
- **Purpose:** Search Apple's support documentation for Apple products.
- **Inputs:** `client`, `query`.
- **Returns:** `Future<_SourceResponse>`; empty and `ok` for a non-Apple query.
- **Side effects:** Issues one HTTP GET per matching product family, one after another.
- **Algorithm:** 1. Take the families from [`appleFamiliesFor`](#applefamiliesfor); none means an
  empty `ok`. 2. Remove the word "Apple" from the query used for relevance. 3. For each family, GET
  `support.apple.com/en-us/docs/<family>`; a 403 records `blocked`, another non-200 or a thrown
  error records `unreachable`, and a page that fails `isAppleDocsIndexPage` records
  `markupChanged` — each then moves on to the next family. 4. Read the page with
  `parseAppleDocsIndex`, strip a trailing ` Wi-Fi` or ` Wi-Fi + Cellular` from each name, drop
  names that are not `isRelevant`, deduplicate per family on the lowercased name, and score each by
  how many more tokens it has than the query. 5. If nothing was found and a family failed, return
  that failure; otherwise sort by the score, ties by original index, and return the first 8 as
  `ok`.
- **Notes:** Apple has no search endpoint for specs, but each family's docs index lists every
  model. Results carry `brand: 'Apple'`, the cleaned name as both `name` and `model`, the product
  docs page as `sourceUrl` and the 240 px index thumbnail. Ranking by extra tokens puts `iPhone 16`
  above `iPhone 16 Pro Max` for the query `iPhone 16`. A family failure is reported only when no
  family produced a result. Dart's `List.sort` is not stable, so ties are broken by each result's
  original index and equally scored names keep page order.

### `static Future<DeviceSearchResult> _fetchAppleDetail(...)` <a id="_fetchappledetail"></a>
- **Kind:** private static method.
- **Source:** line 859.
- **Purpose:** Read an Apple product's tech specs page.
- **Inputs:** `client`, `result`.
- **Returns:** `Future<DeviceSearchResult>`.
- **Side effects:** Issues two HTTP GETs: the product docs page, then its tech specs page.
- **Algorithm:** 1. GET `result.sourceUrl`. 2. Find the tech specs page link with
  `findAppleTechSpecsLink`. 3. GET that page and parse it with `parseAppleTechSpecs`. 4. Map it with
  [`withAppleSpecs`](#withapplespecs).
- **Notes:** A non-200 at either step, or a docs page with no tech specs link, returns the result
  unchanged; thrown errors reach [`fetchDetail`](#fetchdetail)'s `catch`.

### `static DeviceSearchResult withAppleSpecs(DeviceSearchResult result, AppleTechSpecs specs)` <a id="withapplespecs"></a>
- **Kind:** static method of `DeviceSearchService`.
- **Source:** line 889.
- **Purpose:** Map a parsed Apple tech specs page onto a search result.
- **Inputs:** `result` — the chosen result; `specs` — the parsed page.
- **Returns:** The enriched result, via [`withDetail`](#withdetail).
- **Side effects:** None.
- **Algorithm:** Replace non-breaking hyphens and non-breaking spaces in every line read, then map
  sections found with `appleSection`:

  | Section | Field | Rule |
  |---|---|---|
  | `Chip` | `chipset` | First line matching `<name> chip` → `Apple <name>` (`Apple A18`) |
  | `Chip` | `gpuName` | First `N-core GPU` → `<chipset> GPU (N-core)`; none without a chipset |
  | `Memory` | `ram` | First capacity on a line that mentions "memory" |
  | `Storage`, `Capacity` | `storage` | First capacity |
  | `Display` | `screenSize`, `screenResolutionW/H` | `N-inch` → `N"`; `W-by-H` |
  | `Battery and Power`, `Power and Battery`, `Battery` | `battery` | `N-watt-hour` → `N Wh`, otherwise the first `parseBattery` hit |
  | `Operating System` | `os` | First line, only when at most 40 characters |
  | (page) | `imageUrl` | The page's product render |

- **Notes:** Public for tests. Chip names are written the way the bundled presets spell them
  (`Apple A18`, `Apple M4 Pro GPU (16-core)`), so the editor can match a preset. The base
  configuration is used where Apple lists several. Phones list playback hours rather than a
  capacity, which `parseBattery` does not read, so they get no battery. Apple states only the
  introduction year, which is not a release date, so `releaseDate` stays unset.

### `static Future<_SourceResponse> _searchWikipedia(...)` <a id="_searchwikipedia"></a>
- **Kind:** private static method.
- **Source:** line 993.
- **Purpose:** Search English Wikipedia for an article about the device.
- **Inputs:** `client`, `query`.
- **Returns:** `Future<_SourceResponse>` with article titles as results.
- **Side effects:** Issues one HTTP GET to the MediaWiki API (`_wikipediaApi`).
- **Algorithm:** 1. GET `action=query&list=search` limited to 8 main-namespace hits. 2. Map 403 to
  `blocked`, other non-200 and thrown errors to `unreachable`, and undecodable JSON or a missing
  `query.search` list to `markupChanged`. 3. For each hit, drop a trailing disambiguation
  parenthetical such as `(smartphone)` and restore the lowercase `i` MediaWiki capitalises away
  (`IPhone 16` → `iPhone 16`). 4. Keep it when the title contains every query word, or when it has
  at least two words and every one of them is in the query. 5. Split brand and model with
  `splitBrandModel` and link the article under `en.wikipedia.org/wiki/`.
- **Notes:** The reverse match is what lets `Steam Deck OLED` find the `Steam Deck` article; the
  two-word floor stops a one-word title such as `Steam` matching everything. No review or
  deduplication gate is applied; MediaWiki returns each article once.

### `static Future<DeviceSearchResult> _fetchWikipediaDetail(...)` <a id="_fetchwikipediadetail"></a>
- **Kind:** private static method.
- **Source:** line 1070.
- **Purpose:** Read a Wikipedia article's infobox and lead image.
- **Inputs:** `client`, `result`.
- **Returns:** `Future<DeviceSearchResult>`; unchanged when the article has no device infobox.
- **Side effects:** Issues two HTTP GETs to the MediaWiki API.
- **Algorithm:** 1. Take the title from the last path segment of `sourceUrl`. 2. GET
  `action=parse&prop=wikitext&section=0&redirects=1` — the lead section only. 3. Pull the infobox
  with `extractWikiInfobox`; stop unless `isWikiDeviceInfobox` accepts it. 4. In a `try`, GET
  `prop=pageimages` with `pithumbsize=800` for the page image. 5. Map with
  [`withWikipediaInfobox`](#withwikipediainfobox).
- **Notes:** Rendering the page image at 800 px turns an SVG original into a PNG the app can
  decode. An image failure still returns the specs. The device-infobox check is what stops a
  redirect to a company article (`Framework Laptop 13` → the company) from being read as specs.

### `static DeviceSearchResult withWikipediaInfobox(...)` <a id="withwikipediainfobox"></a>
- **Kind:** static method of `DeviceSearchService`.
- **Source:** line 1144.
- **Purpose:** Map a Wikipedia infobox onto a search result.
- **Inputs:** `result`; `infobox` from `extractWikiInfobox`; optional `imageUrl`.
- **Returns:** The enriched result.
- **Side effects:** None.
- **Algorithm:** Rebuild the result with the infobox brand (the model loses a leading brand
  prefix), then merge with [`withDetail`](#withdetail):

  | Infobox parameters (in priority order) | Field | Parser |
  |---|---|---|
  | `developer`, `brand`, `manufacturer` | `brand` | `wikiField`, `wikiBrand` |
  | `soc`, `system_on_chip`, `cpu`, `processor` | `chipset` | `wikiField`, `parseChipName` |
  | `gpu`, `graphics` | `gpuName` | `wikiField`, `parseChipName` |
  | `memory`, `ram` | `ram` | `wikiField`, `parseCapacity` |
  | `storage` | `storage` | `wikiField`, `parseCapacity` |
  | `display`, `screen` | `screenSize`, `screenResolutionW/H` | `wikiFieldText` with `×` → `x`, then `parseWikiScreenSize`, `parseResolution` |
  | `battery`, `power` | `battery` | `wikiFieldText`, `parseBattery` |
  | `os`, `operating_system`, `operatingsystem` | `os` | `wikiField` |
  | `released`, `releasedate`, `release_date`, `first_release`, `release`, `introduced` | `releaseDate` | `wikiField`, `parseWikiDate` |

- **Notes:** Public for tests. Where a product has variants (an LCD and an OLED model) the first
  listed one is read. The maker comes from `developer` before `manufacturer`, which is often a
  contract manufacturer such as Foxconn. Without a brand in the infobox, the search step's
  `splitBrandModel` guess is kept.

## Related

- [`device_search_parsers.md`](device_search_parsers.md) — all markup parsing, unit-tested against fixtures.
- [`../views/device_search_dialog.md`](../views/device_search_dialog.md) — the two-phase UI and field toggles.
- [`chip_search_service.md`](chip_search_service.md) — the CPU/GPU sibling feature.
- [`preset_service.md`](preset_service.md) — the offline bundled-template counterpart.
- [Online Search and Presets](../../../../features/online-search-and-presets.md)
