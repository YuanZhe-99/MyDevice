# lib/features/devices/views/device_detail_page.dart

单个 `Device` 的只读、单 `StatelessWidget` 详情视图（模型来源 `lib/features/devices/models/device.dart`，见 [设备](../../../../features/devices.md)）。它渲染英雄页头、生命周期/财务摘要、CPU/GPU/内存/存储/显示/其他规格卡片、可选静态位置地图（`flutter_map`）和备注——尽可能对设备文本字段与捆绑 `assets/logos/*.svg` 集合模糊匹配时拉入品牌/型号/存储/操作系统 logo。编辑完全委托给从应用栏编辑操作打开的 `device_edit_page.dart`。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `DeviceDetailPage`（构造函数） | 构造函数 | B | 为页面组件存储 `device` 和 `onDeviceChanged` 回调。 |
| [`_detectBrandLogo`](#_detectbrandlogo) | 方法（`DeviceDetailPage`） | A | 把 `device.brand` 与品牌 logo 表模糊匹配。 |
| [`_detectModelLogo`](#_detectmodellogo) | 方法（`DeviceDetailPage`） | A | 把 CPU/GPU 型号字符串与品牌 logo 表模糊匹配，带 ARM Mali/Immortalis 特判。 |
| [`_detectStorageBrandLogo`](#_detectstoragebrandlogo) | 方法（`DeviceDetailPage`） | A | 把存储设备品牌与存储 logo 表模糊匹配。 |
| [`_detectOsLogo`](#_detectoslogo) | 方法（`DeviceDetailPage`） | A | 把 `device.os` 与操作系统 logo 表模糊匹配。 |
| `_statusLabel` | 方法（`DeviceDetailPage`） | B | 把 `device.lifecycleStatus` 映射到其本地化标签。 |
| `_acquisitionTypeLabel` | 方法（`DeviceDetailPage`） | B | 把 `DeviceAcquisitionType` 映射到其本地化标签。 |
| `_recurringCostKindLabel` | 方法（`DeviceDetailPage`） | B | 把 `RecurringCostKind` 映射到其本地化标签。 |
| `_billingCycleLabel` | 方法（`DeviceDetailPage`） | B | 把 `BillingCycle` 映射到其本地化标签。 |
| [`_moneyText`](#_moneytext) | 方法（`DeviceDetailPage`） | A | 格式化 `MoneyValue`，转换金额不同于设备默认货币时追加。 |
| [`_defaultMoneyText`](#_defaultmoneytext) | 方法（`DeviceDetailPage`） | A | 用设备推断默认货币符号格式化原始金额。 |
| `build` | 方法（组件） | B | 构建脚手架并为设备组装所有规格小节。 |
| `_buildHeader` | 方法（组件辅助） | B | 渲染英雄卡片（头像、名、品牌/型号、logo、购买/发布日期）。 |
| `_sectionTitle` | 方法（组件辅助） | B | 渲染带图标和可选品牌 logo 的小节标题行。 |
| `_specCard` | 方法（组件辅助） | B | 把规格行列表包进 `Card`，所有行为空时渲染无。 |
| `_specRow` | 方法（组件辅助） | B | 渲染一个标签/值行，值为空时 `null`。 |
| `_specRowWithLogo` | 方法（组件辅助） | B | 渲染带值前可选小 logo 的标签/值行。 |

## 文档

### `String? _detectBrandLogo()` <a id="_detectbrandlogo"></a>
- **种类：** `DeviceDetailPage` 的方法
- **来源：** `lib/features/devices/views/device_detail_page.dart`（第 114 行）
- **用途：** 找到匹配设备品牌的 SVG logo 资产路径（如有）。
- **输入：** 无（读取 `device.brand`）。
- **返回：** `String?` — `assets/logos/*.svg` 路径，`device.brand` 未设或不匹配 `_brandLogoMap` 任何条目时 `null`。
- **副作用：** 无。
- **算法：**
  1. `device.brand` 为 null 时立即返回 `null`。
  2. 小写品牌字符串。
  3. 按声明顺序迭代 `_brandLogoMap`（约 39 个条目的小写品牌名子串 → SVG 路径的 `const Map<String, String>`，覆盖设备 OEM、芯片厂商和云/托管提供商）并返回小写品牌*包含*为子串的第一个键的值。
  4. 无条目匹配返回 `null`。
- **用法：** `_buildHeader` 中的 `final logoPath = _detectBrandLogo();`（`lib/features/devices/views/device_detail_page.dart`，第 522 行）。
- **备注：** 匹配基于子串且按映射声明顺序先匹配胜出，因此含两个厂商名的品牌字符串（实践中不太可能）解析为 `_brandLogoMap` 中先声明的条目。

### `String? _detectModelLogo(String? model)` <a id="_detectmodellogo"></a>
- **种类：** `DeviceDetailPage` 的静态方法
- **来源：** `lib/features/devices/views/device_detail_page.dart`（第 128 行）
- **用途：** 找到匹配 CPU/GPU 型号字符串（如 `device.cpu.model`、`device.gpu.model`）的 SVG logo 资产路径，复用品牌 logo 表加 ARM GPU 特例。
- **输入：** `model` — 自由文本 CPU/GPU 型号字符串，或 `null`。
- **返回：** `String?` — `assets/logos/*.svg` 路径，或 `null`。
- **副作用：** 无。
- **算法：**
  1. `model` 为 null 返回 `null`。
  2. 小写型号字符串。
  3. 迭代 `_brandLogoMap` 并返回小写型号*以*其*开始*的第一个键的值（注意：`startsWith`，不同于 `_detectBrandLogo` 的 `contains`——型号字符串通常以厂商名开头，如 `"Apple M2"`、`"Qualcomm Snapdragon..."`）。
  4. 无匹配时检查两个 ARM Mali GPU 特例：以 `'mali'` 或 `'immortalis'` 开头的型号解析为 `_brandLogoMap['arm']`（Mali/Immortalis GPU 型号名不含 "ARM"，因此仅通用品牌表抓不到它们）。
  5. 仍不匹配返回 `null`。
- **用法：**
  ```dart
  _sectionTitle(
    theme,
    cs,
    l10n.cpuInfo,
    Icons.memory,
    logoPath: _detectModelLogo(device.cpu.model),
  ),
  ```
  （来自 `build`，`lib/features/devices/views/device_detail_page.dart`，第 350–356 行；也用于第 376 行 GPU 小节）
- **备注：** 与 `_detectBrandLogo` 共享 `_brandLogoMap` 但用 `startsWith` 而非 `contains`，并叠两个 ARM GPU 回退——两函数尽管对照相同表匹配也不可互换。

### `String? _detectStorageBrandLogo(String? brand)` <a id="_detectstoragebrandlogo"></a>
- **种类：** `DeviceDetailPage` 的静态方法
- **来源：** `lib/features/devices/views/device_detail_page.dart`（第 146 行）
- **用途：** 找到匹配存储设备品牌（如 SSD/HDD 厂商）的 SVG logo 资产路径，用单独、存储特定品牌表。
- **输入：** `brand` — 存储条目品牌字符串，或 `null`。
- **返回：** `String?` — `assets/logos/*.svg` 路径，或 `null`。
- **副作用：** 无。
- **算法：** 与 `_detectBrandLogo` 相同的子串 `contains` 循环，但迭代 `_storageBrandLogoMap`——单独的约 14 条目表，含 `_brandLogoMap` 没有的存储专用厂商（Western Digital/WD、Seagate、Kingston、Crucial/Micron、SanDisk、SK hynix、Toshiba、Kioxia），加重叠品牌（Samsung、Intel、Apple）。
- **用法：**
  ```dart
  if (device.storage[i].brand != null)
    _specRowWithLogo(
      l10n.storageBrand,
      device.storage[i].brand!,
      _detectStorageBrandLogo(device.storage[i].brand),
      cs,
    ),
  ```
  （来自 `build`，`lib/features/devices/views/device_detail_page.dart`，第 402–408 行）
- **备注：** `_storageBrandLogoMap` 刻意跨同义品牌拼写重复几个键（`'western digital'` 和 `'wd'` 都映射相同 SVG；`'sk hynix'`、`'skhynix'` 和 `'hynix'` 都映射相同 SVG）以容忍字段中最终出现的任何拼写。

### `String? _detectOsLogo(String? os)` <a id="_detectoslogo"></a>
- **种类：** `DeviceDetailPage` 的静态方法
- **来源：** `lib/features/devices/views/device_detail_page.dart`（第 162 行）
- **用途：** 找到匹配自由文本操作系统字符串的 SVG logo 资产路径。
- **输入：** `os` — `device.os`，或 `null`。
- **返回：** `String?` — `assets/logos/*.svg` 路径，或 `null`。
- **副作用：** 无。
- **算法：** 相同子串 `contains` 循环模式，迭代 `_osLogoMap`（约 17 条目：Windows、Android、iOS/iPadOS 都 → iOS logo、macOS（两种拼写）、Linux 和命名发行版、ChromeOS（两种拼写）、HarmonyOS（两种拼写）、OpenWrt、FreeBSD）。因为匹配是 `contains` 而非精确，`"Windows 11 LTSC"` 或 `"Ubuntu Server"` 之类自由文本值仍正确解析（按源码文档注释自己的例子）。
- **用法：**
  ```dart
  _sectionTitle(
    theme,
    cs,
    l10n.os,
    Icons.info_outline,
    logoPath: _detectOsLogo(device.os),
  ),
  ```
  （来自 `build`，`lib/features/devices/views/device_detail_page.dart`，第 442–448 行）
- **备注：** `'ipados'` 和 `'ios'` 都映射相同 iOS SVG；`'chromeos'` 和 `'chrome os'` 都映射相同 ChromeOS SVG；`'harmonyos'` 和 `'harmony'` 都映射相同 HarmonyOS SVG——这些是刻意拼写变体重复，非不同 logo。

### `String _moneyText(MoneyValue money)` <a id="_moneytext"></a>
- **种类：** `DeviceDetailPage` 的方法
- **来源：** `lib/features/devices/views/device_detail_page.dart`（第 235 行）
- **用途：** 格式化 `MoneyValue` 供显示，两货币不同时在原始旁显示转换默认货币金额。
- **输入：** `money` — `MoneyValue`（金额 + 货币 + `money.defaultCurrency` 中计算的 `convertedAmount`）。
- **返回：** `String` — `"{symbol}{amount}"`（货币匹配默认）或 `"{symbol}{amount} ({baseSymbol}{convertedAmount} {defaultCurrency})"`（货币不同）。
- **副作用：** 无（只为查找调用 `DeviceExchangeRateService.currencySymbol`）。
- **算法：**
  1. 经 `DeviceExchangeRateService.currencySymbol` 查找 `money.currency` 和 `money.defaultCurrency` 的显示符号。
  2. 把原始金额格式化为带符号 2 位小数。
  3. `money.currency == money.defaultCurrency` 时只返回原始字符串。
  4. 否则在括号中追加带基础符号和默认货币代码的转换金额（也 2 位小数），如 `"$50.00 (¥360.00 JPY)"`。
- **用法：**
  ```dart
  _specRow(
    l10n.purchasePrice,
    device.purchasePrice != null ? _moneyText(device.purchasePrice!) : null,
  ),
  ```
  （来自 `build`，`lib/features/devices/views/device_detail_page.dart`，第 319–324 行；也用于 `soldPrice` 和每个循环成本 `price`）
- **备注：** 无。

### `String _defaultMoneyText(double amount)` <a id="_defaultmoneytext"></a>
- **种类：** `DeviceDetailPage` 的方法
- **来源：** `lib/features/devices/views/device_detail_page.dart`（第 250 行）
- **用途：** 用正确货币符号格式化普通金额（已以设备默认货币表达，如计算的总/每日成本）。
- **输入：** `amount` — 已转换为设备默认货币的 `double`。
- **返回：** `String` — `"{symbol}{amount.toStringAsFixed(2)}"`。
- **副作用：** 无。
- **算法：**
  1. 依序回退确定默认货币代码：`device.purchasePrice?.defaultCurrency`，然后 `device.soldPrice?.defaultCurrency`，然后 `device.recurringCosts.firstOrNull?.price.defaultCurrency`，三个财务字段都不存在时 `''`。
  2. 查找该货币代码符号并把 `amount` 格式化为 2 位小数。
- **用法：**
  ```dart
  if (device.hasFinancialData)
    _specRow(l10n.financialTotalCost, _defaultMoneyText(device.totalCost())),
  if (device.averageDailyCost() != null)
    _specRow(l10n.financialDailyCost, _defaultMoneyText(device.averageDailyCost()!)),
  ```
  （来自 `build`，`lib/features/devices/views/device_detail_page.dart`，第 334–343 行）
- **备注：** `device.totalCost()`/`device.averageDailyCost()`（见 [设备 — 生命周期与财务跟踪](../../../../features/devices.md#lifecycle-and-finance-tracking)）已返回默认货币金额，因此此函数只需解析那是哪种货币——它自己不执行转换。
