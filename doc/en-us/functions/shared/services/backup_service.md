# lib/shared/services/backup_service.dart

Static-only service managing local backups: manual/automatic creation, retention, and selective
per-module restore. It implements backup format v2 (introduced in `v1.2.2`, per
`../../../AGENTS.md`): each `backups/backup_*.json` bundle stores the four data-module JSON strings
plus an `_imageRefs` map pointing at content-addressed image blobs under
`backups/blobs/<sha256><ext>`, so identical images across many backups are stored once and garbage
collected only when no remaining backup references them. Legacy v1 bundles with inline base64
`_images` remain restorable. `AutoSyncService` (see
[`auto_sync_service.md`](auto_sync_service.md)) calls `runAutoBackupIfNeeded()` from its periodic
timer and app-resume handler, and `main.dart` calls it once at launch. See the "Backup, Export,
Import, and Images" section of `../../../AGENTS.md` for the full format/retention/restore
contract this file implements.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `appDirProvider` | static field (test hook) | B | Allow tests to redirect backup I/O to a temporary directory. |
| [`_getAppDir`](#_getappdir) | static method | A | Resolve the app data directory honoring the test override. |
| [`_getBackupDir`](#_getbackupdir) | static method | A | Resolve (and create if missing) the `backups/` directory. |
| [`_getBlobDir`](#_getblobdir) | static method | A | Resolve (and create if missing) the shared `backups/blobs/` image blob directory. |
| [`loadSettings`](#loadsettings) | static method | A | Load backup settings (`autoBackupEnabled`, `retentionDays`) from config. |
| [`saveSettings`](#savesettings) | static method | A | Save backup settings to config. |
| [`_validateModuleJson`](#_validatemodulejson) | static method | A | Validate a known data-module JSON string via its model parser. |
| [`_atomicWriteString`](#_atomicwritestring) | static method | A | Write a string to a file atomically (tmp-then-rename). |
| [`_atomicWriteBytes`](#_atomicwritebytes) | static method | A | Write bytes to a file atomically (tmp-then-rename). |
| [`createBackup`](#createbackup) | static method | A | Create a new backup bundle, deduplicating images into the blob store. |
| [`runAutoBackupIfNeeded`](#runautobackupifneeded) | static method | A | Create today's auto-backup if enabled and not already done. |
| [`listBackups`](#listbackups) | static method | A | List existing backups with size and corruption status. |
| [`getBackupModules`](#getbackupmodules) | static method | A | Return the data-module names (plus synthetic `images`) a backup bundle contains. |
| [`_safeImageBasename`](#_safeimagebasename) | static method | A | Return a sanitized flat image file name, or null if rejected. |
| [`restoreBackup`](#restorebackup) | static method | A | Validate and restore selected modules/images from a backup bundle. |
| [`deleteBackup`](#deletebackup) | static method | A | Delete a specific backup and run blob garbage collection. |
| [`_cleanOldBackups`](#_cleanoldbackups) | static method | A | Delete backups older than the retention window. |
| [`_collectUnreferencedBlobs`](#_collectunreferencedblobs) | static method | A | Delete image blobs no remaining backup references. |
| [`RestoreResult`](#restoreresult-new) | constructor | A | Create a restore result instance (`ok`, `wroteAnything`, `missingImages`). |
| [`BackupInfo`](#backupinfo-new) | constructor | A | Create a backup info instance (file, date, size, corrupt flag). |
| [`displaySize`](#displaysize) | getter (`BackupInfo`) | A | Format `sizeBytes` as a human-readable B/KB/MB string. |

Row count (21) matches `grep -c 'Purpose:' backup_service.dart` (21) exactly. The `BackupService`
class doc comment, the `modules` map constant, and the `_backupDir`/`_blobSubDir`/`_formatVersion`/
`_probeMaxBytes`/`_blobGcGrace`/`autoBackupEnabled`/`retentionDays`/`_lastAutoBackup`/
`_autoBackupRunning` fields use plain (non-`Purpose:`) doc comments or none, consistent with
AGENTS.md scoping the `Purpose:` convention to functions/methods/constructors/getters/setters; they
are covered in the overview above and in the Notes of the methods that use them.

## Documentation

### `static Future<Directory> _getAppDir()` <a id="_getappdir"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 63)
- **Purpose:** Resolve the app data directory, honoring the `appDirProvider` test override.
- **Inputs:** None.
- **Returns:** `Future<Directory>`.
- **Side effects:** None directly (delegates to `DeviceStorage.getAppDir()` in production).
- **Algorithm:** If `appDirProvider` is set (tests only), call it; otherwise call
  `DeviceStorage.getAppDir()`.
- **Usage:** Called internally by every other method in this file that touches disk.
- **Notes:** Production code never sets `appDirProvider`; only tests do, in `setUp()`.

### `static Future<Directory> _getBackupDir()` <a id="_getbackupdir"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 74)
- **Purpose:** Resolve the `backups/` directory under the app data dir, creating it if missing.
- **Inputs:** None.
- **Returns:** `Future<Directory>`.
- **Side effects:** Creates the `backups/` directory (recursively) if it does not exist.
- **Algorithm:** Join `_getAppDir()`'s path with `_backupDir` ('backups'); create recursively if
  absent.
- **Usage:** Called by [`createBackup`](#createbackup), [`listBackups`](#listbackups),
  [`_getBlobDir`](#_getblobdir), [`_cleanOldBackups`](#_cleanoldbackups), and
  [`_collectUnreferencedBlobs`](#_collectunreferencedblobs).
- **Notes:** None.

### `static Future<Directory> _getBlobDir()` <a id="_getblobdir"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 88)
- **Purpose:** Resolve the shared content-addressed image blob directory `backups/blobs/`,
  creating it if missing.
- **Inputs:** None.
- **Returns:** `Future<Directory>`.
- **Side effects:** Creates `backups/blobs/` (recursively) if it does not exist.
- **Algorithm:** Join `_getBackupDir()`'s path with `_blobSubDir` ('blobs'); create recursively if
  absent.
- **Usage:** Called by [`createBackup`](#createbackup), [`listBackups`](#listbackups),
  [`restoreBackup`](#restorebackup), and [`_collectUnreferencedBlobs`](#_collectunreferencedblobs).
- **Notes:** None.

### `static Future<void> loadSettings()` <a id="loadsettings"></a>
- **Kind:** static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 102)
- **Purpose:** Load backup settings (`autoBackupEnabled`, `retentionDays`) from
  `storage_config.json` into the static fields.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads `storage_config.json` via `DeviceStorage.readConfig()`; mutates
  `autoBackupEnabled`/`retentionDays`.
- **Algorithm:** Read config map; `autoBackupEnabled = config['autoBackupEnabled'] as bool? ??
  false`; `retentionDays = config['backupRetentionDays'] as int? ?? 0`.
- **Usage:**
  ```dart
  await BackupService.loadSettings();
  final backups = await BackupService.listBackups();
  ```
  (from `lib/features/settings/views/backup_page.dart`)
- **Notes:** Also called at the top of [`runAutoBackupIfNeeded`](#runautobackupifneeded) so the
  periodic/resume auto-backup check always sees the latest settings.

### `static Future<void> saveSettings()` <a id="savesettings"></a>
- **Kind:** static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 113)
- **Purpose:** Save the current `autoBackupEnabled`/`retentionDays` static settings to
  `storage_config.json`.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Writes `storage_config.json` via `DeviceStorage.writeConfig()`.
- **Algorithm:** Read the existing config map, overwrite the two keys, write it back.
- **Usage:**
  ```dart
  await BackupService.saveSettings();
  ```
  (from `lib/features/settings/views/backup_page.dart`, after the user changes auto-backup or
  retention settings)
- **Notes:** None.

### `static void _validateModuleJson(String fileName, String content)` <a id="_validatemodulejson"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 126)
- **Purpose:** Validate a known data-module JSON string via its model parser before it is ever
  written to disk during restore.
- **Inputs:** `fileName` (one of the four `_dataFileNames`-style keys in `modules`); `content`
  (raw JSON string).
- **Returns:** None.
- **Side effects:** None (throws on invalid input; does not write anything).
- **Algorithm:** Decode `content` as a JSON map, then `switch` on `fileName` to call the matching
  model's `fromJson` (`DeviceData`, `NetworkData`, `DataSetData`, or `ServiceData`), discarding the
  result — parsing itself is the validation. An unrecognized `fileName` throws
  `FormatException('unsupported data file: $fileName')`.
- **Usage:** Called internally by [`restoreBackup`](#restorebackup) for every selected module,
  before any file is written.
- **Notes:** Throws when the payload is not valid for the module so restore never overwrites a
  good data file with garbage — this is the mechanism behind "restore validates each selected
  module payload via its model parser... before writing anything" in `../../../AGENTS.md`.

### `static Future<void> _atomicWriteString(File file, String content)` <a id="_atomicwritestring"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 148)
- **Purpose:** Write a string to a file atomically (tmp-then-rename) so a killed process never
  leaves a truncated bundle.
- **Inputs:** `file` (target path); `content`.
- **Returns:** `Future<void>`.
- **Side effects:** Creates parent directories if needed; writes a `.tmp-<microsecondsSinceEpoch>`
  file, flushes it, then renames it over `file`. On rename failure, best-effort deletes the temp
  file and rethrows.
- **Algorithm:** 1. Ensure `file.parent` exists. 2. Write `content` to a uniquely-named temp file
  with `flush: true`. 3. Rename temp file over the target path. 4. On rename failure, try to delete
  the temp file (ignoring errors) and rethrow the original error.
- **Usage:** Called internally by [`createBackup`](#createbackup) (bundle JSON) and
  [`restoreBackup`](#restorebackup) (each restored data-module file).
- **Notes:** The microsecond-timestamped temp name avoids collisions between concurrent writes to
  the same target.

### `static Future<void> _atomicWriteBytes(File file, List<int> bytes)` <a id="_atomicwritebytes"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 173)
- **Purpose:** Write bytes to a file atomically (tmp-then-rename); the binary counterpart of
  [`_atomicWriteString`](#_atomicwritestring), used for blob writes and image restore.
- **Inputs:** `file`; `bytes`.
- **Returns:** `Future<void>`.
- **Side effects:** Same tmp-then-rename pattern as `_atomicWriteString`, writing bytes instead of
  a string.
- **Algorithm:** Identical structure to [`_atomicWriteString`](#_atomicwritestring) with
  `writeAsBytes`/`readAsBytes` in place of the string variants.
- **Usage:** Called internally by [`createBackup`](#createbackup) (new blobs) and
  [`restoreBackup`](#restorebackup) (restored image files, both v2-blob and legacy-inline paths).
- **Notes:** None.

### `static Future<File?> createBackup()` <a id="createbackup"></a>
- **Kind:** static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 199)
- **Purpose:** Create a new backup bundle containing the four data-module JSON files plus
  deduplicated references to any images they use.
- **Inputs:** None.
- **Returns:** `Future<File?>` — the created bundle file, or `null` on any failure.
- **Side effects:** Writes new blob files into `backups/blobs/` for images not already stored,
  writes the bundle JSON atomically into `backups/`, then runs
  [`_cleanOldBackups`](#_cleanoldbackups) and [`_collectUnreferencedBlobs`](#_collectunreferencedblobs).
- **Algorithm:** 1. Build a bundle map starting with `{'_backupFormat': 2}`. 2. For each of the
  four `modules` file names that exists locally, read its content into the bundle under that key.
  3. If an `images/` directory exists, for every file in it: compute its `sha256` hash, derive a
  content-addressed blob name `<hash><ext>`, write the blob (via
  [`_atomicWriteBytes`](#_atomicwritebytes)) only if it is not already present, and record
  `refs['images/<basename>'] = blobName`. Attach `refs` as `bundle['_imageRefs']` if non-empty.
  4. `jsonEncode` the bundle and write it to `backups/backup_<yyyyMMdd_HHmmss>.json` atomically.
  5. Run retention cleanup and blob GC. 6. On any exception, return `null` instead of propagating.
- **Usage:**
  ```dart
  final file = await BackupService.createBackup();
  ```
  (from `lib/features/settings/views/backup_page.dart`, manual "Create backup" action; also called
  by [`runAutoBackupIfNeeded`](#runautobackupifneeded))
- **Notes:** Images are stored once per unique content hash, so repeated backups of an unchanged
  image set stay small; deletion/GC is handled separately by
  [`_collectUnreferencedBlobs`](#_collectunreferencedblobs).

### `static Future<void> runAutoBackupIfNeeded()` <a id="runautobackupifneeded"></a>
- **Kind:** static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 253)
- **Purpose:** Create today's automatic backup if auto-backup is enabled and no valid backup for
  today already exists.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** May create a backup file (via [`createBackup`](#createbackup)) and updates the
  in-memory `_lastAutoBackup` timestamp.
- **Algorithm:** 1. Re-entrancy guard: if `_autoBackupRunning`, return immediately. 2. Load
  settings; if `autoBackupEnabled` is false, return. 3. If `_lastAutoBackup` is set to today or
  later, return (already handled this process run). 4. List existing backups and check whether any
  *non-corrupt* backup's date falls on today; if so, just update `_lastAutoBackup` and return
  without creating a new backup. 5. Otherwise call `createBackup()` and update `_lastAutoBackup`.
  6. `finally` clears the re-entrancy flag.
- **Usage:**
  ```dart
  // Run auto-backup if enabled (once per day, fire-and-forget)
  BackupService.runAutoBackupIfNeeded();
  ```
  (from `lib/main.dart`, at app launch; also called from `AutoSyncService.start()`'s periodic timer
  and `didChangeAppLifecycleState` on resume — see
  [`auto_sync_service.md`](auto_sync_service.md))
- **Notes:** A corrupt (unparseable) bundle from today does not count as "already backed up
  today", so an interrupted write is retried on the next check — matching
  `../../../AGENTS.md`'s corrupt-bundle handling.

### `static Future<List<BackupInfo>> listBackups()` <a id="listbackups"></a>
- **Kind:** static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 299)
- **Purpose:** List existing backups with their date, display size (including referenced blob
  sizes), and corruption status.
- **Inputs:** None.
- **Returns:** `Future<List<BackupInfo>>`, sorted newest-first by date.
- **Side effects:** None (read-only).
- **Algorithm:** 1. If the backup directory does not exist, return `[]`. 2. For each
  `backup_*.json` file: parse the date from its filename (`yyyyMMdd_HHmmss`), falling back to the
  file's mtime if that fails. 3. If the file is at or below `_probeMaxBytes` (4 MB), parse its JSON:
  add up the sizes of any blobs referenced in `_imageRefs` that exist on disk, and mark `corrupt =
  true` if parsing throws. 4. Larger (legacy inline-image) bundles are listed by raw file size alone
  without parsing. 5. Sort all entries by date, descending.
- **Usage:**
  ```dart
  final backups = await BackupService.listBackups();
  ```
  (from `lib/features/settings/views/backup_page.dart`; also called internally by
  [`runAutoBackupIfNeeded`](#runautobackupifneeded) and
  [`_cleanOldBackups`](#_cleanoldbackups))
- **Notes:** The 4 MB probe cap avoids fully parsing very large legacy bundles (which embed base64
  images inline) just to compute a display size.

### `static Future<List<String>> getBackupModules(File file)` <a id="getbackupmodules"></a>
- **Kind:** static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 362)
- **Purpose:** Read a backup bundle and return which data-module names (plus the synthetic
  `images` module) it contains, for the restore module-picker UI.
- **Inputs:** `file` — the backup bundle file.
- **Returns:** `Future<List<String>>` of module ids (e.g. `devices`, `networks`); empty list on any
  parse failure.
- **Side effects:** None (read-only).
- **Algorithm:** 1. Read and JSON-decode the file. 2. Map `modules.entries` to their module id for
  every key present in the bundle. 3. If the bundle has either `_images` (legacy) or `_imageRefs`
  (v2), append the synthetic `'images'` module id. 4. Any exception yields `[]`.
- **Usage:**
  ```dart
  final availableModules = await BackupService.getBackupModules(backup.file);
  ```
  (from `lib/features/settings/views/backup_page.dart`, to populate the restore module checklist)
- **Notes:** Images restore only when the `images` module is explicitly selected, per
  `../../../AGENTS.md`.

### `static String? _safeImageBasename(String rawKey)` <a id="_safeimagebasename"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 386)
- **Purpose:** Return a sanitized flat image file name from a backup bundle's image map key, or
  `null` if the key is unsafe.
- **Inputs:** `rawKey` — a raw key from `_imageRefs` (v2, `images/<name>`) or `_images` (legacy,
  bare basename).
- **Returns:** `String?` — the safe basename, or `null` when rejected.
- **Side effects:** None.
- **Algorithm:** 1. Normalize the key and convert backslashes to forward slashes. 2. Strip a
  leading `images/` prefix if present (v2 format). 3. Reject (`return null`) if the result is
  empty, contains a `/` (nested path), contains `..` (traversal), or is an absolute path.
  4. Otherwise return the normalized basename.
- **Usage:** Called internally by [`restoreBackup`](#restorebackup) for every image entry before
  it is written.
- **Notes:** Accepts both bare basenames (legacy MyDevice bundles) and `images/<name>` keys (v2),
  rejecting traversal, nesting, and absolute paths so a crafted bundle cannot write outside
  `images/` — the security boundary behind "sanitizes image names (flat basenames only;
  traversal/absolute paths rejected)" in `../../../AGENTS.md`.

### `static Future<RestoreResult> restoreBackup(File file, {Set<String>? moduleKeys})` <a id="restorebackup"></a>
- **Kind:** static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 411)
- **Purpose:** Validate and restore the selected data modules (and optionally images) from a
  backup bundle, without ever writing a partially-valid result.
- **Inputs:** `file` — the bundle; optional `moduleKeys` — module ids to restore (`null` means all
  modules present in the bundle, including images).
- **Returns:** `Future<RestoreResult>` (`ok`, `wroteAnything`, `missingImages`).
- **Side effects:** Overwrites app data files atomically; restores image files from blob
  references (v2) or inline base64 (legacy v1) into `images/`.
- **Algorithm:** 1. Read and JSON-decode the bundle. 2. **Validate before writing anything:** for
  each of the four `modules` entries that is both selected (or `moduleKeys == null`) and present in
  the bundle, call [`_validateModuleJson`](#_validatemodulejson) and stage its content in a
  `writes` map — a validation failure throws here, before any file is touched. 3. Write every
  staged file atomically, setting `wrote = true` per file. 4. If images are selected: ensure
  `images/` exists; prefer `_imageRefs` (v2) — for each entry, sanitize the key via
  [`_safeImageBasename`](#_safeimagebasename), skip if the referenced blob file is missing
  (incrementing `missingImages` instead of silently dropping it), else copy the blob's bytes into
  `images/<name>`. If there is no `_imageRefs` but there is a legacy `_images` map, base64-decode
  and write each sanitized entry instead. 5. Return `RestoreResult(ok: true, wroteAnything: wrote,
  missingImages: missingImages)`. 6. On any exception, return `RestoreResult(ok: false, ...)` with
  whatever `wrote`/`missingImages` state had accumulated so far.
- **Usage:**
  ```dart
  final result = await BackupService.restoreBackup(
    backup.file,
    moduleKeys: selected,
  );
  if (!result.ok) {
    if (hadAutoSync && !result.wroteAnything) {
      await WebDAVService.saveConfig(config.copyWith(autoSync: true));
    }
    ...
  }
  ```
  (from `lib/features/settings/views/backup_page.dart`, which disables WebDAV auto-sync *before*
  calling this and only re-enables it when the restore failed with `wroteAnything == false`)
- **Notes:** Every selected module payload is validated against the model parser before anything is
  written; image names are sanitized. `wroteAnything == false` means local data is guaranteed
  untouched, which is exactly the signal `../../../AGENTS.md` documents callers using to decide
  whether re-enabling auto-sync is safe.

### `static Future<void> deleteBackup(File file)` <a id="deletebackup"></a>
- **Kind:** static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 503)
- **Purpose:** Delete a specific backup bundle and then garbage-collect any image blobs no
  remaining backup references.
- **Inputs:** `file` — the backup bundle to delete.
- **Returns:** `Future<void>`.
- **Side effects:** Deletes `file` if it exists; runs [`_collectUnreferencedBlobs`](#_collectunreferencedblobs).
- **Algorithm:** If the file exists, delete it; always run blob GC afterward.
- **Usage:**
  ```dart
  await BackupService.deleteBackup(backup.file);
  ```
  (from `lib/features/settings/views/backup_page.dart`, manual backup deletion)
- **Notes:** None.

### `static Future<void> _cleanOldBackups()` <a id="_cleanoldbackups"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 515)
- **Purpose:** Delete backup bundles older than the configured retention window.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Deletes backup files whose date is before the retention cutoff.
- **Algorithm:** If `retentionDays <= 0` (keep forever), return immediately. Otherwise compute
  `cutoff = now - retentionDays days`, list backups, and delete each whose `date` is before
  `cutoff`.
- **Usage:** Called internally by [`createBackup`](#createbackup) after writing a new bundle.
- **Notes:** Runs before [`_collectUnreferencedBlobs`](#_collectunreferencedblobs) so blobs freed
  by deleted-old-backups can be collected in the same pass.

### `static Future<void> _collectUnreferencedBlobs()` <a id="_collectunreferencedblobs"></a>
- **Kind:** private static method
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 533)
- **Purpose:** Delete image blobs under `backups/blobs/` that no remaining backup bundle
  references.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Deletes unreferenced blob files older than the grace window.
- **Algorithm:** 1. List all blob files; if none, return early. 2. For every `backup_*.json` file
  in the backup directory, parse it and union its `_imageRefs` values (basenames) into a
  `referenced` set. **If any bundle fails to parse, abort the whole pass immediately** (`return`)
  rather than risk deleting a blob a corrupt-but-still-present bundle actually needs. 3. For each
  blob not in `referenced`, check its age; skip (keep) it if younger than `_blobGcGrace` (10
  minutes), otherwise delete it (best-effort, ignoring delete errors).
- **Usage:** Called internally by [`createBackup`](#createbackup) and
  [`deleteBackup`](#deletebackup) after their respective bundle changes.
- **Notes:** Conservative by design: when any remaining bundle cannot be parsed the reference set
  is unknown, so the pass aborts entirely rather than guessing; blobs younger than the 10-minute
  grace window are kept so a concurrent backup write in progress is never raced.

### `const RestoreResult({required this.ok, required this.wroteAnything, this.missingImages = 0})` <a id="restoreresult-new"></a>
- **Kind:** constructor of `RestoreResult`
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 591)
- **Purpose:** Hold the outcome of [`restoreBackup`](#restorebackup): overall success, whether any
  file was written, and how many v2 image references had no blob on disk.
- **Inputs:** `ok`, `wroteAnything`; optional `missingImages` (defaults to 0).
- **Returns:** A new `RestoreResult` instance.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Returned by [`restoreBackup`](#restorebackup); consumed by
  `lib/features/settings/views/backup_page.dart` to decide UI messaging and whether to re-enable
  auto-sync.
- **Notes:** `wroteAnything` is false only when the restore failed before writing any data or image
  file, so local data is guaranteed untouched in that case.

### `const BackupInfo({required this.file, required this.date, required this.sizeBytes, this.corrupt = false})` <a id="backupinfo-new"></a>
- **Kind:** constructor of `BackupInfo`
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 610)
- **Purpose:** Hold one backup's listing metadata: file handle, date, display size, and corruption
  flag.
- **Inputs:** `file`, `date`, `sizeBytes`; optional `corrupt` (defaults to false).
- **Returns:** A new `BackupInfo` instance.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Constructed by and returned from [`listBackups`](#listbackups).
- **Notes:** `sizeBytes` includes referenced blob sizes for v2 bundles; `corrupt` marks bundles
  whose JSON could not be parsed (restore is disabled for these in the UI).

### `String get displaySize` <a id="displaysize"></a>
- **Kind:** getter of `BackupInfo`
- **Source:** `lib/shared/services/backup_service.dart` (approx. line 622)
- **Purpose:** Format `sizeBytes` as a human-readable B/KB/MB string for the backup list UI.
- **Inputs:** None.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** If `sizeBytes < 1024`, format as `'$sizeBytes B'`. Else if `< 1024*1024`, format
  as KB with one decimal. Otherwise format as MB with one decimal.
- **Usage:** Read directly in the backup list UI (`lib/features/settings/views/backup_page.dart`)
  to display each `BackupInfo`'s size.
- **Notes:** None.
