# lib/features/devices/models/device.dart

核心设备模型：`Device` 本身加构成它的每个值类型（`CpuInfo`、`GpuInfo`、`StorageInfo`、`MoneyValue`、`DeviceRecurringCost`）及其支撑枚举（`DeviceCategory`、`DeviceAcquisitionType`、`DeviceLifecycleStatus`、`RecurringCostKind`、`BillingCycle`、`StorageType`、`RamType`、`StorageInterface`），加由 [`../services/device_storage.md`](../services/device_storage.md) 持久化的顶层 `DeviceData` 容器。这里每个模型都遵循应用标准形态：`const`/普通构造函数、`toJson`/`fromJson` 和参与三方同步合并的 `mergeUnknownFieldsFrom`（泛型 `unknownJsonFields`/`mergeUnknownJsonFields` 辅助见 [三方合并](../../../../algorithms/three-way-merge.md) 和 [`json_preservation.md`](../../../shared/utils/json_preservation.md)，这里每个 `fromJson`/`mergeUnknownFieldsFrom` 都调用它们）。本页对照真实源码文档化的生命周期/财务行为见 [设备](../../../../features/devices.md)，穷举持久化字段参考见 [数据格式 — 设备](../../../../data-formats.md#device-libfeaturesdevicesmodelsdevicedart)。

本文件很大（14 个枚举/类中 58 个声明）；其行数与文件 `/// Purpose:` 文档注释计数如何比较见声明表末尾的说明。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `jsonValue` | getter（`DeviceCategory`） | B | 返回序列化枚举名。 |
| [`DeviceCategory.fromJson`](#devicecategory-fromjson) | 静态方法 | A | 解析 `DeviceCategory`，无匹配默认 `other`。 |
| `jsonValue` | getter（`DeviceAcquisitionType`） | B | 返回序列化枚举名。 |
| [`DeviceAcquisitionType.fromJson`](#deviceacquisitiontype-fromjson) | 静态方法 | A | 解析 `DeviceAcquisitionType`，或 `null`。 |
| `jsonValue` | getter（`RecurringCostKind`） | B | 返回序列化枚举名。 |
| [`RecurringCostKind.fromJson`](#recurringcostkind-fromjson) | 静态方法 | A | 解析 `RecurringCostKind`，默认 `other`。 |
| `jsonValue` | getter（`BillingCycle`） | B | 返回序列化枚举名。 |
| [`BillingCycle.fromJson`](#billingcycle-fromjson) | 静态方法 | A | 解析 `BillingCycle`，默认 `monthly`。 |
| [`CpuInfo`](#cpuinfo-new) | 构造函数 | A | 创建 `CpuInfo` 实例。 |
| `isEmpty` | getter（`CpuInfo`） | B | 返回每个字段是否都未设。 |
| [`toJson`](#cpuinfo-tojson) | 方法（`CpuInfo`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`CpuInfo.fromJson`](#cpuinfo-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `CpuInfo`，容忍遗留 `cores` 键。 |
| [`mergeUnknownFieldsFrom`](#cpuinfo-mergeunknownfieldsfrom) | 方法（`CpuInfo`） | A | 从另一个 `CpuInfo` 三方合并未知 JSON 字段。 |
| [`GpuInfo`](#gpuinfo-new) | 构造函数 | A | 创建 `GpuInfo` 实例。 |
| `isEmpty` | getter（`GpuInfo`） | B | 返回每个字段是否都未设。 |
| [`toJson`](#gpuinfo-tojson) | 方法（`GpuInfo`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`GpuInfo.fromJson`](#gpuinfo-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `GpuInfo`。 |
| [`mergeUnknownFieldsFrom`](#gpuinfo-mergeunknownfieldsfrom) | 方法（`GpuInfo`） | A | 从另一个 `GpuInfo` 三方合并未知 JSON 字段。 |
| `jsonValue` | getter（`StorageType`） | B | 返回序列化枚举名。 |
| [`StorageType.fromJson`](#storagetype-fromjson) | 静态方法 | A | 解析 `StorageType`，或 `null`。 |
| `jsonValue` | getter（`RamType`） | B | 返回序列化枚举名。 |
| [`displayName`](#ramtype-displayname) | getter（`RamType`） | A | 返回人类可读 RAM 标准名（如 `"LPDDR5X"`）。 |
| [`RamType.fromJson`](#ramtype-fromjson) | 静态方法 | A | 解析 `RamType`，或 `null`。 |
| `jsonValue` | getter（`StorageInterface`） | B | 返回序列化枚举名。 |
| [`StorageInterface.fromJson`](#storageinterface-fromjson) | 静态方法 | A | 解析 `StorageInterface`，或 `null`。 |
| [`StorageInfo`](#storageinfo-new) | 构造函数 | A | 创建 `StorageInfo` 实例。 |
| `isEmpty` | getter（`StorageInfo`） | B | 返回每个字段是否都未设。 |
| [`displayString`](#storageinfo-displaystring) | getter（`StorageInfo`） | A | 构建人类可读摘要（如 `"512 GB SSD (M.2 NVMe)"`）。 |
| [`toJson`](#storageinfo-tojson) | 方法（`StorageInfo`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`StorageInfo.fromJson`](#storageinfo-fromjson) | 工厂构造函数 | A | 从 JSON 或遗留普通字符串解析 `StorageInfo`。 |
| [`mergeUnknownFieldsFrom`](#storageinfo-mergeunknownfieldsfrom) | 方法（`StorageInfo`） | A | 从另一个 `StorageInfo` 三方合并未知 JSON 字段。 |
| [`MoneyValue`](#moneyvalue-new) | 构造函数 | A | 创建 `MoneyValue` 实例。 |
| [`toJson`](#moneyvalue-tojson) | 方法（`MoneyValue`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`MoneyValue.fromJson`](#moneyvalue-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `MoneyValue`，容忍遗留键。 |
| [`mergeUnknownFieldsFrom`](#moneyvalue-mergeunknownfieldsfrom) | 方法（`MoneyValue`） | A | 从另一个 `MoneyValue` 三方合并未知 JSON 字段。 |
| [`DeviceRecurringCost`](#devicerecurringcost-new) | 构造函数 | A | 创建 `DeviceRecurringCost` 实例。 |
| [`annualConvertedAmount`](#devicerecurringcost-annualconvertedamount) | getter（`DeviceRecurringCost`） | A | 基于 `billingCycle` 把此成本投影为年度转换金额。 |
| `dailyConvertedAmount` | getter（`DeviceRecurringCost`） | B | 把 `annualConvertedAmount` 除以 365。 |
| [`toJson`](#devicerecurringcost-tojson) | 方法（`DeviceRecurringCost`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`DeviceRecurringCost.fromJson`](#devicerecurringcost-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `DeviceRecurringCost`。 |
| [`mergeUnknownFieldsFrom`](#devicerecurringcost-mergeunknownfieldsfrom) | 方法（`DeviceRecurringCost`） | A | 三方合并未知 JSON 字段，含嵌套 `price`。 |
| [`Device`](#device-new) | 构造函数 | A | 创建 `Device` 实例（默认新鲜 `id`/`modifiedAt`）。 |
| [`lifecycleStatus`](#lifecyclestatus) | getter（`Device`） | A | 派生 `sold`/`retired`/`inService`，售出优先。 |
| `isInService` | getter（`Device`） | B | 返回 `lifecycleStatus == inService`。 |
| [`hasFinancialData`](#hasfinancialdata) | getter（`Device`） | A | 返回是否有任何购买/出售价格或循环成本存在。 |
| [`serviceDays`](#servicedays) | 方法（`Device`） | A | 计算从 `purchaseDate` 到现在或 `retiredDate` 的在用天数。 |
| [`recurringCostThrough`](#recurringcostthrough) | 方法（`Device`） | A | 对每个循环成本的每日费率跨 `serviceDays` 求和。 |
| [`totalCost`](#totalcost) | 方法（`Device`） | A | 计算购买价格加循环成本减出售价格。 |
| [`averageDailyCost`](#averagedailycost) | 方法（`Device`） | A | 把 `totalCost` 除以 `serviceDays`，无财务数据为 `null`。 |
| [`ppi`](#ppi) | getter（`Device`） | A | 从分辨率和屏幕对角线计算每英寸像素。 |
| [`_parseScreenDiagonal`](#_parsescreendiagonal) | 静态方法（私有） | A | 把屏幕尺寸字符串（如 `"6.7\""`）解析为英寸。 |
| [`copyWith`](#copywith) | 方法（`Device`） | A | 创建任何子集字段被替换或清除的副本。 |
| [`toJson`](#device-tojson) | 方法（`Device`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`Device.fromJson`](#device-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `Device`，容忍遗留字符串 `storage` 形态。 |
| [`mergeUnknownFieldsFrom`](#device-mergeunknownfieldsfrom) | 方法（`Device`） | A | 合并未知字段加嵌套 cpu/gpu/storage/price/循环成本结构。 |
| [`DeviceData`](#devicedata-new) | 构造函数 | A | 创建 `DeviceData` 实例。 |
| [`toJson`](#devicedata-tojson) | 方法（`DeviceData`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`DeviceData.fromJson`](#devicedata-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `DeviceData`。 |

行数（58）不匹配 `grep -c 'Purpose:' device.dart`（31）。到 `StorageInterface.fromJson` 为止的每个声明（25 行）带自动生成 `/// Purpose:` 文档注释块，`DeviceData` 的三个声明（最后 3 行）也带——31 个注释中的 28 个，加 `StorageInfo` 的构造函数/`isEmpty`/`displayString`（3 个）占全部 31。从 `StorageInfo.toJson` 开始贯穿整个 `MoneyValue`、`DeviceRecurringCost` 和 `Device` 类（27 个声明：`StorageInfo.toJson`/`fromJson`/`mergeUnknownFieldsFrom`、全部四个 `MoneyValue` 声明、全部六个 `DeviceRecurringCost` 声明和全部十四个 `Device` 声明）完全没有 `/// Purpose:` 块——大多数情况连普通文档注释都没有。这是直接读文件确认的，不是从注释密度假设；按每个声明无论是否带自动生成注释都出现的分层规则，那 27 个声明每个仍在这里索引。`DeviceLifecycleStatus`（无自己 getter/方法的裸三值枚举）无行，与本文档集只索引可执行声明而非裸类型声明一致。

## 文档

### `static DeviceCategory fromJson(String value)` <a id="devicecategory-fromjson"></a>
- **种类：** 枚举 `DeviceCategory` 的静态方法。
- **来源：** `lib/features/devices/models/device.dart`（第 103 行）。
- **用途：** 从其序列化名解析 `DeviceCategory`，任何无法识别值默认 `other`。
- **输入：** `value`。
- **返回：** `DeviceCategory` — 绝不 `null`。
- **副作用：** 无。
- **算法：** `DeviceCategory.values.firstWhere((e) => e.name == value, orElse: () => DeviceCategory.other)`。
- **用法：**
  ```dart
  category: DeviceCategory.fromJson(json['category'] as String),
  ```
  （来自 [`Device.fromJson`](#device-fromjson) 和 `DeviceTemplate.fromJson`，见 [`preset_service.md`](../services/preset_service.md)）
- **备注：** 与本文件大多数其他 `fromJson` 枚举解析器不同，此绝返回 `null`——无法识别类别降级为 `other`，而非要求每个调用方处理缺失类别。

### `static DeviceAcquisitionType? fromJson(String? value)` <a id="deviceacquisitiontype-fromjson"></a>
- **种类：** 枚举 `DeviceAcquisitionType` 的静态方法。
- **来源：** `lib/features/devices/models/device.dart`（第 126 行）。
- **用途：** 从其序列化名解析 `DeviceAcquisitionType`。
- **输入：** `value` — 可空。
- **返回：** `DeviceAcquisitionType?` — `value` 为 `null` 或无法识别时 `null`。
- **副作用：** 无。
- **算法：** Null 检查，然后 `DeviceAcquisitionType.values.where((e) => e.name == value).firstOrNull`。
- **用法：** 被 [`Device.fromJson`](#device-fromjson) 为 `acquisitionType` 调用。
- **备注：** 与 `DeviceCategory.fromJson` 不同，这里无法识别值产生 `null`（无记录获取类型），非回退枚举值。

### `static RecurringCostKind fromJson(String? value)` <a id="recurringcostkind-fromjson"></a>
- **种类：** 枚举 `RecurringCostKind` 的静态方法。
- **来源：** `lib/features/devices/models/device.dart`（第 156 行）。
- **用途：** 解析 `RecurringCostKind`，无法识别或缺席默认 `other`。
- **输入：** `value` — 可空。
- **返回：** `RecurringCostKind` — 绝不 `null`。
- **副作用：** 无。
- **算法：** `RecurringCostKind.values.where((e) => e.name == value).firstOrNull ?? RecurringCostKind.other`。
- **用法：** 被 [`DeviceRecurringCost.fromJson`](#devicerecurringcost-fromjson) 调用。
- **备注：** 无。

### `static BillingCycle fromJson(String? value)` <a id="billingcycle-fromjson"></a>
- **种类：** 枚举 `BillingCycle` 的静态方法。
- **来源：** `lib/features/devices/models/device.dart`（第 178 行）。
- **用途：** 解析 `BillingCycle`，无法识别或缺席默认 `monthly`。
- **输入：** `value` — 可空。
- **返回：** `BillingCycle` — 绝不 `null`。
- **副作用：** 无。
- **算法：** `BillingCycle.values.where((e) => e.name == value).firstOrNull ?? BillingCycle.monthly`。
- **用法：** 被 [`DeviceRecurringCost.fromJson`](#devicerecurringcost-fromjson) 调用。
- **备注：** `monthly` 是"缺席"和"无法识别"两者的回退——带格式错误/缺失 `billingCycle` 的循环成本被当作月度，匹配构造函数自己的默认。

### `const CpuInfo({this.model, this.architecture, this.frequency, this.performanceCores, this.efficiencyCores, this.threads, this.cache, this.extraJson = const {}})` <a id="cpuinfo-new"></a>
- **种类：** `CpuInfo` 的构造函数。
- **来源：** `lib/features/devices/models/device.dart`（第 199 行）。
- **用途：** 持有设备 CPU 规格——型号、架构、频率、核心/线程数、缓存——加任何无法识别 JSON 字段。
- **输入：** 所有字段可选；`extraJson` 默认 `{}`。
- **返回：** 新 `CpuInfo`。
- **副作用：** 无。
- **算法：** 带默认的平凡字段赋值。
- **用法：** 由 `device_edit_page.dart` 的保存处理器（见 CPU 字段块）、[`preset_service.md`](../services/preset_service.md) 的 `toDevice` 和经 [`CpuInfo.fromJson`](#cpuinfo-fromjson)/`ChipSearchResult.toCpuInfo`（见 [`chip_search_service.md`](../services/chip_search_service.md)）直接构造。
- **备注：** `const Device(cpu: const CpuInfo())`（全 null、空 `extraJson` 实例）是设备无记录 CPU 时的默认——见下面 [`isEmpty`](#cpuinfo-new)。

### `Map<String, dynamic> toJson()` <a id="cpuinfo-tojson"></a>
- **种类：** `CpuInfo` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 230 行）。
- **用途：** 把此 CPU 规格序列化为持久化在设备 `cpu` 字段内的 JSON。
- **输入：** 无。
- **返回：** `Map<String, dynamic>` — 先展开 `extraJson`，然后只非 null 已知字段。
- **副作用：** 无。
- **算法：** 对七个已知字段各 `{...extraJson, if (field != null) 'field': field, ...}`。
- **用法：** 被 [`Device.toJson`](#device-tojson)（只在 `!cpu.isEmpty` 时）和 [`mergeUnknownFieldsFrom`](#cpuinfo-mergeunknownfieldsfrom) 调用。
- **备注：** 在已知字段*前*展开 `extraJson` 意味着无法识别键碰巧与已知键名碰撞时已知字段总是胜出。

### `factory CpuInfo.fromJson(Map<String, dynamic> json)` <a id="cpuinfo-fromjson"></a>
- **种类：** `CpuInfo` 的工厂构造函数。
- **来源：** `lib/features/devices/models/device.dart`（第 246 行）。
- **用途：** 从 JSON 解析 `CpuInfo`，容忍替代 `performanceCores` 的较旧 `cores` 键。
- **输入：** `json`。
- **返回：** 新 `CpuInfo`；`extraJson` 持有不在 `_cpuInfoJsonKeys` 的每个键。
- **副作用：** 无。
- **算法：** 对每个已知键直接字段提取；`performanceCores` 读取 `json['performanceCores'] as int? ?? json['cores'] as int?`——遗留回退。
- **用法：** 被 [`Device.fromJson`](#device-fromjson)（`json['cpu']` 存在时）和 `PresetService.loadCpus`（见 [`preset_service.md`](../services/preset_service.md)）调用。
- **备注：** `cores`→`performanceCores` 回退是此类唯一遗留格式容忍——它存在为读取 `performanceCores`/`efficiencyCores` 拆分为单独字段前写的数据。

### `CpuInfo mergeUnknownFieldsFrom(CpuInfo other, {CpuInfo? base})` <a id="cpuinfo-mergeunknownfieldsfrom"></a>
- **种类：** `CpuInfo` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 262 行）。
- **用途：** 三方合并此 `CpuInfo` 的未知 JSON 字段与另一个的，使无法识别键像已知字段一样经受同步合并。
- **输入：** `other` — 另一侧（`this` 为本地时典型为远程）；可选 `base` — 上次同步快照。
- **返回：** 新 `CpuInfo`——与 `this` 相同已知字段、`extraJson` 被合并结果替换。
- **副作用：** 无。
- **算法：** 经 `CpuInfo.fromJson` 重新解析 `{...toJson(), ...mergeUnknownJsonFields(primary: extraJson, secondary: other.extraJson, base: base?.extraJson)}`——底层逐键三方合并规则见 [`mergeUnknownJsonFields`](../../../shared/utils/json_preservation.md)。
- **用法：** 被 [`Device.mergeUnknownFieldsFrom`](#device-mergeunknownfieldsfrom) 与记录其余部分一起合并 `device.cpu` 调用。
- **备注：** 这里只合并 `extraJson`——*已知* CPU 字段（`model`、`frequency` 等）总是来自 `this`（primary 侧），匹配 `Device.mergeUnknownFieldsFrom` 一般对待嵌套值对象的方式。

### `const GpuInfo({this.model, this.architecture, this.extraJson = const {}})` <a id="gpuinfo-new"></a>
- **种类：** `GpuInfo` 的构造函数。
- **来源：** `lib/features/devices/models/device.dart`（第 285 行）。
- **用途：** 持有设备 GPU 型号/架构加任何无法识别 JSON 字段。
- **输入：** 所有字段可选；`extraJson` 默认 `{}`。
- **返回：** 新 `GpuInfo`。
- **副作用：** 无。
- **算法：** 平凡字段赋值。
- **用法：** 与 [`CpuInfo`](#cpuinfo-new) 相同调用点：`device_edit_page.dart` 直接构造、`preset_service.dart` 的 `toDevice` 和 `ChipSearchResult.toGpuInfo`。
- **备注：** `GpuInfo` 字段远少于 `CpuInfo`——只显式建模 `model`/`architecture`；在线观察到的任何其他东西（来自 [`chip_search_service.md`](../services/chip_search_service.md)）需要经 `extraJson` 流动。

### `Map<String, dynamic> toJson()` <a id="gpuinfo-tojson"></a>
- **种类：** `GpuInfo` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 300 行）。
- **用途：** 把此 GPU 规格序列化为持久化在设备 `gpu` 字段内的 JSON。
- **输入：** 无。
- **返回：** `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** 与 `CpuInfo.toJson` 相同的展开-然后-已知字段形态，只有两个已知字段。
- **用法：** 被 [`Device.toJson`](#device-tojson)（只在 `!gpu.isEmpty` 时）和 [`mergeUnknownFieldsFrom`](#gpuinfo-mergeunknownfieldsfrom) 调用。
- **备注：** 无。

### `factory GpuInfo.fromJson(Map<String, dynamic> json)` <a id="gpuinfo-fromjson"></a>
- **种类：** `GpuInfo` 的工厂构造函数。
- **来源：** `lib/features/devices/models/device.dart`（第 311 行）。
- **用途：** 从 JSON 解析 `GpuInfo`。
- **输入：** `json`。
- **返回：** 新 `GpuInfo`；`extraJson` 持有不在 `_gpuInfoJsonKeys` 的每个键。
- **副作用：** 无。
- **算法：** 直接字段提取，无遗留键回退（不同于 `CpuInfo.fromJson`）。
- **用法：** 被 [`Device.fromJson`](#device-fromjson)（`json['gpu']` 存在时）调用。
- **备注：** 无。

### `GpuInfo mergeUnknownFieldsFrom(GpuInfo other, {GpuInfo? base})` <a id="gpuinfo-mergeunknownfieldsfrom"></a>
- **种类：** `GpuInfo` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 322 行）。
- **用途：** 三方合并此 `GpuInfo` 的未知 JSON 字段与另一个的。
- **输入：** `other`；可选 `base`。
- **返回：** 带合并 `extraJson` 的新 `GpuInfo`。
- **副作用：** 无。
- **算法：** 与 [`CpuInfo.mergeUnknownFieldsFrom`](#cpuinfo-mergeunknownfieldsfrom) 相同形态。
- **用法：** 被 [`Device.mergeUnknownFieldsFrom`](#device-mergeunknownfieldsfrom) 调用。
- **备注：** 无。

### `static StorageType? fromJson(String? value)` <a id="storagetype-fromjson"></a>
- **种类：** 枚举 `StorageType` 的静态方法。
- **来源：** `lib/features/devices/models/device.dart`（第 352 行）。
- **用途：** 从其序列化名解析 `StorageType`。
- **输入：** `value` — 可空。
- **返回：** `StorageType?` — `value` 为 `null` 或无法识别时 `null`。
- **副作用：** 无。
- **算法：** Null 检查，然后 `.where(...).firstOrNull`。
- **用法：** 被 [`StorageInfo.fromJson`](#storageinfo-fromjson) 调用。
- **备注：** 无。

### `String get displayName`（RamType） <a id="ramtype-displayname"></a>
- **种类：** 枚举 `RamType` 的 getter。
- **来源：** `lib/features/devices/models/device.dart`（第 382 行）。
- **用途：** 返回 RAM 标准的惯用大写显示名（如 `RamType.lpddr5x` → `"LPDDR5X"`），区别于持久化 JSON 使用的小写 `jsonValue`/`name`。
- **输入：** 无。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** 穷举 `switch` 表达式，每个 `RamType` 值一个字面字符串。
- **用法：** 设备编辑/详情 UI 显示 RAM 类型的任何地方直接读取（如显示 `"DDR5"`、`"LPDDR4X"` 等的 RAM 类型下拉）。
- **备注：** 对枚举穷举，因此添加无此 case 的新 `RamType` 值是编译错误。

### `static RamType? fromJson(String? value)` <a id="ramtype-fromjson"></a>
- **种类：** 枚举 `RamType` 的静态方法。
- **来源：** `lib/features/devices/models/device.dart`（第 399 行）。
- **用途：** 从其序列化名解析 `RamType`。
- **输入：** `value` — 可空。
- **返回：** `RamType?`。
- **副作用：** 无。
- **算法：** Null 检查，然后 `.where(...).firstOrNull`。
- **用法：** 被 [`Device.fromJson`](#device-fromjson) 为 `ramType` 调用。
- **备注：** 无。

### `static StorageInterface? fromJson(String? value)` <a id="storageinterface-fromjson"></a>
- **种类：** 枚举 `StorageInterface` 的静态方法。
- **来源：** `lib/features/devices/models/device.dart`（第 424 行）。
- **用途：** 从其序列化名解析 `StorageInterface`。
- **输入：** `value` — 可空。
- **返回：** `StorageInterface?`。
- **副作用：** 无。
- **算法：** Null 检查，然后 `.where(...).firstOrNull`。
- **用法：** 被 [`StorageInfo.fromJson`](#storageinfo-fromjson) 调用。
- **备注：** 无。

### `const StorageInfo({this.capacity, this.type, this.interface_, this.serialNumber, this.brand, this.extraJson = const {}})` <a id="storageinfo-new"></a>
- **种类：** `StorageInfo` 的构造函数。
- **来源：** `lib/features/devices/models/device.dart`（第 444 行）。
- **用途：** 持有一个存储设备的容量、类型、物理接口、序列号和品牌。
- **输入：** 所有字段可选。
- **返回：** 新 `StorageInfo`。
- **副作用：** 无。
- **算法：** 平凡字段赋值。
- **用法：** 在 `device_edit_page.dart` 的存储条目表单直接构造并经 [`StorageInfo.fromJson`](#storageinfo-fromjson)。
- **备注：** Dart 源码中字段命名为 `interface_`（尾下划线）正为避免碰撞类似保留的 `interface` 标识符模式，而 JSON 键保持自然 `'interface'`。

### `String get displayString`（StorageInfo） <a id="storageinfo-displaystring"></a>
- **种类：** `StorageInfo` 的 getter。
- **来源：** `lib/features/devices/models/device.dart`（第 472 行）。
- **用途：** 构建此存储条目的人类可读单行摘要，如 `"512 GB SSD (M.2 NVMe)"`。
- **输入：** 无。
- **返回：** `String` — 空格连接部分；每个字段都 null 时空字符串。
- **副作用：** 无。
- **算法：** 构建部分列表：1. 已设时 `capacity`。2. 已设时 `type` 映射为显示标签（`"SSD"`/`"SD Card"`/`"HDD"`）。3. 已设时 `interface_` 映射为括号显示标签（`"(M.2 NVMe)"`/`"(2.5\" SATA)"`/`"(M.2 SATA)"`/`"(USB)"`）。用单个空格连接所有存在部分。
- **用法：** 设备详情/编辑视图存储条目需要紧凑显示字符串的任何地方直接读取（如存储列表块副标题）。
- **备注：** 省略底层字段为 `null` 的任何部分而非显示占位，因此只设 `capacity` 的存储条目显示为 `"512 GB"`。

### `Map<String, dynamic> toJson()` <a id="storageinfo-tojson"></a>
- **种类：** `StorageInfo` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 495 行）。
- **用途：** 把此存储条目序列化为持久化在设备 `storage` 列表内的 JSON。
- **输入：** 无。
- **返回：** `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** 与 `CpuInfo.toJson` 相同的展开-然后-已知字段形态；`type`/`interface_` 经其 `.jsonValue`（枚举名）序列化。
- **用法：** 被 [`Device.toJson`](#device-tojson) 为 `storage` 每个条目调用，也被 [`mergeUnknownFieldsFrom`](#storageinfo-mergeunknownfieldsfrom) 调用。
- **备注：** 此声明源码无 `/// Purpose:` 文档注释（见声明表上方的行数说明）。

### `factory StorageInfo.fromJson(dynamic json)` <a id="storageinfo-fromjson"></a>
- **种类：** `StorageInfo` 的工厂构造函数。
- **来源：** `lib/features/devices/models/device.dart`（第 504 行）。
- **用途：** 从当前 JSON 对象形态或遗留普通字符串形态（如 `"512 GB"`）解析 `StorageInfo`。
- **输入：** `json` — `dynamic`，非 `Map<String, dynamic>`，正为接受任一形态。
- **返回：** 新 `StorageInfo`；普通字符串输入时只设 `capacity`，每个其他字段 `null`。
- **副作用：** 无。
- **算法：** 1. `json is String` 时直接返回 `StorageInfo(capacity: json)`——遗留路径。2. 否则转换为 `Map<String, dynamic>` 并提取每个已知字段，`type`/`interface` 经各自 `fromJson` 枚举解析器解析。
- **用法：** 被 [`Device.fromJson`](#device-fromjson) 为设备 `storage` 数组每个条目调用（它本身分支于整个 `storage` 值是遗留单字符串还是列表——见 [`Device.fromJson`](#device-fromjson)）。
- **备注：** 这是本文件唯一对同一字段接受两种结构不同 JSON 形态的模型——存储成为结构化对象前写的数据的普通字符串，和当前对象形态。其参数类型是 `dynamic` 而非 `Map<String, dynamic>` 正为允许这个。此声明源码无 `/// Purpose:` 文档注释。

### `StorageInfo mergeUnknownFieldsFrom(StorageInfo other, {StorageInfo? base})` <a id="storageinfo-mergeunknownfieldsfrom"></a>
- **种类：** `StorageInfo` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 520 行）。
- **用途：** 三方合并此 `StorageInfo` 的未知 JSON 字段与另一个的。
- **输入：** `other`；可选 `base`。
- **返回：** 带合并 `extraJson` 的新 `StorageInfo`。
- **副作用：** 无。
- **算法：** 与 `CpuInfo.mergeUnknownFieldsFrom` 相同形态。
- **用法：** 被 [`Device.mergeUnknownFieldsFrom`](#device-mergeunknownfieldsfrom) 对每对索引对齐 `storage` 条目调用一次（两侧列表长度不同时条目如何配对见该条目 Algorithm）。
- **备注：** 此声明源码无 `/// Purpose:` 文档注释。

### `const MoneyValue({required this.amount, required this.currency, required this.defaultCurrency, required this.convertedAmount, required this.exchangeRate, required this.autoRate, this.rateUpdatedAt, this.extraJson = const {}})` <a id="moneyvalue-new"></a>
- **种类：** `MoneyValue` 的构造函数。
- **来源：** `lib/features/devices/models/device.dart`（第 543 行）。
- **用途：** 持有以任何货币输入的价格及其到应用默认货币的转换、所用汇率和该汇率是自动还是手动。
- **输入：** `amount`、`currency`、`defaultCurrency`、`convertedAmount`、`exchangeRate`、`autoRate` 必填；可选 `rateUpdatedAt`、`extraJson`。
- **返回：** 新 `MoneyValue`。
- **副作用：** 无。
- **算法：** 平凡字段赋值——此构造函数自己不做任何转换；调用方从 [`DeviceExchangeRateService.convert`](../services/exchange_rate_service.md#convert)/`convertOptional` 获得已填充 `MoneyValue`，它们调用此构造函数前计算 `convertedAmount`/`exchangeRate`。
- **用法：** 被 `DeviceExchangeRateService.convert`（见 [`exchange_rate_service.md`](../services/exchange_rate_service.md)）调用，它是完整 `MoneyValue` 通常从零构造的唯一地方。
- **备注：** 此声明源码无 `/// Purpose:` 文档注释。

### `Map<String, dynamic> toJson()` <a id="moneyvalue-tojson"></a>
- **种类：** `MoneyValue` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 554 行）。
- **用途：** 把此货币值序列化为持久化在 `purchasePrice`、`soldPrice` 或 `DeviceRecurringCost.price` 内的 JSON。
- **输入：** 无。
- **返回：** 带 `amount`、`currency`、`defaultCurrency`、`convertedAmount`、`exchangeRate`、`autoRate` 和存在时 `rateUpdatedAt`（ISO-8601）的 `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** 直接字段映射（不同于本文件其他 `toJson`，除 `rateUpdatedAt` 外每个已知字段无条件，非 `if (x != null)` 门控，因为 `amount` 到 `autoRate` 都非可空）。
- **用法：** 被 [`Device.toJson`](#device-tojson) 为 `purchasePrice`/`soldPrice`、被 [`DeviceRecurringCost.toJson`](#devicerecurringcost-tojson) 为 `price` 调用。
- **备注：** 此声明源码无 `/// Purpose:` 文档注释。

### `factory MoneyValue.fromJson(Map<String, dynamic> json)` <a id="moneyvalue-fromjson"></a>
- **种类：** `MoneyValue` 的工厂构造函数。
- **来源：** `lib/features/devices/models/device.dart`（第 566 行）。
- **用途：** 从 JSON 解析 `MoneyValue`，容忍替代 `defaultCurrency` 的较旧 `baseCurrency` 键和缺失 `convertedAmount`。
- **输入：** `json`。
- **返回：** 新 `MoneyValue`。
- **副作用：** 无。
- **算法：** 1. 把 `amount`/`currency` 作为必填读取。2. `defaultCurrency` 回退遗留 `json['baseCurrency']` 键，两者都不在时再回退 `currency` 本身。3. `exchangeRate` 缺席默认 `1.0`。4. `convertedAmount` 键本身缺失时回退 `amount * exchangeRate`（而非总是信任存储值）。5. `autoRate` 默认 `true`。6. `rateUpdatedAt` 只在存在时经 `DateTime.parse` 解析。
- **用法：** 被 [`Device.fromJson`](#device-fromjson) 为 `purchasePrice`/`soldPrice`、被 [`DeviceRecurringCost.fromJson`](#devicerecurringcost-fromjson) 为 `price` 调用。
- **备注：** 此声明源码无 `/// Purpose:` 文档注释。`baseCurrency` → `defaultCurrency` 重命名和派生 `convertedAmount` 回退都是较旧持久化数据的真实向后兼容路径，非投机——直接在此代码确认。

### `MoneyValue mergeUnknownFieldsFrom(MoneyValue other, {MoneyValue? base})` <a id="moneyvalue-mergeunknownfieldsfrom"></a>
- **种类：** `MoneyValue` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 588 行）。
- **用途：** 三方合并此 `MoneyValue` 的未知 JSON 字段与另一个的。
- **输入：** `other`；可选 `base`。
- **返回：** 带合并 `extraJson` 的新 `MoneyValue`。
- **副作用：** 无。
- **算法：** 与 `CpuInfo.mergeUnknownFieldsFrom` 相同形态。
- **用法：** 被 [`Device.mergeUnknownFieldsFrom`](#device-mergeunknownfieldsfrom) 为 `purchasePrice`/`soldPrice`（只在两侧该字段都有非 null 值时）、被 [`DeviceRecurringCost.mergeUnknownFieldsFrom`](#devicerecurringcost-mergeunknownfieldsfrom) 为嵌套 `price` 调用。
- **备注：** 此声明源码无 `/// Purpose:` 文档注释。

### `DeviceRecurringCost({String? id, required this.kind, this.name, required this.price, this.billingCycle = BillingCycle.monthly, this.extraJson = const {}})` <a id="devicerecurringcost-new"></a>
- **种类：** `DeviceRecurringCost` 的构造函数。
- **来源：** `lib/features/devices/models/device.dart`（第 609 行）。
- **用途：** 持有一个循环设备成本（租赁、保险、订阅或其他），未提供时生成新鲜 UUID `id`。
- **输入：** 可选 `id`（`null` 自动生成）；`kind`、`price` 必填；可选 `name`；`billingCycle` 默认 `monthly`。
- **返回：** 新 `DeviceRecurringCost`。
- **副作用：** 无（除 `id` 为 null 时调用 `Uuid().v4()`——无 IO）。
- **算法：** 初始化器列表中 `id = id ?? const Uuid().v4()`，其余普通字段赋值。
- **用法：**
  ```dart
  recurringCosts.add(
    DeviceRecurringCost(
      id: draft.existing?.id,
      kind: draft.kind,
      name: _nonEmpty(draft.nameCtrl.text),
      billingCycle: draft.billingCycle,
      price: price,
      extraJson: draft.existing?.extraJson ?? const {},
    ),
  );
  ```
  （来自 `device_edit_page.dart` 的保存处理器；传 `draft.existing?.id` 在编辑时保留相同 `id` 而非铸造新的）
- **备注：** 此声明源码无 `/// Purpose:` 文档注释。真正新成本传 `id: null` 触发 UUID 生成；传既有 id（如用法示例）是让编辑成本不像是同步合并眼中的删除-并-重建所必需（合并按 `id` 而非内容匹配记录——见 [三方合并](../../../../algorithms/three-way-merge.md)，注意 `DeviceRecurringCost` 本身作为 `Device` 内嵌套结构合并，不是自己的顶层 `mergeRecords<T>` 集合）。

### `double get annualConvertedAmount`（DeviceRecurringCost） <a id="devicerecurringcost-annualconvertedamount"></a>
- **种类：** `DeviceRecurringCost` 的 getter。
- **来源：** `lib/features/devices/models/device.dart`（第 618 行）。
- **用途：** 基于其 `billingCycle` 把此循环成本投影为等价年度转换金额。
- **输入：** 无。
- **返回：** `double`。
- **副作用：** 无。
- **算法：** `switch (billingCycle) { BillingCycle.monthly => price.convertedAmount * 12, BillingCycle.yearly => price.convertedAmount }`——直接对照源码确认，匹配 [设备 — 生命周期与财务跟踪](../../../../features/devices.md#lifecycle-and-finance-tracking) 的描述。
- **用法：** 只被本类 [`dailyConvertedAmount`](#devicerecurringcost-new)（见上面 Tier B 行）读取。
- **备注：** 月度成本的转换 `price.convertedAmount` 被当作*月度*金额（因此年度 ×12）；年度成本的 `price.convertedAmount` 已是年度金额（无乘法）——弄反会在 `Device` 上每个下游每日/总成本计算产生 12 倍错误。

### `Map<String, dynamic> toJson()` <a id="devicerecurringcost-tojson"></a>
- **种类：** `DeviceRecurringCost` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 625 行）。
- **用途：** 把此循环成本序列化为持久化在设备 `recurringCosts` 列表内的 JSON。
- **输入：** 无。
- **返回：** 带 `id`、`kind`、`name`（已设时）、`price`（嵌套 `MoneyValue.toJson()`）、`billingCycle` 的 `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** 展开-然后-已知字段形态，嵌套 `price.toJson()`。
- **用法：** 被 [`Device.toJson`](#device-tojson) 为 `recurringCosts` 每个条目调用。
- **备注：** 此声明源码无 `/// Purpose:` 文档注释。

### `factory DeviceRecurringCost.fromJson(Map<String, dynamic> json)` <a id="devicerecurringcost-fromjson"></a>
- **种类：** `DeviceRecurringCost` 的工厂构造函数。
- **来源：** `lib/features/devices/models/device.dart`（第 634 行）。
- **用途：** 从 JSON 解析 `DeviceRecurringCost`。
- **输入：** `json`。
- **返回：** 新 `DeviceRecurringCost`；`price` 缺失时抛（必填、非可空）。
- **副作用：** 无。
- **算法：** 直接字段提取；`kind`/`billingCycle` 经其枚举 `fromJson` 解析器；`price` 在必填 `json['price']` 映射上经 `MoneyValue.fromJson`。
- **用法：** 被 [`Device.fromJson`](#device-fromjson) 为 `recurringCosts` 每个条目调用。
- **备注：** 此声明源码无 `/// Purpose:` 文档注释。

### `DeviceRecurringCost mergeUnknownFieldsFrom(DeviceRecurringCost other, {DeviceRecurringCost? base})` <a id="devicerecurringcost-mergeunknownfieldsfrom"></a>
- **种类：** `DeviceRecurringCost` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 644 行）。
- **用途：** 三方合并此成本的未知 JSON 字段与另一个的，含嵌套 `price` 自己的未知字段。
- **输入：** `other`；可选 `base`。
- **返回：** 带合并 `extraJson` 和合并 `price` 的新 `DeviceRecurringCost`。
- **副作用：** 无。
- **算法：** 1. 从 `toJson()` 开始，与其他模型类相同经 `mergeUnknownJsonFields` 合并进 `extraJson`。2. 额外用 `price.mergeUnknownFieldsFrom(other.price, base: base?.price).toJson()` 覆盖 `json['price']`——这是本文件唯一合并触碰 `extraJson` 之外嵌套字段的类，因为 `price` 本身是有自己未知字段要保留的模型。3. 经 `DeviceRecurringCost.fromJson` 重新解析。
- **用法：** 被 [`Device.mergeUnknownFieldsFrom`](#device-mergeunknownfieldsfrom) 对每对索引对齐 `recurringCosts` 条目调用一次。
- **备注：** 此声明源码无 `/// Purpose:` 文档注释。与 `CpuInfo`/`GpuInfo`/`StorageInfo` 的合并方法（只碰 `extraJson`）不同，这个也递归进 `price` 的合并——已知 `kind`/`name`/`billingCycle` 字段仍无条件来自 `this`，与别处相同。

### `Device({String? id, required this.name, required this.category, ..., DateTime? modifiedAt, this.extraJson = const {}})` <a id="device-new"></a>
- **种类：** `Device` 的构造函数。
- **来源：** `lib/features/devices/models/device.dart`（第 699 行）。
- **用途：** 创建设备记录，两者都未提供时生成新鲜 UUID `id` 和 UTC `modifiedAt` 时间戳。
- **输入：** `name`、`category` 必填；每个其他字段（身份、规格、位置、生命周期、财务、`notes`）可选带合理默认（`cpu`/`gpu` 默认空 `const` 实例、`storage`/`recurringCosts` 默认 `[]`、`isRetired`/`isSold` 默认 `false`）。
- **返回：** 新 `Device`。
- **副作用：** 无（除 `Uuid().v4()`/`DateTime.now()` 调用——无 IO）。
- **算法：** 初始化器列表中 `id = id ?? const Uuid().v4()`、`modifiedAt = modifiedAt ?? DateTime.now().toUtc()`；所有其他字段带声明默认普通赋值。
- **用法：**
  ```dart
  final device = Device(
    id: widget.device?.id,
    name: _nameCtrl.text.trim(),
    category: _category,
    ...
    isRetired: isRetired,
    isSold: isSold,
    ...
  );
  await DeviceStorage.addOrUpdate(device);
  ```
  （来自 `device_edit_page.dart` 的保存处理器——注意本应用经每个字段直接构造更新 `Device` 而非经 [`copyWith`](#copywith)；传 `widget.device?.id` 编辑时保留相同 `id`，`null` 为全新设备铸造新的）
- **备注：** 除非显式覆盖 `modifiedAt` 总是刷新为"现在"——每次不经显式 `modifiedAt` 经此构造函数保存都 bump 记录的同步相关时间戳，这正是 [`mergeRecords<Device>`](../../../../algorithms/three-way-merge.md) 用来检测哪侧变化的东西。

### `DeviceLifecycleStatus get lifecycleStatus` <a id="lifecyclestatus"></a>
- **种类：** `Device` 的 getter。
- **来源：** `lib/features/devices/models/device.dart`（第 736 行）。
- **用途：** 从 `isSold`/`isRetired` 标志派生设备生命周期桶（`sold`/`retired`/`inService`），两者都设时 `isSold` 优先。
- **输入：** 无。
- **返回：** `DeviceLifecycleStatus`。
- **副作用：** 无。
- **算法：** `if (isSold) return sold; if (isRetired) return retired; return inService;`——直接在源码和 [设备 — 生命周期与财务跟踪](../../../../features/devices.md#lifecycle-and-finance-tracking) 确认。
- **用法：**
  ```dart
  byLifecycle[d.lifecycleStatus.name] = (byLifecycle[d.lifecycleStatus.name] ?? 0) + 1;
  ```
  （来自 `lib/shared/services/local_api_server.dart` 的设备摘要端点；也被 `device_list_page.dart` 的过滤标签和 `import_export_service.dart` 的 Markdown 导出直接读取）
- **备注：** `isSold` 和 `isRetired` 都设的设备报告为 `sold` 而非 `retired`——此优先级排序对主页过滤计数和财务摘要承载负载，是此 getter 逻辑值得显式点出的唯一部分（容易假设两标志互斥，但模型不强制）。

### `bool get hasFinancialData` <a id="hasfinancialdata"></a>
- **种类：** `Device` 的 getter。
- **来源：** `lib/features/devices/models/device.dart`（第 744 行）。
- **用途：** 返回此设备是否记录任何财务数据——购买价格、出售价格或至少一个循环成本。
- **输入：** 无。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** `purchasePrice != null || soldPrice != null || recurringCosts.isNotEmpty`。
- **用法：**
  ```dart
  final financeDevices = devices.where((d) => d.hasFinancialData).toList();
  ```
  （来自 `local_api_server.dart` 的财务摘要端点；也门控 `device_detail_page.dart`/`device_finance_overview_page.dart` 是否渲染财务小节）
- **备注：** 这是 [`averageDailyCost`](#averagedailycost) 计算任何东西前也检查的守卫——零财务数据设备总是报告 `averageDailyCost == null` 而非计算 `0.0`，后者否则与"真正免费拥有"视觉不可区分。

### `int? serviceDays({DateTime? asOf})` <a id="servicedays"></a>
- **种类：** `Device` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 747 行）。
- **用途：** 计算此设备已（或曾）在用天数，从 `purchaseDate` 计到或现在（仍在使用）或 `retiredDate`（否则）。
- **输入：** 可选 `asOf` — "仍在使用"分支覆盖"现在"；默认 `DateTime.now()`。
- **返回：** `int?` — `purchaseDate` 未设时 `null`；否则至少 `1`。
- **副作用：** 无。
- **算法：** 1. `purchaseDate` 为 null 返回 `null`。2. `end = isInService ? now : (retiredDate ?? now)`——无记录 `retiredDate` 的退役/出售设备此计算仍回退"现在"。3. 返回 `max(1, end.difference(purchaseDate!).inDays + 1)`——`+1` 让同日购买计为 1 天而非 0，`max(1, ...)` 是下限使即使未来日期购买结果也绝不零或负。
- **用法：**
  ```dart
  'serviceDays': device.serviceDays(),
  ```
  （来自 `local_api_server.dart` 的逐设备 JSON 导出）
- **备注：** 被 [`recurringCostThrough`](#recurringcostthrough) 和 [`averageDailyCost`](#averagedailycost) 作为共享"我们除以/乘以多少天"值消费——改变此方法舍入影响两者。

### `double recurringCostThrough({DateTime? asOf})` <a id="recurringcostthrough"></a>
- **种类：** `Device` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 754 行）。
- **用途：** 对每个循环成本的每日等价费率跨设备总服务天数求和，给出迄今（或投影到 `asOf`）花在循环成本上的总金额。
- **输入：** 可选 `asOf`，转发给 [`serviceDays`](#servicedays)。
- **返回：** `double` — `serviceDays` 为 `null`（无 `purchaseDate`）时 `0`。
- **副作用：** 无。
- **算法：** `recurringCosts.fold<double>(0, (sum, cost) => sum + cost.dailyConvertedAmount * days)`——每个循环成本对*整个*服务天跨度收费，不按自己开始日期分摊（无建模的逐成本开始日期）。
- **用法：**
  ```dart
  'recurringCostThrough': device.recurringCostThrough(),
  ```
  （来自 `local_api_server.dart`；也是 [`totalCost`](#totalcost)/`device_finance_overview_page.dart` 每日成本趋势图的基础，见 [设备 — 财务总览页](../../../../features/devices.md#financial-overview-page)）
- **备注：** 因为每个循环成本无论那个特定租赁/订阅实际何时开始都乘相同 `serviceDays`，给长期持有设备添加循环成本把其累积成本回溯到设备整个拥有跨度，不只从今天起。

### `double totalCost({DateTime? asOf})` <a id="totalcost"></a>
- **种类：** `Device` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 763 行）。
- **用途：** 计算此设备总拥有成本：购买价格加累积循环成本，减任何回收出售价格。
- **输入：** 可选 `asOf`，转发给 [`recurringCostThrough`](#recurringcostthrough)。
- **返回：** `double`。
- **副作用：** 无。
- **算法：** `(purchasePrice?.convertedAmount ?? 0) + recurringCostThrough(asOf: asOf) - (soldPrice?.convertedAmount ?? 0)`——直接对照源码确认，匹配 [设备 — 生命周期与财务跟踪](../../../../features/devices.md#lifecycle-and-finance-tracking) 文档化公式。
- **用法：**
  ```dart
  final amount = math.max(0.0, device.totalCost());
  widget.devices.fold(0, (sum, device) => sum + device.totalCost());
  ```
  （来自 `device_finance_overview_page.dart` 的资产分布图和类别总计；也被 `device_detail_page.dart`、`device_list_page.dart` 和 `local_api_server.dart` 读取）
- **备注：** 可为负（出售价格超过购买价格加循环成本）——把它喂进图表的调用方（如财务总览页资产分布）自己钳制为 `math.max(0.0, ...)`；此方法不钳制。

### `double? averageDailyCost({DateTime? asOf})` <a id="averagedailycost"></a>
- **种类：** `Device` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 769 行）。
- **用途：** 计算拥有此设备的平均每日成本，无财务数据或无可度量天数的 `purchaseDate` 时为 `null`。
- **输入：** 可选 `asOf`，转发给 [`serviceDays`](#servicedays) 和 [`totalCost`](#totalcost) 两者。
- **返回：** `double?` — `serviceDays` 为 `null` 或 [`hasFinancialData`](#hasfinancialdata) 为 `false` 时 `null`；否则 `totalCost(asOf: asOf) / days`。
- **副作用：** 无。
- **算法：** 计算 `days = serviceDays(asOf: asOf)`；`days == null || !hasFinancialData` 时返回 `null`；否则 `totalCost(asOf: asOf) / days`。
- **用法：**
  ```dart
  'averageDailyCost': device.averageDailyCost(),
  ```
  （来自 `local_api_server.dart`；也是 `device_finance_overview_page.dart` 每日成本趋势线上绘制的逐点值，含其虚线未来投影段——见 [设备 — 财务总览页](../../../../features/devices.md#financial-overview-page)）
- **备注：** `hasFinancialData` 守卫特别防止设了 `purchaseDate` 但零记录成本的设备报告 `0.0`（图表会渲染为真实、虽然无聊的数据点）——它改报 `null`（无数据点）。

### `double? get ppi` <a id="ppi"></a>
- **种类：** `Device` 的 getter。
- **来源：** `lib/features/devices/models/device.dart`（第 776 行）。
- **用途：** 从设备屏幕分辨率和物理屏幕尺寸计算每英寸像素。
- **输入：** 无。
- **返回：** `double?` — 分辨率或可解析屏幕对角线缺失时 `null`。
- **副作用：** 无。
- **算法：** 1. `screenResolutionW`/`screenResolutionH` 任一为 null 返回 `null`。2. 经 [`_parseScreenDiagonal`](#_parsescreendiagonal) 把 `screenSize` 解析为英寸；失败或 `<= 0` 返回 `null`。3. 返回 `sqrt(w*w + h*h) / diagonal`——像素分辨率对角线除以物理英寸对角线。
- **用法：**
  ```dart
  if (device.ppi != null)
    _specRow(l10n.ppi, device.ppi!.toStringAsFixed(0)),
  ```
  （来自 `device_detail_page.dart` 的规格列表；也被 `device_edit_page.dart` 和 `import_export_service.dart` 的 Markdown 导出读取）
- **备注：** 完全依赖 `screenSize` 能被 [`_parseScreenDiagonal`](#_parsescreendiagonal) 解析——不以可识别单位/引号结尾的屏幕尺寸字符串即使分辨率完全已知这里也产生 `null`。

### `static double? _parseScreenDiagonal(String? s)` <a id="_parsescreendiagonal"></a>
- **种类：** `Device` 的私有静态方法。
- **来源：** `lib/features/devices/models/device.dart`（第 785 行）。
- **用途：** 把自由文本屏幕尺寸字符串（如 `6.7"`、`15.6 inch`、`13寸`）解析为普通数字英寸值。
- **输入：** `s` — 可空、自由文本。
- **返回：** `double?` — `s` 为 null/空或清洗字符串解析不为数字时 `null`。
- **副作用：** 无。
- **算法：** 经正则剥离 `"`/`'`/`'`/`寸`/`inch`/`inchs`（不区分大小写）的尾部运行，修剪，然后 `double.tryParse`。
- **用法：** 只被 [`ppi`](#ppi) 调用。
- **备注：** 只剥离*尾部*单位后缀——单位在别处（或数字前有额外文本）的屏幕尺寸字符串会解析失败并从 `ppi` 静默产生 `null` 而非抛。

### `Device copyWith({...many optional fields..., bool clearEmoji = false, ...})` <a id="copywith"></a>
- **种类：** `Device` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 794 行）。
- **用途：** 创建此设备的任何子集字段被替换的副本，并对每个可空字段有完全置 null 的显式 `clearXxx` 标志（因为 Dart 中可选参数传 `null` 与"未提供"无法区分）。
- **输入：** 每个要替换字段一个可选参数，加每个可空字段一个 `bool clearXxx = false` 改为清除它（如 `clearEmoji`、`clearBrand`、`clearPurchasePrice`……）；`id` 和 `extraJson` 总是原样带过（根本不是参数）；未显式传入时 `modifiedAt` 默认新鲜 `DateTime.now().toUtc()`。
- **返回：** 相同 `id`、所有指定替换已应用、所有指定 `clearXxx` 字段已置 null、其他一切不变的新 `Device`。
- **副作用：** 无。
- **算法：** 对每个可清除字段：`clearXxx ? null : (xxx ?? this.xxx)`；对不可清除字段（`name`、`category`、`cpu`、`gpu`、`storage`、`isRetired`、`isSold`、`recurringCosts`）：`xxx ?? this.xxx`；`modifiedAt: modifiedAt ?? DateTime.now().toUtc()`。
- **返回（续）：** `extraJson` 总是原样复制——`copyWith` 不能修改无法识别/保留字段。
- **用法：** `lib/` 中未找到任何调用点——每个需要更新 `Device` 的地方（如 `device_edit_page.dart` 的保存处理器）当前经主构造函数用每个字段显式拼出构造全新 `Device`（见 [`Device`](#device-new) 的 Usage），而非调用 `copyWith`。这里作为公共 API 表面文档化，非要移除的死代码——这是文档遍，不是重构。
- **备注：** `clearXxx` 标志模式存在因为 `copyWith(brand: null)` 无法与"调用方未传 `brand`"区分——本代码库需要置 null 字段的每个其他模型 `copyWith` 用相同模式（见如 `../../../datasets/models/dataset.dart` 的 `DataSet.copyWith`，不在此批覆盖）。

### `Map<String, dynamic> toJson()` <a id="device-tojson"></a>
- **种类：** `Device` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 900 行）。
- **用途：** 把此设备序列化为持久化在 `device_data.json` 并经同步到 WebDAV 远程的 JSON。
- **输入：** 无。
- **返回：** `Map<String, dynamic>`——先展开 `extraJson`，然后每个已知字段，大多数 `if (field != null)` 门控；`cpu`/`gpu` 只在 `if (!cpu.isEmpty)`/`if (!gpu.isEmpty)` 时包含；`storage`/`recurringCosts` 只在 `if (...isNotEmpty)` 时包含；`isRetired`/`isSold` 只在 `if (true)` 时包含（`false` 时完全省略）；`id`/`name`/`category`/`modifiedAt` 总是存在。
- **副作用：** 无。
- **算法：** 带上面条件包含规则的直接字段到键映射；嵌套值（`cpu`、`gpu`、每个 `storage`/`recurringCosts` 条目、`purchasePrice`/`soldPrice`）经自己的 `toJson()` 序列化。
- **用法：** 被 [`DeviceData.toJson`](#devicedata-tojson) 为每个设备调用，被 `local_api_server.dart` 的 `mergeUnknownFields` 回调（`primary.mergeUnknownFieldsFrom(...)`）经 [`mergeUnknownFieldsFrom`](#device-mergeunknownfieldsfrom) 间接调用。
- **备注：** `isRetired`/`isSold` 为 `false` 时完全省略（而非写 `false`）让常见 case（在用设备）留在持久化 JSON 外——这是存储大小优化，非正确性要求，因为 [`Device.fromJson`](#device-fromjson) 缺席时把两者默认 `false`。

### `factory Device.fromJson(Map<String, dynamic> json)` <a id="device-fromjson"></a>
- **种类：** `Device` 的工厂构造函数。
- **来源：** `lib/features/devices/models/device.dart`（第 937 行）。
- **用途：** 从 JSON 解析 `Device`，容忍遗留单字符串 `storage` 形态加当前对象列表形态。
- **输入：** `json`。
- **返回：** 新 `Device`；`id`/`name`/`category`/`modifiedAt` 缺失时抛（都必填、非可空读取）。
- **副作用：** 无。
- **算法：** 大多数字段直接字段提取；`cpu`/`gpu` 存在时经 [`CpuInfo.fromJson`](#cpuinfo-fromjson)/[`GpuInfo.fromJson`](#gpuinfo-fromjson)，否则空 `const` 默认；`storage` 分支于 `json['storage']` 是 `String`（遗留：经 `StorageInfo.fromJson` 包进单元素列表）还是 `List`（映射每个条目）；日期字段经 `DateTime.parse`；`extraJson` 经 `unknownJsonFields(json, _deviceJsonKeys)`。
- **用法：**
  ```dart
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return DeviceData.fromJson(json);
  ```
  （来自 [`../services/device_storage.md#load`](../services/device_storage.md)，并被 `lib/shared/services/sync_merge.dart` 的 `mergeDeviceData` 经 `DeviceData.fromJson` 间接调用）
- **备注：** 遗留单字符串 `storage` 分支镜像 [`StorageInfo.fromJson`](#storageinfo-fromjson) 自己的字符串-vs-对象处理——存储成为结构化条目列表前写的数据今天仍正确解析。

### `Device mergeUnknownFieldsFrom(Device other, {Device? base})` <a id="device-mergeunknownfieldsfrom"></a>
- **种类：** `Device` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 1001 行）。
- **用途：** 合并此设备的未知 JSON 字段与另一个的，并额外把相同三方未知字段合并递归进每个嵌套值对象（`cpu`、`gpu`、每个 `storage` 条目、`purchasePrice`、`soldPrice`、每个 `recurringCosts` 条目），使同步合并期间无嵌套无法识别字段丢失。
- **输入：** `other` — 另一侧（secondary）；可选 `base` — 上次同步快照。
- **返回：** 新 `Device`——与 `this` 相同已知顶层字段，但每个嵌套值对象的 `extraJson` 对照 `other` 对应值合并，经 `Device.fromJson` 重新解析。
- **副作用：** 无。
- **算法：** 这是 [`mergeRecords<Device>`](../../../../algorithms/three-way-merge.md) 作为 `mergeUnknownFields` 调用的逐记录回调——它*不*自己决定哪个整记录胜出（那是 `mergeRecords<Device>` 的工作）；它只在 `this` 已被选为 primary 后合并嵌套内容。1. 从 `toJson()` 开始，与本文件每个其他模型相同方式合并顶层 `extraJson`。2. `cpu`/`gpu`：经各自 `mergeUnknownFieldsFrom` 合并；合并结果 `isEmpty` 时完全移除键而非写空对象。3. `storage`：`this.storage` 非空时把 `this.storage` 每个索引 `i` 对照 `other.storage[i]`（`other` 条目更少时新鲜空 `StorageInfo()`）和 `base.storage[i]`（`base` 存在且有那么多条目时）合并重建整个列表。4. `purchasePrice`/`soldPrice`：只在 `this` 和 `other` 该字段都有非 null 值时合并（否则字段留作 `toJson()` 已从 `this` 产生的任何东西）。5. `recurringCosts`：与 `storage` 相同索引对齐重建，除缺失 `other` 条目的回退是 `recurringCosts[i]` 本身（成本与自身合并是空操作）而非新鲜空值，因为 `DeviceRecurringCost` 无有意义"空"默认。6. 经 `Device.fromJson` 重新解析完全组装 `json` 映射。
- **用法：**
  ```dart
  mergeUnknownFields: (primary, secondary, base) =>
      primary.mergeUnknownFieldsFrom(secondary, base: base),
  ```
  （来自 `lib/shared/services/sync_merge.dart` 的 `mergeDeviceData`，作为 `mergeUnknownFields` 回调传入 `mergeRecords<Device>`——`mergeRecords<T>` 在调用此之前如何决定哪侧是 `primary`/`secondary` 见 [三方合并](../../../../algorithms/three-way-merge.md)）
- **备注：** 这里列表合并严格**索引对齐**，不经 `storage`/`recurringCosts` 条目自身内任何身份匹配（`StorageInfo`/`DeviceRecurringCost` 列表项除位置外无稳定跨侧匹配键，除 `DeviceRecurringCost` 确实有 `id`，此方法*不*用其匹配）——两侧在不同位置重排或插入/移除条目时，这会把无关条目 `extraJson` 在同一索引合并到一起。这是真实、源码确认的限制，非假设边缘 case。此声明源码无 `/// Purpose:` 文档注释。

### `const DeviceData({this.devices = const [], this.extraJson = const {}})` <a id="devicedata-new"></a>
- **种类：** `DeviceData` 的构造函数。
- **来源：** `lib/features/devices/models/device.dart`（第 1084 行）。
- **用途：** 持有持久化到 `device_data.json` 的顶层设备列表。
- **输入：** 可选 `devices`（默认 `[]`）；可选 `extraJson`。
- **返回：** 新 `DeviceData`。
- **副作用：** 无。
- **算法：** 平凡字段赋值。
- **用法：**
  ```dart
  await save(DeviceData(devices: devices));
  ```
  （来自 [`../services/device_storage.md#addorupdate`](../services/device_storage.md)，每次保存前围绕更新设备列表构造整个容器）
- **备注：** 无。

### `Map<String, dynamic> toJson()` <a id="devicedata-tojson"></a>
- **种类：** `DeviceData` 的方法。
- **来源：** `lib/features/devices/models/device.dart`（第 1091 行）。
- **用途：** 把设备列表容器序列化为写入 `device_data.json` 的 JSON。
- **输入：** 无。
- **返回：** 带 `devices`（每个经 [`Device.toJson`](#device-tojson) 序列化）加任何保留 `extraJson` 的 `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** `{...extraJson, 'devices': devices.map((d) => d.toJson()).toList()}`。
- **用法：** 被 [`../services/device_storage.md#save`](../services/device_storage.md) 调用。
- **备注：** 无。

### `factory DeviceData.fromJson(Map<String, dynamic> json)` <a id="devicedata-fromjson"></a>
- **种类：** `DeviceData` 的工厂构造函数。
- **来源：** `lib/features/devices/models/device.dart`（第 1101 行）。
- **用途：** 从 `device_data.json` 的解码内容解析 `DeviceData`。
- **输入：** `json`。
- **返回：** 新 `DeviceData`；`devices` 键缺席时默认 `[]`。
- **副作用：** 无。
- **算法：** 把 `json['devices']`（存在时）经 [`Device.fromJson`](#device-fromjson) 映射；`extraJson` 经 `unknownJsonFields(json, _deviceDataJsonKeys)`（此级别只已知单个 `'devices'` 键）。
- **用法：** 被 [`../services/device_storage.md#load`](../services/device_storage.md) 和 `lib/shared/services/sync_merge.dart` 的 `mergeDeviceData`（合并前本地和远程两侧都）调用。
- **备注：** 无。
