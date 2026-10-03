# lib/shared/widgets/topology_canvas_viewer.dart

两个全屏拓扑共同绘制于其上的单一平移缩放画面（自 1.8.0 起）：[`service_topology_page.md`](../../features/services/views/service_topology_page.md) 和 [`dataset_topology_page.md`](../../features/datasets/views/dataset_topology_page.md)。1.8.0 之前服务拓扑有两种模式——接收点按的滚动视图和丢弃点按的 `InteractiveViewer`。点按和拖动从不争夺同一个手势，因此 `TopologyCanvasViewer` 在一种模式中兼顾两者：

- **点按**到达其下的节点，或在空白画布上到达 `onBackgroundTap`；
- **拖动**平移，**捏合**（触摸或触控板）以手指为中心缩放；
- **鼠标滚轮**平移（Shift 把纵向滚轮转为横向），**Ctrl 或 Cmd + 滚轮**以光标为中心缩放，平台的 `PointerScaleEvent` 按其比例缩放。

查看器直接基于 `GestureDetector` 和 `Transform` 构建，而不是基于 `InteractiveViewer`，因为 `InteractiveViewer` 总是在鼠标滚轮上缩放。每个输入都经过 `_apply`，它把缩放钳制到 0.35–2.4，并用 `clampTopologyTranslation` 钳制平移。`TopologyViewControls` 是由缩小、放大、适应窗口和重置图标按钮加一个手势提示工具提示组成的一行，使键盘和屏幕阅读器用户无需手势也能缩放。`fitTransform` 从 `service_topology_widgets.dart` 移到这里，后者仍重新导出它。

