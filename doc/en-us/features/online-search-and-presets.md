# Online Search and Presets

Sources: `lib/features/devices/services/device_search_service.dart`,
`lib/features/devices/services/chip_search_service.dart`, and
`lib/features/devices/services/preset_service.dart`. See
[Architecture](../architecture.md#appflavor) for `AppFlavor` and
[Data Formats](../data-formats.md) for the `CpuInfo`/`GpuInfo` shapes these fill in.

## Device spec search — `device_search_service.dart`

`DeviceSearchService` fetches device specs from two sources, run concurrently and each
individually error-swallowed:

- **GSMArena** (`_searchGSMArena` / `_fetchGSMArenaDetail`).
- **Notebookcheck** (`_searchNotebookcheck` / `_fetchNotebookcheckDetail`).

```dart
static Future<List<DeviceSearchResult>> search(String query) async {
  if (AppFlavor.isStore) return [];
  ...
}
```

Both `search()` and `fetchDetail()` return early (empty list / the unmodified input
result) when `AppFlavor.isStore` is true — confirmed directly in source.

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
