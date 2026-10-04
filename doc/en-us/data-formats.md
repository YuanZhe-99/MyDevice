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
  `imagePath`, `templateImage`, `brand`, `model`, `serialNumber`. `templateImage` (since 1.6.1,
  optional, omitted when null) is the bundled thumbnail the user chose by hand, written exactly as
  a template's `image` (`assets/device_images/<file>.png`). Older builds keep it through
  `extraJson` and fall back to automatic matching.
- **CPU/GPU:** `cpu` (`CpuInfo`: `model`, `architecture`, `frequency`,
  `performanceCores`, `efficiencyCores`, `threads`, `cache`, plus `extraJson`), `gpu`
  (`GpuInfo`: `model`, `architecture`, plus `extraJson`).
- **RAM:** `ram` (free-text size string), `ramType` (`RamType`: `ddr3`, `lpddr3`, `ddr4`,
  `lpddr4`, `lpddr4x`, `ddr5`, `lpddr5`, `lpddr5x`, `lpddr6`, each with a `displayName`
  getter like `'LPDDR5X'`).
- **Storage:** `storage` (`List<StorageInfo>`; each `StorageInfo` has `capacity`, `type`
  (`StorageType`: `ssd`, `sdCard`, `hdd`), `interface_` (`StorageInterface`: `m2Nvme`,
  `sata25`, `m2Sata`, `usb`), `serialNumber`, `brand`, `status` (`StorageHealth`: `ok`,
  `failed`, `offline`; since 1.8.2, written only when not `ok`), `statusNote` (since 1.8.2),
  plus `extraJson`). `StorageInfo.fromJson` also accepts a legacy plain-string format (e.g.
  `"512 GB"`) for backward compatibility; a `status` value it does not know reads as `ok` and is
  kept in `extraJson`, so a newer build's value survives a save.
