# lib/features/services/services/service_topology_layout.dart

`ServiceTopologyLayout` 是服务拓扑图视图的纯、静态布局/路由引擎：给定 `ServiceTopologyGraph`（节点/边，来自 `service_analysis.dart`）、产生它的 `ServiceRoute` 列表和一个 `ServiceTopologyLayoutOptions`，`ServiceTopologyLayout.build` 计算画布 `Size`、每节点 `Rect`、每节点整数等级、每条绘制边的预路由正交折线（`List<Offset>`），以及——选项按设备分组时——每个分组设备一个设备分组框 `Rect`（`groupRects`），外加设备分组框所隐含的设备→自身服务边（`hiddenEdges`，既不路由也不绘制）。在等级分配与 y 放置之间，重心交叉消减扫描可能重排每个等级；它留下的交叉数报告为 `crossings`。组件层（[`../views/service_topology_page.md`](../views/service_topology_page.md) 中的 `_ServiceTopologyView`，以及 [`../views/service_topology_widgets.md`](../views/service_topology_widgets.md) 中的绘制器和节点卡片，位于 `lib/features/services/views/service_topology_page.dart` / `service_topology_widgets.dart`）只绘制这些预计算值——设备分组框画在边之下，分组设备节点画作标题标签页——自己不做布局或寻路；结果按 图/路由/视口/选项 缓存，使切换模式不强制重布局。本文件是应用算法最密集的文件：其大多数私有辅助实现图等级传播、行压实、交叉消减、设备分组框放置或正交 A* 风格寻路，而非组件组合。

