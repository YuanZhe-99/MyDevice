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
    await save(DataSetData(datasets: list));
  }

  /// Purpose: Delete the relevant data from the relevant storage or state.
  /// Inputs: `id`.
  /// Returns: `Future<void>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  static Future<void> delete(String id) async {
    final data = await load();
    final list = data.datasets.where((d) => d.id != id).toList();
    await save(DataSetData(datasets: list));
  }
}
