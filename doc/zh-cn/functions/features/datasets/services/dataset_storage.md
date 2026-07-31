# lib/features/datasets/services/dataset_storage.dart

`DataSetStorage` 持久化 `dataset_data.json` 文件并拥有数据集需要的唯一横切逻辑：设备的 `storage` 列表被重排或移除条目时保持每个数据集位置 `storageIndices` 有效。`remapDeviceStorageLinks` 的概念级走查（已对照此精确源码确认）见 [数据集 — remapDeviceStorageLinks()](../../../../features/datasets.md#remapdevicestoragelinks)，持久化 JSON 形态见 [数据格式 — DataSet / DataSetStorageLink](../../../../data-formats.md#dataset--datasetstoragelink-libfeaturesdatasetsmodelsdatasetdart)。像 `NetworkStorage` 一样，它经 `DeviceStorage.getAppDir()`（`../../../devices/services/device_storage.md`）解析文件位置，并在每次写入后通知 [`AutoSyncService`](../../../shared/services/auto_sync_service.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`_getFile`](#getfile) | 静态方法（私有） | A | 解析应用目录内 `dataset_data.json` 文件。 |
| [`load`](#load) | 静态方法 | A | 加载持久化 `DataSetData`（数据集列表）。 |
| [`save`](#save) | 静态方法 | A | 持久化 `DataSetData` 并通知自动同步服务。 |
| [`addOrUpdate`](#addorupdate) | 静态方法 | A | 按 id 插入或替换数据集。 |
| [`delete`](#delete) | 静态方法 | A | 按 id 删除数据集。 |
| [`remapDeviceStorageLinks`](#remapdevicestoragelinks) | 静态方法 | A | 设备存储列表变化后重映射（或丢弃）数据集存储槽索引。 |
| [`_sameIndices`](#sameindices) | 静态方法（私有） | A | 逐元素比较两个存储索引列表是否相等。 |

行数（7）与 `grep -c 'Purpose:' dataset_storage.dart`（7）精确匹配。

## 文档

### `static Future<File> _getFile()` <a id="getfile"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/datasets/services/dataset_storage.dart`（第 16 行）。
- **用途：** 解析当前应用目录内 `dataset_data.json` 文件。
- **输入：** 无。
- **返回：** `Future<File>`。
- **副作用：** 除 `DeviceStorage.getAppDir()` 的目录创建副作用外无。
- **算法：** `File('${(await DeviceStorage.getAppDir()).path}/dataset_data.json')`。
- **用法：** 被 [`load`](#load) 和 [`save`](#save) 调用。
- **备注：** 与 `NetworkStorage._getFile`（`../../network/services/network_storage.md`）相同模式——委托 `DeviceStorage.getAppDir()` 使 `dataset_data.json` 即使设置自定义存储路径后也与应用其他数据文件同处。

### `static Future<DataSetData> load()` <a id="load"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/datasets/services/dataset_storage.dart`（第 26 行）。
- **用途：** 从 `dataset_data.json` 加载持久化数据集列表。
- **输入：** 无。
- **返回：** `Future<DataSetData>` — 文件缺席或为空时 `const DataSetData()`（空）。
- **副作用：** 读取 `dataset_data.json`。
- **算法：** 存在性/空内容检查，然后 `DataSetData.fromJson(jsonDecode(...))`（见 [`dataset.md`](../models/dataset.md#datasetdata-fromjson)）。
- **用法：**
  ```dart
  final dsData = await DataSetStorage.load();
  ```
  （来自 [`dataset_list_page.md`](../views/dataset_list_page.md) 的 `_load`）
- **备注：** 无。

### `static Future<void> save(DataSetData data)` <a id="save"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/datasets/services/dataset_storage.dart`（第 40 行）。
- **用途：** 把完整数据集列表持久化到 `dataset_data.json` 并通知自动同步服务本地数据已变。
- **输入：** `data`。
- **返回：** `Future<void>`。
- **副作用：** 写 `dataset_data.json`（美化打印、非原子）；调用 `AutoSyncService.instance.notifySaved()`（见 [`auto_sync_service.md`](../../../shared/services/auto_sync_service.md#notifysaved)）。
- **算法：** JSON 编码 `data.toJson()`、写它、然后通知自动同步。
- **用法：**
  ```dart
  await save(DataSetData(datasets: updated, extraJson: data.extraJson));
  ```
  （来自下面 [`remapDeviceStorageLinks`](#remapdevicestoragelinks)，重写受影响链接后）
- **备注：** 数据集数据的每次写入都应经此方法（直接或经 [`addOrUpdate`](#addorupdate)/[`delete`](#delete)/[`remapDeviceStorageLinks`](#remapdevicestoragelinks)），使 `AutoSyncService` 总是被通知。

### `static Future<void> addOrUpdate(DataSet dataset)` <a id="addorupdate"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/datasets/services/dataset_storage.dart`（第 52 行）。
- **用途：** 插入新数据集或按 `id` 替换既有数据集。
- **输入：** `dataset`。
- **返回：** `Future<void>`。
- **副作用：** 经 [`save`](#save) 重写 `dataset_data.json`。
- **算法：** 加载当前列表；找相同 `id` 的既有数据集索引，找到则替换否则追加；保存。
- **用法：**
  ```dart
  await DataSetStorage.addOrUpdate(ds);
  ```
  （来自 [`dataset_edit_page.md`](../views/dataset_edit_page.md) 的 `_save`）
- **备注：** 无。

### `static Future<void> delete(String id)` <a id="delete"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/datasets/services/dataset_storage.dart`（第 69 行）。
- **用途：** 按 id 删除数据集。
- **输入：** `id`。
- **返回：** `Future<void>`。
- **副作用：** 经 [`save`](#save) 重写 `dataset_data.json`。
- **算法：** 把数据集从加载列表过滤；保存。
- **用法：**
  ```dart
  await DataSetStorage.delete(ds.id);
  ```
  （来自 [`dataset_list_page.md`](../views/dataset_list_page.md) 的 `_deleteDataSet`）
- **备注：** 与 `DeviceStorage.deleteDevice` 不同，这不清理任何反向引用——数据集无依赖者，删除它无需级联（对比 [设备 — 退役/出售/删除的级联规则](../../../../features/devices.md#cascade-rules-on-retiresell-delete)，那里删除*设备*确实清理其数据集存储链接，反方向）。

### `static Future<void> remapDeviceStorageLinks({required String deviceId, required int oldSlotCount, required Map<int, int> indexMap})` <a id="remapdevicestoragelinks"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/datasets/services/dataset_storage.dart`（第 85 行）。
- **用途：** 设备存储列表被重排或移除条目后，为一台设备重映射每个数据集的 `storageIndices`，使链接继续指向正确物理槽而非静默漂移。
- **输入：** `deviceId` — 哪台设备存储变了；`oldSlotCount` — 编辑前有多少槽；`indexMap` — 把每个**旧**槽索引（`0..oldSlotCount-1`）映射到其**新**索引；映射缺席的旧索引意为该槽被移除无替代。
- **返回：** `Future<void>`。
- **副作用：** 经 [`save`](#save) 重写 `dataset_data.json`——但只在至少一个数据集实际变化时；给触碰的每个数据集 bump `modifiedAt`（经 [`copyWith`](../models/dataset.md#copywith)）。
- **算法：** 1. 检查 `indexMap` 对每个索引 `0..oldSlotCount-1` 是否恒等映射；是则不做任何加载或保存地立即返回（空操作快速路径）。2. 否则加载所有数据集。3. 对每个数据集、每个 `DataSetStorageLink`：其 `deviceId` 不匹配则保持不变。否则在 `indexMap` 查找链接每个 `storageIndices` 构建 `newIndices`——有映射的索引保留在新位置；无映射的索引（`indexMap[idx] == null`）完全丢弃。4. `newIndices` 与原始 `storageIndices` 不同（按长度或按内容，经 [`_sameIndices`](#sameindices)）时标记此数据集已变。5. `newIndices` 最终为空的链接被完全从数据集 `storageLinks` 丢弃（而非带空列表保留）。6. 至少一个链接变化的任何数据集经 `copyWith(storageLinks: links)` 替换（这也 bump `modifiedAt`）；未受影响数据集原样通过。7. 无数据集变化时保存前返回；否则保存更新数据集列表。
- **用法：** 设备编辑器保存处理器每次保存时调用，带用户在编辑/重排/移除存储行时跟踪的旧→新槽索引映射——此函数调用方必须维持的调用点契约见 [数据集 — 设备编辑器集成](../../../../features/datasets.md#device-editor-integration)。
- **备注：** 这是 `AGENTS.md` 点名的"重排/移除设备存储槽必须保持数据集链接同步"规则的唯一实现（见 [数据集 — 存储槽索引链接](../../../../features/datasets.md#storage-slot-index-linking)）——任何让用户重排或移除存储槽的*新*代码路径也必须带结果索引映射调用此函数，否则数据集链接会静默指向错误（或不复存在）槽。步骤 1 的恒等映射快速路径意味着每次设备保存无条件调用在存储实际未被重排/移除时便宜。

### `static bool _sameIndices(List<int> a, List<int> b)` <a id="sameindices"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/datasets/services/dataset_storage.dart`（第 145 行）。
- **用途：** 逐元素比较两个存储索引列表是否相等。
- **输入：** `a`、`b`。
- **返回：** `bool` — 长度不匹配立即 `false`；否则只在每个位置都匹配时 `true`。
- **副作用：** 无。
- **算法：** 长度检查，然后比较 `a[i]` 与 `b[i]` 的 `for` 循环，第一个不匹配返回 `false`。
- **用法：** 只被 [`remapDeviceStorageLinks`](#remapdevicestoragelinks) 调用，决定链接 `storageIndices` 是否实际变化（而非只长度变化，调用方单独检查）。
- **备注：** 顺序敏感——`[0, 1]` 和 `[1, 0]` 被认为不同，这重要，因为 `remapDeviceStorageLinks` 保留幸存索引的原始顺序而非重新排序。
