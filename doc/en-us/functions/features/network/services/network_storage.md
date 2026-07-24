# lib/features/network/services/network_storage.dart

`NetworkStorage` persists the `network_data.json` file (both `Network` definitions and
`NetworkDevice` assignments) alongside the app's other feature storages. It resolves its file
location through `DeviceStorage.getAppDir()` (`../../../devices/services/device_storage.md`), the
app's single source of truth for the data directory, and notifies
[`AutoSyncService`](../../../shared/services/auto_sync_service.md) after every write so a
background sync picks up the change. See [Networks](../../../../features/networks.md) for the
model shapes this file reads/writes, and
[Data Formats](../../../../data-formats.md#network--networkdevice-libfeaturesnetworkmodelsnetworkdart)
for the exact persisted JSON shape.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`_getFile`](#getfile) | static method (private) | A | Resolve the `network_data.json` file inside the app directory. |
| [`load`](#load) | static method | A | Load the persisted `NetworkData` (networks + assignments). |
| [`save`](#save) | static method | A | Persist `NetworkData` and notify the auto-sync service. |
| [`addOrUpdateNetwork`](#addorupdatenetwork) | static method | A | Insert or replace a network by id. |
| [`deleteNetwork`](#deletenetwork) | static method | A | Delete a network and every assignment referencing it. |
| [`setAssignment`](#setassignment) | static method | A | Insert or replace a device's assignment to a network. |
| [`removeAssignment`](#removeassignment) | static method | A | Remove one device's assignment from a network. |

Row count (7) matches `grep -c 'Purpose:' network_storage.dart` (7) exactly.

## Documentation

### `static Future<File> _getFile()` <a id="getfile"></a>
- **Kind:** private static method.
- **Source:** `lib/features/network/services/network_storage.dart` (line 16).
- **Purpose:** Resolve the `network_data.json` file inside the current app directory.
- **Inputs:** None.
- **Returns:** `Future<File>`.
- **Side effects:** None beyond `DeviceStorage.getAppDir()`'s directory-creation side effect.
- **Algorithm:** `File('${(await DeviceStorage.getAppDir()).path}/network_data.json')`.
- **Usage:** Called by [`load`](#load) and [`save`](#save).
- **Notes:** Delegating to `DeviceStorage.getAppDir()` (rather than resolving its own directory)
  is what keeps `network_data.json` living alongside `device_data.json` even after the user changes
  the storage location in Settings.

### `static Future<NetworkData> load()` <a id="load"></a>
- **Kind:** static method.
- **Source:** `lib/features/network/services/network_storage.dart` (line 26).
- **Purpose:** Load the persisted network dataset from `network_data.json`.
- **Inputs:** None.
- **Returns:** `Future<NetworkData>` — `const NetworkData()` (empty) if the file is absent or empty.
- **Side effects:** Reads `network_data.json`.
- **Algorithm:** Existence/empty-content checks, then `NetworkData.fromJson(jsonDecode(...))` (see
  [`../models/network.md#networkdata-fromjson`](../models/network.md)).
- **Usage:**
  ```dart
  final data = await NetworkStorage.load();
  ```
  (from [`network_list_page.md`](../views/network_list_page.md) and
  [`network_detail_page.md`](../views/network_detail_page.md), every time the page (re)loads)
- **Notes:** None.

### `static Future<void> save(NetworkData data)` <a id="save"></a>
- **Kind:** static method.
- **Source:** `lib/features/network/services/network_storage.dart` (line 40).
- **Purpose:** Persist the full network dataset to `network_data.json` and notify the auto-sync
  service that local data changed.
- **Inputs:** `data`.
- **Returns:** `Future<void>`.
- **Side effects:** Writes `network_data.json` (pretty-printed, non-atomic); calls
  `AutoSyncService.instance.notifySaved()` (see
  [`../../../../shared/services/auto_sync_service.md#notifysaved`](../../../shared/services/auto_sync_service.md)).
- **Algorithm:** JSON-encode `data.toJson()`, write it, then notify auto-sync.
- **Usage:**
  ```dart
  await NetworkStorage.save(
    NetworkData(networks: _networks, assignments: data.assignments),
  );
  ```
  (from [`network_list_page.md`](../views/network_list_page.md)'s `_onReorder`)
- **Notes:** Every write to network data should go through this method (directly, or via
  [`addOrUpdateNetwork`](#addorupdatenetwork)/[`deleteNetwork`](#deletenetwork)/
  [`setAssignment`](#setassignment)/[`removeAssignment`](#removeassignment)) so `AutoSyncService` is
  always notified. Unlike `DeviceStorage.addOrUpdate`, none of this file's mutators call
  `AutoSyncService.notifySaved()` themselves — the callers in the view layer (e.g.
  `network_edit_page.dart`'s `_save`) call it explicitly after awaiting the storage call, in
  addition to `save`'s own internal notification.

### `static Future<void> addOrUpdateNetwork(Network network)` <a id="addorupdatenetwork"></a>
- **Kind:** static method.
- **Source:** `lib/features/network/services/network_storage.dart` (line 52).
- **Purpose:** Insert a new network or replace an existing one, matched by `id`.
- **Inputs:** `network`.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `network_data.json` via [`save`](#save); assignments are carried over
  unchanged.
- **Algorithm:** Load the current list; find the index of an existing network with the same `id`,
  replacing it if found, else append; save with the (possibly unchanged) `assignments` list.
- **Usage:**
  ```dart
  await NetworkStorage.addOrUpdateNetwork(network);
  ```
  (from [`network_edit_page.md`](../views/network_edit_page.md)'s `_save`)
- **Notes:** None.

### `static Future<void> deleteNetwork(String id)` <a id="deletenetwork"></a>
- **Kind:** static method.
- **Source:** `lib/features/network/services/network_storage.dart` (line 69).
- **Purpose:** Delete a network by id and remove every assignment that referenced it.
- **Inputs:** `id`.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `network_data.json` via [`save`](#save).
- **Algorithm:** Filter the network out of the loaded list; filter out every assignment whose
  `networkId == id`; save both lists together in one write.
- **Usage:**
  ```dart
  await NetworkStorage.deleteNetwork(widget.networkId);
  ```
  (from [`network_detail_page.md`](../views/network_detail_page.md)'s `_deleteNetwork`)
- **Notes:** This is the cascade rule for networks: deleting a network always deletes its device
  assignments in the same write, so a dangling `NetworkDevice` pointing at a nonexistent
  `networkId` never persists.

### `static Future<void> setAssignment(NetworkDevice assignment)` <a id="setassignment"></a>
- **Kind:** static method.
- **Source:** `lib/features/network/services/network_storage.dart` (line 83).
- **Purpose:** Insert a new device assignment or replace an existing one, matched by the
  `(networkId, deviceId)` composite key.
- **Inputs:** `assignment`.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `network_data.json` via [`save`](#save); `networks` unchanged.
- **Algorithm:** Load the current list; find the index of an existing assignment with the same
  `networkId` *and* `deviceId`, replacing it if found, else append; save.
- **Usage:**
  ```dart
  await NetworkStorage.setAssignment(result);
  ```
  (from [`network_detail_page.md`](../views/network_detail_page.md)'s `_addDevice` and
  `_editAssignment`)
- **Notes:** Because `NetworkDevice` has no `id`, this method's index lookup is the practical
  expression of the composite-key identity described in
  [Networks](../../../../features/networks.md#composite-key-identity--and-why) — the pair
  `(networkId, deviceId)` is what "replace the existing one" means here, not any synthetic
  identifier.

### `static Future<void> removeAssignment(String networkId, String deviceId)` <a id="removeassignment"></a>
- **Kind:** static method.
- **Source:** `lib/features/network/services/network_storage.dart` (line 104).
- **Purpose:** Remove a single device's assignment from a network.
- **Inputs:** `networkId`, `deviceId`.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `network_data.json` via [`save`](#save); `networks` unchanged.
- **Algorithm:** Filter out the assignment matching both `networkId` and `deviceId`; save.
- **Usage:**
  ```dart
  await NetworkStorage.removeAssignment(
    assignment.networkId,
    assignment.deviceId,
  );
  ```
  (from [`network_detail_page.md`](../views/network_detail_page.md)'s `_removeAssignment`)
- **Notes:** None.
