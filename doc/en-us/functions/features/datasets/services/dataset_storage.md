# lib/features/datasets/services/dataset_storage.dart

`DataSetStorage` persists the `dataset_data.json` file and owns the one piece of cross-cutting
logic datasets need: keeping each dataset's positional `storageIndices` (and its `arrayIds`) valid
whenever a device's `storage` list is reordered or has entries removed, or its RAID arrays change. See
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
| [`_serialised`](#serialised) | static method (private) | A | Run a read-modify-write behind earlier writes of `dataset_data.json` (per-path write queue). |
| [`_write`](#write) | static method (private) | A | Write `dataset_data.json` atomically and notify auto-sync (the unqueued primitive). |
| [`load`](#load) | static method | A | Load the persisted `DataSetData` (dataset list). |
| [`save`](#save) | static method | A | Persist `DataSetData` and notify the auto-sync service. |
| [`addOrUpdate`](#addorupdate) | static method | A | Insert or replace a dataset by id. |
| [`delete`](#delete) | static method | A | Delete a dataset by id. |
| [`remapDeviceStorageLinks`](#remapdevicestoragelinks) | static method | A | Re-map (or drop) dataset slot indices and array ids after a device's storage or arrays changed. |
| [`_sameIds`](#sameids) | static method (private) | A | Compare two array-id lists element-wise for equality. |
| [`_sameIndices`](#sameindices) | static method (private) | A | Compare two storage-index lists element-wise for equality. |

Row count (10) matches `grep -c 'Purpose:' dataset_storage.dart` (10) exactly.

Since 1.6.2 every write is **atomic and serialised**: `save` and every read-modify-write mutator
run inside a per-file-path write queue (`DeviceStorage.serializeWrite`, one `AtomicWriteQueue` per
path), read the file fresh, and end in the private `_write`, which replaces the file through a
temporary file plus rename (`DeviceStorage.atomicWrite`) — so two overlapping edits cannot lose
each other's changes and a crash cannot leave a truncated file. Code that already runs inside the
queue must call `_write`, never the public `save`, which would wait for itself and deadlock.
Every rebuild of the container also carries the file's unknown top-level fields (`extraJson`)
through, so a newer build's data is not dropped by an older one.

## Documentation

### `static Future<File> _getFile()` <a id="getfile"></a>
- **Kind:** private static method.
- **Source:** `lib/features/datasets/services/dataset_storage.dart` (line 27).
- **Purpose:** Resolve the `dataset_data.json` file inside the current app directory.
- **Inputs:** None.
- **Returns:** `Future<File>`.
- **Side effects:** None beyond `DeviceStorage.getAppDir()`'s directory-creation side effect.
- **Algorithm:** `File('${appDir.path}/$_dataFileName')` on `DeviceStorage.getAppDir()`, where
  `_dataFileName` aliases `dataSetDataFileName` (`'dataset_data.json'`) from
  [`data_modules.dart`](../../../app/data_modules.md#constants).
- **Usage:** Called by [`load`](#load) and [`save`](#save).
- **Notes:** Same pattern as `NetworkStorage._getFile`
  (`../../network/services/network_storage.md`) — delegating to `DeviceStorage.getAppDir()` keeps
  `dataset_data.json` co-located with the app's other data files even after a custom storage path
  is set.

### `static Future<void> _serialised(Future<void> Function() operation)` <a id="serialised"></a>
- **Kind:** private static method. **Since:** 1.6.2.
- **Purpose:** Run `operation` after every earlier write of `dataset_data.json` has finished.
- **Inputs:** `operation`. **Returns:** `Future<void>`.
- **Side effects:** Resolves the file path, then appends to that path's write queue.
- **Algorithm:** `DeviceStorage.serializeWrite(file.path, operation)`.
- **Usage:** `save` and every mutator of this class.
- **Notes:** The queue is keyed by file path, not global, so unrelated files never wait for each
  other and a queue left mid-write cannot stall a different storage folder.

### `static Future<void> _write(DataSetData data)` <a id="write"></a>
- **Kind:** private static method. **Since:** 1.6.2.
- **Purpose:** Write `dataset_data.json` atomically and notify auto-sync.
- **Inputs:** `data`. **Returns:** `Future<void>`.
- **Side effects:** Temporary file plus rename write; `AutoSyncService.instance.notifySaved()`.
- **Algorithm:** Pretty-print `data.toJson()` with a two-space indent, `DeviceStorage.atomicWrite`
  it, then notify.
- **Usage:** The queued operations of this class, and `save` through the queue.
- **Notes:** Never enqueue from here or from anything it calls; see the deadlock rule above.

### `static Future<DataSetData> load()` <a id="load"></a>
- **Kind:** static method.
- **Source:** `lib/features/datasets/services/dataset_storage.dart` (line 37).
- **Purpose:** Load the persisted dataset list from `dataset_data.json`.
- **Inputs:** None.
- **Returns:** `Future<DataSetData>` — `const DataSetData()` (empty) if the file is absent or empty.
- **Side effects:** Reads `dataset_data.json`.
- **Algorithm:** Existence/empty-content checks, then `DataSetData.fromJson(jsonDecode(...))` (see
  [`../models/dataset.md#datasetdata-fromjson`](../models/dataset.md#datasetdata-fromjson)).
- **Usage:**
  ```dart
  final dsData = await DataSetStorage.load();
  ```
  (from [`dataset_list_page.md`](../views/dataset_list_page.md)'s `_load`)
- **Notes:** None.

### `static Future<void> save(DataSetData data)` <a id="save"></a>
- **Kind:** static method.
- **Source:** `lib/features/datasets/services/dataset_storage.dart` (line 53).
- **Purpose:** Persist the full dataset list to `dataset_data.json` and notify the auto-sync
  service that local data changed.
- **Inputs:** `data`.
- **Returns:** `Future<void>`.
- **Side effects:** Atomically replaces `dataset_data.json` (pretty-printed, tmp file + rename, queued behind earlier writes); calls
  `AutoSyncService.instance.notifySaved()` (see
  [`../../../shared/services/auto_sync_service.md`](../../../shared/services/auto_sync_service.md)).
- **Algorithm:** Enqueue [`_write`](#write) (JSON-encode `data.toJson()`, atomic write, then notify auto-sync) on the per-path write queue.
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
- **Source:** `lib/features/datasets/services/dataset_storage.dart` (line 72).
- **Purpose:** Insert a new dataset or replace an existing one, matched by `id`.
- **Inputs:** `dataset`.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `dataset_data.json` through the write queue ([`_serialised`](#serialised) → [`_write`](#write)).
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
- **Source:** `lib/features/datasets/services/dataset_storage.dart` (line 89).
- **Purpose:** Delete a dataset by id.
- **Inputs:** `id`.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `dataset_data.json` through the write queue ([`_serialised`](#serialised) → [`_write`](#write)).
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

### `static Future<void> remapDeviceStorageLinks({required String deviceId, required int oldSlotCount, required Map<int, int> indexMap, Set<String>? keptArrayIds, Map<int, String> arrayOfSlot = const {}})` <a id="remapdevicestoragelinks"></a>
- **Kind:** static method.
- **Source:** `lib/features/datasets/services/dataset_storage.dart` (line 110).
- **Purpose:** Re-map every dataset's `storageIndices` (and, since 1.8.2, `arrayIds`) for one
  device after that device's storage list or RAID arrays changed, so links keep pointing at the
  correct physical slot or array instead of silently drifting.
- **Inputs:** `deviceId` — which device's storage changed; `oldSlotCount` — how many slots existed
  before the edit; `indexMap` — maps each **old** slot index (`0..oldSlotCount-1`) to its **new**
  index; an old index absent from the map means that slot was removed with no replacement;
  `keptArrayIds` — when non-null, the device's array ids after the edit (links to any other array
  are dropped); `arrayOfSlot` — **new** slot index → id of the array that slot now belongs to.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `dataset_data.json` through the write queue ([`_serialised`](#serialised) → [`_write`](#write)) — but only if at least one
  dataset actually changed; bumps `modifiedAt` (via [`copyWith`](../models/dataset.md#copywith)) on
  every dataset it touches.
- **Algorithm:** 1. If `indexMap` is the identity mapping for every index `0..oldSlotCount-1`,
  `keptArrayIds` is null and `arrayOfSlot` is empty, return immediately without loading or saving
  anything (no-op fast path). 2. Otherwise load all datasets. 3. For each dataset, for each
  `DataSetStorageLink`: if its `deviceId` doesn't match, keep it unchanged. Otherwise start
  `newArrays` from the link's `arrayIds` (filtered to `keptArrayIds` when given), then look up each
  of the link's `storageIndices` in `indexMap` — an index with no mapping is dropped; a mapped
  index whose new slot is in `arrayOfSlot` is moved to that array (added to `newArrays` once);
  any other mapped index is kept at its new position in `newIndices`. 4. If `newIndices` differs
  from the original `storageIndices` (by length or content, via [`_sameIndices`](#sameindices)) or
  `newArrays` differs from `arrayIds` (via [`_sameIds`](#sameids)), mark this dataset as changed.
  5. A link left with neither slots nor arrays is dropped from the dataset's `storageLinks`
  entirely. 6. Any dataset with at least one changed link is replaced via
  `copyWith(storageLinks: links)` (which also bumps `modifiedAt`); unaffected datasets pass through
  unchanged. 7. If no dataset changed at all, return without saving; otherwise save the updated
  dataset list.
- **Usage:** Called by the device editor's save handler on every save, with the old→new slot index
  map it tracked while the user edited/reordered/removed storage rows, the kept array ids and the
  slot → array membership of the edited arrays — see
  [Datasets](../../../../features/datasets.md#device-editor-integration) for the call-site
  contract this function's callers must uphold.
- **Notes:** This is the single implementation of the "reordering/removing device storage slots
  must keep dataset links in sync" rule called out in `AGENTS.md` (see
  [Datasets](../../../../features/datasets.md#storage-slot-index-linking)) — any *new* code path
  that lets a user reorder or remove storage slots must also call this function with the resulting
  index map, or dataset links will silently point at the wrong (or a nonexistent) slot. Array links
  are by id, so they survive slot changes; a link to a slot that became an array member moves to
  the array, because the array's data is one copy. The editor always passes `keptArrayIds`, so from
  there the fast path of step 1 no longer short-circuits; the load-and-compare still saves nothing
  when no link changed.

### `static bool _sameIds(List<String> a, List<String> b)` <a id="sameids"></a>
- **Kind:** private static method. **Since:** 1.8.2.
- **Source:** `lib/features/datasets/services/dataset_storage.dart` (line 185).
- **Purpose:** Compare two array-id lists element-wise for equality.
- **Inputs:** `a`, `b`.
- **Returns:** `bool` — `false` on a length mismatch; otherwise `true` only if every position
  matches.
- **Side effects:** None.
- **Algorithm:** Length check, then a `for` loop comparing `a[i]` to `b[i]`.
- **Usage:** Called only by [`remapDeviceStorageLinks`](#remapdevicestoragelinks), to decide whether
  a link's `arrayIds` changed.
- **Notes:** Order-sensitive, like [`_sameIndices`](#sameindices).

### `static bool _sameIndices(List<int> a, List<int> b)` <a id="sameindices"></a>
- **Kind:** private static method.
- **Source:** `lib/features/datasets/services/dataset_storage.dart` (line 198).
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
