# lib/features/datasets/services/dataset_placement.dart

纯函数辅助（自 1.8.0 起），对照当前设备列表把数据集的 `storageLinks`（[`../models/dataset.md`](../models/dataset.md)）转成它的**副本**，并为列表页对数据集分组。副本存放在一个**位置**上——设备的一个存储槽，或（自 1.8.2 起）一个 RAID 阵列（`StorageArray`，见 [`../../devices/models/device.md`](../../devices/models/device.md)）。每个被链接的位置都保存一份完整、对等的副本——见 [数据集](../../../../features/datasets.md#copies)——因此 `resolveReplicas` 返回的副本数就是其他所有地方显示的副本数，而 `availableCopyCount` 是其中所在位置仍可读取的副本数。被 [`dataset_list_page.md`](../views/dataset_list_page.md)、[`dataset_copy_summary.md`](../views/dataset_copy_summary.md)、[`dataset_topology.md`](dataset_topology.md) 和 [`dataset_topology_page.md`](../views/dataset_topology_page.md) 使用。

`enum DataSetGroupMode { none, device, storage }`——列表的分组方式，按名称持久化为 `datasetGroupMode`——和 `enum PlaceHealth { ok, degraded, unavailable }`（1.8.2）——位置是否仍能提供其副本——都没有值得单列一行的成员。`StoragePlace` 类本身没有 `Purpose:` 注释；它的构造函数和 getter 有。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `StoragePlace.slot` | 构造函数 | B | 槽位置：设备和一个有效的存储索引。 |
| `StoragePlace.array` | 构造函数 | B | 阵列位置：设备和它的一个 `storageArrays`。 |
| `isArray` | getter（`StoragePlace`） | B | 是否为阵列位置。 |
| `key` | getter（`StoragePlace`） | B | 在设备上唯一的键：槽索引的文本，或 `a:<arrayId>`。 |
| `memberIndices` | getter（`StoragePlace`） | B | 阵列中不重复且在范围内的成员槽；槽位置为空。 |
| `failedDrives` | getter（`StoragePlace`） | B | 位置中故障或离线的硬盘数（槽为 0/1）。 |
| [`health`](#health) | getter（`StoragePlace`） | A | 根据硬盘和 RAID 级别得出的位置 `PlaceHealth`。 |
| [`devicePlaces`](#deviceplaces) | 顶层函数 | A | 设备的各位置：先阵列，后不属于任何阵列的槽。 |
| `DataSetReplica`（构造函数） | 构造函数 | B | 一份副本：数据集和保存它的位置。 |
| `device` | getter（`DataSetReplica`） | B | 保存副本的设备。 |
| `storageIndex` | getter（`DataSetReplica`） | B | 槽副本的槽；阵列副本为 null。 |
| `isAvailable` | getter（`DataSetReplica`） | B | 副本所在位置为 `unavailable` 时为 false。 |
| [`resolveReplicas`](#resolvereplicas) | 顶层函数 | A | 数据集实际存在的副本，跳过悬空链接。 |
| `availableCopyCount` | 顶层函数 | B | 统计所在位置不为 `unavailable` 的副本。 |
| `DataSetGroup`（构造函数） | 构造函数 | B | 一个列表分组：键、设备、可选的位置、数据集。 |
| `storageIndex` | getter（`DataSetGroup`） | B | 槽分组的槽；其他情况为 null。 |
| `isUnlinked` | getter（`DataSetGroup`） | B | 是否为"未存放在任何存储上"组。 |
| [`groupDataSets`](#groupdatasets) | 顶层函数 | A | 按设备或按位置对数据集分组。 |
| `_placesWithMembers` | 顶层函数（私有） | B | `devicePlaces` 加上各阵列的成员槽。 |
| `placeLabel` | 顶层函数 | B | 为位置命名：阵列的 `displayString`，或 `storageSlotLabel`。 |
| [`storageSlotLabel`](#storageslotlabel) | 顶层函数 | A | 存储槽的名称，在其设备上唯一。 |
| `base` | 嵌套函数（`storageSlotLabel`） | B | 去重之前单个槽的标签。 |

行数（22）与 `grep -c 'Purpose:' dataset_placement.dart`（22）精确匹配。

## 文档

### `PlaceHealth get health` <a id="health"></a>
- **种类：** getter（`StoragePlace`）。
- **来源：** `lib/features/datasets/services/dataset_placement.dart`（第 93 行）。
- **用途：** 判断位置能否提供其副本。
- **输入：** 无。
- **返回：** `PlaceHealth.ok`、`degraded` 或 `unavailable`。
- **副作用：** 无。
- **算法：** 没有故障硬盘 ⇒ `ok`。硬盘故障或离线的槽 ⇒ `unavailable`。阵列把故障成员数与 `RaidLevel.faultTolerance(memberCount)` 比较：在其范围内 ⇒ `degraded`，超出 ⇒ `unavailable`；没有定义容错能力的级别（`other`）⇒ `degraded`。
- **用法：** `DataSetReplica.isAvailable`；列表和拓扑的健康标记及副本摘要。
- **备注：** `StorageInfo.isHealthy` 为 false（状态为 `failed` 或 `offline`）时硬盘算作故障。成员是在范围内、去重后的 `memberIndices`。

### `List<StoragePlace> devicePlaces(Device device)` <a id="deviceplaces"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/datasets/services/dataset_placement.dart`（第 109 行）。
- **用途：** 按显示顺序列出设备的各位置。
- **输入：** `device`。
- **返回：** 按存储顺序为每个 `storageArrays` 条目一个阵列位置，然后为每个不属于任何阵列的槽一个槽位置。
- **副作用：** 无。
- **算法：** 添加每个阵列时收集其成员索引，然后按索引顺序添加剩余的槽。
- **用法：** 数据集编辑器的存储选择器、拓扑的存储框，以及（经 `_placesWithMembers`）`groupDataSets`。
- **备注：** 成员槽经由其阵列访问；仍直接指定成员槽的链接依然由 `resolveReplicas` 解析并由 `groupDataSets` 显示。

### `List<DataSetReplica> resolveReplicas(DataSet dataSet, List<Device> devices)` <a id="resolvereplicas"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/datasets/services/dataset_placement.dart`（第 166 行）。
- **用途：** 把数据集的存储链接解析为实际存在的副本。
- **输入：** `dataSet`；`devices` — 当前设备列表。
- **返回：** 每个被链接的槽和阵列一个 `DataSetReplica`，按链接顺序，同一链接内槽在阵列之前。
- **副作用：** 无。
- **算法：** 按 id 索引设备；对每个设备存在的链接，为每个在 `0 ≤ i < storage.length` 范围内的索引添加一个槽位置，然后为每个指向现有阵列的 `arrayIds` 条目添加一个阵列位置；以 `<deviceId>#<index>` / `<deviceId>#a:<arrayId>` 为键的 `seen` 集合去除重复。
- **用法：** `groupDataSets`；列表的副标题和副本摘要；`DataSetTopologyLayout.build`；拓扑详情。
- **备注：** 跳过指向已删除设备的链接、越界索引（[`remapDeviceStorageLinks`](dataset_storage.md#remapdevicestoragelinks) 正是为防止这种失效情形而存在）、已移除的阵列和重复列出的位置，因此长度是真实的副本数——包含故障位置；`availableCopyCount` 给出计数的副本。

### `List<DataSetGroup> groupDataSets(List<DataSet> dataSets, List<Device> devices, DataSetGroupMode mode)` <a id="groupdatasets"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/datasets/services/dataset_placement.dart`（第 256 行）。
- **用途：** 按保存数据集的设备或位置对数据集分组。
- **输入：** `dataSets` — 按显示顺序；`devices`；`mode` — `device` 或 `storage`（断言不为 `none`）。
- **返回：** 非空的分组：键为 `device:<id>` 或 `storage:<id>:<place key>`，按设备列表顺序（存储分组按位置：阵列、空闲槽，然后是仍被直接链接的成员槽），任一数据集没有副本时最后是 `unlinked`。
- **副作用：** 无。
- **算法：** 对每个数据集解析其副本；没有副本 ⇒ 未存放；否则把它加入其副本所属的每个不同分组键各一次。然后按顺序遍历设备（及 `_placesWithMembers`），输出存在的分桶。
- **用法：** [`dataset_list_page.md`](../views/dataset_list_page.md) 中的 `_buildGroupedList`。
- **备注：** 数据集出现在它有副本的每个分组中——在设备模式下每台设备一次，无论它用了该设备的多少个位置。组内保持输入顺序。槽的位置键就是它的索引，因此槽分组键与 1.8.0 相同。`test/dataset_topology_test.dart` 和 `test/storage_raid_health_test.dart` 钉住了分组。

### `String storageSlotLabel(Device device, int index, String Function(int number) fallback)` <a id="storageslotlabel"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/datasets/services/dataset_placement.dart`（第 341 行）。
- **用途：** 为存储槽命名，使其在所属设备上唯一。
- **输入：** `device`、`index`；`fallback` — 以从 1 开始的编号生成本地化的"存储 n"。
- **返回：** `StorageInfo.displayString`，为空时用回退值；设备的另一个槽文本相同时追加 ` #n`。
- **副作用：** 无。
- **算法：** 把该槽的基础标签与其他每个槽的比较。
- **用法：** 槽位置的 `placeLabel`（组标题、副标题、拓扑框、选择 chip 和详情）；编辑器的存储块。
- **备注：** 一台 NAS 中两块相同的 8 TB 磁盘读作"8 TB HDD"和"8 TB HDD #2"。
