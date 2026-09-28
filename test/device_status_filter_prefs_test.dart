import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/devices/services/device_storage.dart';
import 'package:my_device/features/devices/views/device_list_page.dart';

import 'support/fake_storage.dart';
import 'support/pump.dart';

/// Purpose: Test that the home list remembers its All / In Service / Retired
/// / Sold filter locally and restores it on the next visit.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: The default ("All") is never written, matching the other list
/// preferences, so going back to All removes the key.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await seedAppDir(
      'mydevice_status_filter',
      devices: [
        Device(
          id: 'a',
          name: '在用设备',
          category: DeviceCategory.phone,
          modifiedAt: DateTime.utc(2026, 7, 1),
        ),
        Device(
          id: 'b',
          name: '退役设备',
          category: DeviceCategory.laptop,
          isRetired: true,
          modifiedAt: DateTime.utc(2026, 7, 1),
        ),
      ],
    );
  });

  tearDown(() {
    deleteSeededDir(tempDir);
  });

  Future<void> pumpList(WidgetTester tester) => pumpPageAt(
    tester,
    411,
    914,
    page: const DeviceListPage(),
    ready: find.text('在用设备'),
  );

  Finder segment(String label) => find.descendant(
    of: find.byType(SegmentedButton<DeviceStatusFilter>),
    matching: find.text(label),
  );

  // The page writes without awaiting, through real file I/O, so poll the
  // file on the real event loop (same approach as list_columns_ui_test).
  Future<void> waitForConfig(
    WidgetTester tester,
    bool Function(Map<String, dynamic>) done,
  ) async {
    var settled = 0;
    for (var i = 0; i < 40 && settled < 4; i++) {
      if (done(readSeededConfig(tempDir))) settled++;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  testWidgets('picking a filter stores it and All removes it again', (
    tester,
  ) async {
    await pumpList(tester);
    expect(readSeededConfig(tempDir).containsKey('deviceStatusFilter'), false);

    await tester.tap(segment('服役中'));
    await settle(tester);
    await waitForConfig(tester, (c) => c['deviceStatusFilter'] == 'inService');
    expect(readSeededConfig(tempDir)['deviceStatusFilter'], 'inService');
    expect(find.text('退役设备'), findsNothing);

    await tester.tap(segment('全部'));
    await settle(tester);
    await waitForConfig(
      tester,
      (c) => !c.containsKey('deviceStatusFilter'),
    );
    expect(readSeededConfig(tempDir).containsKey('deviceStatusFilter'), false);
  });

  testWidgets('a stored filter is restored when the page opens', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final config = await DeviceStorage.readConfig();
      config['deviceStatusFilter'] = 'retired';
      await DeviceStorage.writeConfig(config);
    });
    await pumpPageAt(
      tester,
      411,
      914,
      page: const DeviceListPage(),
      ready: find.text('退役设备'),
    );
    await settle(tester);
    expect(find.text('在用设备'), findsNothing);
    final button = tester.widget<SegmentedButton<DeviceStatusFilter>>(
      find.byType(SegmentedButton<DeviceStatusFilter>),
    );
    expect(button.selected, {DeviceStatusFilter.retired});
  });

  testWidgets('an unknown stored value falls back to All', (tester) async {
    await tester.runAsync(() async {
      final config = await DeviceStorage.readConfig();
      config['deviceStatusFilter'] = 'somethingNew';
      await DeviceStorage.writeConfig(config);
    });
    await pumpList(tester);
    await settle(tester);
    expect(find.text('退役设备'), findsOneWidget);
    final button = tester.widget<SegmentedButton<DeviceStatusFilter>>(
      find.byType(SegmentedButton<DeviceStatusFilter>),
    );
    expect(button.selected, {DeviceStatusFilter.all});
  });
}
