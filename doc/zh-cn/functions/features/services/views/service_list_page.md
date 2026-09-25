# lib/features/services/views/service_list_page.dart

服务标签的顶层页面及其整个拓扑子流程，概念上描述于 [服务与拓扑](../../../../features/services-topology.md)。此单文件拥有两层：(1) 主列表页（`ServiceListPage`/`_ServiceListPageState`）带四个视图（总览/按设备/路由/端口）；(2) 全屏拓扑页及其渲染（`_ServiceTopologyPage`、`_ServiceTopologyView`、`_TopologyNodeCard`、`_ServiceTopologyEdgePainter` 和 `_TopologyLayoutRequest` 布局缓存键）。每个「添加访问方式」入口都经 `_addAccessPath` 压入引导式访问路径页（[`service_access_path_page.md`](service_access_path_page.md)）；本文件在 1.5.6 之前持有的快速访问路由对话框已被移除。图构建、警告/冲突检测和大多数路由格式化辅助从 `service_analysis.dart`（[`service_analysis.md`](../services/service_analysis.md)）读取；节点/边放置和边路由来自 `service_topology_layout.dart`（[`service_topology_layout.md`](../services/service_topology_layout.md)）；警告文本和其他 UI 标签来自 [`service_labels.md`](../services/service_labels.md)。持久化经 `ServiceStorage`/`DeviceStorage`/`NetworkStorage`（[`service_storage.md`](../services/service_storage.md)）；此页压入的增/改表单住在 [`service_edit_page.md`](service_edit_page.md) 和 [`service_route_edit_page.md`](service_route_edit_page.md)。像应用其他列表页一样，`_ServiceListPageState` 注册到 [`AutoSyncService`](../../../shared/services/auto_sync_service.md)，使后台同步自动重载列表。

