# Service Topology Layout

Source: `lib/features/services/services/service_topology_layout.dart` (algorithm-heavy).
This page is a high-level description of the approach, not a line-by-line trace — see
[Services and Topology](../features/services-topology.md) for the feature-level behavior
this layout serves, and the
[function page](../functions/features/services/services/service_topology_layout.md) for
every declaration.

The entry point is `ServiceTopologyLayout.build(graph, routes, viewportWidth, {options})`,
which returns a `ServiceTopologyLayout` carrying the computed canvas size, a `Rect` per node
(keyed by node id), the rank assigned to each node, a pre-routed polyline (`List<Offset>`)
per edge and, when devices are grouped, the device containers (`groupRects`) and the edges
the containers imply (`hiddenEdges`). The widget layer just paints these — it does no
layout math of its own.

## Options

`ServiceTopologyLayoutOptions` holds the switches of one layout. It has value equality,
because the page's layout cache key includes it.

| Option | Default | Effect |
|---|---|---|
| `groupByDevice` | `false` (the topology page turns it **on** and offers a toggle) | Draw each device that hosts a service as a container around its members. |
| `alignDomainSinks` | `true` | Put every final domain on the last rank. |
| `crossingSweeps` | `4` | Barycenter sweeps that may reorder ranks to remove crossings; `0` keeps the row-based order. |

The class default for `groupByDevice` is off so a bare `build` call routes every edge,
including the device-to-service edges that grouping hides.

## Layout constants

```dart
static const nodeWidth = 204.0;
static const nodeHeight = 76.0;
static const portChipSize = 52.0;
static const rankGap = 38.0;
static const verticalGap = 24.0;
static const padding = 24.0;
static const rowGap = 36.0;
static const containerHeaderHeight = 40.0;
static const containerPadding = 12.0;
static const _routingMargin = 72.0;
static const _routingClearance = 14.0;
static const _routingEscape = 18.0;
static const _routingTrackGap = 22.0;
```

