# lib/features/datasets/models/dataset.dart

Model source for [Datasets](../../../../features/datasets.md). Defines `DataSetStorageLink` (a
reference from a dataset to one or more storage slots on a specific device, by positional index),
`DataSet` (a named collection of such links, spanning one or more devices), and the top-level
`DataSetData` container persisted by
[`../services/dataset_storage.md`](../services/dataset_storage.md). Every model here follows the
app's standard shape — a plain/const constructor, `toJson`/`fromJson`, and a
`mergeUnknownFieldsFrom` built on the generic
[`../../../../shared/utils/json_preservation.md`](../../../shared/utils/json_preservation.md)
helpers. See
[Datasets](../../../../features/datasets.md#storage-slot-index-linking) for why
`storageIndices` being *positional* (not a stable per-slot id) means any code that reorders or
removes a device's storage slots must call
[`DataSetStorage.remapDeviceStorageLinks`](../services/dataset_storage.md#remapdevicestoragelinks)
to keep these links valid, and
[Data Formats](../../../../data-formats.md#dataset--datasetstoragelink-libfeaturesdatasetsmodelsdatasetdart)
for the exhaustive persisted-field reference.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`DataSetStorageLink`](#datasetstoragelink-new) | constructor | A | Create a data set storage link instance. |
| [`toJson`](#datasetstoragelink-tojson) | method (`DataSetStorageLink`) | A | Serialize this value into a JSON-compatible map. |
| [`DataSetStorageLink.fromJson`](#datasetstoragelink-fromjson) | factory constructor | A | Parse a `DataSetStorageLink` from JSON. |
| [`mergeUnknownFieldsFrom`](#datasetstoragelink-mergeunknownfieldsfrom) | method (`DataSetStorageLink`) | A | Three-way merge unknown JSON fields from another `DataSetStorageLink`. |
| [`DataSet`](#dataset-new) | constructor | A | Create a `DataSet` instance (fresh `id`/`modifiedAt` by default). |
| [`copyWith`](#copywith) | method (`DataSet`) | A | Create a copy with selected fields replaced. |
| [`toJson`](#dataset-tojson) | method (`DataSet`) | A | Serialize this value into a JSON-compatible map. |
| [`DataSet.fromJson`](#dataset-fromjson) | factory constructor | A | Parse a `DataSet` from JSON. |
| [`mergeUnknownFieldsFrom`](#dataset-mergeunknownfieldsfrom) | method (`DataSet`) | A | Three-way merge unknown fields, including each nested storage link. |
| [`DataSetData`](#datasetdata-new) | constructor | A | Create a `DataSetData` instance. |
| [`toJson`](#datasetdata-tojson) | method (`DataSetData`) | A | Serialize this value into a JSON-compatible map. |
| [`DataSetData.fromJson`](#datasetdata-fromjson) | factory constructor | A | Parse a `DataSetData` from JSON. |

Row count (12) matches `grep -c 'Purpose:' dataset.dart` (12) exactly.

## Documentation

### `const DataSetStorageLink({required this.deviceId, this.storageIndices = const [], this.extraJson = const {}})` <a id="datasetstoragelink-new"></a>
- **Kind:** constructor of `DataSetStorageLink`.
- **Source:** `lib/features/datasets/models/dataset.dart` (line 22).
- **Purpose:** Hold a reference from a dataset to one device's storage slots, by positional index.
- **Inputs:** `deviceId` required; `storageIndices` defaults to `[]`.
- **Returns:** A new `DataSetStorageLink`.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment with defaults.
- **Usage:**
  ```dart
  DataSetStorageLink(
    deviceId: entry.key,
    storageIndices: entry.value.toList()..sort(),
    extraJson: existingLinks[entry.key]?.extraJson ?? const {},
  ),
  ```
  (from [`dataset_edit_page.md`](../views/dataset_edit_page.md)'s `_save`, one per device with at
  least one selected storage slot)
- **Notes:** `storageIndices` are plain positions into the referenced device's
  `storage: List<StorageInfo>`, not stable slot identifiers — see the file overview above and
  [`remapDeviceStorageLinks`](../services/dataset_storage.md#remapdevicestoragelinks) for how the
  app keeps them valid across storage-list edits.

### `Map<String, dynamic> toJson()` <a id="datasetstoragelink-tojson"></a>
- **Kind:** method of `DataSetStorageLink`.
- **Source:** `lib/features/datasets/models/dataset.dart` (line 33).
- **Purpose:** Serialize this storage link into the JSON persisted inside a dataset's
  `storageLinks` array.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` with `deviceId` and `storageIndices` (a raw `List<int>`,
  always included even if empty).
- **Side effects:** None.
- **Algorithm:** `{...extraJson, 'deviceId': deviceId, 'storageIndices': storageIndices}`.
- **Usage:** Called by [`DataSet.toJson`](#dataset-tojson) for each entry of `storageLinks`, and by
  [`mergeUnknownFieldsFrom`](#datasetstoragelink-mergeunknownfieldsfrom).
- **Notes:** Unlike most other `toJson`s in this app, `storageIndices` is written unconditionally
  even when empty — there is no `if (storageIndices.isNotEmpty)` guard.

### `factory DataSetStorageLink.fromJson(Map<String, dynamic> json)` <a id="datasetstoragelink-fromjson"></a>
- **Kind:** factory constructor of `DataSetStorageLink`.
- **Source:** `lib/features/datasets/models/dataset.dart` (line 44).
- **Purpose:** Parse a `DataSetStorageLink` from JSON.
- **Inputs:** `json`.
- **Returns:** A new `DataSetStorageLink`; `extraJson` holds every key not in
  `_dataSetStorageLinkJsonKeys`.
- **Side effects:** None.
- **Algorithm:** `deviceId` required; `storageIndices` maps a `List<dynamic>` to `List<int>` or
  defaults to `[]` if absent.
- **Usage:** Called by [`DataSet.fromJson`](#dataset-fromjson) for each entry of
  `json['storageLinks']`.
- **Notes:** None.

### `DataSetStorageLink mergeUnknownFieldsFrom(DataSetStorageLink other, {DataSetStorageLink? base})` <a id="datasetstoragelink-mergeunknownfieldsfrom"></a>
- **Kind:** method of `DataSetStorageLink`.
- **Source:** `lib/features/datasets/models/dataset.dart` (line 60).
- **Purpose:** Three-way merge this link's unknown JSON fields with another's.
- **Inputs:** `other`; optional `base`.
- **Returns:** A new `DataSetStorageLink` with merged `extraJson`.
- **Side effects:** None.
- **Algorithm:** Re-parse `{...toJson(), ...mergeUnknownJsonFields(...)}` through
  `DataSetStorageLink.fromJson` — same shape as every other model's merge method in this app (see
  [`mergeUnknownJsonFields`](../../../shared/utils/json_preservation.md)).
- **Usage:** Called by [`DataSet.mergeUnknownFieldsFrom`](#dataset-mergeunknownfieldsfrom), once per
  index-aligned pair of `storageLinks` entries.
- **Notes:** Only `extraJson` is merged; the known fields (`deviceId`, `storageIndices`) still come
  from `this`.

### `DataSet({String? id, required this.name, required this.emoji, this.storageLinks = const [], DateTime? modifiedAt, this.extraJson = const {}})` <a id="dataset-new"></a>
- **Kind:** constructor of `DataSet`.
- **Source:** `lib/features/datasets/models/dataset.dart` (line 89).
- **Purpose:** Create a named dataset spanning zero or more device storage slots, generating a
  fresh UUID `id` and UTC `modifiedAt` when neither is supplied.
- **Inputs:** `name`, `emoji` required; `storageLinks` defaults to `[]`; `id`/`modifiedAt`
  auto-generated when omitted.
- **Returns:** A new `DataSet`.
- **Side effects:** None (beyond `Uuid().v4()`/`DateTime.now()` — no I/O).
- **Algorithm:** `id = id ?? const Uuid().v4()`, `modifiedAt = modifiedAt ?? DateTime.now().toUtc()`
  in the initializer list; remaining fields plain-assigned.
- **Usage:**
  ```dart
  final ds = (_isEditing ? widget.dataSet! : DataSet(name: name, emoji: _emoji))
      .copyWith(name: name, emoji: _emoji, storageLinks: links);
  ```
  (from [`dataset_edit_page.md`](../views/dataset_edit_page.md)'s `_save` — note that unlike
  `network_edit_page.dart`, this page constructs a brand-new `DataSet` only for the "add" case and
  reuses [`copyWith`](#copywith) for both add and edit, rather than always constructing directly)
- **Notes:** `emoji` has no default in the constructor itself (it's `required`), even though
  `_DataSetEditPageState` always supplies `'📁'` as its own initial local state; see
  [`DataSet.fromJson`](#dataset-fromjson) below, where a *missing* persisted `emoji` does default to
  `'📁'`.

### `DataSet copyWith({String? name, String? emoji, List<DataSetStorageLink>? storageLinks, DateTime? modifiedAt})` <a id="copywith"></a>
- **Kind:** method of `DataSet`.
- **Source:** `lib/features/datasets/models/dataset.dart` (line 104).
- **Purpose:** Create a copy of this dataset with selected fields replaced.
- **Inputs:** Any field to override; there is no explicit-clear flag for any field (unlike
  `Network.copyWith`) since every `DataSet` field is either required or has a non-null default.
- **Returns:** A new `DataSet` — `id` always preserved from `this`; `modifiedAt` defaults to "now"
  if not explicitly passed.
- **Side effects:** None.
- **Algorithm:** `field ?? this.field` for each parameter; `modifiedAt` defaults to
  `DateTime.now().toUtc()`.
- **Usage:** See [`DataSet`](#dataset-new) above — this is the primary way `dataset_edit_page.dart`
  produces the saved record, for both new and existing datasets.
- **Notes:** `extraJson` is always carried over unchanged from `this` — only
  [`mergeUnknownFieldsFrom`](#dataset-mergeunknownfieldsfrom) can alter it.

### `Map<String, dynamic> toJson()` <a id="dataset-tojson"></a>
- **Kind:** method of `DataSet`.
- **Source:** `lib/features/datasets/models/dataset.dart` (line 125).
- **Purpose:** Serialize this dataset into the JSON persisted inside `dataset_data.json`'s
  `datasets` array.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` — `extraJson` spread first, then `id`/`name`/`emoji` always,
  `storageLinks` only when non-empty, `modifiedAt` as ISO-8601.
- **Side effects:** None.
- **Algorithm:** Spread-then-known-fields shape; `storageLinks` nested via each link's
  [`toJson`](#datasetstoragelink-tojson).
- **Usage:** Called by [`DataSetData.toJson`](#datasetdata-tojson) for each entry of `datasets`, and
  by [`mergeUnknownFieldsFrom`](#dataset-mergeunknownfieldsfrom).
- **Notes:** A dataset with no storage links at all (e.g. right after creation, before any storage
  is picked) omits the `storageLinks` key entirely rather than writing `[]`.

### `factory DataSet.fromJson(Map<String, dynamic> json)` <a id="dataset-fromjson"></a>
- **Kind:** factory constructor of `DataSet`.
- **Source:** `lib/features/datasets/models/dataset.dart` (line 140).
- **Purpose:** Parse a `DataSet` from JSON.
- **Inputs:** `json`.
- **Returns:** A new `DataSet`; `extraJson` holds every key not in `_dataSetJsonKeys`.
- **Side effects:** None.
- **Algorithm:** Direct field extraction; `emoji` defaults to `'📁'` if the key is absent;
  `storageLinks` maps each entry through
  [`DataSetStorageLink.fromJson`](#datasetstoragelink-fromjson) or defaults to `[]`; `modifiedAt`
  via `DateTime.parse`.
- **Usage:** Called by [`DataSetData.fromJson`](#datasetdata-fromjson) for each entry of
  `json['datasets']`.
- **Notes:** The `'📁'` default here is the one place a missing `emoji` is tolerated — the
  constructor itself requires `emoji` to be passed explicitly.

### `DataSet mergeUnknownFieldsFrom(DataSet other, {DataSet? base})` <a id="dataset-mergeunknownfieldsfrom"></a>
- **Kind:** method of `DataSet`.
- **Source:** `lib/features/datasets/models/dataset.dart` (line 158).
- **Purpose:** Three-way merge this dataset's unknown JSON fields with another's, including each
  index-aligned pair of nested `storageLinks`' own unknown fields.
- **Inputs:** `other` — the other side; optional `base` — the last-synced snapshot.
- **Returns:** A new `DataSet` — same known fields as `this`, `extraJson` merged, and (if
  `storageLinks` is non-empty) every link's `extraJson` merged against the same-index link on
  `other`/`base`.
- **Side effects:** None.
- **Algorithm:** 1. Start from `toJson()`, merge in `extraJson` via `mergeUnknownJsonFields` same as
  every other model. 2. If `storageLinks.isNotEmpty`, overwrite `json['storageLinks']` with a list
  built by merging `storageLinks[i]` against `other.storageLinks[i]` (or an empty placeholder
  `DataSetStorageLink(deviceId: '')` if `other` has fewer links) and `base.storageLinks[i]` (if
  `base` exists and has that many links), for every index `i`. 3. Re-parse the whole map via
  `DataSet.fromJson`.
- **Usage:** Called by `mergeRecords<DataSet>` in `sync_merge.dart` (see
  [Three-Way Merge](../../../../algorithms/three-way-merge.md)).
- **Notes:** This is the one model in this file whose merge touches a nested field beyond
  `extraJson` — mirroring how `Device.mergeUnknownFieldsFrom` recurses into `recurringCosts`
  (see [`../../devices/models/device.md`](../../devices/models/device.md)). The known
  `storageIndices` on each link still come from `this` unconditionally; only the link-level
  `extraJson` is actually merged.

### `const DataSetData({this.datasets = const [], this.extraJson = const {}})` <a id="datasetdata-new"></a>
- **Kind:** constructor of `DataSetData`.
- **Source:** `lib/features/datasets/models/dataset.dart` (line 198).
- **Purpose:** Hold the full persisted dataset list.
- **Inputs:** `datasets` defaults to `[]`.
- **Returns:** A new `DataSetData`.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment with defaults.
- **Usage:**
  ```dart
  await save(DataSetData(datasets: list, extraJson: data.extraJson));
  ```
  (from [`dataset_storage.md`](../services/dataset_storage.md)'s `addOrUpdate`/`delete`)
- **Notes:** None.

### `Map<String, dynamic> toJson()` <a id="datasetdata-tojson"></a>
- **Kind:** method of `DataSetData`.
- **Source:** `lib/features/datasets/models/dataset.dart` (line 205).
- **Purpose:** Serialize the full dataset list into the JSON written to `dataset_data.json`.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` with a `datasets` array.
- **Side effects:** None.
- **Algorithm:** `{...extraJson, 'datasets': datasets.map(toJson)}`.
- **Usage:** Called by [`dataset_storage.md`](../services/dataset_storage.md)'s `save`.
- **Notes:** None.

### `factory DataSetData.fromJson(Map<String, dynamic> json)` <a id="datasetdata-fromjson"></a>
- **Kind:** factory constructor of `DataSetData`.
- **Source:** `lib/features/datasets/models/dataset.dart` (line 215).
- **Purpose:** Parse a `DataSetData` from the JSON stored in `dataset_data.json`.
- **Inputs:** `json`.
- **Returns:** A new `DataSetData`; `datasets` defaults to `[]` if the key is absent.
- **Side effects:** None.
- **Algorithm:** Maps `json['datasets']` through [`DataSet.fromJson`](#dataset-fromjson).
- **Usage:** Called by [`dataset_storage.md`](../services/dataset_storage.md)'s `load`.
- **Notes:** None.
