import 'dart:convert';

import '../../features/datasets/models/dataset.dart';
import '../../features/devices/models/device.dart';
import '../../features/network/models/network.dart';

// ─── Generic record merge ───────────────────────────────────────────

/// A single record-level conflict: same ID, both sides changed since base.
class RecordConflict<T> {
  final String id;
  final T localRecord;
  final T remoteRecord;
  final String displayName;

  const RecordConflict({
    required this.id,
    required this.localRecord,
    required this.remoteRecord,
    required this.displayName,
  });
}

/// Result of merging a list of records.
class RecordMergeResult<T> {
  final List<T> merged;
  final List<RecordConflict<T>> conflicts;

  const RecordMergeResult({required this.merged, this.conflicts = const []});
}

/// Three-way merge for a list of records by ID.
///
/// Uses [base] (last synced version) to detect which side changed:
/// - Only local changed → use local
/// - Only remote changed → use remote
/// - Both changed → conflict (or LWW when [autoResolve] is true)
/// - Neither changed → use either
/// - New record on one side only → include it
/// - Record deleted on one side, unchanged on other → exclude
/// - Record deleted on one side, modified on other → keep the modification
RecordMergeResult<T> mergeRecords<T>({
  required List<T> local,
  required List<T> remote,
  required List<T>? base,
  required String Function(T) getId,
  required DateTime Function(T) getModifiedAt,
  required String Function(T) getDisplayName,
  bool autoResolve = false,
}) {
  final localMap = {for (final r in local) getId(r): r};
  final remoteMap = {for (final r in remote) getId(r): r};
  final baseMap =
      base != null ? {for (final r in base) getId(r): r} : <String, T>{};

  final allIds = {...localMap.keys, ...remoteMap.keys, ...baseMap.keys};
  final merged = <T>[];
  final conflicts = <RecordConflict<T>>[];

  for (final id in allIds) {
    final l = localMap[id];
    final r = remoteMap[id];
    final b = baseMap[id];

    if (l != null && r != null) {
      // Both sides have the record
      if (b != null) {
        // Three-way: check who changed from base
        final localChanged = getModifiedAt(l).isAfter(getModifiedAt(b));
        final remoteChanged = getModifiedAt(r).isAfter(getModifiedAt(b));

        if (localChanged && remoteChanged) {
          if (autoResolve) {
            merged.add(getModifiedAt(l).isAfter(getModifiedAt(r)) ? l : r);
          } else {
            conflicts.add(RecordConflict(
              id: id,
              localRecord: l,
              remoteRecord: r,
              displayName: getDisplayName(l),
            ));
          }
        } else if (localChanged) {
          merged.add(l);
        } else if (remoteChanged) {
          merged.add(r);
        } else {
          merged.add(l); // neither changed
        }
      } else {
        // No base — first sync or both added same ID
        merged.add(getModifiedAt(l).isAfter(getModifiedAt(r)) ? l : r);
      }
    } else if (l != null && r == null) {
      if (b != null) {
        final localChanged = getModifiedAt(l).isAfter(getModifiedAt(b));
        if (localChanged) {
          merged.add(l); // modified locally after remote deleted → keep
        }
      } else {
        merged.add(l); // new locally → include
      }
    } else if (l == null && r != null) {
      if (b != null) {
        final remoteChanged = getModifiedAt(r).isAfter(getModifiedAt(b));
        if (remoteChanged) {
          merged.add(r); // modified remotely after local deleted → keep
        }
      } else {
        merged.add(r); // new remotely → include
      }
    }
    // else: both null, was in base → deleted both sides → exclude
  }

  return RecordMergeResult(merged: merged, conflicts: conflicts);
}

// ─── Assignment merge (no modifiedAt) ───────────────────────────────

/// Three-way merge for network-device assignments.
///
/// Assignments have no modifiedAt, so we detect changes by comparing
/// serialized content against base. Conflicts are auto-resolved to local.
List<NetworkDevice> mergeAssignments(
  List<NetworkDevice> local,
  List<NetworkDevice> remote,
  List<NetworkDevice>? base,
) {
  String key(NetworkDevice a) => '${a.networkId}:${a.deviceId}';
  String content(NetworkDevice a) => jsonEncode(a.toJson());

  final localMap = {for (final a in local) key(a): a};
  final remoteMap = {for (final a in remote) key(a): a};
  final baseMap =
      base != null ? {for (final a in base) key(a): a} : <String, NetworkDevice>{};
  final baseContent =
      base != null ? {for (final a in base) key(a): content(a)} : <String, String>{};

  final allKeys = {...localMap.keys, ...remoteMap.keys, ...baseMap.keys};
  final merged = <NetworkDevice>[];

  for (final k in allKeys) {
    final l = localMap[k];
    final r = remoteMap[k];
    final b = baseMap[k];

    if (l != null && r != null) {
      if (b != null) {
        final localChanged = content(l) != baseContent[k];
        final remoteChanged = content(r) != baseContent[k];
        // Both changed → use local (no timestamp to pick winner)
        if (remoteChanged && !localChanged) {
          merged.add(r);
        } else {
          merged.add(l);
        }
      } else {
        merged.add(l); // both new, use local
      }
    } else if (l != null && r == null) {
      if (b != null) {
        // Deleted remotely — if locally modified, keep; otherwise drop
        final localChanged = content(l) != baseContent[k];
        if (localChanged) merged.add(l);
      } else {
        merged.add(l); // new locally
      }
    } else if (l == null && r != null) {
      if (b != null) {
        final remoteChanged = content(r) != baseContent[k];
        if (remoteChanged) merged.add(r);
      } else {
        merged.add(r); // new remotely
      }
    }
  }

  return merged;
}

