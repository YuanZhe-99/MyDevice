# lib/features/datasets/views/dataset_copy_summary.dart

Two top-level helpers (since 1.8.2) that word how many copies a data set has and how many of them
still count, given that a copy on a failed or offline drive, or on a RAID array that lost more
drives than it tolerates, is unavailable (see
[`dataset_placement.md`](../services/dataset_placement.md#health)). Both return a record
`({String text, bool warn})`: the text, and whether it is a warning (at most one usable copy).
Shared by the grouped list ([`dataset_list_page.md`](dataset_list_page.md#groupedsubtitle)) and the
topology's boxes and details ([`dataset_topology_page.md`](dataset_topology_page.md)). See
[Datasets](../../../../features/datasets.md#copies).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`dataSetCopySummary`](#datasetcopysummary) | top-level function | A | Word a copy count and the unavailable copies; flag at most one usable copy. |
| [`dataSetReplicaSummary`](#datasetreplicasummary) | top-level function | A | `dataSetCopySummary` on resolved replicas. |

Row count (2) matches `grep -c 'Purpose:' dataset_copy_summary.dart` (2) exactly.

## Documentation

### `({String text, bool warn}) dataSetCopySummary(AppLocalizations l10n, {required int total, required int available})` <a id="datasetcopysummary"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/datasets/views/dataset_copy_summary.dart` (line 13).
- **Purpose:** Describe how many copies a data set has and how many still count.
- **Inputs:** `l10n`; `total` — every copy; `available` — the copies whose place is not
  `unavailable`.
- **Returns:** The text and `warn` — true when at most one usable copy is left.
- **Side effects:** None.
- **Algorithm:** No unavailable copies ⇒ `dataSetSingleCopy` ("Only one copy") when `total ≤ 1`,
  else `dataSetCopies(total)`; `warn` is `total ≤ 1`. Otherwise join with ` · `:
  `dataSetNoAvailableCopy` ("No usable copy", only when `available == 0`),
  `dataSetCopies(total)` and `dataSetCopiesUnavailable(total − available)`; `warn` is
  `available ≤ 1`.
- **Usage:** Copy boxes and the copy header of the details in
  [`dataset_topology_page.md`](dataset_topology_page.md), from a node's `copyCount` and
  `availableCount`; and through `dataSetReplicaSummary`.
- **Notes:** Without failed places the wording is exactly that of 1.8.1.

### `({String text, bool warn}) dataSetReplicaSummary(AppLocalizations l10n, List<DataSetReplica> replicas)` <a id="datasetreplicasummary"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/datasets/views/dataset_copy_summary.dart` (line 40).
- **Purpose:** Run `dataSetCopySummary` on resolved copies.
- **Inputs:** `l10n`; `replicas` — from
  [`resolveReplicas`](../services/dataset_placement.md#resolvereplicas).
- **Returns:** As `dataSetCopySummary`.
- **Side effects:** None.
- **Algorithm:** `total: replicas.length`, `available: availableCopyCount(replicas)`.
- **Usage:** `_groupedSubtitle` in [`dataset_list_page.md`](dataset_list_page.md#groupedsubtitle);
  `_buildDataSetCard` in [`dataset_topology_page.md`](dataset_topology_page.md).
- **Notes:** None.
