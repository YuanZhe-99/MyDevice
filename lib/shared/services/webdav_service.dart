import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../features/datasets/models/dataset.dart';
import '../../features/devices/models/device.dart';
import '../../features/devices/services/device_storage.dart';
import '../../features/network/models/network.dart';
import 'sync_merge.dart';

/// Persisted WebDAV configuration.
class WebDAVConfig {
  final String serverUrl;
  final String username;
  final String password;
  final String remotePath;
  final bool autoSync;

  const WebDAVConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.remotePath = '/MyDevice',
    this.autoSync = false,
  });

  bool get isConfigured =>
      serverUrl.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  WebDAVConfig copyWith({bool? autoSync}) => WebDAVConfig(
        serverUrl: serverUrl,
        username: username,
        password: password,
        remotePath: remotePath,
        autoSync: autoSync ?? this.autoSync,
      );

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
        'remotePath': remotePath,
        'autoSync': autoSync,
      };

  factory WebDAVConfig.fromJson(Map<String, dynamic> json) => WebDAVConfig(
        serverUrl: json['serverUrl'] as String? ?? '',
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        remotePath: json['remotePath'] as String? ?? '/MyDevice',
        autoSync: json['autoSync'] as bool? ?? false,
      );

  factory WebDAVConfig.nextcloud(
          String host, String username, String password) =>
      WebDAVConfig(
        serverUrl: 'https://$host/remote.php/dav/files/$username',
        username: username,
        password: password,
      );
}

/// Result of a sync operation.
class SyncResult {
  final bool success;
  final String? error;
  final PendingSync? pending;
  /// Non-fatal warnings collected during sync (e.g. individual image failures).
  final List<String> warnings;

  const SyncResult({
    required this.success,
    this.error,
    this.pending,
    this.warnings = const [],
  });

  bool get hasConflicts => pending != null;
}

/// Holds pending merge results that contain per-record conflicts.
class PendingSync {
  final DeviceMergeResult? deviceMerge;
  final NetworkMergeResult? networkMerge;
  final DataSetMergeResult? dataSetMerge;

  const PendingSync({this.deviceMerge, this.networkMerge, this.dataSetMerge});

  List<RecordConflict> get allConflicts => [
        ...?deviceMerge?.conflicts,
        ...?networkMerge?.conflicts,
        ...?dataSetMerge?.conflicts,
      ];
}

class WebDAVService {
  static const _configFileName = 'webdav_config.json';
  static const _syncBaseDirName = '.sync_base';
  static const _dataFileNames = [
    'device_data.json',
    'network_data.json',
    'dataset_data.json',
  ];

  /// Global lock to prevent concurrent syncs.
  static bool _syncing = false;

  /// Set to true when sync writes merged data to local files.
  static bool _localDataChanged = false;

  /// Whether the last sync wrote local data files (reset after read).
  static bool consumeLocalDataChanged() {
    final v = _localDataChanged;
    _localDataChanged = false;
    return v;
  }

  // ── Config persistence ──

