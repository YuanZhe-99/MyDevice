import 'dart:math' as math;

import '../../ai/services/insight_prompts.dart';
import '../models/device.dart';

/// How many named devices (or categories) one fact line lists at most.
const int financeInsightMaxNames = 3;

/// How many categories the cost-by-category line lists at most.
const int financeInsightMaxCategories = 5;

/// The slots the device finance card asks for, shared by the full facts and
/// the fallback so the card's sections apply to both.
const List<InsightSlot> deviceFinanceInsightSlots = [
  InsightSlot(
    'costSummary',
    'Identify which category or device drives the largest share of daily '
        'ownership cost versus long-serving low-daily-cost gear.',
  ),
  InsightSlot(
    'costAdvice',
    'Give one concrete tactic to lower daily ownership cost (e.g. extending '
        'lifespan of high-daily-cost gear or selling retired hardware).',
  ),
  InsightSlot(
    'recurringSummary',
    'Assess how much recurring fees add to the daily/annual ownership burden '
        'and which cost kind dominates.',
  ),
  InsightSlot(
    'reviewDevice',
    'Name one specific device or category to review—either a high-daily-cost '
        'item or retired gear that could be sold for resale recovery—and '
        'explain why.',
  ),
];

/// Purpose: Format a money amount for a fact line.
/// Inputs: `amount`, `currency`.
/// Returns: `String` such as `1234 CNY`, rounded to whole units.
/// Side effects: None.
/// Notes: Whole units keep the fingerprint stable against tiny rate changes.
/// Internal helper used within this file only.
String _money(double amount, String currency) => '${amount.round()} $currency';

