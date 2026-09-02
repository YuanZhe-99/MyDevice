# Data Formats

This page documents every persisted model, the `extraJson` unknown-field preservation
pattern, and the full persisted-data inventory. See [Architecture](architecture.md) for
where these files live on disk, and [WebDAV Sync](sync.md) for how they merge across
devices.

All fields shown are the actual constructor/`toJson()`/`fromJson()` fields read from the
current source in `lib/features/*/models/*.dart`, not a general Flutter data-model guess.

## Device (`lib/features/devices/models/device.dart`)

`Device` fields:

- **Identity:** `id` (UUID v4, generated if omitted), `name`.
- **Category:** `category` (`DeviceCategory`: `desktop`, `laptop`, `phone`, `tablet`,
  `headphone`, `watch`, `router`, `gameConsole`, `vps`, `devBoard`, `other`), `emoji`,
  `imagePath`, `brand`, `model`, `serialNumber`.
- **CPU/GPU:** `cpu` (`CpuInfo`: `model`, `architecture`, `frequency`,
  `performanceCores`, `efficiencyCores`, `threads`, `cache`, plus `extraJson`), `gpu`
  (`GpuInfo`: `model`, `architecture`, plus `extraJson`).
- **RAM:** `ram` (free-text size string), `ramType` (`RamType`: `ddr3`, `lpddr3`, `ddr4`,
  `lpddr4`, `lpddr4x`, `ddr5`, `lpddr5`, `lpddr5x`, `lpddr6`, each with a `displayName`
  getter like `'LPDDR5X'`).
- **Storage:** `storage` (`List<StorageInfo>`; each `StorageInfo` has `capacity`, `type`
  (`StorageType`: `ssd`, `sdCard`, `hdd`), `interface_` (`StorageInterface`: `m2Nvme`,
  `sata25`, `m2Sata`, `usb`), `serialNumber`, `brand`, plus `extraJson`).
  `StorageInfo.fromJson` also accepts a legacy plain-string format (e.g. `"512 GB"`) for
  backward compatibility.
- **Display/battery/OS:** `screenSize`, `screenResolutionW`, `screenResolutionH`,
  `battery`, `os`. A derived `ppi` getter computes pixel density from resolution and
  parsed screen diagonal.
- **Location:** `locationName`, `latitude`, `longitude` (used by
  [Map](features/map.md)).
- **Lifecycle/finance** (added in `v0.4.0`):
  - `purchaseDate`, `releaseDate`, `acquisitionType` (`DeviceAcquisitionType`:
    `purchased`, `leased`, `purchasedWithSubscription`, `other`).
  - `isRetired`, `retiredDate`; `isSold`, `soldPrice` (`MoneyValue`).
  - `purchasePrice` (`MoneyValue`).
  - `recurringCosts` (`List<DeviceRecurringCost>`; each has `id`, `kind`
    (`RecurringCostKind`: `lease`, `insurance`, `subscription`, `other`), `name`, `price`
    (`MoneyValue`), `billingCycle` (`BillingCycle`: `monthly`, `yearly`)).
  - Derived getters: `lifecycleStatus` (`DeviceLifecycleStatus`: `inService`, `retired`,
    `sold` — sold takes priority over retired), `hasFinancialData`, `serviceDays()`,
    `recurringCostThrough()`, `totalCost()` (`purchasePrice + accrued recurring costs -
    soldPrice`), `averageDailyCost()`.
- **Other:** `notes`, `modifiedAt` (UTC `DateTime`), `extraJson`.

