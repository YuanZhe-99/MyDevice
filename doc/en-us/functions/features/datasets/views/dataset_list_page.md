# lib/features/datasets/views/dataset_list_page.dart

The datasets home screen (see [Datasets](../../../../features/datasets.md)). Owns the dataset
list's load/sort/reorder state, builds each tile's storage-summary subtitle by cross-referencing
[`DataSetStorageLink`](../models/dataset.md#datasetstoragelink-new) indices against the live
device list, and drives the add/edit/delete flow backed by
[`DataSetStorage`](../services/dataset_storage.md). Registers with `AutoSyncService`
(`../../../../shared/services/auto_sync_service.md`) so the list refreshes itself whenever a
background sync brings in new local data — the same pattern used by
[`device_list_page.md`](../../devices/views/device_list_page.md) and
[`network_list_page.md`](../../network/views/network_list_page.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `DataSetListPage` (constructor) | constructor | B | Create the page widget (no parameters). |
| `createState` | method (`DataSetListPage`) | B | Create the page's mutable state object. |
| [`initState`](#initstate) | method (widget lifecycle) | A | Register the auto-sync listener and kick off preference/dataset loading. |
| `dispose` | method (widget lifecycle) | B | Unregister the auto-sync listener. |
| `_handleLocalDataChanged` | method (`_DataSetListPageState`) | B | Reload datasets in response to an auto-sync notification. |
| [`_loadSortPrefs`](#loadsortprefs) | method (`_DataSetListPageState`) | A | Load the persisted sort mode/direction from device storage config. |
| [`_saveSortPrefs`](#savesortprefs) | method (`_DataSetListPageState`) | A | Persist the current sort mode/direction to device storage config. |
| [`_sortedDatasets`](#sorteddatasets) | getter (`_DataSetListPageState`) | A | Sort `_datasets` per the current sort mode/direction. |
| [`_load`](#load) | method (`_DataSetListPageState`) | A | Reload both the dataset list and the device list from storage. |
| [`_storageLines`](#storagelines) | method (`_DataSetListPageState`) | A | Build one display line per storage link, resolving device/slot names. |
| `_addDataSet` | method (`_DataSetListPageState`) | B | Push the blank dataset edit page, then reload if it reported a save. |
| `_editDataSet` | method (`_DataSetListPageState`) | B | Push the dataset edit page for an existing dataset, then reload if it reported a save. |
| [`_deleteDataSet`](#deletedataset) | method (`_DataSetListPageState`) | A | Confirm and, if accepted, delete a dataset and notify the sync layer. |
| [`_onReorder`](#onreorder) | method (`_DataSetListPageState`) | A | Move a dataset within the custom order and persist the new order. |
| `_buildDataSetTile` | method (widget helper) | B | Render one dataset's list tile (emoji, name, storage-summary subtitle). |
| `build` | method (widget) | B | Build the scaffold: app bar, sort menu, dataset list or reorder view, add FAB. |

Row count (16) matches `grep -c 'Purpose:' dataset_list_page.dart` (16) exactly.

## Documentation

### `void initState()` <a id="initstate"></a>
- **Kind:** method of `_DataSetListPageState` (widget lifecycle override).
- **Source:** `lib/features/datasets/views/dataset_list_page.dart` (line 43).
- **Purpose:** Wire this page into the auto-sync notification system and kick off the initial
  preference/dataset loads.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Registers `_handleLocalDataChanged` with
  `AutoSyncService.instance.addOnLocalDataChanged`; starts an async load chain.
- **Algorithm:** 1. Calls `super.initState()`. 2. Registers `_handleLocalDataChanged` as an
  `AutoSyncService` local-data-changed listener. 3. Chains `_loadSortPrefs().then((_) => _load())`.
- **Usage:** Invoked automatically by the Flutter framework when `_DataSetListPageState` is first
  inserted into the tree; no direct call site.
- **Notes:** The counterpart `dispose()` calls
  `AutoSyncService.instance.removeOnLocalDataChanged(_handleLocalDataChanged)` to avoid leaking the
  listener (see
  [`auto_sync_service.md#addonlocaldatachanged`](../../../shared/services/auto_sync_service.md)).

### `Future<void> _loadSortPrefs()` <a id="loadsortprefs"></a>
- **Kind:** method of `_DataSetListPageState`.
- **Source:** `lib/features/datasets/views/dataset_list_page.dart` (line 75).
- **Purpose:** Load the persisted sort mode and sort direction from device storage config, falling
  back to sensible defaults.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads config via `DeviceStorage.readConfig()`; calls `setState`.
- **Algorithm:** Reads the config map; resolves `_sortMode` by matching the stored
  `'datasetSortMode'` string against `DataSetSortMode.values` by `.name`, falling back to
  `DataSetSortMode.custom` if missing/unrecognized; resolves `_sortAscending` (default `false`)
  directly; applies both via one `setState`.
- **Usage:** Chained after construction in [`initState`](#initstate).
- **Notes:** None.

### `Future<void> _saveSortPrefs()` <a id="savesortprefs"></a>
- **Kind:** method of `_DataSetListPageState`.
- **Source:** `lib/features/datasets/views/dataset_list_page.dart` (line 92).
- **Purpose:** Persist the current sort mode and direction back to device storage config.
- **Inputs:** None (reads `_sortMode`, `_sortAscending`).
- **Returns:** `Future<void>`.
- **Side effects:** Reads then writes the config via `DeviceStorage.readConfig()`/`writeConfig()`.
- **Algorithm:** Reads the existing config map, overwrites `'datasetSortMode'` (as the enum's
  `.name`) and `'datasetSortAscending'`, writes the whole map back.
- **Usage:** Called from the sort menu's `onSelected` handler in `build`.
- **Notes:** None.

### `List<DataSet> get _sortedDatasets` <a id="sorteddatasets"></a>
- **Kind:** getter of `_DataSetListPageState`.
- **Source:** `lib/features/datasets/views/dataset_list_page.dart` (line 104).
- **Purpose:** Produce the list for display: `_datasets` sorted by name (or left in custom/storage
  order).
- **Inputs:** None (reads `_datasets`, `_sortMode`, `_sortAscending`).
- **Returns:** `List<DataSet>` — a sorted copy; `_datasets` itself is never mutated.
- **Side effects:** None.
- **Algorithm:** 1. Copy `_datasets` into `list`. 2. If `_sortMode == custom`, return the copy
  unsorted. 3. Otherwise the only other mode, `alphabetical`, compares lowercased names. 4. Wrap the
  comparator to respect `_sortAscending` (swap argument order when ascending). 5. Sort and return.
- **Usage:** Read by the non-reordering branch of `build`'s `ListView.builder`:
  `_sortedDatasets[index]`.
- **Notes:** Unlike `NetworkListPage`'s three-mode sort (custom/alphabetical/subnet), datasets only
  have two modes — there's no per-dataset field analogous to `Network.subnet` worth sorting by.

### `Future<void> _load()` <a id="load"></a>
- **Kind:** method of `_DataSetListPageState`.
- **Source:** `lib/features/datasets/views/dataset_list_page.dart` (line 121).
- **Purpose:** Reload both the dataset list and the full device list, since
  [`_storageLines`](#storagelines) needs live device names/storage entries to build each tile's
  subtitle.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads via `DataSetStorage.load()` and `DeviceStorage.load()`; `setState` updates
  `_datasets`, `_devices`, and clears `_loading`.
- **Algorithm:** Awaits both loads (sequentially, not in parallel), returns early if unmounted, then
  sets `_datasets = dsData.datasets`, `_devices = devData.devices`, `_loading = false` in one
  `setState`.
- **Usage:** Called from [`initState`](#initstate) (after prefs load), `_handleLocalDataChanged`
  (auto-sync), and after every add/edit/delete/reorder flow.
- **Notes:** Loading the device list here (not just the dataset list) is what lets this page show
  `"{device.name} – {storage summary}"` instead of a raw `deviceId`/index — see
  [`_storageLines`](#storagelines).

### `List<String> _storageLines(DataSet ds)` <a id="storagelines"></a>
- **Kind:** method of `_DataSetListPageState`.
- **Source:** `lib/features/datasets/views/dataset_list_page.dart` (line 138).
- **Purpose:** Build one human-readable subtitle line per storage link on a dataset, grouped by
  device, for the list tile's subtitle.
- **Inputs:** `ds` — the dataset to summarize.
- **Returns:** `List<String>` — one line per `DataSetStorageLink` whose `deviceId` still resolves to
  a known device; links referencing a since-deleted device are silently skipped.
- **Side effects:** None.
- **Algorithm:** For each `DataSetStorageLink` in `ds.storageLinks`: 1. Look up the device by
  `link.deviceId` in `_devices`; skip this link entirely if not found (`continue`). 2. For each
  index in `link.storageIndices` that is still in range of `device.storage.length`, collect that
  slot's [`StorageInfo.displayString`](../../devices/models/device.md#storageinfo-displaystring).
  Out-of-range indices (stale after a storage-list shrink that wasn't remapped, or genuinely
  corrupt data) are silently skipped rather than shown as an error. 3. If no storage parts resolved
  (empty list but the device itself exists), the line is just the device's name; otherwise it's
  `"{device.name} – {parts.join(', ')}"`.
- **Usage:** `_storageLines(ds)` in `_buildDataSetTile` (this file, line 233), joined with `'\n'`
  for the tile subtitle (max 4 lines, ellipsized).
- **Notes:** This method is the read side of the positional-index contract described in
  [Datasets](../../../../features/datasets.md#storage-slot-index-linking) — an index that's out of
  range here (rather than causing a crash) is exactly the "stale/dangling" failure mode that
  [`remapDeviceStorageLinks`](../services/dataset_storage.md#remapdevicestoragelinks) exists to
  prevent by keeping indices in sync whenever a device's storage list changes.

### `Future<void> _deleteDataSet(DataSet ds)` <a id="deletedataset"></a>
- **Kind:** method of `_DataSetListPageState`.
- **Source:** `lib/features/datasets/views/dataset_list_page.dart` (line 188).
- **Purpose:** Show a confirmation dialog for deleting a dataset, and if confirmed, delete it and
  refresh the list.
- **Inputs:** `ds` — the dataset the user swiped to delete.
- **Returns:** `Future<void>`.
- **Side effects:** Shows an `AlertDialog`; on confirmation, calls `DataSetStorage.delete`,
  `AutoSyncService.instance.notifySaved()`, and reloads.
- **Algorithm:** 1. Shows an `AlertDialog` with Cancel/Delete actions, awaiting a `bool?`. 2. If
  `true`: deletes by id via `DataSetStorage.delete`, calls
  `AutoSyncService.instance.notifySaved()`, and reloads. 3. Otherwise does nothing.
- **Usage:** `confirmDismiss: (_) async { await _deleteDataSet(ds); return false; }` on the
  `Dismissible` wrapping each tile in `build` — always returns `false` to `confirmDismiss` regardless
  of outcome, since `_load()` (inside `_deleteDataSet`) already rebuilds the list rather than
  letting `Dismissible` remove the tile itself.
- **Notes:** Because `confirmDismiss` always returns `false`, the swiped tile visually snaps back
  before the list rebuilds from the reload — there is a brief moment where the (already-deleted)
  tile is still shown mid-animation.

### `Future<void> _onReorder(int oldIndex, int newIndex)` <a id="onreorder"></a>
- **Kind:** method of `_DataSetListPageState`.
- **Source:** `lib/features/datasets/views/dataset_list_page.dart` (line 219).
- **Purpose:** Move a dataset to a new position in the custom order and persist the change.
- **Inputs:** `oldIndex`, `newIndex` — from `ReorderableListView.builder`'s `onReorderItem`.
- **Returns:** `Future<void>`.
- **Side effects:** Mutates `_datasets` in place; `setState`; persists via
  `DataSetStorage.save`; calls `AutoSyncService.instance.notifySaved()`.
- **Algorithm:** Removes the dataset at `oldIndex` and reinserts it at `newIndex`; calls `setState`;
  awaits `DataSetStorage.save(DataSetData(datasets: _datasets))`, then separately calls
  `AutoSyncService.instance.notifySaved()`.
- **Usage:** `onReorderItem: _onReorder,` on the `ReorderableListView.builder` shown while
  `_reordering` is true, in `build`.
- **Notes:** Unlike `NetworkListPage._onReorder` (which re-loads `assignments` before saving so it
  doesn't clobber them), this method saves `DataSetData(datasets: _datasets)` without carrying
  forward any `extraJson` on the top-level `DataSetData` — if the persisted file ever had unknown
  top-level keys there, a reorder would drop them (this file's `DataSetData` model does have an
  `extraJson` field, but this call site doesn't pass it through).
