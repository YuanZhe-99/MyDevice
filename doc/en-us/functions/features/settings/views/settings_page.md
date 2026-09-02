# lib/features/settings/views/settings_page.dart

`SettingsPage` is the app's top-level Settings screen: theme/locale/currency preferences (via
[`appSettingsProvider`](../../../shared/providers/app_settings.md)), data export/import/storage
location, the desktop-only tray/auto-start/local-API-server section, and links out to
[`WebDAVConfigPage`](../../../shared/views/webdav_config_page.md),
[`BackupPage`](backup_page.md), [`PrivacyPolicyPage`](privacy_policy_page.md), and
[`LicensePage`](license_page.md). It surfaces WebDAV sync health inline via
[`AutoSyncService`](../../../shared/services/auto_sync_service.md) and drives
[`ImportExportService`](../../../shared/services/import_export_service.md) for ZIP/Markdown
export and ZIP import — see [Backup, Restore, and Export](../../../../backup-restore.md#zip-exportimport)
for the format details and path-traversal protection those calls rely on. Desktop-only sections
follow [Platform Notes](../../../../platform-notes.md#desktop-local-api-server).

**Row-count note:** `grep -c 'Purpose:' settings_page.dart` returns **21**, matching this file's
21 real declarations exactly — every block sits directly above the declaration it documents; there
are no misattached blocks and no undocumented declarations in this file.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `SettingsPage` (constructor) | constructor | B | Create the page widget (no parameters). |
| `createState` | method (`SettingsPage`) | B | Create the page's mutable state object. |
| [`initState`](#initstate) | method (widget lifecycle) | A | Register the sync-status listener and kick off all initial settings loads. |
| `_refreshSyncStatus` | method (`_SettingsPageState`) | B | Rebuild in response to an `AutoSyncService` status change. |
| `dispose` | method (widget lifecycle) | B | Unregister the sync-status listener. |
| [`_webDavStatusText`](#_webdavstatustext) | method (`_SettingsPageState`) | A | Build a short WebDAV sync status line for the settings tile subtitle. |
| [`_loadStoragePath`](#_loadstoragepath) | method (`_SettingsPageState`) | A | Load the current device-data storage path. |
| [`_loadVersion`](#_loadversion) | method (`_SettingsPageState`) | A | Load the app's version/build number for display. |
| [`_loadExchangeRateSettings`](#_loadexchangeratesettings) | method (`_SettingsPageState`) | A | Load the default currency and auto-update-exchange-rates flag. |
| `_buildSection` | method (widget helper) | B | Render one titled settings section. |
| `_isDesktop` | getter (`_SettingsPageState`) | B | Whether the app is running on a desktop platform. |
| [`_exportData`](#_exportdata) | method (`_SettingsPageState`) | A | Let the user choose ZIP or Markdown export and write it to a chosen folder. |
| [`_importData`](#_importdata) | method (`_SettingsPageState`) | A | Let the user pick a ZIP backup and import it after confirmation. |
| [`_openDataFolder`](#_opendatafolder) | method (`_SettingsPageState`) | A | Open the app's data directory in the OS file manager. |
| [`_showStoragePathDialog`](#_showstoragepathdialog) | method (`_SettingsPageState`) | A | Let the user set or reset the custom device-data storage path. |
| [`_loadTraySettings`](#_loadtraysettings) | method (`_SettingsPageState`) | A | Load the persisted minimize-to-tray/close-to-tray flags. |
| [`_loadAutoStartStatus`](#_loadautostartstatus) | method (`_SettingsPageState`) | A | Query whether launch-at-startup is currently enabled. |
| [`_loadApiSettings`](#_loadapisettings) | method (`_SettingsPageState`) | A | Load the persisted local API server settings. |
| [`_showApiSettingsDialog`](#_showapisettingsdialog) | method (`_SettingsPageState`) | A | Let the user edit and save local API server settings, then restart the server. |
| [`_refreshExchangeRates`](#_refreshexchangerates) | method (`_SettingsPageState`) | A | Manually refresh and save the latest exchange rates. |
| `build` | method (widget) | B | Read the split rule (`canSplitLayout` on the screen) into `_twoPane`, then render either `_buildSettingsList` alone or a `Row` of it at `settingsLeftPaneWidth` beside `_buildDetailPane`. |
| `_buildSettingsList` | method (widget helper) | B | The General/Data/Desktop/About sections, extracted from `build` unchanged so the list can be the whole body or the left pane. |
| `_detailPage` | method (widget helper) | B | Map a `_SettingsDetail` to its page: WebDAV config, backup, privacy policy, license. |
| `_open` | method (`_SettingsPageState`) | B | Select the detail pane's page when `_twoPane`, else push it on the root navigator — the one path every row uses. |
| `_buildDetailPane` | method (widget helper) | B | The placeholder (`settingsSelectItem`) before a selection, else a nested `Navigator` keyed on the selection hosting `_detailPage`. |

## Documentation

### `void initState()` <a id="initstate"></a>
- **Kind:** method of `_SettingsPageState` (widget lifecycle override)
- **Source:** `lib/features/settings/views/settings_page.dart` (line 62)
- **Purpose:** Register this page for background sync status changes and kick off every settings
  load the page needs, including the desktop-only ones.
- **Inputs:** None.
- **Returns:** `None`.
- **Side effects:** Registers `_refreshSyncStatus` with
  `AutoSyncService.instance.addOnStatusChanged`; starts several independent async load chains
  (none awaited here).
- **Algorithm:**
  1. Calls `super.initState()`.
  2. Fire-and-forget calls `_loadVersion()`, `_loadStoragePath()`, `_loadExchangeRateSettings()`.
  3. Registers `_refreshSyncStatus` as an `AutoSyncService` status-change listener so the WebDAV
     status subtitle stays current as background syncs complete.
  4. If `_isDesktop`, additionally fire-and-forget calls `_loadTraySettings()`,
     `_loadAutoStartStatus()`, `_loadApiSettings()`.
- **Usage:** Invoked automatically by the Flutter framework when `_SettingsPageState` is first
  inserted into the tree.
- **Notes:** The counterpart `dispose()` (line 90) calls
  `AutoSyncService.instance.removeOnStatusChanged(_refreshSyncStatus)` to avoid leaking the
  listener.

### `String? _webDavStatusText(AppLocalizations l10n)` <a id="_webdavstatustext"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 100)
- **Purpose:** Produce a one-line WebDAV sync health summary for the settings tile subtitle, or
  `null` if there's nothing to report yet.
- **Inputs:** `l10n`.
- **Returns:** `String?` — an error/conflict line, a last-success line, or `null`.
- **Side effects:** None (reads `AutoSyncService.instance` fields only).
- **Algorithm:**
  1. If `AutoSyncService.instance.lastError` is set, returns a conflict-flavored or plain-failure
     line depending on `hasPendingConflicts`.
  2. Else if `lastSuccessAt` is set, returns a last-success line with the local timestamp.
  3. Else returns `null` (no sync has run yet).
- **Usage:** `final webDavStatus = _webDavStatusText(l10n);` at the top of `build`
  (`lib/features/settings/views/settings_page.dart`, line 522), shown as the WebDAV Sync tile's
  subtitle, styled in the error color when `lastError` is set.
- **Notes:** Structurally identical to `_syncStatusText` in
  [`webdav_config_page.dart`](../../../shared/views/webdav_config_page.md#_syncstatustext) — both
  read the same `AutoSyncService` fields to build the same three-way status line, once for the
  Settings tile subtitle and once for the WebDAV page itself.

### `Future<void> _loadStoragePath()` <a id="_loadstoragepath"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 118)
- **Purpose:** Load the currently configured device-data storage path for display.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `DeviceStorage.getStoragePath()`; `setState` if mounted.
- **Algorithm:** Awaits `DeviceStorage.getStoragePath()`, then sets `_storagePath` if still mounted.
- **Usage:** Called from [`initState`](#initstate); re-invoked from
  [`_showStoragePathDialog`](#_showstoragepathdialog) after a successful path change.
- **Notes:** None.

### `Future<void> _loadVersion()` <a id="_loadversion"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 128)
- **Purpose:** Load the running app's version and build number for the About section.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `PackageInfo.fromPlatform()`; `setState` if mounted.
- **Algorithm:** Awaits `PackageInfo.fromPlatform()`, then sets `_version` to
  `'${info.version}+${info.buildNumber}'` if still mounted.
- **Usage:** Called once from [`initState`](#initstate); the resulting `_version` string is also
  passed into `showLicensePage(applicationVersion: _version)` in `build`.
- **Notes:** None.

### `Future<void> _loadExchangeRateSettings()` <a id="_loadexchangeratesettings"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 140)
- **Purpose:** Load the user's default currency and whether automatic exchange-rate updates are
  enabled.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `DeviceExchangeRateService.getDefaultCurrency()` and
  `getAutoUpdateEnabled()`; `setState` if mounted.
- **Algorithm:** Awaits both service calls, then sets `_defaultCurrency` and
  `_autoUpdateExchangeRates` together in one `setState`.
- **Usage:** Called once from [`initState`](#initstate).
- **Notes:** None.

### `Future<void> _exportData()` <a id="_exportdata"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 186)
- **Purpose:** Let the user choose ZIP or Markdown export format, pick a destination folder, and
  write the export.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a format-choice dialog and a directory picker (`FilePicker`); calls
  `ImportExportService.exportMarkdown` or `exportZip` (writes a file to disk); shows a snackbar.
- **Algorithm:**
  1. Shows a `SimpleDialog` with "Export as ZIP" / "Export as Markdown" options; returns if
     dismissed.
  2. Prompts for a destination directory via `FilePicker.platform.getDirectoryPath()`; returns if
     cancelled.
  3. Calls `ImportExportService.exportMarkdown(dir)` or `exportZip(dir)` depending on the earlier
     choice.
  4. Shows `exportSuccess` if a non-null path was returned.
- **Usage:** `onTap: _exportData` on the "Export data" tile in `build`
  (`lib/features/settings/views/settings_page.dart`, line 663).
- **Notes:** No failure snackbar path — if `path` is `null` the method just falls through without
  feedback; see [`import_export_service.dart`](../../../shared/services/import_export_service.md)
  for when export can return `null`.

### `Future<void> _importData()` <a id="_importdata"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 245)
- **Purpose:** Let the user pick a ZIP backup file and, after confirmation, import it.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Opens a file picker restricted to `.zip`; shows a confirmation dialog; calls
  `ImportExportService.importZip` (overwrites local data files); shows a result snackbar.
- **Algorithm:**
  1. Picks a single `.zip` file via `FilePicker.platform.pickFiles`; returns if none was picked.
  2. Shows a Cancel/Import confirmation dialog; returns if not confirmed.
  3. Awaits `ImportExportService.importZip(path)` and shows `importSuccess`/`importFailed`
     depending on the boolean result.
- **Usage:** `onTap: _importData` on the "Import data" tile in `build`
  (`lib/features/settings/views/settings_page.dart`, line 668).
- **Notes:** The path-traversal protection for the ZIP's entry names lives in
  `ImportExportService.importZip` itself, not here — see
  [Backup, Restore, and Export](../../../../backup-restore.md#zip-exportimport).

### `Future<void> _openDataFolder()` <a id="_opendatafolder"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 286)
- **Purpose:** Open the app's data directory in the platform's native file manager (desktop only).
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Spawns a platform process (`explorer`, `open`, or `xdg-open`).
- **Algorithm:** Resolves `DeviceStorage.getAppDir()`, then branches on `Platform.isWindows` /
  `isMacOS` / `isLinux` to run the matching OS command with the directory path (Linux uses the
  `file://` URI form via `uri.toFilePath()`).
- **Usage:** `onTap: _openDataFolder` on the "Data Migration" tile in `build`
  (`lib/features/settings/views/settings_page.dart`, line 688), shown only when `_isDesktop`.
- **Notes:** No error handling around `Process.run` — a failure to launch the file manager is not
  surfaced to the user.

### `Future<void> _showStoragePathDialog(BuildContext context)` <a id="_showstoragepathdialog"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 303)
- **Purpose:** Let the user type a custom storage directory or reset to the default, then apply it.
- **Inputs:** `context`.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a dialog with a text field; calls `DeviceStorage.setStoragePath`; reloads
  the path and shows a snackbar on success.
- **Algorithm:**
  1. Shows an `AlertDialog` with a `TextField` pre-filled with `_storagePath`, and Cancel /
     "Reset to default" (returns `''`) / Save actions.
  2. Returns if the dialog was dismissed (`newPath == null`).
  3. Treats an empty string as "use the default" (`pathToSet = null`), otherwise the trimmed text.
  4. Awaits `DeviceStorage.setStoragePath(pathToSet)`; if it reports success, reloads via
     [`_loadStoragePath`](#_loadstoragepath) and shows either
     `settingsResetDefaultLocation` or `settingsStoragePathUpdated`.
- **Usage:** `onTap: () => _showStoragePathDialog(context)` on the "Storage Location" tile in
  `build` (`lib/features/settings/views/settings_page.dart`, line 681), shown only when
  `_isDesktop`.
- **Notes:** Uses the local `context` parameter's `.mounted` (`context.mounted`, line 351) rather
  than the State's own `mounted`, since this method receives `context` explicitly.

### `Future<void> _loadTraySettings()` <a id="_loadtraysettings"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 370)
- **Purpose:** Load the persisted minimize-to-tray and close-to-tray preferences.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `DeviceStorage.readConfig()`; `setState` if mounted.
- **Algorithm:** Reads the config map, defaulting both `minimizeToTray` and `closeToTray` to
  `false` if absent, then applies both via `setState`.
- **Usage:** Called from [`initState`](#initstate) when `_isDesktop`.
- **Notes:** None.

### `Future<void> _loadAutoStartStatus()` <a id="_loadautostartstatus"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 384)
- **Purpose:** Query the OS-level launch-at-startup registration state.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `launchAtStartup.isEnabled()` (queries platform startup-item state, per
  [Platform Notes](../../../../platform-notes.md#launch_at_startup)); `setState` if mounted.
- **Algorithm:** Awaits `launchAtStartup.isEnabled()`, reading an `UnsupportedError` as `false`,
  and sets `_autoStart` if still mounted.
- **Usage:** Called from [`initState`](#initstate) when `_isDesktop`.
- **Notes:** `launchAtStartup` throws `UnsupportedError` until `main` has called its `setup`,
  which never happens under `flutter test` and could not happen if the plugin failed to register;
  either reads as "not enabled" rather than taking the whole settings page down.

### `Future<void> _loadApiSettings()` <a id="_loadapisettings"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 395)
- **Purpose:** Load the persisted local API server configuration (enabled flag, port, listen
  address, credentials).
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `DeviceStorage.readConfig()`; `setState` if mounted.
- **Algorithm:** Reads the config map and applies five keys with defaults (`apiEnabled: false`,
  `apiPort: 7789`, `apiListenAddress: 'localhost'`, `apiUsername`/`apiPassword: ''`) — the `7789`
  default matches `LocalApiServer`'s own default port (see
  [Platform Notes](../../../../platform-notes.md#desktop-local-api-server)).
- **Usage:** Called from [`initState`](#initstate) when `_isDesktop`.
- **Notes:** None.

### `Future<void> _showApiSettingsDialog()` <a id="_showapisettingsdialog"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 412)
- **Purpose:** Let the user edit the local API server's listen address, port, username, and
  password, persist the change, and restart the server with the new settings.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a dialog with four text fields; writes the four settings via
  `DeviceStorage.readConfig()`/`writeConfig()`; calls `LocalApiServer.restart()`; shows a snackbar
  with the resulting port.
- **Algorithm:**
  1. Shows an `AlertDialog` pre-filled from current state, with Cancel/Save actions.
  2. Returns if not saved or unmounted.
  3. Parses the port field with `int.tryParse(...) ?? 7789`; blank address falls back to
     `'localhost'`; blank username/password are stored as `null` (not empty strings) in the config
     map.
  4. Writes the updated config map back via `DeviceStorage.writeConfig`, mirrors the new values
     into local state, then awaits `LocalApiServer.restart()` and shows
     `settingsApiRestarted(LocalApiServer.port)`.
- **Usage:** `onTap: _apiEnabled ? _showApiSettingsDialog : null` on the "API Server" settings tile
  in `build` (`lib/features/settings/views/settings_page.dart`, line 763) — only tappable while the
  API server is enabled.
- **Notes:** Storing `null` rather than `''` for blank username/password matters because
  `LocalApiServer` treats a configured (non-null) credential pair as "Basic Auth required" — see
  [Platform Notes](../../../../platform-notes.md#desktop-local-api-server).

### `Future<void> _refreshExchangeRates()` <a id="_refreshexchangerates"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 496)
- **Purpose:** Manually fetch and persist the latest exchange rates for the configured default
  currency.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `DeviceExchangeRateService.fetchAndSaveLatest(_defaultCurrency)` (network
  request plus a local write); shows a result snackbar.
- **Algorithm:** Awaits the fetch/save call and shows `exchangeRateUpdated` if it returned non-null,
  otherwise `exchangeRateUpdateFailed`.
- **Usage:** `onTap: _refreshExchangeRates` on the "Refresh Exchange Rates" tile in `build`
  (`lib/features/settings/views/settings_page.dart`, line 625).
- **Notes:** None.
