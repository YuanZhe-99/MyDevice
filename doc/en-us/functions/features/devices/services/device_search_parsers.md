# lib/features/devices/services/device_search_parsers.dart

Pure parsing helpers shared by the online device-search sources. Everything in this file is
network-free and side-effect-free, so it can be unit-tested against the saved fixtures under
`test/fixtures/` without touching a remote host. Scraped markup is the most fragile part of the
search feature, so the parsing lives apart from the HTTP plumbing in
[`device_search_service.md`](device_search_service.md), which is this file's only caller.

The split exists because the previous design kept every parser as a private static inside the
service, which made all of them untestable. See
[Online Search and Presets](../../../../features/online-search-and-presets.md#device-spec-search--device_search_servicedart)
for the concept overview this page verifies against source, and
`test/device_search_parser_test.dart` for the fixture-driven tests.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `_namedEntities` | private const map | B | Named HTML entities that appear in the scraped sources. |
| [`decodeEntities`](#decodeentities) | function | A | Decode named and numeric HTML entities. |
| [`stripHtml`](#striphtml) | function | A | Reduce an HTML fragment to visible text. |
| [`looksBlocked`](#looksblocked) | function | A | Detect a bot-wall served in place of content. |
| [`splitBrandModel`](#splitbrandmodel) | function | A | Split a device name into brand and model. |
| [`cleanDeviceName`](#cleandevicename) | function | A | Normalise a scraped title into a plain device name. |
| [`isReviewArticle`](#isreviewarticle) | function | A | Decide whether a title is editorial rather than a device. |
| [`tokenize`](#tokenize) | function | A | Split a string into comparable lowercase tokens. |
| [`relevanceScore`](#relevancescore) | function | A | Score how well a result answers the query. |
| [`isRelevant`](#isrelevant) | function | A | Gate out results that do not answer the query. |
| [`parseCapacity`](#parsecapacity) | function | A | Read a single storage or memory capacity. |
| [`parseMemory`](#parsememory) | function | A | Split a combined storage-and-RAM string. |
| [`parseScreenSize`](#parsescreensize) | function | A | Read a screen diagonal given in inches. |
| [`parseScreenSizeMm`](#parsescreensizemm) | function | A | Read a screen diagonal given in millimetres. |
| [`parseResolution`](#parseresolution) | function | A | Read a pixel resolution. |
| [`parseBattery`](#parsebattery) | function | A | Read a battery capacity in mAh or Wh. |
| [`parseMonth`](#parsemonth) | function | A | Map an English month name or abbreviation to its number. |
| [`parseReleaseDate`](#parsereleasedate) | function | A | Read a year-first date with a month name. |
| [`parseUsDate`](#parseusdate) | function | A | Read a US numeric `MM/DD/YYYY` date. |
| [`parseChipName`](#parsechipname) | function | A | Take the leading component of a chip spec string. |
| [`isLikelyDeviceImage`](#islikelydeviceimage) | function | A | Decide whether an image URL is a device photo. |
| [`isNotebookcheckSearchPage`](#isnotebookchecksearchpage) | function | A | Confirm a response really is Notebookcheck's search page. |
| [`isPhonedbResultsPage`](#isphonedbresultspage) | function | A | Confirm a response really is phonedb's results page. |
| [`parseNotebookcheckSpecs`](#parsenotebookcheckspecs) | function | A | Read the spec table from a Notebookcheck device page. |
| [`parsePhonedbSpecs`](#parsephonedbspecs) | function | A | Read the datasheet rows from a phonedb device page. |

Row count (25) is one more than `grep -c 'Purpose:' device_search_parsers.dart` (24): the private
`_namedEntities` const carries a plain `///` description rather than a full `Purpose:` block,
because it is data rather than behaviour. It is still indexed here per the tiering rule that every
declaration appears in the table.

## Documentation

### `String decodeEntities(String input)` <a id="decodeentities"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/devices/services/device_search_parsers.dart` (line 41).
- **Purpose:** Replace named and numeric HTML entities with the characters they denote.
- **Inputs:** `input` — raw text that may contain entities.
- **Returns:** `String` with entities decoded.
- **Side effects:** None.
- **Algorithm:** A single `replaceAllMapped` pass over `&(#x?[0-9a-fA-F]+|[a-zA-Z]+);`. Numeric
  forms are parsed in base 10 or 16 and range-checked against the Unicode maximum; named forms are
  looked up in `_namedEntities`. Anything unrecognised is returned verbatim.
- **Notes:** One pass matters: decoding repeatedly would turn `&amp;nbsp;` into a space instead of
  the literal `&nbsp;` the source actually wrote. Returning unknown entities verbatim is a
  deliberate change from the previous behaviour, which **deleted** every entity — that is why
  `12&nbsp;GB` used to collapse to `12GB` and `AT&amp;T` to `ATT`.

### `String stripHtml(String html)` <a id="striphtml"></a>
- **Kind:** top-level function.
- **Source:** line 61.
- **Purpose:** Reduce an HTML fragment to its visible text.
- **Inputs:** `html` — a fragment that may contain tags and entities.
- **Returns:** Tag-free text with entities decoded and whitespace runs collapsed.
- **Side effects:** None.
- **Algorithm:** Replace every `<[^>]*>` with a single space, run [`decodeEntities`](#decodeentities),
  collapse `\s+` to one space, trim.
- **Notes:** Tags become a space rather than nothing, so `<b>Intel</b><i>Core</i>` reads as
  `Intel Core` and not `IntelCore`.

### `bool looksBlocked(String body)` <a id="looksblocked"></a>
- **Kind:** top-level function.
- **Source:** line 74.
- **Purpose:** Detect a bot-wall or interstitial served in place of real content.
- **Inputs:** `body` — the decoded response body.
- **Returns:** `true` when the body looks like a challenge page.
- **Side effects:** None.
- **Algorithm:** Case-insensitive substring scan for challenge markers
  (`challenges.cloudflare.com`, `turnstile`, `cf-chl`, `__cf_chl`, `just a moment`,
  `verify you are human`, `navigator.webdriver`, and similar).
- **Notes:** These pages are served with **HTTP 200**, so a status check alone cannot catch them.
  This is exactly the failure mode that made GSMArena look like "no results" rather than a blocked
  source for a long time. `test/fixtures/cloudflare_challenge.html` is a real captured example.

### `(String?, String?) splitBrandModel(String name)` <a id="splitbrandmodel"></a>
- **Kind:** top-level function.
- **Source:** line 99.
- **Purpose:** Split a full device name into a brand and the remaining model.
- **Inputs:** `name` — a full device name such as `Samsung Galaxy Z Fold8`.
- **Returns:** A `(brand, model)` record; `model` is `null` when the name has no space.
- **Side effects:** None.
- **Algorithm:** Check a short list of multi-word brands first, then fall back to splitting at the
  first space.
- **Notes:** The multi-word list exists because a plain first-space split strands half of
  `Raspberry Pi` or `Google Cloud` in the model field.

### `String cleanDeviceName(String raw)` <a id="cleandevicename"></a>
- **Kind:** top-level function.
- **Source:** line 127.
- **Purpose:** Normalise a scraped result title into a plain device name.
- **Inputs:** `raw` — a source-specific title.
- **Returns:** The name with source boilerplate and SKU noise removed.
- **Side effects:** None.
- **Algorithm:** Strip, in order: the Notebookcheck `- Reviews and Specs` suffix, a trailing
  ` specs`, a phonedb trailing codename such as `(Samsung Q7)`, a phonedb OEM part number such as
  `SM-F9660`, region/SIM/network/edition qualifiers, and a trailing capacity. Collapse whitespace.
- **Usage:**
  ```dart
  cleanDeviceName('Samsung Galaxy Z Fold8 - Reviews and Specs');
  // 'Samsung Galaxy Z Fold8'
  ```
- **Notes:** This must run **before** [`isReviewArticle`](#isreviewarticle). Notebookcheck titles
  its canonical device pages `<name> - Reviews and Specs`, so filtering the raw title discards the
  newest devices while keeping older ones that happen to have a bare title.

### `bool isReviewArticle(String name)` <a id="isreviewarticle"></a>
- **Kind:** top-level function.
- **Source:** line 163.
- **Purpose:** Decide whether a result title is an editorial article rather than a device.
- **Inputs:** `name` — a title that has already been through [`cleanDeviceName`](#cleandevicename).
- **Returns:** `true` when the title reads as a review, comparison, benchmark or hands-on.
- **Side effects:** None.
- **Algorithm:** Reject names shorter than 3 or longer than 80 characters, then match a word-boundary
  pattern covering `review(s)`, `comparison`, `versus`, `vs`, `benchmark`, `hands-on`, `unboxing`
  and `test:`.
- **Notes:** Passing a raw Notebookcheck title here is a bug, not a style choice — see
  [`cleanDeviceName`](#cleandevicename).

### `List<String> tokenize(String value)` <a id="tokenize"></a>
- **Kind:** top-level function.
- **Source:** line 181.
- **Purpose:** Split a string into comparable lowercase tokens.
- **Inputs:** `value` — any name or query.
- **Returns:** Alphanumeric tokens of at least two characters.
- **Side effects:** None.
- **Notes:** Single characters are dropped so the `Z` in `Galaxy Z Fold8` cannot dominate scoring;
  two-character tokens such as `17` are kept because they carry the model generation.

### `double relevanceScore(String query, String candidate)` <a id="relevancescore"></a>
- **Kind:** top-level function.
- **Source:** line 194.
- **Purpose:** Score how well a result name answers the query.
- **Inputs:** `query` — what the user typed; `candidate` — a result name.
- **Returns:** The fraction of query tokens present in the candidate, `0.0` to `1.0`.
- **Side effects:** None.
- **Notes:** Returns `0.0` for an empty query so callers cannot divide by zero.

### `bool isRelevant(String query, String candidate, {double threshold = 1.0})` <a id="isrelevant"></a>
- **Kind:** top-level function.
- **Source:** line 209.
- **Purpose:** Gate out results that do not actually answer the query.
- **Inputs:** `query`, `candidate`, and an optional `threshold`.
- **Returns:** `true` when the candidate scores at or above the threshold.
- **Side effects:** None.
- **Notes:** Required for phonedb, which answers a model it does not carry with a loose full-text
  match — a search for `Galaxy Z Fold8` returns 120 unrelated Galaxy phones. Without this gate
  those would be presented as hits. The default threshold of `1.0` requires every query token to
  appear in the result name.

### `String? parseCapacity(String? raw)` <a id="parsecapacity"></a>
- **Kind:** top-level function.
- **Source:** line 221.
- **Purpose:** Read a single storage or memory capacity out of a spec string.
- **Inputs:** `raw` — text such as `12 GB , LPDDR5x` or `256 GB UFS 4.0 Flash`.
- **Returns:** A normalised `"<value> <unit>"` string, or `null`.
- **Side effects:** None.
- **Notes:** Accepts the binary units phonedb reports (`GiB`, `TiB`) and normalises them to the
  decimal spelling the app stores everywhere else, so `12 GiB RAM` becomes `12 GB`.

### `(String? ram, String? storage) parseMemory(String? raw)` <a id="parsememory"></a>
- **Kind:** top-level function.
- **Source:** line 238.
- **Purpose:** Split a combined storage-and-RAM string into its two capacities.
- **Inputs:** `raw` — text such as `256GB 12GB RAM` or `8GB RAM`.
- **Returns:** A `(ram, storage)` record; either side may be `null`.
- **Side effects:** None.
- **Notes:** Only the first comma-separated variant is read, because these sources list every SKU
  while the app records a single configuration.

### `String? parseScreenSize(String? raw)` <a id="parsescreensize"></a>
- **Kind:** top-level function.
- **Source:** line 269.
- **Purpose:** Read a screen diagonal expressed in inches.
- **Inputs:** `raw` — text such as `7.60 inch 4:3, 2448 x 1848 pixel` or `6.80"`.
- **Returns:** The diagonal formatted as `7.60"`, or `null`.
- **Side effects:** None.
- **Notes:** Accepts `inches`, `inch` and a bare `"` so both sources parse with one function.

### `String? parseScreenSizeMm(String? raw)` <a id="parsescreensizemm"></a>
- **Kind:** top-level function.
- **Source:** line 284.
- **Purpose:** Read a screen diagonal expressed in millimetres and convert it to inches.
- **Inputs:** `raw` — text such as `159.3 mm`.
- **Returns:** The diagonal converted to inches, formatted as `6.27"`, or `null`.
- **Side effects:** None.
- **Notes:** phonedb reports `Display Diagonal` in millimetres only, so this is the only way to get
  a screen size out of that source. Non-positive values return `null` rather than `0.00"`.

### `(int?, int?) parseResolution(String? raw)` <a id="parseresolution"></a>
- **Kind:** top-level function.
- **Source:** line 299.
- **Purpose:** Read a pixel resolution.
- **Inputs:** `raw` — text such as `2448 x 1848 pixel` or `1080x2340`.
- **Returns:** A `(width, height)` record, or `(null, null)`.
- **Side effects:** None.
- **Algorithm:** Prefer a figure followed by `pixel`; fall back to any `NNN x NNN` with 3–5 digits
  per side.
- **Notes:** The `pixel` preference and the digit-count floor stop a leading aspect ratio or refresh
  rate from being read as a resolution.

### `String? parseBattery(String? raw)` <a id="parsebattery"></a>
- **Kind:** top-level function.
- **Source:** line 320.
- **Purpose:** Read a battery capacity in mAh or Wh.
- **Inputs:** `raw` — text such as `4800 mAh Lithium-Ion, ...` or `100 Wh`.
- **Returns:** A normalised `"4800 mAh"` / `"100 Wh"` string, or `null`.
- **Side effects:** None.
- **Notes:** mAh is tried first because phone pages quote both.

### `int? parseMonth(String m)` <a id="parsemonth"></a>
- **Kind:** top-level function.
- **Source:** line 334.
- **Purpose:** Map an English month name or abbreviation to its number.
- **Inputs:** `m` — a month name such as `September` or `Sep`.
- **Returns:** `1`–`12`, or `null` when unrecognised.
- **Side effects:** None.
- **Notes:** Matching on the first three letters is what allows phonedb's `2026 Mar 12` to parse;
  the previous full-name-only table returned `null` for it.

### `DateTime? parseReleaseDate(String? raw)` <a id="parsereleasedate"></a>
- **Kind:** top-level function.
- **Source:** line 359.
- **Purpose:** Read a release date written year-first with a month name.
- **Inputs:** `raw` — text such as `2026 Mar 12` or `Released 2024, September 20`.
- **Returns:** The parsed date, or `null`.
- **Side effects:** None.
- **Notes:** Falls back to the first of the month when no day is present, so a month-only source
  still yields a usable date.

### `DateTime? parseUsDate(String? raw)` <a id="parseusdate"></a>
- **Kind:** top-level function.
- **Source:** line 383.
- **Purpose:** Read a release date written as a US numeric date.
- **Inputs:** `raw` — text such as `07/22/2026`.
- **Returns:** The parsed date, or `null`.
- **Side effects:** None.
- **Notes:** Notebookcheck writes `Released` in `MM/DD/YYYY`. The month and day are range-checked,
  so a page that switched to `DD/MM/YYYY` yields `null` rather than a silently wrong date.

### `String? parseChipName(String? raw)` <a id="parsechipname"></a>
- **Kind:** top-level function.
- **Source:** line 399.
- **Purpose:** Take the leading component of a comma-separated chip spec string.
- **Inputs:** `raw` — text such as `Qualcomm Snapdragon 8 Elite Gen 5 for Galaxy 8c/8t, 2 x 4.7 GHz ...`.
- **Returns:** The leading component with any trailing core/thread count removed.
- **Side effects:** None.
- **Notes:** Both sources append clock and core detail after the chip name; the app stores those in
  dedicated `CpuInfo` fields, not in the model string.

### `bool isLikelyDeviceImage(String url)` <a id="islikelydeviceimage"></a>
- **Kind:** top-level function.
- **Source:** line 416.
- **Purpose:** Decide whether an image URL is a device photo rather than an advert.
- **Inputs:** `url` — an absolute or protocol-relative image URL.
- **Returns:** `true` when the URL looks like genuine device imagery.
- **Side effects:** None.
- **Algorithm:** Reject known advert/affiliate/tracking markers first, then require a real image
  extension.
- **Notes:** Rejection deliberately wins over acceptance, so an advert served as `banner.png` is
  still filtered out.

### `bool isNotebookcheckSearchPage(String html)` <a id="isnotebookchecksearchpage"></a>
- **Kind:** top-level function.
- **Source:** line 450.
- **Purpose:** Confirm a response really is Notebookcheck's device search page.
- **Inputs:** `html` — the full response body.
- **Returns:** `true` when the search page rendered, with or without matches.
- **Side effects:** None.
- **Notes:** A query with no matches renders the search page **without** a results table. Without
  this check the caller cannot tell that apart from a layout change and would report
  `markupChanged` for every unknown device — the same conflation of "no results" with "broken"
  that hid the GSMArena breakage. `test/fixtures/notebookcheck_no_results.html` pins the case.

### `bool isPhonedbResultsPage(String html)` <a id="isphonedbresultspage"></a>
- **Kind:** top-level function.
- **Source:** line 464.
- **Purpose:** Confirm a response really is phonedb's search-results page.
- **Inputs:** `html` — the full response body.
- **Returns:** `true` when the results page rendered, with or without matches.
- **Side effects:** None.
- **Notes:** phonedb states its match count even when that count is zero (`0 results match`), so
  the phrase is a reliable marker that the page itself is intact.
  `test/fixtures/phonedb_no_results.html` pins the case.

### `Map<String, String> parseNotebookcheckSpecs(String html)` <a id="parsenotebookcheckspecs"></a>
- **Kind:** top-level function.
- **Source:** line 450.
- **Purpose:** Read the label/value spec table from a Notebookcheck device page.
- **Inputs:** `html` — the full detail-page markup.
- **Returns:** A map of spec label to visible value; empty when nothing matched.
- **Side effects:** None.
- **Algorithm:** Split on the literal `<div class="specs">` label div. For each chunk, take the
  label up to the first `</div>`, then take everything from there to the next
  `<div class="specs_element">` (capped at 4000 characters) and run it through
  [`stripHtml`](#striphtml). First occurrence of a label wins.
- **Usage:**
  ```dart
  final specs = parseNotebookcheckSpecs(html);
  final ram = parseCapacity(specs['Memory']);
  ```
- **Notes:** Two markup shapes have to work. Most values sit inside a `div.specs_details` that
  **nests** a `div.specs_indicator`, so matching a closing `</div></div>` truncates `Memory` and
  `Storage` mid-value and loses everything after the indicator. `Released` has no wrapper at all
  and follows the label directly. Stripping tags across the whole span between labels handles both.
  An empty map means the markup changed, and the caller must report that rather than treat it as a
  device with no specs.

### `Map<String, String> parsePhonedbSpecs(String html)` <a id="parsephonedbspecs"></a>
- **Kind:** top-level function.
- **Source:** line 482.
- **Purpose:** Read the label/value datasheet rows from a phonedb device page.
- **Inputs:** `html` — the full detail-page markup.
- **Returns:** A map of datasheet label to visible value; empty when nothing matched.
- **Side effects:** None.
- **Algorithm:** Match `<td><strong>label</strong>…</td><td>value</td>` with a lazy dot-all
  pattern, stripping both sides.
- **Notes:** First occurrence of a label wins, because the page repeats some labels in its
  comparison footer. As with the Notebookcheck reader, an empty map means the markup changed.

## Related

- [`device_search_service.md`](device_search_service.md) — the only caller; HTTP, source dispatch and outcome reporting.
- [`preset_service.md`](preset_service.md) — the offline counterpart to online search.
- [Online Search and Presets](../../../../features/online-search-and-presets.md)
