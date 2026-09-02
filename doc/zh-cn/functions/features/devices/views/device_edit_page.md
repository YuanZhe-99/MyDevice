# lib/features/devices/views/device_edit_page.dart

单个 `Device` 的增/改表单（模型来源 `lib/features/devices/models/device.dart`；完整字段列表见 [数据格式 — 设备](../../../../data-formats.md#device-libfeaturesdevicesmodelsdevicedart)）。`DeviceEditPage`/`_DeviceEditPageState` 拥有每个可编辑属性的一个 `TextEditingController`（或普通字段）——包括每个存储行和每个循环成本草稿各一套控制器——并在保存时把全部组装进新 `Device`。它集成 `PresetService`（捆绑 CPU/GPU/品牌预设，经私有 `_CpuPresetPicker`/`_GpuPresetPicker` 底部面板浏览）、`chip_search_dialog.dart`/`device_search_dialog.dart` 的在线搜索对话框（门控于 `AppFlavor.isFull`——见 [在线搜索与预设](../../../../features/online-search-and-presets.md)）和 `DeviceExchangeRateService`（购买/出售价格和每个循环成本的货币转换）。保存也是应用中保持 [数据集](../../../../features/datasets.md) 存储链接有效的唯一地方：本文件跨添加/移除跟踪每个存储行的原始槽索引，并在保存时把结果旧→新映射传给 `DataSetStorage.remapDeviceStorageLinks()`——见 [`_save`](#_save) 和 [数据集 — remapDeviceStorageLinks()](../../../../features/datasets.md#remapdevicestoragelinks)。此表单编辑的更广功能和生命周期/财务模型也见 [设备](../../../../features/devices.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `DeviceEditPage`（构造函数） | 构造函数 | B | 为组件存储可选 `device`（编辑目标）和 `searchResult`（预填映射）。 |
| `createState` | 方法（`DeviceEditPage`） | B | 创建 `_DeviceEditPageState`。 |
| `_isEditing` | getter（`_DeviceEditPageState`） | B | 编辑既有设备（`widget.device != null`）而非添加新的时为 true。 |
| [`initState`](#initstate) | 方法（组件生命周期） | A | 从 `widget.device`（或默认）播种每个控制器/字段并启动异步预设/财务设置加载。 |
| [`_loadFinancialSettings`](#_loadfinancialsettings) | 方法（`_DeviceEditPageState`） | A | 加载应用默认货币/自动汇率设置并为尚未定制的价格字段采用新默认。 |
| [`_loadPresets`](#_loadpresets) | 方法（`_DeviceEditPageState`） | A | 加载 CPU/GPU/品牌预设，然后预设就绪时应用带入的搜索结果。 |
| `dispose` | 方法（组件生命周期） | B | 释放此状态拥有的每个控制器，含逐存储槽和逐循环成本草稿控制器。 |
| [`_parseValueUnit`](#_parsevalueunit) | 静态方法（`_DeviceEditPageState`） | A | 把 `"16 GB"` 风格文本解析为 `(value, unit)` 对。 |
| `_combineValueUnit` | 方法（`_DeviceEditPageState`） | B | 把修剪值和单位连接为 `"value unit"`，值空白时 `null`。 |
| `_nonEmpty` | 方法（`_DeviceEditPageState`） | B | 修剪字符串，空结果用 `null` 代替。 |
| `_parseInt` | 方法（`_DeviceEditPageState`） | B | 把修剪字符串解析为 `int`，或 `null`。 |
| [`_parseMoney`](#_parsemoney) | 方法（`_DeviceEditPageState`） | A | 解析用户输入金额，容忍千位分隔符逗号。 |
| [`_parseRate`](#_parserate) | 方法（`_DeviceEditPageState`） | A | 解析手动汇率覆盖，但只在货币不同于默认时。 |
| `_acquisitionTypeLabel` | 方法（`_DeviceEditPageState`） | B | 把 `DeviceAcquisitionType` 映射到其本地化标签。 |
| `_recurringCostKindLabel` | 方法（`_DeviceEditPageState`） | B | 把 `RecurringCostKind` 映射到其本地化标签。 |
| `_billingCycleLabel` | 方法（`_DeviceEditPageState`） | B | 把 `BillingCycle` 映射到其本地化标签。 |
| [`_save`](#_save) | 方法（`_DeviceEditPageState`） | A | 验证、组装并持久化编辑 `Device`，为任何移动/移除存储槽重映射数据集存储链接。 |
| `_pickDate` | 方法（`_DeviceEditPageState`） | B | 显示日期选择器（2000..+365 天）并在选择时设 `_purchaseDate`。 |
| `_pickReleaseDate` | 方法（`_DeviceEditPageState`） | B | 显示日期选择器并在选择时设 `_releaseDate`。 |
| `_pickRetiredDate` | 方法（`_DeviceEditPageState`） | B | 显示日期选择器并在选择时设 `_retiredDate`。 |
| `_storageTypeLabel` | 方法（`_DeviceEditPageState`） | B | 把 `StorageType` 映射到其本地化标签。 |
| `_storageInterfaceLabel` | 方法（`_DeviceEditPageState`） | B | 把 `StorageInterface` 映射到其本地化标签。 |
| `_categoryLabel` | 方法（`_DeviceEditPageState`） | B | 把 `DeviceCategory` 映射到其本地化标签。 |
| `_applyCpuPreset` | 方法（`_DeviceEditPageState`） | B | 把 `CpuInfo` 预设字段复制进 CPU 控制器并 bump `_cpuAutoKey` 刷新 `Autocomplete`。 |
| `_applyGpuPreset` | 方法（`_DeviceEditPageState`） | B | 把 `GpuInfo` 预设字段复制进 GPU 控制器并 bump `_gpuAutoKey`。 |
| `_searchCpuOnline` | 方法（`_DeviceEditPageState`） | B | 打开 CPU 搜索对话框并经 `_applyCpuPreset` 应用所选结果。 |
| `_searchGpuOnline` | 方法（`_DeviceEditPageState`） | B | 打开 GPU 搜索对话框并经 `_applyGpuPreset` 应用所选结果。 |
| `_pickCpuPreset` | 方法（`_DeviceEditPageState`） | B | 打开 CPU 预设底部面板（`_CpuPresetPicker`）并应用所选预设。 |
| `_pickGpuPreset` | 方法（`_DeviceEditPageState`） | B | 打开 GPU 预设底部面板（`_GpuPresetPicker`）并应用所选预设。 |
| [`_showSearchDialog`](#_showsearchdialog) | 方法（`_DeviceEditPageState`） | A | 打开带当前字段值播种的在线设备搜索对话框并应用所选结果。 |
| [`_applySearchResult`](#_applysearchresult) | 方法（`_DeviceEditPageState`） | A | 把搜索结果字段映射应用到表单，把 CPU/GPU 文本与加载预设模糊匹配。 |
| [`_detectLogoForModel`](#_detectlogoformodel) | 方法（`_DeviceEditPageState`） | A | 为实时输入的 CPU/GPU 型号字符串找到 SVG logo 路径。 |
| `_brandLogoWidget` | 方法（组件辅助） | B | 渲染小 SVG logo（着色为 `onSurface`），`logoPath` 为 null 时无。 |
| `_showEmojiPicker` | 方法（`_DeviceEditPageState`） | B | 显示 `_commonEmojis` 底部面板网格；点击一个设 `_emoji` 并清除 `_imagePath`。 |
| [`_pickImage`](#_pickimage) | 方法（`_DeviceEditPageState`） | A | 让用户挑照片并采用为设备图标，清除任何 emoji。 |
| `_removeIcon` | 方法（`_DeviceEditPageState`） | B | 清除 `_emoji` 和 `_imagePath` 两者。 |
| `_buildIconSection` | 方法（组件辅助） | B | 渲染头像预览加图像挑/emoji 挑/移除操作；`avatarSize`（56，或双栏左窗格中的 `editAvatarSize`）与 `stacked`（chip 居中放在预览之下而非旁边）。 |
| `_buildNameField` | 方法（组件辅助） | B | 带校验的名称 `TextFormField`，单列与双栏左窗格共享。 |
| `_buildCategoryField` | 方法（组件辅助） | B | 类别 `DropdownButtonFormField`，同样共享。 |
| `_buildFormBody` | 方法（组件辅助） | B | 在同一个 `Form` 内选择布局：`_buildFields` 的单列 `ListView`，或——`useDetailTwoPane` 通过时——一个 `Row`：`detailLeftPaneWidth` 宽的左窗格（`editAvatarSize` 尺寸的堆叠图标区、名称、类别；钉住窗格高度的 `SingleChildScrollView` 作软键盘兜底）加右侧其余字段的 `ListView`。 |
| `_buildFields` | 方法（组件辅助） | B | 按原顺序的完整字段列表；`twoPane` 时省略左窗格自己渲染的名称、类别与图标区。 |
| `_currencyItems` | 方法（组件辅助） | B | 从 `supportedCurrencies` 构建货币下拉项，加未列出时的 `current`。 |
| `_buildMoneyFields` | 方法（组件辅助） | B | 渲染金额+货币行，非默认货币时加自动汇率复选框和手动汇率字段。 |
| `_addRecurringCost` | 方法（`_DeviceEditPageState`） | B | 追加新空白 `_RecurringCostDraft`（默认种类 `other`，货币 = `_defaultCurrency`）。 |
| `_buildRecurringCostCard` | 方法（组件辅助） | B | 渲染一个循环成本草稿的可编辑卡片（种类/名/计费周期/货币字段/移除按钮）。 |
| `_buildFinancialSection` | 方法（组件辅助） | B | 渲染获取/生命周期/购买/出售/循环成本财务小节。 |
| `build` | 方法（组件） | B | 围绕 `_buildFormBody` 构建脚手架和应用栏（保存 + 在线搜索操作）。 |
| `_RecurringCostDraft`（构造函数） | 构造函数 | B | 创建带新鲜金额/名/汇率控制器、`billingCycle` 默认月度、`autoRate` 默认 true 的草稿。 |
| [`_RecurringCostDraft.fromCost`](#_recurringcostdraft-fromcost) | 工厂构造函数（`_RecurringCostDraft`） | A | 把持久化 `DeviceRecurringCost` 转换为可编辑草稿。 |
| `dispose` | 方法（`_RecurringCostDraft`） | B | 释放草稿的三个控制器。 |
| `_CpuPresetPicker`（构造函数） | 构造函数 | B | 为底部面板组件存储 `presets` 列表。 |
| `createState` | 方法（`_CpuPresetPicker`） | B | 创建 `_CpuPresetPickerState`。 |
| [`_filtered`](#_filtered-cpu)（CPU） | getter（`_CpuPresetPickerState`） | A | 过滤 `widget.presets` 到 model/architecture 含当前搜索查询的条目。 |
| `_coresLabel` | 方法（`_CpuPresetPickerState`） | B | 把存在的 P/E 核心和线程数连接为 `"8P+4E+16T"` 风格标签。 |
| `build` | 方法（组件，`_CpuPresetPickerState`） | B | 渲染可拖拽面板：搜索字段加 `_filtered` 预设列表。 |
| `_GpuPresetPicker`（构造函数） | 构造函数 | B | 为底部面板组件存储 `presets` 列表。 |
| `createState` | 方法（`_GpuPresetPicker`） | B | 创建 `_GpuPresetPickerState`。 |
| [`_filtered`](#_filtered-gpu)（GPU） | getter（`_GpuPresetPickerState`） | A | 过滤 `widget.presets` 到 model/architecture 含当前搜索查询的条目。 |
| `build` | 方法（组件，`_GpuPresetPickerState`） | B | 渲染可拖拽面板：搜索字段加 `_filtered` 预设列表。 |

行数说明：对此文件 `grep -c 'Purpose:'` 返回 55，与上面 55 行精确匹配——本文件每个声明（含每个字段映射标签辅助）都带仓库标准 `/// Purpose:` 文档注释块。

锚点碰撞说明：`_filtered` 声明两次（`_CpuPresetPickerState` 一次、`_GpuPresetPickerState` 一次，都 Tier A）。按裸名锚点规则这些会碰撞，因此本页用 `_filtered-cpu` / `_filtered-gpu` 消歧而非通常裸名锚点——用上面表格的链接，别凭名猜锚点。

## 文档

### `void initState()` <a id="initstate"></a>
- **种类：** `_DeviceEditPageState` 的方法（组件生命周期）
- **来源：** `lib/features/devices/views/device_edit_page.dart`（第 129 行）
- **用途：** 从 `widget.device`（新设备用默认）初始化每个文本控制器和可编辑字段，含重建逐槽存储编辑器行，然后启动异步预设/财务设置加载。
- **输入：** 无（读取 `widget.device`；`widget.searchResult` 稍后在 `_loadPresets` 内消费）。
- **返回：** 无。
- **副作用：** 创建约二十四个 `TextEditingController`（加每个既有存储槽一对）；设置约 20 个普通状态字段；调用 `_loadPresets()` 和 `_loadFinancialSettings()`（各做异步 IO 并稍后调用 `setState`）。
- **算法：**
  1. 捕获 `d = widget.device`（添加新设备时 `null`）。
  2. 对每个简单文本字段（名、品牌、型号、序列号、屏幕尺寸、电池、操作系统、位置、备注）创建用 `d?.field ?? ''` 播种的控制器。
  3. RAM：经 [`_parseValueUnit`](#_parsevalueunit) 把 `d?.ram` 解析为 `(value, unit)` 对；从中播种 `_ramCtrl`/`_ramUnit`；复制 `d?.ramType`。
  4. 购买/出售价格：用 `.amount.toString()` 播种金额控制器；只在价格存在**且**其 `currency != defaultCurrency` 时播种*汇率*控制器（否则留空）——[`_parseRate`](#_parserate) 保存时再次强制相同规则。
  5. CPU/GPU：从 `d?.cpu`/`d?.gpu` 字段播种每个控制器（数字字段经 `.toString()`）。
  6. 屏幕分辨率宽/高同样播种。
  7. 复制 `category`（默认 `DeviceCategory.phone`）和生命周期/财务字段：购买/发布/退役日期、获取类型、退役/出售标志、购买/出售货币和自动汇率标志。
  8. 经 [`_RecurringCostDraft.fromCost`](#_recurringcostdraft-fromcost) 把 `d?.recurringCosts` 转换为草稿。
  9. 存储：`d != null && d.storage.isNotEmpty` 时循环 `i` 对 `d.storage`，用 `_parseValueUnit` 解析每个槽 `capacity` 并填充五个平行列表，加 `_storageOriginalIndices.add(i)`——记录槽的原始索引供稍后重映射。否则播种带 `_storageOriginalIndices = [null]` 的单个空行。
  10. 调用 `_loadPresets()` 然后 `_loadFinancialSettings()`（即发即忘异步，不 await）。
- **用法：** `DeviceEditPage` 首次构建时由 Flutter 框架自动调用；代码库任何地方不直接调用。
- **备注：** `_storageOriginalIndices` 是让保存时存储槽重映射可能的字段——见 [`_save`](#_save) 和 [数据集 — remapDeviceStorageLinks()](../../../../features/datasets.md#remapdevicestoragelinks)。会话中稍后添加的行这里得 `null`，使它们绝不被误当作既有槽。

### `Future<void> _loadFinancialSettings()` <a id="_loadfinancialsettings"></a>
- **种类：** `_DeviceEditPageState` 的方法
- **来源：** `lib/features/devices/views/device_edit_page.dart`（第 252 行）
- **用途：** 加载应用级默认货币和自动更新汇率偏好，并为尚未从旧默认定制走的购买/出售价格字段采用新默认货币。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 两个 await `DeviceExchangeRateService` 调用（`getDefaultCurrency`、`getAutoUpdateEnabled`）；一次 `setState`。
- **算法：**
  1. Await `DeviceExchangeRateService.getDefaultCurrency()` 和 `getAutoUpdateEnabled()`。
  2. 组件不再挂载时提前返回。
  3. 在 `setState` 中：覆盖前捕获旧 `_defaultCurrency`，然后覆盖它和 `_autoUpdateRates`。
  4. 这是新设备（`widget.device?.purchasePrice == null`）且 `_purchaseCurrency` 仍等于*旧*默认时把 `_purchaseCurrency` 更新为新默认（`_soldCurrency`/`soldPrice` 相同检查）。既有设备已设货币即使碰巧等于旧默认也保持不动。
- **用法：** 从 `initState` 调用一次（第 244 行）；别处不调用。
- **备注：** 独立于 `_loadPresets()` 运行——两者都是 `initState` 的即发即忘，各在调用 `setState` 前自己检查 `mounted`。

### `Future<void> _loadPresets()` <a id="_loadpresets"></a>
- **种类：** `_DeviceEditPageState` 的方法
- **来源：** `lib/features/devices/views/device_edit_page.dart`（第 276 行）
- **用途：** 加载捆绑 CPU/GPU/品牌预设列表，然后——对从在线搜索结果创建设备——预设可用后把该结果应用到表单。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 三个 await `PresetService` 加载；一次 `setState`；可能调用 `_applySearchResult`（它自己再调 `setState`）。
- **算法：**
  1. Await `PresetService.loadCpus()`、`loadGpus()`、`loadBrands()`。
  2. 挂载时 `setState` `_cpuPresets`/`_gpuPresets`/`_brandPresets`。
  3. `widget.searchResult != null`（页面经设备列表搜索流程的 `DeviceEditPage(searchResult: result)` 打开，见 `device_list_page.dart`）时调用 `_applySearchResult(widget.searchResult!)`，使 CPU/GPU 对现已加载预设的模糊匹配能运行。
- **用法：** 从 `initState` 调用一次（第 243 行）。
- **备注：** 搜索结果应用*在*预设 `setState` 之后排序（而非从 `initState` 独立触发），正为让 `_applySearchResult` 中的 CPU/GPU 预设匹配有数据可匹配。

### `static (String, String) _parseValueUnit(String? value)` <a id="_parsevalueunit"></a>
- **种类：** `_DeviceEditPageState` 的静态方法
- **来源：** `lib/features/devices/views/device_edit_page.dart`（第 345 行）
- **用途：** 把 `"16 GB"` 或 `"512 GB NVMe SSD"` 之类自由文本容量/尺寸字符串解析为编辑器单独金额+单位字段的 `(value, unit)` 对。
- **输入：** `value` — 原始字符串（如 `Device.ram` 或 `StorageInfo.capacity`），可空。
- **返回：** `(String, String)` 记录 — 如 `('16', 'GB')`；`value` 为 null/空白时 `('', 'GB')`；无识别单位时 `(trimmed, 'GB')`。
- **副作用：** 无。
- **算法：**
  1. null/空白输入立即返回 `('', 'GB')`。
  2. 对照 `^(\d+(?:\.\d+)?)\s*(MB|GB|TB)\b`（不区分大小写）匹配修剪字符串。
  3. 匹配时返回数字组和大写单位组。
  4. 不匹配时把整个修剪字符串作为值、单位默认 `'GB'` 返回（使不可解析遗留文本不丢失，只是归错单位）。
- **用法：**
  ```dart
  final ramParsed = _parseValueUnit(d?.ram);
  _ramCtrl = TextEditingController(text: ramParsed.$1);
  _ramUnit = ramParsed.$2;
  ```
  （`initState`，第 138 行）；也 `initState` 每个存储槽（第 222 行）和 `_applySearchResult` 内 RAM/存储字段（第 888、895 行）使用。
- **备注：** 只识别 `MB`/`GB`/`TB`——匹配 `_memoryUnits`（第 336 行）；调用方对返回值用 Dart 位置记录 `.$1`/`.$2` 访问器。

### `double? _parseMoney(String value)` <a id="_parsemoney"></a>
- **种类：** `_DeviceEditPageState` 的方法
- **来源：** `lib/features/devices/views/device_edit_page.dart`（第 388 行）
- **用途：** 把用户输入金额字段解析为 `double`，容忍千位分隔符逗号。
- **输入：** `value` — 价格/金额 `TextEditingController` 的原始文本。
- **返回：** `double?` — 空白或不可解析时 `null`。
- **副作用：** 无。
- **算法：** 修剪字符串并剥离每个 `,` 字符，然后空结果返回 `null` 否则对清洗字符串 `double.tryParse`。
- **用法：**
  `purchasePrice = await DeviceExchangeRateService.convertOptional(amount: _parseMoney(_purchasePriceCtrl.text), ...)`（`_save`，第 500 行）；也用于出售价格和每个循环成本金额（第 521 行）。
- **备注：** 逗号剥离意味着 `"1,234.56"` 解析为 `1234.56`；无其他分组/小数约定处理（如 `.` 作千位分隔符）。

### `double? _parseRate(TextEditingController controller, String currency)` <a id="_parserate"></a>
- **种类：** `_DeviceEditPageState` 的方法
- **来源：** `lib/features/devices/views/device_edit_page.dart`（第 399 行）
- **用途：** 解析货币字段的手动汇率覆盖，但只在那个货币实际不同于设备默认货币时。
- **输入：** `controller` — 汇率 `TextEditingController`；`currency` — 配对金额字段当前使用的货币代码。
- **返回：** `double?` — `currency == _defaultCurrency`（无需转换，因此任何遗留汇率文本被忽略）或字段不可解析时 `null`；否则解析汇率。
- **副作用：** 无。
- **算法：** `currency == _defaultCurrency` 时立即返回 `null`；否则委托 [`_parseMoney`](#_parsemoney)`(controller.text)`。
- **用法：** `manualRate: _purchaseAutoRate ? null : _parseRate(_purchaseRateCtrl, _purchaseCurrency)`（`_save`，第 506 行）；出售价格和每个循环成本相同模式。
- **备注：** 调用方调用前已对 `autoRate` 门控（自动汇率开启时直接传 `null`），因此 `_parseRate` 只需处理"与默认货币相同" case——两个守卫互补，非冗余。

### `Future<void> _save()` <a id="_save"></a>
- **种类：** `_DeviceEditPageState` 的方法
- **来源：** `lib/features/devices/views/device_edit_page.dart`（第 456 行）
- **用途：** 验证表单、从所有编辑器状态组装 `Device`（重算存储槽索引并转换货币字段）、持久化它，并重映射受存储槽变化影响的任何数据集存储链接。
- **输入：** 无（读取整个组件状态）。
- **返回：** `Future<void>`。
- **副作用：** 可能显示 `SnackBar`（货币转换失败）；调用 `DeviceStorage.addOrUpdate`；编辑既有设备时调用 `DataSetStorage.remapDeviceStorageLinks`；调用 `AutoSyncService.instance.notifySaved()`；弹出页面。
- **算法：**
  1. `_formKey.currentState!.validate()` 失败时立即返回。
  2. 循环 `_storageEntries` 构建 `storageList`（`List<StorageInfo>`）和 `storageIndexMap`（`Map<int,int>`，旧槽索引 → 新槽索引）。行只在有非空容量值、存储类型、接口、品牌或序列号之一时幸存——全空白行完全丢弃。对每个 `_storageOriginalIndices[i]` 非 null 的保留行，追加前记录 `storageIndexMap[originalIndex] = storageList.length`（行*新*位置）——正是 [`DataSetStorage.remapDeviceStorageLinks`](../../../../features/datasets.md#remapdevicestoragelinks) 期望的 `indexMap` 形态。无原始索引的行（本会话添加）贡献 `storageList` 但不贡献 `storageIndexMap`。每个保留行的 `extraJson` 在该原始槽仍存在时从 `widget.device!.storage[originalIndex]` 带过，否则 `{}`。
  3. 在 `try`/`on ExchangeRateException` 内：await 购买价格和出售价格的 `DeviceExchangeRateService.convertOptional`，和每个带可解析金额的 `_recurringCostDrafts` 条目 `.convert`（无可解析金额的草稿跳过——从保存设备丢弃）。`ExchangeRateException` 时显示本地化 snackbar（`exchangeRateManualRequired` 或 `exchangeRateUnavailable`，按 `e.message` 选）并在不保存任何东西下返回。
  4. 计算 `isSold = _isSold`；`isRetired = _isRetired || isSold`（出售总是蕴含退役，镜像 [设备 — 生命周期与财务跟踪](../../../../features/devices.md#lifecycle-and-finance-tracking) 的 `lifecycleStatus` 优先级）。
  5. 构造新 `Device(...)`，复用 `widget.device?.id`（编辑保持相同 id；添加时省略让构造函数生成新鲜 UUID）、新构建 `storageList` 和从每个对应原始嵌套对象（`cpu`、`gpu`、设备本身）复制的 `extraJson` 或新设备 `{}`。
  6. Await `DeviceStorage.addOrUpdate(device)`。
  7. 编辑既有设备（`widget.device != null`）时 await `DataSetStorage.remapDeviceStorageLinks(deviceId: ..., oldSlotCount: widget.device!.storage.length, indexMap: storageIndexMap)`——槽被移除/压实后保持 `DataSet` 存储链接有效的集成点（见 [数据集 — remapDeviceStorageLinks()](../../../../features/datasets.md#remapdevicestoragelinks)；其恒等映射短路使无槽实际移动时这是空操作）。
  8. 调用 `AutoSyncService.instance.notifySaved()`（见 [WebDAV 同步](../../../../sync.md)）并仍挂载时经 `Navigator.of(context).pop()` 弹出页面。
- **用法：** `TextButton(onPressed: _save, child: Text(l10n.save))`（`build`，第 1513 行）。
- **备注：** 全新设备（`widget.device == null`）绝不调用 `remapDeviceStorageLinks`——尚无要重映射的东西。金额空/不可解析的循环成本草稿静默丢弃而非以零金额保存。

### `Future<void> _showSearchDialog()` <a id="_showsearchdialog"></a>
- **种类：** `_DeviceEditPageState` 的方法
- **来源：** `lib/features/devices/views/device_edit_page.dart`（第 810 行）
- **用途：** 打开带表单当前字段值播种的在线设备搜索对话框，并应用用户选择从结果导入的任何字段。
- **输入：** 无（读取当前控制器/状态值）。
- **返回：** `Future<void>`。
- **副作用：** Await `showDeviceSearchDialog`（对话框内网络搜索加可选图像下载，见 [device_search_dialog.md](device_search_dialog.md)）；非 null 结果时调用 `_applySearchResult`。
- **算法：**
  1. 构建对话框初始查询：设了型号时 `"$brand $model"`，否则回退设备名。
  2. 用那个查询加每个其他"当前值"（品牌、型号、芯片组、GPU、组合 RAM、*第一*存储槽组合容量、屏幕尺寸/分辨率、电池、操作系统、发布日期、图像路径）调用 `showDeviceSearchDialog`，使对话框能逐字段显示当前-vs-获取比较。
  3. 对话框被关闭（`result == null`）或期间组件卸载时提前返回。
  4. 否则调用 `_applySearchResult(result)`。
- **用法：** `IconButton(icon: const Icon(Icons.travel_explore), onPressed: _showSearchDialog)`，只在 `if (AppFlavor.isFull)` 时显示（`build`，第 1507–1512 行；商店构建门控见 [在线搜索与预设](../../../../features/online-search-and-presets.md)）。
- **备注：** 只有*第一*存储槽容量被提供为搜索对话框的"当前"上下文——额外槽不体现在查询/当前值负载中。

### `void _applySearchResult(Map<String, dynamic> result)` <a id="_applysearchresult"></a>
- **种类：** `_DeviceEditPageState` 的方法
- **来源：** `lib/features/devices/views/device_edit_page.dart`（第 845 行）
- **用途：** 把在线搜索对话框返回（或经 `DeviceEditPage(searchResult: ...)` 带入）的字段映射应用到编辑表单，可能时把 CPU/GPU 文本与加载预设模糊匹配。
- **输入：** `result` — 按字段名键控的松散类型映射（`brand`、`model`、`chipset`、`gpuName`、`ram`、`storage`、`screenSize`、`screenResolutionW`/`H`、`battery`、`os`、`releaseDate`、`image`）；每个键可选且使用前类型检查。
- **返回：** 无。
- **副作用：** 覆盖所有字段更新的一个 `setState`。
- **算法**（全部在一个 `setState` 内）：
  1. `brand`/`model`：作为 `String` 存在时直接复制进控制器。
  2. `chipset`：小写并对照每个加载 `_cpuPresets` 条目的小写 `model` 用**互包子串包含**（`chipsetLower.contains(presetLower) || presetLower.contains(chipsetLower)`）比较；第一个匹配经 `_applyCpuPreset` 应用。无预设匹配时把原始芯片组字符串直接写进 `_cpuModelCtrl` 并 bump `_cpuAutoKey`（强制 `Autocomplete` 组件重建，因为只设 `.text` 不刷新它——见 `build` 的 `ValueKey('cpu_auto_$_cpuAutoKey')`，第 1705 行）。
  3. `gpuName`：对 `_gpuPresets` 相同互包子串匹配，相同原始文本回退。
  4. `ram`：经 `_parseValueUnit` 解析进 `_ramCtrl`/`_ramUnit`。
  5. `storage`：经 `_parseValueUnit` 解析并只写入槽 **0**（`_storageEntries[0]`/`_storageUnits[0]`），若存在任何存储行。
  6. `screenSize`、`battery`、`os`：直接复制进控制器。
  7. `screenResolutionW`/`screenResolutionH`：经 `.toString()` 复制（作为 `int`）。
  8. `releaseDate`：是 `DateTime` 时直接复制进 `_releaseDate`。
  9. `image`：存在时设 `_imagePath` 并清除 `_emoji`（导入照片总是胜过任何先前选 emoji）。
- **用法：** 页面带搜索结果打开时 `_loadPresets` 的 `_applySearchResult(widget.searchResult!)`（第 287 行）；就地对话框搜索后 `_showSearchDialog` 的 `_applySearchResult(result)`（第 837 行）。
- **备注：** CPU/GPU 匹配刻意宽松（互包子串，非精确），使如结果的 `"Apple A17 Pro"` 能匹配更短预设名或反之；因为基于子串，含糊/短型号字符串可能匹配错误预设——与 `_detectLogoForModel` 和 `device_detail_page.dart` 品牌/型号 logo 检测器相同的权衡。

### `String? _detectLogoForModel(String model)` <a id="_detectlogoformodel"></a>
- **种类：** `_DeviceEditPageState` 的方法
- **来源：** `lib/features/devices/views/device_edit_page.dart`（第 947 行）
- **用途：** 为输入中的 CPU/GPU 型号字符串找到 SVG logo 资产路径，用小本地品牌表加 Mali 特定 ARM 映射。
- **输入：** `model` — `_cpuModelCtrl`/`_gpuModelCtrl` 的活文本。
- **返回：** `String?` — `assets/logos/*.svg` 路径，或 `null`。
- **副作用：** 无。
- **算法：** 小写 `model`；按声明顺序迭代本文件自己的 `_brandLogoMap`（11 条目 `const` 映射：nvidia、amd、intel、apple、qualcomm、mediatek、samsung、broadcom、mali→arm.svg、google、razer）并返回小写型号*以*其*开始*的第一个条目；无匹配返回 `null`。
- **用法：** `_brandLogoWidget(_detectLogoForModel(_cpuModelCtrl.text))` 和 `_brandLogoWidget(_detectLogoForModel(_gpuModelCtrl.text))`，每次 `build` 调用在 CPU/GPU 小节页头旁实时重建（第 1681、1783 行）。
- **备注：** 本文件 `_brandLogoMap` 是比 `device_detail_page.dart` 的 `_brandLogoMap`/`_detectModelLogo`（约 39 条目、那里 `contains` 基础对比这里 `startsWith`）更小、独立的表——两者不共享且可能彼此漂移失同步。

### `Future<void> _pickImage()` <a id="_pickimage"></a>
- **种类：** `_DeviceEditPageState` 的方法
- **来源：** `lib/features/devices/views/device_edit_page.dart`（第 1068 行）
- **用途：** 让用户从设备图库/文件系统挑照片并采用为设备图标。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `ImageService.pickAndSaveImage()`（文件选择器加把所选图像复制进应用存储）；成功时 `setState` `_imagePath` 并清除 `_emoji`。
- **算法：** Await `ImageService.pickAndSaveImage()`；返回非 null 本地路径时 `setState` `_imagePath = path` 和 `_emoji = null`（图像总是替换任何 emoji，匹配 `_applySearchResult` 的 `image` 处理和 `_showEmojiPicker`/`_removeIcon` 的反向）。
- **用法：** `_buildIconSection` 中的 `IconButton(..., onPressed: _pickImage)`（第 1123 行）。
- **备注：** 用户取消选择器（`path == null`）时无变化——两种方式都不浮出错误。

### `factory _RecurringCostDraft.fromCost(DeviceRecurringCost cost)` <a id="_recurringcostdraft-fromcost"></a>
- **种类：** `_RecurringCostDraft` 的工厂构造函数
- **来源：** `lib/features/devices/views/device_edit_page.dart`（第 2221 行）
- **用途：** 把持久化 `DeviceRecurringCost` 转换为循环成本小节的可编辑草稿（带自己文本控制器）。
- **输入：** `cost` — `widget.device.recurringCosts` 的既有 `DeviceRecurringCost`。
- **返回：** 从 `cost` 播种的新 `_RecurringCostDraft` 实例。
- **副作用：** 创建 3 个 `TextEditingController`。
- **算法：** 直接复制 `kind`、`billingCycle`、`price.currency`、`price.autoRate`、`name` 和 `price.amount.toString()`。对汇率字段，只在 `price.currency != price.defaultCurrency` 时用 `price.exchangeRate.toString()` 播种，否则留空——`initState` 应用到购买/出售汇率字段的相同"只在货币不同于默认时显示手动汇率"规则。在 `existing` 中保留对原始 `cost` 的引用（[`_save`](#_save) 用它保留记录 `id` 和 `extraJson`）。
- **用法：** `_recurringCostDrafts.addAll(d?.recurringCosts.map(_RecurringCostDraft.fromCost) ?? const [])`（`initState`，第 210 行）。
- **备注：** `existing` 正是让 `_save` 区分编辑的既有循环成本（保留其 `id`/`extraJson`）与经 `_addRecurringCost` 添加的全新（`existing == null`，得新鲜 `id`）的东西。

### `List<CpuInfo> get _filtered`（`_CpuPresetPickerState` 中） <a id="_filtered-cpu"></a>
- **种类：** `_CpuPresetPickerState` 的 getter
- **来源：** `lib/features/devices/views/device_edit_page.dart`（第 2275 行）
- **用途：** 把底部面板预设列表过滤到 model 或 architecture 文本含当前搜索查询的条目。
- **输入：** 无（读取 `_query`、`widget.presets`）。
- **返回：** `List<CpuInfo>` — `_query` 为空时所有预设，否则过滤子集。
- **副作用：** 无。
- **算法：** `_query` 为空时返回未过滤 `widget.presets`；否则小写查询并只保留小写 `model` 或 `architecture` 含它的预设（`model`/`architecture` 为 null 的预设检查时当作空字符串）。
- **用法：** `build` 顶部 `final items = _filtered;`（第 2305 行），既用于条目数也作为 `ListView.builder` 项。
- **备注：** 匹配只子串/不区分大小写，无模糊或多 token 匹配——两词查询不会匹配以不同顺序含两词的 model。

### `List<GpuInfo> get _filtered`（`_GpuPresetPickerState` 中） <a id="_filtered-gpu"></a>
- **种类：** `_GpuPresetPickerState` 的 getter
- **来源：** `lib/features/devices/views/device_edit_page.dart`（第 2384 行）
- **用途：** 把底部面板预设列表过滤到 model 或 architecture 文本含当前搜索查询的条目。
- **输入：** 无（读取 `_query`、`widget.presets`）。
- **返回：** `List<GpuInfo>` — `_query` 为空时所有预设，否则过滤子集。
- **副作用：** 无。
- **算法：** 与 [`_CpuPresetPickerState._filtered`](#_filtered-cpu) 相同，对 `GpuInfo`/`widget.presets` 而非 `CpuInfo`。
- **用法：** `build` 顶部 `final items = _filtered;`（第 2401 行）。
- **备注：** 与 CPU 选择器 `_filtered` 相同的子串/仅不区分大小写注意。
