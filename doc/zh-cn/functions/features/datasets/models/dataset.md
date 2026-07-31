# lib/features/datasets/models/dataset.dart

[数据集](../../../../features/datasets.md) 的模型来源。定义 `DataSetStorageLink`（数据集对特定设备上一个或多个存储槽的引用，按位置索引）、`DataSet`（此类链接的命名集合，跨一台或多台设备）和由 [`../services/dataset_storage.md`](../services/dataset_storage.md) 持久化的顶层 `DataSetData` 容器。这里每个模型都遵循应用标准形态——普通/const 构造函数、`toJson`/`fromJson` 和构建在通用 [`json_preservation.md`](../../../shared/utils/json_preservation.md) 辅助上的 `mergeUnknownFieldsFrom`。`storageIndices` 是*位置*（非稳定每槽 id）意味着任何重排或移除设备存储槽的代码都必须调用 [`DataSetStorage.remapDeviceStorageLinks`](../services/dataset_storage.md#remapdevicestoragelinks) 保持这些链接有效，原因见 [数据集 — 存储槽索引链接](../../../../features/datasets.md#storage-slot-index-linking)，穷举持久化字段参考见 [数据格式 — DataSet / DataSetStorageLink](../../../../data-formats.md#dataset--datasetstoragelink-libfeaturesdatasetsmodelsdatasetdart)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`DataSetStorageLink`](#datasetstoragelink-new) | 构造函数 | A | 创建数据集存储链接实例。 |
| [`toJson`](#datasetstoragelink-tojson) | 方法（`DataSetStorageLink`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`DataSetStorageLink.fromJson`](#datasetstoragelink-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `DataSetStorageLink`。 |
| [`mergeUnknownFieldsFrom`](#datasetstoragelink-mergeunknownfieldsfrom) | 方法（`DataSetStorageLink`） | A | 从另一个 `DataSetStorageLink` 三方合并未知 JSON 字段。 |
| [`DataSet`](#dataset-new) | 构造函数 | A | 创建 `DataSet` 实例（默认新鲜 `id`/`modifiedAt`）。 |
| [`copyWith`](#copywith) | 方法（`DataSet`） | A | 创建带所选字段替换的副本。 |
| [`toJson`](#dataset-tojson) | 方法（`DataSet`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`DataSet.fromJson`](#dataset-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `DataSet`。 |
| [`mergeUnknownFieldsFrom`](#dataset-mergeunknownfieldsfrom) | 方法（`DataSet`） | A | 三方合并未知字段，含每个嵌套存储链接。 |
| [`DataSetData`](#datasetdata-new) | 构造函数 | A | 创建 `DataSetData` 实例。 |
| [`toJson`](#datasetdata-tojson) | 方法（`DataSetData`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`DataSetData.fromJson`](#datasetdata-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `DataSetData`。 |

行数（12）与 `grep -c 'Purpose:' dataset.dart`（12）精确匹配。

## 文档

### `const DataSetStorageLink({required this.deviceId, this.storageIndices = const [], this.extraJson = const {}})` <a id="datasetstoragelink-new"></a>
- **种类：** `DataSetStorageLink` 的构造函数。
- **来源：** `lib/features/datasets/models/dataset.dart`（第 22 行）。
- **用途：** 持有数据集对一台设备存储槽的引用，按位置索引。
- **输入：** `deviceId` 必填；`storageIndices` 默认 `[]`。
- **返回：** 新 `DataSetStorageLink`。
- **副作用：** 无。
- **算法：** 带默认的平凡字段赋值。
- **用法：**
  ```dart
  DataSetStorageLink(
    deviceId: entry.key,
    storageIndices: entry.value.toList()..sort(),
    extraJson: existingLinks[entry.key]?.extraJson ?? const {},
  ),
  ```
  （来自 [`dataset_edit_page.md`](../views/dataset_edit_page.md) 的 `_save`，每台至少选一个存储槽的设备一个）
- **备注：** `storageIndices` 是引用设备 `storage: List<StorageInfo>` 的普通位置，非稳定槽标识符——见上面文件总览和 [`remapDeviceStorageLinks`](../services/dataset_storage.md#remapdevicestoragelinks) 了解应用如何跨存储列表编辑保持它们有效。

### `Map<String, dynamic> toJson()` <a id="datasetstoragelink-tojson"></a>
- **种类：** `DataSetStorageLink` 的方法。
- **来源：** `lib/features/datasets/models/dataset.dart`（第 33 行）。
- **用途：** 把此存储链接序列化为持久化在数据集 `storageLinks` 数组内的 JSON。
- **输入：** 无。
- **返回：** 带 `deviceId` 和 `storageIndices`（原始 `List<int>`，即使空也总是包含）的 `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** `{...extraJson, 'deviceId': deviceId, 'storageIndices': storageIndices}`。
- **用法：** 被 [`DataSet.toJson`](#dataset-tojson) 为 `storageLinks` 每个条目调用，也被 [`mergeUnknownFieldsFrom`](#datasetstoragelink-mergeunknownfieldsfrom) 调用。
- **备注：** 与本应用大多数其他 `toJson` 不同，`storageIndices` 即使空也无条件写——无 `if (storageIndices.isNotEmpty)` 守卫。

### `factory DataSetStorageLink.fromJson(Map<String, dynamic> json)` <a id="datasetstoragelink-fromjson"></a>
- **种类：** `DataSetStorageLink` 的工厂构造函数。
- **来源：** `lib/features/datasets/models/dataset.dart`（第 44 行）。
- **用途：** 从 JSON 解析 `DataSetStorageLink`。
- **输入：** `json`。
- **返回：** 新 `DataSetStorageLink`；`extraJson` 持有不在 `_dataSetStorageLinkJsonKeys` 的每个键。
- **副作用：** 无。
- **算法：** `deviceId` 必填；`storageIndices` 把 `List<dynamic>` 映射为 `List<int>` 或缺席时默认 `[]`。
- **用法：** 被 [`DataSet.fromJson`](#dataset-fromjson) 为 `json['storageLinks']` 每个条目调用。
- **备注：** 无。

### `DataSetStorageLink mergeUnknownFieldsFrom(DataSetStorageLink other, {DataSetStorageLink? base})` <a id="datasetstoragelink-mergeunknownfieldsfrom"></a>
- **种类：** `DataSetStorageLink` 的方法。
- **来源：** `lib/features/datasets/models/dataset.dart`（第 60 行）。
- **用途：** 三方合并此链接的未知 JSON 字段与另一个的。
- **输入：** `other`；可选 `base`。
- **返回：** 带合并 `extraJson` 的新 `DataSetStorageLink`。
- **副作用：** 无。
- **算法：** 经 `DataSetStorageLink.fromJson` 重新解析 `{...toJson(), ...mergeUnknownJsonFields(...)}`——与本应用每个其他模型的合并方法相同形态（见 [`mergeUnknownJsonFields`](../../../shared/utils/json_preservation.md)）。
- **用法：** 被 [`DataSet.mergeUnknownFieldsFrom`](#dataset-mergeunknownfieldsfrom) 调用，对每对索引对齐的 `storageLinks` 条目一次。
- **备注：** 只合并 `extraJson`；已知字段（`deviceId`、`storageIndices`）仍来自 `this`。

### `DataSet({String? id, required this.name, required this.emoji, this.storageLinks = const [], DateTime? modifiedAt, this.extraJson = const {}})` <a id="dataset-new"></a>
- **种类：** `DataSet` 的构造函数。
- **来源：** `lib/features/datasets/models/dataset.dart`（第 89 行）。
- **用途：** 创建跨零个或多个设备存储槽的命名数据集，两者都未提供时生成新鲜 UUID `id` 和 UTC `modifiedAt`。
- **输入：** `name`、`emoji` 必填；`storageLinks` 默认 `[]`；`id`/`modifiedAt` 省略时自动生成。
- **返回：** 新 `DataSet`。
- **副作用：** 无（除 `Uuid().v4()`/`DateTime.now()`——无 IO）。
- **算法：** 初始化器列表中 `id = id ?? const Uuid().v4()`、`modifiedAt = modifiedAt ?? DateTime.now().toUtc()`；剩余字段普通赋值。
- **用法：**
  ```dart
  final ds = (_isEditing ? widget.dataSet! : DataSet(name: name, emoji: _emoji))
      .copyWith(name: name, emoji: _emoji, storageLinks: links);
  ```
  （来自 [`dataset_edit_page.md`](../views/dataset_edit_page.md) 的 `_save`——注意与 `network_edit_page.dart` 不同，此页只对"添加" case 构造全新 `DataSet`，增和改都复用 [`copyWith`](#copywith)，而非总是直接构造）
- **备注：** `emoji` 构造函数本身无默认（它是 `required`），即使 `_DataSetEditPageState` 总是以 `'📁'` 作为自己的初始本地状态提供；见下面 [`DataSet.fromJson`](#dataset-fromjson)，那里*缺失*持久化 `emoji` 确实默认 `'📁'`。

### `DataSet copyWith({String? name, String? emoji, List<DataSetStorageLink>? storageLinks, DateTime? modifiedAt})` <a id="copywith"></a>
- **种类：** `DataSet` 的方法。
- **来源：** `lib/features/datasets/models/dataset.dart`（第 104 行）。
- **用途：** 创建此数据集的副本并替换所选字段。
- **输入：** 任何要覆盖的字段；无任何字段的显式清除标志（不同于 `Network.copyWith`），因为每个 `DataSet` 字段要么必填要么有非 null 默认。
- **返回：** 新 `DataSet`——`id` 总是从 `this` 保留；`modifiedAt` 未显式传入时默认"现在"。
- **副作用：** 无。
- **算法：** 每个参数 `field ?? this.field`；`modifiedAt` 默认 `DateTime.now().toUtc()`。
- **用法：** 见上面 [`DataSet`](#dataset-new)——这是 `dataset_edit_page.dart` 产生保存记录的主要方式，新数据集和既有数据集都是。
- **备注：** `extraJson` 总是从 `this` 原样带过——只有 [`mergeUnknownFieldsFrom`](#dataset-mergeunknownfieldsfrom) 能改变它。

### `Map<String, dynamic> toJson()` <a id="dataset-tojson"></a>
- **种类：** `DataSet` 的方法。
- **来源：** `lib/features/datasets/models/dataset.dart`（第 125 行）。
- **用途：** 把此数据集序列化为持久化在 `dataset_data.json` 的 `datasets` 数组内的 JSON。
- **输入：** 无。
- **返回：** `Map<String, dynamic>`——先展开 `extraJson`，然后 `id`/`name`/`emoji` 总是、`storageLinks` 只在非空时、`modifiedAt` 为 ISO-8601。
- **副作用：** 无。
- **算法：** 展开-然后-已知字段形态；`storageLinks` 经每个链接的 [`toJson`](#datasetstoragelink-tojson) 嵌套。
- **用法：** 被 [`DataSetData.toJson`](#datasetdata-tojson) 为 `datasets` 每个条目调用，也被 [`mergeUnknownFieldsFrom`](#dataset-mergeunknownfieldsfrom) 调用。
- **备注：** 完全无存储链接的数据集（如刚创建后、选任何存储前）完全省略 `storageLinks` 键而非写 `[]`。

### `factory DataSet.fromJson(Map<String, dynamic> json)` <a id="dataset-fromjson"></a>
- **种类：** `DataSet` 的工厂构造函数。
- **来源：** `lib/features/datasets/models/dataset.dart`（第 140 行）。
- **用途：** 从 JSON 解析 `DataSet`。
- **输入：** `json`。
- **返回：** 新 `DataSet`；`extraJson` 持有不在 `_dataSetJsonKeys` 的每个键。
- **副作用：** 无。
- **算法：** 直接字段提取；`emoji` 键缺席时默认 `'📁'`；`storageLinks` 把每个条目经 [`DataSetStorageLink.fromJson`](#datasetstoragelink-fromjson) 映射或默认 `[]`；`modifiedAt` 经 `DateTime.parse`。
- **用法：** 被 [`DataSetData.fromJson`](#datasetdata-fromjson) 为 `json['datasets']` 每个条目调用。
- **备注：** 这里的 `'📁'` 默认是容忍缺失 `emoji` 的唯一地方——构造函数本身要求显式传 `emoji`。

### `DataSet mergeUnknownFieldsFrom(DataSet other, {DataSet? base})` <a id="dataset-mergeunknownfieldsfrom"></a>
- **种类：** `DataSet` 的方法。
- **来源：** `lib/features/datasets/models/dataset.dart`（第 158 行）。
- **用途：** 三方合并此数据集的未知 JSON 字段与另一个的，含每对索引对齐嵌套 `storageLinks` 自己的未知字段。
- **输入：** `other` — 另一侧；可选 `base` — 上次同步快照。
- **返回：** 新 `DataSet`——与 `this` 相同已知字段、`extraJson` 合并，且（`storageLinks` 非空时）每个链接的 `extraJson` 对照 `other`/`base` 的同索引链接合并。
- **副作用：** 无。
- **算法：** 1. 从 `toJson()` 开始，与每个其他模型相同经 `mergeUnknownJsonFields` 合并进 `extraJson`。2. `storageLinks.isNotEmpty` 时用为每个索引 `i` 合并 `storageLinks[i]` 对照 `other.storageLinks[i]`（`other` 链接更少时用空占位 `DataSetStorageLink(deviceId: '')`）和 `base.storageLinks[i]`（`base` 存在且有那么多链接时）构建的列表覆盖 `json['storageLinks']`。3. 经 `DataSet.fromJson` 重新解析整个映射。
- **用法：** 被 `sync_merge.dart` 的 `mergeRecords<DataSet>` 调用（见 [三方合并](../../../../algorithms/three-way-merge.md)）。
- **备注：** 这是本文件唯一合并触碰 `extraJson` 之外嵌套字段的模型——镜像 `Device.mergeUnknownFieldsFrom` 递归进 `recurringCosts` 的方式（见 [`device.md`](../../devices/models/device.md)）。每个链接的已知 `storageIndices` 仍无条件来自 `this`；只有链接级 `extraJson` 实际被合并。

### `const DataSetData({this.datasets = const [], this.extraJson = const {}})` <a id="datasetdata-new"></a>
- **种类：** `DataSetData` 的构造函数。
- **来源：** `lib/features/datasets/models/dataset.dart`（第 198 行）。
- **用途：** 持有完整持久化数据集列表。
- **输入：** `datasets` 默认 `[]`。
- **返回：** 新 `DataSetData`。
- **副作用：** 无。
- **算法：** 带默认的平凡字段赋值。
- **用法：**
  ```dart
  await save(DataSetData(datasets: list, extraJson: data.extraJson));
  ```
  （来自 [`dataset_storage.md`](../services/dataset_storage.md) 的 `addOrUpdate`/`delete`）
- **备注：** 无。

### `Map<String, dynamic> toJson()` <a id="datasetdata-tojson"></a>
- **种类：** `DataSetData` 的方法。
- **来源：** `lib/features/datasets/models/dataset.dart`（第 205 行）。
- **用途：** 把完整数据集列表序列化为写入 `dataset_data.json` 的 JSON。
- **输入：** 无。
- **返回：** 带 `datasets` 数组的 `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** `{...extraJson, 'datasets': datasets.map(toJson)}`。
- **用法：** 被 [`dataset_storage.md`](../services/dataset_storage.md) 的 `save` 调用。
- **备注：** 无。

### `factory DataSetData.fromJson(Map<String, dynamic> json)` <a id="datasetdata-fromjson"></a>
- **种类：** `DataSetData` 的工厂构造函数。
- **来源：** `lib/features/datasets/models/dataset.dart`（第 215 行）。
- **用途：** 从 `dataset_data.json` 存储的 JSON 解析 `DataSetData`。
- **输入：** `json`。
- **返回：** 新 `DataSetData`；`datasets` 键缺席时默认 `[]`。
- **副作用：** 无。
- **算法：** 把 `json['datasets']` 经 [`DataSet.fromJson`](#dataset-fromjson) 映射。
- **用法：** 被 [`dataset_storage.md`](../services/dataset_storage.md) 的 `load` 调用。
- **备注：** 无。
