# lib/features/devices/models/device.dart

The core device model: `Device` itself plus every value type it's built from (`CpuInfo`, `GpuInfo`,
`StorageInfo`, `MoneyValue`, `DeviceRecurringCost`) and their supporting enums
(`DeviceCategory`, `DeviceAcquisitionType`, `DeviceLifecycleStatus`, `RecurringCostKind`,
`BillingCycle`, `StorageType`, `RamType`, `StorageInterface`), plus the top-level `DeviceData`
container persisted by [`../services/device_storage.md`](../services/device_storage.md). Every
model here follows the app's standard shape: a `const`/plain constructor, `toJson`/`fromJson`, and
a `mergeUnknownFieldsFrom` that participates in the three-way sync merge (see
[Three-Way Merge](../../../../algorithms/three-way-merge.md) and
[`../../../../shared/utils/json_preservation.md`](../../../shared/utils/json_preservation.md)
for the generic `unknownJsonFields`/`mergeUnknownJsonFields` helpers every `fromJson`/
`mergeUnknownFieldsFrom` here calls). See [Devices](../../../../features/devices.md) for the
lifecycle/finance behavior this page documents against real source, and
[Data Formats](../../../../data-formats.md#device-libfeaturesdevicesmodelsdevicedart) for the
exhaustive persisted-field reference.

This file is large (58 declarations across 14 enums/classes); see the note at the end of the
Declarations table for how its row count compares to the file's `/// Purpose:` doc-comment count.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `jsonValue` | getter (`DeviceCategory`) | B | Return the serialized enum name. |
| [`DeviceCategory.fromJson`](#devicecategory-fromjson) | static method | A | Parse a `DeviceCategory`, defaulting to `other` on no match. |
| `jsonValue` | getter (`DeviceAcquisitionType`) | B | Return the serialized enum name. |
| [`DeviceAcquisitionType.fromJson`](#deviceacquisitiontype-fromjson) | static method | A | Parse a `DeviceAcquisitionType`, or `null`. |
| `jsonValue` | getter (`RecurringCostKind`) | B | Return the serialized enum name. |
| [`RecurringCostKind.fromJson`](#recurringcostkind-fromjson) | static method | A | Parse a `RecurringCostKind`, defaulting to `other`. |
| `jsonValue` | getter (`BillingCycle`) | B | Return the serialized enum name. |
| [`BillingCycle.fromJson`](#billingcycle-fromjson) | static method | A | Parse a `BillingCycle`, defaulting to `monthly`. |
| [`CpuInfo`](#cpuinfo-new) | constructor | A | Create a `CpuInfo` instance. |
| `isEmpty` | getter (`CpuInfo`) | B | Return whether every field is unset. |
| [`toJson`](#cpuinfo-tojson) | method (`CpuInfo`) | A | Serialize this value into a JSON-compatible map. |
| [`CpuInfo.fromJson`](#cpuinfo-fromjson) | factory constructor | A | Parse a `CpuInfo` from JSON, tolerating the legacy `cores` key. |
| [`mergeUnknownFieldsFrom`](#cpuinfo-mergeunknownfieldsfrom) | method (`CpuInfo`) | A | Three-way merge unknown JSON fields from another `CpuInfo`. |
| [`GpuInfo`](#gpuinfo-new) | constructor | A | Create a `GpuInfo` instance. |
| `isEmpty` | getter (`GpuInfo`) | B | Return whether every field is unset. |
| [`toJson`](#gpuinfo-tojson) | method (`GpuInfo`) | A | Serialize this value into a JSON-compatible map. |
| [`GpuInfo.fromJson`](#gpuinfo-fromjson) | factory constructor | A | Parse a `GpuInfo` from JSON. |
| [`mergeUnknownFieldsFrom`](#gpuinfo-mergeunknownfieldsfrom) | method (`GpuInfo`) | A | Three-way merge unknown JSON fields from another `GpuInfo`. |
| `jsonValue` | getter (`StorageType`) | B | Return the serialized enum name. |
| [`StorageType.fromJson`](#storagetype-fromjson) | static method | A | Parse a `StorageType`, or `null`. |
| `jsonValue` | getter (`RamType`) | B | Return the serialized enum name. |
| [`displayName`](#ramtype-displayname) | getter (`RamType`) | A | Return the human-readable RAM standard name (e.g. `"LPDDR5X"`). |
| [`RamType.fromJson`](#ramtype-fromjson) | static method | A | Parse a `RamType`, or `null`. |
| `jsonValue` | getter (`StorageInterface`) | B | Return the serialized enum name. |
| [`StorageInterface.fromJson`](#storageinterface-fromjson) | static method | A | Parse a `StorageInterface`, or `null`. |
| [`StorageInfo`](#storageinfo-new) | constructor | A | Create a `StorageInfo` instance. |
| `isEmpty` | getter (`StorageInfo`) | B | Return whether every field is unset. |
| [`displayString`](#storageinfo-displaystring) | getter (`StorageInfo`) | A | Build a human-readable summary (e.g. `"512 GB SSD (M.2 NVMe)"`). |
| [`toJson`](#storageinfo-tojson) | method (`StorageInfo`) | A | Serialize this value into a JSON-compatible map. |
| [`StorageInfo.fromJson`](#storageinfo-fromjson) | factory constructor | A | Parse a `StorageInfo` from JSON or a legacy plain string. |
| [`mergeUnknownFieldsFrom`](#storageinfo-mergeunknownfieldsfrom) | method (`StorageInfo`) | A | Three-way merge unknown JSON fields from another `StorageInfo`. |
| [`MoneyValue`](#moneyvalue-new) | constructor | A | Create a `MoneyValue` instance. |
| [`toJson`](#moneyvalue-tojson) | method (`MoneyValue`) | A | Serialize this value into a JSON-compatible map. |
| [`MoneyValue.fromJson`](#moneyvalue-fromjson) | factory constructor | A | Parse a `MoneyValue` from JSON, tolerating legacy keys. |
| [`mergeUnknownFieldsFrom`](#moneyvalue-mergeunknownfieldsfrom) | method (`MoneyValue`) | A | Three-way merge unknown JSON fields from another `MoneyValue`. |
| [`DeviceRecurringCost`](#devicerecurringcost-new) | constructor | A | Create a `DeviceRecurringCost` instance. |
| [`annualConvertedAmount`](#devicerecurringcost-annualconvertedamount) | getter (`DeviceRecurringCost`) | A | Project this cost to a yearly converted amount based on `billingCycle`. |
| `dailyConvertedAmount` | getter (`DeviceRecurringCost`) | B | Divide `annualConvertedAmount` by 365. |
| [`toJson`](#devicerecurringcost-tojson) | method (`DeviceRecurringCost`) | A | Serialize this value into a JSON-compatible map. |
| [`DeviceRecurringCost.fromJson`](#devicerecurringcost-fromjson) | factory constructor | A | Parse a `DeviceRecurringCost` from JSON. |
| [`mergeUnknownFieldsFrom`](#devicerecurringcost-mergeunknownfieldsfrom) | method (`DeviceRecurringCost`) | A | Three-way merge unknown JSON fields, including the nested `price`. |
| [`Device`](#device-new) | constructor | A | Create a `Device` instance (fresh `id`/`modifiedAt` by default). |
| [`lifecycleStatus`](#lifecyclestatus) | getter (`Device`) | A | Derive `sold`/`retired`/`inService`, sold taking priority. |
| `isInService` | getter (`Device`) | B | Return whether `lifecycleStatus == inService`. |
| [`hasFinancialData`](#hasfinancialdata) | getter (`Device`) | A | Return whether any purchase/sold price or recurring cost is present. |
| [`serviceDays`](#servicedays) | method (`Device`) | A | Compute days in service from `purchaseDate` through now or `retiredDate`. |
| [`recurringCostThrough`](#recurringcostthrough) | method (`Device`) | A | Sum each recurring cost's daily rate across `serviceDays`. |
| [`totalCost`](#totalcost) | method (`Device`) | A | Compute purchase price plus recurring costs minus sold price. |
| [`averageDailyCost`](#averagedailycost) | method (`Device`) | A | Divide `totalCost` by `serviceDays`, or `null` without financial data. |
| [`ppi`](#ppi) | getter (`Device`) | A | Compute pixels-per-inch from resolution and screen diagonal. |
| [`_parseScreenDiagonal`](#_parsescreendiagonal) | static method (private) | A | Parse a screen-size string (e.g. `"6.7\""`) into inches. |
| [`copyWith`](#copywith) | method (`Device`) | A | Create a copy with any subset of fields replaced or cleared. |
| [`toJson`](#device-tojson) | method (`Device`) | A | Serialize this value into a JSON-compatible map. |
| [`Device.fromJson`](#device-fromjson) | factory constructor | A | Parse a `Device` from JSON, tolerating the legacy string `storage` shape. |
| [`mergeUnknownFieldsFrom`](#device-mergeunknownfieldsfrom) | method (`Device`) | A | Merge unknown fields plus nested cpu/gpu/storage/price/recurring-cost structures. |
| [`DeviceData`](#devicedata-new) | constructor | A | Create a `DeviceData` instance. |
| [`toJson`](#devicedata-tojson) | method (`DeviceData`) | A | Serialize this value into a JSON-compatible map. |
| [`DeviceData.fromJson`](#devicedata-fromjson) | factory constructor | A | Parse a `DeviceData` from JSON. |

Row count (58) does not match `grep -c 'Purpose:' device.dart` (31). Every declaration through
`StorageInterface.fromJson` (25 rows) carries the auto-generated `/// Purpose:` doc-comment block,
and `DeviceData`'s three declarations (the last 3 rows) do too — 28 of those 31 comments, plus
`StorageInfo`'s constructor/`isEmpty`/`displayString` (3 more) account for all 31. Starting at
`StorageInfo.toJson` and continuing through the entire `MoneyValue`, `DeviceRecurringCost`, and
`Device` classes (27 declarations: `StorageInfo.toJson`/`fromJson`/`mergeUnknownFieldsFrom`, all
four `MoneyValue` declarations, all six `DeviceRecurringCost` declarations, and all fourteen
`Device` declarations), there is no `/// Purpose:` block at all — not even a plain doc comment in
most cases. This was confirmed by reading the file directly, not assumed from the comment density;
every one of those 27 declarations is still indexed here per the tiering rule that every
declaration appears regardless of whether it carries the auto-generated comment. `DeviceLifecycleStatus`
(a bare three-value enum with no getters/methods of its own) has no row, consistent with how this
doc set indexes only executable declarations, not bare type declarations.

## Documentation

### `static DeviceCategory fromJson(String value)` <a id="devicecategory-fromjson"></a>
- **Kind:** static method of enum `DeviceCategory`.
- **Source:** `lib/features/devices/models/device.dart` (line 103).
- **Purpose:** Parse a `DeviceCategory` from its serialized name, defaulting to `other` for any
  unrecognized value.
- **Inputs:** `value`.
- **Returns:** `DeviceCategory` — never `null`.
- **Side effects:** None.
- **Algorithm:** `DeviceCategory.values.firstWhere((e) => e.name == value, orElse: () =>
  DeviceCategory.other)`.
- **Usage:**
  ```dart
  category: DeviceCategory.fromJson(json['category'] as String),
  ```
  (from [`Device.fromJson`](#device-fromjson) and `DeviceTemplate.fromJson`, see
  [`../services/preset_service.md`](../services/preset_service.md))
- **Notes:** Unlike most other `fromJson` enum parsers in this file, this one never returns `null`
  — an unrecognized category degrades to `other` rather than requiring every caller to handle a
  missing category.

### `static DeviceAcquisitionType? fromJson(String? value)` <a id="deviceacquisitiontype-fromjson"></a>
- **Kind:** static method of enum `DeviceAcquisitionType`.
- **Source:** `lib/features/devices/models/device.dart` (line 126).
- **Purpose:** Parse a `DeviceAcquisitionType` from its serialized name.
- **Inputs:** `value` — nullable.
- **Returns:** `DeviceAcquisitionType?` — `null` if `value` is `null` or unrecognized.
- **Side effects:** None.
- **Algorithm:** Null-check, then `DeviceAcquisitionType.values.where((e) => e.name ==
  value).firstOrNull`.
- **Usage:** Called by [`Device.fromJson`](#device-fromjson) for `acquisitionType`.
- **Notes:** Unlike `DeviceCategory.fromJson`, an unrecognized value here yields `null` (no
  acquisition type recorded), not a fallback enum value.

### `static RecurringCostKind fromJson(String? value)` <a id="recurringcostkind-fromjson"></a>
- **Kind:** static method of enum `RecurringCostKind`.
- **Source:** `lib/features/devices/models/device.dart` (line 156).
- **Purpose:** Parse a `RecurringCostKind`, defaulting to `other` when unrecognized or absent.
- **Inputs:** `value` — nullable.
- **Returns:** `RecurringCostKind` — never `null`.
- **Side effects:** None.
- **Algorithm:** `RecurringCostKind.values.where((e) => e.name == value).firstOrNull ??
  RecurringCostKind.other`.
- **Usage:** Called by [`DeviceRecurringCost.fromJson`](#devicerecurringcost-fromjson).
- **Notes:** None.

### `static BillingCycle fromJson(String? value)` <a id="billingcycle-fromjson"></a>
- **Kind:** static method of enum `BillingCycle`.
- **Source:** `lib/features/devices/models/device.dart` (line 178).
- **Purpose:** Parse a `BillingCycle`, defaulting to `monthly` when unrecognized or absent.
- **Inputs:** `value` — nullable.
- **Returns:** `BillingCycle` — never `null`.
- **Side effects:** None.
- **Algorithm:** `BillingCycle.values.where((e) => e.name == value).firstOrNull ??
  BillingCycle.monthly`.
- **Usage:** Called by [`DeviceRecurringCost.fromJson`](#devicerecurringcost-fromjson).
- **Notes:** `monthly` is the fallback for both "absent" and "unrecognized" — a recurring cost
  with a malformed/missing `billingCycle` is treated as monthly, matching the constructor's own
  default.

### `const CpuInfo({this.model, this.architecture, this.frequency, this.performanceCores, this.efficiencyCores, this.threads, this.cache, this.extraJson = const {}})` <a id="cpuinfo-new"></a>
- **Kind:** constructor of `CpuInfo`.
- **Source:** `lib/features/devices/models/device.dart` (line 199).
- **Purpose:** Hold a device's CPU specs — model, architecture, frequency, core/thread counts,
  cache — plus any unrecognized JSON fields.
- **Inputs:** All fields optional; `extraJson` defaults to `{}`.
- **Returns:** A new `CpuInfo`.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment with defaults.
- **Usage:** Constructed directly by `device_edit_page.dart`'s save handler (see the CPU field
  block), by [`../services/preset_service.md#todevice`](../services/preset_service.md), and via
  [`CpuInfo.fromJson`](#cpuinfo-fromjson)/`ChipSearchResult.toCpuInfo` (see
  [`../services/chip_search_service.md`](../services/chip_search_service.md)).
- **Notes:** `const Device(cpu: const CpuInfo())` (an all-null, empty `extraJson` instance) is the
  default when a device has no CPU recorded — see [`isEmpty`](#cpuinfo-new) below.

### `Map<String, dynamic> toJson()` <a id="cpuinfo-tojson"></a>
- **Kind:** method of `CpuInfo`.
- **Source:** `lib/features/devices/models/device.dart` (line 230).
- **Purpose:** Serialize this CPU spec into the JSON persisted inside a device's `cpu` field.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` — `extraJson` spread first, then only the non-null known
  fields.
- **Side effects:** None.
- **Algorithm:** `{...extraJson, if (field != null) 'field': field, ...}` for each of the seven
  known fields.
- **Usage:** Called by [`Device.toJson`](#device-tojson) (only when `!cpu.isEmpty`) and by
  [`mergeUnknownFieldsFrom`](#cpuinfo-mergeunknownfieldsfrom).
- **Notes:** Spreading `extraJson` *before* the known fields means a known field always wins if an
  unrecognized key happened to collide with a known key name.

### `factory CpuInfo.fromJson(Map<String, dynamic> json)` <a id="cpuinfo-fromjson"></a>
- **Kind:** factory constructor of `CpuInfo`.
- **Source:** `lib/features/devices/models/device.dart` (line 246).
- **Purpose:** Parse a `CpuInfo` from JSON, tolerating an older `cores` key in place of
  `performanceCores`.
- **Inputs:** `json`.
- **Returns:** A new `CpuInfo`; `extraJson` holds every key not in `_cpuInfoJsonKeys`.
- **Side effects:** None.
- **Algorithm:** Direct field extraction for each known key; `performanceCores` reads
  `json['performanceCores'] as int? ?? json['cores'] as int?` — the legacy fallback.
- **Usage:** Called by [`Device.fromJson`](#device-fromjson) (when `json['cpu']` is present) and
  by `PresetService.loadCpus` (see [`../services/preset_service.md`](../services/preset_service.md)).
- **Notes:** The `cores`→`performanceCores` fallback is the only legacy-format tolerance in this
  class — it exists to read data written before `performanceCores`/`efficiencyCores` were split
  out as separate fields.

### `CpuInfo mergeUnknownFieldsFrom(CpuInfo other, {CpuInfo? base})` <a id="cpuinfo-mergeunknownfieldsfrom"></a>
- **Kind:** method of `CpuInfo`.
- **Source:** `lib/features/devices/models/device.dart` (line 262).
- **Purpose:** Three-way merge this `CpuInfo`'s unknown JSON fields with another's, so unrecognized
  keys survive a sync merge the same way known fields do.
- **Inputs:** `other` — the other side (typically remote when `this` is local); optional `base` —
  the last-synced snapshot.
- **Returns:** A new `CpuInfo` — same known fields as `this`, `extraJson` replaced by the merged
  result.
- **Side effects:** None.
- **Algorithm:** Re-parse `{...toJson(), ...mergeUnknownJsonFields(primary: extraJson, secondary:
  other.extraJson, base: base?.extraJson)}` through `CpuInfo.fromJson` — see
  [`mergeUnknownJsonFields`](../../../shared/utils/json_preservation.md) for the underlying
  per-key three-way merge rule.
- **Usage:** Called by [`Device.mergeUnknownFieldsFrom`](#device-mergeunknownfieldsfrom) to merge
  `device.cpu` alongside the rest of the record.
- **Notes:** Only `extraJson` is merged here — the *known* CPU fields (`model`, `frequency`, etc.)
  always come from `this` (the primary side), matching how `Device.mergeUnknownFieldsFrom` treats
  nested value objects generally.

### `const GpuInfo({this.model, this.architecture, this.extraJson = const {}})` <a id="gpuinfo-new"></a>
- **Kind:** constructor of `GpuInfo`.
- **Source:** `lib/features/devices/models/device.dart` (line 285).
- **Purpose:** Hold a device's GPU model/architecture plus any unrecognized JSON fields.
- **Inputs:** All fields optional; `extraJson` defaults to `{}`.
- **Returns:** A new `GpuInfo`.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Same call sites as [`CpuInfo`](#cpuinfo-new): direct construction in
  `device_edit_page.dart`, `preset_service.dart`'s `toDevice`, and `ChipSearchResult.toGpuInfo`.
- **Notes:** `GpuInfo` has far fewer fields than `CpuInfo` — only `model`/`architecture` are
  modeled explicitly; anything else observed online (from
  [`../services/chip_search_service.md`](../services/chip_search_service.md)) would need to flow
  through `extraJson`.

### `Map<String, dynamic> toJson()` <a id="gpuinfo-tojson"></a>
- **Kind:** method of `GpuInfo`.
- **Source:** `lib/features/devices/models/device.dart` (line 300).
- **Purpose:** Serialize this GPU spec into the JSON persisted inside a device's `gpu` field.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>`.
- **Side effects:** None.
- **Algorithm:** Same spread-then-known-fields shape as `CpuInfo.toJson`, with only two known
  fields.
- **Usage:** Called by [`Device.toJson`](#device-tojson) (only when `!gpu.isEmpty`) and by
  [`mergeUnknownFieldsFrom`](#gpuinfo-mergeunknownfieldsfrom).
- **Notes:** None.

### `factory GpuInfo.fromJson(Map<String, dynamic> json)` <a id="gpuinfo-fromjson"></a>
- **Kind:** factory constructor of `GpuInfo`.
- **Source:** `lib/features/devices/models/device.dart` (line 311).
- **Purpose:** Parse a `GpuInfo` from JSON.
- **Inputs:** `json`.
- **Returns:** A new `GpuInfo`; `extraJson` holds every key not in `_gpuInfoJsonKeys`.
- **Side effects:** None.
- **Algorithm:** Direct field extraction, no legacy-key fallback (unlike `CpuInfo.fromJson`).
- **Usage:** Called by [`Device.fromJson`](#device-fromjson) (when `json['gpu']` is present).
- **Notes:** None.

### `GpuInfo mergeUnknownFieldsFrom(GpuInfo other, {GpuInfo? base})` <a id="gpuinfo-mergeunknownfieldsfrom"></a>
- **Kind:** method of `GpuInfo`.
- **Source:** `lib/features/devices/models/device.dart` (line 322).
- **Purpose:** Three-way merge this `GpuInfo`'s unknown JSON fields with another's.
- **Inputs:** `other`; optional `base`.
- **Returns:** A new `GpuInfo` with merged `extraJson`.
- **Side effects:** None.
- **Algorithm:** Identical shape to [`CpuInfo.mergeUnknownFieldsFrom`](#cpuinfo-mergeunknownfieldsfrom).
- **Usage:** Called by [`Device.mergeUnknownFieldsFrom`](#device-mergeunknownfieldsfrom).
- **Notes:** None.

### `static StorageType? fromJson(String? value)` <a id="storagetype-fromjson"></a>
- **Kind:** static method of enum `StorageType`.
- **Source:** `lib/features/devices/models/device.dart` (line 352).
- **Purpose:** Parse a `StorageType` from its serialized name.
- **Inputs:** `value` — nullable.
- **Returns:** `StorageType?` — `null` if `value` is `null` or unrecognized.
- **Side effects:** None.
- **Algorithm:** Null-check, then `.where(...).firstOrNull`.
- **Usage:** Called by [`StorageInfo.fromJson`](#storageinfo-fromjson).
- **Notes:** None.

### `String get displayName` (RamType) <a id="ramtype-displayname"></a>
- **Kind:** getter of enum `RamType`.
- **Source:** `lib/features/devices/models/device.dart` (line 382).
- **Purpose:** Return the conventional uppercase display name for a RAM standard (e.g.
  `RamType.lpddr5x` → `"LPDDR5X"`), distinct from the lowercase `jsonValue`/`name` used in
  persisted JSON.
- **Inputs:** None.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** An exhaustive `switch` expression, one literal string per `RamType` value.
- **Usage:** Read directly wherever RAM type is displayed in the device edit/detail UI (e.g. a RAM
  type dropdown showing `"DDR5"`, `"LPDDR4X"`, etc.).
- **Notes:** Exhaustive over the enum, so adding a new `RamType` value without a case here is a
  compile error.

### `static RamType? fromJson(String? value)` <a id="ramtype-fromjson"></a>
- **Kind:** static method of enum `RamType`.
- **Source:** `lib/features/devices/models/device.dart` (line 399).
- **Purpose:** Parse a `RamType` from its serialized name.
- **Inputs:** `value` — nullable.
- **Returns:** `RamType?`.
- **Side effects:** None.
- **Algorithm:** Null-check, then `.where(...).firstOrNull`.
- **Usage:** Called by [`Device.fromJson`](#device-fromjson) for `ramType`.
- **Notes:** None.

### `static StorageInterface? fromJson(String? value)` <a id="storageinterface-fromjson"></a>
- **Kind:** static method of enum `StorageInterface`.
- **Source:** `lib/features/devices/models/device.dart` (line 424).
- **Purpose:** Parse a `StorageInterface` from its serialized name.
- **Inputs:** `value` — nullable.
- **Returns:** `StorageInterface?`.
- **Side effects:** None.
- **Algorithm:** Null-check, then `.where(...).firstOrNull`.
- **Usage:** Called by [`StorageInfo.fromJson`](#storageinfo-fromjson).
- **Notes:** None.

### `const StorageInfo({this.capacity, this.type, this.interface_, this.serialNumber, this.brand, this.extraJson = const {}})` <a id="storageinfo-new"></a>
- **Kind:** constructor of `StorageInfo`.
- **Source:** `lib/features/devices/models/device.dart` (line 444).
- **Purpose:** Hold one storage device's capacity, type, physical interface, serial number, and
  brand.
- **Inputs:** All fields optional.
- **Returns:** A new `StorageInfo`.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Constructed directly in `device_edit_page.dart`'s storage-entry form and via
  [`StorageInfo.fromJson`](#storageinfo-fromjson).
- **Notes:** The field is named `interface_` (trailing underscore) in Dart source specifically to
  avoid colliding with the reserved-ish `interface` identifier pattern, while the JSON key remains
  the natural `'interface'`.

### `String get displayString` (StorageInfo) <a id="storageinfo-displaystring"></a>
- **Kind:** getter of `StorageInfo`.
- **Source:** `lib/features/devices/models/device.dart` (line 472).
- **Purpose:** Build a human-readable one-line summary of this storage entry, e.g. `"512 GB SSD
  (M.2 NVMe)"`.
- **Inputs:** None.
- **Returns:** `String` — space-joined parts; empty string if every field is null.
- **Side effects:** None.
- **Algorithm:** Build a list of parts: 1. `capacity` if set. 2. `type` mapped to a display label
  (`"SSD"`/`"SD Card"`/`"HDD"`) if set. 3. `interface_` mapped to a parenthesized display label
  (`"(M.2 NVMe)"`/`"(2.5\" SATA)"`/`"(M.2 SATA)"`/`"(USB)"`) if set. Join all present parts with a
  single space.
- **Usage:** Read directly by device detail/edit views wherever a storage entry needs a compact
  display string (e.g. a storage list tile subtitle).
- **Notes:** Omits any part whose underlying field is `null` rather than showing a placeholder, so
  a storage entry with only `capacity` set displays as just `"512 GB"`.

### `Map<String, dynamic> toJson()` <a id="storageinfo-tojson"></a>
- **Kind:** method of `StorageInfo`.
- **Source:** `lib/features/devices/models/device.dart` (line 495).
- **Purpose:** Serialize this storage entry into the JSON persisted inside a device's `storage`
  list.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>`.
- **Side effects:** None.
- **Algorithm:** Same spread-then-known-fields shape as `CpuInfo.toJson`; `type`/`interface_` are
  serialized via their `.jsonValue` (enum name).
- **Usage:** Called by [`Device.toJson`](#device-tojson) for each entry of `storage`, and by
  [`mergeUnknownFieldsFrom`](#storageinfo-mergeunknownfieldsfrom).
- **Notes:** This declaration has no `/// Purpose:` doc comment in source (see the row-count note
  above the Declarations table).

### `factory StorageInfo.fromJson(dynamic json)` <a id="storageinfo-fromjson"></a>
- **Kind:** factory constructor of `StorageInfo`.
- **Source:** `lib/features/devices/models/device.dart` (line 504).
- **Purpose:** Parse a `StorageInfo` from either the current JSON object shape or the legacy plain
  string shape (e.g. `"512 GB"`).
- **Inputs:** `json` — `dynamic`, not `Map<String, dynamic>`, specifically to accept either shape.
- **Returns:** A new `StorageInfo`; for a plain string input, only `capacity` is set and every
  other field is `null`.
- **Side effects:** None.
- **Algorithm:** 1. If `json is String`, return `StorageInfo(capacity: json)` directly — the legacy
  path. 2. Otherwise cast to `Map<String, dynamic>` and extract each known field, parsing
  `type`/`interface` via their respective `fromJson` enum parsers.
- **Usage:** Called by [`Device.fromJson`](#device-fromjson) for each entry of a device's
  `storage` array (which itself branches on whether the whole `storage` value is a legacy single
  string or a list — see [`Device.fromJson`](#device-fromjson)).
- **Notes:** This is the only model in this file that accepts two structurally different JSON
  shapes for the same field — a plain string from data written before storage became a structured
  object, and the current object shape. Its parameter type is `dynamic` rather than
  `Map<String, dynamic>` specifically to allow this. This declaration has no `/// Purpose:` doc
  comment in source.

### `StorageInfo mergeUnknownFieldsFrom(StorageInfo other, {StorageInfo? base})` <a id="storageinfo-mergeunknownfieldsfrom"></a>
- **Kind:** method of `StorageInfo`.
- **Source:** `lib/features/devices/models/device.dart` (line 520).
- **Purpose:** Three-way merge this `StorageInfo`'s unknown JSON fields with another's.
- **Inputs:** `other`; optional `base`.
- **Returns:** A new `StorageInfo` with merged `extraJson`.
- **Side effects:** None.
- **Algorithm:** Identical shape to `CpuInfo.mergeUnknownFieldsFrom`.
- **Usage:** Called by [`Device.mergeUnknownFieldsFrom`](#device-mergeunknownfieldsfrom) once per
  index-aligned pair of `storage` entries (see that entry's Algorithm for how entries are paired
  up when the two sides' lists differ in length).
- **Notes:** This declaration has no `/// Purpose:` doc comment in source.

### `const MoneyValue({required this.amount, required this.currency, required this.defaultCurrency, required this.convertedAmount, required this.exchangeRate, required this.autoRate, this.rateUpdatedAt, this.extraJson = const {}})` <a id="moneyvalue-new"></a>
- **Kind:** constructor of `MoneyValue`.
- **Source:** `lib/features/devices/models/device.dart` (line 543).
- **Purpose:** Hold a price entered in any currency together with its conversion into the app's
  default currency, the rate used, and whether that rate was automatic or manual.
- **Inputs:** `amount`, `currency`, `defaultCurrency`, `convertedAmount`, `exchangeRate`,
  `autoRate` required; optional `rateUpdatedAt`, `extraJson`.
- **Returns:** A new `MoneyValue`.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment — this constructor does not itself perform any
  conversion; callers get a populated `MoneyValue` from
  [`DeviceExchangeRateService.convert`](../services/exchange_rate_service.md#convert)/
  `convertOptional`, which compute `convertedAmount`/`exchangeRate` before calling this
  constructor.
- **Usage:** Called by `DeviceExchangeRateService.convert` (see
  [`../services/exchange_rate_service.md`](../services/exchange_rate_service.md)), which is the
  only place a fully-formed `MoneyValue` is normally constructed from scratch.
- **Notes:** This declaration has no `/// Purpose:` doc comment in source.

### `Map<String, dynamic> toJson()` <a id="moneyvalue-tojson"></a>
- **Kind:** method of `MoneyValue`.
- **Source:** `lib/features/devices/models/device.dart` (line 554).
- **Purpose:** Serialize this money value into the JSON persisted inside `purchasePrice`,
  `soldPrice`, or a `DeviceRecurringCost.price`.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` with `amount`, `currency`, `defaultCurrency`,
  `convertedAmount`, `exchangeRate`, `autoRate`, and `rateUpdatedAt` (ISO-8601) when present.
- **Side effects:** None.
- **Algorithm:** Direct field mapping (unlike the other `toJson`s in this file, every known field
  except `rateUpdatedAt` is unconditional, not `if (x != null)`-gated, since `amount` through
  `autoRate` are all non-nullable).
- **Usage:** Called by [`Device.toJson`](#device-tojson) for `purchasePrice`/`soldPrice`, and by
  [`DeviceRecurringCost.toJson`](#devicerecurringcost-tojson) for `price`.
- **Notes:** This declaration has no `/// Purpose:` doc comment in source.

### `factory MoneyValue.fromJson(Map<String, dynamic> json)` <a id="moneyvalue-fromjson"></a>
- **Kind:** factory constructor of `MoneyValue`.
- **Source:** `lib/features/devices/models/device.dart` (line 566).
- **Purpose:** Parse a `MoneyValue` from JSON, tolerating an older `baseCurrency` key in place of
  `defaultCurrency` and a missing `convertedAmount`.
- **Inputs:** `json`.
- **Returns:** A new `MoneyValue`.
- **Side effects:** None.
- **Algorithm:** 1. Read `amount`/`currency` as required. 2. `defaultCurrency` falls back to the
  legacy `json['baseCurrency']` key, then to `currency` itself if neither is present. 3.
  `exchangeRate` defaults to `1.0` if absent. 4. `convertedAmount` falls back to
  `amount * exchangeRate` if the key itself is missing (rather than always trusting a stored
  value). 5. `autoRate` defaults to `true`. 6. `rateUpdatedAt` parsed via `DateTime.parse` only if
  present.
- **Usage:** Called by [`Device.fromJson`](#device-fromjson) for `purchasePrice`/`soldPrice`, and
  by [`DeviceRecurringCost.fromJson`](#devicerecurringcost-fromjson) for `price`.
- **Notes:** This declaration has no `/// Purpose:` doc comment in source. The `baseCurrency` →
  `defaultCurrency` rename and the derived-`convertedAmount` fallback are both real
  backward-compatibility paths for older persisted data, not speculative — confirmed directly in
  this code.

### `MoneyValue mergeUnknownFieldsFrom(MoneyValue other, {MoneyValue? base})` <a id="moneyvalue-mergeunknownfieldsfrom"></a>
- **Kind:** method of `MoneyValue`.
- **Source:** `lib/features/devices/models/device.dart` (line 588).
- **Purpose:** Three-way merge this `MoneyValue`'s unknown JSON fields with another's.
- **Inputs:** `other`; optional `base`.
- **Returns:** A new `MoneyValue` with merged `extraJson`.
- **Side effects:** None.
- **Algorithm:** Identical shape to `CpuInfo.mergeUnknownFieldsFrom`.
- **Usage:** Called by [`Device.mergeUnknownFieldsFrom`](#device-mergeunknownfieldsfrom) for
  `purchasePrice`/`soldPrice` (only when both sides have a non-null value for that field), and by
  [`DeviceRecurringCost.mergeUnknownFieldsFrom`](#devicerecurringcost-mergeunknownfieldsfrom) for
  the nested `price`.
- **Notes:** This declaration has no `/// Purpose:` doc comment in source.

### `DeviceRecurringCost({String? id, required this.kind, this.name, required this.price, this.billingCycle = BillingCycle.monthly, this.extraJson = const {}})` <a id="devicerecurringcost-new"></a>
- **Kind:** constructor of `DeviceRecurringCost`.
- **Source:** `lib/features/devices/models/device.dart` (line 609).
- **Purpose:** Hold one recurring device cost (lease, insurance, subscription, or other), generating
  a fresh UUID `id` when none is supplied.
- **Inputs:** Optional `id` (auto-generated if `null`); `kind`, `price` required; optional `name`;
  `billingCycle` defaults to `monthly`.
- **Returns:** A new `DeviceRecurringCost`.
- **Side effects:** None (beyond calling `Uuid().v4()` when `id` is null — no I/O).
- **Algorithm:** `id = id ?? const Uuid().v4()` in the initializer list, then plain field
  assignment for the rest.
- **Usage:**
  ```dart
  recurringCosts.add(
    DeviceRecurringCost(
      id: draft.existing?.id,
      kind: draft.kind,
      name: _nonEmpty(draft.nameCtrl.text),
      billingCycle: draft.billingCycle,
      price: price,
      extraJson: draft.existing?.extraJson ?? const {},
    ),
  );
  ```
  (from `device_edit_page.dart`'s save handler; passing `draft.existing?.id` preserves the same
  `id` across an edit rather than minting a new one)
- **Notes:** This declaration has no `/// Purpose:` doc comment in source. Passing `id: null` for a
  genuinely new cost is what triggers UUID generation; passing the existing id (as the usage
  example does) is required to keep editing a cost from looking like a delete-and-recreate to the
  sync merge (which matches records by `id`, not content — see
  [Three-Way Merge](../../../../algorithms/three-way-merge.md), though note `DeviceRecurringCost`
  itself is merged as a nested structure inside `Device`, not as its own top-level `mergeRecords<T>`
  collection).

### `double get annualConvertedAmount` (DeviceRecurringCost) <a id="devicerecurringcost-annualconvertedamount"></a>
- **Kind:** getter of `DeviceRecurringCost`.
- **Source:** `lib/features/devices/models/device.dart` (line 618).
- **Purpose:** Project this recurring cost to an equivalent yearly converted amount, based on its
  `billingCycle`.
- **Inputs:** None.
- **Returns:** `double`.
- **Side effects:** None.
- **Algorithm:** `switch (billingCycle) { BillingCycle.monthly => price.convertedAmount * 12,
  BillingCycle.yearly => price.convertedAmount }` — confirmed directly against source, matching
  [Devices](../../../../features/devices.md#lifecycle-and-finance-tracking)'s description.
- **Usage:** Read only by [`dailyConvertedAmount`](#devicerecurringcost-new) (see the Tier B row
  above) in this same class.
- **Notes:** A monthly cost's converted `price.convertedAmount` is treated as a *monthly* amount
  (hence ×12 for the year); a yearly cost's `price.convertedAmount` is already the yearly amount
  (no multiplication) — getting this backwards would be a 12x error in every downstream
  daily/total-cost calculation on `Device`.

### `Map<String, dynamic> toJson()` <a id="devicerecurringcost-tojson"></a>
- **Kind:** method of `DeviceRecurringCost`.
- **Source:** `lib/features/devices/models/device.dart` (line 625).
- **Purpose:** Serialize this recurring cost into the JSON persisted inside a device's
  `recurringCosts` list.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` with `id`, `kind`, `name` (if set), `price` (nested
  `MoneyValue.toJson()`), `billingCycle`.
- **Side effects:** None.
- **Algorithm:** Spread-then-known-fields shape, nesting `price.toJson()`.
- **Usage:** Called by [`Device.toJson`](#device-tojson) for each entry of `recurringCosts`.
- **Notes:** This declaration has no `/// Purpose:` doc comment in source.

### `factory DeviceRecurringCost.fromJson(Map<String, dynamic> json)` <a id="devicerecurringcost-fromjson"></a>
- **Kind:** factory constructor of `DeviceRecurringCost`.
- **Source:** `lib/features/devices/models/device.dart` (line 634).
- **Purpose:** Parse a `DeviceRecurringCost` from JSON.
- **Inputs:** `json`.
- **Returns:** A new `DeviceRecurringCost`; throws if `price` is missing (required, non-nullable).
- **Side effects:** None.
- **Algorithm:** Direct field extraction; `kind`/`billingCycle` via their enum `fromJson` parsers;
  `price` via `MoneyValue.fromJson` on the required `json['price']` map.
- **Usage:** Called by [`Device.fromJson`](#device-fromjson) for each entry of `recurringCosts`.
- **Notes:** This declaration has no `/// Purpose:` doc comment in source.

### `DeviceRecurringCost mergeUnknownFieldsFrom(DeviceRecurringCost other, {DeviceRecurringCost? base})` <a id="devicerecurringcost-mergeunknownfieldsfrom"></a>
- **Kind:** method of `DeviceRecurringCost`.
- **Source:** `lib/features/devices/models/device.dart` (line 644).
- **Purpose:** Three-way merge this cost's unknown JSON fields with another's, including the
  nested `price`'s own unknown fields.
- **Inputs:** `other`; optional `base`.
- **Returns:** A new `DeviceRecurringCost` with merged `extraJson` and a merged `price`.
- **Side effects:** None.
- **Algorithm:** 1. Start from `toJson()`, merge in `extraJson` via `mergeUnknownJsonFields` same as
  the other model classes. 2. Additionally overwrite `json['price']` with
  `price.mergeUnknownFieldsFrom(other.price, base: base?.price).toJson()` — this is the one class
  in this file whose merge touches a nested field beyond `extraJson`, because `price` is itself a
  model with its own unknown fields to preserve. 3. Re-parse via `DeviceRecurringCost.fromJson`.
- **Usage:** Called by [`Device.mergeUnknownFieldsFrom`](#device-mergeunknownfieldsfrom) once per
  index-aligned pair of `recurringCosts` entries.
- **Notes:** This declaration has no `/// Purpose:` doc comment in source. Unlike `CpuInfo`/`GpuInfo`/
  `StorageInfo`'s merge methods (which only touch `extraJson`), this one also recurses into
  `price`'s merge — the known `kind`/`name`/`billingCycle` fields still come from `this`
  unconditionally, same as elsewhere.

### `Device({String? id, required this.name, required this.category, ..., DateTime? modifiedAt, this.extraJson = const {}})` <a id="device-new"></a>
- **Kind:** constructor of `Device`.
- **Source:** `lib/features/devices/models/device.dart` (line 699).
- **Purpose:** Create a device record, generating a fresh UUID `id` and UTC `modifiedAt` timestamp
  when neither is supplied.
- **Inputs:** `name`, `category` required; every other field (identity, specs, location,
  lifecycle, finance, `notes`) optional with sensible defaults (`cpu`/`gpu` default to empty
  `const` instances, `storage`/`recurringCosts` default to `[]`, `isRetired`/`isSold` default to
  `false`).
- **Returns:** A new `Device`.
- **Side effects:** None (beyond `Uuid().v4()`/`DateTime.now()` calls — no I/O).
- **Algorithm:** `id = id ?? const Uuid().v4()`, `modifiedAt = modifiedAt ?? DateTime.now().toUtc()`
  in the initializer list; all other fields plain-assigned with their declared defaults.
- **Usage:**
  ```dart
  final device = Device(
    id: widget.device?.id,
    name: _nameCtrl.text.trim(),
    category: _category,
    ...
    isRetired: isRetired,
    isSold: isSold,
    ...
  );
  await DeviceStorage.addOrUpdate(device);
  ```
  (from `device_edit_page.dart`'s save handler — note this app constructs an updated `Device`
  directly via every field rather than via [`copyWith`](#copywith); passing `widget.device?.id`
  preserves the same `id` on edit, `null` mints a new one for a brand-new device)
- **Notes:** `modifiedAt` is always refreshed to "now" unless explicitly overridden — every save
  through this constructor without an explicit `modifiedAt` bumps the record's sync-relevant
  timestamp, which is what [`mergeRecords<Device>`](../../../../algorithms/three-way-merge.md)
  uses to detect which side changed.

### `DeviceLifecycleStatus get lifecycleStatus` <a id="lifecyclestatus"></a>
- **Kind:** getter of `Device`.
- **Source:** `lib/features/devices/models/device.dart` (line 736).
- **Purpose:** Derive the device's lifecycle bucket (`sold`/`retired`/`inService`) from the
  `isSold`/`isRetired` flags, with `isSold` taking priority when both are set.
- **Inputs:** None.
- **Returns:** `DeviceLifecycleStatus`.
- **Side effects:** None.
- **Algorithm:** `if (isSold) return sold; if (isRetired) return retired; return inService;` —
  confirmed directly in source and in
  [Devices](../../../../features/devices.md#lifecycle-and-finance-tracking).
- **Usage:**
  ```dart
  byLifecycle[d.lifecycleStatus.name] = (byLifecycle[d.lifecycleStatus.name] ?? 0) + 1;
  ```
  (from `lib/shared/services/local_api_server.dart`'s device-summary endpoint; also read directly
  by `device_list_page.dart`'s filter tabs and `import_export_service.dart`'s Markdown export)
- **Notes:** A device that is both `isSold` and `isRetired` reports as `sold`, not `retired` — this
  priority ordering is load-bearing for the home filter counts and the financial summary, and is
  the one piece of this getter's logic worth calling out explicitly (it's easy to assume the two
  flags are mutually exclusive, but the model does not enforce that).

### `bool get hasFinancialData` <a id="hasfinancialdata"></a>
- **Kind:** getter of `Device`.
- **Source:** `lib/features/devices/models/device.dart` (line 744).
- **Purpose:** Return whether this device has any financial data recorded at all — a purchase
  price, a sold price, or at least one recurring cost.
- **Inputs:** None.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** `purchasePrice != null || soldPrice != null || recurringCosts.isNotEmpty`.
- **Usage:**
  ```dart
  final financeDevices = devices.where((d) => d.hasFinancialData).toList();
  ```
  (from `local_api_server.dart`'s finance-summary endpoint; also gates whether
  `device_detail_page.dart`/`device_finance_overview_page.dart` render a finance section at all)
- **Notes:** This is the guard that [`averageDailyCost`](#averagedailycost) also checks before
  computing anything — a device with zero financial data always reports `averageDailyCost == null`
  rather than a computed `0.0`, which would otherwise be visually indistinguishable from "genuinely
  free to own".

### `int? serviceDays({DateTime? asOf})` <a id="servicedays"></a>
- **Kind:** method of `Device`.
- **Source:** `lib/features/devices/models/device.dart` (line 747).
- **Purpose:** Compute the number of days this device has been (or was) in service, counting from
  `purchaseDate` through either now (if still in service) or `retiredDate` (if not).
- **Inputs:** Optional `asOf` — overrides "now" for the "still in service" branch; defaults to
  `DateTime.now()`.
- **Returns:** `int?` — `null` if `purchaseDate` is unset; otherwise at least `1`.
- **Side effects:** None.
- **Algorithm:** 1. If `purchaseDate` is null, return `null`. 2. `end = isInService ? now :
  (retiredDate ?? now)` — a retired/sold device with no recorded `retiredDate` still falls back to
  "now" for this calculation. 3. Return `max(1, end.difference(purchaseDate!).inDays + 1)` — the
  `+1` makes a same-day purchase count as 1 day rather than 0, and `max(1, ...)` is a floor so the
  result is never zero or negative even for a future-dated purchase.
- **Usage:**
  ```dart
  'serviceDays': device.serviceDays(),
  ```
  (from `local_api_server.dart`'s per-device JSON export)
- **Notes:** Consumed by [`recurringCostThrough`](#recurringcostthrough) and
  [`averageDailyCost`](#averagedailycost) as the shared "how many days do we divide/multiply by"
  value — changing this method's rounding affects both.

### `double recurringCostThrough({DateTime? asOf})` <a id="recurringcostthrough"></a>
- **Kind:** method of `Device`.
- **Source:** `lib/features/devices/models/device.dart` (line 754).
- **Purpose:** Sum every recurring cost's daily-equivalent rate across the device's total service
  days, giving the total amount spent on recurring costs to date (or projected to `asOf`).
- **Inputs:** Optional `asOf`, forwarded to [`serviceDays`](#servicedays).
- **Returns:** `double` — `0` if `serviceDays` is `null` (no `purchaseDate`).
- **Side effects:** None.
- **Algorithm:** `recurringCosts.fold<double>(0, (sum, cost) => sum + cost.dailyConvertedAmount *
  days)` — every recurring cost is charged for the *entire* service-days span, not prorated to its
  own start date (there is no per-cost start date modeled).
- **Usage:**
  ```dart
  'recurringCostThrough': device.recurringCostThrough(),
  ```
  (from `local_api_server.dart`; also the basis for
  [`totalCost`](#totalcost)/`device_finance_overview_page.dart`'s daily-cost trend chart, see
  [Devices](../../../../features/devices.md#financial-overview-page))
- **Notes:** Because every recurring cost multiplies by the *same* `serviceDays` regardless of when
  that particular lease/subscription actually started, adding a recurring cost to a long-owned
  device back-dates its accumulated cost across the device's entire ownership span, not just from
  today forward.

### `double totalCost({DateTime? asOf})` <a id="totalcost"></a>
- **Kind:** method of `Device`.
- **Source:** `lib/features/devices/models/device.dart` (line 763).
- **Purpose:** Compute this device's total cost of ownership: purchase price plus accumulated
  recurring costs, minus any sold price recovered.
- **Inputs:** Optional `asOf`, forwarded to [`recurringCostThrough`](#recurringcostthrough).
- **Returns:** `double`.
- **Side effects:** None.
- **Algorithm:** `(purchasePrice?.convertedAmount ?? 0) + recurringCostThrough(asOf: asOf) -
  (soldPrice?.convertedAmount ?? 0)` — confirmed directly in source and matching
  [Devices](../../../../features/devices.md#lifecycle-and-finance-tracking)'s documented formula.
- **Usage:**
  ```dart
  final amount = math.max(0.0, device.totalCost());
  widget.devices.fold(0, (sum, device) => sum + device.totalCost());
  ```
  (from `device_finance_overview_page.dart`'s asset-distribution chart and category totals; also
  read by `device_detail_page.dart`, `device_list_page.dart`, and `local_api_server.dart`)
- **Notes:** Can be negative (sold price exceeding purchase price plus recurring costs) — callers
  that feed this into a chart (like the finance overview page's asset distribution) clamp it to
  `math.max(0.0, ...)` themselves; this method does not clamp.

### `double? averageDailyCost({DateTime? asOf})` <a id="averagedailycost"></a>
- **Kind:** method of `Device`.
- **Source:** `lib/features/devices/models/device.dart` (line 769).
- **Purpose:** Compute the average daily cost of owning this device, or `null` when there's no
  financial data or no `purchaseDate` to measure days from.
- **Inputs:** Optional `asOf`, forwarded to both [`serviceDays`](#servicedays) and
  [`totalCost`](#totalcost).
- **Returns:** `double?` — `null` if `serviceDays` is `null` or [`hasFinancialData`](#hasfinancialdata)
  is `false`; otherwise `totalCost(asOf: asOf) / days`.
- **Side effects:** None.
- **Algorithm:** Compute `days = serviceDays(asOf: asOf)`; return `null` if `days == null ||
  !hasFinancialData`; else `totalCost(asOf: asOf) / days`.
- **Usage:**
  ```dart
  'averageDailyCost': device.averageDailyCost(),
  ```
  (from `local_api_server.dart`; also the per-point value plotted on
  `device_finance_overview_page.dart`'s daily-cost trend line, including its dashed
  future-projection segment — see
  [Devices](../../../../features/devices.md#financial-overview-page))
- **Notes:** The `hasFinancialData` guard specifically prevents a device with `purchaseDate` set
  but zero recorded cost from reporting `0.0` (which a chart would render as a real, if boring,
  data point) — it reports `null` (no data point) instead.

### `double? get ppi` <a id="ppi"></a>
- **Kind:** getter of `Device`.
- **Source:** `lib/features/devices/models/device.dart` (line 776).
- **Purpose:** Compute pixels-per-inch from the device's screen resolution and physical screen
  size.
- **Inputs:** None.
- **Returns:** `double?` — `null` if resolution or a parseable screen diagonal is missing.
- **Side effects:** None.
- **Algorithm:** 1. Return `null` if either `screenResolutionW`/`screenResolutionH` is null. 2.
  Parse `screenSize` into inches via [`_parseScreenDiagonal`](#_parsescreendiagonal); return `null`
  if that fails or is `<= 0`. 3. Return `sqrt(w*w + h*h) / diagonal` — the resolution diagonal in
  pixels divided by the physical diagonal in inches.
- **Usage:**
  ```dart
  if (device.ppi != null)
    _specRow(l10n.ppi, device.ppi!.toStringAsFixed(0)),
  ```
  (from `device_detail_page.dart`'s spec list; also read by `device_edit_page.dart` and
  `import_export_service.dart`'s Markdown export)
- **Notes:** Depends entirely on `screenSize` being parseable by
  [`_parseScreenDiagonal`](#_parsescreendiagonal) — a screen size string that doesn't end in a
  recognizable unit/quote mark yields `null` here even if resolution is fully known.

### `static double? _parseScreenDiagonal(String? s)` <a id="_parsescreendiagonal"></a>
- **Kind:** private static method of `Device`.
- **Source:** `lib/features/devices/models/device.dart` (line 785).
- **Purpose:** Parse a free-text screen-size string (e.g. `6.7"`, `15.6 inch`, `13寸`) into a plain
  numeric inch value.
- **Inputs:** `s` — nullable, free-text.
- **Returns:** `double?` — `null` if `s` is null/empty or the cleaned string doesn't parse as a
  number.
- **Side effects:** None.
- **Algorithm:** Strip a trailing run of `"`/`'`/`'`/`寸`/`inch`/`inchs` (case-insensitive) via
  regex, trim, then `double.tryParse`.
- **Usage:** Called only by [`ppi`](#ppi).
- **Notes:** Only strips a *trailing* unit suffix — a screen-size string with the unit anywhere
  else (or extra text before the number) will fail to parse and silently yield `null` from `ppi`
  rather than throwing.

### `Device copyWith({...many optional fields..., bool clearEmoji = false, ...})` <a id="copywith"></a>
- **Kind:** method of `Device`.
- **Source:** `lib/features/devices/models/device.dart` (line 794).
- **Purpose:** Create a copy of this device with any subset of fields replaced, and — for every
  nullable field — an explicit `clearXxx` flag to null it out entirely (since passing `null` for an
  optional parameter is indistinguishable from "not provided" in Dart).
- **Inputs:** One optional parameter per field to replace it, plus one `bool clearXxx = false` per
  nullable field to clear it instead (e.g. `clearEmoji`, `clearBrand`, `clearPurchasePrice`, …);
  `id` and `extraJson` are always carried over unchanged (not parameters at all);
  `modifiedAt` defaults to a fresh `DateTime.now().toUtc()` if not explicitly passed.
- **Returns:** A new `Device` with the same `id`, all specified replacements applied, all specified
  `clearXxx` fields nulled, everything else unchanged.
- **Side effects:** None.
- **Algorithm:** For every clearable field: `clearXxx ? null : (xxx ?? this.xxx)`; for
  non-clearable fields (`name`, `category`, `cpu`, `gpu`, `storage`, `isRetired`, `isSold`,
  `recurringCosts`): `xxx ?? this.xxx`; `modifiedAt: modifiedAt ?? DateTime.now().toUtc()`.
- **Returns (continued):** `extraJson` is always copied unchanged — `copyWith` cannot modify
  unrecognized/preserved fields.
- **Usage:** No call site was found anywhere in `lib/` — every place that needs an updated `Device`
  (e.g. `device_edit_page.dart`'s save handler) currently constructs a brand-new `Device` via the
  primary constructor with every field spelled out explicitly (see [`Device`](#device-new)'s
  Usage), rather than calling `copyWith`. It is documented here as public API surface, not as
  dead-code-to-remove — this is a documentation pass, not a refactor.
- **Notes:** The `clearXxx` flag pattern exists because `copyWith(brand: null)` cannot be
  distinguished from "caller didn't pass `brand`" — every other model's `copyWith` in this
  codebase that needs to null out a field uses the same pattern (see e.g. `DataSet.copyWith` in
  `../../../datasets/models/dataset.dart`, not covered by this batch).

### `Map<String, dynamic> toJson()` <a id="device-tojson"></a>
- **Kind:** method of `Device`.
- **Source:** `lib/features/devices/models/device.dart` (line 900).
- **Purpose:** Serialize this device into the JSON persisted in `device_data.json` and synced to
  the WebDAV remote.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` — `extraJson` spread first, then every known field, most
  gated `if (field != null)`; `cpu`/`gpu` only included `if (!cpu.isEmpty)`/`if (!gpu.isEmpty)`;
  `storage`/`recurringCosts` only included `if (...isNotEmpty)`; `isRetired`/`isSold` only included
  `if (true)` (omitted entirely when `false`); `id`/`name`/`category`/`modifiedAt` are always
  present.
- **Side effects:** None.
- **Algorithm:** Direct field-to-key mapping with the conditional-inclusion rules above; nested
  values (`cpu`, `gpu`, each `storage`/`recurringCosts` entry, `purchasePrice`/`soldPrice`) are
  serialized via their own `toJson()`.
- **Usage:** Called by [`DeviceData.toJson`](#devicedata-tojson) for each device, and by
  `local_api_server.dart`'s `mergeUnknownFields` callback (`primary.mergeUnknownFieldsFrom(...)`)
  indirectly via [`mergeUnknownFieldsFrom`](#device-mergeunknownfieldsfrom).
- **Notes:** `isRetired`/`isSold` being omitted entirely when `false` (rather than written as
  `false`) keeps the common case (a device in service) out of the persisted JSON — this is a
  storage-size optimization, not a correctness requirement, since
  [`Device.fromJson`](#device-fromjson) defaults both to `false` when absent.

### `factory Device.fromJson(Map<String, dynamic> json)` <a id="device-fromjson"></a>
- **Kind:** factory constructor of `Device`.
- **Source:** `lib/features/devices/models/device.dart` (line 937).
- **Purpose:** Parse a `Device` from JSON, tolerating the legacy single-string `storage` shape in
  addition to the current list-of-objects shape.
- **Inputs:** `json`.
- **Returns:** A new `Device`; throws if `id`/`name`/`category`/`modifiedAt` are missing (all
  required, non-nullable reads).
- **Side effects:** None.
- **Algorithm:** Direct field extraction for most fields; `cpu`/`gpu` via
  [`CpuInfo.fromJson`](#cpuinfo-fromjson)/[`GpuInfo.fromJson`](#gpuinfo-fromjson) when present,
  else the empty `const` default; `storage` branches on whether `json['storage']` is a `String`
  (legacy: wrap in a single-element list via `StorageInfo.fromJson`) or a `List` (map each entry);
  date fields via `DateTime.parse`; `extraJson` via `unknownJsonFields(json, _deviceJsonKeys)`.
- **Usage:**
  ```dart
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return DeviceData.fromJson(json);
  ```
  (from [`../services/device_storage.md#load`](../services/device_storage.md), and indirectly by
  `mergeDeviceData` in `lib/shared/services/sync_merge.dart` via `DeviceData.fromJson`)
- **Notes:** The legacy single-string `storage` branch mirrors
  [`StorageInfo.fromJson`](#storageinfo-fromjson)'s own string-vs-object handling — data written
  before storage became a list of structured entries still parses correctly today.

### `Device mergeUnknownFieldsFrom(Device other, {Device? base})` <a id="device-mergeunknownfieldsfrom"></a>
- **Kind:** method of `Device`.
- **Source:** `lib/features/devices/models/device.dart` (line 1001).
- **Purpose:** Merge this device's unknown JSON fields with another's, and additionally recurse the
  same three-way unknown-field merge into every nested value object (`cpu`, `gpu`, each `storage`
  entry, `purchasePrice`, `soldPrice`, each `recurringCosts` entry) so no nested unrecognized field
  is lost during a sync merge.
- **Inputs:** `other` — the other side (secondary); optional `base` — the last-synced snapshot.
- **Returns:** A new `Device` — same known top-level fields as `this`, but with every nested value
  object's `extraJson` merged against `other`'s corresponding value, re-parsed via
  `Device.fromJson`.
- **Side effects:** None.
- **Algorithm:** This is the per-record callback [`mergeRecords<Device>`](../../../../algorithms/three-way-merge.md)
  invokes as `mergeUnknownFields` — it does *not* itself decide which whole record wins (that's
  `mergeRecords<Device>`'s job); it only merges nested content once `this` has already been chosen
  as primary. 1. Start from `toJson()`, merge top-level `extraJson` the same way every other model
  in this file does. 2. `cpu`/`gpu`: merge via their own `mergeUnknownFieldsFrom`; if the merged
  result `isEmpty`, remove the key entirely rather than writing an empty object. 3. `storage`: if
  `this.storage` is non-empty, rebuild the whole list by merging each index `i` of `this.storage`
  against `other.storage[i]` (or a fresh empty `StorageInfo()` if `other` has fewer entries) and
  `base.storage[i]` (if `base` exists and has that many entries). 4. `purchasePrice`/`soldPrice`:
  merge only when *both* `this` and `other` have a non-null value for that field (otherwise the
  field is left as whatever `toJson()` already produced from `this`). 5. `recurringCosts`: same
  index-aligned rebuild as `storage`, except the fallback for a missing `other` entry is
  `recurringCosts[i]` itself (merging a cost with itself is a no-op) rather than a fresh empty
  value, since `DeviceRecurringCost` has no meaningful "empty" default. 6. Re-parse the fully
  assembled `json` map via `Device.fromJson`.
- **Usage:**
  ```dart
  mergeUnknownFields: (primary, secondary, base) =>
      primary.mergeUnknownFieldsFrom(secondary, base: base),
  ```
  (from `mergeDeviceData` in `lib/shared/services/sync_merge.dart`, passed as the
  `mergeUnknownFields` callback into `mergeRecords<Device>` — see
  [Three-Way Merge](../../../../algorithms/three-way-merge.md) for how `mergeRecords<T>` decides
  which side is `primary`/`secondary` before ever calling this)
- **Notes:** List merging here is strictly **index-aligned**, not matched by any identity within
  `storage`/`recurringCosts` entries themselves (`StorageInfo`/`DeviceRecurringCost` list items
  have no stable cross-side matching key beyond their position, except that `DeviceRecurringCost`
  does have an `id` which this method does *not* use for matching) — if the two sides reordered or
  inserted/removed entries at different positions, this can merge unrelated entries' `extraJson`
  together at the same index. This is a real, source-confirmed limitation, not a hypothetical edge
  case. This declaration has no `/// Purpose:` doc comment in source.

### `const DeviceData({this.devices = const [], this.extraJson = const {}})` <a id="devicedata-new"></a>
- **Kind:** constructor of `DeviceData`.
- **Source:** `lib/features/devices/models/device.dart` (line 1084).
- **Purpose:** Hold the top-level device list persisted to `device_data.json`.
- **Inputs:** Optional `devices` (defaults to `[]`); optional `extraJson`.
- **Returns:** A new `DeviceData`.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:**
  ```dart
  await save(DeviceData(devices: devices));
  ```
  (from [`../services/device_storage.md#addorupdate`](../services/device_storage.md), constructing
  the whole container around an updated device list before every save)
- **Notes:** None.

### `Map<String, dynamic> toJson()` <a id="devicedata-tojson"></a>
- **Kind:** method of `DeviceData`.
- **Source:** `lib/features/devices/models/device.dart` (line 1091).
- **Purpose:** Serialize the device list container into the JSON written to `device_data.json`.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` with `devices` (each serialized via
  [`Device.toJson`](#device-tojson)) plus any preserved `extraJson`.
- **Side effects:** None.
- **Algorithm:** `{...extraJson, 'devices': devices.map((d) => d.toJson()).toList()}`.
- **Usage:** Called by [`../services/device_storage.md#save`](../services/device_storage.md).
- **Notes:** None.

### `factory DeviceData.fromJson(Map<String, dynamic> json)` <a id="devicedata-fromjson"></a>
- **Kind:** factory constructor of `DeviceData`.
- **Source:** `lib/features/devices/models/device.dart` (line 1101).
- **Purpose:** Parse a `DeviceData` from the decoded contents of `device_data.json`.
- **Inputs:** `json`.
- **Returns:** A new `DeviceData`; `devices` defaults to `[]` if the key is absent.
- **Side effects:** None.
- **Algorithm:** Map `json['devices']` (if present) through [`Device.fromJson`](#device-fromjson);
  `extraJson` via `unknownJsonFields(json, _deviceDataJsonKeys)` (only the single `'devices'` key is
  known at this level).
- **Usage:** Called by [`../services/device_storage.md#load`](../services/device_storage.md) and by
  `mergeDeviceData` in `lib/shared/services/sync_merge.dart` (for both the local and remote sides
  before merging).
- **Notes:** None.
