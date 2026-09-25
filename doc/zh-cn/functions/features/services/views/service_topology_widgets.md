# lib/features/services/views/service_topology_widgets.dart

全屏拓扑（[`service_topology_page.md`](service_topology_page.md)）用来绘制的部件，于 1.5.6 从 `service_list_page.dart` 拆出：`ServiceTopologyNodeCard`（完整卡片，或紧凑节点的小端口 chip，或设备分组框的标题标签页——选中时边框更粗，选择不包含它时变暗，并按标签、角色和车道向屏幕阅读器播报）、`ServiceTopologyEdgePainter`（先绘制设备分组框，再绘制带箭头、按访问车道着色的已路由边，选择所涉及的边会被强调）、`ServiceTopologyLegend`（说明车道和角色颜色的图例）、`fitTransform`（移动模式的「适应窗口」），以及其背后的图标和颜色辅助。`serviceAccessLaneColor` 从引导式访问路径页移到这里，是边画家、图例和该页预览共用的唯一车道颜色规则。`iconForServiceIcon` 和 `iconForService` 的用途不止拓扑：服务列表（[`service_list_page.md`](service_list_page.md)）、服务编辑器及其模板选择器（[`service_edit_page.md`](service_edit_page.md)）和引导式访问路径页（[`service_access_path_page.md`](service_access_path_page.md)）都用它们绘制服务图标。

