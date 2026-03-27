import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../features/devices/services/device_storage.dart';

/// Manages local backups with manual/auto creation and retention policies.
class BackupService {
  static const _backupDir = 'backups';

  static bool autoBackupEnabled = false;
  static int retentionDays = 0; // 0 = keep forever
  static DateTime? _lastAutoBackup;

  /// Data module identifiers used for per-module restore.
  static const modules = <String, String>{
    'device_data.json': 'devices',
    'network_data.json': 'networks',
    'dataset_data.json': 'datasets',
  };

  static Future<Directory> _getBackupDir() async {
    final appDir = await DeviceStorage.getAppDir();
    final dir = Directory(p.join(appDir.path, _backupDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Load backup settings from config.
  static Future<void> loadSettings() async {
    final config = await DeviceStorage.readConfig();
    autoBackupEnabled = config['autoBackupEnabled'] as bool? ?? false;
    retentionDays = config['backupRetentionDays'] as int? ?? 0;
  }

  /// Save backup settings to config.
  static Future<void> saveSettings() async {
    final config = await DeviceStorage.readConfig();
    config['autoBackupEnabled'] = autoBackupEnabled;
    config['backupRetentionDays'] = retentionDays;
    await DeviceStorage.writeConfig(config);
  }

  /// Create a backup now. Returns the backup file, or null on failure.
  static Future<File?> createBackup() async {
    try {
      final appDir = await DeviceStorage.getAppDir();
      final backupDir = await _getBackupDir();
      final bundle = <String, dynamic>{};

      for (final name in modules.keys) {
        final file = File(p.join(appDir.path, name));
        if (await file.exists()) {
          bundle[name] = await file.readAsString();
        }
      }

      // Include images as base64
      final imagesDir = Directory(p.join(appDir.path, 'images'));
      if (await imagesDir.exists()) {
        final imageBundle = <String, String>{};
        await for (final entity in imagesDir.list()) {
          if (entity is File) {
            final bytes = await entity.readAsBytes();
            imageBundle[p.basename(entity.path)] = base64Encode(bytes);
          }
        }
        if (imageBundle.isNotEmpty) {
          bundle['_images'] = imageBundle;
        }
      }

      final jsonStr = jsonEncode(bundle);

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File(p.join(backupDir.path, 'backup_$stamp.json'));
      await file.writeAsString(jsonStr);

      await _cleanOldBackups();
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Run auto-backup if enabled and not yet done today.
  static Future<void> runAutoBackupIfNeeded() async {
    await loadSettings();
    if (!autoBackupEnabled) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastAutoBackup != null) {
      final lastDay = DateTime(
        _lastAutoBackup!.year,
        _lastAutoBackup!.month,
        _lastAutoBackup!.day,
      );
      if (!lastDay.isBefore(today)) return;
    }

    final existing = await listBackups();
    final alreadyToday = existing.any((b) {
      final d = b.date;
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    });
    if (alreadyToday) {
      _lastAutoBackup = now;
      return;
    }

    await createBackup();
    _lastAutoBackup = now;
  }

  /// List all backups sorted by date descending.
  static Future<List<BackupInfo>> listBackups() async {
    final backupDir = await _getBackupDir();
    if (!await backupDir.exists()) return [];

    final files = <BackupInfo>[];
    await for (final entity in backupDir.list()) {
      if (entity is File &&
          p.basename(entity.path).startsWith('backup_') &&
          entity.path.endsWith('.json')) {
        final stat = await entity.stat();
        final name = p.basenameWithoutExtension(entity.path);
        DateTime? date;
        try {
          final parts = name.replaceFirst('backup_', '');
          date = DateFormat('yyyyMMdd_HHmmss').parse(parts);
        } catch (_) {
          date = stat.modified;
        }
        files.add(BackupInfo(
          file: entity,
          date: date,
          sizeBytes: stat.size,
        ));
      }
    }
    files.sort((a, b) => b.date.compareTo(a.date));
    return files;
  }

  /// Read a backup's content and return module names it contains.
  static Future<List<String>> getBackupModules(File file) async {
    try {
      final raw = await file.readAsString();
      final bundle = jsonDecode(raw) as Map<String, dynamic>;
      final result = modules.entries
          .where((e) => bundle.containsKey(e.key))
          .map((e) => e.value)
          .toList();
      if (bundle.containsKey('_images')) {
        result.add('images');
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Restore from a backup file, optionally only specific modules.
  static Future<bool> restoreBackup(
    File file, {
    Set<String>? moduleKeys,
  }) async {
    try {
      final raw = await file.readAsString();

      final bundle = jsonDecode(raw) as Map<String, dynamic>;
      final appDir = await DeviceStorage.getAppDir();

      for (final entry in modules.entries) {
        final fileName = entry.key;
        final moduleId = entry.value;
        if (moduleKeys != null && !moduleKeys.contains(moduleId)) continue;
        if (!bundle.containsKey(fileName)) continue;
        final outFile = File(p.join(appDir.path, fileName));
        await outFile.writeAsString(bundle[fileName] as String);
      }

      // Restore images
      if (bundle.containsKey('_images') &&
          (moduleKeys == null || moduleKeys.contains('images'))) {
        final imageBundle =
            (bundle['_images'] as Map<String, dynamic>).cast<String, String>();
        final imagesDir = Directory(p.join(appDir.path, 'images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        for (final entry in imageBundle.entries) {
          final outFile = File(p.join(imagesDir.path, entry.key));
          await outFile.writeAsBytes(base64Decode(entry.value));
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Delete a specific backup.
  static Future<void> deleteBackup(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> _cleanOldBackups() async {
    if (retentionDays <= 0) return;
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    final backups = await listBackups();
    for (final b in backups) {
      if (b.date.isBefore(cutoff)) {
        await b.file.delete();
      }
    }
  }
}

class BackupInfo {
  final File file;
  final DateTime date;
  final int sizeBytes;

  const BackupInfo({
    required this.file,
    required this.date,
    required this.sizeBytes,
  });

  String get displaySize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