// ─── Device data merge ──────────────────────────────────────────────

class DeviceMergeResult {
  final List<Device> merged;
  final List<RecordConflict<Device>> conflicts;

  const DeviceMergeResult({required this.merged, this.conflicts = const []});

  bool get hasConflicts => conflicts.isNotEmpty;

  DeviceData buildResolved(Map<String, Device> resolutions) {
    final all = <Device>[...merged];
    for (final c in conflicts) {
      all.add(resolutions[c.id] ?? c.localRecord);
    }
    return DeviceData(devices: all);
  }
}

DeviceMergeResult mergeDeviceData(
  String localJson,
  String remoteJson,
  String? baseJson, {
  bool autoResolve = false,
}) {
  final local =
      DeviceData.fromJson(jsonDecode(localJson) as Map<String, dynamic>);
  final remote =
      DeviceData.fromJson(jsonDecode(remoteJson) as Map<String, dynamic>);
  final base = baseJson != null
      ? DeviceData.fromJson(jsonDecode(baseJson) as Map<String, dynamic>)
      : null;

  final result = mergeRecords<Device>(
    local: local.devices,
    remote: remote.devices,
    base: base?.devices,
    getId: (d) => d.id,
    getModifiedAt: (d) => d.modifiedAt,
    getDisplayName: (d) => d.name,
    autoResolve: autoResolve,
  );

  return DeviceMergeResult(
    merged: result.merged,
    conflicts: result.conflicts,
  );
}

// ─── Network data merge ─────────────────────────────────────────────

class NetworkMergeResult {
  final List<Network> mergedNetworks;
  final List<NetworkDevice> mergedAssignments;
  final List<RecordConflict<Network>> conflicts;

  const NetworkMergeResult({
    required this.mergedNetworks,
    required this.mergedAssignments,
    this.conflicts = const [],
  });

  bool get hasConflicts => conflicts.isNotEmpty;

  NetworkData buildResolved(Map<String, Network> resolutions) {
    final all = <Network>[...mergedNetworks];
    for (final c in conflicts) {
      all.add(resolutions[c.id] ?? c.localRecord);
    }
    return NetworkData(networks: all, assignments: mergedAssignments);
  }
}

NetworkMergeResult mergeNetworkData(
  String localJson,
  String remoteJson,
  String? baseJson, {
  bool autoResolve = false,
}) {
  final local =
      NetworkData.fromJson(jsonDecode(localJson) as Map<String, dynamic>);
  final remote =
      NetworkData.fromJson(jsonDecode(remoteJson) as Map<String, dynamic>);
  final base = baseJson != null
      ? NetworkData.fromJson(jsonDecode(baseJson) as Map<String, dynamic>)
      : null;

  final networkResult = mergeRecords<Network>(
    local: local.networks,
    remote: remote.networks,
    base: base?.networks,
    getId: (n) => n.id,
    getModifiedAt: (n) => n.modifiedAt,
    getDisplayName: (n) => n.name,
    autoResolve: autoResolve,
  );

  final assignmentResult = mergeAssignments(
    local.assignments,
    remote.assignments,
    base?.assignments,
  );

  return NetworkMergeResult(
    mergedNetworks: networkResult.merged,
    mergedAssignments: assignmentResult,
    conflicts: networkResult.conflicts,
  );
}

// ─── DataSet data merge ─────────────────────────────────────────────

class DataSetMergeResult {
  final List<DataSet> merged;
  final List<RecordConflict<DataSet>> conflicts;

  const DataSetMergeResult({required this.merged, this.conflicts = const []});

  bool get hasConflicts => conflicts.isNotEmpty;

  DataSetData buildResolved(Map<String, DataSet> resolutions) {
    final all = <DataSet>[...merged];
    for (final c in conflicts) {
      all.add(resolutions[c.id] ?? c.localRecord);
    }
    return DataSetData(datasets: all);
  }
}

DataSetMergeResult mergeDataSetData(
  String localJson,
  String remoteJson,
  String? baseJson, {
  bool autoResolve = false,
}) {
  final local =
      DataSetData.fromJson(jsonDecode(localJson) as Map<String, dynamic>);
  final remote =
      DataSetData.fromJson(jsonDecode(remoteJson) as Map<String, dynamic>);
  final base = baseJson != null
      ? DataSetData.fromJson(jsonDecode(baseJson) as Map<String, dynamic>)
      : null;

  final result = mergeRecords<DataSet>(
    local: local.datasets,
    remote: remote.datasets,
    base: base?.datasets,
    getId: (d) => d.id,
    getModifiedAt: (d) => d.modifiedAt,
    getDisplayName: (d) => d.name,
    autoResolve: autoResolve,
  );

  return DataSetMergeResult(
    merged: result.merged,
    conflicts: result.conflicts,
  );
}
