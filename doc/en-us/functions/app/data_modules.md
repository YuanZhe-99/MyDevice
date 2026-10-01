# lib/app/data_modules.dart

**The seam between this app and the shared `myapps_data` package**, and the single source of truth
for MyDevice's four data files. The hardcoded `_dataFileNames` list and the backup module map now
both read from the registry declared here. The library comment also records (since 1.6.0) that
`ai_insights.json`, the on-device AI cache
([`ai_insights_cache.md`](../features/ai/services/ai_insights_cache.md)), is deliberately **not** a
module here: it is device-local and never synced, backed up or exported.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`DeviceStorageAdapter`](#devicestorageadapter) | class | A | Implements the package's `StorageAdapter` over `DeviceStorage`. |
| [`deviceDefaultRemotePath`](#constants) | constant | A | `'/MyDevice'`. |
| [`deviceArchiveNamePrefix`](#constants) | constant | A | `'mydevice_export_'`. |
| [`deviceDataFileName`](#constants) | constant | A | `'device_data.json'`. |
| [`deviceModuleId`](#constants) | constant | A | `'devices'`. |
| [`networkDataFileName`](#constants) | constant | A | `'network_data.json'`. |
| [`dataSetDataFileName`](#constants) | constant | A | `'dataset_data.json'`. |
| [`serviceDataFileName`](#constants) | constant | A | `'service_data.json'`. |
| [`deviceReferencedImages(json)`](#devicereferencedimages) | function | A | Device image basenames referenced by records. |
| [`buildDevicesModule()`](#modules) | function | A | The devices `DataModule` (the only image source). |
| [`buildNetworksModule()`](#modules) | function | A | The networks `DataModule`. |
| [`buildDataSetsModule()`](#modules) | function | A | The datasets `DataModule`. |
| [`buildServicesModule()`](#services) | function | A | The services `DataModule` (two record containers). |
| [`deviceModuleRegistry`](#registry) | field | A | The app's ordered `ModuleRegistry`. |

## Documentation

### `class DeviceStorageAdapter` <a id="devicestorageadapter"></a>
- **Purpose:** Give the shared engines a storage root and `storage_config.json` access without the
  package knowing anything about `DeviceStorage`.
- **Constructor:** `const DeviceStorageAdapter({Future<Directory> Function()? appDir})`.
- **Methods:** `getAppDir()`, `readConfig()`, `writeConfig(config)`, all delegating to the hub.
  The config pair always reads and writes the one `storage_config.json` in the platform default
  folder, whatever the storage path, and `writeConfig` cannot change the `storagePath` key (see
  [`DeviceStorage.writeConfig`](../features/devices/services/device_storage.md#writeconfig)).
- **Notes:** The optional `appDir` resolver exists so `BackupService` can keep honoring its
  `@visibleForTesting appDirProvider`. It is consulted on every call. `DeviceStorage.getAppDir()`
  resolves against the in-memory custom path, which `setStoragePath` updates, so a custom
  storage-path change is picked up immediately.

### Constants <a id="constants"></a>
- **Notes:** File names and module ids are persisted compatibility contracts — an older build and a
  newer one must interoperate against the same WebDAV server and the same backup bundles. Never
  change them. The four `*DataFileName` constants are the only place the data-file names are
  written: the module builders here use them, and so do the storage hubs —
  `DeviceStorage._dataFileName`, `NetworkStorage._dataFileName`, `DataSetStorage._dataFileName`
  and `ServiceStorage.dataFileName` are aliases of `deviceDataFileName`, `networkDataFileName`,
  `dataSetDataFileName` and `serviceDataFileName`.

### `deviceReferencedImages(json)` <a id="devicereferencedimages"></a>
- **Returns:** Image basenames from `Device.imagePath`; an empty set for malformed input.
- **Notes:** Devices are MyDevice's only image source. The engine unions the local and remote results,
  reproducing the previous rule: sync images referenced by either side, never orphans.

### Single-container modules <a id="modules"></a>
- **Purpose:** Devices, networks, and datasets each wrap one merge function producing one record
  container, so they share a private builder.
- **Notes:** `buildNetworksModule` wraps `mergeNetworkData`, which internally also runs
  `mergeAssignments` — MyDevice's composite-key, timestamp-free merge for `NetworkDevice` records.
  That stays app-side. All three encode with `JsonEncoder.withIndent('  ')` to match the hubs' local
  save format, so an unchanged file still hits the raw-equality fast path on the next sync.

### `buildServicesModule()` <a id="services"></a>
- **Notes:** Built directly rather than through the shared builder, because services merge two record
  containers (nodes and routes). `ServiceMergeResult.buildResolved` already disambiguates a shared ID
  by runtime type, so plain record IDs remain valid resolution keys and no namespacing is needed.

### `deviceModuleRegistry` <a id="registry"></a>
- **Notes:** Order is devices, networks, datasets, services — matching the previous `_dataFileNames`
  list. Order is behaviorally significant for sync order, progress reporting, and backup key order.

## Where the contract documentation lives

`packages/myapps_data/doc/en-us/functions/src/modules/data_module.md` and
`packages/myapps_data/doc/en-us/functions/src/storage/storage_adapter.md`.

## Profile module (since 1.7.0)

`profile.json` (the synced display name and avatar) is the fifth module, appended **last** to
`deviceModuleRegistry` so the indices of the existing four stay unchanged. New declarations:

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `profileFileName` | constant | B | Local and remote name of the profile file, `'profile.json'` (frozen, I1/I2). |
| `profileModuleId` | constant | B | Backup bundle module key, `'profile'` (frozen, I2). |
| `validateProfileJson(json)` | function | A | Throw unless the payload is a JSON object; the model is tolerant inside it. |
| `profileReferencedImages(json)` | function | A | Return the avatar's basename (or an empty set; malformed input also yields an empty set), so the avatar travels through the engine's image phase with the device images. |
| `buildProfileModule()` | function | A | Build the profile `DataModule`: the merge is `mergeProfileJson` and is conflict-free (per-field last writer wins), so `baseJson` and `autoResolve` are unused and the module never reaches the conflict dialog. |

Builds older than 1.7.0 never request the file, so adding the module leaves them unaffected; every
sync costs one extra `GET profile.json`. See [features/profile.md](../../features/profile.md) and
[../../sync.md](../../sync.md).
