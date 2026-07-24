# lib/shared/services/sync_merge.dart

Pure, network-free three-way merge logic shared by all four synced data modules (devices,
networks, datasets, services). `webdav_service.dart` (see [`webdav_service.md`](webdav_service.md))
calls `mergeDeviceData`/`mergeNetworkData`/`mergeDataSetData`/`mergeServiceData` per data file during
`_syncLocked`, using the local file, the downloaded remote file, and the last-synced `.sync_base/`
snapshot. The generic engine is `mergeRecords<T>`, used by all four `id`+`modifiedAt`-keyed record
types; `NetworkDevice` assignments (which have no `id`/`modifiedAt`) use the separate
content-comparison based `mergeAssignments`. See the "WebDAV Sync Rules" section of
`../../../AGENTS.md` and `../../../sync.md` for how this fits into the overall sync flow, including
the discriminated remote-download outcome (only HTTP 404 counts as "missing") that determines what
gets passed in as `remote`/`base` here.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`RecordConflict`](#recordconflict-new) | constructor | A | Create a record conflict instance (same ID, both sides changed since base). |
| [`RecordMergeResult`](#recordmergeresult-new) | constructor | A | Create a record merge result instance (merged list plus conflicts). |
| [`mergeRecords`](#mergerecords) | top-level function | A | Three-way merge for a list of `id`+`modifiedAt`-keyed records. |
| [`mergeAssignments`](#mergeassignments) | top-level function | A | Three-way merge for `NetworkDevice` assignments (no `modifiedAt`; content-comparison based). |
| [`DeviceMergeResult`](#devicemergeresult-new) | constructor | A | Create a device merge result instance. |
| `DeviceMergeResult.hasConflicts` | getter | B | Return whether the device merge has unresolved conflicts. |
| [`DeviceMergeResult.buildResolved`](#devicemergeresult-buildresolved) | method | A | Apply user conflict resolutions and rebuild a complete `DeviceData`. |
| [`mergeDeviceData`](#mergedevicedata) | top-level function | A | Parse, merge, and re-serialize device JSON using `mergeRecords`. |
| [`NetworkMergeResult`](#networkmergeresult-new) | constructor | A | Create a network merge result instance. |
| `NetworkMergeResult.hasConflicts` | getter | B | Return whether the network merge has unresolved conflicts. |
| [`NetworkMergeResult.buildResolved`](#networkmergeresult-buildresolved) | method | A | Apply user conflict resolutions and rebuild a complete `NetworkData`. |
| [`mergeNetworkData`](#mergenetworkdata) | top-level function | A | Parse, merge, and re-serialize network JSON (networks + assignments). |
| [`DataSetMergeResult`](#datasetmergeresult-new) | constructor | A | Create a dataset merge result instance. |
| `DataSetMergeResult.hasConflicts` | getter | B | Return whether the dataset merge has unresolved conflicts. |
| [`DataSetMergeResult.buildResolved`](#datasetmergeresult-buildresolved) | method | A | Apply user conflict resolutions and rebuild a complete `DataSetData`. |
| [`mergeDataSetData`](#mergedatasetdata) | top-level function | A | Parse, merge, and re-serialize dataset JSON using `mergeRecords`. |
| [`ServiceMergeResult`](#servicemergeresult-new) | constructor | A | Create a service merge result instance (services + routes). |
| `ServiceMergeResult.hasConflicts` | getter | B | Return whether either the service or route merge has unresolved conflicts. |
| `ServiceMergeResult.allConflicts` | getter | B | Return the combined service and route conflict list. |
| [`ServiceMergeResult.buildResolved`](#servicemergeresult-buildresolved) | method | A | Apply user conflict resolutions and rebuild a complete `ServiceData`. |
| [`mergeServiceData`](#mergeservicedata) | top-level function | A | Parse, merge, and re-serialize service JSON (services + routes). |

Row count (21) matches `grep -c 'Purpose:' sync_merge.dart` (21) exactly.

## Documentation

### `const RecordConflict({required this.id, required this.localRecord, required this.remoteRecord, required this.displayName})` <a id="recordconflict-new"></a>
- **Kind:** constructor of `RecordConflict<T>`
- **Source:** `lib/shared/services/sync_merge.dart` (approx. line 23)
- **Purpose:** Represent a single record-level conflict: the same ID changed on both local and
  remote since the last synced base.
- **Inputs:** `id`, `localRecord`, `remoteRecord`, `displayName` (for the conflict UI).
- **Returns:** A new `RecordConflict<T>` instance.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:**
  ```dart
  conflicts.add(
    RecordConflict(
      id: id,
      localRecord: preserveUnknown(l, r, b),
      remoteRecord: preserveUnknown(r, l, b),
      displayName: getDisplayName(l),
    ),
  );
  ```
  (from `mergeRecords`, this file)
- **Notes:** `T` is generic — `Device`, `Network`, `DataSet`, `ServiceNode`, or `ServiceRoute`
  depending on which merge produced it.

### `const RecordMergeResult({required this.merged, this.conflicts = const []})` <a id="recordmergeresult-new"></a>
- **Kind:** constructor of `RecordMergeResult<T>`
- **Source:** `lib/shared/services/sync_merge.dart` (approx. line 41)
- **Purpose:** Hold the output of merging a list of records: the merged (conflict-free) list plus
  any per-record conflicts requiring user resolution.
- **Inputs:** `merged`; optional `conflicts` (defaults to empty).
- **Returns:** A new `RecordMergeResult<T>` instance.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Returned by [`mergeRecords`](#mergerecords) and consumed by
  `mergeDeviceData`/`mergeNetworkData`/`mergeDataSetData`/`mergeServiceData`.
- **Notes:** None.

### `RecordMergeResult<T> mergeRecords<T>({required List<T> local, required List<T> remote, required List<T>? base, required String Function(T) getId, required DateTime Function(T) getModifiedAt, required String Function(T) getDisplayName, T Function(T primary, T secondary, T? base)? mergeUnknownFields, bool autoResolve = false, String Function(T)? serialize})` <a id="mergerecords"></a>
- **Kind:** top-level generic function
- **Source:** `lib/shared/services/sync_merge.dart` (approx. line 61)
- **Purpose:** Three-way merge a list of `id`-keyed, `modifiedAt`-timestamped records against a
  last-synced base snapshot. This is the shared engine behind `mergeDeviceData`,
  `mergeNetworkData`'s network list, `mergeDataSetData`, and `mergeServiceData`'s services and
  routes.
- **Inputs:** `local`/`remote`/`base` (nullable — null base means "no prior sync", i.e. first sync
  or a record added on both sides with the same ID); `getId`/`getModifiedAt`/`getDisplayName`
  accessors; optional `mergeUnknownFields` (preserves fields the current model doesn't know about,
  via the `extraJson` pattern in `../../../AGENTS.md`); `autoResolve` (last-writer-wins on true
  conflicts instead of surfacing them — production callers always pass `false`); optional
  `serialize` (enables identical-content conflict suppression).
- **Returns:** `RecordMergeResult<T>` — the merged list plus any unresolved conflicts.
- **Side effects:** None (pure function over its inputs).
- **Algorithm:** For each ID present in the union of local/remote/base:
  1. **Both sides have the record, and a base exists:** compare each side's `modifiedAt` against
     the base's to determine `localChanged`/`remoteChanged`.
     - Both changed: if `serialize` is provided and `serialize(local) == serialize(remote)`, treat
       it as no real conflict (identical content merges silently, even if both sides bumped
       `modifiedAt` — e.g. after a stale base from an earlier failed upload). Else if
       `autoResolve`, pick whichever side has the later `modifiedAt` (last-writer-wins). Else
       record a `RecordConflict`.
     - Only local changed: use local. Only remote changed: use remote. Neither changed: use local
       (arbitrary, since content should match).
     - In every non-conflict case, unknown JSON fields are preserved via `mergeUnknownFields`
       (primary result, secondary side, base) so a field this app version doesn't know about
       written by a newer version is not silently dropped.
  2. **Both sides have the record, no base:** first sync, or both sides independently created the
     same ID — pick the side with the later `modifiedAt` as primary, preserving the other's unknown
     fields.
  3. **Only local has the record:** if a base exists and local changed since base, keep it
     (modified locally after the remote deleted it); if base exists and local did not change, drop
     it (deleted remotely, unmodified locally); if no base, it's new locally — include it.
  4. **Only remote has the record:** symmetric to case 3.
  5. **Neither side has the record** (both null, was in base): deleted on both sides — exclude.
- **Usage:**
  ```dart
  final result = mergeRecords<Device>(
    local: local.devices,
    remote: remote.devices,
    base: base?.devices,
    getId: (d) => d.id,
    getModifiedAt: (d) => d.modifiedAt,
    getDisplayName: (d) => d.name,
    mergeUnknownFields: (primary, secondary, base) =>
        primary.mergeUnknownFieldsFrom(secondary, base: base),
    autoResolve: autoResolve,
    serialize: (x) => jsonEncode(x.toJson()),
  );
  ```
  (from `mergeDeviceData`, this file; also called directly in
  `test/sync_unknown_fields_test.dart`)
- **Notes:** Every production caller (manual sync and auto-sync) passes `autoResolve: false`, so
  true two-sided conflicts always surface for manual resolution rather than being silently resolved
  — see the WebDAV Sync Rules in `../../../AGENTS.md`. The identical-serialized-content check
  matters because a sync interrupted after a successful remote upload but before the local base
  snapshot was saved can otherwise manufacture a spurious conflict on the next sync.

### `List<NetworkDevice> mergeAssignments(List<NetworkDevice> local, List<NetworkDevice> remote, List<NetworkDevice>? base)` <a id="mergeassignments"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/services/sync_merge.dart` (approx. line 163)
- **Purpose:** Three-way merge network-device assignments, which have no `id` or `modifiedAt` and
  so cannot use `mergeRecords`.
- **Inputs:** `local`, `remote`, `base` (nullable).
- **Returns:** `List<NetworkDevice>` — merged assignment list (conflicts are always auto-resolved,
  never surfaced — see Notes).
- **Side effects:** None (pure function).
- **Algorithm:** Identity is the composite key `'${networkId}:${deviceId}'`; change detection
  compares each side's `jsonEncode(a.toJson())` against the base's serialized content for that key
  (there is no timestamp to compare). For each key in the union of local/remote/base keys:
  1. Both sides present, base exists: if only remote changed, use remote merged with local's
     unknown fields; otherwise (both changed, only local changed, or neither changed) use local
     merged with remote's unknown fields — local wins ties/conflicts since there is no timestamp to
     pick a winner.
  2. Both sides present, no base: both new — use local (merged with remote's unknown fields).
  3. Only local present: if base exists and local's content changed since base, keep it (modified
     locally after remote deleted); if base exists and unchanged, drop it; if no base, it's new —
     keep it.
  4. Only remote present: symmetric to case 3.
- **Usage:**
  ```dart
  final assignmentResult = mergeAssignments(
    local.assignments,
    remote.assignments,
    base?.assignments,
  );
  ```
  (from [`mergeNetworkData`](#mergenetworkdata), this file)
- **Notes:** Conflicts are auto-resolved to local because there is no `modifiedAt` to break a tie
  fairly — this is the one place in the sync engine that does not surface a `RecordConflict` to the
  user, matching the "merge `NetworkDevice` assignments by composite key and content comparison"
  rule in `../../../AGENTS.md`.

### `const DeviceMergeResult({required this.merged, this.conflicts = const [], this.extraJson = const {}})` <a id="devicemergeresult-new"></a>
- **Kind:** constructor of `DeviceMergeResult`
- **Source:** `lib/shared/services/sync_merge.dart` (approx. line 234)
- **Purpose:** Hold the merged device list, any conflicts, and merged unknown top-level JSON
  fields produced by [`mergeDeviceData`](#mergedevicedata).
- **Inputs:** `merged`; optional `conflicts`, `extraJson`.
- **Returns:** A new `DeviceMergeResult` instance.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Returned by [`mergeDeviceData`](#mergedevicedata).
- **Notes:** None.

### `DeviceData buildResolved(Map<String, Device> resolutions)` <a id="devicemergeresult-buildresolved"></a>
- **Kind:** method of `DeviceMergeResult`
- **Source:** `lib/shared/services/sync_merge.dart` (approx. line 252)
- **Purpose:** Apply the user's chosen resolution for each conflicting device and rebuild a
  complete `DeviceData` ready to write and upload.
- **Inputs:** `resolutions` — map from conflict `id` to the chosen `Device`.
- **Returns:** `DeviceData` containing `merged` plus one record per conflict (the resolution, or
  the local record if a conflict's `id` is missing from `resolutions`).
- **Side effects:** None.
- **Algorithm:** Start from `merged`; for each conflict, append `resolutions[c.id]` if present,
  else `c.localRecord`.
- **Usage:**
  ```dart
  final mergedData = pending.deviceMerge!.buildResolved(deviceResolutions);
  ```
  (from `WebDAVService.finalizePendingSync`, `lib/shared/services/webdav_service.dart`)
- **Notes:** Falling back to `c.localRecord` means an incomplete resolutions map keeps local data
  rather than silently dropping the record.

### `DeviceMergeResult mergeDeviceData(String localJson, String remoteJson, String? baseJson, {bool autoResolve = false})` <a id="mergedevicedata"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/services/sync_merge.dart` (approx. line 266)
- **Purpose:** Parse local/remote/base device JSON, three-way merge the device list via
  [`mergeRecords`](#mergerecords), and merge unknown top-level JSON fields.
- **Inputs:** `localJson`, `remoteJson` (raw file contents); `baseJson` (nullable — last-synced
  snapshot); `autoResolve`.
- **Returns:** `DeviceMergeResult`.
- **Side effects:** None (pure; throws `FormatException`/type errors on invalid JSON, which
  callers in `webdav_service.dart` catch per-file).
- **Algorithm:** 1. Parse all three JSON strings via `DeviceData.fromJson`. 2. Merge unknown
  top-level fields with `mergeUnknownJsonFields`. 3. Call `mergeRecords<Device>` with `getId: (d) =>
  d.id`, `getModifiedAt: (d) => d.modifiedAt`, `getDisplayName: (d) => d.name`,
  `mergeUnknownFields` delegating to `Device.mergeUnknownFieldsFrom`, and `serialize` via
  `jsonEncode(x.toJson())`. 4. Wrap the result in `DeviceMergeResult`.
- **Usage:**
  ```dart
  final result = mergeDeviceData(local, remote, base, autoResolve: true);
  final mergedJson = DeviceData(
    devices: result.merged,
    extraJson: result.extraJson,
  ).toJson();
  ```
  (from `test/sync_unknown_fields_test.dart`; production usage in
  `WebDAVService._syncLocked`, `lib/shared/services/webdav_service.dart`, always with
  `autoResolve: false`)
- **Notes:** None.

### `const NetworkMergeResult({required this.mergedNetworks, required this.mergedAssignments, this.conflicts = const [], this.extraJson = const {}})` <a id="networkmergeresult-new"></a>
- **Kind:** constructor of `NetworkMergeResult`
- **Source:** `lib/shared/services/sync_merge.dart` (approx. line 320)
- **Purpose:** Hold the merged network list, merged assignments, network conflicts, and merged
  unknown top-level JSON fields produced by [`mergeNetworkData`](#mergenetworkdata).
- **Inputs:** `mergedNetworks`, `mergedAssignments`; optional `conflicts`, `extraJson`.
- **Returns:** A new `NetworkMergeResult` instance.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Returned by [`mergeNetworkData`](#mergenetworkdata).
- **Notes:** `mergedAssignments` never contributes conflicts — see
  [`mergeAssignments`](#mergeassignments).

### `NetworkData buildResolved(Map<String, Network> resolutions)` <a id="networkmergeresult-buildresolved"></a>
- **Kind:** method of `NetworkMergeResult`
- **Source:** `lib/shared/services/sync_merge.dart` (approx. line 339)
- **Purpose:** Apply the user's chosen resolution for each conflicting network and rebuild a
  complete `NetworkData` (networks + assignments) ready to write and upload.
- **Inputs:** `resolutions` — map from conflict `id` to the chosen `Network`.
- **Returns:** `NetworkData` with `mergedNetworks` plus one record per conflict, and
  `mergedAssignments` unchanged.
- **Side effects:** None.
- **Algorithm:** Same pattern as
  [`DeviceMergeResult.buildResolved`](#devicemergeresult-buildresolved): start from
  `mergedNetworks`, append the chosen or fallback-to-local record for each conflict.
- **Usage:**
  ```dart
  final mergedData = pending.networkMerge!.buildResolved(networkResolutions);
  ```
  (from `WebDAVService.finalizePendingSync`, `lib/shared/services/webdav_service.dart`)
- **Notes:** None.

### `NetworkMergeResult mergeNetworkData(String localJson, String remoteJson, String? baseJson, {bool autoResolve = false})` <a id="mergenetworkdata"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/services/sync_merge.dart` (approx. line 357)
- **Purpose:** Parse local/remote/base network JSON, three-way merge the network list via
  [`mergeRecords`](#mergerecords) and the assignment list via
  [`mergeAssignments`](#mergeassignments), and merge unknown top-level JSON fields.
- **Inputs:** `localJson`, `remoteJson`, `baseJson` (nullable), `autoResolve`.
- **Returns:** `NetworkMergeResult`.
- **Side effects:** None (pure; throws on invalid JSON).
- **Algorithm:** 1. Parse all three via `NetworkData.fromJson`. 2. Merge unknown top-level fields.
  3. `mergeRecords<Network>` for the network list (same shape as
  [`mergeDeviceData`](#mergedevicedata)). 4. `mergeAssignments` for the `NetworkDevice` list
  (separately, since it has no `modifiedAt`). 5. Combine into `NetworkMergeResult`.
- **Usage:** Called from `WebDAVService._syncLocked` for `network_data.json`, mirroring
  [`mergeDeviceData`](#mergedevicedata)'s call site.
- **Notes:** None.

### `const DataSetMergeResult({required this.merged, this.conflicts = const [], this.extraJson = const {}})` <a id="datasetmergeresult-new"></a>
- **Kind:** constructor of `DataSetMergeResult`
- **Source:** `lib/shared/services/sync_merge.dart` (approx. line 417)
- **Purpose:** Hold the merged dataset list, any conflicts, and merged unknown top-level JSON
  fields produced by [`mergeDataSetData`](#mergedatasetdata).
- **Inputs:** `merged`; optional `conflicts`, `extraJson`.
- **Returns:** A new `DataSetMergeResult` instance.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Returned by [`mergeDataSetData`](#mergedatasetdata).
- **Notes:** None.

### `DataSetData buildResolved(Map<String, DataSet> resolutions)` <a id="datasetmergeresult-buildresolved"></a>
- **Kind:** method of `DataSetMergeResult`
- **Source:** `lib/shared/services/sync_merge.dart` (approx. line 435)
- **Purpose:** Apply the user's chosen resolution for each conflicting dataset and rebuild a
  complete `DataSetData` ready to write and upload.
- **Inputs:** `resolutions` — map from conflict `id` to the chosen `DataSet`.
- **Returns:** `DataSetData` with `merged` plus one record per conflict.
- **Side effects:** None.
- **Algorithm:** Same pattern as [`DeviceMergeResult.buildResolved`](#devicemergeresult-buildresolved).
- **Usage:**
  ```dart
  final mergedData = pending.dataSetMerge!.buildResolved(dataSetResolutions);
  ```
  (from `WebDAVService.finalizePendingSync`, `lib/shared/services/webdav_service.dart`)
- **Notes:** None.

### `DataSetMergeResult mergeDataSetData(String localJson, String remoteJson, String? baseJson, {bool autoResolve = false})` <a id="mergedatasetdata"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/services/sync_merge.dart` (approx. line 449)
- **Purpose:** Parse local/remote/base dataset JSON, three-way merge the dataset list via
  [`mergeRecords`](#mergerecords), and merge unknown top-level JSON fields.
- **Inputs:** `localJson`, `remoteJson`, `baseJson` (nullable), `autoResolve`.
- **Returns:** `DataSetMergeResult`.
- **Side effects:** None (pure; throws on invalid JSON).
- **Algorithm:** Same shape as [`mergeDeviceData`](#mergedevicedata), parsing via
  `DataSetData.fromJson` and keying `mergeRecords<DataSet>` by `id`/`modifiedAt`/`name`.
- **Usage:** Called from `WebDAVService._syncLocked` for `dataset_data.json`.
- **Notes:** None.

### `const ServiceMergeResult({required this.mergedServices, required this.mergedRoutes, this.serviceConflicts = const [], this.routeConflicts = const [], this.extraJson = const {}})` <a id="servicemergeresult-new"></a>
- **Kind:** constructor of `ServiceMergeResult`
- **Source:** `lib/shared/services/sync_merge.dart` (approx. line 504)
- **Purpose:** Hold the merged service and route lists, their separate conflict lists, and merged
  unknown top-level JSON fields produced by [`mergeServiceData`](#mergeservicedata).
- **Inputs:** `mergedServices`, `mergedRoutes`; optional `serviceConflicts`, `routeConflicts`,
  `extraJson`.
- **Returns:** A new `ServiceMergeResult` instance.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Returned by [`mergeServiceData`](#mergeservicedata).
- **Notes:** Services and routes are merged independently (each via its own `mergeRecords` call),
  so conflicts are tracked in two separate lists rather than one.

### `ServiceData buildResolved(Map<String, dynamic> resolutions)` <a id="servicemergeresult-buildresolved"></a>
- **Kind:** method of `ServiceMergeResult`
- **Source:** `lib/shared/services/sync_merge.dart` (approx. line 535)
- **Purpose:** Apply the user's chosen resolutions for both conflicting services and conflicting
  routes and rebuild a complete `ServiceData` ready to write and upload.
- **Inputs:** `resolutions` — a single map keyed by conflict `id`, holding either a `ServiceNode` or
  a `ServiceRoute` value depending on which conflict list the id came from.
- **Returns:** `ServiceData` with `mergedServices`/`mergedRoutes` plus one record per conflict.
- **Side effects:** None.
- **Algorithm:** 1. Build `services` from `mergedServices` plus, for each service conflict, the
  resolution if it is a `ServiceNode` (else fall back to `c.localRecord`). 2. Build `routes`
  symmetrically from `mergedRoutes` and `routeConflicts`, type-checking for `ServiceRoute`.
- **Usage:**
  ```dart
  final mergedData = pending.serviceMerge!.buildResolved(resolutions);
  ```
  (from `WebDAVService.finalizePendingSync`, `lib/shared/services/webdav_service.dart` — note this
  is the one `buildResolved` call that passes the shared `resolutions` map directly, since it holds
  both service and route resolutions together)
- **Notes:** Because `resolutions` is untyped (`Map<String, dynamic>`), the `is ServiceNode`/`is
  ServiceRoute` checks are what keep a mismatched resolution from being applied to the wrong list.

### `ServiceMergeResult mergeServiceData(String localJson, String remoteJson, String? baseJson, {bool autoResolve = false})` <a id="mergeservicedata"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/services/sync_merge.dart` (approx. line 561)
- **Purpose:** Parse local/remote/base service JSON, three-way merge the service list and the
  route list independently via [`mergeRecords`](#mergerecords), and merge unknown top-level JSON
  fields.
- **Inputs:** `localJson`, `remoteJson`, `baseJson` (nullable), `autoResolve`.
- **Returns:** `ServiceMergeResult`.
- **Side effects:** None (pure; throws on invalid JSON).
- **Algorithm:** 1. Parse all three via `ServiceData.fromJson`. 2. Merge unknown top-level fields.
  3. `mergeRecords<ServiceNode>` keyed by `id`/`modifiedAt`/`name` for services. 4.
  `mergeRecords<ServiceRoute>` keyed by `id`/`modifiedAt`/`name` for routes (a separate call, since
  services and routes are independent record sets). 5. Combine into `ServiceMergeResult`.
- **Usage:** Called from `WebDAVService._syncLocked` for `service_data.json`.
- **Notes:** Endpoints and route hops are nested inside `ServiceNode`/`ServiceRoute` and so follow
  their parent record through this merge rather than being merged independently, per
  `../../../AGENTS.md`.
