# WebDAV Sync

WebDAV sync in MyDevice is **per-record three-way merge, not whole-file replacement**.
The engine lives in `lib/shared/services/webdav_service.dart` (`WebDAVService`) and
`lib/shared/services/sync_merge.dart` (the merge algorithms — see
[Three-Way Merge](algorithms/three-way-merge.md)). This page describes the flow,
retry/heartbeat policy, image sync, and the one place this app's flow differs from the
sibling MyAnime app. For a worked example, see
[Sync Walkthrough](examples/sync-walkthrough.md).

## The 9-step flow

1. **Acquire the remote `.lock`** before any data downloads, using a stable local client
   id, one upload token, a UTC timestamp, and a 60-second TTL
   (`_lockTtlSeconds = 60` in `webdav_service.dart`). An active lock held by another
   client blocks uploads; an expired lock is treated as a failed upload and may be
   replaced. The local `.sync_base/upload_lock.json` file lets the *next* app launch
   detect an interrupted upload and re-download/re-merge before uploading again.
2. **Download remote JSON with a discriminated result.** Only an HTTP 404 counts as
   "missing on remote." **Any other failure (auth/server/network) records a per-file
   error and skips that file** — local data for that file is never uploaded over an
   unreadable remote file. This is the one point where MyDevice's flow intentionally
   differs from MyAnime's: MyAnime aborts the *entire* sync on a non-404 download
   failure, while MyDevice records the failure for that one file and continues syncing
   the other data files (device/network/dataset/service) independently.
3. **Load local JSON and `.sync_base/` base snapshots** (the last successfully synced
   version of each file).
4. **Merge per record using `modifiedAt`** where available (see
   [Three-Way Merge](algorithms/three-way-merge.md)). Records whose *serialized content*
   is identical on both sides merge without a conflict even if both sides' `modifiedAt`
   moved (e.g. after a stale base from an earlier failed upload).
5. **Auto-resolve when only one side changed** relative to the base.
6. **Detect a true conflict** when the same record changed on both sides since the last
   sync.
7. **If there are no record conflicts,** force-upload the complete merged JSON while the
   `.lock` is still valid. Data JSON `PUT`s do **not** use data-file `If-Match` /
   `If-None-Match` preconditions — `.lock` is the sole concurrency guard for data writes.
8. **If there are record conflicts,** return them to the user instead of resolving
   automatically. After the user resolves them, `finalizePendingSync` reacquires
   `.lock` and force-uploads each complete resolved JSON.
9. **Save the new base snapshot only after the upload succeeds,** then clear the
   matching remote/local upload lock.

## Manual vs. auto-sync

- **Manual sync** (from the WebDAV settings page) uses `autoResolve: false` and shows
  conflict dialogs.
- **Auto-sync** also leaves `autoResolve` disabled — it never silently applies
  last-writer-wins. Instead it records failures and true two-sided conflicts as visible
  status in Settings/WebDAV; the user must open the WebDAV page and resolve conflicts
  manually.
- **Dismissing any conflict dialog** (e.g. system back gesture) aborts the whole
  resolution: nothing is uploaded, the conflict stays pending in the visible sync status,
  and no record is silently resolved to the local version.
- `finalizePendingSync` reacquires `.lock` and force-uploads resolved complete JSON
  without data-file preconditions; it returns `false` when any file's remote read or
  upload fails, and failed files keep their base snapshots untouched (so they're retried
  next sync).

## Wake lock

Foreground sync operations on the WebDAV page — manual sync, conflict finalize upload,
force upload, force download — hold a screen wake lock through
`lib/shared/services/sync_wake_lock.dart` (`wakelock_plus`):

- Reference-counted; only enabled if no other feature already holds one.
- Acquired only *after* force-action confirmation (not held during pre-confirmation UI).
- Released in `finally` on completion, failure, cancel, or exception.
- Never used by background auto-sync (only foreground, user-initiated operations hold
  it).

## Retry policy

Transient network failures — socket/timeout/client errors and HTTP 5xx — are retried up
to **2 extra attempts with 1s then 2s backoff**, implemented by the internal
`_withRetry<T>` helper in `webdav_service.dart` (confirmed in source: `retries = 2`
default, `Duration(seconds: attemptIndex)` backoff, i.e. 1s before the first retry, 2s
before the second). This applies to data GET/PUT, byte (image) GET/PUT, and PROPFIND
listings. Two things are never retried:

- **`.lock` writes** — never retried, so a retried create-only PUT cannot misreport lock
  contention.
- **HTTP 4xx responses** — never retried (only `statusCode >= 500` triggers a retry via
  the `shouldRetry` predicate passed to `_withRetry`).

