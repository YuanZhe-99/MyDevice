# lib/shared/services/sync_merge.dart

**Split file.** The generic three-way record merge — `mergeRecords<T>`, `RecordConflict<T>`, and
`RecordMergeResult<T>` — moved to the `myapps_data` package (`lib/src/merge/sync_merge.dart`) and is
re-exported here. MyDevice's own merge logic stays.

MyDevice's signature was the **superset the package adopted**: it carries the optional
`mergeUnknownFields` callback used for model-level `extraJson` preservation. The shared
implementation is therefore behaviorally identical here, and the device merge still passes that
callback.

What this file declares itself is the app-typed half: `mergeAssignments`, and for each of the four
data files a `…MergeResult` class plus a `merge…Data` function. Each result carries its merged
list(s), its conflict list(s), and the preserved top-level `extraJson`. The sync engine carries a
result through as an opaque `state`, which is how the conflict dialogs still receive real model
objects; the module descriptors in [`data_modules.md`](../../app/data_modules.md#modules) call the
`merge…Data` functions and the `buildResolved` methods. `ServiceMergeResult.buildResolved`
disambiguates a shared record ID by runtime type, which is why one flat resolution map can serve
every module.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `RecordConflict` / `RecordMergeResult` / `mergeRecords` | re-export (`export … show`) | B | The generic engine from `myapps_data`, re-exported so existing imports keep compiling. |
| [`mergeAssignments`](#mergeassignments) | top-level function | A | MyDevice-only composite-key merge for network-device assignments. |
| `key` (nested in `mergeAssignments`) | local function | B | The composite key `networkId:deviceId`. |
| `content` (nested in `mergeAssignments`) | local function | B | `jsonEncode(a.toJson())`, the text compared against the base. |
| `DeviceMergeResult` | class | B | Result of merging `device_data.json`. |
| `DeviceMergeResult` constructor | constructor | B | Store `merged`, `conflicts` (default empty) and `extraJson` (default empty). |
| `hasConflicts` | getter (`DeviceMergeResult`) | B | `conflicts.isNotEmpty`. |
| [`buildResolved`](#devicemergeresult-buildresolved) | method (`DeviceMergeResult`) | A | Build the final `DeviceData` from the merged list plus one choice per conflict. |
| [`mergeDeviceData`](#mergedevicedata) | top-level function | A | Three-way merge of `device_data.json`. |
| `NetworkMergeResult` | class | B | Result of merging `network_data.json`: networks and assignments. |
| `NetworkMergeResult` constructor | constructor | B | Store `mergedNetworks`, `mergedAssignments`, `conflicts` and `extraJson`. |
| `hasConflicts` | getter (`NetworkMergeResult`) | B | `conflicts.isNotEmpty`; assignments never conflict. |
| [`buildResolved`](#networkmergeresult-buildresolved) | method (`NetworkMergeResult`) | A | Build the final `NetworkData`, carrying the merged assignments unchanged. |
| [`mergeNetworkData`](#mergenetworkdata) | top-level function | A | Three-way merge of `network_data.json`: networks through `mergeRecords`, assignments through `mergeAssignments`. |
| `DataSetMergeResult` | class | B | Result of merging `dataset_data.json`. |
| `DataSetMergeResult` constructor | constructor | B | Store `merged`, `conflicts` and `extraJson`. |
| `hasConflicts` | getter (`DataSetMergeResult`) | B | `conflicts.isNotEmpty`. |
| [`buildResolved`](#datasetmergeresult-buildresolved) | method (`DataSetMergeResult`) | A | Build the final `DataSetData` from the merged list plus one choice per conflict. |
| [`mergeDataSetData`](#mergedatasetdata) | top-level function | A | Three-way merge of `dataset_data.json`. |
| `ServiceMergeResult` | class | B | Result of merging `service_data.json`: service nodes and routes. |
| `ServiceMergeResult` constructor | constructor | B | Store both merged lists, both conflict lists and `extraJson`. |
| `hasConflicts` | getter (`ServiceMergeResult`) | B | True when either conflict list is non-empty. |
| `allConflicts` | getter (`ServiceMergeResult`) | B | Service conflicts followed by route conflicts, as one untyped list. |
| [`buildResolved`](#servicemergeresult-buildresolved) | method (`ServiceMergeResult`) | A | Build the final `ServiceData`, picking each resolution by runtime type. |
| [`mergeServiceData`](#mergeservicedata) | top-level function | A | Three-way merge of `service_data.json`: two `mergeRecords` passes. |

Row count (25) is seven more than `grep -c '/// Purpose:' sync_merge.dart` (18). Every function,
constructor, getter and method has its own row and its own `Purpose:` block (18). The seven extra
rows are the four result classes and the two local functions nested in `mergeAssignments`, which
carry no doc comment, and the `export … show` directive, which is not a declaration of this file but
is listed so the re-exported names can be found here. Tier A: 9 rows.

## Documentation

### `List<NetworkDevice> mergeAssignments(List<NetworkDevice> local, List<NetworkDevice> remote, List<NetworkDevice>? base)` <a id="mergeassignments"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/services/sync_merge.dart` (line 37).
- **Purpose:** Three-way merge for `NetworkDevice` assignment records, which have no `modifiedAt`.
- **Inputs:** `local`, `remote` — the two sides' assignment lists; `base` — the assignments from the
  last successful sync, or `null` when there is no base snapshot.
- **Returns:** `List<NetworkDevice>` — the merged assignments. It never reports a conflict.
- **Side effects:** None.
- **Algorithm:** Key every assignment by `networkId:deviceId` and compare `jsonEncode(toJson())`
  against the base's serialized content. For every key in the union of the three maps:
  1. Present on both sides with a base: take remote when only remote changed, otherwise local;
     either way the kept record takes unknown fields from the other side through
     `mergeUnknownFieldsFrom(…, base: b)`.
  2. Present on both sides without a base (both new): local, with remote's unknown fields.
  3. Only local, base present (deleted remotely): keep local only if it changed since the base.
     Only local, no base: keep it (new locally).
  4. Only remote, base present (deleted locally): keep remote only if it changed since the base.
     Only remote, no base: keep it (new remotely).
  5. Only in the base: drop it (deleted on both sides).
- **Usage:** Called by [`mergeNetworkData`](#mergenetworkdata).
- **Notes:** Deliberately **not** extracted to `myapps_data`. Because there is no timestamp to pick
  a winner, both-changed resolves to local; the conflict is never shown to the user. See
  [Three-Way Merge](../../../algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge)
  for the walkthrough.

### `DeviceData DeviceMergeResult.buildResolved(Map<String, Device> resolutions)` <a id="devicemergeresult-buildresolved"></a>
- **Kind:** method of `DeviceMergeResult`.
- **Source:** `lib/shared/services/sync_merge.dart` (line 126).
- **Purpose:** Turn the merge result plus the user's conflict choices into the `DeviceData` to
  write.
- **Inputs:** `resolutions` — conflict ID → the chosen `Device`.
- **Returns:** `DeviceData` with `merged` followed by one device per conflict, and the preserved
  `extraJson`.
- **Side effects:** None.
- **Algorithm:** Copy `merged`; for each conflict append `resolutions[c.id]`, or `c.localRecord`
  when the map has no entry for it.
- **Usage:** `buildDevicesModule` in [`data_modules.md`](../../app/data_modules.md#modules), with a
  map filtered to `Device` values. With no conflicts the devices module encodes
  `DeviceData(devices: r.merged, extraJson: r.extraJson)` directly instead.
- **Notes:** An unresolved conflict falls back to the local record, never to the remote one.

### `DeviceMergeResult mergeDeviceData(String localJson, String remoteJson, String? baseJson, {bool autoResolve = false})` <a id="mergedevicedata"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/services/sync_merge.dart` (line 140).
- **Purpose:** Three-way merge of the two sides' `device_data.json`.
- **Inputs:** `localJson`, `remoteJson` — the file contents; `baseJson` — the base snapshot, or
  `null`; `autoResolve` — passed to `mergeRecords`.
- **Returns:** `DeviceMergeResult`.
- **Side effects:** None.
- **Algorithm:** 1. Parse all three with `DeviceData.fromJson`. 2. Merge the top-level `extraJson`
  with `mergeUnknownJsonFields(primary: local, secondary: remote, base: base)`. 3. Run
  `mergeRecords<Device>` keyed by `id`, timed by `modifiedAt`, named by `name`, compared by
  `jsonEncode(toJson())`, with `mergeUnknownFields` calling `primary.mergeUnknownFieldsFrom`.
  4. Wrap the merged list, the conflicts and the `extraJson`.
- **Usage:** `buildDevicesModule` in [`data_modules.md`](../../app/data_modules.md#modules);
  `test/audit_fixes_test.dart` and `test/sync_unknown_fields_test.dart`.
- **Notes:** `autoResolve` comes from the sync engine, which keeps it `false` at every call site, so
  true conflicts reach the user.

### `NetworkData NetworkMergeResult.buildResolved(Map<String, Network> resolutions)` <a id="networkmergeresult-buildresolved"></a>
- **Kind:** method of `NetworkMergeResult`.
- **Source:** `lib/shared/services/sync_merge.dart` (line 213).
- **Purpose:** Turn the merge result plus the user's conflict choices into the `NetworkData` to
  write.
- **Inputs:** `resolutions` — conflict ID → the chosen `Network`.
- **Returns:** `NetworkData` with `mergedNetworks` followed by one network per conflict,
  `mergedAssignments` unchanged, and the preserved `extraJson`.
- **Side effects:** None.
- **Algorithm:** As [`DeviceMergeResult.buildResolved`](#devicemergeresult-buildresolved), plus the
  assignments.
- **Usage:** `buildNetworksModule` in [`data_modules.md`](../../app/data_modules.md#modules), both
  for a clean merge (`buildResolved(const {})`) and after the user resolves conflicts.
- **Notes:** None.

### `NetworkMergeResult mergeNetworkData(String localJson, String remoteJson, String? baseJson, {bool autoResolve = false})` <a id="mergenetworkdata"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/services/sync_merge.dart` (line 231).
- **Purpose:** Three-way merge of the two sides' `network_data.json`.
- **Inputs:** As [`mergeDeviceData`](#mergedevicedata).
- **Returns:** `NetworkMergeResult`.
- **Side effects:** None.
- **Algorithm:** Parse with `NetworkData.fromJson`; merge the top-level `extraJson`; run
  `mergeRecords<Network>` over `networks` with the same callbacks as devices; run
  [`mergeAssignments`](#mergeassignments) over `assignments`; wrap both.
- **Usage:** `buildNetworksModule` in [`data_modules.md`](../../app/data_modules.md#modules);
  `test/sync_unknown_fields_test.dart`.
- **Notes:** Only networks can conflict; assignment disagreements are settled silently by
  `mergeAssignments`.

### `DataSetData DataSetMergeResult.buildResolved(Map<String, DataSet> resolutions)` <a id="datasetmergeresult-buildresolved"></a>
- **Kind:** method of `DataSetMergeResult`.
- **Source:** `lib/shared/services/sync_merge.dart` (line 309).
- **Purpose:** Turn the merge result plus the user's conflict choices into the `DataSetData` to
  write.
- **Inputs:** `resolutions` — conflict ID → the chosen `DataSet`.
- **Returns:** `DataSetData` with `merged` followed by one dataset per conflict, and the preserved
  `extraJson`.
- **Side effects:** None.
- **Algorithm:** As [`DeviceMergeResult.buildResolved`](#devicemergeresult-buildresolved).
- **Usage:** `buildDataSetsModule` in [`data_modules.md`](../../app/data_modules.md#modules), for a
  clean merge and after conflict resolution.
- **Notes:** None.

### `DataSetMergeResult mergeDataSetData(String localJson, String remoteJson, String? baseJson, {bool autoResolve = false})` <a id="mergedatasetdata"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/services/sync_merge.dart` (line 323).
- **Purpose:** Three-way merge of the two sides' `dataset_data.json`.
- **Inputs:** As [`mergeDeviceData`](#mergedevicedata).
- **Returns:** `DataSetMergeResult`.
- **Side effects:** None.
- **Algorithm:** Parse with `DataSetData.fromJson`; merge the top-level `extraJson`; run
  `mergeRecords<DataSet>` over `datasets` with the same callbacks as devices; wrap the result.
- **Usage:** `buildDataSetsModule` in [`data_modules.md`](../../app/data_modules.md#modules).
- **Notes:** None.

### `ServiceData ServiceMergeResult.buildResolved(Map<String, dynamic> resolutions)` <a id="servicemergeresult-buildresolved"></a>
- **Kind:** method of `ServiceMergeResult`.
- **Source:** `lib/shared/services/sync_merge.dart` (line 409).
- **Purpose:** Turn the merge result plus the user's conflict choices into the `ServiceData` to
  write.
- **Inputs:** `resolutions` — conflict ID → the chosen record, a `ServiceNode` or a `ServiceRoute`.
- **Returns:** `ServiceData` with both merged lists, one record appended per conflict, and the
  preserved `extraJson`.
- **Side effects:** None.
- **Algorithm:** 1. Copy `mergedServices`; for each service conflict take `resolutions[c.id]` if it
  is a `ServiceNode`, else `c.localRecord`. 2. Copy `mergedRoutes`; for each route conflict take
  `resolutions[c.id]` if it is a `ServiceRoute`, else `c.localRecord`. 3. Wrap both with
  `extraJson`.
- **Usage:** `buildServicesModule` in [`data_modules.md`](../../app/data_modules.md#services), for a
  clean merge (`buildResolved(const {})`) and in `buildResolvedJson` after conflict resolution.
- **Notes:** The runtime-type check is what lets one flat map hold both kinds: if a service and a
  route share an ID, each list only accepts a value of its own type and otherwise keeps local.

### `ServiceMergeResult mergeServiceData(String localJson, String remoteJson, String? baseJson, {bool autoResolve = false})` <a id="mergeservicedata"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/services/sync_merge.dart` (line 435).
- **Purpose:** Three-way merge of the two sides' `service_data.json`.
- **Inputs:** As [`mergeDeviceData`](#mergedevicedata).
- **Returns:** `ServiceMergeResult`.
- **Side effects:** None.
- **Algorithm:** Parse with `ServiceData.fromJson`; merge the top-level `extraJson`; run
  `mergeRecords<ServiceNode>` over `services` and `mergeRecords<ServiceRoute>` over `routes`, each
  keyed by `id`, timed by `modifiedAt`, named by `name`, with unknown-field merging; wrap both
  results.
- **Usage:** `buildServicesModule` in [`data_modules.md`](../../app/data_modules.md#services);
  `test/service_module_test.dart`.
- **Notes:** Services and routes are merged independently; nothing here checks that a merged route's
  hops still reference services present in the merged list.

## Where the generic engine documentation lives

`packages/myapps_data/doc/en-us/functions/src/merge/sync_merge.md`.
