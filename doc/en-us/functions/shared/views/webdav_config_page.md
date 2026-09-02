# lib/shared/views/webdav_config_page.dart

`WebDAVConfigPage` is the WebDAV sync settings page: it edits/saves a `WebDAVConfig`, tests the
connection, and drives every foreground sync action (manual sync, force upload, force download,
conflict resolution) through [`WebDAVService`](../services/webdav_service.md), reporting outcomes
via [`AutoSyncService`](../services/auto_sync_service.md) and holding
[`SyncWakeLock`](../services/sync_wake_lock.md) while a transfer is in flight. This is the page
described end-to-end in [WebDAV Sync](../../../sync.md) (the 9-step flow, manual-vs-auto-sync
semantics, wake lock, and force upload/download) and walked through concretely in
[Sync Walkthrough](../../../examples/sync-walkthrough.md). The nested `_ConflictDialog` is the UI
half of [Three-Way Merge](../../../algorithms/three-way-merge.md)'s conflict output — one dialog
per `RecordConflict`, shown in sequence by `_resolveConflicts`.

**Row-count note:** `grep -c 'Purpose:' webdav_config_page.dart` returns **23**, matching this
file's 23 real declarations exactly — every block sits directly above the declaration it
documents; there are no misattached blocks and no undocumented declarations in this file.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `WebDAVConfigPage` (constructor) | constructor | B | Create the page widget (no parameters). |
| `createState` | method (`WebDAVConfigPage`) | B | Create the page's mutable state object. |
| [`initState`](#initstate) | method (widget lifecycle) | A | Register the sync-status listener and load the saved config. |
| `_refreshSyncStatus` | method (`_WebDAVConfigPageState`) | B | Rebuild in response to an `AutoSyncService` status change. |
| [`_loadConfig`](#_loadconfig) | method (`_WebDAVConfigPageState`) | A | Load the saved `WebDAVConfig` into the text controllers. |
| `dispose` | method (widget lifecycle) | B | Unregister the listener and dispose the four text controllers. |
| `_currentConfig` | getter (`_WebDAVConfigPageState`) | B | Build a `WebDAVConfig` from the current controller text and `_autoSync`. |
| [`_saveConfig`](#_saveconfig) | method (`_WebDAVConfigPageState`) | A | Persist the current form as the WebDAV config and trigger an immediate sync if fully configured. |
| [`_testConnection`](#_testconnection) | method (`_WebDAVConfigPageState`) | A | Test connectivity to the configured WebDAV server. |
| [`_syncNow`](#_syncnow) | method (`_WebDAVConfigPageState`) | A | Run a manual foreground sync and route the result to conflict resolution or a plain result dialog. |
| [`_showSyncResult`](#_showsyncresult) | method (`_WebDAVConfigPageState`) | A | Present a non-conflict sync/force result: failure dialog, warnings dialog, or success snackbar. |
| [`_forceUpload`](#_forceupload) | method (`_WebDAVConfigPageState`) | A | Confirm and run a destructive force upload (local overwrites remote). |
| [`_forceDownload`](#_forcedownload) | method (`_WebDAVConfigPageState`) | A | Confirm and run a destructive force download (remote overwrites local). |
| `_confirmForceAction` | method (widget helper) | B | Show a Cancel/Confirm dialog for a destructive force action. |
| `_progressText` | method (`_WebDAVConfigPageState`) | B | Map a `SyncProgress` phase to a localized status line. |
| [`_resolveConflicts`](#_resolveconflicts) | method (`_WebDAVConfigPageState`) | A | Show one dialog per pending conflict, then upload the resolved data. |
| [`_disconnect`](#_disconnect) | method (`_WebDAVConfigPageState`) | A | Delete the saved WebDAV config and clear the form. |
| `_fillNextcloud` | method (`_WebDAVConfigPageState`) | B | Fill the form with Nextcloud WebDAV URL/path presets. |
| [`_syncStatusText`](#_syncstatustext) | method (`_WebDAVConfigPageState`) | A | Build a short sync health summary for display. |
| `build` | method (widget) | B | Render the config form, sync-status card, progress bar, and sync/force/disconnect actions, in a column capped at `formMaxWidth` and centred. |
| `_ConflictDialog` (constructor) | constructor | B | Store the conflict to display. |
| [`_modifiedAtOf`](#_modifiedatof) | method (`_ConflictDialog`, static) | A | Extract a display-ready `modifiedAt` timestamp from a dynamic conflict record, if it has one. |
| `build` (`_ConflictDialog`) | method (widget) | B | Render the conflict dialog: record name, both sides' timestamp/ID, Keep Local/Keep Remote actions. |

## Documentation

### `void initState()` <a id="initstate"></a>
- **Kind:** method of `_WebDAVConfigPageState` (widget lifecycle override)
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 44)
- **Purpose:** Wire this page into background sync status notifications and load the previously
  saved WebDAV configuration.
- **Inputs:** None.
- **Returns:** `None`.
- **Side effects:** Registers `_refreshSyncStatus` with
  `AutoSyncService.instance.addOnStatusChanged`; starts the (unawaited) `_loadConfig()` load.
- **Algorithm:** Calls `super.initState()`, registers the status-change listener, then calls
  `_loadConfig()` without awaiting it.
- **Usage:** Invoked automatically by the Flutter framework when `_WebDAVConfigPageState` is first
  inserted into the tree.
- **Notes:** The counterpart `dispose()` (line 83) removes the same listener and disposes the four
  `TextEditingController`s (`_urlController`, `_userController`, `_passController`,
  `_pathController`).

### `Future<void> _loadConfig()` <a id="_loadconfig"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 64)
- **Purpose:** Load the persisted `WebDAVConfig` (if any) into the form's text controllers and
  auto-sync switch.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `WebDAVService.loadConfig()` (reads `webdav_config.json`); mutates the
  four controllers' `.text` directly (not via `setState`, since that happens once at the end);
  `setState` clears `_loading`.
- **Algorithm:** Awaits `WebDAVService.loadConfig()`; if non-null, copies `serverUrl`/`username`/
  `password`/`remotePath` into the matching controllers and `isConfigured`/`autoSync` into
  `_isConfigured`/`_autoSync`; then, regardless of whether a config existed, sets `_loading =
  false` if still mounted.
- **Usage:** Called once from [`initState`](#initstate).
- **Notes:** If no config exists yet, the controllers keep their initial values (`_pathController`
  defaults to `/MyDevice`) and `_isConfigured` stays `false`.

### `Future<void> _saveConfig()` <a id="_saveconfig"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 110)
- **Purpose:** Persist the form's current values as the WebDAV config, and if the result is fully
  configured with auto-sync on, request an immediate sync.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `WebDAVService.saveConfig` (writes `webdav_config.json`); may call
  `AutoSyncService.instance.requestSyncNow()`; `setState`; shows a snackbar.
- **Algorithm:**
  1. Builds `config` from `_currentConfig` (current controller text + `_autoSync`).
  2. Awaits `WebDAVService.saveConfig(config)`.
  3. Sets `_isConfigured = config.isConfigured` via `setState`.
  4. If `config.isConfigured && config.autoSync`, calls
     `AutoSyncService.instance.requestSyncNow()` — see
     [WebDAV Sync](../../../sync.md#auto-sync-triggers) ("saving/enabling a fully configured
     auto-sync WebDAV setup" trigger).
  5. Shows `settingsWebDAVConfigSaved` if still mounted.
- **Usage:** `onPressed: _saveConfig` on the "Save" button in `build`
  (`lib/shared/views/webdav_config_page.dart`, line 568).
- **Notes:** None.

### `Future<void> _testConnection()` <a id="_testconnection"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 133)
- **Purpose:** Verify the currently entered credentials/URL can reach the WebDAV server, without
  saving them.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Sets `_testing` (drives a spinner in the button); calls
  `WebDAVService.testConnection(_currentConfig)` (a network request); shows a result snackbar.
- **Algorithm:** Sets `_testing = true`; awaits `WebDAVService.testConnection(_currentConfig)`;
  if still mounted, clears `_testing` and shows `settingsWebDAVConnectionSuccess` or
  `settingsWebDAVConnectionFailed` based on the boolean result.
- **Usage:** `onPressed: _testing ? null : _testConnection` on the "Test Connection" button in
  `build` (`lib/shared/views/webdav_config_page.dart`, line 575) — disabled while a test is
  already running.
- **Notes:** Uses the in-memory `_currentConfig`, not the saved config, so the user can test
  changes before saving them.

### `Future<void> _syncNow()` <a id="_syncnow"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 159)
- **Purpose:** Run a manual, foreground three-way sync and route the outcome to conflict
  resolution or a plain result dialog/snackbar.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Sets `_syncing`; acquires/releases `SyncWakeLock`; calls
  `WebDAVService.sync(_currentConfig)` (the full 9-step flow); records the result and notifies
  local-data-changed listeners via `AutoSyncService`; may show dialogs/snackbars via
  [`_resolveConflicts`](#_resolveconflicts) or [`_showSyncResult`](#_showsyncresult).
- **Algorithm:**
  1. Sets `_syncing = true` and acquires `SyncWakeLock` (foreground manual sync holds the wake
     lock for the whole operation, per
     [WebDAV Sync](../../../sync.md#wake-lock)).
  2. Awaits `WebDAVService.sync(_currentConfig)` inside a `try`/`finally` that always releases the
     wake lock and clears `_syncing` if still mounted.
  3. Returns early if unmounted after the sync completes.
  4. Calls `AutoSyncService.instance.recordSyncResult(result)` then
     `notifyLocalDataChangedIfNeeded()` so other open pages pick up any merged data.
  5. If `result.hasConflicts`, delegates to [`_resolveConflicts(result)`](#_resolveconflicts) and
     returns; otherwise delegates to [`_showSyncResult(result)`](#_showsyncresult).
- **Usage:** `onPressed: _syncing ? null : _syncNow` on the "Sync Now" button in `build`
  (`lib/shared/views/webdav_config_page.dart`, line 632) — disabled while a sync is already
  running. Uses `autoResolve: false` implicitly, since `WebDAVService.sync` called from this manual
  path always surfaces conflicts rather than auto-resolving them (see
  [WebDAV Sync](../../../sync.md#manual-vs-auto-sync)).
- **Notes:** The wake lock and `_syncing` flag are both released/cleared in `finally`, so an
  exception from `WebDAVService.sync` cannot leave the page stuck in a "syncing" state or leak the
  wake lock.

### `Future<void> _showSyncResult(SyncResult result)` <a id="_showsyncresult"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 186)
- **Purpose:** Present a completed (non-conflict) sync or force-upload/download result: a failure
  dialog with the error text, a success-with-warnings dialog listing each warning, or a plain
  success snackbar.
- **Inputs:** `result` — a `SyncResult` with no pending conflicts.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a dialog (failure or warnings case) or a `SnackBar` (plain success case).
- **Algorithm:**
  1. Returns immediately if unmounted.
  2. If `!result.success`, shows an `AlertDialog` with `result.error` in a `SelectableText` and
     returns.
  3. Else if `result.warnings.isNotEmpty` (e.g. per-image sync failures — see
     [WebDAV Sync](../../../sync.md#image-sync)), shows an `AlertDialog` listing every warning
     string and returns.
  4. Otherwise shows a plain `settingsWebDAVSyncSuccess` snackbar.
- **Usage:** Called from [`_syncNow`](#_syncnow) when there are no conflicts, and from
  [`_forceUpload`](#_forceupload)/[`_forceDownload`](#_forcedownload) after their transfer
  completes.
- **Notes:** The three branches are mutually exclusive and checked in this order — a failed result
  never falls through to the warnings branch.

### `Future<void> _forceUpload()` <a id="_forceupload"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 256)
- **Purpose:** After explicit destructive-action confirmation, overwrite the remote data files and
  images with the local copies, without merging.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a confirmation dialog; sets `_syncing`; acquires/releases
  `SyncWakeLock`; calls `WebDAVService.forceUpload(_currentConfig)` (overwrites remote files);
  records the result; shows the outcome via `_showSyncResult`.
- **Algorithm:**
  1. Shows the shared `_confirmForceAction` dialog with force-upload copy; returns if not confirmed
     or unmounted.
  2. Sets `_syncing = true`, acquires `SyncWakeLock`.
  3. Awaits `WebDAVService.forceUpload(_currentConfig)` in a `try`/`finally` that releases the wake
     lock and clears `_syncing`.
  4. Records the result and notifies local-data-changed listeners, then calls
     [`_showSyncResult(result)`](#_showsyncresult).
- **Usage:** `onPressed: _syncing ? null : _forceUpload` on the "Force Upload" button in `build`
  (`lib/shared/views/webdav_config_page.dart`, line 651).
- **Notes:** The wake lock is only acquired *after* the user confirms, not while the confirmation
  dialog itself is showing — see [WebDAV Sync](../../../sync.md#wake-lock). `forceUpload` performs
  no merge or conflict check at all (see
  [WebDAV Sync](../../../sync.md#force-upload--force-download)), so this button is only offered
  behind the destructive-action confirmation.

### `Future<void> _forceDownload()` <a id="_forcedownload"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 287)
- **Purpose:** After explicit destructive-action confirmation, overwrite the local data files and
  images with the remote copies, without merging.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a confirmation dialog; sets `_syncing`; acquires/releases
  `SyncWakeLock`; calls `WebDAVService.forceDownload(_currentConfig)` (overwrites local files);
  records the result; shows the outcome via `_showSyncResult`.
- **Algorithm:** Identical shape to [`_forceUpload`](#_forceupload), substituting
  `WebDAVService.forceDownload(_currentConfig)` and the force-download confirmation copy.
- **Usage:** `onPressed: _syncing ? null : _forceDownload` on the "Force Download" button in
  `build` (`lib/shared/views/webdav_config_page.dart`, line 659).
- **Notes:** `forceDownload` is download-only and takes no remote lock (see
  [WebDAV Sync](../../../sync.md#force-upload--force-download)) — unlike
  [`_forceUpload`](#_forceupload), the remote is never written by this path.

### `Future<void> _resolveConflicts(SyncResult result)` <a id="_resolveconflicts"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 386)
- **Purpose:** Walk every pending record conflict, ask the user to keep the local or remote
  version of each, and on full resolution upload the merged result.
- **Inputs:** `result` — a `SyncResult` with `result.pending` set (`result.hasConflicts == true`).
- **Returns:** `Future<void>`.
- **Side effects:** Shows one non-dismissible `_ConflictDialog` per conflict; acquires/releases
  `SyncWakeLock`; calls `WebDAVService.finalizePendingSync`; records the outcome via
  `AutoSyncService`; shows a snackbar.
- **Algorithm:**
  1. Iterates `result.pending!.allConflicts` in order.
  2. For each conflict, returns immediately if unmounted; otherwise shows `_ConflictDialog(conflict:
     conflict)` and awaits the chosen record.
  3. If the user dismisses the dialog without choosing (`chosen == null`) — e.g. a system back
     gesture — the method calls `AutoSyncService.instance.recordSyncResult(result)` (recording it
     as still pending/failed), shows `settingsWebDAVSyncFailed`, and returns immediately: **nothing
     is uploaded and none of the remaining conflicts are shown**, matching
     [WebDAV Sync](../../../sync.md#manual-vs-auto-sync)'s "dismissing any conflict dialog aborts
     the whole resolution" rule.
  4. Otherwise records the chosen record under `resolutions[conflict.id]` and continues to the next
     conflict.
  5. Once every conflict has a resolution, acquires `SyncWakeLock`, awaits
     `WebDAVService.finalizePendingSync(_currentConfig, pending, resolutions)` inside a
     `try`/`finally` that always releases the wake lock, and calls
     `AutoSyncService.instance.recordFinalizeResult(ok)`.
  6. Shows `settingsWebDAVSyncSuccess` or `settingsWebDAVSyncFailed` depending on `ok`.
- **Usage:** Called from [`_syncNow`](#_syncnow) whenever `result.hasConflicts` is true.
- **Notes:** `NetworkDevice` conflicts have no `modifiedAt` to show, so `_ConflictDialog` falls
  back to the record ID for them (see
  [`_modifiedAtOf`](#_modifiedatof) below and
  [WebDAV Sync](../../../sync.md#networkdevice-composite-key-merge)).

### `Future<void> _disconnect()` <a id="_disconnect"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 445)
- **Purpose:** Remove the saved WebDAV configuration and reset the form to its blank/default state.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `WebDAVService.deleteConfig()` (deletes `webdav_config.json`); clears all
  four controllers (`_pathController` resets to `/MyDevice` rather than being emptied); `setState`
  clears `_isConfigured`/`_autoSync`; shows a snackbar.
- **Algorithm:** Awaits `WebDAVService.deleteConfig()`, clears the URL/username/password
  controllers, resets the path controller to `/MyDevice`, sets `_isConfigured = false` and
  `_autoSync = false`, then shows `settingsWebDAVConfigRemoved` if still mounted.
- **Usage:** `onPressed: _disconnect` on the "Disconnect" button in `build`
  (`lib/shared/views/webdav_config_page.dart`, line 683).
- **Notes:** This does not touch local data files or `.sync_base/` snapshots — it only removes the
  WebDAV connection config, so re-adding the same server later resumes with a fresh (non-existent)
  base snapshot rather than resuming mid-sync state.

### `String? _syncStatusText(AppLocalizations l10n)` <a id="_syncstatustext"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 483)
- **Purpose:** Produce a short sync health summary card's text, or `null` if there's nothing to
  report yet.
- **Inputs:** `l10n`.
- **Returns:** `String?`.
- **Side effects:** None (reads `AutoSyncService.instance` fields only).
- **Algorithm:** Identical logic to `_webDavStatusText` in
  [`settings_page.dart`](../../features/settings/views/settings_page.md#_webdavstatustext): if
  `lastError` is set, returns a conflict- or failure-flavored line; else if `lastSuccessAt` is set,
  returns a last-success line; else returns `null`.
- **Usage:** `final syncStatus = _syncStatusText(l10n);` in `build`
  (`lib/shared/views/webdav_config_page.dart`, line 505), shown in a colored `Card` above the sync
  progress indicator whenever `_isConfigured` is true and this returns non-null.
- **Notes:** None.

### `static String? _modifiedAtOf(dynamic record)` <a id="_modifiedatof"></a>
- **Kind:** static method of `_ConflictDialog`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 714)
- **Purpose:** Best-effort extraction of a `modifiedAt` timestamp from a conflict record whose
  concrete type (`Device`, `Network`, `DataSet`, `ServiceNode`, ... or `NetworkDevice`) isn't known
  at this call site.
- **Inputs:** `record` — `conflict.localRecord` or `conflict.remoteRecord`, typed `dynamic`.
- **Returns:** `String?` — the record's `modifiedAt` converted to local time and stringified, or
  `null` if the record has no such field (or it isn't a `DateTime`).
- **Side effects:** None.
- **Algorithm:** Wraps a dynamic `record.modifiedAt` access in `try`/`catch`; if the access
  succeeds and the value is a `DateTime`, returns `value.toLocal().toString()`; if the access
  throws (`NoSuchMethodError` for a type with no `modifiedAt` getter, e.g. `NetworkDevice`) or the
  value isn't a `DateTime`, falls through to returning `null`.
- **Usage:** Called twice in `_ConflictDialog.build` (`lib/shared/views/webdav_config_page.dart`,
  lines 732-733), once for `conflict.localRecord` and once for `conflict.remoteRecord`.
- **Notes:** This is the mechanism behind
  [WebDAV Sync](../../../sync.md#networkdevice-composite-key-merge)'s documented fallback: since
  `NetworkDevice` has no `modifiedAt`, this returns `null` for it and the dialog falls back to
  `l10n.syncConflictRecordId(conflict.id)` (the composite key, e.g. `net-home:dev-1`) instead of a
  timestamp — for every other record type, the real `modifiedAt` is shown.
