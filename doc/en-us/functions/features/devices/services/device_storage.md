# lib/features/devices/services/device_storage.dart

`DeviceStorage` persists the device list (`device_data.json`) and also doubles as the app's
canonical storage-location/config service: `getAppDir()` is called by `DataSetStorage` and
`NetworkStorage` (`../../../network/services/network_storage.dart`,
`../../../datasets/services/dataset_storage.dart`) to resolve the *same* app directory those
modules' own data files live in, and `readConfig`/`writeConfig` back a small generic
`storage_config.json`-like key/value store (`theme`, `locale`, `defaultCurrency`,
`autoUpdateExchangeRates`, etc.) that `AppSettings`
(`../../../../shared/providers/app_settings.md`) and
[`exchange_rate_service.md`](exchange_rate_service.md) also read/write through. See
[Data Formats](../../../../data-formats.md) for the `DeviceData`/`Device` JSON shape this file
serializes, and [Devices](../../../../features/devices.md) for the cascade-delete rules
`deleteDevice`/`addOrUpdate` implement.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`_getDefaultAppDir`](#_getdefaultappdir) | static method (private) | A | Resolve (and create) the default `~/Documents/MyDevice` directory. |
| [`_getConfigFile`](#_getconfigfile) | static method (private) | A | Resolve the `storage_config.json` file, always in the default directory. |
| [`_loadCustomPath`](#_loadcustompath) | static method (private) | A | Load the custom storage path from config, once per process. |
| [`getAppDir`](#getappdir) | static method | A | Resolve the app's data directory (custom path if configured, else default). |
| [`getStoragePath`](#getstoragepath) | static method | A | Return the current storage directory's display path. |
| [`setStoragePath`](#setstoragepath) | static method | A | Change the storage location, migrating data/backups/images if needed. |
| [`_readConfigFromDefault`](#_readconfigfromdefault) | static method (private) | A | Read `storage_config.json` from the default (not custom) directory. |
| [`_writeConfigToDefault`](#_writeconfigfromdefault) | static method (private) | A | Write `storage_config.json` to the default directory. |
| [`_getFile`](#_getfile) | static method (private) | A | Resolve a named file inside the current app directory. |
| [`load`](#load) | static method | A | Load the persisted `DeviceData` (device list). |
| [`save`](#save) | static method | A | Persist `DeviceData` and notify the auto-sync service. |
| [`addOrUpdate`](#addorupdate) | static method | A | Insert or replace a device by id; clean up references if it left service. |
| [`deleteDevice`](#deletedevice) | static method | A | Delete a device by id and clean up cross-module references. |
| [`_removeDeviceReferences`](#_removedevicereferences) | static method (private) | A | Strip network/dataset/service references to a device id. |
| [`readConfig`](#readconfig) | static method | A | Read the generic `storage_config.json` key/value map. |
| [`writeConfig`](#writeconfig) | static method | A | Write the generic `storage_config.json` key/value map. |
| [`getThemeMode`](#getthememode) | static method | A | Read the persisted theme mode string. |
| [`setThemeMode`](#setthememode) | static method | A | Persist (or clear) the theme mode string. |
| [`getLocaleTag`](#getlocaletag) | static method | A | Read the persisted locale tag. |
| [`setLocaleTag`](#setlocaletag) | static method | A | Persist (or clear) the locale tag. |

Row count (20) matches `grep -c 'Purpose:' device_storage.dart` (20) exactly.

## Documentation

### `static Future<Directory> _getDefaultAppDir()` <a id="_getdefaultappdir"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 29).
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
- **Source:** `lib/features/devices/services/device_storage.dart` (line 44).
- **Purpose:** Resolve the `storage_config.json` file path, which always lives in the *default*
  app directory regardless of any configured custom storage path.
- **Inputs:** None.
- **Returns:** `Future<File>`.
- **Side effects:** None (does not create the file).
- **Algorithm:** Join `_getDefaultAppDir()`'s path with `_configFileName`.
- **Usage:** Called by [`_loadCustomPath`](#_loadcustompath), [`_readConfigFromDefault`](#_readconfigfromdefault),
  and [`_writeConfigToDefault`](#_writeconfigfromdefault).
- **Notes:** Deliberately bypasses `getAppDir()`/any custom path — this file must be discoverable
  even if the custom path it names is itself invalid or on unmounted storage, otherwise the app
  could never recover the storage path setting.

### `static Future<void> _loadCustomPath()` <a id="_loadcustompath"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 55).
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
- **Usage:** Called at the start of [`getAppDir`](#getappdir).
- **Notes:** A malformed config file is treated the same as "no custom path" (falls back to
  default) rather than surfacing an error to the caller.

### `static Future<Directory> getAppDir()` <a id="getappdir"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 75).
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
- **Source:** `lib/features/devices/services/device_storage.dart` (line 93).
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

### `static Future<bool> setStoragePath(String? newPath)` <a id="setstoragepath"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 105).
- **Purpose:** Change the app's storage location, migrating existing data/backups/images to the
  new location when the new location doesn't already have its own data.
- **Inputs:** `newPath` — the new custom path, or `null`/empty to revert to the default directory.
- **Returns:** `Future<bool>` — `true` on success, `false` if any step throws.
- **Side effects:** Persists `storagePath` to `storage_config.json` (in the default directory);
  copies (then deletes) `device_data.json`/`network_data.json`/`dataset_data.json`/
  `service_data.json`, plus the `backups/` and `images/` directories, from the old location to the
  new one.
- **Algorithm:** 1. Capture the current directory as `oldDir`. 2. Set `_customPath = newPath` and
  persist it into `storage_config.json` (removing the key entirely when `newPath` is null/empty).
  3. Resolve `newDir` via `getAppDir()`; if it's unchanged from `oldDir`, return `true` immediately
  (no migration needed). 4. For each of the four data file names: if the new location already has
  that file, leave it alone (its data wins); otherwise, if the old location has it, copy then delete
  it (move semantics). 5. If an old `backups/` directory exists and the new location doesn't have
  one yet, create the new one and move every file across, then remove the old directory. 6. Repeat
  step 5 for `images/`. 7. Wrap the whole method in a `try`/`catch` returning `false` on any
  exception.
- **Usage:**
  ```dart
  final ok = await DeviceStorage.setStoragePath(pathToSet);
  ```
  (from `settings_page.dart`'s "change storage location" flow)
- **Notes:** A location that already has its own data files for a given name is never overwritten
  — the new location's copy always wins over migrating the old one, per file/directory, so pointing
  the app at an existing MyDevice data folder adopts that folder's data rather than clobbering it.

### `static Future<Map<String, dynamic>> _readConfigFromDefault()` <a id="_readconfigfromdefault"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 185).
- **Purpose:** Read `storage_config.json` from the default directory (used only for
  `storagePath` persistence, distinct from the general [`readConfig`](#readconfig)/
  [`writeConfig`](#writeconfig) pair which reads from the *current*, possibly custom, directory).
- **Inputs:** None.
- **Returns:** `Future<Map<String, dynamic>>` — `{}` if the file is absent or empty.
- **Side effects:** None (read-only).
- **Algorithm:** Existence check, empty-content check, then `jsonDecode`.
- **Usage:** Called only by [`setStoragePath`](#setstoragepath).
- **Notes:** Deliberately separate from `readConfig()`/`_getFile()`, which resolve against
  `getAppDir()` (the *current*, possibly custom, directory) — the storage-path setting itself must
  always live in the default directory so it can be found regardless of what it currently points
  to.

### `static Future<void> _writeConfigToDefault(Map<String, dynamic> config)` <a id="_writeconfigfromdefault"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 199).
- **Purpose:** Write `storage_config.json` to the default directory.
- **Inputs:** `config`.
- **Returns:** `Future<void>`.
- **Side effects:** Writes `storage_config.json` (pretty-printed, non-atomic direct write).
- **Algorithm:** `JsonEncoder.withIndent('  ')` then `writeAsString`.
- **Usage:** Called only by [`setStoragePath`](#setstoragepath).
- **Notes:** Not atomic (no temp-file-then-rename), unlike the sync-critical writes in
  `WebDAVService` (`../../../../shared/services/webdav_service.md`) — this is a small local
  settings file, not one of the four synced data files.

### `static Future<File> _getFile(String name)` <a id="_getfile"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 211).
- **Purpose:** Resolve a named file inside the *current* app directory (respecting any custom
  storage path).
- **Inputs:** `name` — a bare file name (e.g. `device_data.json`).
- **Returns:** `Future<File>`.
- **Side effects:** None beyond `getAppDir()`'s directory-creation side effect.
- **Algorithm:** `File(p.join((await getAppDir()).path, name))`.
- **Usage:** Called by [`load`](#load), [`save`](#save), [`readConfig`](#readconfig),
  [`writeConfig`](#writeconfig), and (indirectly, via `getAppDir`) by
  [`exchange_rate_service.md`](exchange_rate_service.md)'s own file resolution.
- **Notes:** None.

### `static Future<DeviceData> load()` <a id="load"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 223).
- **Purpose:** Load the persisted device list from `device_data.json`.
- **Inputs:** None.
- **Returns:** `Future<DeviceData>` — `const DeviceData()` (empty) if the file is absent or empty.
- **Side effects:** Reads `device_data.json`.
- **Algorithm:** Existence/empty checks, then `DeviceData.fromJson(jsonDecode(...))` (see
  [`../../models/device.md#devicedata-fromjson`](../models/device.md)).
- **Usage:**
  ```dart
  final data = await DeviceStorage.load();
  ```
  (from `device_list_page.dart`, `dataset_edit_page.dart`, `dataset_list_page.dart`, and other
  modules that need to read the device list read-only)
- **Notes:** None.

### `static Future<void> save(DeviceData data)` <a id="save"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 237).
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
- **Source:** `lib/features/devices/services/device_storage.dart` (line 250).
- **Purpose:** Insert a new device or replace an existing one (matched by `id`), then clean up
  cross-module references if the device is no longer in service.
- **Inputs:** `device`.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `device_data.json` via [`save`](#save); may call
  [`_removeDeviceReferences`](#_removedevicereferences).
- **Algorithm:** 1. Load the current list. 2. Find the index of an existing device with the same
  `id`; replace it if found, else append. 3. Save. 4. If `!device.isInService` (retired or sold —
  see [`../../models/device.md#lifecyclestatus`](../models/device.md)), remove this device's
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
- **Source:** `lib/features/devices/services/device_storage.dart` (line 271).
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
- **Source:** `lib/features/devices/services/device_storage.dart` (line 283).
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
- **Source:** `lib/features/devices/services/device_storage.dart` (line 325).
- **Purpose:** Read the generic `storage_config.json` key/value map from the *current* app
  directory — the shared config store used for theme, locale, default currency, and other simple
  settings that don't warrant their own file.
- **Inputs:** None.
- **Returns:** `Future<Map<String, dynamic>>` — `{}` if absent/empty.
- **Side effects:** Reads `storage_config.json` (via [`_getFile`](#_getfile), i.e. from the current,
  possibly custom, directory — distinct from [`_readConfigFromDefault`](#_readconfigfromdefault)).
- **Algorithm:** Existence/empty checks, then `jsonDecode`.
- **Usage:**
  ```dart
  final config = await DeviceStorage.readConfig();
  return (config['defaultCurrency'] as String? ?? defaultDefaultCurrency).toUpperCase();
  ```
  (from [`exchange_rate_service.md`](exchange_rate_service.md)'s `getDefaultCurrency`; also used
  directly by `dataset_list_page.dart` for its own small config flags)
- **Notes:** This is a generic, model-agnostic map — any module can stash its own keys here without
  a shared schema, similar in spirit to `extraJson` preservation elsewhere in the app but for local
  settings rather than synced records.

### `static Future<void> writeConfig(Map<String, dynamic> config)` <a id="writeconfig"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 338).
- **Purpose:** Write the generic `storage_config.json` key/value map back to the current app
  directory.
- **Inputs:** `config` — typically read via [`readConfig`](#readconfig), mutated, then passed back.
- **Returns:** `Future<void>`.
- **Side effects:** Writes `storage_config.json` (pretty-printed, non-atomic).
- **Algorithm:** `JsonEncoder.withIndent('  ')` then `writeAsString`.
- **Usage:**
  ```dart
  config['defaultCurrency'] = currency.toUpperCase();
  await DeviceStorage.writeConfig(config);
  ```
  (from `exchange_rate_service.md`'s `setDefaultCurrency`)
- **Notes:** Callers must read-modify-write (there is no merge helper) — concurrent writers could
  clobber each other's keys, but this file is only ever written from the single-threaded UI/local
  API layer, never from a background isolate.

### `static Future<String?> getThemeMode()` <a id="getthememode"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/device_storage.dart` (line 350).
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
- **Source:** `lib/features/devices/services/device_storage.dart` (line 360).
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
- **Source:** `lib/features/devices/services/device_storage.dart` (line 375).
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
- **Source:** `lib/features/devices/services/device_storage.dart` (line 385).
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
