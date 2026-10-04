import 'dart:convert';
import 'dart:io';

import '../../../app/data_modules.dart';
import '../../../features/devices/services/device_storage.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../models/network.dart';

class NetworkStorage {
  static const _dataFileName = networkDataFileName;

  /// Purpose: Serialise [operation] behind earlier writes of `networks.json`.
  /// Inputs: `operation`.
  /// Returns: `Future<void>`.
  /// Side effects: See `DeviceStorage.serializeWrite`.
  /// Notes: Internal helper used within this file only.
  static Future<void> _serialised(Future<void> Function() operation) async {
    final file = await _getFile();
    return DeviceStorage.serializeWrite(file.path, operation);
  }

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
  /// Side effects: Atomically replaces `networks.json` (queued behind earlier
  /// writes) and notifies auto-sync.
  /// Notes: Public entry point; enqueues [_write]. Code already running inside
  /// the write queue must call [_write], never this method (deadlock).
  static Future<void> save(NetworkData data) => _serialised(() => _write(data));

  /// Purpose: Write `networks.json` atomically and notify auto-sync.
  /// Inputs: `data`.
  /// Returns: `Future<void>`.
  /// Side effects: tmp-file + rename write; calls `AutoSyncService.notifySaved`.
  /// Notes: Internal helper; the unqueued primitive used from inside [_serialised].
  static Future<void> _write(NetworkData data) async {
    final file = await _getFile();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await DeviceStorage.atomicWrite(file, jsonStr);
    AutoSyncService.instance.notifySaved();
  }

  /// Purpose: Add or update network through the current flow.
  /// Inputs: `network`.
  /// Returns: `Future<void>`.
  /// Side effects: Queued read-modify-write of `networks.json`.
  /// Notes: Keeps assignments and unknown top-level fields (`extraJson`).
  static Future<void> addOrUpdateNetwork(Network network) =>
      _serialised(() async {
        final data = await load();
        final networks = List<Network>.of(data.networks);
        final idx = networks.indexWhere((n) => n.id == network.id);
        if (idx >= 0) {
          networks[idx] = network;
        } else {
          networks.add(network);
        }
        await _write(
          NetworkData(
            networks: networks,
            assignments: data.assignments,
            extraJson: data.extraJson,
          ),
        );
      });

  /// Purpose: Delete network from the relevant storage or state.
  /// Inputs: `id`.
  /// Returns: `Future<void>`.
  /// Side effects: Queued read-modify-write of `networks.json`.
  /// Notes: Also drops the network's assignments; keeps `extraJson`.
  static Future<void> deleteNetwork(String id) => _serialised(() async {
    final data = await load();
    final networks = data.networks.where((n) => n.id != id).toList();
    final assignments = data.assignments
        .where((a) => a.networkId != id)
        .toList();
    await _write(
      NetworkData(
        networks: networks,
        assignments: assignments,
        extraJson: data.extraJson,
      ),
    );
  });

  /// Purpose: Update assignment with the provided value.
  /// Inputs: `assignment`.
  /// Returns: `Future<void>`.
  /// Side effects: Queued read-modify-write of `networks.json`.
  /// Notes: Keeps `extraJson`.
  static Future<void> setAssignment(NetworkDevice assignment) =>
      _serialised(() async {
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
        await _write(
          NetworkData(
            networks: data.networks,
            assignments: assignments,
            extraJson: data.extraJson,
          ),
        );
      });

  /// Purpose: Apply a CSV batch against fresh network data in one queued write.
  /// Inputs: Updated assignments.
  /// Returns: Completion.
  /// Side effects: Atomic network write and save notification only if changed.
  /// Notes: Unrelated records survive; deleted target networks reject the batch.
  static Future<void> setAssignments(
    List<NetworkDevice> updates, {
    List<NetworkDevice>? expectedAssignments,
  }) => _serialised(() async {
    final data = await load();
    if (updates.any((a) => !data.networks.any((n) => n.id == a.networkId))) {
      throw StateError('Target network no longer exists');
    }
    final assignments = List<NetworkDevice>.of(data.assignments);
    for (final update in updates) {
      if (expectedAssignments != null) {
        final before = expectedAssignments
            .where(
              (a) =>
                  a.networkId == update.networkId &&
                  a.deviceId == update.deviceId,
            )
            .firstOrNull;
        final current = data.assignments
            .where(
              (a) =>
                  a.networkId == update.networkId &&
                  a.deviceId == update.deviceId,
            )
            .firstOrNull;
        if (jsonEncode(before?.toJson()) != jsonEncode(current?.toJson())) {
          throw StateError(
            'Membership changed since preview; reopen the import',
          );
        }
      }
      final nodeId = update.tailscale['Device ID'];
      if (expectedAssignments != null && nodeId != null) {
        final previous = data.assignments
            .where(
              (a) =>
                  a.networkId == update.networkId &&
                  a.deviceId != update.deviceId &&
                  a.tailscale['Device ID'] == nodeId,
            )
            .toList();
        for (final old in previous) {
          final expected = expectedAssignments
              .where(
                (a) =>
                    a.networkId == old.networkId && a.deviceId == old.deviceId,
              )
              .firstOrNull;
          if (jsonEncode(expected?.toJson()) != jsonEncode(old.toJson())) {
            throw StateError(
              'Node association changed since preview; reopen the import',
            );
          }
          assignments.removeWhere(
            (a) => a.networkId == old.networkId && a.deviceId == old.deviceId,
          );
        }
      }
      final index = assignments.indexWhere(
        (a) => a.networkId == update.networkId && a.deviceId == update.deviceId,
      );
      if (index < 0) {
        assignments.add(update);
      } else {
        assignments[index] = update;
      }
    }
    if (jsonEncode(assignments.map((a) => a.toJson()).toList()) ==
        jsonEncode(data.assignments.map((a) => a.toJson()).toList())) {
      return;
    }
    await _write(
      NetworkData(
        networks: data.networks,
        assignments: assignments,
        extraJson: data.extraJson,
      ),
    );
  });

  /// Purpose: Save raw configuration against the latest existing membership.
  /// Inputs: Membership draft containing format/text.
  /// Returns: Completion.
  /// Side effects: Queued atomic network write.
  /// Notes: Preserves current address/CSV fields; rejects removed memberships.
  static Future<void> setConfiguration(NetworkDevice draft) =>
      _serialised(() async {
        final data = await load();
        final index = data.assignments.indexWhere(
          (a) => a.networkId == draft.networkId && a.deviceId == draft.deviceId,
        );
        if (index < 0) throw StateError('Network membership no longer exists');
        final assignments = List<NetworkDevice>.of(data.assignments);
        assignments[index] = assignments[index].copyWith(
          configFormat: draft.configFormat,
          configText: draft.configText,
          clearConfig: draft.configText == null,
        );
        await _write(
          NetworkData(
            networks: data.networks,
            assignments: assignments,
            extraJson: data.extraJson,
          ),
        );
      });

  /// Purpose: Implement the remove assignment behavior for this file.
  /// Inputs: `networkId`, `deviceId`.
  /// Returns: `Future<void>`.
  /// Side effects: Queued read-modify-write of `networks.json`.
  /// Notes: Keeps `extraJson`.
  static Future<void> removeAssignment(String networkId, String deviceId) =>
      _serialised(() async {
        final data = await load();
        final assignments = data.assignments
            .where((a) => !(a.networkId == networkId && a.deviceId == deviceId))
            .toList();
        await _write(
          NetworkData(
            networks: data.networks,
            assignments: assignments,
            extraJson: data.extraJson,
          ),
        );
      });
}
