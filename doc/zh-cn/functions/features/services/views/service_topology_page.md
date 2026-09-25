# lib/features/services/views/service_topology_page.dart

[服务与拓扑](../../../../features/services-topology.md#views) 描述的全屏服务拓扑：`ServiceTopologyPage`——服务总览的拓扑卡片（[`service_list_page.md`](service_list_page.md)，`_openTopology`）带着由当前清单构建的 `ServiceTopologyGraph` 把它压入根导航器——以及它承载的画布 `_ServiceTopologyView`。页面负责选择 / 移动模式切换、90 度旋转和 PNG 导出；视图负责延迟、缓存的布局（`_TopologyLayoutRequest` 是其缓存键）和节点详情面板。节点卡片、边画家以及图标和标签辅助来自 [`service_topology_widgets.md`](service_topology_widgets.md)；节点和边的放置来自 [`service_topology_layout.md`](../services/service_topology_layout.md)。本文件于 1.5.6 从 `service_list_page.dart` 拆出，行为不变。

**行数说明：** `grep -c 'Purpose:' service_topology_page.dart` 返回 **16**，下面每个声明一块（**7 个 Tier A / 9 个 Tier B**）。`enum _TopologyInteractionMode { select, move }`（第 17 行）是无成员枚举，不单列：选择模式把每张节点卡片的点击接到详情面板并滚动画布；移动模式去掉点击，并把画布包进 `InteractiveViewer`。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
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
| `ServiceTopologyPage`（构造函数） | 构造函数 | B | 创建全屏拓扑页组件。 |
| `createState` | 方法（`ServiceTopologyPage`） | B | 创建页面可变状态对象。 |
| [`_exportTopologyImage`](#exporttopologyimage) | 方法（`_ServiceTopologyPageState`） | A | 把拓扑画布捕获为 PNG 并交给平台分享流程。 |
| `build` | 方法（组件，`_ServiceTopologyPageState`） | B | 构建拓扑页脚手架：旋转/导出操作、模式切换、拓扑视图。 |

## 文档

### `void _ensureLayout(_TopologyLayoutRequest request)` <a id="ensurelayout"></a>
- **种类：** `_ServiceTopologyViewState` 的方法。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 108 行）。
- **用途：** 为请求安排延迟布局计算，除非相同请求已在途。
- **输入：** `request`。
- **返回：** 无。
- **副作用：** 设 `_pendingRequest`；递增 `_layoutGeneration`；安排调用 [`_calculateLayout`](#calculatelayout) 的帧后回调。
- **算法：** 1. `_pendingRequest == request`（相同图/路由身份和视口宽——见 [`_TopologyLayoutRequest.==`](#equals)）时不做事返回（已在途）。2. 否则把 `request` 记录为 `_pendingRequest`、递增 `_layoutGeneration` 并把新值捕获为 `generation`。3. 注册 `WidgetsBinding.instance.addPostFrameCallback` 调用 `_calculateLayout(request, generation)`。
- **用法：** `build` 中每当 `_completedRequest != request || _layout == null`（即当前图/路由/视口组合尚未布局）时调用。
- **备注：** 这是 [服务与拓扑 — 拓扑图布局（高层）](../../../../features/services-topology.md#topology-graph-layout-high-level) 描述行为背后的机制——"全屏拓扑把昂贵布局推迟到首帧后，并按图、路由、宽度和旋转派生视口缓存布局，使模式变化……不重跑路由。"`_layoutGeneration` 计数器正是让新请求使仍在途旧请求失效的东西（见 [`_calculateLayout`](#calculatelayout)）。

### `Future<void> _calculateLayout(_TopologyLayoutRequest request, int generation)` <a id="calculatelayout"></a>
- **种类：** `_ServiceTopologyViewState` 的方法。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 122 行）。
- **用途：** 让出一帧后为一个请求运行拓扑布局引擎，仍是最新请求时缓存结果。
- **输入：** `request`；`generation` — 此计算被安排时捕获的 `_layoutGeneration` 值。
- **返回：** `Future<void>`。
- **副作用：** 调用 `ServiceTopologyLayout.build`；仍最新时 `setState` 更新 `_layout`/`_completedRequest`/`_pendingRequest`。
- **算法：** 1. `await Future<void>.delayed(Duration.zero)` — 让出至少一帧，使这不阻塞安排它的帧。2. 未挂载、`generation` 不再等于 `_layoutGeneration`、或 `_pendingRequest` 不再等于 `request`（新请求取代此请求）时退出。3. 计算 `ServiceTopologyLayout.build(request.graph, request.routes, request.viewportWidth.toDouble())`（见 [`service_topology_layout.md#build`](../services/service_topology_layout.md#build)）。4. 重新检查相同三个过期条件（计算本身可能耗时到新请求到达）。5. `setState` 存储布局、把 `request` 标记为 `_completedRequest` 并清除 `_pendingRequest`。
- **用法：** 只经 [`_ensureLayout`](#ensurelayout) 注册的帧后回调调用。
- **备注：** 双重过期检查（`ServiceTopologyLayout.build` *前*和*后*）正是防止慢速、现已过时布局计算（如旋转前视口宽的）在新请求已完成后破坏状态的东西。

### `void _showNodeDetails(BuildContext context, ServiceTopologyNode node)` <a id="shownodedetails"></a>
- **种类：** `_ServiceTopologyViewState` 的方法。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 245 行）。
- **用途：** 解析点击拓扑节点的设备/服务/相关路由并在带编辑/添加访问操作的底部面板显示。
- **输入：** `context`、`node`。
- **返回：** `void`。
- **副作用：** 显示 `showModalBottomSheet`；其操作按钮调用 `widget.onEditService`/`widget.onEditRoute`/`widget.onAddAccess` 并弹出面板。
- **算法：** 1. 对照 `widget.devices`/`widget.services` 从 `node.deviceId`/`node.serviceId` 解析 `device`/`service`（未设或无法解析 `null`）。2. 用 `relatedRoutesForNode(node, widget.routes, services: widget.services)`（[`service_analysis.md`](../services/service_analysis.md#relatedroutesfornode)）解析 `relatedRoutes`。3. 显示列出节点自己标签/角色/详情/车道的底部面板；解析时设备块；解析时服务块（带端点）加编辑/添加访问按钮；有相关路由时每相关路由一个块（点击编辑）。
- **用法：** `_buildViewer` 中 `onTap: widget.mode == _TopologyInteractionMode.select ? () => _showNodeDetails(context, node) : null`——只在选择模式接，不在移动/缩放模式。
- **备注：** `relatedRoutes` 按 `node.routeIds`（图构建时触碰此节点的路由）匹配；服务节点还按其服务出现在路由上任何位置匹配，设备节点还按其承载的服务匹配。1.5.6 之前此规则内联在这里，并对没有服务的节点匹配每个自由形式跳；相关路由的访问级别现已本地化。

### `const _TopologyLayoutRequest({required this.graph, required this.routes, required this.viewportWidth})` <a id="topologylayoutrequest-new"></a>
- **种类：** 构造函数。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 382 行）。
- **用途：** 创建用作拓扑布局缓存键的值。
- **输入：** `graph`、`routes`、`viewportWidth`。
- **返回：** 新 `_TopologyLayoutRequest`。
- **副作用：** 无。
- **算法：** 普通字段赋值。
- **用法：** `_ServiceTopologyViewState.build` 每次 `build` 调用构造一次。
- **备注：** 无。

### `bool operator ==(Object other)` <a id="equals"></a>
- **种类：** `_TopologyLayoutRequest` 的运算符。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 394 行）。
- **用途：** 为缓存复用目的比较两个布局请求。
- **输入：** `other`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** `identical(this, other)` 为 true、或 `other` 是带 `identical` `graph`、`identical` `routes` 和相等 `viewportWidth` 的 `_TopologyLayoutRequest` 时为 `true`。
- **用法：** 经 `build`（`_completedRequest == request`）和 [`_ensureLayout`](#ensurelayout)（`_pendingRequest == request`）中的 `==`/`!=` 隐式使用。
- **备注：** 对 `graph`/`routes` 用**身份**（`identical`）而非值相等——两个结构相等但不同的 `ServiceTopologyGraph`/路由列表实例会比较不等。这是刻意的：任何新 `buildServiceTopology`/[`_load`](service_list_page.md#load) 调用即使结果图看起来相同也使缓存失效，并避免每次构建深结构比较。`viewportWidth` 比较前舍入为 `int`（在 `_ServiceTopologyViewState.build`），避免微小约束抖动强制重布局。

### `int get hashCode` <a id="hashcode"></a>
- **种类：** `_TopologyLayoutRequest` 的 getter。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 407 行）。
- **用途：** 产生与上面基于身份的 `==` 一致的哈希码。
- **输入：** 无。
- **返回：** `int`。
- **副作用：** 无。
- **算法：** `Object.hash(identityHashCode(graph), identityHashCode(routes), viewportWidth)`。
- **用法：** 本文件无任何地方显式调用——`_TopologyLayoutRequest` 值只经 `==` 比较，从不存 `Map`/`Set`——但 Dart 要求每当覆盖 `==` 时 `hashCode` 与之一致。
- **备注：** 用 `identityHashCode`（匹配 `==` 对 `graph`/`routes` 的身份基础比较），因此从不同底层 `graph`/`routes` 对象构建的两个结构相等实例也哈希不同。

### `Future<void> _exportTopologyImage()` <a id="exporttopologyimage"></a>
- **种类：** `_ServiceTopologyPageState` 的方法。
- **来源：** `lib/features/services/views/service_topology_page.dart`（第 467 行）。
- **用途：** 把拓扑画布（经其 `RepaintBoundary`）捕获为 PNG 并交给平台适当分享/保存流程。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 未就绪时显示 snackbar；设 `_exporting`；把边界渲染为图像并经 `ImageShareService.sharePngBytes` 分享；错误时显示失败 snackbar。
- **算法：** 1. `!_layoutReady` 时显示 snackbar 并返回（尚无可捕获）。2. `setState(() => _exporting = true)`。3. `await WidgetsBinding.instance.endOfFrame`（确保带当前布局的帧已实际绘制）。4. 经 `_captureKey.currentContext` 找 `RenderRepaintBoundary`；不可用抛 `StateError`。5. `boundary.toImage(pixelRatio: 3)`，然后 `image.toByteData(format: ui.ImageByteFormat.png)`；编码失败抛 `StateError`。6. 仍挂载时调用 `ImageShareService.sharePngBytes(context, bytes, fileName: 'mydevice_topology.png')`（见 [`image_share_service.md`](../../../shared/services/image_share_service.md#sharepngbytes)）。7. 任何异常时（挂载则）显示失败 snackbar。8. `finally`：清除 `_exporting`（挂载则）。
- **用法：** `build` 中应用栏导出 `IconButton` 的 `onPressed: _exporting || !_layoutReady ? null : _exportTopologyImage`。
- **备注：** 实际分享/保存机制（分享面板 vs 文件选择器 vs 剪贴板）平台特定且住在 `ImageShareService` 内，不在这里——见 [平台说明 — Android](../../../../platform-notes.md#android)。
