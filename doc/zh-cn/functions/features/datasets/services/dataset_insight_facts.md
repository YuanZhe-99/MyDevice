# lib/features/datasets/services/dataset_insight_facts.dart

资料集列表端侧 AI 洞察卡片背后的纯函数事实构建器，1.11.1 新增。
`buildDatasetInsightFacts` 把[资料集页面](../views/dataset_list_page.md)已有的资料集和设备转成
[`InsightFacts`](../../ai/services/insight_prompts.md)：没有、恰好一个、两个及以上可用副本的资料集数量，
副本全部在同一台设备上的数量，有副本位于降级 RAID 阵列或已退役/售出设备上的数量，以及风险最高的两个资料集。
副本来自 [`resolveReplicas`](dataset_placement.md)，并按 `availableCopyCount` 的规则计数，因此卡片与列表的
副本摘要一致。卡片本身是 [`AiInsightCard`](../../ai/widgets/ai_insight_card.md)。参见
[端侧 AI — 每张卡片获得的内容](../../../../on-device-ai.md#what-each-card-is-given)。

## 声明

| 声明 | 类型 | 层级 | 用途 |
|---|---|---|---|
| `datasetInsightMaxNames` | 顶层 `const int` | B | 事实中最多点名的风险资料集数量（2）。 |
| `datasetInsightSlots` | 顶层 `const List<InsightSlot>` | B | 卡片的三个槽位：`redundancySummary`、`healthRisk`、`backupAdvice`。 |
| [`buildDatasetInsightFacts`](#builddatasetinsightfacts) | 顶层函数 | A | 构建资料集卡片的事实。 |

`grep -c 'Purpose:' lib/features/datasets/services/dataset_insight_facts.dart` 报告 1，对应
`buildDatasetInsightFacts`；两个常量只有普通的 `///` 描述。

## 文档

### `InsightFacts? buildDatasetInsightFacts({required DateTime now, required List<DataSet> datasets, required List<Device> devices, bool includeNames = true})` <a id="builddatasetinsightfacts"></a>
- **类型：** 顶层函数
- **源文件：** `lib/features/datasets/services/dataset_insight_facts.dart`
- **用途：** 构建资料集卡片的事实。
- **输入：** `now` —— 本地时间；`datasets`；`devices` —— 当前设备列表；`includeNames` —— 为 false 时
  用于不点名任何资料集的回退版本。
- **返回：** 模块为 `datasets` 的 `InsightFacts?`——没有资料集时为 null。
- **副作用：** 无。
- **说明：**
  1. 对每个资料集解析其副本并保留可用的副本；按没有、一个、两个及以上计数；两个及以上可用副本共用同一个
     `device.id` 时计为单设备——一台机器故障就会全部丢失。
  2. 统计有副本位于 `degraded` 位置的资料集，以及有副本位于非在役设备上的资料集。放置不考虑生命周期；
     卡片报告它，而不改变计数规则。
  3. 对持有设备少于两台的资料集按可用副本数、设备数、名称排序，点名前两个（截断到 30 个字符，并加入
     `quotedTerms`）；`includeNames` 为 false 时只描述而不点名。
  4. 设备名称、表情符号、容量、备注和路径永远不会发送。
