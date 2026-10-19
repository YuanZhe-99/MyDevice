# lib/features/datasets/services/dataset_insight_facts.dart

The pure fact builder behind the Data Sets list's on-device AI insight card, added in 1.11.1.
`buildDatasetInsightFacts` turns the data sets and devices the
[Data Sets page](../views/dataset_list_page.md) already holds into
[`InsightFacts`](../../ai/services/insight_prompts.md): how many data sets have no, exactly one,
or two or more available copies, how many keep their copies all on one device, how many have a
copy on a degraded RAID array or on a retired or sold device, and the two highest-risk data sets.
Copies come from [`resolveReplicas`](dataset_placement.md) and count as `availableCopyCount`
counts them, so the card agrees with the list's copy summary. The card itself is
[`AiInsightCard`](../../ai/widgets/ai_insight_card.md). See
[On-device AI — What each card is given](../../../../on-device-ai.md#what-each-card-is-given).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `datasetInsightMaxNames` | top-level `const int` | B | How many at-risk data sets the facts name at most (2). |
| `datasetInsightSlots` | top-level `const List<InsightSlot>` | B | The card's three slots: `redundancySummary`, `healthRisk`, `backupAdvice`. |
| [`buildDatasetInsightFacts`](#builddatasetinsightfacts) | top-level function | A | Build the datasets card's facts. |

`grep -c 'Purpose:' lib/features/datasets/services/dataset_insight_facts.dart` reports 1,
matching `buildDatasetInsightFacts`; the two constants carry a plain `///` description.

## Documentation

### `InsightFacts? buildDatasetInsightFacts({required DateTime now, required List<DataSet> datasets, required List<Device> devices, bool includeNames = true})` <a id="builddatasetinsightfacts"></a>
- **Kind:** top-level function
- **Source:** `lib/features/datasets/services/dataset_insight_facts.dart`
- **Purpose:** Build the datasets card's facts.
- **Inputs:** `now` — local time; `datasets`; `devices` — the current device list;
  `includeNames` — false for the fallback that names no data set.
- **Returns:** `InsightFacts?` with module `datasets` — null when there are no data sets.
- **Side effects:** None.
- **Notes:**
  1. For each data set, resolve its replicas and keep the available ones; count it under none,
     one or two-or-more, and as single-device when two or more available copies share one
     `device.id` — one machine failing loses them all.
  2. Count data sets with any replica on a `degraded` place and with any replica on a device that
     is not in service. Placement ignores lifecycle; the card reports it instead of changing what
     counts.
  3. Rank data sets with fewer than two distinct holding devices by available copies, then
     devices, then name, and name the first two (clipped to 30 characters, added to
     `quotedTerms`) — or describe them without names when `includeNames` is false.
  4. Device names, emoji, capacities, notes and paths are never sent.
