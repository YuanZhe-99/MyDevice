# lib/features/datasets/services/dataset_placement.dart

Pure helpers that turn a data set's `storageLinks`
([`../models/dataset.md`](../models/dataset.md)) into its **copies** against the current device
list, and group data sets for the list page (since 1.8.0). A copy lives in a **place** — one
storage slot, or (since 1.8.2) one RAID array (`StorageArray`, see
[`../../devices/models/device.md`](../../devices/models/device.md)) of a device. Every linked place
holds a full, equal copy — see [Datasets](../../../../features/datasets.md#copies) — so the number of
copies `resolveReplicas` returns is the copy count everything else shows, and
`availableCopyCount` is the number of those copies whose place can still be read. Used by
[`dataset_list_page.md`](../views/dataset_list_page.md),
[`dataset_copy_summary.md`](../views/dataset_copy_summary.md),
[`dataset_topology.md`](dataset_topology.md) and
[`dataset_topology_page.md`](../views/dataset_topology_page.md).

`enum DataSetGroupMode { none, device, storage }` — the list's grouping, persisted by name as
`datasetGroupMode` — and `enum PlaceHealth { ok, degraded, unavailable }` (1.8.2) — whether a place
can still serve its copy — have no members worth a row. The `StoragePlace` class itself has no
`Purpose:` comment; its constructors and getters do.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `StoragePlace.slot` | constructor | B | A slot place: device and a valid storage index. |
| `StoragePlace.array` | constructor | B | An array place: device and one of its `storageArrays`. |
| `isArray` | getter (`StoragePlace`) | B | Whether this is an array place. |
| `key` | getter (`StoragePlace`) | B | Key unique on the device: the slot index as text, or `a:<arrayId>`. |
| `memberIndices` | getter (`StoragePlace`) | B | The array's distinct, in-range member slots; empty for a slot. |
| `failedDrives` | getter (`StoragePlace`) | B | Failed or offline drives of the place (0/1 for a slot). |
| [`health`](#health) | getter (`StoragePlace`) | A | `PlaceHealth` of the place from its drives and RAID level. |
| [`devicePlaces`](#deviceplaces) | top-level function | A | A device's places: arrays, then slots in no array. |
| `DataSetReplica` (constructor) | constructor | B | One copy: data set and the place holding it. |
| `device` | getter (`DataSetReplica`) | B | The device holding the copy. |
| `storageIndex` | getter (`DataSetReplica`) | B | The slot of a slot copy; null for an array copy. |
| `isAvailable` | getter (`DataSetReplica`) | B | False when the copy's place is `unavailable`. |
| [`resolveReplicas`](#resolvereplicas) | top-level function | A | A data set's copies that exist, dangling links skipped. |
| `availableCopyCount` | top-level function | B | Count the replicas whose place is not `unavailable`. |
| `DataSetGroup` (constructor) | constructor | B | One list group: key, device, optional place, data sets. |
| `storageIndex` | getter (`DataSetGroup`) | B | The slot of a slot group; null otherwise. |
| `isUnlinked` | getter (`DataSetGroup`) | B | Whether this is the "Not on any storage" group. |
| [`groupDataSets`](#groupdatasets) | top-level function | A | Group data sets by device or by place. |
| `_placesWithMembers` | top-level function (private) | B | `devicePlaces` plus the member slots of arrays. |
| `placeLabel` | top-level function | B | Name a place: array `displayString`, or `storageSlotLabel`. |
| [`storageSlotLabel`](#storageslotlabel) | top-level function | A | A storage slot's name, unique on its device. |
| `base` | nested function (`storageSlotLabel`) | B | One slot's label before de-duplication. |

Row count (22) matches `grep -c 'Purpose:' dataset_placement.dart` (22) exactly.

## Documentation

### `PlaceHealth get health` <a id="health"></a>
- **Kind:** getter (`StoragePlace`).
- **Source:** `lib/features/datasets/services/dataset_placement.dart` (line 93).
- **Purpose:** Tell whether the place can serve its copy.
- **Inputs:** None.
- **Returns:** `PlaceHealth.ok`, `degraded` or `unavailable`.
- **Side effects:** None.
- **Algorithm:** No failed drives ⇒ `ok`. A slot with a failed or offline drive ⇒ `unavailable`.
  An array compares its failed members with `RaidLevel.faultTolerance(memberCount)`: within it ⇒
  `degraded`, beyond it ⇒ `unavailable`; a level without a defined tolerance (`other`) ⇒
  `degraded`.
- **Usage:** `DataSetReplica.isAvailable`; the list's and topology's health markers and copy
  summaries.
- **Notes:** A drive counts as failed when `StorageInfo.isHealthy` is false (status `failed` or
  `offline`). Members are the in-range, de-duplicated `memberIndices`.

### `List<StoragePlace> devicePlaces(Device device)` <a id="deviceplaces"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/datasets/services/dataset_placement.dart` (line 109).
- **Purpose:** List a device's places in display order.
- **Inputs:** `device`.
- **Returns:** One array place per `storageArrays` entry in stored order, then a slot place for
  every slot that belongs to no array.
- **Side effects:** None.
- **Algorithm:** Collect the member indices of each array while adding it, then add the remaining
  slots in index order.
- **Usage:** The data set editor's storage picker, the topology's storage boxes, and (via
  `_placesWithMembers`) `groupDataSets`.
- **Notes:** A member slot is reached through its array; a link that still names a member slot
  directly is still resolved by `resolveReplicas` and shown by `groupDataSets`.

### `List<DataSetReplica> resolveReplicas(DataSet dataSet, List<Device> devices)` <a id="resolvereplicas"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/datasets/services/dataset_placement.dart` (line 166).
- **Purpose:** Resolve a data set's storage links to the copies that exist.
- **Inputs:** `dataSet`; `devices` — the current device list.
- **Returns:** One `DataSetReplica` per linked slot and array, in link order, slots before arrays
  within a link.
- **Side effects:** None.
- **Algorithm:** Index devices by id; for each link whose device exists, add a slot place for each
  index in range `0 ≤ i < storage.length`, then an array place for each `arrayIds` entry that
  names an existing array; a `seen` set keyed `<deviceId>#<index>` / `<deviceId>#a:<arrayId>`
  drops duplicates.
- **Usage:** `groupDataSets`; the list's subtitles and copy summaries; `DataSetTopologyLayout.build`;
  the topology details.
- **Notes:** Skips links to a deleted device, out-of-range indices (the stale case
  [`remapDeviceStorageLinks`](dataset_storage.md#remapdevicestoragelinks) exists to prevent),
  removed arrays and a place listed twice, so the length is a true copy count — failed places
  included; `availableCopyCount` gives the copies that count.

### `List<DataSetGroup> groupDataSets(List<DataSet> dataSets, List<Device> devices, DataSetGroupMode mode)` <a id="groupdatasets"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/datasets/services/dataset_placement.dart` (line 256).
- **Purpose:** Group data sets by the device or the place holding them.
- **Inputs:** `dataSets` — in display order; `devices`; `mode` — `device` or `storage` (asserted
  not `none`).
- **Returns:** The non-empty groups: keyed `device:<id>` or `storage:<id>:<place key>` in
  device-list order (storage groups by place: arrays, free slots, then member slots still linked
  directly), then `unlinked` when any data set has no copy.
- **Side effects:** None.
- **Algorithm:** For each data set, resolve its copies; none ⇒ unlinked; otherwise add it once to
  each distinct group key of its copies. Then walk the devices (and `_placesWithMembers`) in
  order, emitting the buckets that exist.
- **Usage:** `_buildGroupedList` in [`dataset_list_page.md`](../views/dataset_list_page.md).
- **Notes:** A data set appears in every group it has a copy in — once per device in device mode,
  however many of its places it uses. Input order is kept within a group. A slot's place key is
  its index, so slot group keys are unchanged from 1.8.0. `test/dataset_topology_test.dart` and
  `test/storage_raid_health_test.dart` pin the grouping.

### `String storageSlotLabel(Device device, int index, String Function(int number) fallback)` <a id="storageslotlabel"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/datasets/services/dataset_placement.dart` (line 341).
- **Purpose:** Name a storage slot so it is unique on its device.
- **Inputs:** `device`, `index`; `fallback` — the localized "Storage n" for the 1-based number.
- **Returns:** `StorageInfo.displayString`, or the fallback when it is empty, with ` #n` appended
  when another slot of the device has the same text.
- **Side effects:** None.
- **Algorithm:** Compare the slot's base label with every other slot's.
- **Usage:** `placeLabel` for slot places (group headers, subtitles, topology boxes, selection chip
  and details); the editor's storage tiles.
- **Notes:** Two identical 8 TB disks in one NAS read "8 TB HDD" and "8 TB HDD #2".
