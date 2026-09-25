# 服务拓扑布局

来源：`lib/features/services/services/service_topology_layout.dart`（算法密集）。
本页是对方法的顶层描述，非逐行追踪。此布局服务的功能级行为见
[服务与拓扑](../features/services-topology.md)，每个声明见
[函数页](../functions/features/services/services/service_topology_layout.md)。

入口点是 `ServiceTopologyLayout.build(graph, routes, viewportWidth, {options})`。它返回一个
`ServiceTopologyLayout`，携带计算出的画布大小、每个节点的 `Rect`（按节点 id 键控）、分配给每个节点的等级、每条边的预路由折线（`List<Offset>`），以及在按设备分组时的设备分组框（`groupRects`）和分组框所隐含的边（`hiddenEdges`）。组件层只绘制这些，自己不做任何布局数学。

## 选项

`ServiceTopologyLayoutOptions` 持有一次布局的开关。它具有值相等性，因为页面的布局缓存键包含它。

| 选项 | 默认值 | 效果 |
|---|---|---|
| `groupByDevice` | `false`（拓扑页把它**打开**并提供切换开关） | 把每台承载服务的设备绘制为围住其成员的分组框。 |
| `alignDomainSinks` | `true` | 把每个终点域名放在最后一层等级。 |
| `crossingSweeps` | `4` | 可重排等级以消除交叉的重心扫描次数；`0` 保持基于行的顺序。 |

`groupByDevice` 的类默认值为关闭，因此裸 `build` 调用会路由每条边，包括分组所隐藏的设备到服务边。

## 布局常量

```dart
static const nodeWidth = 204.0;
static const nodeHeight = 76.0;
static const portChipSize = 52.0;
static const rankGap = 38.0;
static const verticalGap = 24.0;
static const padding = 24.0;
static const rowGap = 36.0;
static const containerHeaderHeight = 40.0;
static const containerPadding = 12.0;
static const _routingMargin = 72.0;
static const _routingClearance = 14.0;
static const _routingEscape = 18.0;
static const _routingTrackGap = 22.0;
```

