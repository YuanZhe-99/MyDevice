import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../models/device.dart';
import '../services/exchange_rate_service.dart';

enum _FinanceRange { year, threeYears, all }

class DeviceFinanceOverviewPage extends StatefulWidget {
  final List<Device> devices;
  final String defaultCurrency;

  const DeviceFinanceOverviewPage({
    super.key,
    required this.devices,
    required this.defaultCurrency,
  });

  @override
  State<DeviceFinanceOverviewPage> createState() =>
      _DeviceFinanceOverviewPageState();
}

class _DeviceFinanceOverviewPageState extends State<DeviceFinanceOverviewPage> {
  _FinanceRange _range = _FinanceRange.year;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.financialOverview)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildSummaryCard(l10n, theme),
          const SizedBox(height: 12),
          _buildAssetDistribution(l10n, theme),
          const SizedBox(height: 12),
          _buildTrendCard(l10n, theme),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(AppLocalizations l10n, ThemeData theme) {
    final cs = theme.colorScheme;
    final devicesWithFinance = widget.devices
        .where((device) => device.hasFinancialData)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 3 : 2;
            final itemWidth =
                (constraints.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _metric(
                    theme,
                    l10n.financialTotalCost,
                    _moneyText(_totalFinancialCost()),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _metric(
                    theme,
                    l10n.financialDailyCost,
                    _moneyText(_totalDailyCost()),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _metric(
                    theme,
                    l10n.financialDevicesWithFinance,
                    '$devicesWithFinance',
                    valueColor: cs.primary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAssetDistribution(AppLocalizations l10n, ThemeData theme) {
    final buckets = _assetBuckets(l10n);
    final total = buckets.fold(0.0, (sum, bucket) => sum + bucket.amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.financialAssetDistribution,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (buckets.isEmpty || total <= 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    l10n.financialNoData,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 44,
                    sectionsSpace: 2,
                    sections: [
                      for (final bucket in buckets)
                        PieChartSectionData(
                          color: bucket.color,
                          value: bucket.amount,
                          title:
                              '${(bucket.amount / total * 100).toStringAsFixed(0)}%',
                          radius: 72,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final bucket in buckets) ...[
                _distributionRow(theme, bucket, total),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard(AppLocalizations l10n, ThemeData theme) {
    final today = _dateOnly(DateTime.now());
    final historyStart = _historyStart(today);
    final futureEnd = today.add(_historyDuration(today, historyStart));
    final scale = _TrendScale.fromRange(historyStart, today, futureEnd);
    final trendData = _buildTrendData(scale, today);
    final hasData =
        trendData.historySpots.any((spot) => spot.y != 0) ||
        trendData.futureSpots.any((spot) => spot.y != 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.financialDailyCostLogTrend,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<_FinanceRange>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _FinanceRange.year,
                    label: Text(l10n.financialRange1Year),
                  ),
                  ButtonSegment(
                    value: _FinanceRange.threeYears,
                    label: Text(l10n.financialRange3Years),
                  ),
                  ButtonSegment(
                    value: _FinanceRange.all,
                    label: Text(l10n.financialRangeAll),
                  ),
                ],
                selected: {_range},
                onSelectionChanged: (selection) {
                  setState(() => _range = selection.first);
                },
              ),
            ),
            const SizedBox(height: 12),
            if (!hasData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    l10n.financialNoData,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              _buildLineChartPanel(
                context: context,
                l10n: l10n,
                scale: scale,
                series: [
                  _ChartSeries(
                    label: l10n.financialHistory,
                    color: theme.colorScheme.primary,
                    spots: trendData.historySpots,
                  ),
                  _ChartSeries(
                    label: l10n.financialFutureTrend,
                    color: theme.colorScheme.primary,
                    spots: trendData.futureSpots,
                    dashed: true,
                  ),
                ],
                minY: trendData.minY,
                maxY: trendData.maxY,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChartPanel({
    required BuildContext context,
    required AppLocalizations l10n,
    required _TrendScale scale,
    required List<_ChartSeries> series,
    required double minY,
    required double maxY,
  }) {
    final bounds = _chartBounds(minY, maxY);
    final transformedMinY = _logTransform(bounds.minY);
    final transformedMaxY = _logTransform(bounds.maxY);
    final yRange = transformedMaxY - transformedMinY;
    final horizontalInterval = yRange > 0 ? yRange / 4 : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: series.map((s) => _legendDot(s)).toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (scale.pointCount - 1).toDouble(),
              minY: transformedMinY,
              maxY: transformedMaxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: horizontalInterval,
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: scale.labelInterval,
                    getTitlesWidget: (value, _) {
                      final idx = value.round();
                      if ((value - idx).abs() > 0.01 ||
                          idx < 0 ||
                          idx >= scale.pointCount) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          scale.xLabel(idx),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: horizontalInterval,
                    getTitlesWidget: (value, _) {
                      if (value == transformedMinY ||
                          value == transformedMaxY) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        _formatAxisValue(_logInverse(value)),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: series
                  .where((series) => series.spots.isNotEmpty)
                  .map(
                    (series) => LineChartBarData(
                      spots: [
                        for (final spot in series.spots)
                          FlSpot(spot.x, _logTransform(spot.y)),
                      ],
                      isCurved: series.spots.length > 2,
                      curveSmoothness: 0.16,
                      preventCurveOverShooting: true,
                      color: series.color,
                      barWidth: 2.5,
                      dashArray: series.dashed ? [7, 5] : null,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: !series.dashed,
                        color: series.color.withAlpha(20),
                      ),
                    ),
                  )
                  .toList(),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((spot) {
                    var idx = spot.x.round();
                    if (idx < 0) idx = 0;
                    if (idx >= scale.pointCount) idx = scale.pointCount - 1;
                    final s = series[spot.barIndex];
                    return LineTooltipItem(
                      '${scale.tooltipLabel(idx)}\n'
                      '${s.label}: ${_moneyText(_logInverse(spot.y))}',
                      TextStyle(
                        color: s.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _metric(
    ThemeData theme,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _distributionRow(ThemeData theme, _AssetBucket bucket, double total) {
    final share = total <= 0 ? 0.0 : bucket.amount / total;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: bucket.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bucket.label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(_moneyText(bucket.amount)),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: share,
                minHeight: 4,
                color: bucket.color,
                backgroundColor: bucket.color.withAlpha(28),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${bucket.count}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _legendDot(_ChartSeries series) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 2,
          decoration: BoxDecoration(
            color: series.dashed ? Colors.transparent : series.color,
            borderRadius: BorderRadius.circular(1),
          ),
          child: series.dashed
              ? LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      Container(width: 7, color: series.color),
                      const SizedBox(width: 4),
                      Container(width: 7, color: series.color),
                    ],
                  ),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(series.label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  _TrendData _buildTrendData(_TrendScale scale, DateTime today) {
    final historySpots = <FlSpot>[];
    final futureSpots = <FlSpot>[];
    final values = <double>[];

    for (var i = 0; i < scale.pointCount; i++) {
      final date = scale.dates[i];
      final value = _totalDailyCostAt(date);
      values.add(value);
      final spot = FlSpot(i.toDouble(), value);
      if (!date.isAfter(today)) historySpots.add(spot);
      if (!date.isBefore(today)) futureSpots.add(spot);
    }

    final minY = values.fold(0.0, (min, value) => math.min(min, value));
    final maxY = values.fold(0.0, (max, value) => math.max(max, value));

    return _TrendData(
      historySpots: historySpots,
      futureSpots: futureSpots,
      minY: minY,
      maxY: maxY,
    );
  }

  List<_AssetBucket> _assetBuckets(AppLocalizations l10n) {
    final totals = <DeviceCategory, double>{};
    final counts = <DeviceCategory, int>{};
    for (final device in widget.devices) {
      if (!device.hasFinancialData) continue;
      final amount = math.max(0.0, device.totalCost());
      if (amount <= 0) continue;
      totals.update(
        device.category,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
      counts.update(device.category, (value) => value + 1, ifAbsent: () => 1);
    }

    final buckets = <_AssetBucket>[];
    for (final entry in totals.entries) {
      buckets.add(
        _AssetBucket(
          label: _categoryLabel(l10n, entry.key),
          amount: entry.value,
          count: counts[entry.key] ?? 0,
          color: _chartColors[buckets.length % _chartColors.length],
        ),
      );
    }
    buckets.sort((a, b) => b.amount.compareTo(a.amount));
    return buckets;
  }

  DateTime _historyStart(DateTime today) {
    return switch (_range) {
      _FinanceRange.year => DateTime(today.year - 1, today.month, today.day),
      _FinanceRange.threeYears => DateTime(
        today.year - 3,
        today.month,
        today.day,
      ),
      _FinanceRange.all =>
        _earliestPurchaseDate() ??
            DateTime(today.year - 1, today.month, today.day),
    };
  }

  Duration _historyDuration(DateTime today, DateTime historyStart) {
    final days = today.difference(historyStart).inDays.abs();
    return Duration(days: math.max(days, 30));
  }

  DateTime? _earliestPurchaseDate() {
    DateTime? earliest;
    for (final device in widget.devices) {
      final date = device.purchaseDate;
      if (date == null) continue;
      final normalized = _dateOnly(date);
      if (earliest == null || normalized.isBefore(earliest)) {
        earliest = normalized;
      }
    }
    return earliest;
  }

  double _totalDailyCostAt(DateTime date) {
    return widget.devices.fold(
      0.0,
      (sum, device) => sum + (_averageDailyCostAt(device, date) ?? 0),
    );
  }

  double? _averageDailyCostAt(Device device, DateTime date) {
    if (!device.hasFinancialData || device.purchaseDate == null) return null;

    final purchaseDate = _dateOnly(device.purchaseDate!);
    if (date.isBefore(purchaseDate)) return null;

    var serviceEnd = date;
    if (!device.isInService && device.retiredDate != null) {
      final retiredDate = _dateOnly(device.retiredDate!);
      if (retiredDate.isBefore(serviceEnd)) serviceEnd = retiredDate;
    }
    if (serviceEnd.isBefore(purchaseDate)) return null;

    final days = math.max(1, serviceEnd.difference(purchaseDate).inDays + 1);
    final purchase = device.purchasePrice?.convertedAmount ?? 0;
    final recurring = device.recurringCosts.fold(
      0.0,
      (sum, cost) => sum + cost.dailyConvertedAmount * days,
    );
    final sold =
        device.isSold &&
            (device.retiredDate == null ||
                !_dateOnly(device.retiredDate!).isAfter(date))
        ? device.soldPrice?.convertedAmount ?? 0
        : 0.0;

    return (purchase + recurring - sold) / days;
  }

  double _totalFinancialCost() =>
      widget.devices.fold(0, (sum, device) => sum + device.totalCost());

  double _totalDailyCost() => widget.devices.fold(
    0,
    (sum, device) => sum + (device.averageDailyCost() ?? 0),
  );

  ({double minY, double maxY}) _chartBounds(double minY, double maxY) {
    if (minY == maxY) {
      final padding = minY.abs() * 0.1;
      final safePadding = padding == 0 ? 1.0 : padding;
      return (minY: math.min(0, minY - safePadding), maxY: maxY + safePadding);
    }

    final padding = (maxY - minY).abs() * 0.1;
    return (minY: math.min(0, minY - padding), maxY: maxY + padding);
  }

  double _logTransform(double value) {
    if (value == 0) return 0;
    final sign = value < 0 ? -1 : 1;
    return sign * math.log(value.abs() + 1) / math.ln10;
  }

  double _logInverse(double value) {
    if (value == 0) return 0;
    final sign = value < 0 ? -1 : 1;
    return (sign * (math.pow(10, value.abs()) - 1)).toDouble();
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _moneyText(double amount) {
    final symbol = DeviceExchangeRateService.currencySymbol(
      widget.defaultCurrency,
    );
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  String _formatAxisValue(double value) {
    final abs = value.abs();
    final sign = value < 0 ? '-' : '';
    if (abs >= 1000000) {
      return '$sign${(abs / 1000000).toStringAsFixed(1)}m';
    }
    if (abs >= 1000) {
      return '$sign${(abs / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }

  String _categoryLabel(AppLocalizations l10n, DeviceCategory category) {
    return switch (category) {
      DeviceCategory.desktop => l10n.deviceCategoryDesktop,
      DeviceCategory.laptop => l10n.deviceCategoryLaptop,
      DeviceCategory.phone => l10n.deviceCategoryPhone,
      DeviceCategory.tablet => l10n.deviceCategoryTablet,
      DeviceCategory.headphone => l10n.deviceCategoryHeadphone,
      DeviceCategory.watch => l10n.deviceCategoryWatch,
      DeviceCategory.router => l10n.deviceCategoryRouter,
      DeviceCategory.gameConsole => l10n.deviceCategoryGameConsole,
      DeviceCategory.vps => l10n.deviceCategoryVps,
      DeviceCategory.devBoard => l10n.deviceCategoryDevBoard,
      DeviceCategory.other => l10n.deviceCategoryOther,
    };
  }

  static const _chartColors = [
    Colors.blue,
    Colors.orange,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.teal,
    Colors.amber,
    Colors.pink,
    Colors.cyan,
    Colors.indigo,
    Colors.lime,
    Colors.brown,
  ];
}

class _TrendScale {
  final List<DateTime> dates;
  final double labelInterval;
  final DateFormat _dateLabel;
  final DateFormat _tooltipLabel;

  _TrendScale({
    required this.dates,
    required this.labelInterval,
    required DateFormat dateLabel,
    required DateFormat tooltipLabel,
  }) : _dateLabel = dateLabel,
       _tooltipLabel = tooltipLabel;

  factory _TrendScale.fromRange(
    DateTime historyStart,
    DateTime today,
    DateTime futureEnd,
  ) {
    final totalDays = math.max(1, futureEnd.difference(historyStart).inDays);
    final step = totalDays <= 240
        ? const Duration(days: 1)
        : totalDays <= 1800
        ? const Duration(days: 7)
        : const Duration(days: 30);
    final dates = <DateTime>[];
    for (
      var date = historyStart;
      !date.isAfter(futureEnd);
      date = date.add(step)
    ) {
      dates.add(date);
    }
    dates.add(today);
    dates.add(futureEnd);
    dates.sort();

    final deduped = <DateTime>[];
    for (final date in dates) {
      if (deduped.isEmpty || deduped.last != date) deduped.add(date);
    }

    final interval = (deduped.length / 6).ceil();
    return _TrendScale(
      dates: deduped,
      labelInterval: (interval < 1 ? 1 : interval).toDouble(),
      dateLabel: DateFormat('M/d'),
      tooltipLabel: DateFormat('yyyy-MM-dd'),
    );
  }

  int get pointCount => dates.length;

  String xLabel(int index) => _dateLabel.format(dates[index]);

  String tooltipLabel(int index) => _tooltipLabel.format(dates[index]);
}

class _TrendData {
  final List<FlSpot> historySpots;
  final List<FlSpot> futureSpots;
  final double minY;
  final double maxY;

  const _TrendData({
    required this.historySpots,
    required this.futureSpots,
    required this.minY,
    required this.maxY,
  });
}

class _ChartSeries {
  final String label;
  final Color color;
  final List<FlSpot> spots;
  final bool dashed;

  const _ChartSeries({
    required this.label,
    required this.color,
    required this.spots,
    this.dashed = false,
  });
}

class _AssetBucket {
  final String label;
  final double amount;
  final int count;
  final Color color;

  const _AssetBucket({
    required this.label,
    required this.amount,
    required this.count,
    required this.color,
  });
}
