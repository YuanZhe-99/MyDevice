import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/datasets/models/dataset.dart';
import 'package:my_device/features/datasets/views/dataset_edit_page.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/network/views/network_edit_page.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/views/service_edit_page.dart';
import 'package:my_device/features/services/views/service_route_edit_page.dart';
import 'package:my_device/shared/utils/adaptive_layout.dart';

import 'support/fake_storage.dart';
import 'support/pump.dart';

/// Purpose: Test the service, route, dataset and network edit pages' layouts.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: The service and route pages split into two panes that both scroll;
/// the dataset page pins its emoji-and-name row on the left; the network
/// page keeps one column capped at `formMaxWidth`. Each is driven against a
/// seeded storage directory at the real logical-pixel geometry of the devices
/// named. Driven in Simplified Chinese (see `pumpPageAt`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  final service = ServiceNode(
    id: 'svc1',
    deviceId: 'd1',
    name: '服务甲',
    modifiedAt: DateTime.utc(2026, 7, 1),
  );
  final route = ServiceRoute(
    id: 'r1',
    name: '链路一',
    sourceServiceId: 'svc1',
    modifiedAt: DateTime.utc(2026, 7, 1),
  );
  final dataSet = DataSet(
    id: 's1',
    name: '数据集一',
    emoji: '📁',
    modifiedAt: DateTime.utc(2026, 7, 1),
  );

  setUp(() async {
    tempDir = await seedAppDir(
      'mydevice_edit_pages_ui',
      devices: [
        Device(
          id: 'd1',
          name: '主机',
          category: DeviceCategory.values.first,
          storage: const [StorageInfo(capacity: '1 TB')],
          modifiedAt: DateTime.utc(2026, 7, 1),
        ),
      ],
      services: [service],
      routes: [route],
      datasets: [dataSet],
    );
  });

  tearDown(() {
    deleteSeededDir(tempDir);
  });

  group('service edit', () {
    Future<void> pumpAt(WidgetTester tester, double w, double h) => pumpPageAt(
      tester,
      w,
      h,
      page: ServiceEditPage(service: service),
      ready: find.text('端点'), // serviceEndpoints heading
    );

    testWidgets('a Z Fold 8 in landscape puts the identity beside the rest', (
      tester,
    ) async {
      await pumpAt(tester, 933, 704);
      expect(find.byType(VerticalDivider), findsOneWidget);
      final name = tester.getTopLeft(find.text('服务名称').first);
      final endpoints = tester.getTopLeft(find.text('端点').first);
      expect(endpoints.dx, greaterThan(name.dx + 200));
      expect(find.byType(Form), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the same device in portrait stacks them', (tester) async {
      await pumpAt(tester, 704, 933);
      expect(find.byType(VerticalDivider), findsNothing);
      final name = tester.getTopLeft(find.text('服务名称').first);
      final endpoints = tester.getTopLeft(find.text('端点').first);
      expect(endpoints.dy, greaterThan(name.dy));
      expect(tester.takeException(), isNull);
    });
  });

  group('route edit', () {
    Future<void> pumpAt(WidgetTester tester, double w, double h) => pumpPageAt(
      tester,
      w,
      h,
      page: ServiceRouteEditPage(route: route),
      ready: find.text('链路节点'), // routeHops heading
    );

    testWidgets('a Z Fold 8 in landscape puts the source beside the hops', (
      tester,
    ) async {
      await pumpAt(tester, 933, 704);
      expect(find.byType(VerticalDivider), findsOneWidget);
      final source = tester.getTopLeft(find.text('源服务').first);
      final hops = tester.getTopLeft(find.text('链路节点').first);
      expect(hops.dx, greaterThan(source.dx + 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a phone keeps a single column', (tester) async {
      await pumpAt(tester, 412, 915);
      expect(find.byType(VerticalDivider), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('dataset edit', () {
    Future<void> pumpAt(WidgetTester tester, double w, double h) => pumpPageAt(
      tester,
      w,
      h,
      page: DataSetEditPage(dataSet: dataSet),
      ready: find.byType(Card), // one storage card per seeded device
    );

    testWidgets('a Z Fold 8 in landscape pins the name beside the storage', (
      tester,
    ) async {
      await pumpAt(tester, 933, 704);
      expect(find.byType(VerticalDivider), findsOneWidget);
      final name = tester.getTopLeft(find.text('名称').first);
      final card = tester.getTopLeft(find.byType(Card).first);
      expect(card.dx, greaterThan(name.dx + 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the split floor renders without overflow', (tester) async {
      await pumpAt(tester, 600, 480);
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the same device in portrait stacks them', (tester) async {
      await pumpAt(tester, 704, 933);
      expect(find.byType(VerticalDivider), findsNothing);
      final name = tester.getTopLeft(find.text('名称').first);
      final card = tester.getTopLeft(find.byType(Card).first);
      expect(card.dy, greaterThan(name.dy));
      expect(tester.takeException(), isNull);
    });
  });

  group('network edit', () {
    Future<void> pumpAt(WidgetTester tester, double w, double h) => pumpPageAt(
      tester,
      w,
      h,
      page: const NetworkEditPage(),
      ready: find.byType(TextFormField),
    );

    testWidgets('a desktop window caps and centres the form', (tester) async {
      await pumpAt(tester, 1600, 900);
      final field = tester.getRect(find.byType(TextFormField).first);
      expect(field.width, lessThanOrEqualTo(formMaxWidth));
      expect(field.left, greaterThan(200));
      expect(find.byType(VerticalDivider), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a phone is unchanged: the field spans the width', (
      tester,
    ) async {
      await pumpAt(tester, 412, 915);
      final field = tester.getRect(find.byType(TextFormField).first);
      expect(field.left, 16);
      expect(field.width, 412 - 32);
      expect(tester.takeException(), isNull);
    });
  });
}
