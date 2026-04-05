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
  AutoSyncService._();
  static final instance = AutoSyncService._();

  Timer? _debounce;
  bool _started = false;

  static const _debounceDuration = Duration(seconds: 30);

  /// Callbacks invoked when sync writes merged data to local files.
  /// UI pages should register to reload their data.
  final List<void Function()> _onLocalDataChanged = [];
  void addOnLocalDataChanged(void Function() cb) =>
      _onLocalDataChanged.add(cb);
  void removeOnLocalDataChanged(void Function() cb) =>
      _onLocalDataChanged.remove(cb);

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    // Sync once on first launch
    _trySync();
  }

  void stop() {
    _debounce?.cancel();
    _debounce = null;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  /// Called by storage save methods to schedule a debounced sync.
  void notifySaved() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _trySync);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _trySync();
      BackupService.runAutoBackupIfNeeded();
    }
  }

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
