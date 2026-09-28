# lib/features/services/services/service_insight_facts.dart

The pure fact builder behind the Services Overview's on-device AI insight card, added in 1.6.0.
`buildServiceInsightFacts` turns the services, access paths, devices and networks the
[Services page](../views/service_list_page.md) already holds into
[`InsightFacts`](../../ai/services/insight_prompts.md): counts of services by state, kind and
runtime, host devices (and how many are retired or sold), endpoints by protocol and scope,
distinct listening ports and port conflicts, access paths by access level and hop method, the
networks endpoints reference, warnings by kind, and duplicate names and final URLs. It sends
**counts and enum names only**. Port conflicts and warnings come from the same
[`service_analysis`](service_analysis.md) functions the Overview shows, so the card and the list
agree. The card itself is [`AiInsightCard`](../../ai/widgets/ai_insight_card.md), and the facts are
fingerprinted by [`AiInsightStore`](../../ai/services/insight_service.md). See
[On-device AI — What each card is given](../../../../on-device-ai.md#what-each-card-is-given).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `serviceInsightMaxBreakdown` | top-level `const int` | B | How many values one breakdown line lists at most, largest first (5). |
| `serviceInsightSlots` | top-level `const List<InsightSlot>` | B | The card's three slots: `setupSummary`, `warningAdvice`, `exposureAdvice`. |
| `serviceInsightTechTerms` | top-level `const List<String>` | B | Product and protocol names a reply may keep in Latin letters; passed as quoted terms. |
| [`_breakdown`](#_breakdown) | top-level function (private) | A | Render a count breakdown as `a 3, b 1` for a fact line. |
| `_countBy` | top-level function (private) | B | Count items by a string key. |
| [`buildServiceInsightFacts`](#buildserviceinsightfacts) | top-level function | A | Build the services card's facts. |

`grep -c 'Purpose:' lib/features/services/services/service_insight_facts.dart` reports 3,
matching `_breakdown`, `_countBy` and `buildServiceInsightFacts`.

**Reconciliation:** 6 rows against 3 `Purpose:` blocks. The three extra rows are real top-level
constants — `serviceInsightMaxBreakdown`, `serviceInsightSlots` and `serviceInsightTechTerms` —
each with a plain `///` description but no `Purpose:` block. `serviceInsightTechTerms` lists
longer names before the shorter names they contain (`Cloudflare Tunnel` before `Cloudflare`,
`HTTPS` before `HTTP`), because quoted terms are removed in order before the script check.

## Documentation

### `String _breakdown(Map<String, int> counts)` <a id="_breakdown"></a>
- **Kind:** top-level function (private)
- **Source:** `lib/features/services/services/service_insight_facts.dart` (line 66)
- **Purpose:** Render a count breakdown as `a 3, b 1` for a fact line.
- **Inputs:** `counts` — value name to count.
- **Returns:** `String` — `none` when `counts` is empty; otherwise `<name> <count>` entries joined
  with `, `, largest first, at most `serviceInsightMaxBreakdown`, followed by `<n> more` when
  entries were left out.
- **Side effects:** None.
- **Algorithm:** Sort the entries by count descending, then by name ascending; take the first
  `serviceInsightMaxBreakdown`; append `'$rest more'` when any remain; join.
- **Usage:** `'${_breakdown(_countBy(services, (s) => s.kind.name))}'` and every other breakdown
  in [`buildServiceInsightFacts`](#buildserviceinsightfacts); also `_breakdown(methods)` for the
  hop methods.
- **Notes:** The name tie-break makes the line — and so the fingerprint — independent of map
  iteration order.

### `InsightFacts? buildServiceInsightFacts({required DateTime now, required List<ServiceNode> services, required List<ServiceRoute> routes, required List<Device> devices, required List<Network> networks})` <a id="buildserviceinsightfacts"></a>
- **Kind:** top-level function
- **Source:** `lib/features/services/services/service_insight_facts.dart` (line 105)
- **Purpose:** Build the services card's facts.
- **Inputs:** `now` — local time; the page's `services`, `routes` (access paths), `devices` and
  `networks`.
- **Returns:** `InsightFacts?` with `module: services`, the three `serviceInsightSlots` and
  `quotedTerms: serviceInsightTechTerms` — or null when there are no services.
- **Side effects:** None.
- **Algorithm:**
  1. Return null when `services` is empty. Collect the endpoints of every service and the set of
     host device ids; count the hosts whose device exists and is not in service.
  2. Port facts: `listServicePortUses(services)` counted as distinct `deviceId|transport|port`
     triples; `findServicePortConflicts(services)` split into definite and potential (see
     [`service_analysis.md`](service_analysis.md#findserviceportconflicts)).
  3. `findServiceReferenceWarnings(services:, routes:, devices:, networks:)`
     ([`service_analysis.md`](service_analysis.md#findservicereferencewarnings)).
  4. Walk the routes: total hop count and a count of hop methods (`h.method?.name`). Collect the
     distinct network ids the endpoints reference. Count services whose trimmed, lower-cased name
     repeats on one device (by `deviceId|name`) and warnings of kind `duplicateFinalUrl`.
  5. Lines: `- Today:`; `- Services:` with a breakdown by `state`; `- Services by kind:`;
     `- Runtimes:` (`unspecified` when none); `- Hosts:`; `- Endpoints:` by `protocol` and `scope`;
     `- Distinct listening ports:` with definite and potential conflicts; `- Access paths:` —
     `none`, or the count by `accessLevel`, by method and the average hop count
     ([`factNumber`](../../ai/services/insight_prompts.md#factnumber)); `- Networks referenced by
     endpoints:`; `- Warnings:` by kind; `- Duplicates:`.
  6. Return `InsightFacts(module: InsightModule.services, lines, slots: serviceInsightSlots,
     quotedTerms: serviceInsightTechTerms)`.
- **Usage:**
  ```dart
  final facts = buildServiceInsightFacts(
    now: now,
    services: _services,
    routes: _routes,
    devices: _devices,
    networks: _networks,
  );
  ```
  (`lib/features/services/views/service_list_page.dart`, `_buildOverview`, line 454; no
  `fallbackFacts`. Covered by `test/insight_facts_test.dart`, group `service facts`.)
- **Notes:** The builder never sends a service or access-path name, a bind address, a path, a URL,
  a hop host, a port number, a tag, a note or a compose file; names are read only to count
  duplicates. Every breakdown goes through [`_breakdown`](#_breakdown), so equal inputs give an
  equal canonical form. Because no user-typed word is sent, the quoted terms are only the fixed
  tech names, which let a Chinese or Japanese sentence keep names such as `Caddy` or `Tailscale
  Funnel` without failing the script check.
