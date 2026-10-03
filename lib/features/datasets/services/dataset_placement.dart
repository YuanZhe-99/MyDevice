import '../../devices/models/device.dart';
import '../models/dataset.dart';

/// How the dataset list groups its tiles.
enum DataSetGroupMode { none, device, storage }

/// One copy of a data set: the device and the storage slot that hold it.
class DataSetReplica {
  final DataSet dataSet;
  final Device device;
  final int storageIndex;

  /// Purpose: Create a replica.
  /// Inputs: `dataSet`, `device`, `storageIndex` — a valid index into
  /// `device.storage`.
  /// Returns: A new `DataSetReplica`.
  /// Side effects: None.
  /// Notes: Built only by [resolveReplicas], which drops dangling links.
  const DataSetReplica({
    required this.dataSet,
    required this.device,
    required this.storageIndex,
  });

  /// Purpose: Return the storage slot this copy lives on.
  /// Inputs: None.
  /// Returns: `StorageInfo`.
  /// Side effects: None.
  /// Notes: None.
  StorageInfo get storage => device.storage[storageIndex];
}

/// Purpose: Resolve a data set's storage links to the copies that exist.
/// Inputs: `dataSet`; `devices` — the current device list.
/// Returns: One `DataSetReplica` per linked storage slot, in link order and
/// then slot order; links to a deleted device or an out-of-range slot are
/// skipped, and a slot listed twice counts once.
/// Side effects: None.
/// Notes: Every linked slot holds a full, equal copy — a data set is never
/// split across storages — so the length is the copy count.
List<DataSetReplica> resolveReplicas(DataSet dataSet, List<Device> devices) {
  final byId = {for (final device in devices) device.id: device};
  final seen = <String>{};
  final replicas = <DataSetReplica>[];
  for (final link in dataSet.storageLinks) {
    final device = byId[link.deviceId];
    if (device == null) continue;
    for (final index in link.storageIndices) {
      if (index < 0 || index >= device.storage.length) continue;
      if (!seen.add('${device.id}#$index')) continue;
      replicas.add(
        DataSetReplica(dataSet: dataSet, device: device, storageIndex: index),
      );
    }
  }
  return replicas;
}

/// One group of the dataset list: a device, one storage slot of a device, or
/// the data sets that are on no storage.
class DataSetGroup {
  /// `device:<id>`, `storage:<id>:<index>` or `unlinked`.
  final String key;
  final Device? device;
  final int? storageIndex;
  final List<DataSet> dataSets;

  /// Purpose: Create a group.
  /// Inputs: `key`; `device` — null for the unlinked group; `storageIndex` —
  /// set for a storage group only; `dataSets` — in list order.
  /// Returns: A new `DataSetGroup`.
  /// Side effects: None.
  /// Notes: None.
  const DataSetGroup({
    required this.key,
    this.device,
    this.storageIndex,
    required this.dataSets,
  });

  /// Purpose: Tell whether this is the group of data sets on no storage.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isUnlinked => device == null;
}

/// Purpose: Group data sets by the device or the storage slot holding them.
/// Inputs: `dataSets` — already sorted for display; `devices` — the device
/// list, whose order the groups follow; `mode` — must not be
/// `DataSetGroupMode.none`.
/// Returns: The non-empty groups: devices in device-list order (storage
/// groups also by slot index), then the unlinked group when any data set
/// resolves to no copy.
/// Side effects: None.
/// Notes: A data set with copies in several places appears in each of their
/// groups — once per device in device mode, however many of its slots it
/// uses. Within a group the input order is kept.
List<DataSetGroup> groupDataSets(
  List<DataSet> dataSets,
  List<Device> devices,
  DataSetGroupMode mode,
) {
  assert(mode != DataSetGroupMode.none);
  final buckets = <String, List<DataSet>>{};
  final unlinked = <DataSet>[];
  for (final ds in dataSets) {
    final replicas = resolveReplicas(ds, devices);
    if (replicas.isEmpty) {
      unlinked.add(ds);
      continue;
    }
    final keys = <String>{
      for (final r in replicas)
        mode == DataSetGroupMode.device
            ? 'device:${r.device.id}'
            : 'storage:${r.device.id}:${r.storageIndex}',
    };
    for (final key in keys) {
      buckets.putIfAbsent(key, () => []).add(ds);
    }
  }
  final groups = <DataSetGroup>[];
  for (final device in devices) {
    if (mode == DataSetGroupMode.device) {
      final key = 'device:${device.id}';
      final list = buckets[key];
      if (list != null) {
        groups.add(DataSetGroup(key: key, device: device, dataSets: list));
      }
      continue;
    }
    for (var i = 0; i < device.storage.length; i++) {
      final key = 'storage:${device.id}:$i';
      final list = buckets[key];
      if (list != null) {
        groups.add(
          DataSetGroup(
            key: key,
            device: device,
            storageIndex: i,
            dataSets: list,
          ),
        );
      }
    }
  }
  if (unlinked.isNotEmpty) {
    groups.add(DataSetGroup(key: 'unlinked', dataSets: unlinked));
  }
  return groups;
}

/// Purpose: Name a storage slot so it is unique on its device.
/// Inputs: `device`; `index` — the slot; `fallback` — the localized
/// "Storage n" text for a slot whose fields are all empty, given the
/// 1-based number.
/// Returns: `StorageInfo.displayString`, or the fallback when that is empty;
/// with ` #n` appended when another slot of the device has the same text.
/// Side effects: None.
/// Notes: Used by the grouped list headers and the topology's storage boxes.
String storageSlotLabel(
  Device device,
  int index,
  String Function(int number) fallback,
) {
  /// Purpose: Return one slot's label before de-duplication.
  /// Inputs: `i` — the slot index.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Local helper of [storageSlotLabel].
  String base(int i) {
    final text = device.storage[i].displayString;
    return text.isEmpty ? fallback(i + 1) : text;
  }

  final label = base(index);
  var duplicate = false;
  for (var i = 0; i < device.storage.length; i++) {
    if (i != index && base(i) == label) duplicate = true;
  }
  return duplicate ? '$label #${index + 1}' : label;
}
