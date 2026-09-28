# lib/features/devices/services/finance_insight_facts.dart

The pure fact builder behind the Financial overview's on-device AI insight card, added in 1.6.0.
`buildDeviceFinanceInsightFacts` turns the devices the
[Financial overview](../views/device_finance_overview_page.md) already holds into
[`InsightFacts`](../../ai/services/insight_prompts.md): device and lifecycle counts, total cost of
ownership and total daily cost, cost by category, the highest daily-cost devices in service,
recurring costs split by billing cycle, retired and sold devices with their resale total, and the
oldest devices in service. Totals use the same `Device` getters as the device list's financial
card ([`device.md`](../models/device.md#totalcost)), evaluated at `now`, and money is rounded to
whole units in the default currency. The card itself is
[`AiInsightCard`](../../ai/widgets/ai_insight_card.md), and the facts are fingerprinted by
[`AiInsightStore`](../../ai/services/insight_service.md). See
[On-device AI — What each card is given](../../../../on-device-ai.md#what-each-card-is-given).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `financeInsightMaxNames` | top-level `const int` | B | How many named devices (or categories) one fact line lists at most (3). |
| `financeInsightMaxCategories` | top-level `const int` | B | How many categories the cost-by-category line lists at most (5). |
| `deviceFinanceInsightSlots` | top-level `const List<InsightSlot>` | B | The card's four slots, shared by the full facts and the fallback so the sections apply to both. |
| `_money` | top-level function (private) | B | Format an amount as `<whole units> <currency>`. |
| [`buildDeviceFinanceInsightFacts`](#builddevicefinanceinsightfacts) | top-level function | A | Build the device finance card's facts. |

`grep -c 'Purpose:' lib/features/devices/services/finance_insight_facts.dart` reports 2, matching
`_money` and `buildDeviceFinanceInsightFacts`.

**Reconciliation:** 5 rows against 2 `Purpose:` blocks. The three extra rows are real top-level
constants — `financeInsightMaxNames`, `financeInsightMaxCategories` and
`deviceFinanceInsightSlots` — each with a plain `///` description but no `Purpose:` block. The
slots are, in order: `costSummary` (overall cost and daily-cost picture), `costAdvice` (one
practical suggestion about spending on devices), `recurringSummary` (sum up the recurring costs)
and `reviewDevice` (one device or category worth reviewing, for example to retire or sell).

## Documentation

### `InsightFacts? buildDeviceFinanceInsightFacts({required DateTime now, required List<Device> devices, required String defaultCurrency, bool includeNames = true})` <a id="builddevicefinanceinsightfacts"></a>
- **Kind:** top-level function
- **Source:** `lib/features/devices/services/finance_insight_facts.dart` (line 47)
- **Purpose:** Build the device finance card's facts.
- **Inputs:** `now` — local time; `devices` — the page's devices; `defaultCurrency` — the currency
  code every amount is written in; `includeNames` — false for the plainer fallback that names
  categories only (default true).
- **Returns:** `InsightFacts?` with `module: deviceFinance`, the four
  `deviceFinanceInsightSlots` and the quoted terms — or null when no device has financial data
  (`hasFinancialData`).
- **Side effects:** None.
- **Algorithm:**
  1. Keep the devices with financial data; return null when there are none. Start the quoted
     terms with the currency code. A local `label(d)` returns the category name when
     `includeNames` is false; otherwise the device name clipped to 30 runes
     ([`clipTitle`](../../ai/services/insight_prompts.md#cliptitle)), added to the quoted terms,
     followed by the category in parentheses.
  2. `- Today:`, `- Currency:`, `- Devices:` (all devices, how many have cost data, and the
     in-service / retired / sold counts), `- Total cost of ownership to date:` (sum of
     `totalCost(asOf: now)`) and `- Total daily cost:` (sum of `averageDailyCost(asOf: now)`, two
     decimals, `<currency> per day`).
  3. `- Cost by category:` — positive per-device totals only, the same rule as the
     asset-distribution chart; categories sorted by total, at most `financeInsightMaxCategories`,
     each with its device count.
  4. `- Highest daily-cost devices in service:` — in-service devices with a positive daily cost,
     highest first, at most `financeInsightMaxNames`, each as `label` plus the daily cost.
  5. `- Recurring costs on devices in service:` — `none`, or the entry and device counts, the
     kinds by count, the monthly-billed and yearly-billed totals (`price.convertedAmount`) and the
     combined yearly total (`monthly × 12 + yearly`).
  6. `- Retired or sold:` — the retired count, the sold count, how many sold devices have a resale
     price and the resale total (`soldPrice.convertedAmount`).
  7. `- Oldest devices in service:` — in-service devices with a purchase date, oldest first, at
     most `financeInsightMaxNames`, each as `label`, `since <date>` and its `serviceDays`.
  8. Return `InsightFacts(module: InsightModule.deviceFinance, lines, slots:
     deviceFinanceInsightSlots, quotedTerms)`.
- **Usage:**
  ```dart
  InsightFacts? facts({required bool names}) =>
      buildDeviceFinanceInsightFacts(
        now: now,
        devices: widget.devices,
        defaultCurrency: widget.defaultCurrency,
        includeNames: names,
      );
  ```
  (`lib/features/devices/views/device_finance_overview_page.dart`, `build`, line 123: the full
  facts are `facts(names: true)` and the `fallbackFacts` are `facts(names: false)`; covered by
  `test/insight_facts_test.dart`, group `device finance facts`.)
- **Notes:** Only aggregates in the default currency, category and kind enum names and (when
  `includeNames`) device names are sent. The builder never reads a serial number, a note, a
  location, a brand or model, a storage serial or a recurring cost's name. The currency code is
  always quoted because the instructions make the model write amounts with it; otherwise a short
  Chinese or Japanese sentence with a few amounts would fail the script check on the code's Latin
  letters. Whole-unit rounding keeps the fingerprint stable against tiny rate changes; `now`
  enters the facts through `- Today:` and every `asOf: now` total, so the card regenerates at
  midnight.
