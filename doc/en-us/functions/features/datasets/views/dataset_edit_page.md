# lib/features/datasets/views/dataset_edit_page.dart

The add/edit form for a single [`DataSet`](../models/dataset.md#dataset-new) — emoji picker, name
field, and a per-device checklist of storage slots to include. Reused for both "add"
(`dataSet: null`) and "edit" (`dataSet: existing`) via one constructor parameter. Loads the
in-service device list from
[`DeviceStorage.load`](../../devices/services/device_storage.md#load) to build the storage
checklist, and saves through
[`DataSetStorage.addOrUpdate`](../services/dataset_storage.md#addorupdate). See
[Datasets](../../../../features/datasets.md) for the model this page edits, in particular how a
`DataSetStorageLink`'s `storageIndices` are *positions* into a device's `storage` list rather than
stable identifiers.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `DataSetEditPage` (constructor) | constructor | B | Create the page widget (optional `dataSet` to edit). |
| `createState` | method (`DataSetEditPage`) | B | Create the page's mutable state object. |
| `_isEditing` | getter (`_DataSetEditPageState`) | B | Return whether an existing `DataSet` was passed in. |
| [`initState`](#initstate) | method (widget lifecycle) | A | Seed the name/emoji/selected-storage state from `widget.dataSet`, then load devices. |
| [`_loadDevices`](#loaddevices) | method (`_DataSetEditPageState`) | A | Load and filter the in-service devices with storage to offer in the checklist. |
| [`_save`](#save) | method (`_DataSetEditPageState`) | A | Build the storage links, construct/update the `DataSet`, persist it, and pop. |
| `_pickEmoji` | method (`_DataSetEditPageState`) | B | Show the emoji-picker dialog and apply the chosen emoji. |
| `dispose` | method (widget lifecycle) | B | Dispose the name text controller. |
| `build` | method (widget) | B | Build the scaffold around `_buildBody`. |
| `_buildBody` | method (widget helper) | B | Choose the layout: a single `ListView` (emoji/name row, then the storage checklist), or — when `useDetailTwoPane` passes — a `Row` of an `editFormLeftPaneWidth`-wide fixed left pane holding the row (in a scroll view pinned to the pane height as the soft-keyboard fallback) and a right `ListView` of the checklist. |
| `_buildHeaderRow` | method (widget helper) | B | The emoji tile and name field row — extracted from `build` unchanged. |
| `_buildStorageChildren` | method (widget helper) | B | The storage heading, empty-state text and per-device checkbox cards — extracted from `build` unchanged. |

Row count (9) matches `grep -c 'Purpose:' dataset_edit_page.dart` (9) exactly.

## Documentation

### `void initState()` <a id="initstate"></a>
- **Kind:** method of `_DataSetEditPageState` (widget lifecycle override).
- **Source:** `lib/features/datasets/views/dataset_edit_page.dart` (line 71).
- **Purpose:** When editing an existing dataset, seed the name field, emoji, and per-device
  selected-storage-index sets from it; either way, kick off loading the device list.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Sets `_nameController.text`, `_emoji`, and populates `_selectedStorages`; calls
  `_loadDevices()` (fire-and-forget).
- **Algorithm:** 1. Calls `super.initState()`. 2. If `_isEditing`, sets `_nameController.text` and
  `_emoji` from `widget.dataSet`, then for each of its `storageLinks`, populates
  `_selectedStorages[link.deviceId] = Set.of(link.storageIndices)` — converting the link's ordered
  index list into a set keyed by device id, which is what the checklist UI reads/mutates. 3. Calls
  `_loadDevices()` unconditionally (add or edit).
- **Usage:** Invoked automatically by the Flutter framework when `_DataSetEditPageState` is first
  inserted into the tree; no direct call site.
- **Notes:** Converting `storageIndices` (an ordered `List<int>`) into a `Set<int>` here means the
  original order is not preserved across an edit that doesn't touch a given device's selection —
  [`_save`](#save) re-sorts each device's set back into an ascending list before persisting, so this
  is not a data-loss risk, just a normalization.

### `Future<void> _loadDevices()` <a id="loaddevices"></a>
- **Kind:** method of `_DataSetEditPageState`.
- **Source:** `lib/features/datasets/views/dataset_edit_page.dart` (line 89).
- **Purpose:** Load the full device list and narrow it to devices that are both in service and have
  at least one storage entry — the only devices that make sense to offer in the storage checklist.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads via `DeviceStorage.load()`; `setState` updates `_devices` and clears
  `_loading`.
- **Algorithm:** Awaits `DeviceStorage.load()`, returns early if unmounted, then sets `_devices =
  data.devices.where((d) => d.isInService && d.storage.isNotEmpty).toList()` and `_loading = false`.
- **Usage:** Called once from [`initState`](#initstate).
- **Notes:** A retired/sold device (`!d.isInService`) never appears in this checklist even if it
  still has storage links from *before* it left service — those existing links stay in the
  persisted `DataSet` (this page doesn't drop them), but the user can't add new ones for that device
  through this UI. Compare
  [Devices](../../../../features/devices.md#cascade-rules-on-retiresell-delete), where retiring a
  device removes it from pickers going forward without retroactively deleting existing references.

### `Future<void> _save()` <a id="save"></a>
- **Kind:** method of `_DataSetEditPageState`.
- **Source:** `lib/features/datasets/views/dataset_edit_page.dart` (line 105).
- **Purpose:** Build the dataset's storage links from the current checklist selections, construct
  or update the `DataSet`, persist it, and close the page.
- **Inputs:** None (reads `_nameController.text`, `_emoji`, `_selectedStorages`,
  `widget.dataSet`).
- **Returns:** `Future<void>`.
- **Side effects:** Calls `DataSetStorage.addOrUpdate` (writes `dataset_data.json`); calls
  `AutoSyncService.instance.notifySaved()`; pops the page (returning `true`) if still mounted.
- **Algorithm:** 1. Return early if the trimmed name is empty (no validation dialog — just a silent
  no-op). 2. Snapshot each existing link's `extraJson` by `deviceId` from `widget.dataSet` (if
  editing), so re-saving preserves any unknown fields on links that survive. 3. For each device with
  a non-empty selected-index set, build a
  [`DataSetStorageLink`](../models/dataset.md#datasetstoragelink-new) with the indices sorted
  ascending and the preserved `extraJson` (or `{}` for a brand-new link). Devices with an empty
  selection are omitted entirely — they don't get a link at all. 4. Start from `widget.dataSet` if
  editing, else a fresh `DataSet(name: name, emoji: _emoji)`, then
  [`copyWith`](../models/dataset.md#copywith) the trimmed `name`, `_emoji`, and the built `links`
  list (this also bumps `modifiedAt`, since `copyWith` defaults it to "now"). 5. Await
  `DataSetStorage.addOrUpdate(ds)`. 6. Call `AutoSyncService.instance.notifySaved()`. 7. Pop with
  `true` if still mounted (the caller, `dataset_list_page.dart`, uses this `true` to decide whether
  to reload).
- **Usage:** Wired as the app bar's Save `TextButton.onPressed` in `build`.
- **Notes:** Sorting `entry.value.toList()..sort()` before constructing each link is what keeps
  `storageIndices` in ascending order regardless of the order the user checked the boxes in — this
  matters because [`remapDeviceStorageLinks`](../services/dataset_storage.md#remapdevicestoragelinks)
  and the list page's display logic both assume/prefer ascending order, even though nothing
  technically enforces it structurally.
