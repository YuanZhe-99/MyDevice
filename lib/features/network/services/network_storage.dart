import 'dart:convert';
import 'dart:io';

import '../../../features/devices/services/device_storage.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../models/network.dart';

class NetworkStorage {
  static const _dataFileName = 'network_data.json';

  /// Purpose: Provide the internal get file helper for this file.
  /// Inputs: None.
  /// Returns: `Future<File>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
  static Future<File> _getFile() async {
    final appDir = await DeviceStorage.getAppDir();
    return File('${appDir.path}/$_dataFileName');
  }

  /// Purpose: Load the relevant data into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<NetworkData>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  static Future<NetworkData> load() async {
    final file = await _getFile();
    if (!await file.exists()) return const NetworkData();
    var raw = await file.readAsString();
    if (raw.trim().isEmpty) return const NetworkData();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return NetworkData.fromJson(json);
  }

  /// Purpose: Save the relevant data to the relevant storage or service layer.
  /// Inputs: `data`.
  /// Returns: `Future<void>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  static Future<void> save(NetworkData data) async {
    final file = await _getFile();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await file.writeAsString(jsonStr);
    AutoSyncService.instance.notifySaved();
  }

  /// Purpose: Add or update network through the current flow.
  /// Inputs: `network`.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
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

  /// Purpose: Delete network from the relevant storage or state.
  /// Inputs: `id`.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> deleteNetwork(String id) async {
    final data = await load();
    final networks = data.networks.where((n) => n.id != id).toList();
    final assignments = data.assignments
        .where((a) => a.networkId != id)
        .toList();
    await save(NetworkData(networks: networks, assignments: assignments));
  }

  /// Purpose: Update assignment with the provided value.
  /// Inputs: `assignment`.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
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

  /// Purpose: Implement the remove assignment behavior for this file.
  /// Inputs: `networkId`, `deviceId`.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
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
