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
  bool _started = false;

  static const _debounceDuration = Duration(seconds: 30);
  static const _periodicDuration = Duration(minutes: 15);

  /// Callbacks invoked when sync writes merged data to local files.
  /// UI pages should register to reload their data.
  final List<void Function()> _onLocalDataChanged = [];
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
  /// Notes: Internal helper used within this file only.
  Future<void> _trySync() async {
    final config = await WebDAVService.loadConfig();
    if (config == null || !config.isConfigured || !config.autoSync) return;
    try {
      await WebDAVService.sync(config, autoResolve: true);
      // Notify UI pages if sync wrote merged data to local files
      if (WebDAVService.consumeLocalDataChanged()) {
        for (final cb in List.of(_onLocalDataChanged)) {
          cb();
        }
      }
    } catch (_) {
      // Auto-sync failures are silent — user can always sync manually.
    }
  }
}