`portChipSize` 远小于 `nodeWidth`/`nodeHeight`，反映了
[服务](../features/services-topology.md#frp-style-ingresspublic-port-modeling)
把端点/远程入口端口渲染为小圆角方块 chip、区别于主设备/服务/域名节点卡片的设计。`containerPadding` 保持小于 `rankGap` 的一半，因此相邻等级列中的分组框永不相接。

## 流水线

1. **设备分组**（仅在 `groupByDevice` 时）：至少有一个服务节点携带某设备 id 时，该设备被分组。其成员是带该设备 id 的服务、端点和远程入口节点。被分组设备的设备到服务边进入 `hiddenEdges`：分组框已表达相同信息，因此它们既不路由也不绘制。不承载任何服务的设备（端口转发跳所指的路由器）保持普通卡片，其远程入口保持自由 chip。
2. **路由行**：`_routeRows` 按源服务分组，为每条路由在虚拟轴上分配一行。分组时，源先按设备排序（先本地设备按名称，再远程设备），因此一台设备的服务占据连续的一段行。
3. **期望行**：`_desiredRows` 先从节点的路由（中位数）、再从其邻居、最后从稳定回退值派生每个节点的首选行。
4. **等级**：见 [语义等级](#semantic-ranks)。
5. **放置**：见 [行、顺序与 y 位置](#rows-order-and-y-positions)。
6. **分组框**：见 [设备分组框](#device-containers)。
7. 对已绘制（非隐藏）的边做**边路由**：见
   [边路由](#edge-routing-fast-clear-path-first-a-fallback)。

## 语义等级 <a id="semantic-ranks"></a>

节点的水平位置（"等级"）不采用固定角色列，而是从实际边图派生，然后压缩，使未用等级不拉伸画布：

- **`_nodeRanks`**：设备从等级 0 开始，其他节点从等级 1 开始；每条边把其目标推到比源高一级的等级（由 `rankLimit = max(2, nodeCount + 1)` 封顶，因此有环时也会终止）。**`_alignSiblingPortRanks`** 在同一循环中运行，把同一服务的兄弟端口 chip（FRP 入口端口和公网端口，见
  [服务](../features/services-topology.md#frp-style-ingresspublic-port-modeling)）拉到相同等级。
- **终点域名对齐**（`alignDomainSinks`）：传播之后，每个没有出边的域名节点被移到最高等级，因此最终地址在右侧读作一列，而不是按链长分散。
- 然后把稀疏等级稠密化为 `0..N`。
- **`_headerRanks`**（仅在分组时）：被分组的设备节点离开等级列，成为分组框标题；剩余等级再次稠密化，因此只含设备的列（通常是等级 0）消失。标题的等级取其第一个成员的等级。

## 行、顺序与 y 位置 <a id="rows-order-and-y-positions"></a>

`_placeNodes` 放置每个位于等级列中的节点：

- 每个等级的节点按期望行排序，再按角色、车道和标签排序，其行**按等级**压缩（`_compactRankRows`），因此只有其他等级需要的空白带不在此浪费空间。
- 分组时，`_keepGroupsTogether` 把某等级中每个分组框的成员上移到其第一个成员处，并按新顺序重新分配该等级已排序的行值。
- **交叉消减扫描**（`_sweepCrossings`，最多 `crossingSweeps` 遍）：交替的向下和向上遍按重心重排每个等级。重心是节点在较低等级（向下）或较高等级（向上）上邻居的平均行；分组框的成员作为一个整体移动。该等级已排序的行值按新顺序分配，因此行只被置换，原本笔直的链保持笔直。只有新顺序**严格降低**总交叉数时才保留，因此扫描绝不会让图变差；一遍没有改进后即提前停止。
- **交叉计数**（`countCrossings`，公开以便测试）：对每对边，在它们跨越的每条等级线上采样两者（长边的位置线性插值），并统计其顺序交换的次数。只共享端点的边不计数；同一等级内的边被忽略。布局把最终的计数报告为 `crossings`。
- **行高**（`_rowPositions`）：每个不同的行值与任一等级上该行最高的节点一样高；下一个值从低 `(next − this) × (height + rowGap)` 处开始。因此一行卡片的步距为 112 px（旧的固定步距为 120），一行端口 chip 只有 88，压缩产生的小数间隙保持其比例。
- 在一个等级内，节点的起点绝不少于上方节点之下 `verticalGap`；x 在该等级列中居中。

## 设备分组框 <a id="device-containers"></a>

`_placeContainers` 按扁平放置中顶部的顺序遍历每个自由节点和每个分组框（分组框按其最高成员计；相同时分组框排在自由节点之前），并为每个等级维护一个**下限**：

- 自由节点按累计偏移下移，并移到其等级的下限之下。
- 分组框跨越其成员的等级，从那里每个下限之下开始。其成员回到相对最高成员的行目标（因此成员不会保留其他设备节点在其上方留下的间隙），位于 `containerHeaderHeight` 高的标题加 `containerPadding` 之下；同一等级的成员仍至少相隔 `verticalGap` 堆叠。分组框增加的高度会加到其后所有内容的累计偏移上，因此下方的行在各等级间保持对齐。然后分组框把它跨越的每个等级的下限抬到其底部，因此这些等级中的自由节点落在它下方。
- 标题是分组框左上角的标签页，高 `containerHeaderHeight`，最宽 `nodeWidth`；它就是设备节点的矩形，因此进入被分组设备的边（指名该设备的端口映射跳）终止于标题。保持标签页狭窄使边能从上方进入分组框。

不变量，每项都由针对示例图、FRP 演练图和共享 VPS 图的测试覆盖：每个成员位于其分组框内且在标题下方；其他节点不与分组框相接；分组框永不重叠；每条已绘制的边避开除其自身两端外的每个节点；`hiddenEdges` 恰好是被分组设备的设备到服务边；关闭分组时没有分组框也没有隐藏边。该遍是构造式的，因此不需要回退。

绘制器把分组框绘制在边之下：设备角色颜色的低 alpha 填充、细边框（远程设备或 VPS 为虚线），以及位于顶部的标题卡片。

## 边路由：先快速净空路径，A* 回退 <a id="edge-routing-fast-clear-path-first-a-fallback"></a>

**`_routeEdges(edges, rects, ranks, size)`** 从每个节点 `Rect` 构建障碍列表（按 `_routingClearance` 膨胀，使路径与边界保持可见间隙），构建共享路由网格基础（`_RoutingGridBase.fromObstacles`，每次搜索复用），并对每条边（最长的先）调用 **`_routeEdge`**，它：

1. 计算候选锚点对（离开和进入各节点的哪一侧），用 `_portOffsets` 提供的逐边偏移，使共享一侧的边呈扇形展开。
2. 为每个候选添加显式**退出/进入桩**：短的垂直段（`_routingEscape`），使路径垂直离开和进入卡片；桩被阻塞（`_stubBlocked`）时丢弃该候选。
3. 先试 **`_fastRouteBetween`**：对照每个障碍检查直线、L 形、Z 形和绕框形状。大多数边在此结束。
4. 回退到 **`_routeBetween`**：在由障碍派生和段派生轨道构成的网格上进行 A* 搜索。其代价由曼哈顿长度、**转弯代价**和**拥塞代价**相加（复用已路由段的线代价 180，在 0.85 × 轨道间隙内平行运行代价 58，交叉一个代价 28），因此共享走廊的边分散到平行轨道上。
5. 为候选评分（`_pathScore`：长度、转弯、拥塞）并保留最佳者。

已路由的段保存在 **`_RoutedSegments`** 中，按轴坐标索引，因此候选步骤的拥塞代价只访问其所在带内的段（二分查找），而非迄今已路由的每个段。在一次 A* 搜索中，每个网格步骤的长度加拥塞（或其被阻塞这一事实）只计算一次并缓存（一个步骤会从两端和多个方向到达），搜索的数组是类型化的（`Float64List`、`Int32List`）。所有代价都是 0.5 的倍数，因此这些都不改变任何一条路径；它只去除重复工作。在开发机上，1.5.6 之前耗时超过 20 秒的 43 节点、64 边图，现在不分组约一秒完成布局，分组约 0.2 s；性能测试中的 61 节点、91 边图分别约 3.4 s 和 0.4 s。

## 性能备注

全屏拓扑把整个布局推迟到首帧之后，并缓存以图身份、路由身份、视口宽度（感知旋转）和布局选项为键的结果。因此在选择/移动模式间切换或选中节点不会重新布局，而切换"按设备分组"会重新布局同一个图而不重建它。布局在 UI isolate 上运行；要移到 `compute()`，需要先把边路径改为按索引或值键控，因为 `edgePaths` 和 `hiddenEdges` 以 `ServiceTopologyEdge` 身份为键。

## 相关

- [服务与拓扑](../features/services-topology.md) — 此布局渲染的功能（总览/按设备/路由/端口视图、FRP 端口 chip 建模、引导式访问路径页）。
- [服务拓扑演练](../examples/service-topology-walkthrough.md) — 此布局会渲染其路由/跳结构的完整示例。
