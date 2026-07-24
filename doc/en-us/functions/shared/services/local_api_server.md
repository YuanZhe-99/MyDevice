# lib/shared/services/local_api_server.dart

`LocalApiServer` is the desktop-only local HTTP API described in
[../../../platform-notes.md](../../../platform-notes.md): a `shelf`-based, disabled-by-default
server exposing read-only inventory endpoints for devices/networks/datasets/services plus one
mutating device-add endpoint. Every non-add endpoint only surfaces manually saved data — per this
repo's `AGENTS.md`, the Services feature (and by extension this API) must never scan ports,
connect to servers, or inspect Docker.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `port` | static getter | B | Configured API server port (default 7789). |
| `listenAddress` | static getter | B | Configured API server listen address. |
| `enabled` | static getter | B | Whether the API server is enabled in saved settings. |
| `isRunning` | static getter | B | Whether the server is currently bound. |
| `lastError` | static getter | B | Last startup/runtime error code, if any. |
| [`loadConfig`](#loadconfig) | static method | A | Load API server settings from `storage_config.json`. |
| [`start`](#start) | static method | A | Bind and serve the API server per current config. |
| [`stop`](#stop) | static method | A | Force-close the running server, if any. |
| [`restart`](#restart) | static method | A | Reload config and restart the server. |
| `_handlePing` | static method (route handler) | B | `GET /ping` liveness check. |
| [`_handleList`](#handlelist) | static method (route handler) | A | `GET /device/list`: devices, optionally filtered by category. |
| [`_handleSearch`](#handlesearch) | static method (route handler) | A | `GET /device/search`: devices matching a text query. |
| [`_handleAdd`](#handleadd) | static method (route handler) | A | `POST /device/add`: create a device from a JSON body. |
| [`_handleStats`](#handlestats) | static method (route handler) | A | `GET /device/stats`: cross-module summary statistics. |
| [`_handleNetworkList`](#handlenetworklist) | static method (route handler) | A | `GET /network/list`: networks with assignment details. |
| [`_handleNetworkSearch`](#handlenetworksearch) | static method (route handler) | A | `GET /network/search`: networks/assignments matching a query. |
| [`_handleDatasetList`](#handledatasetlist) | static method (route handler) | A | `GET /dataset/list`: datasets with linked storage details. |
| [`_handleDatasetSearch`](#handledatasetsearch) | static method (route handler) | A | `GET /dataset/search`: datasets matching a query. |
| [`_handleServiceList`](#handleservicelist) | static method (route handler) | A | `GET /service/list`: services with simple filters. |
| [`_handleServiceSearch`](#handleservicesearch) | static method (route handler) | A | `GET /service/search`: services matching a query. |
| [`_handleServiceRoutes`](#handleserviceroutes) | static method (route handler) | A | `GET /service/routes`: saved access routes. |
| [`_handleServiceStats`](#handleservicestats) | static method (route handler) | A | `GET /service/stats`: service-only summary statistics. |
| [`buildStatsJson`](#buildstatsjson) | static method | A | Build the `/device/stats` response body. |
| [`deviceToJson`](#devicetojson) | static method | A | Serialize a `Device` for API responses. |
| [`storageToJson`](#storagetojson) | static method | A | Serialize a `StorageInfo`. |
| [`filterDevicesForSearch`](#filterdevicesforsearch) | static method | A | Case-insensitive device text search. |
| [`buildNetworkListJson`](#buildnetworklistjson) | static method | A | Serialize networks with grouped assignments. |
| [`networkToJson`](#networktojson) | static method | A | Serialize one `Network` with optional assignment/device-name enrichment. |
| [`filterNetworksForSearch`](#filternetworksforsearch) | static method | A | Case-insensitive network/assignment text search. |
| [`buildDataSetListJson`](#builddatasetlistjson) | static method | A | Serialize datasets with linked storage. |
| [`dataSetToJson`](#datasettojson) | static method | A | Serialize one `DataSet` with resolved storage links. |
| [`filterDataSetsForSearch`](#filterdatasetsforsearch) | static method | A | Case-insensitive dataset/link text search. |
| [`buildServiceListJson`](#buildservicelistjson) | static method | A | Serialize services for API responses. |
| [`serviceToJson`](#servicetojson) | static method | A | Serialize one `ServiceNode`. |
| [`filterServicesForList`](#filterservicesforlist) | static method | A | Filter services by `deviceId`/`kind`/`state`. |
| [`filterServicesForSearch`](#filterservicesforsearch) | static method | A | Case-insensitive service text search. |
| [`buildServiceRouteListJson`](#buildserviceroutelistjson) | static method | A | Serialize service routes for API responses. |
| [`serviceRouteToJson`](#serviceroutetojson) | static method | A | Serialize one `ServiceRoute`. |
| [`buildServiceStatsJson`](#buildservicestatsjson) | static method | A | Build the `/service/stats` response body. |
| `_deviceToJson` | static method | B | Private forwarding alias for `deviceToJson`. |
| [`_serviceEndpointToJson`](#serviceendpointtojson) | static method | A | Serialize a `ServiceEndpoint` with resolved network name. |
| [`_serviceRouteHopToJson`](#serviceroutehoptojson) | static method | A | Serialize a `ServiceRouteHop` with resolved names. |
| [`_publicTargets`](#publictargets) | static method | A | Read grouped public targets from a route's `extraJson`. |
| [`_deviceNameMap`](#devicenamemap) | static method | A | Build a device-id-to-name lookup map. |
| [`_countBy`](#countby) | static method | A | Generic grouped-count helper. |
| [`_containsText`](#containstext) | static method | A | Case-insensitive substring test across multiple values. |
| [`_intValue`](#intvalue) | static method | A | Tolerant int parser for API request bodies. |
| [`_doubleValue`](#doublevalue) | static method | A | Tolerant double parser for API request bodies. |
| [`_dateValue`](#datevalue) | static method | A | Tolerant `DateTime` parser for API request bodies. |
| [`_moneyValueFromJson`](#moneyvaluefromjson) | static method | A | Parse an optional `MoneyValue` from a JSON map. |
| [`_recurringCostFromJson`](#recurringcostfromjson) | static method | A | Parse an optional `DeviceRecurringCost` from a JSON map. |
| `_json` | static method | B | Wrap a value as a `200 application/json` `Response`. |
| `_error` | static method | B | Build a JSON error `Response` for a given status. |
| [`_parseBody`](#parsebody) | static method | A | Parse the request body as JSON, tolerating malformed input. |
| [`_corsMiddleware`](#corsmiddleware) | static method | A | Permissive CORS middleware for every response. |
| [`_authMiddleware`](#authmiddleware) | static method | A | Enforce Basic Auth / loopback-only access rules. |
| [`_validateBasicAuth`](#validatebasicauth) | static method | A | Validate an `Authorization: Basic` header against configured credentials. |
| [`_errorMiddleware`](#errormiddleware) | static method | A | Catch unhandled handler exceptions as a `500` JSON error. |

## Documentation

### `static Future<void> loadConfig()` <a id="loadconfig"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** line 66.
- **Purpose:** Read persisted API settings (`apiPort`, `apiListenAddress`, `apiEnabled`,
  `apiUsername`, `apiPassword`) from `storage_config.json`.
- **Inputs:** None. **Returns:** `Future<void>`.
- **Side effects:** Reads config via `DeviceStorage.readConfig()`; sets the static fields
  (default port `7789`, default address `'localhost'`).
- **Algorithm:** Direct map reads with defaults for missing keys.
- **Usage:** Called by `start()`/`restart()` and by the settings UI.
- **Notes:** Credentials are read as plaintext, per this app's documented security posture.

### `static Future<void> start()` <a id="start"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** line 80.
- **Purpose:** Bind and start the API server per current settings, or do nothing if disabled.
- **Inputs:** None. **Returns:** `Future<void>`.
- **Side effects:** Binds a listening socket; sets `_server`/`_lastError`; logs to stdout.
- **Algorithm:** `loadConfig()`, `stop()` any prior instance, clear `_lastError`; return early if
  disabled. Compute `isNonLoopback` (address is `0.0.0.0` or neither `localhost` nor
  `127.0.0.1`) and `hasCredentials`; refuse to start with `_lastError = 'credentials_required'`
  if non-loopback without credentials. Build a `Router` with 13 routes (`/ping`, `/device/list`,
  `/device/search`, `/device/add`, `/device/stats`, `/network/list`, `/network/search`,
  `/dataset/list`, `/dataset/search`, `/service/list`, `/service/search`, `/service/routes`,
  `/service/stats`); wrap it in `_corsMiddleware` → `_authMiddleware` → `_errorMiddleware`;
  resolve the bind address and `shelf_io.serve`; capture bind failures into `_lastError`.
- **Usage:** Called from `main()` on desktop platforms.
- **Notes:** Identical unsafe-non-localhost-without-credentials refusal as MyAnime's
  `LocalApiServer.start`, but with MyDevice's own default port `7789` (vs. MyAnime's `7788`) and
  route table.

### `static Future<void> stop()` <a id="stop"></a>
- **Kind:** static method. **Source:** line 148.
- **Purpose:** Forcibly close the running server, if any.
- **Inputs:** None. **Returns:** `Future<void>`.
- **Side effects:** Closes the socket (`force: true`); sets `_server = null`.
- **Algorithm:** `await _server?.close(force: true); _server = null;`.
- **Usage:** Called at the start of `start()` and from the settings UI's disable action.
- **Notes:** Drops in-flight connections; no graceful drain.

### `static Future<void> restart()` <a id="restart"></a>
- **Kind:** static method. **Source:** line 158.
- **Purpose:** Reload settings and rebind.
- **Inputs:** None. **Returns:** `Future<void>`.
- **Side effects:** Same as `loadConfig()` + `start()`.
- **Algorithm:** `await loadConfig(); await start();`.
- **Usage:** Called by the settings UI's save action for the API section.
- **Notes:** None.

### `static Future<Response> _handleList(Request request)` <a id="handlelist"></a>
- **Kind:** static method (route handler). **Source:** line 179.
- **Purpose:** Return saved devices, optionally filtered by category.
- **Inputs:** `request` — optional `?category=` matching `DeviceCategory.name`.
- **Returns:** `200` JSON with the device list (via `buildStatsJson`-adjacent serialization, see
  `deviceToJson`).
- **Side effects:** Reads device storage.
- **Algorithm:** Load devices; if `category` is present and valid, filter by
  `d.category.name == category`; serialize each via `deviceToJson`.
- **Usage:** Called by local/LAN clients wanting the full or category-filtered device inventory.
- **Notes:** Category values must match `DeviceCategory.name` exactly (case-sensitive enum name).

### `static Future<Response> _handleSearch(Request request)` <a id="handlesearch"></a>
- **Kind:** static method (route handler). **Source:** line 202.
- **Purpose:** Search saved devices by human-readable inventory fields.
- **Inputs:** `request` — `?q=` search text.
- **Returns:** `200` JSON list; empty list when there are no matches.
- **Side effects:** Reads device storage.
- **Algorithm:** Load devices; delegate matching to `filterDevicesForSearch`; serialize results.
- **Usage:** Called for device lookup by name/brand/model/etc. without a full list dump.
- **Notes:** Never performs online lookup — inventory fields only.

### `static Future<Response> _handleAdd(Request request)` <a id="handleadd"></a>
- **Kind:** static method (route handler). **Source:** line 217.
- **Purpose:** Create a new device from a JSON body.
- **Inputs:** `request` — JSON body; `name` and `category` required, everything else optional
  (CPU/GPU/storage/finance/location fields).
- **Returns:** `400` on missing/invalid body, missing name, or invalid category; otherwise `200`
  with `{success: true, id, name}`.
- **Side effects:** Persists the new device via `DeviceStorage.addOrUpdate` (which can trigger
  auto-sync's local-data-changed notification).
- **Algorithm:** Validate `name`/`category` (matched against `DeviceCategory.values` by name);
  parse optional nested `cpu`/`gpu`/`storage` maps into `CpuInfo`/`GpuInfo`/`List<StorageInfo>`
  (defaulting to empty values on absence or wrong shape); parse `recurringCosts` via
  `_recurringCostFromJson`, dropping malformed entries (`whereType`); parse scalar fields via the
  tolerant `_intValue`/`_doubleValue`/`_dateValue`/`_moneyValueFromJson` helpers; construct and
  save a `Device`.
- **Usage:** Called by external tools adding a device programmatically.
- **Notes:** Unknown or malformed optional fields are silently ignored rather than rejecting the
  whole request — only `name`/`category` are hard requirements.

### `static Future<Response> _handleStats(Request request)` <a id="handlestats"></a>
- **Kind:** static method (route handler). **Source:** line 326.
- **Purpose:** Return cross-module summary statistics.
- **Inputs:** `request` (unused directly). **Returns:** `200` JSON, see `buildStatsJson`.
- **Side effects:** Reads device, service, network, and dataset storage.
- **Algorithm:** Load all four stores; delegate to `buildStatsJson`.
- **Usage:** Called for a dashboard-style overview across all inventory types.
- **Notes:** Keeps legacy top-level device summary fields for API compatibility.

### `static Future<Response> _handleNetworkList(Request request)` <a id="handlenetworklist"></a>
- **Kind:** static method (route handler). **Source:** line 350.
- **Purpose:** Return saved networks enriched with assignment details.
- **Inputs:** `request` (unused). **Returns:** `200` JSON, see `buildNetworkListJson`.
- **Side effects:** Reads network and device storage (for assignment device names).
- **Algorithm:** Load both stores; delegate to `buildNetworkListJson`.
- **Usage:** Read-only network inventory listing.
- **Notes:** Read-only endpoint.

### `static Future<Response> _handleNetworkSearch(Request request)` <a id="handlenetworksearch"></a>
- **Kind:** static method (route handler). **Source:** line 367.
- **Purpose:** Search saved networks and their device assignments.
- **Inputs:** `request` — `?q=`. **Returns:** `200` JSON list.
- **Side effects:** Reads network and device storage.
- **Algorithm:** Load both stores; delegate to `filterNetworksForSearch`; serialize matches.
- **Usage:** Network lookup by name/addressing fields/notes/assignment host or IP.
- **Notes:** Searches assignment host/IP data too, not just the network record itself.

### `static Future<Response> _handleDatasetList(Request request)` <a id="handledatasetlist"></a>
- **Kind:** static method (route handler). **Source:** line 394.
- **Purpose:** Return saved datasets with linked device storage details.
- **Inputs:** `request` (unused). **Returns:** `200` JSON, see `buildDataSetListJson`.
- **Side effects:** Reads dataset and device storage.
- **Algorithm:** Load both stores; delegate to `buildDataSetListJson`.
- **Usage:** Read-only dataset inventory listing.
- **Notes:** Read-only endpoint.

### `static Future<Response> _handleDatasetSearch(Request request)` <a id="handledatasetsearch"></a>
- **Kind:** static method (route handler). **Source:** line 410.
- **Purpose:** Search datasets and their linked device storage slots.
- **Inputs:** `request` — `?q=`. **Returns:** `200` JSON list.
- **Side effects:** Reads dataset and device storage.
- **Algorithm:** Load both stores; delegate to `filterDataSetsForSearch`; serialize matches.
- **Usage:** Dataset lookup by name plus linked device/storage summaries.
- **Notes:** None.

### `static Future<Response> _handleServiceList(Request request)` <a id="handleservicelist"></a>
- **Kind:** static method (route handler). **Source:** line 432.
- **Purpose:** Return saved service nodes with optional simple filters.
- **Inputs:** `request` — optional `?deviceId=`, `?kind=`, `?state=` (serialized enum names).
- **Returns:** `200` JSON, see `buildServiceListJson`.
- **Side effects:** Reads service, device, and network storage (for name enrichment).
- **Algorithm:** Load stores; apply `filterServicesForList`; serialize via `buildServiceListJson`.
- **Usage:** Service inventory listing, optionally scoped to one device/kind/state.
- **Notes:** Filter values use serialized enum names where applicable.

### `static Future<Response> _handleServiceSearch(Request request)` <a id="handleservicesearch"></a>
- **Kind:** static method (route handler). **Source:** line 457.
- **Purpose:** Search service nodes by name, device, endpoint, tags, and notes.
- **Inputs:** `request` — `?q=`. **Returns:** `200` JSON list.
- **Side effects:** Reads service, device, and network storage.
- **Algorithm:** Load stores; delegate to `filterServicesForSearch`; serialize matches.
- **Usage:** Service lookup across saved metadata.
- **Notes:** Does not scan live ports or inspect running services — manual inventory only.

### `static Future<Response> _handleServiceRoutes(Request request)` <a id="handleserviceroutes"></a>
- **Kind:** static method (route handler). **Source:** line 485.
- **Purpose:** Return saved service access routes.
- **Inputs:** `request` (unused). **Returns:** `200` JSON, see `buildServiceRouteListJson`.
- **Side effects:** Reads service and device storage.
- **Algorithm:** Load stores; delegate to `buildServiceRouteListJson`.
- **Usage:** Fetch the full access-route inventory, e.g. for external topology tooling.
- **Notes:** Route names may be generated internally; callers should prefer notes/final targets
  for display, per this repo's Services feature conventions.

### `static Future<Response> _handleServiceStats(Request request)` <a id="handleservicestats"></a>
- **Kind:** static method (route handler). **Source:** line 502.
- **Purpose:** Return service-specific summary statistics.
- **Inputs:** `request` (unused). **Returns:** `200` JSON, see `buildServiceStatsJson`.
- **Side effects:** Reads service storage.
- **Algorithm:** Load services; delegate to `buildServiceStatsJson`.
- **Usage:** A narrower companion to `/device/stats` for service-only dashboards.
- **Notes:** None.

### `static Map<String, dynamic> buildStatsJson({required List<Device> devices, ...})` <a id="buildstatsjson"></a>
- **Kind:** static method. **Source:** line 517.
- **Purpose:** Build the cross-module `/device/stats` response: device totals/by-category
  counts/recently-added, plus embedded service/network/dataset summary counts.
- **Inputs:** `devices`, `services`, `routes`, plus optional `networks`/`datasets` lists.
- **Returns:** `Map<String, dynamic>`.
- **Side effects:** None (pure computation over its inputs).
- **Algorithm:** Compute `total` device count, `byCategory` via `_countBy`, a `recentlyAdded`
  slice (most-recent devices by `modifiedAt`/`createdAt`), and embed a `services` summary object
  built the same way `buildServiceStatsJson` does, plus counts for any supplied
  networks/datasets.
- **Usage:** Called by `_handleStats`, and is directly unit-testable (accepts loaded data rather
  than reading storage itself).
- **Notes:** `total`, `byCategory`, `recentlyAdded`, and `services` are documented as stable
  field names for API-compatibility reasons.

### `static Map<String, dynamic> deviceToJson(Device device)` <a id="devicetojson"></a>
- **Kind:** static method. **Source:** line 605.
- **Purpose:** Serialize a `Device` into the local API's public response shape.
- **Inputs:** `device`. **Returns:** `Map<String, dynamic>` — identity/category/CPU/GPU/RAM/
  storage/screen/location/lifecycle/finance fields plus `imagePath`.
- **Side effects:** None.
- **Algorithm:** Direct field mapping, including nested `storageToJson` for each storage slot and
  computed finance-summary fields.
- **Usage:** Called by `_handleList`/`_handleSearch`/`_handleAdd`'s response and by
  `buildNetworkListJson`/`buildDataSetListJson`'s device-name enrichment paths indirectly via
  `_deviceNameMap`.
- **Notes:** Keeps legacy keys while additively including lifecycle/location/image/finance
  fields added after the original API contract.

### `static Map<String, dynamic> storageToJson(StorageInfo storage)` <a id="storagetojson"></a>
- **Kind:** static method. **Source:** line 663.
- **Purpose:** Serialize a `StorageInfo` slot for device/dataset API responses.
- **Inputs:** `storage`. **Returns:** `Map<String, dynamic>` (capacity, type, interface, brand,
  serial number).
- **Side effects:** None.
- **Algorithm:** Direct field mapping.
- **Usage:** Called by `deviceToJson` for each storage slot.
- **Notes:** Includes brand and serial number, added to the API after its original contract.

### `static List<Device> filterDevicesForSearch({required List<Device> devices, required String query})` <a id="filterdevicesforsearch"></a>
- **Kind:** static method. **Source:** line 676.
- **Purpose:** Case-insensitive text search over device inventory fields.
- **Inputs:** `devices`, `query`. **Returns:** matching devices, original order preserved.
- **Side effects:** None.
- **Algorithm:** Lowercase the query; keep devices where `_containsText` finds it in name/brand/
  model/serial/CPU/GPU/OS/location/notes fields.
- **Usage:** Called by `_handleSearch`.
- **Notes:** Searches inventory fields only; never performs an online lookup.

### `static List<Map<String, dynamic>> buildNetworkListJson({required List<Network> networks, ...})` <a id="buildnetworklistjson"></a>
- **Kind:** static method. **Source:** line 718.
- **Purpose:** Serialize networks with their device assignments grouped underneath.
- **Inputs:** `networks`, `assignments`, `devices` (for name resolution).
- **Returns:** `List<Map<String, dynamic>>`.
- **Side effects:** None.
- **Algorithm:** Build a device-name map via `_deviceNameMap`; for each network, group its
  assignments (`a.networkId == n.id`) and call `networkToJson`.
- **Usage:** Called by `_handleNetworkList`.
- **Notes:** None.

### `static Map<String, dynamic> networkToJson(Network network, {List<NetworkDevice>? assignments, Map<String, String>? deviceNames})` <a id="networktojson"></a>
- **Kind:** static method. **Source:** line 742.
- **Purpose:** Serialize one `Network`, optionally including its resolved device assignments.
- **Inputs:** `network`; optional `assignments`/`deviceNames`.
- **Returns:** `Map<String, dynamic>`.
- **Side effects:** None.
- **Algorithm:** Direct field mapping (type/subnet/gateway/DNS/notes) plus, when `assignments` is
  supplied, a nested list of `{deviceId, deviceName, ipAddress, hostname, addressMode,
  isExitNode}`.
- **Usage:** Called by `buildNetworkListJson`.
- **Notes:** None.

### `static List<Network> filterNetworksForSearch({required List<Network> networks, ...})` <a id="filternetworksforsearch"></a>
- **Kind:** static method. **Source:** line 775.
- **Purpose:** Case-insensitive search across network and assignment text fields.
- **Inputs:** `networks`, `assignments`, `devices`, `query`.
- **Returns:** matching networks, original order preserved.
- **Side effects:** None.
- **Algorithm:** Match on the network's own fields (name/subnet/gateway/DNS/notes) or on any of
  its assignments' host/IP/hostname fields (including the assigned device's resolved name).
- **Usage:** Called by `_handleNetworkSearch`.
- **Notes:** Including device names lets callers search "which network is device X on."

### `static List<Map<String, dynamic>> buildDataSetListJson({required List<DataSet> datasets, required List<Device> devices})` <a id="builddatasetlistjson"></a>
- **Kind:** static method. **Source:** line 814.
- **Purpose:** Serialize datasets with resolved linked-device-storage details.
- **Inputs:** `datasets`, `devices`. **Returns:** `List<Map<String, dynamic>>`.
- **Side effects:** None.
- **Algorithm:** For each dataset, call `dataSetToJson` with the device list for link resolution.
- **Usage:** Called by `_handleDatasetList`.
- **Notes:** None.

### `static Map<String, dynamic> dataSetToJson(DataSet dataset, {List<Device>? devices})` <a id="datasettojson"></a>
- **Kind:** static method. **Source:** line 828.
- **Purpose:** Serialize one `DataSet`, resolving each storage link's device name and current
  storage-slot summary.
- **Inputs:** `dataset`; optional `devices` for resolution.
- **Returns:** `Map<String, dynamic>`.
- **Side effects:** None.
- **Algorithm:** Direct field mapping plus, per storage link, look up the linked device and
  render its storage-slot summaries via `storageToJson`-equivalent display strings.
- **Usage:** Called by `buildDataSetListJson`.
- **Notes:** Storage links retain slot indices in the output because datasets link to storage by
  index (see [../../../features/datasets.md](../../../features/datasets.md)).

### `static List<DataSet> filterDataSetsForSearch({required List<DataSet> datasets, required List<Device> devices, required String query})` <a id="filterdatasetsforsearch"></a>
- **Kind:** static method. **Source:** line 864.
- **Purpose:** Case-insensitive search across dataset, linked-device, and linked-storage text.
- **Inputs:** `datasets`, `devices`, `query`. **Returns:** matching datasets, original order.
- **Side effects:** None.
- **Algorithm:** Match on the dataset's own name plus, for each storage link, the linked device's
  name and storage summary text.
- **Usage:** Called by `_handleDatasetSearch`.
- **Notes:** None.

### `static List<Map<String, dynamic>> buildServiceListJson({required List<ServiceNode> services, ...})` <a id="buildservicelistjson"></a>
- **Kind:** static method. **Source:** line 907.
- **Purpose:** Serialize service nodes for API responses.
- **Inputs:** `services`, `devices`, `networks` (for endpoint network-name resolution).
- **Returns:** `List<Map<String, dynamic>>`.
- **Side effects:** None.
- **Algorithm:** Build device/network name maps; call `serviceToJson` per service.
- **Usage:** Called by `_handleServiceList`.
- **Notes:** Exposes saved notes only; never queries live service state.

### `static Map<String, dynamic> serviceToJson(ServiceNode service, {Map<String, String>? deviceNames, Map<String, String>? networkNames})` <a id="servicetojson"></a>
- **Kind:** static method. **Source:** line 932.
- **Purpose:** Serialize one `ServiceNode`, including its endpoints via `_serviceEndpointToJson`.
- **Inputs:** `service`; optional name maps for enrichment.
- **Returns:** `Map<String, dynamic>`.
- **Side effects:** None.
- **Algorithm:** Direct field mapping (device/name/template/icon/kind/runtime/state/tags/notes/
  `dockerCompose`) plus a nested endpoints list.
- **Usage:** Called by `buildServiceListJson`.
- **Notes:** Endpoint port ranges expose both the raw `port` value and the formatted `portText`.

### `static List<ServiceNode> filterServicesForList({required List<ServiceNode> services, String? deviceId, String? kind, String? state})` <a id="filterservicesforlist"></a>
- **Kind:** static method. **Source:** line 960.
- **Purpose:** Apply the `/service/list` endpoint's optional simple equality filters.
- **Inputs:** `services`; optional `deviceId`/`kind`/`state`.
- **Returns:** matching services, original order.
- **Side effects:** None.
- **Algorithm:** Successive equality filters, each skipped when its parameter is null/empty.
- **Usage:** Called by `_handleServiceList`.
- **Notes:** Empty filter strings are treated as "no filter," not as "match empty."

### `static List<ServiceNode> filterServicesForSearch({required List<ServiceNode> services, required List<Device> devices, required List<Network> networks, required String query})` <a id="filterservicesforsearch"></a>
- **Kind:** static method. **Source:** line 982.
- **Purpose:** Case-insensitive free-text search over service metadata, endpoints, and linked
  names.
- **Inputs:** `services`, `devices`, `networks`, `query`. **Returns:** matching services,
  original order.
- **Side effects:** None.
- **Algorithm:** Match on service name/tags/notes/device name, plus each endpoint's label/
  protocol/bind-address/notes and its resolved network name.
- **Usage:** Called by `_handleServiceSearch`.
- **Notes:** Searches saved metadata and linked names only — never live port/process state.

### `static List<Map<String, dynamic>> buildServiceRouteListJson({required List<ServiceRoute> routes, required List<ServiceNode> services, required List<Device> devices})` <a id="buildserviceroutelistjson"></a>
- **Kind:** static method. **Source:** line 1031.
- **Purpose:** Serialize service access routes for API responses.
- **Inputs:** `routes`, `services`, `devices`. **Returns:** `List<Map<String, dynamic>>`.
- **Side effects:** None.
- **Algorithm:** Build a services-by-id map; call `serviceRouteToJson` per route.
- **Usage:** Called by `_handleServiceRoutes`.
- **Notes:** None.

### `static Map<String, dynamic> serviceRouteToJson(ServiceRoute route, {Map<String, ServiceNode>? servicesById, Map<String, String>? deviceNames})` <a id="serviceroutetojson"></a>
- **Kind:** static method. **Source:** line 1054.
- **Purpose:** Serialize one `ServiceRoute`, including resolved source service/endpoint, hops
  (via `_serviceRouteHopToJson`), and grouped public targets (via `_publicTargets`).
- **Inputs:** `route`; optional lookup maps.
- **Returns:** `Map<String, dynamic>`.
- **Side effects:** None.
- **Algorithm:** Direct field mapping (`finalUrl`, `accessLevel`, `notes`) plus nested hops and
  `publicTargets`.
- **Usage:** Called by `buildServiceRouteListJson`.
- **Notes:** `finalUrl` remains the first target for API compatibility even when
  `extraJson.publicTargets` holds additional grouped targets (see
  [../../../features/services-topology.md](../../../features/services-topology.md)).

### `static Map<String, dynamic> buildServiceStatsJson({required List<ServiceNode> services, required List<ServiceRoute> routes})` <a id="buildservicestatsjson"></a>
- **Kind:** static method. **Source:** line 1092.
- **Purpose:** Build the `/service/stats` response: service/route totals and by-kind/by-state
  breakdowns.
- **Inputs:** `services`, `routes`. **Returns:** `Map<String, dynamic>`.
- **Side effects:** None.
- **Algorithm:** Totals plus `_countBy` groupings by service kind and state, and a route count.
- **Usage:** Called by `_handleServiceStats`, and embedded inside `buildStatsJson`'s `services`
  field.
- **Notes:** Mirrors the service portion embedded in `/device/stats`, as a standalone endpoint.

### `static Map<String, dynamic> _serviceEndpointToJson(ServiceEndpoint endpoint, Map<String, String>? networkNames)` <a id="serviceendpointtojson"></a>
- **Kind:** static method. **Source:** line 1127.
- **Purpose:** Serialize a `ServiceEndpoint` with its network id resolved to a display name where
  possible.
- **Inputs:** `endpoint`, `networkNames`. **Returns:** `Map<String, dynamic>`.
- **Side effects:** None.
- **Algorithm:** Direct field mapping plus a resolved `networkName` when `networkNames` contains
  the endpoint's `networkId`.
- **Usage:** Called by `serviceToJson` for each of a service's endpoints.
- **Notes:** Internal helper used for both service and route responses.

### `static Map<String, dynamic> _serviceRouteHopToJson(ServiceRouteHop hop, Map<String, ServiceNode>? servicesById, Map<String, String>? deviceNames)` <a id="serviceroutehoptojson"></a>
- **Kind:** static method. **Source:** line 1152.
- **Purpose:** Serialize a `ServiceRouteHop`, resolving its referenced service/device names where
  possible while preserving free-form fields.
- **Inputs:** `hop`; optional lookup maps. **Returns:** `Map<String, dynamic>`.
- **Side effects:** None.
- **Algorithm:** Direct field mapping (type/scheme/host/port/path/notes) plus resolved
  `serviceName`/`deviceName` when the hop references them.
- **Usage:** Called by `serviceRouteToJson` for each hop.
- **Notes:** Keeps free-form hop fields (scheme/host/port/path) intact even when no service/
  device reference resolves.

### `static List<String> _publicTargets(ServiceRoute route)` <a id="publictargets"></a>
- **Kind:** static method. **Source:** line 1181.
- **Purpose:** Read the grouped public targets stored in a route's `extraJson.publicTargets`.
- **Inputs:** `route`. **Returns:** `List<String>`.
- **Side effects:** None.
- **Algorithm:** Read `route.extraJson['publicTargets']`; if it's a list, keep only string
  entries (ignoring non-string entries for forward compatibility); otherwise return `[]`.
- **Usage:** Called by `serviceRouteToJson`.
- **Notes:** Supports forward-compatible JSON by silently ignoring unexpected entry shapes rather
  than throwing.

### `static Map<String, String> _deviceNameMap(List<Device> devices)` <a id="devicenamemap"></a>
- **Kind:** static method. **Source:** line 1192.
- **Purpose:** Build an id-to-name lookup for device cross-referencing.
- **Inputs:** `devices`. **Returns:** `Map<String, String>`.
- **Side effects:** None.
- **Algorithm:** Map comprehension `{for (final d in devices) d.id: d.name}`.
- **Usage:** Called by `buildNetworkListJson` and similar enrichment paths.
- **Notes:** None.

### `static Map<String, int> _countBy<T>(Iterable<T> values, String Function(T) keyOf)` <a id="countby"></a>
- **Kind:** static generic method. **Source:** line 1201.
- **Purpose:** Count elements grouped by a caller-supplied key function.
- **Inputs:** `values`, `keyOf`. **Returns:** `Map<String, int>`.
- **Side effects:** None.
- **Algorithm:** Fold over `values`, incrementing `result[keyOf(v)]` for each.
- **Usage:** Called by `buildStatsJson`/`buildServiceStatsJson` for by-category/by-kind/by-state
  breakdowns.
- **Notes:** Generic — reusable for any grouping key, not tied to a specific enum.

### `static bool _containsText(Iterable<Object?> values, String lowerQuery)` <a id="containstext"></a>
- **Kind:** static method. **Source:** line 1218.
- **Purpose:** Test whether any of several values contains a lowercased query substring.
- **Inputs:** `values` (nullable entries tolerated), `lowerQuery` (already lowercased).
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** `values.any((v) => v != null && v.toString().toLowerCase().contains(lowerQuery))`.
- **Usage:** The common substring-match primitive behind every `filter*ForSearch` function.
- **Notes:** Skips nulls rather than throwing; callers pass the query pre-lowercased once per
  search rather than per candidate.

### `static int? _intValue(Object? value)` <a id="intvalue"></a>
- **Kind:** static method. **Source:** line 1230.
- **Purpose:** Tolerantly parse an `int` from JSON-decoded input that may already be an `int`, a
  numeric string, or something else.
- **Inputs:** `value`. **Returns:** `int?` — `null` if unparseable.
- **Side effects:** None.
- **Algorithm:** Return directly if already `int`; otherwise attempt `int.tryParse` on a `String`
  (or equivalent numeric coercion); `null` on any other type or parse failure.
- **Usage:** Called by `_handleAdd` for `screenResolutionW`/`screenResolutionH`.
- **Notes:** Tolerates numeric strings so minimal/loosely-typed API clients don't get rejected.

### `static double? _doubleValue(Object? value)` <a id="doublevalue"></a>
- **Kind:** static method. **Source:** line 1242.
- **Purpose:** Tolerantly parse a `double` from JSON-decoded input.
- **Inputs:** `value`. **Returns:** `double?`.
- **Side effects:** None.
- **Algorithm:** Return `value.toDouble()` directly if `value is num`; otherwise attempt string
  parsing; `null` on failure.
- **Usage:** Called by `_handleAdd` for `latitude`/`longitude`.
- **Notes:** Accepts both `int` and `double` JSON number encodings via the shared `num` check.

### `static DateTime? _dateValue(Object? value)` <a id="datevalue"></a>
- **Kind:** static method. **Source:** line 1253.
- **Purpose:** Tolerantly parse a `DateTime` from a JSON string.
- **Inputs:** `value`. **Returns:** `DateTime?` — `null` for non-strings, empty strings, or
  unparseable strings.
- **Side effects:** None.
- **Algorithm:** Reject non-`String`/empty input; otherwise `DateTime.tryParse`.
- **Usage:** Called by `_handleAdd` for `purchaseDate`/`releaseDate`/`retiredDate`.
- **Notes:** Invalid strings are ignored (not an error) for compatibility with minimal add
  requests.

### `static MoneyValue? _moneyValueFromJson(Object? value)` <a id="moneyvaluefromjson"></a>
- **Kind:** static method. **Source:** line 1263.
- **Purpose:** Parse an optional `MoneyValue` (amount + currency) from a JSON map.
- **Inputs:** `value`. **Returns:** `MoneyValue?` — `null` if `value` isn't a
  `Map<String, dynamic>` or required sub-fields are malformed.
- **Side effects:** None.
- **Algorithm:** Type-check the map, then parse amount/currency fields (using the tolerant
  numeric parsers where applicable).
- **Usage:** Called by `_handleAdd` for `purchasePrice`/`soldPrice`.
- **Notes:** Malformed money maps are ignored rather than rejecting the whole add request.

### `static DeviceRecurringCost? _recurringCostFromJson(Object? value)` <a id="recurringcostfromjson"></a>
- **Kind:** static method. **Source:** line 1277.
- **Purpose:** Parse an optional `DeviceRecurringCost` entry from a JSON map.
- **Inputs:** `value`. **Returns:** `DeviceRecurringCost?` — `null` on wrong shape.
- **Side effects:** None.
- **Algorithm:** Type-check the map, then parse kind/price/billing-cycle/name fields.
- **Usage:** Called (mapped over a list) by `_handleAdd` for `recurringCosts`.
- **Notes:** Malformed entries are skipped individually (via the caller's `whereType` filter)
  rather than rejecting the whole list.

### `static Future<Map<String, dynamic>?> _parseBody(Request request)` <a id="parsebody"></a>
- **Kind:** static method. **Source:** line 1312.
- **Purpose:** Read and JSON-decode a request body, tolerating malformed input.
- **Inputs:** `request`. **Returns:** `Future<Map<String, dynamic>?>` — `null` on any decode
  failure or non-object body.
- **Side effects:** Reads the request body stream.
- **Algorithm:** `jsonDecode(await request.readAsString())` wrapped in try/catch, returning `null`
  on failure instead of propagating.
- **Usage:** Called by `_handleAdd`.
- **Notes:** This is why malformed JSON produces a clean `400` rather than a generic `500`.

### `static Middleware _corsMiddleware()` <a id="corsmiddleware"></a>
- **Kind:** static method. **Source:** line 1329.
- **Purpose:** Attach permissive CORS headers to every response.
- **Inputs:** None. **Returns:** `Middleware`.
- **Side effects:** None beyond wrapping the handler.
- **Algorithm:** Adds permissive allow-origin/allow-headers response headers around every
  response the inner handler produces.
- **Usage:** First middleware in `start()`'s `Pipeline`.
- **Notes:** Explicit documented tradeoff — this is why `_authMiddleware`'s loopback+credentials
  rule exists at all.

### `static Middleware _authMiddleware()` <a id="authmiddleware"></a>
- **Kind:** static method. **Source:** line 1347.
- **Purpose:** Enforce the API's access rule: loopback is trusted by default, but once
  credentials are configured, every request (including loopback) must present valid Basic Auth.
- **Inputs:** None. **Returns:** `Middleware`.
- **Side effects:** Reads the connection's remote address from `request.context`.
- **Algorithm:** Determine loopback status from the connection info; reject non-loopback requests
  outright when no credentials are configured (`403`); when credentials are configured, require a
  valid `Authorization: Basic` header via `_validateBasicAuth` regardless of loopback status
  (`401` + `WWW-Authenticate` on failure); otherwise pass through.
- **Usage:** Second middleware in `start()`'s `Pipeline`.
- **Notes:** Identical security rule and rationale to MyAnime's `LocalApiServer._authMiddleware`
  — see that page's Notes for the full quoted reasoning.

### `static bool _validateBasicAuth(String header)` <a id="validatebasicauth"></a>
- **Kind:** static method. **Source:** line 1397.
- **Purpose:** Validate an `Authorization: Basic <base64>` header against configured credentials.
- **Inputs:** `header`. **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Reject anything not starting with `"Basic "`; base64-decode, split on the first
  `:` into username/password, compare against `_username`/`_password`.
- **Usage:** Called by `_authMiddleware`.
- **Notes:** Plain equality check against plaintext-stored credentials.

### `static Middleware _errorMiddleware()` <a id="errormiddleware"></a>
- **Kind:** static method. **Source:** line 1414.
- **Purpose:** Catch any unhandled route-handler exception and return a clean JSON `500` instead
  of an unhandled crash.
- **Inputs:** None. **Returns:** `Middleware`.
- **Side effects:** None beyond wrapping the handler.
- **Algorithm:** try/catch around the inner handler call; build a JSON error response via `_error`
  on any exception.
- **Usage:** Innermost middleware in `start()`'s `Pipeline`.
- **Notes:** Last line of defense; routes are expected to return their own `400`/`401`/`403` for
  expected failure modes.
