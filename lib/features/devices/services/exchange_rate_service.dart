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

  /// How long an automatic fetch stays suppressed after a failed one.
  static const _failureBackoff = Duration(minutes: 10);

  /// Parsed `exchange_rates.json` per `path|base`, validated by file mtime.
  static final Map<String, _MemoEntry> _memo = <String, _MemoEntry>{};

  /// Fetches currently running, per `path|base`, shared by all callers.
  static final Map<String, Future<DeviceExchangeRateData?>> _inFlight =
      <String, Future<DeviceExchangeRateData?>>{};

  /// When the last automatic fetch failed, per `path|base` (backoff clock).
  static final Map<String, DateTime> _failedAt = <String, DateTime>{};

  /// Purpose: Forget cached rates, running fetches and failure backoff.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Clears the in-memory caches only; no file is touched.
  /// Notes: For tests and for callers that replaced the file out of band.
  static void resetCache() {
    _memo.clear();
    _inFlight.clear();
    _failedAt.clear();
  }

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
        await _fetchAutomatically(base);
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
  /// Notes: The parsed file is memoised per (path, base) and revalidated by the
  /// file's modification time, so repeated conversions do not re-read and
  /// re-parse it while an out-of-band change is still picked up.
  static Future<DeviceExchangeRateData> load(String baseCurrency) async {
    final base = baseCurrency.toUpperCase();
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final key = '${file.path}|$base';
        final stamp = await file.lastModified();
        final memo = _memo[key];
        if (memo != null && memo.stamp == stamp) return memo.data;
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          final data = DeviceExchangeRateData.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
          if (data.baseCurrency == base && data.rates.isNotEmpty) {
            _memo[key] = _MemoEntry(stamp, data);
            return data;
          }
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
  /// Side effects: Atomically replaces `exchange_rates.json` and refreshes
  /// the in-memory memo.
  /// Notes: Written through a temporary file and rename, so a crash cannot
  /// leave a truncated rates file.
  static Future<void> save(DeviceExchangeRateData data) async {
    final file = await _getFile();
    await DeviceStorage.atomicWrite(
      file,
      const JsonEncoder.withIndent('  ').convert(data.toJson()),
    );
    try {
      _memo['${file.path}|${data.baseCurrency.toUpperCase()}'] = _MemoEntry(
        await file.lastModified(),
        data,
      );
    } catch (_) {}
  }

  /// Purpose: Fetch and save latest from the relevant source.
  /// Inputs: `baseCurrency`.
  /// Returns: `Future<DeviceExchangeRateData?>`.
  /// Side effects: Network fetch and file write; concurrent callers for the
  /// same base share one request.
  /// Notes: An explicit call (settings "refresh") ignores the failure backoff
  /// and clears it on success; the automatic paths use [_fetchAutomatically].
  static Future<DeviceExchangeRateData?> fetchAndSaveLatest(
    String baseCurrency,
  ) => _fetchShared(baseCurrency.toUpperCase(), respectBackoff: false);

  /// Purpose: Fetch for the automatic paths (convert / refreshIfNeeded).
  /// Inputs: `base` - upper-case base currency.
  /// Returns: The fresh data, or null when the fetch failed or is backing off.
  /// Side effects: Same as [fetchAndSaveLatest].
  /// Notes: Internal helper; after a failure no further automatic request is
  /// made for 10 minutes, so a dead network costs one request, not one per
  /// conversion.
  static Future<DeviceExchangeRateData?> _fetchAutomatically(String base) =>
      _fetchShared(base, respectBackoff: true);

  /// Purpose: Run (or join) the single fetch-and-save for [base].
  /// Inputs: `base`, `respectBackoff`.
  /// Returns: The saved data, or null on failure / while backing off.
  /// Side effects: Network request, atomic file write, updates the backoff clock.
  /// Notes: Internal helper; keyed by the storage path so swapped storage
  /// folders never share state.
  static Future<DeviceExchangeRateData?> _fetchShared(
    String base, {
    required bool respectBackoff,
  }) async {
    final file = await _getFile();
    final key = '${file.path}|$base';
    final running = _inFlight[key];
    if (running != null) return running;
    if (respectBackoff) {
      final failed = _failedAt[key];
      if (failed != null &&
          DateTime.now().difference(failed) < _failureBackoff) {
        return null;
      }
    }
    final future = () async {
      final fetched = await fetchLatest(base);
      if (fetched == null) {
        _failedAt[key] = DateTime.now();
        return null;
      }
      _failedAt.remove(key);
      await save(fetched);
      return fetched;
    }();
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
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
      data = await _fetchAutomatically(base) ?? data;
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

/// A memoised, parsed rates file together with the mtime it was read at.
class _MemoEntry {
  final DateTime stamp;
  final DeviceExchangeRateData data;

  /// Purpose: Pair parsed rates with the file mtime they came from.
  /// Inputs: `stamp`, `data`.
  /// Returns: A new `_MemoEntry`.
  /// Side effects: None.
  /// Notes: Internal to this file.
  const _MemoEntry(this.stamp, this.data);
}