**行数说明：** `grep -c 'Purpose:' service_list_page.dart` 返回 **58**，每个块都恰好坐在真实声明正上方。本文件尾部另有 **10 个未文档化顶层辅助函数**（第 1834–2008 行：`_compactTopologyLabel` 到 `_iconForService`），完全无 `/// Purpose:` 块。因此共 **58 + 10 = 68** 个真实声明，下面分 **19 个 Tier A / 49 个 Tier B**。1.5.6 移除了快速访问对话框（`_QuickAccessMethod`——其第一个枚举常量携带着唯一一个不文档化任何声明的块——以及 `_QuickAccessRouteDialog` 及其状态）、`_warningText`（现为 `service_labels.dart` 中的 `serviceWarningLabel`），以及只有该对话框使用的两个尾部辅助（`_splitTargets`、`_emptyToNull`）；`_isFrpLikeService` 移到了 [`service_access_patterns.md`](../services/service_access_patterns.md)，并新增了 `_nodeSubtitle`。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ServiceListPage`（构造函数） | 构造函数 | B | 创建页面组件（无参数）。 |
| `createState` | 方法（`ServiceListPage`） | B | 创建页面可变状态对象。 |
| [`initState`](#initstate) | 方法（`_ServiceListPageState`，组件生命周期） | A | 注册自动同步监听器并启动初始服务/路由/设备/网络加载。 |
| `dispose` | 方法（`_ServiceListPageState`，组件生命周期） | B | 注销自动同步监听器。 |
| `_handleLocalDataChanged` | 方法（`_ServiceListPageState`） | B | 响应自动同步通知重载服务/路由/设备/网络。 |
| [`_load`](#load) | 方法（`_ServiceListPageState`） | A | 从存储重载服务、路由、设备和网络。 |
| `_deviceById` | 方法（`_ServiceListPageState`） | B | 在加载设备列表按 id 查找设备。 |
| `_serviceById` | 方法（`_ServiceListPageState`） | B | 在加载服务列表按 id 查找服务。 |
| `_endpointById` | 方法（`_ServiceListPageState`） | B | 在服务上按 id 查找端点，无 id 时其第一端点。 |
| `_addService` | 方法（`_ServiceListPageState`） | B | 压入空白服务编辑页，弹出 `ServiceEditOutcome` 时重载。 |
| `_editService` | 方法（`_ServiceListPageState`） | B | 为既有服务压入服务编辑页，弹出 `ServiceEditOutcome`（保存或删除）时重载。 |
| `_addRoute` | 方法（`_ServiceListPageState`） | B | 压入高级路由编辑器，报告保存后重载。 |
| [`_addAccessPath`](#addaccesspath) | 方法（`_ServiceListPageState`） | A | 为新访问路径压入引导式访问路径页；页面保存后重载。 |
| `_editRoute` | 方法（`_ServiceListPageState`） | B | 为既有路由压入高级路由编辑器，报告保存后重载。 |
| `_viewLabel` | 方法（`_ServiceListPageState`） | B | 把 `_ServiceView` 映射到其本地化分段按钮标签。 |
| `build` | 方法（组件，`_ServiceListPageState`） | B | 构建脚手架：应用栏操作、FAB、视图切换器、当前视图主体。 |
| `_setColumnsPref` | 方法（`_ServiceListPageState`） | B | 存储新的列数偏好（`DeviceStorage.setServiceListColumns`）并重新渲染。 |
| `_buildCurrentView` | 方法（组件辅助） | B | 分发到当前所选 `_ServiceView` 的构建器，把 `listColumnCount`（以 `shellContentWidth − 16` 和 `serviceCardMinWidth`）得到的列数传给三个列表视图。 |
| `_buildOverview` | 方法（组件辅助） | B | 渲染总览视图：指标卡片（列数来自 `serviceMetricColumns`）、拓扑卡片、警告、路由组、服务列表。 |
| `_buildDevices` | 方法（组件辅助） | B | 渲染按设备视图：每设备分组并可展开的服务，卡片按给定列数放入 `adaptiveTileRows`。 |
| `_buildRoutes` | 方法（组件辅助，`_ServiceListPageState`） | B | 渲染路由视图：每路由一张卡片，放入 `adaptiveTileRows`。 |
| `_buildPorts` | 方法（组件辅助） | B | 渲染端口视图：端口冲突横幅加逐设备端口使用卡片，卡片放入 `adaptiveTileRows`。 |
| `_topologyCard` | 方法（组件辅助） | B | 渲染总览拓扑摘要卡片；页头/操作行由 `adaptive_layout.dart` 的 `useTopologyActionsRow` 门控。 |
| `_openTopology` | 方法（`_ServiceListPageState`） | B | 为构建图压入全屏拓扑页。 |
| [`_routesGroupedByService`](#routesgroupedbyservice) | 方法（`_ServiceListPageState`） | A | 按源服务 id 分组路由并按服务名排序组。 |
| `_serviceRouteGroupCard` | 方法（组件辅助） | B | 渲染一个服务的路由组为可展开卡片。 |
| `_metricCard` | 方法（组件辅助） | B | 渲染一个总览指标块（图标、值、标签）。 |
| `_serviceTile` | 方法（组件辅助） | B | 渲染一个服务列表块（图标、设备、端点、路由数、菜单）。 |
| `_routeCard` | 方法（组件辅助） | B | 渲染一个路由摘要卡片。 |
| [`_hopLabel`](#hoplabel) | 方法（`_ServiceListPageState`） | A | 为一个路由跳计算显示标签。 |
| [`_routeSummary`](#routesummary) | 方法（`_ServiceListPageState`） | A | 为路由构建"源 -> 跳 -> 目标"摘要行。 |
| [`_routesForEndpoint`](#routesforendpoint) | 方法（`_ServiceListPageState`） | A | 找使用给定服务端点的路由显示名。 |
| `_emptyState` | 方法（组件辅助） | B | 渲染居中空状态消息。 |
| `_emptyInline` | 方法（组件辅助） | B | 渲染填充内联空状态消息。 |
| `_ServiceTopologyView`（构造函数） | 构造函数 | B | 创建拓扑视图组件（图、数据、回调、模式、旋转、捕获/布局回调）。 |
| `createState` | 方法（`_ServiceTopologyView`） | B | 创建拓扑视图可变状态对象。 |
| `build` | 方法（组件，`_ServiceTopologyViewState`） | B | 在 `LayoutBuilder` 内布局拓扑画布，请求/显示缓存布局。 |
| [`_ensureLayout`](#ensurelayout) | 方法（`_ServiceTopologyViewState`） | A | 为请求安排延迟布局计算，去重在途请求。 |
| [`_calculateLayout`](#calculatelayout) | 方法（`_ServiceTopologyViewState`） | A | 为一个请求运行布局引擎，仍最新时缓存结果。 |
| `_buildLoading` | 方法（组件辅助） | B | 渲染布局就绪前显示的小加载转圈。 |
| `_reportLayoutReady` | 方法（`_ServiceTopologyViewState`） | B | 布局就绪性变化时通知父级（延迟到下一帧）。 |
| `_buildViewer` | 方法（组件辅助） | B | 渲染定位节点卡片和边画家，包为旋转/捕获/平移缩放。 |
| [`_showNodeDetails`](#shownodedetails) | 方法（`_ServiceTopologyViewState`） | A | 解析点击节点设备/服务/相关路由并在底部面板显示。 |
| [`_TopologyLayoutRequest`（构造函数）](#topologylayoutrequest-new) | 构造函数 | A | 创建布局缓存键值（图、路由、视口宽）。 |
| [`==`](#equals) | 运算符（`_TopologyLayoutRequest`） | A | 按图/路由身份和视口宽比较两个请求。 |
| [`hashCode`](#hashcode) | getter（`_TopologyLayoutRequest`） | A | 与其相等契约一致的请求哈希。 |
| `_ServiceTopologyPage`（构造函数） | 构造函数 | B | 创建全屏拓扑页组件。 |
| `createState` | 方法（`_ServiceTopologyPage`） | B | 创建页面可变状态对象。 |
| [`_exportTopologyImage`](#exporttopologyimage) | 方法（`_ServiceTopologyPageState`） | A | 把拓扑画布捕获为 PNG 并交给平台分享流程。 |
| `build` | 方法（组件，`_ServiceTopologyPageState`） | B | 构建拓扑页脚手架：旋转/导出操作、模式切换、拓扑视图。 |
| `_TopologyNodeCard`（构造函数） | 构造函数 | B | 创建节点卡片组件（节点、图标、点击处理器）。 |
| `build` | 方法（组件，`_TopologyNodeCard`） | B | 把节点渲染为紧凑端口 chip 或完整标签/详情卡片。 |
| `_ServiceTopologyEdgePainter`（构造函数） | 构造函数 | B | 创建边画家（图、布局、配色方案）。 |
| [`paint`](#paint) | 方法（`_ServiceTopologyEdgePainter`，`CustomPainter` 覆盖） | A | 把每条边路由折线和箭头绘制到画布。 |
| [`_drawPolyline`](#drawpolyline) | 方法（`_ServiceTopologyEdgePainter`） | A | 绘制一条边路径加其末端三角箭头。 |
| `_edgeColor` | 方法（`_ServiceTopologyEdgePainter`） | B | 把边访问车道映射到配色方案颜色。 |
| `shouldRepaint` | 方法（`_ServiceTopologyEdgePainter`） | B | 只在图、布局或配色方案变化时重绘。 |
| [`_nodeSubtitle`](#nodesubtitle) | 顶层函数 | A | 拓扑节点卡片显示的副标题：中继显示本地化方法或跳类型，否则显示构建器的 detail。 |
| [`_compactTopologyLabel`](#compacttopologylabel) | 顶层函数 | A | 把拓扑节点标签/详情缩短为紧凑 chip 尺寸字符串。 |
| [`_iconForTopologyNode`](#iconfortopologynode) | 顶层函数 | A | 按 kind 及其解析设备/服务解析拓扑节点图标。 |
| `_iconForMethod` | 顶层函数 | B | 把 `ServiceRouteMethod` 映射到其显示图标。 |
| `_primaryMethod` | 顶层函数 | B | 返回路由首跳方法（如有）。 |
| `_laneLabel` | 顶层函数 | B | 把 `ServiceAccessLane` 映射到其显示标签。 |
| `_roleLabel` | 顶层函数 | B | 把 `ServiceTopologyNodeRole` 映射到其显示标签。 |
| `_nodeFill` | 顶层函数 | B | 把拓扑节点角色映射到其卡片填充色。 |
| `_nodeBorder` | 顶层函数 | B | 把拓扑节点角色映射到其卡片边框色。 |
| `iconForServiceIcon` | 顶层函数 | B | 把服务存储图标键映射到其 `IconData`。 |
| `_iconForService` | 顶层函数 | B | 经 `iconForServiceIcon` 解析服务图标。 |

`enum _ServiceView { overview, devices, routes, ports }` 和 `enum _TopologyInteractionMode { select, move }`（第 27/29 行）是简单、无成员枚举，无自己构造函数/方法，因此也不列出——它们只作为上面方法的参数/返回类型出现（`_viewLabel`、`_buildCurrentView`、`build` 中 `SegmentedButton`）。

`iconForServiceIcon`（第 1961 行）是本文件唯一**公共**（非下划线）顶层声明；它也被 `service_edit_page.dart`（见 [`service_edit_page.md`](service_edit_page.md)）调用渲染服务名/图标字段旁和模板选择器逐模板图标的图标预览。

## 文档

### `void initState()` <a id="initstate"></a>
- **种类：** `_ServiceListPageState` 的方法（组件生命周期覆盖）。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 63 行）。
- **用途：** 把本页接入自动同步通知系统并启动初始服务/路由/设备/网络加载。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 把 `_handleLocalDataChanged` 注册到 `AutoSyncService.instance.addOnLocalDataChanged`；启动异步加载。
- **算法：** 1. 调用 `super.initState()`。2. 把 `_handleLocalDataChanged` 注册为 `AutoSyncService` 本地数据变更监听器。3. 调用 `_load()`（不 await）。
- **用法：** `_ServiceListPageState` 首次插入树时由 Flutter 框架自动调用；无直接调用点。
- **备注：** 对应 `dispose()` 调用 `AutoSyncService.instance.removeOnLocalDataChanged(_handleLocalDataChanged)` 避免泄漏监听器（见 [`auto_sync_service.md#addonlocaldatachanged`](../../../shared/services/auto_sync_service.md)）。

