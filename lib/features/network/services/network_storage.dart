import 'dart:convert';
import 'dart:io';

import '../../../features/devices/services/device_storage.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../models/network.dart';

class NetworkStorage {
  static const _dataFileName = 'network_data.json';

  static Future<File> _getFile() async {
    final appDir = await DeviceStorage.getAppDir();
    return File('${appDir.path}/$_dataFileName');
  }

  static Future<NetworkData> load() async {
    final file = await _getFile();
    if (!await file.exists()) return const NetworkData();
    var raw = await file.readAsString();
    if (raw.trim().isEmpty) return const NetworkData();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return NetworkData.fromJson(json);
  }

  static Future<void> save(NetworkData data) async {
    final file = await _getFile();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await file.writeAsString(jsonStr);
    AutoSyncService.instance.notifySaved();
  }

  static Future<void> addOrUpdateNetwork(Network network) async {
    final data = await load();
    final networks = List<Network>.of(data.networks);
    final idx = networks.indexWhere((n) => n.id == network.id);
    if (idx >= 0) {
      networks[idx] = network;
    } else {
      networks.add(network);
    }
    await save(NetworkData(networks: networks, assignments: data.assignments));
  }

  static Future<void> deleteNetwork(String id) async {
    final data = await load();
    final networks = data.networks.where((n) => n.id != id).toList();
    final assignments = data.assignments
        .where((a) => a.networkId != id)
        .toList();
    await save(NetworkData(networks: networks, assignments: assignments));
  }

  static Future<void> setAssignment(NetworkDevice assignment) async {
    final data = await load();
    final assignments = List<NetworkDevice>.of(data.assignments);
    final idx = assignments.indexWhere(
      (a) =>
          a.networkId == assignment.networkId &&
          a.deviceId == assignment.deviceId,
    );
    if (idx >= 0) {
      assignments[idx] = assignment;
    } else {
      assignments.add(assignment);
    }
    await save(NetworkData(networks: data.networks, assignments: assignments));
  }

  static Future<void> removeAssignment(
    String networkId,
    String deviceId,
  ) async {
    final data = await load();
    final assignments = data.assignments
        .where((a) => !(a.networkId == networkId && a.deviceId == deviceId))
        .toList();
    await save(NetworkData(networks: data.networks, assignments: assignments));
  }
}
