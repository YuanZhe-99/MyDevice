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
static const _sidePenalty = 120.0;  // 1.8.3
static const _alignSnap = 12.0;     // 1.8.3
static const _trackSpacing = 8.0;   // 1.8.3
static const _minStub = 18.0;       // 1.8.3
static const _alignPasses = 9;      // 1.8.3
const _nearLine = 4.0;              // 1.8.3，顶层
```

`portChipSize` 远小于 `nodeWidth`/`nodeHeight`，反映了
[服务](../features/services-topology.md#frp-style-ingresspublic-port-modeling)
把端点/远程入口端口渲染为小圆角方块 chip、区别于主设备/服务/域名节点卡片的设计。`containerPadding` 保持小于 `rankGap` 的一半，因此相邻等级列中的分组框永不相接。

## 流水线

1. **设备分组**（仅在 `groupByDevice` 时）：至少有一个服务节点携带某设备 id 时，该设备被分组。其成员是带该设备 id 的服务、端点和远程入口节点。被分组设备的设备到服务边进入 `hiddenEdges`：分组框已表达相同信息，因此它们既不路由也不绘制。不承载任何服务的设备（端口转发跳所指的路由器）保持普通卡片，其远程入口保持自由 chip。
2. **路由行**：`_routeRows` 按源服务分组，为每条路由在虚拟轴上分配一行。分组时，源先按设备排序（先本地设备按名称，再远程设备），因此一台设备的服务占据连续的一段行。
3. **期望行**：`_desiredRows` 先从节点的路由（中位数）、再从其邻居、最后从稳定回退值派生每个节点的首选行。
4. **等级**：见 [语义等级](#semantic-ranks)。
5. **放置**：见 [行、顺序与 y 位置](#rows-order-and-y-positions) 与
   [对齐相连节点](#aligning-connected-nodes)。
6. **分组框**：见 [设备分组框](#device-containers)；之后再次对齐所有分组框之外的节点，并把整幅图上移回顶部。
7. 对已绘制（非隐藏）的边做**边路由**：见
   [边路由](#edge-routing-fast-clear-path-first-a-fallback)。
8. **轨道**：把共用一条通道的竖段错开到平行轨道上，必要时加宽通道，见 [把边错开到轨道上](#spreading-edges-onto-tracks)。

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
- 这些按行得到的位置只是对齐的起点（1.8.3）。

## 对齐相连节点 <a id="aligning-connected-nodes"></a>

行压缩是按等级进行的，所以同一个期望行在相邻两个等级里可能落在不同高度。1.8.2 中，一个没有端口芯片的服务（比如直接经 Tailscale 访问的服务）会让它下方的每个芯片都与自己的服务错开一行，于是每条服务到芯片的短边都成了阶梯线。自 1.8.3 起，`_alignRanks` 按分层（Sugiyama / Brandes–Köpf）绘图中坐标分配步骤的思路给出 y 坐标。它保持每个等级的顺序，因此 `crossings` 不变，只把节点移向与它相连的节点。

- **每个节点想要的位置**（`_desiredCenter`）：
  - *端口芯片*（本服务的紧凑端点，或某服务通向的远程入口，见 `_portOwners`）取其服务的中心；
  - 其他节点取它在其他等级上邻居中心的中位数；
  - 服务会越过自己的芯片，看芯片连到的节点，因此服务和它的芯片作为一个整体移动。
- **如何放置一个等级**（`_pava`，相邻违例合并算法）：在保持顺序、且相邻节点至少相隔 `rowGap`（卡片 112、芯片 88，与以前相同）的前提下，取最接近期望的位置。结果是精确解，复杂度 O(n)。
- **芯片间距**（`_alignGap`）：不同服务的两个芯片之间，至少保留两个服务之间需要的距离。没有芯片的服务在两个邻居的芯片之间不留芯片；没有这条规则，芯片列会比服务列排得更紧。
- **扫描次数**：交替上下扫描 `_alignPasses`（9）次，最后一次向下，所以芯片最终落在其服务的最终位置旁边。
- **收尾**：每个服务停在其下一列芯片的中点，没有这类芯片的节点让位（权重 0.01）。然后整幅图从 `padding` 开始。

分组框放好之后，`_alignFreeNodes` 对所有分组框之外的节点再做一次同样的对齐。`_placeContainers` 会把累积的下移量加到每个分组框之后的节点上，即使该等级没有分组框，所以 1.8.2 中域名可能被推到远低于其来源的位置。现在每个自由节点按同样的规则取期望位置，而覆盖其等级的每个分组框在 `_pava` 中是固定的重项，所以自由节点保持在每个分组框的同一侧，永不与之相接。域名因此落在它所挂的 Tailscale 卡片或公网 443 芯片旁边。自由节点下移后顶部可能空出来，所以整幅图会再上移回 `padding`。

## 设备分组框 <a id="device-containers"></a>

`_placeContainers` 按扁平放置中顶部的顺序遍历每个自由节点和每个分组框（分组框按其最高成员计；相同时分组框排在自由节点之前），并为每个等级维护一个**下限**：

- 自由节点按累计偏移下移，并移到其等级的下限之下。
- 分组框跨越其成员的等级，从那里每个下限之下开始。其成员回到相对最高成员的行目标（因此成员不会保留其他设备节点在其上方留下的间隙），位于 `containerHeaderHeight` 高的标题加 `containerPadding` 之下；同一等级的成员仍至少相隔 `verticalGap` 堆叠。分组框增加的高度会加到其后所有内容的累计偏移上，因此下方的行在各等级间保持对齐。然后分组框把它跨越的每个等级的下限抬到其底部，因此这些等级中的自由节点落在它下方。
- 标题是分组框左上角的标签页，高 `containerHeaderHeight`，最宽 `nodeWidth`；它就是设备节点的矩形，因此进入被分组设备的边（指名该设备的端口映射跳）终止于标题。保持标签页狭窄使边能从上方进入分组框。

不变量，每项都由针对示例图、FRP 演练图和共享 VPS 图的测试覆盖：每个成员位于其分组框内且在标题下方；其他节点不与分组框相接；分组框永不重叠；每条已绘制的边避开除其自身两端外的每个节点；`hiddenEdges` 恰好是被分组设备的设备到服务边；关闭分组时没有分组框也没有隐藏边。该遍是构造式的，因此不需要回退。

绘制器把分组框绘制在边之下：设备角色颜色的低 alpha 填充、细边框（远程设备或 VPS 为虚线），以及位于顶部的标题卡片。

## 边路由：先快速净空路径，A* 回退 <a id="edge-routing-fast-clear-path-first-a-fallback"></a>

**`_routeEdges(edges, rects, ranks, size)`** 从每个节点 `Rect` 构建障碍列表（按 `_routingClearance` 膨胀，使路径与边界保持可见间隙），构建共享路由网格基础（`_RoutingGridBase.fromObstacles`，每次搜索复用），并对每条边（最长的先）调用 **`_routeEdge`**，它：

1. 计算候选锚点对（离开和进入各节点的哪一侧），用 `_portOffsets` 提供的逐边偏移，使共享一侧的边呈扇形展开。偏移均匀分布，间距 9 px，侧边较短时更小，不会截断到同一点。随后 `_levelAnchors` 把两锚点相差不超过 `_alignSnap` 的边完全拉平，使对齐的节点之间是一条直线。
2. 为每个候选添加显式**退出/进入桩**（`_stubEnd`）：长 `_routingEscape` 的垂直段，使路径垂直离开和进入卡片。比所在列窄的节点（卡片列中的芯片），其桩会越过列边缘。桩被阻塞（`_stubBlocked`）时丢弃该候选。
3. 先试 **`_fastRouteBetween`**：对照每个障碍检查直线、L 形、Z 形和绕框形状。大多数边在此结束。
4. 若没有通畅的快速形状，或最佳形状沿一条已路由的水平线走，也运行 **`_routeBetween`**，取代价较低者。它在由障碍派生和段派生轨道构成的网格上进行 A* 搜索，代价包括：
   - 曼哈顿长度；
   - **转弯代价**；
   - **拥塞代价**：水平段落在已路由水平线上代价 180，相距不足 `_nearLine`（4 px）代价 58；竖段落在已路由竖线上只计 6，因为错开会把它们分开；每交叉一段代价 28。
5. 为候选评分（`_pathScore`：长度、转弯、拥塞），对每个位于背向另一端一侧的端点加 `_sidePenalty`，并保留最佳者。

已路由的段保存在 **`_RoutedSegments`** 中，按轴坐标索引，因此候选步骤的拥塞代价只访问其所在带内的段（二分查找），而非迄今已路由的每个段。在一次 A* 搜索中，每个网格步骤的长度加拥塞（或其被阻塞这一事实）只计算一次并缓存（一个步骤会从两端和多个方向到达），搜索的数组是类型化的（`Float64List`、`Int32List`）。所有代价都是 0.5 的倍数，因此这些都不改变任何一条路径；它只去除重复工作。在开发机上，1.5.6 之前耗时超过 20 秒的 43 节点、64 边图，现在不分组约一秒完成布局，分组约 0.2 s。性能测试中的 61 节点、91 边图，在 1.8.2 中于 Linux 开发机上分别约需 4.6 s 和 0.6 s；1.8.3 中约 1.0 s 和 0.3 s。这是因为竖段共线不再计入拥塞代价，不会再把边逼进很长的 A* 绕行。对齐与错开只需几毫秒。

## 把边错开到轨道上 <a id="spreading-edges-onto-tracks"></a>

等级之间只相隔 `rankGap`（38 px），节点矩形又按 `_routingClearance`（14）膨胀，只剩 10 px 的通道。因此在 1.8.2 中，两相邻列之间的每个拐弯都落在同一条竖线上：看不出哪个服务连到哪个芯片，也看不出哪个芯片连到 Caddy。`_nudgeSegments` 在路由之后解决这个问题。它结合了正交连线路由（libavoid）的*错开*步骤和分层路由器（ELK Layered）的*槽位分配*：

1. **单元**：把画布切成单元，即每一列、列后的通道，以及最后一列之后的边距。先拉直通道内的小 S 形折返（`_mergeJogs`）。
2. **单元组**：每条内部竖段，连同同一路径在该单元中的后续竖段，组成一个单元组。方向一致的竖段合成一条直段。单元组离其端点段到达的锚点至少 `_minStub`，离旁边的节点至少 `_routingClearance`。
3. **排序**：在每个单元中，y 范围相距不足两个轨道间距的单元组互相冲突。每个单元组插到与冲突单元组端点段交叉最少的位置（`_crossingsIfLeft`），所以扇入成为没有交叉的梳状。
4. **轨道**：每个单元组取早先冲突单元组中最高轨道的下一条，每组冲突单元组以 `_trackSpacing`（8 px）的间距居中。
5. **加宽**：轨道放不下的通道，通过对画布上每个 x 做一次单调拉伸来加宽。节点与标题整体平移，分组框拉伸，通道内的路径点随之缩放。任意两个 x 的先后都不变，所以每条路径仍避开原先避开的节点。只有需要的通道会变宽，通常增加几十像素。
6. **水平段**：仍落在另一条边水平线上的水平段，上下移开半个轨道或更多（`_separateHorizontals`）；锚点段则让锚点沿节点侧边滑动。
7. **安全检查**：若某条路径会碰到节点，保留其拉伸后未移动的版本。

之后绘制器把每个拐弯画成圆角（`service_topology_widgets.dart` 中的 `topologyEdgePath`，半径最大 6 px）。

## 可视化检查 <a id="visual-check"></a>

`test/service_topology_preview_test.dart` 会渲染真实的拓扑页面。它使用 `test/support/topology_fixtures.dart` 中的共享样例：一个在 1.8.2 中画得很乱的 homelab 的复刻、FRP 演练、共享 VPS，以及 61 节点的合成图，每个样例分组和不分组各渲染一次。测试从 Flutter SDK 加载 Roboto 与 Material 图标字体，文字和图标与应用中一致。输出为 PNG 和 `metrics.json`，包含交叉数、拐弯数、长度、共线长度、最小平行间距、画布尺寸和布局耗时。不给输出目录时跳过：

```bash
TOPOLOGY_PREVIEW=build/topology-preview flutter test test/service_topology_preview_test.dart
```

在布局改动前后各运行一次，对比图片。在 homelab 复刻上，1.8.3 把分组时的交叉从 22 降到 3、共线长度从 82 px 降到 0；不分组时共线长度从 599 px 降到 0。

## 性能备注

全屏拓扑把整个布局推迟到首帧之后，并缓存以图身份、路由身份、视口宽度（感知旋转）和布局选项为键的结果。因此选中节点、平移或缩放不会重新布局，而切换"按设备分组"会重新布局同一个图而不重建它。布局在 UI isolate 上运行；要移到 `compute()`，需要先把边路径改为按索引或值键控，因为 `edgePaths` 和 `hiddenEdges` 以 `ServiceTopologyEdge` 身份为键。

## 相关

- [服务与拓扑](../features/services-topology.md) — 此布局渲染的功能（总览/按设备/路由/端口视图、FRP 端口 chip 建模、引导式访问路径页）。
- [服务拓扑演练](../examples/service-topology-walkthrough.md) — 此布局会渲染其路由/跳结构的完整示例。
