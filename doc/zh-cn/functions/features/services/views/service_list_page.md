# lib/features/services/views/service_list_page.dart

服务标签的顶层页面，概念上描述于 [服务与拓扑](../../../../features/services-topology.md)：`ServiceListPage` 和 `_ServiceListPageState` 带四个视图（总览/按设备/路由/端口）。总览的拓扑卡片打开全屏拓扑；自 1.5.6 起，全屏拓扑住在 [`service_topology_page.md`](service_topology_page.md)，其节点卡片、边画家和图标辅助住在 [`service_topology_widgets.md`](service_topology_widgets.md)。每个「添加访问方式」入口都经 `_addAccessPath` 压入引导式访问路径页（[`service_access_path_page.md`](service_access_path_page.md)），每条已保存的路由都经 `_editRoute` 打开——适合时（`serviceRouteOpensGuided`）在引导式页面中，否则在高级编辑器中；本文件在 1.5.6 之前持有的快速访问路由对话框已被移除。图构建、警告/冲突检测和大多数路由格式化辅助从 `service_analysis.dart`（[`service_analysis.md`](../services/service_analysis.md)）读取；节点/边放置和边路由来自 `service_topology_layout.dart`（[`service_topology_layout.md`](../services/service_topology_layout.md)）；警告文本和其他 UI 标签来自 [`service_labels.md`](../services/service_labels.md)。持久化经 `ServiceStorage`/`DeviceStorage`/`NetworkStorage`（[`service_storage.md`](../services/service_storage.md)）；此页压入的增/改表单住在 [`service_edit_page.md`](service_edit_page.md) 和 [`service_route_edit_page.md`](service_route_edit_page.md)。像应用其他列表页一样，`_ServiceListPageState` 注册到 [`AutoSyncService`](../../../shared/services/auto_sync_service.md)，使后台同步自动重载列表。

