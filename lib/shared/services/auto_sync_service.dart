import 'dart:async';

import 'package:flutter/widgets.dart';

import 'backup_service.dart';
import 'webdav_service.dart';

/// Singleton service that triggers WebDAV sync automatically when enabled.
///
/// Three triggers:
///   1. App started → immediate sync
///   2. App resumed from background → immediate sync
///   3. Data saved locally → debounced sync (30 s after last save)
class AutoSyncService with WidgetsBindingObserver {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `AutoSyncService._` instance.
  /// Side effects: Implementation-dependent.
  /// Notes: Implementations should preserve this contract.
  AutoSyncService._();
  static final instance = AutoSyncService._();

  Timer? _debounce;
  Timer? _periodic;
  bool _syncing = false;
  bool _started = false;
  DateTime? _lastSuccessAt;
  DateTime? _lastFailureAt;
  String? _lastError;
  bool _hasPendingConflicts = false;

  static const _debounceDuration = Duration(seconds: 30);
  static const _periodicDuration = Duration(minutes: 15);

  /// Callbacks invoked when sync writes merged data to local files.
  /// UI pages should register to reload their data.
  final List<void Function()> _onLocalDataChanged = [];
  final List<VoidCallback> _onStatusChanged = [];

  /// Purpose: Return the last successful sync time recorded by this service.
  /// Inputs: None.
  /// Returns: `DateTime?`.
  /// Side effects: None.
  /// Notes: Used by settings UI to surface sync health.
  DateTime? get lastSuccessAt => _lastSuccessAt;

  /// Purpose: Return the last failed sync time recorded by this service.
  /// Inputs: None.
  /// Returns: `DateTime?`.
  /// Side effects: None.
  /// Notes: Used by settings UI to surface sync health.
  DateTime? get lastFailureAt => _lastFailureAt;

  /// Purpose: Return the most recent sync failure message.
  /// Inputs: None.
  /// Returns: `String?`.
  /// Side effects: None.
  /// Notes: Null after a successful sync.
  String? get lastError => _lastError;

  /// Purpose: Return whether auto-sync found conflicts needing manual resolution.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Conflicts are not auto-resolved during background sync.
  bool get hasPendingConflicts => _hasPendingConflicts;

  /// Purpose: Add on local data changed through the current flow.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  void addOnLocalDataChanged(void Function() cb) => _onLocalDataChanged.add(cb);

  /// Purpose: Implement the remove on local data changed behavior for this file.
  /// Inputs: `cb`.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  void removeOnLocalDataChanged(void Function() cb) =>
      _onLocalDataChanged.remove(cb);

  /// Purpose: Add a listener for sync status changes.
  /// Inputs: `cb`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: UI pages use this to refresh visible sync warnings.
  void addOnStatusChanged(VoidCallback cb) => _onStatusChanged.add(cb);

  /// Purpose: Remove a listener for sync status changes.
  /// Inputs: `cb`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Must be paired with `addOnStatusChanged` in widget dispose.
  void removeOnStatusChanged(VoidCallback cb) => _onStatusChanged.remove(cb);

  /// Purpose: Record a sync result triggered outside the auto-sync loop.
  /// Inputs: `result`.
  /// Returns: None.
  /// Side effects: Updates sync status and notifies listeners.
  /// Notes: Manual sync pages call this so status banners clear after success.
  void recordSyncResult(SyncResult result) {
    if (result.hasConflicts) {
      _recordFailure(
        'Sync conflicts require manual resolution${result.error != null ? ': ${result.error}' : ''}',
        conflicts: true,
      );
    } else if (!result.success) {
      _recordFailure(result.error ?? 'Unknown sync failure');
    } else {
      _recordSuccess();
    }
  }

