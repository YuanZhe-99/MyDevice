# lib/features/devices/views/device_finance_overview_page.dart

The financial overview page opened from the device list's financial overview card (see
[Devices](../../../../features/devices.md#financial-overview-page)). It renders three sections
with `fl_chart`: a summary metrics card, an asset-distribution pie chart by
`DeviceCategory`, and a combined historical/future daily-cost trend line chart. This file owns
all the finance-aggregation math itself (it does not call back into `Device`'s per-device finance
getters beyond `hasFinancialData`/`totalCost`/`purchaseDate`/`retiredDate`/`isSold` — the
date-indexed "cost as of an arbitrary day" computation used for the trend chart is implemented
locally in `_averageDailyCostAt`/`_totalDailyCostAt`). See
[Devices](../../../../features/devices.md#lifecycle-and-finance-tracking) for the underlying
`Device.totalCost()`/`averageDailyCost()` model getters this page's summary metrics reuse.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `DeviceFinanceOverviewPage` (constructor) | constructor | B | Store the device list and default currency for the page widget. |
| `createState` | method (`DeviceFinanceOverviewPage`) | B | Create the page's mutable state object. |
| `build` | method (widget) | B | Build the scaffold and stack the summary/distribution/trend cards. |
| `_buildSummaryCard` | method (widget helper) | B | Render the total cost / daily cost / device-count metrics row. |
| `_buildAssetDistribution` | method (widget helper) | B | Render the asset-distribution pie chart and per-category legend rows. |
| `_buildTrendCard` | method (widget helper) | B | Render the trend chart's title, range selector, and line chart panel. |
| [`_buildLineChartPanel`](#_buildlinechartpanel) | method (`_DeviceFinanceOverviewPageState`) | A | Compute log-scale axis bounds/intervals and build the `fl_chart` `LineChart`. |
| `_metric` | method (widget helper) | B | Render one label/value metric column. |
| `_distributionRow` | method (widget helper) | B | Render one category's legend row with color dot, progress bar, and count. |
| `_legendDot` | method (widget helper) | B | Render one chart-series legend entry (solid or dashed line swatch + label). |
| [`_buildTrendData`](#_buildtrenddata) | method (`_DeviceFinanceOverviewPageState`) | A | Sample the daily-cost function across the trend scale into history/future point lists. |
| [`_assetBuckets`](#_assetbuckets) | method (`_DeviceFinanceOverviewPageState`) | A | Aggregate each device's total cost into per-category buckets, sorted descending. |
| [`_historyStart`](#_historystart) | method (`_DeviceFinanceOverviewPageState`) | A | Compute the trend chart's history start date for the selected range. |
| [`_historyDuration`](#_historyduration) | method (`_DeviceFinanceOverviewPageState`) | A | Compute the forward projection window's length from the history window's length. |
| [`_earliestPurchaseDate`](#_earliestpurchasedate) | method (`_DeviceFinanceOverviewPageState`) | A | Find the earliest `purchaseDate` across all devices. |
| [`_totalDailyCostAt`](#_totaldailycostat) | method (`_DeviceFinanceOverviewPageState`) | A | Sum every device's average daily cost as of a given date. |
| [`_averageDailyCostAt`](#_averagedailycostat) | method (`_DeviceFinanceOverviewPageState`) | A | Compute one device's average daily cost as of an arbitrary date (past or future). |
| [`_totalFinancialCost`](#_totalfinancialcost) | method (`_DeviceFinanceOverviewPageState`) | A | Sum `totalCost()` across all devices. |
| [`_totalDailyCost`](#_totaldailycost) | method (`_DeviceFinanceOverviewPageState`) | A | Sum current `averageDailyCost()` across all devices. |
| [`_chartBounds`](#_chartbounds) | method (`_DeviceFinanceOverviewPageState`) | A | Pad a raw min/max Y range by 10% (or a fallback) for chart display. |
| [`_logTransform`](#_logtransform) | method (`_DeviceFinanceOverviewPageState`) | A | Apply the signed `log10(\|x\|+1)` transform used for the chart's Y axis. |
| [`_logInverse`](#_loginverse) | method (`_DeviceFinanceOverviewPageState`) | A | Invert `_logTransform` back to a real cost value. |
| `_dateOnly` | method (`_DeviceFinanceOverviewPageState`) | B | Strip the time-of-day component from a `DateTime`. |
| [`_moneyText`](#_moneytext-finance) | method (`_DeviceFinanceOverviewPageState`) | A | Format an amount with the page's default-currency symbol. |
| [`_formatAxisValue`](#_formataxisvalue) | method (`_DeviceFinanceOverviewPageState`) | A | Format a Y-axis tick value with `k`/`m` suffixes for large magnitudes. |
| `_categoryLabel` | method (`_DeviceFinanceOverviewPageState`) | B | Map a `DeviceCategory` to its localized label. |
| `_TrendScale` (constructor) | constructor | B | Store the precomputed date list, label interval, and date formatters. |
| [`_TrendScale.fromRange`](#trendscale-fromrange) | factory constructor | A | Build a `_TrendScale` (date samples + label interval) for a history/today/future-end range. |
| `pointCount` | getter (`_TrendScale`) | B | Return the number of sampled dates (chart X-axis point count). |
| `xLabel` | method (`_TrendScale`) | B | Format the short (`M/d`) axis label for a sample index. |
| `tooltipLabel` | method (`_TrendScale`) | B | Format the full (`yyyy-MM-dd`) tooltip label for a sample index. |
| `_TrendData` (constructor) | constructor | B | Store the computed history/future spot lists and Y bounds. |
| `_ChartSeries` (constructor) | constructor | B | Store one chart series' label, color, spots, and dashed flag. |
| `_AssetBucket` (constructor) | constructor | B | Store one category's label, amount, count, and chart color. |

Row count note: `grep -c 'Purpose:'` on this file returns 33; the table above has 34 real
declaration rows (the stray `_chartColors` line is a table formatting artifact, not a separate
row — see below). The one undocumented declaration is `_chartBounds`
(`lib/features/devices/views/device_finance_overview_page.dart`, line 715): it has no `///` doc
comment of any kind (not even a plain one), unlike every other method in the file, so it does not
match the `Purpose:` grep. It is still a real, load-bearing declaration (see
[`_chartBounds`](#_chartbounds) below) and is included here per the "every declaration gets a row"
rule. `_chartColors` (a `static const List<Color>`, line 806) is a data constant, not a function/
method/constructor, and — consistent with how other private enums and constant maps in this
batch's files are handled — is not counted as its own declaration row.

## Documentation

### `Widget _buildLineChartPanel({required BuildContext context, required AppLocalizations l10n, required _TrendScale scale, required List<_ChartSeries> series, required double minY, required double maxY})` <a id="_buildlinechartpanel"></a>
- **Kind:** method of `_DeviceFinanceOverviewPageState`
- **Source:** `lib/features/devices/views/device_finance_overview_page.dart` (line 290)
- **Purpose:** Compute the log-scale Y-axis bounds/grid interval and render the `fl_chart`
  `LineChart` for the daily-cost trend (history + future series), including axis tick and tooltip
  formatting.
- **Inputs:** `scale` — the `_TrendScale` describing the sampled dates/labels; `series` — one or
  two `_ChartSeries` (history, and a dashed future projection); `minY`/`maxY` — the raw
  (untransformed) cost range to display.
- **Returns:** `Widget` — a legend row plus a 260px-tall `LineChart`.
- **Side effects:** None beyond building the widget tree (no state mutation).
- **Algorithm:**
  1. Calls [`_chartBounds`](#_chartbounds) to pad `minY`/`maxY`, then applies
     [`_logTransform`](#_logtransform) to both bounds to get the chart's actual `minY`/`maxY` in
     transformed (log) space.
  2. Computes `horizontalInterval` as a quarter of the transformed Y range (`yRange / 4`, or `1.0`
     if the range collapses to zero) — this becomes both the grid line spacing and the left-axis
     label interval.
  3. Builds `LineChartData` with `minX: 0`, `maxX: scale.pointCount - 1`.
  4. Bottom-axis tick labels: for each candidate `value`, rounds to the nearest index; if the
     rounding error exceeds `0.01` or the index falls outside `[0, pointCount)`, renders nothing
     (`SizedBox.shrink()`); otherwise renders `scale.xLabel(idx)`. Uses `scale.labelInterval` to
     space candidate ticks.
  5. Left-axis tick labels: suppresses the label exactly at the transformed min/max (avoids
     crowding at the chart edges), otherwise renders `_formatAxisValue(_logInverse(value))` — i.e.
     labels are always shown in real cost units, never in log space.
  6. Builds one `LineChartBarData` per non-empty series, re-mapping every `FlSpot`'s `y` through
     `_logTransform` (the `x` — a sample index — is left untouched). Curves the line only when a
     series has more than 2 points; applies `dashArray: [7, 5]` when `series.dashed` is true (the
     future-projection segment) and disables the area fill for dashed series.
  7. Tooltip items clamp the touched spot's index into `[0, pointCount - 1]`, then combine
     `scale.tooltipLabel(idx)` with the series label and
     `_moneyText(_logInverse(spot.y))` (converting the log-space `y` value back to a real amount
     for display).
- **Usage:**
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
  (from `_buildTrendCard`, `lib/features/devices/views/device_finance_overview_page.dart`, lines
  259–278)
- **Notes:** Both series share the same color (`theme.colorScheme.primary`) — history vs. future
  is distinguished only by the dash pattern and area fill, not by color. See
  [Devices](../../../../features/devices.md#financial-overview-page) for why the axis uses a log
  transform (keeps small recurring daily costs and large one-time purchase spikes readable on the
  same chart).

### `_TrendData _buildTrendData(_TrendScale scale, DateTime today)` <a id="_buildtrenddata"></a>
- **Kind:** method of `_DeviceFinanceOverviewPageState`
- **Source:** `lib/features/devices/views/device_finance_overview_page.dart` (line 544)
- **Purpose:** Sample the fleet's total daily cost at every date in the trend scale, splitting the
  points into a "history" series (dates up to and including today) and a "future" series (today
  onward).
- **Inputs:** `scale` — the `_TrendScale` (sampled dates); `today` — the date-only "now" boundary
  between history and projection.
- **Returns:** `_TrendData` containing `historySpots`, `futureSpots`, and the raw `minY`/`maxY`
  observed across all sampled values.
- **Side effects:** None.
- **Algorithm:**
  1. For each index `i` in `scale.dates`, computes `value = _totalDailyCostAt(scale.dates[i])` and
     builds `FlSpot(i.toDouble(), value)`.
  2. Adds the spot to `historySpots` if the date is not after `today`, and to `futureSpots` if the
     date is not before `today` — so `today` itself is included in **both** series, which is what
     visually joins the solid and dashed line segments at the "now" point.
  3. Tracks `minY`/`maxY` via `fold` starting from `0.0` (so the range always includes zero even
     if all costs are positive or negative).
- **Usage:** `final trendData = _buildTrendData(scale, today);` in `_buildTrendCard`
  (`lib/features/devices/views/device_finance_overview_page.dart`, line 203).
- **Notes:** Because `historySpots`/`futureSpots` share the boundary point, the two
  `LineChartBarData` entries built from them in `_buildLineChartPanel` render as one visually
  continuous line that switches from solid to dashed exactly at `today`.

### `List<_AssetBucket> _assetBuckets(AppLocalizations l10n)` <a id="_assetbuckets"></a>
- **Kind:** method of `_DeviceFinanceOverviewPageState`
- **Source:** `lib/features/devices/views/device_finance_overview_page.dart` (line 574)
- **Purpose:** Group every device with positive financial data by `DeviceCategory`, summing total
  cost and counting devices per category, for the asset-distribution pie chart.
- **Inputs:** `l10n` — used only to localize each category's label.
- **Returns:** `List<_AssetBucket>` — one bucket per category that has at least one device with
  `totalCost() > 0`, sorted by `amount` descending.
- **Side effects:** None.
- **Algorithm:**
  1. Skips devices where `hasFinancialData` is false, or where
     `math.max(0.0, device.totalCost())` is `<= 0` (a device that is a net loss, e.g. sold for
     less than accumulated cost, contributes `0` rather than a negative slice — negative amounts
     would break the pie chart's proportions).
  2. Accumulates `totals[category] += amount` and `counts[category] += 1` via `Map.update` with
     `ifAbsent`.
  3. Builds one `_AssetBucket` per category entry, assigning a color by cycling through
     `_chartColors` (`_chartColors[buckets.length % _chartColors.length]`) in the order categories
     were first encountered in `totals.entries` — not a fixed per-category color.
  4. Sorts the resulting list by `amount` descending (largest category first).
- **Usage:** `final buckets = _assetBuckets(l10n);` in `_buildAssetDistribution`
  (`lib/features/devices/views/device_finance_overview_page.dart`, line 128).
- **Notes:** Because color assignment depends on iteration/insertion order of the `totals` map
  (built from `widget.devices` order) rather than a fixed category → color table, the same
  category can be assigned a different pie-chart color across different device lists.

### `DateTime _historyStart(DateTime today)` <a id="_historystart"></a>
- **Kind:** method of `_DeviceFinanceOverviewPageState`
- **Source:** `lib/features/devices/views/device_finance_overview_page.dart` (line 609)
- **Purpose:** Compute the start date of the trend chart's historical window for the currently
  selected `_FinanceRange`.
- **Inputs:** `today` — the date-only current date.
- **Returns:** `DateTime` — `today` minus 1 year, minus 3 years, or (for "all") the earliest
  device purchase date.
- **Side effects:** None (reads `_range` state).
- **Algorithm:** A `switch` on `_range`: `_FinanceRange.year` → `today` with the year decremented
  by 1; `_FinanceRange.threeYears` → year decremented by 3; `_FinanceRange.all` →
  [`_earliestPurchaseDate`](#_earliestpurchasedate), falling back to a 1-year window if no device
  has a purchase date at all.
- **Usage:** `final historyStart = _historyStart(today);` in `_buildTrendCard`
  (`lib/features/devices/views/device_finance_overview_page.dart`, line 200).
- **Notes:** None.

### `Duration _historyDuration(DateTime today, DateTime historyStart)` <a id="_historyduration"></a>
- **Kind:** method of `_DeviceFinanceOverviewPageState`
- **Source:** `lib/features/devices/views/device_finance_overview_page.dart` (line 628)
- **Purpose:** Derive the forward "future projection" window's length from the historical
  window's length, so the projected segment mirrors however far back the chart already looks.
- **Inputs:** `today`, `historyStart`.
- **Returns:** `Duration` — the absolute day count between `today` and `historyStart`, floored at
  30 days.
- **Side effects:** None.
- **Algorithm:** `days = |today.difference(historyStart).inDays|`; returns
  `Duration(days: math.max(days, 30))` — guarantees at least a 30-day projection window even if
  the history window itself is very short.
- **Usage:**
  ```dart
  final futureEnd = today.add(_historyDuration(today, historyStart));
  ```
  (from `_buildTrendCard`, `lib/features/devices/views/device_finance_overview_page.dart`, line
  201)
- **Notes:** None.

### `DateTime? _earliestPurchaseDate()` <a id="_earliestpurchasedate"></a>
- **Kind:** method of `_DeviceFinanceOverviewPageState`
- **Source:** `lib/features/devices/views/device_finance_overview_page.dart` (line 638)
- **Purpose:** Find the earliest `purchaseDate` across all devices in the list, for the "all time"
  trend range.
- **Inputs:** None (reads `widget.devices`).
- **Returns:** `DateTime?` — the earliest date-only purchase date, or `null` if no device has a
  `purchaseDate`.
- **Side effects:** None.
- **Algorithm:** Iterates all devices, skipping those with a null `purchaseDate`; normalizes each
  date via `_dateOnly` and keeps the minimum seen so far.
- **Usage:** Called from [`_historyStart`](#_historystart)'s `_FinanceRange.all` branch.
- **Notes:** None.

### `double _totalDailyCostAt(DateTime date)` <a id="_totaldailycostat"></a>
- **Kind:** method of `_DeviceFinanceOverviewPageState`
- **Source:** `lib/features/devices/views/device_finance_overview_page.dart` (line 656)
- **Purpose:** Sum the fleet-wide average daily cost as of an arbitrary date (used to sample every
  point on the trend chart, past or future).
- **Inputs:** `date`.
- **Returns:** `double` — sum of [`_averageDailyCostAt`](#_averagedailycostat) across
  `widget.devices` (treating a `null` per-device result as `0`).
- **Side effects:** None.
- **Algorithm:** `widget.devices.fold(0.0, (sum, device) => sum + (_averageDailyCostAt(device,
  date) ?? 0))`.
- **Usage:** Called once per sample point inside [`_buildTrendData`](#_buildtrenddata)'s loop.
- **Notes:** None.

### `double? _averageDailyCostAt(Device device, DateTime date)` <a id="_averagedailycostat"></a>
- **Kind:** method of `_DeviceFinanceOverviewPageState`
- **Source:** `lib/features/devices/views/device_finance_overview_page.dart` (line 668)
- **Purpose:** Compute one device's average daily cost as it would have stood (or will stand) on
  an arbitrary date — the core primitive that lets the trend chart plot cost at any past or future
  point, not just "now" (unlike `Device.averageDailyCost()`, which is always relative to the
  present).
- **Inputs:** `device`; `date` — the date to evaluate at (may be in the past or the future
  relative to today).
- **Returns:** `double?` — `null` if the device has no financial data, no `purchaseDate`, or
  `date` is before the purchase date; otherwise the average daily cost as of `date`.
- **Side effects:** None.
- **Algorithm:**
  1. Returns `null` if `!device.hasFinancialData` or `purchaseDate` is null, or if `date` is
     before the (date-only) purchase date.
  2. `serviceEnd` starts as `date`, but if the device is not currently in service and has a
     `retiredDate` earlier than `date`, `serviceEnd` is clamped to `retiredDate` — so cost stops
     accruing "service days" past retirement even when projecting into the future.
  3. Returns `null` if `serviceEnd` ends up before `purchaseDate` (degenerate case).
  4. `days = max(1, serviceEnd.difference(purchaseDate).inDays + 1)` — inclusive day count.
  5. `purchase` = `purchasePrice?.convertedAmount ?? 0` (a one-time cost, same regardless of
     `date`).
  6. `recurring` = sum of each recurring cost's `dailyConvertedAmount * days` — i.e. recurring
     costs scale with however many days have elapsed by `date`.
  7. `sold` = `soldPrice?.convertedAmount` **only if** the device `isSold` **and** either it has no
     `retiredDate` or `retiredDate` is not after `date` — i.e. the sale proceeds only reduce cost
     from the retirement/sale date onward, not before. Otherwise `0.0`.
  8. Returns `(purchase + recurring - sold) / days`.
- **Usage:** Called once per device from [`_totalDailyCostAt`](#_totaldailycostat).
- **Notes:** This duplicates (rather than reuses) the arithmetic shape of
  `Device.totalCost()`/`averageDailyCost()` (see
  [Devices](../../../../features/devices.md#lifecycle-and-finance-tracking)) because those model
  getters are only evaluable "as of now", while this page needs the same cost model evaluated at
  every historical and projected sample date.

### `double _totalFinancialCost()` <a id="_totalfinancialcost"></a>
- **Kind:** method of `_DeviceFinanceOverviewPageState`
- **Source:** `lib/features/devices/views/device_finance_overview_page.dart` (line 702)
- **Purpose:** Sum `Device.totalCost()` (as of now) across every device, for the summary card's
  "Total Cost" metric.
- **Inputs:** None (reads `widget.devices`).
- **Returns:** `double`.
- **Side effects:** None.
- **Algorithm:** `widget.devices.fold(0, (sum, device) => sum + device.totalCost())`.
- **Usage:** `_moneyText(_totalFinancialCost())` in `_buildSummaryCard`
  (`lib/features/devices/views/device_finance_overview_page.dart`, line 94).
- **Notes:** Unlike `_totalDailyCostAt`, this reuses `Device.totalCost()` directly (evaluated at
  "now", the model's default) rather than reimplementing the arithmetic.

### `double _totalDailyCost()` <a id="_totaldailycost"></a>
- **Kind:** method of `_DeviceFinanceOverviewPageState`
- **Source:** `lib/features/devices/views/device_finance_overview_page.dart` (line 710)
- **Purpose:** Sum `Device.averageDailyCost()` (as of now) across every device, for the summary
  card's "Daily Cost" metric.
- **Inputs:** None.
- **Returns:** `double`.
- **Side effects:** None.
- **Algorithm:** `widget.devices.fold(0, (sum, device) => sum + (device.averageDailyCost() ?? 0))`.
- **Usage:** `_moneyText(_totalDailyCost())` in `_buildSummaryCard`
  (`lib/features/devices/views/device_finance_overview_page.dart`, line 102).
- **Notes:** None.

### `({double minY, double maxY}) _chartBounds(double minY, double maxY)` <a id="_chartbounds"></a>
- **Kind:** method of `_DeviceFinanceOverviewPageState`
- **Source:** `lib/features/devices/views/device_finance_overview_page.dart` (line 715)
- **Purpose:** Pad a raw min/max cost range with headroom so the trend line doesn't touch the
  chart's top/bottom edge, and ensure zero is always included in the visible range.
- **Inputs:** `minY`, `maxY` — the raw (untransformed) observed cost range.
- **Returns:** A record `(minY: double, maxY: double)` — the padded bounds.
- **Side effects:** None.
- **Algorithm:**
  1. If `minY == maxY` (a flat line, e.g. only one data point or all-identical values): padding is
     `10%` of `|minY|`, or `1.0` if that padding would be `0` (i.e. the value itself is `0`).
     Returns `(min(0, minY - padding), maxY + padding)`.
  2. Otherwise: padding is `10%` of the range `|maxY - minY|`. Returns the same
     `(min(0, minY - padding), maxY + padding)` shape.
  3. In both branches, `min(0, ...)` guarantees the lower bound never sits above zero — the chart
     always shows the zero line.
- **Usage:** `final bounds = _chartBounds(minY, maxY);` in
  [`_buildLineChartPanel`](#_buildlinechartpanel), immediately before the bounds are run through
  `_logTransform` to get the chart's actual axis extents.
- **Notes:** This declaration has no `///` doc comment in source at all (see the row-count note
  above) — undocumented in-source, but load-bearing for the chart's Y-axis padding.

### `double _logTransform(double value)` <a id="_logtransform"></a>
- **Kind:** method of `_DeviceFinanceOverviewPageState`
- **Source:** `lib/features/devices/views/device_finance_overview_page.dart` (line 731)
- **Purpose:** Apply the signed log transform used for the daily-cost trend chart's Y axis, so
  small recurring costs and large one-time purchase spikes are both readable on the same scale.
- **Inputs:** `value` — a real cost amount (can be negative, e.g. net-loss days).
- **Returns:** `double` — `0` if `value == 0`; otherwise `sign(value) * log10(|value| + 1)`.
- **Side effects:** None.
- **Algorithm:** Short-circuits to `0` for `value == 0` (avoids `log(1)/ln10` rounding noise around
  zero, though that would also evaluate to `0`). Otherwise computes
  `sign * math.log(value.abs() + 1) / math.ln10`, i.e. `log10(|value|+1)` with the original sign
  reapplied. This is the same transform documented in
  [Devices](../../../../features/devices.md#financial-overview-page).
- **Usage:** Applied to `minY`/`maxY` chart bounds and to every plotted spot's `y` value inside
  [`_buildLineChartPanel`](#_buildlinechartpanel).
- **Notes:** The `+1` inside the log keeps the transform defined (and continuous through `0`) for
  small values near zero, unlike a plain `log10(|value|)` which would diverge to `-∞` as `value`
  approaches `0`.

### `double _logInverse(double value)` <a id="_loginverse"></a>
- **Kind:** method of `_DeviceFinanceOverviewPageState`
- **Source:** `lib/features/devices/views/device_finance_overview_page.dart` (line 742)
- **Purpose:** Invert `_logTransform`, converting a log-space axis value back to a real cost amount
  for axis tick labels and tooltips.
- **Inputs:** `value` — a value already in log-transformed space.
- **Returns:** `double` — `0` if `value == 0`; otherwise `sign(value) * (10^|value| - 1)`.
- **Side effects:** None.
- **Algorithm:** `sign * (math.pow(10, value.abs()) - 1)`, the algebraic inverse of
  `log10(|x|+1)`.
- **Usage:**
  ```dart
  _formatAxisValue(_logInverse(value))
  ...
  '${s.label}: ${_moneyText(_logInverse(spot.y))}',
  ```
  (both in [`_buildLineChartPanel`](#_buildlinechartpanel))
- **Notes:** None.

### `String _moneyText(double amount)` <a id="_moneytext-finance"></a>
- **Kind:** method of `_DeviceFinanceOverviewPageState`
- **Source:** `lib/features/devices/views/device_finance_overview_page.dart` (line 761)
- **Purpose:** Format a plain amount with the page's configured default-currency symbol.
- **Inputs:** `amount` — already expressed in `widget.defaultCurrency`.
- **Returns:** `String` — `"{symbol}{amount.toStringAsFixed(2)}"`.
- **Side effects:** None (looks up the symbol via `DeviceExchangeRateService.currencySymbol`).
- **Algorithm:** Straight symbol lookup + 2-decimal formatting; no conversion is performed (unlike
  `device_detail_page.dart`'s `_moneyText`, which handles a `MoneyValue` with two currencies —
  this page's `_moneyText` only ever formats amounts already aggregated into one currency).
- **Usage:** `_moneyText(_totalFinancialCost())`, `_moneyText(bucket.amount)`,
  `_moneyText(_logInverse(spot.y))`, etc. throughout this file.
- **Notes:** None.

### `String _formatAxisValue(double value)` <a id="_formataxisvalue"></a>
- **Kind:** method of `_DeviceFinanceOverviewPageState`
- **Source:** `lib/features/devices/views/device_finance_overview_page.dart` (line 773)
- **Purpose:** Format a real (already log-inverted) Y-axis tick value compactly, using `k`/`m`
  suffixes for large magnitudes so labels stay short at the chart's default width.
- **Inputs:** `value`.
- **Returns:** `String` — `"{sign}{abs/1e6:.1f}m"` for `|value| >= 1_000_000`,
  `"{sign}{abs/1e3:.1f}k"` for `|value| >= 1_000`, else the plain integer value.
- **Side effects:** None.
- **Algorithm:** Three-way branch on magnitude as described above; the sign is extracted
  separately and prefixed only in the `k`/`m` branches (the plain branch relies on
  `value.toStringAsFixed(0)`'s own sign handling).
- **Usage:** `_formatAxisValue(_logInverse(value))` for the chart's left-axis tick labels, in
  [`_buildLineChartPanel`](#_buildlinechartpanel).
- **Notes:** None.

### `factory _TrendScale.fromRange(DateTime historyStart, DateTime today, DateTime futureEnd)` <a id="trendscale-fromrange"></a>
- **Kind:** factory constructor of `_TrendScale`
- **Source:** `lib/features/devices/views/device_finance_overview_page.dart` (line 846)
- **Purpose:** Build the list of dates to sample for the trend chart (its X axis), choosing a
  sampling step size based on the total span so very long ranges don't produce thousands of
  points, and computing how many points apart X-axis labels should be drawn.
- **Inputs:** `historyStart`, `today`, `futureEnd` — the three key dates bounding the sampled
  range.
- **Returns:** A new `_TrendScale` with the deduplicated, sorted `dates` list, a `labelInterval`,
  and fixed `M/d` (axis) / `yyyy-MM-dd` (tooltip) `DateFormat`s.
- **Side effects:** None.
- **Algorithm:**
  1. `totalDays = max(1, futureEnd.difference(historyStart).inDays)`.
  2. Chooses a sampling `step`: `1 day` if `totalDays <= 240`; `7 days` if `totalDays <= 1800`;
     otherwise `30 days` — coarser sampling for longer ranges.
  3. Walks from `historyStart` to `futureEnd` (inclusive) in `step` increments, collecting each
     date.
  4. Explicitly appends `today` and `futureEnd` to the list (guaranteeing both are always present
     as exact sample points, even if the step size would otherwise skip over them), then sorts.
  5. Deduplicates consecutive equal dates (a single linear pass keeping only dates that differ from
     the last kept one).
  6. `labelInterval = ceil(deduped.length / 6)`, floored at `1` — aims for roughly 6 evenly-spaced
     X-axis labels regardless of point count.
- **Usage:** `final scale = _TrendScale.fromRange(historyStart, today, futureEnd);` in
  `_buildTrendCard` (`lib/features/devices/views/device_finance_overview_page.dart`, line 202).
- **Notes:** Because `today` and `futureEnd` are force-appended before deduplication, the actual
  spacing between the last few sample points can be slightly irregular compared to the fixed
  `step` used for the rest of the range.
