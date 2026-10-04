import 'dart:convert';
import 'dart:io';

import '../../../app/data_modules.dart';
import '../../../features/devices/services/device_storage.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../models/dataset.dart';

class DataSetStorage {
  static const _dataFileName = dataSetDataFileName;

  /// Purpose: Serialise [operation] behind earlier writes of `datasets.json`.
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
  /// Returns: `Future<DataSetData>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  static Future<DataSetData> load() async {
    final file = await _getFile();
    if (!await file.exists()) return const DataSetData();
    var raw = await file.readAsString();
    if (raw.trim().isEmpty) return const DataSetData();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return DataSetData.fromJson(json);
  }

  /// Purpose: Save the relevant data to the relevant storage or service layer.
  /// Inputs: `data`.
  /// Returns: `Future<void>`.
  /// Side effects: Atomically replaces `datasets.json` (queued behind earlier
  /// writes) and notifies auto-sync.
  /// Notes: Public entry point; enqueues [_write]. Code already running inside
  /// the write queue must call [_write], never this method (deadlock).
  static Future<void> save(DataSetData data) => _serialised(() => _write(data));

  /// Purpose: Write `datasets.json` atomically and notify auto-sync.
  /// Inputs: `data`.
  /// Returns: `Future<void>`.
  /// Side effects: tmp-file + rename write; calls `AutoSyncService.notifySaved`.
  /// Notes: Internal helper; the unqueued primitive used from inside [_serialised].
  static Future<void> _write(DataSetData data) async {
    final file = await _getFile();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await DeviceStorage.atomicWrite(file, jsonStr);
    AutoSyncService.instance.notifySaved();
  }

  /// Purpose: Add or update through the current flow.
  /// Inputs: `dataset`.
  /// Returns: `Future<void>`.
  /// Side effects: Queued read-modify-write of `datasets.json`.
  /// Notes: Keeps unknown top-level fields (`extraJson`).
  static Future<void> addOrUpdate(DataSet dataset) => _serialised(() async {
    final data = await load();
    final list = List<DataSet>.of(data.datasets);
    final idx = list.indexWhere((d) => d.id == dataset.id);
    if (idx >= 0) {
      list[idx] = dataset;
    } else {
      list.add(dataset);
    }
    await _write(DataSetData(datasets: list, extraJson: data.extraJson));
  });

  /// Purpose: Delete the relevant data from the relevant storage or state.
  /// Inputs: `id`.
  /// Returns: `Future<void>`.
  /// Side effects: Queued read-modify-write of `datasets.json`.
  /// Notes: Keeps unknown top-level fields (`extraJson`).
  static Future<void> delete(String id) => _serialised(() async {
    final data = await load();
    final list = data.datasets.where((d) => d.id != id).toList();
    await _write(DataSetData(datasets: list, extraJson: data.extraJson));
  });

  /// Purpose: Re-map dataset storage links after a device's storage slots changed.
  /// Inputs: `deviceId`, `oldSlotCount` slots before the edit, `indexMap`
  /// original slot index → new slot index (removed slots are absent);
  /// `keptArrayIds` — when given, the device's array ids after the edit, so
  /// links to removed arrays are dropped; `arrayOfSlot` — new slot index →
  /// id of the array it now belongs to.
  /// Returns: `Future<void>`.
  /// Side effects: Rewrites affected dataset links, bumps each changed
  /// dataset's `modifiedAt`, and saves.
  /// Notes: Storage links reference device storage slots positionally, so
  /// removing a slot in the device editor must shift or drop linked indices —
  /// otherwise links silently point at the wrong drive. Array links are by
  /// id and survive slot changes. A link to a slot that is now an array
  /// member is moved to the array, since the array's data is one copy. Links
  /// left without any valid slot or array are removed.
  static Future<void> remapDeviceStorageLinks({
    required String deviceId,
    required int oldSlotCount,
    required Map<int, int> indexMap,
    Set<String>? keptArrayIds,
    Map<int, String> arrayOfSlot = const {},
  }) async {
    var identity = true;
    for (var i = 0; i < oldSlotCount; i++) {
      if (indexMap[i] != i) {
        identity = false;
        break;
      }
    }
    if (identity && keptArrayIds == null && arrayOfSlot.isEmpty) return;

    await _serialised(() async {
      final data = await load();
      var changed = false;
      final updated = <DataSet>[];
      for (final ds in data.datasets) {
        var dsChanged = false;
        final links = <DataSetStorageLink>[];
        for (final link in ds.storageLinks) {
          if (link.deviceId != deviceId) {
            links.add(link);
            continue;
          }
          final newIndices = <int>[];
          final newArrays = keptArrayIds == null
              ? List.of(link.arrayIds)
              : link.arrayIds.where(keptArrayIds.contains).toList();
          for (final idx in link.storageIndices) {
            final mapped = indexMap[idx];
            if (mapped == null) continue;
            final array = arrayOfSlot[mapped];
            if (array == null) {
              newIndices.add(mapped);
            } else if (!newArrays.contains(array)) {
              newArrays.add(array);
            }
          }
          if (newIndices.length != link.storageIndices.length ||
              !_sameIndices(newIndices, link.storageIndices) ||
              !_sameIds(newArrays, link.arrayIds)) {
            dsChanged = true;
          }
          if (newIndices.isNotEmpty || newArrays.isNotEmpty) {
            links.add(
              DataSetStorageLink(
                deviceId: link.deviceId,
                storageIndices: newIndices,
                arrayIds: newArrays,
                extraJson: link.extraJson,
              ),
            );
          }
        }
        if (dsChanged) {
          changed = true;
          updated.add(ds.copyWith(storageLinks: links));
        } else {
          updated.add(ds);
        }
      }
      if (!changed) return;
      await _write(DataSetData(datasets: updated, extraJson: data.extraJson));
    });
  }

  /// Purpose: Compare two array id lists element-wise.
  /// Inputs: `a`, `b`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Purpose: Compare two storage index lists element-wise.
  /// Inputs: `a`, `b`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static bool _sameIndices(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
