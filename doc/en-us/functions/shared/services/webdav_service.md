# lib/shared/services/webdav_service.dart

The core WebDAV sync engine: per-record three-way merge sync (`sync`), conflict finalization
(`finalizePendingSync`), and unconditional force transfers (`forceUpload`/`forceDownload`), plus the
config persistence, remote upload-lock protocol, retry/backoff, and referenced-image sync that
support them. It depends on `sync_merge.dart` (see [`sync_merge.md`](sync_merge.md)) for the
per-record merge algorithm and `sync_progress.dart` (see [`sync_progress.md`](sync_progress.md))
for the progress-reporting value type; `auto_sync_service.dart` (see
[`auto_sync_service.md`](auto_sync_service.md)) drives `sync()` automatically, and
`sync_wake_lock.dart` (see [`sync_wake_lock.md`](sync_wake_lock.md)) is held by the WebDAV page
around the same public entry points documented here. See the "WebDAV Sync Rules" section of
`../../../AGENTS.md` and `../../../sync.md` for the full architecture this file implements,
including the numbered end-to-end flow (lock acquisition, discriminated download, per-record merge,
conflict handling, lock-guarded upload). This file is large (69 declarations); see the note at the
end of the Declarations table for how it was indexed.

A key behavior to note when reading the algorithm sections below: a **remote download failure that
is not HTTP 404** (auth/server/network error) is treated as a per-file error that skips that file
for the current sync attempt — it is never treated as "file missing on remote". This is what
prevents local data from being force-uploaded over a remote file that could not be read, and it is
implemented identically in `_syncLocked` (merge sync), `_finalizeFile` (conflict finalize), and
`_forceDownloadLocked` (force download); see each entry below for the exact line performing this
check. (This differs from the sibling app MyAnime, which aborts the whole sync file-set on a
non-404 download error instead of skipping only the affected file — verified directly against this
file's code, not assumed from MyAnime's behavior.)

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`WebDAVConfig`](#webdavconfig-new) | constructor | A | Create a `WebDAVConfig` instance. |
| `isConfigured` | getter (`WebDAVConfig`) | B | Return whether server/username/password are all non-empty. |
| [`copyWith`](#copywith) | method (`WebDAVConfig`) | A | Create a copy with `autoSync` replaced. |
| [`toJson`](#webdavconfig-tojson) | method (`WebDAVConfig`) | A | Serialize this config into a JSON-compatible map. |
| [`WebDAVConfig.fromJson`](#webdavconfig-fromjson) | factory constructor | A | Create a `WebDAVConfig` from a JSON-compatible map. |
| [`WebDAVConfig.nextcloud`](#webdavconfig-nextcloud) | factory constructor | A | Create a `WebDAVConfig` for a Nextcloud server from host/username/password. |
| [`SyncResult`](#syncresult-new) | constructor | A | Create a `SyncResult` instance. |
| `hasConflicts` | getter (`SyncResult`) | B | Return whether `pending` is non-null. |
| [`PendingSync`](#pendingsync-new) | constructor | A | Create a `PendingSync` instance. |
| `allConflicts` | getter (`PendingSync`) | B | Return the combined conflicts from all four merge results. |
| [`WebDAVUploadLock`](#webdavuploadlock-new) | constructor | A | Create a `WebDAVUploadLock` value. |
| [`WebDAVUploadLock.fromJson`](#webdavuploadlock-fromjson) | factory constructor | A | Parse a `WebDAVUploadLock` from JSON. |
| [`toJson`](#webdavuploadlock-tojson) | method (`WebDAVUploadLock`) | A | Serialize this lock to the remote `.lock` JSON format. |
| `isExpired` | method (`WebDAVUploadLock`) | B | Return whether this lock is expired at `now`. |
| `matches` | method (`WebDAVUploadLock`) | B | Return whether this lock belongs to the given client/token. |
| [`refreshed`](#refreshed) | method (`WebDAVUploadLock`) | A | Create a refreshed copy of this lock (new `updatedAt`, same token). |
| `_UploadSession` | constructor (private) | B | Create an upload session marker (`clientId` + `token`). |
| [`RemoteFile.found`](#remotefile-found) | constructor | A | Create a found result with downloaded content. |
| [`RemoteFile.notFound`](#remotefile-notfound) | constructor | A | Create a not-found result for HTTP 404. |
| [`RemoteFile.failure`](#remotefile-failure) | constructor | A | Create an error result for any non-404 failure. |
| [`consumeLocalDataChanged`](#consumelocaldatachanged) | static method | A | Read-and-reset whether the last sync wrote local data files. |
| [`_reportProgress`](#_reportprogress) | static method (private) | A | Publish a progress snapshot to `progress`. |
| [`_withRetry`](#_withretry) | static method (private) | A | Retry a network operation on transient failures with 1s/2s backoff. |
| [`loadConfig`](#loadconfig) | static method | A | Load the persisted WebDAV config, or null if absent/invalid. |
| [`saveConfig`](#saveconfig) | static method | A | Save the WebDAV config to `webdav_config.json`. |
| [`deleteConfig`](#deleteconfig) | static method | A | Delete the persisted WebDAV config file. |
| [`_getBaseDir`](#_getbasedir) | static method (private) | A | Resolve (and create) the `.sync_base/` directory. |
| [`_readBase`](#_readbase) | static method (private) | A | Read a base snapshot file, or null if absent/unreadable. |
| [`_saveBase`](#_savebase) | static method (private) | A | Atomically write a base snapshot file. |
| [`_loadClientId`](#_loadclientid) | static method (private) | A | Load or create the stable local WebDAV client ID. |
| [`_readLocalUploadLock`](#_readlocaluploadlock) | static method (private) | A | Read the local upload lock left by an interrupted upload. |
| [`_saveLocalUploadLock`](#_savelocaluploadlock) | static method (private) | A | Persist the local upload lock before remote uploads start. |
| [`_clearLocalUploadLock`](#_clearlocaluploadlock) | static method (private) | A | Remove the local upload lock after completion/recovery. |
| [`_atomicWrite`](#_atomicwrite) | static method (private) | A | Write content to a temp file then atomically rename over the target. |
| [`_authHeaders`](#_authheaders) | static method (private) | A | Build the HTTP Basic auth header map for a config. |
| [`_remoteFileUrl`](#_remotefileurl) | static method (private) | A | Build the full remote URL for a file name under the config's remote path. |
| [`testConnection`](#testconnection) | static method | A | Test connectivity to the configured WebDAV server. |
| [`_ensureRemoteDir`](#_ensureremotedir) | static method (private) | A | MKCOL the configured remote directory (best-effort). |
| [`_upload`](#_upload) | static method (private) | A | Upload content to a remote WebDAV path with optional lock preconditions. |
| [`_strongEtag`](#_strongetag) | static method (private) | A | Return an ETag only when it is strong (not weak `W/...`). |
| [`_download`](#_download) | static method (private) | A | Download a remote data file with a discriminated found/notFound/error outcome. |
| [`_readRemoteUploadLock`](#_readremoteuploadlock) | static method (private) | A | Read and parse the remote `.lock` file. |
| [`_writeRemoteUploadLock`](#_writeremoteuploadlock) | static method (private) | A | Write the remote `.lock` file with optional preconditions. |
| [`_deleteRemoteUploadLock`](#_deleteremoteuploadlock) | static method (private) | A | Remove the remote `.lock` file if it still belongs to us. |
| [`_prepareInterruptedUpload`](#_prepareinterruptedupload) | static method (private) | A | Inspect a leftover local upload lock from a previous app run. |
| [`_acquireUploadSession`](#_acquireuploadsession) | static method (private) | A | Acquire the remote upload lock before uploading. |
| [`_refreshUploadLock`](#_refreshuploadlock) | static method (private) | A | Refresh the remote upload lock before a PUT. |
| [`_withLockHeartbeat`](#_withlockheartbeat) | static method (private) | A | Run a transfer while heartbeat-refreshing the held upload lock every 20s. |
| [`_uploadWithSession`](#_uploadwithsession) | static method (private) | A | Force-upload content after refreshing the held upload lock. |
| [`_uploadBytesWithSession`](#_uploadbyteswithsession) | static method (private) | A | Upload bytes after refreshing the held upload lock. |
| [`_releaseUploadSession`](#_releaseuploadsession) | static method (private) | A | Release the held upload lock (local + remote, if still ours). |
| [`_uploadBytes`](#_uploadbytes) | static method (private) | A | Upload raw bytes to a remote path (used for images). |
| [`_downloadBytes`](#_downloadbytes) | static method (private) | A | Download raw bytes from a remote path (used for images). |
| [`_ensureRemoteSubDir`](#_ensureremotesubdir) | static method (private) | A | MKCOL a remote sub-directory (e.g. `images/`), best-effort. |
| [`_listRemoteFiles`](#_listremotefiles) | static method (private) | A | List file names in a remote sub-directory via PROPFIND. |
| [`_getReferencedImageNames`](#_getreferencedimagenames) | static method (private) | A | Extract image basenames referenced by device records in JSON. |
| [`_syncImages`](#_syncimages) | static method (private) | A | Sync only images referenced by actual device records. |
| [`sync`](#sync) | static method | A | Sync data files with the remote using per-record three-way merge. |
| [`_syncLocked`](#_synclocked) | static method (private) | A | Run the merge-based sync body while `_syncing` is held. |
| `ensureUploadSession` (nested in `_syncLocked`) | local function | B | Return the upload session acquired before data downloads. |
| [`uploadJson`](#uploadjson) (nested in `_syncLocked`) | local function | A | Force-upload JSON while holding the remote upload lock. |
| [`_finalizeFile`](#_finalizefile) | static method (private) | A | Write a resolved data file locally, upload it, and save the base. |
| [`finalizePendingSync`](#finalizependingsync) | static method | A | Apply the user's conflict resolutions and upload each resolved file. |
| [`forceUpload`](#forceupload) | static method | A | Upload all local data/images to the remote, overwriting without merge. |
| [`_forceUploadLocked`](#_forceuploadlocked) | static method (private) | A | Run the force-upload body while `_syncing` is held. |
| [`_forceUploadImages`](#_forceuploadimages) | static method (private) | A | Upload all referenced local images during a force upload. |
| [`forceDownload`](#forcedownload) | static method | A | Replace local data/images with the remote copies, overwriting without merge. |
| [`_forceDownloadLocked`](#_forcedownloadlocked) | static method (private) | A | Run the force-download body while `_syncing` is held. |
| [`_forceDownloadImages`](#_forcedownloadimages) | static method (private) | A | Download referenced remote images during a force download. |

Row count (69) matches `grep -c 'Purpose:' webdav_service.dart` (69) exactly. This table was built
using the mandatory big-file protocol: `grep -n -B1 -A5 '/// Purpose:' webdav_service.dart` first,
then targeted `Read` calls around each Tier A candidate to confirm real signatures/behavior before
writing the Algorithm/Usage sections below. Two unrelated methods are both named `toJson`
(`WebDAVConfig.toJson` and `WebDAVUploadLock.toJson`); their anchors are disambiguated with a
class prefix (`webdavconfig-tojson` / `webdavuploadlock-tojson`) since the plain `syncNow` ->
`syncnow` anchor rule would otherwise collide on this one page.

## Documentation

### `const WebDAVConfig({required this.serverUrl, required this.username, required this.password, this.remotePath = '/MyDevice', this.autoSync = false})` <a id="webdavconfig-new"></a>
- **Kind:** constructor of `WebDAVConfig`
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 32)
- **Purpose:** Create a persisted WebDAV configuration value.
- **Inputs:** `serverUrl`, `username`, `password`; `remotePath` (default `/MyDevice`); `autoSync`
  (default false).
- **Returns:** A new `WebDAVConfig` instance.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment with defaults.
- **Usage:** Constructed directly in the WebDAV settings form
  (`lib/shared/views/webdav_config_page.dart`) and via
  [`WebDAVConfig.fromJson`](#webdavconfig-fromjson)/[`WebDAVConfig.nextcloud`](#webdavconfig-nextcloud).
- **Notes:** None.

### `WebDAVConfig copyWith({bool? autoSync})` <a id="copywith"></a>
- **Kind:** method of `WebDAVConfig`
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 53)
- **Purpose:** Create a copy of this config with only `autoSync` optionally replaced.
- **Inputs:** Optional `autoSync`.
- **Returns:** A new `WebDAVConfig` with all other fields unchanged.
- **Side effects:** None.
- **Algorithm:** Constructs a new `WebDAVConfig` copying every field, substituting `autoSync ??
  this.autoSync`.
- **Usage:**
  ```dart
  await WebDAVService.saveConfig(config.copyWith(autoSync: false));
  ```
  (from `lib/features/settings/views/backup_page.dart`, disabling auto-sync before a restore)
- **Notes:** Only `autoSync` is toggleable this way; other fields require a full new
  `WebDAVConfig`.

### `Map<String, dynamic> toJson()` <a id="webdavconfig-tojson"></a>
- **Kind:** method of `WebDAVConfig`
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 66)
- **Purpose:** Serialize this config into the JSON map persisted in `webdav_config.json`.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` with `serverUrl`, `username`, `password`, `remotePath`,
  `autoSync`.
- **Side effects:** None.
- **Algorithm:** Direct field-to-key mapping.
- **Usage:** Called by [`saveConfig`](#saveconfig).
- **Notes:** Keep the output aligned with the persisted file and sync format — this is a local
  config file, not one of the four synced data files.

### `factory WebDAVConfig.fromJson(Map<String, dynamic> json)` <a id="webdavconfig-fromjson"></a>
- **Kind:** factory constructor of `WebDAVConfig`
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 79)
- **Purpose:** Create a `WebDAVConfig` from a JSON-compatible map, tolerating missing keys.
- **Inputs:** `json`.
- **Returns:** A new `WebDAVConfig`, defaulting each field (empty string / `/MyDevice` / false) if
  absent.
- **Side effects:** None.
- **Algorithm:** `json['key'] as Type? ?? default` for each field.
- **Usage:** Called by [`loadConfig`](#loadconfig) after reading `webdav_config.json`.
- **Notes:** Use this path when preserving forward-compatible persisted fields matters (unknown
  keys are simply ignored, not preserved — this config file is not synced, so there is no
  `extraJson` round-trip concern here).

### `factory WebDAVConfig.nextcloud(String host, String username, String password)` <a id="webdavconfig-nextcloud"></a>
- **Kind:** factory constructor of `WebDAVConfig`
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 92)
- **Purpose:** Build a `WebDAVConfig` for a Nextcloud server from just its host, username, and
  password.
- **Inputs:** `host`, `username`, `password`.
- **Returns:** A new `WebDAVConfig` with `serverUrl` set to
  `https://$host/remote.php/dav/files/$username`.
- **Side effects:** None.
- **Algorithm:** String-interpolates the Nextcloud WebDAV URL convention and delegates to the
  default constructor.
- **Usage:** Convenience constructor for the WebDAV setup UI's Nextcloud preset (server URL field
  pre-fill).
- **Notes:** Only handles the standard Nextcloud DAV path shape; other WebDAV providers use the
  default constructor with an explicit `serverUrl`.

### `const SyncResult({required this.success, this.error, this.pending, this.warnings = const []})` <a id="syncresult-new"></a>
- **Kind:** constructor of `SyncResult`
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 117)
- **Purpose:** Hold the outcome of a sync/force operation: success flag, optional error, optional
  pending conflicts, and non-fatal warnings (e.g. individual image failures).
- **Inputs:** `success`; optional `error`, `pending`, `warnings`.
- **Returns:** A new `SyncResult` instance.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Returned by [`sync`](#sync), [`forceUpload`](#forceupload),
  [`forceDownload`](#forcedownload), and their `*Locked` bodies; consumed by
  `AutoSyncService.recordSyncResult` (see [`auto_sync_service.md`](auto_sync_service.md)) and the
  WebDAV page.
- **Notes:** `hasConflicts` (derived getter) being true means `pending` is set and the caller must
  route to conflict resolution instead of treating this as a normal success/failure.

### `bool get hasConflicts` (SyncResult)
- **Tier B** — trivial getter (`pending != null`); indexed in the Declarations table only, no full
  entry per the tiering rules.

### `const PendingSync({this.deviceMerge, this.networkMerge, this.dataSetMerge, this.serviceMerge})` <a id="pendingsync-new"></a>
- **Kind:** constructor of `PendingSync`
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 144)
- **Purpose:** Hold the per-module merge results that contain unresolved record conflicts, for the
  WebDAV page's conflict dialog and for [`finalizePendingSync`](#finalizependingsync).
- **Inputs:** Optional `deviceMerge`, `networkMerge`, `dataSetMerge`, `serviceMerge` — each null
  when that module had no conflicts.
- **Returns:** A new `PendingSync` instance.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Constructed by [`_syncLocked`](#_synclocked) and attached to `SyncResult.pending` when
  any module has conflicts.
- **Notes:** A null field means that module had no conflicts in this sync attempt, not that the
  module wasn't synced.

### `List<RecordConflict> get allConflicts` (PendingSync)
- **Tier B** — trivial getter concatenating the four modules' conflict lists via null-aware
  spreads; indexed in the Declarations table only.

### `const WebDAVUploadLock({required this.clientId, required this.token, required this.startedAt, required this.updatedAt, required this.ttlSeconds})` <a id="webdavuploadlock-new"></a>
- **Kind:** constructor of `WebDAVUploadLock`
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 177)
- **Purpose:** Represent the remote `.lock` file's content: which client holds the upload lock,
  its resume token, when it started/was last refreshed, and its TTL.
- **Inputs:** `clientId`, `token`, `startedAt`, `updatedAt`, `ttlSeconds`.
- **Returns:** A new `WebDAVUploadLock` instance.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Constructed by [`_acquireUploadSession`](#_acquireuploadsession) and
  [`_refreshUploadLock`](#_refreshuploadlock) before writing `.lock`.
- **Notes:** Times are stored in UTC and compared against `ttlSeconds` in
  [`isExpired`](#webdavuploadlock-new) (see the `isExpired`/`matches` Tier B rows).

### `factory WebDAVUploadLock.fromJson(Map<String, dynamic> json)` <a id="webdavuploadlock-fromjson"></a>
- **Kind:** factory constructor of `WebDAVUploadLock`
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 190)
- **Purpose:** Parse a `WebDAVUploadLock` from the downloaded `.lock` file's JSON.
- **Inputs:** `json`.
- **Returns:** A parsed `WebDAVUploadLock`; `ttlSeconds` defaults to `_lockTtlSeconds` (60) if
  absent.
- **Side effects:** None (throws on missing/malformed required fields).
- **Algorithm:** Read `clientId`/`token` as required strings; parse `startedAt`/`updatedAt` via
  `DateTime.parse(...).toUtc()`.
- **Usage:** Called by [`_readRemoteUploadLock`](#_readremoteuploadlock) after downloading
  `.lock`, inside a `try`/`catch` that treats parse failure as "no valid lock".
- **Notes:** Throws when required fields are missing or malformed; callers must catch this and
  treat it as a replaceable stale lock, not propagate the exception.

### `Map<String, dynamic> toJson()` <a id="webdavuploadlock-tojson"></a>
- **Kind:** method of `WebDAVUploadLock`
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 206)
- **Purpose:** Serialize this lock to the remote `.lock` JSON format.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` with ISO-8601 UTC timestamps.
- **Side effects:** None.
- **Algorithm:** Direct field mapping; `startedAt`/`updatedAt` are converted via
  `.toUtc().toIso8601String()`.
- **Usage:** Called by [`_writeRemoteUploadLock`](#_writeremoteuploadlock) and
  [`_saveLocalUploadLock`](#_savelocaluploadlock).
- **Notes:** None.

### `bool isExpired(DateTime now)` / `bool matches(String clientId, String token)` (WebDAVUploadLock)
- **Tier B** — two trivial one-line boolean comparisons (`isExpired`: elapsed seconds since
  `updatedAt` &gt;= `ttlSeconds`; `matches`: field equality against the given `clientId`/`token`);
  indexed in the Declarations table only.

### `WebDAVUploadLock refreshed(DateTime updatedAt)` <a id="refreshed"></a>
- **Kind:** method of `WebDAVUploadLock`
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 235)
- **Purpose:** Create a refreshed copy of this lock with a new `updatedAt`, keeping the original
  token and start time.
- **Inputs:** `updatedAt` — the new refresh timestamp.
- **Returns:** A new `WebDAVUploadLock` with `updatedAt: updatedAt.toUtc()`.
- **Side effects:** None.
- **Algorithm:** Copies `clientId`/`token`/`startedAt`/`ttlSeconds` unchanged, replaces
  `updatedAt`.
- **Usage:** Called by [`_refreshUploadLock`](#_refreshuploadlock) when the remote lock already
  belongs to this session.
- **Notes:** Keeps the original token and started time so a heartbeat refresh cannot accidentally
  look like a new lock acquisition.

### `_UploadSession({required this.clientId, required this.token})`
- **Tier B** — trivial forwarding constructor of the private `_UploadSession` marker class used
  to prove a caller currently holds the upload lock; indexed in the Declarations table only.

### `const RemoteFile.found(String this.content, {this.etag})` <a id="remotefile-found"></a>
- **Kind:** constructor of `RemoteFile`
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 277)
- **Purpose:** Represent a successful remote file download.
- **Inputs:** `content` (required, positional); optional `etag`.
- **Returns:** A `RemoteFile` with `status = RemoteFileStatus.found`, `error = null`.
- **Side effects:** None.
- **Algorithm:** Initializer-list assignment; `content` is a promoted non-null field only on this
  constructor.
- **Usage:** Constructed by [`_download`](#_download) on HTTP 200.
- **Notes:** None.

### `const RemoteFile.notFound()` <a id="remotefile-notfound"></a>
- **Kind:** constructor of `RemoteFile`
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 286)
- **Purpose:** Represent an HTTP 404 — the file genuinely does not exist on the remote yet.
- **Inputs:** None.
- **Returns:** A `RemoteFile` with `status = RemoteFileStatus.notFound`, all other fields null.
- **Side effects:** None.
- **Algorithm:** Initializer-list assignment of the fixed status.
- **Usage:** Constructed by [`_download`](#_download) on HTTP 404; matched explicitly by
  `_syncLocked`/`_forceDownloadLocked` as the only status that may be treated as "missing".
- **Notes:** This is the *only* status a caller may treat as "safe to upload local as new" — see
  the file-level note above the Declarations table.

### `const RemoteFile.failure(String this.error)` <a id="remotefile-failure"></a>
- **Kind:** constructor of `RemoteFile`
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 297)
- **Purpose:** Represent any non-404 download failure (network, auth, server error).
- **Inputs:** `error` — a message describing the failure.
- **Returns:** A `RemoteFile` with `status = RemoteFileStatus.error`, `content`/`etag` null.
- **Side effects:** None.
- **Algorithm:** Initializer-list assignment.
- **Usage:** Constructed by [`_download`](#_download) on any HTTP status other than 200/404, or on
  a thrown exception (timeout, socket error, etc.).
- **Notes:** Callers must never treat this the same as `notFound` — doing so is exactly the bug
  this discriminated result type exists to prevent (per `RemoteFile`'s class doc comment and
  `../../../AGENTS.md`).

### `static bool consumeLocalDataChanged()` <a id="consumelocaldatachanged"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 334)
- **Purpose:** Read and reset whether the most recent sync/force operation wrote local data files.
- **Inputs:** None.
- **Returns:** `bool` — the previous value of the internal `_localDataChanged` flag.
- **Side effects:** Resets `_localDataChanged` to `false`.
- **Algorithm:** Read-then-clear: capture the current flag value, set it false, return the
  captured value.
- **Usage:**
  ```dart
  if (WebDAVService.consumeLocalDataChanged()) {
    for (final cb in List.of(_onLocalDataChanged)) {
      cb();
    }
  }
  ```
  (from `AutoSyncService._trySync` and `notifyLocalDataChangedIfNeeded`, `lib/shared/services/auto_sync_service.dart`)
- **Notes:** Consume-once semantics mean only one caller per sync cycle sees `true`; both
  `AutoSyncService` and the WebDAV page rely on this to avoid double-triggering UI reloads.

### `static void _reportProgress(SyncPhase phase, {String? detail, int current = 0, int total = 0})` <a id="_reportprogress"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 353)
- **Purpose:** Publish a new `SyncProgress` snapshot for the currently running sync/force
  operation.
- **Inputs:** `phase`; optional `detail`, `current`, `total`.
- **Returns:** None.
- **Side effects:** Sets `progress.value` to a new `SyncProgress` (see
  [`sync_progress.md`](sync_progress.md)).
- **Algorithm:** Directly constructs and assigns a new `SyncProgress` value — no branching.
- **Usage:** Called throughout `_syncLocked`, `_syncImages`, `_forceUploadLocked`,
  `_forceDownloadLocked`, and their image helpers to report phase transitions and per-file/per-image
  progress.
- **Notes:** `ValueNotifier` assignment triggers listener rebuilds synchronously, so callers should
  avoid reporting progress from a tight non-async loop without awaiting between reports (all
  current call sites are inside `await`-separated iterations).

### `static Future<T> _withRetry<T>(Future<T> Function() attempt, {bool Function(T value)? shouldRetry, int retries = 2})` <a id="_withretry"></a>
- **Kind:** private static generic method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 375)
- **Purpose:** Retry a network operation up to `retries` extra times on transient failures, with
  linear 1s/2s backoff.
- **Inputs:** `attempt` — the operation to run; optional `shouldRetry` predicate on a *successful*
  result (used to retry HTTP 5xx responses); `retries` (default 2 extra attempts).
- **Returns:** `Future<T>` — the last attempt's value, or rethrows the last transient exception
  once retries are exhausted.
- **Side effects:** `await`s a `Duration(seconds: attemptIndex)` delay between attempts.
- **Algorithm:** Loop indefinitely: 1. Run `attempt()`. 2. If it succeeded and
  `shouldRetry?.call(value)` is true and attempts remain, delay and retry. 3. Otherwise return the
  value. 4. On a caught exception, check if it is transient (`SocketException`, `TimeoutException`,
  `http.ClientException`, or `HttpException`); if not transient or retries are exhausted, rethrow;
  otherwise delay and retry.
- **Usage:**
  ```dart
  final response = await _withRetry(
    () => http.get(url, headers: _authHeaders(config)).timeout(const Duration(seconds: 30)),
    shouldRetry: (r) => r.statusCode >= 500,
  );
  ```
  (from [`_download`](#_download); the same pattern is used by [`_upload`](#_upload),
  [`_uploadBytes`](#_uploadbytes), [`_downloadBytes`](#_downloadbytes), and
  [`_listRemoteFiles`](#_listremotefiles))
- **Notes:** 4xx responses are never retried (callers only pass a `shouldRetry` checking `>= 500`).
  `.lock` writes ([`_writeRemoteUploadLock`](#_writeremoteuploadlock)) pass `retries: 0` through
  [`_upload`](#_upload) so a retried create-only PUT cannot misreport lock contention as a 412.

### `static Future<WebDAVConfig?> loadConfig()` <a id="loadconfig"></a>
- **Kind:** static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 410)
- **Purpose:** Load the persisted WebDAV configuration from `webdav_config.json`.
- **Inputs:** None.
- **Returns:** `Future<WebDAVConfig?>` — null if the file is absent or unparseable.
- **Side effects:** Reads `webdav_config.json` from the app directory.
- **Algorithm:** If the file doesn't exist, return null; else JSON-decode and parse via
  [`WebDAVConfig.fromJson`](#webdavconfig-fromjson); any exception yields null.
- **Usage:**
  ```dart
  final config = await WebDAVService.loadConfig();
  if (config == null || !config.isConfigured || !config.autoSync) return;
  ```
  (from `AutoSyncService._trySync`, `lib/shared/services/auto_sync_service.dart`; also used
  directly by the WebDAV settings page)
- **Notes:** None.

### `static Future<void> saveConfig(WebDAVConfig config)` <a id="saveconfig"></a>
- **Kind:** static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 428)
- **Purpose:** Persist a `WebDAVConfig` to `webdav_config.json`.
- **Inputs:** `config`.
- **Returns:** `Future<void>`.
- **Side effects:** Writes `webdav_config.json` (non-atomic direct write — this is local config,
  not synced data).
- **Algorithm:** JSON-encode `config.toJson()` and write it directly to the config file path.
- **Usage:**
  ```dart
  await WebDAVService.saveConfig(config);
  ```
  (from `lib/shared/views/webdav_config_page.dart`, saving the settings form)
- **Notes:** Unlike the four synced data files, this write is not tmp-then-rename atomic.

### `static Future<void> deleteConfig()` <a id="deleteconfig"></a>
- **Kind:** static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 439)
- **Purpose:** Delete the persisted WebDAV config file, effectively disabling sync.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Deletes `webdav_config.json` if it exists.
- **Algorithm:** Check existence, delete if present.
- **Usage:** Called from the WebDAV settings page's "remove configuration" action.
- **Notes:** None.

### `static Future<Directory> _getBaseDir()` <a id="_getbasedir"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 452)
- **Purpose:** Resolve the `.sync_base/` directory (last-synced snapshot storage), creating it if
  missing.
- **Inputs:** None.
- **Returns:** `Future<Directory>`.
- **Side effects:** Creates `.sync_base/` if it doesn't exist.
- **Algorithm:** Join the app dir path with `_syncBaseDirName`; create if absent.
- **Usage:** Called by every base-snapshot and local-lock helper in this file (`_readBase`,
  `_saveBase`, `_loadClientId`, `_readLocalUploadLock`, `_saveLocalUploadLock`,
  `_clearLocalUploadLock`).
- **Notes:** None.

### `static Future<String?> _readBase(String fileName)` <a id="_readbase"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 464)
- **Purpose:** Read a data file's last-synced base snapshot from `.sync_base/`.
- **Inputs:** `fileName`.
- **Returns:** `Future<String?>` — null if absent or unreadable.
- **Side effects:** None (read-only).
- **Algorithm:** Check existence in the base dir; read if present; any exception yields null.
- **Usage:** Called by [`_syncLocked`](#_synclocked) to load each data file's base snapshot before
  merging.
- **Notes:** A null base is treated by `mergeRecords` (see [`sync_merge.md`](sync_merge.md)) as
  "first sync or both sides independently added the same ID".

### `static Future<void> _saveBase(String fileName, String content)` <a id="_savebase"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 480)
- **Purpose:** Atomically write a data file's new base snapshot after a successful sync/upload.
- **Inputs:** `fileName`, `content`.
- **Returns:** `Future<void>`.
- **Side effects:** Writes `.sync_base/<fileName>` via [`_atomicWrite`](#_atomicwrite).
- **Algorithm:** Resolve the base dir, delegate to `_atomicWrite`.
- **Usage:** Called by [`_syncLocked`](#_synclocked), [`_finalizeFile`](#_finalizefile),
  [`_forceUploadLocked`](#_forceuploadlocked), and [`_forceDownloadLocked`](#_forcedownloadlocked)
  after every successful per-file transfer.
- **Notes:** Per `../../../AGENTS.md`, the base snapshot is only saved after the corresponding
  upload/download succeeds, never before — a failed file keeps its old base so the next sync
  re-merges it correctly.

### `static Future<String> _loadClientId()` <a id="_loadclientid"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 491)
- **Purpose:** Load this device's stable local WebDAV client ID, creating one on first use.
- **Inputs:** None.
- **Returns:** `Future<String>` — a UUID v4 string.
- **Side effects:** May create and write `.sync_base/client_id.txt`.
- **Algorithm:** If the file exists and its trimmed content is non-empty, return it. Otherwise
  generate a new `Uuid().v4()`, write it (non-atomically) to the file, and return it.
- **Usage:** Called at the start of [`_syncLocked`](#_synclocked),
  [`finalizePendingSync`](#finalizependingsync), and [`_forceUploadLocked`](#_forceuploadlocked) to
  identify this device to the upload-lock protocol.
- **Notes:** The client ID is local-only and is never synced or exported — it exists purely to let
  the lock protocol distinguish "this device's lock" from "another device's lock".

### `static Future<WebDAVUploadLock?> _readLocalUploadLock()` <a id="_readlocaluploadlock"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 508)
- **Purpose:** Read the local record of an upload lock left by a possibly-interrupted previous
  upload.
- **Inputs:** None.
- **Returns:** `Future<WebDAVUploadLock?>` — null if absent or unparseable.
- **Side effects:** None (read-only).
- **Algorithm:** Read and JSON-decode `.sync_base/upload_lock.json`, parse via
  `WebDAVUploadLock.fromJson`; any exception yields null.
- **Usage:** Called by [`_prepareInterruptedUpload`](#_prepareinterruptedupload) at the start of
  every sync/force-upload attempt.
- **Notes:** Invalid local locks are ignored and effectively overwritten on the next upload
  attempt.

### `static Future<void> _saveLocalUploadLock(WebDAVUploadLock lock)` <a id="_savelocaluploadlock"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 526)
- **Purpose:** Persist the local upload lock record before remote uploads begin, so an interrupted
  process can detect it on the next launch.
- **Inputs:** `lock`.
- **Returns:** `Future<void>`.
- **Side effects:** Atomically writes `.sync_base/upload_lock.json`.
- **Algorithm:** JSON-encode `lock.toJson()`, write via [`_atomicWrite`](#_atomicwrite).
- **Usage:** Called by [`_acquireUploadSession`](#_acquireuploadsession) and
  [`_refreshUploadLock`](#_refreshuploadlock) after a successful remote lock write.
- **Notes:** The local lock lets the next app start detect interrupted uploads via
  [`_prepareInterruptedUpload`](#_prepareinterruptedupload).

### `static Future<void> _clearLocalUploadLock()` <a id="_clearlocaluploadlock"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 537)
- **Purpose:** Remove the local upload lock record after successful completion or detected
  recovery.
- **Inputs:** None.
- **Returns:** None (`Future<void>`).
- **Side effects:** Deletes `.sync_base/upload_lock.json` if present.
- **Algorithm:** Check existence, delete if present; missing file is a silent no-op.
- **Usage:** Called by [`_prepareInterruptedUpload`](#_prepareinterruptedupload) (on recovery) and
  [`_releaseUploadSession`](#_releaseuploadsession) (on normal completion).
- **Notes:** None.

### `static Future<void> _atomicWrite(File file, String content)` <a id="_atomicwrite"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 552)
- **Purpose:** Write content to a temp file then atomically rename it over the target, so a killed
  process never leaves a corrupted data file.
- **Inputs:** `file`, `content`.
- **Returns:** `Future<void>`.
- **Side effects:** Writes `<file>.tmp`, then renames it over `file`.
- **Algorithm:** Write to `'${file.path}.tmp'`, then `rename()` it over the target path (no
  explicit cleanup on rename failure, unlike `BackupService`'s equivalent helper — see
  [`backup_service.md`](backup_service.md)).
- **Usage:** Called throughout this file for every local data/base file write:
  `_syncLocked`/`_finalizeFile`/`_forceUploadLocked`/`_forceDownloadLocked`, plus `_saveBase`.
- **Notes:** Prevents data corruption if the app is killed during write, matching `_atomicWrite()`
  in `../../../AGENTS.md`'s sync constraints.

### `static Map<String, String> _authHeaders(WebDAVConfig config)` <a id="_authheaders"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 565)
- **Purpose:** Build the HTTP Basic Authorization header for a given config.
- **Inputs:** `config`.
- **Returns:** `Map<String, String>` with one `Authorization: Basic <base64>` entry.
- **Side effects:** None.
- **Algorithm:** Base64-encode `'$username:$password'` and wrap it in the `Authorization` header.
- **Usage:** Called by every network request in this file (`testConnection`, `_ensureRemoteDir`,
  `_upload`, `_download`, `_uploadBytes`, `_downloadBytes`, `_ensureRemoteSubDir`,
  `_listRemoteFiles`, `_deleteRemoteUploadLock`).
- **Notes:** Credentials are only ever sent as Basic Auth over the configured `serverUrl`; the app
  does not implement any other auth scheme.

### `static String _remoteFileUrl(WebDAVConfig config, String fileName)` <a id="_remotefileurl"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 577)
- **Purpose:** Build the full remote URL for a file name under the config's server URL and remote
  path.
- **Inputs:** `config`, `fileName`.
- **Returns:** `String` — a well-formed URL with exactly one `/` between path segments.
- **Side effects:** None.
- **Algorithm:** Strip a trailing `/` from `serverUrl` if present; ensure `remotePath` ends with
  `/`; concatenate `base + path + fileName`.
- **Usage:** Called by every helper that builds a `Uri` for a data/lock/image file
  (`_upload`, `_download`, `_uploadBytes`, `_downloadBytes`, `_writeRemoteUploadLock` via `_upload`,
  `_deleteRemoteUploadLock`).
- **Notes:** None.

### `static Future<bool> testConnection(WebDAVConfig config)` <a id="testconnection"></a>
- **Kind:** static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 592)
- **Purpose:** Test connectivity and credentials against the configured WebDAV server.
- **Inputs:** `config`.
- **Returns:** `Future<bool>` — true if the server responded with 207 (Multi-Status) or 404.
- **Side effects:** Sends a `PROPFIND` request with `Depth: 0` to the remote path.
- **Algorithm:** Build the remote directory URL, send a minimal `PROPFIND` request with a 10s
  timeout, return `true` for status 207 or 404 (either means the server is reachable and
  authenticated even if the directory doesn't exist yet), `false` on any other status or exception.
- **Usage:**
  ```dart
  final ok = await WebDAVService.testConnection(_currentConfig);
  ```
  (from `lib/shared/views/webdav_config_page.dart`, the settings form's "Test connection" button)
- **Notes:** A 404 is accepted as success because the remote directory may not exist yet — it will
  be created by [`_ensureRemoteDir`](#_ensureremotedir) on first real sync.

### `static Future<void> _ensureRemoteDir(WebDAVConfig config)` <a id="_ensureremotedir"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 619)
- **Purpose:** Create the configured remote directory if it doesn't already exist (best-effort).
- **Inputs:** `config`.
- **Returns:** `Future<void>`.
- **Side effects:** Sends an `MKCOL` request to the remote path; ignores all errors.
- **Algorithm:** Build an `MKCOL` request with auth headers and a 10s timeout; swallow any
  exception (the directory may already exist, which most servers report as an error status that is
  irrelevant here).
- **Usage:** Called at the start of [`_syncLocked`](#_synclocked) and
  [`_forceUploadLocked`](#_forceuploadlocked), before any file transfer.
- **Notes:** Best-effort only — a failure here does not abort the sync, since the directory
  typically already exists after the first successful sync.

### `static Future<({bool is412, String? error})> _upload(WebDAVConfig config, String fileName, String content, {String? ifMatchEtag, bool ifNoneMatchAll = false, int retries = 2})` <a id="_upload"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 640)
- **Purpose:** PUT content to a remote WebDAV path, optionally with conditional-request headers
  for `.lock` writes.
- **Inputs:** `config`, `fileName`, `content`; optional `ifMatchEtag` (conditional update),
  `ifNoneMatchAll` (create-only PUT via `If-None-Match: *`); `retries` (default 2, callers pass 0
  for `.lock` writes).
- **Returns:** A record `(is412, error)` — `error == null` means success; `is412` distinguishes a
  precondition-failed response from other errors.
- **Side effects:** Sends an HTTP PUT with a 30s timeout, retried via
  [`_withRetry`](#_withretry) on HTTP 5xx.
- **Algorithm:** 1. Build the URL and headers, including `If-Match`/`If-None-Match` only when
  provided. 2. PUT via `_withRetry` with `shouldRetry: (r) => r.statusCode >= 500`. 3. Map status
  412 to `(is412: true, error: '...')`; 2xx to `(is412: false, error: null)`; anything else to
  `(is412: false, error: 'HTTP <code>')`. 4. Catch any exception into `(is412: false, error:
  '$e')`.
- **Usage:** Called by [`_writeRemoteUploadLock`](#_writeremoteuploadlock) (with `retries: 0`) and
  indirectly by [`_uploadWithSession`](#_uploadwithsession) (no preconditions, default retries) for
  data JSON PUTs.
- **Notes:** Data JSON writes go through `_uploadWithSession()` and intentionally pass no
  data-file preconditions — `.lock` is the sole concurrency guard for data files, per
  `../../../AGENTS.md`. Retries cover network errors and HTTP 5xx only; `.lock` writes pass
  `retries: 0` so a retried create-only PUT cannot misreport lock contention as a 412.

### `static String? _strongEtag(String? etag)` <a id="_strongetag"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 684)
- **Purpose:** Return the given ETag only when it is a strong ETag usable for `.lock`
  `If-Match` preconditions.
- **Inputs:** `etag` — possibly null or weak (prefixed `W/`).
- **Returns:** `String?` — the strong ETag, or null when absent or weak.
- **Side effects:** None.
- **Algorithm:** Return null if `etag` is null or starts with `'W/'`; otherwise return `etag`
  unchanged.
- **Usage:** Called by [`_readRemoteUploadLock`](#_readremoteuploadlock) on the downloaded
  `.lock` response's ETag before it is used as an `If-Match` precondition.
- **Notes:** Weak ETags must not be used in `.lock` `If-Match` preconditions per RFC 9110's strong
  comparison requirement — using a weak ETag there could let a semantically-different lock body
  pass the precondition check.

### `static Future<RemoteFile> _download(WebDAVConfig config, String fileName)` <a id="_download"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 698)
- **Purpose:** Download a remote data file, discriminating "genuinely missing" (404) from any
  other failure.
- **Inputs:** `config`, `fileName`.
- **Returns:** `Future<RemoteFile>` — `.found` with content/ETag on 200, `.notFound` on 404,
  `.failure` for any other status or exception.
- **Side effects:** Sends an HTTP GET with a 30s timeout, retried via `_withRetry` on HTTP 5xx.
- **Algorithm:** 1. GET the file URL via `_withRetry` (`shouldRetry: statusCode >= 500`).
  2. Status 200 → `RemoteFile.found(body, etag: headers['etag'])`. 3. Status 404 →
  `RemoteFile.notFound()`. 4. Any other status → `RemoteFile.failure('HTTP <code>')`. 5. Any
  thrown exception → `RemoteFile.failure('$e')`.
- **Usage:**
  ```dart
  final remote = await _download(config, name);
  if (remote.status == RemoteFileStatus.error) {
    perFileErrors.add('$name: download failed: ${remote.error}');
    continue;
  }
  ```
  (from [`_syncLocked`](#_synclocked), the exact per-file error-skip behavior described at the
  top of this page; also called by [`_readRemoteUploadLock`](#_readremoteuploadlock),
  [`_finalizeFile`](#_finalizefile), and [`_forceDownloadLocked`](#_forcedownloadlocked))
- **Notes:** Callers must treat only `notFound` as "file missing on remote"; an `error` outcome
  (auth/server/network failure) must abort that file's sync so local data is never uploaded over
  an unreadable remote file — this is the central implementation of the discriminated-download
  rule referenced throughout `../../../AGENTS.md` and at the top of this page.

### `static Future<({WebDAVUploadLock? lock, String? etag, String? error})> _readRemoteUploadLock(WebDAVConfig config)` <a id="_readremoteuploadlock"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 725)
- **Purpose:** Download and parse the remote `.lock` file, treating a missing or malformed lock as
  "no lock" rather than an error.
- **Inputs:** `config`.
- **Returns:** A record `(lock, etag, error)`; `error` non-null only for a true download failure
  (not 404, not a parse failure).
- **Side effects:** Downloads `.lock` via [`_download`](#_download).
- **Algorithm:** 1. Download `.lock`. 2. If the download errored, propagate `error`. 3. If not
  found (or content null), return `(null, null, null)` — no lock exists. 4. Try to parse the JSON
  into a `WebDAVUploadLock`, returning its `_strongEtag`; on parse failure return `(null,
  strongEtag, null)` — a malformed lock is treated as absent but its ETag is still returned for a
  create/overwrite precondition.
- **Usage:** Called by [`_prepareInterruptedUpload`](#_prepareinterruptedupload),
  [`_acquireUploadSession`](#_acquireuploadsession), [`_refreshUploadLock`](#_refreshuploadlock),
  and [`_releaseUploadSession`](#_releaseuploadsession).
- **Notes:** Missing or malformed locks are treated as replaceable stale locks, not as blocking
  errors — only a true network/auth/server failure downloading `.lock` propagates as `error`.

### `static Future<({bool is412, String? error})> _writeRemoteUploadLock(WebDAVConfig config, WebDAVUploadLock lock, {String? ifMatchEtag, bool ifNoneMatchAll = false})` <a id="_writeremoteuploadlock"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 751)
- **Purpose:** Write the remote `.lock` file with optional conditional-request preconditions.
- **Inputs:** `config`, `lock`; optional `ifMatchEtag`, `ifNoneMatchAll`.
- **Returns:** Same shape as [`_upload`](#_upload).
- **Side effects:** PUTs `.lock` content via `_upload` with `retries: 0`.
- **Algorithm:** Thin wrapper delegating to `_upload(config, _lockFileName, jsonEncode(lock.toJson()),
  ifMatchEtag: ..., ifNoneMatchAll: ..., retries: 0)`.
- **Usage:** Called by [`_acquireUploadSession`](#_acquireuploadsession) and
  [`_refreshUploadLock`](#_refreshuploadlock).
- **Notes:** Uses the same conditional PUT helper as data uploads, but always with `retries: 0` so
  a retried create-only PUT can never misreport lock contention.

### `static Future<void> _deleteRemoteUploadLock(WebDAVConfig config, {String? etag})` <a id="_deleteremoteuploadlock"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 772)
- **Purpose:** Remove the remote `.lock` file, conditionally on the given ETag if still owned by
  this session.
- **Inputs:** `config`; optional `etag` (sent as `If-Match`).
- **Returns:** None (`Future<void>`).
- **Side effects:** Sends an HTTP DELETE with a 10s timeout; swallows all errors.
- **Algorithm:** DELETE the lock URL with `If-Match: ?etag` (conditional header, only sent if
  non-null); ignore any exception.
- **Usage:** Called by [`_releaseUploadSession`](#_releaseuploadsession) only when the remote lock
  still matches this session's client/token.
- **Notes:** Errors are ignored because a stale lock naturally expires after its TTL even if this
  delete fails.

### `static Future<({String? resumeToken, String? error})> _prepareInterruptedUpload(WebDAVConfig config, String clientId)` <a id="_prepareinterruptedupload"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 792)
- **Purpose:** Detect and handle a local upload-lock record left by an interrupted previous
  upload, before starting a new sync/force-upload attempt.
- **Inputs:** `config`, `clientId`.
- **Returns:** A record `(resumeToken, error)` — a non-null `resumeToken` lets the caller resume
  the same lock token instead of minting a new one; a non-null `error` means the caller must abort.
- **Side effects:** May clear the local lock file via `_clearLocalUploadLock()`.
- **Algorithm:** 1. Read the local lock; if none, return `(null, null)`. 2. Read the remote lock;
  if that download errored, propagate the error (caller aborts). 3. If the remote lock is gone
  entirely, clear the local record and return `(null, null)`. 4. If the remote lock matches this
  local lock's client/token *and* the local lock's client matches the current `clientId`, return
  its token as `resumeToken` (this device's own interrupted upload — safe to resume). 5. If the
  remote lock belongs to a *different* client and is not expired, return a blocking error (another
  device is actively uploading). 6. Otherwise (expired, or some other stale state) clear the local
  record and return `(null, null)`.
- **Usage:** Called at the start of [`_syncLocked`](#_synclocked),
  [`finalizePendingSync`](#finalizependingsync), and [`_forceUploadLocked`](#_forceuploadlocked),
  before [`_acquireUploadSession`](#_acquireuploadsession).
- **Notes:** Normal sync after this step re-downloads, merges, and uploads — resuming a token does
  not skip the merge, it only lets the new attempt reuse the same lock identity instead of racing
  its own still-active lock.

### `static Future<({_UploadSession? session, String? error})> _acquireUploadSession(WebDAVConfig config, String clientId, {String? resumeToken})` <a id="_acquireuploadsession"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 827)
- **Purpose:** Acquire the remote WebDAV upload lock before any upload begins.
- **Inputs:** `config`, `clientId`; optional `resumeToken` (from
  [`_prepareInterruptedUpload`](#_prepareinterruptedupload)).
- **Returns:** A record `(session, error)` — `session` non-null on success.
- **Side effects:** Writes the local lock file and the remote `.lock` file.
- **Algorithm:** 1. Read the remote lock; propagate any download error. 2. If an unexpired lock
  is held by a *different* client, return a blocking error. 3. Build a new `WebDAVUploadLock` with
  `token: resumeToken ?? Uuid().v4()` and TTL `_lockTtlSeconds`. 4. Write it remotely with
  `ifMatchEtag: remote.etag` (conditional replace) or, if no lock/etag existed,
  `ifNoneMatchAll: true` (create-only). 5. On a 412 (lost the race), return a "another device
  started uploading" error; on any other write error, propagate it. 6. On success, save the lock
  locally and return the session (`clientId`, `lock.token`).
- **Usage:**
  ```dart
  final acquired = await _acquireUploadSession(config, clientId, resumeToken: interrupted.resumeToken);
  uploadSession = acquired.session;
  if (uploadSession == null) {
    return SyncResult(success: false, error: acquired.error ?? 'Upload lock was not acquired');
  }
  ```
  (from [`_syncLocked`](#_synclocked); the same pattern appears in
  [`finalizePendingSync`](#finalizependingsync) and [`_forceUploadLocked`](#_forceuploadlocked))
- **Notes:** Active locks owned by other clients block uploads until expiry (60s TTL); the
  create-only `If-None-Match: *` path prevents two clients from both succeeding at creating the
  lock file from a race.

### `static Future<String?> _refreshUploadLock(WebDAVConfig config, _UploadSession session)` <a id="_refreshuploadlock"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 879)
- **Purpose:** Refresh (re-write with a new `updatedAt`) the remote upload lock immediately before
  a PUT, and periodically as a heartbeat during long transfers.
- **Inputs:** `config`, `session`.
- **Returns:** `Future<String?>` — an error message if refresh failed/was blocked, else null.
- **Side effects:** Writes local and remote lock files.
- **Algorithm:** 1. Read the remote lock; propagate any download error. 2. If an unexpired lock
  exists that does *not* match this session's client/token and belongs to a different client,
  return a blocking error. 3. If the remote lock matches this session, refresh it (new
  `updatedAt`, same token); otherwise (lock missing/expired) mint a fresh lock with this session's
  identity. 4. Write it remotely with the appropriate precondition (as in
  [`_acquireUploadSession`](#_acquireuploadsession)); map a 412 to a "another device started
  uploading" message. 5. On success, save the lock locally and return null.
- **Usage:** Called directly by [`_uploadWithSession`](#_uploadwithsession) and
  [`_uploadBytesWithSession`](#_uploadbyteswithsession) before their PUT, and periodically by
  [`_withLockHeartbeat`](#_withlockheartbeat)'s timer callback.
- **Notes:** If another active client owns the lock, uploading is blocked — this is what turns a
  lost-lock race into a visible sync error rather than a silent data clobber.

### `static Future<T> _withLockHeartbeat<T>(WebDAVConfig config, _UploadSession session, Future<T> Function() operation)` <a id="_withlockheartbeat"></a>
- **Kind:** private static generic method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 930)
- **Purpose:** Run a long-lived transfer while periodically re-refreshing the held upload lock so
  it cannot expire mid-transfer.
- **Inputs:** `config`, `session`, `operation` — the in-flight transfer to run.
- **Returns:** `operation()`'s result, unchanged.
- **Side effects:** Starts a `Timer.periodic` (every `_lockHeartbeatInterval`, 20s) that calls
  [`_refreshUploadLock`](#_refreshuploadlock); cancels the timer when `operation()` completes (in
  `finally`).
- **Algorithm:** 1. Start a periodic timer with a re-entrancy guard (`refreshing` flag) so
  overlapping ticks cannot pile up. 2. Each tick calls `_refreshUploadLock`, swallowing any
  exception (best-effort). 3. Await `operation()`. 4. In `finally`, cancel the timer regardless of
  success/failure/exception.
- **Usage:** Called by [`_uploadWithSession`](#_uploadwithsession) and
  [`_uploadBytesWithSession`](#_uploadbyteswithsession) to wrap their actual PUT call.
- **Notes:** Without this heartbeat, a single PUT slower than the 60-second lock TTL would let
  another client treat the lock as expired and upload concurrently, silently reverting that
  client's changes on its next merge. Heartbeat failures are swallowed: they must never abort a
  transfer that is already in flight.

### `static Future<({bool is412, String? error})> _uploadWithSession(WebDAVConfig config, String fileName, String content, _UploadSession session)` <a id="_uploadwithsession"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 962)
- **Purpose:** Force-upload a data JSON file's content while holding (and heartbeat-refreshing) the
  upload lock.
- **Inputs:** `config`, `fileName`, `content`, `session`.
- **Returns:** Same shape as [`_upload`](#_upload).
- **Side effects:** Refreshes the lock, then PUTs the content, heartbeat-refreshing throughout.
- **Algorithm:** 1. Refresh the lock immediately; if that fails, return the error without
  attempting the PUT. 2. Otherwise run `_upload(config, fileName, content)` (no data-file
  preconditions) wrapped in [`_withLockHeartbeat`](#_withlockheartbeat).
- **Usage:** Called by [`uploadJson`](#uploadjson) (the nested helper inside
  [`_syncLocked`](#_synclocked)) and by [`_finalizeFile`](#_finalizefile) and
  [`_forceUploadLocked`](#_forceuploadlocked).
- **Notes:** Data JSON writes are protected by `.lock`, so they intentionally do not send
  data-file `If-Match`/`If-None-Match` preconditions.

### `static Future<bool> _uploadBytesWithSession(WebDAVConfig config, String fileName, Uint8List bytes, _UploadSession session)` <a id="_uploadbyteswithsession"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 984)
- **Purpose:** Upload image bytes while holding (and heartbeat-refreshing) the upload lock.
- **Inputs:** `config`, `fileName`, `bytes`, `session`.
- **Returns:** `Future<bool>` — true on success; throws on failure (see Notes).
- **Side effects:** Refreshes the lock, then uploads the bytes, heartbeat-refreshing throughout.
- **Algorithm:** 1. Refresh the lock; if that fails, `throw Exception(lockError)`. 2. Otherwise
  run `_uploadBytes(config, fileName, bytes)` wrapped in `_withLockHeartbeat`.
- **Usage:** Called by [`_syncImages`](#_syncimages) and [`_forceUploadImages`](#_forceuploadimages)
  for each image to upload.
- **Notes:** Unlike `_uploadWithSession`, a lock-refresh failure here throws rather than returning
  an error record; callers catch it as a per-image warning rather than aborting the whole sync.

### `static Future<void> _releaseUploadSession(WebDAVConfig config, _UploadSession? session)` <a id="_releaseuploadsession"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 1004)
- **Purpose:** Release the held WebDAV upload lock at the end of a sync/force-upload attempt.
- **Inputs:** `config`, `session` (nullable — a no-op if the lock was never acquired).
- **Returns:** None (`Future<void>`).
- **Side effects:** Deletes the local lock file and, conditionally, the remote `.lock` file.
- **Algorithm:** 1. If `session` is null, return. 2. Read the remote lock; if it still matches
  this session's client/token, delete it remotely with the matching ETag. 3. Always clear the
  local lock record.
- **Usage:** Called in a `finally` block by [`_syncLocked`](#_synclocked),
  [`finalizePendingSync`](#finalizependingsync), and [`_forceUploadLocked`](#_forceuploadlocked).
- **Notes:** Remote delete only runs if the lock still has our client ID and token, so releasing
  never deletes a lock another device has since acquired (e.g. after our lock expired and was
  replaced).

### `static Future<bool> _uploadBytes(WebDAVConfig config, String remotePath, Uint8List bytes)` <a id="_uploadbytes"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 1023)
- **Purpose:** PUT raw bytes to a remote path (used for image uploads), with retry on transient
  failure.
- **Inputs:** `config`, `remotePath`, `bytes`.
- **Returns:** `Future<bool>` — true on 2xx; throws `Exception('HTTP <code>')` on any other
  status.
- **Side effects:** Sends an HTTP PUT with a 120s timeout, retried via `_withRetry` on HTTP 5xx.
- **Algorithm:** PUT the bytes with auth + octet-stream headers via `_withRetry`; throw if the
  final status is outside 200-299.
- **Usage:** Called by [`_uploadBytesWithSession`](#_uploadbyteswithsession).
- **Notes:** No data-file conditional headers — image files have no revision-conflict concept in
  this app, only presence/absence.

### `static Future<Uint8List?> _downloadBytes(WebDAVConfig config, String remotePath)` <a id="_downloadbytes"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 1053)
- **Purpose:** GET raw bytes from a remote path (used for image downloads), with retry on
  transient failure.
- **Inputs:** `config`, `remotePath`.
- **Returns:** `Future<Uint8List?>` — the body bytes on 200; throws `Exception('HTTP <code>')`
  otherwise (there is no discriminated-404 handling here, unlike `_download`).
- **Side effects:** Sends an HTTP GET with a 120s timeout, retried via `_withRetry` on HTTP 5xx.
- **Algorithm:** GET via `_withRetry`; return `bodyBytes` on 200; throw otherwise.
- **Usage:** Called by [`_syncImages`](#_syncimages), [`_forceDownloadImages`](#_forcedownloadimages).
- **Notes:** Callers catch the thrown exception per-image and record it as a non-fatal warning
  rather than aborting the whole image phase.

### `static Future<void> _ensureRemoteSubDir(WebDAVConfig config, String subDir)` <a id="_ensureremotesubdir"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 1073)
- **Purpose:** Create a remote sub-directory (e.g. `images/`) if it doesn't already exist
  (best-effort).
- **Inputs:** `config`, `subDir`.
- **Returns:** None (`Future<void>`).
- **Side effects:** Sends an `MKCOL` request; ignores all errors.
- **Algorithm:** Same shape as [`_ensureRemoteDir`](#_ensureremotedir) but targeting
  `'$subDir/'` under the remote path.
- **Usage:** Called by [`_syncImages`](#_syncimages) and [`_forceUploadImages`](#_forceuploadimages)
  before transferring any images.
- **Notes:** None.

### `static Future<Set<String>?> _listRemoteFiles(WebDAVConfig config, String subDir)` <a id="_listremotefiles"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 1094)
- **Purpose:** List file names present in a remote sub-directory via a `PROPFIND` request, so
  callers know what already exists remotely without downloading it.
- **Inputs:** `config`, `subDir`.
- **Returns:** `Future<Set<String>?>` — the file basenames, or **null when the listing failed**
  (not an empty set).
- **Side effects:** Sends a `PROPFIND` (`Depth: 1`) request with a 15s timeout, retried on HTTP
  5xx.
- **Algorithm:** 1. Send `PROPFIND` via `_withRetry`. 2. If the status isn't 207, return null.
  3. Otherwise read the response body and regex-match `<...href>...</...href>` entries, skipping
  any href ending in `/` (the directory itself or sub-directories), collecting the trailing path
  segment of each remaining href as a file basename. 4. Any exception yields null.
- **Usage:**
  ```dart
  final remoteNames = await _listRemoteFiles(config, 'images');
  if (remoteNames == null) {
    errors.add('Image sync skipped: could not list the remote images directory');
    return errors;
  }
  ```
  (from [`_syncImages`](#_syncimages); also used by [`_forceUploadImages`](#_forceuploadimages)
  and [`_forceDownloadImages`](#_forcedownloadimages))
- **Notes:** A null result means the remote state is unknown (network/server error); callers must
  not treat it as an empty directory, otherwise every referenced image would be re-uploaded (or,
  for downloads, the phase would appear to have nothing to fetch) on any transient PROPFIND
  failure — this is the fix for the "repeated re-uploads after a transient PROPFIND failure" issue
  described in `../../../AGENTS.md`.

### `static Set<String> _getReferencedImageNames(String? json)` <a id="_getreferencedimagenames"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 1138)
- **Purpose:** Extract the basenames of device images referenced in a device-data JSON string.
- **Inputs:** `json` — raw `device_data.json` content, nullable.
- **Returns:** `Set<String>` — empty if `json` is null or unparseable.
- **Side effects:** None.
- **Algorithm:** Parse via `DeviceData.fromJson`, map each device's `imagePath` (skipping nulls via
  `whereType<String>`) to its basename via `p.basename`, collect into a set.
- **Usage:**
  ```dart
  final referencedImages = {
    ..._getReferencedImageNames(localDeviceJson),
    ..._getReferencedImageNames(remoteDeviceJson),
  };
  ```
  (from [`_syncLocked`](#_synclocked); the local+remote union pattern is also used by
  `_forceUploadLocked`/`_forceDownloadLocked` for their respective single side)
- **Notes:** Images sync additively, referenced-only, based on the union of local and remote
  `imagePath` basenames — orphan images (not referenced by any device record on either side) are
  never uploaded or downloaded, per `../../../AGENTS.md`.

### `static Future<List<String>> _syncImages(WebDAVConfig config, Directory appDir, Set<String> referencedImages, Future<_UploadSession?> Function() ensureUploadSession)` <a id="_syncimages"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 1165)
- **Purpose:** Sync only images referenced by actual device records (local ∪ remote), during a
  normal merge sync.
- **Inputs:** `config`, `appDir`; `referencedImages` (union of local+remote basenames);
  `ensureUploadSession` — a closure returning the already-acquired upload session (see
  [`_syncLocked`](#_synclocked)'s nested `ensureUploadSession`).
- **Returns:** `Future<List<String>>` — non-fatal per-image error strings.
- **Side effects:** Creates `images/` locally if missing; MKCOLs the remote `images/` dir; may
  upload local images and download remote images; sets `_localDataChanged = true` when any image
  is downloaded.
- **Algorithm:** 1. If `referencedImages` is empty, return no errors. 2. Ensure the local
  `images/` directory exists and the remote `images/` sub-dir exists. 3. Collect local referenced
  image names actually present on disk (skipping non-referenced/orphan files). 4. List remote
  image names via [`_listRemoteFiles`](#_listremotefiles); **if that listing returns null, skip
  the entire image phase** with a single warning rather than guessing (see that function's Notes).
  5. Upload every locally-present referenced image missing remotely, reporting progress per file
  and recording a per-image warning on timeout/exception (upload lock acquisition failure is also
  recorded per-image, not fatal). 6. Download every remotely-present referenced image missing
  locally, reporting progress and recording per-image warnings; each successful download sets
  `_localDataChanged = true` so the UI reloads even if the data JSON itself didn't change.
- **Usage:** Called once per sync attempt from [`_syncLocked`](#_synclocked), after all four data
  files have been processed.
- **Notes:** `referencedImages` being the union of local+remote basenames (computed by the caller
  via [`_getReferencedImageNames`](#_getreferencedimagenames)) means images referenced on either
  side are covered without ever transferring orphaned images.

### `static Future<SyncResult> sync(WebDAVConfig config, {bool autoResolve = false})` <a id="sync"></a>
- **Kind:** static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 1276)
- **Purpose:** Run one full per-record three-way merge sync cycle against the remote server.
- **Inputs:** `config`; `autoResolve` (default false — every production caller leaves it false so
  true two-sided conflicts always surface for manual resolution).
- **Returns:** `Future<SyncResult>`.
- **Side effects:** Sets/clears the `_syncing` guard; publishes `connecting` then
  `done`/`error` progress; delegates all real I/O to [`_syncLocked`](#_synclocked).
- **Algorithm:** 1. If `_syncing` is already true, return a failure `SyncResult` immediately
  ("Sync already in progress") without touching any state. 2. Set `_syncing = true`. 3. Report
  `connecting` progress, call `_syncLocked(config, autoResolve: autoResolve)`. 4. Report
  `done`/`error` progress based on the result. 5. In `finally`, clear `_syncing`.
- **Usage:**
  ```dart
  await SyncWakeLock.acquire();
  SyncResult result;
  try {
    result = await WebDAVService.sync(_currentConfig);
  } finally {
    await SyncWakeLock.release();
    if (mounted) setState(() => _syncing = false);
  }
  ```
  (from `lib/shared/views/webdav_config_page.dart`, `_syncNow()`; also called from
  `AutoSyncService._trySync`, `lib/shared/services/auto_sync_service.dart`, always with
  `autoResolve: false`)
- **Notes:** This is the sole public entry point for merge-based sync; the actual merge logic and
  the per-file non-404-error-skips-that-file behavior live in `_syncLocked`.

### `static Future<SyncResult> _syncLocked(WebDAVConfig config, {bool autoResolve = false})` <a id="_synclocked"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 1307)
- **Purpose:** Run the full merge-based sync body — lock acquisition, per-file discriminated
  download, per-record merge, conditional upload, and referenced-image sync — while the caller's
  `_syncing` guard is held.
- **Inputs:** `config`, `autoResolve`.
- **Returns:** `Future<SyncResult>`, with `pending` set when any of the four modules has
  unresolved conflicts.
- **Side effects:** Reads/writes local data files and `.sync_base/` snapshots; performs all
  network I/O for the sync (lock, downloads, uploads, images); publishes progress.
- **Algorithm:**
  1. Ensure the remote directory exists; load the app dir and this device's client ID.
  2. [`_prepareInterruptedUpload`](#_prepareinterruptedupload) — abort on a blocking error (e.g.
     another active client's lock).
  3. [`_acquireUploadSession`](#_acquireuploadsession) — abort if the lock could not be acquired.
  4. Define two local closures over the acquired `uploadSession`: `ensureUploadSession()` (returns
     it — Tier B, trivial) and [`uploadJson`](#uploadjson) (force-uploads via
     `_uploadWithSession`, or reports a lock-not-acquired error).
  5. For each of the four data files (`device_data.json`, `network_data.json`,
     `dataset_data.json`, `service_data.json`), in a per-file `try`/`catch` so one file's failure
     cannot block the others:
     - Download the remote copy via [`_download`](#_download). **If the download status is
       `error` (not 404), record a per-file error and `continue` to the next file** — this is the
       exact implementation of the discriminated-download rule described at the top of this page.
     - If neither side has the file, skip it. If only remote has it, write it locally as the new
       base and mark local data changed. If only local has it, force-upload it as new under the
       lock and save the base.
     - If both sides have identical raw content, just save that content as the new base (no
       merge/upload needed).
     - Otherwise load the file's `.sync_base/` snapshot and merge via the matching
       `merge<Module>Data` function (see [`sync_merge.md`](sync_merge.md)). If the merge produced
       no conflicts, **re-read the local file** first (to catch a concurrent user edit during the
       network round-trip) and re-merge if it changed, then write/upload the merged JSON and save
       the new base. If the merge produced conflicts, stash the merge result (`pendingDevice` /
       `pendingNetwork` / `pendingDataSet` / `pendingService`) instead of uploading.
  6. After all four files: compute the union of referenced image basenames from the tracked
     local/remote `device_data.json` content and run [`_syncImages`](#_syncimages).
  7. If any module has pending conflicts, return a `SyncResult` with `pending` set (and
     `success` reflecting whether there were also hard per-file errors). Otherwise return a plain
     success/failure `SyncResult` with any accumulated `warnings` (image errors).
  8. Any uncaught exception is caught at the outermost level and returned as a failure result.
  9. `finally`: release the upload session via
     [`_releaseUploadSession`](#_releaseuploadsession).
- **Usage:** Called only by [`sync`](#sync), which owns the `_syncing` guard around it.
- **Notes:** Local files are re-read after network I/O specifically to detect concurrent user
  edits during sync, per `../../../AGENTS.md`. Each data file's merge/upload is independently
  try/caught so a malformed file does not block the others. This method (not `sync` itself) is
  where the MyDevice-specific "non-404 download error records a per-file error and skips that
  file" behavior actually lives, at the `remote.status == RemoteFileStatus.error` check near the
  top of the per-file loop.

### `Future<_UploadSession?> ensureUploadSession()` (nested in `_syncLocked`)
- **Tier B** — a trivial one-line local closure (`return uploadSession;`) that closes over the
  session acquired earlier in `_syncLocked`, giving [`_syncImages`](#_syncimages) a stable way to
  fetch "the current upload session" without re-acquiring it; indexed in the Declarations table
  only.

### `Future<({bool is412, String? error})> uploadJson(String fileName, String content)` (nested in `_syncLocked`) <a id="uploadjson"></a>
- **Kind:** local function, nested in `_syncLocked`
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 1347)
- **Purpose:** Force-upload a data file's content while holding the remote upload lock, from
  within the per-file merge loop.
- **Inputs:** `fileName`, `content`.
- **Returns:** Same shape as [`_upload`](#_upload)/[`_uploadWithSession`](#_uploadwithsession).
- **Side effects:** Delegates to `_uploadWithSession`, which refreshes the lock and PUTs under a
  heartbeat.
- **Algorithm:** Call `ensureUploadSession()`; if null, return a "lock not acquired" error;
  otherwise delegate to `_uploadWithSession(config, fileName, content, session)`.
- **Usage:** Called for the "only local has the file" upload-as-new path and for every merged
  (conflict-free) file's upload, within `_syncLocked`'s per-file loop.
- **Notes:** Closes over the outer `config` and `ensureUploadSession`, so it always uses the one
  session acquired for this whole sync attempt.

### `static Future<bool> _finalizeFile(WebDAVConfig config, String fileName, String mergedJson, _UploadSession uploadSession)` <a id="_finalizefile"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 1699)
- **Purpose:** Write one conflict-resolved data file locally, upload it under the held lock, and
  save its new base snapshot.
- **Inputs:** `config`, `fileName`, `mergedJson` (the fully-resolved serialized data),
  `uploadSession`.
- **Returns:** `Future<bool>` — false when the remote read or the upload fails.
- **Side effects:** Downloads the current remote file (validation-only), writes the local file
  atomically, sets `_localDataChanged = true`, uploads, and saves the base snapshot on success.
- **Algorithm:** 1. Download the remote file first; **if that download errors (not 404), return
  false** without writing or uploading anything — the same discriminated-download rule as
  `_syncLocked`. 2. Write `mergedJson` to the local file atomically and mark local data changed.
  3. Upload via `_uploadWithSession`; if it errors, return false. 4. Save the new base snapshot;
  return true.
- **Usage:** Called once per resolved module (device/network/dataset/service) from
  [`finalizePendingSync`](#finalizependingsync).
- **Notes:** Resolved data is force-uploaded under `.lock` without data-file preconditions, same
  as the normal merge-upload path. A remote download error here aborts just that one file's
  finalization, not the whole `finalizePendingSync` call.

### `static Future<bool> finalizePendingSync(WebDAVConfig config, PendingSync pending, Map<String, dynamic> resolutions)` <a id="finalizependingsync"></a>
- **Kind:** static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 1727)
- **Purpose:** Apply the user's manually chosen conflict resolutions and upload each affected
  module's fully-resolved data file.
- **Inputs:** `config`; `pending` (the `PendingSync` from a prior `sync()` call); `resolutions`
  (map from conflict `id` to the chosen record — `Device`/`Network`/`DataSet`, or, for services, a
  `ServiceNode`/`ServiceRoute` mixed in the same map).
- **Returns:** `Future<bool>` — false when any file's remote read or upload fails.
- **Side effects:** Performs local file-system writes and network I/O for every module with
  pending conflicts.
- **Algorithm:** 1. Load the client ID, run
  [`_prepareInterruptedUpload`](#_prepareinterruptedupload) and
  [`_acquireUploadSession`](#_acquireuploadsession); return false immediately if either blocks.
  2. For each of `pending.deviceMerge`/`networkMerge`/`dataSetMerge`/`serviceMerge` that is
  non-null: build a per-conflict resolutions map (type-checked against the module's record type),
  call the merge result's `buildResolved(...)` (see [`sync_merge.md`](sync_merge.md)), serialize
  to indented JSON, and call [`_finalizeFile`](#_finalizefile) for that module's file; AND the
  per-file success into `allOk`. 3. Return `allOk`. 4. Any exception yields false. 5. `finally`:
  release the upload session.
- **Usage:**
  ```dart
  ok = await WebDAVService.finalizePendingSync(
    _currentConfig,
    pending,
    resolutions,
  );
  ...
  AutoSyncService.instance.recordFinalizeResult(ok);
  ```
  (from `lib/shared/views/webdav_config_page.dart`, after the user resolves each conflict in the
  dialog)
- **Notes:** Failed files keep their base snapshots untouched, per `../../../AGENTS.md`, so a
  retried finalize (or the next regular sync) re-merges them correctly instead of assuming they
  succeeded.

### `static Future<SyncResult> forceUpload(WebDAVConfig config)` <a id="forceupload"></a>
- **Kind:** static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 1842)
- **Purpose:** Upload every local data file and referenced image to the remote, overwriting
  remote data unconditionally with no merge or conflict check.
- **Inputs:** `config`.
- **Returns:** `Future<SyncResult>`.
- **Side effects:** Overwrites remote data files, uploads images, saves base snapshots, publishes
  progress. Sets/clears `_syncing`.
- **Algorithm:** Same `_syncing`-guard/progress-reporting shell as [`sync`](#sync), delegating the
  actual work to [`_forceUploadLocked`](#_forceuploadlocked).
- **Usage:**
  ```dart
  result = await WebDAVService.forceUpload(_currentConfig);
  ```
  (from `lib/shared/views/webdav_config_page.dart`, the "Force Upload" action, behind a
  destructive-action confirmation dialog and `SyncWakeLock`)
- **Notes:** Remote changes made since the last sync are lost. Runs under the remote `.lock` and
  the `_syncing` guard like a normal sync, but never merges — it is a destructive last-writer-wins
  overwrite by design.

### `static Future<SyncResult> _forceUploadLocked(WebDAVConfig config)` <a id="_forceuploadlocked"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 1868)
- **Purpose:** Run the force-upload body: acquire the lock, upload every existing local data file
  unconditionally, then upload referenced images.
- **Inputs:** `config`.
- **Returns:** `Future<SyncResult>`.
- **Side effects:** Same as [`forceUpload`](#forceupload) minus the `_syncing`/progress shell.
- **Algorithm:** 1. Ensure remote dir, load client ID, run
  [`_prepareInterruptedUpload`](#_prepareinterruptedupload) and
  [`_acquireUploadSession`](#_acquireuploadsession); abort with a failure `SyncResult` if either
  blocks. 2. For each of the four data files that exists locally: upload it via
  `_uploadWithSession` (no merge, no download of the remote copy at all); on error, return a
  failure `SyncResult` immediately; on success, save the local content as the new base (remote now
  equals local by construction). 3. Call [`_forceUploadImages`](#_forceuploadimages) for images
  referenced by the local `device_data.json`. 4. Return a success `SyncResult` with any image
  warnings. 5. `finally`: release the upload session.
- **Usage:** Called only by [`forceUpload`](#forceupload).
- **Notes:** Unlike `_syncLocked`, this never downloads the remote data file for comparison —
  local simply overwrites remote unconditionally, which is the entire point of a force upload.

### `static Future<List<String>> _forceUploadImages(WebDAVConfig config, Directory appDir, Set<String> referencedImages, _UploadSession session)` <a id="_forceuploadimages"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 1943)
- **Purpose:** Upload every locally-referenced image during a force upload, guaranteeing remote
  completeness even if the remote listing is unavailable.
- **Inputs:** `config`, `appDir`, `referencedImages`, `session`.
- **Returns:** `Future<List<String>>` — non-fatal per-image warnings.
- **Side effects:** Ensures the remote `images/` sub-dir exists; uploads image bytes.
- **Algorithm:** 1. If `referencedImages` is empty or the local `images/` dir doesn't exist,
  return no errors. 2. Collect local referenced image names present on disk. 3. List remote image
  names via [`_listRemoteFiles`](#_listremotefiles); **if that listing fails (null), upload
  everything** (`toUpload = localNames`) rather than skipping the phase — unlike
  [`_syncImages`](#_syncimages), force upload must guarantee remote completeness, so it falls back
  to uploading all referenced images instead of skipping on an unknown remote state. If the
  listing succeeded, only upload names not already present remotely. 4. Upload each, reporting
  progress and recording per-image timeout/exception warnings.
- **Usage:** Called once from [`_forceUploadLocked`](#_forceuploadlocked).
- **Notes:** Image names are immutable UUIDs, so a name already present remotely is guaranteed to
  be the same content — skipping it when the listing is available is always safe.

### `static Future<SyncResult> forceDownload(WebDAVConfig config)` <a id="forcedownload"></a>
- **Kind:** static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 1999)
- **Purpose:** Replace every local data file and referenced image with the remote copy,
  unconditionally, with no merge or conflict check.
- **Inputs:** `config`.
- **Returns:** `Future<SyncResult>`.
- **Side effects:** Overwrites local data files, saves base snapshots, sets
  `_localDataChanged = true`, publishes progress. Sets/clears `_syncing`.
- **Algorithm:** Same `_syncing`-guard/progress-reporting shell as [`sync`](#sync), delegating to
  [`_forceDownloadLocked`](#_forcedownloadlocked).
- **Usage:**
  ```dart
  result = await WebDAVService.forceDownload(_currentConfig);
  ```
  (from `lib/shared/views/webdav_config_page.dart`, the "Force Download" action, behind a
  destructive-action confirmation dialog and `SyncWakeLock`)
- **Notes:** Local changes made since the last sync are lost. Download-only, so no remote `.lock`
  is taken (nothing is written remotely); the `_syncing` guard still applies to prevent overlap
  with another sync/force operation.

### `static Future<SyncResult> _forceDownloadLocked(WebDAVConfig config)` <a id="_forcedownloadlocked"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 2027)
- **Purpose:** Run the force-download body: download every data file unconditionally and validate
  it before replacing the local copy.
- **Inputs:** `config`.
- **Returns:** `Future<SyncResult>`.
- **Side effects:** Overwrites local data files atomically, saves base snapshots, sets
  `_localDataChanged = true`, downloads images.
- **Algorithm:** 1. For each of the four data files: download it via [`_download`](#_download).
  **If the download status is `error` (not 404), return a failure `SyncResult` immediately** — the
  same discriminated-download rule as `_syncLocked`, applied here to abort the whole force-download
  rather than just skip one file, since a force download's entire purpose is to fully replace local
  state and a partial replacement would be worse than aborting. If `notFound` (or null content),
  add a "kept local file" warning and continue to the next file (local file is left untouched).
  2. Otherwise validate the remote content is parseable JSON (`jsonDecode`); if not, return a
  failure `SyncResult` (protects against writing corrupt data even on a 200 response).
  3. Write it locally atomically, save it as the new base, mark local data changed.
  4. After all four files, call [`_forceDownloadImages`](#_forcedownloadimages) for images
  referenced by the downloaded `device_data.json`. 5. Return a success `SyncResult` with any
  warnings.
- **Usage:** Called only by [`forceDownload`](#forcedownload).
- **Notes:** Remote content is JSON-validated before it replaces any local file; a missing remote
  file (404) keeps the local copy and adds a warning rather than deleting local data. Note this
  method aborts the *entire* force-download on a non-404 error for one file, which is intentionally
  stricter than `_syncLocked`'s per-file skip — a partially-replaced local dataset would be a worse
  outcome for an operation whose entire point is a full local replacement.

### `static Future<List<String>> _forceDownloadImages(WebDAVConfig config, Directory appDir, Set<String> referencedImages)` <a id="_forcedownloadimages"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/webdav_service.dart` (approx. line 2088)
- **Purpose:** Download every remotely-referenced image not already present locally, during a
  force download.
- **Inputs:** `config`, `appDir`, `referencedImages`.
- **Returns:** `Future<List<String>>` — non-fatal per-image warnings.
- **Side effects:** Creates the local `images/` dir if missing; writes downloaded image files;
  sets `_localDataChanged = true` per successful download.
- **Algorithm:** 1. If `referencedImages` is empty, return no errors. 2. Ensure the local
  `images/` dir exists. 3. List remote image names via
  [`_listRemoteFiles`](#_listremotefiles); **if that listing fails (null), skip the whole image
  phase** with one warning, same as `_syncImages` (never guess an unknown remote state is empty).
  4. Compute `toDownload` as referenced images present remotely and *not* already present locally
  (checked synchronously via `existsSync`). 5. Download each, reporting progress and recording
  per-image timeout/exception warnings; each success sets `_localDataChanged = true`.
- **Usage:** Called once from [`_forceDownloadLocked`](#_forcedownloadlocked).
- **Notes:** Image names are immutable UUIDs, so a name already present locally is always the
  correct content and is skipped without re-downloading.
