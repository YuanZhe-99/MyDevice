# lib/features/services/views/service_topology_widgets.dart

全屏拓扑（[`service_topology_page.md`](service_topology_page.md)）用来绘制的部件，于 1.5.6 从 `service_list_page.dart` 拆出，行为不变：`ServiceTopologyNodeCard`（完整卡片，或紧凑节点的小端口 chip）、`ServiceTopologyEdgePainter`（带箭头、按访问车道着色的已路由边），以及其背后的图标、颜色和标签辅助。`iconForServiceIcon` 和 `iconForService` 的用途不止拓扑：服务列表（[`service_list_page.md`](service_list_page.md)）、服务编辑器及其模板选择器（[`service_edit_page.md`](service_edit_page.md)）和引导式访问路径页（[`service_access_path_page.md`](service_access_path_page.md)）都用它们绘制服务图标。

**行数说明：** `grep -c 'Purpose:' service_topology_widgets.dart` 返回 **18**，下面每个声明一块（**5 个 Tier A / 13 个 Tier B**）。从 `_compactTopologyLabel` 到 `iconForService` 的十个顶层辅助在 `service_list_page.dart` 里时没有 `/// Purpose:` 块；移动时补上了，拓扑页或其他文件调用的六个变为公共（`iconForTopologyNode`、`iconForRouteMethod`、`primaryRouteMethod`、`topologyLaneLabel`、`topologyRoleLabel`、`iconForService`）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ServiceTopologyNodeCard`（构造函数） | 构造函数 | B | 创建节点卡片组件（节点、图标、点击处理器）。 |
| `build` | 方法（组件，`ServiceTopologyNodeCard`） | B | 把节点渲染为紧凑端口 chip 或完整标签/详情卡片。 |
| `ServiceTopologyEdgePainter`（构造函数） | 构造函数 | B | 创建边画家（图、布局、配色方案）。 |
| [`paint`](#paint) | 方法（`ServiceTopologyEdgePainter`，`CustomPainter` 覆盖） | A | 把每条边路由折线和箭头绘制到画布。 |
| [`_drawPolyline`](#drawpolyline) | 方法（`ServiceTopologyEdgePainter`） | A | 绘制一条边路径加其末端三角箭头。 |
| `_edgeColor` | 方法（`ServiceTopologyEdgePainter`） | B | 把边访问车道映射到配色方案颜色。 |
| `shouldRepaint` | 方法（`ServiceTopologyEdgePainter`） | B | 只在图、布局或配色方案变化时重绘。 |
| [`_nodeSubtitle`](#nodesubtitle) | 顶层函数 | A | 拓扑节点卡片显示的副标题：中继显示本地化方法或跳类型，否则显示构建器的 detail。 |
| [`_compactTopologyLabel`](#compacttopologylabel) | 顶层函数 | A | 把拓扑节点标签/详情缩短为紧凑 chip 尺寸字符串。 |
| [`iconForTopologyNode`](#iconfortopologynode) | 顶层函数 | A | 按 kind 及其解析设备/服务解析拓扑节点图标。 |
| `iconForRouteMethod` | 顶层函数 | B | 把 `ServiceRouteMethod` 映射到其显示图标（null → 通用路由图标）。 |
| `primaryRouteMethod` | 顶层函数 | B | 返回路由首跳方法（如有）。 |
| `topologyLaneLabel` | 顶层函数 | B | 把 `ServiceAccessLane` 映射到其（英文）显示标签。 |
| `topologyRoleLabel` | 顶层函数 | B | 把 `ServiceTopologyNodeRole` 映射到其（英文）显示标签。 |
| `_nodeFill` | 顶层函数 | B | 把拓扑节点角色映射到其卡片填充色。 |
| `_nodeBorder` | 顶层函数 | B | 把拓扑节点角色映射到其卡片边框色。 |
| `iconForServiceIcon` | 顶层函数 | B | 把服务存储图标键映射到其 `IconData`（未知时为 `Icons.dns`）。 |
| `iconForService` | 顶层函数 | B | 经 `iconForServiceIcon` 解析服务图标。 |

## 文档

### `void paint(Canvas canvas, Size size)` <a id="paint"></a>
- **种类：** `ServiceTopologyEdgePainter` 的方法（`CustomPainter` 覆盖）。
- **来源：** `lib/features/services/views/service_topology_widgets.dart`（第 175 行）。
- **用途：** 把每条图边路由折线和箭头绘制到画布。
- **输入：** `canvas`；`size`（不直接使用——布局已带绝对坐标）。
- **返回：** 无。
- **副作用：** 绘制到 `canvas`。
- **算法：** 对 `graph.edges` 每条边：在 `layout.edgePaths` 查找其路由点；缺失或少于 2 点跳过；构建 `_edgeColor(edge)` 着色（62% alpha、2.2 描边宽、圆帽/圆角）的 `Paint`；委托 [`_drawPolyline`](#drawpolyline) 实际绘制。
- **用法：** 此画家支撑的 `CustomPaint` 需要重绘时由 Flutter 框架调用（`shouldRepaint` 门控）。
- **备注：** 路由点（带避障的正交路径）来自 [`ServiceTopologyLayout.build`](../services/service_topology_layout.md#build)——此画家只绘制给它的路径；自己不做路由。

### `void _drawPolyline(Canvas canvas, Paint paint, List<Offset> points)` <a id="drawpolyline"></a>
- **种类：** `ServiceTopologyEdgePainter` 的方法。
- **来源：** `lib/features/services/views/service_topology_widgets.dart`（第 195 行）。
- **用途：** 绘制一条边多段路径加其末端三角箭头。
- **输入：** `canvas`、`paint`、`points` — 路由折线（2 个或更多点）。
- **返回：** `void`。
- **副作用：** 绘制到 `canvas`。
- **算法：** 1. 构建移到 `points.first` 然后 `lineTo` 穿过每个后续点的 `Path`；绘制它。2. 从末端向后扫描找距端点超 0.5px 的最后点作方向参考（防退化的近零长末段）。3. 经 `atan2` 计算接近角。4. 从端点以 `angle ± 0.45` 弧度画回两条短线（`V` 形箭头，约 9px 长）。
- **用法：** [`paint`](#paint) 每条边调用一次。
- **备注：** 向后扫描非退化参考点意味着箭头方向反映边实际接近方向，即使路由器发出近重复最后点。

### `String? _nodeSubtitle(BuildContext context, ServiceTopologyNode node)` <a id="nodesubtitle"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/services/views/service_topology_widgets.dart`（第 257 行）。
- **用途：** 返回拓扑节点卡片在其标签下显示的副标题。
- **输入：** `context`、`node`。
- **返回：** `String?` — 无可显示内容时为 null。
- **副作用：** 无。
- **算法：** 对中继节点，节点带方法时返回本地化方法（`serviceRouteMethodUiLabel`），否则在 `detail` 是原始跳类型名时返回本地化跳类型。其他每个节点返回修剪后的 `detail`，为空时返回 null。
- **用法：** `ServiceTopologyNodeCard.build` 的完整卡片副标题，与车道标签连接。
- **备注：** 图构建器在中继的 `detail` 中存储原始枚举名；在渲染时再本地化，使 [`service_analysis.dart`](../services/service_analysis.md) 保持与语言无关。

