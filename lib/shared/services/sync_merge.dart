import 'dart:convert';

import '../../features/datasets/models/dataset.dart';
import '../../features/devices/models/device.dart';
import '../../features/network/models/network.dart';
import '../../features/services/models/service.dart';
import '../utils/json_preservation.dart';

// ─── Generic record merge ───────────────────────────────────────────

/// A single record-level conflict: same ID, both sides changed since base.
class RecordConflict<T> {
  final String id;
  final T localRecord;
  final T remoteRecord;
  final String displayName;

  /// Purpose: Create a record conflict instance.
  /// Inputs: None.
  /// Returns: A new `RecordConflict` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
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

  /// Purpose: Create a record merge result instance.
  /// Inputs: `conflicts`.
  /// Returns: A new `RecordMergeResult` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  const RecordMergeResult({required this.merged, this.conflicts = const []});
}

/// Purpose: Implement the merge records behavior for this file.
/// Inputs: `autoResolve`.
/// Returns: `RecordMergeResult<T>`.
/// Side effects: May read or mutate application state, storage, or service resources.
/// Notes: None.
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
  T Function(T primary, T secondary, T? base)? mergeUnknownFields,
  bool autoResolve = false,
}) {
  final localMap = {for (final r in local) getId(r): r};
  final remoteMap = {for (final r in remote) getId(r): r};
  final baseMap = base != null
      ? {for (final r in base) getId(r): r}
      : <String, T>{};

  final allIds = {...localMap.keys, ...remoteMap.keys, ...baseMap.keys};
  final merged = <T>[];
  final conflicts = <RecordConflict<T>>[];
  T preserveUnknown(T primary, T secondary, T? base) =>
      mergeUnknownFields?.call(primary, secondary, base) ?? primary;

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
            final primary = getModifiedAt(l).isAfter(getModifiedAt(r)) ? l : r;
            final secondary = identical(primary, l) ? r : l;
            merged.add(preserveUnknown(primary, secondary, b));
          } else {
            conflicts.add(
              RecordConflict(
                id: id,
                localRecord: preserveUnknown(l, r, b),
                remoteRecord: preserveUnknown(r, l, b),
                displayName: getDisplayName(l),
              ),
            );
          }
        } else if (localChanged) {
          merged.add(preserveUnknown(l, r, b));
        } else if (remoteChanged) {
          merged.add(preserveUnknown(r, l, b));
        } else {
          merged.add(preserveUnknown(l, r, b)); // neither changed
        }
      } else {
        // No base — first sync or both added same ID
        final primary = getModifiedAt(l).isAfter(getModifiedAt(r)) ? l : r;
        final secondary = identical(primary, l) ? r : l;
        merged.add(preserveUnknown(primary, secondary, null));
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

/// Purpose: Implement the merge assignments behavior for this file.
/// Inputs: `local`, `remote`, `base`.
/// Returns: `List<NetworkDevice>`.
/// Side effects: May read or mutate application state, storage, or service resources.
/// Notes: None.
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
  final baseMap = base != null
      ? {for (final a in base) key(a): a}
      : <String, NetworkDevice>{};
  final baseContent = base != null
      ? {for (final a in base) key(a): content(a)}
      : <String, String>{};

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
          merged.add(r.mergeUnknownFieldsFrom(l, base: b));
        } else {
          merged.add(l.mergeUnknownFieldsFrom(r, base: b));
        }
      } else {
        merged.add(l.mergeUnknownFieldsFrom(r)); // both new, use local
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
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a device merge result instance.
  /// Inputs: `conflicts`.
  /// Returns: A new `DeviceMergeResult` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  const DeviceMergeResult({
    required this.merged,
    this.conflicts = const [],
    this.extraJson = const {},
  });

  /// Purpose: Return the current has conflicts value.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasConflicts => conflicts.isNotEmpty;

  /// Purpose: Build and return resolved for the current context.
  /// Inputs: `resolutions`.
  /// Returns: `DeviceData`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  DeviceData buildResolved(Map<String, Device> resolutions) {
    final all = <Device>[...merged];
    for (final c in conflicts) {
      all.add(resolutions[c.id] ?? c.localRecord);
    }
    return DeviceData(devices: all, extraJson: extraJson);
  }
}

