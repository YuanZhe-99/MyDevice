import '../../devices/models/device.dart';
import '../models/dataset.dart';

/// How the dataset list groups its tiles.
enum DataSetGroupMode { none, device, storage }

/// Whether a place can still serve its copy.
enum PlaceHealth {
  /// Working.
  ok,

  /// A RAID array with failed members that still holds its data.
  degraded,

  /// A failed or offline drive, or an array that lost more drives than it
  /// tolerates: the copy there does not count.
  unavailable,
}

/// Where a data set copy can live: one storage slot or one RAID array of a
/// device.
class StoragePlace {
  final Device device;

  /// The slot, for a slot place.
  final int? storageIndex;

  /// The array, for an array place.
  final StorageArray? array;

  /// Purpose: Create a slot place.
  /// Inputs: `device`; `index` — a valid index into `device.storage`.
  /// Returns: A new `StoragePlace`.
  /// Side effects: None.
  /// Notes: None.
  const StoragePlace.slot(this.device, int index)
    : storageIndex = index,
      array = null;

  /// Purpose: Create an array place.
  /// Inputs: `device`, `array` — one of `device.storageArrays`.
  /// Returns: A new `StoragePlace`.
  /// Side effects: None.
  /// Notes: None.
  const StoragePlace.array(this.device, StorageArray this.array)
    : storageIndex = null;

  /// Purpose: Tell whether this is an array place.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isArray => array != null;

  /// Purpose: Return a key unique on the device.
  /// Inputs: None.
  /// Returns: The slot index as text, or `a:<arrayId>`.
  /// Side effects: None.
  /// Notes: Used in node, group and widget ids, so a slot keeps its 1.8.x id.
  String get key => isArray ? 'a:${array!.id}' : '$storageIndex';

  /// Purpose: Return the array's member slots that exist on the device.
  /// Inputs: None.
  /// Returns: Distinct, in-range indices in stored order; empty for a slot.
  /// Side effects: None.
  /// Notes: None.
  List<int> get memberIndices {
    if (!isArray) return const [];
    final seen = <int>{};
    return [
      for (final i in array!.memberIndices)
        if (i >= 0 && i < device.storage.length && seen.add(i)) i,
    ];
  }

  /// Purpose: Count the failed or offline drives of this place.
  /// Inputs: None.
  /// Returns: For a slot 0 or 1; for an array its unhealthy members.
  /// Side effects: None.
  /// Notes: None.
  int get failedDrives => isArray
      ? memberIndices.where((i) => !device.storage[i].isHealthy).length
      : (device.storage[storageIndex!].isHealthy ? 0 : 1);

  /// Purpose: Tell whether the place can serve its copy.
  /// Inputs: None.
  /// Returns: `PlaceHealth`.
  /// Side effects: None.
  /// Notes: A slot is `unavailable` when failed or offline. An array is
  /// `degraded` while its failed members are within the level's fault
  /// tolerance, `unavailable` beyond it; a level without a defined tolerance
  /// (`other`) with failed members is `degraded`.
  PlaceHealth get health {
    final failed = failedDrives;
    if (failed == 0) return PlaceHealth.ok;
    if (!isArray) return PlaceHealth.unavailable;
    final tolerance = array!.level.faultTolerance(memberIndices.length);
    if (tolerance == null || failed <= tolerance) return PlaceHealth.degraded;
    return PlaceHealth.unavailable;
  }
}

/// Purpose: List a device's places in display order.
/// Inputs: `device`.
/// Returns: Its arrays in stored order, then the slots that are in no array.
/// Side effects: None.
/// Notes: A slot that belongs to an array is reached through the array; see
/// [resolveReplicas] for links that still point at such a slot.
List<StoragePlace> devicePlaces(Device device) {
  final inArray = <int>{};
  final places = <StoragePlace>[];
  for (final a in device.storageArrays) {
    final place = StoragePlace.array(device, a);
    inArray.addAll(place.memberIndices);
    places.add(place);
  }
  for (var i = 0; i < device.storage.length; i++) {
    if (!inArray.contains(i)) places.add(StoragePlace.slot(device, i));
  }
  return places;
}

/// One copy of a data set: the place that holds it.
class DataSetReplica {
  final DataSet dataSet;
  final StoragePlace place;

  /// Purpose: Create a replica.
  /// Inputs: `dataSet`, `place`.
  /// Returns: A new `DataSetReplica`.
  /// Side effects: None.
  /// Notes: Built only by [resolveReplicas], which drops dangling links.
  const DataSetReplica({required this.dataSet, required this.place});