### `Future<void> _load()` <a id="load"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 94 行）。
- **用途：** 从各自存储重载服务、路由、设备和网络并刷新页面状态。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 经 `ServiceStorage.load()`、`DeviceStorage.load()`、`NetworkStorage.load()` 读取；`setState` 更新 `_services`/`_routes`/`_devices`/`_networks` 并清除 `_loading`。
- **算法：** Await `ServiceStorage.load()`（服务 + 路由），然后 `DeviceStorage.load()`，然后 `NetworkStorage.load()`，顺序（非并行）；未挂载提前返回；一次 `setState` 分配全部四个列表并设 `_loading = false`。
- **用法：** 从 [`initState`](#initstate)、`_handleLocalDataChanged`（自动同步）和每个增/改/访问路径流程后调用：`_addService`/`_editService` 对 `ServiceEditOutcome` 的 `if (result != null) _load();`，`_addRoute`/`_editRoute` 的 `if (result == true) _load();`，以及页面保存后 [`_addAccessPath`](#addaccesspath) 的 `await _load();`。
- **备注：** 三个存储顺序加载而非 `Future.wait`，因此总加载时间跨它们相加——鉴于这些是小本地 JSON 文件可接受。

### `Future<void> _addAccessPath({ServiceAccessDraft? draft})` <a id="addaccesspath"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 196 行）。
- **用途：** 为新访问路径打开引导式访问路径页。
- **输入：** `draft` — 可选的起始草稿，如用 `ServiceAccessDraft(sourceServiceId: ...)` 预选源服务。
- **返回：** `Future<void>`。
- **副作用：** 在根导航器上压入 [`ServiceAccessPathPage`](service_access_path_page.md)；它弹出 `true`（页面自己已保存路由）时重载。
- **算法：** 带 `draft` 以 `push<bool>` 压入页面；结果为 `true` 时 `await _load()`。
- **用法：**
  ```dart
  IconButton(
    icon: const Icon(Icons.add_link),
    tooltip: l10n.serviceAddAccess,
    onPressed: _services.isEmpty ? null : () => _addAccessPath(),
  ),
  ```
  也（不带草稿）从 `_buildOverview` 的添加访问按钮和 `_topologyCard` 的操作行调用，（以该服务为源）从 `_serviceRouteGroupCard` 和 `_serviceTile` 的弹出菜单调用，并作为 `onAddAccess` 回调传给 `_ServiceTopologyPage`/`_ServiceTopologyView`/[`_showNodeDetails`](#shownodedetails)，其类型为 `Future<void> Function({ServiceAccessDraft? draft})`。
- **备注：** 1.5.6 中取代了 `_addAccessRoute` 及其打开的 `_QuickAccessRouteDialog`。页面自己持久化路由，因此此方法只负责重载。

### `List<MapEntry<String, List<ServiceRoute>>> _routesGroupedByService()` <a id="routesgroupedbyservice"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 748 行）。
- **用途：** 按源服务 id 分组所有路由，供总览逐服务路由卡片。
- **输入：** 无。
- **返回：** `List<MapEntry<String, List<ServiceRoute>>>`，按解析服务名（不区分大小写）排序；无法解析 id 按其自己原始文本排序。
- **副作用：** 无。
- **算法：** 1. 把 `_routes` 分桶进按 `route.sourceServiceId` 键控的映射（`putIfAbsent(...).add(route)`）。2. 转换为条目列表。3. 按 `_serviceById(key)?.name ?? key` 小写排序。
- **用法：** `_buildOverview` 中 `for (final entry in _routesGroupedByService()) _serviceRouteGroupCard(l10n, entry.key, entry.value)`。
- **备注：** 源服务此后被删的路由仍按其原始（无法解析）服务 id 分组，而非从总览丢弃。

### `String _hopLabel(ServiceRouteHop hop)` <a id="hoplabel"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 927 行）。
- **用途：** 为一个路由跳计算短显示标签，供路由摘要行。
- **输入：** `hop`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** 1. 跳 `serviceId` 解析到已知服务时返回该服务名。2. 否则 `hop.label` 非空返回它。3. 否则 `hop.host` 非空返回从存在的 `scheme`/`port`/`path` 中构建的 `scheme://host:port/path` 形态字符串。4. 否则回退本地化跳类型（`serviceHopTypeLabel`）。
- **用法：** [`_routeSummary`](#routesummary) 内 `route.hops.map(_hopLabel)`。
- **备注：** 这是 `service_analysis.dart` 拓扑图构建器 `_relayLabel` 的 UI 文本摘要对应物——两者都为跳实现类似服务名/标签/主机/类型回退链，但独立（这个供路由列表文本，那个供图节点标签）；见 [`service_analysis.md#relaylabel`](../services/service_analysis.md#relaylabel)。

### `String _routeSummary(ServiceRoute route, {ServiceNode? source, ServiceEndpoint? sourceEndpoint})` <a id="routesummary"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 944 行）。
- **用途：** 构建每条路由卡片下显示的两行文本摘要：源到目标路径，然后访问级别。
- **输入：** `route`；`source`/`sourceEndpoint` — 已解析源服务/端点（使此方法不必重新解析）。
- **返回：** `String` — 箭头连接路径和本地化访问级别（`serviceAccessLevelLabel`）用 `'\n'` 连接。
- **副作用：** 无。
- **算法：** 1. 构建 `parts` 列表：源服务名（端点有端口时追加其端口文本），然后每个跳 [`_hopLabel`](#hoplabel)，然后每个访问目标（`serviceRouteAccessTargets(route)`）经 `compactAccessTargetLabel` 运行。2. 用 `' -> '` 连接非空 `parts`，`parts` 最终为空时回退 `route.name`。3. 追加本地化访问级别为第二行。
- **用法：** `_routeCard` 副标题中 `_routeSummary(route, source: source, sourceEndpoint: sourceEndpoint)`。
- **备注：** 实践中 `parts` 不可能为空（路由总是至少一跳），因此 `route.name` 回退是防御而非正常到达路径。

### `String? _routesForEndpoint(String serviceId, String endpointId)` <a id="routesforendpoint"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 969 行）。
- **用途：** 找使用给定服务端点（作为源或经跳）的每条路由显示名，供端口视图副标题。
- **输入：** `serviceId`、`endpointId`。
- **返回：** `String?` — 逗号连接路由显示目标列表，无路由引用此端点时 `null`。
- **副作用：** 无。
- **算法：** 过滤 `_routes` 到 (`sourceServiceId` 和 `sourceEndpointId` 都匹配) 或任何跳 (`serviceId` 和 `endpointId`) 都匹配的；把幸存者经 `serviceRouteDisplayTarget` 映射；用 `', '` 连接；无匹配返回 `null`。
- **用法：** `_buildPorts` 逐端口副标题内 `_routesForEndpoint(use.service.id, use.endpoint.id)`（与其他 `whereType<String>()` 过滤部分连接）。
- **备注：** 按*组合*服务 id 和端点 id 匹配——引用相同服务但不同端点的路由不匹配。

### `void _ensureLayout(_TopologyLayoutRequest request)` <a id="ensurelayout"></a>
- **种类：** `_ServiceTopologyViewState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1111 行）。
- **用途：** 为请求安排延迟布局计算，除非相同请求已在途。
- **输入：** `request`。
- **返回：** 无。
- **副作用：** 设 `_pendingRequest`；递增 `_layoutGeneration`；安排调用 [`_calculateLayout`](#calculatelayout) 的帧后回调。
- **算法：** 1. `_pendingRequest == request`（相同图/路由身份和视口宽——见 [`_TopologyLayoutRequest.==`](#equals)）时不做事返回（已在途）。2. 否则把 `request` 记录为 `_pendingRequest`、递增 `_layoutGeneration` 并把新值捕获为 `generation`。3. 注册 `WidgetsBinding.instance.addPostFrameCallback` 调用 `_calculateLayout(request, generation)`。
- **用法：** `build` 中每当 `_completedRequest != request || _layout == null`（即当前图/路由/视口组合尚未布局）时调用。
- **备注：** 这是 [服务与拓扑 — 拓扑图布局（高层）](../../../../features/services-topology.md#topology-graph-layout-high-level) 描述行为背后的机制——"全屏拓扑把昂贵布局推迟到首帧后，并按图、路由、宽度和旋转派生视口缓存布局，使模式变化……不重跑路由。"`_layoutGeneration` 计数器正是让新请求使仍在途旧请求失效的东西（见 [`_calculateLayout`](#calculatelayout)）。

### `Future<void> _calculateLayout(_TopologyLayoutRequest request, int generation)` <a id="calculatelayout"></a>
- **种类：** `_ServiceTopologyViewState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1125 行）。
- **用途：** 让出一帧后为一个请求运行拓扑布局引擎，仍是最新请求时缓存结果。
- **输入：** `request`；`generation` — 此计算被安排时捕获的 `_layoutGeneration` 值。
- **返回：** `Future<void>`。
- **副作用：** 调用 `ServiceTopologyLayout.build`；仍最新时 `setState` 更新 `_layout`/`_completedRequest`/`_pendingRequest`。
- **算法：** 1. `await Future<void>.delayed(Duration.zero)` — 让出至少一帧，使这不阻塞安排它的帧。2. 未挂载、`generation` 不再等于 `_layoutGeneration`、或 `_pendingRequest` 不再等于 `request`（新请求取代此请求）时退出。3. 计算 `ServiceTopologyLayout.build(request.graph, request.routes, request.viewportWidth.toDouble())`（见 [`service_topology_layout.md#build`](../services/service_topology_layout.md#build)）。4. 重新检查相同三个过期条件（计算本身可能耗时到新请求到达）。5. `setState` 存储布局、把 `request` 标记为 `_completedRequest` 并清除 `_pendingRequest`。
- **用法：** 只经 [`_ensureLayout`](#ensurelayout) 注册的帧后回调调用。
- **备注：** 双重过期检查（`ServiceTopologyLayout.build` *前*和*后*）正是防止慢速、现已过时布局计算（如旋转前视口宽的）在新请求已完成后破坏状态的东西。

### `void _showNodeDetails(BuildContext context, ServiceTopologyNode node)` <a id="shownodedetails"></a>
- **种类：** `_ServiceTopologyViewState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1248 行）。
- **用途：** 解析点击拓扑节点的设备/服务/相关路由并在带编辑/添加访问操作的底部面板显示。
- **输入：** `context`、`node`。
- **返回：** `void`。
- **副作用：** 显示 `showModalBottomSheet`；其操作按钮调用 `widget.onEditService`/`widget.onEditRoute`/`widget.onAddAccess` 并弹出面板。
- **算法：** 1. 对照 `widget.devices`/`widget.services` 从 `node.deviceId`/`node.serviceId` 解析 `device`/`service`（未设或无法解析 `null`）。2. 用 `relatedRoutesForNode(node, widget.routes, services: widget.services)`（[`service_analysis.md`](../services/service_analysis.md#relatedroutesfornode)）解析 `relatedRoutes`。3. 显示列出节点自己标签/角色/详情/车道的底部面板；解析时设备块；解析时服务块（带端点）加编辑/添加访问按钮；有相关路由时每相关路由一个块（点击编辑）。
- **用法：** `_buildViewer` 中 `onTap: widget.mode == _TopologyInteractionMode.select ? () => _showNodeDetails(context, node) : null`——只在选择模式接，不在移动/缩放模式。
- **备注：** `relatedRoutes` 按 `node.routeIds`（图构建时触碰此节点的路由）匹配；服务节点还按其服务出现在路由上任何位置匹配，设备节点还按其承载的服务匹配。1.5.6 之前此规则内联在这里，并对没有服务的节点匹配每个自由形式跳；相关路由的访问级别现已本地化。

### `const _TopologyLayoutRequest({required this.graph, required this.routes, required this.viewportWidth})` <a id="topologylayoutrequest-new"></a>
- **种类：** 构造函数。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1383 行）。
- **用途：** 创建用作拓扑布局缓存键的值。
- **输入：** `graph`、`routes`、`viewportWidth`。
- **返回：** 新 `_TopologyLayoutRequest`。
- **副作用：** 无。
- **算法：** 普通字段赋值。
- **用法：** `_ServiceTopologyViewState.build` 每次 `build` 调用构造一次。
- **备注：** 无。

### `bool operator ==(Object other)` <a id="equals"></a>
- **种类：** `_TopologyLayoutRequest` 的运算符。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1395 行）。
- **用途：** 为缓存复用目的比较两个布局请求。
- **输入：** `other`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** `identical(this, other)` 为 true、或 `other` 是带 `identical` `graph`、`identical` `routes` 和相等 `viewportWidth` 的 `_TopologyLayoutRequest` 时为 `true`。
- **用法：** 经 `build`（`_completedRequest == request`）和 [`_ensureLayout`](#ensurelayout)（`_pendingRequest == request`）中的 `==`/`!=` 隐式使用。
- **备注：** 对 `graph`/`routes` 用**身份**（`identical`）而非值相等——两个结构相等但不同的 `ServiceTopologyGraph`/路由列表实例会比较不等。这是刻意的：任何新 `buildServiceTopology`/[`_load`](#load) 调用即使结果图看起来相同也使缓存失效，并避免每次构建深结构比较。`viewportWidth` 比较前舍入为 `int`（在 `_ServiceTopologyViewState.build`），避免微小约束抖动强制重布局。

### `int get hashCode` <a id="hashcode"></a>
- **种类：** `_TopologyLayoutRequest` 的 getter。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1408 行）。
- **用途：** 产生与上面基于身份的 `==` 一致的哈希码。
- **输入：** 无。
- **返回：** `int`。
- **副作用：** 无。
- **算法：** `Object.hash(identityHashCode(graph), identityHashCode(routes), viewportWidth)`。
- **用法：** 本文件无任何地方显式调用——`_TopologyLayoutRequest` 值只经 `==` 比较，从不存 `Map`/`Set`——但 Dart 要求每当覆盖 `==` 时 `hashCode` 与之一致。
- **备注：** 用 `identityHashCode`（匹配 `==` 对 `graph`/`routes` 的身份基础比较），因此从不同底层 `graph`/`routes` 对象构建的两个结构相等实例也哈希不同。

### `Future<void> _exportTopologyImage()` <a id="exporttopologyimage"></a>
- **种类：** `_ServiceTopologyPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1460 行）。
- **用途：** 把拓扑画布（经其 `RepaintBoundary`）捕获为 PNG 并交给平台适当分享/保存流程。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 未就绪时显示 snackbar；设 `_exporting`；把边界渲染为图像并经 `ImageShareService.sharePngBytes` 分享；错误时显示失败 snackbar。
- **算法：** 1. `!_layoutReady` 时显示 snackbar 并返回（尚无可捕获）。2. `setState(() => _exporting = true)`。3. `await WidgetsBinding.instance.endOfFrame`（确保带当前布局的帧已实际绘制）。4. 经 `_captureKey.currentContext` 找 `RenderRepaintBoundary`；不可用抛 `StateError`。5. `boundary.toImage(pixelRatio: 3)`，然后 `image.toByteData(format: ui.ImageByteFormat.png)`；编码失败抛 `StateError`。6. 仍挂载时调用 `ImageShareService.sharePngBytes(context, bytes, fileName: 'mydevice_topology.png')`（见 [`image_share_service.md`](../../../shared/services/image_share_service.md#sharepngbytes)）。7. 任何异常时（挂载则）显示失败 snackbar。8. `finally`：清除 `_exporting`（挂载则）。
- **用法：** `build` 中应用栏导出 `IconButton` 的 `onPressed: _exporting || !_layoutReady ? null : _exportTopologyImage`。
- **备注：** 实际分享/保存机制（分享面板 vs 文件选择器 vs 剪贴板）平台特定且住在 `ImageShareService` 内，不在这里——见 [平台说明 — Android](../../../../platform-notes.md#android)。

### `void paint(Canvas canvas, Size size)` <a id="paint"></a>
- **种类：** `_ServiceTopologyEdgePainter` 的方法（`CustomPainter` 覆盖）。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1740 行）。
- **用途：** 把每条图边路由折线和箭头绘制到画布。
- **输入：** `canvas`；`size`（不直接使用——布局已带绝对坐标）。
- **返回：** 无。
- **副作用：** 绘制到 `canvas`。
- **算法：** 对 `graph.edges` 每条边：在 `layout.edgePaths` 查找其路由点；缺失或少于 2 点跳过；构建 `_edgeColor(edge)` 着色（62% alpha、2.2 描边宽、圆帽/圆角）的 `Paint`；委托 [`_drawPolyline`](#drawpolyline) 实际绘制。
- **用法：** 此画家支撑的 `CustomPaint` 需要重绘时由 Flutter 框架调用（`shouldRepaint` 门控）。
- **备注：** 路由点（带避障的正交路径）来自 [`ServiceTopologyLayout.build`](../services/service_topology_layout.md#build)——此画家只绘制给它的路径；自己不做路由。

### `void _drawPolyline(Canvas canvas, Paint paint, List<Offset> points)` <a id="drawpolyline"></a>
- **种类：** `_ServiceTopologyEdgePainter` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1759 行）。
- **用途：** 绘制一条边多段路径加其末端三角箭头。
- **输入：** `canvas`、`paint`、`points` — 路由折线（2 个或更多点）。
- **返回：** `void`。
- **副作用：** 绘制到 `canvas`。
- **算法：** 1. 构建移到 `points.first` 然后 `lineTo` 穿过每个后续点的 `Path`；绘制它。2. 从末端向后扫描找距端点超 0.5px 的最后点作方向参考（防退化的近零长末段）。3. 经 `atan2` 计算接近角。4. 从端点以 `angle ± 0.45` 弧度画回两条短线（`V` 形箭头，约 9px 长）。
- **用法：** [`paint`](#paint) 每条边调用一次。
- **备注：** 向后扫描非退化参考点意味着箭头方向反映边实际接近方向，即使路由器发出近重复最后点。

### `String? _nodeSubtitle(BuildContext context, ServiceTopologyNode node)` <a id="nodesubtitle"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1820 行）。
- **用途：** 返回拓扑节点卡片在其标签下显示的副标题。
- **输入：** `context`、`node`。
- **返回：** `String?` — 无可显示内容时为 null。
- **副作用：** 无。
- **算法：** 对中继节点，节点带方法时返回本地化方法（`serviceRouteMethodUiLabel`），否则在 `detail` 是原始跳类型名时返回本地化跳类型。其他每个节点返回修剪后的 `detail`，为空时返回 null。
- **用法：** `_TopologyNodeCard.build` 的完整卡片副标题，与车道标签连接。
- **备注：** 图构建器在中继的 `detail` 中存储原始枚举名；在渲染时再本地化，使 [`service_analysis.dart`](../services/service_analysis.md) 保持与语言无关。

### `String _compactTopologyLabel(ServiceTopologyNode node)` <a id="compacttopologylabel"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1834 行）。
- **用途：** 把拓扑节点标签/详情缩短为适合紧凑端口 chip 的短字符串。
- **输入：** `node`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** 对 `remoteEntry` 节点：经正则从标签提取尾部 `:port`（或 `:start-end`）后缀，找到只返回端口文本；否则 5 字符或更少原样返回标签，更长取其前 5 字符。对任何其他节点 kind：搜索连接 `label` + `detail` 文本中*最后*端口类数字序列，找到返回它；否则回退相同短标签或截断规则。
- **用法：** `_TopologyNodeCard.build` 紧凑（端口 chip）分支中 `_compactTopologyLabel(node)`。
- **备注：** 偏好*最后*数字匹配（非第一）正是让 `"tcp bind-host:8080"` 之类 detail 字符串显示 `8080` 而非绑定地址中较早、无关数字的东西；这只是显示性缩短——节点完整标签/详情经其 `Tooltip` 仍可用。

### `IconData _iconForTopologyNode(ServiceTopologyNode node, List<ServiceNode> services, List<Device> devices)` <a id="iconfortopologynode"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1850 行）。
- **用途：** 基于 kind 和（可解析时）其底层设备/服务解析拓扑节点要显示的图标。
- **输入：** `node`、`services`、`devices`。
- **返回：** `IconData`。
- **副作用：** 无。
- **算法：** `device` kind → 解析设备类别图标（`deviceCategoryIcon`），无法解析时泛型设备图标。`service` kind → 解析服务图标（`_iconForService`），无法解析时泛型 `dns` 图标。`endpoint` kind → 固定 ethernet-settings 图标。`remoteEntry` → 公共图标。`domain` → 语言图标。其他任何 → `_iconForMethod(node.method)`。
- **用法：** `_ServiceTopologyViewState._buildViewer` 和 [`_showNodeDetails`](#shownodedetails) 中 `_iconForTopologyNode(node, widget.services, widget.devices)`。
- **备注：** 无。
