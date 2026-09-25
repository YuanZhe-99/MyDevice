# lib/shared/services/auto_sync_service.dart

**Facade over the shared scheduler.** The lifecycle observer, 30-second save debounce, 15-minute
periodic timer, in-flight guard, and status bookkeeping moved to the `myapps_data` package
(`lib/src/sync/auto_sync_scheduler.dart`). This app's extras stay here as hooks.

## Hooks this app supplies

| Hook | Value |
|---|---|
| `isAutoSyncActive` | Config exists, is configured, and has `autoSync` enabled. |
| `runSync` | `WebDAVService.sync(config)` — never with `autoResolve`. |
| `consumeLocalDataChanged` | `WebDAVService.consumeLocalDataChanged`. |
| `onPeriodicTick` | `BackupService.runAutoBackupIfNeeded`, so a desktop instance left running across midnight still takes its daily backup. |
| `onResume` | `BackupService.runAutoBackupIfNeeded` (MyDevice has no reminder refresh). |

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AutoSyncService` | class | B | Singleton that triggers WebDAV sync automatically when enabled. |
| `AutoSyncService._` | constructor (private) | B | Prevent direct instantiation; the only instance is `instance`. |
| `instance` | static final field | B | The singleton. |
| [`_scheduler`](#_scheduler) | late final field (private) | A | The shared `AutoSyncScheduler`, wired with this app's hooks. |
| `lastSuccessAt` | getter | B | Time of the last successful sync, for the settings UI. |
| `lastFailureAt` | getter | B | Time of the last failed sync, for the settings UI. |
| `lastError` | getter | B | The most recent failure message; `null` after a successful sync. |
| `hasPendingConflicts` | getter | B | Whether a sync found conflicts that need manual resolution. |
| `addOnLocalDataChanged` | method | B | Register a UI reload callback. |
| `removeOnLocalDataChanged` | method | B | Remove a UI reload callback. |
| `addOnStatusChanged` | method | B | Register a status-change callback. |
| `removeOnStatusChanged` | method | B | Remove a status-change callback; pair it with `addOnStatusChanged` in `dispose`. |
| [`recordSyncResult`](#recordsyncresult) | method | A | Record a manually triggered sync into the same status path. |
| `notifyLocalDataChangedIfNeeded` | method | B | Fire reload callbacks **if** the engine's local-data-changed flag is set (and consume it). |
| `notifyLocalDataChangedNow` | method | B | Fire reload callbacks unconditionally (restore, ZIP import). |
| `recordFinalizeResult` | method | B | Record a conflict finalization: success, or the failure "Failed to upload resolved sync conflicts". |
| [`start`](#start) | method | A | Begin observing the lifecycle, sync once, and start the periodic timer. |
| `stop` | method | B | Cancel both timers and stop observing the lifecycle. |
| [`notifySaved`](#notifysaved) | method | A | Storage hook: restart the 30-second debounce. |
| [`requestSyncNow`](#requestsyncnow) | method | A | Cancel any pending debounce and sync immediately. |

Row count (20) is two more than `grep -c '/// Purpose:' auto_sync_service.dart` (18). One of the 18
`Purpose:` blocks is the library header at line 1, which is not a declaration, so 17 declarations
carry one. The three extra rows are the `AutoSyncService` class and the fields `instance` and
`_scheduler`, which carry an ordinary `///` description or none and are listed because every
declaration appears in the table. Tier A: 5 rows. Every member except `_scheduler` is a one-line
delegation to the scheduler; the Tier A entries below are the ones whose behavior a caller has to
know.

## Documentation

### `late final shared.AutoSyncScheduler _scheduler` <a id="_scheduler"></a>
- **Kind:** private `late final` instance field of `AutoSyncService`.
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 30).
- **Purpose:** Hold the one shared scheduler, configured with the five hooks listed in
  [Hooks this app supplies](#hooks-this-app-supplies).
- **Inputs:** None; built lazily on first access.
- **Returns:** The `AutoSyncScheduler` every public member delegates to.
- **Side effects:** None when built. The hooks it carries read `webdav_config.json`, run WebDAV
  syncs, and run the daily auto-backup when the scheduler invokes them.
- **Algorithm:** 1. `isAutoSyncActive` loads the WebDAV config and requires it to be non-null,
  `isConfigured`, and `autoSync`. 2. `runSync` loads the config again; if it vanished since the
  gate, it returns `AutoSyncResult(success: false)` rather than throwing; otherwise it calls
  `WebDAVService.sync(config)` and copies `success`, `hasConflicts` and `error` into an
  `AutoSyncResult`. 3. `consumeLocalDataChanged` is `WebDAVService.consumeLocalDataChanged`. 4.
  `onPeriodicTick` and `onResume` are both `BackupService.runAutoBackupIfNeeded`.
- **Usage:** Internal only; every public member of `AutoSyncService` forwards to it.
- **Notes:** `runSync` calls `WebDAVService.sync` without `autoResolve`, so it stays at its `false`
  default and true conflicts surface as `hasPendingConflicts`. The scheduler swallows errors from
  `onPeriodicTick`/`onResume`, so a failing backup never breaks the timer or the resume handler.

### `void recordSyncResult(SyncResult result)` <a id="recordsyncresult"></a>
- **Kind:** method of `AutoSyncService`.
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 121).
- **Purpose:** Feed the result of a sync the user ran by hand into the same status fields the
  background loop maintains.
