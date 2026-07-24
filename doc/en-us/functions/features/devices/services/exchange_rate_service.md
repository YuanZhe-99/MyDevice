# lib/features/devices/services/exchange_rate_service.dart

`DeviceExchangeRateService` fetches and caches currency exchange rates (from
`open.er-api.com`) and converts arbitrary amounts into the app's default currency, producing the
`MoneyValue` records used by `Device.purchasePrice`/`soldPrice`/`DeviceRecurringCost.price` (see
[`../../models/device.md`](../models/device.md)). It persists rates to `exchange_rates.json` and
reads/writes its settings (`defaultCurrency`, `autoUpdateExchangeRates`) through
[`device_storage.md`](device_storage.md)'s generic `readConfig`/`writeConfig` config store. See
[Devices](../../../../features/devices.md) for how `MoneyValue`/finance fields consume the
conversions this file produces.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`ExchangeRateException`](#exchangerateexception-new) | constructor | A | Create an exception carrying a machine-readable error code. |
| `toString` | method (`ExchangeRateException`) | B | Return the exception's message. |
| [`DeviceExchangeRateData`](#deviceexchangeratedata-new) | constructor | A | Create a `DeviceExchangeRateData` instance. |
| [`toJson`](#deviceexchangeratedata-tojson) | method (`DeviceExchangeRateData`) | A | Serialize this value into a JSON-compatible map. |
| [`DeviceExchangeRateData.fromJson`](#deviceexchangeratedata-fromjson) | factory constructor | A | Parse a `DeviceExchangeRateData` from a JSON-compatible map. |
| [`currencySymbol`](#currencysymbol) | static method | A | Map a currency code to its display symbol. |
| [`getDefaultCurrency`](#getdefaultcurrency) | static method | A | Read the app's default currency code. |
| [`setDefaultCurrency`](#setdefaultcurrency) | static method | A | Persist the app's default currency code. |
| [`getAutoUpdateEnabled`](#getautoupdateenabled) | static method | A | Read whether daily automatic rate refresh is enabled. |
| [`setAutoUpdateEnabled`](#setautoupdateenabled) | static method | A | Persist whether daily automatic rate refresh is enabled. |
| [`refreshIfNeeded`](#refreshifneeded) | static method | A | Refresh rates from the network if auto-update is on and they're stale. |
| [`_getFile`](#_getfile) | static method (private) | A | Resolve the `exchange_rates.json` file in the current app directory. |
| [`load`](#load) | static method | A | Load cached rates for a base currency, or built-in fallback rates. |
| [`save`](#save) | static method | A | Persist rate data to `exchange_rates.json`. |
| [`fetchAndSaveLatest`](#fetchandsavelatest) | static method | A | Fetch latest rates from the network and persist them. |
| [`fetchLatest`](#fetchlatest) | static method | A | Fetch latest rates from `open.er-api.com` for a base currency. |
| [`convertOptional`](#convertoptional) | static method | A | Convert a nullable amount into a `MoneyValue`, or `null` if the amount is `null`. |
| [`convert`](#convert) | static method | A | Convert an amount into a `MoneyValue` in the app's default currency. |
| [`_rateToDefault`](#_ratetodefault) | static method (private) | A | Resolve the exchange rate to use for a conversion (manual, cached, or fetched). |
| [`_shouldFetchToday`](#_shouldfetchtoday) | static method (private) | A | Return whether cached rates are stale (last fetched on a different calendar day). |
| [`_fallbackRatesFor`](#_fallbackratesfor) | static method (private) | A | Derive hardcoded fallback rates for an arbitrary base currency. |

Row count (21) matches `grep -c 'Purpose:' exchange_rate_service.dart` (21) exactly.

## Documentation

### `const ExchangeRateException(this.message)` <a id="exchangerateexception-new"></a>
- **Kind:** constructor of `ExchangeRateException` (implements `Exception`).
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 18).
- **Purpose:** Wrap a machine-readable error code (not a localized message) describing why a
  currency conversion could not be completed.
- **Inputs:** `message` — one of the fixed code strings `'manual_rate_required'` or
  `'exchange_rate_unavailable'` (see [`_rateToDefault`](#_ratetodefault)).
- **Returns:** A new `ExchangeRateException`.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:** Thrown by [`_rateToDefault`](#_ratetodefault); caught in `device_edit_page.dart`'s
  save handler, which maps `message` to a localized string (`exchangeRateManualRequired` /
  `exchangeRateUnavailable`) for the snackbar shown to the user.
- **Notes:** `message` is a stable code, not a human-readable sentence — callers must translate it
  themselves rather than displaying it directly.

### `Map<String, dynamic> DeviceExchangeRateData.toJson()` <a id="deviceexchangeratedata-tojson"></a>
- **Kind:** method of `DeviceExchangeRateData`.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 50).
- **Purpose:** Serialize this rate snapshot into the JSON persisted to `exchange_rates.json`.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` with `baseCurrency`, `rates`, and an ISO-8601
  `lastFetchedAt` when present.
- **Side effects:** None.
- **Algorithm:** Direct field mapping; `lastFetchedAt` only included when non-null.
- **Usage:** Called by [`save`](#save).
- **Notes:** None.

### `factory DeviceExchangeRateData.fromJson(Map<String, dynamic> json)` <a id="deviceexchangeratedata-fromjson"></a>
- **Kind:** factory constructor of `DeviceExchangeRateData`.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 62).
- **Purpose:** Parse a cached rate snapshot from `exchange_rates.json`, tolerating missing keys.
- **Inputs:** `json`.
- **Returns:** A new `DeviceExchangeRateData`; `baseCurrency` defaults to `'USD'`; `rates` keys are
  upper-cased on parse; `rates` defaults to `{}` if absent.
- **Side effects:** None.
- **Algorithm:** Read `baseCurrency` with a `'USD'` default; map `rates` entries to upper-cased keys
  with `num.toDouble()` values; parse `lastFetchedAt` via `DateTime.parse` only when present.
- **Usage:** Called by [`load`](#load).
- **Notes:** Currency codes are always normalized to upper case on both read and write paths in
  this file, so lookups (`data.rates[from]`) never need a case-insensitive comparison.

### `static String currencySymbol(String code)` <a id="currencysymbol"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 103).
- **Purpose:** Map a currency code to its conventional display symbol (`$`, `€`, `¥`, etc.).
- **Inputs:** `code` — any string, case-insensitively upper-cased before matching.
- **Returns:** `String` — the mapped symbol for one of the 14 `supportedCurrencies`, or the
  upper-cased `code` itself as a fallback for anything unrecognized.
- **Side effects:** None.
- **Algorithm:** A `switch` expression over `code.toUpperCase()` with one case per supported
  currency (note `CNY` and `JPY` both map to `¥`), falling through to the code itself (`_ =>
  code.toUpperCase()`) for unknown codes.
- **Usage:**
  ```dart
  final symbol = DeviceExchangeRateService.currencySymbol(money.currency);
  return '${DeviceExchangeRateService.currencySymbol(currency)}${amount.toStringAsFixed(2)}';
  ```
  (from `device_detail_page.dart`'s money-formatting helpers)
- **Notes:** An unrecognized code degrades gracefully to showing the code itself (e.g. `"XYZ12.34"`)
  rather than throwing or showing a blank symbol.

### `static Future<String> getDefaultCurrency()` <a id="getdefaultcurrency"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 126).
- **Purpose:** Read the app's configured default currency code (the currency all `MoneyValue`s are
  converted into).
- **Inputs:** None.
- **Returns:** `Future<String>` — upper-cased; `defaultDefaultCurrency` (`'USD'`) if unset.
- **Side effects:** Reads `storage_config.json` via `DeviceStorage.readConfig()` (see
  [`device_storage.md#readconfig`](device_storage.md)).
- **Algorithm:** `(config['defaultCurrency'] as String? ?? 'USD').toUpperCase()`.
- **Usage:**
  ```dart
  final currency = await DeviceExchangeRateService.getDefaultCurrency();
  ```
  (from `device_edit_page.dart`, `device_list_page.dart`, and `settings_page.dart`)
- **Notes:** None.

### `static Future<void> setDefaultCurrency(String currency)` <a id="setdefaultcurrency"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 137).
- **Purpose:** Persist the app's default currency code.
- **Inputs:** `currency`.
- **Returns:** `Future<void>`.
- **Side effects:** Reads then rewrites `storage_config.json` via `DeviceStorage`.
- **Algorithm:** Read config, set `config['defaultCurrency'] = currency.toUpperCase()`, write back.
- **Usage:**
  ```dart
  await DeviceExchangeRateService.setDefaultCurrency(value);
  ```
  (from `settings_page.dart`'s default-currency picker)
- **Notes:** Changing the default currency does not retroactively re-convert any already-stored
  `MoneyValue`s — it only affects future conversions.

### `static Future<bool> getAutoUpdateEnabled()` <a id="getautoupdateenabled"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 148).
- **Purpose:** Read whether daily automatic exchange-rate refresh is enabled.
- **Inputs:** None.
- **Returns:** `Future<bool>` — defaults to `true` if unset.
- **Side effects:** Reads `storage_config.json`.
- **Algorithm:** `config['autoUpdateExchangeRates'] as bool? ?? true`.
- **Usage:** Called by [`refreshIfNeeded`](#refreshifneeded) and [`_rateToDefault`](#_ratetodefault);
  also read directly by `settings_page.dart` and `device_edit_page.dart` to decide whether to show
  a manual-rate entry field.
- **Notes:** Defaulting to `true` means automatic updates are opt-out, not opt-in.

### `static Future<void> setAutoUpdateEnabled(bool enabled)` <a id="setautoupdateenabled"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 158).
- **Purpose:** Persist whether daily automatic exchange-rate refresh is enabled.
- **Inputs:** `enabled`.
- **Returns:** `Future<void>`.
- **Side effects:** Reads then rewrites `storage_config.json`.
- **Algorithm:** Read config, set the flag, write back.
- **Usage:**
  ```dart
  await DeviceExchangeRateService.setAutoUpdateEnabled(value);
  ```
  (from `settings_page.dart`'s auto-update toggle)
- **Notes:** None.

### `static Future<void> refreshIfNeeded()` <a id="refreshifneeded"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 169).
- **Purpose:** Refresh exchange rates from the network once per day, if the user has enabled
  automatic updates.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** May write `exchange_rates.json`; performs a network request via
  [`fetchAndSaveLatest`](#fetchandsavelatest) when rates are stale.
- **Algorithm:** Wrapped entirely in a `try`/`catch` that swallows all errors. 1. If auto-update is
  disabled, return immediately. 2. Load the current default currency and its cached rate data. 3.
  If [`_shouldFetchToday`](#_shouldfetchtoday) says the cache is stale, or the cached data's
  `baseCurrency` no longer matches the current default currency, fetch and save fresh rates.
- **Usage:**
  ```dart
  // Refresh exchange rates daily when the user enabled automatic updates.
  DeviceExchangeRateService.refreshIfNeeded();
  ```
  (from `lib/main.dart`, fired-and-forgotten — not awaited — during app startup, alongside
  `BackupService.runAutoBackupIfNeeded()`)
- **Notes:** Called without `await` at startup, so app launch is never blocked on a network round
  trip; any failure (offline, API error) is silently absorbed and simply retried on the next
  qualifying call (app restart, or any conversion that goes through
  [`_rateToDefault`](#_ratetodefault)).

### `static Future<DeviceExchangeRateData> load(String baseCurrency)` <a id="load"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 195).
- **Purpose:** Load cached exchange rate data for a base currency, falling back to built-in
  hardcoded rates when nothing valid is cached.
- **Inputs:** `baseCurrency`.
- **Returns:** `Future<DeviceExchangeRateData>` — always non-null; never throws.
- **Side effects:** Reads `exchange_rates.json`.
- **Algorithm:** Wrapped in `try`/`catch` (any error falls through to the fallback). 1. If the file
  exists and has content, parse it. 2. Only accept the cached data if its `baseCurrency` matches the
  requested one *and* it actually has rates — otherwise fall through. 3. Fallback:
  `DeviceExchangeRateData(baseCurrency: base, rates: _fallbackRatesFor(base))`.
- **Usage:** Called by [`refreshIfNeeded`](#refreshifneeded) and [`_rateToDefault`](#_ratetodefault).
- **Notes:** A cached file for the *wrong* base currency (e.g. the user just changed their default
  currency) is treated as absent, not converted — the caller gets fresh fallback rates for the new
  base until the next successful fetch.

### `static Future<void> save(DeviceExchangeRateData data)` <a id="save"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 220).
- **Purpose:** Persist rate data to `exchange_rates.json`.
- **Inputs:** `data`.
- **Returns:** `Future<void>`.
- **Side effects:** Writes `exchange_rates.json` (pretty-printed, non-atomic).
- **Algorithm:** JSON-encode `data.toJson()`, write it.
- **Usage:** Called by [`fetchAndSaveLatest`](#fetchandsavelatest).
- **Notes:** None.

### `static Future<DeviceExchangeRateData?> fetchAndSaveLatest(String baseCurrency)` <a id="fetchandsavelatest"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 232).
- **Purpose:** Fetch the latest rates from the network for a base currency and persist them if
  successful.
- **Inputs:** `baseCurrency`.
- **Returns:** `Future<DeviceExchangeRateData?>` — `null` if the fetch failed.
- **Side effects:** Network request via [`fetchLatest`](#fetchlatest); writes
  `exchange_rates.json` via [`save`](#save) on success.
- **Algorithm:** Fetch; if `null`, return `null` without writing; otherwise save and return the
  fetched data.
- **Usage:**
  ```dart
  final result = await DeviceExchangeRateService.fetchAndSaveLatest(_defaultCurrency);
  ```
  (from `settings_page.dart`'s manual "refresh rates now" button, and internally by
  [`refreshIfNeeded`](#refreshifneeded)/[`_rateToDefault`](#_ratetodefault))
- **Notes:** None.

### `static Future<DeviceExchangeRateData?> fetchLatest(String baseCurrency)` <a id="fetchlatest"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 246).
- **Purpose:** Fetch the latest exchange rates for a base currency from `open.er-api.com`.
- **Inputs:** `baseCurrency`.
- **Returns:** `Future<DeviceExchangeRateData?>` — `null` on any HTTP error, non-`success` API
  result, or exception (timeout, network error, malformed JSON).
- **Side effects:** Sends an HTTP GET to `https://open.er-api.com/v6/latest/<base>` with a 10s
  timeout.
- **Algorithm:** GET the endpoint; return `null` unless status is 200 and the decoded body's
  `result` field is `'success'`; otherwise map `rates` to upper-cased keys with `double` values and
  stamp `lastFetchedAt: DateTime.now()`. The whole method is wrapped in `try`/`catch` returning
  `null` on any exception.
- **Usage:** Called only by [`fetchAndSaveLatest`](#fetchandsavelatest).
- **Notes:** Uses a third-party free API (`open.er-api.com`) with no API key; all failure modes
  degrade to `null` rather than throwing, so callers always have a defined "fetch failed" path.

### `static Future<MoneyValue?> convertOptional({required double? amount, required String currency, required String defaultCurrency, required bool autoRate, double? manualRate, Map<String, dynamic> extraJson = const {}})` <a id="convertoptional"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 274).
- **Purpose:** Convert a nullable amount into a `MoneyValue`, short-circuiting to `null` when there
  is no amount to convert.
- **Inputs:** `amount` (nullable); `currency`, `defaultCurrency`, `autoRate`; optional `manualRate`,
  `extraJson`.
- **Returns:** `Future<MoneyValue?>` — `null` iff `amount` is `null`.
- **Side effects:** Same as [`convert`](#convert) when `amount` is non-null.
- **Algorithm:** Null-check on `amount`, then delegate entirely to [`convert`](#convert).
- **Usage:**
  ```dart
  purchasePrice = await DeviceExchangeRateService.convertOptional(
    amount: _parseAmount(_purchasePriceCtrl.text),
    currency: _purchaseCurrency,
    defaultCurrency: _defaultCurrency,
    autoRate: _purchaseAutoRate,
    manualRate: _parseRate(_purchaseRateCtrl, _purchaseCurrency),
    extraJson: widget.device?.purchasePrice?.extraJson ?? const {},
  );
  ```
  (from `device_edit_page.dart`'s save handler, for the optional `purchasePrice`/`soldPrice`
  fields)
- **Notes:** Exists so callers with an optional price field don't need their own null-check
  wrapper around `convert`.

### `static Future<MoneyValue> convert({required double amount, required String currency, required String defaultCurrency, required bool autoRate, double? manualRate, Map<String, dynamic> extraJson = const {}})` <a id="convert"></a>
- **Kind:** static method.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 298).
- **Purpose:** Convert an amount in an arbitrary currency into a `MoneyValue` carrying both the
  original amount and its converted value in the app's default currency.
- **Inputs:** `amount`, `currency`, `defaultCurrency`, `autoRate`; optional `manualRate` (required
  when `autoRate` is false), `extraJson`.
- **Returns:** `Future<MoneyValue>` with `convertedAmount = amount * rate` and
  `rateUpdatedAt: DateTime.now()`.
- **Side effects:** Same as [`_rateToDefault`](#_ratetodefault) (may read cache, may fetch from the
  network).
- **Algorithm:** Upper-case both currency codes, resolve the rate via
  [`_rateToDefault`](#_ratetodefault), then construct the `MoneyValue`.
- **Usage:**
  ```dart
  final price = await DeviceExchangeRateService.convert(
    amount: draft.rawAmount,
    currency: draft.currency,
    defaultCurrency: _defaultCurrency,
    autoRate: draft.autoRate,
    manualRate: draft.autoRate ? null : _parseRate(draft.rateCtrl, draft.currency),
    extraJson: draft.existing?.price.extraJson ?? const {},
  );
  ```
  (from `device_edit_page.dart`'s save handler, building each `DeviceRecurringCost.price`)
- **Notes:** Can throw [`ExchangeRateException`](#exchangerateexception-new) (propagated from
  `_rateToDefault`) — callers must catch it, as `device_edit_page.dart` does.

### `static Future<double> _rateToDefault({required String from, required String base, required bool autoRate, double? manualRate})` <a id="_ratetodefault"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 331).
- **Purpose:** Resolve the numeric exchange rate to multiply an amount by, choosing between
  identity, a manual rate, or cached/freshly-fetched automatic rates.
- **Inputs:** `from`, `base`, `autoRate`; optional `manualRate`.
- **Returns:** `Future<double>`.
- **Side effects:** May read `exchange_rates.json` (via [`load`](#load)) and perform a network
  fetch (via [`fetchAndSaveLatest`](#fetchandsavelatest)) when auto-update is enabled and the
  cache is stale.
- **Algorithm:** 1. If `from == base`, return `1.0` immediately. 2. If `autoRate` is false: require
  a positive `manualRate`, throwing `ExchangeRateException('manual_rate_required')` otherwise;
  return it directly. 3. Otherwise (`autoRate` true): load cached rate data for `base`; if
  auto-update is enabled and the cache is stale ([`_shouldFetchToday`](#_shouldfetchtoday)),
  attempt a fresh fetch, falling back to the stale cached data if the fetch itself fails. 4. Try
  `data.rates[from]` (a base→from rate) and invert it (`1 / baseToFrom`) to get from→base. 5. If
  that key is missing or non-positive, fall back to `_fallbackRatesFor(base)[from]`, inverted the
  same way. 6. If neither source has a usable rate, throw
  `ExchangeRateException('exchange_rate_unavailable')`.
- **Usage:** Called by [`convert`](#convert).
- **Notes:** The API's `rates` map is keyed `base → other`, so converting `from → base` always
  requires inverting (`1 / rate`) — every rate lookup in this method does that inversion, both for
  the live cache and the hardcoded fallback table.

### `static bool _shouldFetchToday(DateTime? lastFetch)` <a id="_shouldfetchtoday"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 364).
- **Purpose:** Decide whether cached rates are stale enough to warrant a fresh network fetch —
  "stale" means last fetched on a different calendar day than today.
- **Inputs:** `lastFetch` — nullable.
- **Returns:** `bool` — `true` if `lastFetch` is `null`, or if today's year/month/day differs from
  `lastFetch`'s.
- **Side effects:** None (reads `DateTime.now()`).
- **Algorithm:** Null check returns `true`; otherwise compare `now.year`/`now.month`/`now.day`
  against `lastFetch`'s corresponding fields with `||`.
- **Usage:** Called by [`refreshIfNeeded`](#refreshifneeded) and [`_rateToDefault`](#_ratetodefault).
- **Notes:** This is a calendar-day check, not a 24-hour rolling window — fetching at 23:59 and
  again at 00:01 the next minute counts as stale (new calendar day), while fetching at 00:01 and
  again at 23:59 the same day does not, regardless of elapsed wall-clock time.

### `static Map<String, double> _fallbackRatesFor(String baseCurrency)` <a id="_fallbackratesfor"></a>
- **Kind:** private static method.
- **Source:** `lib/features/devices/services/exchange_rate_service.dart` (line 377).
- **Purpose:** Derive a full USD-based hardcoded rate table re-based to an arbitrary base currency,
  for use when no cached or fetched rates are available at all.
- **Inputs:** `baseCurrency`.
- **Returns:** `Map<String, double>` — one entry per currency in the fixed `_usdFallbackRates`
  table, each divided by that base currency's USD rate.
- **Side effects:** None.
- **Algorithm:** Look up `basePerUsd = _usdFallbackRates[base] ?? 1.0`; build a new map comprehension
  dividing every entry in `_usdFallbackRates` by `basePerUsd`, re-basing the whole USD-relative
  table to the requested base currency.
- **Usage:** Called by [`load`](#load) (when nothing is cached) and
  [`_rateToDefault`](#_ratetodefault) (last-resort fallback when even the cache lacks the needed
  currency).
- **Notes:** `_usdFallbackRates` is a fixed snapshot baked into the source (e.g. `'CNY': 7.25`) —
  it is never updated at runtime and will drift from real rates over time; it exists purely so
  conversions never hard-fail when the device has never successfully reached the network.