/// Purpose: Implement the merge device data behavior for this file.
/// Inputs: `localJson`, `remoteJson`, `baseJson`.
/// Returns: `DeviceMergeResult`.
/// Side effects: May read or mutate application state, storage, or service resources.
/// Notes: None.
DeviceMergeResult mergeDeviceData(
  String localJson,
  String remoteJson,
  String? baseJson, {
  bool autoResolve = false,
}) {
  final local = DeviceData.fromJson(
    jsonDecode(localJson) as Map<String, dynamic>,
  );
  final remote = DeviceData.fromJson(
    jsonDecode(remoteJson) as Map<String, dynamic>,
  );
  final base = baseJson != null
      ? DeviceData.fromJson(jsonDecode(baseJson) as Map<String, dynamic>)
      : null;
  final extraJson = mergeUnknownJsonFields(
    primary: local.extraJson,
    secondary: remote.extraJson,
    base: base?.extraJson,
  );

  final result = mergeRecords<Device>(
    local: local.devices,
    remote: remote.devices,
    base: base?.devices,
    getId: (d) => d.id,
    getModifiedAt: (d) => d.modifiedAt,
    getDisplayName: (d) => d.name,
    mergeUnknownFields: (primary, secondary, base) =>
        primary.mergeUnknownFieldsFrom(secondary, base: base),
    autoResolve: autoResolve,
  );

  return DeviceMergeResult(
    merged: result.merged,
    conflicts: result.conflicts,
    extraJson: extraJson,
  );
}

// ─── Network data merge ─────────────────────────────────────────────

class NetworkMergeResult {
  final List<Network> mergedNetworks;
  final List<NetworkDevice> mergedAssignments;
  final List<RecordConflict<Network>> conflicts;
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a network merge result instance.
  /// Inputs: `conflicts`.
  /// Returns: A new `NetworkMergeResult` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  const NetworkMergeResult({
    required this.mergedNetworks,
    required this.mergedAssignments,
    this.conflicts = const [],
    this.extraJson = const {},
  });

  /// Purpose: Return the current has conflicts value.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasConflicts => conflicts.isNotEmpty;

  /// Purpose: Build and return resolved for the current context.
  /// Inputs: `resolutions`.
  /// Returns: `NetworkData`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  NetworkData buildResolved(Map<String, Network> resolutions) {
    final all = <Network>[...mergedNetworks];
    for (final c in conflicts) {
      all.add(resolutions[c.id] ?? c.localRecord);
    }
    return NetworkData(
      networks: all,
      assignments: mergedAssignments,
      extraJson: extraJson,
    );
  }
}

/// Purpose: Implement the merge network data behavior for this file.
/// Inputs: `localJson`, `remoteJson`, `baseJson`.
/// Returns: `NetworkMergeResult`.
/// Side effects: May read or mutate application state, storage, or service resources.
/// Notes: None.
NetworkMergeResult mergeNetworkData(
  String localJson,
  String remoteJson,
  String? baseJson, {
  bool autoResolve = false,
}) {
  final local = NetworkData.fromJson(
    jsonDecode(localJson) as Map<String, dynamic>,
  );
  final remote = NetworkData.fromJson(
    jsonDecode(remoteJson) as Map<String, dynamic>,
  );
  final base = baseJson != null
      ? NetworkData.fromJson(jsonDecode(baseJson) as Map<String, dynamic>)
      : null;
  final extraJson = mergeUnknownJsonFields(
    primary: local.extraJson,
    secondary: remote.extraJson,
    base: base?.extraJson,
  );

  final networkResult = mergeRecords<Network>(
    local: local.networks,
    remote: remote.networks,
    base: base?.networks,
    getId: (n) => n.id,
    getModifiedAt: (n) => n.modifiedAt,
    getDisplayName: (n) => n.name,
    mergeUnknownFields: (primary, secondary, base) =>
        primary.mergeUnknownFieldsFrom(secondary, base: base),
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
    extraJson: extraJson,
  );
}

// ─── DataSet data merge ─────────────────────────────────────────────

class DataSetMergeResult {
  final List<DataSet> merged;
  final List<RecordConflict<DataSet>> conflicts;
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a data set merge result instance.
  /// Inputs: `conflicts`.
  /// Returns: A new `DataSetMergeResult` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  const DataSetMergeResult({
    required this.merged,
    this.conflicts = const [],
    this.extraJson = const {},
  });

  /// Purpose: Return the current has conflicts value.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasConflicts => conflicts.isNotEmpty;

  /// Purpose: Build and return resolved for the current context.
  /// Inputs: `resolutions`.
  /// Returns: `DataSetData`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  DataSetData buildResolved(Map<String, DataSet> resolutions) {
    final all = <DataSet>[...merged];
    for (final c in conflicts) {
      all.add(resolutions[c.id] ?? c.localRecord);
    }
    return DataSetData(datasets: all, extraJson: extraJson);
  }
}

