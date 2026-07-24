# Service Topology Layout

Source: `lib/features/services/services/service_topology_layout.dart` (~52 KB,
algorithm-heavy). This page is a high-level description of the approach, not a
line-by-line trace — see [Services and Topology](../features/services-topology.md) for
the feature-level behavior this layout serves.

The entry point is `ServiceTopologyLayout.build(graph, routes, viewportWidth)`, which
returns a `ServiceTopologyLayout` carrying the computed canvas size, a `Rect` per node
(keyed by node id), the rank assigned to each node, and a pre-routed polyline (`List
<Offset>`) per edge — the widget layer just paints these, it does no layout math of its
own.

## Layout constants

Confirmed node/edge sizing constants from source:

```dart
static const nodeWidth = 204.0;
static const nodeHeight = 76.0;
static const portChipSize = 52.0;
static const rankGap = 38.0;
static const verticalGap = 24.0;
static const padding = 24.0;
static const _routingMargin = 72.0;
static const _routingClearance = 14.0;
static const _routingEscape = 18.0;
static const _routingTrackGap = 22.0;
```

`portChipSize` being much smaller than `nodeWidth`/`nodeHeight` reflects the
[Services](../features/services-topology.md#frp-style-ingresspublic-port-modeling)
design of rendering endpoint/remote-entry ports as small rounded-square chips distinct
from primary device/service/domain node cards.

## Semantic layered layout with dynamic graph ranks

Rather than fixed role columns, node horizontal position ("rank") is derived from the
actual edge graph and then compressed so unused ranks don't stretch the canvas:

- **`_nodeRanks(graph, validEdges)`** — a rank-propagation pass: starting every node at
  rank 0, it walks edges repeating `ranks[edge.to] = max(ranks[edge.to], ranks[edge.from]
  + 1)` (capped by `rankLimit = max(2, nodeCount + 1)` to guarantee termination even on
  a graph with a cycle), then remaps the resulting sparse rank values down to a dense
  `0..N` sequence (`uniqueRanks.toSet().toList()..sort()`).
- **`_alignSiblingPortRanks(edges, nodeMap, ranks)`** — a secondary pass that pulls
  sibling port nodes (e.g. the FRP ingress/public port pair described in
  [Services](../features/services-topology.md#frp-style-ingresspublic-port-modeling))
  to the same rank as each other when their natural propagated ranks would otherwise
  separate them, so paired ports read as a visual unit.
- **`_placeNodes(graph, nodeRanks, desiredRows)`** — places nodes into rank columns
  (`rankX`), and within each rank, **compacts rows** via `_compactRankRows` /
  `_compactDesiredRows` / `_compactRowValueMap` so blank vertical bands that only exist
  because *other* ranks needed those rows don't waste space in *this* rank. Row
  matching for the sparse-to-compact remap uses a small floating-point tolerance
  (`_rowEpsilon`) via `_compactRowValue`.
- **`_routeRows(graph, routes, nodeMap)`** and **`_desiredRows(...)`** derive each
  node's preferred row from which route(s) it participates in, so nodes belonging to
  the same access route tend to land on the same visual row/lane.

## Edge routing: fast clear-path first, A* fallback

**`_routeEdges(validEdges, rects, ranks, size)`** is the entry point for edge routing.
It builds an obstacle list from every node `Rect` (via
`_RoutingGridBase.fromObstacles(obstacles, size)` — a shared routing-grid/track
structure reused across all edge searches so obstacle-derived tracks aren't
recomputed per edge) and, for every edge, calls **`_routeEdge`**, which:

1. Computes candidate anchor pairs (which side of the "from" node to exit, which side
   of the "to" node to enter) via `_portOffsets`, ordered so same-rank/adjacent-rank
   edges get sensible anchor choices first.
2. For each candidate anchor pair, computes explicit **exit/entry stubs** — short
   perpendicular segments that force the path to leave/enter each node's edge
   perpendicular to its border (`_stubBlocked` checks whether a stub is itself blocked
   by an obstacle, using `_routingEscape`/`_routingClearance` as clearance margins).
3. Tries **`_fastRouteBetween`** first — a cheap, direct clear-path check between the
   escaped start/end points (the common case: most edges in a real topology don't need
   full pathfinding because there's simply nothing between two nodes on the same or
   adjacent rank).
4. Falls back to **`_routeBetween`** — an obstacle-avoiding orthogonal search
   implemented as a priority-queue search (`_RouteHeap` over `_RouteState` — effectively
   an A* search over grid states) when the fast path is blocked. Its cost function
   combines Manhattan distance (`_manhattan`) with a **turn cost** (penalizing direction
   changes) and a **congestion cost** (`_congestionCost`, penalizing paths that run
   close to or overlap already-routed segments from earlier edges), so multiple edges
   sharing a corridor spread out into distinct parallel tracks instead of overlapping.
5. Candidate full paths are scored (fewer turns, less congestion preferred) and
   validated end-to-end against every obstacle before being accepted
   (`_isSegmentPathClear`-style full-path obstacle check, referenced near the "Check
   whether every segment in a candidate polyline avoids obstacles" doc comment).

Node obstacles used during routing are **inflated** slightly beyond the node's visible
`Rect` (via the `_routingClearance`/`_routingMargin` constants) so routed paths keep a
visible gap from node borders rather than touching them, and shared "routing tracks"
derived once from the obstacle layout (`_RoutingGridBase`) are reused across edges to
keep same-column/adjacent-column parallel edges from colliding.

## Performance notes

Per `AGENTS.md`'s version history (`v0.5.12`), the full-screen topology view defers this
entire layout pass until after the first frame, and caches the result keyed by graph
identity, routes, viewport width, and rotation state — so switching between select/move
modes or rotating the view doesn't force a re-layout unless the underlying graph or
viewport actually changed. Trying the fast clear-path route before falling back to the
full A*-style search is itself a performance optimization: most edges in practice never
need the more expensive search.

## Related

- [Services and Topology](../features/services-topology.md) — the feature this layout
  renders (overview/by-device/route/port views, FRP port-chip modeling, quick
  access-route creation).
- [Service Topology Walkthrough](../examples/service-topology-walkthrough.md) — a
  worked example whose route/hop structure this layout would render.
