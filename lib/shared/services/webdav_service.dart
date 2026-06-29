import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

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

/// A WebDAV upload lock stored in the remote `.lock` file.
class WebDAVUploadLock {
  final String clientId;
  final String token;
  final DateTime startedAt;
  final DateTime updatedAt;
  final int ttlSeconds;

  /// Purpose: Create a WebDAV upload lock value.
  /// Inputs: `clientId`, `token`, `startedAt`, `updatedAt`, `ttlSeconds`.
  /// Returns: A new `WebDAVUploadLock` instance.
  /// Side effects: None.
  /// Notes: Times are stored in UTC and compared against [ttlSeconds].
  const WebDAVUploadLock({
    required this.clientId,
    required this.token,
    required this.startedAt,
    required this.updatedAt,
    required this.ttlSeconds,
  });

  /// Purpose: Parse a WebDAV upload lock from JSON.
  /// Inputs: `json`.
  /// Returns: A parsed `WebDAVUploadLock`.
  /// Side effects: None.
  /// Notes: Throws when required fields are missing or malformed.
  factory WebDAVUploadLock.fromJson(Map<String, dynamic> json) {
    return WebDAVUploadLock(
      clientId: json['clientId'] as String,
      token: json['token'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      ttlSeconds: json['ttlSeconds'] as int? ?? 150,
    );
  }

  /// Purpose: Serialize this lock to the remote `.lock` JSON format.
  /// Inputs: None.
  /// Returns: JSON-compatible map.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    'token': token,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'ttlSeconds': ttlSeconds,
  };

  /// Purpose: Return whether this lock is expired at [now].
  /// Inputs: `now`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Expired locks are treated as failed uploads and may be replaced.
  bool isExpired(DateTime now) =>
      now.toUtc().difference(updatedAt.toUtc()).inSeconds >= ttlSeconds;

  /// Purpose: Return whether this lock belongs to the given session.
  /// Inputs: `clientId`, `token`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Used before refreshing or deleting remote locks.
  bool matches(String clientId, String token) =>
      this.clientId == clientId && this.token == token;

  /// Purpose: Create a refreshed copy of this lock.
  /// Inputs: `updatedAt`.
  /// Returns: `WebDAVUploadLock`.
  /// Side effects: None.
  /// Notes: Keeps the original token and started time.
  WebDAVUploadLock refreshed(DateTime updatedAt) => WebDAVUploadLock(
    clientId: clientId,
    token: token,
    startedAt: startedAt,
    updatedAt: updatedAt.toUtc(),
    ttlSeconds: ttlSeconds,
  );
}

/// Local state for the upload lock currently held by this process.
class _UploadSession {
  final String clientId;
  final String token;

  /// Purpose: Create an upload session marker.
  /// Inputs: `clientId`, `token`.
  /// Returns: A new `_UploadSession` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _UploadSession({required this.clientId, required this.token});
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
  static const _lockFileName = '.lock';
  static const _clientIdFileName = 'client_id.txt';
  static const _localLockFileName = 'upload_lock.json';
  static const _lockTtlSeconds = 150;

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

  /// Purpose: Load or create the stable local WebDAV client ID.
  /// Inputs: None.
  /// Returns: `Future<String>`.
  /// Side effects: May create `.sync_base/client_id.txt`.
  /// Notes: The client ID is local-only and is never synced or exported.
  static Future<String> _loadClientId() async {
    final dir = await _getBaseDir();
    final file = File('${dir.path}/$_clientIdFileName');
    if (await file.exists()) {
      final existing = (await file.readAsString()).trim();
      if (existing.isNotEmpty) return existing;
    }
    final id = const Uuid().v4();
    await file.writeAsString(id);
    return id;
  }

