# 服务拓扑布局

来源：`lib/features/services/services/service_topology_layout.dart`（约 52 KB，算法密集）。本页是对方法的顶层描述，非逐行追踪——此布局服务的功能级行为见 [服务与拓扑](../features/services-topology.md)。

入口点是 `ServiceTopologyLayout.build(graph, routes, viewportWidth)`，它返回携带计算画布大小、每个节点的 `Rect`（按节点 id 键控）、分配给每个节点的等级，以及每条边预路由折线（`List<Offset>`）的 `ServiceTopologyLayout`——组件层只绘制这些，自己不做任何布局数学。

## 布局常量

来自源码确认的节点/边尺寸常量：

```dart
static const nodeWidth = 204.0;
static const nodeHeight = 76.0;
static const portChipSize = 52.0;
static const rankGap = 38.0;
static const verticalGap = 24.0;
static const padding = 24.0;
static const _routingMargin = 72.0;
static const _routingClearance = 14.0;
static const _routingEscape = 18.0;
static const _routingTrackGap = 22.0;
```

`portChipSize` 远小于 `nodeWidth`/`nodeHeight` 反映 [服务](../features/services-topology.md#frp-style-ingresspublic-port-modeling) 把端点/远程入口端口渲染为区别于主设备/服务/域节点卡片的小圆角方块 chip 的设计。

## 语义分层布局与动态图等级

节点水平位置（"等级"）而非固定角色列从实际边图派生，然后压缩，使未用等级不拉伸画布：

- **`_nodeRanks(graph, validEdges)`** — 等级传播遍：每个节点从等级 0 开始，重复 `ranks[edge.to] = max(ranks[edge.to], ranks[edge.from] + 1)` 遍历边（由 `rankLimit = max(2, nodeCount + 1)` 封顶，保证即使在有环图上终止），然后把结果的稀疏等级值向下重映射为稠密 `0..N` 序列（`uniqueRanks.toSet().toList()..sort()`）。
- **`_alignSiblingPortRanks(edges, nodeMap, ranks)`** — 次级遍，把兄弟端口节点（如 [服务](../features/services-topology.md#frp-style-ingresspublic-port-modeling) 描述的 FRP 入口/公共端口对）拉到自己与彼此相同的等级，否则其自然传播等级会分开它们，使成对端口读作视觉单元。
- **`_placeNodes(graph, nodeRanks, desiredRows)`** — 把节点放入等级列（`rankX`），并在每个等级内经 `_compactRankRows` / `_compactDesiredRows` / `_compactRowValueMap` **压缩行**，使只因*其他*等级需要那些行而存在的空白垂直带不浪费*此*等级空间。稀疏到压缩重映射的行匹配用小的浮点容忍（`_rowEpsilon`）经 `_compactRowValue`。
- **`_routeRows(graph, routes, nodeMap)`** 和 **`_desiredRows(...)`** 从节点参与哪条/哪些路由派生其首选行，使属于同一访问路由的节点倾向于落在相同视觉行/车道。

## 边路由：先快速净空路径，A* 回退

**`_routeEdges(validEdges, rects, ranks, size)`** 是边路由入口点。它从每个节点 `Rect` 构建障碍列表（经 `_RoutingGridBase.fromObstacles(obstacles, size)`——跨所有边搜索复用的共享路由网格/轨道结构，使障碍派生轨道不逐边重算），并对每条边调用 **`_routeEdge`**，它：

1. 经 `_portOffsets` 计算候选锚点对（从"从"节点哪侧退出、从"到"节点哪侧进入），排序使同等级/相邻等级边先获得合理锚点选择。
2. 对每个候选锚点对，计算显式**退出/进入桩**——强制路径垂直于节点边界离开/进入每个节点边缘的短垂直段（`_stubBlocked` 用 `_routingEscape`/`_routingClearance` 作为净空边距检查桩本身是否被障碍阻塞）。
3. 先试 **`_fastRouteBetween`**——转义起点/终点间廉价的直接净空路径检查（常见 case：真实拓扑中大多数边不需要完整寻路，因为同等级或相邻等级两节点间根本没有东西）。
4. 快速路径被阻塞时回退 **`_routeBetween`**——实现为优先队列搜索（`_RouteHeap` 对 `_RouteState`——实际是对网格状态的 A* 搜索）的避障正交搜索。其代价函数组合曼哈顿距离（`_manhattan`）与**转弯代价**（惩罚方向变化）和**拥塞代价**（`_congestionCost`，惩罚靠近或重叠较早边已路由段的路径），使共享走廊的多条边分散进不同平行轨道而非重叠。
5. 候选完整路径被评分（更少转弯、更少拥塞优先）并在被接受前对照每个障碍端到端验证（`_isSegmentPathClear` 风格完整路径障碍检查，引用"Check whether every segment in a candidate polyline avoids obstacles"文档注释附近）。

路由期间使用的节点障碍被略微**膨胀**超出节点可见 `Rect`（经 `_routingClearance`/`_routingMargin` 常量），使路由路径与节点边界保持可见间隙而非接触，从障碍布局派生一次的共享"路由轨道"（`_RoutingGridBase`）跨边复用，使同列/相邻列平行边不碰撞。

## 性能备注

按 `AGENTS.md` 版本历史（`v0.5.12`），全屏拓扑视图把整个布局遍推迟到首帧后，并缓存以图身份、路由、视口宽度和旋转状态键控的结果——因此在选择/移动模式间切换或旋转视图不强制重新布局，除非底层图或视口实际变化。回退完整 A* 风格搜索前先试快速净空路径本身是性能优化：实践中大多数边从不需要更昂贵的搜索。

## 相关

- [服务与拓扑](../features/services-topology.md) — 此布局渲染的功能（总览/按设备/路由/端口视图、FRP 端口 chip 建模、快速访问路由创建）。
- [服务拓扑演练](../examples/service-topology-walkthrough.md) — 此布局会渲染其路由/跳结构的完整示例。
