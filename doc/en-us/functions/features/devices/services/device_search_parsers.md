# lib/features/devices/services/device_search_parsers.dart

Pure parsing helpers shared by the online device-search sources. Everything in this file is
network-free and side-effect-free, so it can be unit-tested against the saved fixtures under
`test/fixtures/` without touching a remote host. Scraped markup is the most fragile part of the
search feature, so the parsing lives apart from the HTTP plumbing in
[`device_search_service.md`](device_search_service.md), which is this file's only caller in `lib/`.

The file is grouped by concern: entity and tag handling, names, relevance, values, the Notebookcheck
and PhoneDB page readers, the Apple Support readers (docs index, tech specs page), and the Wikipedia
readers (infobox wikitext, dates).

The split exists because the previous design kept every parser as a private static inside the
service, which made all of them untestable. See
[Online Search and Presets](../../../../features/online-search-and-presets.md#device-spec-search--device_search_servicedart)
for the concept overview this page verifies against source, and
`test/device_search_parser_test.dart` (Notebookcheck, PhoneDB) and
`test/device_search_sources_test.dart` (Apple, Wikipedia) for the fixture-driven tests.

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
| `AppleDocsEntry` | typedef (record) | B | One product link on an Apple Support docs index: `name`, `url`, `thumbnailUrl`. |
| [`parseAppleDocsIndex`](#parseappledocsindex) | function | A | Read the product links off an Apple Support docs index page. |
| [`isAppleDocsIndexPage`](#isappledocsindexpage) | function | A | Recognise an Apple Support docs index page. |
| [`findAppleTechSpecsLink`](#findappletechspecslink) | function | A | Find the tech specs page link on an Apple product docs page. |
| `AppleTechSpecs` | typedef (record) | B | The parts of a tech specs page the app reads: `title`, `imageUrl`, `yearIntroduced`, `sections`. |
| [`parseAppleTechSpecs`](#parseappletechspecs) | function | A | Split an Apple tech specs page into titled sections. |
| [`appleSection`](#applesection) | function | A | Pick a tech specs section by heading prefix. |
| [`extractWikiInfobox`](#extractwikiinfobox) | function | A | Pull the parameters of a page's first infobox out of wikitext. |
| [`wikiValueItems`](#wikivalueitems) | function | A | Turn a raw infobox value into plain-text items. |
| [`wikiField`](#wikifield) | function | A | Read the first item of the first present infobox parameter. |
| [`wikiFieldText`](#wikifieldtext) | function | A | Read every item of the first present infobox parameter. |
| [`parseWikiScreenSize`](#parsewikiscreensize) | function | A | Read a screen diagonal in inches from infobox text. |
| [`wikiBrand`](#wikibrand) | function | A | Reduce an infobox maker field to a brand name. |
| [`isWikiDeviceInfobox`](#iswikideviceinfobox) | function | A | Tell a device infobox from a company or person infobox. |
| [`parseWikiDate`](#parsewikidate) | function | A | Read a release date from infobox text. |

Row count (40) is three more than `grep -c 'Purpose:' device_search_parsers.dart` (37): the private
`_namedEntities` const and the two record typedefs `AppleDocsEntry` and `AppleTechSpecs` carry a
plain `///` description rather than a full `Purpose:` block, because they are data shapes rather
than behaviour. They are still indexed here per the tiering rule that every declaration appears in
the table.

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
- **Source:** line 166.
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
- **Source:** line 184.
- **Purpose:** Split a string into comparable lowercase tokens.
- **Inputs:** `value` — any name or query.
- **Returns:** Alphanumeric tokens of at least two characters.
- **Side effects:** None.
- **Notes:** Single characters are dropped so the `Z` in `Galaxy Z Fold8` cannot dominate scoring;
  two-character tokens such as `17` are kept because they carry the model generation. The service
  also counts tokens directly, to rank Apple results and to require a two-word Wikipedia title.

### `double relevanceScore(String query, String candidate)` <a id="relevancescore"></a>
- **Kind:** top-level function.
- **Source:** line 197.
- **Purpose:** Score how well a result name answers the query.
- **Inputs:** `query` — what the user typed; `candidate` — a result name.
- **Returns:** The fraction of query tokens present in the candidate, `0.0` to `1.0`.
- **Side effects:** None.
- **Notes:** Returns `0.0` for an empty query so callers cannot divide by zero.

### `bool isRelevant(String query, String candidate, {double threshold = 1.0})` <a id="isrelevant"></a>
- **Kind:** top-level function.
- **Source:** line 212.
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
- **Source:** line 224.
- **Purpose:** Read a single storage or memory capacity out of a spec string.
- **Inputs:** `raw` — text such as `12 GB , LPDDR5x` or `256 GB UFS 4.0 Flash`.
- **Returns:** A normalised `"<value> <unit>"` string, or `null`.
- **Side effects:** None.
- **Notes:** Accepts the binary units phonedb reports (`GiB`, `TiB`) and normalises them to the
  decimal spelling the app stores everywhere else, so `12 GiB RAM` becomes `12 GB`.

### `(String? ram, String? storage) parseMemory(String? raw)` <a id="parsememory"></a>
- **Kind:** top-level function.
- **Source:** line 241.
- **Purpose:** Split a combined storage-and-RAM string into its two capacities.
- **Inputs:** `raw` — text such as `256GB 12GB RAM` or `8GB RAM`.
- **Returns:** A `(ram, storage)` record; either side may be `null`.
- **Side effects:** None.
- **Notes:** Only the first comma-separated variant is read, because these sources list every SKU
  while the app records a single configuration.

### `String? parseScreenSize(String? raw)` <a id="parsescreensize"></a>
- **Kind:** top-level function.
- **Source:** line 272.
- **Purpose:** Read a screen diagonal expressed in inches.
- **Inputs:** `raw` — text such as `7.60 inch 4:3, 2448 x 1848 pixel` or `6.80"`.
- **Returns:** The diagonal formatted as `7.60"`, or `null`.
- **Side effects:** None.
- **Notes:** Accepts `inches`, `inch` and a bare `"` so both sources parse with one function.

### `String? parseScreenSizeMm(String? raw)` <a id="parsescreensizemm"></a>
- **Kind:** top-level function.
- **Source:** line 287.
- **Purpose:** Read a screen diagonal expressed in millimetres and convert it to inches.
- **Inputs:** `raw` — text such as `159.3 mm`.
- **Returns:** The diagonal converted to inches, formatted as `6.27"`, or `null`.
- **Side effects:** None.
- **Notes:** phonedb reports `Display Diagonal` in millimetres only, so this is the only way to get
  a screen size out of that source. Non-positive values return `null` rather than `0.00"`.

### `(int?, int?) parseResolution(String? raw)` <a id="parseresolution"></a>
- **Kind:** top-level function.
- **Source:** line 302.
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
- **Source:** line 323.
- **Purpose:** Read a battery capacity in mAh or Wh.
- **Inputs:** `raw` — text such as `4800 mAh Lithium-Ion, ...` or `100 Wh`.
- **Returns:** A normalised `"4800 mAh"` / `"100 Wh"` string, or `null`.
- **Side effects:** None.
- **Notes:** mAh is tried first because phone pages quote both.

### `int? parseMonth(String m)` <a id="parsemonth"></a>
- **Kind:** top-level function.
- **Source:** line 337.
- **Purpose:** Map an English month name or abbreviation to its number.
- **Inputs:** `m` — a month name such as `September` or `Sep`.
- **Returns:** `1`–`12`, or `null` when unrecognised.
- **Side effects:** None.
- **Notes:** Matching on the first three letters is what allows phonedb's `2026 Mar 12` to parse;
  the previous full-name-only table returned `null` for it.

### `DateTime? parseReleaseDate(String? raw)` <a id="parsereleasedate"></a>
- **Kind:** top-level function.
- **Source:** line 362.
- **Purpose:** Read a release date written year-first with a month name.
- **Inputs:** `raw` — text such as `2026 Mar 12` or `Released 2024, September 20`.
- **Returns:** The parsed date, or `null`.
- **Side effects:** None.
- **Notes:** Falls back to the first of the month when no day is present, so a month-only source
  still yields a usable date.

### `DateTime? parseUsDate(String? raw)` <a id="parseusdate"></a>
- **Kind:** top-level function.
- **Source:** line 386.
- **Purpose:** Read a release date written as a US numeric date.
- **Inputs:** `raw` — text such as `07/22/2026`.
- **Returns:** The parsed date, or `null`.
- **Side effects:** None.
- **Notes:** Notebookcheck writes `Released` in `MM/DD/YYYY`. The month and day are range-checked,
  so a page that switched to `DD/MM/YYYY` yields `null` rather than a silently wrong date.

### `String? parseChipName(String? raw)` <a id="parsechipname"></a>
- **Kind:** top-level function.
- **Source:** line 402.
- **Purpose:** Take the leading component of a comma-separated chip spec string.
- **Inputs:** `raw` — text such as `Qualcomm Snapdragon 8 Elite Gen 5 for Galaxy 8c/8t, 2 x 4.7 GHz ...`.
- **Returns:** The leading component with any trailing core/thread count removed.
- **Side effects:** None.
- **Notes:** Both sources append clock and core detail after the chip name; the app stores those in
  dedicated `CpuInfo` fields, not in the model string.

### `bool isLikelyDeviceImage(String url)` <a id="islikelydeviceimage"></a>
- **Kind:** top-level function.
- **Source:** line 419.
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
- **Source:** line 449.
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
- **Source:** line 459.
- **Purpose:** Confirm a response really is phonedb's search-results page.
- **Inputs:** `html` — the full response body.
- **Returns:** `true` when the results page rendered, with or without matches.
- **Side effects:** None.
- **Notes:** phonedb states its match count even when that count is zero (`0 results match`), so
  the phrase is a reliable marker that the page itself is intact.
  `test/fixtures/phonedb_no_results.html` pins the case.

### `Map<String, String> parseNotebookcheckSpecs(String html)` <a id="parsenotebookcheckspecs"></a>
- **Kind:** top-level function.
- **Source:** line 477.
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
- **Source:** line 509.
- **Purpose:** Read the label/value datasheet rows from a phonedb device page.
- **Inputs:** `html` — the full detail-page markup.
- **Returns:** A map of datasheet label to visible value; empty when nothing matched.
- **Side effects:** None.
- **Algorithm:** Match `<td><strong>label</strong>…</td><td>value</td>` with a lazy dot-all
  pattern, stripping both sides.
- **Notes:** First occurrence of a label wins, because the page repeats some labels in its
  comparison footer. As with the Notebookcheck reader, an empty map means the markup changed.

### `List<AppleDocsEntry> parseAppleDocsIndex(String html, String family)` <a id="parseappledocsindex"></a>
- **Kind:** top-level function.
- **Source:** line 538.
- **Purpose:** Read the product links off an Apple Support documentation index page.
- **Inputs:** `html` — a page such as `support.apple.com/en-us/docs/iphone`; `family` — the path
  segment after `docs/` (`iphone`, `mac`, ...).
- **Returns:** One `AppleDocsEntry` per product, in page order, without duplicates.
- **Side effects:** None.
- **Algorithm:** Match each `<a ...>` tag, then check inside its attributes for a `class` starting
  with `product` and an `href` of `https://support.apple.com/<locale>/docs/<family>/<id>`. Skip a URL already seen and an anchor with no
  `<div class="product-name">`. Take the name through [`stripHtml`](#striphtml), and the first
  `<img>` source through [`decodeEntities`](#decodeentities) with `size=120x120` widened to
  `size=240x240`.
- **Notes:** The ID is numeric or, for older products, alphanumeric such as `pl293`. Because the
  attributes are matched separately inside each tag, their order does not matter. A page with no
  product links yields an empty list, which the caller tells apart from a layout change with
  [`isAppleDocsIndexPage`](#isappledocsindexpage). `test/fixtures/apple_docs_index.html` pins it.

### `bool isAppleDocsIndexPage(String html)` <a id="isappledocsindexpage"></a>
- **Kind:** top-level function.
- **Source:** line 576.
- **Purpose:** Recognise an Apple Support docs index page.
- **Inputs:** `html` — the full response body.
- **Returns:** `true` when the page carries the product grid (`class="product-name"`).
- **Side effects:** None.
- **Notes:** Separates "no matching product" from a changed layout, as
  [`isNotebookcheckSearchPage`](#isnotebookchecksearchpage) does for Notebookcheck.

### `String? findAppleTechSpecsLink(String html)` <a id="findappletechspecslink"></a>
- **Kind:** top-level function.
- **Source:** line 583.
- **Purpose:** Find the "Tech Specs" link on an Apple product docs page.
- **Inputs:** `html` — a page such as `support.apple.com/en-us/docs/iphone/301045`.
- **Returns:** The absolute tech specs page URL, or null.
- **Side effects:** None.
- **Algorithm:** Scan every `<a ...>` opening tag for `link-text="tech specs"` (case-insensitive)
  and return its `href`, prefixing `https://support.apple.com` to a root-relative one.
- **Notes:** The link is marked `data-ss-analytics-link-text="tech specs"`; its visible text is not
  relied on. `test/fixtures/apple_docs_page.html` pins it.

### `AppleTechSpecs parseAppleTechSpecs(String html)` <a id="parseappletechspecs"></a>
- **Kind:** top-level function.
- **Source:** line 611.
- **Purpose:** Split an Apple tech specs page into titled sections.
- **Inputs:** `html` — a page such as `support.apple.com/en-us/121029`.
- **Returns:** An `AppleTechSpecs` record: the `<h1>` title without ` - Tech Specs`, the product
  render, the introduction year, and each `<h3>` heading mapped to the text of its list items and
  paragraphs, in order.
- **Side effects:** None.
- **Algorithm:** 1. Title from the first `<h1>`. 2. Image: the first `cdsassets.apple.com` `.png`,
  `.jpg` or `.jpeg`. 3. Year: `Year introduced: YYYY` in the stripped page text. 4. Split on `<h3`;
  per part, the heading is the text up to `</h3>` with `<sup>` footnote markers removed, and the
  body runs to the next `<div class="gb-group` (or the next heading). 5. Each `<li>` or `<p>` in the
  body, with `<sup>` removed and tags stripped, becomes a line; empty lines are dropped. The first
  section with a given heading wins.
- **Notes:** Footnote removal is why `Capacity<sup>1</sup>` is found as `Capacity`. Apple ships the
  render on a transparent or white background. `test/fixtures/apple_specs_iphone.html` and
  `apple_specs_mac.html` pin both product lines.

### `List<String> appleSection(AppleTechSpecs specs, List<String> names)` <a id="applesection"></a>
- **Kind:** top-level function.
- **Source:** line 666.
- **Purpose:** Pick the lines of the first section whose heading starts with one of the given names.
- **Inputs:** `specs`; `names` in priority order, compared case-insensitively.
- **Returns:** The section's lines, or an empty list.
- **Side effects:** None.
- **Notes:** Priority follows `names` first, then page order. Apple words headings slightly
  differently across product lines ("Battery and Power" on a Mac, "Power and Battery" on an
  iPhone), so callers pass every spelling; the prefix match also absorbs trailing qualifiers.

### `Map<String, String>? extractWikiInfobox(String wikitext)` <a id="extractwikiinfobox"></a>
- **Kind:** top-level function.
- **Source:** line 686.
- **Purpose:** Pull the parameters of a page's first infobox out of wikitext.
- **Inputs:** `wikitext` — the lead section of an article.
- **Returns:** Lowercased parameter names mapped to their raw values, or null when the page has no
  infobox or its braces never close.
- **Side effects:** None.
- **Algorithm:** 1. Find the first `{{infobox` (case-insensitive). 2. Walk forward counting `{{` and
  `}}` to find the matching close. 3. Split the body on `|` only at depth zero of both `{{ }}` and
  `[[ ]]`. 4. Skip the first part (the template name); split each other part at its first `=`,
  lowercase and trim the key, and keep the first non-empty value per key.
- **Notes:** Depth counting is what stops a piped link or a list template inside a value from
  ending it early. Values stay raw wikitext; [`wikiValueItems`](#wikivalueitems) turns them into
  text. `test/fixtures/wikipedia_steam_deck.json` and `wikipedia_company.json` pin a device and a
  company article.

### `List<String> wikiValueItems(String raw)` <a id="wikivalueitems"></a>
- **Kind:** top-level function.
- **Source:** line 753.
- **Purpose:** Turn a raw infobox value into its plain-text items.
- **Inputs:** `raw` — wikitext such as `{{ubl|'''LCD:''' 16 GB [[LPDDR5]]|...}}`.
- **Returns:** The visible items in order (one per list entry or line), with references, comments,
  markup and variant labels such as `LCD:` removed.
- **Side effects:** None.
- **Algorithm:** 1. Remove comments, `<ref>` tags and `[[File:...]]` / `[[Image:...]]`; replace
  links with their label. 2. Resolve templates innermost-first, at most 30 rounds:

  | Template | Becomes |
  |---|---|
  | List templates (`ubl`, `plainlist`, `flatlist`, `hlist`, ...) | One item per positional argument |
  | `nowrap`, `nobr`, `small`, `abbr`, ... | The first positional argument |
  | `nbsp`, `!` / `br`, `break` | A space / a line break |
  | `convert`, `cvt` | `<value> <unit>` |
  | `start date...`, `release date...`, `dts` | `YYYY-MM-DD`, missing month or day as `01` |
  | `vgrelease`, `video game release` | One line per date (every second argument) |
  | Anything else | Dropped |

  3. Unwrap external links to their label, drop bold/italic quotes, remove thousands separators,
  and turn `<br>` into line breaks. 4. Per line: strip tags, leading list markers and a short
  `Label:` prefix; keep non-empty lines.
- **Notes:** Links are resolved first because a piped link inside a template would otherwise be cut
  at its pipe when the template's arguments are split. Thousands separators are removed so
  `4,400 mAh` is not read as `400 mAh`. Unknown templates (prices, icons, "current version"
  helpers) are dropped rather than guessed at. Named template arguments (`df=yes`) are ignored.

### `String? wikiField(Map<String, String> infobox, List<String> keys)` <a id="wikifield"></a>
- **Kind:** top-level function.
- **Source:** line 847.
- **Purpose:** Read the first value of the first present infobox parameter.
- **Inputs:** `infobox`; `keys` in priority order.
- **Returns:** The first plain-text item from [`wikiValueItems`](#wikivalueitems), or null.
- **Side effects:** None.
- **Notes:** Infoboxes name the same thing differently (`soc`, `system_on_chip`, `cpu`), so callers
  pass every spelling they accept. A key whose value yields no items falls through to the next key.

### `String? wikiFieldText(Map<String, String> infobox, List<String> keys)` <a id="wikifieldtext"></a>
- **Kind:** top-level function.
- **Source:** line 863.
- **Purpose:** Read every item of the first present infobox parameter.
- **Inputs:** `infobox`; `keys` in priority order.
- **Returns:** The items joined with `, `, or null.
- **Side effects:** None.
- **Notes:** For values whose useful part is not the first item — a display listed as panel type,
  then size, then resolution.

### `String? parseWikiScreenSize(String? raw)` <a id="parsewikiscreensize"></a>
- **Kind:** top-level function.
- **Source:** line 879.
- **Purpose:** Read a screen diagonal in inches from infobox text.
- **Inputs:** `raw` — text such as `6.1 in`, `7.9-in LCD` or `7", 1280×800`.
- **Returns:** The diagonal formatted as `7.9"`, or null.
- **Side effects:** None.
- **Notes:** Wikipedia abbreviates the unit (`in`), which [`parseScreenSize`](#parsescreensize) does
  not accept because `in` is an ordinary word on other sources.

### `String? wikiBrand(String? raw)` <a id="wikibrand"></a>
- **Kind:** top-level function.
- **Source:** line 893.
- **Purpose:** Reduce an infobox maker field to a brand name.
- **Inputs:** `raw` — text such as `Valve Corporation` or `Samsung Electronics`.
- **Returns:** The first maker with corporate suffixes removed, or null.
- **Side effects:** None.
- **Algorithm:** Take the text before the first `/` or the first comma not followed by `Ltd` (so the
  comma inside `Co., Ltd.` does not split), then strip trailing suffixes repeatedly until none is
  left (`Corporation`, `Corp.`, `Inc.`, `Electronics`, `Co., Ltd.`, a bare `Co.`, `Ltd.`,
  `Limited`, `Company`, `Computer`, `Technology`, `Group`, `Holdings`). An empty result becomes
  null.
- **Notes:** Suffixes stack, so `Samsung Electronics Co., Ltd.` becomes `Samsung`; a maker list
  such as `Nintendo / Foxconn` keeps only the first maker.

### `bool isWikiDeviceInfobox(Map<String, String> infobox)` <a id="iswikideviceinfobox"></a>
- **Kind:** top-level function.
- **Source:** line 922.
- **Purpose:** Tell whether an infobox describes a device rather than a company, person or product
  line.
- **Inputs:** `infobox`.
- **Returns:** `true` when it carries at least one of `cpu`, `soc`, `system_on_chip`, `processor`,
  `memory`, `storage` or `display`.
- **Side effects:** None.
- **Notes:** A redirect such as "Framework Laptop 13" lands on the company article, whose
  `Infobox company` must not be read as specs.

### `DateTime? parseWikiDate(String? raw)` <a id="parsewikidate"></a>
- **Kind:** top-level function.
- **Source:** line 938.
- **Purpose:** Read a release date from infobox text.
- **Inputs:** `raw` — text such as `2024-09-20`, `February 25, 2022` or `25 February 2022`.
- **Returns:** The first date found, or null.
- **Side effects:** None.
- **Algorithm:** Try, in order: `YYYY-MM-DD` (what [`wikiValueItems`](#wikivalueitems) makes of a
  date template), `Month D, YYYY`, `D Month YYYY`, and `Month YYYY` (first of the month). Month names
  go through [`parseMonth`](#parsemonth).
- **Notes:** A bare year is ignored; a year alone is not a release date. An ISO date with a month
  outside 1–12 or a day outside 1–31 returns null instead of rolling over into the next month as
  `DateTime` would.

## Related

- [`device_search_service.md`](device_search_service.md) — the only caller; HTTP, source dispatch and outcome reporting.
- [`preset_service.md`](preset_service.md) — the offline counterpart to online search.
- [Online Search and Presets](../../../../features/online-search-and-presets.md)
