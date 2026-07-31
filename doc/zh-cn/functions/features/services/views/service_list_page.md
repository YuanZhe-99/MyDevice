# lib/features/services/views/service_list_page.dart

服务标签的顶层页面和其整个拓扑子流程，概念上描述于 [服务与拓扑](../../../../features/services-topology.md)。此单文件拥有三层：(1) 主列表页（`ServiceListPage`/`_ServiceListPageState`）带四个视图（总览/按设备/路由/端口）；(2) 快速访问路由对话框（`_QuickAccessRouteDialog`/`_QuickAccessRouteDialogState`），添加直接/反向代理/隧道/FRP/路由器端口转发访问路径的简单/默认流程；和 (3) 全屏拓扑页及其渲染（`_ServiceTopologyPage`、`_ServiceTopologyView`、`_TopologyNodeCard`、`_ServiceTopologyEdgePainter` 和 `_TopologyLayoutRequest` 布局缓存键）。图构建、警告/冲突检测和大多数路由格式化辅助从 `service_analysis.dart`（[`service_analysis.md`](../services/service_analysis.md)）读取；节点/边放置和边路由来自 `service_topology_layout.dart`（[`service_topology_layout.md`](../services/service_topology_layout.md)）。持久化经 `ServiceStorage`/`DeviceStorage`/`NetworkStorage`（[`service_storage.md`](../services/service_storage.md)）；此页压入的增/改表单住在 [`service_edit_page.md`](service_edit_page.md) 和 [`service_route_edit_page.md`](service_route_edit_page.md)。像应用其他列表页一样，`_ServiceListPageState` 注册到 [`AutoSyncService`](../../../shared/services/auto_sync_service.md)，使后台同步自动重载列表。

