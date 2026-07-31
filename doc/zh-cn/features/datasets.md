# 数据集

模型来源：`lib/features/datasets/models/dataset.dart`。精确字段列表见 [数据格式 — DataSet / DataSetStorageLink](../data-formats.md#dataset--datasetstoragelink-libfeaturesdatasetsmodelsdatasetdart)。

## DataSet / DataSetStorageLink

- **`DataSet`：** `id`、`name`、`emoji`（默认 `'📁'`）、`storageLinks`（`List<DataSetStorageLink>`）、`modifiedAt`、`extraJson`。
- **`DataSetStorageLink`：** `deviceId` 加 `storageIndices`（`List<int>`）——该设备 `storage: List<StorageInfo>` 列表中此数据集跨度的位置。

单个 `DataSet` 可跨多台设备的存储槽（多个 `DataSetStorageLink` 条目），也可跨同一设备多个槽（一个链接 `storageIndices` 的多个索引）。

## 存储槽索引链接

因为链接存储设备 `storage` 列表的普通整数索引而非每槽稳定标识符，**任何重排或移除设备存储槽的代码路径都必须保持数据集链接同步**——否则设备存储列表被编辑后链接静默开始指向错误物理槽（或不复存在的槽）。

## `remapDeviceStorageLinks()`

`DataSetStorage.remapDeviceStorageLinks()`（在 `lib/features/datasets/services/dataset_storage.dart`）是保持链接有效的函数。确认签名：

```dart
static Future<void> remapDeviceStorageLinks({
  required String deviceId,
  required int oldSlotCount,
  required Map<int, int> indexMap,
})
```

- `indexMap` 把每个**旧**槽索引映射到编辑后的**新**槽索引。
- `indexMap` 对每个索引 `0..oldSlotCount-1` 都是恒等映射（无实际移动）时函数不碰任何数据集地立即返回。
- 否则加载所有数据集，对每个 `deviceId` 匹配的 `DataSetStorageLink`，把 `storageIndices` 中每个索引经 `indexMap` 重映射：
  - 有映射的索引（`indexMap[idx] != null`）保留、重映射到其新位置——这是**槽移除/压实** case：幸存槽下移填充被移除槽留下的间隙，`indexMap` 反映新（压实）位置。
  - **无**映射的索引（完全移除、无对应新槽）从 `storageIndices` **丢弃**。
- 链接实际变化的任何 `DataSet` 获得 bump 的 `modifiedAt`，使修复经同步传播（见 [WebDAV 同步](../sync.md)）而非设备间静默发散。

## 设备编辑器集成

设备编辑器在用户编辑/重排/移除存储条目时跟踪每个存储行的**原始槽索引**，保存时带结果的旧→新索引映射调用 `remapDeviceStorageLinks()`。这正是 `AGENTS.md` 直接点名"任何重排或移除设备存储槽的新代码路径必须同样做"的原因——容易添加忘记此步骤并静默损坏数据集链接的新存储编辑 UI 路径。

## 相关

- [设备](devices.md) 了解这些链接索引进的 `storage: List<StorageInfo>` 字段。
- [数据格式 — 交叉引用规则](../data-formats.md#cross-reference-rules) — 删除数据集删除其包含的存储链接；删除设备也必须清理其数据集链接。
