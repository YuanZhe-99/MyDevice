import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/services/sync_merge.dart';
import '../../shared/services/webdav_service.dart';

class WebDAVConfigPage extends StatefulWidget {
  const WebDAVConfigPage({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

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

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  WebDAVConfig get _currentConfig => WebDAVConfig(
        serverUrl: _urlController.text.trim(),
        username: _userController.text.trim(),
        password: _passController.text.trim(),
        remotePath: _pathController.text.trim(),
        autoSync: _autoSync,
      );

  Future<void> _saveConfig() async {
    final config = _currentConfig;
    await WebDAVService.saveConfig(config);
    setState(() => _isConfigured = config.isConfigured);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context)!.settingsWebDAVConfigSaved)),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final ok = await WebDAVService.testConnection(_currentConfig);
    if (mounted) {
      setState(() => _testing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? AppLocalizations.of(context)!.settingsWebDAVConnectionSuccess
              : AppLocalizations.of(context)!.settingsWebDAVConnectionFailed),
        ),
      );
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final result = await WebDAVService.sync(_currentConfig);
    if (!mounted) return;
    setState(() => _syncing = false);

    if (result.hasConflicts) {
      await _resolveConflicts(result.pending!);
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    if (!result.success) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.settingsWebDAVSyncFailed),
          content: SingleChildScrollView(
            child: Text(result.error ?? '-'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
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
                Text(l10n.settingsWebDAVSyncImageWarnings(
                    result.warnings.length)),
                const SizedBox(height: 8),
                ...result.warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(w,
                        style: Theme.of(ctx).textTheme.bodySmall),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsWebDAVSyncSuccess)),
    );
  }

  Future<void> _resolveConflicts(PendingSync pending) async {
    final resolutions = <String, dynamic>{};

    for (final conflict in pending.allConflicts) {
      if (!mounted) return;
      final chosen = await showDialog<dynamic>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ConflictDialog(conflict: conflict),
      );
      if (chosen != null) {
        resolutions[conflict.id] = chosen;
      } else {
        resolutions[conflict.id] = conflict.localRecord;
      }
    }

    final ok = await WebDAVService.finalizePendingSync(
      _currentConfig,
      pending,
      resolutions,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? AppLocalizations.of(context)!.settingsWebDAVSyncSuccess
              : AppLocalizations.of(context)!.settingsWebDAVSyncFailed),
        ),
      );
    }
  }

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
                AppLocalizations.of(context)!.settingsWebDAVConfigRemoved)),
      );
    }
  }

  void _fillNextcloud() {
    _urlController.text =
        'https://your-nextcloud-host/remote.php/dav/files/USERNAME';
    _pathController.text = '/MyDevice';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsWebDAVSync),
        centerTitle: true,
      ),
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
                    hintText:
                        'https://example.com/remote.php/dav/files/user',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _userController,
                  decoration:
                      InputDecoration(labelText: l10n.settingsWebDAVUsername),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _passController,
                  decoration:
                      InputDecoration(labelText: l10n.settingsWebDAVPassword),
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
                                    strokeWidth: 2))
                            : Text(l10n.settingsWebDAVTestConnection),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isConfigured) ...[
                  FilledButton.icon(
                    onPressed: _syncing ? null : _syncNow,
                    icon: _syncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.sync),
                    label: Text(_syncing
                        ? l10n.settingsWebDAVSyncing
                        : l10n.settingsWebDAVSyncNow),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.settingsWebDAVAutoSync),
                    subtitle: Text(l10n.settingsWebDAVAutoSyncDesc),
                    value: _autoSync,
                    onChanged: (v) async {
                      setState(() => _autoSync = v);
                      await WebDAVService.saveConfig(_currentConfig);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _disconnect,
                    child: Text(
                      l10n.settingsWebDAVDisconnect,
                      style: TextStyle(color: theme.colorScheme.error),
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

  const _ConflictDialog({required this.conflict});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            Text(l10n.syncConflictLocalVersion,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('ID: ${conflict.id}'),
            const SizedBox(height: 12),
            Text(l10n.syncConflictRemoteVersion,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('ID: ${conflict.id}'),
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
