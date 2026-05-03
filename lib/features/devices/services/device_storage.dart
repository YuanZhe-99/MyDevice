import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../datasets/models/dataset.dart';
import '../../datasets/services/dataset_storage.dart';
import '../../network/models/network.dart';
import '../../network/services/network_storage.dart';
import '../models/device.dart';
import '../../../shared/services/auto_sync_service.dart';

class DeviceStorage {
  static const _dataFileName = 'device_data.json';
  static const _configFileName = 'storage_config.json';

  /// Custom storage path (loaded from config).
  static String? _customPath;
  static bool _configLoaded = false;

  /// Default app directory (~/Documents/MyDevice).
  static Future<Directory> _getDefaultAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final appDir = Directory(p.join(dir.path, 'MyDevice'));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  /// Config file always lives in the default directory.
  static Future<File> _getConfigFile() async {
    final dir = await _getDefaultAppDir();
    return File(p.join(dir.path, _configFileName));
  }

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

  /// Return the display path of current storage location.
  static Future<String> getStoragePath() async {
    final appDir = await getAppDir();
    return appDir.path;
  }

  /// Change storage location. Migrates data if new location is empty,
  /// otherwise switches to existing data.
  static Future<bool> setStoragePath(String? newPath) async {
    try {
      final oldDir = await getAppDir();

      _customPath = newPath;
      // Persist to config (always in default dir)
      final config = await _readConfigFromDefault();
      if (newPath != null && newPath.isNotEmpty) {
        config['storagePath'] = newPath;
      } else {
        config.remove('storagePath');
      }
      await _writeConfigToDefault(config);

      final newDir = await getAppDir();
      if (oldDir.path == newDir.path) return true;

      // Migrate data files
      final dataFileNames = [
        _dataFileName,
        'network_data.json',
        'dataset_data.json',
      ];

      for (final name in dataFileNames) {
        final oldFile = File(p.join(oldDir.path, name));
        final newFile = File(p.join(newDir.path, name));

        if (await newFile.exists()) {
          // New location has data — switch to it (keep old data intact)
          continue;
        }
        if (await oldFile.exists()) {
          // Move data to new location
          await oldFile.copy(newFile.path);
          await oldFile.delete();
        }
      }

      // Also migrate backups directory
      final oldBackups = Directory(p.join(oldDir.path, 'backups'));
      final newBackups = Directory(p.join(newDir.path, 'backups'));
      if (await oldBackups.exists() && !await newBackups.exists()) {
        await newBackups.create(recursive: true);
        await for (final entity in oldBackups.list()) {
          if (entity is File) {
            await entity.copy(p.join(newBackups.path, p.basename(entity.path)));
            await entity.delete();
          }
        }
        await oldBackups.delete();
      }

      // Also migrate images directory
      final oldImages = Directory(p.join(oldDir.path, 'images'));
      final newImages = Directory(p.join(newDir.path, 'images'));
      if (await oldImages.exists() && !await newImages.exists()) {
        await newImages.create(recursive: true);
        await for (final entity in oldImages.list()) {
          if (entity is File) {
            await entity.copy(p.join(newImages.path, p.basename(entity.path)));
            await entity.delete();
          }
        }
        await oldImages.delete();
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Read config from the default location (for storagePath persistence).
  static Future<Map<String, dynamic>> _readConfigFromDefault() async {
    final file = await _getConfigFile();
    if (!await file.exists()) return {};
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Write config to the default location.
  static Future<void> _writeConfigToDefault(Map<String, dynamic> config) async {
    final file = await _getConfigFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
    );
  }

  static Future<File> _getFile(String name) async {
    final appDir = await getAppDir();
    return File(p.join(appDir.path, name));
  }

  // ── Data persistence ──

  static Future<DeviceData> load() async {
    final file = await _getFile(_dataFileName);
    if (!await file.exists()) return const DeviceData();
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const DeviceData();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return DeviceData.fromJson(json);
  }

  static Future<void> save(DeviceData data) async {
    final file = await _getFile(_dataFileName);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await file.writeAsString(jsonStr);
    AutoSyncService.instance.notifySaved();
  }

  /// Add a new device or update an existing one (matched by id).
  static Future<void> addOrUpdate(Device device) async {
    final data = await load();
    final devices = List<Device>.of(data.devices);
    final idx = devices.indexWhere((d) => d.id == device.id);
    if (idx >= 0) {
      devices[idx] = device;
    } else {
      devices.add(device);
    }
    await save(DeviceData(devices: devices));
    if (!device.isInService) {
      await _removeDeviceReferences(device.id);
    }
  }

  /// Delete a device by id and clean up references in other modules.
  static Future<void> deleteDevice(String id) async {
    final data = await load();
    final devices = data.devices.where((d) => d.id != id).toList();
    await save(DeviceData(devices: devices));
    await _removeDeviceReferences(id);
  }

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
      await DataSetStorage.save(DataSetData(datasets: cleanedDatasets));
    }
  }

  // ── Config persistence (theme, locale) ──

  static Future<Map<String, dynamic>> readConfig() async {
    final file = await _getFile(_configFileName);
    if (!await file.exists()) return {};
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> writeConfig(Map<String, dynamic> config) async {
    final file = await _getFile(_configFileName);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
    );
  }

  static Future<String?> getThemeMode() async {
    final config = await readConfig();
    return config['themeMode'] as String?;
  }

  static Future<void> setThemeMode(String? mode) async {
    final config = await readConfig();
    if (mode == null) {
      config.remove('themeMode');
    } else {
      config['themeMode'] = mode;
    }
    await writeConfig(config);
  }

  static Future<String?> getLocaleTag() async {
    final config = await readConfig();
    return config['locale'] as String?;
  }

  static Future<void> setLocaleTag(String? tag) async {
    final config = await readConfig();
    if (tag == null) {
      config.remove('locale');
    } else {
      config['locale'] = tag;
    }
    await writeConfig(config);
  }
}
