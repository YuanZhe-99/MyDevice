# 数据集

模型来源：`lib/features/datasets/models/dataset.dart`。精确字段列表见 [数据格式 — DataSet / DataSetStorageLink](../data-formats.md#dataset--datasetstoragelink-libfeaturesdatasetsmodelsdatasetdart)。

## DataSet / DataSetStorageLink

- **`DataSet`：** `id`、`name`、`emoji`（默认 `'📁'`）、`storageLinks`（`List<DataSetStorageLink>`）、`modifiedAt`、`extraJson`。
- **`DataSetStorageLink`：** `deviceId` 加 `storageIndices`（`List<int>`）——该设备 `storage: List<StorageInfo>` 列表中此数据集跨度的位置。

单个 `DataSet` 可以位于多台设备的存储槽上（多个 `DataSetStorageLink` 条目），也可以位于同一设备的多个槽上（一个链接 `storageIndices` 的多个索引）。自 1.8.2 起，链接还可以指定该设备的整个 RAID 阵列（`arrayIds`）。

## 副本 <a id="copies"></a>

**每个被链接的存储槽都保存该数据集一份完整、对等的副本。** 数据集从不拆分到多块存储上，也没有哪个副本是"原件"：各副本是保持同步的对等体。因此数据集解析到的槽数就是它的**副本数**，只有一份副本的数据集没有备份。模型没有角色字段，也不需要；1.8.0 在 UI 中明确了这一含义（编辑页的"存放副本的存储"及其说明），而没有改动文件。

`lib/features/datasets/services/dataset_placement.dart` 中的 `resolveReplicas` 对照当前设备列表把数据集的链接转成它的副本，跳过指向已删除设备的链接、越界索引和重复列出的槽。所有计数副本的地方——分组列表和拓扑——都经过它，因此结果总是一致。见 [`dataset_placement.md`](../functions/features/datasets/services/dataset_placement.md)。

## 硬盘健康状况与 RAID 阵列 <a id="drive-health-and-raid-arrays"></a>

自 1.8.2 起，副本存放在一个**位置**（`StoragePlace`）上：设备的一个存储槽或一个 RAID 阵列（见 [设备](devices.md#drive-status-and-raid-arrays)）。`devicePlaces` 列出设备的各个位置——先是它的阵列，然后是不属于任何阵列的槽——编辑页、分组列表和拓扑都显示这些位置，因此阵列内的硬盘要经由阵列访问。仍直接指定阵列成员的链接（旧链接，或在建立阵列之前创建的链接）会保持其副本可见：该成员槽列在设备各位置之后。

位置有一个健康状况（`PlaceHealth`）：硬盘故障或离线时，该槽*不可用*；阵列的故障成员数在其级别的容错范围内时为*降级*，超出时为*不可用*。不可用位置上的副本仍会列出和绘制，但不计为可用：`availableCopyCount` 统计其余副本，共享的 `dataSetCopySummary` 将其表述为"n 份副本 · k 份不可用"（一份都不剩时以"没有可用副本"开头）。可用副本不超过一份的数据集以错误色绘制。编辑页显示每个位置的状态，但仍允许勾选。

## 列表分组 <a id="grouping-the-list"></a>

自 1.8.0 起，数据集列表的应用栏有一个**分组**菜单：*不分组*（默认）、*按设备* 或 *按存储*。该选择以 `datasetGroupMode` 本地保存在 `storage_config.json` 中（见 [数据格式](../data-formats.md#storage_configjson-key-datasetgroupmode)）。

- **按设备：** 每台至少保存一份副本的设备一组，按设备列表顺序。在多台设备上有副本的数据集出现在每台设备下；在同一设备两个槽上有副本的数据集在该设备下只出现一次。
- **按存储：** 每个位置一组——RAID 阵列（"设备 · RAID 5 · 名称"）或槽（"设备 · 存储"），阵列在前。槽由 `storageSlotLabel` 命名：槽的摘要（如"8 TB HDD"），空槽为"存储 n"，同一设备两个槽读起来相同时加 `#n` 后缀。
- **未存放在任何存储上：** 最后一组，收纳解析不到任何副本的数据集（没有链接，或只有悬空链接）。

在分组中，列表块的副标题显示副本数以及数据集的其他位置（"其他位置：…"）；只有一份副本的数据集以错误色显示*仅一份副本*，故障硬盘上的副本会被标为不可用（见 [上文](#drive-health-and-raid-arrays)）。分组保持每组内的排序顺序，一列时保留滑动删除、多列时保留菜单块，并隐藏*调整顺序*，因为一个数据集可能位于多个组中。

## 资料集拓扑 <a id="data-set-topology"></a>

数据集列表应用栏中的账户树操作打开一个全屏拓扑（`dataset_topology_page.dart`，由 `dataset_topology.dart` 中纯函数式的 `DataSetTopologyLayout` 布局）：

- **嵌套框。** 每台设备是一个带图标和名称的大框；它的位置——RAID 阵列（图层图标），然后是不属于任何阵列的槽——是堆叠在其中的中框；位置上的每份数据集副本是其中的小框，每行两个，带 `×n` 副本数徽章（部分副本不可用时为 `×可用数/n`）。故障或离线的硬盘以及已失效的阵列带错误色边框和图标，降级的阵列只带图标；不可用位置上的副本变灰并加删除线。图例解释该标记。没有存储槽的设备从不绘制；有存储但没有副本的设备只在*显示没有资料集的设备*打开时绘制。
- **同步连线。** 自 1.8.1 起默认关闭（应用栏中的时间线操作可将其打开；该选择不会保存）。打开时，同一数据集的各副本由柔和曲线相连——按绘制顺序穿过各副本的一条链，而不是每对之间一条线，因此四份副本是三条线。一个数据集的副本和连线保持同一种颜色（其 id 的稳定哈希）；只有一份副本的数据集改用错误色绘制。
- **排布。** 自 1.8.1 起设备按列紧凑排布，每台设备放入当前最短的一列，因此较高的设备（存储很多）只是让其所在列变长，后续设备则填充其他列。列数取画布最接近正方形到 16:10 的那个（宽 / 高介于 1 和 1.6 之间；相同时取较小的画布），与窗口尺寸无关——其余交给平移和缩放。设备顺序是贪心的：先放保存数据集最多的设备，然后每次放与已放置设备共享数据集最多的设备，因此互相同步的设备并排。
- **选择。** 点按一份副本会点亮该数据集的所有副本、它们的存储和设备，以及它们之间的连线；点按存储或设备的标题会点亮其上的每个数据集及其在别处的所有副本。其余一切变暗。点按空白画布或选择 chip 清除选择。
- **详情。** 手机上是底部面板，分栏窗口上是画布旁的窗格：先是被点按的对象，然后其上每个数据集一张卡片，以"设备 – 存储"列出每份副本（位于所选框上的副本打勾，不可用的副本以错误色加删除线），并带编辑按钮。编辑器关闭后拓扑重新加载。
- **视图。** 与服务拓扑相同的单一画布：点按选择，拖动平移，捏合或 Ctrl + 滚轮缩放，滚轮平移；缩放、适应窗口和重置按钮；设备筛选；图例；带高亮的画布 PNG 导出。

筛选缩小的是绘制的内容，而不是计数的内容：副本的 `×n` 仍计入隐藏设备上的副本，通往隐藏副本的连线只是不绘制。

## 存储槽索引链接 <a id="storage-slot-index-linking"></a>

因为链接存储设备 `storage` 列表的普通整数索引而非每槽稳定标识符，**任何重排或移除设备存储槽的代码路径都必须保持数据集链接同步**——否则设备存储列表被编辑后链接静默开始指向错误物理槽（或不复存在的槽）。

## `remapDeviceStorageLinks()`

`DataSetStorage.remapDeviceStorageLinks()`（在 `lib/features/datasets/services/dataset_storage.dart`）是保持链接有效的函数。确认签名：

```dart
static Future<void> remapDeviceStorageLinks({
  required String deviceId,
  required int oldSlotCount,
  required Map<int, int> indexMap,
  Set<String>? keptArrayIds,
  Map<int, String> arrayOfSlot = const {},
})
```

- `indexMap` 把每个**旧**槽索引映射到编辑后的**新**槽索引。
- `keptArrayIds`（自 1.8.2 起）是编辑后该设备的阵列 id：不在其中的 `arrayIds` 被丢弃。`arrayOfSlot` 把**新**槽索引映射到它现在所属的阵列：指向这种槽的链接会移到该阵列（只加一次），因为阵列的数据算一份副本。阵列链接按 id 记录，因此槽的移动从不影响它们。
- `indexMap` 对每个索引 `0..oldSlotCount-1` 都是恒等映射（无实际移动），且 `keptArrayIds` 和 `arrayOfSlot` 都未提供时，函数不碰任何数据集地立即返回。
- 否则加载所有数据集，对每个 `deviceId` 匹配的 `DataSetStorageLink`，把 `storageIndices` 中每个索引经 `indexMap` 重映射：
  - 有映射的索引（`indexMap[idx] != null`）保留、重映射到其新位置——这是**槽移除/压实** case：幸存槽下移填充被移除槽留下的间隙，`indexMap` 反映新（压实）位置。
  - **无**映射的索引（完全移除、无对应新槽）从 `storageIndices` **丢弃**。
  - 既无槽也无阵列的链接被移除。
- 链接实际变化的任何 `DataSet` 获得 bump 的 `modifiedAt`，使修复经同步传播（见 [WebDAV 同步](../sync.md)）而非设备间静默发散。

## 设备编辑器集成 <a id="device-editor-integration"></a>

设备编辑器在用户编辑/重排/移除存储条目时跟踪每个存储行的**原始槽索引**，保存时带结果的旧→新索引映射调用 `remapDeviceStorageLinks()`。这正是 `AGENTS.md` 直接点名"任何重排或移除设备存储槽的新代码路径必须同样做"的原因——容易添加忘记此步骤并静默损坏数据集链接的新存储编辑 UI 路径。

## 相关

- [`dataset_topology.md`](../functions/features/datasets/services/dataset_topology.md) 和 [`dataset_topology_page.md`](../functions/features/datasets/views/dataset_topology_page.md) 了解拓扑的布局和页面。

- [设备](devices.md) 了解这些链接索引进的 `storage: List<StorageInfo>` 字段。
- [数据格式 — 交叉引用规则](../data-formats.md#cross-reference-rules) — 删除数据集删除其包含的存储链接；删除设备也必须清理其数据集链接。
