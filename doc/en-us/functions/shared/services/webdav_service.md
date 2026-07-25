# lib/shared/services/webdav_service.dart

**Facade over the shared engine.** The WebDAV transport, upload-lock lifecycle, merge pipeline,
`.sync_base` snapshots, and referenced-image sync moved to the `myapps_data` package
(`lib/src/webdav/sync_engine.dart` and friends). This file kept every public name and signature, so
call sites, the conflict dialogs, and the existing tests are unchanged.

The four data files are described once in
[`../../app/data_modules.md`](../../app/data_modules.md); the hardcoded `_dataFileNames` list is gone.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`SyncResult`](#syncresult) | class | A | Success flag, error text, pending conflicts, non-fatal warnings. |
| [`PendingSync`](#pendingsync) | class | A | Per-module unresolved conflicts plus the engine state to finalize. |
| [`WebDAVService.progress`](#progress) | static getter | A | Live `ValueNotifier<SyncProgress>` for the progress bar. |
| [`consumeLocalDataChanged()`](#consumelocaldatachanged) | static method | A | Read and clear the "sync wrote local data" signal. |
| [`loadConfig()`](#loadconfig) | static method | A | Read `webdav_config.json`. |
| [`saveConfig(config)`](#saveconfig) | static method | A | Atomically write `webdav_config.json`. |
| [`deleteConfig()`](#deleteconfig) | static method | A | Remove `webdav_config.json`. |
| [`testConnection(config)`](#testconnection) | static method | A | One PROPFIND; 207 or 404 means reachable. |
| [`sync(config, {autoResolve})`](#sync) | static method | A | Full two-way sync under the remote `.lock`. |
| [`finalizePendingSync(...)`](#finalizependingsync) | static method | A | Upload the user's conflict resolutions. |
| [`forceUpload(config)`](#forceupload) | static method | A | Overwrite remote with local, no merge. |
| [`forceDownload(config)`](#forcedownload) | static method | A | Overwrite local with remote, no merge. |

Re-exported from the package under their original names: `WebDAVConfig`, `WebDAVUploadLock`,
`RemoteFile`, `RemoteFileStatus`.

## Documentation

### `class SyncResult` <a id="syncresult"></a>
- **Fields:** `success`, `error`, `pending`, `warnings` (non-fatal image transfer failures).
- **Getter:** `hasConflicts`.

### `class PendingSync` <a id="pendingsync"></a>
- **Fields:** `deviceMerge`, `networkMerge`, `dataSetMerge`, `serviceMerge` (the app-typed merge
  results), plus `enginePending` (opaque engine state used by `finalizePendingSync`).
- **Getter:** `allConflicts` — flattens device, network, dataset, and both service containers.
- **Notes:** The engine carries each typed merge result through as opaque `state`, which is why the
  conflict dialogs still receive real model objects.

### `progress` <a id="progress"></a>
- **Kind:** static getter → `ValueNotifier<SyncProgress>`.

### `consumeLocalDataChanged()` <a id="consumelocaldatachanged"></a>
- **Returns:** `bool` — whether sync wrote local data or downloaded images since the last call.
- **Side effects:** Resets the flag.

### `loadConfig()` <a id="loadconfig"></a>
- **Returns:** `Future<WebDAVConfig?>`; null when absent, malformed, or unreadable.
- **Notes:** A missing or null `remotePath` still defaults to `/MyDevice`.

### `saveConfig(config)` <a id="saveconfig"></a>
- **Side effects:** Atomic write of `webdav_config.json`, compact JSON. Credentials stay plaintext.

### `deleteConfig()` <a id="deleteconfig"></a>
- **Side effects:** Deletes the config when present; base snapshots and client ID are left alone.

### `testConnection(config)` <a id="testconnection"></a>
- **Returns:** `Future<bool>` — true for HTTP 207 or 404.

### `sync(config, {autoResolve = false})` <a id="sync"></a>
- **Side effects:** Acquires the remote `.lock`, then per module in registry order downloads, merges,
  uploads, and saves the base; then syncs referenced device images; updates `progress`.
- **Notes:** A per-file failure is collected and the remaining modules still sync. `autoResolve` is
  false at every production call site.

### `finalizePendingSync(config, pending, resolutions)` <a id="finalizependingsync"></a>
- **Inputs:** One flat `Map<String, dynamic>` of record ID to chosen record, spanning every module.
- **Returns:** `Future<bool>` — false when any module fails.
- **Notes:** Each module's `buildResolved` picks out the records it recognizes by runtime type, which
  is how one flat map serves modules with different record types. The remote file is re-downloaded
  before upload, as it always was here.

### `forceUpload(config)` <a id="forceupload"></a>
- **Side effects:** Overwrites remote data and uploads missing referenced images under the `.lock`.

### `forceDownload(config)` <a id="forcedownload"></a>
- **Side effects:** Replaces local data files and base snapshots; downloads missing images.
  Lock-free, syntax-only validation.

## Where the engine documentation lives

`packages/myapps_data/doc/en-us/functions/src/webdav/` — `sync_engine.md`, `webdav_client.md`,
`webdav_config.md`, `upload_lock.md`.