/// Purpose: Implement the merge data set data behavior for this file.
/// Inputs: `localJson`, `remoteJson`, `baseJson`.
/// Returns: `DataSetMergeResult`.
/// Side effects: May read or mutate application state, storage, or service resources.
/// Notes: None.
DataSetMergeResult mergeDataSetData(
  String localJson,
  String remoteJson,
  String? baseJson, {
  bool autoResolve = false,
}) {
  final local = DataSetData.fromJson(
    jsonDecode(localJson) as Map<String, dynamic>,
  );
  final remote = DataSetData.fromJson(
    jsonDecode(remoteJson) as Map<String, dynamic>,
  );
  final base = baseJson != null
      ? DataSetData.fromJson(jsonDecode(baseJson) as Map<String, dynamic>)
      : null;
  final extraJson = mergeUnknownJsonFields(
    primary: local.extraJson,
    secondary: remote.extraJson,
    base: base?.extraJson,
  );

  final result = mergeRecords<DataSet>(
    local: local.datasets,
    remote: remote.datasets,
    base: base?.datasets,
    getId: (d) => d.id,
    getModifiedAt: (d) => d.modifiedAt,
    getDisplayName: (d) => d.name,
    mergeUnknownFields: (primary, secondary, base) =>
        primary.mergeUnknownFieldsFrom(secondary, base: base),
    autoResolve: autoResolve,
  );

  return DataSetMergeResult(
    merged: result.merged,
    conflicts: result.conflicts,
    extraJson: extraJson,
  );
}

// ─── Service data merge ─────────────────────────────────────────────

class ServiceMergeResult {
  final List<ServiceNode> mergedServices;
  final List<ServiceRoute> mergedRoutes;
  final List<RecordConflict<ServiceNode>> serviceConflicts;
  final List<RecordConflict<ServiceRoute>> routeConflicts;
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a service merge result instance.
  /// Inputs: `serviceConflicts`.
  /// Returns: A new `ServiceMergeResult` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  const ServiceMergeResult({
    required this.mergedServices,
    required this.mergedRoutes,
    this.serviceConflicts = const [],
    this.routeConflicts = const [],
    this.extraJson = const {},
  });

  /// Purpose: Return the current has conflicts value.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasConflicts =>
      serviceConflicts.isNotEmpty || routeConflicts.isNotEmpty;

  /// Purpose: Return the current all conflicts value.
  /// Inputs: None.
  /// Returns: `List<RecordConflict>`.
  /// Side effects: None.
  /// Notes: None.
  List<RecordConflict> get allConflicts => [
    ...serviceConflicts,
    ...routeConflicts,
  ];

  /// Purpose: Build and return resolved for the current context.
  /// Inputs: `resolutions`.
  /// Returns: `ServiceData`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  ServiceData buildResolved(Map<String, dynamic> resolutions) {
    final services = <ServiceNode>[...mergedServices];
    for (final c in serviceConflicts) {
      final chosen = resolutions[c.id];
      services.add(chosen is ServiceNode ? chosen : c.localRecord);
    }

    final routes = <ServiceRoute>[...mergedRoutes];
    for (final c in routeConflicts) {
      final chosen = resolutions[c.id];
      routes.add(chosen is ServiceRoute ? chosen : c.localRecord);
    }

    return ServiceData(
      services: services,
      routes: routes,
      extraJson: extraJson,
    );
  }
}

/// Purpose: Implement the merge service data behavior for this file.
/// Inputs: `localJson`, `remoteJson`, `baseJson`.
/// Returns: `ServiceMergeResult`.
/// Side effects: May read or mutate application state, storage, or service resources.
/// Notes: None.
ServiceMergeResult mergeServiceData(
  String localJson,
  String remoteJson,
  String? baseJson, {
  bool autoResolve = false,
}) {
  final local = ServiceData.fromJson(
    jsonDecode(localJson) as Map<String, dynamic>,
  );
  final remote = ServiceData.fromJson(
    jsonDecode(remoteJson) as Map<String, dynamic>,
  );
  final base = baseJson != null
      ? ServiceData.fromJson(jsonDecode(baseJson) as Map<String, dynamic>)
      : null;
  final extraJson = mergeUnknownJsonFields(
    primary: local.extraJson,
    secondary: remote.extraJson,
    base: base?.extraJson,
  );

  final serviceResult = mergeRecords<ServiceNode>(
    local: local.services,
    remote: remote.services,
    base: base?.services,
    getId: (s) => s.id,
    getModifiedAt: (s) => s.modifiedAt,
    getDisplayName: (s) => s.name,
    mergeUnknownFields: (primary, secondary, base) =>
        primary.mergeUnknownFieldsFrom(secondary, base: base),
    autoResolve: autoResolve,
  );

  final routeResult = mergeRecords<ServiceRoute>(
    local: local.routes,
    remote: remote.routes,
    base: base?.routes,
    getId: (r) => r.id,
    getModifiedAt: (r) => r.modifiedAt,
    getDisplayName: (r) => r.name,
    mergeUnknownFields: (primary, secondary, base) =>
        primary.mergeUnknownFieldsFrom(secondary, base: base),
    autoResolve: autoResolve,
  );

  return ServiceMergeResult(
    mergedServices: serviceResult.merged,
    mergedRoutes: routeResult.merged,
    serviceConflicts: serviceResult.conflicts,
    routeConflicts: routeResult.conflicts,
    extraJson: extraJson,
  );
}
