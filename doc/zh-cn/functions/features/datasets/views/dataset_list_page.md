# lib/features/datasets/views/dataset_list_page.dart

数据集首页（见 [数据集](../../../../features/datasets.md)）。拥有数据集列表的加载/排序/重排状态，对照活设备列表交叉引用 [`DataSetStorageLink`](../models/dataset.md#datasetstoragelink-new) 索引构建每个块存储摘要副标题，并驱动由 [`DataSetStorage`](../services/dataset_storage.md) 支撑的增/改/删流程。注册到 `AutoSyncService`（`../../../../shared/services/auto_sync_service.md`），使后台同步带入新本地数据时列表自我刷新——与 [`device_list_page.md`](../../devices/views/device_list_page.md) 和 [`network_list_page.md`](../../network/views/network_list_page.md) 使用的相同模式。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `DataSetListPage`（构造函数） | 构造函数 | B | 创建页面组件（无参数）。 |
| `createState` | 方法（`DataSetListPage`） | B | 创建页面可变状态对象。 |
| [`initState`](#initstate) | 方法（组件生命周期） | A | 注册自动同步监听器并启动偏好/数据集加载。 |
| `dispose` | 方法（组件生命周期） | B | 注销自动同步监听器。 |
| `_handleLocalDataChanged` | 方法（`_DataSetListPageState`） | B | 响应自动同步通知重载数据集。 |
| [`_loadSortPrefs`](#loadsortprefs) | 方法（`_DataSetListPageState`） | A | 从设备存储配置加载持久化排序模式/方向。 |
| [`_saveSortPrefs`](#savesortprefs) | 方法（`_DataSetListPageState`） | A | 把当前排序模式/方向持久化到设备存储配置。 |
| [`_sortedDatasets`](#sorteddatasets) | getter（`_DataSetListPageState`） | A | 按当前排序模式/方向排序 `_datasets`。 |
| [`_load`](#load) | 方法（`_DataSetListPageState`） | A | 从存储重载数据集列表和设备列表两者。 |
| [`_storageLines`](#storagelines) | 方法（`_DataSetListPageState`） | A | 为每个存储链接构建一个显示行，解析设备/槽名。 |
| `_addDataSet` | 方法（`_DataSetListPageState`） | B | 压入空白数据集编辑页，报告保存后重载。 |
| `_editDataSet` | 方法（`_DataSetListPageState`） | B | 为既有数据集压入数据集编辑页，报告保存后重载。 |
| [`_deleteDataSet`](#deletedataset) | 方法（`_DataSetListPageState`） | A | 确认并接受时删除数据集并通知同步层。 |
| [`_onReorder`](#onreorder) | 方法（`_DataSetListPageState`） | A | 在自定义顺序内移动数据集并持久化新顺序。 |
| `_setColumnsPref` | 方法（`_DataSetListPageState`） | B | 存储新的列数偏好（`DeviceStorage.setDataSetListColumns`）并重新渲染。 |
| `_buildDataSetTile` | 方法（组件辅助） | B | 渲染一个数据集列表块（emoji、名称、存储摘要副标题）；`reorderHandle` 禁用点按编辑。 |
| `_buildMenuTile` | 方法（组件辅助） | B | 多列 tile：`_buildDataSetTile` 加尾部删除 `PopupMenuButton`，取代滑动。 |
| `build` | 方法（组件） | B | 构建脚手架：应用栏、列数控件（容量为 1 及重排时隐藏）、排序菜单、数据集列表——一列时是滑动 tile，多列时是菜单 tile 的 `adaptiveTileRow`——或重排视图、添加 FAB。列数由 `listColumnCount` 以 `shellContentWidth − 16` 和 `dataSetTileMinWidth` 得出。 |

行数（16）与 `grep -c 'Purpose:' dataset_list_page.dart`（16）精确匹配。

## 文档

### `void initState()` <a id="initstate"></a>
- **种类：** `_DataSetListPageState` 的方法（组件生命周期覆盖）。
- **来源：** `lib/features/datasets/views/dataset_list_page.dart`（第 43 行）。
- **用途：** 把本页接入自动同步通知系统并启动初始偏好/数据集加载。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 把 `_handleLocalDataChanged` 注册到 `AutoSyncService.instance.addOnLocalDataChanged`；启动异步加载链。
- **算法：** 1. 调用 `super.initState()`。2. 把 `_handleLocalDataChanged` 注册为 `AutoSyncService` 本地数据变更监听器。3. 链 `_loadSortPrefs().then((_) => _load())`。
- **用法：** `_DataSetListPageState` 首次插入树时由 Flutter 框架自动调用；无直接调用点。
- **备注：** 对应 `dispose()` 调用 `AutoSyncService.instance.removeOnLocalDataChanged(_handleLocalDataChanged)` 避免泄漏监听器（见 [`auto_sync_service.md`](../../../shared/services/auto_sync_service.md)）。

### `Future<void> _loadSortPrefs()` <a id="loadsortprefs"></a>
- **种类：** `_DataSetListPageState` 的方法。
- **来源：** `lib/features/datasets/views/dataset_list_page.dart`（第 75 行）。
- **用途：** 从设备存储配置加载持久化排序模式和排序方向，回退合理默认。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 经 `DeviceStorage.readConfig()` 读取配置；调用 `setState`。
- **算法：** 读取配置映射；把存储 `'datasetSortMode'` 字符串对照 `DataSetSortMode.values` 按 `.name` 匹配解析 `_sortMode`，缺失/无法识别回退 `DataSetSortMode.custom`；直接解析 `_sortAscending`（默认 `false`）；经一次 `setState` 应用两者。
- **用法：** 在 [`initState`](#initstate) 构造后链接。
- **备注：** 无。

### `Future<void> _saveSortPrefs()` <a id="savesortprefs"></a>
- **种类：** `_DataSetListPageState` 的方法。
- **来源：** `lib/features/datasets/views/dataset_list_page.dart`（第 92 行）。
- **用途：** 把当前排序模式和方向持久化回设备存储配置。
- **输入：** 无（读取 `_sortMode`、`_sortAscending`）。
- **返回：** `Future<void>`。
- **副作用：** 经 `DeviceStorage.readConfig()`/`writeConfig()` 读取然后写配置。
- **算法：** 读取既有配置映射、覆盖 `'datasetSortMode'`（作为枚举 `.name`）和 `'datasetSortAscending'`、写回整个映射。
- **用法：** 从 `build` 中排序菜单 `onSelected` 处理器调用。
- **备注：** 无。

### `List<DataSet> get _sortedDatasets` <a id="sorteddatasets"></a>
- **种类：** `_DataSetListPageState` 的 getter。
- **来源：** `lib/features/datasets/views/dataset_list_page.dart`（第 104 行）。
- **用途：** 产生显示列表：按名称排序的 `_datasets`（或留在自定义/存储顺序）。
- **输入：** 无（读取 `_datasets`、`_sortMode`、`_sortAscending`）。
- **返回：** `List<DataSet>` — 排序副本；`_datasets` 本身绝不被修改。
- **副作用：** 无。
- **算法：** 1. 把 `_datasets` 复制进 `list`。2. `_sortMode == custom` 时返回未排序副本。3. 否则唯一其他模式 `alphabetical` 比较小写名称。4. 包装比较器尊重 `_sortAscending`（升序时交换参数顺序）。5. 排序并返回。
- **用法：** 被 `build` 的 `ListView.builder` 非重排分支读取：`_sortedDatasets[index]`。
- **备注：** 与 `NetworkListPage` 的三模式排序（自定义/字母/子网）不同，数据集只有两模式——没有与 `Network.subnet` 类比、值得排序的逐数据集字段。

### `Future<void> _load()` <a id="load"></a>
- **种类：** `_DataSetListPageState` 的方法。
- **来源：** `lib/features/datasets/views/dataset_list_page.dart`（第 121 行）。
- **用途：** 重载数据集列表和完整设备列表，因为 [`_storageLines`](#storagelines) 需要活设备名/存储条目构建每个块副标题。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 经 `DataSetStorage.load()` 和 `DeviceStorage.load()` 读取；`setState` 更新 `_datasets`、`_devices` 并清除 `_loading`。
- **算法：** Await 两个加载（顺序、非并行），未挂载提前返回，然后一次 `setState` 设 `_datasets = dsData.datasets`、`_devices = devData.devices`、`_loading = false`。
- **用法：** 从 [`initState`](#initstate)（偏好加载后）、`_handleLocalDataChanged`（自动同步）和每个增/改/删/重排流程后调用。
- **备注：** 这里加载设备列表（不只数据集列表）正是让本页显示 `"{device.name} – {storage summary}"` 而非原始 `deviceId`/索引的东西——见 [`_storageLines`](#storagelines)。

### `List<String> _storageLines(DataSet ds)` <a id="storagelines"></a>
- **种类：** `_DataSetListPageState` 的方法。
- **来源：** `lib/features/datasets/views/dataset_list_page.dart`（第 138 行）。
- **用途：** 为数据集上每个存储链接构建一个人可读副标题行，按设备分组，供列表块副标题。
- **输入：** `ds` — 要摘要的数据集。
- **返回：** `List<String>` — 每个 `deviceId` 仍解析到已知设备的 `DataSetStorageLink` 一行；引用已删除设备的链接静默跳过。
- **副作用：** 无。
- **算法：** 对 `ds.storageLinks` 中每个 `DataSetStorageLink`：1. 在 `_devices` 按 `link.deviceId` 查找设备；未找到完全跳过此链接（`continue`）。2. 对 `link.storageIndices` 中仍在 `device.storage.length` 范围内的每个索引，收集该槽的 [`StorageInfo.displayString`](../../devices/models/device.md#storageinfo-displaystring)。越界索引（存储列表收缩后未重映射的过期，或真实损坏数据）静默跳过而非显示为错误。3. 无存储部分解析（空列表但设备本身存在）时行只是设备名；否则 `"{device.name} – {parts.join(', ')}"`。
- **用法：** `_buildDataSetTile` 中的 `_storageLines(ds)`（本文件，第 233 行），用 `'\n'` 连接为块副标题（最多 4 行，省略号）。
- **备注：** 此方法是 [数据集 — 存储槽索引链接](../../../../features/datasets.md#storage-slot-index-linking) 描述位置索引契约的读侧——这里越界索引（而非导致崩溃）正是 [`remapDeviceStorageLinks`](../services/dataset_storage.md#remapdevicestoragelinks) 存在、通过设备存储列表变化时保持索引同步来预防的"过期/悬空"失败模式。

### `Future<void> _deleteDataSet(DataSet ds)` <a id="deletedataset"></a>
- **种类：** `_DataSetListPageState` 的方法。
- **来源：** `lib/features/datasets/views/dataset_list_page.dart`（第 188 行）。
- **用途：** 显示删除数据集确认对话框，确认时删除并刷新列表。
- **输入：** `ds` — 用户滑删的数据集。
- **返回：** `Future<void>`。
- **副作用：** 显示 `AlertDialog`；确认时调用 `DataSetStorage.delete`、`AutoSyncService.instance.notifySaved()` 并重载。
- **算法：** 1. 显示带取消/删除操作的 `AlertDialog`，await `bool?`。2. `true` 时：经 `DataSetStorage.delete` 按 id 删除、调用 `AutoSyncService.instance.notifySaved()` 并重载。3. 否则什么都不做。
- **用法：** `confirmDismiss: (_) async { await _deleteDataSet(ds); return false; }` 在 `build` 中包裹每个块的 `Dismissible` 上——无论结果如何总是向 `confirmDismiss` 返回 `false`，因为 `_deleteDataSet` 内的 `_load()` 已重建列表，而非让 `Dismissible` 自己移除块。
- **备注：** 因为 `confirmDismiss` 总是返回 `false`，滑动的块在列表从重载重建前视觉弹回——动画中途有短暂时刻仍显示（已删除）块。

### `Future<void> _onReorder(int oldIndex, int newIndex)` <a id="onreorder"></a>
- **种类：** `_DataSetListPageState` 的方法。
- **来源：** `lib/features/datasets/views/dataset_list_page.dart`（第 219 行）。
- **用途：** 把数据集移到自定义顺序新位置并持久化变更。
- **输入：** `oldIndex`、`newIndex` — 来自 `ReorderableListView.builder` 的 `onReorderItem`。
- **返回：** `Future<void>`。
- **副作用：** 原地修改 `_datasets`；`setState`；经 `DataSetStorage.save` 持久化；调用 `AutoSyncService.instance.notifySaved()`。
- **算法：** 移除 `oldIndex` 处数据集并在 `newIndex` 重新插入；调用 `setState`；await `DataSetStorage.save(DataSetData(datasets: _datasets))`，然后单独调用 `AutoSyncService.instance.notifySaved()`。
- **用法：** `onReorderItem: _onReorder,` 在 `build` 中 `_reordering` 为 true 时显示的 `ReorderableListView.builder` 上。
- **备注：** 与 `NetworkListPage._onReorder`（保存前重新加载 `assignments` 使不破坏它们）不同，此方法不带任何顶层 `DataSetData` 上 `extraJson` 地保存 `DataSetData(datasets: _datasets)`——持久化文件曾有任何未知顶层键时重排会丢弃它们（本文件 `DataSetData` 模型确实有 `extraJson` 字段，但此调用点不传递它）。
