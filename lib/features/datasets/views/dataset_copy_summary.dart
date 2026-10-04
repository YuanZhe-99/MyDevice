import '../../../l10n/app_localizations.dart';
import '../services/dataset_placement.dart';

/// Purpose: Describe how many copies a data set has and how many still
/// count.
/// Inputs: `l10n`; `total` — every copy; `available` — the copies whose
/// place is not unavailable.
/// Returns: The text and whether it is a warning (at most one usable copy).
/// Side effects: None.
/// Notes: Without unavailable copies: "Only one copy" or "n copies". With
/// some: "n copies · k unavailable", led by "No usable copy" when none is
/// left. Shared by the grouped list, the topology boxes and its details.
({String text, bool warn}) dataSetCopySummary(
  AppLocalizations l10n, {
  required int total,
  required int available,
}) {
  final unavailable = total - available;
  if (unavailable == 0) {
    return (
      text: total <= 1 ? l10n.dataSetSingleCopy : l10n.dataSetCopies(total),
      warn: total <= 1,
    );
  }
  return (
    text: [
      if (available == 0) l10n.dataSetNoAvailableCopy,
      l10n.dataSetCopies(total),
      l10n.dataSetCopiesUnavailable(unavailable),
    ].join(' · '),
    warn: available <= 1,
  );
}

/// Purpose: Run [dataSetCopySummary] on resolved copies.
/// Inputs: `l10n`; `replicas` — from `resolveReplicas`.
/// Returns: As [dataSetCopySummary].
/// Side effects: None.
/// Notes: None.
({String text, bool warn}) dataSetReplicaSummary(
  AppLocalizations l10n,
  List<DataSetReplica> replicas,
) => dataSetCopySummary(
  l10n,
  total: replicas.length,
  available: availableCopyCount(replicas),
);
