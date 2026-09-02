import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/devices/views/device_detail_page.dart';

import 'support/pump.dart';

/// Purpose: Test that the device detail page renders correctly in both
/// layouts.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Drives the real page at the real logical-pixel geometry of the
/// devices named in each case, so an overflow or a wrong-layout regression is
/// caught at the size it would actually happen. The fixture carries no
/// coordinates on purpose: the map block would try to fetch tiles, and the
/// test environment's HTTP client refuses every request. Driven in Simplified
/// Chinese (see `pumpPageAt`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final device = Device(
    id: 'd1',
    name: '与奔驰于透明之夜的你，谈一场看不见的恋爱。',
    category: DeviceCategory.values.first,
    brand: '品牌',
    model: '型号一号',
    cpu: const CpuInfo(model: 'Snapdragon 8 Elite', architecture: 'ARMv9'),
    ram: '16 GB',
    notes: '一段坐在卡片下方的备注。',
    modifiedAt: DateTime.utc(2026, 7, 1),
  );

  final bareDevice = Device(
    id: 'd2',
    name: '没有规格的设备',
    category: DeviceCategory.values.first,
    modifiedAt: DateTime.utc(2026, 7, 1),
  );

  Future<void> pumpAt(
    WidgetTester tester,
    double w,
    double h, {
    Device? which,
  }) => pumpPageAt(
    tester,
    w,
    h,
    page: DeviceDetailPage(device: which ?? device),
    ready: find.text((which ?? device).name),
  );

  // The CPU card's model label; a spec row that only ever lives on the
  // right in the two-pane layout.
  final cpuLabel = find.text('型号');

  testWidgets('a Z Fold 8 in landscape splits into two panes', (tester) async {
    await pumpAt(tester, 933, 704);
    expect(find.byType(VerticalDivider), findsOneWidget);
    final name = tester.getTopLeft(find.text(device.name));
    final cpu = tester.getTopLeft(cpuLabel);
    // The header is on the left, the spec cards on the right.
    expect(cpu.dx, greaterThan(name.dx + 200));
    // The notes stay under the header, on the left.
    final notes = tester.getTopLeft(find.text(device.notes!));
    expect(notes.dx, lessThan(cpu.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same device in portrait keeps a single column', (
    tester,
  ) async {
    await pumpAt(tester, 704, 933);
    expect(find.byType(VerticalDivider), findsNothing);
    final name = tester.getTopLeft(find.text(device.name));
    final cpu = tester.getTopLeft(cpuLabel);
    expect(cpu.dy, greaterThan(name.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone in either orientation keeps a single column', (
    tester,
  ) async {
    await pumpAt(tester, 411, 923); // Pixel 10 Pro Fold cover
    expect(find.byType(VerticalDivider), findsNothing);
    expect(tester.takeException(), isNull);
    await pumpAt(tester, 915, 412);
    expect(find.byType(VerticalDivider), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the left pane stays put while the specs scroll', (tester) async {
    await pumpAt(tester, 1024, 768);
    final before = tester.getTopLeft(find.text(device.name));
    final specList = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    await tester.drag(specList.first, const Offset(0, -200));
    await settle(tester);
    expect(tester.getTopLeft(find.text(device.name)), before);
  });

  testWidgets('a device with no specs keeps one column on a wide window', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704, which: bareDevice);
    expect(find.byType(VerticalDivider), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the split floor renders without overflow', (tester) async {
    await pumpAt(tester, 600, 480);
    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
