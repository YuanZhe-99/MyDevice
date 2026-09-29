import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_device/features/devices/services/exchange_rate_service.dart';

import 'support/fake_storage.dart';

/// Purpose: Test the exchange-rate service's request economy.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: A `MockClient` counts the requests `http.get` makes through
/// `http.runWithClient`. One successful fetch must serve later conversions
/// from the saved file, a failed one must not be retried on every conversion,
/// and simultaneous conversions must share a single request.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await seedAppDir('mydevice_exchange_cache');
    DeviceExchangeRateService.resetCache();
  });

  tearDown(() {
    DeviceExchangeRateService.resetCache();
    deleteSeededDir(tempDir);
  });

  http.Response ok() => http.Response(
    jsonEncode({
      'result': 'success',
      'rates': {'USD': 1.0, 'EUR': 0.5},
    }),
    200,
  );

  Future<double> convertEur() async => (await DeviceExchangeRateService.convert(
    amount: 10,
    currency: 'EUR',
    defaultCurrency: 'USD',
    autoRate: true,
  )).exchangeRate;

  test('three conversions make one request and use the fetched rate', () async {
    var requests = 0;
    final rates = await http.runWithClient(
      () async => [await convertEur(), await convertEur(), await convertEur()],
      () => MockClient((_) async {
        requests++;
        return ok();
      }),
    );
    expect(requests, 1);
    expect(rates, everyElement(2.0)); // 1 EUR = 2 USD when USD->EUR is 0.5
  });

  test('simultaneous conversions share one in-flight request', () async {
    var requests = 0;
    await http.runWithClient(
      () => Future.wait([convertEur(), convertEur(), convertEur()]),
      () => MockClient((_) async {
        requests++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return ok();
      }),
    );
    expect(requests, 1);
  });

  test('a failed fetch backs off; an explicit refresh does not', () async {
    var requests = 0;
    await http.runWithClient(
      () async {
        // Falls back to the built-in rates every time, but asks the network
        // only once.
        for (var i = 0; i < 3; i++) {
          expect(await convertEur(), greaterThan(0));
        }
        expect(requests, 1);

        final refreshed = await DeviceExchangeRateService.fetchAndSaveLatest(
          'USD',
        );
        expect(refreshed, isNull);
        expect(requests, 2);
      },
      () => MockClient((_) async {
        requests++;
        return http.Response('down', 503);
      }),
    );
  });

  test('a successful explicit refresh is written atomically', () async {
    await http.runWithClient(() async {
      final data = await DeviceExchangeRateService.fetchAndSaveLatest('USD');
      expect(data, isNotNull);
    }, () => MockClient((_) async => ok()));
    final loaded = await DeviceExchangeRateService.load('USD');
    expect(loaded.rates['EUR'], 0.5);
    final leftovers = tempDir
        .listSync(recursive: true)
        .where((e) => e.path.contains('.tmp'));
    expect(leftovers, isEmpty);
  });
}
