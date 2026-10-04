# Datasets

Model source: `lib/features/datasets/models/dataset.dart`. See
[Data Formats](../data-formats.md#dataset--datasetstoragelink-libfeaturesdatasetsmodelsdatasetdart)
for the exact field list.

## DataSet / DataSetStorageLink

- **`DataSet`:** `id`, `name`, `emoji` (default `'📁'`), `storageLinks`
  (`List<DataSetStorageLink>`), `modifiedAt`, `extraJson`.
- **`DataSetStorageLink`:** `deviceId` plus `storageIndices` (`List<int>`) — the
  positions within that device's `storage: List<StorageInfo>` list that this dataset
  spans.

A single `DataSet` can be on storage slots of multiple devices (multiple
`DataSetStorageLink` entries), and on multiple slots of the same device
(multiple indices in one link's `storageIndices`). Since 1.8.2 a link can also name whole RAID
arrays of the device (`arrayIds`).

## Copies

**Every linked storage slot holds a full, equal copy of the data set.** A data set is never
split across storages, and no copy is "the original": the copies are peers kept in sync. So the
number of slots a data set resolves to is its **copy count**, and a data set with one copy has
no backup. The model has no role field and needs none; 1.8.0 made this meaning explicit in the
UI (the edit page's "Storages holding a copy" and its note) without changing the file.

`resolveReplicas` in `lib/features/datasets/services/dataset_placement.dart` turns a data set's
links into its copies against the current device list, skipping a link to a deleted device, an
out-of-range index and a slot listed twice. Everything that counts copies goes through it — the
grouped list and the topology — so they always agree. See
[`dataset_placement.md`](../functions/features/datasets/services/dataset_placement.md).

## Drive health and RAID arrays <a id="drive-health-and-raid-arrays"></a>

Since 1.8.2 a copy lives on a **place** (`StoragePlace`): either one storage slot or one RAID
array of a device (see [Devices](devices.md#drive-status-and-raid-arrays)). `devicePlaces` lists a
device's places — its arrays first, then the slots in no array — and the edit page, the grouped
list and the topology all show those, so a drive inside an array is reached through the array. A
link that still names an array member directly (an older link, or one made before the array) keeps
its copy visible: the member slot is listed after the device's places.

A place has a health (`PlaceHealth`): a slot is *unavailable* when its drive is failed or offline;
an array is *degraded* while its failed members are within the level's fault tolerance and
*unavailable* beyond it. Copies on an unavailable place stay listed and drawn but do not count as
usable: `availableCopyCount` counts the rest, and the shared `dataSetCopySummary` words it as "n
copies · k unavailable" (led by "No usable copy" when none is left). A data set with at most one
usable copy is drawn in the error colour. The edit page shows each place's state but keeps it
tickable.

## Grouping the list

Since 1.8.0 the data set list's app bar has a **Group** menu: *No grouping* (the default),
*By device* or *By storage*. The choice is stored locally as `datasetGroupMode` in
`storage_config.json` (see [Data Formats](../data-formats.md#storage_configjson-key-datasetgroupmode)).

- **By device:** one group per device that holds at least one copy, in device-list order. A data
  set with copies on several devices appears under each of them; one with copies on two slots of
  the same device appears once there.
- **By storage:** one group per place — a RAID array ("device · RAID 5 · name") or a slot
  ("device · storage"), arrays first. Slots are named by
  `storageSlotLabel`: the slot's summary (e.g. "8 TB HDD"), "Storage n" for an empty slot, and a
  `#n` suffix when two slots of one device would read the same.
- **Not on any storage:** a last group for data sets that resolve to no copy (no links, or only
  dangling ones).

In a group a tile's subtitle shows the copy count and where else the data set is ("Also on:
…"); a data set with a single copy reads *Only one copy* in the error colour, and copies on failed
drives are called out as unavailable (see [above](#drive-health-and-raid-arrays)). Grouping keeps the
sort order inside each group, keeps swipe-to-delete at one column and the menu tile above it, and
hides *Reorder*, since a data set may sit in several groups.

## Data set topology

The account-tree action in the data set list's app bar opens a full-screen topology
(`dataset_topology_page.dart`, laid out by the pure `DataSetTopologyLayout` in
`dataset_topology.dart`):

- **Nested boxes.** Each device is a large box with its icon and name; its places — RAID arrays
  (a layers icon) and then the slots in no array — are medium boxes stacked inside it; each data
  set copy on a place is a small box inside it, two per row, with an `×n` copy-count badge
  (`×usable/n` when some copies are unavailable). A failed or offline drive and a lost array get
  an error border and icon, a degraded array the icon; copies on an unavailable place are greyed
  and struck through. The legend explains the mark. Devices with no storage slot are never drawn;
  devices with storage but no copy only when *Show devices without data sets* is on.
- **Sync lines.** Off by default since 1.8.1 (the timeline action in the app bar turns them
  on; the choice is not saved). When on, the copies of one data set are joined by soft curves — one chain through the
  copies in drawing order, not a line between every pair, so four copies make three lines. A
  data set keeps one colour for its copies and lines (a stable hash of its id); a data set with a
  single copy is drawn in the error colours instead.
- **Placement.** Since 1.8.1 devices are packed into columns, each device into the currently
  shortest column, so a tall device (many storages) simply makes its column longer while the next
  devices fill the others. The column count is the one whose canvas comes closest to square up to
  16:10 (width / height between 1 and 1.6; ties go to the smaller canvas), independent of the
  window size — pan and zoom take care of the rest. The device order is greedy: the device holding the most data sets first, then each time the device that
  shares the most data sets with those already placed, so devices that sync sit side by side.
- **Selection.** Tapping a copy lights every copy of that data set, their storages and devices,
  and the lines between them; tapping a storage's or a device's header lights every data set on
  it and all of their copies elsewhere. Everything else is dimmed. A tap on empty canvas or the
  selection chip clears it.
- **Details.** A bottom sheet on phones, a pane beside the canvas on split windows: what was
  tapped, then one card per data set on it listing every copy as "device – storage" (copies on
  the selected box ticked, unavailable ones struck through in the error colour) with an edit
  button. After the editor closes the topology reloads.
- **View.** The same single canvas as the services topology: tap to select, drag to pan,
  pinch or Ctrl + wheel to zoom, the wheel to pan; zoom, Fit and Reset buttons; a device filter;
  a legend; PNG export of the canvas with its highlight.

The filter narrows what is drawn, not what is counted: a copy's `×n` still counts copies on
hidden devices, and a line to a hidden copy is simply not drawn.

## Storage-slot-index linking

Because a link stores plain integer indices into a device's `storage` list rather than
stable per-slot identifiers, **any code path that reorders or removes device storage
slots must keep dataset links in sync** — otherwise a link silently starts pointing at
the wrong physical slot (or a slot that no longer exists) after the device's storage
list is edited.

## `remapDeviceStorageLinks()`

`DataSetStorage.remapDeviceStorageLinks()` (in
`lib/features/datasets/services/dataset_storage.dart`) is the function that keeps links
valid. Confirmed signature:

```dart
static Future<void> remapDeviceStorageLinks({
  required String deviceId,
  required int oldSlotCount,
  required Map<int, int> indexMap,
  Set<String>? keptArrayIds,
  Map<int, String> arrayOfSlot = const {},
})
```

- `indexMap` maps each **old** slot index to its **new** slot index after the edit.
- `keptArrayIds` (since 1.8.2) is the device's array ids after the edit: `arrayIds` not in it are
  dropped. `arrayOfSlot` maps a **new** slot index to the array it now belongs to: a link to such a
  slot is moved to the array (once), since an array's data is one copy. Array links are by id, so
  slot moves never touch them.
- If `indexMap` is the identity mapping for every index `0..oldSlotCount-1` (nothing
  actually moved), and neither `keptArrayIds` nor `arrayOfSlot` is given, the function returns
  immediately without touching any dataset.
- Otherwise it loads all datasets, and for every `DataSetStorageLink` whose `deviceId`
  matches, it re-maps each index in `storageIndices` through `indexMap`:
  - An index with a mapping (`indexMap[idx] != null`) is kept, remapped to its new
    position — this is the **slot removal/compaction** case: surviving slots shift
    down to fill the gap left by a removed slot, and `indexMap` reflects the new
    (compacted) positions.
  - An index with **no** mapping (removed entirely, no corresponding new slot) is
    **dropped** from `storageIndices`.
  - A link left with no slot and no array is removed.
- Any `DataSet` whose links actually changed gets a bumped `modifiedAt` so the fix
  propagates through sync (see [WebDAV Sync](../sync.md)) instead of silently
  diverging between devices.

## Device editor integration

The device editor tracks each storage row's **original slot index** as the user
edits/reorders/removes storage entries, and calls `remapDeviceStorageLinks()` on save
with the resulting old→new index map. This is why "any new code path that reorders or
removes device storage slots must do the same" is called out directly in `AGENTS.md` —
it's easy to add a new storage-editing UI path that forgets this step and silently
corrupts dataset links.

## Related

- [`dataset_topology.md`](../functions/features/datasets/services/dataset_topology.md) and
  [`dataset_topology_page.md`](../functions/features/datasets/views/dataset_topology_page.md) for
  the topology's layout and page.
- [Devices](devices.md) for the `storage: List<StorageInfo>` field these links index
  into.
- [Data Formats](../data-formats.md#cross-reference-rules) — deleting a dataset deletes
  its contained storage links; deleting a device must also clean up its dataset links.
