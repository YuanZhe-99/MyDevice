# lib/features/services/services/service_storage.dart

`ServiceStorage` persists the manual service inventory (`service_data.json`): the
`ServiceNode` list and the `ServiceRoute` list described in
[`../models/service.md`](../models/service.md). It piggybacks on
[`../../devices/services/device_storage.md`](../../devices/services/device_storage.md)'s
`getAppDir()` for the actual storage directory (so it always lives alongside
`device_data.json`/`network_data.json`/`dataset_data.json`, and moves with them when the
storage location changes), and every mutating method here notifies
[`../../../shared/services/auto_sync_service.md`](../../../shared/services/auto_sync_service.md)
via `save`. See [Services and Topology](../../../../features/services-topology.md) for the
manual-inventory-only constraint this file's methods respect (no discovery, no
scanning — every write is a direct, user-initiated inventory edit), and
[Data Formats](../../../../data-formats.md#servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart)
for the exact `ServiceData` JSON shape this file reads/writes.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`_getFile`](#_getfile) | static method (private) | A | Resolve the `service_data.json` file inside the current app directory. |
| [`load`](#load) | static method | A | Load the persisted `ServiceData` (services + routes). |
| [`save`](#save) | static method | A | Persist `ServiceData` and notify the auto-sync service. |
| [`addOrUpdateService`](#addorupdateservice) | static method | A | Insert or replace a service by id. |
| [`deleteService`](#deleteservice) | static method | A | Delete a service by id and strip route hops that referenced it. |
| [`addOrUpdateRoute`](#addorupdateroute) | static method | A | Insert or replace a route by id. |
| [`deleteRoute`](#deleteroute) | static method | A | Delete a route by id. |
| [`removeDeviceReferences`](#removedevicereferences) | static method | A | Remove every service/route reference to a deleted or retired device. |

Row count (8) matches `grep -c 'Purpose:' service_storage.dart` (8) exactly.

## Documentation

### `static Future<File> _getFile()` <a id="_getfile"></a>
- **Kind:** private static method.
- **Source:** `lib/features/services/services/service_storage.dart` (line 16).
- **Purpose:** Resolve the `service_data.json` file inside the app's current data
  directory (respecting any custom storage path configured via
  [`DeviceStorage.setStoragePath`](../../devices/services/device_storage.md#setstoragepath)).
- **Inputs:** None.
- **Returns:** `Future<File>`.
- **Side effects:** None beyond `DeviceStorage.getAppDir()`'s directory-creation side effect.
- **Algorithm:** `File('${(await DeviceStorage.getAppDir()).path}/$dataFileName')`, where
  `dataFileName` is the constant `'service_data.json'`.
- **Usage:** Called internally by [`load`](#load) and [`save`](#save) only; not exposed
  outside this class.
- **Notes:** Unlike `DeviceStorage`'s own equivalent (`_getFile`, which is also
  private-per-file), this file has no separate "default directory" variant — it always
  resolves against whatever `DeviceStorage.getAppDir()` currently reports.

### `static Future<ServiceData> load()` <a id="load"></a>
- **Kind:** static method.
- **Source:** `lib/features/services/services/service_storage.dart` (line 26).
- **Purpose:** Load the persisted service inventory from `service_data.json`.
- **Inputs:** None.
- **Returns:** `Future<ServiceData>` — `const ServiceData()` (empty) if the file is absent
  or its contents are blank.
- **Side effects:** Reads `service_data.json`.
- **Algorithm:** 1. Resolve the file via [`_getFile`](#_getfile). 2. If it doesn't exist,
  return an empty `ServiceData`. 3. Read its contents; if the trimmed text is empty, also
  return an empty `ServiceData`. 4. Otherwise `jsonDecode` and parse via
  [`ServiceData.fromJson`](../models/service.md#servicedata-fromjson).
- **Usage:**
  ```dart
  final serviceData = await ServiceStorage.load();
  final deviceData = await DeviceStorage.load();
  final networkData = await NetworkStorage.load();
  ```
  (from `service_list_page.dart`'s `_load`; also read by `service_route_edit_page.dart`,
  `import_export_service.dart`'s Markdown/backup export, and
  [`../../../shared/services/local_api_server.md`](../../../shared/services/local_api_server.md)'s
  read-only `/service/*` endpoints)
- **Notes:** None.

### `static Future<void> save(ServiceData data)` <a id="save"></a>
- **Kind:** static method.
- **Source:** `lib/features/services/services/service_storage.dart` (line 40).
- **Purpose:** Persist the full service inventory (services and routes together) to
  `service_data.json` and notify the auto-sync service that local data changed.
- **Inputs:** `data` — the complete `ServiceData` to write; every mutator in this class
  calls this with a freshly reconstructed `ServiceData`, never a partial update.
- **Returns:** `Future<void>`.
- **Side effects:** Writes `service_data.json` (pretty-printed, non-atomic direct write);
  calls `AutoSyncService.instance.notifySaved()` (see
  [`../../../shared/services/auto_sync_service.md`](../../../shared/services/auto_sync_service.md)).
- **Algorithm:** JSON-encode `data.toJson()` with a two-space indent, write it, then
  notify auto-sync.
- **Usage:** Called by every other mutating method in this file
  ([`addOrUpdateService`](#addorupdateservice), [`deleteService`](#deleteservice),
  [`addOrUpdateRoute`](#addorupdateroute), [`deleteRoute`](#deleteroute),
  [`removeDeviceReferences`](#removedevicereferences)); not called directly from outside
  this class.
- **Notes:** Because every method here always loads the full list first and calls `save`
  with a reconstructed `ServiceData`, two concurrent mutations (e.g. from two isolates)
  could race and clobber each other — matching the same read-modify-write caveat noted on
  [`DeviceStorage.writeConfig`](../../devices/services/device_storage.md#writeconfig), but
  this app's storage layer is only ever driven from the single-threaded UI/local API path.

### `static Future<void> addOrUpdateService(ServiceNode service)` <a id="addorupdateservice"></a>
- **Kind:** static method.
- **Source:** `lib/features/services/services/service_storage.dart` (line 52).
- **Purpose:** Insert a new service or replace an existing one, matched by `id`.
- **Inputs:** `service`.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `service_data.json` via [`save`](#save); routes are carried
  through unchanged.
- **Algorithm:** 1. Load the current `ServiceData`. 2. Copy the services list; find the
  index of an existing service with the same `id`. 3. Replace it if found, else append.
  4. Save a new `ServiceData` with the updated services list and the routes/`extraJson`
  untouched.
- **Usage:**
  ```dart
  await ServiceStorage.addOrUpdateService(service);
  ```
  (from `service_edit_page.dart`'s save handler)
- **Notes:** Unlike [`DeviceStorage.addOrUpdate`](../../devices/services/device_storage.md#addorupdate),
  this method performs no cascade cleanup of its own — a service edit never needs to
  remove cross-module references (only deletion or the device leaving service does, see
  [`deleteService`](#deleteservice) and
  [`removeDeviceReferences`](#removedevicereferences)).

### `static Future<void> deleteService(String id)` <a id="deleteservice"></a>
- **Kind:** static method.
- **Source:** `lib/features/services/services/service_storage.dart` (line 75).
- **Purpose:** Delete a service by id and strip any route hop that referenced it, so a
  deleted service can't dangle as a hop's `serviceId`.
- **Inputs:** `id`.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `service_data.json` via [`save`](#save).
- **Algorithm:** 1. Load the current `ServiceData`. 2. Filter the service out of the
  services list. 3. For every route, drop any hop whose `serviceId == id` (via
  `route.copyWith(hops: ...)`) — routes themselves are kept even if this empties their
  hop list; only hops referencing the deleted service are removed. 4. Save the updated
  services and routes.
- **Usage:**
  ```dart
  await ServiceStorage.deleteService(service.id);
  ```
  (from `service_edit_page.dart`'s delete-confirmation flow)
- **Notes:** This method does **not** delete routes whose `sourceServiceId == id` (a
  route sourced from the deleted service is left in place with its now-invalid
  `sourceServiceId`) — only hop references are cleaned up here. Compare
  [`removeDeviceReferences`](#removedevicereferences), which does drop routes whose
  source service was removed as part of a whole-device cleanup.

### `static Future<void> addOrUpdateRoute(ServiceRoute route)` <a id="addorupdateroute"></a>
- **Kind:** static method.
- **Source:** `lib/features/services/services/service_storage.dart` (line 100).
- **Purpose:** Insert a new route or replace an existing one, matched by `id`.
- **Inputs:** `route`.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `service_data.json` via [`save`](#save); services are
  carried through unchanged.
- **Algorithm:** Same insert-or-replace-by-`id` shape as
  [`addOrUpdateService`](#addorupdateservice), applied to the routes list instead.
- **Usage:**
  ```dart
  await ServiceStorage.addOrUpdateRoute(route);
  ```
  (from both `service_list_page.dart`'s quick access-route flow and
  `service_route_edit_page.dart`'s advanced route editor save handler — see
  [Services and Topology](../../../../features/services-topology.md#quick-access-route-creation-vs-the-advanced-editor)
  for the two flows)
- **Notes:** None.

### `static Future<void> deleteRoute(String id)` <a id="deleteroute"></a>
- **Kind:** static method.
- **Source:** `lib/features/services/services/service_storage.dart` (line 123).
- **Purpose:** Delete a route by id.
- **Inputs:** `id`.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `service_data.json` via [`save`](#save).
- **Algorithm:** Filter the route out of the loaded routes list, then save with services
  unchanged.
- **Usage:**
  ```dart
  await ServiceStorage.deleteRoute(route.id);
  ```
  (from `service_route_edit_page.dart`'s delete-confirmation flow)
- **Notes:** Unlike [`deleteService`](#deleteservice), this performs no further cleanup —
  a route has no dependents within this model to clean up.

### `static Future<void> removeDeviceReferences(String deviceId)` <a id="removedevicereferences"></a>
- **Kind:** static method.
- **Source:** `lib/features/services/services/service_storage.dart` (line 139).
- **Purpose:** Remove every service and route reference to a device that was deleted or
  left service (retired/sold) — the service-layer half of
  [`DeviceStorage`](../../devices/services/device_storage.md)'s cross-module cascade-delete
  rule.
- **Inputs:** `deviceId`.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `service_data.json` via [`save`](#save), but **only** if
  something actually changed (see Algorithm step 4).
- **Algorithm:** 1. Load the current `ServiceData`. 2. Compute `removedServiceIds` — the
  ids of every service whose `deviceId == deviceId`. 3. Build the new services list by
  dropping those services, and the new routes list by dropping any route whose
  `sourceServiceId` is in `removedServiceIds`, then (for the routes that remain) filtering
  out any hop whose `deviceId == deviceId` or whose `serviceId` is in
  `removedServiceIds`. 4. Only call `save` if the services list length changed, the
  routes list length changed, or any surviving route's hop count shrank (checked by
  comparing each new route's hop count against the original route with the same `id`) —
  otherwise this is a no-op with no write.
- **Usage:**
  ```dart
  await ServiceStorage.removeDeviceReferences(id);
  ```
  (from [`DeviceStorage._removeDeviceReferences`](../../devices/services/device_storage.md#_removedevicereferences),
  called unconditionally whenever a device is deleted or edited out of service)
- **Notes:** This is the only method in this file with a conditional save — every other
  mutator here always writes. The three-part "did anything change" check (services
  count, routes count, or any route's hop count) exists because dropping *services* and
  dropping *hops from a route that survives* are both changes worth persisting, but
  neither alone is sufficient to detect the other.
