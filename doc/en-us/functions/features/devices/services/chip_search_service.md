# lib/features/devices/services/chip_search_service.dart

`ChipSearchService` searches bundled CPU/GPU presets first, then — for full-flavor builds only —
queries TechPowerUp, AMD's official site, and Intel's official site in parallel, using Startpage as
a URL-discovery proxy (this service issues no direct search-engine-provided API calls; it scrapes
Startpage's own results page). See
[Online Search and Presets](../../../../features/online-search-and-presets.md#chip-spec-search---chip_search_servicedart)
for the concept overview, and [`../../models/device.md`](../models/device.md) for the
`CpuInfo`/`GpuInfo` shapes `ChipSearchResult.toCpuInfo`/`toGpuInfo` produce.

**Store-flavor gating**: unlike
[`device_search_service.md`](device_search_service.md)'s early-return pattern, the two public entry
points here, [`searchCpu`](#searchcpu) and [`searchGpu`](#searchgpu), always run their local
`presets` search regardless of flavor — only the *online* portion is wrapped in
`if (AppFlavor.isFull) { ... }`, confirmed directly in source. This is one of the four gating
checks required by `AGENTS.md`'s Build Flavors section (see
[Architecture](../../../../architecture.md#appflavor) for `AppFlavor`); the other three are
[`device_search_service.md`](device_search_service.md)'s early returns and two UI call sites
(`device_edit_page.dart`'s three online-search buttons, `device_list_page.dart`'s online search
FAB) outside this file, not re-verified as part of this batch.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`ChipSearchResult`](#chipsearchresult-new) | constructor | A | Create a `ChipSearchResult` instance. |
| [`toCpuInfo`](#tocpuinfo) | method (`ChipSearchResult`) | A | Convert this result into a `CpuInfo`. |
| [`toGpuInfo`](#togpuinfo) | method (`ChipSearchResult`) | A | Convert this result into a `GpuInfo`. |
| [`searchCpu`](#searchcpu) | static method | A | Search bundled CPU presets, then (full flavor only) TechPowerUp/AMD/Intel in parallel. |
| [`searchGpu`](#searchgpu) | static method | A | Search bundled GPU presets, then (full flavor only) TechPowerUp/AMD in parallel. |
| [`_findTechPowerUpUrl`](#_findtechpowerupurl) | static method (private) | A | Discover a TechPowerUp spec-page URL via a Startpage search. |
| [`_searchTechPowerUpCpu`](#_searchtechpowerupcpu) | static method (private) | A | Scrape a TechPowerUp CPU spec page's `th`/`td` table. |
| [`_searchTechPowerUpGpu`](#_searchtechpowerupgpu) | static method (private) | A | Scrape a TechPowerUp GPU spec page's `og:title`/`og:description` meta tags. |
| [`_findAmdUrl`](#_findamdurl) | static method (private) | A | Discover an AMD official product-page URL via a Startpage search. |
| [`_parseAmdSpecs`](#_parseamdspecs) | static method (private) | A | Parse AMD's `dt`/`dd` spec pairs, truncating embedded tooltip text. |
| [`_searchAmdCpu`](#_searchamdcpu) | static method (private) | A | Scrape an AMD CPU product page, gated on an AMD/Ryzen/EPYC/Athlon/Threadripper keyword. |
| [`_searchAmdGpu`](#_searchamdgpu) | static method (private) | A | Scrape an AMD GPU product page, gated on an AMD/Radeon/RX keyword. |
| [`_searchIntelCpu`](#_searchintelcpu) | static method (private) | A | Derive CPU specs from an Intel product-page URL slug (page itself returns 403). |

Row count (13) does not match `grep -c 'Purpose:' chip_search_service.dart` (10):
[`_parseAmdSpecs`](#_parseamdspecs) has a plain one-line doc comment with no `/// Purpose:` block,
and [`_searchAmdCpu`](#_searchamdcpu)/[`_searchAmdGpu`](#_searchamdgpu) have no doc comment at all
— every other declaration in the file has the full `/// Purpose:` block.

## Documentation

### `const ChipSearchResult({required this.source, this.sourceUrl, this.model, this.architecture, this.frequency, this.performanceCores, this.efficiencyCores, this.threads, this.cache})` <a id="chipsearchresult-new"></a>
- **Kind:** constructor of `ChipSearchResult`.
- **Source:** `lib/features/devices/services/chip_search_service.dart` (line 27).
- **Purpose:** Hold one CPU or GPU search result — its source (`'preset'`/`'TechPowerUp'`/`'AMD'`/
  `'Intel'`), optional source URL, and whichever spec fields apply (GPU results only populate
  `model`/`architecture`).
- **Inputs:** `source` required; all spec fields optional.
- **Returns:** A new `ChipSearchResult`.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Constructed by every search method in this file (preset match, TechPowerUp, AMD,
  Intel); consumed by the chip search dialog via [`toCpuInfo`](#tocpuinfo)/[`toGpuInfo`](#togpuinfo).
- **Notes:** The same class models both CPU and GPU results — GPU searches simply leave
  `frequency`/`performanceCores`/`efficiencyCores`/`threads`/`cache` unset.

### `CpuInfo toCpuInfo()` <a id="tocpuinfo"></a>
- **Kind:** method of `ChipSearchResult`.
- **Source:** `lib/features/devices/services/chip_search_service.dart` (line 44).
- **Purpose:** Convert this chip search result into a `CpuInfo` for attaching to a `Device`.
- **Inputs:** None.
- **Returns:** `CpuInfo` (see [`../../models/device.md`](../models/device.md)) with every field
  copied straight across by name.
- **Side effects:** None.
- **Algorithm:** Direct field-to-field construction.
- **Usage:**
  ```dart
  Navigator.of(context).pop(result.toCpuInfo());
  ```
  (from `chip_search_dialog.dart`, when the user picks a CPU search result)
- **Notes:** `source`/`sourceUrl` are dropped — `CpuInfo` has no field for where the spec came
  from.

### `GpuInfo toGpuInfo()` <a id="togpuinfo"></a>
- **Kind:** method of `ChipSearchResult`.
- **Source:** `lib/features/devices/services/chip_search_service.dart` (line 59).
- **Purpose:** Convert this chip search result into a `GpuInfo` for attaching to a `Device`.
- **Inputs:** None.
- **Returns:** `GpuInfo` with only `model`/`architecture` copied (its only two fields).
- **Side effects:** None.
- **Algorithm:** `GpuInfo(model: model, architecture: architecture)`.
- **Usage:**
  ```dart
  Navigator.of(context).pop(result.toGpuInfo());
  ```
  (from `chip_search_dialog.dart`, when the user picks a GPU search result)
- **Notes:** Any CPU-only fields this result happens to carry (they shouldn't, for a GPU search)
  are silently ignored, not an error.

### `static Future<List<ChipSearchResult>> searchCpu(String query, List<CpuInfo> presets)` <a id="searchcpu"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/chip_search_service.dart` (line 83).
- **Purpose:** Search bundled CPU presets by substring match, then — for full-flavor builds — also
  query TechPowerUp/AMD/Intel in parallel, de-duplicating online results against presets already
  found.
- **Inputs:** `query`; `presets` — typically from `PresetService.loadCpus()` (see
  [`preset_service.md`](preset_service.md)).
- **Returns:** `Future<List<ChipSearchResult>>` — preset matches first, then any distinct online
  matches appended.
- **Side effects:** Three concurrent HTTP requests (via Startpage/TechPowerUp/AMD/Intel) when
  `AppFlavor.isFull`; none otherwise.
- **Algorithm:** 1. Case-insensitive substring-match `query` against every preset's `model`,
  building a `ChipSearchResult` with `source: 'preset'` for each hit. 2. If `AppFlavor.isFull`: run
  `_searchTechPowerUpCpu`/`_searchAmdCpu`/`_searchIntelCpu` concurrently via `Future.wait`, each
  wrapped in `.catchError((_) => null)`. 3. Track already-seen lowercased models (starting from the
  preset matches); for each non-null online result whose lowercased `model` isn't already present,
  append it and record its model as seen.
- **Usage:** Called from `chip_search_dialog.dart` when the user searches for a CPU during device
  editing.
- **Notes:** De-duplication is by lowercased exact `model` string match only — an online result
  whose model string differs even slightly from a preset's (e.g. extra whitespace, a suffix) is
  treated as distinct and included alongside the preset match, not merged with it.

### `static Future<List<ChipSearchResult>> searchGpu(String query, List<GpuInfo> presets)` <a id="searchgpu"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/chip_search_service.dart` (line 136).
- **Purpose:** Search bundled GPU presets by substring match, then — for full-flavor builds — also
  query TechPowerUp/AMD in parallel (no Intel GPU source), de-duplicating against presets.
- **Inputs:** `query`; `presets` — typically from `PresetService.loadGpus()`.
- **Returns:** `Future<List<ChipSearchResult>>`.
- **Side effects:** Two concurrent HTTP requests when `AppFlavor.isFull`; none otherwise.
- **Algorithm:** Same shape as [`searchCpu`](#searchcpu): preset substring match first, then (full
  flavor only) `_searchTechPowerUpGpu`/`_searchAmdGpu` concurrently, de-duplicated by lowercased
  `model`.
- **Usage:** Called from `chip_search_dialog.dart` when the user searches for a GPU.
- **Notes:** Only two online sources (no Intel GPU search exists in this file), unlike
  `searchCpu`'s three.

### `static Future<String?> _findTechPowerUpUrl(String query, String section)` <a id="_findtechpowerupurl"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/chip_search_service.dart` (line 183).
- **Purpose:** Discover a TechPowerUp spec-page URL for a query by searching Startpage with a
  `site:techpowerup.com/<section>` filter.
- **Inputs:** `query`; `section` — `'cpu-specs'` or `'gpu-specs'`.
- **Returns:** `Future<String?>` — the first matching URL, or `null` if none found / non-200
  response.
- **Side effects:** One HTTP POST to `startpage.com/sp/search`, 15s timeout.
- **Algorithm:** POST the search query (`"$query site:techpowerup.com/$section"`) to Startpage;
  regex-match the first `https://www.techpowerup.com/$section/....c\d+` URL in the response body.
- **Usage:** Called by both [`_searchTechPowerUpCpu`](#_searchtechpowerupcpu) and
  [`_searchTechPowerUpGpu`](#_searchtechpowerupgpu).
- **Notes:** Relies entirely on Startpage's own results-page HTML containing the target URL in
  plain text — no Startpage API is used, this is scraping a public search results page.

### `static Future<ChipSearchResult?> _searchTechPowerUpCpu(String query)` <a id="_searchtechpowerupcpu"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/chip_search_service.dart` (line 214).
- **Purpose:** Find and scrape a TechPowerUp CPU spec page's `th`/`td` table into a
  `ChipSearchResult`.
- **Inputs:** `query`.
- **Returns:** `Future<ChipSearchResult?>` — `null` if no URL found, non-200 response, or the
  parsed spec table is empty.
- **Side effects:** Two HTTP requests: the Startpage lookup (via
  [`_findTechPowerUpUrl`](#_findtechpowerupurl)) and the spec-page GET, 15s timeout.
- **Algorithm:** 1. Resolve the spec URL. 2. GET it. 3. Regex-iterate every `<th>...</th><td>...
  </td>` pair into a `specs` map (key/value both tag-stripped and whitespace-collapsed). 4. Model
  name from `<title>`, with a trailing `" Specs"` suffix stripped. 5. Architecture from
  `specs['Codename']`, overridden by `specs['Generation']` if present. 6. Frequency: base clock
  from `specs['Frequency']`; if a `'Turbo Clock'` other than `'N/A'` is also present, format as
  `"$base (boost $turbo)"`. 7. Cores/threads: `specs['# of Cores']`/`specs['# of Threads']` parsed
  as `int`; then, if hybrid-architecture keys `'Performance Cores'`/`'Efficiency Cores'` are
  present, they *override* the plain core count (regex-extracting the leading digit run, since
  those fields' values contain extra descriptive text). 8. Cache: join `'L2 <l2>'`/`'L3 <l3>'` with
  `' / '` for whichever of `Cache L2`/`Cache L3` are present.
- **Usage:** Called by [`searchCpu`](#searchcpu) (full flavor only), via `Future.wait`.
- **Notes:** The hybrid P/E-core override (step 7) means a CPU with both plain `'# of Cores'` and
  `'Performance Cores'`/`'Efficiency Cores'` keys reports the hybrid breakdown, not the flat count —
  this matters for modern hybrid-architecture CPUs where TechPowerUp publishes both.

### `static Future<ChipSearchResult?> _searchTechPowerUpGpu(String query)` <a id="_searchtechpowerupgpu"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/chip_search_service.dart` (line 327).
- **Purpose:** Find a TechPowerUp GPU spec page and extract model/architecture from its
  `og:title`/`og:description` Open Graph meta tags (rather than an HTML spec table).
- **Inputs:** `query`.
- **Returns:** `Future<ChipSearchResult?>` — `null` if no URL found, non-200 response, or either
  meta tag is missing.
- **Side effects:** Two HTTP requests (URL discovery + spec page GET).
- **Algorithm:** 1. Resolve the GPU spec URL via [`_findTechPowerUpUrl`](#_findtechpowerupurl)
  (`section: 'gpu-specs'`). 2. GET it. 3. Regex-extract `og:title` (model, with a trailing `"
  Specs"` suffix stripped) and `og:description` (a comma-separated spec summary). 4. Take the
  description's first comma-separated part as the chip name; strip a known vendor prefix
  (`'NVIDIA '`, `'AMD '`, `'Intel '`, `'Apple '`, `'Qualcomm '`) if present, using the remainder as
  `architecture`.
- **Usage:** Called by [`searchGpu`](#searchgpu) (full flavor only), via `Future.wait`.
- **Notes:** Uses meta tags instead of the `th`/`td` table `_searchTechPowerUpCpu` uses — GPU spec
  pages on TechPowerUp are not table-structured the same way CPU pages are, so this method only
  extracts `model`/`architecture`, not frequency/cores/cache.

### `static Future<String?> _findAmdUrl(String query, String category)` <a id="_findamdurl"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/chip_search_service.dart` (line 396).
- **Purpose:** Discover an AMD official product-page URL for a query via Startpage, filtered to
  `amd.com/en/products/<category>`.
- **Inputs:** `query`; `category` — `'processors'` or `'graphics'`.
- **Returns:** `Future<String?>` — the first matching, non-backslash-terminated URL, or `null`.
- **Side effects:** One HTTP POST to Startpage, 15s timeout.
- **Algorithm:** POST `"$query specifications site:amd.com/en/products/$category"` to Startpage;
  regex-match every `https://www.amd.com/en/products/....html` URL, filter out any ending in a
  literal backslash (a markup-escaping artifact), and return the first survivor.
- **Usage:** Called by both [`_searchAmdCpu`](#_searchamdcpu) and [`_searchAmdGpu`](#_searchamdgpu).
- **Notes:** The trailing-backslash filter exists specifically to reject a malformed match caused
  by how Startpage's result HTML escapes certain URLs — without it, a truncated/corrupted URL
  could be returned as if valid.

### `static Map<String, String> _parseAmdSpecs(String html)` <a id="_parseamdspecs"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/chip_search_service.dart` (line 420).
- **Purpose:** Parse AMD product pages' `<dt>`/`<dd>` spec label/value pairs into a map, truncating
  known tooltip text embedded inside the label.
- **Inputs:** `html`.
- **Returns:** `Map<String, String>` — empty if no pairs matched.
- **Side effects:** None.
- **Algorithm:** 1. Regex-iterate every `<dt>...</dt>\s*<dd>...</dd>` pair, tag-stripping and
  whitespace-collapsing both the key and value. 2. Skip a pair if either side is empty after
  cleaning. 3. For the key, scan a fixed list of known tooltip-start markers (`' Max boost '`, `'
  Represents '`, `' Boost Clock Frequency '`, `" 'Game Frequency'"`, `' AMD\`s product warranty'`,
  `' EPYC-'`, `' All-core boost'`) and truncate the key at the first one found — AMD's `<dt>`
  elements embed explanatory tooltip text directly after the actual label with no separating
  markup.
- **Usage:** Called by both [`_searchAmdCpu`](#_searchamdcpu) and [`_searchAmdGpu`](#_searchamdgpu).
- **Notes:** This declaration has no `/// Purpose:` doc-comment block in source — only a plain
  one-line `/// Parse AMD DT/DD spec pairs, cleaning tooltip noise.` comment (see the row-count
  note above the Declarations table). The tooltip-marker list is a fixed, hand-curated set found by
  inspecting AMD's actual markup — a new tooltip phrasing AMD introduces later would not be
  stripped until this list is updated.

### `static Future<ChipSearchResult?> _searchAmdCpu(String query)` <a id="_searchamdcpu"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/chip_search_service.dart` (line 459).
- **Purpose:** Scrape an AMD CPU product page for spec detail, but only when the query itself looks
  like an AMD CPU (avoids wasting a Startpage/AMD round trip on queries that obviously aren't AMD).
- **Inputs:** `query`.
- **Returns:** `Future<ChipSearchResult?>` — `null` if the query doesn't match the AMD-CPU keyword
  gate, no product URL is found, the page fetch fails, or the parsed spec map is empty.
- **Side effects:** Up to two HTTP requests (URL discovery + product page GET, 20s timeout).
- **Algorithm:** 1. Gate: lowercased `query` must contain at least one of `'amd'`, `'ryzen'`,
  `'epyc'`, `'athlon'`, `'threadripper'`, else return `null` immediately (no network call at all).
  2. Resolve the product URL via [`_findAmdUrl`](#_findamdurl) (`category: 'processors'`). 3. GET
  it; parse specs via [`_parseAmdSpecs`](#_parseamdspecs). 4. `model` from `specs['Name']`;
  `architecture` from `specs['Processor Architecture']`, falling back to `specs['Former
  Codename']`. 5. Frequency: base from `specs['Base Clock']`; if a boost clock
  (`specs['Max. Boost Clock']`) is also present, format `"$base (boost $boost)"`; if only boost is
  present (no base), use boost alone. 6. Cores/threads: `int.tryParse` on `specs['# of CPU
  Cores']`/`specs['# of Threads']`. 7. Cache: same `'L2 <l2>' / 'L3 <l3>'` join pattern as
  TechPowerUp's cache field, from `specs['L2 Cache']`/`specs['L3 Cache']`.
- **Usage:** Called by [`searchCpu`](#searchcpu) (full flavor only), via `Future.wait`, wrapped in
  `.catchError((_) => null)`.
- **Notes:** This declaration has no doc comment in source at all. The keyword gate (step 1) is the
  only one of the three online CPU sources that pre-filters by query content before making any
  network request — TechPowerUp and Intel's searches always attempt the network call regardless of
  query text.

### `static Future<ChipSearchResult?> _searchAmdGpu(String query)` <a id="_searchamdgpu"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/chip_search_service.dart` (line 525).
- **Purpose:** Scrape an AMD GPU product page for spec detail, gated on an AMD/Radeon/RX keyword in
  the query.
- **Inputs:** `query`.
- **Returns:** `Future<ChipSearchResult?>` — `null` if the keyword gate fails, no URL is found, the
  fetch fails, or specs are empty.
- **Side effects:** Up to two HTTP requests (20s timeout on the product page GET).
- **Algorithm:** 1. Gate: lowercased `query` must contain `'amd'`, `'radeon'`, or `'rx '` (note the
  trailing space on `'rx '`), else return `null` immediately. 2. Resolve the product URL via
  [`_findAmdUrl`](#_findamdurl) (`category: 'graphics'`). 3. GET it; parse via
  [`_parseAmdSpecs`](#_parseamdspecs). 4. `model` from `specs['Name']`; `architecture` from
  `specs['GPU Architecture']`, falling back to `specs['Series']` (e.g. `"Radeon RX 7000 Series"`)
  since AMD's GPU pages don't consistently expose a dedicated architecture field.
- **Usage:** Called by [`searchGpu`](#searchgpu) (full flavor only), via `Future.wait`, wrapped in
  `.catchError((_) => null)`.
- **Notes:** This declaration has no doc comment in source at all. The `'rx '` keyword (with a
  trailing space) is deliberately narrower than a bare `'rx'` substring match, presumably to avoid
  false-positives on unrelated words containing "rx".

### `static Future<ChipSearchResult?> _searchIntelCpu(String query)` <a id="_searchintelcpu"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/chip_search_service.dart` (line 568).
- **Purpose:** Derive CPU model/cache/frequency from an Intel product-page URL slug discovered via
  Startpage — the actual Intel page itself returns HTTP 403 and is never fetched, so all data comes
  from parsing the URL's path segments alone.
- **Inputs:** `query`.
- **Returns:** `Future<ChipSearchResult?>` — `null` if the keyword gate fails, the Startpage
  request fails, or no matching Intel spec URL pattern is found in the response.
- **Side effects:** One HTTP POST to Startpage, 15s timeout. No request is ever sent to
  `intel.com` itself.
- **Algorithm:** 1. Gate: lowercased `query` must contain one of `'intel'`, `'core'`, `'xeon'`,
  `'celeron'`, `'pentium'`, else return `null`. 2. POST
  `"$query specifications site:intel.com/content/www/us/en/products/sku"` to Startpage. 3.
  Regex-match an Intel spec URL of the shape
  `.../products/sku/<id>/<slug>/specifications.html`, capturing both the full URL and the `<slug>`.
  4. Derive the model name from the slug: strip everything from `-<N>m-cache` onward, split on
  `-`, map the literal token `'intel'` → `'Intel'` and `'processor'` → `''` (dropped), drop empty
  tokens, join with spaces; then capitalize known product-line tokens (`core`/`ultra`/`xeon`/
  `celeron`/`pentium`) via a case-insensitive regex replace; then reformat model numbers of the
  shape `i<digit><3+ digits><optional letters>` into `i<digit>-<digits><UPPERCASE letters>` (e.g.
  `"i52520m"` → `"i5-2520M"`). 5. Extract `cache` from the slug (`<N>m-cache` → `"<N> MB"`). 6.
  Extract `frequency` from the slug (`up-to-<N>-<M>-ghz` → `"Up to <N>.<M> GHz"`).
- **Usage:** Called by [`searchCpu`](#searchcpu) (full flavor only), via `Future.wait`, wrapped in
  `.catchError((_) => null)`.
- **Notes:** Because Intel's own page 403s, `sourceUrl` in the returned result still points at the
  real (unreachable, from this app) Intel spec page — it is provided purely "for user reference"
  (per this file's class-level doc comment), not as a link this app itself can successfully fetch
  again. The model-number reformatting regex (`i<digit><digits><letters>` → hyphenated) is
  explicitly commented in source as "best effort" — it can misfire on slug shapes it wasn't
  designed for.
