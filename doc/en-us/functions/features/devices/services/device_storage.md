# lib/features/devices/services/device_storage.dart

`DeviceStorage` persists the device list (`device_data.json`) and also doubles as the app's
canonical storage-location/config service: `getAppDir()` is called by `DataSetStorage` and
`NetworkStorage` (`../../../network/services/network_storage.dart`,
`../../../datasets/services/dataset_storage.dart`) to resolve the *same* app directory those
modules' own data files live in, and `readConfig`/`writeConfig` back a small generic key/value
store (`themeMode`, `locale`, `defaultCurrency`, `autoUpdateExchangeRates`, list columns, etc.)
that `AppSettings` (`../../../../shared/providers/app_settings.md`) and
[`exchange_rate_service.md`](exchange_rate_service.md) also read/write through. That store is the
one `storage_config.json` in the platform default folder, which also holds the custom storage
path, so moving the data never touches the preferences; see
[Data Formats](../../../../data-formats.md#storage_configjson) for its rules. See
[Data Formats](../../../../data-formats.md) for the `DeviceData`/`Device` JSON shape this file
serializes, and [Devices](../../../../features/devices.md) for the cascade-delete rules
`deleteDevice`/`addOrUpdate` implement.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `DeviceStorage` | class | B | Static-only storage hub: the device list, the app directory, and `storage_config.json`. |
| `_dataFileName` | static const (private) | B | The device list's file name: `deviceDataFileName` (`'device_data.json'`) from `data_modules.dart`. |
| `_configFileName` | static const (private) | B | `'storage_config.json'`, the local preferences file name. |
| `_customPath` | static field (private) | B | Cached custom storage path; `null` means the default directory. |
| `_configLoaded` | static field (private) | B | Whether `_loadCustomPath` already ran in this process. |
| [`_getDefaultAppDir`](#_getdefaultappdir) | static method (private) | A | Resolve (and create) the default `~/Documents/MyDevice` directory. |
| [`_getConfigFile`](#_getconfigfile) | static method (private) | A | Resolve the `storage_config.json` file, always in the default directory. |
| [`_loadCustomPath`](#_loadcustompath) | static method (private) | A | Load the custom storage path from config, once per process. |
| [`getAppDir`](#getappdir) | static method | A | Resolve the app's data directory (custom path if configured, else default). |
| [`getStoragePath`](#getstoragepath) | static method | A | Return the current storage directory's display path. |
| [`setStoragePath`](#setstoragepath) | static method | A | Change the storage location, move the whole storage folder to it, and report what stayed behind. |
| [`_leftoverEntries`](#_leftoverentries) | static method (private) | A | List the files a storage move left in the old folder, except the top-level config. |
| `_strayCheckedFor` | static field (private) | B | The custom path whose folder was last checked for a stray `storage_config.json`. |
| [`_adoptStrayConfig`](#_adoptstrayconfig) | static method (private) | A | Merge a `storage_config.json` an older build left in the custom folder into the default one, then delete it. |
| [`_readConfigFromDefault`](#_readconfigfromdefault) | static method (private) | A | Read `storage_config.json` from the default directory — the only copy. |
| [`_writeConfigToDefault`](#_writeconfigtodefault) | static method (private) | A | Write `storage_config.json` to the default directory. |
| [`_getFile`](#_getfile) | static method (private) | A | Resolve a named file inside the current app directory. |
| [`load`](#load) | static method | A | Load the persisted `DeviceData` (device list). |
| [`save`](#save) | static method | A | Persist `DeviceData` and notify the auto-sync service. |
| [`addOrUpdate`](#addorupdate) | static method | A | Insert or replace a device by id; clean up references if it left service. |
| [`deleteDevice`](#deletedevice) | static method | A | Delete a device by id and clean up cross-module references. |
| [`_removeDeviceReferences`](#_removedevicereferences) | static method (private) | A | Strip network/dataset/service references to a device id. |
| [`readConfig`](#readconfig) | static method | A | Read the preferences map from the default folder's `storage_config.json`. |
| [`writeConfig`](#writeconfig) | static method | A | Write the preferences map to the default folder's `storage_config.json`, keeping `storagePath` owned by `setStoragePath`. |
| [`getThemeMode`](#getthememode) | static method | A | Read the persisted theme mode string. |
| [`setThemeMode`](#setthememode) | static method | A | Persist (or clear) the theme mode string. |
| [`getLocaleTag`](#getlocaletag) | static method | A | Read the persisted locale tag. |
| [`setLocaleTag`](#setlocaletag) | static method | A | Persist (or clear) the locale tag. |
| [`_getListColumns`](#getlistcolumns) | static method (private) | A | Read one list page's column preference from `storage_config.json`. |
| [`_setListColumns`](#setlistcolumns) | static method (private) | A | Persist one list page's column preference, removing the key for auto. |
| `getDeviceListColumns` | static method | B | `_getListColumns('deviceListColumns')`: the device list's column preference. |
| `setDeviceListColumns` | static method | B | `_setListColumns('deviceListColumns', columns)`. |
| `getNetworkListColumns` | static method | B | `_getListColumns('networkListColumns')`: the network list's column preference. |
| `setNetworkListColumns` | static method | B | `_setListColumns('networkListColumns', columns)`. |
| `getDataSetListColumns` | static method | B | `_getListColumns('dataSetListColumns')`: the dataset list's column preference. |
| `setDataSetListColumns` | static method | B | `_setListColumns('dataSetListColumns', columns)`. |
| `getServiceListColumns` | static method | B | `_getListColumns('serviceListColumns')`: one preference serves the devices, routes and ports views; the overview is always one column. |
| `setServiceListColumns` | static method | B | `_setListColumns('serviceListColumns', columns)`. |
| `StoragePathResult` | class | B | What `setStoragePath` did: whether the path was recorded and which entries the move left behind. |
| `saved` | field (`StoragePathResult`) | B | Whether the new path was recorded; false means nothing changed. |
| `unmoved` | field (`StoragePathResult`) | B | Relative paths the move left in the old folder; empty when everything moved or nothing had to. |
| `from` | field (`StoragePathResult`) | B | The old folder holding the unmoved entries; null when nothing was moved. |
| [`StoragePathResult`](#storagepathresult-new) | constructor | A | Create a result; `saved` defaults to true, `unmoved` to empty. |
| [`complete`](#complete) | getter (`StoragePathResult`) | A | Whether the change fully succeeded: saved and nothing left behind. |

Row count (44) is ten more than `grep -c '/// Purpose:' device_storage.dart` (34). Each of the 32
static methods, including each of the eight list-column accessors, has its own row and its own
`Purpose:` block, and so do the `StoragePathResult` constructor and its `complete` getter. The ten
extra rows are the `DeviceStorage` class itself, the private static consts `_dataFileName` and
`_configFileName`, the private static fields `_customPath`, `_configLoaded` and
`_strayCheckedFor`, the `StoragePathResult` class, and its fields `saved`, `unmoved` and `from`,
which carry an ordinary `///` description or none and are listed because every declaration
appears in the table. Tier A: 26 rows.

## Documentation

### `static Future<Directory> _getDefaultAppDir()` <a id="_getdefaultappdir"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 32).
- **Purpose:** Resolve the default `<Documents>/MyDevice` directory, creating it if missing.
- **Inputs:** None.
- **Returns:** `Future<Directory>`.
- **Side effects:** Creates the directory (recursively) if it doesn't already exist.
- **Algorithm:** `getApplicationDocumentsDirectory()` then join `'MyDevice'`; create recursively if
  absent.
- **Usage:** Called by [`getAppDir`](#getappdir) whenever no custom path is configured.
- **Notes:** This is the directory used before the user ever changes the storage location in
  Settings.

### `static Future<File> _getConfigFile()` <a id="_getconfigfile"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 47).
- **Purpose:** Resolve the `storage_config.json` file path, which always lives in the *default*
  app directory regardless of any configured custom storage path.
- **Inputs:** None.
- **Returns:** `Future<File>`.
- **Side effects:** None (does not create the file).
- **Algorithm:** Join `_getDefaultAppDir()`'s path with `_configFileName`.
- **Usage:** Called by [`_loadCustomPath`](#_loadcustompath), [`_adoptStrayConfig`](#_adoptstrayconfig),
  [`_readConfigFromDefault`](#_readconfigfromdefault), and
  [`_writeConfigToDefault`](#_writeconfigtodefault).
- **Notes:** Deliberately bypasses `getAppDir()`/any custom path — this file must be discoverable
  even if the custom path it names is itself invalid or on unmounted storage, otherwise the app
  could never recover the storage path setting.

### `static Future<void> _loadCustomPath()` <a id="_loadcustompath"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 58).
- **Purpose:** Load the custom storage path (if any) from `storage_config.json` into the static
  `_customPath` cache, exactly once per process.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads `storage_config.json`; sets the static `_customPath`/`_configLoaded`
  fields.
- **Algorithm:** 1. If `_configLoaded` is already true, return immediately (no re-read). 2.
  Otherwise, read and parse the config file inside a `try`/`catch` that swallows any error
  (missing file, malformed JSON), extracting `json['storagePath']`. 3. Set `_configLoaded = true`
  unconditionally, even on error, so a corrupt config file doesn't force a re-read attempt on every
  call.
- **Usage:** Called at the start of [`getAppDir`](#getappdir) and
  [`_adoptStrayConfig`](#_adoptstrayconfig).
- **Notes:** A malformed config file is treated the same as "no custom path" (falls back to
  default) rather than surfacing an error to the caller.

### `static Future<Directory> getAppDir()` <a id="getappdir"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 78).
- **Purpose:** Resolve the app's current data directory — the configured custom path if one is
  set and non-empty, otherwise the default `<Documents>/MyDevice` directory.
- **Inputs:** None.
- **Returns:** `Future<Directory>`.
- **Side effects:** Creates the resolved directory if it doesn't already exist.
- **Algorithm:** Ensure `_loadCustomPath()` has run; if `_customPath` is set and non-empty, return
  (creating if needed) that directory; otherwise delegate to `_getDefaultAppDir()`.
- **Usage:**
  ```dart
  final appDir = await DeviceStorage.getAppDir();
  ```
  (from `NetworkStorage`/`DataSetStorage`'s equivalent directory resolvers, and internally by every
  other method in this file) — `DeviceStorage.getAppDir()` is the single source of truth for where
  *all* of this app's data files live, not just device data.
- **Notes:** Because other feature storages call this same method, changing the storage path via
  [`setStoragePath`](#setstoragepath) moves every module's data, not just devices.

### `static Future<String> getStoragePath()` <a id="getstoragepath"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 96).
- **Purpose:** Return the current storage directory's absolute path, for display in Settings.
- **Inputs:** None.
- **Returns:** `Future<String>`.
- **Side effects:** None beyond `getAppDir()`'s directory-creation side effect.
- **Algorithm:** `(await getAppDir()).path`.
- **Usage:**
  ```dart
  final path = await DeviceStorage.getStoragePath();
  ```
  (from `settings_page.dart`, showing the current storage location)
- **Notes:** None.

### `static Future<StoragePathResult> setStoragePath(String? newPath)` <a id="setstoragepath"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 127).
- **Purpose:** Change the app's storage location, move everything in the old storage folder to
  the new one, and report what the move left behind.
- **Inputs:** `newPath` — the new custom path, or `null`/empty to revert to the default directory.
- **Returns:** `Future<StoragePathResult>` (see [`StoragePathResult`](#storagepathresult-new)) —
  `saved: false` only when an exception escapes (for example while reading or writing
  `storage_config.json`), in which case nothing changed; otherwise `saved: true`, with `unmoved`
  listing the relative paths still in the old folder and `from` naming that folder (empty and
  null when the path did not change).
- **Side effects:** May adopt a stray config first ([`_adoptStrayConfig`](#_adoptstrayconfig));
  sets `_customPath`; persists `storagePath` to the default directory's `storage_config.json`;
  moves the old folder's contents into the new one through `migrateStorageContents` from
  `myapps_data` (`packages/myapps_data/lib/src/storage/storage_migration.dart`).
- **Algorithm:** 1. `_adoptStrayConfig()`, so a stray copy in the current custom folder is merged
  before that folder is emptied. 2. Capture the current directory as `oldDir`. 3. Set
  `_customPath = newPath` and persist it into `storage_config.json` via
  [`_readConfigFromDefault`](#_readconfigfromdefault) /
  [`_writeConfigToDefault`](#_writeconfigtodefault), removing the key when `newPath` is null or
  empty. 4. Resolve `newDir` via `getAppDir()`, which creates it; if its path equals `oldDir`'s,
  return `const StoragePathResult()` (nothing to move). 5.
  `await migrateStorageContents(from: oldDir, to: newDir)`: every top-level file and directory
  except `storage_config.json` is copied file by file into `newDir` and each original deleted after
  its copy; source directories are removed only once empty. It returns the paths it failed to
  move. 6. Union those with [`_leftoverEntries(oldDir)`](#_leftoverentries) — which also catches
  the files skipped because the destination already had one of that name — sort, and return
  `StoragePathResult(unmoved: ..., from: oldDir.path)`. The whole body sits in a `try`/`catch`
  that returns `StoragePathResult(saved: false)`.
- **Usage:**
  ```dart
  final result = await DeviceStorage.setStoragePath(pathToSet);
  ```
  (from `settings_page.dart`'s "change storage location" flow, which shows a failure snackbar, a
  dialog listing `result.unmoved` under `result.from`, or the usual success snackbar — see
  [`_showStoragePathDialog`](../../settings/views/settings_page.md#_showstoragepathdialog))
- **Notes:** The move covers the whole folder rather than an enumerated list: all four data files,
  `images/`, `.sync_base/`, `backups/` including `backups/blobs/`, and `webdav_config.json`, so a
  data file added later moves automatically. It replaced per-directory copies that left
  `backups/blobs/` behind (restored backups lost their images) and missed `.sync_base/` entirely,
  which let the next sync treat records other devices had deleted as new local records and
  resurrect them. A file already present at the destination wins and its source copy is left in
  place, so nothing is discarded on a guess about which copy is newer — but that copy is no longer
  readable by the app, which is why it is reported with the failures. `storage_config.json` stays
  in the platform default directory: it holds the custom path itself and every other preference,
  and [`readConfig`](#readconfig)/[`writeConfig`](#writeconfig) always use that copy, so a move
  never touches the preferences. (Before 1.5.7 the preferences were read from the current storage
  folder and so looked reset after a move.) `test/storage_path_test.dart` covers preferences
  across a move and an entry left behind by an occupied destination.

### `static Future<List<String>> _leftoverEntries(Directory oldDir)` <a id="_leftoverentries"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 166).
- **Purpose:** List the files a storage move left in the old folder.
- **Inputs:** `oldDir` — the folder the data moved out of.
- **Returns:** `Future<List<String>>` — the path of every file still under `oldDir`, relative to
  it, except the top-level `storage_config.json`; empty when the folder is gone or cannot be
  listed.
- **Side effects:** Lists the folder (recursively, not following links).
- **Algorithm:** If `oldDir` does not exist, return `[]`. Otherwise walk
  `oldDir.list(recursive: true, followLinks: false)`, keep only `File` entities, and add each
  `p.relative(entity.path, from: oldDir.path)` unless it equals `_configFileName`. Any exception is
  swallowed and the list gathered so far returned.
- **Usage:** Called by [`setStoragePath`](#setstoragepath) after the move.
- **Notes:** `migrateStorageContents` reports files it failed to copy but not those it skipped
  because the destination already had a file of that name; both stay behind unseen by the app, so
  the old folder itself is the source of truth. Empty directories are not listed.

### `static Future<void> _adoptStrayConfig()` <a id="_adoptstrayconfig"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 198).
- **Purpose:** Adopt a `storage_config.json` that an older build wrote into the custom storage
  folder.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Sets `_strayCheckedFor`; may rewrite the default folder's
  `storage_config.json` and delete the stray file.
- **Algorithm:** 1. `_loadCustomPath()`. 2. Return when there is no custom path or when
  `_strayCheckedFor` already equals it; otherwise record it in `_strayCheckedFor`. 3. Inside a
  `try`/`catch` that swallows everything: resolve the stray file `<custom>/storage_config.json`;
  return if it is the default config file itself (`p.equals`) or does not exist. 4. Parse it (an
  empty file counts as `{}`), merge as `{...default, ...stray}` so the stray keys win, force
  `storagePath` back to the custom path, write the result through
  [`_writeConfigToDefault`](#_writeconfigtodefault), then delete the stray file.
- **Usage:** Called first by [`setStoragePath`](#setstoragepath), [`readConfig`](#readconfig) and
  [`writeConfig`](#writeconfig).
- **Notes:** Before 1.5.7 `readConfig`/`writeConfig` used the current storage folder while the
  custom path lived in the default one, so after a move the preferences seemed reset and new ones
  went into a second file in the custom folder; those are the newer values, hence they win.
  `storagePath` is the exception because only the default file may hold it. Checked once per
  custom path per process; a stray file that cannot be read or parsed is left in place (and not
  retried until the custom path changes or the app restarts).

### `static Future<Map<String, dynamic>> _readConfigFromDefault()` <a id="_readconfigfromdefault"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 228).
- **Purpose:** Read `storage_config.json` from the default directory — the only copy of the
  preferences and the custom path.
- **Inputs:** None.
- **Returns:** `Future<Map<String, dynamic>>` — `{}` if the file is absent or empty.
- **Side effects:** None (read-only).
- **Algorithm:** Existence check, empty-content check, then `jsonDecode`.
- **Usage:** Called by [`setStoragePath`](#setstoragepath), [`_adoptStrayConfig`](#_adoptstrayconfig)
  and [`readConfig`](#readconfig).
- **Notes:** Resolves through [`_getConfigFile`](#_getconfigfile), never `getAppDir()`: the
  storage-path setting must be findable regardless of what it currently points to, and keeping
  every preference beside it means a move never strands them.

### `static Future<void> _writeConfigToDefault(Map<String, dynamic> config)` <a id="_writeconfigtodefault"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 242).
- **Purpose:** Write `storage_config.json` to the default directory.
- **Inputs:** `config`.
- **Returns:** `Future<void>`.
- **Side effects:** Writes `storage_config.json` (pretty-printed, non-atomic direct write).
- **Algorithm:** `JsonEncoder.withIndent('  ')` then `writeAsString`.
- **Usage:** Called by [`setStoragePath`](#setstoragepath), [`_adoptStrayConfig`](#_adoptstrayconfig)
  and [`writeConfig`](#writeconfig).
- **Notes:** Not atomic (no temp-file-then-rename), unlike the sync-critical writes in
  `WebDAVService` (`../../../../shared/services/webdav_service.md`) — this is a small local
  settings file, not one of the four synced data files.

### `static Future<File> _getFile(String name)` <a id="_getfile"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 254).
- **Purpose:** Resolve a named file inside the *current* app directory (respecting any custom
  storage path).
- **Inputs:** `name` — a bare file name (e.g. `device_data.json`).
- **Returns:** `Future<File>`.
- **Side effects:** None beyond `getAppDir()`'s directory-creation side effect.
- **Algorithm:** `File(p.join((await getAppDir()).path, name))`.
- **Usage:** Called by [`load`](#load) and [`save`](#save).
  [`DeviceExchangeRateService._getFile`](exchange_rate_service.md#_getfile) does not call it; it
  joins its own file name onto [`getAppDir`](#getappdir) directly.
- **Notes:** Before 1.5.7 [`readConfig`](#readconfig)/[`writeConfig`](#writeconfig) also resolved
  `storage_config.json` through this method, which is what put preferences in the custom folder.

### `static Future<DeviceData> load()` <a id="load"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 266).
- **Purpose:** Load the persisted device list from `device_data.json`.
- **Inputs:** None.
- **Returns:** `Future<DeviceData>` — `const DeviceData()` (empty) if the file is absent or empty.
- **Side effects:** Reads `device_data.json`.
- **Algorithm:** Existence/empty checks, then `DeviceData.fromJson(jsonDecode(...))` (see
  [`../models/device.md#devicedata-fromjson`](../models/device.md#devicedata-fromjson)).
- **Usage:**
  ```dart
  final data = await DeviceStorage.load();
  ```
  (from `device_list_page.dart`, `dataset_edit_page.dart`, `dataset_list_page.dart`, and other
  modules that need to read the device list read-only)
- **Notes:** None.

### `static Future<void> save(DeviceData data)` <a id="save"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 280).
- **Purpose:** Persist the full device list to `device_data.json` and notify the auto-sync
  service that local data changed.
- **Inputs:** `data`.
- **Returns:** `Future<void>`.
- **Side effects:** Writes `device_data.json` (pretty-printed, non-atomic); calls
  `AutoSyncService.instance.notifySaved()` (see
  [`../../../../shared/services/auto_sync_service.md`](../../../shared/services/auto_sync_service.md)).
- **Algorithm:** JSON-encode `data.toJson()`, write it, then notify auto-sync.
- **Usage:**
  ```dart
  await DeviceStorage.save(DeviceData(devices: _devices));
  ```
  (from `device_list_page.dart`, after a local reorder/edit)
- **Notes:** Every write to the device list should go through this method (directly or via
  [`addOrUpdate`](#addorupdate)/[`deleteDevice`](#deletedevice)) so `AutoSyncService` is always
  notified.

### `static Future<void> addOrUpdate(Device device)` <a id="addorupdate"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 293).
- **Purpose:** Insert a new device or replace an existing one (matched by `id`), then clean up
  cross-module references if the device is no longer in service.
- **Inputs:** `device`.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `device_data.json` via [`save`](#save); may call
  [`_removeDeviceReferences`](#_removedevicereferences).
- **Algorithm:** 1. Load the current list. 2. Find the index of an existing device with the same
  `id`; replace it if found, else append. 3. Save. 4. If `!device.isInService` (retired or sold —
  see [`../models/device.md#lifecyclestatus`](../models/device.md#lifecyclestatus)), remove this device's
  references from network assignments, dataset storage links, and service records.
- **Usage:**
  ```dart
  await DeviceStorage.addOrUpdate(device);
  ```
  (from `device_edit_page.dart`'s save handler, and from `local_api_server.dart` for the local HTTP
  API's device-update endpoint)
- **Notes:** This is exactly where the "retired/sold devices must be removed from network/storage
  pickers" cascade rule (documented in
  [Devices](../../../../features/devices.md#cascade-rules-on-retiresell-delete)) is triggered —
  every save that flips a device out of service runs the same cleanup as an outright delete.

### `static Future<void> deleteDevice(String id)` <a id="deletedevice"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 314).
- **Purpose:** Delete a device by id and clean up every cross-module reference to it.
- **Inputs:** `id`.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `device_data.json`; calls
  [`_removeDeviceReferences`](#_removedevicereferences).
- **Algorithm:** Filter the device out of the loaded list, save, then clean up references.
- **Usage:**
  ```dart
  await DeviceStorage.deleteDevice(device.id);
  ```
  (from `device_list_page.dart`'s delete confirmation flow)
- **Notes:** None.

### `static Future<void> _removeDeviceReferences(String id)` <a id="_removedevicereferences"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 326).
- **Purpose:** Strip every reference to a device id from network assignments, dataset storage
  links, and service records — the shared cleanup used by both retiring/selling a device and
  outright deleting it.
- **Inputs:** `id`.
- **Returns:** `Future<void>`.
- **Side effects:** May rewrite `network_data.json` (via `NetworkStorage.save`) and/or
  `dataset_data.json` (via `DataSetStorage.save`); always calls
  `ServiceStorage.removeDeviceReferences(id)`.
- **Algorithm:** 1. Load network data; filter out any assignment whose `deviceId == id`; save only
  if something was actually removed (length comparison). 2. Load dataset data; for each dataset,
  filter its `storageLinks` to drop entries referencing `id`, tracking whether *any* dataset
  changed; save the whole dataset list only if at least one did. 3. Unconditionally delegate to
  `ServiceStorage.removeDeviceReferences(id)` for service-record/route cleanup.
- **Usage:** Called by both [`addOrUpdate`](#addorupdate) (when a device leaves service) and
  [`deleteDevice`](#deletedevice).
- **Notes:** This is the single implementation of the "deleting a device must remove related
  network assignments, dataset storage links, service records, and service route references" rule
  from [Devices](../../../../features/devices.md#cascade-rules-on-retiresell-delete) — network and
  dataset cleanup are conditionally saved (only on an actual change), while the service cleanup is
  unconditionally delegated regardless of whether anything actually changed there.

### `static Future<Map<String, dynamic>> readConfig()` <a id="readconfig"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 372).
- **Purpose:** Read the app's local preferences — the generic key/value map in the default
  folder's `storage_config.json`, the shared config store used for theme, locale, default currency,
  list columns and other simple settings that don't warrant their own file.
- **Inputs:** None.
- **Returns:** `Future<Map<String, dynamic>>` — `{}` if absent/empty.
- **Side effects:** May adopt a stray config from the custom storage folder first
  ([`_adoptStrayConfig`](#_adoptstrayconfig)); reads `storage_config.json` from the default folder.
- **Algorithm:** `await _adoptStrayConfig()`, then
  [`_readConfigFromDefault`](#_readconfigfromdefault) (existence/empty checks, then `jsonDecode`).
- **Usage:**
  ```dart
  final config = await DeviceStorage.readConfig();
  return (config['defaultCurrency'] as String? ?? defaultDefaultCurrency).toUpperCase();
  ```
  (from [`exchange_rate_service.md`](exchange_rate_service.md)'s `getDefaultCurrency`; also used
  directly by `dataset_list_page.dart` for its own small config flags)
- **Notes:** This is a generic, model-agnostic map — any module can stash its own keys here without
  a shared schema, similar in spirit to `extraJson` preservation elsewhere in the app but for local
  settings rather than synced records. The file is the same whatever the storage path — the one in
  the platform default folder, beside `storagePath` — so moving the data never resets a
  preference. Before 1.5.7 this read the *current* storage folder, where no config existed after a
  move.

### `static Future<void> writeConfig(Map<String, dynamic> config)` <a id="writeconfig"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 385).
- **Purpose:** Write the app's local preferences back to the default folder's
  `storage_config.json`.
- **Inputs:** `config` — typically read via [`readConfig`](#readconfig), mutated, then passed back.
- **Returns:** `Future<void>`.
- **Side effects:** May adopt a stray config first ([`_adoptStrayConfig`](#_adoptstrayconfig));
  rewrites `storage_config.json` in the default folder (pretty-printed, non-atomic).
- **Algorithm:** `await _adoptStrayConfig()`; copy `config`, remove `storagePath`, put back the
  current `_customPath` under `storagePath` when it is set and non-empty, then
  [`_writeConfigToDefault`](#_writeconfigtodefault).
- **Usage:**
  ```dart
  config['defaultCurrency'] = currency.toUpperCase();
  await DeviceStorage.writeConfig(config);
  ```
  (from `exchange_rate_service.md`'s `setDefaultCurrency`)
- **Notes:** Callers must read-modify-write (there is no merge helper) — concurrent writers could
  clobber each other's keys, but this file is only ever written from the single-threaded UI/local
  API layer, never from a background isolate. `storagePath` belongs to
  [`setStoragePath`](#setstoragepath): whatever `config` holds under that key is replaced by the
  current custom path, or removed without one, so a preference write can never move or lose the
  data (covered by `test/storage_path_test.dart`).

### `static Future<String?> getThemeMode()` <a id="getthememode"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 398).
- **Purpose:** Read the persisted theme mode string (`'light'`/`'dark'`/`'system'`, or unset).
- **Inputs:** None.
- **Returns:** `Future<String?>`.
- **Side effects:** Reads `storage_config.json` via [`readConfig`](#readconfig).
- **Algorithm:** `(await readConfig())['themeMode'] as String?`.
- **Usage:**
  ```dart
  final modeStr = await DeviceStorage.getThemeMode();
  ```
  (from `../../../../shared/providers/app_settings.md`'s `AppSettings` initialization)
- **Notes:** None.

### `static Future<void> setThemeMode(String? mode)` <a id="setthememode"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 408).
- **Purpose:** Persist the theme mode string, or clear it entirely when `mode` is null.
- **Inputs:** `mode`.
- **Returns:** `Future<void>`.
- **Side effects:** Reads then rewrites `storage_config.json`.
- **Algorithm:** Read config; `remove('themeMode')` if `mode` is null, else set it; write back.
- **Usage:**
  ```dart
  DeviceStorage.setThemeMode(str);
  ```
  (from `AppSettings`, fire-and-forget on theme change)
- **Notes:** None.

### `static Future<String?> getLocaleTag()` <a id="getlocaletag"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 423).
- **Purpose:** Read the persisted locale tag (e.g. `'en'`, `'zh'`), or `null` if unset (follow
  system locale).
- **Inputs:** None.
- **Returns:** `Future<String?>`.
- **Side effects:** Reads `storage_config.json` via [`readConfig`](#readconfig).
- **Algorithm:** `(await readConfig())['locale'] as String?`.
- **Usage:** Called from `AppSettings` initialization alongside `getThemeMode`.
- **Notes:** None.

### `static Future<void> setLocaleTag(String? tag)` <a id="setlocaletag"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 433).
- **Purpose:** Persist the locale tag, or clear it entirely when `tag` is null (revert to system
  locale).
- **Inputs:** `tag`.
- **Returns:** `Future<void>`.
- **Side effects:** Reads then rewrites `storage_config.json`.
- **Algorithm:** Read config; `remove('locale')` if `tag` is null, else set it; write back.
- **Usage:**
  ```dart
  DeviceStorage.setLocaleTag(null);   // follow system locale
  DeviceStorage.setLocaleTag(tag);    // pin to an explicit locale
  ```
  (from `AppSettings`'s locale-change handler)
- **Notes:** None.

### `static Future<int> _getListColumns(String key)` <a id="getlistcolumns"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 451).
- **Purpose:** Read one list page's column preference.
- **Inputs:** `key` — the `storage_config.json` key for that page.
- **Returns:** `Future<int>` — the stored count, or `listColumnsAuto` when the key is absent, not
  an integer, or outside 1..`listMaxColumns`.
- **Side effects:** Reads `storage_config.json` via `readConfig`.
- **Usage:** The four `get…ListColumns` accessors.
- **Notes:** The preference is clamped again at render time by `listColumnCount` against what the
  current width fits; this only rejects values that could never be valid.

### `static Future<void> _setListColumns(String key, int columns)` <a id="setlistcolumns"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 466).
- **Purpose:** Persist one list page's column preference.
- **Inputs:** `key`; `columns` — `listColumnsAuto` or a pinned count.
- **Returns:** None.
- **Side effects:** Reads and rewrites `storage_config.json`.
- **Usage:** The four `set…ListColumns` accessors, called fire-and-forget from the list pages.
- **Notes:** A count in 1..`listMaxColumns` is stored; anything else removes the key, so the
  default is absent from the file rather than written as zero — matching `setThemeMode`.

### `const StoragePathResult({bool saved = true, List<String> unmoved = const [], String? from})` <a id="storagepathresult-new"></a>
- **Kind:** constructor of `StoragePathResult`, the top-level class that tells the caller what
  [`setStoragePath`](#setstoragepath) did.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 560).
- **Purpose:** Create a result.
- **Inputs:** `saved` — whether the new path was recorded (default `true`; `false` means nothing
  changed); `unmoved` — relative paths the move left in the old folder (default empty); `from` —
  the old folder holding them (null when nothing was moved).
- **Returns:** A new `StoragePathResult`.
- **Side effects:** None.
- **Algorithm:** Field assignment.
- **Usage:** `setStoragePath` returns `const StoragePathResult()` when the path did not change,
  `StoragePathResult(unmoved: unmoved, from: oldDir.path)` after a move, and
  `const StoragePathResult(saved: false)` on an exception.
- **Notes:** An unmoved entry is not readable by the app at the new location, so a caller must
  surface `unmoved` to the user; Settings does so in its `storage-unmoved-dialog`.

### `bool get complete` <a id="complete"></a>
- **Kind:** getter of `StoragePathResult`.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 571).
- **Purpose:** Report whether the change fully succeeded.
- **Inputs:** None.
- **Returns:** `bool` — `saved && unmoved.isEmpty`.
- **Side effects:** None.
- **Algorithm:** `saved && unmoved.isEmpty`.
- **Usage:** For callers and tests that only need a yes/no; `settings_page.dart` checks `saved`
  and `unmoved` separately to pick its message.
- **Notes:** None.
