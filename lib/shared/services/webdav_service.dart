/// Purpose: MyDevice's WebDAV sync API, now a facade over the shared
/// `WebDavSyncEngine` from the `myapps_data` package.
/// Inputs: `WebDAVConfig` values from the config page and auto-sync service.
/// Returns: App-typed `SyncResult`/`PendingSync` values.
/// Side effects: Delegates all local and remote I/O to the shared engine.
/// Notes: PLAN.md P3.3.3. Every public member kept its name, signature, and
/// semantics so call sites, the conflict dialogs, and the existing tests
/// compile and behave unchanged (I7). The four data modules are described in
/// `lib/app/data_modules.dart`; the hardcoded `_dataFileNames` list is gone.
library;

import 'package:flutter/foundation.dart';
import 'package:myapps_data/myapps_data.dart' as shared;
import 'package:myapps_data/myapps_data.dart' show SyncProgress;

import '../../app/data_modules.dart';
import 'sync_merge.dart';

// The config and transport value types are the package's now, re-exported under
// their original names so every call site sees the same type (I7). Field names,
// JSON keys, and the `.nextcloud()` factory are unchanged (I1/I2).
export 'package:myapps_data/myapps_data.dart'
    show WebDAVConfig, WebDAVUploadLock, RemoteFile, RemoteFileStatus;

/// Result of a sync operation.
class SyncResult {
  /// Whether the operation completed without a fatal or per-file error.
  final bool success;

  /// Error text shown to the user when [success] is false.
  final String? error;

  /// Unresolved conflicts awaiting the conflict dialogs.
  final PendingSync? pending;

  /// Non-fatal warnings collected during sync (e.g. individual image failures).
  final List<String> warnings;

  /// Purpose: Create a sync result instance.
  /// Inputs: `warnings`.
  /// Returns: A new `SyncResult` instance.
  /// Side effects: None.
  /// Notes: None.
  const SyncResult({
    required this.success,
    this.error,
    this.pending,
    this.warnings = const [],
  });

  /// Purpose: Return the current has conflicts value.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasConflicts => pending != null;
}

/// Holds pending merge results that contain per-record conflicts.
class PendingSync {
  /// Pending device merge, when devices conflicted.
  final DeviceMergeResult? deviceMerge;

  /// Pending network merge, when networks conflicted.
  final NetworkMergeResult? networkMerge;

  /// Pending dataset merge, when datasets conflicted.
  final DataSetMergeResult? dataSetMerge;

  /// Pending service merge, when service nodes or routes conflicted.
  final ServiceMergeResult? serviceMerge;

  /// Engine-side pending state used to finalize under a fresh remote lock.
  final shared.EnginePendingSync? enginePending;

  /// Purpose: Create a pending sync instance.
  /// Inputs: None.
  /// Returns: A new `PendingSync` instance.
  /// Side effects: None.
  /// Notes: `enginePending` is null only for values built by older test code.
  const PendingSync({
    this.deviceMerge,
    this.networkMerge,
    this.dataSetMerge,
    this.serviceMerge,
    this.enginePending,
  });

  /// Purpose: Return the current all conflicts value.
  /// Inputs: None.
  /// Returns: `List<RecordConflict>`.
  /// Side effects: None.
  /// Notes: None.
  List<RecordConflict> get allConflicts => [
    ...?deviceMerge?.conflicts,
    ...?networkMerge?.conflicts,
    ...?dataSetMerge?.conflicts,
    ...?serviceMerge?.allConflicts,
  ];
}

/// WebDAV sync facade over the shared engine.
class WebDAVService {
  /// Lazily-built engine shared by every static entry point.
  ///
  /// One long-lived instance preserves the in-flight guard, the sticky
  /// local-data-changed flag, and the progress notifier identity that the old
  /// static implementation held in class fields.
  static final shared.WebDavSyncEngine _engine = shared.WebDavSyncEngine(
    storage: const DeviceStorageAdapter(),
    modules: deviceModuleRegistry,
    defaultRemotePath: deviceDefaultRemotePath,
  );

  /// Live sync progress for the config page's progress bar.
  static ValueNotifier<SyncProgress> get progress => _engine.progress;

  /// Purpose: Read and clear the "local data changed" signal.
  /// Inputs: None.
  /// Returns: `bool` — whether sync wrote local data or downloaded images.
  /// Side effects: Resets the flag.
  /// Notes: Open pages call this to decide whether to reload from disk.
  static bool consumeLocalDataChanged() => _engine.consumeLocalDataChanged();

