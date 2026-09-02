import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/devices/views/device_finance_overview_page.dart';

import 'support/pump.dart';

/// Purpose: Test the finance overview's summary-beside-chart layout.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The layout is gated three ways — the window's shape, a width floor
/// for both blocks, and whether the distribution chart has data — so the
/// cases cover a window that passes all three, the two that fail the shape,
/// and a device set that fails the data gate on a window that passes the
/// other two. Driven in Simplified Chinese (see `pumpPageAt`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MoneyValue usd(double amount) => MoneyValue(
    amount: amount,
    currency: 'USD',
    defaultCurrency: 'USD',
    convertedAmount: amount,
    exchangeRate: 1,
    autoRate: false,
  );

  final priced = [
    for (var i = 1; i <= 3; i++)
      Device(
        id: 'd$i',
        name: '设备 $i',
        category: DeviceCategory.values[i % DeviceCategory.values.length],
        purchaseDate: DateTime.utc(2024, i, 1),
        purchasePrice: usd(1000.0 * i),
        modifiedAt: DateTime.utc(2026, 7, 1),
      ),
  ];

  final unpriced = [
    Device(
      id: 'd9',
      name: '没有价格的设备',
      category: DeviceCategory.values.first,
      modifiedAt: DateTime.utc(2026, 7, 1),
    ),
  ];

  Future<void> pumpAt(
    WidgetTester tester,
    double w,
    double h, {
    List<Device>? devices,
  }) => pumpPageAt(
    tester,
    w,
    h,
    page: DeviceFinanceOverviewPage(
      devices: devices ?? priced,
      defaultCurrency: 'USD',
    ),
    ready: find.text('总成本'),
  );

  final summary = find.text('总成本'); // financialTotalCost, summary card
  final chart = find.text('资产分布'); // financialAssetDistribution card title

  testWidgets('a Z Fold 8 in landscape puts the summary beside the chart', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704);
    final s = tester.getRect(summary);
    final c = tester.getRect(chart);
    expect(c.left, greaterThan(s.right));
    // Vertically they share the same row.
    expect(c.top, lessThan(s.bottom + 40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Z Fold 7 in portrait also qualifies', (tester) async {
    // 750 − 32 = 718 clears the 592 floor; the split rule passes at 0.90.
    await pumpAt(tester, 750, 832);
    expect(
      tester.getRect(chart).left,
      greaterThan(tester.getRect(summary).right),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Z Fold 8 in portrait stacks them', (tester) async {
    await pumpAt(tester, 704, 933);
    expect(
      tester.getTopLeft(chart).dy,
      greaterThan(tester.getTopLeft(summary).dy),
    );
    expect(tester.getTopLeft(chart).dx, tester.getTopLeft(summary).dx);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone in landscape stacks them — the cost stated on purpose', (
    tester,
  ) async {
    await pumpAt(tester, 915, 412);
    expect(
      tester.getTopLeft(chart).dy,
      greaterThan(tester.getTopLeft(summary).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('no finance data keeps the stacked layout on a wide window', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704, devices: unpriced);
    expect(
      tester.getTopLeft(chart).dy,
      greaterThan(tester.getTopLeft(summary).dy),
    );
    expect(find.text('暂无财务数据'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