### `String _compactTopologyLabel(ServiceTopologyNode node)` <a id="compacttopologylabel"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/services/views/service_topology_widgets.dart`（第 278 行）。
- **用途：** 把拓扑节点标签/详情缩短为适合紧凑端口 chip 的短字符串。
- **输入：** `node`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** 对 `remoteEntry` 节点：经正则从标签提取尾部 `:port`（或 `:start-end`）后缀，找到只返回端口文本；否则 5 字符或更少原样返回标签，更长取其前 5 字符。对任何其他节点 kind：搜索连接 `label` + `detail` 文本中*最后*端口类数字序列，找到返回它；否则回退相同短标签或截断规则。
- **用法：** `ServiceTopologyNodeCard.build` 紧凑（端口 chip）分支中 `_compactTopologyLabel(node)`。
- **备注：** 偏好*最后*数字匹配（非第一）正是让 `"tcp bind-host:8080"` 之类 detail 字符串显示 `8080` 而非绑定地址中较早、无关数字的东西；这只是显示性缩短——节点完整标签/详情经其 `Tooltip` 仍可用。

### `IconData iconForTopologyNode(ServiceTopologyNode node, List<ServiceNode> services, List<Device> devices)` <a id="iconfortopologynode"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/services/views/service_topology_widgets.dart`（第 300 行）。
- **用途：** 基于 kind 和（可解析时）其底层设备/服务解析拓扑节点要显示的图标。
- **输入：** `node`、`services`、`devices`。
- **返回：** `IconData`。
- **副作用：** 无。
- **算法：** `device` kind → 解析设备类别图标（`deviceCategoryIcon`），无法解析时泛型设备图标。`service` kind → 解析服务图标（`iconForService`），无法解析时泛型 `dns` 图标。`endpoint` kind → 固定 ethernet-settings 图标。`remoteEntry` → 公共图标。`domain` → 语言图标。其他任何 → `iconForRouteMethod(node.method)`。
- **用法：** `_ServiceTopologyViewState._buildViewer` 和 [`_showNodeDetails`](service_topology_page.md#shownodedetails) 中 `iconForTopologyNode(node, widget.services, widget.devices)`。
- **备注：** 无。