  static Future<WebDAVConfig?> loadConfig() async {
    try {
      final dir = await DeviceStorage.getAppDir();
      final file = File('${dir.path}/$_configFileName');
      if (!await file.exists()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return WebDAVConfig.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveConfig(WebDAVConfig config) async {
    final dir = await DeviceStorage.getAppDir();
    final file = File('${dir.path}/$_configFileName');
    await file.writeAsString(jsonEncode(config.toJson()));
  }

  static Future<void> deleteConfig() async {
    final dir = await DeviceStorage.getAppDir();
    final file = File('${dir.path}/$_configFileName');
    if (await file.exists()) await file.delete();
  }

  // ── Base (last-synced) file management ──

  static Future<Directory> _getBaseDir() async {
    final appDir = await DeviceStorage.getAppDir();
    final dir = Directory('${appDir.path}/$_syncBaseDirName');
    if (!await dir.exists()) await dir.create();
    return dir;
  }

  static Future<String?> _readBase(String fileName) async {
    try {
      final dir = await _getBaseDir();
      final file = File('${dir.path}/$fileName');
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveBase(String fileName, String content) async {
    final dir = await _getBaseDir();
    final file = File('${dir.path}/$fileName');
    await _atomicWrite(file, content);
  }

  // ── Atomic file write ──

  /// Write content to a temp file then atomically rename over the target.
  /// Prevents data corruption if the app is killed during write.
  static Future<void> _atomicWrite(File file, String content) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content);
    await tmp.rename(file.path);
  }

  // ── HTTP helpers ──

  static Map<String, String> _authHeaders(WebDAVConfig config) {
    final creds =
        base64Encode(utf8.encode('${config.username}:${config.password}'));
    return {'Authorization': 'Basic $creds'};
  }

  static String _remoteFileUrl(WebDAVConfig config, String fileName) {
    final base = config.serverUrl.endsWith('/')
        ? config.serverUrl.substring(0, config.serverUrl.length - 1)
        : config.serverUrl;
    final path = config.remotePath.endsWith('/')
        ? config.remotePath
        : '${config.remotePath}/';
    return '$base$path$fileName';
  }

  static Future<bool> testConnection(WebDAVConfig config) async {
    try {
      final base = config.serverUrl.endsWith('/')
          ? config.serverUrl.substring(0, config.serverUrl.length - 1)
          : config.serverUrl;
      final url = Uri.parse('$base${config.remotePath}/');
      final request = http.Request('PROPFIND', url);
      request.headers.addAll(_authHeaders(config));
      request.headers['Depth'] = '0';
      request.headers['Content-Type'] = 'application/xml';
      request.body =
          '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>';

      final streamed = await http.Client()
          .send(request)
          .timeout(const Duration(seconds: 10));
      return streamed.statusCode == 207 || streamed.statusCode == 404;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _ensureRemoteDir(WebDAVConfig config) async {
    try {
      final base = config.serverUrl.endsWith('/')
          ? config.serverUrl.substring(0, config.serverUrl.length - 1)
          : config.serverUrl;
      final url = Uri.parse('$base${config.remotePath}/');
      final request = http.Request('MKCOL', url);
      request.headers.addAll(_authHeaders(config));
      await http.Client().send(request).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  static Future<bool> _upload(
      WebDAVConfig config, String fileName, String content) async {
    try {
      final url = Uri.parse(_remoteFileUrl(config, fileName));
      final response = await http
          .put(
            url,
            headers: {
              ..._authHeaders(config),
              'Content-Type': 'application/octet-stream',
            },
            body: utf8.encode(content),
          )
          .timeout(const Duration(seconds: 30));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _download(
      WebDAVConfig config, String fileName) async {
    try {
      final url = Uri.parse(_remoteFileUrl(config, fileName));
      final response = await http
          .get(url, headers: _authHeaders(config))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) return response.body;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Binary upload / download for images ──

  static Future<bool> _uploadBytes(
      WebDAVConfig config, String remotePath, Uint8List bytes) async {
    final url = Uri.parse(_remoteFileUrl(config, remotePath));
    final response = await http
        .put(
          url,
          headers: {
            ..._authHeaders(config),
            'Content-Type': 'application/octet-stream',
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 120));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return true;
  }

  static Future<Uint8List?> _downloadBytes(
      WebDAVConfig config, String remotePath) async {
    final url = Uri.parse(_remoteFileUrl(config, remotePath));
    final response = await http
        .get(url, headers: _authHeaders(config))
        .timeout(const Duration(seconds: 120));
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception('HTTP ${response.statusCode}');
  }

  static Future<void> _ensureRemoteSubDir(
      WebDAVConfig config, String subDir) async {
    try {
      final url = Uri.parse(_remoteFileUrl(config, '$subDir/'));
      final request = http.Request('MKCOL', url);
      request.headers.addAll(_authHeaders(config));
      await http.Client().send(request).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// List file names in a remote sub-directory via PROPFIND.
  static Future<Set<String>> _listRemoteFiles(
      WebDAVConfig config, String subDir) async {
    try {
      final url = Uri.parse(_remoteFileUrl(config, '$subDir/'));
      final request = http.Request('PROPFIND', url);
      request.headers.addAll(_authHeaders(config));
      request.headers['Depth'] = '1';
      request.headers['Content-Type'] = 'application/xml';
      request.body =
          '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>';

      final streamed = await http.Client()
          .send(request)
          .timeout(const Duration(seconds: 15));
      if (streamed.statusCode != 207) return {};

      final body = await streamed.stream.bytesToString();
      // Parse <d:href> entries; skip the directory itself
      final hrefPattern = RegExp(r'<(?:\w+:)?href>([^<]+)</(?:\w+:)?href>', caseSensitive: false);
      final names = <String>{};
      for (final m in hrefPattern.allMatches(body)) {
        final href = Uri.decodeFull(m.group(1)!);
        if (href.endsWith('/')) continue; // skip directories
        final name = href.split('/').last;
        if (name.isNotEmpty) names.add(name);
      }
      return names;
    } catch (_) {
      return {};
    }
  }

  /// Extract basenames of device images referenced in [json].
  static Set<String> _getReferencedImageNames(String? json) {
    if (json == null) return {};
    try {
      final data = DeviceData.fromJson(
          jsonDecode(json) as Map<String, dynamic>);
      return data.devices
          .map((d) => d.imagePath)
          .whereType<String>()
          .map((path) => p.basename(path))
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// Sync only images referenced by actual device records.
  ///
  /// [referencedImages] is the union of basenames from local + remote device
  /// data, so images from both sides are covered without syncing orphans.
  ///
  /// Returns a list of non-fatal error strings for individual transfer failures.
  static Future<List<String>> _syncImages(
      WebDAVConfig config,
      Directory appDir,
      Set<String> referencedImages) async {
    final errors = <String>[];
    if (referencedImages.isEmpty) return errors;

    final imgDir = Directory(p.join(appDir.path, 'images'));
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }

    await _ensureRemoteSubDir(config, 'images');

    // Collect local referenced images (skip orphans)
    final localNames = <String>{};
    await for (final entity in imgDir.list()) {
      if (entity is File) {
        final name = p.basename(entity.path);
        if (referencedImages.contains(name)) localNames.add(name);
      }
    }

    // List all remote file names to avoid re-uploading existing files
    final remoteNames = await _listRemoteFiles(config, 'images');

    // Upload local referenced images missing on remote
    for (final name in localNames) {
      if (!remoteNames.contains(name)) {
        try {
          final bytes = await File(p.join(imgDir.path, name)).readAsBytes();
          await _uploadBytes(config, 'images/$name', bytes);
        } on TimeoutException {
          errors.add('Upload timed out: $name');
        } catch (e) {
          errors.add('Upload failed for $name: $e');
        }
      }
    }

    // Download referenced remote images missing locally
    for (final name in referencedImages) {
      if (!localNames.contains(name) && remoteNames.contains(name)) {
        try {
          final bytes = await _downloadBytes(config, 'images/$name');
          if (bytes != null) {
            await File(p.join(imgDir.path, name)).writeAsBytes(bytes);
          }
        } on TimeoutException {
          errors.add('Download timed out: $name');
        } catch (e) {
          errors.add('Download failed for $name: $e');
        }
      }
    }

    return errors;
  }

  // ── Per-record merge sync ──

  /// Sync data files with the remote server using per-record three-way merge.
  ///
  /// When [autoResolve] is true, conflicts are resolved automatically using
  /// last-writer-wins per record. Used by auto-sync to prevent blocking.
  static Future<SyncResult> sync(WebDAVConfig config,
      {bool autoResolve = false}) async {
    if (_syncing) {
      return const SyncResult(
          success: false, error: 'Sync already in progress');
    }
    _syncing = true;
    try {
      await _ensureRemoteDir(config);
      final appDir = await DeviceStorage.getAppDir();

      DeviceMergeResult? pendingDevice;
      NetworkMergeResult? pendingNetwork;
      DataSetMergeResult? pendingDataSet;
      final perFileErrors = <String>[];

      // Track device JSON from both sides for image reference computation.
      String? localDeviceJson;
      String? remoteDeviceJson;

      for (final name in _dataFileNames) {
        final localFile = File('${appDir.path}/$name');
        final localExists = await localFile.exists();
        final remoteRaw = await _download(config, name);

        if (!localExists && remoteRaw == null) continue;

        if (!localExists && remoteRaw != null) {
          await _atomicWrite(localFile, remoteRaw);
          await _saveBase(name, remoteRaw);
          _localDataChanged = true;
          if (name == 'device_data.json') remoteDeviceJson = remoteRaw;
          continue;
        }

        final localRaw = await localFile.readAsString();
        if (name == 'device_data.json') localDeviceJson = localRaw;

        if (localExists && remoteRaw == null) {
          final uploaded = await _upload(config, name, localRaw);
          if (uploaded) await _saveBase(name, localRaw);
          continue;
        }

        if (name == 'device_data.json') remoteDeviceJson = remoteRaw;

        if (localRaw == remoteRaw) {
          await _saveBase(name, localRaw);
          continue;
        }

        final baseJson = await _readBase(name);

        // Per-file try-catch: if one file fails to merge, others still sync.
        try {
          switch (name) {
            case 'device_data.json':
              var result = mergeDeviceData(
                localRaw, remoteRaw!, baseJson,
                autoResolve: autoResolve,
              );
              if (!result.hasConflicts) {
                // Re-read local to detect concurrent saves during network I/O
                final freshLocalRaw = await localFile.readAsString();
                if (freshLocalRaw != localRaw) {
                  result = mergeDeviceData(
                    freshLocalRaw, remoteRaw, baseJson,
                    autoResolve: autoResolve,
                  );
                }
              }
              if (result.hasConflicts) {
                pendingDevice = result;
              } else {
                final mergedData = DeviceData(devices: result.merged);
                final mergedJson =
                    const JsonEncoder.withIndent('  ').convert(mergedData.toJson());
                await _atomicWrite(localFile, mergedJson);
                final uploaded = await _upload(config, name, mergedJson);
                if (uploaded) await _saveBase(name, mergedJson);
                // Use merged result for image reference computation.
                localDeviceJson = mergedJson;
                _localDataChanged = true;
              }
            case 'network_data.json':
              var result = mergeNetworkData(
                localRaw, remoteRaw!, baseJson,
                autoResolve: autoResolve,
              );
              if (!result.hasConflicts) {
                final freshLocalRaw = await localFile.readAsString();
                if (freshLocalRaw != localRaw) {
                  result = mergeNetworkData(
                    freshLocalRaw, remoteRaw, baseJson,
                    autoResolve: autoResolve,
                  );
                }
              }
              if (result.hasConflicts) {
                pendingNetwork = result;
              } else {
                final mergedData = NetworkData(
                  networks: result.mergedNetworks,
                  assignments: result.mergedAssignments,
                );
                final mergedJson =
                    const JsonEncoder.withIndent('  ').convert(mergedData.toJson());
                await _atomicWrite(localFile, mergedJson);
                final uploaded = await _upload(config, name, mergedJson);
                if (uploaded) await _saveBase(name, mergedJson);
                _localDataChanged = true;
              }
            case 'dataset_data.json':
              var result = mergeDataSetData(
                localRaw, remoteRaw!, baseJson,
                autoResolve: autoResolve,
              );
              if (!result.hasConflicts) {
                final freshLocalRaw = await localFile.readAsString();
                if (freshLocalRaw != localRaw) {
                  result = mergeDataSetData(
                    freshLocalRaw, remoteRaw, baseJson,
                    autoResolve: autoResolve,
                  );
                }
              }
              if (result.hasConflicts) {
                pendingDataSet = result;
              } else {
                final mergedData = DataSetData(datasets: result.merged);
                final mergedJson =
                    const JsonEncoder.withIndent('  ').convert(mergedData.toJson());
                await _atomicWrite(localFile, mergedJson);
                final uploaded = await _upload(config, name, mergedJson);
                if (uploaded) await _saveBase(name, mergedJson);
                _localDataChanged = true;
              }
          }
        } catch (e) {
          // Per-file merge error: skip this file, continue syncing others.
          perFileErrors.add('$name: $e');
        }
      }

      // Sync only images referenced by actual device records (local ∪ remote),
      // skipping orphaned images to avoid transferring stale/unused data.
      final referencedImages = {
        ..._getReferencedImageNames(localDeviceJson),
        ..._getReferencedImageNames(remoteDeviceJson),
      };
      final imageErrors = await _syncImages(config, appDir, referencedImages);

      final allErrors = [...perFileErrors];
      final hasConflicts =
          pendingDevice != null ||
          pendingNetwork != null ||
          pendingDataSet != null;

      if (hasConflicts) {
        return SyncResult(
          success: allErrors.isEmpty,
          error: allErrors.isNotEmpty ? allErrors.join('; ') : null,
          pending: PendingSync(
            deviceMerge: pendingDevice,
            networkMerge: pendingNetwork,
            dataSetMerge: pendingDataSet,
          ),
          warnings: imageErrors,
        );
      }

      return SyncResult(
        success: allErrors.isEmpty,
        error: allErrors.isNotEmpty ? allErrors.join('; ') : null,
        warnings: imageErrors,
      );
    } catch (e, st) {
      return SyncResult(success: false, error: '$e\n$st');
    } finally {
      _syncing = false;
    }
  }

  /// Finalize sync by applying user's conflict resolutions.
  static Future<bool> finalizePendingSync(
    WebDAVConfig config,
    PendingSync pending,
    Map<String, dynamic> resolutions,
  ) async {
    try {
      final appDir = await DeviceStorage.getAppDir();

      if (pending.deviceMerge != null) {
        final deviceResolutions = <String, Device>{};
        for (final c in pending.deviceMerge!.conflicts) {
          final chosen = resolutions[c.id];
          if (chosen is Device) deviceResolutions[c.id] = chosen;
        }
        final mergedData = pending.deviceMerge!.buildResolved(deviceResolutions);
        final mergedJson =
            const JsonEncoder.withIndent('  ').convert(mergedData.toJson());
        await _atomicWrite(File('${appDir.path}/device_data.json'), mergedJson);
        final uploaded = await _upload(config, 'device_data.json', mergedJson);
        if (uploaded) await _saveBase('device_data.json', mergedJson);
      }

      if (pending.networkMerge != null) {
        final networkResolutions = <String, Network>{};
        for (final c in pending.networkMerge!.conflicts) {
          final chosen = resolutions[c.id];
          if (chosen is Network) networkResolutions[c.id] = chosen;
        }
        final mergedData =
            pending.networkMerge!.buildResolved(networkResolutions);
        final mergedJson =
            const JsonEncoder.withIndent('  ').convert(mergedData.toJson());
        await _atomicWrite(File('${appDir.path}/network_data.json'), mergedJson);
        final uploaded = await _upload(config, 'network_data.json', mergedJson);
        if (uploaded) await _saveBase('network_data.json', mergedJson);
      }

      if (pending.dataSetMerge != null) {
        final dataSetResolutions = <String, DataSet>{};
        for (final c in pending.dataSetMerge!.conflicts) {
          final chosen = resolutions[c.id];
          if (chosen is DataSet) dataSetResolutions[c.id] = chosen;
        }
        final mergedData =
            pending.dataSetMerge!.buildResolved(dataSetResolutions);
        final mergedJson =
            const JsonEncoder.withIndent('  ').convert(mergedData.toJson());
        await _atomicWrite(File('${appDir.path}/dataset_data.json'), mergedJson);
        final uploaded = await _upload(config, 'dataset_data.json', mergedJson);
        if (uploaded) await _saveBase('dataset_data.json', mergedJson);
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
