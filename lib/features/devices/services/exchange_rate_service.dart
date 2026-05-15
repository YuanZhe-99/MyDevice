import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/device.dart';
import 'device_storage.dart';

class ExchangeRateException implements Exception {
  final String message;

  /// Purpose: Create an exchange rate exception instance.
  /// Inputs: `message`.
  /// Returns: A new `ExchangeRateException` instance.
  /// Side effects: Implementation-dependent.
  /// Notes: Implementations should preserve this contract.
  const ExchangeRateException(this.message);

  /// Purpose: Implement the to string behavior for this file.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  @override
  String toString() => message;
}

class DeviceExchangeRateData {
  final String baseCurrency;
  final Map<String, double> rates;
  final DateTime? lastFetchedAt;

  /// Purpose: Create a device exchange rate data instance.
  /// Inputs: None.
  /// Returns: A new `DeviceExchangeRateData` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  const DeviceExchangeRateData({
    required this.baseCurrency,
    required this.rates,
    this.lastFetchedAt,
  });

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Keep the output aligned with the persisted file and sync format.
  Map<String, dynamic> toJson() => {
    'baseCurrency': baseCurrency,
    'rates': rates,
    if (lastFetchedAt != null)
      'lastFetchedAt': lastFetchedAt!.toIso8601String(),
  };

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `DeviceExchangeRateData.fromJson` instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  factory DeviceExchangeRateData.fromJson(Map<String, dynamic> json) =>
      DeviceExchangeRateData(
        baseCurrency: json['baseCurrency'] as String? ?? 'USD',
        rates:
            (json['rates'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k.toUpperCase(), (v as num).toDouble()),
            ) ??
            const {},
        lastFetchedAt: json['lastFetchedAt'] != null
            ? DateTime.parse(json['lastFetchedAt'] as String)
            : null,
      );
}

class DeviceExchangeRateService {
  static const _fileName = 'exchange_rates.json';
  static const _baseUrl = 'https://open.er-api.com/v6/latest';
  static const defaultDefaultCurrency = 'USD';

  static const supportedCurrencies = [
    'USD',
    'CNY',
    'EUR',
    'GBP',
    'JPY',
    'CAD',
    'AUD',
    'TWD',
    'HKD',
    'SGD',
    'KRW',
    'CHF',
    'NZD',
    'INR',
  ];

