# lib/features/devices/views/device_list_page.dart

设备清单首页（见 [设备](../../../../features/devices.md)）。拥有设备列表的加载/排序/过滤/分组状态、链接到 `device_finance_overview_page.dart` 的财务摘要页头卡片、由 `lib/features/devices/services/device_storage.dart` 支撑的增/改/删/重排流程，和"从模板添加"底部面板（`_TemplatePicker`，用 `lib/features/devices/services/preset_service.dart`）。它注册到 `AutoSyncService`（`lib/shared/services/auto_sync_service.dart`），使后台同步带入新本地数据时列表自我刷新。在线搜索 FAB（`_addFromSearch`，接到 `chip_search_dialog`/`device_search_dialog` 的姊妹 `showDeviceSearchDialog`）门控在 `AppFlavor.isFull` 后——此满足的商店风格门控要求见 [在线搜索与预设](../../../../features/online-search-and-presets.md)（4 个调用点中的第 4 个）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `DeviceListPage`（构造函数） | 构造函数 | B | 创建页面组件（无参数）。 |
| `createState` | 方法（`DeviceListPage`） | B | 创建页面可变状态对象。 |
| [`initState`](#initstate) | 方法（组件生命周期） | A | 注册自动同步监听器并启动偏好/设备加载。 |
| `dispose` | 方法（组件生命周期） | B | 注销自动同步监听器。 |
| `_handleLocalDataChanged` | 方法（`_DeviceListPageState`） | B | 响应自动同步通知重载设备。 |
| [`_loadSortPrefs`](#_loadsortprefs) | 方法（`_DeviceListPageState`） | A | 从设备存储配置加载持久化排序模式/分组/方向。 |
| [`_loadFinancialPrefs`](#_loadfinancialprefs) | 方法（`_DeviceListPageState`） | A | 加载财务显示的持久化默认货币。 |
| [`_saveSortPrefs`](#_savesortprefs) | 方法（`_DeviceListPageState`） | A | 把当前排序模式/分组/方向持久化到设备存储配置。 |
| [`_visibleDevices`](#_visibledevices) | getter（`_DeviceListPageState`） | A | 按活动 `DeviceStatusFilter` 过滤 `_devices`。 |
| [`_sortedDevices`](#_sorteddevices) | getter（`_DeviceListPageState`） | A | 按当前排序设置排序并可选择分组可见设备。 |
| [`_loadDevices`](#_loaddevices) | 方法（`_DeviceListPageState`） | A | 从存储重载设备列表并刷新状态。 |
| `_addDevice` | 方法（`_DeviceListPageState`） | B | 压入空白设备编辑页，然后重载。 |
| `_addFromSearch` | 方法（`_DeviceListPageState`） | B | 运行在线设备搜索对话框，然后打开带其结果预填的编辑页。 |
| `_editDevice` | 方法（`_DeviceListPageState`） | B | 为既有设备压入设备编辑页，然后重载。 |
| `_viewDevice` | 方法（`_DeviceListPageState`） | B | 压入设备详情页，然后重载。 |
| `_viewFinancialOverview` | 方法（`_DeviceListPageState`） | B | 压入财务总览页，然后重载。 |
| [`_confirmDeleteDevice`](#_confirmdeletedevice) | 方法（`_DeviceListPageState`） | A | 确认并接受时删除设备并通知同步层。 |
| [`_addFromTemplate`](#_addfromtemplate) | 方法（`_DeviceListPageState`） | A | 挑捆绑设备模板、物化为 `Device` 并打开它供编辑。 |
| `_categoryLabel` | 方法（`_DeviceListPageState`） | B | 把 `DeviceCategory` 映射到其本地化标签。 |
| `_sortModeLabel` | 方法（`_DeviceListPageState`） | B | 把 `SortMode` 映射到其本地化标签。 |
| `_filterLabel` | 方法（`_DeviceListPageState`） | B | 把 `DeviceStatusFilter` 映射到其本地化标签。 |
| [`_statusCount`](#_statuscount) | 方法（`_DeviceListPageState`） | A | 统计给定生命周期状态的设备。 |
| [`_totalFinancialCost`](#_totalfinancialcost-list) | 方法（`_DeviceListPageState`） | A | 跨所有设备求和 `totalCost()`。 |
| [`_totalDailyCost`](#_totaldailycost-list) | 方法（`_DeviceListPageState`） | A | 跨所有设备求和当前 `averageDailyCost()`。 |
| [`_moneyText`](#_moneytext-list) | 方法（`_DeviceListPageState`） | A | 用页面默认货币符号格式化金额。 |
| `_setSortMode` | 方法（`_DeviceListPageState`） | B | 设排序模式并持久化。 |
| `_toggleGroupByCategory` | 方法（`_DeviceListPageState`） | B | 切换类别分组并持久化。 |
| `_toggleSortOrder` | 方法（`_DeviceListPageState`） | B | 切换升/降序并持久化。 |
| [`_onReorder`](#_onreorder) | 方法（`_DeviceListPageState`） | A | 在自定义顺序内移动设备并持久化新顺序。 |
| `build` | 方法（组件） | B | 构建脚手架：应用栏、列数控件（`listColumnsButton`，容量为 1 及重排时隐藏）、排序/分组菜单、设备列表或重排视图、FAB。以 `shellContentWidth(screen.width) − 32` 和 `deviceTileMinWidth` 经 `listColumnCount` 计算列数。 |
| `_setColumnsPref` | 方法（`_DeviceListPageState`） | B | 存储新的列数偏好（`DeviceStorage.setDeviceListColumns`）并重新渲染。 |
| `_buildTile` | 方法（组件辅助） | B | 一个设备 tile：一列时是带滑动 `Dismissible` 的卡片，否则是带尾部编辑/删除 `PopupMenuButton` 的 `_DeviceCard`。 |
| `_tileRows` | 方法（组件辅助） | B | 把一段设备排成列表 children：一列时就是 tile，否则是带内边距的 `adaptiveTileRows`。 |
| `_buildDeviceList` | 方法（组件辅助） | B | 构建可滚动设备列表——多列时 `ListView.builder` 每个索引一个 `adaptiveTileRow`——分组开启时插入类别页头（每个页头后跟自己的行）。 |
| `_buildHomeHeader` | 方法（组件辅助） | B | 构建财务摘要卡片和状态过滤分段控件。 |
| `_buildMetric` | 方法（组件辅助） | B | 渲染一个标签/值指标列。 |
| `_buildStatusCount` | 方法（组件辅助） | B | 渲染一个带进度条的生命周期状态计数。 |
| `_buildDismissibleCard` | 方法（组件辅助） | B | 把设备卡片包进带滑动编辑/滑动删除的 `Dismissible`。 |
| `_DeviceCard`（构造函数） | 构造函数 | B | 存储设备、类别标签、货币、点击处理器和可选尾部组件。 |
| `_DeviceCard.build` | 方法（组件） | B | 渲染一个设备列表块（头像、名、类别/品牌/每日成本副标题）。 |
| `_TemplateChoice`（构造函数） | 构造函数 | B | 把选中的模板与为其选定的容量配对。 |
| `_TemplatePicker`（构造函数） | 构造函数 | B | 为选择器面板存储捆绑模板列表。 |
| `_TemplatePicker.createState` | 方法（`_TemplatePicker`） | B | 创建选择器可变状态对象。 |
| [`_filtered`](#_filtered) | getter（`_TemplatePickerState`） | A | 按当前搜索查询过滤模板。 |
| [`_choose`](#_choose) | 方法（`_TemplatePickerState`） | A | 确定选中模板应使用哪一个存储容量。 |
| `_TemplatePickerState.build` | 方法（组件） | B | 渲染可拖拽模板选择器面板（搜索字段 + 过滤列表）。 |

## 文档

### `void initState()` <a id="initstate"></a>
- **种类：** `_DeviceListPageState` 的方法（组件生命周期覆盖）
- **来源：** `lib/features/devices/views/device_list_page.dart`（第 54 行）
- **用途：** 把本页接入自动同步通知系统并启动初始偏好/设备加载。
- **输入：** 无。
- **返回：** `None`。
- **副作用：** 把 `_handleLocalDataChanged` 注册到 `AutoSyncService.instance.addOnLocalDataChanged`；启动两个独立异步加载链。
- **算法：**
  1. 调用 `super.initState()`。
  2. 把 `_handleLocalDataChanged` 注册为 `AutoSyncService` 本地数据变更监听器，使后台同步拉入新数据时设备列表自动自我重载。
  3. 调用 `_loadFinancialPrefs()`（即发即忘——不 await）。
  4. 链 `_loadSortPrefs().then((_) => _loadDevices())`——先加载排序/分组/方向偏好，然后用已加载偏好加载并排序/分组设备（避免列表首次渲染后可见重新排序闪烁）。
- **用法：** `_DeviceListPageState` 首次插入树时由 Flutter 框架自动调用；无直接调用点。
- **备注：** 对应 `dispose()`（第 67 行）调用 `AutoSyncService.instance.removeOnLocalDataChanged(_handleLocalDataChanged)` 避免页面释放后泄漏监听器。

### `Future<void> _loadSortPrefs()` <a id="_loadsortprefs"></a>
- **种类：** `_DeviceListPageState` 的方法
- **来源：** `lib/features/devices/views/device_list_page.dart`（第 86 行）
- **用途：** 从设备存储配置加载持久化排序模式、类别分组标志和排序方向，回退合理默认。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 经 `DeviceStorage.readConfig()` 读取配置；调用 `setState`。
- **算法：**
  1. 读取配置映射。
  2. 把存储 `'sortMode'` 字符串对照 `SortMode.values` 按 `.name` 匹配解析 `_sortMode`，存储值缺失或无法识别回退 `SortMode.custom`（`firstOrNull ?? SortMode.custom`）。
  3. 直接把 `_groupByCategory`（默认 `false`）和 `_sortAscending`（默认 `false`）作为布尔解析。
  4. 经单个 `setState` 应用三者。
- **用法：** [`initState`](#initstate) 构造后链接：`_loadSortPrefs().then((_) => _loadDevices());`。
- **备注：** 无。

### `Future<void> _loadFinancialPrefs()` <a id="_loadfinancialprefs"></a>
- **种类：** `_DeviceListPageState` 的方法
- **来源：** `lib/features/devices/views/device_list_page.dart`（第 105 行）
- **用途：** 加载用户配置的默认货币，使本页财务数字正确格式化。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `DeviceExchangeRateService.getDefaultCurrency()`；仍挂载时 `setState`。
- **算法：** Await 服务调用，然后组件仍挂载时设 `_defaultCurrency`（若页面在此解析前被弹出，防释放后 `setState`）。
- **用法：** 从 [`initState`](#initstate) 调用一次，即发即忘。
- **备注：** 无。

### `Future<void> _saveSortPrefs()` <a id="_savesortprefs"></a>
- **种类：** `_DeviceListPageState` 的方法
- **来源：** `lib/features/devices/views/device_list_page.dart`（第 115 行）
- **用途：** 把当前排序模式、分组标志和排序方向持久化回设备存储配置。
- **输入：** 无（读取 `_sortMode`、`_groupByCategory`、`_sortAscending`）。
- **返回：** `Future<void>`。
- **副作用：** 经 `DeviceStorage.readConfig()`/`writeConfig()` 读取然后写配置。
- **算法：** 读取既有配置映射、覆盖三个排序相关键（`'sortMode'` 作为枚举 `.name`、`'groupByCategory'`、`'sortAscending'`）并写回整个映射——保留配置中任何其他键。
- **用法：** 从 [`_setSortMode`](#)、`_toggleGroupByCategory` 和 `_toggleSortOrder` 在各修改其状态字段后调用。
- **备注：** 无。

### `List<Device> get _visibleDevices` <a id="_visibledevices"></a>
- **种类：** `_DeviceListPageState` 的 getter
- **来源：** `lib/features/devices/views/device_list_page.dart`（第 128 行）
- **用途：** 对完整设备列表应用活动 `DeviceStatusFilter`。
- **输入：** 无（读取 `_devices`、`_statusFilter`）。
- **返回：** `List<Device>` — 匹配过滤器的子集。
- **副作用：** 无。
- **算法：** 用对 `_statusFilter` 的 `switch` 过滤 `_devices`：`all` 保留一切；`inService` 保留 `device.isInService`；`retired`/`sold` 保留 `lifecycleStatus` 等于对应 `DeviceLifecycleStatus` 的设备（`lifecycleStatus` 如何派生见 [设备 — 生命周期与财务跟踪](../../../../features/devices.md#lifecycle-and-finance-tracking)）。
- **用法：** [`_sortedDevices`](#_sorteddevices) 顶部读取：`var list = List<Device>.of(_visibleDevices);`。
- **备注：** 无。

### `List<Device> get _sortedDevices` <a id="_sorteddevices"></a>
- **种类：** `_DeviceListPageState` 的 getter
- **来源：** `lib/features/devices/views/device_list_page.dart`（第 147 行）
- **用途：** 产生最终显示列表：按活动 `SortMode` 和方向排序的 `_visibleDevices`，可选按类别分组。
- **输入：** 无（读取 `_visibleDevices`、`_sortMode`、`_sortAscending`、`_groupByCategory`、`_devices`）。
- **返回：** `List<Device>`。
- **副作用：** 无（不修改 `_devices`；排序副本）。
- **算法：**
  1. 把 `_visibleDevices` 复制进 `list`。
  2. `_sortMode == SortMode.custom` 时：此模式意为"存储中的任何顺序"——不应用比较器。`_groupByCategory` 开启时列表仍按 `category.index` 排序，但平局按每个设备在 `_devices` 中的原始索引打破（即 `_devices.indexOf(a).compareTo(_devices.indexOf(b))`），保留每类别*内*自定义顺序。立即返回。
  3. 否则构建 `comparator`：`alphabetical` 比较小写名；`releaseDate`/`purchaseDate` 比较相应日期降序（最新在前），null 无论方向总是排最后（`a.releaseDate == null` → 返回 `1`，即 `a` 排在 `b` 后）。
  4. 包装比较器尊重 `_sortAscending`：升序时交换参数顺序（`comparator(b, a)`）反转（自然降序）比较器。
  5. `_groupByCategory` 开启时先按 `category.index` 排序，每类别内回退 `effectiveComparator`；否则直接按 `effectiveComparator` 排序整个列表。
- **用法：** `_buildDeviceList` 中的 `final sorted = _sortedDevices;`（`lib/features/devices/views/device_list_page.dart`，第 638 行）。
- **备注：** 日期比较器 null 处理方向不变——null 总是最后，升序降序都是，因为升序包装只是交换比较器两参数而非取反其结果。

### `Future<void> _loadDevices()` <a id="_loaddevices"></a>
- **种类：** `_DeviceListPageState` 的方法
- **来源：** `lib/features/devices/views/device_list_page.dart`（第 203 行）
- **用途：** 从存储重载完整设备列表并刷新页面状态。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 经 `DeviceStorage.load()` 读取；`setState` 更新 `_devices` 并清除 `_loading`。
- **算法：** Await `DeviceStorage.load()`，然后设 `_devices = data.devices` 和 `_loading = false`。
- **用法：** 从 [`initState`](#initstate)（偏好加载后）、`_handleLocalDataChanged`（自动同步）和每个增/改/删/重排/模板流程后调用保持列表最新。
- **备注：** 这是页面拾取底层设备数据任何变化的唯一点，无论本页本地做出还是后台同步拉入。

### `Future<bool> _confirmDeleteDevice(Device device)` <a id="_confirmdeletedevice"></a>
- **种类：** `_DeviceListPageState` 的方法
- **来源：** `lib/features/devices/views/device_list_page.dart`（第 288 行）
- **用途：** 显示删除设备确认对话框，确认时删除并刷新列表。
- **输入：** `device` — 用户滑删的设备。
- **返回：** `Future<bool>` — 设备被删除 `true`，取消 `false`。
- **副作用：** 显示 `AlertDialog`；确认时调用 `DeviceStorage.deleteDevice`、`AutoSyncService.instance.notifySaved()` 并重载设备。
- **算法：**
  1. 显示带取消/删除操作的 `AlertDialog`，await `showDialog` 的 `bool?`。
  2. 结果恰好 `true` 时：经 `DeviceStorage.deleteDevice` 按 ID 删除设备、调用 `AutoSyncService.instance.notifySaved()`（标记本地数据已变使同步运行拾取删除——删除设备在模型层级联到什么见 [设备 — 退役/出售/删除的级联规则](../../../../features/devices.md#cascade-rules-on-retiresell-delete)）、重载设备列表并返回 `true`。
  3. 否则无副作用返回 `false`。
- **用法：** `_buildDismissibleCard` 中的 `confirmDismiss: (direction) async { ... return _confirmDeleteDevice(device); }`（`lib/features/devices/views/device_list_page.dart`，第 944 行）——`Dismissible` 的 `confirmDismiss` 用返回 `bool` 决定是否实际移除滑动块。
- **备注：** 无。

### `Future<void> _addFromTemplate()` <a id="_addfromtemplate"></a>
- **种类：** `_DeviceListPageState` 的方法
- **来源：** `lib/features/devices/views/device_list_page.dart`（第 321 行）
- **用途：** 让用户挑捆绑设备模板，然后为结果设备打开预填编辑页。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 经 `PresetService` 加载捆绑 JSON；显示模态底部面板（`_TemplatePicker`）；导航到 `DeviceEditPage`；重载设备。
- **算法：**
  1. Await `PresetService.loadTemplates()`（惰性加载/缓存行为见 [在线搜索与预设 — 捆绑预设](../../../../features/online-search-and-presets.md#bundled-presets--preset_servicedart)）。
  2. 未挂载提前返回。
  3. 在滚动控制模态底部面板显示 `_TemplatePicker`，await 所选 `DeviceTemplate?`。
  4. 挑了模板且组件仍挂载时：await `PresetService.loadCpus()`/`loadGpus()`（也惰性缓存），解析后未挂载提前返回，然后调用 `template.toDevice(cpuPresets: cpus, gpuPresets: gpus)` 从模板构建具体 `Device`、压入 `DeviceEditPage(device: device)` 并重载。
- **用法：** `build` 中"从模板添加"FAB 的 `onPressed: _addFromTemplate,`（`lib/features/devices/views/device_list_page.dart`，第 618 行）。
- **备注：** 三个单独 `mounted` 检查守卫三个 await 步骤（模板加载、选择器结果、cpu/gpu 预设加载），因为用户可在任一期间导航离开页面。

### `int _statusCount(DeviceLifecycleStatus status)` <a id="_statuscount"></a>
- **种类：** `_DeviceListPageState` 的方法
- **来源：** `lib/features/devices/views/device_list_page.dart`（第 394 行）
- **用途：** 统计当前有多少设备有给定生命周期状态。
- **输入：** `status`。
- **返回：** `int`。
- **副作用：** 无。
- **算法：** `_devices.where((d) => d.lifecycleStatus == status).length`。
- **用法：** `_buildHomeHeader` 中的 `_statusCount(DeviceLifecycleStatus.inService)` 等（`lib/features/devices/views/device_list_page.dart`，第 700–702 行），供给三个状态进度条。
- **备注：** 无。

### `double _totalFinancialCost()` <a id="_totalfinancialcost-list"></a>
- **种类：** `_DeviceListPageState` 的方法
- **来源：** `lib/features/devices/views/device_list_page.dart`（第 402 行）
- **用途：** 跨每个设备求和 `Device.totalCost()`（截至现在），供主页页头"总成本"指标。
- **输入：** 无。
- **返回：** `double`。
- **副作用：** 无。
- **算法：** `_devices.fold(0, (sum, device) => sum + device.totalCost())`。
- **用法：** `_buildHomeHeader` 中的 `_moneyText(_totalFinancialCost())`（`lib/features/devices/views/device_list_page.dart`，第 747 行）。
- **备注：** 与 `DeviceFinanceOverviewPage._totalFinancialCost` 相同形态（本文件列表页页头显示财务总览页摘要卡片显示的相同聚合）。

### `double _totalDailyCost()` <a id="_totaldailycost-list"></a>
- **种类：** `_DeviceListPageState` 的方法
- **来源：** `lib/features/devices/views/device_list_page.dart`（第 410 行）
- **用途：** 跨每个设备求和 `Device.averageDailyCost()`（截至现在），供主页页头"每日成本"指标。
- **输入：** 无。
- **返回：** `double`。
- **副作用：** 无。
- **算法：** `_devices.fold(0, (sum, device) => sum + (device.averageDailyCost() ?? 0))`。
- **用法：** `_buildHomeHeader` 中的 `_moneyText(_totalDailyCost())`（`lib/features/devices/views/device_list_page.dart`，第 755 行）。
- **备注：** 无。

### `String _moneyText(double amount)` <a id="_moneytext-list"></a>
- **种类：** `_DeviceListPageState` 的方法
- **来源：** `lib/features/devices/views/device_list_page.dart`（第 418 行）
- **用途：** 用页面配置的默认货币符号格式化普通金额。
- **输入：** `amount` — 已在 `_defaultCurrency`。
- **返回：** `String` — `"{symbol}{amount.toStringAsFixed(2)}"`。
- **副作用：** 无（经 `DeviceExchangeRateService.currencySymbol` 查找符号）。
- **算法：** 符号查找 + 2 位小数格式化，无转换——与 `DeviceFinanceOverviewPage._moneyText` 相同形态。
- **用法：** `_buildHomeHeader` 中的 `_moneyText(_totalFinancialCost())`、`_moneyText(_totalDailyCost())`。
- **备注：** 无。

### `Future<void> _onReorder(int oldIndex, int newIndex)` <a id="_onreorder"></a>
- **种类：** `_DeviceListPageState` 的方法
- **来源：** `lib/features/devices/views/device_list_page.dart`（第 458 行）
- **用途：** 把设备移到自定义（存储）顺序新位置并持久化变更。
- **输入：** `oldIndex`、`newIndex` — 由 `ReorderableListView.builder` 的 `onReorderItem` 回调提供。
- **返回：** `Future<void>`。
- **副作用：** 原地修改 `_devices`；`setState`；经 `DeviceStorage.save` 持久化。
- **算法：** 移除 `oldIndex` 处设备并在 `newIndex` 重新插入、调用 `setState` 立即反映重排，然后 await `DeviceStorage.save(DeviceData(devices: _devices))` 持久化新顺序。
- **用法：** `build` 中 `_reordering` 为 true 时显示的 `ReorderableListView.builder` 上的 `onReorderItem: _onReorder,`（`lib/features/devices/views/device_list_page.dart`，第 586 行）。
- **备注：** 源码文档注释说明 `onReorderItem`（而非较旧 `onReorder` 回调）已在移除后调整 `newIndex`，因此此方法不需要自己的索引调整逻辑——Flutter 重排回调常见的差一错误源。

### `List<DeviceTemplate> get _filtered` <a id="_filtered"></a>
- **种类：** `_TemplatePickerState` 的 getter
- **来源：** `lib/features/devices/views/device_list_page.dart`（第 1040 行）
- **用途：** 按当前搜索查询过滤捆绑设备模板列表。
- **输入：** 无（读取 `_query`、`widget.templates`）。
- **返回：** `List<DeviceTemplate>` — 查询为空时所有模板，否则名称、品牌、型号、CPU、GPU 或内存中含（不区分大小写）查询的模板。
- **副作用：** 无。
- **算法：** `_query` 为空时返回未过滤 `widget.templates`；否则把每个模板的 `name`、`brand`、`model`、`cpu`、`gpu` 和 `ram` 拼成一个小写字符串，并保留其中 `contains` 查询的模板。
- **用法：** `_TemplatePickerState.build` 中的 `final items = _filtered;`（`lib/features/devices/views/device_list_page.dart`，第 1056 行），驱动选择器 `ListView`。
- **备注：** 参与匹配的字段有意与列表项所显示的内容一致。仅按 `name` 过滤意味着输入副标题里正在显示的芯片名——「Snapdragon」「Apple M4」——却什么都搜不到。

### `Future<void> _choose(DeviceTemplate t)` <a id="_choose"></a>
- **种类：** `_TemplatePickerState` 的方法
- **来源：** `lib/features/devices/views/device_list_page.dart`
- **用途：** 确定选中模板应使用哪一个存储容量，然后关闭面板。
- **输入：** `t` —— 被点击的模板。
- **返回：** `Future<void>`；以 `_TemplateChoice` 弹出面板。
- **副作用：** 可能打开容量选择对话框；弹出所在的底部面板。
- **算法：** 只有一个容量或没有容量时，立即以索引 0 弹出。否则显示 `SimpleDialog` 列出各容量的 `displayString`，并以所选索引弹出。
- **备注：** 单一容量的模板会跳过对话框，因此常见情形仍是一次点击。关闭对话框表示取消选择，而不是静默退回最小容量——那正是 `toDevice` 过去对每个多容量模板所做的事。
