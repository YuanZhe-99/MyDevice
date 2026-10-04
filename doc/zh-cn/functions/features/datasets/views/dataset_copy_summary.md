# lib/features/datasets/views/dataset_copy_summary.dart

两个顶层辅助（自 1.8.2 起），表述数据集有多少份副本以及其中有多少份仍然计数——故障或离线硬盘上的副本，或失去的硬盘数超过其容错能力的 RAID 阵列上的副本，都是不可用的（见 [`dataset_placement.md`](../services/dataset_placement.md#health)）。两者都返回记录 `({String text, bool warn})`：文本，以及是否为警告（可用副本不超过一份）。由分组列表（[`dataset_list_page.md`](dataset_list_page.md#groupedsubtitle)）和拓扑的框与详情（[`dataset_topology_page.md`](dataset_topology_page.md)）共用。见 [数据集](../../../../features/datasets.md#copies)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`dataSetCopySummary`](#datasetcopysummary) | 顶层函数 | A | 表述副本数和不可用副本；标记可用副本不超过一份的情况。 |
| [`dataSetReplicaSummary`](#datasetreplicasummary) | 顶层函数 | A | 对已解析副本运行 `dataSetCopySummary`。 |

行数（2）与 `grep -c 'Purpose:' dataset_copy_summary.dart`（2）精确匹配。

## 文档

### `({String text, bool warn}) dataSetCopySummary(AppLocalizations l10n, {required int total, required int available})` <a id="datasetcopysummary"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/datasets/views/dataset_copy_summary.dart`（第 13 行）。
- **用途：** 描述数据集有多少份副本以及其中有多少份仍然计数。
- **输入：** `l10n`；`total` — 全部副本；`available` — 所在位置不为 `unavailable` 的副本。
- **返回：** 文本和 `warn`——只剩不超过一份可用副本时为 true。
- **副作用：** 无。
- **算法：** 没有不可用副本 ⇒ `total ≤ 1` 时为 `dataSetSingleCopy`（"仅一份副本"），否则为 `dataSetCopies(total)`；`warn` 为 `total ≤ 1`。否则以 ` · ` 连接：`dataSetNoAvailableCopy`（"没有可用副本"，仅当 `available == 0`）、`dataSetCopies(total)` 和 `dataSetCopiesUnavailable(total − available)`；`warn` 为 `available ≤ 1`。
- **用法：** [`dataset_topology_page.md`](dataset_topology_page.md) 中的副本框和详情的副本标题，取自节点的 `copyCount` 和 `availableCount`；以及经由 `dataSetReplicaSummary`。
- **备注：** 没有故障位置时，措辞与 1.8.1 完全相同。

### `({String text, bool warn}) dataSetReplicaSummary(AppLocalizations l10n, List<DataSetReplica> replicas)` <a id="datasetreplicasummary"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/datasets/views/dataset_copy_summary.dart`（第 40 行）。
- **用途：** 对已解析的副本运行 `dataSetCopySummary`。
- **输入：** `l10n`；`replicas` — 来自 [`resolveReplicas`](../services/dataset_placement.md#resolvereplicas)。
- **返回：** 同 `dataSetCopySummary`。
- **副作用：** 无。
- **算法：** `total: replicas.length`，`available: availableCopyCount(replicas)`。
- **用法：** [`dataset_list_page.md`](dataset_list_page.md#groupedsubtitle) 中的 `_groupedSubtitle`；[`dataset_topology_page.md`](dataset_topology_page.md) 中的 `_buildDataSetCard`。
- **备注：** 无。