- **RAID arrays** (since 1.8.2): `storageArrays` (`List<StorageArray>`, omitted when empty); each
  has `id` (UUID, stable — data sets link to it), `name` (omitted when empty), `level`
  (`RaidLevel`: `raid0`, `raid1`, `raid5`, `raid6`, `raid10`, `raidz1`, `raidz2`, `raidz3`,
  `jbod`, `other`), `memberIndices` (`List<int>`, indices into `storage`), plus `extraJson`. A
  drive belongs to at most one array (the editor enforces it). `Device.mergeUnknownFieldsFrom`
  merges arrays' unknown fields by `id`. Older builds keep the whole `storageArrays` key, and
  `status`/`statusNote` inside each storage entry, through `extraJson`.
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
  slot *indices* on that device's `storage` list that belong to this dataset — and, since 1.8.2,
  `arrayIds` (`List<String>`, omitted when empty) — ids of that device's `storageArrays`. Every
  listed slot and every listed array holds a full, equal copy of the data set — a data set is never
  split across storages, and an array is one copy however many drives it spans — so the number of
  resolvable places is its copy count. A copy on a failed or offline drive, or on an array that lost
  more drives than its level tolerates, still counts towards that number but not towards the
  *usable* copies. An older build keeps `arrayIds` through `extraJson` but does not count those
  copies. See
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
  Since 1.5.6 a route may also carry `extraJson['accessLane']`, which pins the lane the
  topology draws it in (see [below](#app-written-extrajson-keys)).
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

### App-written `extraJson` keys

Two `ServiceRoute` keys are written by the app itself rather than being fields of the model.
Both are optional and additive, so a build that does not know them keeps them through the
mechanism above and behaves exactly as it did before they existed:

| Key | Value | Written by | Meaning |
|---|---|---|---|
| `publicTargets` | list of strings | both route editors, when a route has more than one target | Every access target of the route, first one equal to `finalUrl`. |
| `accessLane` | `"local"`, `"vpn"` or `"public"` | the guided access-path page (always, from the chosen reachability); the advanced editor's lane dropdown (removed again by *Auto*) | Pins the topology lane the route is drawn in. Added in 1.5.6. |

`serviceAccessLaneForRoute` reads `accessLane` first and falls back to the pre-1.5.6
inference — a public-style hop method (FRP, router port forward, Caddy, Nginx, Traefik,
Cloudflare Tunnel, Pangolin) means public whatever the access level, then Tailscale Funnel or a
`vpn` access level means VPN, then a `public` or `authenticated` access level means public, and
anything else is local. An absent or unknown value means that inference, unchanged, so older
routes and older builds keep drawing every route where they always did. The key exists because
the inference cannot express a LAN-only reverse proxy (Caddy with split DNS): its method alone
makes it public.

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

Optional `image` names a bundled thumbnail of the device itself:

```json
{ "name": "iPhone 15 Pro", "category": "phone", "brand": "Apple", "model": "iPhone 15 Pro",
  "image": "assets/device_images/apple-iphone-15-pro-back.png" }
```

Thumbnails are 256 px square PNGs with a transparent background, and every visible pixel
(alpha > 8) lies inside the inscribed circle, because each avatar clips to that circle. They are
matched to devices at display time; only a thumbnail the user chose by hand is stored, as the
device's `templateImage`. A device created from a template stores the template's `image` there
too (see [Online Search and Presets](features/online-search-and-presets.md#device-thumbnails)).

**Adding a device:** append the entry, run `dart run tool/sort_templates.dart` to restore
the sort order, then `dart run tool/validate_json.dart`. The validator checks required
fields, types, the category enum, duplicate names and the sort order — an unsorted or
malformed file fails there rather than in the app. For `image` it also checks the path,
the transparent corners and the inside-the-circle rule.

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
| Profile (display name and avatar) | `profile.json` | Yes | Per-field last writer wins by `displayNameUpdatedAt` / `avatarUpdatedAt` (since 1.7.0); never conflicts |
| Images and avatar | `images/` | Yes | Referenced-only filename comparison; includes the profile avatar |
| Theme, interface style (`uiStyle`), navigation position (`navPlacement`, `navRailRight`), locale, backup settings, sort preferences, data set grouping (`datasetGroupMode`), home status filter, list column preferences, default currency, exchange-rate settings, on-device AI switches, custom storage path | `storage_config.json` (default folder) | No | Local preference |
| WebDAV credentials | `webdav_config.json` | No | Local secret/config only |
| Sync base snapshots | `.sync_base/*.json` | No | Local merge tracking |
| Backups | `backups/backup_*.json` | No | Local recovery; v2 bundles reference deduplicated image blobs |
| Backup image blobs | `backups/blobs/` | No | Content-addressed (`sha256`), shared across backups, reference-counted GC |
| Exchange-rate cache | `exchange_rates.json` | No | Local cache/fallback data |
| On-device AI insights | `ai_insights.json` | No | Per-device cache of generated insight cards (v1.6.0); never synced, backed up or exported; rebuildable, so an unreadable file reads as empty |

The default app data directory is `Documents/MyDevice` on desktop or the platform app
documents directory on mobile. Custom storage paths are stored in `storage_config.json`, which
itself always stays in the default folder; changing the path moves everything else in the storage
folder — data files, backups, images, `.sync_base/`, `webdav_config.json`, `ai_insights.json` — and reports anything
it left behind (see [`storage_config.json`](#storage_configjson),
[Architecture](architecture.md#core-architecture-rules), `DeviceStorage.getAppDir()`).

- **`storage_config.json`** — one file in the platform default folder (see
  [below](#storage_configjson)) holding the local, unsynced preferences (theme, locale, backup
  settings, sort preferences, the data set list's grouping `datasetGroupMode` (absent when not
  grouped; see [below](#storage_configjson-key-datasetgroupmode)), the home list's last status filter `deviceStatusFilter` (absent
  when "All"), default currency, exchange-rate settings, custom storage
  path, tray/minimize/close-to-tray flags, local API port/credentials, and the four list
  column preferences `deviceListColumns`, `networkListColumns`, `dataSetListColumns` and
  `serviceListColumns` — an integer 1–4 when pinned, absent when auto; see
  [Adaptive Layout](adaptive-layout.md#how-many-columns)), and the on-device AI switches
  `onDeviceAiEnabled` and `onDeviceAiPreferFast` (v1.6.0) — written only when `true` and removed
  when switched off, device-local because whether a model exists is a property of the device; see
  [On-device AI](on-device-ai.md)).
- **`webdav_config.json`** — local WebDAV credentials/config only; never synced.
- **`.sync_base/`** — per-data-file base snapshots (`device_data.json`,
  `network_data.json`, `dataset_data.json`, `service_data.json`) from the last
  successful sync, used for three-way merge; also holds `upload_lock.json`, the local
  record of an in-flight upload used to detect an interrupted upload on next launch. See
  [WebDAV Sync](sync.md).
- **`backups/`** — see [Backup and Restore](backup-restore.md) for the full v2 bundle
  format and blob store layout.

### `storage_config.json` <a id="storage_configjson"></a>

- **One file, in the default folder.** `storage_config.json` always lives in the platform default
  folder (`Documents/MyDevice` on desktop), whatever the storage path, because the app must read
  the custom path before it knows where the data is. It holds every local preference *and* the
  custom path (`storagePath`). `DeviceStorage.readConfig`/`writeConfig`, and the
  `DeviceStorageAdapter` the shared engines use, all read and write this one file, so moving the
  data never resets or duplicates a preference.
- **`storagePath` belongs to `setStoragePath`.** A preference write replaces whatever the map
  holds under `storagePath` with the current custom path, or drops the key when there is none, so
  saving a theme or a column choice can never move or lose the data.
- **Adopting a stray copy (1.5.7).** Before 1.5.7, `readConfig`/`writeConfig` used the current
  storage folder while the custom path lived in the default one, so after a move the preferences
  read as defaults and new ones went into a second `storage_config.json` in the custom folder.
  The first config access for a given custom path now checks that folder: a stray
  `storage_config.json` there is merged into the default file — its keys win, being the newer
  ones, except `storagePath` — and deleted. A stray file that cannot be read or parsed is left
  alone.
- **Changing the storage path.** Everything in the old folder except the top-level
  `storage_config.json` moves to the new one (see
  [`DeviceStorage.setStoragePath`](functions/features/devices/services/device_storage.md#setstoragepath)).
  A file already present at the destination wins and its source copy stays put. Every file left
  in the old folder — one that failed to copy, or one skipped because the destination already had
  a file of that name — is reported back, and Settings lists them with the old folder's path,
  because the app cannot see them at the new location.

## `profile.json` <a id="profilejson"></a>

`profile.json` (1.7.0) is the fifth registered module, so it also syncs, is backed up, is included in
ZIP export, and has its own `.sync_base/profile.json`. It holds the user's display name and avatar
(see [`features/profile.md`](features/profile.md)):

```json
{
  "version": 1,
  "displayName": "Yuan",
  "displayNameUpdatedAt": "2026-10-01T14:06:42.530801Z",
  "avatar": "images/avatar_2953ac52-337e-4271-a8e1-bcd97ee416ba.jpg",
  "avatarUpdatedAt": "2026-10-01T14:08:59.163627Z"
}
```

- `displayName` / `displayNameUpdatedAt` — the name and when it last changed (UTC). Trimmed on save;
  clearing it writes `"displayName": null` with a new timestamp.
- `avatar` / `avatarUpdatedAt` — the avatar as a path relative to the data directory
  (`images/avatar_<uuid>.jpg`, a 512 x 512 JPEG) and when it last changed (UTC). A removed avatar is
  written as an explicit `"avatar": null` with its timestamp, so the removal syncs.
- A field is written only once it has a timestamp; a field with no timestamp means "never set" and
  always loses a merge to one that was set. Each field merges by last writer wins, independently of
  the other — see [`sync.md`](sync.md#the-profile-file). Unknown keys survive. `version` is `1`.
- The avatar image is an ordinary file in `images/`, so it syncs through the engine's referenced-only
  additive image phase (the module reports it through `profileReferencedImages`), and is backed up and
  exported with the other images. Each new avatar gets a fresh file name, because image sync never
  overwrites an existing file; replaced avatars are deleted locally only, so old ones remain on the
  WebDAV server and other devices.
- Builds older than 1.7.0 never request `profile.json`, so it does not affect them.

### `storage_config.json` key `uiStyle`

Since 1.7.0 `storage_config.json` may hold `"uiStyle": "material3"`. Only the non-default Material 3
style is stored; the default Expressive style (floating navigation bar, rounder shapes, bolder
titles) is the absence of the key. Local preference, never synced.

### `storage_config.json` keys `navPlacement`, `navRailRight`

Since 1.7.1 `storage_config.json` may hold two optional keys that place the navigation. Each is written **only when it differs from the default** and removed otherwise, so a default install's config has neither. Local preferences, never synced.

| Key | Values | Meaning | Applies to |
|---|---|---|---|
| `navPlacement` | `"sideOnWide"`, `"side"` | Absent = bottom bar on every window (default). `"sideOnWide"` = side rail on wide windows, bar on narrow ones. `"side"` = side rail everywhere, phones included (not recommended). Unknown values read as the default. | Both styles |
| `navRailRight` | `true` | The side rail sits on the right instead of the left. | Both styles, whenever a rail shows |

### `storage_config.json` key `datasetGroupMode` <a id="storage_configjson-key-datasetgroupmode"></a>

Since 1.8.0 `storage_config.json` may hold `"datasetGroupMode"`: `"device"` or `"storage"` — how
the data set list groups its tiles. Written only when grouping is on and removed for *No
grouping*, so a default install's config has no such key; an unknown value reads as no grouping.
Local preference, never synced. The data set file itself is unchanged: a data set's copy count is
derived from its existing `storageLinks`.

## `ai_insights.json`

The on-device AI insight cache (v1.6.0), written atomically through `AiInsightsCache` with its own
write queue, in the storage folder (`DeviceStorage.getAppDir()`), so it moves with a custom storage
path. It is **not** a registered data module: never synced, never in a backup bundle or ZIP
export, and it has no preservation schema. Unlike the data files, an unreadable or malformed file
reads as empty — it is a cache, and losing it only costs one regeneration per card. *Clear
generated insights* in Settings deletes it.

```json
{
  "version": 1,
  "insights": {
    "deviceFinance": {
      "fingerprint": "3f9a…",
      "generatedAt": "2026-09-28T01:02:03.000Z",
      "language": "zh_CN",
      "lines": ["…", "…", "…", "…"],
      "model": "stable/full · nano-v3",
      "promptVersion": 1,
      "slots": ["costSummary", "costAdvice", "recurringSummary", "reviewDevice"],
      "status": "ok"
    }
  }
}
```

- Keys under `insights` are `deviceFinance` and `services`. Unknown keys and malformed entries are
  dropped on read.
- `fingerprint` is the hex SHA-256 described in
  [on-device-ai.md](on-device-ai.md#cache-and-fingerprint); a card regenerates only when it changes.
- `lines` holds the validated sentences in slot order and `slots` the slot id of each, so a card can
  group lines under its section headings even when an earlier slot was dropped.
- `status` is `ok`, or `skipped` when the model refused (`guardrail`) or cannot write the language;
  a skipped entry has no lines and is not retried until the fingerprint changes.
- `generatedAt` is UTC.

## Cross-reference rules

- Deleting a device must remove related network assignments, dataset storage links,
  service records, and service route references.
- Retiring or selling a device should also remove it from assignments/links and pickers
  (see [Devices](features/devices.md)).
- Deleting a network filters assignments in `NetworkStorage.deleteNetwork()`.
- Deleting a dataset deletes its contained storage links.
- **Known limitation:** sync merge does not currently run full cross-reference
  validation after merging (see [WebDAV Sync](sync.md#known-limitation)).

## Write safety (since 1.6.2)

The data files (`device_data.json`, `network_data.json`, `dataset_data.json`, `service_data.json`, and since 1.7.0 `profile.json`), `storage_config.json` and `exchange_rates.json` are replaced atomically: the new content goes to a same-folder `<name>.tmp-<microseconds>` file that is renamed over the target (retried briefly if Windows reports the target as locked). The data storages additionally serialise their read-modify-write operations per file path. The on-disk JSON shape and the sync/backup formats are unchanged; a stray `*.tmp-*` file can only remain after a crash and is safe to delete.
