# lib/features/devices/services/device_search_service.dart

`DeviceSearchService` scrapes device specs (phones, laptops, tablets) from two public sites —
GSMArena and Notebookcheck — run concurrently, each individually error-swallowed. It has no bundled
API key; every result comes from parsing the sites' HTML directly. See
[Online Search and Presets](../../../../features/online-search-and-presets.md#device-spec-search---device_search_servicedart)
for the concept overview, and [`../../models/device.md`](../models/device.md) for the
`CpuInfo`/`GpuInfo`/`StorageInfo` shapes a `DeviceSearchResult` ultimately fills into a `Device` via
the device edit page (not in this file).

**Store-flavor gating**: both public entry points, [`search`](#search) and
[`fetchDetail`](#fetchdetail), return early — an empty list and the unmodified input result,
respectively — when `AppFlavor.isFull` is false (i.e. `AppFlavor.isStore` is true), confirmed
directly in source. This is one of the four gating checks required by `AGENTS.md`'s Build Flavors
section (see [Architecture](../../../../architecture.md#appflavor) for `AppFlavor`); the other
three are [`chip_search_service.md`](chip_search_service.md)'s `AppFlavor.isFull` check and two UI
call sites (`device_edit_page.dart`'s three online-search buttons, `device_list_page.dart`'s online
search FAB) that are outside this file and were not re-verified as part of this batch.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`DeviceSearchResult`](#devicesearchresult-new) | constructor | A | Create a `DeviceSearchResult` instance. |
| [`withDetail`](#withdetail) | method (`DeviceSearchResult`) | A | Create a copy with detail-page fields filled in, marking `detailFetched: true`. |
| [`search`](#search) | static method | A | Search GSMArena and Notebookcheck concurrently for quick results. |
| [`fetchDetail`](#fetchdetail) | static method | A | Fetch full detail for a search result by scraping its detail page. |
| [`_searchGSMArena`](#_searchgsmarena) | static method (private) | A | Scrape GSMArena's quick-search results page. |
| [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail) | static method (private) | A | Scrape a GSMArena device detail page for full specs. |
| [`_spec`](#_spec) | static method (private) | A | Extract one `data-spec="key"` value from GSMArena detail HTML. |
| [`_splitBrandModel`](#_splitbrandmodel) | static method (private) | A | Split a device name into brand and model at the first space. |
| [`_parseMemory`](#_parsememory) | static method (private) | A | Parse a combined storage+RAM string into separate RAM/storage values. |
| [`_parseScreenSize`](#_parsescreensize) | static method (private) | A | Extract a screen size in inches from free text. |
| [`_parseResolution`](#_parseresolution) | static method (private) | A | Extract a `W x H` resolution pair from free text. |
| [`_parseBattery`](#_parsebattery) | static method (private) | A | Extract a battery capacity in mAh from free text. |
| [`_parseReleaseDate`](#_parsereleasedate) | static method (private) | A | Parse a GSMArena release-date string into a `DateTime`. |
| [`_parseMonth`](#_parsemonth) | static method (private) | A | Map an English month name to its 1-based number. |
| [`_isDeviceImage`](#_isdeviceimage) | static method (private) | A | Reject ad/affiliate/tracking image URLs, accept genuine device photos. |
| [`_stripHtml`](#_striphtml) | static method (private) | A | Strip HTML tags and entities from a fragment, collapsing whitespace. |
| [`_searchNotebookcheck`](#_searchnotebookcheck) | static method (private) | A | Scrape Notebookcheck's laptop-search results table. |
| [`_fetchNotebookcheckDetail`](#_fetchnotebookcheckdetail) | static method (private) | A | Extract the device image from a Notebookcheck detail page's JSON-LD. |

Row count (18) does not match `grep -c 'Purpose:' device_search_service.dart` (16): the
`DeviceSearchResult` constructor and its `withDetail` method (the first two rows) have no
`/// Purpose:` doc-comment block — every method of `DeviceSearchService` itself does.

## Documentation

### `const DeviceSearchResult({required this.source, this.sourceUrl, ..., this.detailFetched = false})` <a id="devicesearchresult-new"></a>
- **Kind:** constructor of `DeviceSearchResult`.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 28).
- **Purpose:** Hold one search result from an online device database — source name/URL, thumbnail,
  and (once fetched) full detail fields.
- **Inputs:** `source` required; every spec field optional; `detailFetched` defaults to `false`.
- **Returns:** A new `DeviceSearchResult`.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Constructed by [`_searchGSMArena`](#_searchgsmarena) and
  [`_searchNotebookcheck`](#_searchnotebookcheck) for each quick result; consumed by the device
  search dialog UI, which calls [`fetchDetail`](#fetchdetail) when the user picks one.
- **Notes:** This declaration has no `/// Purpose:` doc comment in source (see the row-count note
  above the Declarations table).

### `DeviceSearchResult withDetail({String? imageUrl, ..., DateTime? releaseDate})` <a id="withdetail"></a>
- **Kind:** method of `DeviceSearchResult`.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 49).
- **Purpose:** Create a copy of this result with detail-page fields filled in, marking
  `detailFetched: true` so the UI knows full detail has been loaded.
- **Inputs:** All detail fields optional; each falls back to the existing value via `?? this.xxx`
  if not provided.
- **Returns:** A new `DeviceSearchResult` — `source`/`sourceUrl`/`name`/`brand`/`model`/
  `thumbnailUrl` are always carried over unchanged from `this` (not replaceable through this
  method); `detailFetched` is unconditionally `true` on the result.
- **Side effects:** None.
- **Algorithm:** Construct a new `DeviceSearchResult`, copying identity/quick-search fields
  verbatim and applying `field ?? this.field` for every detail field.
- **Usage:**
  ```dart
  return result.withDetail(
    imageUrl: deviceImageUrl,
    chipset: chipset,
    gpuName: gpu,
    ram: ram,
    storage: storage,
    screenSize: screenSize,
    screenResolutionW: resW,
    screenResolutionH: resH,
    battery: battery,
    os: os,
    releaseDate: releaseDate,
  );
  ```
  (from [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail); [`_fetchNotebookcheckDetail`](#_fetchnotebookcheckdetail)
  calls it too, re-passing the already-parsed inline specs so they aren't lost)
- **Notes:** This declaration has no `/// Purpose:` doc comment in source. Unlike a typical
  `copyWith`, the identity fields (`source`, `name`, `brand`, `model`, `thumbnailUrl`) are not
  parameters at all here — only detail fields can be set through this method, by design, since
  detail fetching should never change which device the result refers to.

### `static Future<List<DeviceSearchResult>> search(String query)` <a id="search"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 95).
- **Purpose:** Search for devices by name across GSMArena and Notebookcheck concurrently, returning
  quick results (name, brand/model, thumbnail — no full spec detail yet).
- **Inputs:** `query`.
- **Returns:** `Future<List<DeviceSearchResult>>` — the concatenation of both sources' results;
  `[]` immediately for store-flavor builds.
- **Side effects:** Two concurrent HTTP requests (one per source) when not store-flavor.
- **Algorithm:** 1. If `AppFlavor.isStore`, return `[]` immediately — no network call at all. 2.
  Otherwise run `_searchGSMArena`/`_searchNotebookcheck` concurrently via `Future.wait`, each
  wrapped in `.catchError((_) => <DeviceSearchResult>[])` so one source failing doesn't fail the
  other. 3. Flatten (`expand`) both result lists into one.
- **Usage:** Called from the device search dialog when the user submits a query (see
  [Online Search and Presets](../../../../features/online-search-and-presets.md#device-spec-search---device_search_servicedart)).
- **Notes:** The store-flavor check happens *before* either network call is attempted — a store
  build never even constructs the request, not merely discards the response.

### `static Future<DeviceSearchResult> fetchDetail(DeviceSearchResult result)` <a id="fetchdetail"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 110).
- **Purpose:** Fetch full spec detail for a previously found search result by scraping its detail
  page, dispatching to the right scraper based on `result.source`.
- **Inputs:** `result` — typically one returned by [`search`](#search).
- **Returns:** `Future<DeviceSearchResult>` — the unmodified `result` for store-flavor builds, a
  missing `sourceUrl`, or an unrecognized `source`; otherwise the detail-enriched result.
- **Side effects:** One HTTP request to the result's detail page, for a recognized non-store case.
- **Algorithm:** 1. If `AppFlavor.isStore` or `result.sourceUrl == null`, return `result` unchanged.
  2. `switch (result.source)`: `'GSMArena'` → `_fetchGSMArenaDetail`; `'Notebookcheck'` →
  `_fetchNotebookcheckDetail`; anything else → return `result` unchanged.
- **Usage:** Called by the device search dialog after the user picks a quick result, before
  prefilling the device edit form.
- **Notes:** An unrecognized `source` string degrading to a no-op (rather than throwing) means a
  future third source added to `search()` without a matching `fetchDetail` case would silently
  never fetch detail, not crash.

### `static Future<List<DeviceSearchResult>> _searchGSMArena(String query)` <a id="_searchgsmarena"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 132).
- **Purpose:** Query GSMArena's quick-search endpoint and parse the `<div class="makers">` results
  list into up to 10 `DeviceSearchResult`s.
- **Inputs:** `query`.
- **Returns:** `Future<List<DeviceSearchResult>>` — `[]` on a non-200 response or no `makers` div
  found.
- **Side effects:** One HTTP GET to `gsmarena.com/results.php3` with a spoofed desktop
  `User-Agent` and a 15s timeout.
- **Algorithm:** 1. GET the quick-search URL. 2. Regex-extract the `<div class="makers">...</div>`
  block. 3. Iterate `<li>` entries inside it (capped at 10). 4. Per entry, regex-extract `href`,
  `<img src>`, and the `<span>` name (which may contain a `<br>` between brand/model — tags
  stripped and whitespace collapsed). 5. Split the cleaned name into brand/model via
  [`_splitBrandModel`](#_splitbrandmodel) and build a `DeviceSearchResult` with `source:
  'GSMArena'`.
- **Usage:** Called by [`search`](#search) via `Future.wait`.
- **Notes:** Parsing is regex-based HTML scraping, not a real HTML parser — it depends on
  GSMArena's current markup structure (`class="makers"`, `<li>`/`<span>`/`<img>` shape) and would
  silently start returning `[]` if that markup changes, rather than raising an error.

### `static Future<DeviceSearchResult> _fetchGSMArenaDetail(DeviceSearchResult result)` <a id="_fetchgsmarenadetail"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 206).
- **Purpose:** Fetch a GSMArena device's detail page and extract its main photo plus chipset,
  GPU, memory, screen, battery, OS, and release-date specs.
- **Inputs:** `result` — `result.sourceUrl!` must be set.
- **Returns:** `Future<DeviceSearchResult>` — `result` unchanged on a non-200 response, else the
  result of [`withDetail`](#withdetail) with every parsed field.
- **Side effects:** One HTTP GET to the detail URL, 15s timeout.
- **Algorithm:** 1. GET the page. 2. Find the first `specs-photo-main` image URL that
  [`_isDeviceImage`](#_isdeviceimage) accepts (skipping ad/affiliate images). 3. Extract
  `chipset`/`gpu`/`internalmemory`/`displaysize`/`displayresolution`/`batdescription1`/`os` via
  [`_spec`](#_spec). 4. Parse memory via [`_parseMemory`](#_parsememory), screen size via
  [`_parseScreenSize`](#_parsescreensize), resolution via [`_parseResolution`](#_parseresolution),
  battery via [`_parseBattery`](#_parsebattery). 5. Parse the release date from `released-hl`
  (falling back to `status` if absent) via [`_parseReleaseDate`](#_parsereleasedate). 6. Call
  `result.withDetail(...)` with everything gathered.
- **Usage:** Called by [`fetchDetail`](#fetchdetail) for `result.source == 'GSMArena'`.
- **Notes:** The main-image search iterates *all* `specs-photo-main` image matches and picks the
  first one [`_isDeviceImage`](#_isdeviceimage) accepts, rather than blindly taking the first
  match — this is what filters out ad/tracking images that sometimes appear before the real device
  photo in that markup region.

### `static String? _spec(String html, String key)` <a id="_spec"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 271).
- **Purpose:** Extract one `data-spec="key"` value from GSMArena detail-page HTML.
- **Inputs:** `html`, `key` — the spec attribute name (e.g. `'chipset'`).
- **Returns:** `String?` — `null` if not found or the cleaned value is empty.
- **Side effects:** None.
- **Algorithm:** Regex-match `data-spec="$key"[^>]*>\s*(.+?)\s*</(?:td|span|div|li)>` (non-greedy,
  dot-all), then strip inner tags and collapse whitespace on the captured group.
- **Usage:** Called repeatedly by [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail), once per spec
  key.
- **Notes:** Matches whichever of `td`/`span`/`div`/`li` closes the value first — GSMArena uses
  different wrapper elements for different spec rows.

### `static (String?, String?) _splitBrandModel(String name)` <a id="_splitbrandmodel"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 293).
- **Purpose:** Split a device's full display name into brand and model at the first space.
- **Inputs:** `name`.
- **Returns:** `(String?, String?)` record — `(name, null)` if there's no space at all.
- **Side effects:** None.
- **Algorithm:** Find the first space; split there.
- **Usage:** Called by both [`_searchGSMArena`](#_searchgsmarena) and
  [`_searchNotebookcheck`](#_searchnotebookcheck).
- **Notes:** A naive first-space split — multi-word brands (rare in this domain) would be split
  incorrectly, but this matches how GSMArena/Notebookcheck names are conventionally formatted
  (`"Brand Model..."`).

### `static (String? ram, String? storage) _parseMemory(String? raw)` <a id="_parsememory"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 304).
- **Purpose:** Parse GSMArena's combined `internalmemory` spec text (e.g. `"128GB 8GB RAM, ..."`)
  into separate storage and RAM values.
- **Inputs:** `raw` — nullable free text; only the first comma-separated segment is considered.
- **Returns:** `(String? ram, String? storage)` record — both `null` if no pattern matches.
- **Side effects:** None.
- **Algorithm:** Try three regex patterns in order against the first comma segment: 1. `"<N>GB
  <M>GB RAM"` → `(ram: M GB, storage: N GB)`. 2. `"<N>TB <M>GB RAM"` → `(ram: M GB, storage: N
  TB)`. 3. RAM-only `"<N>(GB|MB) RAM"` (matched against the full `raw`, not just the first segment)
  → `(ram: N <unit>, storage: null)`. Returns `(null, null)` if none match.
- **Usage:** Called by [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail).
- **Notes:** The storage-first ordering in the first two patterns (`storage GB/TB` before `RAM
  GB`) matches GSMArena's own convention of listing storage capacity before RAM in that field.

### `static String? _parseScreenSize(String? raw)` <a id="_parsescreensize"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 343).
- **Purpose:** Extract a screen size in inches from GSMArena's `displaysize` spec text.
- **Inputs:** `raw` — nullable.
- **Returns:** `String?` — e.g. `'6.7"'`, or `null` if no `"<number> inches"` pattern is found.
- **Side effects:** None.
- **Algorithm:** Regex `([\d.]+)\s*inches`; wrap the captured number in a trailing `"`.
- **Usage:** Called by [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail).
- **Notes:** Produces the same `N"` shape [`../../models/device.md#_parsescreendiagonal`](../models/device.md)
  expects to parse back out for `Device.ppi` — both sides of that round trip live in different
  files but depend on the same trailing-quote convention.

### `static (int?, int?) _parseResolution(String? raw)` <a id="_parseresolution"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 354).
- **Purpose:** Extract a `width x height` resolution pair from GSMArena's `displayresolution` spec
  text.
- **Inputs:** `raw` — nullable.
- **Returns:** `(int?, int?)` record — `(null, null)` if no `"<N> x <M>"` pattern matches.
- **Side effects:** None.
- **Algorithm:** Regex `(\d+)\s*x\s*(\d+)`; parse both captured groups as `int`.
- **Usage:** Called by [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail).
- **Notes:** None.

### `static String? _parseBattery(String? raw)` <a id="_parsebattery"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 366).
- **Purpose:** Extract a battery capacity in mAh from GSMArena's `batdescription1` spec text.
- **Inputs:** `raw` — nullable.
- **Returns:** `String?` — e.g. `'5000 mAh'`, or `null` if no `"<N> mAh"` pattern matches.
- **Side effects:** None.
- **Algorithm:** Regex `(\d+)\s*mAh`.
- **Usage:** Called by [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail).
- **Notes:** None.

### `static DateTime? _parseReleaseDate(String? raw)` <a id="_parsereleasedate"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 377).
- **Purpose:** Parse GSMArena's free-text release-date spec (e.g. `"Released 2024, September 20"`
  or `"2024, September"`) into a `DateTime`.
- **Inputs:** `raw` — nullable.
- **Returns:** `DateTime?` — `null` if neither pattern matches or the month name isn't recognized.
- **Side effects:** None.
- **Algorithm:** 1. Try the full pattern `(\d{4}),?\s+(\w+)\s+(\d{1,2})` (year, month name, day);
  if matched and the month resolves via [`_parseMonth`](#_parsemonth), return `DateTime(year,
  month, day)`. 2. Otherwise try the year-month-only pattern `(\d{4}),?\s+(\w+)`; if matched and
  the month resolves, return `DateTime(year, month)` (day defaults to the 1st). 3. Otherwise
  `null`.
- **Usage:** Called by [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail).
- **Notes:** A resolvable year+month but unresolvable day pattern still falls through to the
  year-month-only attempt on the *original* `raw` string, not on a partially-matched remainder —
  both regexes are tried independently against the same input.

### `static int? _parseMonth(String m)` <a id="_parsemonth"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 401).
- **Purpose:** Map a full English month name to its 1-based calendar number.
- **Inputs:** `m` — case-insensitive.
- **Returns:** `int?` — `null` if not one of the 12 recognized English month names.
- **Side effects:** None.
- **Algorithm:** Fixed `const` lookup map keyed by lowercase month name, indexed by
  `m.toLowerCase()`.
- **Usage:** Called twice by [`_parseReleaseDate`](#_parsereleasedate).
- **Notes:** Only recognizes English month names — GSMArena's site is English-language, so this is
  not a localization gap in practice, but it would be if a non-English source were ever added.

### `static bool _isDeviceImage(String url)` <a id="_isdeviceimage"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 425).
- **Purpose:** Decide whether an image URL from a GSMArena detail page is a genuine device photo,
  rejecting ad/affiliate/tracking images.
- **Inputs:** `url`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** 1. Reject (`false`) if the lowercased URL contains any of a fixed blocklist:
  `amazon`, `amzn`, `affiliate`, `banner`, `advert`, `tracking`, `click.`, `/ad/`, `doubleclick`,
  `googlesyndication`. 2. Accept (`true`) if it contains `gsmarena.com`/`fdn.gsmarena.com`
  (GSMArena's own CDN). 3. Accept (`true`) if it ends in `.jpg`/`.jpeg`/`.png`/`.webp` (any host).
  4. Otherwise reject (`false`).
- **Usage:** Called by [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail) while scanning candidate
  `specs-photo-main` image URLs.
- **Notes:** The blocklist check runs *before* the GSMArena-CDN allowlist check, so a URL that
  somehow matched both (e.g. contained `gsmarena.com` and also `tracking`) would still be rejected
  — blocklist takes priority.

### `static String _stripHtml(String html)` <a id="_striphtml"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 459).
- **Purpose:** Strip HTML tags and common entities from an HTML fragment, collapsing whitespace
  down to single spaces.
- **Inputs:** `html`.
- **Returns:** `String` — trimmed plain text.
- **Side effects:** None.
- **Algorithm:** Chained `replaceAll`: strip `<...>` tags, strip named entities (`&[a-zA-Z]+;`),
  strip numeric entities (`&#\d+;`), collapse runs of whitespace to one space, trim.
- **Usage:** Called by [`_searchNotebookcheck`](#_searchnotebookcheck) to clean the inline-specs
  text following a result row's `<br/>`.
- **Notes:** Named/numeric HTML entities are stripped entirely (not decoded to their character) —
  e.g. `&amp;` becomes empty, not `&`. This is acceptable for the numeric spec text this function
  is used on in practice, but would corrupt text containing real punctuation entities.

### `static Future<List<DeviceSearchResult>> _searchNotebookcheck(String query)` <a id="_searchnotebookcheck"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 477).
- **Purpose:** Query Notebookcheck's Laptop Search tool (which also covers tablets, phones, and
  smartwatches) and parse its results table into up to 8 `DeviceSearchResult`s with inline specs.
- **Inputs:** `query`.
- **Returns:** `Future<List<DeviceSearchResult>>` — `[]` on a non-200 response.
- **Side effects:** One HTTP GET to `notebookcheck.net/Laptop_Search.8223.0.html`, 15s timeout.
- **Algorithm:** 1. GET the search URL. 2. Regex-iterate `<tr>` rows whose class contains
  `odd`/`even` (capped at 8 results). 3. Skip separator rows (containing both `nb_model` and
  `colspan`). 4. Extract the result link/name via regex; skip if the name is empty, too short
  (`< 3` chars), too long (`> 80` chars), or matches a review-article keyword regex
  (`review|comparison|versus|benchmark|test[:\s]`, case-insensitive) — filtering out review
  articles that also match the row pattern. 5. If the row contains `<br/>`, strip HTML from the
  text after it via [`_stripHtml`](#_striphtml) and split on commas: part 0 → `gpuName`, part 1 →
  `chipset`; scan remaining parts for a `"<size>\" <W>x<H>"` pattern to fill `screenSize`/
  `screenResolutionW`/`screenResolutionH`, stopping at the first match. 6. Split the name via
  [`_splitBrandModel`](#_splitbrandmodel) and build the result with `source: 'Notebookcheck'`.
- **Usage:** Called by [`search`](#search) via `Future.wait`.
- **Notes:** The review-article filter (name length/keyword checks) exists because
  Notebookcheck's search results table can include review article rows alongside genuine device
  entries, and those would otherwise be indistinguishable from a device by row structure alone.

### `static Future<DeviceSearchResult> _fetchNotebookcheckDetail(DeviceSearchResult result)` <a id="_fetchnotebookcheckdetail"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_search_service.dart` (line 587).
- **Purpose:** Fetch a Notebookcheck detail page and extract its device image from embedded
  JSON-LD `Product` structured data, keeping the inline specs already parsed during search.
- **Inputs:** `result` — `result.sourceUrl!` must be set.
- **Returns:** `Future<DeviceSearchResult>` — `result` unchanged on a non-200 response, else the
  result of [`withDetail`](#withdetail) with just `imageUrl` newly set (specs re-passed unchanged).
- **Side effects:** One HTTP GET to the detail URL, 15s timeout.
- **Algorithm:** 1. GET the page. 2. Regex-find every `<script type="application/ld+json">` block.
  3. For each, try to `jsonDecode` it inside a `try`/`catch` (skipping non-JSON or parse-failed
  blocks silently); if it decodes and `data['@type'] == 'Product'`, extract `image` — either a
  string directly or a `{"url": ...}` object — and stop scanning further blocks. 4. Call
  `result.withDetail(imageUrl: imageUrl, chipset: result.chipset, gpuName: result.gpuName,
  screenSize: result.screenSize, screenResolutionW: result.screenResolutionW,
  screenResolutionH: result.screenResolutionH)` — explicitly re-passing the already-known inline
  specs so `withDetail`'s `?? this.xxx` fallback isn't even needed for them.
- **Usage:** Called by [`fetchDetail`](#fetchdetail) for `result.source == 'Notebookcheck'`.
- **Notes:** Unlike GSMArena's regex-scraped detail page, this uses the page's own structured
  JSON-LD data for the image — more robust to markup changes for that one field, but Notebookcheck
  detail pages otherwise contribute no additional spec fields beyond what search already parsed
  (chipset/GPU/screen come only from the search results row).