流水线的高层描述（语义等级、设备分组框、交叉消减扫描，以及快速净空路径优先、带 A* 回退的正交路由）见 [服务拓扑布局](../../../../algorithms/service-topology-layout.md)，此布局渲染的功能见 [服务与拓扑](../../../../features/services-topology.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ServiceTopologyLayoutOptions` | 类 | B | 一次布局的开关；值相等，因为它是页面布局缓存键的一部分。 |
| `groupByDevice` | 字段（`ServiceTopologyLayoutOptions`） | B | 把每台承载服务的设备画作围住其成员的设备分组框。 |
| `alignDomainSinks` | 字段（`ServiceTopologyLayoutOptions`） | B | 把每个无出边的域名节点移到最后一个等级。 |
| `crossingSweeps` | 字段（`ServiceTopologyLayoutOptions`） | B | 重心扫描次数上限；0 保持基于行的顺序。 |
| `ServiceTopologyLayoutOptions.new` | 构造函数（`ServiceTopologyLayoutOptions`） | B | const 构造函数；默认 `groupByDevice: false`、`alignDomainSinks: true`、`crossingSweeps: 4`。 |
| `operator ==` | 运算符（`ServiceTopologyLayoutOptions`） | B | 基于三个字段的值相等。 |
| `hashCode` | getter（`ServiceTopologyLayoutOptions`） | B | 三个字段的 `Object.hash`，与 `==` 一致。 |
| `ServiceTopologyLayout` | 类 | B | 不可变布局结果：画布大小、节点矩形、等级、边路径、设备分组框、隐藏边、交叉数。 |
| `size` | 字段（`ServiceTopologyLayout`） | B | 拓扑的计算画布大小。 |
| `nodeRects` | 字段（`ServiceTopologyLayout`） | B | 节点 id → 放置 `Rect`（分组设备的矩形是其标题标签页）。 |
| `nodeRanks` | 字段（`ServiceTopologyLayout`） | B | 节点 id → 分配整数等级（列）。 |
| `edgePaths` | 字段（`ServiceTopologyLayout`） | B | 绘制边 → 预路由正交折线（按身份作键）。 |
| `groupRects` | 字段（`ServiceTopologyLayout`） | B | 设备节点 id → 设备分组框矩形；不分组时为空。 |
| `hiddenEdges` | 字段（`ServiceTopologyLayout`） | B | 设备分组框所隐含的设备→自身服务边的身份集合；不路由也不绘制。 |
| `crossings` | 字段（`ServiceTopologyLayout`） | B | 扫描后留下的等级间交叉数，按 `countCrossings` 的度量。 |
| `ServiceTopologyLayout.new` | 构造函数（`ServiceTopologyLayout`） | B | const 构造函数：四个必填字段；`groupRects`/`hiddenEdges` 默认为空，`crossings` 默认 0。 |
| `nodeWidth` | 静态 const（`ServiceTopologyLayout`） | B | 默认节点卡片宽（204.0）。 |
| `nodeHeight` | 静态 const（`ServiceTopologyLayout`） | B | 默认节点卡片高（76.0）。 |
| `portChipSize` | 静态 const（`ServiceTopologyLayout`） | B | 紧凑端口 chip 宽/高（52.0）。 |
| `rankGap` | 静态 const（`ServiceTopologyLayout`） | B | 等级列间水平间隙（38.0）。 |
| `verticalGap` | 静态 const（`ServiceTopologyLayout`） | B | 堆叠节点间最小垂直间隙（24.0）。 |
| `padding` | 静态 const（`ServiceTopologyLayout`） | B | 画布边缘填充（24.0）。 |
| `rowGap` | 静态 const（`ServiceTopologyLayout`） | B | 上一行较高节点之外的行间距（36.0）。 |
| `containerHeaderHeight` | 静态 const（`ServiceTopologyLayout`） | B | 设备分组框标题标签页的高度（40.0）。 |
| `containerPadding` | 静态 const（`ServiceTopologyLayout`） | B | 设备分组框围绕成员及标题下方的内边距（12.0）。 |
| `_routingMargin` | 静态 const（`ServiceTopologyLayout`） | B | 为路由边保留的额外画布边距（72.0）。 |
| `_routingClearance` | 静态 const（`ServiceTopologyLayout`） | B | 路由期间应用到节点矩形的障碍膨胀（14.0）。 |
| `_routingEscape` | 静态 const（`ServiceTopologyLayout`） | B | 每个节点垂直退出/进入桩长度（18.0）。 |
| `_routingTrackGap` | 静态 const（`ServiceTopologyLayout`） | B | 平行路由轨道/车道间间距（22.0）。 |
| [`build`](#build) | 静态方法（`ServiceTopologyLayout`） | A | 为拓扑图计算节点位置、设备分组框和预路由边路径。 |
| [`_deviceGroups`](#_devicegroups) | 静态方法（`ServiceTopologyLayout`） | A | 找出画作设备分组框的设备及其成员节点 id。 |
| [`_headerRanks`](#_headerranks) | 静态方法（`ServiceTopologyLayout`） | A | 分组设备节点离开列后重新稠密化等级。 |
| [`_placeNodes`](#_placenodes) | 静态方法（`ServiceTopologyLayout`） | A | 把节点放入等级列、减少交叉，并把行变为 y 位置。 |
| [`_keepGroupsTogether`](#_keepgroupstogether) | 静态方法（`ServiceTopologyLayout`） | A | 重排一个等级，使每个设备分组框的成员连续。 |
| [`_rowPositions`](#_rowpositions) | 静态方法（`ServiceTopologyLayout`） | A | 把紧凑行值变为按内容定尺寸的 y 位置。 |
| [`_sweepCrossings`](#_sweepcrossings) | 静态方法（`ServiceTopologyLayout`） | A | 用交替重心扫描减少边交叉。 |
| [`_orderPositions`](#_orderpositions) | 静态方法（`ServiceTopologyLayout`） | A | 给每个已放置节点一个在其等级内严格有序的位置。 |
| [`countCrossings`](#countcrossings) | 静态方法（`ServiceTopologyLayout`） | A | 统计跨等级线的边对顺序交换（为测试公开）。 |
| [`_placeContainers`](#_placecontainers) | 静态方法（`ServiceTopologyLayout`） | A | 围绕成员绘制设备分组框并放置标题标签页。 |
| [`_compactRankRows`](#_compactrankrows) | 静态方法（`ServiceTopologyLayout`） | A | 把行变为 y 位置前在一个等级内压实期望行。 |
| [`_compactDesiredRows`](#_compactdesiredrows) | 静态方法（`ServiceTopologyLayout`） | A | 移除只被无可见节点路由保留的行间隙。 |
| [`_compactRowValueMap`](#_compactrowvaluemap) | 静态方法（`ServiceTopologyLayout`） | A | 从稀疏期望行值构建紧凑值映射。 |
| [`_compactRowValue`](#_compactrowvalue) | 静态方法（`ServiceTopologyLayout`） | A | 为一个原始期望行查找压实行值。 |
| [`_nodeRanks`](#_noderanks) | 静态方法（`ServiceTopologyLayout`） | A | 传播逐节点等级、可选对齐终点域名，并稠密化。 |
| [`_alignSiblingPortRanks`](#_alignsiblingportranks) | 静态方法（`ServiceTopologyLayout`） | A | 把兄弟入口/公共端口节点拉到相同等级。 |
| `_nodeWidth` | 静态方法（`ServiceTopologyLayout`） | B | 节点卡片宽，节点紧凑时 `portChipSize`。 |
| `_nodeHeight` | 静态方法（`ServiceTopologyLayout`） | B | 节点卡片高，节点紧凑时 `portChipSize`。 |
| [`_routeRows`](#_routerows) | 静态方法（`ServiceTopologyLayout`） | A | 沿虚拟行轴给每条路由分配首选行。 |
| [`_desiredRows`](#_desiredrows) | 静态方法（`ServiceTopologyLayout`） | A | 从路由/邻居派生每个节点首选行。 |
| [`_routeEdges`](#_routeedges) | 静态方法（`ServiceTopologyLayout`） | A | 入口点：把每条绘制边路由为正交折线。 |
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
| [`_compareRoutesForLayout`](#_compareroutesforlayout) | 静态方法（`ServiceTopologyLayout`） | A | 按车道、方法、然后目标排序一个源的路由。 |
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
| `_RoutedSegments` | 类 | B | 迄今已路由的段，按轴坐标建索引供拥塞评分。 |
| `all` | 字段（`_RoutedSegments`） | B | 每个已路由段，按插入顺序。 |
| `_horizontal` | 字段（`_RoutedSegments`） | B | 水平段，按 y 排序。 |
| `_vertical` | 字段（`_RoutedSegments`） | B | 垂直段，按 x 排序。 |
| [`addAll`](#addall) | 方法（`_RoutedSegments`） | A | 把段追加到 `all` 并插入有序轴索引。 |
| [`cost`](#cost) | 方法（`_RoutedSegments`） | A | 候选段的拥塞代价，只访问附近的段。 |
| [`_lowerBound`](#_lowerbound) | 静态方法（`_RoutedSegments`） | A | 二分查找键不小于某值的第一个索引。 |
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

**行数说明：** `grep -c '/// Purpose:' service_topology_layout.dart` 返回 **71**。其中一个是在 `_routeRows` 内声明的本地 `deviceKey` 辅助（在该条目中描述，不占表格行），因此 **70** 个表格行带 `/// Purpose:` 注释。上面声明表有 **115** 行，因为它还列出 45 个不带该注释的声明：8 个类/枚举声明本身（`ServiceTopologyLayoutOptions`、`ServiceTopologyLayout`、`_TopologySide`、`_RoutingGridBase`、`_RoutedSegments`、`_Segment`、`_RouteState`、`_RouteHeap`）、20 个数据字段（`ServiceTopologyLayoutOptions` 上 3 个、`ServiceTopologyLayout` 上 7 个、`_RoutingGridBase` 上 2 个、`_RoutedSegments` 上 3 个、`_Segment` 上 2 个、`_RouteState` 上 2 个、`_RouteHeap` 上 1 个）、15 个常量（`ServiceTopologyLayout` 上 13 个 `static const` + 顶层 `_epsilon`/`_rowEpsilon`），以及 2 个单行 getter `_Segment.horizontal`/`.vertical`。70 + 45 = 115。Tier A：45 行。

## 文档

### `static ServiceTopologyLayout build(ServiceTopologyGraph graph, List<ServiceRoute> routes, double viewportWidth, {ServiceTopologyLayoutOptions options = const ServiceTopologyLayoutOptions()})` <a id="build"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 131 行）。
- **用途：** 为一个图/路由集合/视口/选项计算节点矩形、等级、画布大小、预路由边折线，并在分组时计算设备分组框和隐藏边。
- **输入：** `graph`（节点 + 边）、`routes`（驱动行分组）、`viewportWidth`（最小画布宽）、`options`（设备分组、终点域名对齐、交叉消减扫描次数上限）。
- **返回：** 带 `size`、`nodeRects`、`nodeRanks`、`edgePaths`、`groupRects`、`hiddenEdges`、`crossings` 的新 `ServiceTopologyLayout`。
- **副作用：** 无——对输入纯函数。
- **算法：**
  1. 构建 `nodeMap`（id → 节点）和 `validEdges`——`from`/`to` 都解析到真实节点的边；悬空边静默丢弃。构建 `incoming`/`outgoing` 邻接集合。
  2. 若 `options.groupByDevice`，计算 `groups`（[`_deviceGroups`](#_devicegroups)）及其逆映射 `memberGroup`（成员 id → 设备节点 id）；否则两者都为空。
  3. `hiddenEdges` = 从分组设备节点到其自身某个 **service** 成员的每条有效边；`drawnEdges` = 其余有效边。
  4. 计算 `routeRows`（[`_routeRows`](#_routerows)，存在任何分组时传 `byDevice`），然后计算 `desiredRows`（[`_desiredRows`](#_desiredrows)）。
  5. 从所有有效边计算 `nodeRanks`（[`_nodeRanks`](#_noderanks)，`alignDomainSinks` 取自 `options`）；分组时用 [`_headerRanks`](#_headerranks) 重新定级。
  6. 全局压实 `desiredRows`（[`_compactDesiredRows`](#_compactdesiredrows)），然后用 [`_placeNodes`](#_placenodes)（绘制边、`memberGroup`、`options.crossingSweeps`）放置除分组设备节点外的每个节点，它返回矩形、行目标和交叉数。
  7. 分组时，[`_placeContainers`](#_placecontainers) 围绕设备分组框移动矩形，并添加每个分组设备的标题标签页；其设备分组框矩形成为 `groupRects`。
  8. 画布 `size` = `max(viewportWidth, maxRight + padding + _routingMargin)` × `max(360.0, maxBottom + padding + _routingMargin)`，基于节点**和**设备分组框矩形计算。
  9. 只路由绘制边（[`_routeEdges`](#_routeedges)）得 `edgePaths`。
- **用法：**
  ```dart
  final layout = ServiceTopologyLayout.build(
    request.graph,
    request.routes,
    request.viewportWidth.toDouble(),
    options: request.options,
  );
  ```
  （`lib/features/services/views/service_topology_page.dart`，`_calculateLayout`，第 163–168 行，在 `await Future<void>.delayed(Duration.zero)` 之后，因此不在当前帧内运行。）
- **备注：** 等级纯来自边图（含隐藏边），行来自路由/邻居；两者在 `_placeNodes` 中汇合。分组时，分组设备节点离开等级列、成为分组框标题；隐藏边在 `edgePaths` 中没有条目。

### `static Map<String, List<String>> _deviceGroups(ServiceTopologyGraph graph)` <a id="_devicegroups"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 248 行）。
- **用途：** 找出布局画作设备分组框的设备。
- **输入：** `graph`。
- **返回：** 设备节点 id → 成员节点 id，按图中顺序。
- **副作用：** 无。
- **算法：** 把每个 `device` 节点的 `deviceId` 映射到其节点 id。收集 `deviceId` 映射到某设备节点的每个 `service`、`endpoint` 或 `remoteEntry` 节点。只保留至少有一个 `service` 成员的设备。
- **用法：**
  ```dart
  final groups = options.groupByDevice
      ? _deviceGroups(graph)
      : const <String, List<String>>{};
  ```
  （`build`，第 155–157 行。）
- **备注：** 被某跳点名但不承载服务的设备（如路由器）保持普通卡片，其远程入口保持自由 chip。

### `static Map<String, int> _headerRanks(Map<String, int> ranks, Map<String, List<String>> groups)` <a id="_headerranks"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 281 行）。
- **用途：** 分组设备节点离开列后重新给图定级。
- **输入：** `ranks`（来自 `_nodeRanks`）、`groups`（来自 `_deviceGroups`）。
- **返回：** 每个非分组节点的稠密等级；每个分组设备节点得到其成员中最小的等级。
- **副作用：** 无。
- **算法：** 收集非分组节点使用的不同等级，排序，并重映射为 `0..N`。然后把每个分组设备的等级设为其成员新等级的最小值。
- **用法：**
  ```dart
  if (groups.isNotEmpty) nodeRanks = _headerRanks(nodeRanks, groups);
  ```
  （`build`，第 191 行。）
- **备注：** 只容纳分组设备的列（通常是等级 0）消失，因此画布左侧不留空带。标题等级供边路由（`_portOffsets`）使用。

### `static ({Map<String, Rect> rects, Map<String, double> targets, int crossings}) _placeNodes(List<ServiceTopologyNode> nodes, Map<String, int> nodeRanks, Map<String, double> desiredRows, List<ServiceTopologyEdge> edges, Map<String, String> memberGroup, int sweeps)` <a id="_placenodes"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 316 行）。
- **用途：** 把节点放入等级列、减少交叉，并把行变为 y 位置。
- **输入：** `nodes`（等级列中的每个节点——分组设备节点被排除）、`nodeRanks`、`desiredRows`（已全局压实）、`edges`（绘制边）、`memberGroup`（不分组时为空）、`sweeps`（重心扫描次数上限）。
- **返回：** 一个记录：`rects`（节点 id → 矩形）、`targets`（节点 id → 其行要求的 y，在其等级内上方节点把它往下推之前）和 `crossings`（扫描后留下的交叉数）。
- **副作用：** 无。
- **算法：**
  1. 按等级分组 `nodes`；按 `desiredRows` 排序每个等级，平局按 `_roleOrder`、然后 `_laneBucket`、然后小写标签。
  2. 每个等级的列宽是其最宽的 `_nodeWidth`；`rankX` 每个等级推进 `rankWidth + rankGap`。
  3. 对每个等级：计算等级本地紧凑行（[`_compactRankRows`](#_compactrankrows)）；分组时用 [`_keepGroupsTogether`](#_keepgroupstogether) 重排 id；按该顺序把该等级已排序的行值分发（行只被置换）到 `rows` 和 `order[rank]`。
  4. 用两端都在 `nodes` 中的边，对 `order`/`rows` 运行 [`_sweepCrossings`](#_sweepcrossings)；它可能进一步置换行，并返回交叉数。
  5. 用 [`_rowPositions`](#_rowpositions) 构建 `rowY`。
  6. 从上到下走每个等级：`target = rowY(rows[id])`（记录在 `targets` 中），`y = max(target, previousBottom + verticalGap)`；x 在其列内居中。
- **用法：**
  ```dart
  final placed = _placeNodes(
    [
      for (final node in graph.nodes)
        if (!groups.containsKey(node.id)) node,
    ],
    nodeRanks,
    compactRows,
    drawnEdges,
    memberGroup,
    options.crossingSweeps,
  );
  ```
  （`build`，第 193–203 行。）
- **备注：** 不再有固定行步长：每行高度等于其最高节点加 `rowGap`（卡片行 112 px，chip 行 88 px）。`verticalGap` 只在压实会让一个等级内两个节点碰撞时作为下限生效。`targets` 让 `_placeContainers` 把成员重新放回它们自己的行。

### `static List<String> _keepGroupsTogether(List<String> ids, Map<String, String> memberGroup)` <a id="_keepgroupstogether"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 419 行）。
- **用途：** 重排一个等级，使每个设备分组框的成员相邻。
- **输入：** `ids`（按行顺序的该等级）、`memberGroup`。
- **返回：** 相同的 id，每个设备分组框的成员被移到其第一个成员处，保持它们自己的顺序。
- **副作用：** 无。
- **算法：** 遍历 `ids`；自由节点原样输出；遇到某组的第一个成员时，按 `ids` 顺序输出该组每个成员；跳过已输出的 id。
- **用法：**
  ```dart
  final grouped = memberGroup.isEmpty
      ? ids
      : _keepGroupsTogether(ids, memberGroup);
  ```
  （`_placeNodes`，第 369–371 行。）
- **备注：** 每个等级 O(n²)。调用方按新顺序分发该等级已排序的行值，因此该等级的行仍是原来行的一个置换。

### `static double Function(double) _rowPositions(Map<String, double> rows, Map<String, ServiceTopologyNode> nodeMap)` <a id="_rowpositions"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 449 行）。
- **用途：** 把紧凑行值变为按内容定尺寸的 y 位置。
- **输入：** `rows`（节点 id → 紧凑行）、`nodeMap`。
- **返回：** 一个把行值映射为其 y 位置的函数。
- **副作用：** 无。
- **算法：**
  1. 对每个不同行值（在 `_rowEpsilon` 内匹配），记录所有等级中该行上最高的 `_nodeHeight`。
  2. 排序这些值。第一个从 `padding + max(0, value) × (nodeHeight + rowGap)` 开始；每个后续值从上一个之下 `(next − this) × (height(this) + rowGap)` 处开始。
  3. 返回的函数查找该值（在 `_rowEpsilon` 内）；未知值回退为 `padding + row × (nodeHeight + rowGap)`。
- **用法：**
  ```dart
  final rowY = _rowPositions(rows, nodeMap);
  ```
  （`_placeNodes`，第 390 行；在第 401 行应用。）
- **备注：** 压实产生的小数间隙保持其比例，端口 chip 行比卡片行矮。这取代了旧的固定 `nodeHeight + 44` 步长。

### `static int _sweepCrossings(Map<int, List<String>> order, Map<String, double> rows, Map<String, int> ranks, List<ServiceTopologyEdge> edges, Map<String, String> memberGroup, int sweeps)` <a id="_sweepcrossings"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 495 行）。
- **用途：** 用交替重心扫描减少边交叉。
- **输入：** `order`（等级 → 按行顺序的 id）、`rows`（id → 紧凑行）、`ranks`、`edges`（已放置节点间的绘制边）、`memberGroup`、`sweeps`（上限）。
- **返回：** 它留下的顺序的交叉数。
- **副作用：** 扫描改进时修改 `order` 和 `rows`。
- **算法：**
  1. `best` = 对当前顺序计算 [`countCrossings`](#countcrossings)，位置取自 [`_orderPositions`](#_orderpositions)；若 `sweeps <= 0` 或其为 0 则直接返回。
  2. 从 `edges` 构建无向邻居集合。
  3. 每次扫描：偶数次向下（等级升序，跳过第一个），奇数次向上（降序，跳过最后一个）。对每个有 2+ 个 id 的等级，节点的重心是其在较低等级（向下）或较高等级（向上）的邻居的平均行，没有则取自身行。
  4. 组成单元——每个自由节点一个，每个设备分组框一个（其成员按等级顺序）——以其成员重心的平均值为键；按键稳定排序，再按原单元索引。
  5. 若顺序改变，按新顺序分发该等级已排序的行值、重新计数，只在计数**严格**更低时保留新顺序/行。
  6. 一次扫描无改进，或 `best` 达到 0 时停止。
- **用法：**
  ```dart
  final crossings = _sweepCrossings(
    order,
    rows,
    nodeRanks,
    [
      for (final edge in edges)
        if (nodeMap.containsKey(edge.from) && nodeMap.containsKey(edge.to))
          edge,
    ],
    memberGroup,
    sweeps,
  );
  ```
  （`_placeNodes`，第 378–389 行。）
- **备注：** 因为行只在等级内被置换，直链在原位保持笔直，结果的交叉数绝不多于输入。每次试验都重新统计每个边对，因此扫描代价为 O(sweeps × ranks × E² × span)。

### `static Map<String, double> _orderPositions(Map<int, List<String>> order, Map<String, double> rows)` <a id="_orderpositions"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 593 行）。
- **用途：** 给每个已放置节点一个在其等级内严格有序的位置。
- **输入：** `order`、`rows`。
- **返回：** id → `rows[id] + index × 1e-4`，其中 `index` 是节点在其等级列表中的位置。
- **副作用：** 无。
- **算法：** 对每个等级带索引的 id 列表做一次映射推导。
- **用法：**
  ```dart
  var best = countCrossings(ranks, _orderPositions(order, rows), edges);
  ```
  （`_sweepCrossings`，第 503 行；每个试验顺序也在第 572 行调用。）
- **备注：** 同一行值上的两个节点仍按列表顺序堆叠；索引项让 `countCrossings` 能看到该顺序。

### `static int countCrossings(Map<String, int> ranks, Map<String, double> positions, List<ServiceTopologyEdge> edges)` <a id="countcrossings"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法（公开）。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 613 行）。
- **用途：** 统计等级间的边交叉。
- **输入：** `ranks`（节点 id → 等级）、`positions`（节点 id → 任何能给等级排序的度量）、`edges`。
- **返回：** 两条边从一条等级线到下一条交换顺序的次数，对每个边对求和。
- **副作用：** 无。
- **算法：**
  1. 把每条边变为跨度 `(r0, p0) → (r1, p1)`，其中 `r0 < r1`；跳过同一等级内的边，或一端不在 `ranks`/`positions` 中的边。
  2. 对每对跨度，遍历它们共享的等级线（`max(r0)..min(r1)`），在每条线上线性插值每个跨度的位置；取差值的符号（`_rowEpsilon` 内为 0）。非零符号之间每次变化计一次交叉。
- **用法：**
  ```dart
  final count = countCrossings(
    ranks,
    _orderPositions(trialOrder, trialRows),
    edges,
  );
  ```
  （`_sweepCrossings`，第 570–574 行；`test/service_topology_layout_test.dart` 也在第 228 行直接调用。）
- **备注：** 这是推广到长边的双层逆序数。两条边在某条线上相遇、然后以交换后的顺序继续，计一次；只共享一个端点的两条边不计。O(E² × span)。

### `static ({Map<String, Rect> rects, Map<String, Rect> groups}) _placeContainers(Map<String, Rect> flat, Map<String, double> targets, Map<String, int> ranks, Map<String, List<String>> groups)` <a id="_placecontainers"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 678 行）。
- **用途：** 围绕成员绘制设备分组框。
- **输入：** `flat`（来自 `_placeNodes` 的矩形）、`targets`（来自 `_placeNodes` 的行目标）、`ranks`、`groups`（设备节点 id → 成员 id）。
- **返回：** 一个记录：`rects`（调整后的矩形，现在包含每个分组设备的标题标签页）和 `groups`（按设备节点 id 作键的设备分组框矩形）。
- **副作用：** 无。
- **算法：**
  1. 构建条目：每个设备分组框一个（top = 其最高成员的 flat top），每个自由节点一个；按 top 排序，平局时设备分组框在自由节点之前，再按索引。
  2. 每个等级维护一个下限，以及一个运行中的 `shift`。自由节点落在 `max(flatTop + shift, floor + verticalGap)`，并抬高其等级的下限。
  3. 设备分组框跨越其成员的等级。`memberTop` = `item.top + shift + headerSpace`（`headerSpace = containerHeaderHeight + containerPadding`），并对其等级中的每个下限抬到 `floor + verticalGap + headerSpace`；`shift` 变为 `memberTop − item.top`。
  4. 成员（按 flat top）移到 `memberTop + target − firstTarget`，但至少在其等级中上一个成员之下 `verticalGap`。
  5. 设备分组框是成员边界向外扩 `containerPadding`，顶部位于 `memberTop − headerSpace`。标题标签页高 `containerHeaderHeight`，位于设备分组框左上角，宽 `min(container.width, nodeWidth)`。跨度内每个等级以设备分组框的底部为其下限。
- **用法：**
  ```dart
  final contained = _placeContainers(
    nodeRects,
    placed.targets,
    nodeRanks,
    groups,
  );
  ```
  （`build`，第 207–212 行。）
- **备注：** 成员回到它们的行目标，因此不会保留另一台设备的节点在它们上方留下的间隙；运行中的 shift 让下方的行在各等级间保持对齐。按构造，每个成员都位于其设备分组框内，没有自由节点与设备分组框相交，设备分组框之间也从不重叠，因此不需要回退。标题较窄，因此边仍可从上方进入设备分组框。设备分组框矩形不是路由障碍；标题标签页是。

### `static Map<String, double> _compactRankRows(List<ServiceTopologyNode> nodes, Map<String, double> desiredRows)` <a id="_compactrankrows"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 786 行）。
- **用途：** 只为一个等级节点重算紧凑行号，使*其他*等级未用行不在此等级留下空白带。
- **输入：** `nodes`（已过滤到一个等级）、`desiredRows`（全局映射）。
- **返回：** `Map<String, double>` — 节点 id → 紧凑行，本地到此等级。
- **副作用：** 无。
- **算法：** 经 [`_compactRowValueMap`](#_compactrowvaluemap) 只从本等级节点 `desiredRows` 值构建行值映射，然后经 [`_compactRowValue`](#_compactrowvalue) 查找每个节点压实值。
- **用法：**
  ```dart
  final rankRows = _compactRankRows(rankNodes, desiredRows);
  ```
  （`_placeNodes`，第 367 行。）
- **备注：** 因为压实等级本地，相同原始 `desiredRows` 值可在两个不同等级映射到不同压实行号——这是刻意的（每等级只关心自己垂直间隙）。

### `static Map<String, double> _compactDesiredRows(ServiceTopologyGraph graph, Map<String, double> desiredRows)` <a id="_compactdesiredrows"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 804 行）。
- **用途：** 移除全局 `desiredRows` 映射中只因 `_routeRows` 为无对应可见节点的路由/源保留行而存在的行间隙。
- **输入：** `graph`、`desiredRows`。
- **返回：** `Map<String, double>` — 与 `desiredRows` 相同键，压实值。
- **副作用：** 无。
- **算法：** 收集并排序实际属于 `graph.nodes` 条目的期望行值（`usedRows`）；为空则原样返回输入。经 [`_compactRowValueMap`](#_compactrowvaluemap) 从 `usedRows` 构建压实映射，然后经 [`_compactRowValue`](#_compactrowvalue) 重映射 `desiredRows` 每个条目。
- **用法：**
  ```dart
  final compactRows = _compactDesiredRows(graph, desiredRows);
  ```
  （`build`，第 192 行。）
- **备注：** 这是*全局*压实遍（一次跨所有等级），在 `_placeNodes` 前运行；`_compactRankRows` 是之后以更细粒度服务相同目的的第二次等级本地压实遍。

### `static Map<double, double> _compactRowValueMap(Iterable<double> rows)` <a id="_compactrowvaluemap"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 829 行）。
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
  （`_compactRankRows`，第 790–792 行；也 `_compactDesiredRows`，第 816 行。）
- **备注：** `clamp(0.72, 1.0)` 边界是压实行能多"松"或多"紧"的承载负载常量；`_rowPositions` 随后按该行高度加 `rowGap` 缩放每一步。

### `static double _compactRowValue(double row, Map<double, double> rowMap)` <a id="_compactrowvalue"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 856 行）。
- **用途：** 经 `rowMap` 解析一个原始期望行值到压实行，容忍浮点漂移。
- **输入：** `row`、`rowMap`（来自 `_compactRowValueMap`）。
- **返回：** 匹配压实值，或 `rowMap` 无键在 `_rowEpsilon` 内时 `row` 不变。
- **副作用：** 无。
- **算法：** 线性扫描 `rowMap.entries`，匹配 `(row - entry.key).abs() <= _rowEpsilon`；每次查找 O(n)（n = 不同压实行）。
- **用法：**
  ```dart
  node.id: _compactRowValue(desiredRows[node.id] ?? 0, rowMap),
  ```
  （`_compactRankRows`，第 795 行；也 `_compactDesiredRows`，第 820 行。）
- **备注：** 回退原始 `row`（而非抛）意味着构建它所用映射外的值原样保留而非重映射。

### `static Map<String, int> _nodeRanks(ServiceTopologyGraph graph, List<ServiceTopologyEdge> validEdges, {bool alignDomainSinks = false})` <a id="_noderanks"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 872 行）。
- **用途：** 经松弛从边图派生每个节点水平等级（列），可选把终点域名移到最后一个等级，然后把等级压缩为稠密 `0..N` 序列。
- **输入：** `graph`、`validEdges`、`alignDomainSinks`（默认 `false`；`build` 传 `options.alignDomainSinks`，其默认为 `true`）。
- **返回：** `Map<String, int>` — 节点 id → 稠密等级。
- **副作用：** 无。
- **算法：**
  1. 播种 `ranks`：`device` 节点从等级 0 开始；每个其他节点 kind 从等级 1 开始。
  2. 设 `rankLimit = max(2, nodeCount + 1)`。至多 `nodeCount + 2` 次迭代：对每条边松弛 `ranks[edge.to] = max(ranks[edge.to], min(rankLimit, ranks[edge.from] + 1))`；每次迭代也调用 [`_alignSiblingPortRanks`](#_alignsiblingportranks) 并把其 `changed` 结果 OR 进去。完整遍无变化时提前停止。
  3. 若 `alignDomainSinks`：每个不是任何有效边 `from` 的 `domain` 节点取找到的最高等级。
  4. 收集 `uniqueRanks`（排序、去重）并把每个节点原始等级重映射到其索引，产生无未用间隙的稠密 `0..N` 等级序列。
- **用法：**
  ```dart
  var nodeRanks = _nodeRanks(
    graph,
    validEdges,
    alignDomainSinks: options.alignDomainSinks,
  );
  ```
  （`build`，第 186–190 行。）
- **备注：** `rankLimit` 封顶传播，使循环边图不能无界增长等级——它保证终止（`nodeCount + 2` 界也是硬迭代上限）而非彻底防环。终点域名对齐把最终地址排在右侧同一列。

### `static bool _alignSiblingPortRanks(List<ServiceTopologyEdge> edges, Map<String, ServiceTopologyNode> nodeMap, Map<String, int> ranks)` <a id="_alignsiblingportranks"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 925 行）。
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
  （`_nodeRanks`，第 893–895 行，每次松弛迭代调用一次。）
- **备注：** 只提升等级（绝不降低），与 `_nodeRanks` 单调松弛一致；在同一循环内调用意味着兄弟对齐本身可触发下次迭代进一步边松弛。

### `static Map<String, double> _routeRows(ServiceTopologyGraph graph, List<ServiceRoute> routes, Map<String, ServiceTopologyNode> nodeMap, {bool byDevice = false})` <a id="_routerows"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 988 行）。
- **用途：** 沿虚拟行轴给每条路由分配首选行，按源服务分组并排序，使同源路由落在相邻行。
- **输入：** `graph`、`routes`、`nodeMap`、`byDevice`（先按设备排序源）。
- **返回：** `Map<String, double>` — 路由 id → 行分数。
- **副作用：** 无。
- **算法：**
  1. 按 `_serviceNodeId(route.sourceServiceId)` 把路由分组进 `routesBySource`。
  2. 收集所有源 id（每个路由源，加每个 `localService` 节点，无论有无路由）并排序：有 `byDevice` 时先按本地辅助 `deviceKey`（本地设备在远程设备——角色 `remoteDevice`——之前，然后小写设备标签，然后设备 id）；然后按小写标签。
  3. 按该顺序走源，维护运行 `row`：无路由源仍把 `row` 推进 1.35（保留间隙而不发出任何行条目）；有路由源经 [`_compareRoutesForLayout`](#_compareroutesforlayout) 排序它们、给每条分配顺序行（每路由 `row += 1`）、然后在下一源前加额外 0.38 间隙。
- **用法：**
  ```dart
  final routeRows = _routeRows(
    graph,
    routes,
    nodeMap,
    byDevice: groups.isNotEmpty,
  );
  ```
  （`build`，第 173–178 行。）
- **备注：** `byDevice` 让每台设备的服务占据一段连续的行，使其设备分组框保持紧凑。1.35/0.38/1.0 间距常量正是 [`_compactRowValueMap`](#_compactrowvaluemap) 的 `clamp(0.72, 1.0)` 步骤稍后规范化的东西。

### `static Map<String, double> _desiredRows(ServiceTopologyGraph graph, List<ServiceRoute> routes, Map<String, double> routeRows, Map<String, Set<String>> incoming, Map<String, Set<String>> outgoing)` <a id="_desiredrows"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1063 行）。
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
  final desiredRows = _desiredRows(
    graph,
    routes,
    routeRows,
    incoming,
    outgoing,
  );
  ```
  （`build`，第 179–185 行。）
- **备注：** 邻居传播 10 迭代上限（步骤 3）意味着非常长的其他未路由节点链在 10 遍内传播未达时仍可落入步骤 4 回退——实践中受典型拓扑直径限制。

### `static Map<ServiceTopologyEdge, List<Offset>> _routeEdges(List<ServiceTopologyEdge> validEdges, Map<String, Rect> rects, Map<String, int> ranks, Size size)` <a id="_routeedges"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1133 行）。
- **用途：** 边路由入口点：一次构建共享障碍/网格状态，然后对照它路由每条边，累积已路由段使较后边避开较早边。
- **输入：** `validEdges`（`build` 只传绘制边）、`rects`（放置节点矩形，含标题标签页）、`ranks`、`size`（画布）。
- **返回：** `Map<ServiceTopologyEdge, List<Offset>>` — 每条边一个折线（路由失败可能为空）。
- **副作用：** 无（构建新鲜本地集合）。
- **算法：**
  1. 经 [`_portOffsets`](#_portoffsets) 计算 `outgoingOffsets`/`incomingOffsets`，使共享节点侧边扇出。
  2. 构建 `obstacles` 为每个节点矩形膨胀 `_routingClearance`，然后构建共享 [`_RoutingGridBase.fromObstacles`](#_routinggridbase-fromobstacles) 和一个空的 `_RoutedSegments` 索引。
  3. 按 `_edgeSpan` 降序（最长优先）、然后 `_laneRank(edge.lane)`、然后 `'from->to'` 字符串排序边——最可能需要真实寻路的边先认领直接走廊，较短边之后绕它们路由。
  4. 按该顺序对每条边用共享障碍/网格和迄今已路由段调用 [`_routeEdge`](#_routeedge)；把结果段（经 [`_segmentsForPath`](#_segmentsforpath)）用 [`addAll`](#addall) 加入 `routedSegments`。
- **用法：**
  ```dart
  final edgePaths = _routeEdges(drawnEdges, nodeRects, nodeRanks, size);
  ```
  （`build`，第 227 行。）
- **备注：** `routedSegments` 在整个调用单调累积——拥塞代价因此顺序依赖：较早路由（更长）边先挑净空走廊，较后边付绕行代价。设备分组框矩形不是障碍。

### `static Map<ServiceTopologyEdge, double> _portOffsets(List<ServiceTopologyEdge> edges, Map<String, Rect> rects, Map<String, int> ranks, {required bool outgoing})` <a id="_portoffsets"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1191 行）。
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
  （`_routeEdges`，第 1139–1150 行。）
- **备注：** 每次布局调用两次（每方向一次），因为边在其 `from` 节点退出扇出独立于其 `to` 节点进入扇出。标题标签页只有 40 px 高，因此其 `maxOffset` 为 8。

### `static List<Offset> _routeEdge({required Rect from, required Rect to, required double fromOffset, required double toOffset, required List<Rect> obstacles, required _RoutingGridBase gridBase, required _RoutedSegments routedSegments, required Size size})` <a id="_routeedge"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1235 行）。
- **用途：** 路由两个放置节点矩形间一条边，试多个锚侧候选并保留产生最低分有效路径的那个。
- **输入：** `from`/`to` 矩形、逐边端口偏移、共享 `obstacles`/`gridBase`、`routedSegments`（迄今已路由段的索引）、画布 `size`。
- **返回：** 简化正交折线，或每个候选锚对都失败时 `[]`。
- **副作用：** 无。
- **算法：**
  1. 确定 `forward`（`to` 在 `from` 右）和 `sameRank`（中心水平 8px 内）；挑首选 `startSide`/`endSide`：同等级边从朝画布中线之外的任一侧（`left`/`right`）退出/进入，否则自然前向/后向侧。
  2. 构建有序、去重候选列表：首选对先，然后四个 `{left,right}×{left,right}` 组合作回退。
  3. 对每个候选：经 `_anchor` + 偏移计算锚点，然后沿 `_sideVector` 用 `_routingEscape` 推出并钳制到画布（`_clampOffset`）得 `startExit`/`endEntry`。任一脚桩被节点自己膨胀矩形外障碍阻塞（[`_stubBlocked`](#_stubblocked)）则跳过候选。
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
  （`_routeEdges`，第 1170–1179 行。）
- **备注：** 所有候选锚对（至多 5 个）无条件试（首个成功不提前退出）——这是固定、小组合搜索而非贪婪首匹配，用有界额外工作量换更干净挑选路由。

### `static List<Offset>? _fastRouteBetween({required Offset start, required Offset goal, required List<Rect> obstacles, required _RoutedSegments routedSegments, required Size size})` <a id="_fastroutebetween"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1330 行）。
- **用途：** 回退完整网格寻路前在两个已转义点间试一连串廉价、直接正交候选路径。
- **输入：** `start`、`goal`（已推过其节点脚桩）、`obstacles`、`routedSegments`、`size`。
- **返回：** 找到的最佳净空简化折线，候选都非障碍净空时 `null`（信号调用方回退 `_routeBetween`）。
- **副作用：** 无。
- **算法：** 经本地 `addCandidate` 辅助构建并测试候选，它吸附、简化（[`_simplifyPolyline`](#_simplifypolyline)）并障碍检查（[`_pathClear`](#_pathclear)）每个形态：
  1. 直线，只在 `start`/`goal` 已共享 x 或 y（`_epsilon` 内）时。
  2. 两个单弯"L"形态（`goal.dx, start.dy` 角和 `start.dx, goal.dy` 角）。
  3. 经中点（`midX`/`midY`）的两个"Z"形态。
  4. 至多四条经 `start`/`goal` 包围盒外每侧（左/右/上/下）偏移 `_routingTrackGap` 轨道的"绕包围盒"路由，钳制到画布。
  在所有障碍净空候选中按 [`_pathScore`](#_pathscore) 排序并返回最低；候选列表最终为空时 `null`。
- **用法：**
  ```dart
  final middle =
      _fastRouteBetween(
        start: startExit,
        goal: endEntry,
        obstacles: obstacles,
        routedSegments: routedSegments,
        size: size,
      ) ??
      _routeBetween(...);
  ```
  （`_routeEdge`，第 1292–1307 行。）
- **备注：** 真实拓扑中大多数边（同或相邻等级、中间无物）在此解决，从不运行 `_routeBetween` 的 A* 风格网格搜索。

### `static List<Offset>? _routeBetween({required Offset start, required Offset goal, required List<Rect> obstacles, required _RoutingGridBase gridBase, required _RoutedSegments routedSegments, required Size size})` <a id="_routebetween"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1390 行）。
- **用途：** 用共享+逐边坐标网格上的 A* 风格优先队列搜索找两个转义点间避障正交路径。
- **输入：** `start`、`goal`、`obstacles`、`gridBase`（共享轨道）、`routedSegments`、`size`。
- **返回：** 简化折线，或 `start`/`goal` 不落在网格坐标或找不到路径时 `null`。
- **副作用：** 无（每次调用构建新鲜本地搜索状态）。
- **算法：**
  1. 用逐调用轨道扩展 `gridBase` 共享 `xs`/`ys`：`start`/`goal` 本身及其周围 ±`_routingTrackGap`，以及 `routedSegments.all` 中每个段（其端点，加其垂直轴上 ±`_routingTrackGap`）——使新车道在既有已路由边旁打开，而非迫使一切经相同共享轨道。
  2. 把组合坐标排序进 `xValues`/`yValues`；定位 `start`/`goal` 网格索引；任一非精确网格点返回 `null`。
  3. 分配类型化搜索状态：`distances`（`Float64List`，`pointCount * 3`，以无穷大填充）、`previous`（`Int32List`，同样大小，`-1` = 无前驱）和 `stepCosts`（`Float64List`，`pointCount * 2`，每个水平/垂直网格步一槽，`NaN` = 尚未计算）。
  4. 在状态 `(point, direction)` 上运行 Dijkstra/A* 搜索（`direction`：0 = 开始、1 = 水平移动、2 = 垂直移动），用 [`_RouteHeap`](#add) 作开集，按 `g + heuristic` 排序，启发式为到 `goal` 的 `_manhattan` 距离。
  5. 对每个弹出状态扩展 4 个正交网格邻居。该步代价在 `stepCosts` 的 `min(point, next) * 2 + (vertical ? 1 : 0)` 处查找；首次使用时计算：[`_segmentBlocked`](#_segmentblocked) 时为 `-1`，否则为 `_manhattan` 长度 + [`_congestionCost`](#_congestioncost)，并缓存。被阻塞（负）的步跳过。总计 = 步代价 + 26.0 转弯惩罚（只在 `currentDirection` 已设且不同时）。只在 `nextCost + _epsilon < distances[nextState]` 时松弛并推入。
  6. 一旦弹出位于 `goalPoint` 的状态立即停止（最小堆保证最低代价先出）；沿 `previous` 回溯直到 `-1` 重建路径、反转并简化（[`_simplifyPolyline`](#_simplifypolyline)）。
- **用法：**
  ```dart
  _routeBetween(
    start: startExit,
    goal: endEntry,
    obstacles: obstacles,
    gridBase: gridBase,
    routedSegments: routedSegments,
    size: size,
  );
  ```
  （`_routeEdge`，第 1300–1307 行，作为 `_fastRouteBetween` 的 `??` 回退。）
- **备注：** 一个步会从两端、以多个方向被到达，而其障碍和拥塞在一次搜索中都不变，因此缓存它与重新计算结果相同（所有代价都是 0.5 的倍数，因此求和顺序不会改变它们）。结合 `_RoutedSegments` 索引，这把一个 43 节点 / 64 边的图在开发机上从约 23–29 s 降到不分组约 1.1 s / 分组约 0.2 s；61 节点 / 91 边的合成测试图不分组约 3.4 s、分组约 0.4 s 完成布局。每点 3 状态方向编码让转弯惩罚能区分"继续直行"与"刚转弯"。

### `static double _pathScore(List<Offset> path, _RoutedSegments routedSegments)` <a id="_pathscore"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1524 行）。
- **用途：** 评分完整形成路由路径，使竞争锚对/候选路径可排名并挑最干净。
- **输入：** `path`、`routedSegments`（先前提交段，供拥塞）。
- **返回：** `path.length < 2` 时 `double.infinity`；否则越低越好分数。
- **副作用：** 无。
- **算法：** 对每个连续点对：加 `_manhattan` 距离、加对照 `routedSegments` 的 [`_congestionCost`](#_congestioncost)，并在段方向（由 `dx` epsilon 测试得出的水平 vs 垂直）不同于前段方向时加 26.0 惩罚。
- **用法：**
  ```dart
  final score = _pathScore(path, routedSegments);
  if (score < bestScore) {
    bestScore = score;
    bestPath = path;
  }
  ```
  （`_routeEdge`，第 1315–1319 行；也 `_fastRouteBetween`，第 1376–1381 行。）
- **备注：** 用与 `_routeBetween` 搜索代价相同 26.0 转弯惩罚常量，使快速路由器和 A* 路由器找到的路径在一致刻度评分。

### `static bool _pathClear(List<Offset> path, List<Rect> obstacles)` <a id="_pathclear"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1547 行）。
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
  （`_fastRouteBetween` 本地 `addCandidate`，第 1340–1341 行。）
- **备注：** 无。

### `static bool _stubBlocked(Offset a, Offset b, List<Rect> obstacles, {required Rect allowed})` <a id="_stubblocked"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1560 行）。
- **用途：** 检查节点短退出/进入脚桩段是否被*其他*障碍阻塞（排除节点自己膨胀矩形，脚桩预期从中穿出）。
- **输入：** `a`、`b`（脚桩端点）、`obstacles`、`allowed`（节点自己膨胀矩形，忽略）。
- **返回：** 任何非 `allowed` 障碍阻塞脚桩时 `true`。
- **副作用：** 无。
- **算法：** 循环 `obstacles`，跳过与 `allowed` `_sameRect` 的任何；对每个剩余单障碍列表调用 [`_segmentBlocked`](#_segmentblocked)，第一个命中返回 `true`。
- **用法：**
  ```dart
  if (_stubBlocked(start, startExit, obstacles, allowed: fromObstacle) ||
      _stubBlocked(endEntry, end, obstacles, allowed: toObstacle)) {
    continue;
  }
  ```
  （`_routeEdge`，第 1288–1291 行。）
- **备注：** 无 `allowed` 排除，每个脚桩都会被其离开/进入的节点本身标记为阻塞，因为脚桩必然从该节点自己膨胀边界开始。

### `static bool _segmentBlocked(Offset a, Offset b, List<Rect> obstacles)` <a id="_segmentblocked"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1578 行）。
- **用途：** 对照完整障碍列表检查一个正交段。
- **输入：** `a`、`b`、`obstacles`。
- **返回：** 段非正交、或其包围矩形（膨胀 0.6）重叠任何障碍时 `true`。
- **副作用：** 无。
- **算法：** `dx` 和 `dy` 都不在 `_epsilon` 内（即段对角）时直接当阻塞——路由器只产生轴对齐段，因此这兼作不变量检查。否则构建段包围 `Rect`（两端点 min/max）、膨胀 0.6（小边缘接触边距），返回是否有任何障碍 `.overlaps` 它。
- **用法：**
  ```dart
  stepCost = _segmentBlocked(a, b, obstacles)
      ? -1
      : _manhattan(a, b) + _congestionCost(a, b, routedSegments);
  ```
  （`_routeBetween` 的步代价缓存，第 1490–1492 行。）
- **备注：** 路由器的核心几何原语（`_pathClear`、`_stubBlocked` 和 `_routeBetween` 中每个首次计算的网格步）。

### `static double _congestionCost(Offset a, Offset b, _RoutedSegments routedSegments)` <a id="_congestioncost"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1599 行）。
- **用途：** 惩罚经、近、或跨已路由段运行的候选段，使共享走廊的多条边分散进不同平行轨道而非重叠。
- **输入：** `a`、`b`（候选段端点）、`routedSegments`。
- **返回：** `double` — 跨已路由段求和的惩罚。
- **副作用：** 无。
- **算法：** 委托给 [`_RoutedSegments.cost`](#cost)：每个已路由段，同线且跨度重叠为 180.0，否则在 `_routingTrackGap * 0.85` 内且跨度重叠的平行段为 58.0，否则垂直交叉为 28.0。
- **用法：**
  ```dart
  : _manhattan(a, b) + _congestionCost(a, b, routedSegments);
  ```
  （`_routeBetween`，第 1492 行；也 `_pathScore`，第 1532 行。）
- **备注：** 结果与之前对每个已路由段的线性扫描完全相同；现在只访问候选所在轴附近的段。字面车道复用被惩罚约 6 倍于交叉，"过近但未重合"介于两者。

### `static List<_Segment> _segmentsForPath(List<Offset> path)` <a id="_segmentsforpath"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1610 行）。
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
  （`_routeEdges`，第 1180–1181 行。）
- **备注：** 丢弃零长度段正是让 `_RoutedSegments.addAll` 能把每个段恰好归档为水平或垂直之一的原因。

### `static List<Offset> _simplifyPolyline(List<Offset> points)` <a id="_simplifypolyline"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1625 行）。
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
  final path = _simplifyPolyline([
    start,
    startExit,
    ...middle.skip(1),
    end,
  ]);
  ```
  （`_routeEdge`，第 1309–1314 行。）
- **备注：** 这是专门、仅正交简化（非 Douglas-Peucker）——它只移除恰好沿两个网格轴之一共线的点。

### `static int _compareRoutesForLayout(ServiceRoute a, ServiceRoute b)` <a id="_compareroutesforlayout"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1695 行）。
- **用途：** 为行分配排序一个服务的路由：先按访问车道、然后 HTTP 方法、然后显示目标。
- **输入：** `a`、`b`（`ServiceRoute`）。
- **返回：** 标准 `Comparator<ServiceRoute>` `int`（负/零/正）。
- **副作用：** 无。
- **算法：** 三层打破平局，一层不同即返回：(1) `_laneOrder(serviceAccessLaneForRoute(route))`（local < vpn < public）；(2) 首跳方法名（`_routeMethodName`），字母序；(3) `serviceRouteDisplayTarget(route)`，字母序、不区分大小写。
- **用法：**
  ```dart
  final orderedRoutes = [...sourceRoutes]..sort(_compareRoutesForLayout);
  ```
  （`_routeRows`，第 1048 行。）
- **备注：** `serviceAccessLaneForRoute`/`serviceRouteDisplayTarget` 定义在 `lib/features/services/services/service_analysis.dart`，非本文件。

### `static double _median(List<double> values)` <a id="_median"></a>
- **种类：** `ServiceTopologyLayout` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1749 行）。
- **用途：** 计算行分数列表统计中位数，用于从路由/邻居派生节点期望行。
- **输入：** `values`（每个调用点非空）。
- **返回：** `double` — 中位数值。
- **副作用：** 无。
- **算法：** 排序 `values` 副本；计数奇数时返回精确中间元素；偶数时返回两中间元素平均。
- **用法：**
  ```dart
  if (scores.isNotEmpty) desired[node.id] = _median(scores);
  ```
  （`_desiredRows`，第 1089 行，以及第 1105 行邻居传播再次调用。）
- **备注：** 用中位数而非平均意味着一个离群路由行不把节点整个位置拖向它。

### `factory _RoutingGridBase.fromObstacles(List<Rect> obstacles, Size size)` <a id="_routinggridbase-fromobstacles"></a>
- **种类：** `_RoutingGridBase` 的工厂构造函数。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1858 行）。
- **用途：** 构建从节点障碍和画布大小一次派生的共享 x/y 路由轨道坐标集合，跨每条边寻路调用复用。
- **输入：** `obstacles`（膨胀节点矩形）、`size`（画布）。
- **返回：** 带填充 `xs`/`ys` 的新 `_RoutingGridBase`。
- **副作用：** 无。
- **算法：** 总是添加四个画布边距轨道（每轴 `padding/2` 和 `size - padding/2`）。对每个障碍，在其边界*外*偏移 `_routingTrackGap` 添加四个轨道（`left - gap`、`right + gap`、`top - gap`、`bottom + gap`）——刻意绝不添加经障碍自己边界或中心的轨道，使共享网格绝不把段路由得贴节点边界（或穿它）。所有值都钳制到画布并吸附到 0.5。
- **用法：**
  ```dart
  final gridBase = _RoutingGridBase.fromObstacles(obstacles, size);
  ```
  （`_routeEdges`，第 1154 行——每次 `build()` 调用构建一次并传给每个 `_routeEdge`/`_routeBetween` 调用。）
- **备注：** `_routeBetween` 仍在此共享基础上为该单边的特定 start/goal/已路由段添加逐调用轨道。

### `void addAll(Iterable<_Segment> segments)` <a id="addall"></a>
- **种类：** `_RoutedSegments` 的方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1898 行）。
- **用途：** 把段加入列表和轴索引。
- **输入：** `segments`。
- **返回：** `void`。
- **副作用：** 修改 `all`、`_horizontal`、`_vertical`。
- **算法：** 把每个段追加到 `all`；水平段按其 y 的 [`_lowerBound`](#_lowerbound) 插入 `_horizontal`，否则垂直段按其 x 的下界插入 `_vertical`，使两个列表都保持有序。
- **用法：**
  ```dart
  routedSegments.addAll(_segmentsForPath(path));
  ```
  （`_routeEdges`，第 1181 行。）
- **备注：** 一个段归档为水平或垂直，绝不同时两者——`_segmentsForPath` 丢弃零长度段。插入每段 O(n)（列表移位），每个已路由段只付一次。

### `double cost(Offset a, Offset b)` <a id="cost"></a>
- **种类：** `_RoutedSegments` 的方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1928 行）。
- **用途：** 评分候选段与已路由段的冲突程度。
- **输入：** `a`、`b` — 候选的两端。
- **返回：** `double` — 每个同线且跨度与之重叠的已路由段计 180，否则每个在 `0.85 × _routingTrackGap` 内且跨度重叠的平行段计 58，外加每个它穿过的垂直段计 28。
- **副作用：** 无。
- **算法：** 对位于 `y` 的水平候选：从 `y - near` 二分查找 `_horizontal`，并在 `s.a.dy <= y + near` 时遍历；每个与候选 [`sameAxisOverlap`](#sameaxisoverlap) 的加 180，否则每个 [`nearAxisOverlap`](#nearaxisoverlap) 的加 58。然后在 `[minX - _epsilon, maxX + _epsilon]` 上遍历 `_vertical`，每个被候选 [`crosses`](#crosses) 的加 28。垂直候选交换两轴镜像此过程。
- **用法：**
  ```dart
  ) => routedSegments.cost(a, b);
  ```
  （`_congestionCost`，第 1603 行。）
- **备注：** 应用与逐一对照每个段相同的三项测试，但只访问候选带内的段——平行段在其线的近距离内，垂直段其线位于其跨度内——因此产生相同的和。代价都是整数，因此求和顺序不会改变结果。

### `static int _lowerBound(List<_Segment> sorted, double value, double Function(_Segment) key)` <a id="_lowerbound"></a>
- **种类：** `_RoutedSegments` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 1988 行）。
- **用途：** 找到键不小于 `value` 的第一个索引。
- **输入：** `sorted`（按 `key` 升序）、`value`、`key`。
- **返回：** `int` — 插入点，没有时为 `sorted.length`。
- **副作用：** 无。
- **算法：** 在 `[low, high)` 上的标准二分查找：`key(sorted[middle]) < value` 时把 `low` 移过 `middle`，否则把 `high` 缩到 `middle`。
- **用法：**
  ```dart
  var i = _lowerBound(_horizontal, y - near, (s) => s.a.dy);
  ```
  （`cost`，第 1935、1949、1959、1973 行；`addAll`，第 1903 和 1908 行。）
- **备注：** 无。

### `bool sameAxisOverlap(_Segment other)` <a id="sameaxisoverlap"></a>
- **种类：** `_Segment` 的方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 2027 行）。
- **用途：** 确定两段是否位于完全相同水平或垂直线且跨度重叠——即视觉重合。
- **输入：** `other`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 两段都 `horizontal` 且共享相同 y（`_epsilon` 内）时对 x 跨度委托 [`_rangesOverlap`](#_rangesoverlap)；都 `vertical` 且共享相同 x 时对 y 跨度委托 `_rangesOverlap`；否则 `false`（不同轴或偏移线）。
- **用法：**
  ```dart
  if (candidate.sameAxisOverlap(other)) {
  ```
  （[`_RoutedSegments.cost`](#cost)，第 1940 和 1964 行——180 档。）
- **备注：** 比 `nearAxisOverlap` 更严格——线必须在 `_epsilon` 内重合。

### `bool nearAxisOverlap(_Segment other, double distance)` <a id="nearaxisoverlap"></a>
- **种类：** `_Segment` 的方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 2044 行）。
- **用途：** 确定两平行段是否在调用方提供 `distance` 内运行且跨度重叠——用作较软"过近"拥塞信号而非硬障碍。
- **输入：** `other`、`distance`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 与 `sameAxisOverlap` 相同结构，但线重合测试用 `<= distance` 而非 `< _epsilon`。
- **用法：**
  ```dart
  } else if (candidate.nearAxisOverlap(other, near)) {
  ```
  （[`_RoutedSegments.cost`](#cost)，第 1942 和 1966 行，其中 `near = _routingTrackGap * 0.85`——58 档。）
- **备注：** `0.85` 系数让"近"比实际轨道间距略紧，使适当间距的相邻车道不被惩罚。

### `bool crosses(_Segment other)` <a id="crosses"></a>
- **种类：** `_Segment` 的方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 2061 行）。
- **用途：** 确定水平和垂直段是否实际相交（真实 T/X 交叉），而非仅仅邻近。
- **输入：** `other`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** `this` 水平且 `other` 垂直时检查 `other` 的 x 落在 `this` x 跨度内*且* `this` 的 y 落在 `other` y 跨度内（都经 [`_between`](#_between)）；对称 case 镜像；同轴两段按此定义绝不"交叉"。
- **用法：**
  ```dart
  if (candidate.crosses(_vertical[i])) cost += 28.0;
  ```
  （[`_RoutedSegments.cost`](#cost)，第 1953 和 1977 行——28 档。）
- **备注：** 垂直交叉被惩罚远轻于车道复用，因为交叉在正交布局中不可避免且实际不混乱。

### `static bool _rangesOverlap(double a1, double a2, double b1, double b2)` <a id="_rangesoverlap"></a>
- **种类：** `_Segment` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 2078 行）。
- **用途：** 确定两个 1-D 范围（各给两个无序端点）是否重叠超过 `_epsilon`。
- **输入：** `a1`、`a2`、`b1`、`b2`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 把两个范围规范化为 `(min, max)` 对；当且仅当 `max(aMin, bMin) < min(aMax, bMax) - _epsilon` 时重叠——严格重叠要求，仅在端点接触的范围不算。
- **用法：**
  ```dart
  return _rangesOverlap(a.dx, b.dx, other.a.dx, other.b.dx);
  ```
  （`sameAxisOverlap`，第 2031 和 2034 行；`nearAxisOverlap`，第 2048 和 2051 行。）
- **备注：** 严格比较让同线仅端到端接触的两段不被当作重叠惩罚。

### `static bool _between(double value, double start, double end)` <a id="_between"></a>
- **种类：** `_Segment` 的静态方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 2091 行）。
- **用途：** 两端带 `_epsilon` 松量的包含范围成员测试，用来测试交点是否落在段跨度内。
- **输入：** `value`、`start`、`end`（无序）。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 规范化为 `minValue = min(start, end) - _epsilon`、`maxValue = max(start, end) + _epsilon`；返回 `value >= minValue && value <= maxValue`。
- **用法：**
  ```dart
  return _between(other.a.dx, a.dx, b.dx) &&
      _between(a.dy, other.a.dy, other.b.dy);
  ```
  （`crosses`，第 2063–2068 行。）
- **备注：** 与 `_rangesOverlap` 不同，这刻意是包含的，使恰在段端点处的交叉仍算。

### `void add(_RouteState state)` <a id="add"></a>
- **种类：** `_RouteHeap` 的方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 2125 行）。
- **用途：** 插入新搜索状态进二叉最小堆，保持堆序。
- **输入：** `state`。
- **返回：** 无。
- **副作用：** 追加进 `_items` 并经 `_bubbleUp` 重排。
- **算法：** 把 `state` 追加到 `_items` 末尾，然后对其新索引调用 [`_bubbleUp`](#_bubbleup) 恢复最小堆不变量——标准二叉堆插入，`O(log n)`。
- **用法：**
  ```dart
  heap.add(_RouteState(startState, _manhattan(start, goal)));
  ```
  （`_routeBetween`，第 1460 行，播种搜索；也在第 1505 行为每个松弛邻居调用。）
- **备注：** 除标准二叉堆插入契约外无。

### `_RouteState removeFirst()` <a id="removefirst"></a>
- **种类：** `_RouteHeap` 的方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 2135 行）。
- **用途：** 弹出并返回最低代价状态（堆根），之后恢复堆序。
- **输入：** 无。
- **返回：** `_RouteState` — 最小代价条目。
- **副作用：** 修改 `_items`（移除最后元素，可能覆盖根）。
- **算法：** 保存 `_items.first`；移除并保存 `_items.removeLast()`；仍有条目时把移除的最后元素移入槽 0 并对其调用 [`_bubbleDown`](#_bubbledown)；返回保存的 first（根）值——标准二叉堆提取最小，`O(log n)`。
- **用法：**
  ```dart
  final current = heap.removeFirst();
  ```
  （`_routeBetween`，第 1464 行，主搜索循环。）
- **备注：** 正确处理单元素 case：`first` 和 `last` 是相同元素，`_items.isNotEmpty` 守卫跳过空堆 `_bubbleDown`。

### `void _bubbleUp(int index)` <a id="_bubbleup"></a>
- **种类：** `_RouteHeap` 的方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 2150 行）。
- **用途：** 插入后从 `index` 向上恢复最小堆不变量。
- **输入：** `index`。
- **返回：** `void`。
- **副作用：** 经 `_swap` 修改 `_items`。
- **算法：** `index > 0` 时计算 `parent = (index - 1) >> 1`；父 `.cost` 已 `<=` 当前项则停止；否则 `_swap` 它们并从 `parent` 继续。
- **用法：**
  ```dart
  void add(_RouteState state) {
    _items.add(state);
    _bubbleUp(_items.length - 1);
  }
  ```
  （`add`，第 2125–2128 行。）
- **备注：** 标准数组支撑二叉堆父索引算术（`(i - 1) >> 1`）。

### `void _bubbleDown(int index)` <a id="_bubbledown"></a>
- **种类：** `_RouteHeap` 的方法。
- **来源：** `lib/features/services/services/service_topology_layout.dart`（第 2164 行）。
- **用途：** 根被替换后从 `index` 向下恢复最小堆不变量。
- **输入：** `index`。
- **返回：** `void`。
- **副作用：** 经 `_swap` 修改 `_items`。
- **算法：** 循环：计算 `left = index*2+1`、`right = left+1`；找 `{index, left, right}`（边界检查）中 `.cost` 最小的（`smallest`）；仍 `index` 则停止；否则 `_swap` `index` 和 `smallest` 并从 `smallest` 继续。
- **用法：**
  ```dart
  if (_items.isNotEmpty) {
    _items[0] = last;
    _bubbleDown(0);
  }
  ```
  （`removeFirst`，第 2138–2141 行。）
- **备注：** 标准数组支撑二叉堆子索引算术（`i*2+1`、`i*2+2`）。
