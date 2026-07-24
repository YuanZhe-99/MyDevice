# lib/shared/services/auto_sync_service.dart

Singleton (`AutoSyncService.instance`) that triggers WebDAV sync automatically on three events —
app launch, app resume, and a 30-second debounce after local data saves — plus a 15-minute periodic
timer while the process stays alive. It wraps `WebDAVService.sync()` (see
[`webdav_service.md`](webdav_service.md)) with a re-entrancy guard and in-memory status tracking
(last success/failure time, last error, pending-conflict flag) that `SettingsPage` and
`WebDAVConfigPage` read to surface sync health. The periodic timer also runs
`BackupService.runAutoBackupIfNeeded()` (see [`backup_service.md`](backup_service.md)) so a
long-running desktop instance still gets its daily backup. See `../../../sync.md` and the "WebDAV
Sync Rules" section of `../../../AGENTS.md` for the broader sync architecture and the rule that
auto-sync always runs with `autoResolve: false` (conflicts are surfaced, never silently
last-writer-wins resolved).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AutoSyncService._()` | constructor | B | Prevent direct instantiation and expose only static members. |
| [`lastSuccessAt`](#lastsuccessat) | getter | B | Return the last successful sync time recorded by this service. |
| [`lastFailureAt`](#lastfailureat) | getter | B | Return the last failed sync time recorded by this service. |
| [`lastError`](#lasterror) | getter | B | Return the most recent sync failure message. |
| [`hasPendingConflicts`](#haspendingconflicts) | getter | B | Return whether auto-sync found conflicts needing manual resolution. |
| [`addOnLocalDataChanged`](#addonlocaldatachanged) | method | B | Register a callback for when sync writes merged data locally. |
| [`removeOnLocalDataChanged`](#removeonlocaldatachanged) | method | B | Unregister a local-data-changed callback. |
| [`addOnStatusChanged`](#addonstatuschanged) | method | B | Register a listener for sync status changes. |
| [`removeOnStatusChanged`](#removeonstatuschanged) | method | B | Unregister a sync status listener. |
| [`recordSyncResult`](#recordsyncresult) | method | A | Record a sync result triggered outside the auto-sync loop. |
| [`notifyLocalDataChangedIfNeeded`](#notifylocaldatachangedifneeded) | method | A | Notify UI reload listeners after a manual sync/force op wrote local data. |
| [`notifyLocalDataChangedNow`](#notifylocaldatachangednow) | method | A | Notify UI reload listeners unconditionally after an out-of-band data replacement. |
| [`recordFinalizeResult`](#recordfinalizeresult) | method | A | Record a conflict-finalization result. |
| [`start`](#start) | method | A | Start the auto-sync lifecycle observer and periodic timer. |
| [`stop`](#stop) | method | A | Stop the auto-sync lifecycle observer and periodic timer. |
| [`notifySaved`](#notifysaved) | method | A | Schedule a debounced sync after a local data save. |
| [`requestSyncNow`](#requestsyncnow) | method | A | Trigger a sync immediately, skipping the debounce timer. |
| [`didChangeAppLifecycleState`](#didchangeapplifecyclestate) | method (override) | A | React to app resume by syncing and running the auto-backup check. |
| [`_trySync`](#_trysync) | method | A | Run one guarded sync attempt and record its outcome. |
| [`_recordSuccess`](#_recordsuccess) | method | A | Record a successful sync. |
| [`_recordFailure`](#_recordfailure) | method | A | Record a failed sync. |
| [`_notifyStatusChanged`](#_notifystatuschanged) | method | A | Notify all registered sync status listeners. |

Row count (22) matches `grep -c 'Purpose:' auto_sync_service.dart` (22) exactly. The
`AutoSyncService` class doc comment and the private state fields (`_debounce`, `_periodic`,
`_syncing`, `_started`, `_lastSuccessAt`, `_lastFailureAt`, `_lastError`, `_hasPendingConflicts`,
`_debounceDuration`, `_periodicDuration`, the callback lists) use plain (non-`Purpose:`) doc
comments or none at all, consistent with AGENTS.md scoping the `Purpose:` convention to
functions/methods/constructors/getters/setters; they are covered in the overview and in the
Algorithm/Notes sections of the methods that use them.

## Documentation

### `AutoSyncService._()` <a id="autosyncservice-_"></a>
- **Kind:** private constructor of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 20)
- **Purpose:** Prevent direct instantiation; the class exposes only the `AutoSyncService.instance`
  singleton and static-like instance members reached through it.
- **Inputs:** None.
- **Returns:** A new `AutoSyncService._` instance (used once, for `static final instance`).
- **Side effects:** None.
- **Algorithm:** Empty private constructor body.
- **Usage:** Never called directly; use `AutoSyncService.instance`.
- **Notes:** None.

### `DateTime? get lastSuccessAt` <a id="lastsuccessat"></a>
- **Kind:** getter of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 45)
- **Purpose:** Return the last successful sync time recorded by this service.
- **Inputs:** None.
- **Returns:** `DateTime?`, null before any sync has succeeded this process.
- **Side effects:** None.
- **Usage:** Read by Settings/WebDAV sync-health UI.
- **Notes:** Used by settings UI to surface sync health; in-memory only, reset on app restart.

### `DateTime? get lastFailureAt` <a id="lastfailureat"></a>
- **Kind:** getter of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 52)
- **Purpose:** Return the last failed sync time recorded by this service.
- **Inputs:** None.
- **Returns:** `DateTime?`.
- **Side effects:** None.
- **Usage:** Read by Settings/WebDAV sync-health UI alongside [`lastError`](#lasterror).
- **Notes:** In-memory only, reset on app restart.

### `String? get lastError` <a id="lasterror"></a>
- **Kind:** getter of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 59)
- **Purpose:** Return the most recent sync failure message.
- **Inputs:** None.
- **Returns:** `String?`, null after a successful sync.
- **Side effects:** None.
- **Usage:**
  ```dart
  color: AutoSyncService.instance.lastError == null
      ? Colors.green
      : Colors.red,
  ```
  (adapted from `lib/shared/views/webdav_config_page.dart` and
  `lib/features/settings/views/settings_page.dart`, which color-code the sync status indicator)
- **Notes:** Cleared to null by [`_recordSuccess`](#_recordsuccess).

### `bool get hasPendingConflicts` <a id="haspendingconflicts"></a>
- **Kind:** getter of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 66)
- **Purpose:** Return whether auto-sync found conflicts needing manual resolution.
- **Inputs:** None.
- **Returns:** `bool`.
- **Side effects:** None.
- **Usage:** Read by Settings/WebDAV UI to show a "resolve conflicts" prompt.
- **Notes:** Conflicts are not auto-resolved during background sync — the user must open the
  WebDAV page and resolve them manually (per the WebDAV Sync Rules in `../../../AGENTS.md`).

### `void addOnLocalDataChanged(void Function() cb)` <a id="addonlocaldatachanged"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 73)
- **Purpose:** Register a callback invoked when sync writes merged data to local files.
- **Inputs:** `cb` — a no-argument callback.
- **Returns:** None.
- **Side effects:** Appends `cb` to the internal `_onLocalDataChanged` list.
- **Usage:**
  ```dart
  AutoSyncService.instance.addOnLocalDataChanged(_handleLocalDataChanged);
  ```
  (from `lib/features/devices/views/device_list_page.dart`, `initState()`; mirrored in the network,
  dataset, and service list pages)
- **Notes:** Always pair with [`removeOnLocalDataChanged`](#removeonlocaldatachanged) in
  `dispose()`.

### `void removeOnLocalDataChanged(void Function() cb)` <a id="removeonlocaldatachanged"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 80)
- **Purpose:** Unregister a previously added local-data-changed callback.
- **Inputs:** `cb`.
- **Returns:** None.
- **Side effects:** Removes `cb` from `_onLocalDataChanged`.
- **Usage:**
  ```dart
  AutoSyncService.instance.removeOnLocalDataChanged(_handleLocalDataChanged);
  ```
  (from `lib/features/devices/views/device_list_page.dart`, `dispose()`)
- **Notes:** None.

### `void addOnStatusChanged(VoidCallback cb)` <a id="addonstatuschanged"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 88)
- **Purpose:** Register a listener for sync status changes (success/failure/conflict).
- **Inputs:** `cb`.
- **Returns:** None.
- **Side effects:** Appends `cb` to `_onStatusChanged`.
- **Usage:**
  ```dart
  AutoSyncService.instance.addOnStatusChanged(_refreshSyncStatus);
  ```
  (from `lib/shared/views/webdav_config_page.dart` and
  `lib/features/settings/views/settings_page.dart`, `initState()`)
- **Notes:** UI pages use this to refresh visible sync warnings.

### `void removeOnStatusChanged(VoidCallback cb)` <a id="removeonstatuschanged"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 95)
- **Purpose:** Unregister a previously added sync status listener.
- **Inputs:** `cb`.
- **Returns:** None.
- **Side effects:** Removes `cb` from `_onStatusChanged`.
- **Usage:**
  ```dart
  AutoSyncService.instance.removeOnStatusChanged(_refreshSyncStatus);
  ```
  (from `lib/shared/views/webdav_config_page.dart`, `dispose()`)
- **Notes:** Must be paired with `addOnStatusChanged` in widget dispose.

### `void recordSyncResult(SyncResult result)` <a id="recordsyncresult"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 102)
- **Purpose:** Record a sync result produced outside the auto-sync loop (i.e. a manual sync
  triggered from the WebDAV page).
- **Inputs:** `result` — a `SyncResult` from `WebDAVService.sync()`.
- **Returns:** None.
- **Side effects:** Updates success/failure/conflict status fields and notifies status listeners.
- **Algorithm:** 1. If `result.hasConflicts`, record a failure with a conflicts flag and an
  optional detail message. 2. Else if `!result.success`, record a failure with `result.error` (or a
  generic message). 3. Otherwise record success.
- **Usage:**
  ```dart
  result = await WebDAVService.sync(_currentConfig);
  ...
  AutoSyncService.instance.recordSyncResult(result);
  AutoSyncService.instance.notifyLocalDataChangedIfNeeded();
  ```
  (from `lib/shared/views/webdav_config_page.dart`, `_syncNow()`)
- **Notes:** Manual sync pages call this so status banners clear after success. This mirrors the
  branching in the private [`_trySync`](#_trysync) used for background auto-sync.

### `void notifyLocalDataChangedIfNeeded()` <a id="notifylocaldatachangedifneeded"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 123)
- **Purpose:** Notify UI reload listeners after a manual sync or force operation wrote local data
  files.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Calls `WebDAVService.consumeLocalDataChanged()` (reads-and-resets the flag) and,
  if it was true, invokes every registered `_onLocalDataChanged` callback.
- **Algorithm:** 1. Consume the WebDAV local-data-changed flag. 2. If it was set, iterate a
  snapshot (`List.of(...)`) of the callback list and invoke each.
- **Usage:** See [`recordSyncResult`](#recordsyncresult) — always called right after recording a
  manual sync result.
- **Notes:** Iterates a copy of the listener list so a callback that adds/removes a listener during
  iteration cannot corrupt it.

### `void notifyLocalDataChangedNow()` <a id="notifylocaldatachangednow"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 138)
- **Purpose:** Notify UI reload listeners unconditionally after local data files were replaced
  outside of sync (backup restore, ZIP import).
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Invokes every registered `_onLocalDataChanged` callback.
- **Algorithm:** Iterate a snapshot of `_onLocalDataChanged` and invoke each callback; unlike
  [`notifyLocalDataChangedIfNeeded`](#notifylocaldatachangedifneeded), it does not check the WebDAV
  flag first.
- **Usage:**
  ```dart
  AutoSyncService.instance.notifyLocalDataChangedNow();
  ```
  (from `lib/features/settings/views/backup_page.dart`, after a successful backup restore)
- **Notes:** Use this for out-of-band data replacement (restore/import), not for sync results.

### `void recordFinalizeResult(bool ok)` <a id="recordfinalizeresult"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 149)
- **Purpose:** Record the outcome of finalizing a manually resolved sync conflict.
- **Inputs:** `ok` — whether `WebDAVService.finalizePendingSync()` succeeded.
- **Returns:** None.
- **Side effects:** Records success or a fixed failure message and notifies status listeners.
- **Algorithm:** If `ok`, record success; otherwise record failure with
  `'Failed to upload resolved sync conflicts'`.
- **Usage:**
  ```dart
  ok = await WebDAVService.finalizePendingSync(_currentConfig, pending, resolutions);
  ...
  AutoSyncService.instance.recordFinalizeResult(ok);
  ```
  (from `lib/shared/views/webdav_config_page.dart`, `_finalizeConflicts()`)
- **Notes:** Used after users resolve conflicts manually via the WebDAV page's conflict dialog.

### `void start()` <a id="start"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 164)
- **Purpose:** Start the app-lifecycle observer and periodic auto-sync/auto-backup timer.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Registers `this` as a `WidgetsBindingObserver`, immediately runs one sync
  attempt, and starts a 15-minute `Timer.periodic` that re-syncs and calls
  `BackupService.runAutoBackupIfNeeded()` on every tick.
- **Algorithm:** 1. If already started (`_started`), return (idempotent). 2. Set `_started = true`
  and add `this` as a `WidgetsBinding` observer. 3. Call `_trySync()` once for the initial launch
  sync. 4. Start `_periodic` as a 15-minute `Timer.periodic` whose callback calls `_trySync()` then
  `BackupService.runAutoBackupIfNeeded()`.
- **Usage:**
  ```dart
  // Start auto-sync lifecycle observer
  AutoSyncService.instance.start();
  ```
  (from `lib/main.dart`, during app startup)
- **Notes:** The periodic timer also runs the daily auto-backup check so a desktop instance left
  running across midnight still creates its daily backup without a launch or resume event.

### `void stop()` <a id="stop"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 181)
- **Purpose:** Stop the auto-sync lifecycle observer and periodic timer.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Cancels `_debounce` and `_periodic` timers, removes `this` as a
  `WidgetsBindingObserver`, and clears `_started`.
- **Algorithm:** Cancel and null out both timers, remove the lifecycle observer, set
  `_started = false`. No branching.
- **Usage:** Not called anywhere in the current codebase (`start()` runs once at app launch and the
  service lives for the process lifetime); provided for symmetry with `start()` and for tests.
- **Notes:** None.

### `void notifySaved()` <a id="notifysaved"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 196)
- **Purpose:** Schedule a debounced sync 30 seconds after a local data save.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Cancels any pending `_debounce` timer and starts a new one.
- **Algorithm:** 1. If not started, do nothing. 2. Cancel any existing debounce timer.
  3. Start a new `Timer(_debounceDuration, _trySync)` (30 seconds).
- **Usage:**
  ```dart
  AutoSyncService.instance.notifySaved();
  ```
  (from `lib/features/devices/services/device_storage.dart`, `lib/features/network/services/network_storage.dart`,
  `lib/features/datasets/services/dataset_storage.dart`, and `lib/features/services/services/service_storage.dart`
  `save()` methods, plus several list/detail/edit pages after a local mutation)
- **Notes:** Called by storage-layer `save()` methods so non-UI writes are covered, per the WebDAV
  Sync Rules in `../../../AGENTS.md`. Repeated calls restart the 30-second window (true debounce).

### `void requestSyncNow()` <a id="requestsyncnow"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 208)
- **Purpose:** Trigger a sync as soon as possible, skipping the debounce timer.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Cancels any pending debounce timer and starts a sync attempt via `unawaited`.
- **Algorithm:** Cancel `_debounce`, set it to null, then call `unawaited(_trySync())` so the
  caller does not block on the sync completing.
- **Usage:**
  ```dart
  AutoSyncService.instance.requestSyncNow();
  ```
  (from `lib/shared/views/webdav_config_page.dart`, called right after saving/enabling a fully
  configured auto-sync WebDAV setup)
- **Notes:** Used right after enabling/saving WebDAV auto-sync configuration, aligned with
  MyAnime/MyDay's equivalent behavior.

### `void didChangeAppLifecycleState(AppLifecycleState state)` <a id="didchangeapplifecyclestate"></a>
- **Kind:** method of `AutoSyncService` (override of `WidgetsBindingObserver`)
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 220)
- **Purpose:** React to the app resuming from background by syncing and checking auto-backup.
- **Inputs:** `state` — the new `AppLifecycleState`.
- **Returns:** None.
- **Side effects:** On resume, calls `_trySync()` and `BackupService.runAutoBackupIfNeeded()`.
- **Algorithm:** If `state == AppLifecycleState.resumed`, call `_trySync()` then
  `BackupService.runAutoBackupIfNeeded()`; otherwise do nothing.
- **Usage:** Invoked by the Flutter framework via `WidgetsBinding` after `start()` registers `this`
  as an observer; not called directly by app code.
- **Notes:** Mobile OS suspension may delay timers until resume, so this is the primary sync
  trigger on mobile after the initial launch sync.

### `Future<void> _trySync()` <a id="_trysync"></a>
- **Kind:** private method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 234)
- **Purpose:** Run one guarded background sync attempt and record its outcome.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Loads the WebDAV config, may call `WebDAVService.sync()`, updates status
  fields, notifies status and local-data-changed listeners.
- **Algorithm:** 1. If `_syncing` is already true, return (silently skip — see Notes).
  2. Load the WebDAV config; if absent, not configured, or `autoSync` disabled, return without
  syncing. 3. Set `_syncing = true`. 4. Call `WebDAVService.sync(config)` with the default
  `autoResolve: false`. 5. Branch on the result exactly like
  [`recordSyncResult`](#recordsyncresult) (conflicts → failure with conflicts flag; failure →
  failure; else → success). 6. If `WebDAVService.consumeLocalDataChanged()` is true, invoke all
  `_onLocalDataChanged` callbacks. 7. Catch any exception and record it as a failure. 8. In
  `finally`, clear `_syncing`.
- **Usage:** Called internally by [`start`](#start) (initial and periodic),
  [`notifySaved`](#notifysaved) (debounced), [`requestSyncNow`](#requestsyncnow), and
  [`didChangeAppLifecycleState`](#didchangeapplifecyclestate) (on resume). Not called directly from
  outside the file.
- **Notes:** The `_syncing` guard silently skips overlapping triggers (timer/resume/debounce)
  instead of surfacing a spurious "Sync already in progress" failure banner. Auto-sync always runs
  with `autoResolve: false`, so true two-sided conflicts are recorded as pending rather than
  resolved with last-writer-wins.

### `void _recordSuccess()` <a id="_recordsuccess"></a>
- **Kind:** private method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 269)
- **Purpose:** Record a successful sync.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Sets `_lastSuccessAt` to now, clears `_lastError` and
  `_hasPendingConflicts`, then notifies status listeners.
- **Algorithm:** Straight-line field assignment followed by
  `_notifyStatusChanged()`; no branching.
- **Usage:** Called by [`_trySync`](#_trysync), [`recordSyncResult`](#recordsyncresult), and
  [`recordFinalizeResult`](#recordfinalizeresult) on the success path.
- **Notes:** None.

### `void _recordFailure(String error, {bool conflicts = false})` <a id="_recordfailure"></a>
- **Kind:** private method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 281)
- **Purpose:** Record a failed sync.
- **Inputs:** `error` — failure message; `conflicts` — whether the failure is a pending-conflict
  state rather than a hard error.
- **Returns:** None.
- **Side effects:** Sets `_lastFailureAt` to now, `_lastError` to `error`, and
  `_hasPendingConflicts` to `conflicts`, then notifies status listeners.
- **Algorithm:** Straight-line field assignment followed by `_notifyStatusChanged()`.
- **Usage:** Called by [`_trySync`](#_trysync), [`recordSyncResult`](#recordsyncresult), and
  [`recordFinalizeResult`](#recordfinalizeresult) on the failure/conflict paths.
- **Notes:** None.

### `void _notifyStatusChanged()` <a id="_notifystatuschanged"></a>
- **Kind:** private method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (approx. line 293)
- **Purpose:** Notify all registered sync status listeners.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Invokes every registered `_onStatusChanged` callback.
- **Algorithm:** Iterate a snapshot (`List.of(...)`) of `_onStatusChanged` and invoke each.
- **Usage:** Called internally by [`_recordSuccess`](#_recordsuccess) and
  [`_recordFailure`](#_recordfailure).
- **Notes:** Iterates a copy so a listener that adds/removes another listener mid-notification
  cannot corrupt the list being iterated.