`MoneyValue` (currency conversion wrapper used by `purchasePrice`, `soldPrice`, and each
recurring cost's `price`): `amount`, `currency`, `defaultCurrency`, `convertedAmount`,
`exchangeRate`, `autoRate`, `rateUpdatedAt`, plus `extraJson`.

## Network / NetworkDevice (`lib/features/network/models/network.dart`)

- **`Network`:** `id`, `name`, `type` (`NetworkType`: `lan`, `tailscale`, `zerotier`,
  `easytier`, `wireguard`, `other`), `subnet`, `gateway`, `dnsServers` (`List<String>`),
  `notes`, `modifiedAt`, `extraJson`.
- **`NetworkDevice`:** an assignment between a network and a device — `networkId`,
  `deviceId`, `addressMode` (`AddressMode`: `dhcp`, `static_` — serialized as `"dhcp"` /
  `"static"`), `ipAddress`, `hostname`, `isExitNode`, `extraJson`.

`NetworkDevice` **intentionally has no `id` and no `modifiedAt` field** — confirmed in
source: its constructor takes only `networkId`, `deviceId`, `addressMode`, `ipAddress`,
`hostname`, `isExitNode`, `extraJson`. Its identity is the **composite key**
`(networkId, deviceId)`, and because there is no timestamp, sync merge compares
*serialized JSON content* against the last-synced base snapshot instead of comparing
`modifiedAt` values. See [WebDAV Sync](sync.md#networkdevice-composite-key-merge) and
[Three-Way Merge](algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge).

`NetworkData` (top-level container) holds `networks: List<Network>` and
`assignments: List<NetworkDevice>` plus `extraJson`.

## DataSet / DataSetStorageLink (`lib/features/datasets/models/dataset.dart`)

- **`DataSet`:** `id`, `name`, `emoji` (defaults to `'📁'` on parse if absent),
  `storageLinks` (`List<DataSetStorageLink>`), `modifiedAt`, `extraJson`.
- **`DataSetStorageLink`:** `deviceId` plus `storageIndices` (`List<int>`) — the storage
  slot *indices* on that device's `storage` list that belong to this dataset. See
  [Datasets](features/datasets.md) for how these indices are kept valid when a device's
  storage list changes.

## ServiceNode / ServiceEndpoint / ServiceRoute / ServiceRouteHop (`lib/features/services/models/service.dart`)

- **`ServiceNode`:** a service instance on a device — `id`, `deviceId`, `name`,
  `templateId`, `icon`, `kind` (`ServiceKind`: `web`, `reverseProxy`, `tunnel`, `media`,
  `storage`, `git`, `dev`, `game`, `network`, `database`, `monitoring`, `ai`, `custom`),
  `runtime` (`ServiceRuntime`: `docker`, `compose`, `native`, `systemd`, `launchd`,
  `routerApp`, `container`, `custom`), `state` (`ServiceState`: `active`, `paused`,
  `deprecated`, `unknown`), `endpoints` (`List<ServiceEndpoint>`), `tags`, `notes`,
  `dockerCompose` (plain text), `modifiedAt`, `extraJson`.
- **`ServiceEndpoint`:** a manually recorded local/listening endpoint — `id`, `label`,
  `protocol` (`ServiceProtocol`: `http`, `https`, `tcp`, `udp`, `ssh`, `minecraft`,
  `rtsp`, `vnc`, `custom`), `transport` (`ServiceTransport`: `tcp`, `udp`, `tcpUdp`),
  `bindAddress`, `port`, `portEnd` (for port ranges — `portText` getter renders
  `"$port-$portEnd"` when different, else `"$port"`), `path`, `networkId`, `scope`
  (`ServiceScope`: `localhost`, `lan`, `vpn`, `public`, `custom`), `isPrimary`, `notes`,
  `extraJson`.
- **`ServiceRoute`:** a manually recorded access path — `id`, `name`, `sourceServiceId`,
  `sourceEndpointId`, `hops` (`List<ServiceRouteHop>`), `finalUrl` (first/primary target,
  kept for backward compatibility), `accessLevel` (`ServiceAccessLevel`: `lan`, `vpn`,
  `authenticated`, `public`, `custom`), `notes`, `modifiedAt`, `extraJson`. Additional
  grouped URLs/domains sharing the same access path are stored in
  `extraJson['publicTargets']` (see [Services and Topology](features/services-topology.md)).
- **`ServiceRouteHop`:** one hop in a route — `id`, `type` (`ServiceRouteHopType`:
  `origin`, `reverseProxy`, `tunnel`, `portForward`, `publicEndpoint`,
  `internalEndpoint`, `dns`, `manual`), optional `serviceId`/`endpointId`/`deviceId`
  references back into inventory, or free-form `label`/`scheme`/`host`/`port`/`path`,
  `method` (`ServiceRouteMethod`: `caddy`, `nginx`, `traefik`, `frp`,
  `cloudflareTunnel`, `pangolin`, `tailscaleFunnel`, `routerPortForward`, `direct`,
  `custom`), `notes`, `extraJson`.

`ServiceData` (top-level container) holds `services: List<ServiceNode>` and
`routes: List<ServiceRoute>` plus `extraJson`.

## `extraJson`: unknown-field preservation

Every model above carries an `extraJson` field populated by
`unknownJsonFields(json, knownKeys)` in `lib/shared/utils/json_preservation.dart`:

```dart
Map<String, dynamic> unknownJsonFields(
  Map<String, dynamic> json,
  Set<String> knownKeys,
) => {
  for (final entry in json.entries)
    if (!knownKeys.contains(entry.key)) entry.key: entry.value,
};
```

Every model's `toJson()` spreads `extraJson` first (`...extraJson, 'id': id, ...`), so
extra fields round-trip even through models the current app build doesn't know about
(e.g. a field a newer version added). Each model's known-key set is declared as a
top-level `const _xxxJsonKeys = {...}` constant next to the class (e.g.
`_deviceJsonKeys`, `_networkDeviceJsonKeys`, `_serviceNodeJsonKeys`).

When two sides of a sync both changed a record's `extraJson`, `mergeUnknownJsonFields()`
(same file) reconciles per-key using the three-way base:

```dart
Map<String, dynamic> mergeUnknownJsonFields({
  required Map<String, dynamic> primary,
  required Map<String, dynamic> secondary,
  Map<String, dynamic>? base,
})
```

For each key across `primary`/`secondary`/`base`: if only `secondary` changed the key
relative to `base`, its value wins; otherwise `primary` wins (including when both
changed — primary is whichever side the caller treats as the "winning" record for that
merge). `jsonValueEquals()` compares values via a canonicalized (recursively key-sorted)
JSON encoding so map key order never causes a false "changed" detection. Every model's
own `mergeUnknownFieldsFrom(other, {base})` method (e.g. `Device.mergeUnknownFieldsFrom`,
`ServiceNode.mergeUnknownFieldsFrom`) calls this helper and recurses into nested models
(e.g. `Device` merges `cpu`, `gpu`, each `storage` slot by index, `purchasePrice`,
`soldPrice`, and each `recurringCosts` entry). See
[Three-Way Merge](algorithms/three-way-merge.md) for how this plugs into full-record
merge.

## Bundled device templates (`assets/presets/device_templates.json`)

A read-only asset shipped inside the app, loaded by `PresetService.loadTemplates()` and
parsed by `DeviceTemplate.fromJson`. Unlike the persisted formats above it never syncs
and users cannot edit it; changing the catalog requires an app update.

Note the shape asymmetry: `cpus.json`, `gpus.json` and `brands.json` wrap their array in
an object (`{"cpus": [...]}`), while this file is a **bare array**.

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | Yes | Display name; must be unique, and the file is sorted by its lowercased value. |
| `category` | string | Yes | One of the `DeviceCategory` values. An unknown value degrades silently to `other`. |
| `brand` | string | No | |
| `model` | string | No | |
| `cpu` | string **or** object | No | See both forms below. |
| `gpu` | string | No | Only the string form is read. |
| `ram` | string | No | e.g. `"12 GB"`. |
| `storage` | array | No | One or more capacities; each a string or an object with `capacity`. |
| `screenSize` | string | No | e.g. `"16.2\""`. |
| `screenResolutionW` / `screenResolutionH` | integer | No | |
| `battery` | string | No | e.g. `"100 Wh"` or `"4800 mAh"`. |
| `os` | string | No | |
| `releaseDate` | string | No | ISO-8601; parsed with `DateTime.parse`. |

The plain form, used by most entries:

```json
{
  "name": "MacBook Pro 16\" (M4 Pro)",
  "category": "laptop",
  "brand": "Apple",
  "cpu": "Apple M4 Pro",
  "storage": ["512 GB", "1 TB", "2 TB", "4 TB"]
}
```

The object form, used by the VPS entries, which carry detail for chips deliberately
absent from `cpus.json`:

```json
{
  "name": "Hetzner CX22",
  "category": "vps",
  "cpu": { "model": "Intel Xeon", "architecture": "x86_64", "performanceCores": 2 },
  "storage": [{ "capacity": "40 GB", "type": "ssd" }]
}
```

`DeviceTemplate` keeps both: `cpu` holds the model string, and `cpuDetail` holds the full
`CpuInfo` when the object form was used. `toDevice()` prefers `cpuDetail`, then an exact
match in `cpuPresets`, then the bare model string.

**Adding a device:** append the entry, run `dart run tool/sort_templates.dart` to restore
the sort order, then `dart run tool/validate_json.dart`. The validator checks required
fields, types, the category enum, duplicate names and the sort order — an unsorted or
malformed file fails there rather than in the app.

## UTC `modifiedAt`

Every model with a `modifiedAt` field defaults it to `DateTime.now().toUtc()` in its
constructor and `copyWith()`, and serializes it via `.toIso8601String()`. This is
required for sync conflict detection to work correctly across devices in different
timezones (see [Architecture](architecture.md#core-architecture-rules)). `NetworkDevice`
is the sole model with no `modifiedAt` at all, by design (see above).

## Persisted Data Inventory

(Reproduced from `AGENTS.md`, verified field/key names above.)

| Data | File | Synced | Merge strategy |
| --- | --- | --- | --- |
| Devices | `device_data.json` | Yes | Per-record by `id` and `modifiedAt` |
| Networks | `network_data.json` | Yes | Per-record by `id` and `modifiedAt` |
| Network assignments | `network_data.json` | Yes | Composite key plus content comparison |
| Datasets | `dataset_data.json` | Yes | Per-record by `id` and `modifiedAt` |
| Services and service routes | `service_data.json` | Yes | Per-record services/routes by `id` and `modifiedAt` |
| Images | `images/` | Yes | Referenced-only filename comparison |
| Theme, locale, backup settings, sort preferences, list column preferences, default currency, exchange-rate settings | `storage_config.json` | No | Local preference |
| WebDAV credentials | `webdav_config.json` | No | Local secret/config only |
| Sync base snapshots | `.sync_base/*.json` | No | Local merge tracking |
| Backups | `backups/backup_*.json` | No | Local recovery; v2 bundles reference deduplicated image blobs |
| Backup image blobs | `backups/blobs/` | No | Content-addressed (`sha256`), shared across backups, reference-counted GC |
| Exchange-rate cache | `exchange_rates.json` | No | Local cache/fallback data |

The default app data directory is `Documents/MyDevice` on desktop or the platform app
documents directory on mobile. Custom storage paths are stored in `storage_config.json`;
changing the path migrates data files, backups, and images (see
[Architecture](architecture.md#core-architecture-rules), `DeviceStorage.getAppDir()`).

- **`storage_config.json`** — local, unsynced preferences (theme, locale, backup
  settings, sort preferences, default currency, exchange-rate settings, custom storage
  path, tray/minimize/close-to-tray flags, local API port/credentials, and the four list
  column preferences `deviceListColumns`, `networkListColumns`, `dataSetListColumns` and
  `serviceListColumns` — an integer 1–4 when pinned, absent when auto; see
  [Adaptive Layout](adaptive-layout.md#how-many-columns)).
- **`webdav_config.json`** — local WebDAV credentials/config only; never synced.
- **`.sync_base/`** — per-data-file base snapshots (`device_data.json`,
  `network_data.json`, `dataset_data.json`, `service_data.json`) from the last
  successful sync, used for three-way merge; also holds `upload_lock.json`, the local
  record of an in-flight upload used to detect an interrupted upload on next launch. See
  [WebDAV Sync](sync.md).
- **`backups/`** — see [Backup and Restore](backup-restore.md) for the full v2 bundle
  format and blob store layout.

## Cross-reference rules

- Deleting a device must remove related network assignments, dataset storage links,
  service records, and service route references.
- Retiring or selling a device should also remove it from assignments/links and pickers
  (see [Devices](features/devices.md)).
- Deleting a network filters assignments in `NetworkStorage.deleteNetwork()`.
- Deleting a dataset deletes its contained storage links.
- **Known limitation:** sync merge does not currently run full cross-reference
  validation after merging (see [WebDAV Sync](sync.md#known-limitation)).
