import 'dart:io';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../features/datasets/services/dataset_storage.dart';
import '../../features/devices/models/device.dart';
import '../../features/devices/services/device_storage.dart';
import '../../features/network/models/network.dart';
import '../../features/network/services/network_storage.dart';

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

  /// Export all data as a Markdown file for LLM personalization.
  /// Returns the exported file path, or null on failure.
  static Future<String?> exportMarkdown(String destDir) async {
    try {
      final deviceData = await DeviceStorage.load();
      final networkData = await NetworkStorage.load();
      final datasetData = await DataSetStorage.load();

      final devices = List<Device>.from(deviceData.devices)
        ..sort((a, b) {
          if (a.purchaseDate == null && b.purchaseDate == null) {
            return a.name.compareTo(b.name);
          }
          if (a.purchaseDate == null) return 1;
          if (b.purchaseDate == null) return -1;
          return a.purchaseDate!.compareTo(b.purchaseDate!);
        });

      final deviceMap = {for (final d in deviceData.devices) d.id: d};

      final buf = StringBuffer();
      buf.writeln('# MyDevice!!!!! — Device Inventory');
      buf.writeln();
      buf.writeln(
          'Exported: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
      buf.writeln(
          'Total: ${devices.length} devices, ${networkData.networks.length} networks, ${datasetData.datasets.length} datasets');
      buf.writeln();
      buf.writeln('---');

      // ── Devices ──
      if (devices.isNotEmpty) {
        buf.writeln();
        buf.writeln('# Devices');

        for (final d in devices) {
          buf.writeln();
          final title = d.emoji != null ? '${d.emoji} ${d.name}' : d.name;
          buf.writeln('## $title');
          buf.writeln();

          buf.writeln('- **Category:** ${_categoryLabel(d.category)}');
          if (d.brand != null) buf.writeln('- **Brand:** ${d.brand}');
          if (d.model != null) buf.writeln('- **Model:** ${d.model}');
          if (d.serialNumber != null) {
            buf.writeln('- **Serial Number:** ${d.serialNumber}');
          }

          // CPU
          if (!d.cpu.isEmpty) {
            final parts = <String>[];
            if (d.cpu.model != null) parts.add(d.cpu.model!);
            if (d.cpu.architecture != null) parts.add(d.cpu.architecture!);
            if (d.cpu.frequency != null) parts.add(d.cpu.frequency!);
            final cores = <String>[];
            if (d.cpu.performanceCores != null) {
              cores.add('${d.cpu.performanceCores}P');
            }
            if (d.cpu.efficiencyCores != null) {
              cores.add('${d.cpu.efficiencyCores}E');
            }
            if (cores.isNotEmpty) parts.add('${cores.join('+')} cores');
            if (d.cpu.threads != null) parts.add('${d.cpu.threads}T');
            if (d.cpu.cache != null) parts.add(d.cpu.cache!);
            buf.writeln('- **CPU:** ${parts.join(', ')}');
          }

          // GPU
          if (!d.gpu.isEmpty) {
            final parts = <String>[];
            if (d.gpu.model != null) parts.add(d.gpu.model!);
            if (d.gpu.architecture != null) parts.add('(${d.gpu.architecture})');
            buf.writeln('- **GPU:** ${parts.join(' ')}');
          }

          // RAM
          if (d.ram != null) {
            final ramStr = d.ramType != null
                ? '${d.ram} GB ${d.ramType!.displayName}'
                : '${d.ram} GB';
            buf.writeln('- **RAM:** $ramStr');
          }

          // Storage
          for (final s in d.storage) {
            if (!s.isEmpty) buf.writeln('- **Storage:** ${s.displayString}');
          }

          // Screen
          if (d.screenSize != null || d.screenResolutionW != null) {
            final parts = <String>[];
            if (d.screenSize != null) parts.add(d.screenSize!);
            if (d.screenResolutionW != null && d.screenResolutionH != null) {
              parts.add('${d.screenResolutionW}×${d.screenResolutionH}');
              if (d.ppi != null) parts.add('${d.ppi!.round()} PPI');
            }
            buf.writeln('- **Screen:** ${parts.join(', ')}');
          }

          if (d.battery != null) buf.writeln('- **Battery:** ${d.battery}');
          if (d.os != null) buf.writeln('- **OS:** ${d.os}');
          if (d.locationName != null) {
            buf.writeln('- **Location:** ${d.locationName}');
          }
          if (d.purchaseDate != null) {
            buf.writeln(
                '- **Purchase Date:** ${DateFormat('yyyy-MM-dd').format(d.purchaseDate!)}');
          }
          if (d.releaseDate != null) {
            buf.writeln(
                '- **Release Date:** ${DateFormat('yyyy-MM-dd').format(d.releaseDate!)}');
          }
          if (d.notes != null && d.notes!.isNotEmpty) {
            buf.writeln('- **Notes:** ${d.notes}');
          }
        }
      }

      // ── Networks ──
      if (networkData.networks.isNotEmpty) {
        buf.writeln();
        buf.writeln('---');
        buf.writeln();
        buf.writeln('# Networks');

        for (final n in networkData.networks) {
          buf.writeln();
          buf.writeln('## ${n.name}');
          buf.writeln();

          buf.writeln('- **Type:** ${_networkTypeLabel(n.type)}');
          if (n.subnet != null) buf.writeln('- **Subnet:** ${n.subnet}');
          if (n.gateway != null) buf.writeln('- **Gateway:** ${n.gateway}');
          if (n.dnsServers.isNotEmpty) {
            buf.writeln('- **DNS:** ${n.dnsServers.join(', ')}');
          }
          if (n.notes != null && n.notes!.isNotEmpty) {
            buf.writeln('- **Notes:** ${n.notes}');
          }

          // Devices in this network
          final assignments = networkData.assignments
              .where((a) => a.networkId == n.id)
              .toList();
          if (assignments.isNotEmpty) {
            buf.writeln();
            buf.writeln('**Devices:**');
            buf.writeln();
            for (final a in assignments) {
              final device = deviceMap[a.deviceId];
              final name = device?.name ?? a.deviceId;
              final parts = <String>[];
              if (a.ipAddress != null) parts.add(a.ipAddress!);
              if (a.hostname != null) parts.add(a.hostname!);
              parts.add(a.addressMode == AddressMode.static_
                  ? 'Static'
                  : 'DHCP');
              if (a.isExitNode) parts.add('Exit Node');
              buf.writeln('- $name — ${parts.join(', ')}');
            }
          }
        }
      }

      // ── Datasets ──
      if (datasetData.datasets.isNotEmpty) {
        buf.writeln();
        buf.writeln('---');
        buf.writeln();
        buf.writeln('# Data Sets');

        for (final ds in datasetData.datasets) {
          buf.writeln();
          buf.writeln('## ${ds.emoji} ${ds.name}');

          if (ds.storageLinks.isNotEmpty) {
            buf.writeln();
            buf.writeln('**Linked Storages:**');
            buf.writeln();
            for (final link in ds.storageLinks) {
              final device = deviceMap[link.deviceId];
              final dName = device?.name ?? link.deviceId;
              if (device != null && link.storageIndices.isNotEmpty) {
                final slots = link.storageIndices
                    .where((i) => i < device.storage.length)
                    .map((i) => device.storage[i].displayString)
                    .where((s) => s.isNotEmpty)
                    .toList();
                if (slots.isNotEmpty) {
                  buf.writeln('- $dName: ${slots.join(', ')}');
                } else {
                  buf.writeln('- $dName');
                }
              } else {
                buf.writeln('- $dName');
              }
            }
          }
        }
      }

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final outFile = File(p.join(destDir, 'mydevice_export_$stamp.md'));
      await outFile.writeAsString(buf.toString());
      return outFile.path;
    } catch (_) {
      return null;
    }
  }

  static String _categoryLabel(DeviceCategory c) => switch (c) {
        DeviceCategory.desktop => 'Desktop',
        DeviceCategory.laptop => 'Laptop',
        DeviceCategory.phone => 'Phone',
        DeviceCategory.tablet => 'Tablet',
        DeviceCategory.headphone => 'Headphone',
        DeviceCategory.watch => 'Watch',
        DeviceCategory.router => 'Router',
        DeviceCategory.gameConsole => 'Game Console',
        DeviceCategory.vps => 'VPS',
        DeviceCategory.devBoard => 'Dev Board',
        DeviceCategory.other => 'Other',
      };

  static String _networkTypeLabel(NetworkType t) => switch (t) {
        NetworkType.lan => 'LAN',
        NetworkType.tailscale => 'Tailscale',
        NetworkType.zerotier => 'ZeroTier',
        NetworkType.easytier => 'EasyTier',
        NetworkType.wireguard => 'WireGuard',
        NetworkType.other => 'Other',
      };
}
