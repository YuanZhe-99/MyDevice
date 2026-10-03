# lib/features/datasets/services/dataset_placement.dart

Pure helpers that turn a data set's `storageLinks`
([`../models/dataset.md`](../models/dataset.md)) into its **copies** against the current device
list, and group data sets for the list page (since 1.8.0). Every linked storage slot holds a
full, equal copy — see [Datasets](../../../../features/datasets.md#copies) — so the number of
copies `resolveReplicas` returns is the copy count everything else shows. Used by
[`dataset_list_page.md`](../views/dataset_list_page.md),
[`dataset_topology.md`](dataset_topology.md) and
[`dataset_topology_page.md`](../views/dataset_topology_page.md).

`enum DataSetGroupMode { none, device, storage }` — the list's grouping, persisted by name as
`datasetGroupMode` — has no members worth a row.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `DataSetReplica` (constructor) | constructor | B | One copy: data set, device, storage index. |
| `storage` | getter (`DataSetReplica`) | B | The `StorageInfo` the copy lives on. |
| [`resolveReplicas`](#resolvereplicas) | top-level function | A | A data set's copies that exist, dangling links skipped. |
| `DataSetGroup` (constructor) | constructor | B | One list group: key, device, optional storage index, data sets. |
| `isUnlinked` | getter (`DataSetGroup`) | B | Whether this is the "Not on any storage" group. |
| [`groupDataSets`](#groupdatasets) | top-level function | A | Group data sets by device or by storage slot. |
| [`storageSlotLabel`](#storageslotlabel) | top-level function | A | A storage slot's name, unique on its device. |
| `base` | nested function (`storageSlotLabel`) | B | One slot's label before de-duplication. |

Row count (8) matches `grep -c 'Purpose:' dataset_placement.dart` (8) exactly.

## Documentation

### `List<DataSetReplica> resolveReplicas(DataSet dataSet, List<Device> devices)` <a id="resolvereplicas"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/datasets/services/dataset_placement.dart` (line 41).
- **Purpose:** Resolve a data set's storage links to the copies that exist.
- **Inputs:** `dataSet`; `devices` — the current device list.
- **Returns:** One `DataSetReplica` per linked slot, in link order and then index order.
- **Side effects:** None.
- **Algorithm:** Index devices by id; for each link whose device exists, for each index in range
  `0 ≤ i < storage.length` not already seen for that device, add a replica.
- **Usage:** `groupDataSets`; the list's grouped subtitles; `DataSetTopologyLayout.build`; the
  topology details.
- **Notes:** Skips links to a deleted device, out-of-range indices (the stale case
  [`remapDeviceStorageLinks`](dataset_storage.md#remapdevicestoragelinks) exists to prevent) and a
  slot listed twice, so the length is a true copy count.

### `List<DataSetGroup> groupDataSets(List<DataSet> dataSets, List<Device> devices, DataSetGroupMode mode)` <a id="groupdatasets"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/datasets/services/dataset_placement.dart` (line 100).
- **Purpose:** Group data sets by the device or the storage slot holding them.
- **Inputs:** `dataSets` — in display order; `devices`; `mode` — `device` or `storage` (asserted
  not `none`).
- **Returns:** The non-empty groups: keyed `device:<id>` or `storage:<id>:<index>` in device-list
  (and slot) order, then `unlinked` when any data set has no copy.
- **Side effects:** None.
- **Algorithm:** For each data set, resolve its copies; none ⇒ unlinked; otherwise add it once to
  each distinct group key of its copies. Then walk the devices (and their slots) in order,
  emitting the buckets that exist.
- **Usage:** `_buildGroupedList` in [`dataset_list_page.md`](../views/dataset_list_page.md).
- **Notes:** A data set appears in every group it has a copy in — once per device in device mode,
  however many of its slots it uses. Input order is kept within a group.
  `test/dataset_topology_test.dart` pins both modes.

### `String storageSlotLabel(Device device, int index, String Function(int number) fallback)` <a id="storageslotlabel"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/datasets/services/dataset_placement.dart` (line 163).
- **Purpose:** Name a storage slot so it is unique on its device.
- **Inputs:** `device`, `index`; `fallback` — the localized "Storage n" for the 1-based number.
- **Returns:** `StorageInfo.displayString`, or the fallback when it is empty, with ` #n` appended
  when another slot of the device has the same text.
- **Side effects:** None.
- **Algorithm:** Compare the slot's base label with every other slot's.
- **Usage:** Group headers and subtitles of the list; storage boxes, the selection chip and the
  details of the topology.
- **Notes:** Two identical 8 TB disks in one NAS read "8 TB HDD" and "8 TB HDD #2".