/// Purpose: Build the device finance card's facts.
/// Inputs: `now` — local time; `devices`; `defaultCurrency`; `includeNames`
/// — false for the plainer fallback that names categories only.
/// Returns: `InsightFacts?` — null when no device has financial data.
/// Side effects: None.
/// Notes: Only aggregates in the default currency, category names and (when
/// `includeNames`) device names are sent. `quotedTerms` always holds the
/// currency code, plus the device names when they are sent. The builder never reads a serial
/// number, a note, a location, a brand or model, a storage serial or a
/// recurring cost's name. Totals use the same `Device` getters as the device
/// list's financial card, evaluated at `now`.
InsightFacts? buildDeviceFinanceInsightFacts({
  required DateTime now,
  required List<Device> devices,
  required String defaultCurrency,
  bool includeNames = true,
}) {
  final withData = devices.where((d) => d.hasFinancialData).toList();
  if (withData.isEmpty) return null;
  final cur = defaultCurrency;
  // The instructions make the model write amounts with this code, so it is
  // quoted: otherwise a short Chinese or Japanese sentence with three
  // amounts fails the script check on the code's Latin letters.
  final quoted = <String>{cur};

  String label(Device d) {
    if (!includeNames) return d.category.name;
    final name = clipTitle(d.name, 30);
    quoted.add(name);
    return '$name (${d.category.name})';
  }

  int count(DeviceLifecycleStatus s) =>
      devices.where((d) => d.lifecycleStatus == s).length;

  final totalCost = withData.fold(0.0, (s, d) => s + d.totalCost(asOf: now));
  final dailyCost = withData.fold(
    0.0,
    (s, d) => s + (d.averageDailyCost(asOf: now) ?? 0),
  );

  final lines = <String>[
    '- Today: ${factDate(now)}',
    '- Currency: $cur',
    '- Devices: ${devices.length}, of which ${withData.length} have cost data; '
        'in service ${count(DeviceLifecycleStatus.inService)}, '
        'retired ${count(DeviceLifecycleStatus.retired)}, '
        'sold ${count(DeviceLifecycleStatus.sold)}',
    '- Total cost of ownership to date: ${_money(totalCost, cur)}',
    '- Total daily cost: ${factNumber(dailyCost, 2)} $cur per day',
  ];

  // Cost by category, same rule as the asset-distribution chart: only
  // positive totals count.
  final byCategory = <DeviceCategory, (double, int)>{};
  for (final d in withData) {
    final amount = math.max(0.0, d.totalCost(asOf: now));
    if (amount <= 0) continue;
    final prev = byCategory[d.category] ?? (0.0, 0);
    byCategory[d.category] = (prev.$1 + amount, prev.$2 + 1);
  }
  final categories = byCategory.entries.toList()
    ..sort((a, b) => b.value.$1.compareTo(a.value.$1));
  if (categories.isNotEmpty) {
    lines.add(
      '- Cost by category: ${[for (final e in categories.take(financeInsightMaxCategories)) '${e.key.name} ${_money(e.value.$1, cur)} '
            '(${e.value.$2} device${e.value.$2 == 1 ? '' : 's'})'].join('; ')}',
    );
  }

  // Highest daily cost among devices still in service.
  final daily = [
    for (final d in withData)
      if (d.isInService && (d.averageDailyCost(asOf: now) ?? 0) > 0)
        (d, d.averageDailyCost(asOf: now)!),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  if (daily.isNotEmpty) {
    lines.add(
      '- Highest daily-cost devices in service: ${[for (final (d, v) in daily.take(financeInsightMaxNames)) '${label(d)} ${factNumber(v, 2)} $cur per day'].join('; ')}',
    );
    // The share is worked out here: a small model cannot divide reliably.
    final inServiceDaily = daily.fold(0.0, (s, e) => s + e.$2);
    final (top, topDaily) = daily.first;
    lines.add(
      '- Daily cost of devices in service: ${factNumber(inServiceDaily, 2)} '
      '$cur per day across ${daily.length} '
      'device${daily.length == 1 ? '' : 's'}; ${label(top)} alone is '
      '${(topDaily / inServiceDaily * 100).round()}% of it',
    );
  }

  // Recurring costs on devices still in service.
  final recurringDevices = devices
      .where((d) => d.isInService && d.recurringCosts.isNotEmpty)
      .toList();
  if (recurringDevices.isEmpty) {
    lines.add('- Recurring costs on devices in service: none');
  } else {
    var monthly = 0.0;
    var yearly = 0.0;
    var entries = 0;
    final kinds = <RecurringCostKind, int>{};
    for (final d in recurringDevices) {
      for (final c in d.recurringCosts) {
        entries++;
        kinds.update(c.kind, (v) => v + 1, ifAbsent: () => 1);
        switch (c.billingCycle) {
          case BillingCycle.monthly:
            monthly += c.price.convertedAmount;
          case BillingCycle.yearly:
            yearly += c.price.convertedAmount;
        }
      }
    }
    final kindText =
        (kinds.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .map((e) => '${e.key.name} ${e.value}')
            .join(', ');
    lines.add(
      '- Recurring costs on devices in service: $entries entries on '
      '${recurringDevices.length} device${recurringDevices.length == 1 ? '' : 's'} '
      '($kindText); monthly-billed ${_money(monthly, cur)} per month, '
      'yearly-billed ${_money(yearly, cur)} per year, '
      'together ${_money(monthly * 12 + yearly, cur)} per year',
    );
    final perDay = (monthly * 12 + yearly) / 365;
    lines.add(
      '- Daily burden of recurring fees: ${factNumber(perDay, 2)} $cur per '
      'day added to the ownership cost of devices in service',
    );
  }

  // Retired and sold devices, and what resale recovered.
  final sold = devices.where((d) => d.isSold).toList();
  final resale = sold
      .where((d) => d.soldPrice != null)
      .fold(0.0, (s, d) => s + d.soldPrice!.convertedAmount);
  final soldWithPrice = sold.where((d) => d.soldPrice != null).length;
  lines.add(
    '- Retired or sold: ${count(DeviceLifecycleStatus.retired)} retired, '
    '${sold.length} sold, $soldWithPrice sold with a resale price totalling '
    '${_money(resale, cur)}',
  );

  // Retired but unsold hardware: what it cost new is the pool resale could
  // recover part of.
  final idle = devices
      .where(
        (d) =>
            d.lifecycleStatus == DeviceLifecycleStatus.retired &&
            d.purchasePrice != null,
      )
      .toList();
  if (idle.isNotEmpty) {
    final paid = idle.fold(0.0, (s, d) => s + d.purchasePrice!.convertedAmount);
    lines.add(
      '- Retired and not sold: ${idle.length} '
      'device${idle.length == 1 ? '' : 's'} bought for ${_money(paid, cur)} '
      'in total${idle.length <= financeInsightMaxNames ? ': ${idle.map(label).join('; ')}' : ''}',
    );
  }

  // Oldest devices still in service, by purchase date.
  final oldest = [
    for (final d in devices)
      if (d.isInService && d.purchaseDate != null) d,
  ]..sort((a, b) => a.purchaseDate!.compareTo(b.purchaseDate!));
  if (oldest.isNotEmpty) {
    lines.add(
      '- Oldest devices in service: ${[for (final d in oldest.take(financeInsightMaxNames)) '${label(d)} since ${factDate(d.purchaseDate!)}, '
            '${d.serviceDays(asOf: now)} days'].join('; ')}',
    );
  }

  return InsightFacts(
    module: InsightModule.deviceFinance,
    lines: lines,
    slots: deviceFinanceInsightSlots,
    quotedTerms: quoted.toList(),
  );
}
