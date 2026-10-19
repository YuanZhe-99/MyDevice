import '../../ai/services/insight_prompts.dart';
import '../../devices/models/device.dart';
import '../models/dataset.dart';
import 'dataset_placement.dart';

/// How many at-risk data sets the facts name at most.
const int datasetInsightMaxNames = 2;

/// The slots the datasets card asks for, shared by the full facts and the
/// fallback so the card's sections apply to both.
const List<InsightSlot> datasetInsightSlots = [
  InsightSlot(
    'redundancySummary',
    'Evaluate overall backup resilience, focusing on single-copy datasets '
        'and multi-copy datasets trapped on a single physical device.',
  ),
  InsightSlot(
    'healthRisk',
    'Flag the most urgent storage risk (unavailable copies, degraded RAID '
        'arrays, or copies on retired devices), or confirm all copies are '
        'healthy.',
  ),
  InsightSlot(
    'backupAdvice',
    'Name the highest-risk dataset and suggest a concrete placement change '
        'to achieve true cross-device redundancy.',
  ),
];

/// Purpose: Build the datasets card's facts.
/// Inputs: `now` — local time; `datasets`; `devices` — the current device
/// list; `includeNames` — false for the plainer fallback that names no data
/// set.
/// Returns: `InsightFacts?` — null when there are no data sets.
/// Side effects: None.
/// Notes: Copies come from [resolveReplicas] and count as
/// [availableCopyCount] does, so the card agrees with the list's copy
/// summary. Placement itself ignores a device's lifecycle; this builder
/// reports copies on retired or sold devices separately instead of changing
/// what counts. A data set whose available copies all sit on one device
/// (`device.id`) is redundant in name only: one machine failing loses it.
/// Only data set names (clipped to 30 characters, when `includeNames`) and
/// counts are sent — never a device name, a path, a serial or an emoji.
InsightFacts? buildDatasetInsightFacts({
  required DateTime now,
  required List<DataSet> datasets,
  required List<Device> devices,
  bool includeNames = true,
}) {
  if (datasets.isEmpty) return null;
  final quoted = <String>{};
  var none = 0;
  var single = 0;
  var multi = 0;
  var sameDevice = 0;
  var degraded = 0;
  var onInactive = 0;
  // (data set, available copies, distinct devices holding them)
  final risk = <(DataSet, int, int)>[];
  for (final ds in datasets) {
    final replicas = resolveReplicas(ds, devices);
    final available = replicas.where((r) => r.isAvailable).toList();
    final hosts = available.map((r) => r.device.id).toSet().length;
    switch (available.length) {
      case 0:
        none++;
      case 1:
        single++;
      default:
        multi++;
        if (hosts == 1) sameDevice++;
    }
    if (replicas.any((r) => r.place.health == PlaceHealth.degraded)) {
      degraded++;
    }
    if (replicas.any((r) => !r.device.isInService)) onInactive++;
    if (hosts < 2) risk.add((ds, available.length, hosts));
  }
  // Fewest copies first, then fewest devices, then name for a stable order.
  risk.sort((a, b) {
    final byCopies = a.$2.compareTo(b.$2);
    if (byCopies != 0) return byCopies;
    final byHosts = a.$3.compareTo(b.$3);
    return byHosts != 0 ? byHosts : a.$1.name.compareTo(b.$1.name);
  });

  final lines = <String>[
    '- Today: ${factDate(now)}',
    '- Datasets: ${datasets.length}',
    '- Available copies: $none with none, $single with exactly one, '
        '$multi with two or more',
    '- Two or more copies but all on one device: $sameDevice',
    '- Datasets with a copy on a degraded RAID array: $degraded',
    '- Datasets with a copy on a retired or sold device: $onInactive',
  ];
  if (risk.isNotEmpty) {
    String describe((DataSet, int, int) e) {
      final where = e.$2 == 0
          ? 'no available copy'
          : e.$2 == 1
          ? '1 available copy'
          : '${e.$2} available copies on one device';
      if (!includeNames) return where;
      final name = clipTitle(e.$1.name, 30);
      quoted.add(name);
      return '$name ($where)';
    }

    lines.add(
      '- Highest-risk datasets: '
      '${risk.take(datasetInsightMaxNames).map(describe).join('; ')}',
    );
  }

  return InsightFacts(
    module: InsightModule.datasets,
    lines: lines,
    slots: datasetInsightSlots,
    quotedTerms: quoted.toList(),
  );
}