**行数说明：** `grep -c 'Purpose:' service_topology_widgets.dart` 返回 **28**，下面每个声明一块（**8 个 Tier A / 20 个 Tier B**；`fitTransform` 的嵌套函数 `offset` 也计入）。公共常量 `topologyDimmedNodeOpacity`（0.35）和 `topologyDimmedEdgeAlpha`（0.18）在源码中有文档，不单列。拆分时只输出英文的 `topologyLaneLabel` 和 `topologyRoleLabel` 已移除：卡片和详情改用 [`../services/service_labels.md`](../services/service_labels.md) 中本地化的 `serviceAccessLaneLabel` 和 `serviceTopologyRoleLabel`；`_nodeFill` / `_nodeBorder` 则变为以角色为键的 `_roleFill` / `_roleBorder`，以便图例使用。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ServiceTopologyNodeCard`（构造函数） | 构造函数 | B | 创建节点卡片组件（节点、图标、点击处理器、选中、变暗、标题）。 |
| [`build`](#cardbuild) | 方法（组件，`ServiceTopologyNodeCard`） | A | 渲染卡片、chip 或标题标签页，带其语义、选中边框和变暗效果。 |
| `_buildHeader` | 方法（组件辅助，`ServiceTopologyNodeCard`） | B | 设备分组框的标题标签页：图标，然后是名称和本地化类别，排在一行中，超长以省略号截断。 |
| `_buildChip` | 方法（组件辅助，`ServiceTopologyNodeCard`） | B | 紧凑端口 chip：图标在短标签之上，完整文本在工具提示中。 |
| `_buildCard` | 方法（组件辅助，`ServiceTopologyNodeCard`） | B | 完整卡片：图标头像、标签、副标题和车道。 |
| `ServiceTopologyEdgePainter`（构造函数） | 构造函数 | B | 创建边画家（图、布局、配色方案、高亮）。 |
| [`paint`](#paint) | 方法（`ServiceTopologyEdgePainter`，`CustomPainter` 覆盖） | A | 先绘制设备分组框，再绘制每条边的路由折线和箭头，并强调选择所涉及的边。 |
| [`_paintContainers`](#paintcontainers) | 方法（`ServiceTopologyEdgePainter`） | A | 填充并描边每个设备分组框；远程设备和 VPS 设备用虚线。 |
| `_dashed` | 静态方法（`ServiceTopologyEdgePainter`） | B | 路径的虚线副本（7 px 线段，5 px 间隙）。 |
| `_paintEdge` | 方法（`ServiceTopologyEdgePainter`） | B | 以给定的 alpha 和宽度描画一条边的路径。 |
| [`_drawPolyline`](#drawpolyline) | 方法（`ServiceTopologyEdgePainter`） | A | 绘制一条边路径加其末端三角箭头。 |
| `_edgeColor` | 方法（`ServiceTopologyEdgePainter`） | B | 边的车道颜色；没有车道时为 outline 颜色。 |
| `shouldRepaint` | 方法（`ServiceTopologyEdgePainter`） | B | 只在图、布局、配色方案或高亮变化时重绘。 |
| `serviceAccessLaneColor` | 顶层函数 | B | 访问车道的颜色（局域网为 tertiary，VPN 为 secondary，公网为 primary）。 |
| [`_nodeSubtitle`](#nodesubtitle) | 顶层函数 | A | 拓扑节点卡片显示的副标题：中继显示本地化方法或跳类型，设备显示本地化类别，否则显示构建器的 detail。 |
| [`_compactTopologyLabel`](#compacttopologylabel) | 顶层函数 | A | 把拓扑节点标签/详情缩短为紧凑 chip 尺寸字符串。 |
| [`iconForTopologyNode`](#iconfortopologynode) | 顶层函数 | A | 按 kind 及其解析设备/服务解析拓扑节点图标。 |
| `iconForRouteMethod` | 顶层函数 | B | 把 `ServiceRouteMethod` 映射到其显示图标（null → 通用路由图标）。 |
| `primaryRouteMethod` | 顶层函数 | B | 返回路由首跳方法（如有）。 |
| `_roleFill` | 顶层函数 | B | 把节点角色映射到其卡片填充色。 |
| `_roleBorder` | 顶层函数 | B | 把节点角色映射到其卡片边框和图标颜色。 |
| `iconForServiceIcon` | 顶层函数 | B | 把服务存储图标键映射到其 `IconData`（未知时为 `Icons.dns`）。 |
| `iconForService` | 顶层函数 | B | 经 `iconForServiceIcon` 解析服务图标。 |
| `ServiceTopologyLegend`（构造函数） | 构造函数 | B | 创建图例。 |
| `build` | 方法（组件，`ServiceTopologyLegend`） | B | 把三种车道的线条样本和六种角色的色块连同本地化标签自动换行排列。 |
| `_entry` | 方法（组件辅助，`ServiceTopologyLegend`） | B | 一个图例条目：色块及其标签。 |
| [`fitTransform`](#fittransform) | 顶层函数 | A | 在缩放限制和平移边距之内，把画布适配进查看器的变换。 |
| `offset` | 嵌套函数（`fitTransform`） | B | 缩放后画布在单个轴上的偏移：能让查看器保持在边界内时居中，否则为 0。 |

## 文档

### `Widget build(BuildContext context)` (`ServiceTopologyNodeCard`) <a id="cardbuild"></a>
- **种类：** `ServiceTopologyNodeCard` 的方法（组件构建）。
- **来源：** `lib/features/services/views/service_topology_widgets.dart`（第 64 行）。
- **用途：** 把节点渲染为完整卡片或端口 chip，带其选中状态。
- **输入：** `context`。
- **返回：** 组件树。
- **副作用：** 无。
- **算法：** 解析本地化车道标签和角色的边框颜色；设置了 `header` 时构建 `_buildHeader`，否则紧凑节点构建 `_buildChip`，其余构建 `_buildCard`（选中时卡片边框宽 3.0、chip 和标题边框宽 2.4，而非 1.4 和 1.2）；`dimmed` 时包进不透明度为 `topologyDimmedNodeOpacity` 的 `Opacity`；再把它包进一个 `Semantics` 容器：其标签由节点标签、角色和车道以逗号连接而成，带 `selected`、`button` 和点击操作，并排除子组件自身的语义。
- **用法：** 页面 `_buildViewer` 中每个已布局节点一个；作为分组框标题的设备节点（`layout.groupRects`）设置 `header`。
- **备注：** 排除子组件使工具提示和文本不会被再读一遍；点击操作由 `Semantics` 自己提供。

### `void paint(Canvas canvas, Size size)` <a id="paint"></a>
- **种类：** `ServiceTopologyEdgePainter` 的方法（`CustomPainter` 覆盖）。
- **来源：** `lib/features/services/views/service_topology_widgets.dart`（第 309 行）。
- **用途：** 把每条图边的路由折线和箭头绘制到画布；有选择时强调选择所涉及的边。
- **输入：** `canvas`；`size`（不直接使用——布局已带绝对坐标）。
- **返回：** 无。
- **副作用：** 绘制到 `canvas`。
- **算法：** 先执行 [`_paintContainers`](#paintcontainers)。然后，没有高亮时，每条边都经 `_paintEdge` 以 0.62 alpha、2.2 宽绘制。有高亮时，先以 `topologyDimmedEdgeAlpha`（0.18）、2.2 宽绘制高亮排除的边，再在其上以完全不透明、3.0 宽绘制点亮的边。`_paintEdge` 在 `layout.edgePaths` 中查找边的点，少于两个点则跳过，并经 [`_drawPolyline`](#drawpolyline) 以 `_edgeColor(edge)` 颜色、圆帽和圆角描画。
- **用法：** 此画家支撑的 `CustomPaint` 需要重绘时由 Flutter 框架调用（由 `shouldRepaint` 门控，它也比较高亮）。
- **备注：** 路由点（带避障的正交路径）来自 [`ServiceTopologyLayout.build`](../services/service_topology_layout.md#build)——此画家只绘制给它的路径；自己不做路由。最后绘制点亮的边，使高亮路由在与淡化的边交叉处仍然可见。隐藏边（`layout.hiddenEdges`，即分组框所隐含的设备到服务边）没有路径，因此永不绘制。

### `void _paintContainers(Canvas canvas)` <a id="paintcontainers"></a>
- **种类：** `ServiceTopologyEdgePainter` 的方法。
- **来源：** `lib/features/services/views/service_topology_widgets.dart`（第 335 行）。
- **用途：** 绘制布局的设备分组框。
- **输入：** `canvas`。
- **返回：** `void`。
- **副作用：** 绘制到 `canvas`。
- **算法：** 对每个 `layout.groupRects` 条目，查找设备节点；绘制一个 18 px 圆角矩形，以其角色的 `_roleFill` 在 alpha 0.22 下填充，再以 `_roleBorder` 在 alpha 0.55、1.2 宽下描边——设备为远程设备（`remoteDevice` 角色）或 VPS（其 `detail` 为 `DeviceCategory.vps.name`）时经 `_dashed` 描边。高亮不包含该设备时，填充降为 0.08，边框降为 0.25。
- **用法：** [`paint`](#paint) 的第一步，使边绘制在分组框之上。
- **备注：** 分组框的标签不在此绘制：设备节点自己的卡片以标题形态绘制，位于分组框的左上角。

### `void _drawPolyline(Canvas canvas, Paint paint, List<Offset> points)` <a id="drawpolyline"></a>
- **种类：** `ServiceTopologyEdgePainter` 的方法。
- **来源：** `lib/features/services/views/service_topology_widgets.dart`（第 417 行）。
- **用途：** 绘制一条边多段路径加其末端三角箭头。
- **输入：** `canvas`、`paint`、`points` — 路由折线（2 个或更多点）。
- **返回：** `void`。
- **副作用：** 绘制到 `canvas`。
- **算法：** 1. 构建移到 `points.first` 然后 `lineTo` 穿过每个后续点的 `Path`；绘制它。2. 从末端向后扫描找距端点超 0.5px 的最后点作方向参考（防退化的近零长末段）。3. 经 `atan2` 计算接近角。4. 从端点以 `angle ± 0.45` 弧度画回两条短线（`V` 形箭头，约 9px 长）。
- **用法：** [`paint`](#paint) 每条边调用一次。
- **备注：** 向后扫描非退化参考点意味着箭头方向反映边实际接近方向，即使路由器发出近重复最后点。

### `String? _nodeSubtitle(BuildContext context, ServiceTopologyNode node)` <a id="nodesubtitle"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/services/views/service_topology_widgets.dart`（第 496 行）。
- **用途：** 返回拓扑节点卡片在其标签下显示的副标题。
- **输入：** `context`、`node`。
- **返回：** `String?` — 无可显示内容时为 null。
- **副作用：** 无。
- **算法：** 对 `detail` 为 `DeviceCategory` 名称的设备节点，返回 `deviceCategoryLabel`。对中继节点，节点带方法时返回本地化方法（`serviceRouteMethodUiLabel`），否则在 `detail` 是原始跳类型名时返回本地化跳类型。其他每个节点返回修剪后的 `detail`，为空时返回 null。
- **用法：** `ServiceTopologyNodeCard._buildCard` 的副标题，与车道标签连接；以及 `_buildHeader` 的类别。
- **备注：** 图构建器在中继和设备的 `detail` 中存储原始枚举名；在渲染时再本地化，使 [`service_analysis.dart`](../services/service_analysis.md) 保持与语言无关。1.5.6 之前设备卡片显示原始类别名（如 `vps`）。

