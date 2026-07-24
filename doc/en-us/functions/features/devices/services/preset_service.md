# lib/features/devices/services/preset_service.dart

`PresetService` loads the app's bundled preset data — CPUs, GPUs, brands, and full device
templates — from `assets/presets/*.json` via `rootBundle.loadString()`, lazily parsing and caching
each file on first use. It depends on `CpuInfo`/`GpuInfo`/`StorageInfo`/`Device` from
[`../../models/device.md`](../models/device.md) for the shapes it parses into, and its
`BrandEntry`/`DeviceTemplate` model classes are themselves defined in this file. See
[Online Search and Presets](../../../../features/online-search-and-presets.md#bundled-presets---presetservicedart)
for the bundled-preset concept overview this page verifies against source.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `PresetService._` | private constructor | B | Prevent instantiation; `PresetService` is static-only. |
| [`loadCpus`](#loadcpus) | static method | A | Load and cache the bundled CPU preset list. |
| [`loadGpus`](#loadgpus) | static method | A | Load and cache the bundled GPU preset list. |
| [`loadBrands`](#loadbrands) | static method | A | Load and cache the bundled brand list. |
| [`loadTemplates`](#loadtemplates) | static method | A | Load and cache the bundled device template list. |
| [`BrandEntry`](#brandentry-new) | constructor | A | Create a `BrandEntry` instance. |
| [`BrandEntry.fromJson`](#brandentry-fromjson) | factory constructor | A | Parse a `BrandEntry` from JSON. |
| [`DeviceTemplate`](#devicetemplate-new) | constructor | A | Create a `DeviceTemplate` instance. |
| [`DeviceTemplate._asString`](#_asstring) | private static method | A | Coerce a template's `cpu`/`gpu` JSON value (string or object) to a plain string. |
| [`DeviceTemplate.fromJson`](#devicetemplate-fromjson) | factory constructor | A | Parse a `DeviceTemplate` from JSON. |
| [`DeviceTemplate.toDevice`](#todevice) | method (`DeviceTemplate`) | A | Convert this template into a new `Device`, optionally filling full CPU/GPU detail from presets. |

Row count (11) does not match `grep -c 'Purpose:' preset_service.dart` (10): `DeviceTemplate.fromJson`
(line 156) has no `/// Purpose:` doc-comment block at all — it is a plain one-line `factory`
declaration with no preceding doc comment — while every other declaration in the file has one. It
is still indexed here per the tiering rule that every declaration appears in the table regardless
of whether it carries the auto-generated comment.

## Documentation

### `static Future<List<CpuInfo>> loadCpus()` <a id="loadcpus"></a>
- **Kind:** static method of `PresetService`.
- **Source:** `lib/features/devices/services/preset_service.dart` (line 25).
- **Purpose:** Load the bundled CPU preset list, parsing `assets/presets/cpus.json` only once and
  reusing the parsed result on subsequent calls.
- **Inputs:** None.
- **Returns:** `Future<List<CpuInfo>>`.
- **Side effects:** Reads `assets/presets/cpus.json` via `rootBundle.loadString()` on the first
  call only; populates the static `_cpus` cache field.
- **Algorithm:** 1. If `_cpus` is already populated, return it immediately (no I/O). 2. Otherwise
  load and `jsonDecode` the asset, map each entry of its `cpus` array through `CpuInfo.fromJson`
  (see [`../../models/device.md#cpuinfo-fromjson`](../models/device.md)), cache the resulting
  list in `_cpus`, and return it.
- **Usage:**
  ```dart
  final cpus = await PresetService.loadCpus();
  ```
  (from `device_edit_page.dart`'s `_loadPresets()`, and again from `device_list_page.dart`'s
  `_addFromTemplate()` before calling [`toDevice`](#todevice))
- **Notes:** The cache is process-lifetime and never invalidated — the bundled JSON asset only
  changes with an app update/reinstall, so there is no need to re-read it while the app is running.
  Repeated calls (e.g. opening the device editor multiple times) are effectively free after the
  first.

### `static Future<List<GpuInfo>> loadGpus()` <a id="loadgpus"></a>
- **Kind:** static method of `PresetService`.
- **Source:** `lib/features/devices/services/preset_service.dart` (line 41).
- **Purpose:** Load the bundled GPU preset list, parsing `assets/presets/gpus.json` only once.
- **Inputs:** None.
- **Returns:** `Future<List<GpuInfo>>`.
- **Side effects:** Reads `assets/presets/gpus.json` on first call; populates `_gpus`.
- **Algorithm:** Identical cache-then-load-then-parse shape as [`loadCpus`](#loadcpus), reading the
  `gpus` array and mapping through `GpuInfo.fromJson`.
- **Usage:** Same call pattern as `loadCpus`, from the same two call sites.
- **Notes:** Same process-lifetime caching behavior as `loadCpus`.

### `static Future<List<BrandEntry>> loadBrands()` <a id="loadbrands"></a>
- **Kind:** static method of `PresetService`.
- **Source:** `lib/features/devices/services/preset_service.dart` (line 57).
- **Purpose:** Load the bundled brand list, parsing `assets/presets/brands.json` only once.
- **Inputs:** None.
- **Returns:** `Future<List<BrandEntry>>`.
- **Side effects:** Reads `assets/presets/brands.json` on first call; populates `_brands`.
- **Algorithm:** Same cache-then-load-then-parse shape, reading the `brands` array and mapping
  through [`BrandEntry.fromJson`](#brandentry-fromjson).
- **Usage:**
  ```dart
  final brands = await PresetService.loadBrands();
  ```
  (from `device_edit_page.dart`'s `_loadPresets()`, feeding the brand autocomplete field)
- **Notes:** Same process-lifetime caching behavior as `loadCpus`.

### `static Future<List<DeviceTemplate>> loadTemplates()` <a id="loadtemplates"></a>
- **Kind:** static method of `PresetService`.
- **Source:** `lib/features/devices/services/preset_service.dart` (line 73).
- **Purpose:** Load the bundled full-device template list, parsing
  `assets/presets/device_templates.json` only once.
- **Inputs:** None.
- **Returns:** `Future<List<DeviceTemplate>>`.
- **Side effects:** Reads `assets/presets/device_templates.json` on first call; populates
  `_templates`.
- **Algorithm:** Same cache-then-load pattern, but the asset root is a JSON *array* directly (not
  wrapped in a named key like `cpus`/`gpus`/`brands`), mapped through
  [`DeviceTemplate.fromJson`](#devicetemplate-fromjson).
- **Usage:**
  ```dart
  final templates = await PresetService.loadTemplates();
  ```
  (from `device_list_page.dart`'s `_addFromTemplate()`, populating the template picker bottom
  sheet)
- **Notes:** Same process-lifetime caching behavior as `loadCpus`. Note the differing JSON root
  shape versus the other three `loadXxx` methods — a plain array instead of `{"templates": [...]}`
  — this is a real, source-confirmed asymmetry, not an inconsistency to "fix" in documentation.

### `const BrandEntry({required this.name, this.logo})` <a id="brandentry-new"></a>
- **Kind:** constructor of `BrandEntry`.
- **Source:** `lib/features/devices/services/preset_service.dart` (line 96).
- **Purpose:** Hold one bundled brand's display name and optional logo asset reference.
- **Inputs:** `name` (required); optional `logo`.
- **Returns:** A new `BrandEntry` instance.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Constructed only by [`BrandEntry.fromJson`](#brandentry-fromjson).
- **Notes:** None.

### `factory BrandEntry.fromJson(Map<String, dynamic> json)` <a id="brandentry-fromjson"></a>
- **Kind:** factory constructor of `BrandEntry`.
- **Source:** `lib/features/devices/services/preset_service.dart` (line 103).
- **Purpose:** Parse one brand entry from the decoded `brands.json` array.
- **Inputs:** `json`.
- **Returns:** A new `BrandEntry` with `name` required and `logo` optional.
- **Side effects:** None (throws if `json['name']` is missing/not a string).
- **Algorithm:** Direct field extraction: `name` as a required `String`, `logo` as an optional
  `String?`.
- **Usage:** Called by [`loadBrands`](#loadbrands) for each entry of the `brands` array.
- **Notes:** Unlike the device/CPU/GPU models, `BrandEntry` has no `toJson`/`extraJson` — it is a
  read-only bundled preset, never persisted or merged, so there is nothing to preserve on a
  round-trip.

### `const DeviceTemplate({required this.name, required this.category, ...})` <a id="devicetemplate-new"></a>
- **Kind:** constructor of `DeviceTemplate`.
- **Source:** `lib/features/devices/services/preset_service.dart` (line 128).
- **Purpose:** Hold one bundled full-device template's fields (name, category, brand/model,
  cpu/gpu model strings, ram, storage list, screen, battery, OS, release date).
- **Inputs:** `name`, `category` required; all other fields optional, `storage` defaults to `[]`.
- **Returns:** A new `DeviceTemplate` instance.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment with defaults.
- **Usage:** Constructed only by [`DeviceTemplate.fromJson`](#devicetemplate-fromjson).
- **Notes:** `cpu`/`gpu` are plain model-name strings here, not full `CpuInfo`/`GpuInfo` — full
  detail is only resolved later in [`toDevice`](#todevice) by matching these strings against
  loaded presets.

### `static String? DeviceTemplate._asString(dynamic value)` <a id="_asstring"></a>
- **Kind:** private static method of `DeviceTemplate`.
- **Source:** `lib/features/devices/services/preset_service.dart` (line 150).
- **Purpose:** Normalize a template's `cpu`/`gpu` JSON field, which may be stored either as a plain
  string or as an object with a `model` key, into a plain string.
- **Inputs:** `value` — the raw decoded JSON value for `cpu` or `gpu`.
- **Returns:** `String?` — the string itself, `value['model']` if `value` is a map, or `null` for
  any other shape.
- **Side effects:** None.
- **Algorithm:** `if (value is String) return value；if (value is Map<String, dynamic>) return
  value['model'] as String?; return null.`
- **Usage:** Called twice by [`DeviceTemplate.fromJson`](#devicetemplate-fromjson), for the `cpu`
  and `gpu` fields.
- **Notes:** Exists to tolerate two different authoring shapes for `cpu`/`gpu` in
  `device_templates.json` — a bare model-name string or a small object — without needing two
  separate JSON schemas.

### `factory DeviceTemplate.fromJson(Map<String, dynamic> json)` <a id="devicetemplate-fromjson"></a>
- **Kind:** factory constructor of `DeviceTemplate`.
- **Source:** `lib/features/devices/services/preset_service.dart` (line 156).
- **Purpose:** Parse one device template from the decoded `device_templates.json` array.
- **Inputs:** `json`.
- **Returns:** A new `DeviceTemplate`; `storage` defaults to `[]` if absent; `releaseDate` is parsed
  via `DateTime.parse` only when present.
- **Side effects:** None.
- **Algorithm:** Direct field extraction; `category` via `DeviceCategory.fromJson`; `cpu`/`gpu` via
  [`_asString`](#_asstring); `storage` mapped through `StorageInfo.fromJson` when present.
- **Usage:** Called by [`loadTemplates`](#loadtemplates) for each element of the top-level JSON
  array.
- **Notes:** This declaration has no `/// Purpose:` doc comment in source (see the row-count note
  above the Declarations table) — its behavior here was confirmed by reading the implementation
  directly, not by paraphrasing a doc comment.

### `Device DeviceTemplate.toDevice({List<CpuInfo>? cpuPresets, List<GpuInfo>? gpuPresets})` <a id="todevice"></a>
- **Kind:** method of `DeviceTemplate`.
- **Source:** `lib/features/devices/services/preset_service.dart` (line 187).
- **Purpose:** Convert this template into a new `Device`, pre-filling all template fields and
  optionally upgrading the plain `cpu`/`gpu` model-name strings to full `CpuInfo`/`GpuInfo` detail
  by matching them against loaded presets.
- **Inputs:** Optional `cpuPresets`/`gpuPresets` — typically the lists from
  [`loadCpus`](#loadcpus)/[`loadGpus`](#loadgpus).
- **Returns:** A new `Device` (a fresh `id`/`modifiedAt` via the `Device` constructor — see
  [`../../models/device.md#device-new`](../models/device.md)); only the template's `storage`
  list's *first* entry is carried over (`storage.isNotEmpty ? [storage.first] : []`).
- **Side effects:** None.
- **Algorithm:** 1. Start with `CpuInfo(model: cpu)`/`GpuInfo(model: gpu)` as a fallback. 2. If
  `cpu`/`cpuPresets` are both present, look for a preset whose `model` exactly equals `cpu` and use
  it if found. 3. For GPU, try an exact `model` match first; if none, fall back to a *prefix* match
  (`model!.startsWith(gpu!)`) — this handles GPU presets with a core-count suffix like "(10-core)"
  that wouldn't exact-match the template's bare model string. 4. Construct and return the `Device`
  with all template fields plus the resolved `cpuInfo`/`gpuInfo`.
- **Usage:**
  ```dart
  final device = template.toDevice(cpuPresets: cpus, gpuPresets: gpus);
  await Navigator.of(context, rootNavigator: true) /* ... push edit page with device ... */;
  ```
  (from `device_list_page.dart`'s `_addFromTemplate()`, after the user picks a template from the
  bottom sheet)
- **Notes:** Only the first `storage` entry from the template is used even if the template lists
  multiple; this matches `Device.storage`'s general usage in this app (see
  [`../../models/device.md`](../models/device.md)) where most devices have a single primary
  storage entry.
