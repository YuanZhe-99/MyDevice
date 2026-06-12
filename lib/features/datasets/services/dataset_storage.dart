import 'dart:convert';
import 'dart:io';

import '../../../features/devices/services/device_storage.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../models/dataset.dart';

class DataSetStorage {
  static const _dataFileName = 'dataset_data.json';

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
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  static Future<void> save(DataSetData data) async {
    final file = await _getFile();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await file.writeAsString(jsonStr);
    AutoSyncService.instance.notifySaved();
  }

  /// Purpose: Add or update through the current flow.
  /// Inputs: `dataset`.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> addOrUpdate(DataSet dataset) async {
    final data = await load();
    final list = List<DataSet>.of(data.datasets);
    final idx = list.indexWhere((d) => d.id == dataset.id);
    if (idx >= 0) {
      list[idx] = dataset;
    } else {
      list.add(dataset);
    }
    await save(DataSetData(datasets: list, extraJson: data.extraJson));
  }

  /// Purpose: Delete the relevant data from the relevant storage or state.
  /// Inputs: `id`.
  /// Returns: `Future<void>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  static Future<void> delete(String id) async {
    final data = await load();
    final list = data.datasets.where((d) => d.id != id).toList();
    await save(DataSetData(datasets: list, extraJson: data.extraJson));
  }

  /// Purpose: Re-map dataset storage links after a device's storage slots changed.
  /// Inputs: `deviceId`, `oldSlotCount` slots before the edit, `indexMap`
  /// original slot index → new slot index (removed slots are absent).
  /// Returns: `Future<void>`.
  /// Side effects: Rewrites affected dataset links, bumps each changed
  /// dataset's `modifiedAt`, and saves.
  /// Notes: Storage links reference device storage slots positionally, so
  /// removing a slot in the device editor must shift or drop linked indices —
  /// otherwise links silently point at the wrong drive. Links left without
  /// any valid slot are removed.
  static Future<void> remapDeviceStorageLinks({
    required String deviceId,
    required int oldSlotCount,
    required Map<int, int> indexMap,
  }) async {
    var identity = true;
    for (var i = 0; i < oldSlotCount; i++) {
      if (indexMap[i] != i) {
        identity = false;
        break;
      }
    }
    if (identity) return;

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
        for (final idx in link.storageIndices) {
          final mapped = indexMap[idx];
          if (mapped != null) newIndices.add(mapped);
        }
        if (newIndices.length != link.storageIndices.length ||
            !_sameIndices(newIndices, link.storageIndices)) {
          dsChanged = true;
        }
        if (newIndices.isNotEmpty) {
          links.add(
            DataSetStorageLink(
              deviceId: link.deviceId,
              storageIndices: newIndices,
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
    await save(DataSetData(datasets: updated, extraJson: data.extraJson));
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