公共常量（在源码中有文档，不单列）：`topologyMinScale`（0.35）、`topologyMaxScale`（2.4）、`topologyBoundaryMargin`（180）、`topologyZoomStep`（1.25）；私有的 `_wheelZoomDivisor`（200，与 `InteractiveViewer` 使用的滚轮到缩放比例相同）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`fitTransform`](#fittransform) | 顶层函数 | A | 在缩放限制和平移边距之内，把画布适配进查看器的变换。 |
| `offset` | 嵌套函数（`fitTransform`） | B | 缩放后画布在单个轴上的偏移：能让查看器保持在边界内时居中，否则为 0。 |
| `topologyTransform` | 顶层函数 | B | 一致缩放加平移的矩阵。 |
| [`clampTopologyTranslation`](#clamptopologytranslation) | 顶层函数 | A | 把平移保持在平移限制之内。 |
| `axis` | 嵌套函数（`clampTopologyTranslation`） | B | 钳制单个轴。 |
| `TopologyCanvasViewer`（构造函数） | 构造函数 | B | 创建查看器：画布尺寸、子组件、控制器、背景点按、限制。 |
| `createState` | 方法（`TopologyCanvasViewer`） | B | 创建公开的 `TopologyCanvasViewerState`，使页面能经键调用 `fit`/`zoomBy`/`reset`。 |
| `_controller` | getter（`TopologyCanvasViewerState`） | B | 组件的控制器，或首次使用时创建的私有控制器。 |
| `dispose` | 方法（`TopologyCanvasViewerState`） | B | 只释放私有控制器。 |
| `_scale` | getter（`TopologyCanvasViewerState`） | B | 当前缩放。 |
| `_translation` | getter（`TopologyCanvasViewerState`） | B | 当前平移。 |
| `_apply` | 方法（`TopologyCanvasViewerState`） | B | 写入钳制后的变换；每个输入都经过它。 |
| [`zoomBy`](#zoomby) | 方法（`TopologyCanvasViewerState`） | A | 以视口中的某点为中心缩放，默认为中心。 |
| `fit` | 方法（`TopologyCanvasViewerState`） | B | 为画布和视口设置 `fitTransform`。 |
| `reset` | 方法（`TopologyCanvasViewerState`） | B | 回到单位矩阵：画布左上角处 1:1。 |
| `_onScaleStart` | 方法（`TopologyCanvasViewerState`） | B | 记住手势开始时的变换和焦点。 |
| [`_onScaleUpdate`](#onscaleupdate) | 方法（`TopologyCanvasViewerState`） | A | 用拖动或捏合平移和缩放，保持焦点下的画布点不动。 |
| `_onScaleEnd` | 方法（`TopologyCanvasViewerState`） | B | 忘掉该手势；没有惯性滑动。 |
| [`_onPointerSignal`](#onpointersignal) | 方法（`TopologyCanvasViewerState`） | A | 滚轮平移，Shift + 滚轮横向平移，Ctrl/Cmd + 滚轮缩放。 |
| [`build`](#build) | 方法（组件，`TopologyCanvasViewerState`） | A | `Listener` → `GestureDetector` → `ClipRect` → `OverflowBox` → `Transform` 层叠。 |
| `TopologyViewControls`（构造函数） | 构造函数 | B | 由四个回调创建控件行。 |
| `build` | 方法（组件，`TopologyViewControls`） | B | 缩小、放大、适应窗口、重置和手势提示（键 `topology-zoom-out`、`topology-zoom-in`、`topology-fit`、`topology-reset`、`topology-gesture-hint`）。 |

行数（22）与 `grep -c 'Purpose:' topology_canvas_viewer.dart`（22）精确匹配。

## 文档

### `Matrix4 fitTransform(Size canvas, Size viewport, {required double minScale, required double maxScale, double boundaryMargin = 0})` <a id="fittransform"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/widgets/topology_canvas_viewer.dart`（第 38 行）。
- **用途：** 计算把画布适配进查看器的变换。
- **输入：** `canvas` — 查看器所布局的子组件（画布旋转时为转过后的尺寸）；`viewport` — 查看器的尺寸；`minScale`、`maxScale` — 缩放限制；`boundaryMargin` — 子组件周围的边距。
- **返回：** `Matrix4` — 三个轴上一致的缩放加一个平移；画布或视口为空时为单位矩阵。
- **副作用：** 无。
- **算法：** 1. `scale = min(viewport.width / canvas.width, viewport.height / canvas.height)`，钳制到限制范围内。2. 逐轴计算（`offset`）：没有余量 ⇒ 0；有余量 ⇒ 余量的一半不超过 `boundaryMargin × scale` 时居中，否则为 0。3. 带该平移的 `Matrix4.diagonal3Values(scale, scale, scale)`。
- **用法：** `TopologyCanvasViewerState.fit`。
- **备注：** 1.8.0 从 `service_topology_widgets.dart` 原样移来；该文件重新导出它。缩放也作用在 z 轴上，因为查看器用 `getMaxScaleOnAxis` 读回其缩放。`test/service_topology_page_test.dart` 钉住了较紧的那个轴、两个限制、边距规则和空尺寸的情形。

### `Offset clampTopologyTranslation(double scale, Offset translation, {required Size canvas, required Size viewport, double margin})` <a id="clamptopologytranslation"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/widgets/topology_canvas_viewer.dart`（第 88 行）。
- **用途：** 把变换的平移保持在平移限制之内。
- **输入：** `scale`、`translation` — 候选值；`canvas`、`viewport`；`margin` — 默认为 `topologyBoundaryMargin`。
- **返回：** 钳制后的平移。
- **副作用：** 无。
- **算法：** 逐轴取 `lo = min(view − (child + margin) × scale, 0)` 和 `hi = max(margin × scale, view − child × scale)`；钳制到 `[lo, hi]`。
- **用法：** `_apply`。
- **备注：** 比视口大的画布可以一直平移到其边缘外的边距抵达视口边缘为止，与 `InteractiveViewer` 允许的一样；较小的画布可以放在任何完全可见的位置。画布永远无法被平移出视野。`test/topology_canvas_viewer_test.dart` 钉住了这两种情形。

### `void zoomBy(double factor, {Offset? focal})` <a id="zoomby"></a>
- **种类：** `TopologyCanvasViewerState` 的方法。
- **来源：** `lib/shared/widgets/topology_canvas_viewer.dart`（第 226 行）。
- **用途：** 以视口中的某点为中心缩放。
- **输入：** `factor` — 乘到缩放上；`focal` — 保持不动的视口点，为 null 时是视口中心。
- **返回：** `void`。
- **副作用：** 设置控制器的值。
- **算法：** `scene = (focal − t) / s0`；`s1 = clamp(s0 × factor)`；应用 `(s1, focal − scene × s1)`。
- **用法：** 缩放按钮（经页面的视图键，使用 `topologyZoomStep` 或其倒数）和 Ctrl + 滚轮。
- **备注：** 无。

### `void _onScaleUpdate(ScaleUpdateDetails details)` <a id="onscaleupdate"></a>
- **种类：** `TopologyCanvasViewerState` 的方法。
- **来源：** `lib/shared/widgets/topology_canvas_viewer.dart`（第 273 行）。
- **用途：** 用拖动或捏合平移和缩放。
- **输入：** `details`。
- **返回：** `void`。
- **副作用：** 设置控制器的值。
- **算法：** 从手势开始时保存的变换出发：`s1 = clamp(s0 × details.scale)`；把起始焦点下的场景点放到当前焦点下。
- **用法：** `GestureDetector` 的 `onScaleUpdate`；单指拖动报告的缩放为 1，因此只平移。
- **备注：** 从起点而非增量计算，因此舍入误差从不累积。触控板捏合以平移缩放手势到达，也经过这里。识别器只在超过触摸容差后才认领拖动，因此拖动的前几个像素不会移动画布，短促的点按仍会到达节点。

### `void _onPointerSignal(PointerSignalEvent event)` <a id="onpointersignal"></a>
- **种类：** `TopologyCanvasViewerState` 的方法。
- **来源：** `lib/shared/widgets/topology_canvas_viewer.dart`（第 298 行）。
- **用途：** 处理鼠标滚轮和平台缩放信号。
- **输入：** `event`。
- **返回：** `void`。
- **副作用：** 向 `GestureBinding.instance.pointerSignalResolver` 注册；平移或缩放。
- **算法：** `PointerScaleEvent` 在指针处按 `event.scale` 缩放。按住 Ctrl 或 Cmd 的 `PointerScrollEvent` 在指针处按 `exp(−dy / 200)` 缩放；否则按 `−scrollDelta` 平移，按住 Shift 时把仅纵向的增量转为横向。
- **用法：** 外层 `Listener` 的 `onPointerSignal`。
- **备注：** 经过解析器意味着外层的可滚动组件不会同时滚动。`test/topology_canvas_viewer_test.dart` 钉住了滚轮平移、Shift 以及以光标为中心的 Ctrl 缩放。

### `Widget build(BuildContext context)`（`TopologyCanvasViewerState`） <a id="build"></a>
- **种类：** `TopologyCanvasViewerState` 的方法（组件构建）。
- **来源：** `lib/shared/widgets/topology_canvas_viewer.dart`（第 326 行）。
- **用途：** 构建查看器。
- **输入：** `context`。
- **返回：** 组件树。
- **副作用：** 为 `fit`、`zoomBy` 和钳制记住视口尺寸。
- **算法：** `LayoutBuilder` → `Listener(onPointerSignal)` → 不透明的 `GestureDetector`（`onTap: onBackgroundTap` 和缩放回调）→ `ClipRect` → 左上对齐、无约束的 `OverflowBox` → 在控制器上带 `Transform` 的 `AnimatedBuilder` → 尺寸为 `canvasSize` 的子组件。
- **用法：** 两个拓扑页。
- **备注：** 节点卡片自身的点按识别器在手势竞技场中胜过背景点按，因此只有未命中任何卡片的点按才会到达 `onBackgroundTap`。命中测试跟随 `Transform`，因此节点在绘制的任何位置都可以点按。
