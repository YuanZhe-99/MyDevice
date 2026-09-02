# lib/features/datasets/views/dataset_edit_page.dart

单个 [`DataSet`](../models/dataset.md#dataset-new) 的增/改表单——emoji 选择器、名称字段和要包含的每设备存储槽清单。经一个构造函数参数为"添加"（`dataSet: null`）和"编辑"（`dataSet: existing`）复用。从 [`DeviceStorage.load`](../../devices/services/device_storage.md#load) 加载在用设备列表构建存储清单，并经 [`DataSetStorage.addOrUpdate`](../services/dataset_storage.md#addorupdate) 保存。本页编辑的模型见 [数据集](../../../../features/datasets.md)，尤其 `DataSetStorageLink` 的 `storageIndices` 是设备 `storage` 列表的*位置*而非稳定标识符。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `DataSetEditPage`（构造函数） | 构造函数 | B | 创建页面组件（可选 `dataSet` 供编辑）。 |
| `createState` | 方法（`DataSetEditPage`） | B | 创建页面可变状态对象。 |
| `_isEditing` | getter（`_DataSetEditPageState`） | B | 返回是否传入了既有 `DataSet`。 |
| [`initState`](#initstate) | 方法（组件生命周期） | A | 从 `widget.dataSet` 播种名称/emoji/所选存储状态，然后加载设备。 |
| [`_loadDevices`](#loaddevices) | 方法（`_DataSetEditPageState`） | A | 加载并过滤清单中要提供的带存储在用设备。 |
| [`_save`](#save) | 方法（`_DataSetEditPageState`） | A | 构建存储链接、构造/更新 `DataSet`、持久化并弹出。 |
| `_pickEmoji` | 方法（`_DataSetEditPageState`） | B | 显示 emoji 选择器对话框并应用所选 emoji。 |
| `dispose` | 方法（组件生命周期） | B | 释放名称文本控制器。 |
| `build` | 方法（组件） | B | 围绕 `_buildBody` 构建脚手架。 |
| `_buildBody` | 方法（组件辅助） | B | 选择布局：单个 `ListView`（emoji/名称行，然后存储清单），或——`useDetailTwoPane` 通过时——一个 `Row`：`editFormLeftPaneWidth` 宽、装着该行的固定左窗格（放在钉住窗格高度的滚动视图里作软键盘兜底）加右侧清单 `ListView`。 |
| `_buildHeaderRow` | 方法（组件辅助） | B | emoji 块和名称字段行——从 `build` 原样抽出。 |
| `_buildStorageChildren` | 方法（组件辅助） | B | 存储标题、空态文本和每设备复选框卡片——从 `build` 原样抽出。 |

行数（9）与 `grep -c 'Purpose:' dataset_edit_page.dart`（9）精确匹配。

## 文档

### `void initState()` <a id="initstate"></a>
- **种类：** `_DataSetEditPageState` 的方法（组件生命周期覆盖）。
- **来源：** `lib/features/datasets/views/dataset_edit_page.dart`（第 71 行）。
- **用途：** 编辑既有数据集时从中播种名称字段、emoji 和每设备所选存储索引集合；无论哪种情况都启动加载设备列表。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 设置 `_nameController.text`、`_emoji` 并填充 `_selectedStorages`；调用 `_loadDevices()`（即发即忘）。
- **算法：** 1. 调用 `super.initState()`。2. `_isEditing` 时从 `widget.dataSet` 设置 `_nameController.text` 和 `_emoji`，然后对其每个 `storageLinks` 填充 `_selectedStorages[link.deviceId] = Set.of(link.storageIndices)`——把链接有序索引列表转换为按设备 id 键控的集合，清单 UI 读/改的正是它。3. 无条件调用 `_loadDevices()`（添加或编辑）。
- **用法：** `_DataSetEditPageState` 首次插入树时由 Flutter 框架自动调用；无直接调用点。
- **备注：** 这里把 `storageIndices`（有序 `List<int>`）转换为 `Set<int>` 意味着未碰给定设备选择的编辑不保留原始顺序——[`_save`](#save) 持久化前把每个设备集合重新排序回升序列表，因此这不是数据丢失风险，只是规范化。

### `Future<void> _loadDevices()` <a id="loaddevices"></a>
- **种类：** `_DataSetEditPageState` 的方法。
- **来源：** `lib/features/datasets/views/dataset_edit_page.dart`（第 89 行）。
- **用途：** 加载完整设备列表并缩小到既在用又有至少一个存储条目的设备——存储清单中提供才合理的唯一设备。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 经 `DeviceStorage.load()` 读取；`setState` 更新 `_devices` 并清除 `_loading`。
- **算法：** Await `DeviceStorage.load()`，未挂载提前返回，然后设 `_devices = data.devices.where((d) => d.isInService && d.storage.isNotEmpty).toList()` 和 `_loading = false`。
- **用法：** 从 [`initState`](#initstate) 调用一次。
- **备注：** 退役/出售设备（`!d.isInService`）即使离开服务*前*已有存储链接也绝不出现于此清单——那些既有链接留在持久化 `DataSet` 中（本页不丢弃它们），但用户不能经此 UI 为该设备添加新链接。对比 [设备 — 退役/出售/删除的级联规则](../../../../features/devices.md#cascade-rules-on-retiresell-delete)，那里退役设备未来从选择器移除而不追溯删除既有引用。

### `Future<void> _save()` <a id="save"></a>
- **种类：** `_DataSetEditPageState` 的方法。
- **来源：** `lib/features/datasets/views/dataset_edit_page.dart`（第 105 行）。
- **用途：** 从当前清单选择构建数据集存储链接、构造或更新 `DataSet`、持久化并关闭页面。
- **输入：** 无（读取 `_nameController.text`、`_emoji`、`_selectedStorages`、`widget.dataSet`）。
- **返回：** `Future<void>`。
- **副作用：** 调用 `DataSetStorage.addOrUpdate`（写 `dataset_data.json`）；调用 `AutoSyncService.instance.notifySaved()`；仍挂载时弹出页面（返回 `true`）。
- **算法：** 1. 修剪名称为空时提前返回（无验证对话框——只是静默空操作）。2. 从 `widget.dataSet`（编辑时）按 `deviceId` 快照每个既有链接的 `extraJson`，使重新保存保留幸存链接上的任何未知字段。3. 对每个所选索引集合非空的设备，用升序排序索引和保留 `extraJson`（全新链接 `{}`）构建 [`DataSetStorageLink`](../models/dataset.md#datasetstoragelink-new)。空选择设备完全省略——它们根本得不到链接。4. 编辑时从 `widget.dataSet` 开始，否则新鲜 `DataSet(name: name, emoji: _emoji)`，然后 [`copyWith`](../models/dataset.md#copywith) 修剪 `name`、`_emoji` 和构建 `links` 列表（这也 bump `modifiedAt`，因为 `copyWith` 默认"现在"）。5. Await `DataSetStorage.addOrUpdate(ds)`。6. 调用 `AutoSyncService.instance.notifySaved()`。7. 仍挂载时以 `true` 弹出（调用方 `dataset_list_page.dart` 用此 `true` 决定是否重载）。
- **用法：** 在 `build` 中接为应用栏保存 `TextButton.onPressed`。
- **备注：** 构造每个链接前排序 `entry.value.toList()..sort()` 正是让 `storageIndices` 无论用户勾选顺序如何都保持升序的东西——这重要，因为 [`remapDeviceStorageLinks`](../services/dataset_storage.md#remapdevicestoragelinks) 和列表页显示逻辑都假设/偏好升序，即使结构上无强制。
