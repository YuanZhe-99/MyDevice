# Backup, Restore, and Export

This page covers `lib/shared/services/backup_service.dart` (local backup/restore) and
`lib/shared/services/import_export_service.dart` (ZIP and Markdown export/import). See
[Data Formats](data-formats.md) for the model `fromJson` parsers used to validate
restored data, and [WebDAV Sync](sync.md) for why restoring interacts with auto-sync.

## Backup format v2

Each `backups/backup_*.json` bundle (`_backupFormat: 2`) stores:

- The raw JSON string content of each present data module file (`device_data.json`,
  `network_data.json`, `dataset_data.json`, `service_data.json` — the same four files
  from the [Persisted Data Inventory](data-formats.md#persisted-data-inventory)).
- An `_imageRefs` map from `images/<filename>` to a content-addressed blob name
  `<sha256><ext>` stored under `backups/blobs/`.

```dart
static const modules = <String, String>{
  'device_data.json': 'devices',
  'network_data.json': 'networks',
  'dataset_data.json': 'datasets',
  'service_data.json': 'services',
};
```

### Deduplication

`createBackup()` hashes every file under `images/` with SHA-256 and writes it to
`backups/blobs/<hash><ext>` only if that blob doesn't already exist. **Identical images
are stored once and shared by every backup that references them** — repeated backups of
an unchanged image library stay small because only the `_imageRefs` map (not the image
bytes) grows per backup.

### Garbage collection

`_collectUnreferencedBlobs()` runs after every create/delete/retention pass:

- It walks every remaining `backup_*.json`, and if **any** bundle fails to parse, the
  whole GC pass **aborts** — the reference set is unknown, so nothing is deleted under
  uncertainty.
- A blob is physically deleted **only when no remaining backup references it**.
- Blobs are never deleted if younger than the **10-minute grace window**
  (confirmed in source: `_blobGcGrace = Duration(minutes: 10)`), protecting a backup that
  is being written concurrently with a GC pass.

### Legacy v1 restore

Bundles with inline base64 `_images` (bare basenames, no `images/` prefix) remain
restorable: `restoreBackup()` checks `_imageRefs` first, and falls back to decoding
`_images` entries with `base64Decode()` when present instead.

## Retention

`BackupService.retentionDays` (0 = keep forever) is loaded/saved through
`storage_config.json` (`autoBackupEnabled`, `backupRetentionDays`). `_cleanOldBackups()`
deletes any backup older than `DateTime.now().subtract(Duration(days: retentionDays))`
when `retentionDays > 0`.

## Atomic writes and corrupt-bundle handling

Both the bundle JSON and every blob/image file are written via tmp-then-rename
(`_atomicWriteString` / `_atomicWriteBytes`), so a crash mid-write cannot leave a
truncated file at the final path.

`listBackups()` parses any bundle at or below a 4 MiB probe size
(`_probeMaxBytes = 4 * 1024 * 1024`) to detect corruption; larger legacy inline-image
bundles are listed by file size alone without a corruption check. A bundle that fails to
parse is flagged `corrupt: true` — the backup history shows it with restore disabled,
and (importantly) it does **not** count as "already backed up today," so an interrupted
auto-backup from earlier the same day is retried by the next `runAutoBackupIfNeeded()`
call. `runAutoBackupIfNeeded()` is re-entrancy guarded (`_autoBackupRunning`); its
triggers are app launch, app resume, and the 15-minute auto-sync periodic timer (this
last one specifically covers desktop instances that stay running across midnight).

## Restore validation

`restoreBackup()` validates **every selected module's JSON payload against its model
parser before writing anything**:

```dart
static void _validateModuleJson(String fileName, String content) {
  final json = jsonDecode(content) as Map<String, dynamic>;
  switch (fileName) {
    case 'device_data.json': DeviceData.fromJson(json);
    case 'network_data.json': NetworkData.fromJson(json);
    case 'dataset_data.json': DataSetData.fromJson(json);
    case 'service_data.json': ServiceData.fromJson(json);
    default: throw FormatException('unsupported data file: $fileName');
  }
}
```

If any selected module fails to parse, the whole restore throws before any file write
happens. Only after every selected payload validates does the function iterate and
write each file atomically.

Image names are sanitized by `_safeImageBasename()`: it accepts both bare basenames
(legacy) and `images/<name>` keys (v2), and rejects anything containing `/` after
stripping the `images/` prefix, `..`, or an absolute path — so a crafted bundle cannot
write outside the `images/` directory.

## Image module gating

`getBackupModules()` reports a **synthetic `images` module** whenever the bundle
contains either `_images` (legacy) or `_imageRefs` (v2). This lets the restore UI offer
"Images" as its own selectable checkbox alongside devices/networks/datasets/services.
Images are restored only when the `images` module is included in `moduleKeys` (or when
`moduleKeys` is `null`, meaning "restore everything").

## Restore result and the auto-sync-disable safety rule

`restoreBackup()` returns a `RestoreResult`:

```dart
class RestoreResult {
  final bool ok;
  final bool wroteAnything;
  final int missingImages;
}
```

- `wroteAnything` is `false` only when the restore failed *before* writing any data or
  image file — callers use this to know local data is guaranteed untouched.
- `missingImages` counts v2 `_imageRefs` entries whose blob file was absent from the
  blob store (e.g. a bundle copied without its `backups/blobs/` directory) — the caller
  surfaces this as a localized `backupRestoreMissingImages` warning instead of silently
  dropping those images.

**Safety rule:** when WebDAV auto-sync is enabled, restoring a backup **disables
auto-sync in `webdav_config.json` before the first file is written** (no `mounted` gate
on the UI side), so a crash or page disposal mid-restore can never leave restored-old
data with auto-sync still switched on. Auto-sync is re-enabled only when the restore
failed with `wroteAnything == false` — i.e. only when local data is guaranteed
untouched. Without disabling auto-sync first, the next sync would treat restored-old
data as if it were fresh local edits/deletions and propagate them to the remote and to
every other synced device.

After a successful restore:

1. The backup page reloads open pages via
   `AutoSyncService.notifyLocalDataChangedNow()`.
2. It warns (`backupRestoreMissingImages`) if any v2 image blobs were missing.
3. Only when WebDAV sync is configured, it asks whether to force-upload the restored
   data (holding the sync wake lock; the result is recorded in sync status). See
   [WebDAV Sync](sync.md#force-upload--force-download).

## ZIP export/import

`import_export_service.dart` exports the four data JSON files plus every file under
`images/` into a ZIP archive, and imports the reverse. On import, each archive entry name
is normalized and must be either one of the known data file names or match
`images/<flat-name>` (confirmed in source: `normalizedName.startsWith('images/') &&
normalizedName.split('/').length == 2`, i.e. exactly one path segment after `images/`) —
anything else, or any name containing `..`, is rejected. The resolved output path is also
double-checked with `path.isWithin(appDir, outFile)` before writing.

**Documented v1.2.2 fix:** the earlier version of this check only tested
`normalizedName.startsWith('images/')` — which is `true` for *any* nested path under
`images/` (e.g. `images/../../evil.txt` after certain normalizations, or simply
`images/sub/dir/file`), so it always passed and admitted nested entries the allowlist was
supposed to reject. The current check additionally requires exactly one path segment
after the `images/` prefix (`split('/').length == 2`), closing that gap. This is the
path-traversal protection referenced in `AGENTS.md`'s "ZIP import must keep path
traversal protection" rule.

## Markdown export

`import_export_service.dart` also produces an LLM-friendly Markdown export covering
devices, networks, datasets, and services — including service endpoints, routes, hops,
Docker Compose notes, and grouped public targets (`extraJson.publicTargets`, see
[Services and Topology](features/services-topology.md)). Device export includes
lifecycle and finance information when relevant (added alongside device
lifecycle/finance in `v0.4.0`; service data added in `v0.5.6`).

## `image_service.dart`

Handles file picking, URL download, UUID filenames under `images/`, relative path
resolution, and deletion — the primitives that `Device.imagePath` and the sync/backup
image logic build on.
