import 'dart:convert';
import 'dart:io';

import 'package:myapps_data/myapps_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../datasets/models/dataset.dart';
import '../../datasets/services/dataset_storage.dart';
import '../../network/models/network.dart';
import '../../network/services/network_storage.dart';
import '../../services/services/service_storage.dart';
import '../models/device.dart';
import '../../../app/data_modules.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../../shared/utils/adaptive_layout.dart';

class DeviceStorage {
  static const _dataFileName = deviceDataFileName;
  static const _configFileName = 'storage_config.json';

  /// Custom storage path (loaded from config).
  static String? _customPath;
  static bool _configLoaded = false;

  /// One write queue per data file path (see [serializeWrite]).
  static final Map<String, AtomicWriteQueue> _queues =
      <String, AtomicWriteQueue>{};

  /// Purpose: Run [operation] after every earlier write to [path] finished.
  /// Inputs: `path` - the data file the operation reads and rewrites;
  /// `operation` - the read-modify-write to run.
  /// Returns: `Future<void>` with the operation's own outcome.
  /// Side effects: Appends to the queue of that path.
  /// Notes: Shared by the four data storages. Queues are keyed by file path,
  /// not global, so unrelated files never wait for each other and a queue
  /// left mid-write (e.g. by a torn-down test) cannot stall another folder.
  /// Code already inside an operation must call its private `_write`, never
  /// the public `save`, which would enqueue behind itself and deadlock.
  static Future<void> serializeWrite(
    String path,
    Future<void> Function() operation,
  ) => (_queues[path] ??= AtomicWriteQueue()).enqueue(operation);