  /// Purpose: Implement the currency symbol behavior for this file.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static String currencySymbol(String code) => switch (code.toUpperCase()) {
    'CNY' => '¥',
    'USD' => r'$',
    'EUR' => '€',
    'GBP' => '£',
    'JPY' => '¥',
    'CAD' => r'C$',
    'AUD' => r'A$',
    'TWD' => r'NT$',
    'HKD' => r'HK$',
    'SGD' => r'S$',
    'KRW' => '₩',
    'CHF' => 'Fr',
    'NZD' => r'NZ$',
    'INR' => '₹',
    _ => code.toUpperCase(),
  };

  /// Purpose: Implement the get default currency behavior for this file.
  /// Inputs: None.
  /// Returns: `Future<String>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<String> getDefaultCurrency() async {
    final config = await DeviceStorage.readConfig();
    return (config['defaultCurrency'] as String? ?? defaultDefaultCurrency)
        .toUpperCase();
  }

  /// Purpose: Update default currency with the provided value.
  /// Inputs: `currency`.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> setDefaultCurrency(String currency) async {
    final config = await DeviceStorage.readConfig();
    config['defaultCurrency'] = currency.toUpperCase();
    await DeviceStorage.writeConfig(config);
  }

  /// Purpose: Implement the get auto update enabled behavior for this file.
  /// Inputs: None.
  /// Returns: `Future<bool>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<bool> getAutoUpdateEnabled() async {
    final config = await DeviceStorage.readConfig();
    return config['autoUpdateExchangeRates'] as bool? ?? true;
  }

  /// Purpose: Update auto update enabled with the provided value.
  /// Inputs: `enabled`.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> setAutoUpdateEnabled(bool enabled) async {
    final config = await DeviceStorage.readConfig();
    config['autoUpdateExchangeRates'] = enabled;
    await DeviceStorage.writeConfig(config);
  }

  /// Purpose: Implement the refresh if needed behavior for this file.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> refreshIfNeeded() async {
    try {
      if (!await getAutoUpdateEnabled()) return;
      final base = await getDefaultCurrency();
      final data = await load(base);
      if (_shouldFetchToday(data.lastFetchedAt) || data.baseCurrency != base) {
        await fetchAndSaveLatest(base);
      }
    } catch (_) {}
  }

  /// Purpose: Provide the internal get file helper for this file.
  /// Inputs: None.
  /// Returns: `Future<File>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
  static Future<File> _getFile() async {
    final appDir = await DeviceStorage.getAppDir();
    return File(p.join(appDir.path, _fileName));
  }

  /// Purpose: Load the relevant data into the current workflow or state.
  /// Inputs: `baseCurrency`.
  /// Returns: `Future<DeviceExchangeRateData>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  static Future<DeviceExchangeRateData> load(String baseCurrency) async {
    final base = baseCurrency.toUpperCase();
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          final data = DeviceExchangeRateData.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
          if (data.baseCurrency == base && data.rates.isNotEmpty) return data;
        }
      }
    } catch (_) {}
    return DeviceExchangeRateData(
      baseCurrency: base,
      rates: _fallbackRatesFor(base),
    );
  }

  /// Purpose: Save the relevant data to the relevant storage or service layer.
  /// Inputs: `data`.
  /// Returns: `Future<void>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  static Future<void> save(DeviceExchangeRateData data) async {
    final file = await _getFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data.toJson()),
    );
  }

  /// Purpose: Fetch and save latest from the relevant source.
  /// Inputs: `baseCurrency`.
  /// Returns: `Future<DeviceExchangeRateData?>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<DeviceExchangeRateData?> fetchAndSaveLatest(
    String baseCurrency,
  ) async {
    final fetched = await fetchLatest(baseCurrency);
    if (fetched == null) return null;
    await save(fetched);
    return fetched;
  }

  /// Purpose: Fetch latest from the relevant source.
  /// Inputs: `baseCurrency`.
  /// Returns: `Future<DeviceExchangeRateData?>`.
  /// Side effects: May perform network I/O.
  /// Notes: None.
  static Future<DeviceExchangeRateData?> fetchLatest(
    String baseCurrency,
  ) async {
    final base = baseCurrency.toUpperCase();
    try {
      final uri = Uri.parse('$_baseUrl/$base');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['result'] != 'success') return null;
      final rawRates = json['rates'] as Map<String, dynamic>;
      return DeviceExchangeRateData(
        baseCurrency: base,
        rates: rawRates.map(
          (k, v) => MapEntry(k.toUpperCase(), (v as num).toDouble()),
        ),
        lastFetchedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Implement the convert optional behavior for this file.
  /// Inputs: `extraJson`.
  /// Returns: `Future<MoneyValue?>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<MoneyValue?> convertOptional({
    required double? amount,
    required String currency,
    required String defaultCurrency,
    required bool autoRate,
    double? manualRate,
    Map<String, dynamic> extraJson = const {},
  }) async {
    if (amount == null) return null;
    return convert(
      amount: amount,
      currency: currency,
      defaultCurrency: defaultCurrency,
      autoRate: autoRate,
      manualRate: manualRate,
      extraJson: extraJson,
    );
  }

  /// Purpose: Implement the convert behavior for this file.
  /// Inputs: `extraJson`.
  /// Returns: `Future<MoneyValue>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<MoneyValue> convert({
    required double amount,
    required String currency,
    required String defaultCurrency,
    required bool autoRate,
    double? manualRate,
    Map<String, dynamic> extraJson = const {},
  }) async {
    final from = currency.toUpperCase();
    final base = defaultCurrency.toUpperCase();
    final rate = await _rateToDefault(
      from: from,
      base: base,
      autoRate: autoRate,
      manualRate: manualRate,
    );
    return MoneyValue(
      amount: amount,
      currency: from,
      defaultCurrency: base,
      convertedAmount: amount * rate,
      exchangeRate: rate,
      autoRate: autoRate,
      rateUpdatedAt: DateTime.now(),
      extraJson: extraJson,
    );
  }

  /// Purpose: Provide the internal rate to default helper for this file.
  /// Inputs: None.
  /// Returns: `Future<double>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Future<double> _rateToDefault({
    required String from,
    required String base,
    required bool autoRate,
    double? manualRate,
  }) async {
    if (from == base) return 1.0;
    if (!autoRate) {
      if (manualRate == null || manualRate <= 0) {
        throw const ExchangeRateException('manual_rate_required');
      }
      return manualRate;
    }

    var data = await load(base);
    if (await getAutoUpdateEnabled() && _shouldFetchToday(data.lastFetchedAt)) {
      data = await fetchAndSaveLatest(base) ?? data;
    }

    final baseToFrom = data.rates[from];
    if (baseToFrom != null && baseToFrom > 0) return 1 / baseToFrom;

    final fallback = _fallbackRatesFor(base)[from];
    if (fallback != null && fallback > 0) return 1 / fallback;

    throw const ExchangeRateException('exchange_rate_unavailable');
  }

  /// Purpose: Provide the internal should fetch today helper for this file.
  /// Inputs: `lastFetch`.
  /// Returns: `bool`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static bool _shouldFetchToday(DateTime? lastFetch) {
    if (lastFetch == null) return true;
    final now = DateTime.now();
    return now.year != lastFetch.year ||
        now.month != lastFetch.month ||
        now.day != lastFetch.day;
  }

  /// Purpose: Provide the internal fallback rates for helper for this file.
  /// Inputs: `baseCurrency`.
  /// Returns: `Map<String, double>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Map<String, double> _fallbackRatesFor(String baseCurrency) {
    final base = baseCurrency.toUpperCase();
    final basePerUsd = _usdFallbackRates[base] ?? 1.0;
    return {
      for (final entry in _usdFallbackRates.entries)
        entry.key: entry.value / basePerUsd,
    };
  }

  static const Map<String, double> _usdFallbackRates = {
    'USD': 1.0,
    'CNY': 7.25,
    'EUR': 0.92,
    'GBP': 0.79,
    'JPY': 155.0,
    'CAD': 1.36,
    'AUD': 1.52,
    'TWD': 32.4,
    'HKD': 7.82,
    'SGD': 1.35,
    'KRW': 1360.0,
    'CHF': 0.90,
    'NZD': 1.66,
    'INR': 83.5,
  };
}
