import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/ai/services/insight_prompts.dart';
import 'package:my_device/features/datasets/models/dataset.dart';
import 'package:my_device/features/datasets/services/dataset_insight_facts.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/devices/services/finance_insight_facts.dart';
import 'package:my_device/features/network/models/network.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/services/service_insight_facts.dart';

/// Purpose: Build a money value already in the default currency.
/// Inputs: `amount`.
/// Returns: `MoneyValue`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
MoneyValue _cny(double amount) => MoneyValue(
  amount: amount,
  currency: 'CNY',
  defaultCurrency: 'CNY',
  convertedAmount: amount,
  exchangeRate: 1,
  autoRate: false,
);

/// Purpose: Test the pure fact builders behind the two insight cards.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The privacy cases matter most: a fact line is sent to the model, so
/// each forbidden field is filled with a unique marker and every line is
/// checked not to contain it.
void main() {
  final now = DateTime(2026, 9, 28, 10);

  group('device finance facts', () {
    final laptop = Device(
      id: 'l',
      name: 'Work Laptop',
      category: DeviceCategory.laptop,
      brand: 'SECRET-BRAND',
      model: 'SECRET-MODEL',
      serialNumber: 'SERIAL-123',
      notes: 'NOTE-ABC',
      locationName: 'HOME-ADDRESS',
      latitude: 1.5,
      longitude: 2.5,
      purchaseDate: DateTime(2024, 9, 28),
      purchasePrice: _cny(7300),
      recurringCosts: [
        DeviceRecurringCost(
          kind: RecurringCostKind.insurance,
          name: 'COST-NAME',
          price: _cny(30),
        ),
      ],
    );
    final phone = Device(
      id: 'p',
      name: 'Old Phone',
      category: DeviceCategory.phone,
      purchaseDate: DateTime(2020, 1, 1),
      purchasePrice: _cny(5000),
      recurringCosts: [
        DeviceRecurringCost(
          kind: RecurringCostKind.subscription,
          price: _cny(120),
          billingCycle: BillingCycle.yearly,
        ),
      ],
    );
    final sold = Device(
      id: 's',
      name: 'Sold Tablet',
      category: DeviceCategory.tablet,
      purchaseDate: DateTime(2022, 1, 1),
      retiredDate: DateTime(2025, 1, 1),
      isSold: true,
      purchasePrice: _cny(4000),
      soldPrice: _cny(1500),
    );
    final noCost = Device(
      id: 'n',
      name: 'Router',
      category: DeviceCategory.router,
    );

    InsightFacts build({bool names = true}) => buildDeviceFinanceInsightFacts(
      now: now,
      devices: [laptop, phone, sold, noCost],
      defaultCurrency: 'CNY',
      includeNames: names,
    )!;

    test('null when no device has financial data', () {
      expect(
        buildDeviceFinanceInsightFacts(
          now: now,
          devices: [noCost],
          defaultCurrency: 'CNY',
        ),
        isNull,
      );
    });

    test('never sends identifying or free-text fields', () {
      final text = build().lines.join('\n');
      for (final marker in [
        'SECRET-BRAND',
        'SECRET-MODEL',
        'SERIAL-123',
        'NOTE-ABC',
        'HOME-ADDRESS',
        'COST-NAME',
      ]) {
        expect(text, isNot(contains(marker)), reason: marker);
      }
    });

    test('counts statuses and totals in the default currency', () {
      final lines = build().lines;
      expect(lines, contains('- Currency: CNY'));
      expect(
        lines,
        contains(
          '- Devices: 4, of which 3 have cost data; in service 3, '
          'retired 0, sold 1',
        ),
      );
      final resale = lines.singleWhere(
        (l) => l.startsWith('- Retired or sold'),
      );
      expect(resale, contains('1 sold with a resale price totalling 1500 CNY'));
    });

    test('recurring costs are split by billing cycle', () {
      final line = build().lines.singleWhere(
        (l) => l.startsWith('- Recurring costs'),
      );
      expect(line, contains('2 entries on 2 devices'));
      expect(line, contains('monthly-billed 30 CNY per month'));
      expect(line, contains('yearly-billed 120 CNY per year'));
      expect(line, contains('together 480 CNY per year'));
    });

    test('oldest in-service devices come first and are named', () {
      final facts = build();
      final line = facts.lines.singleWhere(
        (l) => l.startsWith('- Oldest devices'),
      );
      expect(line.indexOf('Old Phone'), lessThan(line.indexOf('Work Laptop')));
      expect(line, isNot(contains('Sold Tablet')));
      expect(facts.quotedTerms, containsAll(['Old Phone', 'Work Laptop']));
    });

    test('the fallback names no device but keeps the same slots', () {
      final full = build();
      final plain = build(names: false);
      final text = plain.lines.join('\n');
      for (final name in ['Work Laptop', 'Old Phone', 'Sold Tablet']) {
        expect(text, isNot(contains(name)));
      }
      expect(plain.quotedTerms, ['CNY']);
      expect(plain.slots.map((s) => s.id), full.slots.map((s) => s.id));
      expect(plain.module, InsightModule.deviceFinance);
    });

    test('equal inputs give an equal canonical form', () {
      expect(build().canonical(), build().canonical());
    });

    test('works out the in-service daily share and the recurring burden', () {
      final lines = build().lines;
      final share = lines.singleWhere(
        (l) => l.startsWith('- Daily cost of devices in service'),
      );
      expect(share, contains('across 2 devices'));
      expect(share, matches(RegExp(r'alone is \d+% of it$')));
      expect(
        lines,
        contains(
          '- Daily burden of recurring fees: 1.32 CNY per day added to the '
          'ownership cost of devices in service',
        ),
      );
      // Nothing is retired without being sold in this fixture.
      expect(
        lines.where((l) => l.startsWith('- Retired and not sold')),
        isEmpty,
      );
    });

    test('retired, unsold hardware is the resale pool', () {
      final shelf = Device(
        id: 'old',
        name: 'Shelf Camera',
        category: DeviceCategory.other,
        purchaseDate: DateTime(2019, 1, 1),
        purchasePrice: _cny(2600),
        isRetired: true,
        retiredDate: DateTime(2024, 1, 1),
      );
      final facts = buildDeviceFinanceInsightFacts(
        now: now,
        devices: [laptop, shelf],
        defaultCurrency: 'CNY',
      )!;
      expect(
        facts.lines,
        contains(
          '- Retired and not sold: 1 device bought for 2600 CNY in total: '
          'Shelf Camera (other)',
        ),
      );
      final plain = buildDeviceFinanceInsightFacts(
        now: now,
        devices: [laptop, shelf],
        defaultCurrency: 'CNY',
        includeNames: false,
      )!;
      expect(plain.lines.join('\n'), isNot(contains('Shelf Camera')));
    });
  });

  group('service facts', () {
    final host = Device(
      id: 'h',
      name: 'HOST-NAME',
      category: DeviceCategory.desktop,
    );
    final retiredHost = Device(
      id: 'r',
      name: 'Retired Host',
      category: DeviceCategory.desktop,
      isRetired: true,
    );
    final lan = Network(
      id: 'net',
      name: 'NET-NAME',
      type: NetworkType.values.first,
    );
    final web = ServiceNode(
      id: 'web',
      deviceId: 'h',
      name: 'SERVICE-NAME',
      kind: ServiceKind.web,
      runtime: ServiceRuntime.docker,
      tags: ['TAG-X'],
      notes: 'NOTE-Y',
      dockerCompose: 'COMPOSE-Z',
      endpoints: [
        ServiceEndpoint(
          id: 'e1',
          label: 'ENDPOINT-LABEL',
          protocol: ServiceProtocol.https,
          bindAddress: '10.9.8.7',
          port: 48123,
          path: '/SECRET-PATH',
          networkId: 'net',
          scope: ServiceScope.public,
        ),
      ],
    );
    final clash = ServiceNode(
      id: 'clash',
      deviceId: 'h',
      name: 'Other',
      kind: ServiceKind.media,
      endpoints: [ServiceEndpoint(id: 'e2', port: 48123)],
    );
    final old = ServiceNode(
      id: 'old',
      deviceId: 'r',
      name: 'Old',
      state: ServiceState.deprecated,
    );
    final route = ServiceRoute(
      id: 'route',
      name: 'ROUTE-NAME',
      sourceServiceId: 'web',
      finalUrl: 'https://secret.example.org',
      accessLevel: ServiceAccessLevel.public,
      hops: [
        ServiceRouteHop(
          id: 'hop',
          type: ServiceRouteHopType.reverseProxy,
          host: 'proxy.secret.example',
          label: 'HOP-LABEL',
          method: ServiceRouteMethod.caddy,
        ),
      ],
    );

    InsightFacts build() => buildServiceInsightFacts(
      now: now,
      services: [web, clash, old],
      routes: [route],
      devices: [host, retiredHost],
      networks: [lan],
    )!;

    test('null when there are no services', () {
      expect(
        buildServiceInsightFacts(
          now: now,
          services: const [],
          routes: const [],
          devices: [host],
          networks: const [],
        ),
        isNull,
      );
    });

    test('never sends names, addresses, URLs, ports or free text', () {
      final text = build().lines.join('\n');
      for (final marker in [
        'HOST-NAME',
        'NET-NAME',
        'SERVICE-NAME',
        'TAG-X',
        'NOTE-Y',
        'COMPOSE-Z',
        'ENDPOINT-LABEL',
        '10.9.8.7',
        '48123',
        'SECRET-PATH',
        'ROUTE-NAME',
        'secret.example',
        'HOP-LABEL',
      ]) {
        expect(text, isNot(contains(marker)), reason: marker);
      }
    });

    test('reports counts, conflicts and access paths by enum name', () {
      final lines = build().lines;
      expect(
        lines[1],
        startsWith('- Services: 3; by state: active 2, deprecated 1'),
      );
      expect(
        lines,
        contains(
          '- Hosts: 2 devices run services; 1 of them are retired or sold',
        ),
      );
      final ports = lines.singleWhere((l) => l.startsWith('- Distinct'));
      expect(ports, contains('port conflicts: 1 definite'));
      final paths = lines.singleWhere((l) => l.startsWith('- Access paths'));
      expect(paths, contains('by access level: public 1'));
      expect(paths, contains('by method: caddy 1'));
      expect(lines, contains('- Networks referenced by endpoints: 1'));
    });

    test('reports the busiest host by category and the public share', () {
      final lines = build().lines;
      expect(
        lines,
        contains(
          '- Host concentration: the busiest host (desktop) runs 2 of 3 '
          'services',
        ),
      );
      expect(
        lines.where((l) => l.startsWith('- Publicly exposed access paths: ')),
        hasLength(1),
      );
      expect(lines.join('\n'), isNot(contains('HOST-NAME')));
    });

    test('quotes only tech names, and the canonical form is stable', () {
      final facts = build();
      expect(facts.quotedTerms, serviceInsightTechTerms);
      expect(facts.module, InsightModule.services);
      expect(facts.canonical(), build().canonical());
    });
  });

  group('dataset facts', () {
    final nas = Device(
      id: 'nas',
      name: 'NAS-NAME',
      category: DeviceCategory.other,
      storage: [
        for (var i = 0; i < 3; i++)
          StorageInfo(
            capacity: '8 TB',
            status: i == 0 ? StorageHealth.failed : StorageHealth.ok,
          ),
        const StorageInfo(capacity: '4 TB'),
        const StorageInfo(capacity: '4 TB'),
      ],
      storageArrays: [
        StorageArray(
          id: 'pool',
          name: 'Pool',
          level: RaidLevel.raid5,
          memberIndices: const [0, 1, 2],
        ),
      ],
    );
    final oldPc = Device(
      id: 'pc',
      name: 'PC-NAME',
      category: DeviceCategory.desktop,
      isRetired: true,
      storage: const [StorageInfo(capacity: '2 TB')],
    );
    final media = DataSet(
      id: 'media',
      name: 'Media',
      emoji: '🎬',
      storageLinks: const [
        DataSetStorageLink(deviceId: 'nas', arrayIds: ['pool']),
        DataSetStorageLink(deviceId: 'pc', storageIndices: [0]),
      ],
    );
    final photos = DataSet(
      id: 'photos',
      name: 'Photos',
      emoji: '📷',
      storageLinks: const [
        DataSetStorageLink(deviceId: 'nas', storageIndices: [3, 4]),
      ],
    );
    final notes = DataSet(id: 'notes', name: 'Notes', emoji: '🗒️');

    InsightFacts build({bool names = true}) => buildDatasetInsightFacts(
      now: now,
      datasets: [media, photos, notes],
      devices: [nas, oldPc],
      includeNames: names,
    )!;

    test('null when there are no data sets', () {
      expect(
        buildDatasetInsightFacts(now: now, datasets: const [], devices: [nas]),
        isNull,
      );
    });

    test('counts copies, single-device redundancy and risky places', () {
      final lines = build().lines;
      expect(lines, contains('- Datasets: 3'));
      expect(
        lines,
        contains(
          '- Available copies: 1 with none, 0 with exactly one, '
          '2 with two or more',
        ),
      );
      expect(lines, contains('- Two or more copies but all on one device: 1'));
      expect(
        lines,
        contains('- Datasets with a copy on a degraded RAID array: 1'),
      );
      expect(
        lines,
        contains('- Datasets with a copy on a retired or sold device: 1'),
      );
      expect(
        lines,
        contains(
          '- Highest-risk datasets: Notes (no available copy); '
          'Photos (2 available copies on one device)',
        ),
      );
    });

    test('names only data sets, and the fallback names none', () {
      final full = build();
      expect(full.quotedTerms, containsAll(['Notes', 'Photos']));
      final text = full.lines.join('\n');
      for (final marker in ['NAS-NAME', 'PC-NAME', '🎬', '📷']) {
        expect(text, isNot(contains(marker)), reason: marker);
      }
      final plain = build(names: false);
      expect(plain.lines.join('\n'), isNot(contains('Photos')));
      expect(plain.quotedTerms, isEmpty);
      expect(plain.slots.map((s) => s.id), [
        'redundancySummary',
        'healthRisk',
        'backupAdvice',
      ]);
      expect(plain.module, InsightModule.datasets);
    });
  });
}
