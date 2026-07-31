# lib/features/services/services/service_topology_layout.dart

`ServiceTopologyLayout` 是服务拓扑图视图的纯、静态布局/路由引擎：给定 `ServiceTopologyGraph`（节点/边，来自 `service_analysis.dart`）和产生它的 `ServiceRoute` 列表，`ServiceTopologyLayout.build` 计算画布 `Size`、每节点 `Rect`、每节点整数等级和每边预路由正交折线（`List<Offset>`）。组件层（`service_list_page.md` 的 `ServiceTopologyView`，从 `lib/features/services/views/service_list_page.dart` 调用）只绘制这些预计算值——它自己不做布局或寻路，结果按 图/路由/视口/旋转 缓存，使切换模式不强制重布局。本文件是应用算法最密集的文件：其大多数私有辅助实现真实图等级传播、行压实或正交 A* 风格寻路，而非组件组合。

本文件实现的两个算法的高层描述（动态语义等级，和快速净空路径优先带 A* 回退的正交路由）见 [服务拓扑布局](../../../../algorithms/service-topology-layout.md)，此布局渲染的功能见 [服务与拓扑](../../../../features/services-topology.md)。概念文档引用的函数名（`_nodeRanks`、`_alignSiblingPortRanks`、`_placeNodes`、`_fastRouteBetween`、`_routeBetween`、`_RouteHeap`/`_RouteState`、`_congestionCost`）写本页时对照当前源码验证；概念文档一个细节下面细化：`_nodeRanks` 不把每个节点从等级 0 开始——设备节点从等级 0 开始，每个其他节点 kind 从等级 1 开始（见那个条目）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ServiceTopologyLayout` | 类 | B | 不可变布局结果：画布大小、节点矩形、节点等级、边路径。 |
| `size` | 字段（`ServiceTopologyLayout`） | B | 拓扑的计算画布大小。 |
| `nodeRects` | 字段（`ServiceTopologyLayout`） | B | 节点 id → 放置 `Rect`。 |
| `nodeRanks` | 字段（`ServiceTopologyLayout`） | B | 节点 id → 分配整数等级（列）。 |
| `edgePaths` | 字段（`ServiceTopologyLayout`） | B | 边 → 预路由正交折线。 |
| `ServiceTopologyLayout.new` | 构造函数（`ServiceTopologyLayout`） | B | 四个必填字段的转发 const 构造函数。 |
| `nodeWidth` | 静态 const（`ServiceTopologyLayout`） | B | 默认节点卡片宽（204.0）。 |
| `nodeHeight` | 静态 const（`ServiceTopologyLayout`） | B | 默认节点卡片高（76.0）。 |
| `portChipSize` | 静态 const（`ServiceTopologyLayout`） | B | 紧凑端口 chip 宽/高（52.0）。 |
| `rankGap` | 静态 const（`ServiceTopologyLayout`） | B | 等级列间水平间隙（38.0）。 |
| `verticalGap` | 静态 const（`ServiceTopologyLayout`） | B | 堆叠节点间最小垂直间隙（24.0）。 |
| `padding` | 静态 const（`ServiceTopologyLayout`） | B | 画布边缘填充（24.0）。 |
| `_routingMargin` | 静态 const（`ServiceTopologyLayout`） | B | 为路由边保留的额外画布边距（72.0）。 |
| `_routingClearance` | 静态 const（`ServiceTopologyLayout`） | B | 路由期间应用到节点矩形的障碍膨胀（14.0）。 |
| `_routingEscape` | 静态 const（`ServiceTopologyLayout`） | B | 每个节点垂直退出/进入桩长度（18.0）。 |
| `_routingTrackGap` | 静态 const（`ServiceTopologyLayout`） | B | 平行路由轨道/车道间间距（22.0）。 |
| [`build`](#build) | 静态方法（`ServiceTopologyLayout`） | A | 为拓扑图计算节点位置和预路由边路径。 |
| [`_placeNodes`](#_placenodes) | 静态方法（`ServiceTopologyLayout`） | A | 把节点放入等级列并在每个等级内压实行。 |
| [`_compactRankRows`](#_compactrankrows) | 静态方法（`ServiceTopologyLayout`） | A | 把行变为 y 位置前在一个等级内压实期望行。 |
| [`_compactDesiredRows`](#_compactdesiredrows) | 静态方法（`ServiceTopologyLayout`） | A | 移除只被无可见节点路由保留的行间隙。 |
| [`_compactRowValueMap`](#_compactrowvaluemap) | 静态方法（`ServiceTopologyLayout`） | A | 从稀疏期望行值构建紧凑值映射。 |
| [`_compactRowValue`](#_compactrowvalue) | 静态方法（`ServiceTopologyLayout`） | A | 为一个原始期望行查找压实行值。 |
| [`_nodeRanks`](#_noderanks) | 静态方法（`ServiceTopologyLayout`） | A | 传播并密化逐节点水平等级（列）。 |
| [`_alignSiblingPortRanks`](#_alignsiblingportranks) | 静态方法（`ServiceTopologyLayout`） | A | 把兄弟入口/公共端口节点拉到相同等级。 |
| `_nodeWidth` | 静态方法（`ServiceTopologyLayout`） | B | 节点卡片宽，节点紧凑时 `portChipSize`。 |
| `_nodeHeight` | 静态方法（`ServiceTopologyLayout`） | B | 节点卡片高，节点紧凑时 `portChipSize`。 |
| [`_routeRows`](#_routerows) | 静态方法（`ServiceTopologyLayout`） | A | 沿虚拟行轴给每条路由分配首选行。 |
| [`_desiredRows`](#_desiredrows) | 静态方法（`ServiceTopologyLayout`） | A | 从路由/邻居派生每个节点首选行。 |
| [`_routeEdges`](#_routeedges) | 静态方法（`ServiceTopologyLayout`） | A | 入口点：把每条边路由为正交折线。 |
| [`_portOffsets`](#_portoffsets) | 静态方法（`ServiceTopologyLayout`） | A | 把共享节点侧的边扇出为不同垂直偏移。 |
| [`_routeEdge`](#_routeedge) | 静态方法（`ServiceTopologyLayout`） | A | 路由一条边，按偏好顺序试锚侧候选。 |
| [`_fastRouteBetween`](#_fastroutebetween) | 静态方法（`ServiceTopologyLayout`） | A | A* 前试廉价直接/L/Z/绕框候选。 |
| [`_routeBetween`](#_routebetween) | 静态方法（`ServiceTopologyLayout`） | A | 避障正交 A* 风格网格搜索（回退路由器）。 |
| [`_pathScore`](#_pathscore) | 静态方法（`ServiceTopologyLayout`） | A | 按长度、转弯和拥塞评分路由路径。 |
| [`_pathClear`](#_pathclear) | 静态方法（`ServiceTopologyLayout`） | A | 对照障碍检查候选折线每个段。 |
| [`_stubBlocked`](#_stubblocked) | 静态方法（`ServiceTopologyLayout`） | A | 检查退出/进入桩是否被另一障碍阻塞。 |
| [`_segmentBlocked`](#_segmentblocked) | 静态方法（`ServiceTopologyLayout`） | A | 对照障碍列表检查一个正交段。 |
| [`_congestionCost`](#_congestioncost) | 静态方法（`ServiceTopologyLayout`） | A | 惩罚与已路由段重叠/交叉的候选段。 |
| [`_segmentsForPath`](#_segmentsforpath) | 静态方法（`ServiceTopologyLayout`） | A | 把折线转为 `_Segment` 供拥塞跟踪。 |
| [`_simplifyPolyline`](#_simplifypolyline) | 静态方法（`ServiceTopologyLayout`） | A | 从折线去重点并丢弃共线内部点。 |
| `_anchor` | 静态方法（`ServiceTopologyLayout`） | B | 矩形左/右边上的点，垂直偏移。 |
| `_sideVector` | 静态方法（`ServiceTopologyLayout`） | B | `_TopologySide` 的单位外向量。 |
| `_edgeSpan` | 静态方法（`ServiceTopologyLayout`） | B | 边端点矩形中心间欧几里得距离。 |
| `_serviceNodeId` | 静态方法（`ServiceTopologyLayout`） | B | 为服务构建合成 `service:<id>` 节点 id。 |
| [`_compareRoutesForLayout`](#_compareroutesforlayout) | 静态方法（`ServiceTopologyLayout`） | A | 按车道、方法、然后目标排序一个源的 路由。 |
| `_laneOrder` | 静态方法（`ServiceTopologyLayout`） | B | `ServiceAccessLane` 排序键（local < vpn < public）。 |
| `_laneRank` | 静态方法（`ServiceTopologyLayout`） | B | 可空 `ServiceAccessLane` 排序键（null 排最后）。 |
| `_routeMethodName` | 静态方法（`ServiceTopologyLayout`） | B | 首跳 HTTP 方法名，或 `''`。 |
| [`_median`](#_median) | 静态方法（`ServiceTopologyLayout`） | A | 行分数列表的统计中位数。 |
| `_roleOrder` | 静态方法（`ServiceTopologyLayout`） | B | `ServiceTopologyNodeRole` 排序键（device→…→domain）。 |
| `_laneBucket` | 静态方法（`ServiceTopologyLayout`） | B | 节点自己车道排序键（未设先排）。 |
| `_manhattan` | 静态方法（`ServiceTopologyLayout`） | B | 两个 `Offset` 间 L1 距离。 |
| `_snapOffset` | 静态方法（`ServiceTopologyLayout`） | B | 把 `Offset` 两坐标吸附到半像素网格。 |
| `_clampOffset` | 静态方法（`ServiceTopologyLayout`） | B | 把 `Offset` 钳制进 `[0, size]`。 |
| `_snap` | 静态方法（`ServiceTopologyLayout`） | B | 把值舍入到最近 0.5。 |
| `_sameRect` | 静态方法（`ServiceTopologyLayout`） | B | 容 epsilon 的 `Rect` 相等。 |
| `_TopologySide` | 枚举 | B | `left` / `right` — 边从节点哪侧退出/进入。 |
| `_epsilon` | 顶层 const | B | 几何比较共享浮点容忍（0.01）。 |
| `_rowEpsilon` | 顶层 const | B | 行值匹配浮点容忍（0.0001）。 |
| `_RoutingGridBase` | 类 | B | 可复用共享 x/y 路由轨道坐标集合。 |
| `xs` | 字段（`_RoutingGridBase`） | B | 共享垂直网格线（x 坐标）。 |
| `ys` | 字段（`_RoutingGridBase`） | B | 共享水平网格线（y 坐标）。 |
| `_RoutingGridBase.new` | 构造函数（`_RoutingGridBase`） | B | `xs`/`ys` 转发 const 构造函数。 |
| [`_RoutingGridBase.fromObstacles`](#_routinggridbase-fromobstacles) | 工厂（`_RoutingGridBase`） | A | 从节点障碍和画布大小构建共享路由轨道。 |
| `_Segment` | 类 | B | 正交（水平或垂直）线段 `a`→`b`。 |
| `a` | 字段（`_Segment`） | B | 段起点。 |
| `b` | 字段（`_Segment`） | B | 段终点。 |
| `_Segment.new` | 构造函数（`_Segment`） | B | `a`/`b` 转发 const 构造函数。 |
| `horizontal` | getter（`_Segment`） | B | 段端点是否共享 y（`_epsilon` 内）。 |
| `vertical` | getter（`_Segment`） | B | 段端点是否共享 x（`_epsilon` 内）。 |
| [`sameAxisOverlap`](#sameaxisoverlap) | 方法（`_Segment`） | A | 两段是否同线且跨度重叠。 |
| [`nearAxisOverlap`](#nearaxisoverlap) | 方法（`_Segment`） | A | 两平行段是否在 `distance` 内运行。 |
| [`crosses`](#crosses) | 方法（`_Segment`） | A | 水平和垂直段是否实际相交。 |
| [`_rangesOverlap`](#_rangesoverlap) | 静态方法（`_Segment`） | A | 两个 1-D 范围是否重叠超过 `_epsilon`。 |
| [`_between`](#_between) | 静态方法（`_Segment`） | A | 带 `_epsilon` 松量的包含范围测试。 |
| `_RouteState` | 类 | B | 搜索堆条目：网格状态 `index` 和累积 `cost`。 |
| `index` | 字段（`_RouteState`） | B | 编码 `(point, direction)` 状态索引。 |
| `cost` | 字段（`_RouteState`） | B | 排序堆的优先级（g + 启发式）。 |
| `_RouteState.new` | 构造函数（`_RouteState`） | B | `index`/`cost` 转发 const 构造函数。 |
| `_RouteHeap` | 类 | B | `_RouteState` 的二叉最小堆，按 `cost` 排序。 |
| `_items` | 字段（`_RouteHeap`） | B | 堆数组的可增长后备列表。 |
| `isNotEmpty` | getter（`_RouteHeap`） | B | 堆是否仍有条目。 |
| [`add`](#add) | 方法（`_RouteHeap`） | A | 插入状态并上滤恢复堆序。 |
| [`removeFirst`](#removefirst) | 方法（`_RouteHeap`） | A | 弹出最小代价状态并把新根下滤。 |
| [`_bubbleUp`](#_bubbleup) | 方法（`_RouteHeap`） | A | 上滤：父代价更大时与父交换。 |
| [`_bubbleDown`](#_bubbledown) | 方法（`_RouteHeap`） | A | 下滤：较小子胜过当前节点时与其交换。 |
| `_swap` | 方法（`_RouteHeap`） | B | 按索引交换两个后备数组槽。 |

**行数说明：** `grep -c 'Purpose:' service_topology_layout.dart` 返回 **56**——文件每个方法、构造函数、getter 和工厂都带 `/// Purpose:` 文档注释。上面声明表有 **87** 行，因为也列出本代码库大文件/文档注释约定不标注的声明：6 个类/枚举声明本身（`ServiceTopologyLayout`、`_TopologySide`、`_RoutingGridBase`、`_Segment`、`_RouteState`、`_RouteHeap`，其中 `_TopologySide` 是枚举）、这些类跨 15 个普通数据字段、12 个 `static const`/顶层常量（10 个布局常量 + `_epsilon`/`_rowEpsilon`）和 2 个平凡单行 getter（`_Segment.horizontal`/`.vertical`），它们读作属性访问器而非文档注释行为。56（文档化）+ 31（未文档化字段/常量/类/getter）= 87，精确对账。

