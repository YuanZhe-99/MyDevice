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

A single `DataSet` can span storage slots on multiple devices (multiple
`DataSetStorageLink` entries), and can span multiple slots on the same device
(multiple indices in one link's `storageIndices`).

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
})
```

- `indexMap` maps each **old** slot index to its **new** slot index after the edit.
- If `indexMap` is the identity mapping for every index `0..oldSlotCount-1` (nothing
  actually moved), the function returns immediately without touching any dataset.
- Otherwise it loads all datasets, and for every `DataSetStorageLink` whose `deviceId`
  matches, it re-maps each index in `storageIndices` through `indexMap`:
  - An index with a mapping (`indexMap[idx] != null`) is kept, remapped to its new
    position — this is the **slot removal/compaction** case: surviving slots shift
    down to fill the gap left by a removed slot, and `indexMap` reflects the new
    (compacted) positions.
  - An index with **no** mapping (removed entirely, no corresponding new slot) is
    **dropped** from `storageIndices`.
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

- [Devices](devices.md) for the `storage: List<StorageInfo>` field these links index
  into.
- [Data Formats](../data-formats.md#cross-reference-rules) — deleting a dataset deletes
  its contained storage links; deleting a device must also clean up its dataset links.