### `String _compactTopologyLabel(ServiceTopologyNode node)` <a id="compacttopologylabel"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/services/views/service_topology_widgets.dart`（第 525 行）。
- **用途：** 把拓扑节点标签/详情缩短为适合紧凑端口 chip 的短字符串。
- **输入：** `node`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** 对 `remoteEntry` 节点：经正则从标签提取尾部 `:port`（或 `:start-end`）后缀，找到只返回端口文本；否则 5 字符或更少原样返回标签，更长取其前 5 字符。对任何其他节点 kind：搜索连接 `label` + `detail` 文本中*最后*端口类数字序列，找到返回它；否则回退相同短标签或截断规则。
- **用法：** 紧凑（端口 chip）分支 `ServiceTopologyNodeCard._buildChip` 中的 `_compactTopologyLabel(node)`。
- **备注：** 偏好*最后*数字匹配（非第一）正是让 `"tcp bind-host:8080"` 之类 detail 字符串显示 `8080` 而非绑定地址中较早、无关数字的东西；这只是显示性缩短——节点完整标签/详情经其 `Tooltip` 仍可用。

### `IconData iconForTopologyNode(ServiceTopologyNode node, List<ServiceNode> services, List<Device> devices)` <a id="iconfortopologynode"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/services/views/service_topology_widgets.dart`（第 547 行）。
- **用途：** 基于 kind 和（可解析时）其底层设备/服务解析拓扑节点要显示的图标。
- **输入：** `node`、`services`、`devices`。
- **返回：** `IconData`。
- **副作用：** 无。
- **算法：** `device` kind → 解析设备类别图标（`deviceCategoryIcon`），无法解析时泛型设备图标。`service` kind → 解析服务图标（`iconForService`），无法解析时泛型 `dns` 图标。`endpoint` kind → 固定 ethernet-settings 图标。`remoteEntry` → 公共图标。`domain` → 语言图标。其他任何 → `iconForRouteMethod(node.method)`。
- **用法：** `_ServiceTopologyViewState._buildViewer` 和节点详情的 [`build`](service_topology_page.md#detailsbuild) 中的 `iconForTopologyNode(node, widget.services, widget.devices)`。
- **备注：** 无。

### `Matrix4 fitTransform(Size canvas, Size viewport, {required double minScale, required double maxScale, double boundaryMargin = 0})` <a id="fittransform"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/services/views/service_topology_widgets.dart`（第 825 行）。
- **用途：** 计算把画布适配进 `InteractiveViewer` 的变换。
- **输入：** `canvas` — 查看器所布局的子组件（画布旋转时为转过后的尺寸）；`viewport` — 查看器的尺寸；`minScale`、`maxScale` — 查看器的缩放限制；`boundaryMargin` — 查看器在子组件周围的边距。
- **返回：** `Matrix4` — 三个轴上一致的缩放加一个平移；画布或视口为空时为单位矩阵。
- **副作用：** 无。
- **算法：** 1. `scale = min(viewport.width / canvas.width, viewport.height / canvas.height)`，钳制到限制范围内。2. 逐轴计算（`offset`）：没有余量 ⇒ 0；有余量 ⇒ 余量的一半不超过 `boundaryMargin × scale` 时居中，否则为 0。3. 带该平移的 `Matrix4.diagonal3Values(scale, scale, scale)`。
- **用法：** 页面视图的 `fitToViewport`，使用移动模式的 0.35 / 2.4 限制和 180 边距。
- **备注：** 缩放也作用在 z 轴上，因为 `InteractiveViewer` 用 `getMaxScaleOnAxis` 读回其缩放；若 z 为 1，只要适配是在缩小，缩放就会被读成 100 %。超出边距时不居中，因为查看器会在下一次平移时把越界偏移弹回 0，居中只会让图跳动。`test/service_topology_page_test.dart` 钉住了较紧的那个轴、两个限制、边距规则和空尺寸的情形。