**行数说明：** `grep -c 'Purpose:' service_list_page.dart` 返回 **34**，每个块都恰好坐在真实声明正上方，每个声明也都有块：下面共 **34** 行，分 **7 个 Tier A / 27 个 Tier B**。1.5.6 移除了快速访问对话框（`_QuickAccessMethod`——其第一个枚举常量携带着唯一一个不文档化任何声明的块——以及 `_QuickAccessRouteDialog` 及其状态）、`_warningText`（现为 `service_labels.dart` 中的 `serviceWarningLabel`），以及只有该对话框使用的两个尾部辅助（`_splitTargets`、`_emptyToNull`）；`_isFrpLikeService` 移到了 [`service_access_patterns.md`](../services/service_access_patterns.md)。随后它把整个拓扑子流程移出——16 个声明移到 [`service_topology_page.md`](service_topology_page.md)，18 个移到 [`service_topology_widgets.md`](service_topology_widgets.md)，其中包括此前在这里没有 `/// Purpose:` 块的十个尾部辅助。

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
| `_editService` | 方法（`_ServiceListPageState`） | B | 为既有服务压入服务编辑页，弹出 `ServiceEditOutcome`（保存或删除）时等待重载完成。 |
| `_addRoute` | 方法（`_ServiceListPageState`） | B | 压入高级路由编辑器，报告保存后重载。 |
| [`_addAccessPath`](#addaccesspath) | 方法（`_ServiceListPageState`） | A | 为新访问路径压入引导式访问路径页；页面保存后重载。 |
| `_editRoute` | 方法（`_ServiceListPageState`） | B | `serviceRouteOpensGuided` 认为适合时在引导式页面中打开已保存的路由，否则在高级编辑器中打开；保存或删除后等待重载完成。所有打开已保存路由的地方都经过它。 |
| `_viewLabel` | 方法（`_ServiceListPageState`） | B | 把 `_ServiceView` 映射到其本地化分段按钮标签。 |
| `build` | 方法（组件，`_ServiceListPageState`） | B | 构建脚手架：应用栏操作、FAB、视图切换器、当前视图主体。 |
| `_setColumnsPref` | 方法（`_ServiceListPageState`） | B | 存储新的列数偏好（`DeviceStorage.setServiceListColumns`）并重新渲染。 |
| `_buildCurrentView` | 方法（组件辅助） | B | 分发到当前所选 `_ServiceView` 的构建器，把 `listColumnCount`（以 `shellContentWidth − 16` 和 `serviceCardMinWidth`）得到的列数传给三个列表视图。 |
| `_buildOverview` | 方法（组件辅助） | B | 渲染总览视图：指标卡片（列数来自 `serviceMetricColumns`）、拓扑卡片、警告、路由组、服务列表。 |
| `_buildDevices` | 方法（组件辅助） | B | 渲染按设备视图：每设备分组并可展开的服务，卡片按给定列数放入 `adaptiveTileRows`。 |
| `_buildRoutes` | 方法（组件辅助，`_ServiceListPageState`） | B | 渲染路由视图：每路由一张卡片，放入 `adaptiveTileRows`。 |
| `_buildPorts` | 方法（组件辅助） | B | 渲染端口视图：端口冲突横幅加逐设备端口使用卡片，卡片放入 `adaptiveTileRows`。 |
| `_topologyCard` | 方法（组件辅助） | B | 渲染总览拓扑摘要卡片；页头/操作行由 `adaptive_layout.dart` 的 `useTopologyActionsRow` 门控。 |
| `_openTopology` | 方法（`_ServiceListPageState`） | B | 为构建图压入 `ServiceTopologyPage`，附带本页的编辑器和一个重载并返回清单的 `reload`。 |
| [`_routesGroupedByService`](#routesgroupedbyservice) | 方法（`_ServiceListPageState`） | A | 按源服务 id 分组路由并按服务名排序组。 |
| `_serviceRouteGroupCard` | 方法（组件辅助） | B | 渲染一个服务的路由组为可展开卡片。 |
| `_metricCard` | 方法（组件辅助） | B | 渲染一个总览指标块（图标、值、标签）。 |
| `_serviceTile` | 方法（组件辅助） | B | 渲染一个服务列表块（图标、设备、端点、路由数、菜单）。 |
| `_routeCard` | 方法（组件辅助） | B | 渲染一个路由摘要卡片，以其主方法的图标（`iconForRouteMethod`）开头。 |
| [`_hopLabel`](#hoplabel) | 方法（`_ServiceListPageState`） | A | 为一个路由跳计算显示标签。 |
| [`_routeSummary`](#routesummary) | 方法（`_ServiceListPageState`） | A | 为路由构建"源 -> 跳 -> 目标"摘要行。 |
| [`_routesForEndpoint`](#routesforendpoint) | 方法（`_ServiceListPageState`） | A | 找使用给定服务端点的路由显示名。 |
| `_emptyState` | 方法（组件辅助） | B | 渲染居中空状态消息。 |
| `_emptyInline` | 方法（组件辅助） | B | 渲染填充内联空状态消息。 |

`enum _ServiceView { overview, devices, routes, ports }`（第 24 行）是简单、无成员枚举，无自己构造函数/方法，因此也不列出——它只作为 `_viewLabel` 和 `_buildCurrentView` 的参数/返回类型，以及在 `build` 中的 `SegmentedButton` 里出现。

本页显示的服务和路由图标来自 [`service_topology_widgets.md`](service_topology_widgets.md)（`iconForService`），服务编辑器和引导式访问路径页也共用它。

## 文档

### `void initState()` <a id="initstate"></a>
- **种类：** `_ServiceListPageState` 的方法（组件生命周期覆盖）。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 58 行）。
- **用途：** 把本页接入自动同步通知系统并启动初始服务/路由/设备/网络加载。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 把 `_handleLocalDataChanged` 注册到 `AutoSyncService.instance.addOnLocalDataChanged`；启动异步加载。
- **算法：** 1. 调用 `super.initState()`。2. 把 `_handleLocalDataChanged` 注册为 `AutoSyncService` 本地数据变更监听器。3. 调用 `_load()`（不 await）。
- **用法：** `_ServiceListPageState` 首次插入树时由 Flutter 框架自动调用；无直接调用点。
- **备注：** 对应 `dispose()` 调用 `AutoSyncService.instance.removeOnLocalDataChanged(_handleLocalDataChanged)` 避免泄漏监听器（见 [`auto_sync_service.md#addonlocaldatachanged`](../../../shared/services/auto_sync_service.md)）。

### `Future<void> _load()` <a id="load"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 89 行）。
- **用途：** 从各自存储重载服务、路由、设备和网络并刷新页面状态。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 经 `ServiceStorage.load()`、`DeviceStorage.load()`、`NetworkStorage.load()` 读取；`setState` 更新 `_services`/`_routes`/`_devices`/`_networks` 并清除 `_loading`。
- **算法：** Await `ServiceStorage.load()`（服务 + 路由），然后 `DeviceStorage.load()`，然后 `NetworkStorage.load()`，顺序（非并行）；未挂载提前返回；一次 `setState` 分配全部四个列表并设 `_loading = false`。
- **用法：** 从 [`initState`](#initstate)、`_handleLocalDataChanged`（自动同步）和每个增/改/访问路径流程后调用：`_addService` 对 `ServiceEditOutcome` 的 `if (result != null) _load();`（`_editService` 中为 await），`_addRoute` 的 `if (result == true) _load();`，以及编辑器保存后 `_editRoute` 和 [`_addAccessPath`](#addaccesspath) 的 `await _load();`；还有拓扑的 `reload`（`_openTopology`），它返回重载后的列表。
- **备注：** 三个存储顺序加载而非 `Future.wait`，因此总加载时间跨它们相加——鉴于这些是小本地 JSON 文件可接受。

### `Future<void> _addAccessPath({ServiceAccessDraft? draft})` <a id="addaccesspath"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 191 行）。
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
  也（不带草稿）从 `_buildOverview` 的添加访问按钮和 `_topologyCard` 的操作行调用，（以该服务为源）从 `_serviceRouteGroupCard` 和 `_serviceTile` 的弹出菜单调用，并作为 `onAddAccess` 回调传给 `ServiceTopologyPage`，由其节点详情（[`_showDetailsSheet`](service_topology_page.md#showdetailssheet)、[`_buildDetailsPane`](service_topology_page.md#builddetailspane)）调用；其类型为 `Future<void> Function({ServiceAccessDraft? draft})`。
- **备注：** 1.5.6 中取代了 `_addAccessRoute` 及其打开的 `_QuickAccessRouteDialog`。页面自己持久化路由，因此此方法只负责重载。

### `List<MapEntry<String, List<ServiceRoute>>> _routesGroupedByService()` <a id="routesgroupedbyservice"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 759 行）。
- **用途：** 按源服务 id 分组所有路由，供总览逐服务路由卡片。
- **输入：** 无。
- **返回：** `List<MapEntry<String, List<ServiceRoute>>>`，按解析服务名（不区分大小写）排序；无法解析 id 按其自己原始文本排序。
- **副作用：** 无。
- **算法：** 1. 把 `_routes` 分桶进按 `route.sourceServiceId` 键控的映射（`putIfAbsent(...).add(route)`）。2. 转换为条目列表。3. 按 `_serviceById(key)?.name ?? key` 小写排序。
- **用法：** `_buildOverview` 中 `for (final entry in _routesGroupedByService()) _serviceRouteGroupCard(l10n, entry.key, entry.value)`。
- **备注：** 源服务此后被删的路由仍按其原始（无法解析）服务 id 分组，而非从总览丢弃。

### `String _hopLabel(ServiceRouteHop hop)` <a id="hoplabel"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 943 行）。
- **用途：** 为一个路由跳计算短显示标签，供路由摘要行。
- **输入：** `hop`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** 1. 跳 `serviceId` 解析到已知服务时返回该服务名。2. 否则 `hop.label` 非空返回它。3. 否则 `hop.host` 非空返回从存在的 `scheme`/`port`/`path` 中构建的 `scheme://host:port/path` 形态字符串。4. 否则回退本地化跳类型（`serviceHopTypeLabel`）。
- **用法：** [`_routeSummary`](#routesummary) 内 `route.hops.map(_hopLabel)`。
- **备注：** 这是 `service_analysis.dart` 拓扑图构建器 `_relayLabel` 的 UI 文本摘要对应物——两者都为跳实现类似服务名/标签/主机/类型回退链，但独立（这个供路由列表文本，那个供图节点标签）；见 [`service_analysis.md#relaylabel`](../services/service_analysis.md#relaylabel)。

### `String _routeSummary(ServiceRoute route, {ServiceNode? source, ServiceEndpoint? sourceEndpoint})` <a id="routesummary"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 962 行）。
- **用途：** 构建每条路由卡片下显示的两行文本摘要：源到目标路径，然后访问级别和车道。
- **输入：** `route`；`source`/`sourceEndpoint` — 已解析源服务/端点（使此方法不必重新解析）。
- **返回：** `String` — 箭头连接的路径，然后是本地化访问级别（`serviceAccessLevelLabel`）和访问车道（`serviceAccessLaneForRoute` 的 `serviceAccessLaneLabel`）用 `' · '` 连接，两行之间用 `'\n'` 连接。
- **副作用：** 无。
- **算法：** 1. 构建 `parts` 列表：源服务名（端点有端口时追加其端口文本），然后每个跳 [`_hopLabel`](#hoplabel)，然后每个访问目标（`serviceRouteAccessTargets(route)`）经 `compactAccessTargetLabel` 运行。2. 用 `' -> '` 连接非空 `parts`，`parts` 最终为空时回退 `route.name`。3. 追加本地化访问级别和车道为第二行，使车道覆盖在卡片上与在拓扑上一样显示。
- **用法：** `_routeCard` 副标题中 `_routeSummary(route, source: source, sourceEndpoint: sourceEndpoint)`。
- **备注：** 实践中 `parts` 不可能为空（路由总是至少一跳），因此 `route.name` 回退是防御而非正常到达路径。

### `String? _routesForEndpoint(String serviceId, String endpointId)` <a id="routesforendpoint"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 991 行）。
- **用途：** 找使用给定服务端点（作为源或经跳）的每条路由显示名，供端口视图副标题。
- **输入：** `serviceId`、`endpointId`。
- **返回：** `String?` — 逗号连接路由显示目标列表，无路由引用此端点时 `null`。
- **副作用：** 无。
- **算法：** 过滤 `_routes` 到 (`sourceServiceId` 和 `sourceEndpointId` 都匹配) 或任何跳 (`serviceId` 和 `endpointId`) 都匹配的；把幸存者经 `serviceRouteDisplayTarget` 映射；用 `', '` 连接；无匹配返回 `null`。
- **用法：** `_buildPorts` 逐端口副标题内 `_routesForEndpoint(use.service.id, use.endpoint.id)`（与其他 `whereType<String>()` 过滤部分连接）。
- **备注：** 按*组合*服务 id 和端点 id 匹配——引用相同服务但不同端点的路由不匹配。
