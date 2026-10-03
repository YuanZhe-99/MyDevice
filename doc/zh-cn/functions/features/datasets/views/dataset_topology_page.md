# lib/features/datasets/views/dataset_topology_page.dart

全屏资料集拓扑（自 1.8.0 起），从数据集列表的应用栏（[`dataset_list_page.md`](dataset_list_page.md)，`_openTopology`）压入根导航器。设备是大框，其存储槽是其中的中框，每份数据集副本是其槽内的小框；同一数据集的各副本由同步连线相连。布局来自 [`../services/dataset_topology.md`](../services/dataset_topology.md)；画布是共享的 [`TopologyCanvasViewer`](../../../shared/widgets/topology_canvas_viewer.md)——点按选择，拖动或滚轮平移，捏合或 Ctrl + 滚轮缩放。见 [数据集](../../../../features/datasets.md#data-set-topology)。

类型别名 `DataSetTopologyInventory`（`reload` 返回的 `dataSets`、`devices` 记录）不单列。键：框 `dataset-topology-node-<id>`；应用栏 `dataset-topology-filter`、`dataset-topology-links`（同步连线，默认关闭；显示时画家图层的键为 `dataset-topology-links-layer`）、`dataset-topology-show-empty`、`dataset-topology-export`；`dataset-topology-legend-toggle`、`dataset-topology-legend`、`dataset-topology-selection-chip`、`dataset-topology-empty`；详情 `dataset-topology-details-sheet`、`dataset-topology-details-pane`、`dataset-topology-details-empty`、`dataset-topology-details-close`、`dataset-topology-card-<id>`、`dataset-topology-edit-<id>`；筛选 chip `dataset-topology-filter-all`、`dataset-topology-filter-device-<id>`。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`dataSetTopologyColor`](#datasettopologycolor) | 顶层函数 | A | 数据集用于其副本和连线的稳定颜色。 |
| `DataSetTopologyPage`（构造函数） | 构造函数 | B | 创建页面：数据集、设备、编辑器回调、可选的 `reload`。 |
| `createState` | 方法（`DataSetTopologyPage`） | B | 创建页面的状态。 |
| `dispose` | 方法（`_DataSetTopologyPageState`） | B | 释放变换控制器。 |
| [`_layout`](#layoutfor) | 方法（`_DataSetTopologyPageState`） | A | 布局，带缓存。 |
| `_select` | 方法（`_DataSetTopologyPageState`） | B | 选中被点按的框；在手机上打开详情面板。 |
| `_clearSelection` | 方法（`_DataSetTopologyPageState`） | B | 清除选择。 |
| `_edit` | 方法（`_DataSetTopologyPageState`） | B | 等待编辑器，然后 `reload` 并替换数据。 |
| `_showDetailsSheet` | 方法（`_DataSetTopologyPageState`） | B | 在底部面板中显示详情。 |
| `_openFilters` | 方法（`_DataSetTopologyPageState`） | B | 一个即时生效的设备 chip 面板。 |
| `apply` | 嵌套函数（`_openFilters`） | B | 把筛选应用到页面和面板，并重置变换。 |
| `_export` | 方法（`_DataSetTopologyPageState`） | B | 把带高亮的画布捕获为 `mydevice_dataset_topology.png` 并分享。 |
| [`build`](#build) | 方法（组件，`_DataSetTopologyPageState`） | A | 应用栏、视图控件、图例条、画布、详情窗格。 |
| `_buildLegendStrip` | 方法（组件辅助） | B | 图例开关、图例、选择 chip。 |
| `entry` | 嵌套函数（`_buildLegendStrip`） | B | 一个图例条目。 |
| `box` | 嵌套函数（`_buildLegendStrip`） | B | 一个框样例。 |
| `_nodeLabel` | 顶层函数 | B | 设备名、存储标签或"emoji 名称"。 |
| `_DataSetTopologyCanvas`（构造函数） | 构造函数 | B | 由布局、高亮、同步连线开关和点按回调创建画布。 |
| [`build`](#canvasbuild) | 方法（组件，`_DataSetTopologyCanvas`） | A | 设备和存储框、连线画家（打开时），然后是副本框。 |
| `place` | 嵌套函数（`_DataSetTopologyCanvas.build`） | B | 把一个框放到其矩形处。 |
| `_DataSetTopologyBox`（构造函数） | 构造函数 | B | 创建一个框：节点、标签、选中、变暗、点按。 |
| [`build`](#boxbuild) | 方法（组件，`_DataSetTopologyBox`） | A | 带边框的设备/存储框或填充的副本 chip，带语义和变暗。 |
| `_frame` | 方法（组件辅助，`_DataSetTopologyBox`） | B | 只有标题条接收点按的带边框容器。 |
| `_DataSetLinkPainter`（构造函数） | 构造函数 | B | 创建画家。 |
| [`paint`](#paint) | 方法（`_DataSetLinkPainter`） | A | 把每条连线画成两端带圆点的柔和曲线，点亮的最后画。 |
| `shouldRepaint` | 方法（`_DataSetLinkPainter`） | B | 布局、选择或配色方案变化时重绘。 |
| `_DataSetTopologyDetails`（构造函数） | 构造函数 | B | 为一个框创建详情。 |
| [`build`](#detailsbuild) | 方法（组件，`_DataSetTopologyDetails`） | A | 框的标题，然后其上每个数据集一张卡片。 |
| `_buildDataSetCard` | 方法（组件辅助，`_DataSetTopologyDetails`） | B | 以"设备 – 存储"列出数据集的副本，带编辑按钮。 |
| `_isHere` | 方法（`_DataSetTopologyDetails`） | B | 副本是否位于所选框上。 |

行数（30）与 `grep -c 'Purpose:' dataset_topology_page.dart`（30）精确匹配。

## 文档

### `Color dataSetTopologyColor(ColorScheme cs, String dataSetId)` <a id="datasettopologycolor"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/datasets/views/dataset_topology_page.dart`（第 30 行）。
- **用途：** 选取数据集副本和同步连线的颜色。
- **输入：** `cs`、`dataSetId`。
- **返回：** 八种调色板颜色之一（配色方案的 primary 和 tertiary、青绿、靛蓝、橙、粉、绿、紫），以 id 的乘数 31 哈希为索引。
- **副作用：** 无。
- **算法：** 对各代码单元计算 `hash = (hash × 31 + unit) & 0x7fffffff`；`palette[hash % 8]`。
- **用法：** 副本框和 `_DataSetLinkPainter`。
- **备注：** 跨启动和跨设备稳定（不同于 `String.hashCode`）。错误色不在调色板中；它标记只有一份副本的数据集。

### `DataSetTopologyLayout _layout()` <a id="layoutfor"></a>
- **种类：** `_DataSetTopologyPageState` 的方法。
- **来源：** `lib/features/datasets/views/dataset_topology_page.dart`（第 127 行）。
- **用途：** 返回布局。
- **输入：** 无。
- **返回：** `DataSetTopologyLayout`。
- **副作用：** 缓存到 `_cache`。
- **算法：** 当数据列表和筛选集合身份相同且空设备开关相等时复用缓存；否则调用 [`DataSetTopologyLayout.build`](../services/dataset_topology.md#build)。
- **用法：** `build` 中画布的 `Builder`。
- **备注：** 自 1.8.1 起布局以正方形到 16:10 的画布为目标，而不是窗口宽度（此前为 `_layoutFor(double width)`），因此调整窗口大小、选择、同步连线开关、平移或缩放都不会重建它。

### `Widget build(BuildContext context)`（`_DataSetTopologyPageState`） <a id="build"></a>
- **种类：** 方法（组件构建）。
- **来源：** `lib/features/datasets/views/dataset_topology_page.dart`（第 340 行）。
- **用途：** 构建页面。
- **输入：** `context`。
- **返回：** 组件树。
- **副作用：** 填充布局缓存。
- **算法：** 1. 应用栏：带统计所选设备数徽章的设备筛选、同步连线切换（默认关闭，不保存）、"显示没有资料集的设备"切换（会重置变换）、导出（导出中或没有绘制内容时禁用）。2. 由 `TopologyViewControls`、图例条和画布组成的列：布局为空时显示空消息，否则是一个带 `onBackgroundTap: _clearSelection` 的 `TopologyCanvasViewer`，包着一个 `RepaintBoundary`（导出用）和画布。3. 在 `useDetailTwoPane` 窗口上，右侧是宽 `topologyDetailPaneWidth` 的窗格：一条提示，或所选框的详情及关闭按钮。
- **用法：** 框架。
- **备注：** 窗格始终存在，因此选择从不改变画布宽度。

### `Widget build(BuildContext context)`（`_DataSetTopologyCanvas`） <a id="canvasbuild"></a>
- **种类：** 方法（组件构建）。
- **来源：** `lib/features/datasets/views/dataset_topology_page.dart`（第 652 行）。
- **用途：** 构建框和连线。
- **输入：** `context`。
- **返回：** 尺寸为 `layout.size` 的 `Stack`。
- **副作用：** 无。
- **算法：** 先是设备和存储框，再是——仅当 `showLinks` 时——带连线画家的 `IgnorePointer` `CustomPaint`，然后是副本框——因此连线从不遮住副本。高亮不包含某个框时它变暗，它是高亮所选的框时处于选中状态。
- **用法：** 在 [`build`](#build) 的查看器内。
- **备注：** 无。

### `Widget build(BuildContext context)`（`_DataSetTopologyBox`） <a id="boxbuild"></a>
- **种类：** 方法（组件构建）。
- **来源：** `lib/features/datasets/views/dataset_topology_page.dart`（第 732 行）。
- **用途：** 渲染一个框。
- **输入：** `context`。
- **返回：** 组件树。
- **副作用：** 无。
- **算法：** 设备：带 44 px 标题（类别图标、名称）的带边框框。存储：带 34 px 标题（存储图标、标签）、颜色更深的带边框框。副本：以数据集颜色填充的 chip（只有一份副本时用错误色），带标签和 `×n` 徽章。外面包着 `Semantics`（标签、种类或副本数、按钮、选中）、用于变暗的 `Opacity` 和 `Tooltip`。
- **用法：** 画布中的 `place`。
- **备注：** 设备和存储框只在标题上接收点按（`_frame`），因此在框体内的点按会到达那里的副本或背景。

### `void paint(Canvas canvas, Size size)`（`_DataSetLinkPainter`） <a id="paint"></a>
- **种类：** `_DataSetLinkPainter` 的方法。
- **来源：** `lib/features/datasets/views/dataset_topology_page.dart`（第 902 行）。
- **用途：** 绘制同步连线。
- **输入：** `canvas`、`size`。
- **返回：** 无。
- **副作用：** 绘制。
- **算法：** 先画未点亮的连线，点亮的最后画。并排的副本：从相对的两侧画一条水平三次曲线。同一列中的副本：一条从右侧离开、从右侧进入的三次曲线，向外弯出 `28 + 0.1 × Δy`。点亮的线 3.2 px、完全不透明，其余 2.2 px、alpha 0.7，变暗的为 `topologyDimmedEdgeAlpha`；两端各一个 3.5 px 圆点。
- **用法：** 画布的 `CustomPaint`。
- **备注：** 无。

### `Widget build(BuildContext context)`（`_DataSetTopologyDetails`） <a id="detailsbuild"></a>
- **种类：** 方法（组件构建）。
- **来源：** `lib/features/datasets/views/dataset_topology_page.dart`（第 1001 行）。
- **用途：** 渲染所选框的详情。
- **输入：** `context`。
- **返回：** 一个 `ListView`。
- **副作用：** 无。
- **算法：** 一个标题块（设备图标 / 存储图标 / emoji；名称；类别、设备名或副本数；窗格中的关闭按钮）。然后是框上的数据集——副本只显示它自己的数据集——以卡片呈现：emoji、名称、编辑按钮、"副本 · n 份副本"（或以错误色显示*仅一份副本*），以及每份副本一行，位于所选框上的打勾；没有时显示*没有资料集*。
- **用法：** 面板和窗格。
- **备注：** 无。
