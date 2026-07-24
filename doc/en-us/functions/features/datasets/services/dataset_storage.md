# lib/features/datasets/services/dataset_storage.dart

`DataSetStorage` persists the `dataset_data.json` file and owns the one piece of cross-cutting
logic datasets need: keeping each dataset's positional `storageIndices` valid whenever a device's
`storage` list is reordered or has entries removed. See
[Datasets](../../../../features/datasets.md#remapdevicestoragelinks) for the concept-level
walkthrough of `remapDeviceStorageLinks` (already confirmed against this exact source), and
[Data Formats](../../../../data-formats.md#dataset--datasetstoragelink-libfeaturesdatasetsmodelsdatasetdart)
for the persisted JSON shape. Like `NetworkStorage`, it resolves its file location through
`DeviceStorage.getAppDir()` (`../../../devices/services/device_storage.md`) and notifies
[`AutoSyncService`](../../../shared/services/auto_sync_service.md) after every write.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`_getFile`](#getfile) | static method (private) | A | Resolve the `dataset_data.json` file inside the app directory. |
| [`load`](#load) | static method | A | Load the persisted `DataSetData` (dataset list). |
| [`save`](#save) | static method | A | Persist `DataSetData` and notify the auto-sync service. |
| [`addOrUpdate`](#addorupdate) | static method | A | Insert or replace a dataset by id. |
| [`delete`](#delete) | static method | A | Delete a dataset by id. |
| [`remapDeviceStorageLinks`](#remapdevicestoragelinks) | static method | A | Re-map (or drop) dataset storage-slot indices after a device's storage list changed. |
| [`_sameIndices`](#sameindices) | static method (private) | A | Compare two storage-index lists element-wise for equality. |

Row count (7) matches `grep -c 'Purpose:' dataset_storage.dart` (7) exactly.

## Documentation

### `static Future<File> _getFile()` <a id="getfile"></a>
- **Kind:** private static method.
- **Source:** `lib/features/datasets/services/dataset_storage.dart` (line 16).
- **Purpose:** Resolve the `dataset_data.json` file inside the current app directory.
- **Inputs:** None.
- **Returns:** `Future<File>`.
- **Side effects:** None beyond `DeviceStorage.getAppDir()`'s directory-creation side effect.
- **Algorithm:** `File('${(await DeviceStorage.getAppDir()).path}/dataset_data.json')`.
- **Usage:** Called by [`load`](#load) and [`save`](#save).
- **Notes:** Same pattern as `NetworkStorage._getFile`
  (`../../network/services/network_storage.md`) — delegating to `DeviceStorage.getAppDir()` keeps
  `dataset_data.json` co-located with the app's other data files even after a custom storage path
  is set.

### `static Future<DataSetData> load()` <a id="load"></a>
- **Kind:** static method.
- **Source:** `lib/features/datasets/services/dataset_storage.dart` (line 26).
- **Purpose:** Load the persisted dataset list from `dataset_data.json`.
- **Inputs:** None.
- **Returns:** `Future<DataSetData>` — `const DataSetData()` (empty) if the file is absent or empty.
- **Side effects:** Reads `dataset_data.json`.
- **Algorithm:** Existence/empty-content checks, then `DataSetData.fromJson(jsonDecode(...))` (see
  [`../models/dataset.md#datasetdata-fromjson`](../models/dataset.md)).
- **Usage:**
  ```dart
  final dsData = await DataSetStorage.load();
  ```
  (from [`dataset_list_page.md`](../views/dataset_list_page.md)'s `_load`)
- **Notes:** None.

### `static Future<void> save(DataSetData data)` <a id="save"></a>
- **Kind:** static method.
- **Source:** `lib/features/datasets/services/dataset_storage.dart` (line 40).
- **Purpose:** Persist the full dataset list to `dataset_data.json` and notify the auto-sync
  service that local data changed.
- **Inputs:** `data`.
- **Returns:** `Future<void>`.
- **Side effects:** Writes `dataset_data.json` (pretty-printed, non-atomic); calls
  `AutoSyncService.instance.notifySaved()` (see
  [`../../../../shared/services/auto_sync_service.md#notifysaved`](../../../shared/services/auto_sync_service.md)).
- **Algorithm:** JSON-encode `data.toJson()`, write it, then notify auto-sync.
- **Usage:**
  ```dart
  await save(DataSetData(datasets: updated, extraJson: data.extraJson));
  ```
  (from [`remapDeviceStorageLinks`](#remapdevicestoragelinks) below, after rewriting affected links)
- **Notes:** Every write to dataset data should go through this method (directly or via
  [`addOrUpdate`](#addorupdate)/[`delete`](#delete)/[`remapDeviceStorageLinks`](#remapdevicestoragelinks))
  so `AutoSyncService` is always notified.

### `static Future<void> addOrUpdate(DataSet dataset)` <a id="addorupdate"></a>
- **Kind:** static method.
- **Source:** `lib/features/datasets/services/dataset_storage.dart` (line 52).
- **Purpose:** Insert a new dataset or replace an existing one, matched by `id`.
- **Inputs:** `dataset`.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `dataset_data.json` via [`save`](#save).
- **Algorithm:** Load the current list; find the index of an existing dataset with the same `id`,
  replacing it if found, else append; save.
- **Usage:**
  ```dart
  await DataSetStorage.addOrUpdate(ds);
  ```
  (from [`dataset_edit_page.md`](../views/dataset_edit_page.md)'s `_save`)
- **Notes:** None.

### `static Future<void> delete(String id)` <a id="delete"></a>
- **Kind:** static method.
- **Source:** `lib/features/datasets/services/dataset_storage.dart` (line 69).
- **Purpose:** Delete a dataset by id.
- **Inputs:** `id`.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `dataset_data.json` via [`save`](#save).
- **Algorithm:** Filter the dataset out of the loaded list; save.
- **Usage:**
  ```dart
  await DataSetStorage.delete(ds.id);
  ```
  (from [`dataset_list_page.md`](../views/dataset_list_page.md)'s `_deleteDataSet`)
- **Notes:** Unlike `DeviceStorage.deleteDevice`, this does not clean up any reverse references —
  a dataset has no dependents, so deleting it needs no cascade (compare
  [Devices](../../../../features/devices.md#cascade-rules-on-retiresell-delete), where deleting a
  *device* does clean up its dataset storage links, in the other direction).

### `static Future<void> remapDeviceStorageLinks({required String deviceId, required int oldSlotCount, required Map<int, int> indexMap})` <a id="remapdevicestoragelinks"></a>
- **Kind:** static method.
- **Source:** `lib/features/datasets/services/dataset_storage.dart` (line 85).
- **Purpose:** Re-map every dataset's `storageIndices` for one device after that device's storage
  list was reordered or had entries removed, so links keep pointing at the correct physical slot
  instead of silently drifting.
- **Inputs:** `deviceId` — which device's storage changed; `oldSlotCount` — how many slots existed
  before the edit; `indexMap` — maps each **old** slot index (`0..oldSlotCount-1`) to its **new**
  index; an old index absent from the map means that slot was removed with no replacement.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `dataset_data.json` via [`save`](#save) — but only if at least one
  dataset actually changed; bumps `modifiedAt` (via [`copyWith`](../models/dataset.md#copywith)) on
  every dataset it touches.
- **Algorithm:** 1. Check whether `indexMap` is the identity mapping for every index
  `0..oldSlotCount-1`; if so, return immediately without loading or saving anything (no-op fast
  path). 2. Otherwise load all datasets. 3. For each dataset, for each `DataSetStorageLink`: if its
  `deviceId` doesn't match, keep it unchanged. Otherwise, build `newIndices` by looking up each of
  the link's `storageIndices` in `indexMap` — an index with a mapping is kept at its new position;
  an index with no mapping (`indexMap[idx] == null`) is dropped entirely. 4. If `newIndices` differs
  from the original `storageIndices` (by length or by content, via [`_sameIndices`](#sameindices)),
  mark this dataset as changed. 5. A link whose `newIndices` end up empty is dropped from the
  dataset's `storageLinks` entirely (rather than kept with an empty list). 6. Any dataset with at
  least one changed link is replaced via `copyWith(storageLinks: links)` (which also bumps
  `modifiedAt`); unaffected datasets pass through unchanged. 7. If no dataset changed at all, return
  without saving; otherwise save the updated dataset list.
- **Usage:** Called by the device editor's save handler on every save, with the old→new slot index
  map it tracked while the user edited/reordered/removed storage rows — see
  [Datasets](../../../../features/datasets.md#device-editor-integration) for the call-site
  contract this function's callers must uphold.
- **Notes:** This is the single implementation of the "reordering/removing device storage slots
  must keep dataset links in sync" rule called out in `AGENTS.md` (see
  [Datasets](../../../../features/datasets.md#storage-slot-index-linking)) — any *new* code path
  that lets a user reorder or remove storage slots must also call this function with the resulting
  index map, or dataset links will silently point at the wrong (or a nonexistent) slot. The
  identity-mapping fast path in step 1 means calling this unconditionally on every device save is
  cheap when storage wasn't actually reordered/removed.

### `static bool _sameIndices(List<int> a, List<int> b)` <a id="sameindices"></a>
- **Kind:** private static method.
- **Source:** `lib/features/datasets/services/dataset_storage.dart` (line 145).
- **Purpose:** Compare two storage-index lists element-wise for equality.
- **Inputs:** `a`, `b`.
- **Returns:** `bool` — `false` immediately on a length mismatch; otherwise `true` only if every
  position matches.
- **Side effects:** None.
- **Algorithm:** Length check, then a `for` loop comparing `a[i]` to `b[i]`, returning `false` on
  the first mismatch.
- **Usage:** Called only by [`remapDeviceStorageLinks`](#remapdevicestoragelinks), to decide whether
  a link's `storageIndices` actually changed (as opposed to only its length changing, which is
  checked separately by the caller).
- **Notes:** Order-sensitive — `[0, 1]` and `[1, 0]` are considered different, which matters because
  `remapDeviceStorageLinks` preserves the original ordering of surviving indices rather than
  re-sorting them.
