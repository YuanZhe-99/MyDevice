import 'dart:io';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../features/devices/services/device_storage.dart';

class ImportExportService {
  static const _dataFileNames = [
    'device_data.json',
    'network_data.json',
    'dataset_data.json',
  ];

  /// Export all data and images as a ZIP file.
  /// Returns the exported file path, or null on failure.
  static Future<String?> exportZip(String destDir) async {
    try {
      final appDir = await DeviceStorage.getAppDir();
      final archive = Archive();

      // Add data files
      for (final name in _dataFileNames) {
        final file = File(p.join(appDir.path, name));
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
        }
      }

      // Add images
      final imagesDir = Directory(p.join(appDir.path, 'images'));
      if (await imagesDir.exists()) {
        await for (final entity in imagesDir.list()) {
          if (entity is File) {
            final bytes = await entity.readAsBytes();
            final name = 'images/${p.basename(entity.path)}';
            archive.addFile(ArchiveFile(name, bytes.length, bytes));
          }
        }
      }

      final zipBytes = ZipEncoder().encode(archive);

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final outFile = File(p.join(destDir, 'mydevice_export_$stamp.zip'));
      await outFile.writeAsBytes(zipBytes);
      return outFile.path;
    } catch (_) {
      return null;
    }
  }

  /// Import data from a previously exported ZIP file.
  /// Returns true on success.
  static Future<bool> importZip(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final appDir = await DeviceStorage.getAppDir();

      for (final entry in archive) {
        if (entry.isFile) {
          final outFile = File(p.join(appDir.path, entry.name));
          final parentDir = outFile.parent;
          if (!await parentDir.exists()) {
            await parentDir.create(recursive: true);
          }
          await outFile.writeAsBytes(entry.content as List<int>);
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
