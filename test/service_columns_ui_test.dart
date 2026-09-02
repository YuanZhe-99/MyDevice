import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/views/service_list_page.dart';

import 'support/fake_storage.dart';
import 'support/pump.dart';

/// Purpose: Test that the services page's routes view takes columns while its
/// overview does not.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: The overview is a heterogeneous scroll (metric grid, topology card,
/// route groups, tiles) and deliberately stays single-column with no column
/// control; the routes view is a flat list of cards and does split.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await seedAppDir(
      'mydevice_service_columns_ui',
      devices: [
        Device(id: 'dev1', name: '主机', category: DeviceCategory.values.first),
      ],
      services: [
        ServiceNode(id: 'svc1', deviceId: 'dev1', name: '服务甲'),
        ServiceNode(id: 'svc2', deviceId: 'dev1', name: '服务乙'),
      ],
      routes: [
        for (var i = 1; i <= 4; i++)
          ServiceRoute(
            id: 'r$i',
            name: '链路 $i',
            sourceServiceId: i.isOdd ? 'svc1' : 'svc2',
            modifiedAt: DateTime.utc(2026, 7, 1),
          ),
      ],
    );
  });

  tearDown(() {
    deleteSeededDir(tempDir);
  });

  Future<void> pumpAt(WidgetTester tester, double w, double h) => pumpPageAt(
    tester,
    w,
    h,
    page: const ServiceListPage(),
    // The overview's metric cards are its first children; the service tiles
    // sit below the fold on most windows and are never built there.
    ready: find.byType(Card),
  );

  final columnButton = find.byIcon(Icons.view_column_outlined);

  testWidgets('the overview hides the column control on a wide window', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704);
    expect(columnButton, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the routes view lays its cards out in two columns', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704);
    await tester.tap(find.text('链路').first);
    await settle(tester);
    expect(columnButton, findsOneWidget);
    final cards = find.byType(Card);
    final first = tester.getTopLeft(cards.at(0));
    final second = tester.getTopLeft(cards.at(1));
    final third = tester.getTopLeft(cards.at(2));
    expect(second.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
    expect(third.dy, greaterThan(first.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the routes view stays on one column on a phone', (tester) async {
    await pumpAt(tester, 412, 915);
    await tester.tap(find.text('链路').first);
    await settle(tester);
    expect(columnButton, findsNothing);
    final cards = find.byType(Card);
    expect(
      tester.getTopLeft(cards.at(1)).dy,
      greaterThan(tester.getTopLeft(cards.at(0)).dy),
    );
  });
}
