# Online Search and Presets

Sources: `lib/features/devices/services/device_search_service.dart`,
`lib/features/devices/services/chip_search_service.dart`, and
`lib/features/devices/services/preset_service.dart`. See
[Architecture](../architecture.md#appflavor) for `AppFlavor` and
[Data Formats](../data-formats.md) for the `CpuInfo`/`GpuInfo` shapes these fill in.

## Device spec search — `device_search_service.dart`

`DeviceSearchService` fetches device specs from two sources, run concurrently over one
shared client, each reporting its own outcome rather than swallowing failures:

- **Notebookcheck** (`_searchNotebookcheck` / `_fetchNotebookcheckDetail`) — laptops,
  tablets, phones and smartwatches; the detail page carries a full spec table.
- **PhoneDB** (`_searchPhonedb` / `_fetchPhonedbDetail`) — phones at SKU level, behind a
  relevance gate because it answers an unknown model with a loose full-text match.

All markup parsing lives in `device_search_parsers.dart`, which is network-free and unit
tested against saved fixtures in `test/fixtures/`.

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

`tool/check_sources.dart` probes every source and prints the same classification, so
scraper rot can be checked with one command instead of being noticed by a user. It is
deliberately **not** wired into CI, because it makes real third-party network requests.

## Chip spec search — `chip_search_service.dart`

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
   hidden for store.
4. `lib/features/devices/views/device_list_page.dart` — the online search FAB is hidden
   for store.

Any ungated online search path is an App Store rejection risk (Apple/Google review
guidelines around network scraping of third-party sites in a store-distributed app).
See [Architecture](../architecture.md#appflavor) for how `AppFlavor.isStore` is derived
from the `FLAVOR` dart-define.

## Bundled presets — `preset_service.dart`

`PresetService` loads bundled preset data from `assets/presets/` via
`rootBundle.loadString()`:

- `cpus.json` → `loadCpus()` → `List<CpuInfo>`
- `gpus.json` → `loadGpus()` → `List<GpuInfo>`
- `brands.json` → `loadBrands()` → `List<BrandEntry>`
- `device_templates.json` → `loadTemplates()` → `List<DeviceTemplate>`

These are **lazy-loaded and cached** — each `loadXxx()` only reads and parses its asset
file once, then reuses the parsed result on subsequent calls, so opening the device
editor repeatedly doesn't re-parse the bundled JSON every time.

## Related

- [Devices](devices.md) for how `CpuInfo`/`GpuInfo`/device fields get filled in from
  search results or presets.
- [Data Formats](../data-formats.md) for the exact `CpuInfo`/`GpuInfo` shapes.
