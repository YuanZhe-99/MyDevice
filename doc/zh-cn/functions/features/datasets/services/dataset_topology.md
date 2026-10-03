# lib/features/datasets/services/dataset_topology.dart

资料集拓扑（自 1.8.0 起）纯函数式、确定性的布局，由 [`dataset_topology_page.md`](../views/dataset_topology_page.md) 绘制。它嵌套三种框——设备（大）、其存储槽（中）以及每个槽上的数据集副本（小）——并用同步连线连接每个数据集的各副本。功能说明见 [数据集](../../../../features/datasets.md#data-set-topology)。

`enum DataSetTopologyNodeKind { device, storage, copy }` 不单列。`DataSetTopologyLayout` 的尺寸常量在源码中有文档，不单列：`padding` 24、`deviceGap` 32、`deviceHeader` 44、`devicePadding` 12、`storageHeader` 34、`storagePadding` 8、`storageGap` 10、`copyWidth` 140、`copyHeight` 36、`copyGap` 8、`copiesPerRow` 2、`emptyStorageBody` 24，以及派生的 `storageWidth`（304）和 `deviceWidth`（328）。

节点 id：`device:<deviceId>`、`storage:<deviceId>:<index>`、`copy:<dataSetId>@<deviceId>:<index>`。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `DataSetTopologyNode`（构造函数） | 构造函数 | B | 一个已放置的框：id、种类、矩形、设备、槽、数据集、副本数。 |
| `DataSetTopologyLink`（构造函数） | 构造函数 | B | 一个数据集两个副本框之间的一条同步连线。 |
| `DataSetTopologyHighlight`（构造函数） | 构造函数 | B | 一次选择点亮的框和数据集。 |
| `DataSetTopologyLayout`（构造函数） | 构造函数 | B | 结果：尺寸、节点、连线，以及 id 索引。 |
| `node` | 方法（`DataSetTopologyLayout`） | B | 按 id 查找框。 |
| `isEmpty` | getter（`DataSetTopologyLayout`） | B | 是否什么都不绘制。 |
| [`build`](#build) | 静态方法（`DataSetTopologyLayout`） | A | 按视口宽度、筛选和空设备开关布局拓扑。 |
| `copyNodeId` | 静态方法（`DataSetTopologyLayout`） | B | 副本框的 id。 |
| [`_orderByAffinity`](#orderbyaffinity) | 静态方法（`DataSetTopologyLayout`） | A | 为设备排序，使共享数据集的设备相邻。 |
| [`highlightFor`](#highlightfor) | 方法（`DataSetTopologyLayout`） | A | 选中的框点亮哪些框和数据集。 |

行数（10）与 `grep -c 'Purpose:' dataset_topology.dart`（10）精确匹配。

## 文档

### `static DataSetTopologyLayout build({required List<Device> devices, required List<DataSet> dataSets, required double viewportWidth, Set<String> deviceIds = const {}, bool showEmptyDevices = false})` <a id="build"></a>
- **种类：** `DataSetTopologyLayout` 的静态方法。
- **来源：** `lib/features/datasets/services/dataset_topology.dart`（第 157 行）。
- **用途：** 布局拓扑。
- **输入：** `devices` — 其顺序用于打破平局；`dataSets` — 显示顺序；`viewportWidth`；`deviceIds` — 非空 ⇒ 只包含这些设备；`showEmptyDevices` — 也绘制有存储但没有副本的设备。
- **返回：** 布局；没有符合条件的内容时为 `Size.zero` 且无节点。
- **副作用：** 无。
- **算法：** 1. 解析每个数据集的副本（[`resolveReplicas`](dataset_placement.md#resolvereplicas)），并按槽分桶。2. 取有存储、通过筛选且（除非 `showEmptyDevices`）保存有副本的设备；用 `_orderByAffinity` 排序。3. 每行放 `floor((width − 2·padding + gap) / (deviceWidth + gap))` 台设备，至少一台。4. 在每台设备中，把它的槽堆叠在 44 px 标题之下；槽体每行放两个副本（或 24 px 的空槽体）。设备的高度随其槽变化；一行与其最高的设备一样高。5. 对每个数据集，按放置顺序（逐行、逐设备、逐槽）串联其副本框，每对相邻副本一条连线。
- **用法：** 拓扑页的 `_layoutFor`，按数据身份、筛选、开关和取整后的宽度缓存。
- **备注：** 副本的 `copyCount` 计入其数据集的每份副本，包括筛选隐藏的设备上的副本，而连线只在已绘制的副本之间绘制。`test/dataset_topology_test.dart` 钉住了嵌套、连线、排序、换行、筛选和空的情形。

### `static List<Device> _orderByAffinity(List<Device> devices, Map<String, Set<String>> onDevice)` <a id="orderbyaffinity"></a>
- **种类：** `DataSetTopologyLayout` 的静态方法。
- **来源：** `lib/features/datasets/services/dataset_topology.dart`（第 314 行）。
- **用途：** 为设备排序，使共享数据集的设备相邻。
- **输入：** `devices` — 按列表顺序；`onDevice` — 设备 id → 它保存的数据集 id。
- **返回：** 重新排序后的设备。
- **副作用：** 无。
- **算法：** 贪心：反复取剩余设备中与已放置设备共享数据集最多的一台，平局时取数据集更多的，再按列表顺序。因此第一台是保存数据集最多的设备。
- **用法：** `build`。
- **备注：** 确定性，对设备数为 O(n²)——在清单规模下没有问题。

### `DataSetTopologyHighlight? highlightFor(String selectedId)` <a id="highlightfor"></a>
- **种类：** `DataSetTopologyLayout` 的方法。
- **来源：** `lib/features/datasets/services/dataset_topology.dart`（第 350 行）。
- **用途：** 解析一次选择点亮哪些框和数据集。
- **输入：** `selectedId` — 节点 id。
- **返回：** 高亮；id 不在此布局中时为 null。
- **副作用：** 无。
- **算法：** 1. 被点亮的数据集：副本即其自身的数据集；存储或设备则是在其上有副本的每个数据集。2. 被点亮的框：所选框，加上被点亮数据集的每个已绘制副本及其存储和设备。
- **用法：** 拓扑页的画布，每次构建时。
- **备注：** 因此选中一个框会显示其上的一切被镜像到了哪里。