## Heartbeat

While a data or image `PUT` is in flight, the held `.lock` is heartbeat-refreshed every
**20 seconds** (`_lockHeartbeatInterval = Duration(seconds: 20)`, via `_withLockHeartbeat`
in `webdav_service.dart`) — confirmed well below the 60-second lock TTL, so a transfer
slower than the TTL can never let another client treat the lock as expired and upload
concurrently. Heartbeat failures are swallowed and never abort the in-flight transfer.

## Sync progress

`WebDAVService.progress` is a `ValueNotifier<SyncProgress>`
(`lib/shared/services/sync_progress.dart`) publishing connecting/downloading/
merging/uploading phases with per-file and per-image counts. The service emits raw
phases and file names only; the WebDAV page maps phases to localized text and renders a
`LinearProgressIndicator`.

## Image sync

Images sync **additively and referenced-only**: the sync engine computes the union of
`imagePath` basenames referenced by local and remote `Device` records and only
transfers those files. Orphan images (no longer referenced by any device) are not
repeatedly uploaded or downloaded. Remote image directory listings return `null` on any
PROPFIND failure; `_syncImages` then skips the image phase with a visible warning
instead of treating the unknown remote state as empty — this previously caused every
referenced image to be re-uploaded after a transient PROPFIND failure. Downloaded images
set the local-data-changed flag so UI pages reload even when the data JSON itself didn't
change.

## Per-file data merge rules

| File | Merge strategy |
| --- | --- |
| `device_data.json` | `Device` records merged by `id` and `modifiedAt` |
| `network_data.json` | `Network` records by `id`/`modifiedAt`; `NetworkDevice` assignments by composite key and content comparison |
| `dataset_data.json` | `DataSet` records by `id` and `modifiedAt` |
| `service_data.json` | `ServiceNode` and `ServiceRoute` records by `id` and `modifiedAt`; endpoints and route hops follow their parent record |

Each data file's merge has **per-file error handling** — one malformed file does not
block the others from syncing. Local files are re-read after network I/O to detect
concurrent user edits made *during* the sync. `_atomicWrite()` uses tmp-then-rename to
avoid corrupting local files. `_syncing` prevents concurrent sync runs.

## NetworkDevice composite-key merge

`NetworkDevice` has no `id` and no `modifiedAt` (see
[Data Formats](data-formats.md#network--networkdevice-libfeaturesnetworkmodelsnetworkdart)),
so its merge (`mergeAssignments` in `sync_merge.dart`) uses the composite key
`(networkId, deviceId)` and compares *serialized JSON content* against the base snapshot
to detect which side(s) changed, since there is no timestamp to compare. See
[Three-Way Merge](algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge)
for the exact algorithm, and
[Sync Walkthrough](examples/sync-walkthrough.md#networkdevice-assignment-example) for a
worked example.

Because `NetworkDevice` has no timestamp to show in a conflict, **the conflict dialog
falls back to showing the record ID** for `NetworkDevice` assignments instead of a bare
`modifiedAt` on both sides (which is what it shows for every other record type).

## Force upload / force download

- `WebDAVService.forceUpload()` overwrites remote data files and uploads referenced
  images without any merge or conflict check, under the remote `.lock`, then saves base
  snapshots.
- `WebDAVService.forceDownload()` replaces local data files (JSON-validated first,
  atomic writes) and downloads referenced images without merging, saves base snapshots,
  and sets the local-data-changed flag. It is download-only and takes no remote lock.

Both share the `_syncing` guard and require a destructive-action confirmation dialog in
the WebDAV page.

## Auto-sync triggers

Auto-sync fires on:

- App launch.
- App resume.
- A 30-second debounce after storage saves.
- A 15-minute periodic timer while the app process is alive.
- Saving/enabling a fully configured auto-sync WebDAV setup (immediate sync via
  `requestSyncNow()`).

`_trySync` holds an instance-level `_syncing` guard so overlapping triggers are silently
skipped instead of surfacing a spurious "sync already in progress" failure banner.
Mobile OS suspension may delay timers until resume. Storage-layer `save()` methods notify
auto-sync so non-UI writes are covered. Auto-sync records the latest success, failure,
and pending-conflict state in memory so Settings and the WebDAV page can surface sync
health.

After manual sync or force operations, the WebDAV page calls
`AutoSyncService.notifyLocalDataChangedIfNeeded()` so open pages reload without waiting
for the next background sync.

## Known limitation

Sync merge does not currently run full cross-reference validation after merging (e.g. it
will not proactively clean up a `NetworkDevice` assignment whose device was deleted on
the other side as part of the merge pass itself). See
[Data Formats](data-formats.md#cross-reference-rules).