`portChipSize` being much smaller than `nodeWidth`/`nodeHeight` reflects the
[Services](../features/services-topology.md#frp-style-ingresspublic-port-modeling)
design of rendering endpoint/remote-entry ports as small rounded-square chips distinct
from primary device/service/domain node cards. `containerPadding` stays below half of
`rankGap`, so containers in neighbouring rank columns never touch.

## Pipeline

1. **Device groups** (only with `groupByDevice`): a device is grouped when at least one
   service node carries its id. Its members are the service, endpoint and remote-entry
   nodes with that device id. The device-to-service edges of a grouped device go into
   `hiddenEdges`: the container says the same thing, so they are neither routed nor
   painted. A device that hosts nothing — a router a port-forward hop names — stays a
   plain card, and its remote entry stays a free chip.
2. **Route rows** — `_routeRows` gives each route a row on a virtual axis, grouped by
   source service. With grouping, sources are ordered by device first (local devices by
   name, then remote ones), so a device's services take a contiguous band of rows.
3. **Desired rows** — `_desiredRows` derives each node's preferred row from its routes
   (median), then from its neighbours, then a stable fallback.
4. **Ranks** — see [Semantic ranks](#semantic-ranks).
5. **Placement** — see [Rows, order and y positions](#rows-order-and-y-positions).
6. **Containers** — see [Device containers](#device-containers).
7. **Edge routing** over the drawn (not hidden) edges — see
   [Edge routing](#edge-routing-fast-clear-path-first-a-fallback).

## Semantic ranks

Rather than fixed role columns, a node's horizontal position ("rank") is derived from the
actual edge graph and then compressed so unused ranks don't stretch the canvas:

- **`_nodeRanks`** — devices start at rank 0, every other node at rank 1; each edge pushes
  its target one rank past its source (capped by `rankLimit = max(2, nodeCount + 1)`, so
  a cycle terminates). **`_alignSiblingPortRanks`** runs inside the same loop and pulls
  sibling port chips of one service (the FRP ingress and public port, see
  [Services](../features/services-topology.md#frp-style-ingresspublic-port-modeling)) to
  the same rank.
- **Domain sink alignment** (`alignDomainSinks`): after propagation, every domain node
  without outgoing edges is moved to the highest rank, so final addresses read as one
  column on the right instead of being scattered by chain length.
- The sparse ranks are then densified to `0..N`.
- **`_headerRanks`** (only with grouping): grouped device nodes leave the columns — they
  become container headers — and the remaining ranks are densified again, so a column that
  held only devices (usually rank 0) disappears. A header's rank is its first member's.

## Rows, order and y positions

`_placeNodes` places every node that sits in a rank column:

- Each rank's nodes are sorted by desired row, then role, lane and label, and their rows
  are compacted **per rank** (`_compactRankRows`), so blank bands that only other ranks
  needed don't waste space here.
- With grouping, `_keepGroupsTogether` moves each container's members in a rank up to its
  first member, and the rank's sorted row values are handed out again in the new order.
- **Crossing sweep** (`_sweepCrossings`, up to `crossingSweeps` passes): alternating down
  and up passes reorder each rank by the barycenter — the mean row of the node's
  neighbours on lower ranks (down) or higher ranks (up); a container's members move as one
  block. The rank's sorted row values are handed out in the new order, so rows are only
  permuted and chains that were straight stay straight. A new order is kept only when it
  **strictly lowers** the total crossing count, so the sweep can never make a graph
  worse; it stops early after a pass without improvement.
- **Crossing count** (`countCrossings`, public so it can be tested): for every pair of
  edges, sample both on each rank line they span (a long edge's position is interpolated
  linearly) and count the times their order swaps. Edges that only share an end do not
  count; edges within one rank are ignored. The layout reports the count it ends with as
  `crossings`.
- **Row heights** (`_rowPositions`): each distinct row value is as tall as its tallest
  node on any rank; the next value starts `(next − this) × (height + rowGap)` lower. A row
  of cards therefore has a 112 px stride (the old fixed stride was 120), a row of port
  chips only 88, and fractional gaps from compaction keep their proportion.
- Within a rank, a node never starts less than `verticalGap` below the one above it; x is
  centred in the rank's column.

## Device containers

`_placeContainers` walks every free node and every container in the order of its top in
the flat placement — a container by its highest member, before free nodes on a tie — and
keeps a **floor** per rank:

- A free node is moved down by the running shift, and below its rank's floor.
- A container spans its members' ranks and starts below every floor there. Its members go
  back to their row targets relative to the highest member (so a member doesn't keep a gap
  another device's node left above it), under a `containerHeaderHeight` header plus
  `containerPadding`; members of one rank still stack at least `verticalGap` apart.
  Whatever the container adds is added to the running shift for everything after it, so
  rows below stay aligned across ranks. The container then raises the floor of every rank
  it spans to its bottom, so a free node in those ranks lands below it.
- The header is a tab on the container's top-left, `containerHeaderHeight` tall and at most
  `nodeWidth` wide; it is the device node's rect, so edges into a grouped device (a
  port-mapping hop naming the device) end on the header. Keeping the tab narrow lets edges
  enter the container from above.

Invariants, each covered by a test on the sample, FRP-walkthrough and shared-VPS graphs:
every member lies inside its container and below the header; no other node meets a
container; containers never overlap; every drawn edge avoids every node but its own ends;
`hiddenEdges` is exactly the device-to-service edges of grouped devices; with grouping off
there are no containers and no hidden edges. The pass is constructive, so it needs no
fallback.

The painter draws containers under the edges: a low-alpha fill in the device role's
colour, a thin border — dashed for a remote device or a VPS — and the header card on top.

## Edge routing: fast clear-path first, A* fallback

**`_routeEdges(edges, rects, ranks, size)`** builds an obstacle list from every node `Rect`
(inflated by `_routingClearance`, so paths keep a visible gap from borders), a shared
routing-grid base (`_RoutingGridBase.fromObstacles`, reused by every search), and for every
edge — longest first — calls **`_routeEdge`**, which:

1. Computes candidate anchor pairs (which side of each node to leave and enter), with
   per-edge offsets from `_portOffsets` so edges sharing a side fan out.
2. For each candidate, adds explicit **exit/entry stubs** — short perpendicular segments
   (`_routingEscape`) so paths leave and enter cards perpendicularly; a blocked stub
   (`_stubBlocked`) drops the candidate.
3. Tries **`_fastRouteBetween`** first: straight, L, Z and around-the-box shapes checked
   against every obstacle. Most edges end here.
4. Falls back to **`_routeBetween`**, an A* search over the grid of obstacle-derived and
   segment-derived tracks. Its cost adds Manhattan length, a **turn cost** and a
   **congestion cost** (reusing a routed segment's line costs 180, running parallel within
   0.85 × the track gap 58, crossing one 28), so edges sharing a corridor spread onto
   parallel tracks.
5. Scores the candidates (`_pathScore`: length, turns, congestion) and keeps the best.

Routed segments are kept in **`_RoutedSegments`**, indexed by axis coordinate, so the
congestion cost of a candidate step only visits the segments in its band (binary search)
instead of every segment routed so far. Within one A* search, each grid step's length plus
congestion — or the fact that it is blocked — is computed once and cached (a step is
reached from both ends and in several directions), and the search's arrays are typed
(`Float64List`, `Int32List`). All costs are multiples of 0.5, so none of this changes a
single path; it only removes repeated work. On a developer machine a 43-node, 64-edge graph
that took over 20 seconds before 1.5.6 now lays out in about a second without grouping and
about 0.2 s with it; the 61-node, 91-edge graph of the performance test takes about 3.4 s
and 0.4 s.

## Performance notes

The full-screen topology defers the whole layout until after the first frame and caches
the result keyed by graph identity, routes identity, viewport width (rotation-aware) and the
layout options — so switching between select/move modes or selecting a node doesn't
re-lay out, while toggling "Group by device" re-lays out the same graph without rebuilding
it. Layout runs on the UI isolate; moving it to `compute()` would need index- or value-keyed
edge paths first, because `edgePaths` and `hiddenEdges` are keyed by `ServiceTopologyEdge`
identity.

## Related

- [Services and Topology](../features/services-topology.md) — the feature this layout
  renders (overview/by-device/route/port views, FRP port-chip modeling, the guided
  access-path page).
- [Service Topology Walkthrough](../examples/service-topology-walkthrough.md) — a
  worked example whose route/hop structure this layout renders.
