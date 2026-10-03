# lib/features/datasets/services/dataset_placement.dart

纯函数辅助（自 1.8.0 起），对照当前设备列表把数据集的 `storageLinks`（[`../models/dataset.md`](../models/dataset.md)）转成它的**副本**，并为列表页对数据集分组。每个被链接的存储槽都保存一份完整、对等的副本——见 [数据集](../../../../features/datasets.md#copies)——因此 `resolveReplicas` 返回的副本数就是其他所有地方显示的副本数。被 [`dataset_list_page.md`](../views/dataset_list_page.md)、[`dataset_topology.md`](dataset_topology.md) 和 [`dataset_topology_page.md`](../views/dataset_topology_page.md) 使用。

`enum DataSetGroupMode { none, device, storage }`——列表的分组方式，按名称持久化为 `datasetGroupMode`——没有值得单列一行的成员。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `DataSetReplica`（构造函数） | 构造函数 | B | 一份副本：数据集、设备、存储索引。 |
| `storage` | getter（`DataSetReplica`） | B | 副本所在的 `StorageInfo`。 |
| [`resolveReplicas`](#resolvereplicas) | 顶层函数 | A | 数据集实际存在的副本，跳过悬空链接。 |
| `DataSetGroup`（构造函数） | 构造函数 | B | 一个列表分组：键、设备、可选的存储索引、数据集。 |
| `isUnlinked` | getter（`DataSetGroup`） | B | 是否为"未存放在任何存储上"组。 |
| [`groupDataSets`](#groupdatasets) | 顶层函数 | A | 按设备或按存储槽对数据集分组。 |
| [`storageSlotLabel`](#storageslotlabel) | 顶层函数 | A | 存储槽的名称，在其设备上唯一。 |
| `base` | 嵌套函数（`storageSlotLabel`） | B | 去重之前单个槽的标签。 |

行数（8）与 `grep -c 'Purpose:' dataset_placement.dart`（8）精确匹配。

## 文档

### `List<DataSetReplica> resolveReplicas(DataSet dataSet, List<Device> devices)` <a id="resolvereplicas"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/datasets/services/dataset_placement.dart`（第 41 行）。
- **用途：** 把数据集的存储链接解析为实际存在的副本。
- **输入：** `dataSet`；`devices` — 当前设备列表。
- **返回：** 每个被链接的槽一个 `DataSetReplica`，按链接顺序、再按索引顺序。
- **副作用：** 无。
- **算法：** 按 id 索引设备；对每个设备存在的链接，对其中每个在 `0 ≤ i < storage.length` 范围内、且该设备尚未见过的索引，添加一份副本。
- **用法：** `groupDataSets`；列表的分组副标题；`DataSetTopologyLayout.build`；拓扑详情。
- **备注：** 跳过指向已删除设备的链接、越界索引（[`remapDeviceStorageLinks`](dataset_storage.md#remapdevicestoragelinks) 正是为防止这种失效情形而存在）和重复列出的槽，因此长度是真实的副本数。

### `List<DataSetGroup> groupDataSets(List<DataSet> dataSets, List<Device> devices, DataSetGroupMode mode)` <a id="groupdatasets"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/datasets/services/dataset_placement.dart`（第 100 行）。
- **用途：** 按保存数据集的设备或存储槽对数据集分组。
- **输入：** `dataSets` — 按显示顺序；`devices`；`mode` — `device` 或 `storage`（断言不为 `none`）。
- **返回：** 非空的分组：键为 `device:<id>` 或 `storage:<id>:<index>`，按设备列表（及槽）顺序，任一数据集没有副本时最后是 `unlinked`。
- **副作用：** 无。
- **算法：** 对每个数据集解析其副本；没有副本 ⇒ 未存放；否则把它加入其副本所属的每个不同分组键各一次。然后按顺序遍历设备（及其槽），输出存在的分桶。
- **用法：** [`dataset_list_page.md`](../views/dataset_list_page.md) 中的 `_buildGroupedList`。
- **备注：** 数据集出现在它有副本的每个分组中——在设备模式下每台设备一次，无论它用了该设备的多少个槽。组内保持输入顺序。`test/dataset_topology_test.dart` 钉住了两种模式。

### `String storageSlotLabel(Device device, int index, String Function(int number) fallback)` <a id="storageslotlabel"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/datasets/services/dataset_placement.dart`（第 163 行）。
- **用途：** 为存储槽命名，使其在所属设备上唯一。
- **输入：** `device`、`index`；`fallback` — 以从 1 开始的编号生成本地化的"存储 n"。
- **返回：** `StorageInfo.displayString`，为空时用回退值；设备的另一个槽文本相同时追加 ` #n`。
- **副作用：** 无。
- **算法：** 把该槽的基础标签与其他每个槽的比较。
- **用法：** 列表的组标题和副标题；拓扑的存储框、选择 chip 和详情。
- **备注：** 一台 NAS 中两块相同的 8 TB 磁盘读作"8 TB HDD"和"8 TB HDD #2"。
