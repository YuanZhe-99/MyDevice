# lib/features/settings/views/backup_page.dart

`BackupPage` is the Settings sub-page for local backups: it lists existing `backups/backup_*.json`
bundles via [`BackupService`](../../../shared/services/backup_service.md), lets the user create a
new backup, toggle auto-backup and retention, and restore or delete an existing one. Restoring is
the safety-critical path in this file — it interacts directly with WebDAV auto-sync through
[`WebDAVService`](../../../shared/services/webdav_service.md) and
[`AutoSyncService`](../../../shared/services/auto_sync_service.md), and force-uploads under
[`SyncWakeLock`](../../../shared/services/sync_wake_lock.md). See
[Backup, Restore, and Export](../../../../backup-restore.md) for the full backup-format,
deduplication, and restore-validation model this page's flows sit on top of, and
[WebDAV Sync](../../../../sync.md) for the sync semantics `_handlePostRestoreSync` triggers.

**Row-count note:** `grep -c 'Purpose:' backup_page.dart` returns **16**, matching this file's 16
real declarations exactly — every block sits directly above the declaration it documents; there
are no misattached blocks and no undocumented tail declarations in this file.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `BackupPage` (constructor) | constructor | B | Create the page widget (no parameters). |
| `createState` | method (`BackupPage`) | B | Create the page's mutable state object. |
| `initState` | method (widget lifecycle) | B | Kick off the initial backup-list/settings load. |
| [`_load`](#_load) | method (`_BackupPageState`) | A | Load backup settings and the current backup list from `BackupService`. |
| [`_createBackup`](#_createbackup) | method (`_BackupPageState`) | A | Create a new backup and report success/failure. |
| [`_restoreBackup`](#_restorebackup) | method (`_BackupPageState`) | A | Pick modules, confirm, and restore a backup, disabling auto-sync first for safety. |
| [`_handlePostRestoreSync`](#_handlepostrestoresync) | method (`_BackupPageState`) | A | Offer a force-upload after a successful restore when WebDAV is configured. |
| [`_deleteBackup`](#_deletebackup) | method (`_BackupPageState`) | A | Confirm and delete a backup bundle, then reload the list. |
| [`_toggleAutoBackup`](#_toggleautobackup) | method (`_BackupPageState`) | A | Persist the auto-backup enabled flag. |
| [`_setRetention`](#_setretention) | method (`_BackupPageState`) | A | Persist the backup retention-days setting. |
| `build` | method (widget) | B | Render the info card, settings section, create-backup tile, and backup history list, in a column capped at `formMaxWidth` and centred. |
| `_buildSection` | method (widget helper) | B | Render one titled settings section. |
| `_RestoreModuleDialog` (constructor) | constructor | B | Store the list of modules available to restore from a bundle. |
| `createState` (`_RestoreModuleDialog`) | method (`_RestoreModuleDialog`) | B | Create the dialog's mutable state object. |
| `initState` (`_RestoreModuleDialogState`) | method (widget lifecycle) | B | Seed the selected-modules set to "all modules" by default. |
| `build` (`_RestoreModuleDialogState`) | method (widget) | B | Render the select-all checkbox plus one checkbox per restorable module. |

## Documentation

### `Future<void> _load()` <a id="_load"></a>
- **Kind:** method of `_BackupPageState`
- **Source:** `lib/features/settings/views/backup_page.dart` (line 51)
- **Purpose:** Load backup settings (auto-backup flag, retention days) and the current backup
  history from `BackupService`, and refresh the page.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `BackupService.loadSettings()` and `BackupService.listBackups()`
  (file-system reads under `backups/`); `setState` on success.
- **Algorithm:**
  1. Awaits `BackupService.loadSettings()` to populate the service's static
     `autoBackupEnabled`/`retentionDays`.
  2. Awaits `BackupService.listBackups()` to get the current `List<BackupInfo>` (each entry
     already flagged `corrupt: true` if its JSON failed to parse — see
     [Backup, Restore, and Export](../../../../backup-restore.md#atomic-writes-and-corrupt-bundle-handling)).
  3. If still mounted, copies all four values into local state (`_backups`, `_autoBackup`,
     `_retentionDays`, `_loading = false`) in a single `setState`.
- **Usage:** Called from `initState()` on first load, and again after every create/restore/delete
  to refresh the visible list (e.g. at the end of [`_createBackup`](#_createbackup)).
- **Notes:** None.

### `Future<void> _createBackup()` <a id="_createbackup"></a>
- **Kind:** method of `_BackupPageState`
- **Source:** `lib/features/settings/views/backup_page.dart` (line 69)
- **Purpose:** Create a new local backup bundle and show a success or failure snackbar.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `BackupService.createBackup()` (writes a new `backup_*.json` and any new
  content-addressed blobs under `backups/blobs/`); shows a `SnackBar`; reloads the list on success.
- **Algorithm:** Awaits `BackupService.createBackup()`; if it returns a non-null file, shows the
  `backupCreated` snackbar and calls [`_load`](#_load) to refresh the history; otherwise shows the
  `backupFailed` snackbar.
- **Usage:** `onTap: _createBackup` on the "Create backup" list tile in `build`
  (`lib/features/settings/views/backup_page.dart`, line 373).
- **Notes:** None.

### `Future<void> _restoreBackup(BackupInfo backup)` <a id="_restorebackup"></a>
- **Kind:** method of `_BackupPageState`
- **Source:** `lib/features/settings/views/backup_page.dart` (line 96)
- **Purpose:** Let the user pick which modules to restore from a bundle, confirm the destructive
  action, and restore it — disabling WebDAV auto-sync first as a safety measure.
- **Inputs:** `backup` — the `BackupInfo` entry the user tapped restore on.
- **Returns:** `Future<void>`.
- **Side effects:** Reads the bundle's available modules; shows a module-picker dialog and a
  confirmation dialog; may call `WebDAVService.saveConfig` to disable (and, on a no-op failure,
  re-enable) auto-sync; calls `BackupService.restoreBackup` (writes data/image files); notifies
  `AutoSyncService`; shows snackbars; calls [`_handlePostRestoreSync`](#_handlepostrestoresync).
- **Algorithm:**
  1. Loads `BackupService.getBackupModules(backup.file)`; if empty (bundle unreadable), shows
     `backupRestoreFailed` and returns.
  2. Shows `_RestoreModuleDialog` to collect the selected module keys; returns if the user picked
     none or dismissed it.
  3. Shows a Cancel/Restore confirmation `AlertDialog`; returns if not confirmed.
  4. Loads the current `WebDAVService.loadConfig()`. If WebDAV is configured and `autoSync` is on,
     immediately saves the config with `autoSync: false` — **before any restore data is written**,
     so a crash or page disposal mid-restore can never leave restored-old data with auto-sync
     still enabled (see
     [Backup, Restore, and Export](../../../../backup-restore.md#restore-result-and-the-auto-sync-disable-safety-rule)).
  5. Calls `BackupService.restoreBackup(backup.file, moduleKeys: selected)`.
  6. If the result is not `ok`: re-enables auto-sync only if it was disabled in step 4 **and**
     `result.wroteAnything` is `false` (i.e. local data is guaranteed untouched); shows
     `backupRestoreFailed`; returns.
  7. On success: calls `AutoSyncService.instance.notifyLocalDataChangedNow()` so open pages reload
     the restored data immediately; shows a `backupRestoreMissingImages` warning if
     `result.missingImages > 0`; calls [`_handlePostRestoreSync`](#_handlepostrestoresync) with the
     pre-restore config (or `null` if WebDAV wasn't configured).
- **Usage:** `onPressed: b.corrupt ? null : () => _restoreBackup(b)` on each backup history tile's
  restore button in `build` (`lib/features/settings/views/backup_page.dart`, line 418) — disabled
  for bundles flagged `corrupt`.
- **Notes:** Step 4's auto-sync disable happens with no `mounted` gate, deliberately: it must run
  even if the page is disposed immediately after, since leaving auto-sync on with restored-old
  local data would let the next sync propagate stale records/deletions to the remote and every
  other synced device.

### `Future<void> _handlePostRestoreSync(WebDAVConfig? config)` <a id="_handlepostrestoresync"></a>
- **Kind:** method of `_BackupPageState`
- **Source:** `lib/features/settings/views/backup_page.dart` (line 191)
- **Purpose:** After a successful restore, offer to force-upload the restored data when WebDAV
  sync was configured; otherwise just confirm the restore completed.
- **Inputs:** `config` — the `WebDAVConfig` loaded before the restore (auto-sync already disabled
  on it by [`_restoreBackup`](#_restorebackup)), or `null` if sync isn't configured.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a non-dismissible dialog when `config` is non-null; on confirmation,
  acquires `SyncWakeLock`, calls `WebDAVService.forceUpload(config)`, releases the wake lock, and
  records the result via `AutoSyncService.instance.recordSyncResult`; shows a snackbar either way.
- **Algorithm:**
  1. If `config == null`, shows the plain `backupRestored` snackbar and returns — auto-sync was
     never touched, so there's nothing else to offer.
  2. Otherwise shows a non-dismissible `AlertDialog` combining the "sync disabled" notice
     (`backupRestoredSyncDisabled`) with the force-upload prompt (`backupForceUploadPrompt`).
  3. If the user declines (or the widget is unmounted), returns without re-enabling auto-sync —
     it stays off until the user manually re-enables it on the WebDAV page.
  4. If confirmed: acquires `SyncWakeLock`, calls `WebDAVService.forceUpload(config)` inside a
     `try`/`finally` that always releases the wake lock, then records the result and shows
     `backupForceUploadDone`/`backupForceUploadFailed`.
- **Usage:** `await _handlePostRestoreSync(webDavConfigured ? config : null);` at the end of
  [`_restoreBackup`](#_restorebackup) (`lib/features/settings/views/backup_page.dart`, line 176).
- **Notes:** Auto-sync itself was already disabled earlier, in `_restoreBackup`, before any file
  was written; this method only handles the user-facing follow-up decision (force-upload now, or
  leave sync off until the user revisits WebDAV settings). See
  [WebDAV Sync](../../../../sync.md#force-upload--force-download) for what `forceUpload` does.

### `Future<void> _deleteBackup(BackupInfo backup)` <a id="_deletebackup"></a>
- **Kind:** method of `_BackupPageState`
- **Source:** `lib/features/settings/views/backup_page.dart` (line 249)
- **Purpose:** Confirm and, if accepted, permanently delete one backup bundle and refresh the list.
- **Inputs:** `backup` — the `BackupInfo` entry the user tapped delete on.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a Cancel/Delete confirmation dialog; on confirmation calls
  `BackupService.deleteBackup(backup.file)` (deletes the bundle file, subject to that service's
  blob-GC grace window — see
  [Backup, Restore, and Export](../../../../backup-restore.md#garbage-collection)) and reloads.
- **Algorithm:** Shows the confirmation `AlertDialog`; if the result is not exactly `true`, or the
  widget is unmounted, returns without deleting; otherwise awaits `BackupService.deleteBackup` then
  [`_load`](#_load).
- **Usage:** `onPressed: () => _deleteBackup(b)` on each backup history tile's delete button in
  `build` (`lib/features/settings/views/backup_page.dart`, line 423).
- **Notes:** Unlike restore, delete has no `corrupt`-gated disable — a corrupt bundle can still be
  deleted.

### `Future<void> _toggleAutoBackup(bool value)` <a id="_toggleautobackup"></a>
- **Kind:** method of `_BackupPageState`
- **Source:** `lib/features/settings/views/backup_page.dart` (line 279)
- **Purpose:** Enable or disable automatic backups and persist the setting.
- **Inputs:** `value` — the new switch state.
- **Returns:** `Future<void>`.
- **Side effects:** `setState` updates `_autoBackup`; sets `BackupService.autoBackupEnabled`; calls
  `BackupService.saveSettings()` (writes `storage_config.json`).
- **Algorithm:** Updates local state immediately via `setState`, mirrors the value onto the
  service's static `autoBackupEnabled`, then awaits `saveSettings()` to persist it.
- **Usage:** `onChanged: _toggleAutoBackup` on the "Auto Backup" `SwitchListTile` in `build`
  (`lib/features/settings/views/backup_page.dart`, line 346).
- **Notes:** None.

### `Future<void> _setRetention(int days)` <a id="_setretention"></a>
- **Kind:** method of `_BackupPageState`
- **Source:** `lib/features/settings/views/backup_page.dart` (line 290)
- **Purpose:** Change the backup retention period and persist it.
- **Inputs:** `days` — one of the fixed `_retentionOptions` (`0, 3, 7, 14, 30, 60, 90`; `0` means
  keep forever).
- **Returns:** `Future<void>`.
- **Side effects:** `setState` updates `_retentionDays`; sets `BackupService.retentionDays`; calls
  `BackupService.saveSettings()`.
- **Algorithm:** Same shape as [`_toggleAutoBackup`](#_toggleautobackup): local `setState`, mirror
  onto the service's static field, await the persist call.
- **Usage:** `onChanged: (v) { if (v != null) _setRetention(v); }` on the retention
  `DropdownButton<int>` in `build` (`lib/features/settings/views/backup_page.dart`, line 360).
- **Notes:** The actual day-based deletion logic (`_cleanOldBackups()`) lives in
  `BackupService`, not here — this method only persists the chosen threshold; see
  [Backup, Restore, and Export](../../../../backup-restore.md#retention).
