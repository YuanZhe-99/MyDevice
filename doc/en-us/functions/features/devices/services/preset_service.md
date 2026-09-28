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
| `cachedTemplates` | static getter | B | Return the template list if already loaded, else null, so widgets can match synchronously. |
| [`findTemplateImage`](#findtemplateimage) | static method | A | Load the templates and return the thumbnail a device identity matches. |
| [`matchTemplateImage`](#matchtemplateimage) | static method | A | Match a device identity to a template thumbnail by normalized equality. |
| `_identityKey` | private static method | B | Lowercase and strip non-alphanumerics to form a comparison key. |
| [`BrandEntry`](#brandentry-new) | constructor | A | Create a `BrandEntry` instance. |
| [`BrandEntry.fromJson`](#brandentry-fromjson) | factory constructor | A | Parse a `BrandEntry` from JSON. |
| [`DeviceTemplate`](#devicetemplate-new) | constructor | A | Create a `DeviceTemplate` instance. |
| [`DeviceTemplate._asString`](#_asstring) | private static method | A | Coerce a template's `cpu`/`gpu` JSON value (string or object) to a plain string. |
| [`DeviceTemplate._asCpuInfo`](#_ascpuinfo) | private static method | A | Keep the detail an object-form `cpu` carries beyond its model. |
| [`DeviceTemplate.fromJson`](#devicetemplate-fromjson) | factory constructor | A | Parse a `DeviceTemplate` from JSON. |
| [`DeviceTemplate.toDevice`](#todevice) | method (`DeviceTemplate`) | A | Convert this template into a new `Device`, optionally filling full CPU/GPU detail from presets. |

Row count (16) matches `grep -c 'Purpose:' preset_service.dart` (16) exactly. `DeviceTemplate.fromJson`
previously had no `/// Purpose:` block; it gained one in 1.5.8 when it started parsing `image`.

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

### `static Future<String?> findTemplateImage({String? brand, String? model, String? name})` <a id="findtemplateimage"></a>
- **Kind:** static method of `PresetService`.
- **Source:** `lib/features/devices/services/preset_service.dart` (line 101).
- **Purpose:** Return the bundled thumbnail of the template a device matches.
- **Inputs:** The device's `brand`, `model` and `name`.
- **Returns:** The template's `image` asset path, or null.
- **Side effects:** Loads and caches the template catalog on first use (via
  [`loadTemplates`](#loadtemplates)).
- **Algorithm:** `loadTemplates()` then [`matchTemplateImage`](#matchtemplateimage).
- **Usage:** `DeviceAvatar` calls it while the catalog is not yet cached; once it is,
  the avatar calls `matchTemplateImage(cachedTemplates!, …)` synchronously.
- **Notes:** Display-only. The path is never written into the device, so `devices.json`, sync
  and backup are unchanged, and devices added before thumbnails existed pick one up too.

### `static String? matchTemplateImage(List<DeviceTemplate> templates, {String? brand, String? model, String? name})` <a id="matchtemplateimage"></a>
- **Kind:** static method of `PresetService`.
- **Source:** `lib/features/devices/services/preset_service.dart` (line 120).
- **Purpose:** Match a device identity to a template thumbnail.
- **Inputs:** `templates`; the device's `brand`, `model`, `name`.
- **Returns:** The first matching template's `image`, or null.
- **Side effects:** None.
- **Algorithm:** Only templates with an `image` take part. Keys are lowercased with every
  non-alphanumeric removed (`_identityKey`), then compared for **equality**, in this order:
  1. device brand+model = template brand+model (only when the device has a model);
  2. device name = template name;
  3. device brand+model = template name.
- **Usage:** `PresetService.matchTemplateImage(templates, brand: 'Apple', model: 'iPhone 15 Pro')`.
- **Notes:** Equality, not containment, so `iPhone 15` never claims the `iPhone 15 Pro` photo and a
  bare `iPhone` matches nothing. `iPad Pro 13" (M4)` and `ipad pro 13 m4` compare equal.

### `const BrandEntry({required this.name, this.logo})` <a id="brandentry-new"></a>
- **Kind:** constructor of `BrandEntry`.
- **Source:** `lib/features/devices/services/preset_service.dart` (line 171).
- **Purpose:** Hold one bundled brand's display name and optional logo asset reference.
- **Inputs:** `name` (required); optional `logo`.
- **Returns:** A new `BrandEntry` instance.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Constructed only by [`BrandEntry.fromJson`](#brandentry-fromjson).
- **Notes:** None.

### `factory BrandEntry.fromJson(Map<String, dynamic> json)` <a id="brandentry-fromjson"></a>
- **Kind:** factory constructor of `BrandEntry`.
- **Source:** `lib/features/devices/services/preset_service.dart` (line 178).
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
- **Source:** `lib/features/devices/services/preset_service.dart` (line 217).
- **Purpose:** Hold one bundled full-device template's fields (name, category, brand/model,
  cpu/gpu model strings, ram, storage list, screen, battery, OS, release date, and the optional
  `image` thumbnail asset).
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
- **Source:** `lib/features/devices/services/preset_service.dart` (line 244).
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
- **Source:** `lib/features/devices/services/preset_service.dart` (line 270).
- **Purpose:** Parse one device template from the decoded `device_templates.json` array.
- **Inputs:** `json`.
- **Returns:** A new `DeviceTemplate`; `storage` defaults to `[]` if absent; `releaseDate` is parsed
  via `DateTime.parse` only when present.
- **Side effects:** None.
- **Algorithm:** Direct field extraction; `category` via `DeviceCategory.fromJson`; `cpu`/`gpu` via
  [`_asString`](#_asstring); `storage` mapped through `StorageInfo.fromJson` when present; the
  optional `image` string copied as is.
- **Usage:** Called by [`loadTemplates`](#loadtemplates) for each element of the top-level JSON
  array.
- **Notes:** `image` is not checked here; `tool/validate_json.dart` enforces its location and
  pixel rules.

### `static CpuInfo? DeviceTemplate._asCpuInfo(dynamic value)` <a id="_ascpuinfo"></a>
- **Kind:** private static method of `DeviceTemplate`.
- **Source:** `lib/features/devices/services/preset_service.dart` (line 260).
- **Purpose:** Keep the detail an object-form `cpu` carries beyond its model name.
- **Inputs:** `value` — the raw `cpu` JSON value.
- **Returns:** A `CpuInfo` when the template authored an object, otherwise null.
- **Side effects:** None.
- **Notes:** The 14 VPS templates author `architecture` and `performanceCores` inside `cpu`.
  [`_asString`](#_asstring) keeps only `['model']`, so before this existed the rest was discarded at
  parse time — and `toDevice`'s exact-match preset lookup could not recover it either, because names
  like `Intel Xeon` and `Ampere Altra` are deliberately not in `cpus.json`. The authored data never
  reached the UI at all.

### `Device DeviceTemplate.toDevice({List<CpuInfo>? cpuPresets, List<GpuInfo>? gpuPresets, int storageIndex = 0})` <a id="todevice"></a>
- **Kind:** method of `DeviceTemplate`.
- **Source:** `lib/features/devices/services/preset_service.dart` (line 310).
- **Purpose:** Convert this template into a new `Device`, pre-filling all template fields and
  optionally upgrading the plain `cpu`/`gpu` model-name strings to full `CpuInfo`/`GpuInfo` detail
  by matching them against loaded presets.
- **Inputs:** Optional `cpuPresets`/`gpuPresets` — typically the lists from
  [`loadCpus`](#loadcpus)/[`loadGpus`](#loadgpus) — and `storageIndex`, which selects among the
  capacities the template offers.
- **Returns:** A new `Device` (a fresh `id`/`modifiedAt` via the `Device` constructor — see
  [`../../models/device.md#device-new`](../models/device.md)) carrying the single capacity named
  by `storageIndex`, clamped into range.
- **Side effects:** None.
- **Algorithm:** 1. Start with `CpuInfo(model: cpu)`/`GpuInfo(model: gpu)` as a fallback. 2. If
  `cpu`/`cpuPresets` are both present, look for a preset whose `model` exactly equals `cpu` and use
  it if found; then, if the template carried a non-empty `cpuDetail`, that wins outright. 3. For
  GPU, try an exact `model` match first; if none, fall back to a *prefix* match
  (`model!.startsWith(gpu!)`) — this handles GPU presets with a core-count suffix like "(10-core)"
  that wouldn't exact-match the template's bare model string. 4. Construct and return the `Device`
  with all template fields plus the resolved `cpuInfo`/`gpuInfo`.
- **Usage:**
  ```dart
  final device = choice.template.toDevice(
    cpuPresets: cpus,
    gpuPresets: gpus,
    storageIndex: choice.storageIndex,
  );
  ```
  (from `device_list_page.dart`'s `_addFromTemplate()`, after the user picks a template — and, for
  a multi-capacity template, a capacity — from the bottom sheet)
- **Notes:** `storageIndex` exists because this method previously hardcoded `storage.first`, which
  made every multi-capacity template collapse to its smallest option with no way to choose — a
  MacBook Pro template listing 512 GB through 4 TB always produced 512 GB. The index is clamped
  rather than range-checked, so an out-of-date caller cannot throw. `cpuDetail` takes priority over
  the preset lookup because the VPS templates author `architecture` and core counts for chips such
  as `Intel Xeon` and `Ampere Altra` that are deliberately absent from `cpus.json`, so the preset
  lookup could never have recovered them.

Template-picker icons prefer the template's own `image` thumbnail, shown full-size because it is
already circle-safe. Without one they use the bundled `brands.json` catalogue (case-insensitive
exact brand matching), including the existing router and VPS provider marks. `TemplateIcon` contains the whole
transparent SVG in a square 64% of the avatar diameter; no part is cropped by the circle.
Monochrome brand marks follow the theme foreground colour; CloudCone retains its original transparent PNG colours. Brands without an asset retain their
category icon. This picker decoration does not modify the device's user-selected emoji or image.
