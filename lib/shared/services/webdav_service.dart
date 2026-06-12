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
import '../../features/services/models/service.dart';
import 'sync_merge.dart';

/// Persisted WebDAV configuration.
class WebDAVConfig {
  final String serverUrl;
  final String username;
  final String password;
  final String remotePath;
  final bool autoSync;

  /// Purpose: Create a web davconfig instance.
  /// Inputs: `remotePath`.
  /// Returns: A new `WebDAVConfig` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  const WebDAVConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.remotePath = '/MyDevice',
    this.autoSync = false,
  });

  /// Purpose: Return whether configured is true.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isConfigured =>
      serverUrl.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  /// Purpose: Create a copy with selected fields replaced.
  /// Inputs: None.
  /// Returns: `WebDAVConfig`.
  /// Side effects: None.
  /// Notes: None.
  WebDAVConfig copyWith({bool? autoSync}) => WebDAVConfig(
    serverUrl: serverUrl,
    username: username,
    password: password,
    remotePath: remotePath,
    autoSync: autoSync ?? this.autoSync,
  );

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Keep the output aligned with the persisted file and sync format.
  Map<String, dynamic> toJson() => {
    'serverUrl': serverUrl,
    'username': username,
    'password': password,
    'remotePath': remotePath,
    'autoSync': autoSync,
  };

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A new `WebDAVConfig.fromJson` instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  factory WebDAVConfig.fromJson(Map<String, dynamic> json) => WebDAVConfig(
    serverUrl: json['serverUrl'] as String? ?? '',
    username: json['username'] as String? ?? '',
    password: json['password'] as String? ?? '',
    remotePath: json['remotePath'] as String? ?? '/MyDevice',
    autoSync: json['autoSync'] as bool? ?? false,
  );

  /// Purpose: Create a nextcloud instance.
  /// Inputs: `host`, `username`, `password`.
  /// Returns: A new `WebDAVConfig.nextcloud` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  factory WebDAVConfig.nextcloud(
    String host,
    String username,
    String password,
  ) => WebDAVConfig(
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

  /// Purpose: Create a sync result instance.
  /// Inputs: `warnings`.
  /// Returns: A new `SyncResult` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
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
  final DeviceMergeResult? deviceMerge;
  final NetworkMergeResult? networkMerge;
  final DataSetMergeResult? dataSetMerge;
  final ServiceMergeResult? serviceMerge;

  /// Purpose: Create a pending sync instance.
  /// Inputs: None.
  /// Returns: A new `PendingSync` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  const PendingSync({
    this.deviceMerge,
    this.networkMerge,
    this.dataSetMerge,
    this.serviceMerge,
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

/// Outcome status of a remote file download attempt.
enum RemoteFileStatus { found, notFound, error }

/// Discriminated result of a remote file download.
///
/// Distinguishes "the file does not exist on the remote" (HTTP 404) from
/// transport/server failures, because only a true 404 may trigger the
/// upload-local-as-new sync path. Treating errors as "missing" can overwrite
/// remote data and cascade into cross-device record deletion.
class RemoteFile {
  final RemoteFileStatus status;
  final String? content;
  final String? etag;
  final String? error;

  /// Purpose: Create a found result with downloaded content.
  /// Inputs: `content`, optional `etag` response header value.
  /// Returns: A new `RemoteFile` instance with `RemoteFileStatus.found`.
  /// Side effects: None.
  /// Notes: None.
  const RemoteFile.found(String this.content, {this.etag})
    : status = RemoteFileStatus.found,
      error = null;

  /// Purpose: Create a not-found result for HTTP 404.
  /// Inputs: None.
  /// Returns: A new `RemoteFile` instance with `RemoteFileStatus.notFound`.
  /// Side effects: None.
  /// Notes: None.
  const RemoteFile.notFound()
    : status = RemoteFileStatus.notFound,
      content = null,
      etag = null,
      error = null;

  /// Purpose: Create an error result for any non-404 failure.
  /// Inputs: `error` message.
  /// Returns: A new `RemoteFile` instance with `RemoteFileStatus.error`.
  /// Side effects: None.
  /// Notes: None.
  const RemoteFile.failure(String this.error)
    : status = RemoteFileStatus.error,
      content = null,
      etag = null;
}

class WebDAVService {
  static const _configFileName = 'webdav_config.json';
  static const _syncBaseDirName = '.sync_base';
  static const _dataFileNames = [
    'device_data.json',
    'network_data.json',
    'dataset_data.json',
    'service_data.json',
  ];

  /// Global lock to prevent concurrent syncs.
  static bool _syncing = false;

  /// Set to true when sync writes merged data to local files.
  static bool _localDataChanged = false;

  /// Purpose: Implement the consume local data changed behavior for this file.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  /// Whether the last sync wrote local data files (reset after read).
  static bool consumeLocalDataChanged() {
    final v = _localDataChanged;
    _localDataChanged = false;
    return v;
  }

  // ── Config persistence ──

  /// Purpose: Load config into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<WebDAVConfig?>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
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

  /// Purpose: Save config to the relevant storage or service layer.
  /// Inputs: `config`.
  /// Returns: `Future<void>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  static Future<void> saveConfig(WebDAVConfig config) async {
    final dir = await DeviceStorage.getAppDir();
    final file = File('${dir.path}/$_configFileName');
    await file.writeAsString(jsonEncode(config.toJson()));
  }

  /// Purpose: Delete config from the relevant storage or state.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  static Future<void> deleteConfig() async {
    final dir = await DeviceStorage.getAppDir();
    final file = File('${dir.path}/$_configFileName');
    if (await file.exists()) await file.delete();
  }

  // ── Base (last-synced) file management ──

  /// Purpose: Provide the internal get base dir helper for this file.
  /// Inputs: None.
  /// Returns: `Future<Directory>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
  static Future<Directory> _getBaseDir() async {
    final appDir = await DeviceStorage.getAppDir();
    final dir = Directory('${appDir.path}/$_syncBaseDirName');
    if (!await dir.exists()) await dir.create();
    return dir;
  }

  /// Purpose: Provide the internal read base helper for this file.
  /// Inputs: `fileName`.
  /// Returns: `Future<String?>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Save base to the relevant storage or service layer.
  /// Inputs: `fileName`, `content`.
  /// Returns: `Future<void>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
  static Future<void> _saveBase(String fileName, String content) async {
    final dir = await _getBaseDir();
    final file = File('${dir.path}/$fileName');
    await _atomicWrite(file, content);
  }

  // ── Atomic file write ──

  /// Purpose: Provide the internal atomic write helper for this file.
  /// Inputs: `file`, `content`.
  /// Returns: `Future<void>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
  /// Write content to a temp file then atomically rename over the target.
  /// Prevents data corruption if the app is killed during write.
  static Future<void> _atomicWrite(File file, String content) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content);
    await tmp.rename(file.path);
  }

  // ── HTTP helpers ──

  /// Purpose: Provide the internal auth headers helper for this file.
  /// Inputs: `config`.
  /// Returns: `Map<String, String>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Map<String, String> _authHeaders(WebDAVConfig config) {
    final creds = base64Encode(
      utf8.encode('${config.username}:${config.password}'),
    );
    return {'Authorization': 'Basic $creds'};
  }

  /// Purpose: Provide the internal remote file url helper for this file.
  /// Inputs: `config`, `fileName`.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static String _remoteFileUrl(WebDAVConfig config, String fileName) {
    final base = config.serverUrl.endsWith('/')
        ? config.serverUrl.substring(0, config.serverUrl.length - 1)
        : config.serverUrl;
    final path = config.remotePath.endsWith('/')
        ? config.remotePath
        : '${config.remotePath}/';
    return '$base$path$fileName';
  }

  /// Purpose: Test connection and report the outcome.
  /// Inputs: `config`.
  /// Returns: `Future<bool>`.
  /// Side effects: May perform network I/O.
  /// Notes: None.
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

  /// Purpose: Provide the internal ensure remote dir helper for this file.
  /// Inputs: `config`.
  /// Returns: `Future<void>`.
  /// Side effects: May perform network I/O.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal upload helper for this file.
  /// Inputs: `config`, `fileName`, `content`, optional `ifMatchEtag`, optional `ifNoneMatchAll`.
  /// Returns: `Future<String?>` — `null` on success, otherwise an error message.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only. When `ifMatchEtag` is set the PUT
  /// carries an `If-Match` precondition; `ifNoneMatchAll` sends `If-None-Match: *` so a
  /// first upload cannot overwrite a file created concurrently by another device.
  /// HTTP 412 means the remote changed during sync and the caller must re-sync.
  static Future<String?> _upload(
    WebDAVConfig config,
    String fileName,
    String content, {
    String? ifMatchEtag,
    bool ifNoneMatchAll = false,
  }) async {
    try {
      final url = Uri.parse(_remoteFileUrl(config, fileName));
      final response = await http
          .put(
            url,
            headers: {
              ..._authHeaders(config),
              'Content-Type': 'application/octet-stream',
              'If-Match': ?ifMatchEtag,
              if (ifNoneMatchAll) 'If-None-Match': '*',
            },
            body: utf8.encode(content),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 412) {
        return 'remote file changed during sync (HTTP 412); run sync again';
      }
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      return 'HTTP ${response.statusCode}';
    } catch (e) {
      return '$e';
    }
  }

  /// Purpose: Return [etag] only when it is a strong ETag usable in `If-Match`.
  /// Inputs: `etag` from a download response, possibly null or weak (`W/...`).
  /// Returns: `String?` — the strong ETag, or null when absent/weak.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Weak ETags must not be
  /// used in `If-Match` preconditions (RFC 9110 strong comparison).
  static String? _strongEtag(String? etag) {
    if (etag == null || etag.startsWith('W/')) return null;
    return etag;
  }

  /// Purpose: Download a remote data file with a discriminated outcome.
  /// Inputs: `config`, `fileName`.
  /// Returns: `Future<RemoteFile>` — found with content/ETag, notFound for HTTP 404,
  /// or error for any other failure.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only. Callers must treat only
  /// `notFound` as "file missing on remote"; an `error` outcome (auth/server/network
  /// failure) must abort that file's sync so local data is never uploaded over an
  /// unreadable remote file.
  static Future<RemoteFile> _download(
    WebDAVConfig config,
    String fileName,
  ) async {
    try {
      final url = Uri.parse(_remoteFileUrl(config, fileName));
      final response = await http
          .get(url, headers: _authHeaders(config))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return RemoteFile.found(response.body, etag: response.headers['etag']);
      }
      if (response.statusCode == 404) return const RemoteFile.notFound();
      return RemoteFile.failure('HTTP ${response.statusCode}');
    } catch (e) {
      return RemoteFile.failure('$e');
    }
  }

  // ── Binary upload / download for images ──

  /// Purpose: Provide the internal upload bytes helper for this file.
  /// Inputs: `config`, `remotePath`, `bytes`.
  /// Returns: `Future<bool>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Future<bool> _uploadBytes(
    WebDAVConfig config,
    String remotePath,
    Uint8List bytes,
  ) async {
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

  /// Purpose: Provide the internal download bytes helper for this file.
  /// Inputs: `config`, `remotePath`.
  /// Returns: `Future<Uint8List?>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Future<Uint8List?> _downloadBytes(
    WebDAVConfig config,
    String remotePath,
  ) async {
    final url = Uri.parse(_remoteFileUrl(config, remotePath));
    final response = await http
        .get(url, headers: _authHeaders(config))
        .timeout(const Duration(seconds: 120));
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception('HTTP ${response.statusCode}');
  }

  /// Purpose: Provide the internal ensure remote sub dir helper for this file.
  /// Inputs: `config`, `subDir`.
  /// Returns: `Future<void>`.
  /// Side effects: May perform network I/O.
  /// Notes: Internal helper used within this file only.
  static Future<void> _ensureRemoteSubDir(
    WebDAVConfig config,
    String subDir,
  ) async {
    try {
      final url = Uri.parse(_remoteFileUrl(config, '$subDir/'));
      final request = http.Request('MKCOL', url);
      request.headers.addAll(_authHeaders(config));
      await http.Client().send(request).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// Purpose: Collect and return remote files.
  /// Inputs: `config`, `subDir`.
  /// Returns: `Future<Set<String>>`.
  /// Side effects: May perform network I/O.
  /// Notes: Internal helper used within this file only.
  /// List file names in a remote sub-directory via PROPFIND.
  static Future<Set<String>> _listRemoteFiles(
    WebDAVConfig config,
    String subDir,
  ) async {
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
      final hrefPattern = RegExp(
        r'<(?:\w+:)?href>([^<]+)</(?:\w+:)?href>',
        caseSensitive: false,
      );
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

  /// Purpose: Provide the internal get referenced image names helper for this file.
  /// Inputs: `json`.
  /// Returns: `Set<String>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  /// Extract basenames of device images referenced in [json].
  static Set<String> _getReferencedImageNames(String? json) {
    if (json == null) return {};
    try {
      final data = DeviceData.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      return data.devices
          .map((d) => d.imagePath)
          .whereType<String>()
          .map((path) => p.basename(path))
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// Purpose: Sync images with the relevant peer or storage.
  /// Inputs: `config`, `appDir`, `referencedImages`.
  /// Returns: `Future<List<String>>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
  /// Sync only images referenced by actual device records.
  ///
  /// [referencedImages] is the union of basenames from local + remote device
  /// data, so images from both sides are covered without syncing orphans.
  ///
  /// Returns a list of non-fatal error strings for individual transfer failures.
  static Future<List<String>> _syncImages(
    WebDAVConfig config,
    Directory appDir,
    Set<String> referencedImages,
  ) async {
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

  /// Purpose: Sync the relevant data with the relevant peer or storage.
  /// Inputs: `config`.
  /// Returns: `Future<SyncResult>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  /// Sync data files with the remote server using per-record three-way merge.
  ///
  /// When [autoResolve] is true, conflicts are resolved automatically using
  /// last-writer-wins per record. Used by auto-sync to prevent blocking.
  static Future<SyncResult> sync(
    WebDAVConfig config, {
    bool autoResolve = false,
  }) async {
    if (_syncing) {
      return const SyncResult(
        success: false,
        error: 'Sync already in progress',
      );
    }
    _syncing = true;
    try {
      await _ensureRemoteDir(config);
      final appDir = await DeviceStorage.getAppDir();

      DeviceMergeResult? pendingDevice;
      NetworkMergeResult? pendingNetwork;
      DataSetMergeResult? pendingDataSet;
      ServiceMergeResult? pendingService;
      final perFileErrors = <String>[];

      // Track device JSON from both sides for image reference computation.
      String? localDeviceJson;
      String? remoteDeviceJson;

      for (final name in _dataFileNames) {
        final localFile = File('${appDir.path}/$name');
        final localExists = await localFile.exists();
        final remote = await _download(config, name);

        // Any non-404 download failure aborts this file's sync; treating it
        // as "missing on remote" would overwrite remote data and can cascade
        // into cross-device record deletion on the next merge.
        if (remote.status == RemoteFileStatus.error) {
          perFileErrors.add('$name: download failed: ${remote.error}');
          continue;
        }
        final remoteRaw = remote.content;
        final remoteEtag = _strongEtag(remote.etag);

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
          // Only on local → upload as new; If-None-Match: * prevents
          // overwriting a file another device created concurrently.
          final uploadError = await _upload(
            config,
            name,
            localRaw,
            ifNoneMatchAll: true,
          );
          if (uploadError == null) {
            await _saveBase(name, localRaw);
          } else {
            perFileErrors.add('$name: upload failed: $uploadError');
          }
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
                localRaw,
                remoteRaw!,
                baseJson,
                autoResolve: autoResolve,
              );
              if (!result.hasConflicts) {
                // Re-read local to detect concurrent saves during network I/O
                final freshLocalRaw = await localFile.readAsString();
                if (freshLocalRaw != localRaw) {
                  result = mergeDeviceData(
                    freshLocalRaw,
                    remoteRaw,
                    baseJson,
                    autoResolve: autoResolve,
                  );
                }
              }
              if (result.hasConflicts) {
                pendingDevice = result;
              } else {
                final mergedData = DeviceData(
                  devices: result.merged,
                  extraJson: result.extraJson,
                );
                final mergedJson = const JsonEncoder.withIndent(
                  '  ',
                ).convert(mergedData.toJson());
                await _atomicWrite(localFile, mergedJson);
                _localDataChanged = true;
                final uploadError = await _upload(
                  config,
                  name,
                  mergedJson,
                  ifMatchEtag: remoteEtag,
                );
                if (uploadError == null) {
                  await _saveBase(name, mergedJson);
                } else {
                  perFileErrors.add('$name: upload failed: $uploadError');
                }
                // Use merged result for image reference computation.
                localDeviceJson = mergedJson;
              }
            case 'network_data.json':
              var result = mergeNetworkData(
                localRaw,
                remoteRaw!,
                baseJson,
                autoResolve: autoResolve,
              );
              if (!result.hasConflicts) {
                final freshLocalRaw = await localFile.readAsString();
                if (freshLocalRaw != localRaw) {
                  result = mergeNetworkData(
                    freshLocalRaw,
                    remoteRaw,
                    baseJson,
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
                  extraJson: result.extraJson,
                );
                final mergedJson = const JsonEncoder.withIndent(
                  '  ',
                ).convert(mergedData.toJson());
                await _atomicWrite(localFile, mergedJson);
                _localDataChanged = true;
                final uploadError = await _upload(
                  config,
                  name,
                  mergedJson,
                  ifMatchEtag: remoteEtag,
                );
                if (uploadError == null) {
                  await _saveBase(name, mergedJson);
                } else {
                  perFileErrors.add('$name: upload failed: $uploadError');
                }
              }
            case 'dataset_data.json':
              var result = mergeDataSetData(
                localRaw,
                remoteRaw!,
                baseJson,
                autoResolve: autoResolve,
              );
              if (!result.hasConflicts) {
                final freshLocalRaw = await localFile.readAsString();
                if (freshLocalRaw != localRaw) {
                  result = mergeDataSetData(
                    freshLocalRaw,
                    remoteRaw,
                    baseJson,
                    autoResolve: autoResolve,
                  );
                }
              }
              if (result.hasConflicts) {
                pendingDataSet = result;
              } else {
                final mergedData = DataSetData(
                  datasets: result.merged,
                  extraJson: result.extraJson,
                );
                final mergedJson = const JsonEncoder.withIndent(
                  '  ',
                ).convert(mergedData.toJson());
                await _atomicWrite(localFile, mergedJson);
                _localDataChanged = true;
                final uploadError = await _upload(
                  config,
                  name,
                  mergedJson,
                  ifMatchEtag: remoteEtag,
                );
                if (uploadError == null) {
                  await _saveBase(name, mergedJson);
                } else {
                  perFileErrors.add('$name: upload failed: $uploadError');
                }
              }
            case 'service_data.json':
              var result = mergeServiceData(
                localRaw,
                remoteRaw!,
                baseJson,
                autoResolve: autoResolve,
              );
              if (!result.hasConflicts) {
                final freshLocalRaw = await localFile.readAsString();
                if (freshLocalRaw != localRaw) {
                  result = mergeServiceData(
                    freshLocalRaw,
                    remoteRaw,
                    baseJson,
                    autoResolve: autoResolve,
                  );
                }
              }
              if (result.hasConflicts) {
                pendingService = result;
              } else {
                final mergedData = ServiceData(
                  services: result.mergedServices,
                  routes: result.mergedRoutes,
                  extraJson: result.extraJson,
                );
                final mergedJson = const JsonEncoder.withIndent(
                  '  ',
                ).convert(mergedData.toJson());
                await _atomicWrite(localFile, mergedJson);
                _localDataChanged = true;
                final uploadError = await _upload(
                  config,
                  name,
                  mergedJson,
                  ifMatchEtag: remoteEtag,
                );
                if (uploadError == null) {
                  await _saveBase(name, mergedJson);
                } else {
                  perFileErrors.add('$name: upload failed: $uploadError');
                }
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
          pendingDataSet != null ||
          pendingService != null;

      if (hasConflicts) {
        return SyncResult(
          success: allErrors.isEmpty,
          error: allErrors.isNotEmpty ? allErrors.join('; ') : null,
          pending: PendingSync(
            deviceMerge: pendingDevice,
            networkMerge: pendingNetwork,
            dataSetMerge: pendingDataSet,
            serviceMerge: pendingService,
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

  /// Purpose: Write a resolved data file locally, upload it, and save the base.
  /// Inputs: `config`, `fileName`, `mergedJson` (serialized resolved data).
  /// Returns: `Future<bool>` — false when the remote read or upload fails.
  /// Side effects: Downloads the current remote file for an If-Match precondition,
  /// writes the local file, uploads, saves the base snapshot.
  /// Notes: Internal helper used within this file only. A remote download error
  /// aborts the file so resolutions are never uploaded over an unreadable remote;
  /// an upload failure (including HTTP 412 when the remote changed since download)
  /// leaves the base snapshot untouched so the next sync re-merges.
  static Future<bool> _finalizeFile(
    WebDAVConfig config,
    String fileName,
    String mergedJson,
  ) async {
    final appDir = await DeviceStorage.getAppDir();
    final remote = await _download(config, fileName);
    if (remote.status == RemoteFileStatus.error) return false;
    await _atomicWrite(File('${appDir.path}/$fileName'), mergedJson);
    _localDataChanged = true;
    final uploadError = await _upload(
      config,
      fileName,
      mergedJson,
      ifMatchEtag: _strongEtag(remote.etag),
      ifNoneMatchAll: remote.status == RemoteFileStatus.notFound,
    );
    if (uploadError != null) return false;
    await _saveBase(fileName, mergedJson);
    return true;
  }

  /// Purpose: Implement the finalize pending sync behavior for this file.
  /// Inputs: `config`, `pending`, `resolutions`.
  /// Returns: `Future<bool>` — false when any file's remote read or upload fails.
  /// Side effects: Performs local file-system and network I/O.
  /// Notes: Finalize sync by applying user's conflict resolutions. Failed files
  /// keep their base snapshots untouched so the next sync re-merges them.
  static Future<bool> finalizePendingSync(
    WebDAVConfig config,
    PendingSync pending,
    Map<String, dynamic> resolutions,
  ) async {
    try {
      var allOk = true;

      if (pending.deviceMerge != null) {
        final deviceResolutions = <String, Device>{};
        for (final c in pending.deviceMerge!.conflicts) {
          final chosen = resolutions[c.id];
          if (chosen is Device) deviceResolutions[c.id] = chosen;
        }
        final mergedData = pending.deviceMerge!.buildResolved(
          deviceResolutions,
        );
        final mergedJson = const JsonEncoder.withIndent(
          '  ',
        ).convert(mergedData.toJson());
        final ok = await _finalizeFile(config, 'device_data.json', mergedJson);
        allOk = allOk && ok;
      }

      if (pending.networkMerge != null) {
        final networkResolutions = <String, Network>{};
        for (final c in pending.networkMerge!.conflicts) {
          final chosen = resolutions[c.id];
          if (chosen is Network) networkResolutions[c.id] = chosen;
        }
        final mergedData = pending.networkMerge!.buildResolved(
          networkResolutions,
        );
        final mergedJson = const JsonEncoder.withIndent(
          '  ',
        ).convert(mergedData.toJson());
        final ok = await _finalizeFile(config, 'network_data.json', mergedJson);
        allOk = allOk && ok;
      }

      if (pending.dataSetMerge != null) {
        final dataSetResolutions = <String, DataSet>{};
        for (final c in pending.dataSetMerge!.conflicts) {
          final chosen = resolutions[c.id];
          if (chosen is DataSet) dataSetResolutions[c.id] = chosen;
        }
        final mergedData = pending.dataSetMerge!.buildResolved(
          dataSetResolutions,
        );
        final mergedJson = const JsonEncoder.withIndent(
          '  ',
        ).convert(mergedData.toJson());
        final ok = await _finalizeFile(config, 'dataset_data.json', mergedJson);
        allOk = allOk && ok;
      }

      if (pending.serviceMerge != null) {
        final mergedData = pending.serviceMerge!.buildResolved(resolutions);
        final mergedJson = const JsonEncoder.withIndent(
          '  ',
        ).convert(mergedData.toJson());
        final ok = await _finalizeFile(config, 'service_data.json', mergedJson);
        allOk = allOk && ok;
      }

      return allOk;
    } catch (_) {
      return false;
    }
  }
}