**行数说明：** `grep -c 'Purpose:' service_list_page.dart` 返回 **72**。与 `service_analysis.dart`（见 [`service_analysis.md`](../services/service_analysis.md)）不同，这 72 个块没有一个错附到调用点语句——每个都恰好坐在真实声明正上方（读每块后紧跟行验证）。然而 72 中有一个（第 32 行 `direct(ServiceRouteMethod.direct),` 上方的块）文档化**枚举常量**，非函数/方法/构造函数/getter——它是 `_QuickAccessMethod` 十个值中的第一个，其他九个（`caddy` 到 `custom`）完全无文档块。与本文档集只列行为承载声明（普通数据字段同样省略；见 `service_analysis.md` 字段排除先例）的约定一致，那个枚举常量块在此散文描述而非作为自己的声明表行。因此 72 个块中 **71** 个文档化真实声明。另外，本文件尾部有 **12 个未文档化顶层辅助函数**（第 2253–2438 行：`_splitTargets` 到 `_iconForService`）完全无 `/// Purpose:` 块。那得 **71 + 12 = 83** 个真实声明总计，下面分 **24 个 Tier A / 59 个 Tier B**。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `_QuickAccessMethod`（构造函数） | 构造函数 | B | 创建包装底层 `ServiceRouteMethod` 的枚举值。 |
| `isPortMapping` | getter（`_QuickAccessMethod`） | B | 此快速访问方法是否为 FRP 或路由器端口转发（vs 代理/隧道/直接）。 |
| `ServiceListPage`（构造函数） | 构造函数 | B | 创建页面组件（无参数）。 |
| `createState` | 方法（`ServiceListPage`） | B | 创建页面可变状态对象。 |
| [`initState`](#initstate) | 方法（`_ServiceListPageState`，组件生命周期） | A | 注册自动同步监听器并启动初始服务/路由/设备/网络加载。 |
| `dispose` | 方法（`_ServiceListPageState`，组件生命周期） | B | 注销自动同步监听器。 |
| `_handleLocalDataChanged` | 方法（`_ServiceListPageState`） | B | 响应自动同步通知重载服务/路由/设备/网络。 |
| [`_load`](#load) | 方法（`_ServiceListPageState`） | A | 从存储重载服务、路由、设备和网络。 |
| `_deviceById` | 方法（`_ServiceListPageState`） | B | 在加载设备列表按 id 查找设备。 |
| `_serviceById` | 方法（`_ServiceListPageState`） | B | 在加载服务列表按 id 查找服务。 |
| `_endpointById` | 方法（`_ServiceListPageState`） | B | 在服务上按 id 查找端点，无 id 时其第一端点。 |
| `_addService` | 方法（`_ServiceListPageState`） | B | 压入空白服务编辑页，报告保存后重载。 |
| `_editService` | 方法（`_ServiceListPageState`） | B | 为既有服务压入服务编辑页，报告保存后重载。 |
| `_addRoute` | 方法（`_ServiceListPageState`） | B | 压入高级路由编辑器，报告保存后重载。 |
| [`_addAccessRoute`](#addaccessroute) | 方法（`_ServiceListPageState`） | A | 显示快速访问对话框并持久化其返回的每条路由。 |
| `_editRoute` | 方法（`_ServiceListPageState`） | B | 为既有路由压入高级路由编辑器，报告保存后重载。 |
| `_viewLabel` | 方法（`_ServiceListPageState`） | B | 把 `_ServiceView` 映射到其本地化分段按钮标签。 |
| `build` | 方法（组件，`_ServiceListPageState`） | B | 构建脚手架：应用栏操作、FAB、视图切换器、当前视图主体。 |
| `_buildCurrentView` | 方法（组件辅助） | B | 分发到当前所选 `_ServiceView` 的构建器。 |
| `_buildOverview` | 方法（组件辅助） | B | 渲染总览视图：指标卡片、拓扑卡片、警告、路由组、服务列表。 |
| `_buildDevices` | 方法（组件辅助） | B | 渲染按设备视图：每设备分组并可展开的服务。 |
| `_buildRoutes` | 方法（组件辅助，`_ServiceListPageState`） | B | 渲染路由视图：每路由一张卡片。 |
| `_buildPorts` | 方法（组件辅助） | B | 渲染端口视图：端口冲突横幅加逐设备端口使用列表。 |
| `_topologyCard` | 方法（组件辅助） | B | 渲染总览拓扑摘要卡片，带响应式页头/操作行。 |
| `_openTopology` | 方法（`_ServiceListPageState`） | B | 为构建图压入全屏拓扑页。 |
| [`_routesGroupedByService`](#routesgroupedbyservice) | 方法（`_ServiceListPageState`） | A | 按源服务 id 分组路由并按服务名排序组。 |
| `_serviceRouteGroupCard` | 方法（组件辅助） | B | 渲染一个服务的路由组为可展开卡片。 |
| `_metricCard` | 方法（组件辅助） | B | 渲染一个总览指标块（图标、值、标签）。 |
| `_serviceTile` | 方法（组件辅助） | B | 渲染一个服务列表块（图标、设备、端点、路由数、菜单）。 |
| `_routeCard` | 方法（组件辅助） | B | 渲染一个路由摘要卡片。 |
| [`_hopLabel`](#hoplabel) | 方法（`_ServiceListPageState`） | A | 为一个路由跳计算显示标签。 |
| [`_routeSummary`](#routesummary) | 方法（`_ServiceListPageState`） | A | 为路由构建"源 -> 跳 -> 目标"摘要行。 |
| [`_routesForEndpoint`](#routesforendpoint) | 方法（`_ServiceListPageState`） | A | 找使用给定服务端点的路由显示名。 |
| `_warningText` | 方法（`_ServiceListPageState`） | B | 把 `ServiceWarning` 映射到其本地化消息。 |
| `_emptyState` | 方法（组件辅助） | B | 渲染居中空状态消息。 |
| `_emptyInline` | 方法（组件辅助） | B | 渲染填充内联空状态消息。 |
| `_QuickAccessRouteDialog`（构造函数） | 构造函数 | B | 创建对话框组件（服务、设备、可选初始服务）。 |
| `createState` | 方法（`_QuickAccessRouteDialog`） | B | 创建对话框可变状态对象。 |
| [`initState`](#initstate-quickaccessroutedialogstate) | 方法（`_QuickAccessRouteDialogState`，组件生命周期） | A | 创建文本控制器并播种默认源服务/端点。 |
| `dispose` | 方法（`_QuickAccessRouteDialogState`，组件生命周期） | B | 释放四个文本控制器。 |
| `_selectedSource` | getter（`_QuickAccessRouteDialogState`） | B | 解析当前所选源 `ServiceNode`（如有）。 |
| [`_buildRoutes`](#buildroutes) | 方法（`_QuickAccessRouteDialogState`） | A | 组装当前表单状态描述的单个 `ServiceRoute`。 |
| [`_buildHop`](#buildhop) | 方法（`_QuickAccessRouteDialogState`） | A | 构建匹配所选快速访问方法的单跳 `ServiceRouteHop`。 |
| `_submit` | 方法（`_QuickAccessRouteDialogState`） | B | 验证表单并带构建路由列表弹出对话框。 |
| `build` | 方法（组件，`_QuickAccessRouteDialogState`） | B | 渲染快速访问表单（源/端点/方法/中继/访问级别字段）。 |
| [`_relayServiceOptions`](#relayserviceoptions) | 方法（`_QuickAccessRouteDialogState`） | A | 列出候选中继服务，端口映射方法偏好 FRP 类。 |
| [`_isFrpLikeService`](#isfrplikeservice) | 方法（`_QuickAccessRouteDialogState`） | A | 启发式决定服务是否像 FRP/隧道中继。 |
| `_deviceName` | 方法（`_QuickAccessRouteDialogState`） | B | 把设备 id 解析为其名，无法解析时 id 本身。 |
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
| [`_splitTargets`](#splittargets) | 顶层函数 | A | 把换行/逗号分隔字符串拆分为修剪、非空目标字符串。 |
| `_emptyToNull` | 顶层函数 | B | 修剪字符串并把空结果转换为 `null`。 |
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

`_QuickAccessMethod` 其他九个枚举值（`caddy`、`nginx`、`traefik`、`frp`、`pangolin`、`cloudflareTunnel`、`tailscaleFunnel`、`routerPortForward`、`custom`）是普通数据，像 `direct` 一样，同样不给自己的表格行。`enum _ServiceView { overview, devices, routes, ports }` 和 `enum _TopologyInteractionMode { select, move }`（第 22/24 行）是简单、无成员枚举，无自己构造函数/方法，因此也不列出——它们只作为上面方法的参数/返回类型出现（`_viewLabel`、`_buildCurrentView`、`build` 中 `SegmentedButton`）。

`iconForServiceIcon`（第 2391 行）是本文件唯一**公共**（非下划线）顶层声明；它也被 `service_edit_page.dart`（见 [`service_edit_page.md`](service_edit_page.md)）调用渲染服务名/图标字段旁和模板选择器逐模板图标的图标预览。

## 文档

### `void initState()` <a id="initstate"></a>
- **种类：** `_ServiceListPageState` 的方法（组件生命周期覆盖）。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 93 行）。
- **用途：** 把本页接入自动同步通知系统并启动初始服务/路由/设备/网络加载。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 把 `_handleLocalDataChanged` 注册到 `AutoSyncService.instance.addOnLocalDataChanged`；启动异步加载。
- **算法：** 1. 调用 `super.initState()`。2. 把 `_handleLocalDataChanged` 注册为 `AutoSyncService` 本地数据变更监听器。3. 调用 `_load()`（不 await）。
- **用法：** `_ServiceListPageState` 首次插入树时由 Flutter 框架自动调用；无直接调用点。
- **备注：** 对应 `dispose()` 调用 `AutoSyncService.instance.removeOnLocalDataChanged(_handleLocalDataChanged)` 避免泄漏监听器（见 [`auto_sync_service.md#addonlocaldatachanged`](../../../shared/services/auto_sync_service.md)）。

### `Future<void> _load()` <a id="load"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 124 行）。
- **用途：** 从各自存储重载服务、路由、设备和网络并刷新页面状态。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 经 `ServiceStorage.load()`、`DeviceStorage.load()`、`NetworkStorage.load()` 读取；`setState` 更新 `_services`/`_routes`/`_devices`/`_networks` 并清除 `_loading`。
- **算法：** Await `ServiceStorage.load()`（服务 + 路由），然后 `DeviceStorage.load()`，然后 `NetworkStorage.load()`，顺序（非并行）；未挂载提前返回；一次 `setState` 分配全部四个列表并设 `_loading = false`。
- **用法：** 从 [`initState`](#initstate)、`_handleLocalDataChanged`（自动同步）和每个增/改/访问路由流程后（`_addService`/`_editService`/`_addRoute`/`_editRoute` 的 `if (result == true) _load();` 模式和 [`_addAccessRoute`](#addaccessroute) 的 `await _load();`）调用。
- **备注：** 三个存储顺序加载而非 `Future.wait`，因此总加载时间跨它们相加——鉴于这些是小本地 JSON 文件可接受。

### `Future<void> _addAccessRoute({ServiceNode? source})` <a id="addaccessroute"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 210 行）。
- **用途：** 打开快速访问路由对话框并持久化其返回的每条路由。
- **输入：** `source` — 预选为对话框源服务的可选服务。
- **返回：** `Future<void>`。
- **副作用：** 显示 `_QuickAccessRouteDialog`；对每条返回路由调用一次 `ServiceStorage.addOrUpdateRoute`；重载。
- **算法：** 1. 用 `_QuickAccessRouteDialog(services: _services, devices: _devices, initialService: source)` 做 `showDialog<List<ServiceRoute>>`。2. 结果为 `null` 或空（对话框取消）提前返回。3. 对每条返回路由顺序 `await ServiceStorage.addOrUpdateRoute(route)`。4. `await _load()`。
- **用法：**
  ```dart
  IconButton(
    icon: const Icon(Icons.add_link),
    tooltip: l10n.serviceAddAccess,
    onPressed: _services.isEmpty ? null : () => _addAccessRoute(),
  ),
  ```
  也（带特定 `source`）从 `_buildOverview` 的添加访问按钮、`_serviceRouteGroupCard`、`_serviceTile` 弹出菜单、`_topologyCard` 操作行调用，并作为 `onAddAccess` 回调传给 `_ServiceTopologyPage`/`_ServiceTopologyView`/[`_showNodeDetails`](#shownodedetails)。
- **备注：** [`_QuickAccessRouteDialogState._buildRoutes`](#buildroutes) 当前总是返回单元素（或空）列表，但此方法写成循环任意列表，因此未来一次提交多条路由的对话框变体这里无需更改。

### `List<MapEntry<String, List<ServiceRoute>>> _routesGroupedByService()` <a id="routesgroupedbyservice"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 737 行）。
- **用途：** 按源服务 id 分组所有路由，供总览逐服务路由卡片。
- **输入：** 无。
- **返回：** `List<MapEntry<String, List<ServiceRoute>>>`，按解析服务名（不区分大小写）排序；无法解析 id 按其自己原始文本排序。
- **副作用：** 无。
- **算法：** 1. 把 `_routes` 分桶进按 `route.sourceServiceId` 键控的映射（`putIfAbsent(...).add(route)`）。2. 转换为条目列表。3. 按 `_serviceById(key)?.name ?? key` 小写排序。
- **用法：** `_buildOverview` 中 `for (final entry in _routesGroupedByService()) _serviceRouteGroupCard(l10n, entry.key, entry.value)`。
- **备注：** 源服务此后被删的路由仍按其原始（无法解析）服务 id 分组，而非从总览丢弃。

### `String _hopLabel(ServiceRouteHop hop)` <a id="hoplabel"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 912 行）。
- **用途：** 为一个路由跳计算短显示标签，供路由摘要行。
- **输入：** `hop`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** 1. 跳 `serviceId` 解析到已知服务时返回该服务名。2. 否则 `hop.label` 非空返回它。3. 否则 `hop.host` 非空返回从存在的 `scheme`/`port`/`path` 中构建的 `scheme://host:port/path` 形态字符串。4. 否则回退 `hop.type.name`。
- **用法：** [`_routeSummary`](#routesummary) 内 `route.hops.map(_hopLabel)`。
- **备注：** 这是 `service_analysis.dart` 拓扑图构建器 `_relayLabel` 的 UI 文本摘要对应物——两者都为跳实现类似服务名/标签/主机/类型回退链，但独立（这个供路由列表文本，那个供图节点标签）；见 [`service_analysis.md#relaylabel`](../services/service_analysis.md#relaylabel)。

### `String _routeSummary(ServiceRoute route, {ServiceNode? source, ServiceEndpoint? sourceEndpoint})` <a id="routesummary"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 929 行）。
- **用途：** 构建每条路由卡片下显示的两行文本摘要：源到目标路径，然后访问级别。
- **输入：** `route`；`source`/`sourceEndpoint` — 已解析源服务/端点（使此方法不必重新解析）。
- **返回：** `String` — 箭头连接路径和 `route.accessLevel.name` 用 `'\n'` 连接。
- **副作用：** 无。
- **算法：** 1. 构建 `parts` 列表：源服务名（端点有端口时追加其端口文本），然后每个跳 [`_hopLabel`](#hoplabel)，然后每个访问目标（`serviceRouteAccessTargets(route)`）经 `compactAccessTargetLabel` 运行。2. 用 `' -> '` 连接非空 `parts`，`parts` 最终为空时回退 `route.name`。3. 追加 `route.accessLevel.name` 为第二行。
- **用法：** `_routeCard` 副标题中 `_routeSummary(route, source: source, sourceEndpoint: sourceEndpoint)`。
- **备注：** 实践中 `parts` 不可能为空（路由总是至少一跳），因此 `route.name` 回退是防御而非正常到达路径。

### `String? _routesForEndpoint(String serviceId, String endpointId)` <a id="routesforendpoint"></a>
- **种类：** `_ServiceListPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 951 行）。
- **用途：** 找使用给定服务端点（作为源或经跳）的每条路由显示名，供端口视图副标题。
- **输入：** `serviceId`、`endpointId`。
- **返回：** `String?` — 逗号连接路由显示目标列表，无路由引用此端点时 `null`。
- **副作用：** 无。
- **算法：** 过滤 `_routes` 到 (`sourceServiceId` 和 `sourceEndpointId` 都匹配) 或任何跳 (`serviceId` 和 `endpointId`) 都匹配的；把幸存者经 `serviceRouteDisplayTarget` 映射；用 `', '` 连接；无匹配返回 `null`。
- **用法：** `_buildPorts` 逐端口副标题内 `_routesForEndpoint(use.service.id, use.endpoint.id)`（与其他 `whereType<String>()` 过滤部分连接）。
- **备注：** 按*组合*服务 id 和端点 id 匹配——引用相同服务但不同端点的路由不匹配。

### `void initState()` <a id="initstate-quickaccessroutedialogstate"></a>
- **种类：** `_QuickAccessRouteDialogState` 的方法（组件生命周期覆盖）。因两者都命名 `initState`，与上面 [`_ServiceListPageState.initState`](#initstate) 消歧。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1084 行）。
- **用途：** 创建对话框文本控制器并播种默认源服务/端点选择。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 实例化四个 `TextEditingController`；设置 `_sourceServiceId`/`_sourceEndpointId`。
- **算法：** 1. `super.initState()`。2. 创建 `_targetsCtrl`/`_remoteHostCtrl`/`_remotePortCtrl`/`_notesCtrl`。3. 默认 `_sourceServiceId` 为 `widget.initialService?.id`，回退 `widget.services` 第一条目。4. 默认 `_sourceEndpointId` 为解析源第一端点 id。
- **用法：** `_QuickAccessRouteDialog` 状态创建时自动调用，如 [`_addAccessRoute`](#addaccessroute) 的 `showDialog(... builder: (context) => _QuickAccessRouteDialog(...))` 调用。
- **备注：** 对应 `dispose()`（第 1101 行）释放全部四个控制器。与外层页面不同，此对话框不注册 `AutoSyncService`——它是短命模态表单，非持久页面。

### `List<ServiceRoute> _buildRoutes()` <a id="buildroutes"></a>
- **种类：** `_QuickAccessRouteDialogState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1125 行）。
- **用途：** 组装当前表单状态描述的单个 `ServiceRoute`，准备好交回调用方。
- **输入：** 无（读取对话框表单状态字段）。
- **返回：** `List<ServiceRoute>` — 未选源服务时空，否则单元素列表。
- **副作用：** 无（纯构造）。
- **算法：** 1. 解析 `_selectedSource`；`null` 返回 `const []`。2. 经 [`_splitTargets`](#splittargets) 把 `_targetsCtrl.text` 拆分为目标。3. 经 [`_buildHop`](#buildhop)`(_method.routeMethod)` 构建单跳。4. 构造一个 `name` 来自 `serviceRouteGeneratedName`、`finalUrl` 是第一目标、`extraJson` 经 `serviceRouteExtraJsonWithTargets` 携带任何剩余目标的 `ServiceRoute`。
- **用法：** `_submit` 中 `Navigator.of(context).pop(_buildRoutes());`。
- **备注：** 尽管名字/返回类型复数，这总是构建**至多一个** `ServiceRoute`——快速访问流程每次提交只创建一个带单跳的路由，按 [快速访问路由创建 vs 高级编辑器](../../../../features/services-topology.md#quick-access-route-creation-vs-the-advanced-editor)。

### `ServiceRouteHop _buildHop(ServiceRouteMethod method)` <a id="buildhop"></a>
- **种类：** `_QuickAccessRouteDialogState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1155 行）。
- **用途：** 构建匹配当前所选快速访问方法的单跳 `ServiceRouteHop`。
- **输入：** `method`。
- **返回：** `ServiceRouteHop`。
- **副作用：** 无。
- **算法：** `_method.isPortMapping`（FRP 或路由器端口转发）时：构建带 `_relayServiceId`/`_remoteDeviceId` 加解析 `_remoteHostCtrl`/`_remotePortCtrl` 文本（未选中继服务时回退方法名标签）的 `ServiceRouteHopType.portForward` 跳。否则：按对 `method` 的 `switch` 挑跳类型（`direct` → `manual`；`caddy`/`nginx`/`traefik` → `reverseProxy`；`routerPortForward` → `portForward`；其他一切，即隧道风格方法 `frp`/`pangolin`/`cloudflareTunnel`/`tailscaleFunnel`/`custom` → `tunnel`），带 `serviceId: _relayServiceId` 和相同标签回退。
- **用法：** [`_buildRoutes`](#buildroutes) 中 `_buildHop(method)`。
- **备注：** 实现 [服务与拓扑 — FRP 风格入口/公共端口建模](../../../../features/services-topology.md#frp-style-ingresspublic-port-modeling) 描述的 FRP 入口/公共端口建模拆分——这里端口映射分支产生*入口*端口跳；配对的公共远程入口端口来自单独 `_remoteHostCtrl`/`_remotePortCtrl` 字段，非第二个跳。

### `List<ServiceNode> _relayServiceOptions()` <a id="relayserviceoptions"></a>
- **种类：** `_QuickAccessRouteDialogState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1426 行）。
- **用途：** 列出"经由"下拉候选中继服务，所选方法是端口映射方法时偏好 FRP 类服务在前。
- **输入：** 无（读取 `widget.services`、`_sourceServiceId`、`_method`）。
- **返回：** `List<ServiceNode>` — 除所选源外的每个服务，排序。
- **副作用：** 无。
- **算法：** 1. 过滤掉当前所选源服务。2. 排序：`_method.isPortMapping` 时 [`_isFrpLikeService`](#isfrplikeservice) 为 `true` 的服务排在 `false` 前；否则（或作为打破平局）不区分大小写比较名。
- **用法：** 填充 `build` 中继服务下拉 `items`。
- **备注：** FRP 偏好排序只是 UX 便利（先浮出可能正确的中继）——不过滤非 FRP 类服务；任何服务仍可选。

### `bool _isFrpLikeService(ServiceNode service)` <a id="isfrplikeservice"></a>
- **种类：** `_QuickAccessRouteDialogState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1446 行）。
- **用途：** 启发式决定服务是否像 FRP/隧道中继，供排序中继下拉。
- **输入：** `service`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 把 `service.name`/`templateId`/`icon`/`kind.name`（跳过 null）连接进一个小写字符串；含 `"frp"` 或 `service.kind == ServiceKind.tunnel` 时返回 `true`。
- **用法：** 从 [`_relayServiceOptions`](#relayserviceoptions) 排序比较器调用。
- **备注：** 纯命名/kind 启发式——不检查任何实际服务配置（Docker Compose 文本、端点等），与仅手动清单设计一致（无发现），按 [服务与拓扑](../../../../features/services-topology.md)。

### `void _ensureLayout(_TopologyLayoutRequest request)` <a id="ensurelayout"></a>
- **种类：** `_ServiceTopologyViewState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1554 行）。
- **用途：** 为请求安排延迟布局计算，除非相同请求已在途。
- **输入：** `request`。
- **返回：** 无。
- **副作用：** 设 `_pendingRequest`；递增 `_layoutGeneration`；安排调用 [`_calculateLayout`](#calculatelayout) 的帧后回调。
- **算法：** 1. `_pendingRequest == request`（相同图/路由身份和视口宽——见 [`_TopologyLayoutRequest.==`](#equals)）时不做事返回（已在途）。2. 否则把 `request` 记录为 `_pendingRequest`、递增 `_layoutGeneration` 并把新值捕获为 `generation`。3. 注册 `WidgetsBinding.instance.addPostFrameCallback` 调用 `_calculateLayout(request, generation)`。
- **用法：** `build` 中每当 `_completedRequest != request || _layout == null`（即当前图/路由/视口组合尚未布局）时调用。
- **备注：** 这是 [服务与拓扑 — 拓扑图布局（高层）](../../../../features/services-topology.md#topology-graph-layout-high-level) 描述行为背后的机制——"全屏拓扑把昂贵布局推迟到首帧后，并按图、路由、宽度和旋转派生视口缓存布局，使模式变化……不重跑路由。"`_layoutGeneration` 计数器正是让新请求使仍在途旧请求失效的东西（见 [`_calculateLayout`](#calculatelayout)）。

### `Future<void> _calculateLayout(_TopologyLayoutRequest request, int generation)` <a id="calculatelayout"></a>
- **种类：** `_ServiceTopologyViewState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1568 行）。
- **用途：** 让出一帧后为一个请求运行拓扑布局引擎，仍是最新请求时缓存结果。
- **输入：** `request`；`generation` — 此计算被安排时捕获的 `_layoutGeneration` 值。
- **返回：** `Future<void>`。
- **副作用：** 调用 `ServiceTopologyLayout.build`；仍最新时 `setState` 更新 `_layout`/`_completedRequest`/`_pendingRequest`。
- **算法：** 1. `await Future<void>.delayed(Duration.zero)` — 让出至少一帧，使这不阻塞安排它的帧。2. 未挂载、`generation` 不再等于 `_layoutGeneration`、或 `_pendingRequest` 不再等于 `request`（新请求取代此请求）时退出。3. 计算 `ServiceTopologyLayout.build(request.graph, request.routes, request.viewportWidth.toDouble())`（见 [`service_topology_layout.md#build`](../services/service_topology_layout.md#build)）。4. 重新检查相同三个过期条件（计算本身可能耗时到新请求到达）。5. `setState` 存储布局、把 `request` 标记为 `_completedRequest` 并清除 `_pendingRequest`。
- **用法：** 只经 [`_ensureLayout`](#ensurelayout) 注册的帧后回调调用。
- **备注：** 双重过期检查（`ServiceTopologyLayout.build` *前*和*后*）正是防止慢速、现已过时布局计算（如旋转前视口宽的）在新请求已完成后破坏状态的东西。

### `void _showNodeDetails(BuildContext context, ServiceTopologyNode node)` <a id="shownodedetails"></a>
- **种类：** `_ServiceTopologyViewState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1691 行）。
- **用途：** 解析点击拓扑节点的设备/服务/相关路由并在带编辑/添加访问操作的底部面板显示。
- **输入：** `context`、`node`。
- **返回：** `void`。
- **副作用：** 显示 `showModalBottomSheet`；其操作按钮调用 `widget.onEditService`/`widget.onEditRoute`/`widget.onAddAccess` 并弹出面板。
- **算法：** 1. 对照 `widget.devices`/`widget.services` 从 `node.deviceId`/`node.serviceId` 解析 `device`/`service`（未设或无法解析 `null`）。2. 解析 `relatedRoutes`：id 在 `node.routeIds`、或源服务、或任何跳服务匹配 `node.serviceId` 的路由。3. 显示列出节点自己标签/角色/详情/车道的底部面板；解析时设备块；解析时服务块（带端点）加编辑/添加访问按钮；有相关路由时每相关路由一个块（点击编辑）。
- **用法：** `_buildViewer` 中 `onTap: widget.mode == _TopologyInteractionMode.select ? () => _showNodeDetails(context, node) : null`——只在选择模式接，不在移动/缩放模式。
- **备注：** `relatedRoutes` 按 `node.routeIds`（图构建时触碰此节点的路由）和按服务 id 匹配，因此即使此确切节点不是其源，只要节点服务出现在路由跳上任何地方，路由也能在这里浮出。

### `const _TopologyLayoutRequest({required this.graph, required this.routes, required this.viewportWidth})` <a id="topologylayoutrequest-new"></a>
- **种类：** 构造函数。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1822 行）。
- **用途：** 创建用作拓扑布局缓存键的值。
- **输入：** `graph`、`routes`、`viewportWidth`。
- **返回：** 新 `_TopologyLayoutRequest`。
- **副作用：** 无。
- **算法：** 普通字段赋值。
- **用法：** `_ServiceTopologyViewState.build` 每次 `build` 调用构造一次。
- **备注：** 无。

### `bool operator ==(Object other)` <a id="equals"></a>
- **种类：** `_TopologyLayoutRequest` 的运算符。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1834 行）。
- **用途：** 为缓存复用目的比较两个布局请求。
- **输入：** `other`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** `identical(this, other)` 为 true、或 `other` 是带 `identical` `graph`、`identical` `routes` 和相等 `viewportWidth` 的 `_TopologyLayoutRequest` 时为 `true`。
- **用法：** 经 `build`（`_completedRequest == request`）和 [`_ensureLayout`](#ensurelayout)（`_pendingRequest == request`）中的 `==`/`!=` 隐式使用。
- **备注：** 对 `graph`/`routes` 用**身份**（`identical`）而非值相等——两个结构相等但不同的 `ServiceTopologyGraph`/路由列表实例会比较不等。这是刻意的：任何新 `buildServiceTopology`/[`_load`](#load) 调用即使结果图看起来相同也使缓存失效，并避免每次构建深结构比较。`viewportWidth` 比较前舍入为 `int`（在 `_ServiceTopologyViewState.build`），避免微小约束抖动强制重布局。

### `int get hashCode` <a id="hashcode"></a>
- **种类：** `_TopologyLayoutRequest` 的 getter。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1847 行）。
- **用途：** 产生与上面基于身份的 `==` 一致的哈希码。
- **输入：** 无。
- **返回：** `int`。
- **副作用：** 无。
- **算法：** `Object.hash(identityHashCode(graph), identityHashCode(routes), viewportWidth)`。
- **用法：** 本文件无任何地方显式调用——`_TopologyLayoutRequest` 值只经 `==` 比较，从不存 `Map`/`Set`——但 Dart 要求每当覆盖 `==` 时 `hashCode` 与之一致。
- **备注：** 用 `identityHashCode`（匹配 `==` 对 `graph`/`routes` 的身份基础比较），因此从不同底层 `graph`/`routes` 对象构建的两个结构相等实例也哈希不同。

### `Future<void> _exportTopologyImage()` <a id="exporttopologyimage"></a>
- **种类：** `_ServiceTopologyPageState` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 1899 行）。
- **用途：** 把拓扑画布（经其 `RepaintBoundary`）捕获为 PNG 并交给平台适当分享/保存流程。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 未就绪时显示 snackbar；设 `_exporting`；把边界渲染为图像并经 `ImageShareService.sharePngBytes` 分享；错误时显示失败 snackbar。
- **算法：** 1. `!_layoutReady` 时显示 snackbar 并返回（尚无可捕获）。2. `setState(() => _exporting = true)`。3. `await WidgetsBinding.instance.endOfFrame`（确保带当前布局的帧已实际绘制）。4. 经 `_captureKey.currentContext` 找 `RenderRepaintBoundary`；不可用抛 `StateError`。5. `boundary.toImage(pixelRatio: 3)`，然后 `image.toByteData(format: ui.ImageByteFormat.png)`；编码失败抛 `StateError`。6. 仍挂载时调用 `ImageShareService.sharePngBytes(context, bytes, fileName: 'mydevice_topology.png')`（见 [`image_share_service.md`](../../../shared/services/image_share_service.md#sharepngbytes)）。7. 任何异常时（挂载则）显示失败 snackbar。8. `finally`：清除 `_exporting`（挂载则）。
- **用法：** `build` 中应用栏导出 `IconButton` 的 `onPressed: _exporting || !_layoutReady ? null : _exportTopologyImage`。
- **备注：** 实际分享/保存机制（分享面板 vs 文件选择器 vs 剪贴板）平台特定且住在 `ImageShareService` 内，不在这里——见 [平台说明 — Android](../../../../platform-notes.md#android)。

### `void paint(Canvas canvas, Size size)` <a id="paint"></a>
- **种类：** `_ServiceTopologyEdgePainter` 的方法（`CustomPainter` 覆盖）。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 2180 行）。
- **用途：** 把每条图边路由折线和箭头绘制到画布。
- **输入：** `canvas`；`size`（不直接使用——布局已带绝对坐标）。
- **返回：** 无。
- **副作用：** 绘制到 `canvas`。
- **算法：** 对 `graph.edges` 每条边：在 `layout.edgePaths` 查找其路由点；缺失或少于 2 点跳过；构建 `_edgeColor(edge)` 着色（62% alpha、2.2 描边宽、圆帽/圆角）的 `Paint`；委托 [`_drawPolyline`](#drawpolyline) 实际绘制。
- **用法：** 此画家支撑的 `CustomPaint` 需要重绘时由 Flutter 框架调用（`shouldRepaint` 门控）。
- **备注：** 路由点（带避障的正交路径）来自 [`ServiceTopologyLayout.build`](../services/service_topology_layout.md#build)——此画家只绘制给它的路径；自己不做路由。

### `void _drawPolyline(Canvas canvas, Paint paint, List<Offset> points)` <a id="drawpolyline"></a>
- **种类：** `_ServiceTopologyEdgePainter` 的方法。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 2199 行）。
- **用途：** 绘制一条边多段路径加其末端三角箭头。
- **输入：** `canvas`、`paint`、`points` — 路由折线（2 个或更多点）。
- **返回：** `void`。
- **副作用：** 绘制到 `canvas`。
- **算法：** 1. 构建移到 `points.first` 然后 `lineTo` 穿过每个后续点的 `Path`；绘制它。2. 从末端向后扫描找距端点超 0.5px 的最后点作方向参考（防退化的近零长末段）。3. 经 `atan2` 计算接近角。4. 从端点以 `angle ± 0.45` 弧度画回两条短线（`V` 形箭头，约 9px 长）。
- **用法：** [`paint`](#paint) 每条边调用一次。
- **备注：** 向后扫描非退化参考点意味着箭头方向反映边实际接近方向，即使路由器发出近重复最后点。

### `List<String> _splitTargets(String value)` <a id="splittargets"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 2253 行）。
- **用途：** 把自由形式、换行/逗号分隔访问目标字符串拆分为干净列表。
- **输入：** `value` — 快速访问对话框目标字段原始文本。
- **返回：** `List<String>` — 修剪、非空条目。
- **副作用：** 无。
- **算法：** 按正则 `[\n,]+` 拆分；修剪每块；丢弃空结果。
- **用法：** [`_QuickAccessRouteDialogState._buildRoutes`](#buildroutes) 中 `_splitTargets(_targetsCtrl.text)`。
- **备注：** 接受换行或逗号分隔输入（或混合），因此用户可任一种方式粘贴域列表。

### `String _compactTopologyLabel(ServiceTopologyNode node)` <a id="compacttopologylabel"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 2264 行）。
- **用途：** 把拓扑节点标签/详情缩短为适合紧凑端口 chip 的短字符串。
- **输入：** `node`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** 对 `remoteEntry` 节点：经正则从标签提取尾部 `:port`（或 `:start-end`）后缀，找到只返回端口文本；否则 5 字符或更少原样返回标签，更长取其前 5 字符。对任何其他节点 kind：搜索连接 `label` + `detail` 文本中*最后*端口类数字序列，找到返回它；否则回退相同短标签或截断规则。
- **用法：** `_TopologyNodeCard.build` 紧凑（端口 chip）分支中 `_compactTopologyLabel(node)`。
- **备注：** 偏好*最后*数字匹配（非第一）正是让 `"tcp bind-host:8080"` 之类 detail 字符串显示 `8080` 而非绑定地址中较早、无关数字的东西；这只是显示性缩短——节点完整标签/详情经其 `Tooltip` 仍可用。

### `IconData _iconForTopologyNode(ServiceTopologyNode node, List<ServiceNode> services, List<Device> devices)` <a id="iconfortopologynode"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/services/views/service_list_page.dart`（第 2280 行）。
- **用途：** 基于 kind 和（可解析时）其底层设备/服务解析拓扑节点要显示的图标。
- **输入：** `node`、`services`、`devices`。
- **返回：** `IconData`。
- **副作用：** 无。
- **算法：** `device` kind → 解析设备类别图标（`deviceCategoryIcon`），无法解析时泛型设备图标。`service` kind → 解析服务图标（`_iconForService`），无法解析时泛型 `dns` 图标。`endpoint` kind → 固定 ethernet-settings 图标。`remoteEntry` → 公共图标。`domain` → 语言图标。其他任何 → `_iconForMethod(node.method)`。
- **用法：** `_ServiceTopologyViewState._buildViewer` 和 [`_showNodeDetails`](#shownodedetails) 中 `_iconForTopologyNode(node, widget.services, widget.devices)`。
- **备注：** 无。
