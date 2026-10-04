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
static const _sidePenalty = 120.0;  // 1.8.3
static const _alignSnap = 12.0;     // 1.8.3
static const _trackSpacing = 8.0;   // 1.8.3
static const _minStub = 18.0;       // 1.8.3
static const _alignPasses = 9;      // 1.8.3
const _nearLine = 4.0;              // 1.8.3, top level
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
5. **Placement** — see [Rows, order and y positions](#rows-order-and-y-positions) and
   [Aligning connected nodes](#aligning-connected-nodes).
6. **Containers** — see [Device containers](#device-containers); then the nodes outside every
   container are aligned again and the drawing is lifted back to the top.
7. **Edge routing** over the drawn (not hidden) edges — see
   [Edge routing](#edge-routing-fast-clear-path-first-a-fallback).
8. **Tracks** — vertical runs that share a gap are spread onto parallel tracks, widening the gap
   when needed — see [Spreading edges onto tracks](#spreading-edges-onto-tracks).

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
- These row positions are only where alignment starts (1.8.3).

## Aligning connected nodes

Row compaction is rank-local, so the same desired row can land at different heights in two
neighbouring ranks. In 1.8.2 a service without a port chip (say, one reached straight through
Tailscale) moved every chip below it a row away from its own service, and each short
service-to-chip edge became a staircase. Since 1.8.3, `_alignRanks` assigns the y coordinates the
way the coordinate-assignment step of a layered (Sugiyama / Brandes–Köpf) drawing does: it keeps
every rank's order, so `crossings` does not change, and moves nodes towards what they connect to.

- **What each node asks for** (`_desiredCenter`):
  - A *port chip* — a compact endpoint of its own service, or a remote entry a service leads to
    (`_portOwners`) — asks for its service's centre.
  - Any other node asks for the median centre of its neighbours on other ranks.
  - A service looks past its own chips to what they connect to, so a service and its chips move
    as one block.
- **How a rank is placed** (`_pava`, the pool-adjacent-violators algorithm): the closest
  positions to those wishes that keep the order and keep consecutive nodes `rowGap` apart (cards
  112, chips 88, as before). It is exact and O(n).
- **Chip spacing** (`_alignGap`): two chips of different services keep at least the distance
  their services need. A service without a chip leaves no chip between its neighbours' chips,
  and without this rule the chip column would pack tighter than the service column.
- **Passes:** `_alignPasses` (9) alternating down and up passes; the last goes down, so chips end
  beside their services' final positions.
- **Settling:** each service settles on the middle of its chips in the next column, while nodes
  without such chips give way (weight 0.01). Then the drawing starts at `padding`.

After the containers are placed, `_alignFreeNodes` repeats this for the nodes outside every
container. `_placeContainers` adds its running shift to every node after a container, even in
ranks no container covers, so in 1.8.2 a domain could end up far below its source. Now each free
node asks for the same centre, and every container covering its rank is a fixed, heavy item in
`_pava`, so a free node keeps its side of every container and never meets one. Domains therefore
sit beside the Tailscale card or the public 443 chip they hang off. Free nodes that move down can
leave the top empty, so the whole drawing is lifted back to `padding`.

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
   per-edge offsets from `_portOffsets` so edges sharing a side fan out. The offsets are spread
   evenly, 9 px apart or closer on a short side, and never clamped onto each other. Then
   `_levelAnchors` makes an edge whose two anchors are within `_alignSnap` exactly level, so
   aligned nodes get a straight line.
2. For each candidate, adds explicit **exit/entry stubs** (`_stubEnd`) — perpendicular
   segments `_routingEscape` long, so paths leave and enter cards perpendicularly. A node
   narrower than its column (a chip among cards) gets a stub that reaches past the column's edge.
   A blocked stub (`_stubBlocked`) drops the candidate.
3. Tries **`_fastRouteBetween`** first: straight, L, Z and around-the-box shapes checked
   against every obstacle. Most edges end here.
4. Also runs **`_routeBetween`**, an A* search over the grid of obstacle-derived and
   segment-derived tracks, when no fast shape is clear or the best one runs along a routed
   horizontal line; the cheaper result wins. The search cost adds:
   - Manhattan length;
   - a **turn cost**;
   - a **congestion cost**: a horizontal run on a routed horizontal line costs 180, one within
     `_nearLine` (4 px) of it 58; a vertical run on a routed vertical line costs only 6, since
     nudging separates those; crossing a segment costs 28.
5. Scores the candidates (`_pathScore`: length, turns, congestion), adds `_sidePenalty` for
   each end on the side facing away from the other end, and keeps the best.

Routed segments are kept in **`_RoutedSegments`**, indexed by axis coordinate, so the
congestion cost of a candidate step only visits the segments in its band (binary search)
instead of every segment routed so far. Within one A* search, each grid step's length plus
congestion — or the fact that it is blocked — is computed once and cached (a step is
reached from both ends and in several directions), and the search's arrays are typed
(`Float64List`, `Int32List`). All costs are multiples of 0.5, so none of this changes a
single path; it only removes repeated work. On a developer machine a 43-node, 64-edge graph
that took over 20 seconds before 1.5.6 now lays out in about a second without grouping and
about 0.2 s with it. The 61-node, 91-edge graph of the performance test took about 4.6 s and
0.6 s in 1.8.2 on the Linux development machine. In 1.8.3 it takes about 1.0 s and 0.3 s, because
vertical sharing no longer pays congestion that sent edges into long A* detours. Alignment and
nudging cost a few milliseconds.

## Spreading edges onto tracks

Ranks are only `rankGap` (38 px) apart, and node rects are inflated by `_routingClearance` (14),
which leaves a 10 px corridor. In 1.8.2 every turn between two neighbouring columns therefore
landed on one shared vertical line: you could not tell which service went to which chip, or which
chip fed Caddy. `_nudgeSegments` fixes this after routing. It combines the *nudging* step of
orthogonal connector routing (libavoid) with the *slot assignment* of layered routers (ELK
Layered):

1. **Cells.** Cut the canvas into cells: each column, the gap after it, and a margin after the
   last column. Small S-jogs inside a gap are straightened first (`_mergeJogs`).
2. **Units.** Each interior vertical run becomes a unit, together with the same path's next runs
   in that cell. Runs that all head the same way merge into one straight run. A unit may not
   come within `_minStub` of the anchors its end runs reach, nor within `_routingClearance` of a
   node beside it.
3. **Order.** In each cell, units whose y-ranges come within two track spacings conflict. Each
   unit is inserted where it crosses the fewest end runs of the units it conflicts with
   (`_crossingsIfLeft`), so a fan-in becomes a comb without crossings.
4. **Tracks.** Each unit takes the track after the highest track of the earlier units it
   conflicts with, and each group of conflicting units is centred `_trackSpacing` (8 px) apart.
5. **Widening.** A gap that is too narrow for its tracks is widened by one monotone stretch of
   every x on the canvas. Nodes and headers move rigidly, containers stretch, and path points in
   the gap scale with it. Since no two x values change order, every path still avoids every node
   it avoided. Only gaps that need it grow, typically by a few tens of pixels.
6. **Horizontal runs.** A horizontal run left lying on another edge's run is moved half a track
   or more up or down (`_separateHorizontals`); a run at an anchor slides its anchor along the
   node's side.
7. **Safety check.** A path that would end up touching a node keeps its unmoved, stretched
   version.

The painter then rounds every bend (`topologyEdgePath` in `service_topology_widgets.dart`,
radius up to 6 px).

## Visual check

`test/service_topology_preview_test.dart` renders the real topology page for the shared fixtures
in `test/support/topology_fixtures.dart` — a replica of a 1.8.2 homelab that drew badly, the
FRP walkthrough, a shared VPS, and the 61-node synthetic graph — grouped and flat. It loads
Roboto and the Material icon font from the Flutter SDK, so text and icons render as in the app.
It writes PNGs and a `metrics.json` (crossings, bends, length, shared-line length, smallest
parallel gap, canvas size, layout ms). The test is skipped unless an output folder is given:

```bash
TOPOLOGY_PREVIEW=build/topology-preview flutter test test/service_topology_preview_test.dart
```

Run it before and after a layout change and compare the images. On the homelab replica, 1.8.3
cut crossings from 22 to 3 and shared-line length from 82 px to 0 grouped, and from 599 px to 0
flat.

## Performance notes

The full-screen topology defers the whole layout until after the first frame and caches
the result keyed by graph identity, routes identity, viewport width (rotation-aware) and the
layout options — so selecting a node, panning or zooming doesn't
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
