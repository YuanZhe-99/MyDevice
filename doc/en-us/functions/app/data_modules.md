# lib/app/data_modules.dart

**The seam between this app and the shared `myapps_data` package**, and the single source of truth
for MyDevice's four data files. The hardcoded `_dataFileNames` list and the backup module map now
both read from the registry declared here.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`DeviceStorageAdapter`](#devicestorageadapter) | class | A | Implements the package's `StorageAdapter` over `DeviceStorage`. |
| [`deviceDefaultRemotePath`](#constants) | constant | A | `'/MyDevice'`. |
| [`deviceArchiveNamePrefix`](#constants) | constant | A | `'mydevice_export_'`. |
| [`deviceDataFileName`](#constants) | constant | A | `'device_data.json'`. |
| [`deviceModuleId`](#constants) | constant | A | `'devices'`. |
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
- **Notes:** The optional `appDir` resolver exists so `BackupService` can keep honoring its
  `@visibleForTesting appDirProvider`. It is consulted on every call. `DeviceStorage.getAppDir()`
  re-reads its config each call, so a custom storage-path change is picked up immediately.

### Constants <a id="constants"></a>
- **Notes:** File names and module ids are persisted compatibility contracts — an older build and a
  newer one must interoperate against the same WebDAV server and the same backup bundles. Never
  change them.

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
