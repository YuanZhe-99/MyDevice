import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/device.dart';
import 'device_storage.dart';

class ExchangeRateException implements Exception {
  final String message;

  const ExchangeRateException(this.message);

  @override
  String toString() => message;
}

class DeviceExchangeRateData {
  final String baseCurrency;
  final Map<String, double> rates;
  final DateTime? lastFetchedAt;

  const DeviceExchangeRateData({
    required this.baseCurrency,
    required this.rates,
    this.lastFetchedAt,
  });

  Map<String, dynamic> toJson() => {
    'baseCurrency': baseCurrency,
    'rates': rates,
    if (lastFetchedAt != null)
      'lastFetchedAt': lastFetchedAt!.toIso8601String(),
  };

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

  static Future<String> getDefaultCurrency() async {
    final config = await DeviceStorage.readConfig();
    return (config['defaultCurrency'] as String? ?? defaultDefaultCurrency)
        .toUpperCase();
  }

  static Future<void> setDefaultCurrency(String currency) async {
    final config = await DeviceStorage.readConfig();
    config['defaultCurrency'] = currency.toUpperCase();
    await DeviceStorage.writeConfig(config);
  }

  static Future<bool> getAutoUpdateEnabled() async {
    final config = await DeviceStorage.readConfig();
    return config['autoUpdateExchangeRates'] as bool? ?? true;
  }

  static Future<void> setAutoUpdateEnabled(bool enabled) async {
    final config = await DeviceStorage.readConfig();
    config['autoUpdateExchangeRates'] = enabled;
    await DeviceStorage.writeConfig(config);
  }

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

  static Future<File> _getFile() async {
    final appDir = await DeviceStorage.getAppDir();
    return File(p.join(appDir.path, _fileName));
  }

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

  static Future<void> save(DeviceExchangeRateData data) async {
    final file = await _getFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data.toJson()),
    );
  }

  static Future<DeviceExchangeRateData?> fetchAndSaveLatest(
    String baseCurrency,
  ) async {
    final fetched = await fetchLatest(baseCurrency);
    if (fetched == null) return null;
    await save(fetched);
    return fetched;
  }

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

  static bool _shouldFetchToday(DateTime? lastFetch) {
    if (lastFetch == null) return true;
    final now = DateTime.now();
    return now.year != lastFetch.year ||
        now.month != lastFetch.month ||
        now.day != lastFetch.day;
  }

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
