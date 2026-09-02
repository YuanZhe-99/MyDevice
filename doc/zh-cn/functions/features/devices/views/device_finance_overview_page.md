# lib/features/devices/views/device_finance_overview_page.dart

从设备列表财务总览卡片打开的财务总览页（见 [设备 — 财务总览页](../../../../features/devices.md#financial-overview-page)）。它用 `fl_chart` 渲染三个小节：摘要指标卡片、按 `DeviceCategory` 的资产分布饼图和组合历史/未来每日成本趋势折线图。本文件自己拥有所有财务聚合数学（除 `hasFinancialData`/`totalCost`/`purchaseDate`/`retiredDate`/`isSold` 外不回调 `Device` 的逐设备财务 getter——趋势图使用的日期索引"截至任意日的成本"计算本地实现于 `_averageDailyCostAt`/`_totalDailyCostAt`）。本页摘要指标复用的底层 `Device.totalCost()`/`averageDailyCost()` 模型 getter 见 [设备 — 生命周期与财务跟踪](../../../../features/devices.md#lifecycle-and-finance-tracking)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `DeviceFinanceOverviewPage`（构造函数） | 构造函数 | B | 为页面组件存储设备列表和默认货币。 |
| `createState` | 方法（`DeviceFinanceOverviewPage`） | B | 创建页面可变状态对象。 |
| `build` | 方法（组件） | B | 构建脚手架；在双重门控下（屏幕上的 `canSplitLayout`、body 宽度减 32 上的 `useFinanceSideBySide`、以及非空的分布）摘要卡放在 `financeSummaryPaneWidth` 宽的窗格里与分布卡并排，否则三张卡堆叠；趋势卡始终全宽在下。 |
| `_buildSummaryCard` | 方法（组件辅助） | B | 按 `financeSummaryColumns`（`adaptive_layout.dart`）为卡片宽度返回的列数，或按 `fixedColumns`（并排窗格中为 1），渲染总成本 / 每日成本 / 设备数指标行。 |
| `_buildAssetDistribution` | 方法（组件辅助） | B | 渲染资产分布饼图和逐类别图例行。 |
| `_buildTrendCard` | 方法（组件辅助） | B | 渲染趋势图标题、范围选择器和折线图面板。 |
| [`_buildLineChartPanel`](#_buildlinechartpanel) | 方法（`_DeviceFinanceOverviewPageState`） | A | 计算对数刻度轴边界/间隔并构建 `fl_chart` `LineChart`。 |
| `_metric` | 方法（组件辅助） | B | 渲染一个标签/值指标列。 |
| `_distributionRow` | 方法（组件辅助） | B | 渲染一个类别的图例行，带色点、进度条和计数。 |
| `_legendDot` | 方法（组件辅助） | B | 渲染一个图表系列图例条目（实线或虚线色块 + 标签）。 |
| [`_buildTrendData`](#_buildtrenddata) | 方法（`_DeviceFinanceOverviewPageState`） | A | 把每日成本函数跨趋势刻度采样进历史/未来点列表。 |
| [`_assetBuckets`](#_assetbuckets) | 方法（`_DeviceFinanceOverviewPageState`） | A | 把每个设备总成本聚合进逐类别桶，降序排序。 |
| [`_historyStart`](#_historystart) | 方法（`_DeviceFinanceOverviewPageState`） | A | 计算所选范围趋势图历史开始日期。 |
| [`_historyDuration`](#_historyduration) | 方法（`_DeviceFinanceOverviewPageState`） | A | 从历史窗口长度计算前向投影窗口长度。 |
| [`_earliestPurchaseDate`](#_earliestpurchasedate) | 方法（`_DeviceFinanceOverviewPageState`） | A | 跨所有设备找最早 `purchaseDate`。 |
| [`_totalDailyCostAt`](#_totaldailycostat) | 方法（`_DeviceFinanceOverviewPageState`） | A | 截至给定日期求和每个设备的平均每日成本。 |
| [`_averageDailyCostAt`](#_averagedailycostat) | 方法（`_DeviceFinanceOverviewPageState`） | A | 计算一个设备截至任意日期（过去或未来）的平均每日成本。 |
| [`_totalFinancialCost`](#_totalfinancialcost) | 方法（`_DeviceFinanceOverviewPageState`） | A | 跨所有设备求和 `totalCost()`。 |
| [`_totalDailyCost`](#_totaldailycost) | 方法（`_DeviceFinanceOverviewPageState`） | A | 跨所有设备求和当前 `averageDailyCost()`。 |
| [`_chartBounds`](#_chartbounds) | 方法（`_DeviceFinanceOverviewPageState`） | A | 为图表显示按 10%（或回退）填充原始 min/max Y 范围。 |
| [`_logTransform`](#_logtransform) | 方法（`_DeviceFinanceOverviewPageState`） | A | 应用图表 Y 轴使用的带符号 `log10(\|x\|+1)` 变换。 |
| [`_logInverse`](#_loginverse) | 方法（`_DeviceFinanceOverviewPageState`） | A | 把 `_logTransform` 反转回真实成本值。 |
| `_dateOnly` | 方法（`_DeviceFinanceOverviewPageState`） | B | 从 `DateTime` 剥离日内时间分量。 |
| [`_moneyText`](#_moneytext-finance) | 方法（`_DeviceFinanceOverviewPageState`） | A | 用页面默认货币符号格式化金额。 |
| [`_formatAxisValue`](#_formataxisvalue) | 方法（`_DeviceFinanceOverviewPageState`） | A | 大数量级用 `k`/`m` 后缀格式化 Y 轴刻度值。 |
| `_categoryLabel` | 方法（`_DeviceFinanceOverviewPageState`） | B | 把 `DeviceCategory` 映射到其本地化标签。 |
| `_TrendScale`（构造函数） | 构造函数 | B | 存储预计算日期列表、标签间隔和日期格式化器。 |
| [`_TrendScale.fromRange`](#trendscale-fromrange) | 工厂构造函数 | A | 为历史/今天/未来结束范围构建 `_TrendScale`（日期样本 + 标签间隔）。 |
| `pointCount` | getter（`_TrendScale`） | B | 返回采样日期数（图表 X 轴点数）。 |
| `xLabel` | 方法（`_TrendScale`） | B | 为样本索引格式化短（`M/d`）轴标签。 |
| `tooltipLabel` | 方法（`_TrendScale`） | B | 为样本索引格式化完整（`yyyy-MM-dd`）工具提示标签。 |
| `_TrendData`（构造函数） | 构造函数 | B | 存储计算历史/未来点列表和 Y 边界。 |
| `_ChartSeries`（构造函数） | 构造函数 | B | 存储一个图表系列的标签、颜色、点和虚线标志。 |
| `_AssetBucket`（构造函数） | 构造函数 | B | 存储一个类别的标签、金额、计数和图表颜色。 |

行数说明：对此文件 `grep -c 'Purpose:'` 返回 33；上面表格有 34 个真实声明行（游离 `_chartColors` 行是表格格式伪影，非单独行——见下面）。唯一未文档化声明是 `_chartBounds`（`lib/features/devices/views/device_finance_overview_page.dart`，第 715 行）：它完全无 `///` 文档注释（连普通都没有），不像文件每个其他方法，因此不匹配 `Purpose:` grep。它仍是真实、承载负载声明（见下面 [`_chartBounds`](#_chartbounds)）并按"每个声明得一行"规则包含于此。`_chartColors`（`static const List<Color>`，第 806 行）是数据常量，非函数/方法/构造函数，且——与本批文件其他私有枚举和常量映射处理方式一致——不计数为自己的声明行。

## 文档

### `Widget _buildLineChartPanel({required BuildContext context, required AppLocalizations l10n, required _TrendScale scale, required List<_ChartSeries> series, required double minY, required double maxY})` <a id="_buildlinechartpanel"></a>
- **种类：** `_DeviceFinanceOverviewPageState` 的方法
- **来源：** `lib/features/devices/views/device_finance_overview_page.dart`（第 290 行）
- **用途：** 计算对数刻度 Y 轴边界/网格间隔并渲染每日成本趋势（历史 + 未来系列）的 `fl_chart` `LineChart`，含轴刻度和工具提示格式化。
- **输入：** `scale` — 描述采样日期/标签的 `_TrendScale`；`series` — 一个或两个 `_ChartSeries`（历史和虚线未来投影）；`minY`/`maxY` — 要显示的原始（未变换）成本范围。
- **返回：** `Widget` — 图例行加 260px 高 `LineChart`。
- **副作用：** 除构建组件树外无（无状态修改）。
- **算法：**
  1. 调用 [`_chartBounds`](#_chartbounds) 填充 `minY`/`maxY`，然后对两个边界应用 [`_logTransform`](#_logtransform) 得图表变换（对数）空间中的实际 `minY`/`maxY`。
  2. 计算 `horizontalInterval` 为变换 Y 范围的四分之一（`yRange / 4`，范围坍缩为零时 `1.0`）——这成为网格线间距和左轴标签间隔两者。
  3. 构建 `minX: 0`、`maxX: scale.pointCount - 1` 的 `LineChartData`。
  4. 底部轴刻度标签：对每个候选 `value` 舍入到最近索引；舍入误差超 `0.01` 或索引落在 `[0, pointCount)` 外时渲染无（`SizedBox.shrink()`）；否则渲染 `scale.xLabel(idx)`。用 `scale.labelInterval` 间隔候选刻度。
  5. 左轴刻度标签：抑制恰在变换 min/max 的标签（避免图表边缘拥挤），否则渲染 `_formatAxisValue(_logInverse(value))`——即标签总是以真实成本单位显示，绝不在对数空间。
  6. 为每个非空系列构建一个 `LineChartBarData`，把每个 `FlSpot` 的 `y` 经 `_logTransform` 重新映射（`x`——样本索引——不动）。系列超过 2 个点才曲线化线；`series.dashed` 为 true（未来投影段）时应用 `dashArray: [7, 5]` 并禁用虚线系列面积填充。
  7. 工具提示项把触摸点索引钳制进 `[0, pointCount - 1]`，然后组合 `scale.tooltipLabel(idx)` 与系列标签和 `_moneyText(_logInverse(spot.y))`（把对数空间 `y` 值转回真实金额供显示）。
- **用法：**
  ```dart
  _buildLineChartPanel(
    context: context,
    l10n: l10n,
    scale: scale,
    series: [
      _ChartSeries(label: l10n.financialHistory, color: theme.colorScheme.primary, spots: trendData.historySpots),
      _ChartSeries(label: l10n.financialFutureTrend, color: theme.colorScheme.primary, spots: trendData.futureSpots, dashed: true),
    ],
    minY: trendData.minY,
    maxY: trendData.maxY,
  ),
  ```
  （来自 `_buildTrendCard`，`lib/features/devices/views/device_finance_overview_page.dart`，第 259–278 行）
- **备注：** 两个系列共享相同颜色（`theme.colorScheme.primary`）——历史 vs 未来只由虚线模式和面积填充区分，非颜色。轴为何用对数变换（让小循环每日成本和大一次性购买尖峰在同一图表可读）见 [设备 — 财务总览页](../../../../features/devices.md#financial-overview-page)。

### `_TrendData _buildTrendData(_TrendScale scale, DateTime today)` <a id="_buildtrenddata"></a>
- **种类：** `_DeviceFinanceOverviewPageState` 的方法
- **来源：** `lib/features/devices/views/device_finance_overview_page.dart`（第 544 行）
- **用途：** 在趋势刻度每个日期采样车队总每日成本，把点拆分为"历史"系列（到今天含今天）和"未来"系列（今天起）。
- **输入：** `scale` — `_TrendScale`（采样日期）；`today` — 历史和投影间边界的仅日期"现在"。
- **返回：** 含 `historySpots`、`futureSpots` 和跨所有采样值观察到的原始 `minY`/`maxY` 的 `_TrendData`。
- **副作用：** 无。
- **算法：**
  1. 对 `scale.dates` 每个索引 `i`，计算 `value = _totalDailyCostAt(scale.dates[i])` 并构建 `FlSpot(i.toDouble(), value)`。
  2. 日期不晚于 `today` 时把点加入 `historySpots`，不早于 `today` 时加入 `futureSpots`——因此 `today` 本身包含在**两个**系列中，这正是视觉上在"现在"点连接实线和虚线段的 东西。
  3. 从 `0.0` 开始的 `fold` 跟踪 `minY`/`maxY`（使范围即使所有成本都正或负也总是含零）。
- **用法：** `_buildTrendCard` 中的 `final trendData = _buildTrendData(scale, today);`（`lib/features/devices/views/device_finance_overview_page.dart`，第 203 行）。
- **备注：** 因为 `historySpots`/`futureSpots` 共享边界点，`_buildLineChartPanel` 从它们构建的两个 `LineChartBarData` 条目渲染为一条视觉连续、恰在 `today` 从实线切换虚线的线。

### `List<_AssetBucket> _assetBuckets(AppLocalizations l10n)` <a id="_assetbuckets"></a>
- **种类：** `_DeviceFinanceOverviewPageState` 的方法
- **来源：** `lib/features/devices/views/device_finance_overview_page.dart`（第 574 行）
- **用途：** 按 `DeviceCategory` 分组每个带正财务数据的设备，为资产分布饼图求和总成本并逐类别计数设备。
- **输入：** `l10n` — 只用于本地化每个类别标签。
- **返回：** `List<_AssetBucket>` — 每个至少有一个 `totalCost() > 0` 设备的类别一个桶，按 `amount` 降序排序。
- **副作用：** 无。
- **算法：**
  1. 跳过 `hasFinancialData` 为 false、或 `math.max(0.0, device.totalCost())` 为 `<= 0` 的设备（净亏损设备，如售价低于累积成本，贡献 `0` 而非负切片——负金额会破坏饼图比例）。
  2. 经带 `ifAbsent` 的 `Map.update` 累积 `totals[category] += amount` 和 `counts[category] += 1`。
  3. 为每个类别条目构建一个 `_AssetBucket`，按 `totals.entries` 中类别首次遇到顺序循环 `_chartColors` 分配颜色（`_chartColors[buckets.length % _chartColors.length]`）——非固定逐类别颜色。
  4. 按 `amount` 降序排序结果列表（最大类别在前）。
- **用法：** `_buildAssetDistribution` 中的 `final buckets = _assetBuckets(l10n);`（`lib/features/devices/views/device_finance_overview_page.dart`，第 128 行）。
- **备注：** 因为颜色分配依赖 `totals` 映射（从 `widget.devices` 顺序构建）的迭代/插入顺序而非固定类别 → 颜色表，同一类别跨不同设备列表可被分配不同饼图颜色。

### `DateTime _historyStart(DateTime today)` <a id="_historystart"></a>
- **种类：** `_DeviceFinanceOverviewPageState` 的方法
- **来源：** `lib/features/devices/views/device_finance_overview_page.dart`（第 609 行）
- **用途：** 为当前所选 `_FinanceRange` 计算趋势图历史窗口开始日期。
- **输入：** `today` — 仅日期当前日期。
- **返回：** `DateTime` — `today` 减 1 年、减 3 年，或（"全部"）最早设备购买日期。
- **副作用：** 无（读取 `_range` 状态）。
- **算法：** 对 `_range` 做 `switch`：`_FinanceRange.year` → 年份减 1 的 `today`；`_FinanceRange.threeYears` → 年份减 3；`_FinanceRange.all` → [`_earliestPurchaseDate`](#_earliestpurchasedate)，无设备有购买日期时回退 1 年窗口。
- **用法：** `_buildTrendCard` 中的 `final historyStart = _historyStart(today);`（`lib/features/devices/views/device_finance_overview_page.dart`，第 200 行）。
- **备注：** 无。

### `Duration _historyDuration(DateTime today, DateTime historyStart)` <a id="_historyduration"></a>
- **种类：** `_DeviceFinanceOverviewPageState` 的方法
- **来源：** `lib/features/devices/views/device_finance_overview_page.dart`（第 628 行）
- **用途：** 从历史窗口长度派生前向"未来投影"窗口长度，使投影段镜像图表已回看的距离。
- **输入：** `today`、`historyStart`。
- **返回：** `Duration` — `today` 与 `historyStart` 间的绝对天数，下限 30 天。
- **副作用：** 无。
- **算法：** `days = |today.difference(historyStart).inDays|`；返回 `Duration(days: math.max(days, 30))`——即使历史窗口本身很短也保证至少 30 天投影窗口。
- **用法：**
  ```dart
  final futureEnd = today.add(_historyDuration(today, historyStart));
  ```
  （来自 `_buildTrendCard`，`lib/features/devices/views/device_finance_overview_page.dart`，第 201 行）
- **备注：** 无。

### `DateTime? _earliestPurchaseDate()` <a id="_earliestpurchasedate"></a>
- **种类：** `_DeviceFinanceOverviewPageState` 的方法
- **来源：** `lib/features/devices/views/device_finance_overview_page.dart`（第 638 行）
- **用途：** 跨列表中所有设备找最早 `purchaseDate`，供"全部时间"趋势范围。
- **输入：** 无（读取 `widget.devices`）。
- **返回：** `DateTime?` — 最早仅日期购买日期，无设备有 `purchaseDate` 时 `null`。
- **副作用：** 无。
- **算法：** 迭代所有设备，跳过 `purchaseDate` 为 null 的；经 `_dateOnly` 规范化每个日期并保留至今所见最小。
- **用法：** 从 [`_historyStart`](#_historystart) 的 `_FinanceRange.all` 分支调用。
- **备注：** 无。

### `double _totalDailyCostAt(DateTime date)` <a id="_totaldailycostat"></a>
- **种类：** `_DeviceFinanceOverviewPageState` 的方法
- **来源：** `lib/features/devices/views/device_finance_overview_page.dart`（第 656 行）
- **用途：** 截至任意日期（用于采样趋势图上每个点，过去或未来）求和车队级平均每日成本。
- **输入：** `date`。
- **返回：** `double` — 跨 `widget.devices` 的 [`_averageDailyCostAt`](#_averagedailycostat) 之和（逐设备 `null` 结果当作 `0`）。
- **副作用：** 无。
- **算法：** `widget.devices.fold(0.0, (sum, device) => sum + (_averageDailyCostAt(device, date) ?? 0))`。
- **用法：** [`_buildTrendData`](#_buildtrenddata) 循环内每个采样点调用一次。
- **备注：** 无。

### `double? _averageDailyCostAt(Device device, DateTime date)` <a id="_averagedailycostat"></a>
- **种类：** `_DeviceFinanceOverviewPageState` 的方法
- **来源：** `lib/features/devices/views/device_finance_overview_page.dart`（第 668 行）
- **用途：** 计算一个设备在任意日期将已（或将要）达到的平均每日成本——让趋势图能在任何过去或未来点绘制成本的核心原语，不只"现在"（不同于总是相对当前的 `Device.averageDailyCost()`）。
- **输入：** `device`；`date` — 要评估的日期（可相对今天在过去或未来）。
- **返回：** `double?` — 设备无财务数据、无 `purchaseDate` 或 `date` 早于购买日期时 `null`；否则截至 `date` 的平均每日成本。
- **副作用：** 无。
- **算法：**
  1. `!device.hasFinancialData` 或 `purchaseDate` 为 null、或 `date` 早于（仅日期）购买日期时返回 `null`。
  2. `serviceEnd` 以 `date` 开始，但设备当前不在用且有早于 `date` 的 `retiredDate` 时 `serviceEnd` 钳制为 `retiredDate`——因此即使投影未来，成本也停止在退役后累积"服务天数"。
  3. `serviceEnd` 最终早于 `purchaseDate`（退化 case）时返回 `null`。
  4. `days = max(1, serviceEnd.difference(purchaseDate).inDays + 1)`——包含天数。
  5. `purchase` = `purchasePrice?.convertedAmount ?? 0`（一次性成本，无论 `date` 相同）。
  6. `recurring` = 每个循环成本 `dailyConvertedAmount * days` 之和——即循环成本随 `date` 时已过天数缩放。
  7. `sold` = `soldPrice?.convertedAmount` **只在**设备 `isSold` **且**无 `retiredDate` 或 `retiredDate` 不晚于 `date` 时——即出售收益只从退役/出售日其减少成本，不在此之前。否则 `0.0`。
  8. 返回 `(purchase + recurring - sold) / days`。
- **用法：** [`_totalDailyCostAt`](#_totaldailycostat) 每个设备调用一次。
- **备注：** 这重复（而非复用）`Device.totalCost()`/`averageDailyCost()` 的算术形态（见 [设备 — 生命周期与财务跟踪](../../../../features/devices.md#lifecycle-and-finance-tracking)），因为那些模型 getter 只可"截至现在"评估，而本页需要在每个历史和投影采样日期评估相同成本模型。

### `double _totalFinancialCost()` <a id="_totalfinancialcost"></a>
- **种类：** `_DeviceFinanceOverviewPageState` 的方法
- **来源：** `lib/features/devices/views/device_finance_overview_page.dart`（第 702 行）
- **用途：** 跨每个设备求和 `Device.totalCost()`（截至现在），供摘要卡片"总成本"指标。
- **输入：** 无（读取 `widget.devices`）。
- **返回：** `double`。
- **副作用：** 无。
- **算法：** `widget.devices.fold(0, (sum, device) => sum + device.totalCost())`。
- **用法：** `_buildSummaryCard` 中的 `_moneyText(_totalFinancialCost())`（`lib/features/devices/views/device_finance_overview_page.dart`，第 94 行）。
- **备注：** 与 `_totalDailyCostAt` 不同，这直接复用 `Device.totalCost()`（在"现在"、模型默认评估）而非重新实现算术。

### `double _totalDailyCost()` <a id="_totaldailycost"></a>
- **种类：** `_DeviceFinanceOverviewPageState` 的方法
- **来源：** `lib/features/devices/views/device_finance_overview_page.dart`（第 710 行）
- **用途：** 跨每个设备求和 `Device.averageDailyCost()`（截至现在），供摘要卡片"每日成本"指标。
- **输入：** 无。
- **返回：** `double`。
- **副作用：** 无。
- **算法：** `widget.devices.fold(0, (sum, device) => sum + (device.averageDailyCost() ?? 0))`。
- **用法：** `_buildSummaryCard` 中的 `_moneyText(_totalDailyCost())`（`lib/features/devices/views/device_finance_overview_page.dart`，第 102 行）。
- **备注：** 无。

### `({double minY, double maxY}) _chartBounds(double minY, double maxY)` <a id="_chartbounds"></a>
- **种类：** `_DeviceFinanceOverviewPageState` 的方法
- **来源：** `lib/features/devices/views/device_finance_overview_page.dart`（第 715 行）
- **用途：** 用余量填充原始 min/max 成本范围，使趋势线不碰图表顶/底边，并确保零总是包含在可见范围内。
- **输入：** `minY`、`maxY` — 原始（未变换）观察成本范围。
- **返回：** 记录 `(minY: double, maxY: double)` — 填充边界。
- **副作用：** 无。
- **算法：**
  1. `minY == maxY`（平线，如只有一个数据点或全相同值）时：填充为 `|minY|` 的 `10%`，那个填充为 `0`（即值本身 `0`）时 `1.0`。返回 `(min(0, minY - padding), maxY + padding)`。
  2. 否则：填充为范围 `|maxY - minY|` 的 `10%`。返回相同 `(min(0, minY - padding), maxY + padding)` 形态。
  3. 两个分支中 `min(0, ...)` 保证下界绝不高于零——图表总是显示零线。
- **用法：** [`_buildLineChartPanel`](#_buildlinechartpanel) 中的 `final bounds = _chartBounds(minY, maxY);`，紧接边界被 `_logTransform` 运行得到图表实际轴范围前。
- **备注：** 此声明源码完全无 `///` 文档注释（见上面行数说明）——源码未文档化，但对图表 Y 轴填充承载负载。

### `double _logTransform(double value)` <a id="_logtransform"></a>
- **种类：** `_DeviceFinanceOverviewPageState` 的方法
- **来源：** `lib/features/devices/views/device_finance_overview_page.dart`（第 731 行）
- **用途：** 应用每日成本趋势图 Y 轴使用的带符号对数变换，使小循环成本和一次性购买尖峰在同一刻度都可读。
- **输入：** `value` — 真实成本金额（可为负，如净亏损日）。
- **返回：** `double` — `value == 0` 时 `0`；否则 `sign(value) * log10(|value| + 1)`。
- **副作用：** 无。
- **算法：** `value == 0` 短路为 `0`（避免零附近 `log(1)/ln10` 舍入噪声，虽然那也求值为 `0`）。否则计算 `sign * math.log(value.abs() + 1) / math.ln10`，即 `log10(|value|+1)` 重新应用原始符号。这是 [设备 — 财务总览页](../../../../features/devices.md#financial-overview-page) 文档化的相同变换。
- **用法：** 应用于 `minY`/`maxY` 图表边界和 [`_buildLineChartPanel`](#_buildlinechartpanel) 内每个绘制点 `y` 值。
- **备注：** 对数内 `+1` 让变换对零附近小值定义（且经 `0` 连续），不像普通 `log10(|value|)` 会在 `value` 接近 `0` 时发散到 `-∞`。

### `double _logInverse(double value)` <a id="_loginverse"></a>
- **种类：** `_DeviceFinanceOverviewPageState` 的方法
- **来源：** `lib/features/devices/views/device_finance_overview_page.dart`（第 742 行）
- **用途：** 反转 `_logTransform`，把对数空间轴值转回真实成本金额供轴刻度标签和工具提示。
- **输入：** `value` — 已在对数变换空间的值。
- **返回：** `double` — `value == 0` 时 `0`；否则 `sign(value) * (10^|value| - 1)`。
- **副作用：** 无。
- **算法：** `sign * (math.pow(10, value.abs()) - 1)`，`log10(|x|+1)` 的代数逆。
- **用法：**
  ```dart
  _formatAxisValue(_logInverse(value))
  ...
  '${s.label}: ${_moneyText(_logInverse(spot.y))}',
  ```
  （都在 [`_buildLineChartPanel`](#_buildlinechartpanel) 中）
- **备注：** 无。

### `String _moneyText(double amount)` <a id="_moneytext-finance"></a>
- **种类：** `_DeviceFinanceOverviewPageState` 的方法
- **来源：** `lib/features/devices/views/device_finance_overview_page.dart`（第 761 行）
- **用途：** 用页面配置的默认货币符号格式化普通金额。
- **输入：** `amount` — 已以 `widget.defaultCurrency` 表达。
- **返回：** `String` — `"{symbol}{amount.toStringAsFixed(2)}"`。
- **副作用：** 无（经 `DeviceExchangeRateService.currencySymbol` 查找符号）。
- **算法：** 直接符号查找 + 2 位小数格式化；不执行转换（不同于 `device_detail_page.dart` 处理带两货币 `MoneyValue` 的 `_moneyText`——本页 `_moneyText` 只格式化已聚合进单一货币的金额）。
- **用法：** `_moneyText(_totalFinancialCost())`、`_moneyText(bucket.amount)`、`_moneyText(_logInverse(spot.y))` 等，贯穿本文件。
- **备注：** 无。

### `String _formatAxisValue(double value)` <a id="_formataxisvalue"></a>
- **种类：** `_DeviceFinanceOverviewPageState` 的方法
- **来源：** `lib/features/devices/views/device_finance_overview_page.dart`（第 773 行）
- **用途：** 紧凑格式化真实（已对数反转）Y 轴刻度值，大数量级用 `k`/`m` 后缀使标签在图表默认宽度保持短。
- **输入：** `value`。
- **返回：** `String` — `|value| >= 1_000_000` 时 `"{sign}{abs/1e6:.1f}m"`、`|value| >= 1_000` 时 `"{sign}{abs/1e3:.1f}k"`、否则普通整数值。
- **副作用：** 无。
- **算法：** 如上按数量级三分支；符号单独提取且只在 `k`/`m` 分支前置（普通分支依赖 `value.toStringAsFixed(0)` 自己的符号处理）。
- **用法：** 图表左轴刻度标签的 `_formatAxisValue(_logInverse(value))`，在 [`_buildLineChartPanel`](#_buildlinechartpanel) 中。
- **备注：** 无。

### `factory _TrendScale.fromRange(DateTime historyStart, DateTime today, DateTime futureEnd)` <a id="trendscale-fromrange"></a>
- **种类：** `_TrendScale` 的工厂构造函数
- **来源：** `lib/features/devices/views/device_finance_overview_page.dart`（第 846 行）
- **用途：** 构建趋势图要采样的日期列表（其 X 轴），基于总跨度选择采样步长使非常长范围不产生数千点，并计算 X 轴标签应相隔多少点绘制。
- **输入：** `historyStart`、`today`、`futureEnd` — 界定采样范围的三个关键日期。
- **返回：** 带去重、排序 `dates` 列表、`labelInterval` 和固定 `M/d`（轴）/ `yyyy-MM-dd`（工具提示）`DateFormat` 的新 `_TrendScale`。
- **副作用：** 无。
- **算法：**
  1. `totalDays = max(1, futureEnd.difference(historyStart).inDays)`。
  2. 选择采样 `step`：`totalDays <= 240` 时 `1 day`；`totalDays <= 1800` 时 `7 days`；否则 `30 days`——更长范围更粗采样。
  3. 以 `step` 增量从 `historyStart` 走到 `futureEnd`（闭区间），收集每个日期。
  4. 显式把 `today` 和 `futureEnd` 追加进列表（保证两者总是作为精确采样点存在，即使步长否则会跳过它们），然后排序。
  5. 去重连续相等日期（单线性遍，只保留与最后保留者不同的日期）。
  6. `labelInterval = ceil(deduped.length / 6)`，下限 `1`——无论点数多少瞄准约 6 个均匀间隔 X 轴标签。
- **用法：** `_buildTrendCard` 中的 `final scale = _TrendScale.fromRange(historyStart, today, futureEnd);`（`lib/features/devices/views/device_finance_overview_page.dart`，第 202 行）。
- **备注：** 因为 `today` 和 `futureEnd` 去重前强制追加，最后几个采样点间实际间距与范围其余部分使用的固定 `step` 相比可稍不规则。