  /// Purpose: Atomically replace [file] with [content], retrying brief lock races.
  /// Inputs: `file`, `content`.
  /// Returns: `Future<void>`; throws the last `FileSystemException` when every
  /// attempt failed.
  /// Side effects: tmp-file + rename write via `atomicWriteString`.
  /// Notes: Shared by every storage. On Windows the rename over the target
  /// fails with "access denied" while another reader (or a virus scanner) has
  /// the target open for a moment, so a failed attempt is retried up to five
  /// times with a short growing delay before the error is surfaced.
  static Future<void> atomicWrite(File file, String content) async {
    for (var attempt = 1; ; attempt++) {
      try {
        await atomicWriteString(file, content);
        return;
      } on FileSystemException {
        if (attempt >= 5) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 25 * attempt));
      }
    }
  }

  /// Purpose: Serialise [operation] behind earlier writes of `devices.json`.
  /// Inputs: `operation`.
  /// Returns: `Future<void>`.
  /// Side effects: See [serializeWrite].
  /// Notes: Internal helper used within this file only.
  static Future<void> _serialised(Future<void> Function() operation) async {
    final file = await _getFile(_dataFileName);
    return serializeWrite(file.path, operation);
  }

  /// Purpose: Provide the internal get default app dir helper for this file.
  /// Inputs: None.
  /// Returns: `Future<Directory>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only. The platform path is
  /// resolved on every call and deliberately never cached, so a swapped path
  /// provider (tests) is honoured.
  /// Default app directory (~/Documents/MyDevice).
  static Future<Directory> _getDefaultAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final appDir = Directory(p.join(dir.path, 'MyDevice'));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  /// Purpose: Provide the internal get config file helper for this file.
  /// Inputs: None.
  /// Returns: `Future<File>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
  /// Config file always lives in the default directory.
  static Future<File> _getConfigFile() async {
    final dir = await _getDefaultAppDir();
    return File(p.join(dir.path, _configFileName));
  }

  /// Purpose: Load custom path into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
  /// Load custom path from config (once).
  static Future<void> _loadCustomPath() async {
    if (_configLoaded) return;
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          _customPath = json['storagePath'] as String?;
        }
      }
    } catch (_) {}
    _configLoaded = true;
  }

  /// Purpose: Implement the get app dir behavior for this file.
  /// Inputs: None.
  /// Returns: `Future<Directory>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  static Future<Directory> getAppDir() async {
    await _loadCustomPath();
    if (_customPath != null && _customPath!.isNotEmpty) {
      final dir = Directory(_customPath!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    return _getDefaultAppDir();
  }

  /// Purpose: Implement the get storage path behavior for this file.
  /// Inputs: None.
  /// Returns: `Future<String>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  /// Return the display path of current storage location.
  static Future<String> getStoragePath() async {
    final appDir = await getAppDir();
    return appDir.path;
  }

  /// Purpose: Update the custom storage directory and migrate the app's data to it.
  /// Inputs: `newPath`; pass `null` or empty to reset to the default location.
  /// Returns: `Future<StoragePathResult>` — `saved` is false only when the
  /// path could not be recorded; `unmoved` lists the entries the move left in
  /// the old folder.
  /// Side effects: Rewrites `storage_config.json` and moves the old storage
  /// folder's contents to the new location.
  /// Notes: Migrates **everything** in the folder — all four data files,
  /// `images/`, `.sync_base/`, `backups/` (blobs included), and
  /// `webdav_config.json` — not an enumerated list, so a data file added later
  /// moves automatically. `storage_config.json` deliberately stays put: it lives
  /// in the platform default directory, holds the custom path itself and every
  /// other preference, so moving the data never touches the preferences. A
  /// stray copy an older build left in the custom folder is adopted first.
  /// An unmoved entry is not readable by the app at the new location; the
  /// caller must tell the user.
  ///
  /// This replaced hand-rolled per-directory copies that only walked top-level
  /// files, so `backups/blobs/` was left behind and every restored backup lost
  /// its images, and that only ran when the destination directory did not exist
  /// at all. `.sync_base/` was missed entirely — the dangerous case, since
  /// without a base snapshot the next sync treats records other devices deleted
  /// as new local records and re-uploads them, resurrecting deletions.
  ///
  /// Existing destination files win and their source copies are left in place,
  /// so nothing is discarded on a guess about which copy is newer.
  static Future<StoragePathResult> setStoragePath(String? newPath) async {
    try {
      await _adoptStrayConfig();
      final oldDir = await getAppDir();

      // Persist to config first (always in default dir) and only then switch
      // the in-memory path, so a failed write leaves both untouched.
      final config = await _readConfigFromDefault();
      final previousConfig = {...config};
      final previousPath = _customPath;
      if (newPath != null && newPath.isNotEmpty) {
        config['storagePath'] = newPath;
      } else {
        config.remove('storagePath');
      }
      await _writeConfigToDefault(config);
      _customPath = newPath;

      final Directory newDir;
      try {
        newDir = await getAppDir();
      } catch (_) {
        // The new folder cannot be created: roll the path and the persisted
        // config back so the app keeps using the old location.
        _customPath = previousPath;
        try {
          await _writeConfigToDefault(previousConfig);
        } catch (_) {}
        return const StoragePathResult(saved: false);
      }
      if (oldDir.path == newDir.path) return const StoragePathResult();

      // Per-entry failures are reported rather than thrown; the path change
      // itself has already been persisted, so the move is best-effort and any
      // unmoved entry stays in the old folder, where the caller can point the
      // user to it.
      final failed = await migrateStorageContents(from: oldDir, to: newDir);
      final unmoved = {...failed, ...await _leftoverEntries(oldDir)}.toList()
        ..sort();
      return StoragePathResult(unmoved: unmoved, from: oldDir.path);
    } catch (_) {
      return const StoragePathResult(saved: false);
    }
  }

  /// Purpose: List the files a storage move left in the old folder.
  /// Inputs: `oldDir` — the folder the data moved out of.
  /// Returns: Relative paths of every file still there, except the
  /// top-level `storage_config.json`, which never moves.
  /// Side effects: Lists the folder.
  /// Notes: `migrateStorageContents` reports files it failed to copy, but
  /// not those it skipped because the destination already had one of the
  /// same name; both stay behind unseen by the app, so both are reported.
  static Future<List<String>> _leftoverEntries(Directory oldDir) async {
    final left = <String>[];
    try {
      if (!await oldDir.exists()) return left;
      await for (final entity in oldDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final relative = p.relative(entity.path, from: oldDir.path);
        if (relative == _configFileName) continue;
        left.add(relative);
      }
    } catch (_) {}
    return left;
  }

  /// The custom path whose folder was last checked for a stray config file.
  static String? _strayCheckedFor;

  /// Purpose: Adopt a `storage_config.json` that an older build wrote into the
  /// custom storage folder.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: May merge the stray file into the default folder's
  /// `storage_config.json` and delete the stray file.
  /// Notes: Before 1.5.7 `readConfig`/`writeConfig` used the current storage
  /// folder while the custom path lived in the default one, so after a move
  /// the preferences seemed reset and new ones went to a second file in the
  /// custom folder. The stray file's keys are the newer ones and win, except
  /// `storagePath`, which only the default file may hold. Checked once per
  /// custom path; a file that cannot be read or parsed is left alone.
  static Future<void> _adoptStrayConfig() async {
    await _loadCustomPath();
    final custom = _customPath;
    if (custom == null || custom.isEmpty || _strayCheckedFor == custom) {
      return;
    }
    _strayCheckedFor = custom;
    try {
      final defaultFile = await _getConfigFile();
      final stray = File(p.join(custom, _configFileName));
      if (p.equals(stray.path, defaultFile.path) || !await stray.exists()) {
        return;
      }
      final raw = await stray.readAsString();
      final strayConfig = raw.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      final merged = {...await _readConfigFromDefault(), ...strayConfig};
      merged['storagePath'] = custom;
      await _writeConfigToDefault(merged);
      await stray.delete();
    } catch (_) {}
  }

  /// Purpose: Provide the internal read config from default helper for this file.
  /// Inputs: None.
  /// Returns: `Future<Map<String, dynamic>>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
  /// Read config from the default location (for storagePath persistence).
  static Future<Map<String, dynamic>> _readConfigFromDefault() async {
    final file = await _getConfigFile();
    if (!await file.exists()) return {};
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Purpose: Provide the internal write config to default helper for this file.
  /// Inputs: `config`.
  /// Returns: `Future<void>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
  /// Write config to the default location.
  static Future<void> _writeConfigToDefault(Map<String, dynamic> config) async {
    final file = await _getConfigFile();
    await atomicWrite(file, const JsonEncoder.withIndent('  ').convert(config));
  }

  /// Purpose: Provide the internal get file helper for this file.
  /// Inputs: `name`.
  /// Returns: `Future<File>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
  static Future<File> _getFile(String name) async {
    final appDir = await getAppDir();
    return File(p.join(appDir.path, name));
  }

  // ── Data persistence ──

  /// Purpose: Load the relevant data into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<DeviceData>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  static Future<DeviceData> load() async {
    final file = await _getFile(_dataFileName);
    if (!await file.exists()) return const DeviceData();
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const DeviceData();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return DeviceData.fromJson(json);
  }

  /// Purpose: Save the relevant data to the relevant storage or service layer.
  /// Inputs: `data`.
  /// Returns: `Future<void>`.
  /// Side effects: Atomically replaces `devices.json` (queued behind earlier
  /// writes) and notifies auto-sync.
  /// Notes: Public entry point; enqueues [_write]. Code that already runs
  /// inside the write queue must call [_write] directly, never this method,
  /// or it would wait on itself and deadlock.
  static Future<void> save(DeviceData data) => _serialised(() => _write(data));

  /// Purpose: Write `devices.json` atomically and notify auto-sync.
  /// Inputs: `data`.
  /// Returns: `Future<void>`.
  /// Side effects: tmp-file + rename write of the data file; calls
  /// `AutoSyncService.notifySaved`.
  /// Notes: Internal helper; the unqueued primitive that queued operations
  /// call from inside [_serialised]. Never enqueue from here.
  static Future<void> _write(DeviceData data) async {
    final file = await _getFile(_dataFileName);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await atomicWrite(file, jsonStr);
    AutoSyncService.instance.notifySaved();
  }

  /// Purpose: Add or update through the current flow.
  /// Inputs: `device`.
  /// Returns: `Future<void>`.
  /// Side effects: Queued read-modify-write of `devices.json`; may rewrite
  /// the network, dataset and service files when the device leaves service.
  /// Notes: The load-modify-write runs inside the write queue so concurrent
  /// calls cannot lose each other's device; unknown top-level fields
  /// (`extraJson`) are carried over.
  /// Add a new device or update an existing one (matched by id).
  static Future<void> addOrUpdate(Device device) async {
    await _serialised(() async {
      final data = await load();
      final devices = List<Device>.of(data.devices);
      final idx = devices.indexWhere((d) => d.id == device.id);
      if (idx >= 0) {
        devices[idx] = device;
      } else {
        devices.add(device);
      }
      await _write(DeviceData(devices: devices, extraJson: data.extraJson));
    });
    if (!device.isInService) {
      await _removeDeviceReferences(device.id);
    }
  }

  /// Purpose: Delete device from the relevant storage or state.
  /// Inputs: `id`.
  /// Returns: `Future<void>`.
  /// Side effects: Queued read-modify-write of `devices.json`, then rewrites
  /// the network, dataset and service files that referenced the device.
  /// Notes: Unknown top-level fields (`extraJson`) are carried over.
  /// Delete a device by id and clean up references in other modules.
  static Future<void> deleteDevice(String id) async {
    await _serialised(() async {
      final data = await load();
      final devices = data.devices.where((d) => d.id != id).toList();
      await _write(DeviceData(devices: devices, extraJson: data.extraJson));
    });
    await _removeDeviceReferences(id);
  }

  /// Purpose: Provide the internal remove device references helper for this file.
  /// Inputs: `id`.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Future<void> _removeDeviceReferences(String id) async {
    // Remove network assignments referencing this device
    final netData = await NetworkStorage.load();
    final cleanedAssignments = netData.assignments
        .where((a) => a.deviceId != id)
        .toList();
    if (cleanedAssignments.length != netData.assignments.length) {
      await NetworkStorage.save(
        NetworkData(
          networks: netData.networks,
          assignments: cleanedAssignments,
          extraJson: netData.extraJson,
        ),
      );
    }

    // Remove dataset storage links referencing this device
    final dsData = await DataSetStorage.load();
    var dsChanged = false;
    final cleanedDatasets = dsData.datasets.map((ds) {
      final filtered = ds.storageLinks
          .where((link) => link.deviceId != id)
          .toList();
      if (filtered.length != ds.storageLinks.length) {
        dsChanged = true;
        return ds.copyWith(storageLinks: filtered);
      }
      return ds;
    }).toList();
    if (dsChanged) {
      await DataSetStorage.save(
        DataSetData(datasets: cleanedDatasets, extraJson: dsData.extraJson),
      );
    }

    await ServiceStorage.removeDeviceReferences(id);
  }

  // ── Config persistence (theme, locale) ──

  /// Purpose: Read the app's local preferences.
  /// Inputs: None.
  /// Returns: `Future<Map<String, dynamic>>` — `storage_config.json` from the
  /// default folder; empty when it does not exist.
  /// Side effects: Performs local file-system I/O; may adopt a stray config
  /// file from the custom storage folder first.
  /// Notes: One file for every preference and the custom path, always in the
  /// platform default folder, whatever the storage path — so moving the data
  /// never resets the theme, language, currency or list columns.
  static Future<Map<String, dynamic>> readConfig() async {
    await _adoptStrayConfig();
    return _readConfigFromDefault();
  }

  /// Purpose: Write the app's local preferences.
  /// Inputs: `config` — the complete map, usually read with [readConfig] and
  /// modified.
  /// Returns: `Future<void>`.
  /// Side effects: Rewrites `storage_config.json` in the default folder.
  /// Notes: `storagePath` belongs to [setStoragePath]: whatever `config`
  /// holds under that key is replaced by the current custom path, or removed
  /// without one, so a preference write can never move or lose the data.
  static Future<void> writeConfig(Map<String, dynamic> config) async {
    await _adoptStrayConfig();
    final custom = _customPath;
    final out = {...config}..remove('storagePath');
    if (custom != null && custom.isNotEmpty) out['storagePath'] = custom;
    await _writeConfigToDefault(out);
  }

  /// Purpose: Read the interface style (1.7.0).
  /// Inputs: None.
  /// Returns: `Future<String?>` — `'material3'`, or null for the default
  /// Expressive style.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Local setting, never synced. Only the non-default Material 3
  /// style is stored, as `uiStyle: "material3"`.
  static Future<String?> getUiStyle() async {
    final config = await readConfig();
    return config['uiStyle'] == 'material3' ? 'material3' : null;
  }

  /// Purpose: Persist the interface style (1.7.0).
  /// Inputs: `name` — `'material3'`, or null for the default Expressive style.
  /// Returns: `Future<void>`.
  /// Side effects: Read-modify-writes `storage_config.json`.
  /// Notes: Writes `uiStyle: "material3"` or removes the key, so a default
  /// install's config stays free of it.
  static Future<void> setUiStyle(String? name) async {
    final config = await readConfig();
    if (name == 'material3') {
      config['uiStyle'] = 'material3';
    } else {
      config.remove('uiStyle');
    }
    await writeConfig(config);
  }

  /// Purpose: Read where the shell puts its navigation (1.7.1).
  /// Inputs: None.
  /// Returns: `Future<String?>` — `'sideOnWide'`, `'side'`, or null for the
  /// default (bottom everywhere).
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Device-local, never synced; applies to both interface styles.
  /// Unknown values read as the default.
  static Future<String?> getNavPlacement() async {
    final value = (await readConfig())['navPlacement'];
    return value == 'sideOnWide' || value == 'side' ? value as String : null;
  }

  /// Purpose: Persist where the shell puts its navigation (1.7.1).
  /// Inputs: `name` — `'sideOnWide'`, `'side'`, or null for bottom.
  /// Returns: `Future<void>`.
  /// Side effects: Read-modify-writes `storage_config.json`.
  /// Notes: The default (bottom) removes the key.
  static Future<void> setNavPlacement(String? name) async {
    final config = await readConfig();
    if (name == 'sideOnWide' || name == 'side') {
      config['navPlacement'] = name;
    } else {
      config.remove('navPlacement');
    }
    await writeConfig(config);
  }

  /// Purpose: Return whether the navigation rail sits on the right (1.7.1).
  /// Inputs: None.
  /// Returns: `Future<bool>` — false (left) by default.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Device-local, never synced; applies to both interface styles.
  static Future<bool> getNavRailRight() async {
    final config = await readConfig();
    return config['navRailRight'] == true;
  }

  /// Purpose: Persist which side the navigation rail sits on (1.7.1).
  /// Inputs: `right`.
  /// Returns: `Future<void>`.
  /// Side effects: Read-modify-writes `storage_config.json`.
  /// Notes: Only the right side is stored; left removes the key.
  static Future<void> setNavRailRight(bool right) async {
    final config = await readConfig();
    if (right) {
      config['navRailRight'] = true;
    } else {
      config.remove('navRailRight');
    }
    await writeConfig(config);
  }

  /// Purpose: Implement the get theme mode behavior for this file.
  /// Inputs: None.
  /// Returns: `Future<String?>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<String?> getThemeMode() async {
    final config = await readConfig();
    return config['themeMode'] as String?;
  }

  /// Purpose: Update theme mode with the provided value.
  /// Inputs: `mode`.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> setThemeMode(String? mode) async {
    final config = await readConfig();
    if (mode == null) {
      config.remove('themeMode');
    } else {
      config['themeMode'] = mode;
    }
    await writeConfig(config);
  }

  /// Purpose: Implement the get locale tag behavior for this file.
  /// Inputs: None.
  /// Returns: `Future<String?>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<String?> getLocaleTag() async {
    final config = await readConfig();
    return config['locale'] as String?;
  }

  /// Purpose: Update locale tag with the provided value.
  /// Inputs: `tag`.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> setLocaleTag(String? tag) async {
    final config = await readConfig();
    if (tag == null) {
      config.remove('locale');
    } else {
      config['locale'] = tag;
    }
    await writeConfig(config);
  }

  // ── On-device AI (device-local, never synced; off by default, v1.6.0) ──

  /// Purpose: Read whether the user turned on on-device AI.
  /// Inputs: None.
  /// Returns: `Future<bool>` — false when the key is absent.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Device-local, never synced; off by default.
  static Future<bool> getOnDeviceAiEnabled() async =>
      (await readConfig())['onDeviceAiEnabled'] == true;

  /// Purpose: Persist the on-device AI switch.
  /// Inputs: `enabled`.
  /// Returns: `Future<void>`.
  /// Side effects: Read-modify-writes `storage_config.json`.
  /// Notes: Stored only when true; false removes the key.
  static Future<void> setOnDeviceAiEnabled(bool enabled) =>
      _setFlag('onDeviceAiEnabled', enabled);

  /// Purpose: Read whether the faster on-device model is preferred.
  /// Inputs: None.
  /// Returns: `Future<bool>` — false when the key is absent.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Android only in effect.
  static Future<bool> getOnDeviceAiPreferFast() async =>
      (await readConfig())['onDeviceAiPreferFast'] == true;

  /// Purpose: Persist the faster-model preference.
  /// Inputs: `enabled`.
  /// Returns: `Future<void>`.
  /// Side effects: Read-modify-writes `storage_config.json`.
  /// Notes: Stored only when true; false removes the key.
  static Future<void> setOnDeviceAiPreferFast(bool enabled) =>
      _setFlag('onDeviceAiPreferFast', enabled);

  /// Purpose: Store a boolean preference that defaults to false.
  /// Inputs: `key`, `enabled`.
  /// Returns: `Future<void>`.
  /// Side effects: Read-modify-writes `storage_config.json`.
  /// Notes: Internal helper used within this file only. Writes `true` or
  /// removes the key, so a default install's config stays free of it.
  static Future<void> _setFlag(String key, bool enabled) async {
    final config = await readConfig();
    if (enabled) {
      config[key] = true;
    } else {
      config.remove(key);
    }
    await writeConfig(config);
  }

  // ── List column preferences (device-local, never synced) ──

  /// Purpose: Read a stored list column preference.
  /// Inputs: `key` — the `storage_config.json` key for one list page.
  /// Returns: `Future<int>` — `listColumnsAuto` when unset or malformed.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Internal helper shared by the four per-page accessors; the
  /// preference is clamped again at render time against what the width fits.
  static Future<int> _getListColumns(String key) async {
    final config = await readConfig();
    final value = config[key];
    if (value is! int || value < 1 || value > listMaxColumns) {
      return listColumnsAuto;
    }
    return value;
  }

  /// Purpose: Persist a list column preference for one list page.
  /// Inputs: `key`, `columns`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: The default `listColumnsAuto` is removed from config rather than
  /// stored, matching how `setThemeMode` handles its default.
  static Future<void> _setListColumns(String key, int columns) async {
    final config = await readConfig();
    if (columns >= 1 && columns <= listMaxColumns) {
      config[key] = columns;
    } else {
      config.remove(key);
    }
    await writeConfig(config);
  }

  /// Purpose: Read the device list's column preference.
  /// Inputs: None.
  /// Returns: `Future<int>` — defaults to `listColumnsAuto`.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: None.
  static Future<int> getDeviceListColumns() =>
      _getListColumns('deviceListColumns');

  /// Purpose: Persist the device list's column preference.
  /// Inputs: `columns`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: None.
  static Future<void> setDeviceListColumns(int columns) =>
      _setListColumns('deviceListColumns', columns);

  /// Purpose: Read the network list's column preference.
  /// Inputs: None.
  /// Returns: `Future<int>` — defaults to `listColumnsAuto`.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: None.
  static Future<int> getNetworkListColumns() =>
      _getListColumns('networkListColumns');

  /// Purpose: Persist the network list's column preference.
  /// Inputs: `columns`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: None.
  static Future<void> setNetworkListColumns(int columns) =>
      _setListColumns('networkListColumns', columns);

  /// Purpose: Read the dataset list's column preference.
  /// Inputs: None.
  /// Returns: `Future<int>` — defaults to `listColumnsAuto`.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: None.
  static Future<int> getDataSetListColumns() =>
      _getListColumns('dataSetListColumns');

  /// Purpose: Persist the dataset list's column preference.
  /// Inputs: `columns`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: None.
  static Future<void> setDataSetListColumns(int columns) =>
      _setListColumns('dataSetListColumns', columns);

  /// Purpose: Read the services page's column preference.
  /// Inputs: None.
  /// Returns: `Future<int>` — defaults to `listColumnsAuto`.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: One preference serves the devices, routes and ports views; the
  /// overview is always a single column.
  static Future<int> getServiceListColumns() =>
      _getListColumns('serviceListColumns');

  /// Purpose: Persist the services page's column preference.
  /// Inputs: `columns`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: None.
  static Future<void> setServiceListColumns(int columns) =>
      _setListColumns('serviceListColumns', columns);
}

/// What `DeviceStorage.setStoragePath` did.
class StoragePathResult {
  /// Whether the new path was recorded. False means nothing changed.
  final bool saved;

  /// Entries (relative paths) the move left in the old folder; empty when
  /// everything moved or nothing had to.
  final List<String> unmoved;

  /// The old folder, where the unmoved entries still are; null when nothing
  /// was moved.
  final String? from;

  /// Purpose: Create a result.
  /// Inputs: `saved` — true by default; `unmoved`; `from`.
  /// Returns: A new `StoragePathResult`.
  /// Side effects: None.
  /// Notes: None.
  const StoragePathResult({
    this.saved = true,
    this.unmoved = const [],
    this.from,
  });

  /// Purpose: Report whether the change fully succeeded.
  /// Inputs: None.
  /// Returns: `bool` — saved and nothing left behind.
  /// Side effects: None.
  /// Notes: None.
  bool get complete => saved && unmoved.isEmpty;
}
