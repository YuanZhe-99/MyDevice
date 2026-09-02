import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/devices/services/device_storage.dart';
import 'package:my_device/features/devices/views/device_list_page.dart';

import 'support/fake_storage.dart';
import 'support/pump.dart';

/// Purpose: Test multi-column rendering of the device list and its control.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Drives the real device list page at the real logical-pixel geometry
/// of the devices named in each case, so a column-count or gesture regression
/// is caught at the size it would actually happen. The device tile is the one
/// that changes shape between layouts — its swipe `Dismissible` is dropped
/// above one column and a trailing menu takes over edit and delete.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  const longName = '与奔驰于透明之夜的你，谈一场看不见的恋爱，并且这个名字长到列表行里绝对放不下。';

  setUp(() async {
    tempDir = await seedAppDir(
      'mydevice_columns_ui',
      devices: [
        for (var i = 1; i <= 6; i++)
          Device(
            id: 'd$i',
            name: i == 1 ? longName : '设备 $i',
            category: DeviceCategory.values[i % DeviceCategory.values.length],
            brand: '品牌',
            modifiedAt: DateTime.utc(2026, 7, 1),
          ),
      ],
    );
  });

  tearDown(() {
    deleteSeededDir(tempDir);
  });

  Future<void> pumpAt(WidgetTester tester, double width, double height) =>
      pumpPageAt(
        tester,
        width,
        height,
        page: const DeviceListPage(),
        ready: find.text('设备 2'),
      );

  final columnButton = find.byIcon(Icons.view_column_outlined);
  final deviceTiles = find.byType(ListTile);

  // The page writes its preference without awaiting it, through real file
  // I/O, so poll the file on the real event loop rather than assume a frame.
  // The write's continuations are queued in the test zone, so real time and
  // a pump have to alternate for the chain to run to completion.
  Future<void> waitForConfig(
    WidgetTester tester,
    bool Function(Map<String, dynamic>) done,
  ) async {
    var settled = 0;
    for (var i = 0; i < 40 && settled < 4; i++) {
      // Once the content is there, keep alternating a few more times so the
      // writer's close completes and tear-down can delete the directory.
      if (done(readSeededConfig(tempDir))) settled++;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  testWidgets('a Z Fold 8 in landscape lays the list out in two columns', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704);
    expect(deviceTiles, findsWidgets);
    // Two tiles with the same top edge means two columns. Tops rather than
    // centres, because the long-named tile is taller than its neighbour and
    // the row top-aligns its cells.
    final first = tester.getTopLeft(deviceTiles.at(0));
    final second = tester.getTopLeft(deviceTiles.at(1));
    expect(second.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
    // Swipe actions are dropped once the tiles stop spanning the full width;
    // the trailing menu carries edit and delete instead.
    expect(find.byType(Dismissible), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same device in portrait stays on one column', (
    tester,
  ) async {
    await pumpAt(tester, 704, 933);
    final first = tester.getTopLeft(deviceTiles.at(0));
    final second = tester.getTopLeft(deviceTiles.at(1));
    expect(second.dy, greaterThan(first.dy));
    expect(second.dx, first.dx);
    // Single column keeps swipe-to-edit and swipe-to-delete.
    expect(find.byType(Dismissible), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone shows no column control at all', (tester) async {
    await pumpAt(tester, 411, 914); // Pixel 10 Pro Fold cover screen
    expect(columnButton, findsNothing);
    expect(find.byType(Dismissible), findsWidgets);
  });

  testWidgets('a phone in landscape cannot split either', (tester) async {
    await pumpAt(tester, 915, 412);
    expect(columnButton, findsNothing);
    final first = tester.getTopLeft(deviceTiles.at(0));
    final second = tester.getTopLeft(deviceTiles.at(1));
    expect(second.dx, first.dx);
  });

  testWidgets('a wide window offers the column control and stores the pick', (
    tester,
  ) async {
    await pumpAt(tester, 1024, 768); // tablet landscape
    expect(columnButton, findsOneWidget);
    expect(
      tester.getTopLeft(deviceTiles.at(1)).dy,
      tester.getTopLeft(deviceTiles.at(0)).dy,
    );

    await tester.tap(columnButton);
    await settle(tester);
    await tester.tap(find.text('1 列'));
    await settle(tester);
    await waitForConfig(tester, (c) => c['deviceListColumns'] == 1);

    expect(readSeededConfig(tempDir)['deviceListColumns'], 1);
    expect(
      tester.getTopLeft(deviceTiles.at(1)).dy,
      greaterThan(tester.getTopLeft(deviceTiles.at(0)).dy),
    );
    // Pinned to one column the tiles are full width again, so the swipe
    // gestures come back.
    expect(find.byType(Dismissible), findsWidgets);

    await tester.tap(columnButton);
    await settle(tester);
    await tester.tap(find.text('自动'));
    await settle(tester);
    await waitForConfig(tester, (c) => !c.containsKey('deviceListColumns'));
    expect(readSeededConfig(tempDir).containsKey('deviceListColumns'), isFalse);
  });

  testWidgets('a stored preference is clamped, not rejected, on a fold', (
    tester,
  ) async {
    // Real file I/O before the page is pumped has to run outside the
    // binding's fake-async zone, or the await never completes.
    await tester.runAsync(() => DeviceStorage.setDeviceListColumns(4));
    await pumpAt(tester, 933, 704); // room for two at 320 dp
    final first = tester.getTopLeft(deviceTiles.at(0));
    final second = tester.getTopLeft(deviceTiles.at(1));
    final third = tester.getTopLeft(deviceTiles.at(2));
    expect(second.dy, first.dy);
    expect(third.dy, greaterThan(first.dy));
    // The stored value is untouched by the clamp.
    expect(readSeededConfig(tempDir)['deviceListColumns'], 4);
  });

  testWidgets('grouped mode keeps each category header above its rows', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final config = await DeviceStorage.readConfig();
      config['groupByCategory'] = true;
      await DeviceStorage.writeConfig(config);
    });
    await pumpAt(tester, 933, 704);
    expect(tester.takeException(), isNull);
    // Every category header sits above the first tile that follows it.
    final headers = find.byWidgetPredicate(
      (w) =>
          w is Padding &&
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('header_'),
    );
    expect(headers, findsWidgets);
    final firstHeader = tester.getTopLeft(headers.first);
    final firstTile = tester.getTopLeft(deviceTiles.first);
    expect(firstTile.dy, greaterThan(firstHeader.dy));
  });
}
