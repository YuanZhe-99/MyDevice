import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';

void main() {
  test('device finance fields survive json round trip and calculate cost', () {
    final device = Device(
      id: 'device-1',
      name: 'Laptop',
      category: DeviceCategory.laptop,
      purchaseDate: DateTime(2026, 1, 1),
      retiredDate: DateTime(2026, 1, 10),
      isRetired: true,
      acquisitionType: DeviceAcquisitionType.purchasedWithSubscription,
      purchasePrice: const MoneyValue(
        amount: 1000,
        currency: 'USD',
        defaultCurrency: 'USD',
        convertedAmount: 1000,
        exchangeRate: 1,
        autoRate: true,
      ),
      soldPrice: const MoneyValue(
        amount: 200,
        currency: 'USD',
        defaultCurrency: 'USD',
        convertedAmount: 200,
        exchangeRate: 1,
        autoRate: false,
      ),
      recurringCosts: [
        DeviceRecurringCost(
          id: 'cost-1',
          kind: RecurringCostKind.insurance,
          billingCycle: BillingCycle.yearly,
          price: const MoneyValue(
            amount: 365,
            currency: 'USD',
            defaultCurrency: 'USD',
            convertedAmount: 365,
            exchangeRate: 1,
            autoRate: true,
          ),
        ),
      ],
    );

    final restored = Device.fromJson(device.toJson());

    expect(restored.lifecycleStatus, DeviceLifecycleStatus.retired);
    expect(
      restored.acquisitionType,
      DeviceAcquisitionType.purchasedWithSubscription,
    );
    expect(restored.purchasePrice?.convertedAmount, 1000);
    expect(restored.soldPrice?.convertedAmount, 200);
    expect(restored.recurringCosts.single.kind, RecurringCostKind.insurance);
    expect(restored.serviceDays(), 10);
    expect(restored.totalCost(), 810);
    expect(restored.averageDailyCost(), 81);
  });

  test('sold devices are not considered in service', () {
    final device = Device(
      name: 'Phone',
      category: DeviceCategory.phone,
      isSold: true,
    );

    expect(device.lifecycleStatus, DeviceLifecycleStatus.sold);
    expect(device.isInService, isFalse);
  });
}
