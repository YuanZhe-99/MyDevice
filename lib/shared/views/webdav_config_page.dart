import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/services/auto_sync_service.dart';
import '../../shared/services/sync_merge.dart';
import '../../shared/services/sync_progress.dart';
import '../../shared/services/sync_wake_lock.dart';
import '../../shared/services/webdav_service.dart';

class WebDAVConfigPage extends StatefulWidget {
  /// Purpose: Create a web davconfig page instance.
  /// Inputs: None.
  /// Returns: A new `WebDAVConfigPage` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  const WebDAVConfigPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `State` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  @override
  State<WebDAVConfigPage> createState() => _WebDAVConfigPageState();
}

class _WebDAVConfigPageState extends State<WebDAVConfigPage> {
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _pathController = TextEditingController(text: '/MyDevice');
  bool _loading = true;
  bool _testing = false;
  bool _syncing = false;
  bool _isConfigured = false;
  bool _autoSync = false;

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Registers listeners and may kick off asynchronous loading.
  /// Notes: Guard any post-await UI updates with `mounted` when needed.
  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnStatusChanged(_refreshSyncStatus);
    _loadConfig();
  }

  /// Purpose: Refresh this page when background sync status changes.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  void _refreshSyncStatus() {
    if (mounted) setState(() {});
  }

  /// Purpose: Load config into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _loadConfig() async {
    final config = await WebDAVService.loadConfig();
    if (config != null) {
      _urlController.text = config.serverUrl;
      _userController.text = config.username;
      _passController.text = config.password;
      _pathController.text = config.remotePath;
      _isConfigured = config.isConfigured;
      _autoSync = config.autoSync;
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Purpose: Release listeners, controllers, and other owned resources.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Releases owned resources and unregisters listeners.
  /// Notes: Call the superclass implementation in the expected lifecycle order.
  @override
  void dispose() {
    AutoSyncService.instance.removeOnStatusChanged(_refreshSyncStatus);
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  /// Purpose: Provide the internal current config helper for this file.
  /// Inputs: None.
  /// Returns: `WebDAVConfig`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  WebDAVConfig get _currentConfig => WebDAVConfig(
    serverUrl: _urlController.text.trim(),
    username: _userController.text.trim(),
    password: _passController.text.trim(),
    remotePath: _pathController.text.trim(),
    autoSync: _autoSync,
  );

  /// Purpose: Save config to the relevant storage or service layer.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _saveConfig() async {
    final config = _currentConfig;
    await WebDAVService.saveConfig(config);
    setState(() => _isConfigured = config.isConfigured);
    if (config.isConfigured && config.autoSync) {
      AutoSyncService.instance.requestSyncNow();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.settingsWebDAVConfigSaved,
          ),
        ),
      );
    }
  }

  /// Purpose: Test connection and report the outcome.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final ok = await WebDAVService.testConnection(_currentConfig);
    if (mounted) {
      setState(() => _testing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? AppLocalizations.of(context)!.settingsWebDAVConnectionSuccess
                : AppLocalizations.of(context)!.settingsWebDAVConnectionFailed,
          ),
        ),
      );
    }
  }

  /// Purpose: Sync now with the relevant peer or storage.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild. Opens or
  /// updates routes, dialogs, or other UI flows. Holds the sync wake lock
  /// while the sync request runs.
  /// Notes: Internal helper used within this file only. The wake lock is
  /// released in `finally` so failures and exceptions cannot leak it.
  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    await SyncWakeLock.acquire();
    SyncResult result;
    try {
      result = await WebDAVService.sync(_currentConfig);
    } finally {
      await SyncWakeLock.release();
    }
    if (!mounted) return;
    AutoSyncService.instance.recordSyncResult(result);
    AutoSyncService.instance.notifyLocalDataChangedIfNeeded();
    setState(() => _syncing = false);

    if (result.hasConflicts) {
      await _resolveConflicts(result);
      return;
    }

    await _showSyncResult(result);
  }

  /// Purpose: Present a non-conflict sync/force result to the user.
  /// Inputs: `result`.
  /// Returns: `Future<void>`.
  /// Side effects: Shows a dialog for failures/warnings or a snackbar on success.
  /// Notes: Internal helper used within this file only.
  Future<void> _showSyncResult(SyncResult result) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    if (!result.success) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.settingsWebDAVSyncFailed),
          content: SingleChildScrollView(
            child: SelectableText(result.error ?? '-'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      );
      return;
    }

    if (result.warnings.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.settingsWebDAVSyncSuccess),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.settingsWebDAVSyncImageWarnings(result.warnings.length),
                ),
                const SizedBox(height: 8),
                ...result.warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(w, style: Theme.of(ctx).textTheme.bodySmall),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsWebDAVSyncSuccess)));
  }

  /// Purpose: Confirm and run a force upload (local overwrites remote).
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Overwrites remote data after user confirmation. Holds the
  /// sync wake lock while the upload runs.
  /// Notes: Internal helper used within this file only. The wake lock is
  /// acquired only after the user confirms and released in `finally`.
  Future<void> _forceUpload() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirmForceAction(
      title: l10n.settingsWebDAVForceUploadConfirmTitle,
      body: l10n.settingsWebDAVForceUploadConfirmBody,
      confirmLabel: l10n.settingsWebDAVForceUpload,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _syncing = true);
    await SyncWakeLock.acquire();
    SyncResult result;
    try {
      result = await WebDAVService.forceUpload(_currentConfig);
    } finally {
      await SyncWakeLock.release();
    }
    if (!mounted) return;
    AutoSyncService.instance.recordSyncResult(result);
    AutoSyncService.instance.notifyLocalDataChangedIfNeeded();
    setState(() => _syncing = false);
    await _showSyncResult(result);
  }

  /// Purpose: Confirm and run a force download (remote overwrites local).
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Overwrites local data after user confirmation. Holds the
  /// sync wake lock while the download runs.
  /// Notes: Internal helper used within this file only. The wake lock is
  /// acquired only after the user confirms and released in `finally`.
  Future<void> _forceDownload() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirmForceAction(
      title: l10n.settingsWebDAVForceDownloadConfirmTitle,
      body: l10n.settingsWebDAVForceDownloadConfirmBody,
      confirmLabel: l10n.settingsWebDAVForceDownload,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _syncing = true);
    await SyncWakeLock.acquire();
    SyncResult result;
    try {
      result = await WebDAVService.forceDownload(_currentConfig);
    } finally {
      await SyncWakeLock.release();
    }
    if (!mounted) return;
    AutoSyncService.instance.recordSyncResult(result);
    AutoSyncService.instance.notifyLocalDataChangedIfNeeded();
    setState(() => _syncing = false);
    await _showSyncResult(result);
  }

  /// Purpose: Ask the user to confirm a destructive force upload/download.
  /// Inputs: `title`, `body`, `confirmLabel`.
  /// Returns: `Future<bool?>` — true when confirmed.
  /// Side effects: Opens a modal dialog.
  /// Notes: Internal helper used within this file only.
  Future<bool?> _confirmForceAction({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(ctx)!.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  /// Purpose: Map a sync progress snapshot to a localized status line.
  /// Inputs: `l10n`, `progress`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _progressText(AppLocalizations l10n, SyncProgress progress) {
    switch (progress.phase) {
      case SyncPhase.connecting:
        return l10n.syncPhaseConnecting;
      case SyncPhase.downloadingData:
        return l10n.syncPhaseDownloadingData(
          progress.detail ?? '',
          progress.current,
          progress.total,
        );
      case SyncPhase.merging:
        return l10n.syncPhaseMerging(progress.detail ?? '');
      case SyncPhase.uploadingData:
        return l10n.syncPhaseUploadingData(progress.detail ?? '');
      case SyncPhase.uploadingImages:
        return l10n.syncPhaseUploadingImages(progress.current, progress.total);
      case SyncPhase.downloadingImages:
        return l10n.syncPhaseDownloadingImages(
          progress.current,
          progress.total,
        );
      case SyncPhase.idle:
      case SyncPhase.done:
      case SyncPhase.error:
        return '';
    }
  }

  /// Purpose: Ask the user to resolve each pending sync conflict, then upload
  /// the resolved data.
  /// Inputs: `result` — the conflicting sync result carrying the pending merge.
  /// Returns: `Future<void>`.
  /// Side effects: Shows one dialog per conflict; on full resolution uploads
  /// the resolved data under the sync wake lock and records the outcome.
  /// Notes: Internal helper used within this file only. Dismissing any
  /// conflict dialog (system back) aborts the whole resolution: nothing is
  /// uploaded, the conflict stays pending in the visible sync status, and no
  /// record is silently resolved to the local version.
  Future<void> _resolveConflicts(SyncResult result) async {
    final pending = result.pending!;
    final resolutions = <String, dynamic>{};

    for (final conflict in pending.allConflicts) {
      if (!mounted) return;
      final chosen = await showDialog<dynamic>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ConflictDialog(conflict: conflict),
      );
      if (chosen == null) {
        // User backed out — abort without uploading; conflict stays pending.
        AutoSyncService.instance.recordSyncResult(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.settingsWebDAVSyncFailed,
              ),
            ),
          );
        }
        return;
      }
      resolutions[conflict.id] = chosen;
    }

    await SyncWakeLock.acquire();
    bool ok;
    try {
      ok = await WebDAVService.finalizePendingSync(
        _currentConfig,
        pending,
        resolutions,
      );
    } finally {
      await SyncWakeLock.release();
    }
    AutoSyncService.instance.recordFinalizeResult(ok);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? AppLocalizations.of(context)!.settingsWebDAVSyncSuccess
                : AppLocalizations.of(context)!.settingsWebDAVSyncFailed,
          ),
        ),
      );
    }
  }

  /// Purpose: Provide the internal disconnect helper for this file.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _disconnect() async {
    await WebDAVService.deleteConfig();
    _urlController.clear();
    _userController.clear();
    _passController.clear();
    _pathController.text = '/MyDevice';
    setState(() {
      _isConfigured = false;
      _autoSync = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.settingsWebDAVConfigRemoved,
          ),
        ),
      );
    }
  }

  /// Purpose: Fill nextcloud with predefined values.
  /// Inputs: None.
  /// Returns: `void`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  void _fillNextcloud() {
    _urlController.text =
        'https://your-nextcloud-host/remote.php/dav/files/USERNAME';
    _pathController.text = '/MyDevice';
    setState(() {});
  }

  /// Purpose: Build a short sync health summary for display.
  /// Inputs: `l10n`.
  /// Returns: `String?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String? _syncStatusText(AppLocalizations l10n) {
    final service = AutoSyncService.instance;
    if (service.lastError != null) {
      return service.hasPendingConflicts
          ? '${l10n.settingsWebDAVAutoSyncConflict}: ${service.lastError}'
          : '${l10n.settingsWebDAVAutoSyncFailed}: ${service.lastError}';
    }
    if (service.lastSuccessAt != null) {
      return '${l10n.settingsWebDAVLastSuccess}: ${service.lastSuccessAt!.toLocal()}';
    }
    return null;
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final syncStatus = _syncStatusText(l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsWebDAVSync), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Presets
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _fillNextcloud,
                      icon: const Icon(Icons.cloud, size: 18),
                      label: Text(l10n.settingsWebDAVNextcloud),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Server URL
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsWebDAVServerURL,
                    hintText: 'https://example.com/remote.php/dav/files/user',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _userController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsWebDAVUsername,
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _passController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsWebDAVPassword,
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _pathController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsWebDAVRemotePath,
                    hintText: '/MyDevice',
                  ),
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _saveConfig,
                        child: Text(l10n.save),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _testing ? null : _testConnection,
                        child: _testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.settingsWebDAVTestConnection),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isConfigured) ...[
                  if (syncStatus != null) ...[
                    Card(
                      color: AutoSyncService.instance.lastError == null
                          ? theme.colorScheme.surfaceContainerHighest
                          : theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          syncStatus,
                          style: TextStyle(
                            color: AutoSyncService.instance.lastError == null
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ValueListenableBuilder<SyncProgress>(
                    valueListenable: WebDAVService.progress,
                    builder: (context, progress, _) {
                      if (!progress.isRunning) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(value: progress.fraction),
                          const SizedBox(height: 8),
                          Text(
                            _progressText(l10n, progress),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
                  FilledButton.icon(
                    onPressed: _syncing ? null : _syncNow,
                    icon: _syncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(
                      _syncing
                          ? l10n.settingsWebDAVSyncing
                          : l10n.settingsWebDAVSyncNow,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _syncing ? null : _forceUpload,
                          icon: const Icon(Icons.upload, size: 18),
                          label: Text(l10n.settingsWebDAVForceUpload),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _syncing ? null : _forceDownload,
                          icon: const Icon(Icons.download, size: 18),
                          label: Text(l10n.settingsWebDAVForceDownload),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.settingsWebDAVAutoSync),
                    subtitle: Text(l10n.settingsWebDAVAutoSyncDesc),
                    value: _autoSync,
                    onChanged: (v) async {
                      setState(() => _autoSync = v);
                      final config = _currentConfig;
                      await WebDAVService.saveConfig(config);
                      if (v && config.isConfigured) {
                        AutoSyncService.instance.requestSyncNow();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _disconnect,
                    icon: const Icon(Icons.link_off),
                    label: Text(l10n.settingsWebDAVDisconnect),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ConflictDialog extends StatelessWidget {
  final RecordConflict conflict;

  /// Purpose: Create a conflict dialog instance.
  /// Inputs: None.
  /// Returns: A new `_ConflictDialog` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  const _ConflictDialog({required this.conflict});

  /// Purpose: Extract the modified timestamp from a merge record when present.
  /// Inputs: `record` — a dynamic conflict record (Device/Network/DataSet/...).
  /// Returns: `String?` — the local-time timestamp, or null when unavailable.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. `NetworkDevice`
  /// assignments intentionally have no `modifiedAt`, so this falls back to
  /// null and the dialog shows the record ID instead.
  static String? _modifiedAtOf(dynamic record) {
    try {
      final value = record.modifiedAt;
      if (value is DateTime) return value.toLocal().toString();
    } catch (_) {
      // Record type has no modifiedAt field.
    }
    return null;
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state. Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localModified = _modifiedAtOf(conflict.localRecord);
    final remoteModified = _modifiedAtOf(conflict.remoteRecord);
    return AlertDialog(
      title: Text(l10n.syncConflictTitle(conflict.displayName)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.syncConflictBody),
            const SizedBox(height: 16),
            Text(
              l10n.syncConflictLocalVersion,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              localModified != null
                  ? l10n.syncConflictModifiedAt(localModified)
                  : l10n.syncConflictRecordId(conflict.id),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.syncConflictRemoteVersion,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              remoteModified != null
                  ? l10n.syncConflictModifiedAt(remoteModified)
                  : l10n.syncConflictRecordId(conflict.id),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(conflict.localRecord),
          child: Text(l10n.syncConflictKeepLocal),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(conflict.remoteRecord),
          child: Text(l10n.syncConflictKeepRemote),
        ),
      ],
    );
  }
}
