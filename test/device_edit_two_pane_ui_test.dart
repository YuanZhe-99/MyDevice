import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/devices/views/device_edit_page.dart';

import 'support/fake_storage.dart';
import 'support/pump.dart';

/// Purpose: Test the device edit page's two-pane layout.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: The page reads preferences from `storage_config.json`, so it is
/// driven against a seeded (empty) storage directory rather than the user's.
/// The name and category fields are the ones that move: they share the left
/// pane with the avatar picker on a wide window and lead the single column
/// otherwise; brand is the first field that always stays on the right.
/// Driven in Simplified Chinese (see `pumpPageAt`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await seedAppDir('mydevice_edit_two_pane_ui');
  });

  tearDown(() {
    deleteSeededDir(tempDir);
  });

  final device = Device(
    id: 'd1',
    name: '测试设备',
    category: DeviceCategory.values.first,
    brand: '品牌',
    model: '型号一号',
    modifiedAt: DateTime.utc(2026, 7, 1),
  );

  Future<void> pumpAt(WidgetTester tester, double w, double h) => pumpPageAt(
    tester,
    w,
    h,
    page: DeviceEditPage(device: device),
    ready: find.text('品牌'),
  );

  final name = find.text('名称'); // deviceName label
  final category = find.text('类别'); // deviceCategory label
  final brand = find.text('品牌'); // deviceBrand label

  testWidgets('a Z Fold 8 in landscape pins the identity fields on the left', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704);
    expect(find.byType(VerticalDivider), findsOneWidget);
    final n = tester.getTopLeft(name.first);
    final c = tester.getTopLeft(category.first);
    final b = tester.getTopLeft(brand.first);
    expect(c.dx, n.dx);
    expect(b.dx, greaterThan(n.dx + 200));
    // One Form still wraps both panes.
    expect(find.byType(Form), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same device in portrait keeps the single column', (
    tester,
  ) async {
    await pumpAt(tester, 704, 933);
    expect(find.byType(VerticalDivider), findsNothing);
    final n = tester.getTopLeft(name.first);
    final b = tester.getTopLeft(brand.first);
    expect(b.dx, n.dx);
    expect(b.dy, greaterThan(n.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the split floor fits the left pane without overflow', (
    tester,
  ) async {
    await pumpAt(tester, 600, 480);
    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(name, findsWidgets);
    expect(category, findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a soft keyboard degrades the left pane to a scroll', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await settle(tester);
    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone keeps the single column', (tester) async {
    await pumpAt(tester, 412, 915);
    expect(find.byType(VerticalDivider), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