  /// Purpose: Read the local upload lock left by an interrupted upload.
  /// Inputs: None.
  /// Returns: `Future<WebDAVUploadLock?>`.
  /// Side effects: None.
  /// Notes: Invalid local locks are ignored and overwritten on the next upload.
  static Future<WebDAVUploadLock?> _readLocalUploadLock() async {
    try {
      final dir = await _getBaseDir();
      final file = File('${dir.path}/$_localLockFileName');
      if (!await file.exists()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return WebDAVUploadLock.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Persist the local upload lock before remote uploads start.
  /// Inputs: `lock`.
  /// Returns: None.
  /// Side effects: Writes `.sync_base/upload_lock.json`.
  /// Notes: The local lock lets the next app start detect interrupted uploads.
  static Future<void> _saveLocalUploadLock(WebDAVUploadLock lock) async {
    final dir = await _getBaseDir();
    final file = File('${dir.path}/$_localLockFileName');
    await _atomicWrite(file, jsonEncode(lock.toJson()));
  }

  /// Purpose: Remove the local upload lock after upload completion or recovery.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Deletes `.sync_base/upload_lock.json` when present.
  /// Notes: Missing files are ignored.
  static Future<void> _clearLocalUploadLock() async {
    final dir = await _getBaseDir();
    final file = File('${dir.path}/$_localLockFileName');
    if (await file.exists()) await file.delete();
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
  /// Returns: `Future<({bool is412, String? error})>` — null error on success.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only. When `ifMatchEtag` is set the PUT
  /// carries an `If-Match` precondition; `ifNoneMatchAll` sends `If-None-Match: *` so a
  /// first upload cannot overwrite a file created concurrently by another device.
  /// HTTP 412 means the remote changed during sync and the caller must re-sync.
  static Future<({bool is412, String? error})> _upload(
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
        return (
          is412: true,
          error: 'remote file changed during sync (HTTP 412)',
        );
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (is412: false, error: null);
      }
      return (is412: false, error: 'HTTP ${response.statusCode}');
    } catch (e) {
      return (is412: false, error: '$e');
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

  /// Purpose: Read and parse the remote WebDAV upload lock.
  /// Inputs: `config`.
  /// Returns: Remote lock, ETag, and optional error.
  /// Side effects: Performs network I/O.
  /// Notes: Missing or malformed locks are treated as replaceable stale locks.
  static Future<({WebDAVUploadLock? lock, String? etag, String? error})>
  _readRemoteUploadLock(WebDAVConfig config) async {
    final remote = await _download(config, _lockFileName);
    if (remote.status == RemoteFileStatus.error) {
      return (lock: null, etag: null, error: remote.error);
    }
    if (remote.status == RemoteFileStatus.notFound || remote.content == null) {
      return (lock: null, etag: null, error: null);
    }
    try {
      final json = jsonDecode(remote.content!) as Map<String, dynamic>;
      return (
        lock: WebDAVUploadLock.fromJson(json),
        etag: _strongEtag(remote.etag),
        error: null,
      );
    } catch (_) {
      return (lock: null, etag: _strongEtag(remote.etag), error: null);
    }
  }

  /// Purpose: Write the remote WebDAV upload lock with optional preconditions.
  /// Inputs: `config`, `lock`, optional ETag or create-only flag.
  /// Returns: Upload result.
  /// Side effects: Performs network I/O and may replace `.lock`.
  /// Notes: Uses the same conditional PUT helper as data uploads.
  static Future<({bool is412, String? error})> _writeRemoteUploadLock(
    WebDAVConfig config,
    WebDAVUploadLock lock, {
    String? ifMatchEtag,
    bool ifNoneMatchAll = false,
  }) {
    return _upload(
      config,
      _lockFileName,
      jsonEncode(lock.toJson()),
      ifMatchEtag: ifMatchEtag,
      ifNoneMatchAll: ifNoneMatchAll,
    );
  }

  /// Purpose: Remove the remote WebDAV upload lock if it still belongs to us.
  /// Inputs: `config`, `etag`.
  /// Returns: None.
  /// Side effects: Performs network I/O.
  /// Notes: Errors are ignored because stale locks expire after the TTL.
  static Future<void> _deleteRemoteUploadLock(
    WebDAVConfig config, {
    String? etag,
  }) async {
    try {
      await http
          .delete(
            Uri.parse(_remoteFileUrl(config, _lockFileName)),
            headers: {..._authHeaders(config), 'If-Match': ?etag},
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// Purpose: Inspect a leftover local upload lock from a previous app run.
  /// Inputs: `config`, `clientId`.
  /// Returns: Optional token to resume and optional blocking error.
  /// Side effects: May clear stale local lock state.
  /// Notes: Normal sync after this step re-downloads, merges, and uploads.
  static Future<({String? resumeToken, String? error})>
  _prepareInterruptedUpload(WebDAVConfig config, String clientId) async {
    final localLock = await _readLocalUploadLock();
    if (localLock == null) return (resumeToken: null, error: null);

    final remote = await _readRemoteUploadLock(config);
    if (remote.error != null) return (resumeToken: null, error: remote.error);

    final remoteLock = remote.lock;
    if (remoteLock == null) {
      await _clearLocalUploadLock();
      return (resumeToken: null, error: null);
    }

    final now = DateTime.now().toUtc();
    if (remoteLock.matches(localLock.clientId, localLock.token) &&
        localLock.clientId == clientId) {
      return (resumeToken: localLock.token, error: null);
    }
    if (remoteLock.clientId != clientId && !remoteLock.isExpired(now)) {
      return (
        resumeToken: null,
        error: 'Another device is uploading; retry after the lock expires.',
      );
    }

    await _clearLocalUploadLock();
    return (resumeToken: null, error: null);
  }

  /// Purpose: Acquire the remote WebDAV upload lock before uploading.
  /// Inputs: `config`, `clientId`, optional `resumeToken`.
  /// Returns: Upload session or a visible error.
  /// Side effects: Writes local and remote lock files.
  /// Notes: Active locks owned by other clients block uploads until expiry.
  static Future<({_UploadSession? session, String? error})>
  _acquireUploadSession(
    WebDAVConfig config,
    String clientId, {
    String? resumeToken,
  }) async {
    final now = DateTime.now().toUtc();
    final remote = await _readRemoteUploadLock(config);
    if (remote.error != null) return (session: null, error: remote.error);

    final remoteLock = remote.lock;
    if (remoteLock != null &&
        remoteLock.clientId != clientId &&
        !remoteLock.isExpired(now)) {
      return (
        session: null,
        error: 'Another device is uploading; retry after the lock expires.',
      );
    }

    final lock = WebDAVUploadLock(
      clientId: clientId,
      token: resumeToken ?? const Uuid().v4(),
      startedAt: now,
      updatedAt: now,
      ttlSeconds: _lockTtlSeconds,
    );
    final write = await _writeRemoteUploadLock(
      config,
      lock,
      ifMatchEtag: remote.etag,
      ifNoneMatchAll: remoteLock == null && remote.etag == null,
    );
    if (write.error != null) {
      return (
        session: null,
        error: write.is412
            ? 'Another device started uploading; retry after the lock expires.'
            : write.error,
      );
    }
    await _saveLocalUploadLock(lock);
    return (
      session: _UploadSession(clientId: clientId, token: lock.token),
      error: null,
    );
  }

  /// Purpose: Refresh the remote upload lock before a PUT.
  /// Inputs: `config`, `session`.
  /// Returns: Optional error string.
  /// Side effects: Updates local and remote lock timestamps.
  /// Notes: If another active client owns the lock, uploading is blocked.
  static Future<String?> _refreshUploadLock(
    WebDAVConfig config,
    _UploadSession session,
  ) async {
    final remote = await _readRemoteUploadLock(config);
    if (remote.error != null) return remote.error;
    final now = DateTime.now().toUtc();
    final remoteLock = remote.lock;
    if (remoteLock != null &&
        !remoteLock.matches(session.clientId, session.token) &&
        remoteLock.clientId != session.clientId &&
        !remoteLock.isExpired(now)) {
      return 'Another device is uploading; retry after the lock expires.';
    }

    final lock =
        (remoteLock != null &&
            remoteLock.matches(session.clientId, session.token))
        ? remoteLock.refreshed(now)
        : WebDAVUploadLock(
            clientId: session.clientId,
            token: session.token,
            startedAt: now,
            updatedAt: now,
            ttlSeconds: _lockTtlSeconds,
          );
    final write = await _writeRemoteUploadLock(
      config,
      lock,
      ifMatchEtag: remote.etag,
      ifNoneMatchAll: remoteLock == null && remote.etag == null,
    );
    if (write.error != null) {
      return write.is412
          ? 'Another device started uploading; retry after the lock expires.'
          : write.error;
    }
    await _saveLocalUploadLock(lock);
    return null;
  }

  /// Purpose: Upload content after refreshing the held upload lock.
  /// Inputs: `config`, `fileName`, `content`, `session`, optional preconditions.
  /// Returns: Upload result.
  /// Side effects: Performs network I/O.
  /// Notes: Callers still handle HTTP 412 by re-downloading and re-merging.
  static Future<({bool is412, String? error})> _uploadWithSession(
    WebDAVConfig config,
    String fileName,
    String content,
    _UploadSession session, {
    String? ifMatchEtag,
    bool ifNoneMatchAll = false,
  }) async {
    final lockError = await _refreshUploadLock(config, session);
    if (lockError != null) return (is412: false, error: lockError);
    return _upload(
      config,
      fileName,
      content,
      ifMatchEtag: ifMatchEtag,
      ifNoneMatchAll: ifNoneMatchAll,
    );
  }

  /// Purpose: Upload bytes after refreshing the held upload lock.
  /// Inputs: `config`, `fileName`, `bytes`, `session`.
  /// Returns: `Future<bool>`.
  /// Side effects: Performs network I/O.
  /// Notes: Used for referenced image uploads under the same remote lock.
  static Future<bool> _uploadBytesWithSession(
    WebDAVConfig config,
    String fileName,
    Uint8List bytes,
    _UploadSession session,
  ) async {
    final lockError = await _refreshUploadLock(config, session);
    if (lockError != null) throw Exception(lockError);
    return _uploadBytes(config, fileName, bytes);
  }

  /// Purpose: Release the held WebDAV upload lock.
  /// Inputs: `config`, `session`.
  /// Returns: None.
  /// Side effects: Deletes matching local and remote lock files.
  /// Notes: Remote delete only runs if the lock still has our client ID and token.
  static Future<void> _releaseUploadSession(
    WebDAVConfig config,
    _UploadSession? session,
  ) async {
    if (session == null) return;
    final remote = await _readRemoteUploadLock(config);
    if (remote.lock?.matches(session.clientId, session.token) ?? false) {
      await _deleteRemoteUploadLock(config, etag: remote.etag);
    }
    await _clearLocalUploadLock();
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
    Future<_UploadSession?> Function() ensureUploadSession,
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
        final uploadSession = await ensureUploadSession();
        if (uploadSession == null) {
          errors.add('Upload skipped for $name: upload lock was not acquired');
          continue;
        }
        try {
          final bytes = await File(p.join(imgDir.path, name)).readAsBytes();
          await _uploadBytesWithSession(
            config,
            'images/$name',
            bytes,
            uploadSession,
          );
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
    _UploadSession? uploadSession;
    try {
      await _ensureRemoteDir(config);
      final appDir = await DeviceStorage.getAppDir();
      final clientId = await _loadClientId();
      final interrupted = await _prepareInterruptedUpload(config, clientId);
      if (interrupted.error != null) {
        return SyncResult(success: false, error: interrupted.error);
      }

      String? lockError;

      /// Purpose: Acquire the upload lock once, lazily before the first upload.
      /// Inputs: None.
      /// Returns: The active upload session, or null if acquisition failed.
      /// Side effects: May write local and remote lock files.
      /// Notes: Internal helper used only within this sync attempt.
      Future<_UploadSession?> ensureUploadSession() async {
        if (uploadSession != null) return uploadSession;
        final acquired = await _acquireUploadSession(
          config,
          clientId,
          resumeToken: interrupted.resumeToken,
        );
        lockError = acquired.error;
        uploadSession = acquired.session;
        return uploadSession;
      }

      /// Purpose: Upload JSON while holding the remote upload lock.
      /// Inputs: `fileName`, `content`, optional ETag or create-only flag.
      /// Returns: Upload result.
      /// Side effects: Performs network I/O.
      /// Notes: Internal helper used only within this sync attempt.
      Future<({bool is412, String? error})> uploadJson(
        String fileName,
        String content, {
        String? ifMatchEtag,
        bool ifNoneMatchAll = false,
      }) async {
        final session = await ensureUploadSession();
        if (session == null) {
          return (
            is412: false,
            error: lockError ?? 'Upload lock was not acquired',
          );
        }
        return _uploadWithSession(
          config,
          fileName,
          content,
          session,
          ifMatchEtag: ifMatchEtag,
          ifNoneMatchAll: ifNoneMatchAll,
        );
      }

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
        var remoteRaw = remote.content;
        var remoteEtag = _strongEtag(remote.etag);

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
          final uploadResult = await uploadJson(
            name,
            localRaw,
            ifNoneMatchAll: true,
          );
          if (uploadResult.error == null) {
            await _saveBase(name, localRaw);
            continue;
          }
          if (!uploadResult.is412) {
            perFileErrors.add('$name: upload failed: ${uploadResult.error}');
            continue;
          }

          final freshRemote = await _download(config, name);
          if (freshRemote.status != RemoteFileStatus.found ||
              freshRemote.content == null) {
            perFileErrors.add('$name: re-download after HTTP 412 failed');
            continue;
          }
          remoteRaw = freshRemote.content;
          remoteEtag = _strongEtag(freshRemote.etag);
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
              var currentLocalRaw = localRaw;
              var currentRemoteRaw = remoteRaw!;
              var currentRemoteEtag = remoteEtag;
              var completedFile = false;
              var sawConflict = false;

              for (var attempt = 0; attempt < 3; attempt++) {
                var result = mergeDeviceData(
                  currentLocalRaw,
                  currentRemoteRaw,
                  baseJson,
                  autoResolve: autoResolve,
                );
                if (!result.hasConflicts) {
                  final freshLocalRaw = await localFile.readAsString();
                  if (freshLocalRaw != currentLocalRaw) {
                    currentLocalRaw = freshLocalRaw;
                    localDeviceJson = freshLocalRaw;
                    continue;
                  }
                }
                if (result.hasConflicts) {
                  pendingDevice = result;
                  remoteDeviceJson = currentRemoteRaw;
                  sawConflict = true;
                  break;
                }
                final mergedData = DeviceData(
                  devices: result.merged,
                  extraJson: result.extraJson,
                );
                final mergedJson = const JsonEncoder.withIndent(
                  '  ',
                ).convert(mergedData.toJson());
                await _atomicWrite(localFile, mergedJson);
                _localDataChanged = true;
                final uploadResult = await uploadJson(
                  name,
                  mergedJson,
                  ifMatchEtag: currentRemoteEtag,
                );
                if (uploadResult.error == null) {
                  await _saveBase(name, mergedJson);
                  localDeviceJson = mergedJson;
                  completedFile = true;
                  break;
                }
                if (!uploadResult.is412) {
                  perFileErrors.add(
                    '$name: upload failed: ${uploadResult.error}',
                  );
                  completedFile = true;
                  break;
                }
                final freshRemote = await _download(config, name);
                if (freshRemote.status != RemoteFileStatus.found ||
                    freshRemote.content == null) {
                  perFileErrors.add('$name: re-download after HTTP 412 failed');
                  completedFile = true;
                  break;
                }
                currentRemoteRaw = freshRemote.content!;
                currentRemoteEtag = _strongEtag(freshRemote.etag);
                remoteDeviceJson = currentRemoteRaw;
                currentLocalRaw = await localFile.readAsString();
                localDeviceJson = currentLocalRaw;
              }

              if (!completedFile && !sawConflict) {
                perFileErrors.add(
                  '$name: upload failed after repeated concurrent updates',
                );
              }
            case 'network_data.json':
              var currentLocalRaw = localRaw;
              var currentRemoteRaw = remoteRaw!;
              var currentRemoteEtag = remoteEtag;
              var completedFile = false;
              var sawConflict = false;

              for (var attempt = 0; attempt < 3; attempt++) {
                var result = mergeNetworkData(
                  currentLocalRaw,
                  currentRemoteRaw,
                  baseJson,
                  autoResolve: autoResolve,
                );
                if (!result.hasConflicts) {
                  final freshLocalRaw = await localFile.readAsString();
                  if (freshLocalRaw != currentLocalRaw) {
                    currentLocalRaw = freshLocalRaw;
                    continue;
                  }
                }
                if (result.hasConflicts) {
                  pendingNetwork = result;
                  sawConflict = true;
                  break;
                }
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
                final uploadResult = await uploadJson(
                  name,
                  mergedJson,
                  ifMatchEtag: currentRemoteEtag,
                );
                if (uploadResult.error == null) {
                  await _saveBase(name, mergedJson);
                  completedFile = true;
                  break;
                }
                if (!uploadResult.is412) {
                  perFileErrors.add(
                    '$name: upload failed: ${uploadResult.error}',
                  );
                  completedFile = true;
                  break;
                }
                final freshRemote = await _download(config, name);
                if (freshRemote.status != RemoteFileStatus.found ||
                    freshRemote.content == null) {
                  perFileErrors.add('$name: re-download after HTTP 412 failed');
                  completedFile = true;
                  break;
                }
                currentRemoteRaw = freshRemote.content!;
                currentRemoteEtag = _strongEtag(freshRemote.etag);
                currentLocalRaw = await localFile.readAsString();
              }

              if (!completedFile && !sawConflict) {
                perFileErrors.add(
                  '$name: upload failed after repeated concurrent updates',
                );
              }
            case 'dataset_data.json':
              var currentLocalRaw = localRaw;
              var currentRemoteRaw = remoteRaw!;
              var currentRemoteEtag = remoteEtag;
              var completedFile = false;
              var sawConflict = false;

              for (var attempt = 0; attempt < 3; attempt++) {
                var result = mergeDataSetData(
                  currentLocalRaw,
                  currentRemoteRaw,
                  baseJson,
                  autoResolve: autoResolve,
                );
                if (!result.hasConflicts) {
                  final freshLocalRaw = await localFile.readAsString();
                  if (freshLocalRaw != currentLocalRaw) {
                    currentLocalRaw = freshLocalRaw;
                    continue;
                  }
                }
                if (result.hasConflicts) {
                  pendingDataSet = result;
                  sawConflict = true;
                  break;
                }
                final mergedData = DataSetData(
                  datasets: result.merged,
                  extraJson: result.extraJson,
                );
                final mergedJson = const JsonEncoder.withIndent(
                  '  ',
                ).convert(mergedData.toJson());
                await _atomicWrite(localFile, mergedJson);
                _localDataChanged = true;
                final uploadResult = await uploadJson(
                  name,
                  mergedJson,
                  ifMatchEtag: currentRemoteEtag,
                );
                if (uploadResult.error == null) {
                  await _saveBase(name, mergedJson);
                  completedFile = true;
                  break;
                }
                if (!uploadResult.is412) {
                  perFileErrors.add(
                    '$name: upload failed: ${uploadResult.error}',
                  );
                  completedFile = true;
                  break;
                }
                final freshRemote = await _download(config, name);
                if (freshRemote.status != RemoteFileStatus.found ||
                    freshRemote.content == null) {
                  perFileErrors.add('$name: re-download after HTTP 412 failed');
                  completedFile = true;
                  break;
                }
                currentRemoteRaw = freshRemote.content!;
                currentRemoteEtag = _strongEtag(freshRemote.etag);
                currentLocalRaw = await localFile.readAsString();
              }

              if (!completedFile && !sawConflict) {
                perFileErrors.add(
                  '$name: upload failed after repeated concurrent updates',
                );
              }
            case 'service_data.json':
              var currentLocalRaw = localRaw;
              var currentRemoteRaw = remoteRaw!;
              var currentRemoteEtag = remoteEtag;
              var completedFile = false;
              var sawConflict = false;

              for (var attempt = 0; attempt < 3; attempt++) {
                var result = mergeServiceData(
                  currentLocalRaw,
                  currentRemoteRaw,
                  baseJson,
                  autoResolve: autoResolve,
                );
                if (!result.hasConflicts) {
                  final freshLocalRaw = await localFile.readAsString();
                  if (freshLocalRaw != currentLocalRaw) {
                    currentLocalRaw = freshLocalRaw;
                    continue;
                  }
                }
                if (result.hasConflicts) {
                  pendingService = result;
                  sawConflict = true;
                  break;
                }
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
                final uploadResult = await uploadJson(
                  name,
                  mergedJson,
                  ifMatchEtag: currentRemoteEtag,
                );
                if (uploadResult.error == null) {
                  await _saveBase(name, mergedJson);
                  completedFile = true;
                  break;
                }
                if (!uploadResult.is412) {
                  perFileErrors.add(
                    '$name: upload failed: ${uploadResult.error}',
                  );
                  completedFile = true;
                  break;
                }
                final freshRemote = await _download(config, name);
                if (freshRemote.status != RemoteFileStatus.found ||
                    freshRemote.content == null) {
                  perFileErrors.add('$name: re-download after HTTP 412 failed');
                  completedFile = true;
                  break;
                }
                currentRemoteRaw = freshRemote.content!;
                currentRemoteEtag = _strongEtag(freshRemote.etag);
                currentLocalRaw = await localFile.readAsString();
              }

              if (!completedFile && !sawConflict) {
                perFileErrors.add(
                  '$name: upload failed after repeated concurrent updates',
                );
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
      final imageErrors = await _syncImages(
        config,
        appDir,
        referencedImages,
        ensureUploadSession,
      );

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
      await _releaseUploadSession(config, uploadSession);
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
    _UploadSession uploadSession,
  ) async {
    final appDir = await DeviceStorage.getAppDir();
    final remote = await _download(config, fileName);
    if (remote.status == RemoteFileStatus.error) return false;
    await _atomicWrite(File('${appDir.path}/$fileName'), mergedJson);
    _localDataChanged = true;
    final uploadResult = await _uploadWithSession(
      config,
      fileName,
      mergedJson,
      uploadSession,
      ifMatchEtag: _strongEtag(remote.etag),
      ifNoneMatchAll: remote.status == RemoteFileStatus.notFound,
    );
    if (uploadResult.error != null) return false;
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
    _UploadSession? uploadSession;
    try {
      final clientId = await _loadClientId();
      final interrupted = await _prepareInterruptedUpload(config, clientId);
      if (interrupted.error != null) return false;
      final acquired = await _acquireUploadSession(
        config,
        clientId,
        resumeToken: interrupted.resumeToken,
      );
      uploadSession = acquired.session;
      if (uploadSession == null) return false;

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
        final ok = await _finalizeFile(
          config,
          'device_data.json',
          mergedJson,
          uploadSession,
        );
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
        final ok = await _finalizeFile(
          config,
          'network_data.json',
          mergedJson,
          uploadSession,
        );
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
        final ok = await _finalizeFile(
          config,
          'dataset_data.json',
          mergedJson,
          uploadSession,
        );
        allOk = allOk && ok;
      }

      if (pending.serviceMerge != null) {
        final mergedData = pending.serviceMerge!.buildResolved(resolutions);
        final mergedJson = const JsonEncoder.withIndent(
          '  ',
        ).convert(mergedData.toJson());
        final ok = await _finalizeFile(
          config,
          'service_data.json',
          mergedJson,
          uploadSession,
        );
        allOk = allOk && ok;
      }

      return allOk;
    } catch (_) {
      return false;
    } finally {
      await _releaseUploadSession(config, uploadSession);
    }
  }
}
