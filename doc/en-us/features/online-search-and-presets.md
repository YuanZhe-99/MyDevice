# Online Search and Presets

Sources: `lib/features/devices/services/device_search_service.dart`,
`lib/features/devices/services/chip_search_service.dart`, and
`lib/features/devices/services/preset_service.dart`. See
[Architecture](../architecture.md#appflavor) for `AppFlavor` and
[Data Formats](../data-formats.md) for the `CpuInfo`/`GpuInfo` shapes these fill in.

## Device spec search — `device_search_service.dart`

`DeviceSearchService` fetches device specs from a **source registry** (`_sources`): each
entry has a name, an `enabled` switch, an `appliesTo(query)` test, a search function and a
detail function. Enabled sources that apply run concurrently over one shared client, each
reporting its own outcome rather than swallowing failures. Results are listed in registry
order:

| Source | Search / detail | Covers | Notes |
|---|---|---|---|
| **Apple** (since 1.6.1) | `_searchApple` / `_fetchAppleDetail` | Apple products only | Applies when the query names an Apple product word (`appleFamiliesFor`: iPhone, iPad, Mac/MacBook/iMac, Watch, AirPods). Reads the family's Apple Support docs index, then the product's docs page, then its tech-specs page. |
| **Notebookcheck** | `_searchNotebookcheck` / `_fetchNotebookcheckDetail` | Laptops, tablets, phones, smartwatches | The detail page carries a full spec table. |
| **PhoneDB** | `_searchPhonedb` / `_fetchPhonedbDetail` | Phones at SKU level | Behind a relevance gate because it answers an unknown model with a loose full-text match. |
| **Wikipedia** (since 1.6.1) | `_searchWikipedia` / `_fetchWikipediaDetail` | Anything with its own article (consoles, handhelds, boards) | A **fallback**: queried only when every other source found nothing, so product-line articles never bury exact answers. Reads the lead section's infobox through the MediaWiki API. |

All markup parsing lives in `device_search_parsers.dart`, which is network-free and unit
tested against saved fixtures in `test/fixtures/`; the Apple and Wikipedia field mapping
(`withAppleSpecs`, `withWikipediaInfobox`) is public on the service for the same reason.

**User agent.** Every request sends `DeviceSearchService.userAgent`, an honest
`MyDevice (+https://github.com/YuanZhe-99/MyDevice)`. Until 1.6.0 the service sent a Chrome
user agent; Cloudflare, in front of Notebookcheck, answers a Chrome agent arriving over Dart's
(non-Chrome) TLS handshake with HTTP 403, which is why the search looked dead in 1.6.0. The same
agent is accepted by every other source, and MediaWiki's API policy asks for one. The chip search
below still sends a browser agent, because Startpage returns no results without one.

**What each new source reads:**

- *Apple* — `parseAppleDocsIndex` (product links; Wi-Fi / Cellular variants collapse into one
  result), `findAppleTechSpecsLink`, `parseAppleTechSpecs` (the `<h3>` sections). The chip line
  becomes `Apple A18` / `Apple M4 Pro` and the first "N-core GPU" becomes `Apple M4 Pro GPU
  (16-core)`, the spelling of the bundled presets; the base memory and storage configuration;
  size and `W-by-H` resolution from Display; battery only when Apple states a capacity
  (`72.4-watt-hour`); no release date, because Apple states only the introduction year. The
  product render (`cdsassets.apple.com`) is offered as the image.
- *Wikipedia* — `extractWikiInfobox` (the first infobox's parameters, split at nesting depth
  zero), `wikiValueItems` (resolves list, `convert`, date and `vgrelease` templates, links and
  references; drops variant labels such as `LCD:`), `isWikiDeviceInfobox` (rejects a company or
  person infobox that a redirect lands on), `parseWikiDate`, `parseWikiScreenSize`, `wikiBrand`
  (`developer` before `manufacturer`, which is often a contract manufacturer). The page image
  rendered at 800 px is offered as the image, so an SVG original arrives as a PNG.

**Hiding the feature.** `AppFlavor.deviceSearchExposed` (currently `isFull`) gates the "Fetch
Device Info" button in the device editor and the search shortcut on the device list. Setting it
to false hides both while the service, parsers, fixtures, tests and `tool/check_sources.dart`
stay — the switch for the day every source stops answering. A single source that breaks is
switched off with its `enabled` flag instead.

```dart
static Future<DeviceSearchResponse> search(String query) async {
  if (AppFlavor.isStore) {
    return const DeviceSearchResponse(results: [], outcomes: []);
  }
  ...
}
```

Both `search()` and `fetchDetail()` return early (an empty response / the unmodified
input result) when `AppFlavor.isStore` is true — confirmed directly in source.

**GSMArena was removed.** It answers every request with a Cloudflare Turnstile challenge
served as HTTP 200. The old code checked only the status code, then failed to match its
row pattern and returned an empty list — indistinguishable from "no such device". No
HTTP-only client can pass that challenge, so the source is unrecoverable by scraping.

### Reporting failure honestly

That silent breakage is why `search()` now returns a `DeviceSearchResponse` carrying one
`DeviceSourceOutcome` per source, with a `DeviceSearchStatus` of:

| Status | Meaning | Retry helps? |
|---|---|---|
| `ok` | Source answered and parsed; `resultCount` may still be 0 | n/a |
| `blocked` | Bot-wall or challenge page served instead of content | No |
| `unreachable` | DNS, socket, timeout, or a non-200 status | Yes |
| `markupChanged` | Answered, but no parser anchor was present | No — needs a code fix |

A zero-match search is deliberately **`ok`, not a failure**: `isNotebookcheckSearchPage`
and `isPhonedbResultsPage` recognise a healthy page that simply has no rows. Without that
distinction the new signal would cry wolf on every device a source does not carry.

`tool/check_sources.dart` probes every source (Notebookcheck search and detail, PhoneDB search
and detail, the Apple docs index, a docs page and a tech-specs page, Wikipedia search and an
infobox) with the app's own user agent and prints the same classification, so scraper rot can be
checked with one command instead of being noticed by a user. `tool/test_live.dart` runs the real
service end to end for a few queries and prints the fields each source fills in. Both are
deliberately **not** wired into CI, because they make real third-party network requests.

## Chip spec search — `chip_search_service.dart` <a id="chip-spec-search---chip_search_servicedart"></a>

`ChipSearchService` fetches CPU specs from TechPowerUp and Intel, and GPU specs from
TechPowerUp and AMD:

- **TechPowerUp** — CPU `th`/`td` spec tables, GPU `og:description` meta tags
  (`_searchTechPowerUpCpu`, `_searchTechPowerUpGpu`).
- **AMD** (official) — CPU/GPU product pages with `dt`/`dd` spec pairs
  (`_searchAmdCpu`, `_searchAmdGpu`).
- **Intel** (official) — URL slug parsing for model/cache/max frequency
  (`_searchIntelCpu`).

Confirmed gating in source:

```dart
static Future<List<ChipSearchResult>> searchCpu(...) async {
  ...
  if (AppFlavor.isFull) {
    // query TechPowerUp / Intel
  }
  ...
}
```

Online CPU/GPU search only runs `if (AppFlavor.isFull)` — i.e. it's skipped entirely for
store builds, same effective behavior as `device_search_service.dart`'s early return.

## Store-flavor gating requirements

Per `AGENTS.md`'s Build Flavors section, online device/chip search must be fully gated
for store builds, checked at **four call sites**:

1. `lib/features/devices/services/device_search_service.dart` — `search()` and
   `fetchDetail()` return early for store.
2. `lib/features/devices/services/chip_search_service.dart` — online CPU/GPU search is
   gated behind `AppFlavor.isFull`.
3. `lib/features/devices/views/device_edit_page.dart` — three online search buttons are
   hidden for store (the device search button through `AppFlavor.deviceSearchExposed`, which is
   false whenever `isStore` is true).
4. `lib/features/devices/views/device_list_page.dart` — the online search FAB is hidden
   for store (also through `deviceSearchExposed`).

Any ungated online search path is an App Store rejection risk (Apple/Google review
guidelines around network scraping of third-party sites in a store-distributed app).
See [Architecture](../architecture.md#appflavor) for how `AppFlavor.isStore` is derived
from the `FLAVOR` dart-define.

## Bundled presets — `preset_service.dart` <a id="bundled-presets--preset_servicedart"></a> <a id="bundled-presets---presetservicedart"></a>

`PresetService` loads bundled preset data from `assets/presets/` via
`rootBundle.loadString()`:

- `cpus.json` → `loadCpus()` → `List<CpuInfo>`
- `gpus.json` → `loadGpus()` → `List<GpuInfo>`
- `brands.json` → `loadBrands()` → `List<BrandEntry>`
- `device_templates.json` → `loadTemplates()` → `List<DeviceTemplate>`

These are **lazy-loaded and cached** — each `loadXxx()` only reads and parses its asset
file once, then reuses the parsed result on subsequent calls, so opening the device
editor repeatedly doesn't re-parse the bundled JSON every time.

### Device thumbnails <a id="device-thumbnails"></a>

A template may carry `image`, a bundled photo of the device in `assets/device_images/`.
VPS templates have no physical device and keep their provider logo.

- **Making one:** `dart run tool/prepare_device_image.dart <photo> assets/device_images/<slug>.png`.
  If the photo is not already transparent, the tool floods in from the edges to remove a plain
  background (only pixels connected to the border, so a white screen inside the device
  survives). It then trims to the device, scales it into a square 64% of the canvas
  (0.64·√2 < 1, so even its corners are inside the circle), and centres it on a transparent
  256 px canvas. Resampling uses premultiplied alpha, so no background-coloured halo remains.
  It verifies the result and exits 1 if the result fails. `--crop=x,y,w,h` first cuts one region
  out of the source (one view from a sheet of several, or one phone from a group shot), and
  `--roundrect=R` replaces the background removal with a rounded-rectangle mask whose corner
  radius is R times the shorter side — for a phone photographed straight on against wood grain or
  cloth, which a flood fill cannot separate from the device (since 1.6.0). `--keep-background`
  skips removal entirely, for an already transparent render whose crop cuts through a neighbouring
  device (one phone out of a manufacturer's colour line-up), where the flood fill would compare
  the transparent pixels' colour with a dark device and eat into it (since 1.6.1). The pipeline
  itself lives in `lib/shared/utils/device_image_processing.dart`, shared with the in-app
  [image editor](devices.md#icon-and-image); the two tool files are thin CLIs over it.
- **Rules**, enforced by `tool/validate_json.dart` and `test/device_image_test.dart` through
  `checkDeviceImage` (in `device_image_processing.dart`, re-exported by `tool/device_image_check.dart`): square, at least 128 px, alpha channel, fully
  transparent corners, and no pixel with alpha > 8 outside the inscribed circle.
- **Licensing:** freely licensed sources (public domain, CC0, CC BY, CC BY-SA) wherever one exists.
  Since 1.6.0 some product images are not freely licensed: ASUS's NUC renders, and manufacturer
  product images supplied by the repository owner (Razer Blade 14, Intel NUC 11, Galaxy Z Fold6 and
  Fold8, AirPods 4). Since 1.6.1 Apple products use Apple's own renders from its tech-specs pages
  (MacBook Air/Pro, iPad mini/Pro, iPhone 14/15 Pro/17/Air, every Apple Watch template, AirPods
  Pro 2), and the Windows Dev Kit 2023 and Surface Laptop 7 use Microsoft Store renders. Their rows
  in `SOURCES.md` say so and name the copyright holder, so they can be replaced when a free image
  appears. Since 1.6.1 every row also has a "Trademarks shown" column naming the brand whose
  product design, name or logo the picture shows. Each
  file's source, author and license is recorded in `assets/device_images/SOURCES.md`. A template
  with no suitable photo has no `image` and falls back to its brand logo.
- **Where it shows:**
  - the template picker (full diameter, `TemplateIcon(circleSafe: true)`);
  - every `DeviceAvatar` whose device has no emoji or photo of its own, showing the thumbnail the
    user chose by hand (`Device.templateImage`) if it is still bundled, else the one its identity
    matches (`PresetService.matchTemplateImage`: normalized exact brand+model, then name, then
    brand+model against the template name).
- **Automatic matching is not stored:** it is display-only, so devices added before 1.5.8 get
  thumbnails too and older builds still show the category icon. Matching stays exact on purpose
  (so "iPhone 15" never claims the "iPhone 15 Pro" photo).
- **Choosing one by hand (since 1.6.1):** when matching misses (a device named differently from
  its template), the editor's **Thumbnail** chip opens a searchable grid
  (`showTemplateImagePicker` in `lib/features/devices/widgets/template_image_picker.dart`). Its
  order comes from `PresetService.rankTemplateImageCandidates`: the exact identity match first,
  then the thumbnails sharing the most words with the device's brand, model and name, then every
  other thumbnail in catalog order, one entry per file (a search also matches the names of sibling
  templates borrowing that file). The first tile, **Automatic**, clears the choice. The choice is
  stored as `templateImage` on the device (the bundled asset path); a path that a later release
  removed is ignored in favour of matching. `DeviceTemplate.toDevice` sets it too, so a device added
  from a template keeps its thumbnail after being renamed.

## Related

- [Devices](devices.md) for how `CpuInfo`/`GpuInfo`/device fields get filled in from
  search results or presets.
- [Data Formats](../data-formats.md) for the exact `CpuInfo`/`GpuInfo` shapes.

Template-picker icons use the bundled `brands.json` catalogue (case-insensitive exact brand
matching), including the existing router and VPS provider marks. `TemplateIcon` contains the whole
transparent SVG in a square 64% of the avatar diameter; no part is cropped by the circle.
Monochrome brand marks follow the theme foreground colour; CloudCone retains its original transparent PNG colours. Brands without an asset retain their
category icon. This picker decoration does not modify the device's user-selected emoji or image.
Each logo's source and license is listed in `assets/logos/SOURCES.md` (since 1.6.1): 41 Simple
Icons files (CC0), 6 public-domain logos from Wikimedia Commons, and 16 whose source was never
recorded. Every logo, service icon and device thumbnail is a trademark of its owner, used only to
identify it; all three `SOURCES.md` files and the in-app License page say so, and state that
these images are not part of the GPL-3.0 source.

The device-template audit covers all 154 entries, enum/field validity, names, dates and preset
references. CPU/GPU names without a matching detail preset remain usable names, not invalid
foreign keys. Samsung S26 and Fold8 template dates use sales availability rather than the
announcement: [S26: 2026-03-11](https://news.samsung.com/global/samsung-galaxy-s26-series-and-galaxy-buds4-series-now-available-worldwide)
and [Fold8: 2026-08-07](https://news.samsung.com/global/samsung-officially-launches-galaxy-z-fold8-ultra-fold8-flip8-watch-ultra2-and-watch9).
