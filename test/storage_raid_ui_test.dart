import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/datasets/models/dataset.dart';
import 'package:my_device/features/datasets/services/dataset_storage.dart';
import 'package:my_device/features/datasets/views/dataset_topology_page.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/devices/services/device_storage.dart';
import 'package:my_device/features/devices/views/device_edit_page.dart';
import 'package:my_device/l10n/app_localizations.dart';
import 'package:my_device/shared/widgets/topology_canvas_viewer.dart';

import 'storage_raid_health_test.dart' show raidFixture;
import 'support/fake_storage.dart';
import 'support/pump.dart';

/// Purpose: Test the RAID array and drive status UI in the device editor
/// and the data set topology.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Driven in Simplified Chinese, like the other page tests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await seedAppDir(
      'mydevice_storage_raid_ui',
      devices: [
        Device(
          id: 'nas',
          name: 'NAS',
          category: DeviceCategory.other,
          storage: const [
            StorageInfo(capacity: '8 TB'),
            StorageInfo(capacity: '8 TB'),
            StorageInfo(capacity: '4 TB'),
          ],
        ),
      ],
    );
  });

  tearDown(() => deleteSeededDir(tempDir));

  /// Purpose: Read the stored devices.
  /// Inputs: `tester`.
  /// Returns: The saved device list.
  /// Side effects: Reads the seeded storage.
  /// Notes: Runs on the real event loop because storage uses `dart:io`.
  Future<List<Device>> load(WidgetTester tester) async =>
      (await tester.runAsync(DeviceStorage.load))!.devices;

  testWidgets('the editor marks a drive failed and builds a RAID array', (
    tester,
  ) async {
    final device = (await load(tester)).single;
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(700, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DeviceEditPage(device: device),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await settle(tester);
    await pumpUntil(tester, find.widgetWithText(TextFormField, '型号'));
    await settle(tester);

    // The fields are a lazy list; scroll the storage section into view.
    Future<void> reveal(Finder finder) => tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // Mark the third drive offline, with a note.
    final status = find.byKey(const ValueKey('storage-status-2'));
    await reveal(status);
    await settle(tester);
    await tester.tap(status);
    await settle(tester);
    await tester.tap(find.text('离线').last);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, '状态备注'), '掉线');

    // A RAID 1 array of the first two drives.
    await reveal(find.byKey(const Key('storage-array-add')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('storage-array-add')));
    await settle(tester);
    for (final i in [0, 1]) {
      final chip = find.byKey(ValueKey('array-0-member-$i'));
      await reveal(chip);
      await tester.tap(chip);
      await settle(tester);
    }
    await tester.enterText(
      find.widgetWithText(TextFormField, '阵列名称'),
      'Mirror',
    );
    await tester.pump();

    await tester.tap(find.text('保存').first);
    for (var i = 0; i < 300; i++) {
      if (find.text('打开').evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    final saved = (await load(tester)).single;
    expect(saved.storage, hasLength(3));
    expect(saved.storage[2].status, StorageHealth.offline);
    expect(saved.storage[2].statusNote, '掉线');
    expect(saved.storage[0].status, StorageHealth.ok);
    final array = saved.storageArrays.single;
    expect(array.name, 'Mirror');
    expect(array.level, RaidLevel.raid1);
    expect(array.memberIndices, [0, 1]);
  });

  testWidgets('slot links move to the array the slots joined', (tester) async {
    await tester.runAsync(() async {
      await DataSetStorage.save(
        DataSetData(
          datasets: [
            DataSet(
              id: 'photos',
              name: 'Photos',
              emoji: '📷',
              storageLinks: const [
                DataSetStorageLink(
                  deviceId: 'nas',
                  storageIndices: [0, 1, 2],
                  arrayIds: ['gone'],
                ),
              ],
            ),
          ],
        ),
      );
      // Slot 2 was removed; slots 0 and 1 now form array "pool".
      await DataSetStorage.remapDeviceStorageLinks(
        deviceId: 'nas',
        oldSlotCount: 3,
        indexMap: {0: 0, 1: 1},
        keptArrayIds: {'pool'},
        arrayOfSlot: {0: 'pool', 1: 'pool'},
      );
    });
    final link = (await tester.runAsync(
      DataSetStorage.load,
    ))!.datasets.single.storageLinks.single;
    expect(link.storageIndices, isEmpty);
    expect(link.arrayIds, ['pool']);
  });

  testWidgets('the topology marks failed places and counts usable copies', (
    tester,
  ) async {
    final f = raidFixture(failedInArray: 1);
    await pumpPageAt(
      tester,
      1280,
      800,
      page: DataSetTopologyPage(
        dataSets: f.dataSets,
        devices: f.devices,
        onEditDataSet: (_) async {},
      ),
      ready: find.byType(TopologyCanvasViewer),
    );
    // The offline drive and the degraded array both show the error icon.
    expect(
      find.byKey(const ValueKey('dataset-topology-unhealthy-storage:nas:3')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('dataset-topology-unhealthy-storage:nas:a:pool'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dataset-topology-unhealthy-storage:pc:0')),
      findsNothing,
    );
    // Scratch has two copies, one on the offline drive.
    expect(find.text('×1/2'), findsWidgets);
    // Media's array copy still counts while the array is only degraded.
    expect(find.text('×2'), findsWidgets);
  });
}