  /// Purpose: Load the saved WebDAV configuration.
  /// Inputs: None.
  /// Returns: `Future<WebDAVConfig?>` — null when absent or unreadable.
  /// Side effects: Reads `webdav_config.json`.
  /// Notes: A missing `remotePath` still defaults to `/MyDevice`.
  static Future<shared.WebDAVConfig?> loadConfig() => _engine.loadConfig();

  /// Purpose: Save the WebDAV configuration.
  /// Inputs: `config`.
  /// Returns: `Future<void>`.
  /// Side effects: Atomically writes `webdav_config.json`.
  /// Notes: Credentials remain plaintext, unchanged from before (out of scope).
  static Future<void> saveConfig(shared.WebDAVConfig config) =>
      _engine.saveConfig(config);

  /// Purpose: Delete the saved WebDAV configuration.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Removes `webdav_config.json` when present.
  /// Notes: Base snapshots and the client ID are intentionally left in place.
  static Future<void> deleteConfig() => _engine.deleteConfig();

  /// Purpose: Check that the server is reachable with these credentials.
  /// Inputs: `config`, possibly unsaved values from the config page.
  /// Returns: `Future<bool>` — true for HTTP 207 or 404.
  /// Side effects: Issues one PROPFIND.
  /// Notes: 404 counts as reachable because the collection may not exist yet.
  static Future<bool> testConnection(shared.WebDAVConfig config) =>
      _engine.testConnection(config);

  /// Purpose: Run a full two-way sync under the remote upload lock.
  /// Inputs: `config`, `autoResolve` (false everywhere in production, I4).
  /// Returns: `Future<SyncResult>`, carrying `PendingSync` on true conflicts.
  /// Side effects: Local and remote data/image/lock I/O; updates [progress].
  /// Notes: Modules sync in registry order; conflicts are never auto-resolved.
  static Future<SyncResult> sync(
    shared.WebDAVConfig config, {
    bool autoResolve = false,
  }) async {
    return _toSyncResult(await _engine.sync(config, autoResolve: autoResolve));
  }

  /// Purpose: Finalize sync by applying the user's conflict resolutions.
  /// Inputs: `config`, `pending`, `resolutions` (record ID → chosen record).
  /// Returns: `Future<bool>` — false when applying or uploading fails.
  /// Side effects: Reacquires the remote lock, writes local data, uploads.
  /// Notes: One flat resolution map spans every module, exactly as before —
  /// each module's `buildResolved` picks out the records it recognizes by type.
  static Future<bool> finalizePendingSync(
    shared.WebDAVConfig config,
    PendingSync pending,
    Map<String, dynamic> resolutions,
  ) async {
    final enginePending = pending.enginePending;
    if (enginePending == null) return false;
    return _engine.finalizePendingSync(config, enginePending, {
      for (final module in enginePending.modules)
        module.module.moduleId: resolutions,
    });
  }

  /// Purpose: Overwrite remote data with local data, without merging.
  /// Inputs: `config`.
  /// Returns: `Future<SyncResult>`.
  /// Side effects: Overwrites remote files, uploads images, saves bases.
  /// Notes: Remote changes since the last sync are lost.
  static Future<SyncResult> forceUpload(shared.WebDAVConfig config) async {
    return _toSyncResult(await _engine.forceUpload(config));
  }

  /// Purpose: Overwrite local data with remote data, without merging.
  /// Inputs: `config`.
  /// Returns: `Future<SyncResult>`.
  /// Side effects: Replaces local data files and bases, downloads images.
  /// Notes: Local changes since the last sync are lost.
  static Future<SyncResult> forceDownload(shared.WebDAVConfig config) async {
    return _toSyncResult(await _engine.forceDownload(config));
  }

  /// Purpose: Convert an engine result into the app-typed result.
  /// Inputs: `result` from the shared engine.
  /// Returns: `SyncResult` with the app's `PendingSync` shape rebuilt.
  /// Side effects: None.
  /// Notes: The engine carries each app-typed merge result through as opaque
  /// `state`, so the conflict dialogs still receive real model objects.
  static SyncResult _toSyncResult(shared.EngineSyncResult result) {
    final pending = result.pending;
    return SyncResult(
      success: result.success,
      error: result.error,
      warnings: result.warnings,
      pending: pending == null
          ? null
          : PendingSync(
              deviceMerge:
                  pending.forModuleId('devices')?.state as DeviceMergeResult?,
              networkMerge:
                  pending.forModuleId('networks')?.state as NetworkMergeResult?,
              dataSetMerge:
                  pending.forModuleId('datasets')?.state as DataSetMergeResult?,
              serviceMerge:
                  pending.forModuleId('services')?.state as ServiceMergeResult?,
              enginePending: pending,
            ),
    );
  }
}
