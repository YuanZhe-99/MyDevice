import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/network/models/network.dart';
import 'package:my_device/features/network/views/network_detail_page.dart';

import 'support/fake_storage.dart';
import 'support/pump.dart';

/// Purpose: Test that the network detail page renders correctly in both
/// layouts.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: The page loads itself by id, so it is driven against a seeded
/// storage directory at the real logical-pixel geometry of the devices named
/// in each case. Driven in Simplified Chinese (see `pumpPageAt`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await seedAppDir(
      'mydevice_network_detail_ui',
      devices: [
        Device(id: 'd1', name: '主机', category: DeviceCategory.values.first),
        Device(id: 'd2', name: '笔记本', category: DeviceCategory.values.first),
      ],
      networks: [
        Network(
          id: 'n1',
          name: '家庭网络',
          type: NetworkType.values.first,
          subnet: '10.0.0.0/24',
          gateway: '10.0.0.1',
        ),
      ],
      assignments: [
        NetworkDevice(networkId: 'n1', deviceId: 'd1', ipAddress: '10.0.0.2'),
        NetworkDevice(networkId: 'n1', deviceId: 'd2', ipAddress: '10.0.0.3'),
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
    page: const NetworkDetailPage(networkId: 'n1'),
    ready: find.textContaining('10.0.0.2'),
  );

  // The subnet only appears in the info card; the assignment's address only
  // in a device tile's "mode · ip · …" subtitle.
  final subnet = find.textContaining('10.0.0.0/24').first;
  final assignment = find.textContaining('10.0.0.2').first;

  testWidgets('a Z Fold 8 in landscape puts the info card beside the devices', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704);
    expect(find.byType(VerticalDivider), findsOneWidget);
    final info = tester.getRect(subnet);
    final list = tester.getRect(assignment);
    expect(info.right, lessThan(list.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same device in portrait stacks them', (tester) async {
    await pumpAt(tester, 704, 933);
    expect(find.byType(VerticalDivider), findsNothing);
    expect(
      tester.getTopLeft(assignment).dy,
      greaterThan(tester.getTopLeft(subnet).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone keeps a single column', (tester) async {
    await pumpAt(tester, 412, 915);
    expect(find.byType(VerticalDivider), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
