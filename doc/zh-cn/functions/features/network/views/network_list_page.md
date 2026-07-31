# lib/features/network/views/network_list_page.dart

网络首页（见 [网络](../../../../features/networks.md)）。拥有网络列表的加载/排序/重排状态、每个 [`Network`](../models/network.md#network-new) 一张卡片（带逐类型 logo/图标），和由 [`NetworkStorage`](../services/network_storage.md) 支撑的增/改/详情导航流程。与设备/数据集列表页不同，本页**不**向 `AutoSyncService` 注册本地数据变更通知——它只在从压入返回时重载（见下面声明表 [`_buildNetworkCard`](#buildnetworkcard-note)）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `NetworkListPage`（构造函数） | 构造函数 | B | 创建页面组件（无参数）。 |
| `createState` | 方法（`NetworkListPage`） | B | 创建页面可变状态对象。 |
| [`initState`](#initstate) | 方法（组件生命周期） | A | 注册自动同步监听器并启动偏好/网络加载。 |
| `dispose` | 方法（组件生命周期） | B | 注销自动同步监听器。 |
| `_handleLocalDataChanged` | 方法（`_NetworkListPageState`） | B | 响应自动同步通知重载网络。 |
| [`_loadSortPrefs`](#loadsortprefs) | 方法（`_NetworkListPageState`） | A | 从设备存储配置加载持久化排序模式/方向。 |
| [`_saveSortPrefs`](#savesortprefs) | 方法（`_NetworkListPageState`） | A | 把当前排序模式/方向持久化到设备存储配置。 |
| [`_sortedNetworks`](#sortednetworks) | getter（`_NetworkListPageState`） | A | 按当前排序模式/方向排序 `_networks`。 |
| [`_load`](#load) | 方法（`_NetworkListPageState`） | A | 从存储重载网络列表并刷新状态。 |
| [`_onReorder`](#onreorder) | 方法（`_NetworkListPageState`） | A | 在自定义顺序内移动网络并持久化新顺序。 |
| `_typeIcon` | 方法（`_NetworkListPageState`） | B | 把 `NetworkType` 映射到回退 `IconData`（无 logo 资产时使用）。 |
| `_typeLabel` | 方法（`_NetworkListPageState`） | B | 把 `NetworkType` 映射到其本地化标签。 |
| `_sortModeLabel` | 方法（`_NetworkListPageState`） | B | 把 `NetworkSortMode` 映射到其本地化标签。 |
| `_buildNetworkCard` | 方法（组件辅助） | B | 渲染一个网络卡片，带可选尾部拖拽手柄。 |
| `build` | 方法（组件） | B | 构建脚手架：应用栏、排序菜单、网络列表或重排视图、添加 FAB。 |

行数（15）与 `grep -c 'Purpose:' network_list_page.dart`（15）精确匹配。

## 文档

### `void initState()` <a id="initstate"></a>
- **种类：** `_NetworkListPageState` 的方法（组件生命周期覆盖）。
- **来源：** `lib/features/network/views/network_list_page.dart`（第 43 行）。
- **用途：** 把本页接入自动同步通知系统并启动初始偏好/网络加载。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 把 `_handleLocalDataChanged` 注册到 `AutoSyncService.instance.addOnLocalDataChanged`；启动异步加载链。
- **算法：** 1. 调用 `super.initState()`。2. 把 `_handleLocalDataChanged` 注册为 `AutoSyncService` 本地数据变更监听器，使带入新网络数据的后台同步自动重载此列表。3. 链 `_loadSortPrefs().then((_) => _load())`——排序偏好先加载，然后用已加载偏好加载并排序网络。
- **用法：** `_NetworkListPageState` 首次插入树时由 Flutter 框架自动调用；无直接调用点。
- **备注：** 对应 `dispose()` 调用 `AutoSyncService.instance.removeOnLocalDataChanged(_handleLocalDataChanged)` 避免页面释放后泄漏监听器（见 [`auto_sync_service.md#addonlocaldatachanged`](../../../shared/services/auto_sync_service.md)）。

### `Future<void> _loadSortPrefs()` <a id="loadsortprefs"></a>
- **种类：** `_NetworkListPageState` 的方法。
- **来源：** `lib/features/network/views/network_list_page.dart`（第 74 行）。
- **用途：** 从设备存储配置加载持久化排序模式和排序方向，回退合理默认。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 经 `DeviceStorage.readConfig()` 读取配置；调用 `setState`。
- **算法：** 读取配置映射；把存储 `'networkSortMode'` 字符串对照 `NetworkSortMode.values` 按 `.name` 匹配解析 `_sortMode`，缺失/无法识别回退 `NetworkSortMode.custom`（`firstOrNull ?? NetworkSortMode.custom`）；直接解析 `_sortAscending`（默认 `false`）；经一次 `setState` 应用两者。
- **用法：** [`initState`](#initstate) 构造后链接。
- **备注：** 无。

### `Future<void> _saveSortPrefs()` <a id="savesortprefs"></a>
- **种类：** `_NetworkListPageState` 的方法。
- **来源：** `lib/features/network/views/network_list_page.dart`（第 91 行）。
- **用途：** 把当前排序模式和方向持久化回设备存储配置。
- **输入：** 无（读取 `_sortMode`、`_sortAscending`）。
- **返回：** `Future<void>`。
- **副作用：** 经 `DeviceStorage.readConfig()`/`writeConfig()` 读取然后写配置。
- **算法：** 读取既有配置映射、覆盖 `'networkSortMode'`（作为枚举 `.name`）和 `'networkSortAscending'`、写回整个映射——保留任何其他键。
- **用法：** 从 `build` 中排序菜单 `onSelected` 处理器调用，紧接每个修改 `_sortMode`/`_sortAscending` 后。
- **备注：** 无。

### `List<Network> get _sortedNetworks` <a id="sortednetworks"></a>
- **种类：** `_NetworkListPageState` 的 getter。
- **来源：** `lib/features/network/views/network_list_page.dart`（第 103 行）。
- **用途：** 产生显示列表：按活动 `NetworkSortMode` 和方向排序的 `_networks`（或留在自定义/存储顺序）。
- **输入：** 无（读取 `_networks`、`_sortMode`、`_sortAscending`）。
- **返回：** `List<Network>` — 排序副本；`_networks` 本身绝不被修改。
- **副作用：** 无。
- **算法：** 1. 把 `_networks` 复制进 `list`。2. `_sortMode == custom` 时立即返回未排序副本（自定义顺序是存储中当前任何东西）。3. 否则构建比较器：`alphabetical` 比较小写名；`subnet` 比较 `subnet` 字符串，null 总是排最后（`a.subnet == null` → `1`，即排后）。4. 包装比较器尊重 `_sortAscending`：升序时交换参数顺序（`comparator(b, a)`）反转否则降序的比较器。5. 排序并返回副本。
- **用法：** 被 `build` 的 `ListView.builder` 非重排分支读取：`_sortedNetworks[index]`。
- **备注：** `subnet` 排序 null 处理方向不变——升序降序 null 都留最后，因为升序包装交换比较器参数而非取反其结果（与 `_DeviceListPageState._sortedDevices` 相同技术，见 [`device_list_page.md`](../../devices/views/device_list_page.md#_sorteddevices)）。

### `Future<void> _load()` <a id="load"></a>
- **种类：** `_NetworkListPageState` 的方法。
- **来源：** `lib/features/network/views/network_list_page.dart`（第 131 行）。
- **用途：** 从存储重载完整网络列表并刷新页面状态。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 经 `NetworkStorage.load()` 读取；`setState` 更新 `_networks`。
- **算法：** Await `NetworkStorage.load()`，然后设 `_networks = data.networks`（丢弃 `data.assignments`——本页只显示网络列表，非逐网络设备赋值）。
- **用法：** 从 [`initState`](#initstate)（偏好加载后）、`_handleLocalDataChanged`（自动同步）和 `build` 中从增/详情页压入返回后调用（见下面 `_buildNetworkCard` 的说明）。
- **备注：** <a id="buildnetworkcard-note"></a>因为本页无与*本页自身做的本地编辑*相关的 `AutoSyncService` 注册（只有经 [`initState`](#initstate) 的后台同步通知），`build` 中每个导航压入——"添加"FAB 和 `_buildNetworkCard` 的 `onTap` 进 `NetworkDetailPage`——都在压入路由返回后再次调用 `_load()`，这正是那些页面上做的编辑/删除在这里可见的方式。

### `Future<void> _onReorder(int oldIndex, int newIndex)` <a id="onreorder"></a>
- **种类：** `_NetworkListPageState` 的方法。
- **来源：** `lib/features/network/views/network_list_page.dart`（第 141 行）。
- **用途：** 把网络移到自定义顺序新位置并持久化变更。
- **输入：** `oldIndex`、`newIndex` — 由 `ReorderableListView.builder` 的 `onReorderItem` 回调提供。
- **返回：** `Future<void>`。
- **副作用：** 原地修改 `_networks`；`setState`；经 `NetworkStorage.save` 持久化。
- **算法：** 移除 `oldIndex` 处网络并在 `newIndex` 重新插入；调用 `setState` 立即反映重排；加载当前 `NetworkData`（读取最新 `assignments`）并 await `NetworkStorage.save(NetworkData(networks: _networks, assignments: data.assignments))` 持久化新网络顺序而不打扰赋值。
- **用法：** `build` 中 `_reordering` 为 true 时显示的 `ReorderableListView.builder` 上的 `onReorderItem: _onReorder,`。
- **备注：** 文档注释说明 `onReorderItem`（而非较旧 `onReorder` 回调）已在移除后调整 `newIndex`，因此这里无需额外索引调整逻辑——与 `_DeviceListPageState._onReorder`（`../../devices/views/device_list_page.md#_onreorder`）相同约定。
