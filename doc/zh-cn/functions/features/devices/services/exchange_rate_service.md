# lib/features/devices/services/exchange_rate_service.dart

`DeviceExchangeRateService` 获取并缓存货币汇率（来自 `open.er-api.com`）并把任意金额转换为应用默认货币，产生 `Device.purchasePrice`/`soldPrice`/`DeviceRecurringCost.price` 使用的 `MoneyValue` 记录（见 [`device.md`](../models/device.md)）。它把汇率持久化到 `exchange_rates.json`，并经 [`device_storage.md`](device_storage.md) 的通用 `readConfig`/`writeConfig` 配置存储读写其设置（`defaultCurrency`、`autoUpdateExchangeRates`）。`MoneyValue`/财务字段如何消费此文件产生的转换见 [设备](../../../../features/devices.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`ExchangeRateException`](#exchangerateexception-new) | 构造函数 | A | 创建携带机器可读错误码的异常。 |
| `toString` | 方法（`ExchangeRateException`） | B | 返回异常的消息。 |
| [`DeviceExchangeRateData`](#deviceexchangeratedata-new) | 构造函数 | A | 创建 `DeviceExchangeRateData` 实例。 |
| [`toJson`](#deviceexchangeratedata-tojson) | 方法（`DeviceExchangeRateData`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`DeviceExchangeRateData.fromJson`](#deviceexchangeratedata-fromjson) | 工厂构造函数 | A | 从 JSON 兼容映射解析 `DeviceExchangeRateData`。 |
| [`currencySymbol`](#currencysymbol) | 静态方法 | A | 把货币代码映射到其显示符号。 |
| [`getDefaultCurrency`](#getdefaultcurrency) | 静态方法 | A | 读取应用默认货币代码。 |
| [`setDefaultCurrency`](#setdefaultcurrency) | 静态方法 | A | 持久化应用默认货币代码。 |
| [`getAutoUpdateEnabled`](#getautoupdateenabled) | 静态方法 | A | 读取每日自动汇率刷新是否启用。 |
| [`setAutoUpdateEnabled`](#setautoupdateenabled) | 静态方法 | A | 持久化每日自动汇率刷新是否启用。 |
| [`refreshIfNeeded`](#refreshifneeded) | 静态方法 | A | 自动更新开启且汇率过期时从网络刷新。 |
| [`_getFile`](#_getfile) | 静态方法（私有） | A | 解析当前应用目录内 `exchange_rates.json` 文件。 |
| [`load`](#load) | 静态方法 | A | 加载基础货币的缓存汇率，或内置回退汇率。 |
| [`save`](#save) | 静态方法 | A | 把汇率数据持久化到 `exchange_rates.json`。 |
| [`fetchAndSaveLatest`](#fetchandsavelatest) | 静态方法 | A | 从网络获取最新汇率并持久化。 |
| [`fetchLatest`](#fetchlatest) | 静态方法 | A | 从 `open.er-api.com` 为基础货币获取最新汇率。 |
| [`convertOptional`](#convertoptional) | 静态方法 | A | 把可空金额转换为 `MoneyValue`，金额为 `null` 时为 `null`。 |
| [`convert`](#convert) | 静态方法 | A | 把金额转换为应用默认货币的 `MoneyValue`。 |
| [`_rateToDefault`](#_ratetodefault) | 静态方法（私有） | A | 解析转换要用的汇率（手动、缓存或获取）。 |
| [`_shouldFetchToday`](#_shouldfetchtoday) | 静态方法（私有） | A | 返回缓存汇率是否过期（上次在不同日历日获取）。 |
| [`_fallbackRatesFor`](#_fallbackratesfor) | 静态方法（私有） | A | 为任意基础货币派生硬编码回退汇率。 |

行数（21）与 `grep -c 'Purpose:' exchange_rate_service.dart`（21）精确匹配。

## 文档

### `const ExchangeRateException(this.message)` <a id="exchangerateexception-new"></a>
- **种类：** `ExchangeRateException` 的构造函数（实现 `Exception`）。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 18 行）。
- **用途：** 包装描述货币转换为何无法完成的机器可读错误码（非本地化消息）。
- **输入：** `message` — 固定码字符串 `'manual_rate_required'` 或 `'exchange_rate_unavailable'` 之一（见 [`_rateToDefault`](#_ratetodefault)）。
- **返回：** 新 `ExchangeRateException`。
- **副作用：** 无。
- **算法：** 平凡字段赋值。
- **用法：** 由 [`_rateToDefault`](#_ratetodefault) 抛出；在 `device_edit_page.dart` 的保存处理器捕获，把 `message` 映射为给用户 snackbar 显示的本地化字符串（`exchangeRateManualRequired` / `exchangeRateUnavailable`）。
- **备注：** `message` 是稳定码，非人类可读句子——调用方必须自己翻译而非直接显示。

### `Map<String, dynamic> DeviceExchangeRateData.toJson()` <a id="deviceexchangeratedata-tojson"></a>
- **种类：** `DeviceExchangeRateData` 的方法。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 50 行）。
- **用途：** 把此汇率快照序列化为持久化到 `exchange_rates.json` 的 JSON。
- **输入：** 无。
- **返回：** 带 `baseCurrency`、`rates` 和存在时 ISO-8601 `lastFetchedAt` 的 `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** 直接字段映射；`lastFetchedAt` 只在非 null 时包含。
- **用法：** 被 [`save`](#save) 调用。
- **备注：** 无。

### `factory DeviceExchangeRateData.fromJson(Map<String, dynamic> json)` <a id="deviceexchangeratedata-fromjson"></a>
- **种类：** `DeviceExchangeRateData` 的工厂构造函数。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 62 行）。
- **用途：** 从 `exchange_rates.json` 解析缓存汇率快照，容忍缺失键。
- **输入：** `json`。
- **返回：** 新 `DeviceExchangeRateData`；`baseCurrency` 默认 `'USD'`；`rates` 键解析时大写；`rates` 缺席默认 `{}`。
- **副作用：** 无。
- **算法：** 带 `'USD'` 默认读取 `baseCurrency`；把 `rates` 条目映射为大写键带 `num.toDouble()` 值；`lastFetchedAt` 只在存在时经 `DateTime.parse` 解析。
- **用法：** 被 [`load`](#load) 调用。
- **备注：** 货币代码在本文件读和写路径都总是规范化为大写，因此查找（`data.rates[from]`）从不需要不区分大小写比较。

### `static String currencySymbol(String code)` <a id="currencysymbol"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 103 行）。
- **用途：** 把货币代码映射到其惯用显示符号（`$`、`€`、`¥` 等）。
- **输入：** `code` — 任何字符串，匹配前不区分大小写大写。
- **返回：** `String` — 14 个 `supportedCurrencies` 之一的映射符号，或任何无法识别的大写 `code` 本身作为回退。
- **副作用：** 无。
- **算法：** 对 `code.toUpperCase()` 的 `switch` 表达式，每个受支持货币一个 case（注意 `CNY` 和 `JPY` 都映射 `¥`），未知代码落入代码本身（`_ => code.toUpperCase()`）。
- **用法：**
  ```dart
  final symbol = DeviceExchangeRateService.currencySymbol(money.currency);
  return '${DeviceExchangeRateService.currencySymbol(currency)}${amount.toStringAsFixed(2)}';
  ```
  （来自 `device_detail_page.dart` 的货币格式化辅助）
- **备注：** 无法识别代码优雅降级为显示代码本身（如 `"XYZ12.34"`）而非抛或显示空白符号。

### `static Future<String> getDefaultCurrency()` <a id="getdefaultcurrency"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 126 行）。
- **用途：** 读取应用配置的默认货币代码（所有 `MoneyValue` 被转换进的货币）。
- **输入：** 无。
- **返回：** `Future<String>` — 大写；未设时 `defaultDefaultCurrency`（`'USD'`）。
- **副作用：** 经 `DeviceStorage.readConfig()`（见 [`device_storage.md#readconfig`](device_storage.md)）读取 `storage_config.json`。
- **算法：** `(config['defaultCurrency'] as String? ?? 'USD').toUpperCase()`。
- **用法：**
  ```dart
  final currency = await DeviceExchangeRateService.getDefaultCurrency();
  ```
  （来自 `device_edit_page.dart`、`device_list_page.dart` 和 `settings_page.dart`）
- **备注：** 无。

### `static Future<void> setDefaultCurrency(String currency)` <a id="setdefaultcurrency"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 137 行）。
- **用途：** 持久化应用默认货币代码。
- **输入：** `currency`。
- **返回：** `Future<void>`。
- **副作用：** 经 `DeviceStorage` 读取然后重写 `storage_config.json`。
- **算法：** 读取配置、设 `config['defaultCurrency'] = currency.toUpperCase()`、写回。
- **用法：**
  ```dart
  await DeviceExchangeRateService.setDefaultCurrency(value);
  ```
  （来自 `settings_page.dart` 的默认货币选择器）
- **备注：** 更改默认货币不追溯重新转换任何已存储 `MoneyValue`——只影响未来转换。

### `static Future<bool> getAutoUpdateEnabled()` <a id="getautoupdateenabled"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 148 行）。
- **用途：** 读取每日自动汇率刷新是否启用。
- **输入：** 无。
- **返回：** `Future<bool>` — 未设时默认 `true`。
- **副作用：** 读取 `storage_config.json`。
- **算法：** `config['autoUpdateExchangeRates'] as bool? ?? true`。
- **用法：** 被 [`refreshIfNeeded`](#refreshifneeded) 和 [`_rateToDefault`](#_ratetodefault) 调用；也被 `settings_page.dart` 和 `device_edit_page.dart` 直接读取决定是否显示手动汇率输入字段。
- **备注：** 默认 `true` 意味着自动更新是退出而非加入。

### `static Future<void> setAutoUpdateEnabled(bool enabled)` <a id="setautoupdateenabled"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 158 行）。
- **用途：** 持久化每日自动汇率刷新是否启用。
- **输入：** `enabled`。
- **返回：** `Future<void>`。
- **副作用：** 读取然后重写 `storage_config.json`。
- **算法：** 读取配置、设标志、写回。
- **用法：**
  ```dart
  await DeviceExchangeRateService.setAutoUpdateEnabled(value);
  ```
  （来自 `settings_page.dart` 的自动更新切换）
- **备注：** 无。

### `static Future<void> refreshIfNeeded()` <a id="refreshifneeded"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 169 行）。
- **用途：** 用户启用自动更新时每天从网络刷新一次汇率。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 可能写 `exchange_rates.json`；汇率过期时经 [`fetchAndSaveLatest`](#fetchandsavelatest) 执行网络请求。
- **算法：** 完全包在吞掉所有错误的 `try`/`catch`。1. 自动更新禁用时立即返回。2. 加载当前默认货币及其缓存汇率数据。3. [`_shouldFetchToday`](#_shouldfetchtoday) 说缓存过期、或缓存数据 `baseCurrency` 不再匹配当前默认货币时，获取并保存新鲜汇率。
- **用法：**
  ```dart
  // Refresh exchange rates daily when the user enabled automatic updates.
  DeviceExchangeRateService.refreshIfNeeded();
  ```
  （来自 `lib/main.dart`，应用启动时与 `BackupService.runAutoBackupIfNeeded()` 一起即发即忘——不 await）
- **备注：** 启动时不带 `await` 调用，因此应用启动绝不被网络往返阻塞；任何失败（离线、API 错误）被静默吸收并简单在下次合格调用重试（应用重启，或任何经 [`_rateToDefault`](#_ratetodefault) 的转换）。

### `static Future<DeviceExchangeRateData> load(String baseCurrency)` <a id="load"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 195 行）。
- **用途：** 加载基础货币的缓存汇率数据，无有效缓存时回退内置硬编码汇率。
- **输入：** `baseCurrency`。
- **返回：** `Future<DeviceExchangeRateData>` — 总是非 null；绝不抛。
- **副作用：** 读取 `exchange_rates.json`。
- **算法：** 包在 `try`/`catch`（任何错误落入回退）。1. 文件存在且有内容时解析它。2. 只在缓存数据 `baseCurrency` 匹配请求的*且*实际有汇率时接受——否则落入。3. 回退：`DeviceExchangeRateData(baseCurrency: base, rates: _fallbackRatesFor(base))`。
- **用法：** 被 [`refreshIfNeeded`](#refreshifneeded) 和 [`_rateToDefault`](#_ratetodefault) 调用。
- **备注：** *错误*基础货币的缓存文件（如用户刚改默认货币）被当作缺席，不转换——调用方在下次成功获取前获得新基础的鲜活回退汇率。

### `static Future<void> save(DeviceExchangeRateData data)` <a id="save"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 220 行）。
- **用途：** 把汇率数据持久化到 `exchange_rates.json`。
- **输入：** `data`。
- **返回：** `Future<void>`。
- **副作用：** 写 `exchange_rates.json`（美化打印、非原子）。
- **算法：** JSON 编码 `data.toJson()`、写它。
- **用法：** 被 [`fetchAndSaveLatest`](#fetchandsavelatest) 调用。
- **备注：** 无。

### `static Future<DeviceExchangeRateData?> fetchAndSaveLatest(String baseCurrency)` <a id="fetchandsavelatest"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 232 行）。
- **用途：** 从网络为基础货币获取最新汇率，成功时持久化。
- **输入：** `baseCurrency`。
- **返回：** `Future<DeviceExchangeRateData?>` — 获取失败时 `null`。
- **副作用：** 经 [`fetchLatest`](#fetchlatest) 的网络请求；成功时经 [`save`](#save) 写 `exchange_rates.json`。
- **算法：** 获取；`null` 时不写地返回 `null`；否则保存并返回获取数据。
- **用法：**
  ```dart
  final result = await DeviceExchangeRateService.fetchAndSaveLatest(_defaultCurrency);
  ```
  （来自 `settings_page.dart` 的手动"立即刷新汇率"按钮，和 [`refreshIfNeeded`](#refreshifneeded)/[`_rateToDefault`](#_ratetodefault) 内部）
- **备注：** 无。

### `static Future<DeviceExchangeRateData?> fetchLatest(String baseCurrency)` <a id="fetchlatest"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 246 行）。
- **用途：** 从 `open.er-api.com` 为基础货币获取最新汇率。
- **输入：** `baseCurrency`。
- **返回：** `Future<DeviceExchangeRateData?>` — 任何 HTTP 错误、非 `success` API 结果或异常（超时、网络错误、格式错误 JSON）时 `null`。
- **副作用：** 发送到 `https://open.er-api.com/v6/latest/<base>` 的 HTTP GET，10s 超时。
- **算法：** GET 端点；除非状态 200 且解码体 `result` 字段为 `'success'` 否则返回 `null`；否则把 `rates` 映射为大写键带 `double` 值并盖章 `lastFetchedAt: DateTime.now()`。整个方法包在返回任何异常 `null` 的 `try`/`catch`。
- **用法：** 只被 [`fetchAndSaveLatest`](#fetchandsavelatest) 调用。
- **备注：** 用无 API 密钥的第三方免费 API（`open.er-api.com`）；所有失败模式降级为 `null` 而非抛，使调用方总有定义的"获取失败"路径。

### `static Future<MoneyValue?> convertOptional({required double? amount, required String currency, required String defaultCurrency, required bool autoRate, double? manualRate, Map<String, dynamic> extraJson = const {}})` <a id="convertoptional"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 274 行）。
- **用途：** 把可空金额转换为 `MoneyValue`，无可转换金额时短路 `null`。
- **输入：** `amount`（可空）；`currency`、`defaultCurrency`、`autoRate`；可选 `manualRate`、`extraJson`。
- **返回：** `Future<MoneyValue?>` — 当且仅当 `amount` 为 `null` 时 `null`。
- **副作用：** `amount` 非 null 时与 [`convert`](#convert) 相同。
- **算法：** 对 `amount` null 检查，然后完全委托 [`convert`](#convert)。
- **用法：**
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
  （来自 `device_edit_page.dart` 的保存处理器，可选 `purchasePrice`/`soldPrice` 字段）
- **备注：** 存在使带可选价格字段的调用方不需要自己围绕 `convert` 的 null 检查包装。

### `static Future<MoneyValue> convert({required double amount, required String currency, required String defaultCurrency, required bool autoRate, double? manualRate, Map<String, dynamic> extraJson = const {}})` <a id="convert"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 298 行）。
- **用途：** 把任意货币金额转换为携带原始金额和其在应用默认货币转换值的 `MoneyValue`。
- **输入：** `amount`、`currency`、`defaultCurrency`、`autoRate`；可选 `manualRate`（`autoRate` 为 false 时必填）、`extraJson`。
- **返回：** 带 `convertedAmount = amount * rate` 和 `rateUpdatedAt: DateTime.now()` 的 `Future<MoneyValue>`。
- **副作用：** 与 [`_rateToDefault`](#_ratetodefault) 相同（可能读缓存、可能从网络获取）。
- **算法：** 大写两个货币代码、经 [`_rateToDefault`](#_ratetodefault) 解析汇率、然后构造 `MoneyValue`。
- **用法：**
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
  （来自 `device_edit_page.dart` 的保存处理器，构建每个 `DeviceRecurringCost.price`）
- **备注：** 可抛 [`ExchangeRateException`](#exchangerateexception-new)（从 `_rateToDefault` 传播）——调用方必须捕获它，如 `device_edit_page.dart` 那样。

### `static Future<double> _rateToDefault({required String from, required String base, required bool autoRate, double? manualRate})` <a id="_ratetodefault"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 331 行）。
- **用途：** 解析要乘金额的数值汇率，在恒等、手动汇率或缓存/新获取自动汇率间选择。
- **输入：** `from`、`base`、`autoRate`；可选 `manualRate`。
- **返回：** `Future<double>`。
- **副作用：** 自动更新启用且缓存过期时可能读取 `exchange_rates.json`（经 [`load`](#load)）并执行网络获取（经 [`fetchAndSaveLatest`](#fetchandsavelatest)）。
- **算法：** 1. `from == base` 时立即返回 `1.0`。2. `autoRate` 为 false 时：要求正 `manualRate`，否则抛 `ExchangeRateException('manual_rate_required')`；直接返回它。3. 否则（`autoRate` true）：为 `base` 加载缓存汇率数据；自动更新启用且缓存过期（[`_shouldFetchToday`](#_shouldfetchtoday)）时尝试新鲜获取，获取本身失败回退过期缓存数据。4. 试 `data.rates[from]`（base→from 汇率）并反转它（`1 / baseToFrom`）得 from→base。5. 该键缺失或非正时回退 `_fallbackRatesFor(base)[from]`，同样反转。6. 两源都无可用的率时抛 `ExchangeRateException('exchange_rate_unavailable')`。
- **用法：** 被 [`convert`](#convert) 调用。
- **备注：** API 的 `rates` 映射以 `base → other` 键控，因此转换 `from → base` 总是需要反转（`1 / rate`）——此方法每个汇率查找都做那个反转，活缓存和硬编码回退表都是。

### `static bool _shouldFetchToday(DateTime? lastFetch)` <a id="_shouldfetchtoday"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 364 行）。
- **用途：** 决定缓存汇率是否过期到值得新鲜网络获取——"过期"意为上次在不同日历日获取。
- **输入：** `lastFetch` — 可空。
- **返回：** `bool` — `lastFetch` 为 `null`、或今天的年/月/日不同于 `lastFetch` 的时 `true`。
- **副作用：** 无（读取 `DateTime.now()`）。
- **算法：** Null 检查返回 `true`；否则用 `||` 比较 `now.year`/`now.month`/`now.day` 与 `lastFetch` 对应字段。
- **用法：** 被 [`refreshIfNeeded`](#refreshifneeded) 和 [`_rateToDefault`](#_ratetodefault) 调用。
- **备注：** 这是日历日检查，非 24 小时滚动窗口——23:59 获取、下一分钟 00:01 再获取算过期（新日历日），而 00:01 获取、同日 23:59 再获取不算，无论流逝挂钟时间。

### `static Map<String, double> _fallbackRatesFor(String baseCurrency)` <a id="_fallbackratesfor"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/exchange_rate_service.dart`（第 377 行）。
- **用途：** 派生重新以任意基础货币为基的完整基于 USD 的硬编码汇率表，供完全无缓存或获取汇率时使用。
- **输入：** `baseCurrency`。
- **返回：** `Map<String, double>` — 固定 `_usdFallbackRates` 表中每个货币一个条目，各除以该基础货币的 USD 汇率。
- **副作用：** 无。
- **算法：** 查找 `basePerUsd = _usdFallbackRates[base] ?? 1.0`；构建把 `_usdFallbackRates` 每个条目除以 `basePerUsd` 的新映射推导，把整个 USD 相对表重新以请求基础货币为基。
- **用法：** 被 [`load`](#load)（无缓存时）和 [`_rateToDefault`](#_ratetodefault)（即使缓存也缺所需货币时的最后手段回退）调用。
- **备注：** `_usdFallbackRates` 是烘焙进源码的固定快照（如 `'CNY': 7.25`）——它绝不在运行时更新并会随时间漂移出真实汇率；它存在纯粹使设备从未成功到达网络时转换绝不硬失败。