  /// Purpose: Return the device holding the copy.
  /// Inputs: None.
  /// Returns: `Device`.
  /// Side effects: None.
  /// Notes: None.
  Device get device => place.device;

  /// Purpose: Return the slot of a slot copy.
  /// Inputs: None.
  /// Returns: The index, or null for an array copy.
  /// Side effects: None.
  /// Notes: None.
  int? get storageIndex => place.storageIndex;

  /// Purpose: Tell whether the copy counts.
  /// Inputs: None.
  /// Returns: False when its place is `unavailable`.
  /// Side effects: None.
  /// Notes: None.
  bool get isAvailable => place.health != PlaceHealth.unavailable;
}

/// Purpose: Resolve a data set's storage links to the copies that exist.
/// Inputs: `dataSet`; `devices` — the current device list.
/// Returns: One `DataSetReplica` per linked slot and array, in link order,
/// slots before arrays; links to a deleted device, an out-of-range slot or a
/// removed array are skipped, and a place listed twice counts once.
/// Side effects: None.
/// Notes: Every linked place holds a full, equal copy — a data set is never
/// split — so the length is the copy count, failed places included; use
/// [availableCopyCount] for the copies that count.
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
        DataSetReplica(
          dataSet: dataSet,
          place: StoragePlace.slot(device, index),
        ),
      );
    }
    for (final id in link.arrayIds) {
      final array = device.storageArrays.where((a) => a.id == id).firstOrNull;
      if (array == null || !seen.add('${device.id}#a:$id')) continue;
      replicas.add(
        DataSetReplica(
          dataSet: dataSet,
          place: StoragePlace.array(device, array),
        ),
      );
    }
  }
  return replicas;
}

/// Purpose: Count the copies that can still be read.
/// Inputs: `replicas` — from [resolveReplicas].
/// Returns: The replicas whose place is not `unavailable`.
/// Side effects: None.
/// Notes: A degraded array still counts.
int availableCopyCount(List<DataSetReplica> replicas) =>
    replicas.where((r) => r.isAvailable).length;

/// One group of the dataset list: a device, one place (slot or RAID array)
/// of a device, or the data sets that are on no storage.
class DataSetGroup {
  /// `device:<id>`, `storage:<id>:<place key>` or `unlinked`.
  final String key;
  final Device? device;

  /// The place, for a storage group.
  final StoragePlace? place;
  final List<DataSet> dataSets;

  /// Purpose: Create a group.
  /// Inputs: `key`; `device` — null for the unlinked group; `place` — set
  /// for a storage group only; `dataSets` — in list order.
  /// Returns: A new `DataSetGroup`.
  /// Side effects: None.
  /// Notes: None.
  const DataSetGroup({
    required this.key,
    this.device,
    this.place,
    required this.dataSets,
  });

  /// Purpose: Return the slot of a slot group.
  /// Inputs: None.
  /// Returns: The index, or null for other groups.
  /// Side effects: None.
  /// Notes: None.
  int? get storageIndex => place?.storageIndex;

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
/// groups also by place: arrays, then slots, as [devicePlaces] orders them,
/// then member slots still linked directly), then the unlinked group when
/// any data set resolves to no copy.
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
            : 'storage:${r.device.id}:${r.place.key}',
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
    for (final place in _placesWithMembers(device)) {
      final key = 'storage:${device.id}:${place.key}';
      final list = buckets[key];
      if (list != null) {
        groups.add(
          DataSetGroup(key: key, device: device, place: place, dataSets: list),
        );
      }
    }
  }
  if (unlinked.isNotEmpty) {
    groups.add(DataSetGroup(key: 'unlinked', dataSets: unlinked));
  }
  return groups;
}

/// Purpose: List every place of a device, member slots included.
/// Inputs: `device`.
/// Returns: [devicePlaces], then the slots that belong to an array.
/// Side effects: None.
/// Notes: Internal helper of [groupDataSets]; member slots are only shown
/// when a link still points at one directly.
List<StoragePlace> _placesWithMembers(Device device) {
  final places = devicePlaces(device);
  final listed = {for (final p in places) p.key};
  return [
    ...places,
    for (var i = 0; i < device.storage.length; i++)
      if (!listed.contains('$i')) StoragePlace.slot(device, i),
  ];
}

/// Purpose: Name a place: an array by its level and name, a slot by
/// [storageSlotLabel].
/// Inputs: `place`; `fallback` — as for [storageSlotLabel].
/// Returns: `String`.
/// Side effects: None.
/// Notes: None.
String placeLabel(StoragePlace place, String Function(int number) fallback) =>
    place.isArray
    ? place.array!.displayString
    : storageSlotLabel(place.device, place.storageIndex!, fallback);

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
