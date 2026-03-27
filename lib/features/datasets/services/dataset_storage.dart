import 'dart:convert';
import 'dart:io';

import '../../../features/devices/services/device_storage.dart';
import '../models/dataset.dart';

class DataSetStorage {
  static const _dataFileName = 'dataset_data.json';

  static Future<File> _getFile() async {
    final appDir = await DeviceStorage.getAppDir();
    return File('${appDir.path}/$_dataFileName');
  }

  static Future<DataSetData> load() async {
    final file = await _getFile();
    if (!await file.exists()) return const DataSetData();
    var raw = await file.readAsString();
    if (raw.trim().isEmpty) return const DataSetData();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return DataSetData.fromJson(json);
  }

  static Future<void> save(DataSetData data) async {
    final file = await _getFile();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await file.writeAsString(jsonStr);
  }

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

  static Future<void> delete(String id) async {
    final data = await load();
    final list = data.datasets.where((d) => d.id != id).toList();
    await save(DataSetData(datasets: list));
  }
}