- **Inputs:** `result` — the app-typed `SyncResult` from `WebDAVService`.
- **Returns:** None.
- **Side effects:** Updates `lastSuccessAt`/`lastFailureAt`/`lastError`/`hasPendingConflicts` and
  notifies status listeners.
- **Algorithm:** Convert `result` into `shared.AutoSyncResult(success, hasConflicts, error)` and
  pass it to the scheduler, which records conflicts as a failure with
  `hasPendingConflicts = true`, a plain failure with `result.error` (or "Unknown sync failure"),
  and anything else as a success that clears the error and the conflict flag.
- **Usage:**
  ```dart
  AutoSyncService.instance.recordSyncResult(result);
  AutoSyncService.instance.notifyLocalDataChangedIfNeeded();
  ```
  (from `webdav_config_page.dart` after manual sync, force upload and force download, and from
  `backup_page.dart` after its force upload)
- **Notes:** This is how a status banner raised by a failed background sync clears after the user
  syncs successfully by hand.

### `void start()` <a id="start"></a>
- **Kind:** method of `AutoSyncService`.
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 161).
- **Purpose:** Begin automatic syncing for the life of the process.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Registers a `WidgetsBindingObserver`, starts an immediate guarded sync, and
  starts the 15-minute periodic timer, whose every tick requests a sync and runs `onPeriodicTick`.
- **Algorithm:** Delegates to the scheduler: return if already started; set the started flag; add
  the lifecycle observer; request a sync now; start `Timer.periodic(15 min)`.
- **Usage:**
  ```dart
  AutoSyncService.instance.start();
  ```
  (from `lib/main.dart` at startup)
- **Notes:** Idempotent. Every trigger passes the `isAutoSyncActive` gate first, so starting with
  WebDAV unconfigured or auto-sync off costs nothing. Before `start()`, `notifySaved()` is ignored.

### `void notifySaved()` <a id="notifysaved"></a>
- **Kind:** method of `AutoSyncService`.
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 175).
- **Purpose:** Let a storage save schedule a debounced sync.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Cancels any pending debounce timer and starts a new 30-second one that runs a
  guarded sync.
- **Algorithm:** Delegates to the scheduler: return if not started; otherwise replace the debounce
  timer (trailing edge).
- **Usage:**
  ```dart
  AutoSyncService.instance.notifySaved();
  ```
  (from `DeviceStorage.save` in [`device_storage.md`](../../features/devices/services/device_storage.md#save)
  and the other storages' `save` methods; several edit and list pages also call it directly)
- **Notes:** A burst of saves produces one sync 30 seconds after the last of them. Ignored before
  [`start`](#start), so early storage writes cannot schedule a sync.

### `void requestSyncNow()` <a id="requestsyncnow"></a>
- **Kind:** method of `AutoSyncService`.
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 182).
- **Purpose:** Sync as soon as possible without waiting for the debounce.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Cancels the pending debounce timer and starts a guarded sync, unawaited.
- **Algorithm:** Delegates to the scheduler's internal request-now path, the same one the launch,
  periodic and resume triggers use.
- **Usage:**
  ```dart
  AutoSyncService.instance.requestSyncNow();
  ```
  (from `webdav_config_page.dart`, after saving a configuration with auto-sync on and when the
  auto-sync switch is turned on)
- **Notes:** Unlike [`notifySaved`](#notifysaved) it does not check the started flag. It still
  passes the `isAutoSyncActive` gate, and an overlapping trigger is silently skipped by the
  in-flight guard.

## Notes

- Status is in-memory only and is never persisted.
- Auto-sync leaves `autoResolve` disabled: true two-sided conflicts are recorded as visible pending
  status rather than silently applying last-writer-wins.
- Overlapping triggers are silently skipped by the in-flight guard.
- `notifySaved()` is ignored before `start()`.
- **Behavior change from the extraction:** resume now cancels a pending save-debounce before syncing,
  instead of leaving it queued alongside the resume sync. The in-flight guard already made the
  difference unobservable; this simply unifies the three apps on one rule.

## Where the scheduler documentation lives

`packages/myapps_data/doc/en-us/functions/src/sync/auto_sync_scheduler.md`.
