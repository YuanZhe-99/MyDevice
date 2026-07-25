# lib/shared/services/sync_merge.dart

**Split file.** The generic three-way record merge — `mergeRecords<T>`, `RecordConflict<T>`, and
`RecordMergeResult<T>` — moved to the `myapps_data` package (`lib/src/merge/sync_merge.dart`) and is
re-exported here. MyDevice's own merge logic stays.

MyDevice's signature was the **superset the package adopted**: it carries the optional
`mergeUnknownFields` callback used for model-level `extraJson` preservation. The shared
implementation is therefore behaviorally identical here, and the device merge still passes that
callback.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`mergeAssignments(...)`](#mergeassignments) | function | A | MyDevice-only composite-key merge for network-device assignments. |
| `DeviceMergeResult` / `mergeDeviceData(...)` | class + function | A | Devices, with unknown-field preservation. |
| `NetworkMergeResult` / `mergeNetworkData(...)` | class + function | A | Networks plus their assignments. |
| `DataSetMergeResult` / `mergeDataSetData(...)` | class + function | A | Datasets. |
| `ServiceMergeResult` / `mergeServiceData(...)` | class + function | A | Service nodes and routes (two containers). |
| `RecordConflict<T>` / `RecordMergeResult<T>` / `mergeRecords<T>` | re-export | A | The generic engine, from the package. |

## Documentation

### `mergeAssignments(local, remote, base)` <a id="mergeassignments"></a>
- **Purpose:** Three-way merge for `NetworkDevice` assignment records.
- **Notes:** Deliberately **not** extracted. Assignments have no `modifiedAt`, so changes are
  detected by comparing serialized content against the base, and the key is composite
  (`networkId:deviceId`). Both-changed resolves to local, since there is no timestamp to pick a
  winner. Unknown fields are merged from the losing side.

### Per-module merge wrappers
- **Notes:** Each returns an app-typed result carrying its merged list, its conflict list(s), and
  preserved top-level `extraJson`. The sync engine carries these through as opaque `state`, which is
  how the conflict dialogs still receive real model objects. `ServiceMergeResult.buildResolved`
  disambiguates a shared record ID by runtime type, which is why one flat resolution map can serve
  every module.

## Where the generic engine documentation lives

`packages/myapps_data/doc/en-us/functions/src/merge/sync_merge.md`.
