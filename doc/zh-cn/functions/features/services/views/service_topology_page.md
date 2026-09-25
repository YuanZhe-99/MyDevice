# lib/features/services/views/service_topology_page.dart

[服务与拓扑](../../../../features/services-topology.md#views) 描述的全屏服务拓扑：`ServiceTopologyPage`——服务总览的拓扑卡片（[`service_list_page.md`](service_list_page.md)，`_openTopology`）带着由当前清单构建的 `ServiceTopologyGraph` 把它压入根导航器——以及它承载的画布 `_ServiceTopologyView`。本文件于 1.5.6 从 `service_list_page.dart` 拆出，随后获得了拓扑的交互：

- **选择。** 在选择模式下点击节点即选中它；经过它的路由（`relatedRoutesForNode`）由 `serviceTopologyHighlight` 点亮，其余节点变暗，其余边淡化。点击空白画布、选择 chip 或详情窗格的关闭按钮会清除选择。
- **详情。** 在手机上，点击还会打开详情底部面板；在 `useDetailTwoPane` 窗口上，则改为在画布旁放一个宽 `topologyDetailPaneWidth` 的非模态窗格。该窗格始终存在，因此选择从不改变画布宽度。在窗格中，路由行把高亮收窄到该路由，其编辑按钮打开路由编辑器。
- **筛选。** 应用栏操作打开一个含设备 chip、车道 chip 和搜索框的面板；页面构建并记忆化收窄后的图（`filterServiceTopologyInput`），徽章统计生效的部分。
- **图例。** 模式行下方可折叠的图例条（`ServiceTopologyLegend`），位于导出的画布之外。
- **适应窗口与重置。** 在移动模式下，图标按钮把画布适配进查看器（`fitTransform`），或重置其变换。
- **按设备分组。** 应用栏切换开关，在本次会话中默认打开，把 `groupByDevice` 传给布局：设备成为带标题标签页的设备分组框，设备到服务边被隐藏。它是布局请求的一部分，因此切换会重新布局同一个图。
- **起点。** 详情提供每个节点的「添加访问路径」操作（`_nodeActions`，来自 `ServiceAccessDraft.forNode`）：从服务或端点添加访问路径、通过 VPS 上的中继公开服务、为域名添加其他服务、为设备上的服务添加访问路径。每个操作都以预填该节点的方式打开引导式页面。
- **刷新。** 页面打开的每个编辑器——服务、路由、访问路径——都会被等待，之后页面经 `reload` 重新读取清单并重建其图（`_refresh`），因此编辑无需重新打开拓扑即可显示。

页面负责它自己的清单和图副本，以及模式、旋转、导出、分组、选择和筛选状态；视图负责延迟、缓存的布局（`_TopologyLayoutRequest` 是其缓存键）。节点卡片、边画家、图例以及图标、颜色和适配辅助来自 [`service_topology_widgets.md`](service_topology_widgets.md)；筛选和高亮逻辑来自 [`../services/service_analysis.md`](../services/service_analysis.md)；节点和边的放置来自 [`../services/service_topology_layout.md`](../services/service_topology_layout.md)。

**行数说明：** `grep -c 'Purpose:' service_topology_page.dart` 返回 **39**，下面每个声明一块（**18 个 Tier A / 21 个 Tier B**）。`_nodeActions` 的本地函数 `fromHere` 没有注释，也不占一行。类型别名 `ServiceTopologyInventory`（`reload` 返回的 `services`、`devices`、`routes` 记录）和 `_NodeAction`（操作的 `key`、`label`、`icon` 和 `draft`）同样不列出。`enum _TopologyInteractionMode { select, move }`（第 18 行）是无成员枚举，不单列：选择模式接上节点点击和背景点击，并滚动画布；移动模式去掉点击，并把画布包进 `InteractiveViewer`。私有常量 `_minScale`（0.35）、`_maxScale`（2.4）和 `_boundaryMargin`（180）是该查看器的限制，与 `fitTransform` 共用。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `_ServiceTopologyView`（构造函数） | 构造函数 | B | 创建画布组件：图、清单、布局选项、模式、旋转、捕获键、选择、点击、变换。 |
| `createState` | 方法（`_ServiceTopologyView`） | B | 创建画布的可变状态对象。 |
| `build` | 方法（组件，`_ServiceTopologyViewState`） | B | 在 `LayoutBuilder` 内布局画布，请求/显示缓存布局并记住视口。 |
| [`_ensureLayout`](#ensurelayout) | 方法（`_ServiceTopologyViewState`） | A | 为请求安排延迟布局计算，去重在途请求。 |
| [`_calculateLayout`](#calculatelayout) | 方法（`_ServiceTopologyViewState`） | A | 为一个请求运行布局引擎，仍最新时缓存结果。 |
| `_buildLoading` | 方法（组件辅助） | B | 渲染布局就绪前显示的小加载转圈。 |
| `_reportLayoutReady` | 方法（`_ServiceTopologyViewState`） | B | 布局就绪性变化时通知父级（延迟到下一帧）。 |
| [`fitToViewport`](#fittoviewport) | 方法（`_ServiceTopologyViewState`） | A | 经变换控制器把已布局的画布适配进视图。 |
| [`_buildViewer`](#buildviewer) | 方法（组件辅助） | A | 带选择状态渲染边和节点卡片，置于滚动视图（选择）或 `InteractiveViewer`（移动）中。 |
| [`_TopologyLayoutRequest`（构造函数）](#topologylayoutrequest-new) | 构造函数 | A | 创建布局缓存键值（图、路由、视口宽、布局选项）。 |
| [`==`](#equals) | 运算符（`_TopologyLayoutRequest`） | A | 按图/路由身份、视口宽和选项比较两个请求。 |
| [`hashCode`](#hashcode) | getter（`_TopologyLayoutRequest`） | A | 与其相等契约一致的请求哈希。 |
| `ServiceTopologyPage`（构造函数） | 构造函数 | B | 创建全屏拓扑页：清单、图、三个编辑器回调（各自在其编辑器关闭时完成）以及可选的 `reload`。 |
| `createState` | 方法（`ServiceTopologyPage`） | B | 创建页面可变状态对象。 |
| `dispose` | 方法（`_ServiceTopologyPageState`，组件生命周期） | B | 释放变换控制器。 |
| [`_visible`](#visible) | 方法（`_ServiceTopologyPageState`） | A | 当前筛选显示的图和路由，按筛选记忆化。 |
| [`_selectionIn`](#selectionin) | 方法（`_ServiceTopologyPageState`） | A | 在可见图上解析选中节点、其相关路由和高亮。 |
| [`_selectNode`](#selectnode) | 方法（`_ServiceTopologyPageState`） | A | 选中被点击的节点；没有窗格时打开详情面板。 |
| `_clearSelection` | 方法（`_ServiceTopologyPageState`） | B | 清除选择和聚焦路由。 |
| `_toggleRouteFocus` | 方法（`_ServiceTopologyPageState`） | B | 把高亮收窄到一条相关路由，或放宽回全部。 |
| `_setFilter` | 方法（`_ServiceTopologyPageState`） | B | 应用筛选并重置移动模式的变换。 |
| `_openFilters` | 方法（`_ServiceTopologyPageState`） | B | 打开筛选面板，列出承载服务的设备。 |
| [`_showDetailsSheet`](#showdetailssheet) | 方法（`_ServiceTopologyPageState`） | A | 在底部面板中显示节点详情，其操作调用各编辑器。 |
| [`_nodeActions`](#nodeactions) | 方法（`_ServiceTopologyPageState`） | A | 节点提供的「添加访问路径」操作，连同各自的草稿。 |
| `_openEditor` | 方法（`_ServiceTopologyPageState`） | B | 等待某个编辑器回调，然后 `_refresh`。 |
| [`_refresh`](#refresh) | 方法（`_ServiceTopologyPageState`） | A | 经 `reload` 读取清单并重建图。 |
| [`_exportTopologyImage`](#exporttopologyimage) | 方法（`_ServiceTopologyPageState`） | A | 把拓扑画布（含高亮）捕获为 PNG 并交给平台分享流程。 |
| [`build`](#pagebuild) | 方法（组件，`_ServiceTopologyPageState`） | A | 构建脚手架：筛选/旋转/导出操作、模式行、图例条、画布、详情窗格。 |
| `_buildModeRow` | 方法（组件辅助） | B | 选择 / 移动切换，移动模式下另加「适应窗口」和「重置」图标按钮。 |
| `_buildLegendStrip` | 方法（组件辅助） | B | 图例开关、图例，以及可清除选择的选择 chip。 |
| [`_buildDetailsPane`](#builddetailspane) | 方法（组件辅助） | A | 分栏窗口的详情窗格：一条提示，或选中节点的详情。 |
| `_buildNoMatch` | 方法（组件辅助） | B | 「没有符合筛选条件的内容」消息，带「清除筛选」按钮。 |
| `_TopologyNodeDetails`（构造函数） | 构造函数 | B | 为面板或窗格创建节点详情，连同节点的操作。 |
| [`build`](#detailsbuild) | 方法（组件，`_TopologyNodeDetails`） | A | 渲染节点、其设备和服务、其操作以及其路由。 |
| `_TopologyFilterSheet`（构造函数） | 构造函数 | B | 由一个筛选、设备 chip 和变更回调创建筛选面板。 |
| `createState` | 方法（`_TopologyFilterSheet`） | B | 创建面板的可变状态对象。 |
| `dispose` | 方法（`_TopologyFilterSheetState`，组件生命周期） | B | 释放搜索控制器。 |
| `_update` | 方法（`_TopologyFilterSheetState`） | B | 把变更应用到面板并交给页面。 |
| [`build`](#filterbuild) | 方法（组件，`_TopologyFilterSheetState`） | A | 渲染搜索框、车道 chip 和设备 chip。 |

## 文档

### `void _ensureLayout(_TopologyLayoutRequest request)` <a id="ensurelayout"></a>
- **种类：** `_ServiceTopologyViewState` 的方法。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 148 行）。
- **用途：** 为请求安排延迟布局计算，除非相同请求已在途。
- **输入：** `request`。
- **返回：** 无。
- **副作用：** 设 `_pendingRequest`；递增 `_layoutGeneration`；安排调用 [`_calculateLayout`](#calculatelayout) 的帧后回调。
- **算法：** 1. `_pendingRequest == request`（相同图/路由身份和视口宽——见 [`_TopologyLayoutRequest.==`](#equals)）时不做事返回（已在途）。2. 否则把 `request` 记录为 `_pendingRequest`、递增 `_layoutGeneration` 并把新值捕获为 `generation`。3. 注册 `WidgetsBinding.instance.addPostFrameCallback` 调用 `_calculateLayout(request, generation)`。
- **用法：** `build` 中每当 `_completedRequest != request || _layout == null`（即当前图/路由/视口组合尚未布局）时调用。
- **备注：** 这是 [服务与拓扑 — 拓扑图布局（高层）](../../../../features/services-topology.md#topology-graph-layout-high-level) 描述行为背后的机制——"全屏拓扑把昂贵布局推迟到首帧后，并按图、路由、宽度和旋转派生视口缓存布局，使模式变化……不重跑路由。"`_layoutGeneration` 计数器正是让新请求使仍在途旧请求失效的东西（见 [`_calculateLayout`](#calculatelayout)）。

### `Future<void> _calculateLayout(_TopologyLayoutRequest request, int generation)` <a id="calculatelayout"></a>
- **种类：** `_ServiceTopologyViewState` 的方法。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 162 行）。
- **用途：** 让出一帧后为一个请求运行拓扑布局引擎，仍是最新请求时缓存结果。
- **输入：** `request`；`generation` — 此计算被安排时捕获的 `_layoutGeneration` 值。
- **返回：** `Future<void>`。
- **副作用：** 调用 `ServiceTopologyLayout.build`；仍最新时 `setState` 更新 `_layout`/`_completedRequest`/`_pendingRequest`。
- **算法：** 1. `await Future<void>.delayed(Duration.zero)` — 让出至少一帧，使这不阻塞安排它的帧。2. 未挂载、`generation` 不再等于 `_layoutGeneration`、或 `_pendingRequest` 不再等于 `request`（新请求取代此请求）时退出。3. 计算 `ServiceTopologyLayout.build(request.graph, request.routes, request.viewportWidth.toDouble(), options: request.options)`（见 [`service_topology_layout.md#build`](../services/service_topology_layout.md#build)）。4. 重新检查相同三个过期条件（计算本身可能耗时到新请求到达）。5. `setState` 存储布局、把 `request` 标记为 `_completedRequest` 并清除 `_pendingRequest`。
- **用法：** 只经 [`_ensureLayout`](#ensurelayout) 注册的帧后回调调用。
- **备注：** 双重过期检查（`ServiceTopologyLayout.build` *前*和*后*）正是防止慢速、现已过时布局计算（如旋转前视口宽的）在新请求已完成后破坏状态的东西。

### `void fitToViewport()` <a id="fittoviewport"></a>
- **种类：** `_ServiceTopologyViewState` 的方法。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 225 行）。
- **用途：** 把已布局的画布适配进视图。
- **输入：** 无。
- **返回：** `void`。
- **副作用：** 设置 `widget.transformationController.value`。
- **算法：** 取缓存布局的尺寸（旋转四分之一圈数为奇数时交换宽高，因为查看器看到的是旋转后的画布）和 `build` 记住的视口尺寸；把控制器设为 `fitTransform(canvas, viewport, minScale: _minScale, maxScale: _maxScale, boundaryMargin: _boundaryMargin)`（见 [`service_topology_widgets.md`](service_topology_widgets.md#fittransform)）。
- **用法：** 页面的「适应窗口」按钮经 `GlobalKey<_ServiceTopologyViewState>` 调用它：`onPressed: () => _viewKey.currentState?.fitToViewport()`。
- **备注：** 首次布局之前或没有控制器时什么也不做。页面在「重置」、旋转和每次筛选变化时把控制器重置为单位矩阵，因为为一个画布算出的适配对下一个画布是错的。

### `Widget _buildViewer(BuildContext context, ServiceTopologyLayout layout, int turns)` <a id="buildviewer"></a>
- **种类：** `_ServiceTopologyViewState` 的方法（组件辅助）。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 254 行）。
- **用途：** 在查看器内构建画布——边和节点卡片。
- **输入：** `context`；`layout` — 缓存的布局；`turns` — 旋转的四分之一圈数，0 到 3。
- **返回：** `Widget`。
- **副作用：** 无。
- **算法：** 1. 一个尺寸为 `layout.size` 的 `Stack`：先是带 `ServiceTopologyEdgePainter`（传入高亮）的 `CustomPaint`，再为每个已布局节点放一张 `ServiceTopologyNodeCard`：键为 `topology-node-<id>`，选中节点带 `selected`，作为分组框标题的设备节点（`layout.groupRects`）带 `header`，高亮不包含它时带 `dimmed`，`onTap` 只在选择模式下设置；画家把分组框绘制在边之下。2. 有旋转时包进 `RotatedBox`，再包进导出用的 `RepaintBoundary`。3. 选择模式：一个键为 `topology-canvas` 的 `GestureDetector`，其点击清除选择，内含两层嵌套滚动视图。移动模式：一个使用页面 `TransformationController` 的 `InteractiveViewer`，带 `_boundaryMargin`、`_minScale` 和 `_maxScale`。
- **用法：** `build`，在当前请求的布局就绪之后。
- **备注：** 节点卡片上的点击在手势竞技场中胜过背景点击，因此只有未命中任何卡片的点击才会清除选择。选择变化只触发重绘：布局请求不包含高亮。

### `const _TopologyLayoutRequest({required this.graph, required this.routes, required this.viewportWidth, required this.options})` <a id="topologylayoutrequest-new"></a>
- **种类：** 构造函数。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 341 行）。
- **用途：** 创建用作拓扑布局缓存键的值。
- **输入：** `graph`、`routes`、`viewportWidth`、`options` — 视图的 `ServiceTopologyLayoutOptions`。
- **返回：** 新 `_TopologyLayoutRequest`。
- **副作用：** 无。
- **算法：** 普通字段赋值。
- **用法：** `_ServiceTopologyViewState.build` 每次 `build` 调用构造一次。
- **备注：** 无。

### `bool operator ==(Object other)` <a id="equals"></a>
- **种类：** `_TopologyLayoutRequest` 的运算符。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 354 行）。
- **用途：** 为缓存复用目的比较两个布局请求。
- **输入：** `other`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** `identical(this, other)` 为 true、或 `other` 是带 `identical` `graph`、`identical` `routes`、相等 `viewportWidth` 和相等 `options` 的 `_TopologyLayoutRequest` 时为 `true`。
- **用法：** 经 `build`（`_completedRequest == request`）和 [`_ensureLayout`](#ensurelayout)（`_pendingRequest == request`）中的 `==`/`!=` 隐式使用。
- **备注：** 对 `graph`/`routes` 用**身份**（`identical`）而非值相等——两个结构相等但不同的 `ServiceTopologyGraph`/路由列表实例会比较不等。这是刻意的：任何新 `buildServiceTopology`/[`_load`](service_list_page.md#load) 调用即使结果图看起来相同也使缓存失效，并避免每次构建深结构比较。`viewportWidth` 比较前舍入为 `int`（在 `_ServiceTopologyViewState.build`），避免微小约束抖动强制重布局。`options` 按值比较，因此切换"按设备分组"会重新布局同一个图实例而不重建它。

### `int get hashCode` <a id="hashcode"></a>
- **种类：** `_TopologyLayoutRequest` 的 getter。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 369 行）。
- **用途：** 产生与上面基于身份的 `==` 一致的哈希码。
- **输入：** 无。
- **返回：** `int`。
- **副作用：** 无。
- **算法：** `Object.hash(identityHashCode(graph), identityHashCode(routes), viewportWidth, options)`。
- **用法：** 本文件无任何地方显式调用——`_TopologyLayoutRequest` 值只经 `==` 比较，从不存 `Map`/`Set`——但 Dart 要求每当覆盖 `==` 时 `hashCode` 与之一致。
- **备注：** 用 `identityHashCode`（匹配 `==` 对 `graph`/`routes` 的身份基础比较），因此从不同底层 `graph`/`routes` 对象构建的两个结构相等实例也哈希不同。

### `({ServiceTopologyGraph graph, List<ServiceRoute> routes}) _visible()` <a id="visible"></a>
- **种类：** `_ServiceTopologyPageState` 的方法。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 491 行）。
- **用途：** 返回当前筛选显示的图和路由。
- **输入：** 无。
- **返回：** 筛选什么都不收窄时，返回页面自己的 `graph` 和 `routes`；否则返回 `buildServiceTopology` 用 `filterServiceTopologyInput` 给出的服务和路由构建的图。
- **副作用：** 把筛选后的图连同其筛选缓存到 `_filtered`。
- **算法：** 1. 筛选未生效 ⇒ `(_graph, _routes)`。2. 已有针对相等筛选的缓存 ⇒ 缓存的图和路由。3. 否则用 [`filterServiceTopologyInput`](../services/service_analysis.md#filterservicetopologyinput) 收窄清单，构建图，缓存并返回。
- **用法：** `build`、`_showDetailsSheet`。
- **备注：** 筛选变化前一直返回相同的实例，正是这一点让视图以身份为键的布局缓存（[`==`](#equals)）在各次重建之间持续命中——每次 build 都新建图会导致每一帧都重新布局。

### `_selectionIn(ServiceTopologyGraph graph, List<ServiceRoute> routes)` <a id="selectionin"></a>
- **种类：** `_ServiceTopologyPageState` 的方法。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 524 行）。
- **用途：** 在可见图上解析选择。
- **输入：** `graph`、`routes` — 来自 [`_visible`](#visible)。
- **返回：** 一个记录，含选中节点、其相关路由和 `ServiceTopologyHighlight`；未选中任何节点或筛选隐藏了该节点时为 null。
- **副作用：** 把结果缓存到 `_lit`。
- **算法：** 1. 在 `graph` 中找 id 为 `_selectedNodeId` 的节点。2. `_lit` 是为同一图实例、同一节点和同一聚焦路由构建的时，复用它。3. 否则取 `relatedRoutesForNode(node, routes, services:)`；聚焦路由在其中时收窄到它；以该节点为 `selectedNodeId` 计算 [`serviceTopologyHighlight`](../services/service_analysis.md#servicetopologyhighlight)；缓存。
- **用法：** `build`。
- **备注：** 选择保持期间，缓存维持同一个高亮实例，因此边画家的 `shouldRepaint` 在无关的重建中保持为 false。节点被筛选隐藏的选择会被保留而非清除，并随该节点一同回来。

### `void _selectNode(ServiceTopologyNode node)` <a id="selectnode"></a>
- **种类：** `_ServiceTopologyPageState` 的方法。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 563 行）。
- **用途：** 选中被点击的节点。
- **输入：** `node`。
- **返回：** `void`。
- **副作用：** 设置 `_selectedNodeId`，清除 `_focusedRouteId`；没有详情窗格时打开详情面板。
- **算法：** `setState`；然后，当窗口的 `useDetailTwoPane` 为 false 时调用 [`_showDetailsSheet`](#showdetailssheet)。
- **用法：** 视图的 `onNodeTap`。
- **备注：** 选择保存在页面中而不是面板中，因此面板关闭后高亮仍保留。

### `void _showDetailsSheet(ServiceTopologyNode node)` <a id="showdetailssheet"></a>
- **种类：** `_ServiceTopologyPageState` 的方法。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 642 行）。
- **用途：** 在底部面板中显示节点详情。
- **输入：** `node`。
- **返回：** `void`。
- **副作用：** 显示模态底部面板；其操作会弹出面板并调用 `widget.onEditService`、`widget.onEditRoute` 或 `widget.onAddAccess`（经 `_openEditor`）。
- **算法：** 在可见路由上解析相关路由，并在带拖动手柄、滚动受控的面板中显示 [`_TopologyNodeDetails`](#detailsbuild)（键 `topology-details-sheet`，`shrinkWrap`）。路由行打开该路由的编辑器；「编辑服务」打开服务编辑器；节点的每个操作（[`_nodeActions`](#nodeactions)）以其草稿打开引导式访问路径页。
- **用法：** [`_selectNode`](#selectnode)，在没有详情窗格的窗口上。
- **备注：** 取代 1.5.6 拆分时视图中的 `_showNodeDetails`；其内容是共享的详情组件，因此面板和窗格不会彼此漂移。

### `List<_NodeAction> _nodeActions(ServiceTopologyNode node)` <a id="nodeactions"></a>
- **种类：** `_ServiceTopologyPageState` 的方法。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 690 行）。
- **用途：** 列出节点提供的「添加访问路径」操作。
- **输入：** `node`。
- **返回：** 按按钮顺序排列的操作；中继、远程入口以及服务已不存在的节点为空。
- **副作用：** 无。
- **算法：** 在页面的清单上取 `ServiceAccessDraft.forNode(node, …)`（[`service_access_patterns.md`](../services/service_access_patterns.md#fornode)）。服务节点提供「从这里添加访问路径」（键 `topology-action-from-here`，普通源草稿）。指明了中继的草稿再加上「通过此中继公开服务」（`topology-action-expose`）。否则，对于非服务节点：域名提供「为此目标添加其他服务」（`topology-action-target`），设备提供「为此设备上的服务添加访问路径」（`topology-action-device`），端点 chip 提供「从这里添加访问路径」。
- **用法：** [`_showDetailsSheet`](#showdetailssheet) 和 [`_buildDetailsPane`](#builddetailspane)。
- **备注：** VPS 上的中继服务同时显示两种服务操作：访问中继本身，以及通过它公开另一个服务。

### `Future<void> _refresh()` <a id="refresh"></a>
- **种类：** `_ServiceTopologyPageState` 的方法。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 755 行）。
- **用途：** 用当前清单重建图。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `widget.reload`；替换 `_services`、`_devices`、`_routes` 和 `_graph`；清除 `_filtered` 和 `_lit` 缓存。
- **算法：** 没有 `reload` 时直接返回。否则等待它；若仍处于挂载状态，则以新列表及基于它们的 `buildServiceTopology` 调用 `setState`。
- **用法：** `_openEditor`，在详情打开的每个编辑器——服务编辑器、路由的编辑器、引导式页面——之后调用。
- **备注：** 选择和筛选保持不变；被编辑删除的节点只是不再被选中。新的图实例是一个新的布局请求，因此画布会重新布局。在 1.5.6 的第 5 阶段之前，拓扑一直保留打开时的那个图。

### `Future<void> _exportTopologyImage()` <a id="exporttopologyimage"></a>
- **种类：** `_ServiceTopologyPageState` 的方法。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 781 行）。
- **用途：** 把拓扑画布（经其 `RepaintBoundary`）捕获为 PNG 并交给平台适当分享/保存流程。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 未就绪时显示 snackbar；设 `_exporting`；把边界渲染为图像并经 `ImageShareService.sharePngBytes` 分享；错误时显示失败 snackbar。
- **算法：** 1. `!_layoutReady` 时显示 snackbar 并返回（尚无可捕获）。2. `setState(() => _exporting = true)`。3. `await WidgetsBinding.instance.endOfFrame`（确保带当前布局的帧已实际绘制）。4. 经 `_captureKey.currentContext` 找 `RenderRepaintBoundary`；不可用抛 `StateError`。5. `boundary.toImage(pixelRatio: 3)`，然后 `image.toByteData(format: ui.ImageByteFormat.png)`；编码失败抛 `StateError`。6. 仍挂载时调用 `ImageShareService.sharePngBytes(context, bytes, fileName: 'mydevice_topology.png')`（见 [`image_share_service.md`](../../../shared/services/image_share_service.md#sharepngbytes)）。7. 任何异常时（挂载则）显示失败 snackbar。8. `finally`：清除 `_exporting`（挂载则）。
- **用法：** [`build`](#pagebuild) 中应用栏导出 `IconButton` 的 `onPressed: _exporting || !canExport ? null : _exportTopologyImage`。
- **备注：** 实际分享/保存机制（分享面板 vs 文件选择器 vs 剪贴板）平台特定且住在 `ImageShareService` 内，不在这里——见 [平台说明 — Android](../../../../platform-notes.md#android)。边界连同高亮一起包住画布，因此选中的路由可以单独导出；图例条和详情窗格都在边界之外。没有就绪的布局、或筛选留下空图时，`build` 禁用此操作。

### `Widget build(BuildContext context)` <a id="pagebuild"></a>
- **种类：** `_ServiceTopologyPageState` 的方法（组件构建）。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 832 行）。
- **用途：** 构建拓扑页脚手架。
- **输入：** `context`。
- **返回：** 组件树。
- **副作用：** 除填充 `_visible` 和 `_selectionIn` 的缓存外无。
- **算法：** 1. 解析可见图和选择。2. 应用栏操作：筛选按钮（键 `topology-filter`，筛选生效时带显示 `ServiceTopologyFilter.activeCount` 的 `Badge`）、"按设备分组"切换开关（键 `topology-group-by-device`，`_groupByDevice` 打开时处于选中状态；切换它会重置变换）、旋转（同时重置变换）和导出（只在非空图的布局就绪时启用）。3. 拓扑列：`_buildModeRow`、`_buildLegendStrip`，然后是 `_buildNoMatch`（筛选后的图为空）或 `_ServiceTopologyView`——带 `ServiceTopologyLayoutOptions(groupByDevice: _groupByDevice)`、高亮、选中 id、`_selectNode`、清除选择的背景点击以及变换。4. 在 `useDetailTwoPane` 窗口上，是由该列、一条分隔线和宽 `topologyDetailPaneWidth(width)` 的 [`_buildDetailsPane`](#builddetailspane) 组成的 `Row`；否则只有该列。
- **用法：** 由框架调用。
- **备注：** 即使未选中任何节点，窗格也存在：布局取决于画布宽度，因此随选择出现又消失的窗格会在每次点击时重新布局——并闪出加载转圈。

### `Widget _buildDetailsPane(AppLocalizations l10n, ...? selection)` <a id="builddetailspane"></a>
- **种类：** `_ServiceTopologyPageState` 的方法（组件辅助）。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 1050 行）。
- **用途：** 构建分栏窗口的详情窗格。
- **输入：** `l10n`；`selection` — 来自 [`_selectionIn`](#selectionin)，或 null。
- **返回：** `Widget`。
- **副作用：** 无。
- **算法：** 未选中任何节点 ⇒ 居中的提示（键 `topology-details-empty`）。否则是 [`_TopologyNodeDetails`](#detailsbuild)（键 `topology-details-pane`），带聚焦路由、多于一条路由时的聚焦提示、供路由行使用的 `_toggleRouteFocus`、供其编辑按钮使用的路由编辑器、节点的 [`_nodeActions`](#nodeactions)，以及供关闭按钮使用的 `_clearSelection`；编辑器经 `_openEditor` 打开。
- **用法：** 分栏窗口上的 [`build`](#pagebuild)。
- **备注：** 非模态：旁边的画布保持可交互，因此可以直接选中另一个节点。

### `Widget build(BuildContext context)` (`_TopologyNodeDetails`) <a id="detailsbuild"></a>
- **种类：** `_TopologyNodeDetails` 的方法（组件构建）。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 1172 行）。
- **用途：** 渲染节点详情。
- **输入：** `context`。
- **返回：** 组件树。
- **副作用：** 无。
- **算法：** 一个 `ListView`，依次包含：节点块（图标、标签；角色、详情和车道作为副标题；设置了 `onClose` 时带键为 `topology-details-close` 的关闭按钮）；带本地化类别（`deviceCategoryLabel`）的设备块；带端点的服务块；一组换行排列的按钮：「编辑服务」（节点有服务时）以及每个操作一个描边按钮，按操作设键；然后是「链路」、按需显示的聚焦提示，以及每条相关路由一行（键 `topology-route-<id>`，聚焦时 `selected`）：方法图标、目标、目标摘要、本地化的访问级别和车道；设置了 `onRouteEdit` 时带编辑按钮（`topology-route-edit-<id>`），否则是右箭头。
- **用法：** [`_showDetailsSheet`](#showdetailssheet) 和 [`_buildDetailsPane`](#builddetailspane)。
- **备注：** 每个标签都已本地化（`serviceTopologyRoleLabel`、`serviceAccessLaneLabel`、`serviceAccessLevelLabel`、`deviceCategoryLabel`）；1.5.6 之前，角色、车道和设备类别以英文或原始枚举名显示。

### `Widget build(BuildContext context)` (`_TopologyFilterSheetState`) <a id="filterbuild"></a>
- **种类：** `_TopologyFilterSheetState` 的方法（组件构建）。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 1357 行）。
- **用途：** 渲染筛选面板。
- **输入：** `context`。
- **返回：** 组件树。
- **副作用：** 无；各控件调用 `_update`，由它把每次变更交给页面。
- **算法：** 带「清除筛选」的标题（`topology-filter-clear`，筛选生效时启用；也会清空搜索框）；搜索框（`topology-filter-search`）；车道 chip（`topology-filter-lane-<lane>`，一个彩色圆点加本地化车道名，无勾选标记）；设备 chip——「全部设备」（`topology-filter-all-devices`）和每台设备一个（`topology-filter-device-<id>`）。
- **用法：** `_openFilters`，作为面板的内容。
- **备注：** 最后一个选中的车道不能关闭，因为不选车道就什么也不显示。清除最后一个设备 chip 意味着重新显示全部设备。变更实时生效；关闭面板会保留它们。