  /// Purpose: Notify UI reload listeners after a manual sync or force
  /// operation wrote local data files.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Consumes the WebDAV local-data-changed flag and invokes
  /// registered reload callbacks.
  /// Notes: Manual sync pages call this so open pages reload without waiting
  /// for the next background sync.
  void notifyLocalDataChangedIfNeeded() {
    if (WebDAVService.consumeLocalDataChanged()) {
      for (final cb in List.of(_onLocalDataChanged)) {
        cb();
      }
    }
  }

  /// Purpose: Record a conflict-finalization result.
  /// Inputs: `ok`.
  /// Returns: None.
  /// Side effects: Updates sync status and notifies listeners.
  /// Notes: Used after users resolve conflicts manually.
  void recordFinalizeResult(bool ok) {
    if (ok) {
      _recordSuccess();
    } else {
      _recordFailure('Failed to upload resolved sync conflicts');
    }
  }

  /// Purpose: Start the current workflow for the current workflow.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    // Sync once on first launch
    _trySync();
    _periodic = Timer.periodic(_periodicDuration, (_) => _trySync());
  }

  /// Purpose: Stop the current workflow and clean up any related activity.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  void stop() {
    _debounce?.cancel();
    _debounce = null;
    _periodic?.cancel();
    _periodic = null;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  /// Purpose: Notify dependent code that saved changed.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  /// Called by storage save methods to schedule a debounced sync.
  void notifySaved() {
    if (!_started) return;
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _trySync);
  }

  /// Purpose: Trigger a sync as soon as possible, skipping the debounce timer.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Cancels any pending debounce and starts a sync attempt.
  /// Notes: Used right after enabling/saving WebDAV auto-sync configuration
  /// (aligned with MyAnime/MyDay).
  void requestSyncNow() {
    _debounce?.cancel();
    _debounce = null;
    unawaited(_trySync());
  }

  /// Purpose: Implement the did change app lifecycle state behavior for this file.
  /// Inputs: `state`.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _trySync();
      BackupService.runAutoBackupIfNeeded();
    }
  }

  /// Purpose: Provide the internal try sync helper for this file.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only. The `_syncing` guard
  /// silently skips overlapping triggers (timer/resume/debounce) so they do
  /// not surface a spurious "Sync already in progress" failure banner.
  Future<void> _trySync() async {
    if (_syncing) return;
    final config = await WebDAVService.loadConfig();
    if (config == null || !config.isConfigured || !config.autoSync) return;
    _syncing = true;
    try {
      final result = await WebDAVService.sync(config);
      if (result.hasConflicts) {
        _recordFailure(
          'Sync conflicts require manual resolution${result.error != null ? ': ${result.error}' : ''}',
          conflicts: true,
        );
      } else if (!result.success) {
        _recordFailure(result.error ?? 'Unknown sync failure');
      } else {
        _recordSuccess();
      }
      // Notify UI pages if sync wrote merged data to local files
      if (WebDAVService.consumeLocalDataChanged()) {
        for (final cb in List.of(_onLocalDataChanged)) {
          cb();
        }
      }
    } catch (e) {
      _recordFailure(e.toString());
    } finally {
      _syncing = false;
    }
  }

  /// Purpose: Record a successful sync.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Clears failure state and notifies status listeners.
  /// Notes: Internal helper used within this file only.
  void _recordSuccess() {
    _lastSuccessAt = DateTime.now();
    _lastError = null;
    _hasPendingConflicts = false;
    _notifyStatusChanged();
  }

  /// Purpose: Record a failed sync.
  /// Inputs: `error`, optional `conflicts`.
  /// Returns: None.
  /// Side effects: Updates failure state and notifies status listeners.
  /// Notes: Internal helper used within this file only.
  void _recordFailure(String error, {bool conflicts = false}) {
    _lastFailureAt = DateTime.now();
    _lastError = error;
    _hasPendingConflicts = conflicts;
    _notifyStatusChanged();
  }

  /// Purpose: Notify all registered sync status listeners.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Invokes UI callbacks.
  /// Notes: Internal helper used within this file only.
  void _notifyStatusChanged() {
    for (final cb in List.of(_onStatusChanged)) {
      cb();
    }
  }
}
