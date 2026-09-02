# lib/shared/utils/adaptive_layout.dart

全应用范围的自适应布局策略：决定布局是否可以分栏的 `splitMinWidth`、`splitMinHeight` 和 `splitMinAspect` 阈值；多列列表用的 `listTileGap`、`listMaxColumns` 和 `listColumnsAuto`；壳导航栏用的 `navRailMinWidth` 和 `navRailWidth`；服务概览用的 `serviceMetricMinWidth`、`serviceMetricMaxColumns` 和 `topologyActionsRowMinWidth`；财务摘要卡用的 `financeSummaryMetricMinWidth`、`financeSummaryGap`、`financeSummaryMinColumns` 和 `financeSummaryMaxColumns`；搜索对话框用的 `dialogInsetHorizontal`、`dialogInsetVertical`、`dialogMaxWidth` 和 `dialogMinBodyHeight`；四个多列列表用的 `deviceTileMinWidth`、`networkTileMinWidth`、`dataSetTileMinWidth` 和 `serviceCardMinWidth`；以及财务总览并排行用的 `financeSummaryPaneMinWidth` 和 `financeChartMinWidth`。其上有十一个纯函数助手。

该模块刻意只依赖 `dart:core`——不含 Flutter import，`canSplitLayout` 正因此接收两个 double 而非 `Size`——所以每个助手都能直接单元测试（`test/adaptive_layout_test.dart`），渲染结果则由 `test/shell_nav_ui_test.dart`、`test/dialog_layout_ui_test.dart`、`test/list_columns_ui_test.dart`、`test/list_columns_more_ui_test.dart` 和 `test/service_columns_ui_test.dart` 在真实设备几何上单独覆盖。

这些数字的散文推导、折叠屏设备表以及与 Google 指南的对照见 [../../../adaptive-layout.md](../../../adaptive-layout.md)。本页记录声明。