## 文档

### `static ServiceTopologyLayout build(ServiceTopologyGraph graph, List<ServiceRoute> routes, double viewportWidth)` <a id="build"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 41 行）。
- **用途：** 为一个拓扑图/路由集合/视口宽度计算节点矩形、等级、画布大小和预路由边折线。
- **输入：** `graph`（节点 + 边）、`routes`（驱动行分组）、`viewportWidth`（最小画布宽）。
- **返回：** 带 `size`、`nodeRects`、`nodeRanks`、`edgePaths` 的新 `ServiceTopologyLayout`。
- **副作用：** 无——对输入纯函数。
- **算法：**
  1. 构建 `nodeMap`（id → 节点）和 `validEdges`——`from`/`to` 都解析到真实节点的边保留；悬空边静默丢弃。
  2. 从 `validEdges` 为每个节点构建 `incoming`/`outgoing` 邻接集合。
  3. 计算 `routeRows`（[`_routeRows`](#_routerows)），然后从路由/邻接计算 `desiredRows`（[`_desiredRows`](#_desiredrows)）。
  4. 独立于边图计算 `nodeRanks`（[`_nodeRanks`](#_noderanks)）。
  5. 全局压实 `desiredRows`（[`_compactDesiredRows`](#_compactdesiredrows)），然后经带等级本地行压实的 [`_placeNodes`](#_placenodes) 把节点放入等级列得 `nodeRects`。
  6. 从最远节点矩形右/下计算画布 `size` 为 `max(viewportWidth, maxRight + padding + _routingMargin)` × `max(360.0, maxBottom + padding + _routingMargin)`。
  7. 对照现已最终矩形/等级/大小路由每条边（[`_routeEdges`](#_routeedges)）得 `edgePaths`。
- **用法：**
  ```dart
  final layout = ServiceTopologyLayout.build(
    request.graph,
    request.routes,
    request.viewportWidth.toDouble(),
  );
  ```
  （`lib/features/services/views/service_list_page.dart`，`_calculateLayout`，按 `AGENTS.md` 的 `v0.5.12` 说明延迟到首帧后运行。）
- **备注：** 行/等级计算（步骤 3–4）刻意独立于节点放置（步骤 5）——等级纯来自边图，而行来自路由/邻居；它们只在 `_placeNodes` 按期望行排序每个等级内节点时组合。

### `static Map<String, Rect> _placeNodes(ServiceTopologyGraph graph, Map<String, int> nodeRanks, Map<String, double> desiredRows)` <a id="_placenodes"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 101 行）。
- **用途：** 把节点放入等级（列）桶、排序每个等级内节点，并经等级本地行压实布局 x/y 矩形。
- **输入：** `graph`、`nodeRanks`（来自 `_nodeRanks`）、`desiredRows`（已全局压实）。
- **返回：** `Map<String, Rect>` — 每个节点 id 一个放置矩形。
- **副作用：** 无。
- **算法：**
  1. 按等级分组节点（`ranked[rank]`），然后按 `desiredRows` 升序排序每个等级节点，平局按 [`_roleOrder`](#build) 然后 `_laneBucket` 然后标签。
  2. 计算每等级列宽为其节点最大 `_nodeWidth`；从左到右布局 `rankX`，每等级推进 `rankWidth + rankGap`。
  3. 对每个等级经 [`_compactRankRows`](#_compactrankrows) 重算**等级本地**压实行映射（独立于已应用到 `desiredRows` 的全局压实——这移除只因*其他*等级使用那些行而存在的空白带）。
  4. 从上到下走等级节点：目标 y 是 `padding + row * (nodeHeight + 44)`，但绝不小于 `previousBottom + verticalGap`（使压实绝不与前一节点重叠）；x 在等级列宽内居中。
- **用法：**
  ```dart
  final nodeRects = _placeNodes(graph, nodeRanks, compactRows);
  ```
  （`build`，第 74 行。）
- **备注：** 垂直行步长（`nodeHeight + 44`）是固定常量，与 `verticalGap`（24.0）分离——`verticalGap` 只在两行压实到否则会碰撞的足够近时作为最小间距下限触发。

### `static Map<String, double> _compactRankRows(List<ServiceTopologyNode> nodes, Map<String, double> desiredRows)` <a id="_compactrankrows"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 168 行）。
- **用途：** 只为一个等级节点重算紧凑行号，使*其他*等级未用行不在此等级留下空白带。
- **输入：** `nodes`（已过滤到一个等级）、`desiredRows`（全局映射）。
- **返回：** `Map<String, double>` — 节点 id → 紧凑行，本地到此等级。
- **副作用：** 无。
- **算法：** 经 [`_compactRowValueMap`](#_compactrowvaluemap) 只从本等级节点 `desiredRows` 值构建行值映射，然后经 [`_compactRowValue`](#_compactrowvalue) 查找每个节点压实值。
- **用法：**
  ```dart
  final rankRows = _compactRankRows(nodes, desiredRows);
  ```
  （`_placeNodes`，第 147 行。）
- **备注：** 因为压实等级本地，相同原始 `desiredRows` 值可在两个不同等级映射到不同压实行号——这是刻意的（每等级只关心自己垂直间隙）。

### `static Map<String, double> _compactDesiredRows(ServiceTopologyGraph graph, Map<String, double> desiredRows)` <a id="_compactdesiredrows"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 186 行）。
- **用途：** 移除全局 `desiredRows` 映射中只因 `_routeRows` 为无对应可见节点的路由/源保留行而存在的行间隙。
- **输入：** `graph`、`desiredRows`。
- **返回：** `Map<String, double>` — 与 `desiredRows` 相同键，压实值。
- **副作用：** 无。
- **算法：** 收集并排序实际属于 `graph.nodes` 条目的期望行值（`usedRows`）；为空则原样返回输入。经 [`_compactRowValueMap`](#_compactrowvaluemap) 从 `usedRows` 构建压实映射，然后经 [`_compactRowValue`](#_compactrowvalue) 重映射 `desiredRows` 每个条目。
- **用法：**
  ```dart
  final compactRows = _compactDesiredRows(graph, desiredRows);
  ```
  （`build`，第 73 行。）
- **备注：** 这是*全局*压实遍（一次跨所有等级），在 `_placeNodes` 前运行；`_compactRankRows` 是之后以更细粒度服务相同目的的第二次等级本地压实遍。

### `static Map<double, double> _compactRowValueMap(Iterable<double> rows)` <a id="_compactrowvaluemap"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 211 行）。
- **用途：** 把稀疏、可能不规则原始行值集合变成稠密压实序列，坍缩大间隙同时保留小排序间隙作视觉呼吸空间。
- **输入：** `rows` — 原始行值（可含近重复）。
- **返回：** `Map<double, double>`，把每个不同原始行（`_rowEpsilon` 内去重）映射到压实位置。
- **副作用：** 无。
- **算法：**
  1. 排序 `rows`，然后把 `_rowEpsilon` 内相邻值去重进 `compactedRows`。
  2. 按顺序走 `compactedRows`，累积 `nextRow`；第一步后每步加 `rawGap.clamp(0.72, 1.0)`——同源路由间隙（原始步 1.0）保持接近整行，而源间间隙（原始步 0.38）仍至少贡献 0.72，保证可见分离而不让大到 1.35（空源间距）的间隙按比例拉伸画布。
- **用法：**
  ```dart
  final rowMap = _compactRowValueMap(
    nodes.map((node) => desiredRows[node.id]).whereType<double>(),
  );
  ```
  （`_compactRankRows`，第 172–174 行。）
- **备注：** `clamp(0.72, 1.0)` 边界是压实行能多"松"或多"紧"的承载负载常量；概念文档未浮出它们，只有读此方法可见。

### `static double _compactRowValue(double row, Map<double, double> rowMap)` <a id="_compactrowvalue"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 238 行）。
- **用途：** 经 `rowMap` 解析一个原始期望行值到压实行，容忍浮点漂移。
- **输入：** `row`、`rowMap`（来自 `_compactRowValueMap`）。
- **返回：** 匹配压实值，或 `rowMap` 无键在 `_rowEpsilon` 内时 `row` 不变。
- **副作用：** 无。
- **算法：** 线性扫描 `rowMap.entries`，匹配 `(row - entry.key).abs() <= _rowEpsilon`；每次查找 O(n)（n = 不同压实行）。
- **用法：**
  ```dart
  node.id: _compactRowValue(desiredRows[node.id] ?? 0, rowMap),
  ```
  （`_compactRankRows`，第 177 行。）
- **备注：** 回退原始 `row`（而非抛）意味着构建它所用映射外的值原样保留而非重映射。

### `static Map<String, int> _nodeRanks(ServiceTopologyGraph graph, List<ServiceTopologyEdge> validEdges)` <a id="_noderanks"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 250 行）。
- **用途：** 经松弛从边图派生每个节点水平等级（列），然后把结果稀疏等级压缩为稠密 `0..N` 序列。
- **输入：** `graph`、`validEdges`。
- **返回：** `Map<String, int>` — 节点 id → 稠密等级。
- **副作用：** 无。
- **算法：**
  1. 播种 `ranks`：kind `ServiceTopologyNodeKind.device` 每个节点从等级 0 开始；每个其他节点 kind 从等级 1 开始（这不同于朴素"每人都从 0 开始"阅读——设备节点从一开始钉在左缘）。
  2. 设 `rankLimit = max(2, nodeCount + 1)`。至多 `nodeCount + 2` 次迭代：对每条边松弛 `ranks[edge.to] = max(ranks[edge.to], min(rankLimit, ranks[edge.from] + 1))`；每次迭代也调用 [`_alignSiblingPortRanks`](#_alignsiblingportranks) 并把其 `changed` 结果 OR 进去。完整遍无变化时提前停止。
  3. 收集 `uniqueRanks`（排序、去重）并把每个节点原始等级重映射到其在该排序列表中的索引，产生无未用间隙的稠密 `0..N` 等级序列。
- **用法：**
  ```dart
  final nodeRanks = _nodeRanks(graph, validEdges);
  ```
  （`build`，第 72 行。）
- **备注：** `rankLimit` 封顶传播，使循环边图不能无界增长等级——它保证终止（不动点循环界 `nodeCount + 2` 也是即使 `changed` 从不安定也硬迭代上限）而非彻底防环。

### `static bool _alignSiblingPortRanks(List<ServiceTopologyEdge> edges, Map<String, ServiceTopologyNode> nodeMap, Map<String, int> ranks)` <a id="_alignsiblingportranks"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 291 行）。
- **用途：** 把同一服务的兄弟"端口类"子节点（如成对 FRP 入口/公共端口节点）拉到相同等级，使它们读作一个视觉单元。
- **输入：** `edges`、`nodeMap`、`ranks`（原地修改）。
- **返回：** `bool` — 本次调用是否有等级变化。
- **副作用：** 原地修改 `ranks`（提升一些条目）。
- **算法：**
  1. 对每条 `from` 节点是 `service` 且 `to` 节点 `compact`、kind `endpoint` 或 `remoteEntry` 的边，把 `to` id 按共同 `from` 服务 id 分组（`servicePorts`）。
  2. 对每个有 2+ 兄弟端口的服务，计算 `targetRank` 为其间当前最大等级，然后把任何低于 `targetRank` 的兄弟提升到它，标记 `changed = true`。
- **用法：**
  ```dart
  if (_alignSiblingPortRanks(validEdges, nodeMap, ranks)) {
    changed = true;
  }
  ```
  （`_nodeRanks`，第 270–272 行，每次松弛迭代调用一次。）
- **备注：** 只提升等级（绝不降低），与 `_nodeRanks` 单调松弛一致；在同一循环内调用意味着兄弟对齐本身可触发下次迭代进一步边松弛。

### `static Map<String, double> _routeRows(ServiceTopologyGraph graph, List<ServiceRoute> routes, Map<String, ServiceTopologyNode> nodeMap)` <a id="_routerows"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 349 行）。
- **用途：** 沿虚拟行轴给每条路由分配首选行，按源服务分组并排序，使同源路由落在相邻行。
- **输入：** `graph`、`routes`、`nodeMap`。
- **返回：** `Map<String, double>` — 路由 id → 行分数。
- **副作用：** 无。
- **算法：**
  1. 按 `_serviceNodeId(route.sourceServiceId)` 把路由分组进 `routesBySource`。
  2. 收集所有源 id（有路由或无路由——含零路由本地服务节点）并按标签字母排序。
  3. 按该顺序走源，维护运行 `row`：无路由源仍把 `row` 推进 1.35（保留间隙而不发出任何行条目）；有路由源经 [`_compareRoutesForLayout`](#_compareroutesforlayout) 排序它们、给每条分配顺序行（每路由 `row += 1`）、然后在下一源前加额外 0.38 间隙。
- **用法：**
  ```dart
  final routeRows = _routeRows(graph, routes, nodeMap);
  ```
  （`build`，第 64 行。）
- **备注：** 1.35/0.38/1.0 间距常量正是 [`_compactRowValueMap`](#_compactrowvaluemap) 的 `clamp(0.72, 1.0)` 步骤稍后规范化的东西——一旦真实节点参与，空源间隙（1.35）和源间间隙（0.38）压实非常不同。

### `static Map<String, double> _desiredRows(ServiceTopologyGraph graph, List<ServiceRoute> routes, Map<String, double> routeRows, Map<String, Set<String>> incoming, Map<String, Set<String>> outgoing)` <a id="_desiredrows"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 399 行）。
- **用途：** 派生每个节点首选行：可能时直接从其参与路由，否则从已评分邻居传播，否则稳定回退顺序。
- **输入：** `graph`、`routes`、`routeRows`（来自 `_routeRows`）、`incoming`/`outgoing` 邻接。
- **返回：** `Map<String, double>` — 节点 id → 期望行（每个节点得条目）。
- **副作用：** 无。
- **算法：**
  1. 对每个服务节点收集其源路由行（`sourceRouteRows`）。
  2. 对每个节点收集 `scores` = 自己 `routeIds` 行加（是服务时）源路由行；有分数时 `desired[node.id] = _median(scores)`。
  3. 至多迭代 10 次：对任何仍无 `desired` 条目的节点，收集其 `incoming`/`outgoing` 邻居 `desired` 分数，有则 `desired[node.id] = _median(...)`；完整遍无变化提前停止。
  4. 任何仍未评分（与任何已路由节点隔离）节点从 `max(desired.values) + 1`（`desired` 空则 0）开始按 `_roleOrder` 然后标签顺序得顺序回退行。
- **用法：**
  ```dart
  final desiredRows = _desiredRows(graph, routes, routeRows, incoming, outgoing);
  ```
  （`build`，第 65–71 行。）
- **备注：** 邻居传播 10 迭代上限（步骤 3）意味着非常长的其他未路由节点链在 10 遍内传播未达时仍可落入步骤 4 回退——实践中受典型拓扑直径限制。

### `static Map<ServiceTopologyEdge, List<Offset>> _routeEdges(List<ServiceTopologyEdge> validEdges, Map<String, Rect> rects, Map<String, int> ranks, Size size)` <a id="_routeedges"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 469 行）。
- **用途：** 边路由入口点：一次构建共享障碍/网格状态，然后对照它路由每条边，累积已路由段使较后边避开较早边。
- **输入：** `validEdges`、`rects`（放置节点矩形）、`ranks`、`size`（画布）。
- **返回：** `Map<ServiceTopologyEdge, List<Offset>>` — 每条边一个折线（路由失败可能为空）。
- **副作用：** 无（构建新鲜本地集合）。
- **算法：**
  1. 经 [`_portOffsets`](#_portoffsets) 计算 `outgoingOffsets`/`incomingOffsets`，使共享节点侧边扇出。
  2. 构建 `obstacles` 为每个节点矩形膨胀 `_routingClearance`，然后构建共享 [`_RoutingGridBase.fromObstacles`](#_routinggridbase-fromobstacles)。
  3. 按 [`_edgeSpan`](#build) 降序（最长优先）、然后 `_laneRank(edge.lane)`、然后 `'from->to'` 字符串排序边——最可能需要真实寻路的边先认领直接走廊，较短边之后绕它们路由。
  4. 按该顺序对每条边用共享障碍/网格和迄今已路由段调用 [`_routeEdge`](#_routeedge)；移到下一边前把结果段（经 [`_segmentsForPath`](#_segmentsforpath)）追加进 `routedSegments`。
- **用法：**
  ```dart
  final edgePaths = _routeEdges(validEdges, nodeRects, nodeRanks, size);
  ```
  （`build`，第 86 行。）
- **备注：** `routedSegments` 在整个调用单调累积——拥塞代价（经 `_congestionCost`）因此顺序依赖：较早路由（更长）边先挑净空走廊，较后边付绕行代价。

### `static Map<ServiceTopologyEdge, double> _portOffsets(List<ServiceTopologyEdge> edges, Map<String, Rect> rects, Map<String, int> ranks, {required bool outgoing})` <a id="_portoffsets"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 527 行）。
- **用途：** 对 `from`（或 `to`）侧共享相同节点的边，计算每条边垂直偏移，使它们沿节点边缘扇出而非重叠。
- **输入：** `edges`、`rects`、`ranks`、`outgoing`（是否按 `from` 或 `to` 分组）。
- **返回：** `Map<ServiceTopologyEdge, double>` — 每条边距节点中心垂直偏移。
- **副作用：** 无。
- **算法：**
  1. 按相关节点 id 分组边（`entry.key`）。
  2. 对每组计算 `maxOffset = max(0, nodeRect.height / 2 - 12)` 并按对等中心 y、然后 `ranks[peer]`、然后 `'from->to'` 字符串排序组边。
  3. 围绕组中点索引对称分配偏移：`((i - midpoint) * 9.0).clamp(-maxOffset, maxOffset)`，即相邻边 9px 间距，钳制使偏移绝不离开节点自己边缘。
- **用法：**
  ```dart
  final outgoingOffsets = _portOffsets(validEdges, rects, ranks, outgoing: true);
  final incomingOffsets = _portOffsets(validEdges, rects, ranks, outgoing: false);
  ```
  （`_routeEdges`，第 475–486 行。）
- **备注：** 每次布局调用两次（每方向一次），因为边在其 `from` 节点退出扇出独立于其 `to` 节点进入扇出。

### `static List<Offset> _routeEdge({required Rect from, required Rect to, required double fromOffset, required double toOffset, required List<Rect> obstacles, required _RoutingGridBase gridBase, required List<_Segment> routedSegments, required Size size})` <a id="_routeedge"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 571 行）。
- **用途：** 路由两个放置节点矩形间一条边，试多个锚侧候选并保留产生最低分有效路径的那个。
- **输入：** `from`/`to` 矩形、逐边端口偏移、共享 `obstacles`/`gridBase`、迄今 `routedSegments`、画布 `size`。
- **返回：** 简化正交折线，或每个候选锚对都失败时 `[]`。
- **副作用：** 无。
- **算法：**
  1. 确定 `forward`（`to` 在 `from` 右）和 `sameRank`（中心水平 8px 内）；挑首选 `startSide`/`endSide`：同等级边从朝画布中线之外的任一侧（`left`/`right`）退出/进入，否则自然前向/后向侧。
  2. 构建有序、去重候选列表：首选对先，然后四个 `{left,right}×{left,right}` 组合作回退。
  3. 对每个候选：经 [`_anchor`](#build) + 偏移计算锚点，然后沿 [`_sideVector`](#build) 用 `_routingEscape` 推出并钳制到画布（[`_clampOffset`](#build)）得 `startExit`/`endEntry`。任一脚桩被节点自己膨胀矩形外障碍阻塞（[`_stubBlocked`](#_stubblocked)）则跳过候选。
  4. 路由中间段：先试 [`_fastRouteBetween`](#_fastroutebetween)，返回 `null` 时回退 [`_routeBetween`](#_routebetween)。两者都失败则跳过候选。
  5. 组装完整路径（`start → startExit → middle (skip duplicate first point) → end`）、简化它（[`_simplifyPolyline`](#_simplifypolyline)）并评分（[`_pathScore`](#_pathscore)）；保留迄今所见最低分候选。
  6. 返回找到的最佳路径，无候选产生则 `const []`。
- **用法：**
  ```dart
  final path = _routeEdge(
    from: from,
    to: to,
    fromOffset: outgoingOffsets[edge] ?? 0,
    toOffset: incomingOffsets[edge] ?? 0,
    obstacles: obstacles,
    gridBase: gridBase,
    routedSegments: routedSegments,
    size: size,
  );
  ```
  （`_routeEdges`，第 506–515 行。）
- **备注：** 全部 5 个候选锚对无条件试（首个成功不提前退出）——这是固定、小组合搜索（≤5 候选 × 每次 2 次路由尝试）而非贪婪首匹配，用有界额外工作量换更干净挑选路由。

### `static List<Offset>? _fastRouteBetween({required Offset start, required Offset goal, required List<Rect> obstacles, required List<_Segment> routedSegments, required Size size})` <a id="_fastroutebetween"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 666 行）。
- **用途：** 回退完整网格寻路前在两个已转义点间试一连串廉价、直接正交候选路径。
- **输入：** `start`、`goal`（已推过其节点脚桩）、`obstacles`、`routedSegments`、`size`。
- **返回：** 找到的最佳净空简化折线，候选都非障碍净空时 `null`（信号调用方回退 `_routeBetween`）。
- **副作用：** 无。
- **算法：** 经本地 `addCandidate` 辅助构建并测试候选，它简化（[`_simplifyPolyline`](#_simplifypolyline)）并障碍检查（[`_pathClear`](#_pathclear)）每个形态：
  1. 直线，只在 `start`/`goal` 已共享 x 或 y（`_epsilon` 内）时。
  2. 两个单弯"L"形态（`goal.dx, start.dy` 角和 `start.dx, goal.dy` 角）。
  3. 经中点（`midX`/`midY`）的两个"Z"形态。
  4. 至多四条经 `start`/`goal` 包围盒外每侧（左/右/上/下）偏移 `_routingTrackGap` 轨道的"绕包围盒"路由，钳制到画布。
  在所有障碍净空候选中按 [`_pathScore`](#_pathscore) 排序并返回最低；候选列表最终为空时 `null`。
- **用法：**
  ```dart
  final middle = _fastRouteBetween(
    start: startExit,
    goal: endEntry,
    obstacles: obstacles,
    routedSegments: routedSegments,
    size: size,
  ) ?? _routeBetween(...);
  ```
  （`_routeEdge`，第 628–643 行。）
- **备注：** 这是概念文档和 `AGENTS.md` 描述的优化：真实拓扑中大多数边（同或相邻等级、中间无物）在此解决，从不运行 `_routeBetween` 的 A* 风格网格搜索。

### `static List<Offset>? _routeBetween({required Offset start, required Offset goal, required List<Rect> obstacles, required _RoutingGridBase gridBase, required List<_Segment> routedSegments, required Size size})` <a id="_routebetween"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 726 行）。
- **用途：** 用共享+逐边坐标网格上的 A* 风格优先队列搜索找两个转义点间避障正交路径。
- **输入：** `start`、`goal`、`obstacles`、`gridBase`（共享轨道）、`routedSegments`、`size`。
- **返回：** 简化折线，或 `start`/`goal` 不落在网格坐标或找不到路径时 `null`。
- **副作用：** 无（每次调用构建新鲜本地搜索状态）。
- **算法：**
  1. 用逐调用轨道扩展 `gridBase` 共享 `xs`/`ys`：围绕 `start`/`goal` 本身（±`_routingTrackGap`），和围绕每条已 `routedSegments` 段（其垂直轴偏移）——使新车道在既有已路由边旁打开，而非迫使一切经相同共享轨道。
  2. 把组合坐标排序进 `xValues`/`yValues`；定位 `start`/`goal` 网格索引；任一非精确网格点返回 `null`。
  3. 在状态 `(point, direction)` 上运行 Dijkstra/A* 搜索（`direction`：0 = 开始、1 = 水平移动、2 = 垂直移动），用 [`_RouteHeap`](#add) 作开集，按 `g + heuristic` 排序，启发式为到 `goal` 的 [`_manhattan`](#_median) 距离。距离持有在大小 `pointCount * 3`（每点每方向一槽）的扁平 `List<double>`。
  4. 对每个弹出状态扩展 4 个正交网格邻居；[`_segmentBlocked`](#_segmentblocked) 拒绝连接段则跳过邻居。边代价 = `_manhattan` 步 + 26.0 转弯惩罚（只在 `currentDirection` 已设且不同于邻居方向）+ 对照 `routedSegments` 的 [`_congestionCost`](#_congestioncost)。只在 `nextCost + _epsilon < distances[nextState]` 时松弛并推入邻居状态。
  5. 任何到达 `goalPoint` 状态一被弹出立即停止（最小堆保证最低代价先出）；走 `previous[]` 重建路径回 `start`、反转并简化（[`_simplifyPolyline`](#_simplifypolyline)）。
- **用法：**
  ```dart
  final middle = _fastRouteBetween(...) ?? _routeBetween(
    start: startExit,
    goal: endEntry,
    obstacles: obstacles,
    gridBase: gridBase,
    routedSegments: routedSegments,
    size: size,
  );
  ```
  （`_routeEdge`，第 628–643 行。）
- **备注：** 这是概念文档和 `AGENTS.md` 所指" A* 回退"；因为只在 `_fastRouteBetween` 失败时运行，其 `O((grid size) log(grid size))` 代价实践中很少付。每点 3 状态方向编码正是让转弯惩罚项无需单独父指针查找就能区分"继续直行"与"刚转弯"。

### `static double _pathScore(List<Offset> path, List<_Segment> routedSegments)` <a id="_pathscore"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 844 行）。
- **用途：** 评分完整形成路由路径，使竞争锚对/候选路径可排名并挑最干净。
- **输入：** `path`、`routedSegments`（先前提交段，供拥塞）。
- **返回：** `path.length < 2` 时 `double.infinity`；否则越低越好分数。
- **副作用：** 无。
- **算法：** 对每个连续点对：加 [`_manhattan`](#_median) 距离、加对照 `routedSegments` 的 [`_congestionCost`](#_congestioncost)，并在段方向（从 `dx`/`dy` epsilon 测试的水平 vs 垂直）不同于前段方向时加 26.0 惩罚。
- **用法：**
  ```dart
  final score = _pathScore(path, routedSegments);
  if (score < bestScore) {
    bestScore = score;
    bestPath = path;
  }
  ```
  （`_routeEdge`，第 651–655 行。）
- **备注：** 用与 `_routeBetween` 搜索代价相同 26.0 转弯惩罚常量，使快速路由器和 A* 路由器找到的路径在一致刻度评分、可被 `_routeEdge` 直接比较。

### `static bool _pathClear(List<Offset> path, List<Rect> obstacles)` <a id="_pathclear"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 867 行）。
- **用途：** 快速路由器接受前检查候选折线每段是否无障碍。
- **输入：** `path`、`obstacles`。
- **返回：** `path.length < 2` 时 `false`；否则只在无连续对被阻塞时 `true`。
- **副作用：** 无。
- **算法：** 循环连续点对，对每个调用 [`_segmentBlocked`](#_segmentblocked)；第一个阻塞段短路 `false`。
- **用法：**
  ```dart
  final path = _simplifyPolyline(points.map(_snapOffset).toList());
  if (path.length < 2 || !_pathClear(path, obstacles)) return;
  ```
  （`_fastRouteBetween` 本地 `addCandidate`，第 676–677 行。）
- **备注：** 这是概念文档称为 `_isSegmentPathClear` 风格验证的"检查候选折线每段是否避障"检查。

### `static bool _stubBlocked(Offset a, Offset b, List<Rect> obstacles, {required Rect allowed})` <a id="_stubblocked"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 880 行）。
- **用途：** 检查节点短退出/进入脚桩段是否被*其他*障碍阻塞（排除节点自己膨胀矩形，脚桩预期从中穿出）。
- **输入：** `a`、`b`（脚桩端点）、`obstacles`、`allowed`（节点自己膨胀矩形，忽略）。
- **返回：** 任何非 `allowed` 障碍阻塞脚桩时 `true`。
- **副作用：** 无。
- **算法：** 循环 `obstacles`，跳过与 `allowed` [`_sameRect`](#build) 的任何；对每个剩余单障碍列表调用 [`_segmentBlocked`](#_segmentblocked)，第一个命中返回 `true`。
- **用法：**
  ```dart
  if (_stubBlocked(start, startExit, obstacles, allowed: fromObstacle) ||
      _stubBlocked(endEntry, end, obstacles, allowed: toObstacle)) {
    continue;
  }
  ```
  （`_routeEdge`，第 624–627 行。）
- **备注：** 无 `allowed` 排除，每个脚桩都会被其离开/进入的节点本身标记为阻塞，因为脚桩必然从该节点自己膨胀边界开始。

### `static bool _segmentBlocked(Offset a, Offset b, List<Rect> obstacles)` <a id="_segmentblocked"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 898 行）。
- **用途：** 对照完整障碍列表检查一个正交段。
- **输入：** `a`、`b`、`obstacles`。
- **返回：** 段非正交、或其包围矩形（膨胀 0.6）重叠任何障碍时 `true`。
- **副作用：** 无。
- **算法：** `dx` 和 `dy` 都不在 `_epsilon` 内（即段对角）时直接当阻塞——路由器只产生轴对齐段，因此这兼作不变量检查。否则构建段包围 `Rect`（两端点 min/max）、膨胀 0.6（小抗锯齿/边缘接触边距），返回是否有任何障碍 `.overlaps` 它。
- **用法：**
  ```dart
  if (_segmentBlocked(a, b, obstacles)) continue;
  ```
  （`_routeBetween` 邻居扩展，第 813 行。）
- **备注：** 这是上面几乎每个路由函数最终依赖的核心几何原语（`_pathClear`、`_stubBlocked` 和 `_routeBetween` 每次邻居扩展）。

### `static double _congestionCost(Offset a, Offset b, List<_Segment> routedSegments)` <a id="_congestioncost"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 916 行）。
- **用途：** 惩罚经、近、或跨已路由段运行的候选段，使共享走廊的多条边分散进不同平行轨道而非重叠。
- **输入：** `a`、`b`（候选段端点）、`routedSegments`。
- **返回：** `double` — 跨每个先前段求和惩罚。
- **副作用：** 无。
- **算法：** 把 `a`/`b` 包装为 `_Segment` 候选；对每个先前 `segment`，按优先级顺序恰好加一个：180.0（[`sameAxisOverlap`](#sameaxisoverlap)，同线字面重叠）、否则 58.0（[`nearAxisOverlap`](#nearaxisoverlap) 在 `_routingTrackGap * 0.85` 内，在过近相邻车道运行）、否则 28.0（[`crosses`](#crosses)，简单垂直交叉）——否则 0。不同先前段代价累积（求和）。
- **用法：**
  ```dart
  final congestionCost = _congestionCost(a, b, routedSegments);
  final nextCost = currentCost + _manhattan(a, b) + turnCost + congestionCost;
  ```
  （`_routeBetween`，第 818–820 行；也 `_pathScore` 直接使用。）
- **备注：** 三个惩罚档（180 / 58 / 28）排序使字面车道复用被惩罚约 3 倍于简单交叉，"过近但未重合"介于两者——这是概念文档"转弯/拥塞代价"描述所指的具体实现。

### `static List<_Segment> _segmentsForPath(List<Offset> path)` <a id="_segmentsforpath"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 940 行）。
- **用途：** 把接受路由折线转换为未来拥塞检查用的 `_Segment` 列表。
- **输入：** `path`。
- **返回：** `List<_Segment>` — 每个连续点对长度超 `_epsilon` 一个（丢弃意外零长度重复）。
- **副作用：** 无。
- **算法：** 循环 `i` 从 1 到 `path.length - 1`；`(path[i] - path[i-1]).distance > _epsilon` 时追加 `_Segment(path[i-1], path[i])`。
- **用法：**
  ```dart
  paths[edge] = path;
  routedSegments.addAll(_segmentsForPath(path));
  ```
  （`_routeEdges`，第 516–517 行。）
- **备注：** 这是新路由边路径成为（经 `_congestionCost`）同一 `_routeEdges` 调用中其后每条边的障碍邻近输入的方式。

### `static List<Offset> _simplifyPolyline(List<Offset> points)` <a id="_simplifypolyline"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 955 行）。
- **用途：** 把原始候选折线清理为最小正交表示：去重近相同点，然后丢弃不代表实际转弯的内部点。
- **输入：** `points`。
- **返回：** `List<Offset>` — 去重并转弯简化。
- **副作用：** 无。
- **算法：**
  1. 去重：只保留距最后保留点超 `_epsilon` 的点。
  2. 去重后少于 3 点原样返回（无可简化）。
  3. 否则走内部点：对 `previous`（最后保留）与 `next` 之间每个 `current`，检查 `previous→current→next` 是否是直水平运行（三者共享 y）或直垂直运行（三者共享 x）；两者都不是才保留 `current`（即它是实际转弯点）。
- **用法：**
  ```dart
  final path = _simplifyPolyline([start, startExit, ...middle.skip(1), end]);
  ```
  （`_routeEdge`，第 645–650 行。）
- **备注：** 这是专门、仅正交简化（非通用 Douglas-Peucker 遍）——它只能移除恰好沿两个网格轴之一共线的点，匹配此路由器产生每段轴对齐的事实。

### `static int _compareRoutesForLayout(ServiceRoute a, ServiceRoute b)` <a id="_compareroutesforlayout"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1025 行）。
- **用途：** 为行分配排序一个服务的路由：先按访问车道、然后 HTTP 方法、然后显示目标。
- **输入：** `a`、`b`（`ServiceRoute`）。
- **返回：** 标准 `Comparator<ServiceRoute>` `int`（负/零/正）。
- **副作用：** 无。
- **算法：** 三层打破平局，一层不同即返回：(1) `_laneOrder(serviceAccessLaneForRoute(route))`（local < vpn < public）；(2) 首跳方法名（`_routeMethodName`），字母序；(3) `serviceRouteDisplayTarget(route)`，字母序、不区分大小写。
- **用法：**
  ```dart
  final orderedRoutes = [...sourceRoutes]..sort(_compareRoutesForLayout);
  ```
  （`_routeRows`，第 384 行。）
- **备注：** `serviceAccessLaneForRoute`/`serviceRouteDisplayTarget` 定义在 `lib/features/services/services/service_analysis.dart`，非本文件——此比较器是布局模块自己对路由排序的意见，独立于 UI 别处路由如何排序。

### `static double _median(List<double> values)` <a id="_median"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1079 行）。
- **用途：** 计算行分数列表统计中位数，用于从路由/邻居派生节点期望行。
- **输入：** `values`（每个调用点非空）。
- **返回：** `double` — 中位数值。
- **副作用：** 无。
- **算法：** 排序 `values` 副本；计数奇数时返回精确中间元素；偶数时返回两中间元素平均。
- **用法：**
  ```dart
  if (scores.isNotEmpty) desired[node.id] = _median(scores);
  ```
  （`_desiredRows`，第 425 行，第 441 行邻居传播再次。）
- **备注：** 用中位数而非平均意味着一个离群路由行不把节点整个位置拖向它——节点改与其路由"典型"行落位。

### `factory _RoutingGridBase.fromObstacles(List<Rect> obstacles, Size size)` <a id="_routinggridbase-fromobstacles"></a>
- **种类：** `_RoutingGridBase` 的工厂构造函数。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1188 行）。
- **用途：** 从节点障碍和画布大小一次派生的共享 x/y 路由轨道坐标集合，跨每条边寻路调用复用。
- **输入：** `obstacles`（膨胀节点矩形）、`size`（画布）。
- **返回：** 带填充 `xs`/`ys` 的新 `_RoutingGridBase`。
- **副作用：** 无。
- **算法：** 总是添加四个画布边距轨道（每轴 `padding/2` 和 `size - padding/2`）。对每个障碍，在其边界*外*偏移 `_routingTrackGap` 添加四个轨道（`left - gap`、`right + gap`、`top - gap`、`bottom + gap`）——刻意绝不添加经障碍自己左/右/上/下坐标的轨道，使共享网格绝不把段路由得贴节点边界（或穿它）。
- **用法：**
  ```dart
  final gridBase = _RoutingGridBase.fromObstacles(obstacles, size);
  ```
  （`_routeEdges`，第 490 行——每次 `build()` 调用构建一次并传给每个 `_routeEdge`/`_routeBetween` 调用。）
- **备注：** 每次布局构建一次（而非逐边）是概念文档点名的"跨所有边搜索复用"优化；`_routeBetween` 仍在此共享基础上为该单边的特定 start/goal/已路由段添加逐调用额外轨道。

### `bool sameAxisOverlap(_Segment other)` <a id="sameaxisoverlap"></a>
- **种类：** `_Segment` 的方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1230 行）。
- **用途：** 确定两段是否位于完全相同水平或垂直线且跨度重叠——即视觉重合。
- **输入：** `other`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 两段都 `horizontal` 且共享相同 y（`_epsilon` 内）时对 x 跨度委托 [`_rangesOverlap`](#_rangesoverlap)；都 `vertical` 且共享相同 x 时对 y 跨度委托 `_rangesOverlap`；否则 `false`（不同轴或偏移线）。
- **用法：**
  ```dart
  if (candidate.sameAxisOverlap(segment)) {
    cost += 180.0;
  }
  ```
  （`_congestionCost`，第 924–925 行——最高惩罚拥塞档。）
- **备注：** 这是比 `nearAxisOverlap` 更严格检查——它要求线恰好重合（`_epsilon` 内），非仅仅近距离运行。

### `bool nearAxisOverlap(_Segment other, double distance)` <a id="nearaxisoverlap"></a>
- **种类：** `_Segment` 的方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1247 行）。
- **用途：** 确定两平行段是否在调用方提供 `distance` 内运行且跨度重叠——用作较软"过近"拥塞信号而非硬障碍。
- **输入：** `other`、`distance`（容忍，实践中 `_routingTrackGap * 0.85`）。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 与 `sameAxisOverlap` 相同结构，但线重合测试用 `<= distance` 而非 `< _epsilon`，使 `distance` 内近平行（非恰好重合）轨道仍算重叠。
- **用法：**
  ```dart
  } else if (candidate.nearAxisOverlap(segment, _routingTrackGap * 0.85)) {
    cost += 58.0;
  }
  ```
  （`_congestionCost`，第 926–927 行。）
- **备注：** 调用点 `_routingTrackGap` 上 `0.85` 乘数意味着"近"刻意比别处使用实际轨道间距略紧，使合法相邻（适当间距）车道自身不被惩罚。

### `bool crosses(_Segment other)` <a id="crosses"></a>
- **种类：** `_Segment` 的方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1264 行）。
- **用途：** 确定水平和垂直段是否实际相交（真实 T/X 交叉），而非仅仅邻近。
- **输入：** `other`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** `this` 水平且 `other` 垂直时检查 `other` 的 x 落在 `this` x 跨度内*且* `this` 的 y 落在 `other` y 跨度内（都经 [`_between`](#_between)）；对称 case（`this` 垂直、`other` 水平）镜像；同轴两段（都水平或都垂直）按此定义绝不"交叉"。
- **用法：**
  ```dart
  } else if (candidate.crosses(segment)) {
    cost += 28.0;
  }
  ```
  （`_congestionCost`，第 928–929 行——最轻拥塞惩罚档。）
- **备注：** 垂直交叉被惩罚远轻（28.0）于车道复用（180.0/58.0），因为交叉在正交布局中视觉不可避免且实际不混乱，不像两条边沿相同轨道运行。

### `static bool _rangesOverlap(double a1, double a2, double b1, double b2)` <a id="_rangesoverlap"></a>
- **种类：** `_Segment` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1281 行）。
- **用途：** 确定两个 1-D 范围（各给两个无序端点）重叠超过 `_epsilon`。
- **输入：** `a1`、`a2`、`b1`、`b2`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 把两个范围规范化为 `(min, max)` 对；当且仅当 `max(aMin, bMin) < min(aMax, bMax) - _epsilon` 时重叠——即严格重叠要求，仅在端点接触的范围不算重叠。
- **用法：**
  ```dart
  return _rangesOverlap(a.dx, b.dx, other.a.dx, other.b.dx);
  ```
  （`sameAxisOverlap`，第 1234 行，`nearAxisOverlap` 类似。）
- **备注：** 严格（`- _epsilon`）比较正是让同线仅端到端接触的两段不被标记为"重叠"的东西（相关时它们只会被 `crosses`/邻接逻辑标记）。

### `static bool _between(double value, double start, double end)` <a id="_between"></a>
- **种类：** `_Segment` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1294 行）。
- **用途：** 两端带 `_epsilon` 松量的包含范围成员测试，`crosses` 用来测试交点是否实际落在段跨度内。
- **输入：** `value`、`start`、`end`（无序）。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 规范化为 `minValue = min(start, end) - _epsilon`、`maxValue = max(start, end) + _epsilon`；返回 `value >= minValue && value <= maxValue`。
- **用法：**
  ```dart
  return _between(other.a.dx, a.dx, b.dx) &&
      _between(a.dy, other.a.dy, other.b.dy);
  ```
  （`crosses`，第 1266–1267 行。）
- **备注：** 与 `_rangesOverlap` 不同，这刻意包含/宽松（`+ _epsilon` 加宽范围）而非严格，使恰在段端点处的交叉仍算真实交叉。

### `void add(_RouteState state)` <a id="add"></a>
- **种类：** `_RouteHeap` 的方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1328 行）。
- **用途：** 插入新搜索状态进二叉最小堆，保持堆序。
- **输入：** `state`。
- **返回：** 无。
- **副作用：** 追加进 `_items` 并经 `_bubbleUp` 重排。
- **算法：** 把 `state` 追加到 `_items` 末尾，然后对其新索引调用 [`_bubbleUp`](#_bubbleup) 恢复最小堆不变量——标准二叉堆插入，`O(log n)`。
- **用法：**
  ```dart
  heap.add(_RouteState(startState, _manhattan(start, goal)));
  ```
  （`_routeBetween`，第 788 行，播种搜索；也第 825 行每个松弛邻居调用。）
- **备注：** 除标准二叉堆插入契约外无。

### `_RouteState removeFirst()` <a id="removefirst"></a>
- **种类：** `_RouteHeap` 的方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1338 行）。
- **用途：** 弹出并返回最低代价状态（堆根），之后恢复堆序。
- **输入：** 无。
- **返回：** `_RouteState` — 最小代价条目。
- **副作用：** 修改 `_items`（移除最后元素，可能覆盖根）。
- **算法：** 保存 `_items.first`；移除并保存 `_items.removeLast()`；仍有条目时把移除的最后元素移入槽 0 并对其调用 [`_bubbleDown`](#_bubbledown) 恢复堆序；返回保存 first（根）值——标准二叉堆提取最小，`O(log n)`。
- **用法：**
  ```dart
  final current = heap.removeFirst();
  ```
  （`_routeBetween`，第 792 行，主 A* 搜索循环。）
- **备注：** 正确处理单元素 case：`first` 和 `last` 是相同元素，`_items.isNotEmpty` 守卫跳过空堆 `_bubbleDown`。

### `void _bubbleUp(int index)` <a id="_bubbleup"></a>
- **种类：** `_RouteHeap` 的方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1353 行）。
- **用途：** 插入后从 `index` 向上恢复最小堆不变量。
- **输入：** `index`。
- **返回：** `void`。
- **副作用：** 经 `_swap` 修改 `_items`。
- **算法：** `index > 0` 时计算 `parent = (index - 1) >> 1`；父 `.cost` 已 `<=` 当前项则停止；否则 [`_swap`](#build) 它们并从 `parent` 继续。
- **用法：**
  ```dart
  void add(_RouteState state) {
    _items.add(state);
    _bubbleUp(_items.length - 1);
  }
  ```
  （`add`，第 1328–1331 行。）
- **备注：** 标准数组支撑二叉堆父索引算术（`(i - 1) >> 1`）。

### `void _bubbleDown(int index)` <a id="_bubbledown"></a>
- **种类：** `_RouteHeap` 的方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1367 行）。
- **用途：** 根被替换后从 `index` 向下恢复最小堆不变量。
- **输入：** `index`。
- **返回：** `void`。
- **副作用：** 经 `_swap` 修改 `_items`。
- **算法：** 循环：计算 `left = index*2+1`、`right = left+1`；找 `{index, left, right}`（边界检查）中 `.cost` 最小的（`smallest`）；仍 `index` 则停止；否则 [`_swap`](#build) `index` 和 `smallest` 并从 `smallest` 继续。
- **用法：**
  ```dart
  if (_items.isNotEmpty) {
    _items[0] = last;
    _bubbleDown(0);
  }
  ```
  （`removeFirst`，第 1341–1344 行。）
- **备注：** 标准数组支撑二叉堆子索引算术（`i*2+1`、`i*2+2`）。
