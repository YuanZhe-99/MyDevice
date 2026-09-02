import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/services/device_storage.dart';
import 'package:my_device/shared/utils/adaptive_layout.dart';

import 'support/fake_storage.dart';

/// Purpose: Test that each list page's column preference round-trips and that
/// the default is absent from `storage_config.json` rather than written.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: The four keys must stay independent — the user picks a count per
/// page, and one page's choice must never move another's.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await seedAppDir('mydevice_cols_prefs');
  });

  tearDown(() {
    deleteSeededDir(tempDir);
  });

  test('every page defaults to auto with nothing stored', () async {
    expect(await DeviceStorage.getDeviceListColumns(), listColumnsAuto);
    expect(await DeviceStorage.getNetworkListColumns(), listColumnsAuto);
    expect(await DeviceStorage.getDataSetListColumns(), listColumnsAuto);
    expect(await DeviceStorage.getServiceListColumns(), listColumnsAuto);
    expect(readSeededConfig(tempDir), isEmpty);
  });

  test('a pinned count round-trips per page, independently', () async {
    await DeviceStorage.setDeviceListColumns(2);
    await DeviceStorage.setNetworkListColumns(3);
    await DeviceStorage.setServiceListColumns(4);

    expect(await DeviceStorage.getDeviceListColumns(), 2);
    expect(await DeviceStorage.getNetworkListColumns(), 3);
    expect(await DeviceStorage.getDataSetListColumns(), listColumnsAuto);
    expect(await DeviceStorage.getServiceListColumns(), 4);

    final config = readSeededConfig(tempDir);
    expect(config['deviceListColumns'], 2);
    expect(config['networkListColumns'], 3);
    expect(config.containsKey('dataSetListColumns'), isFalse);
    expect(config['serviceListColumns'], 4);
  });

  test(
    'choosing auto again removes the key rather than storing zero',
    () async {
      await DeviceStorage.setDataSetListColumns(3);
      expect(readSeededConfig(tempDir)['dataSetListColumns'], 3);
      await DeviceStorage.setDataSetListColumns(listColumnsAuto);
      expect(
        readSeededConfig(tempDir).containsKey('dataSetListColumns'),
        isFalse,
      );
      expect(await DeviceStorage.getDataSetListColumns(), listColumnsAuto);
    },
  );

  test('a malformed or out-of-range value reads as auto', () async {
    final config = await DeviceStorage.readConfig();
    config['deviceListColumns'] = 'two';
    config['networkListColumns'] = 9;
    config['dataSetListColumns'] = -1;
    await DeviceStorage.writeConfig(config);
    expect(await DeviceStorage.getDeviceListColumns(), listColumnsAuto);
    expect(await DeviceStorage.getNetworkListColumns(), listColumnsAuto);
    expect(await DeviceStorage.getDataSetListColumns(), listColumnsAuto);
  });

  test('other preferences in the same file survive a column write', () async {
    final config = await DeviceStorage.readConfig();
    config['sortMode'] = 'alphabetical';
    await DeviceStorage.writeConfig(config);
    await DeviceStorage.setDeviceListColumns(3);
    expect(readSeededConfig(tempDir)['sortMode'], 'alphabetical');
  });
}