使用方：`shell_scaffold.dart` 用 `useNavigationRail`；四个列表页用 `listColumnCount`、`columnCapacity`、`shellContentWidth` 及各自的 tile 最小值，`device_storage.dart` 校验已存偏好时用 `listColumnsAuto` 和 `listMaxColumns`；`adaptive_tile_grid.dart` 用 `listRowCount` 和 `listTileGap`；`service_list_page.dart` 用 `serviceMetricColumns`、`useTopologyActionsRow` 和 `dialogMaxWidth`；`device_finance_overview_page.dart` 用 `financeSummaryColumns`、`canSplitLayout`、`useFinanceSideBySide` 和 `financeSummaryPaneWidth`；`detail_layout.dart`（见 [detail_layout.md](detail_layout.md)）的 `useDetailTwoPane` 是 `canSplitLayout` 的一行委托；`device_search_dialog.dart` 和 `chip_search_dialog.dart` 用 `dialogBodyHeight`、`dialogMaxWidth` 和两个内缩常量。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`canSplitLayout`](#cansplitlayout) | 顶层函数 | A | 报告布局是否可以拆成窗格或多列。 |
| [`useNavigationRail`](#usenavigationrail) | 顶层函数 | A | 报告壳是否应显示导航栏。 |
| [`shellContentWidth`](#shellcontentwidth) | 顶层函数 | A | 返回壳内页面内容实际获得的宽度。 |
| [`columnCapacity`](#columncapacity) | 顶层函数 | A | 返回给定最小宽度时内容框能容纳多少列。 |
| [`listRowCount`](#listrowcount) | 顶层函数 | A | 返回列表在某列数下需要多少行。 |
| [`listColumnCount`](#listcolumncount) | 顶层函数 | A | 返回列表实际应渲染的列数。 |
| [`serviceMetricColumns`](#servicemetriccolumns) | 顶层函数 | A | 返回服务概览每行放多少张指标卡。 |
| [`useTopologyActionsRow`](#usetopologyactionsrow) | 顶层函数 | A | 报告拓扑卡片的标题与动作是否共享一行。 |
| [`financeSummaryColumns`](#financesummarycolumns) | 顶层函数 | A | 返回财务摘要卡把指标排成多少列。 |
| [`dialogBodyHeight`](#dialogbodyheight) | 顶层函数 | A | 返回搜索对话框主体应取的高度。 |
| [`useFinanceSideBySide`](#usefinancesidebyside) | 顶层函数 | A | 报告财务摘要是否放得下在图表旁边。 |
| [`financeSummaryPaneWidth`](#financesummarypanewidth) | 顶层函数 | A | 返回财务摘要指标列的宽度。 |

二十五个常量在源码中连同每个值的理由一起记录，此处不重复成行。

## 文档

### `bool canSplitLayout(double width, double height)` <a id="cansplitlayout"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/adaptive_layout.dart`。
- **用途：** 报告布局是否可以拆成窗格或多列。
- **输入：** `width`、`height` — 视口逻辑像素尺寸，来自 `MediaQuery.sizeOf`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** `width < 600`、`height < 480` 或 `height <= 0` 时为 `false`；否则 `width / height >= 0.82`。
- **用法：** `listColumnCount`，以及四个列表页决定列数控件是否显示的容量；双栏页面（1.5.2 起）也以它门控。
- **备注：** 三个独立条件，因为没有任何一个单独足够。宽高比测试是承重的：Galaxy Z Fold 8 横屏（4:3）分栏、竖屏（3:4）不分，而近方形的 Fold 7 和 Fold 8 Ultra 两个方向都分。高度下限存在是因为仅有宽高比会放行宽而矮的视口——外屏或横持手机。

### `bool useNavigationRail(double screenWidth)` <a id="usenavigationrail"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/adaptive_layout.dart`。
- **用途：** 报告壳是否应显示导航栏。
- **输入：** `screenWidth` — 整个屏幕的逻辑像素宽度。
- **返回：** `bool` — `screenWidth >= 600`。
- **副作用：** 无。
- **用法：** `ShellScaffold.build`。
- **备注：** 刻意仅看宽度，不经由 `canSplitLayout`。导航栏用宽度（只要此值为真就充裕）换高度（并不充裕）；它帮助最大的场景是横持手机，而分栏规则拒绝该场景。

### `double shellContentWidth(double screenWidth)` <a id="shellcontentwidth"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/adaptive_layout.dart`。
- **用途：** 返回壳内页面内容实际获得的宽度。
- **输入：** `screenWidth` — 整个屏幕的逻辑像素宽度。
- **返回：** `double`，永不为负——显示导航栏时为 `screenWidth − 81`，否则为 `screenWidth`。
- **副作用：** 无。
- **用法：** 四个列表页，减去各自内边距后传给 `columnCapacity` 和 `listColumnCount`。
- **备注：** 只有壳内五个页面可以使用。其他每一页都推到壳之上的根导航器，必须测量原始窗口。

### `int columnCapacity(double contentWidth, {required double minItemWidth, double gap = listTileGap, int maxColumns = listMaxColumns})` <a id="columncapacity"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/adaptive_layout.dart`。
- **用途：** 返回给定最小宽度时内容框能容纳多少列。
- **输入：** `contentWidth`；`minItemWidth`；`gap`（默认 12）；`maxColumns`（默认 4）。
- **返回：** `int`，1 到 `maxColumns`。
- **副作用：** 无。
- **算法：** `((contentWidth + gap) / (minItemWidth + gap)).floor().clamp(1, maxColumns)`。非正宽度返回 1；非正最小值返回上限；小于 1 的上限按 1 处理。
- **用法：** `listColumnCount`、`serviceMetricColumns`、`financeSummaryColumns`，以及四个列表页用来决定列数控件是否显示的容量。
- **备注：** 分子加一个间距，让算式只为列*之间*的间距付费，而非每列之后都付一次。

### `int listRowCount(int itemCount, int columns)` <a id="listrowcount"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/adaptive_layout.dart`。
- **用途：** 返回列表在某列数下需要多少行。
- **输入：** `itemCount`、`columns`。
- **返回：** `int` — `ceil(itemCount / columns)`，空列表为 0；小于 1 的列数按 1 处理。
- **副作用：** 无。
- **用法：** `adaptiveTileRows`，以及设备、网络和数据集列表 `ListView.builder` 的 item 数。
- **备注：** 无。

### `int listColumnCount({required double screenWidth, required double screenHeight, required double contentWidth, required double minItemWidth, required int preference})` <a id="listcolumncount"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/adaptive_layout.dart`。
- **用途：** 返回列表实际应渲染的列数。
- **输入：** `screenWidth`、`screenHeight` — 整个屏幕，决定是否允许分栏；`contentWidth` — 列表自身获得的宽度；`minItemWidth` — 一个 tile 最窄可到多少；`preference` — `listColumnsAuto` 或钉住的列数。
- **返回：** `int`，至少 1。
- **副作用：** 无。
- **算法：** `canSplitLayout` 为假时 1；否则偏好为自动时取 `columnCapacity(contentWidth, minItemWidth)`，否则取钳到 1..容量的偏好。
- **用法：** 四个列表页的 `build`，以 `shellContentWidth(screen.width)` 减页面内边距作 `contentWidth`。
- **备注：** 门控读屏幕、容量读列表自身宽度，是刻意的。钉住的偏好钳制而非拒绝，所以窗口缩小——或折叠屏合上——时退回一列而不丢失已存选择。与 MyAnime 的版本不同，最小值是参数，因为 MyDevice 有四种 tile 形状。

### `int serviceMetricColumns(double contentWidth)` <a id="servicemetriccolumns"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/adaptive_layout.dart`。
- **用途：** 返回服务概览每行放多少张指标卡。
- **输入：** `contentWidth` — 概览列表的 `LayoutBuilder` 约束。
- **返回：** `int`，1 到 4。
- **副作用：** 无。
- **算法：** `columnCapacity(contentWidth, minItemWidth: 150, gap: 12, maxColumns: 4)`。
- **用法：** `_ServiceListPageState._buildOverview`。
- **备注：** 与概览在 1.5.0 之前内联携带的 `((w + 12) / 162).floor()` 钳到 1..4 算术完全等价，所以规则搬到这里时没有任何视口的列数改变。

### `bool useTopologyActionsRow(double contentWidth)` <a id="usetopologyactionsrow"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/adaptive_layout.dart`。
- **用途：** 报告拓扑卡片的标题与动作是否共享一行。
- **输入：** `contentWidth` — 卡片内边距内的宽度。
- **返回：** `bool` — `contentWidth >= 680`。
- **副作用：** 无。
- **用法：** `_ServiceListPageState._topologyCard`，取反后作为其 `compact` 标志。
- **备注：** 值就是卡片在 1.5.0 之前内联使用的 680；变化的是卡片拿到的宽度，因为导航栏现在先占去屏幕的 81。

### `int financeSummaryColumns(double contentWidth)` <a id="financesummarycolumns"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/adaptive_layout.dart`。
- **用途：** 返回财务摘要卡把三个指标排成多少列。
- **输入：** `contentWidth` — 卡片内边距内的宽度。
- **返回：** `int`，2 或 3。
- **副作用：** 无。
- **算法：** `columnCapacity(contentWidth, minItemWidth: 160, gap: 16, maxColumns: 3)` 钳到 2..3。
- **用法：** `_DeviceFinanceOverviewPageState._buildSummaryCard`。
- **备注：** 裸 `columnCapacity` 会在 320 dp 外屏上降到一列，卡片从未如此，故设下限。第三列在 512 dp 出现，而 1.5.0 之前的内联规则要求 520。

### `double dialogBodyHeight(double availableHeight, {required double preferred})` <a id="dialogbodyheight"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/adaptive_layout.dart`。
- **用途：** 返回搜索对话框主体应取的高度。
- **输入：** `availableHeight` — 窗口高度减软键盘内缩；`preferred` — 窗口有空间时对话框想要的高度。
- **返回：** `double`，`dialogMinBodyHeight`（240）到 `preferred`。
- **副作用：** 无。
- **算法：** `(availableHeight − 2 × 40).clamp(240, preferred)`；`preferred` 低于 240 时返回 240。
- **用法：** `_DeviceSearchDialogState.build`（首选 560）和 `_ChipSearchDialogState.build`（首选 480）。
- **备注：** 1.5.0 之前两个对话框固定为首选高度，在横持手机或横持折叠态外屏上溢出。

### `bool useFinanceSideBySide(double contentWidth)` <a id="usefinancesidebyside"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/adaptive_layout.dart`。
- **用途：** 报告财务摘要是否放得下在资产分布图旁边。
- **输入：** `contentWidth` — 财务页 body 宽度减其 32 dp 内边距；即原始窗口，因为页面推到壳之上。
- **返回：** `bool` — `contentWidth >= 240 + 340 + 12`。
- **副作用：** 无。
- **用法：** `_DeviceFinanceOverviewPageState.build`，与 `canSplitLayout` 和非空分布一起。
- **备注：** 叠在分栏规则之上的宽度下限，不是替代它。每台展开的折叠屏都超过它，因为 MyDevice 的两块比 MyAnime 的小；下限在 600 dp 分栏最小值处仍然生效。

### `double financeSummaryPaneWidth(double contentWidth)` <a id="financesummarypanewidth"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/adaptive_layout.dart`。
- **用途：** 返回财务摘要指标列的宽度。
- **输入：** `contentWidth` — 两块共享的宽度。
- **返回：** `double` — `(contentWidth × 0.34).clamp(240, 360)`。
- **副作用：** 无。
- **用法：** 并排行中摘要卡外的 `SizedBox`。
- **备注：** 没有右侧上限：门控之上窗格以 0.34 增长而图表以 0.66 增长，所以图表 340 dp 下限在边界处满足、其上超出——在 `test/detail_layout_test.dart` 中跨整个范围断言。
