# lib/features/services/services/service_topology_layout.dart

`ServiceTopologyLayout` is a pure, static layout/routing engine for the services-topology graph
view: given a `ServiceTopologyGraph` (nodes/edges, from `service_analysis.dart`), the
`ServiceRoute` list that produced it, and a `ServiceTopologyLayoutOptions`,
`ServiceTopologyLayout.build` computes a canvas `Size`, a `Rect` per node, an integer rank per
node, a pre-routed orthogonal polyline (`List<Offset>`) per drawn edge, and — when the options
group by device — a container `Rect` per grouped device (`groupRects`) plus the device→own-service
edges the containers imply (`hiddenEdges`, neither routed nor painted). Between rank assignment
and y placement, a barycenter crossing sweep may reorder each rank; the crossings it leaves are
reported as `crossings`. The widget layer (`_ServiceTopologyView` in
[`../views/service_topology_page.md`](../views/service_topology_page.md) and the painter and
node cards in [`../views/service_topology_widgets.md`](../views/service_topology_widgets.md),
in `lib/features/services/views/service_topology_page.dart` /
`service_topology_widgets.dart`) only paints these precomputed values — containers under the
edges, grouped device nodes as header tabs — and does no layout or pathfinding of its own; the
result is cached per graph/routes/viewport/options so switching modes doesn't force a relayout.
This is the most algorithm-dense file in the app: most of its private helpers implement graph-rank
propagation, row compaction, crossing reduction, container placement, or orthogonal A*-style
pathfinding rather than widget composition.

See [Service Topology Layout](../../../../algorithms/service-topology-layout.md) for the
high-level description of the pipeline (semantic ranking, device containers, the crossing sweep,
and fast-clear-path-first orthogonal routing with an A* fallback) and
[Services and Topology](../../../../features/services-topology.md) for the feature this layout
renders.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ServiceTopologyLayoutOptions` | class | B | The switches of one layout; value-equal because it is part of the page's layout cache key. |
| `groupByDevice` | field (`ServiceTopologyLayoutOptions`) | B | Draw each device that hosts a service as a container around its members. |
| `alignDomainSinks` | field (`ServiceTopologyLayoutOptions`) | B | Move every domain node without outgoing edges to the last rank. |
| `crossingSweeps` | field (`ServiceTopologyLayoutOptions`) | B | Barycenter sweep limit; 0 keeps the row-based order. |
| `ServiceTopologyLayoutOptions.new` | constructor (`ServiceTopologyLayoutOptions`) | B | Const constructor; defaults `groupByDevice: false`, `alignDomainSinks: true`, `crossingSweeps: 4`. |
| `operator ==` | operator (`ServiceTopologyLayoutOptions`) | B | Value equality over the three fields. |
| `hashCode` | getter (`ServiceTopologyLayoutOptions`) | B | `Object.hash` of the three fields, consistent with `==`. |
| `ServiceTopologyLayout` | class | B | Immutable layout result: canvas size, node rects, ranks, edge paths, containers, hidden edges, crossings. |
| `size` | field (`ServiceTopologyLayout`) | B | Computed canvas size for the topology. |
| `nodeRects` | field (`ServiceTopologyLayout`) | B | Node id → placed `Rect` (a grouped device's rect is its header tab). |
| `nodeRanks` | field (`ServiceTopologyLayout`) | B | Node id → assigned integer rank (column). |
| `edgePaths` | field (`ServiceTopologyLayout`) | B | Drawn edge → pre-routed orthogonal polyline (identity-keyed). |
| `groupRects` | field (`ServiceTopologyLayout`) | B | Device node id → container rect; empty without grouping. |
| `hiddenEdges` | field (`ServiceTopologyLayout`) | B | Identity set of device→own-service edges the containers imply; not routed or painted. |
| `crossings` | field (`ServiceTopologyLayout`) | B | Crossings between ranks left after the sweep, as `countCrossings` measures them. |
| `ServiceTopologyLayout.new` | constructor (`ServiceTopologyLayout`) | B | Const constructor: four required fields; `groupRects`/`hiddenEdges` default empty, `crossings` 0. |
| `nodeWidth` | static const (`ServiceTopologyLayout`) | B | Default node card width (204.0). |
| `nodeHeight` | static const (`ServiceTopologyLayout`) | B | Default node card height (76.0). |
| `portChipSize` | static const (`ServiceTopologyLayout`) | B | Compact port-chip width/height (52.0). |
| `rankGap` | static const (`ServiceTopologyLayout`) | B | Horizontal gap between rank columns (38.0). |
| `verticalGap` | static const (`ServiceTopologyLayout`) | B | Minimum vertical gap between stacked nodes (24.0). |
| `padding` | static const (`ServiceTopologyLayout`) | B | Canvas edge padding (24.0). |
| `rowGap` | static const (`ServiceTopologyLayout`) | B | Space between rows beyond the taller node of the upper row (36.0). |
| `containerHeaderHeight` | static const (`ServiceTopologyLayout`) | B | Height of a device container's header tab (40.0). |
| `containerPadding` | static const (`ServiceTopologyLayout`) | B | Container inner margin around members and under the header (12.0). |
| `_routingMargin` | static const (`ServiceTopologyLayout`) | B | Extra canvas margin reserved for routed edges (72.0). |
| `_routingClearance` | static const (`ServiceTopologyLayout`) | B | Obstacle inflation applied to node rects during routing (14.0). |
| `_routingEscape` | static const (`ServiceTopologyLayout`) | B | Length of the perpendicular exit/entry stub at each node (18.0). |
| `_routingTrackGap` | static const (`ServiceTopologyLayout`) | B | Spacing between parallel routing tracks/lanes (22.0). |
| [`build`](#build) | static method (`ServiceTopologyLayout`) | A | Compute node positions, containers, and pre-routed edge paths for a topology graph. |
| [`_deviceGroups`](#_devicegroups) | static method (`ServiceTopologyLayout`) | A | Find the devices drawn as containers and their member node ids. |
| [`_headerRanks`](#_headerranks) | static method (`ServiceTopologyLayout`) | A | Re-densify ranks once grouped device nodes leave the columns. |
| [`_placeNodes`](#_placenodes) | static method (`ServiceTopologyLayout`) | A | Place nodes into rank columns, reduce crossings, and turn rows into y positions. |
| [`_keepGroupsTogether`](#_keepgroupstogether) | static method (`ServiceTopologyLayout`) | A | Reorder one rank so each container's members are contiguous. |
| [`_rowPositions`](#_rowpositions) | static method (`ServiceTopologyLayout`) | A | Turn compact row values into content-sized y positions. |
| [`_sweepCrossings`](#_sweepcrossings) | static method (`ServiceTopologyLayout`) | A | Reduce edge crossings with alternating barycenter sweeps. |
| [`_orderPositions`](#_orderpositions) | static method (`ServiceTopologyLayout`) | A | Give each placed node a strictly ordered position within its rank. |
| [`countCrossings`](#countcrossings) | static method (`ServiceTopologyLayout`) | A | Count edge-pair order swaps across rank lines (public for tests). |
| [`_placeContainers`](#_placecontainers) | static method (`ServiceTopologyLayout`) | A | Draw device containers around their members and place header tabs. |
| [`_compactRankRows`](#_compactrankrows) | static method (`ServiceTopologyLayout`) | A | Compact desired rows within one rank before turning them into y positions. |
| [`_compactDesiredRows`](#_compactdesiredrows) | static method (`ServiceTopologyLayout`) | A | Remove row gaps only reserved by routes without visible nodes. |
| [`_compactRowValueMap`](#_compactrowvaluemap) | static method (`ServiceTopologyLayout`) | A | Build a compact value map from sparse desired-row values. |
| [`_compactRowValue`](#_compactrowvalue) | static method (`ServiceTopologyLayout`) | A | Look up a compacted row value for one raw desired row. |
| [`_nodeRanks`](#_noderanks) | static method (`ServiceTopologyLayout`) | A | Propagate, optionally align domain sinks, and densify the per-node rank. |
| [`_alignSiblingPortRanks`](#_alignsiblingportranks) | static method (`ServiceTopologyLayout`) | A | Pull sibling ingress/public port nodes to the same rank. |
| `_nodeWidth` | static method (`ServiceTopologyLayout`) | B | Node card width, or `portChipSize` when the node is compact. |
| `_nodeHeight` | static method (`ServiceTopologyLayout`) | B | Node card height, or `portChipSize` when the node is compact. |
| [`_routeRows`](#_routerows) | static method (`ServiceTopologyLayout`) | A | Assign each route a preferred row along a virtual row axis. |
| [`_desiredRows`](#_desiredrows) | static method (`ServiceTopologyLayout`) | A | Derive each node's preferred row from its routes/neighbors. |
| [`_routeEdges`](#_routeedges) | static method (`ServiceTopologyLayout`) | A | Entry point: route every drawn edge into an orthogonal polyline. |
| [`_portOffsets`](#_portoffsets) | static method (`ServiceTopologyLayout`) | A | Fan out edges sharing a node side into distinct perpendicular offsets. |
| [`_routeEdge`](#_routeedge) | static method (`ServiceTopologyLayout`) | A | Route one edge, trying anchor-side candidates in preference order. |
| [`_fastRouteBetween`](#_fastroutebetween) | static method (`ServiceTopologyLayout`) | A | Try cheap direct/L/Z/around-the-box candidates before A*. |
| [`_routeBetween`](#_routebetween) | static method (`ServiceTopologyLayout`) | A | Obstacle-avoiding orthogonal A*-style grid search (fallback router). |
| [`_pathScore`](#_pathscore) | static method (`ServiceTopologyLayout`) | A | Score a routed path by length, turns, and congestion. |
| [`_pathClear`](#_pathclear) | static method (`ServiceTopologyLayout`) | A | Check every segment of a candidate polyline against obstacles. |
| [`_stubBlocked`](#_stubblocked) | static method (`ServiceTopologyLayout`) | A | Check whether an exit/entry stub is blocked by another obstacle. |
| [`_segmentBlocked`](#_segmentblocked) | static method (`ServiceTopologyLayout`) | A | Check one orthogonal segment against the obstacle list. |
| [`_congestionCost`](#_congestioncost) | static method (`ServiceTopologyLayout`) | A | Penalize a candidate segment for overlapping/crossing routed segments. |
| [`_segmentsForPath`](#_segmentsforpath) | static method (`ServiceTopologyLayout`) | A | Turn a polyline into `_Segment`s for congestion tracking. |
| [`_simplifyPolyline`](#_simplifypolyline) | static method (`ServiceTopologyLayout`) | A | Dedupe points and drop collinear interior points from a polyline. |
| `_anchor` | static method (`ServiceTopologyLayout`) | B | Point on a rect's left/right edge, offset vertically. |
| `_sideVector` | static method (`ServiceTopologyLayout`) | B | Unit outward vector for a `_TopologySide`. |
| `_edgeSpan` | static method (`ServiceTopologyLayout`) | B | Euclidean distance between an edge's endpoint rect centers. |
| `_serviceNodeId` | static method (`ServiceTopologyLayout`) | B | Build the synthetic `service:<id>` node id for a service. |
| [`_compareRoutesForLayout`](#_compareroutesforlayout) | static method (`ServiceTopologyLayout`) | A | Order one source's routes by lane, method, then target. |
| `_laneOrder` | static method (`ServiceTopologyLayout`) | B | Sort key for `ServiceAccessLane` (local < vpn < public). |
| `_laneRank` | static method (`ServiceTopologyLayout`) | B | Sort key for nullable `ServiceAccessLane` (null sorts last). |
| `_routeMethodName` | static method (`ServiceTopologyLayout`) | B | First hop's HTTP method name, or `''`. |
| [`_median`](#_median) | static method (`ServiceTopologyLayout`) | A | Statistical median of a list of row scores. |
| `_roleOrder` | static method (`ServiceTopologyLayout`) | B | Sort key for `ServiceTopologyNodeRole` (device→…→domain). |
| `_laneBucket` | static method (`ServiceTopologyLayout`) | B | Sort key for a node's own lane (unset sorts first). |
| `_manhattan` | static method (`ServiceTopologyLayout`) | B | L1 distance between two `Offset`s. |
| `_snapOffset` | static method (`ServiceTopologyLayout`) | B | Snap both coordinates of an `Offset` to the half-pixel grid. |
| `_clampOffset` | static method (`ServiceTopologyLayout`) | B | Clamp an `Offset` inside `[0, size]`. |
| `_snap` | static method (`ServiceTopologyLayout`) | B | Round a value to the nearest 0.5. |
| `_sameRect` | static method (`ServiceTopologyLayout`) | B | Epsilon-tolerant `Rect` equality. |
| `_TopologySide` | enum | B | `left` / `right` — which side of a node an edge exits/enters. |
| `_epsilon` | top-level const | B | Shared floating-point tolerance (0.01) for geometry comparisons. |
| `_rowEpsilon` | top-level const | B | Floating-point tolerance (0.0001) for row-value matching. |
| `_RoutingGridBase` | class | B | Reusable set of shared x/y routing-track coordinates. |
| `xs` | field (`_RoutingGridBase`) | B | Shared vertical grid lines (x coordinates). |
| `ys` | field (`_RoutingGridBase`) | B | Shared horizontal grid lines (y coordinates). |
| `_RoutingGridBase.new` | constructor (`_RoutingGridBase`) | B | Forwarding const constructor for `xs`/`ys`. |
| [`_RoutingGridBase.fromObstacles`](#_routinggridbase-fromobstacles) | factory (`_RoutingGridBase`) | A | Build shared routing tracks from node obstacles and canvas size. |
| `_RoutedSegments` | class | B | Segments routed so far, indexed by axis coordinate for congestion scoring. |
| `all` | field (`_RoutedSegments`) | B | Every routed segment, in insertion order. |
| `_horizontal` | field (`_RoutedSegments`) | B | Horizontal segments, sorted by y. |
| `_vertical` | field (`_RoutedSegments`) | B | Vertical segments, sorted by x. |
| [`addAll`](#addall) | method (`_RoutedSegments`) | A | Append segments to `all` and insert them into the sorted axis index. |
| [`cost`](#cost) | method (`_RoutedSegments`) | A | Congestion cost of a candidate segment, visiting only nearby segments. |
| [`_lowerBound`](#_lowerbound) | static method (`_RoutedSegments`) | A | Binary search for the first index whose key is at least a value. |
| `_Segment` | class | B | An orthogonal (horizontal or vertical) line segment `a`→`b`. |
| `a` | field (`_Segment`) | B | Segment start point. |
| `b` | field (`_Segment`) | B | Segment end point. |
| `_Segment.new` | constructor (`_Segment`) | B | Forwarding const constructor for `a`/`b`. |
| `horizontal` | getter (`_Segment`) | B | Whether the segment's endpoints share a y (within `_epsilon`). |
| `vertical` | getter (`_Segment`) | B | Whether the segment's endpoints share an x (within `_epsilon`). |
| [`sameAxisOverlap`](#sameaxisoverlap) | method (`_Segment`) | A | Whether two segments lie on the same line and their spans overlap. |
| [`nearAxisOverlap`](#nearaxisoverlap) | method (`_Segment`) | A | Whether two parallel segments run within `distance` of each other. |
| [`crosses`](#crosses) | method (`_Segment`) | A | Whether a horizontal and a vertical segment actually intersect. |
| [`_rangesOverlap`](#_rangesoverlap) | static method (`_Segment`) | A | Whether two 1-D ranges overlap by more than `_epsilon`. |
| [`_between`](#_between) | static method (`_Segment`) | A | Inclusive range test with `_epsilon` slack. |
| `_RouteState` | class | B | A search-heap entry: grid state `index` and accumulated `cost`. |
| `index` | field (`_RouteState`) | B | Encoded `(point, direction)` state index. |
| `cost` | field (`_RouteState`) | B | Priority (g + heuristic) used to order the heap. |
| `_RouteState.new` | constructor (`_RouteState`) | B | Forwarding const constructor for `index`/`cost`. |
| `_RouteHeap` | class | B | Binary min-heap of `_RouteState`, ordered by `cost`. |
| `_items` | field (`_RouteHeap`) | B | Backing growable list for the heap array. |
| `isNotEmpty` | getter (`_RouteHeap`) | B | Whether the heap still has entries. |
| [`add`](#add) | method (`_RouteHeap`) | A | Insert a state and sift it up to restore heap order. |
| [`removeFirst`](#removefirst) | method (`_RouteHeap`) | A | Pop the minimum-cost state and sift the new root down. |
| [`_bubbleUp`](#_bubbleup) | method (`_RouteHeap`) | A | Sift-up: swap with parent while parent's cost is larger. |
| [`_bubbleDown`](#_bubbledown) | method (`_RouteHeap`) | A | Sift-down: swap with the smaller child while it beats the current node. |
| `_swap` | method (`_RouteHeap`) | B | Swap two backing-array slots by index. |

**Row-count note:** `grep -c '/// Purpose:' service_topology_layout.dart` returns **71**. One of
those is the local `deviceKey` helper declared inside `_routeRows` (described in that entry, not a
table row), so **70** table rows carry a `/// Purpose:` comment. The Declarations table above has
**115** rows because it also lists 45 declarations without one: the 8 class/enum declarations
themselves (`ServiceTopologyLayoutOptions`, `ServiceTopologyLayout`, `_TopologySide`,
`_RoutingGridBase`, `_RoutedSegments`, `_Segment`, `_RouteState`, `_RouteHeap`), 20 data fields
(3 on `ServiceTopologyLayoutOptions`, 7 on `ServiceTopologyLayout`, 2 on `_RoutingGridBase`, 3 on
`_RoutedSegments`, 2 on `_Segment`, 2 on `_RouteState`, 1 on `_RouteHeap`), 15 constants (13
`static const` on `ServiceTopologyLayout` + the top-level `_epsilon`/`_rowEpsilon`), and the 2
one-line getters `_Segment.horizontal`/`.vertical`. 70 + 45 = 115. Tier A: 45 rows.

## Documentation

### `static ServiceTopologyLayout build(ServiceTopologyGraph graph, List<ServiceRoute> routes, double viewportWidth, {ServiceTopologyLayoutOptions options = const ServiceTopologyLayoutOptions()})` <a id="build"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 131).
- **Purpose:** Compute node rectangles, ranks, canvas size, pre-routed edge polylines and, when
  grouping, the device containers and hidden edges for one graph/route set/viewport/options.
- **Inputs:** `graph` (nodes + edges), `routes` (drives row grouping), `viewportWidth` (minimum
  canvas width), `options` (device grouping, domain-sink alignment, crossing sweep limit).
- **Returns:** A new `ServiceTopologyLayout` with `size`, `nodeRects`, `nodeRanks`, `edgePaths`,
  `groupRects`, `hiddenEdges`, `crossings`.
- **Side effects:** None — pure function of its inputs.
- **Algorithm:**
  1. Build `nodeMap` (id → node) and `validEdges` — edges whose `from`/`to` both resolve to a
     real node; dangling edges are silently dropped. Build `incoming`/`outgoing` adjacency sets.
  2. If `options.groupByDevice`, compute `groups` ([`_deviceGroups`](#_devicegroups)) and the
     inverse `memberGroup` (member id → device node id); otherwise both are empty.
  3. `hiddenEdges` = every valid edge from a grouped device node to one of its own **service**
     members; `drawnEdges` = the remaining valid edges.
  4. Compute `routeRows` ([`_routeRows`](#_routerows), `byDevice` when any group exists), then
     `desiredRows` ([`_desiredRows`](#_desiredrows)).
  5. Compute `nodeRanks` ([`_nodeRanks`](#_noderanks), `alignDomainSinks` from `options`) from all
     valid edges; when grouping, re-rank with [`_headerRanks`](#_headerranks).
  6. Compact `desiredRows` globally ([`_compactDesiredRows`](#_compactdesiredrows)), then place
     every node except grouped device nodes with [`_placeNodes`](#_placenodes) (drawn edges,
     `memberGroup`, `options.crossingSweeps`), which returns rects, row targets and crossings.
  7. When grouping, [`_placeContainers`](#_placecontainers) shifts rects around containers and
     adds each grouped device's header tab; its container rects become `groupRects`.
  8. Canvas `size` = `max(viewportWidth, maxRight + padding + _routingMargin)` ×
     `max(360.0, maxBottom + padding + _routingMargin)`, over node **and** container rects.
  9. Route the drawn edges only ([`_routeEdges`](#_routeedges)) to get `edgePaths`.
- **Usage:**
  ```dart
  final layout = ServiceTopologyLayout.build(
    request.graph,
    request.routes,
    request.viewportWidth.toDouble(),
    options: request.options,
  );
  ```
  (`lib/features/services/views/service_topology_page.dart`, `_calculateLayout`, lines 163–168,
  after an `await Future<void>.delayed(Duration.zero)` so it runs off the current frame.)
- **Notes:** Ranks come purely from the edge graph (including hidden edges), rows from
  routes/neighbors; they meet in `_placeNodes`. With grouping, grouped device nodes leave the rank
  columns and become container headers; hidden edges have no entry in `edgePaths`.

### `static Map<String, List<String>> _deviceGroups(ServiceTopologyGraph graph)` <a id="_devicegroups"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 248).
- **Purpose:** Find the devices the layout draws as containers.
- **Inputs:** `graph`.
- **Returns:** Device node id → member node ids, in graph order.
- **Side effects:** None.
- **Algorithm:** Map each `device` node's `deviceId` to its node id. Collect every `service`,
  `endpoint` or `remoteEntry` node whose `deviceId` maps to a device node. Keep only devices with
  at least one `service` member.
- **Usage:**
  ```dart
  final groups = options.groupByDevice
      ? _deviceGroups(graph)
      : const <String, List<String>>{};
  ```
  (`build`, lines 155–157.)
- **Notes:** A device that a hop names but that hosts no service (e.g. a router) stays a plain
  card, and its remote entry stays a free chip.

### `static Map<String, int> _headerRanks(Map<String, int> ranks, Map<String, List<String>> groups)` <a id="_headerranks"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 281).
- **Purpose:** Re-rank the graph once grouped device nodes leave the columns.
- **Inputs:** `ranks` (from `_nodeRanks`), `groups` (from `_deviceGroups`).
- **Returns:** Dense ranks for every non-grouped node; each grouped device node gets the smallest
  rank among its members.
- **Side effects:** None.
- **Algorithm:** Collect the distinct ranks used by non-grouped nodes, sort, and remap them to
  `0..N`. Then set each grouped device's rank to the minimum of its members' new ranks.
- **Usage:**
  ```dart
  if (groups.isNotEmpty) nodeRanks = _headerRanks(nodeRanks, groups);
  ```
  (`build`, line 191.)
- **Notes:** A column that held only grouped devices (usually rank 0) disappears, so the canvas
  keeps no empty band on the left. The header rank is used by edge routing (`_portOffsets`).

### `static ({Map<String, Rect> rects, Map<String, double> targets, int crossings}) _placeNodes(List<ServiceTopologyNode> nodes, Map<String, int> nodeRanks, Map<String, double> desiredRows, List<ServiceTopologyEdge> edges, Map<String, String> memberGroup, int sweeps)` <a id="_placenodes"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 316).
- **Purpose:** Place nodes into rank columns, reduce crossings, and turn rows into y positions.
- **Inputs:** `nodes` (every node in a rank column — grouped device nodes are excluded),
  `nodeRanks`, `desiredRows` (already globally compacted), `edges` (drawn edges), `memberGroup`
  (empty without grouping), `sweeps` (barycenter sweep limit).
- **Returns:** A record: `rects` (node id → rect), `targets` (node id → the y its row asks for,
  before nodes above it in its rank push it down), and `crossings` (left after the sweep).
- **Side effects:** None.
- **Algorithm:**
  1. Group `nodes` by rank; sort each rank by `desiredRows`, tie-broken by `_roleOrder`, then
     `_laneBucket`, then lower-cased label.
  2. Each rank's column width is its widest `_nodeWidth`; `rankX` advances by
     `rankWidth + rankGap` per rank.
  3. Per rank: compute rank-local compact rows ([`_compactRankRows`](#_compactrankrows)); when
     grouping, reorder the ids with [`_keepGroupsTogether`](#_keepgroupstogether); hand the rank's
     sorted row values out in that order (rows are only permuted) into `rows` and `order[rank]`.
  4. Run [`_sweepCrossings`](#_sweepcrossings) over `order`/`rows` with the edges whose both ends
     are in `nodes`; it may permute rows further and returns the crossing count.
  5. Build `rowY` with [`_rowPositions`](#_rowpositions).
  6. Walk each rank top-to-bottom: `target = rowY(rows[id])` (recorded in `targets`),
     `y = max(target, previousBottom + verticalGap)`; x centers the node in its column.
- **Usage:**
  ```dart
  final placed = _placeNodes(
    [
      for (final node in graph.nodes)
        if (!groups.containsKey(node.id)) node,
    ],
    nodeRanks,
    compactRows,
    drawnEdges,
    memberGroup,
    options.crossingSweeps,
  );
  ```
  (`build`, lines 193–203.)
- **Notes:** There is no fixed row stride any more: each row is as tall as its tallest node plus
  `rowGap` (112 px for a card row, 88 px for a chip row). `verticalGap` only applies as a floor
  when compaction would make two nodes in one rank collide. `targets` lets `_placeContainers`
  re-place members at their own rows.

### `static List<String> _keepGroupsTogether(List<String> ids, Map<String, String> memberGroup)` <a id="_keepgroupstogether"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 419).
- **Purpose:** Reorder one rank so each container's members sit together.
- **Inputs:** `ids` (the rank in row order), `memberGroup`.
- **Returns:** The same ids, each container's members moved up to its first member, in their own
  order.
- **Side effects:** None.
- **Algorithm:** Walk `ids`; a free node is emitted as-is; on the first member of a group, emit
  every member of that group in `ids` order; skip ids already emitted.
- **Usage:**
  ```dart
  final grouped = memberGroup.isEmpty
      ? ids
      : _keepGroupsTogether(ids, memberGroup);
  ```
  (`_placeNodes`, lines 369–371.)
- **Notes:** O(n²) per rank. The caller hands out the rank's sorted row values in the new order,
  so the rank's rows stay a permutation of what they were.

### `static double Function(double) _rowPositions(Map<String, double> rows, Map<String, ServiceTopologyNode> nodeMap)` <a id="_rowpositions"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 449).
- **Purpose:** Turn compact row values into y positions sized by content.
- **Inputs:** `rows` (node id → compact row), `nodeMap`.
- **Returns:** A function from a row value to its y position.
- **Side effects:** None.
- **Algorithm:**
  1. For each distinct row value (matched within `_rowEpsilon`), record the tallest
     `_nodeHeight` on it across all ranks.
  2. Sort the values. The first starts at `padding + max(0, value) × (nodeHeight + rowGap)`; each
     next one starts `(next − this) × (height(this) + rowGap)` below the previous.
  3. The returned function looks the value up (within `_rowEpsilon`); an unknown value falls back
     to `padding + row × (nodeHeight + rowGap)`.
- **Usage:**
  ```dart
  final rowY = _rowPositions(rows, nodeMap);
  ```
  (`_placeNodes`, line 390; applied at line 401.)
- **Notes:** Fractional gaps from compaction keep their proportion, and a row of port chips is
  shorter than a row of cards. This replaced the old fixed `nodeHeight + 44` stride.

### `static int _sweepCrossings(Map<int, List<String>> order, Map<String, double> rows, Map<String, int> ranks, List<ServiceTopologyEdge> edges, Map<String, String> memberGroup, int sweeps)` <a id="_sweepcrossings"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 495).
- **Purpose:** Reduce edge crossings with alternating barycenter sweeps.
- **Inputs:** `order` (rank → ids in row order), `rows` (id → compact row), `ranks`, `edges`
  (drawn edges between placed nodes), `memberGroup`, `sweeps` (limit).
- **Returns:** The crossing count of the order it leaves.
- **Side effects:** Mutates `order` and `rows` when a sweep improves them.
- **Algorithm:**
  1. `best` = [`countCrossings`](#countcrossings) of the current
     [`_orderPositions`](#_orderpositions); return it if `sweeps <= 0` or it is 0.
  2. Build undirected neighbor sets from `edges`.
  3. For each sweep: even sweeps go down (ranks ascending, skipping the first), odd sweeps go up
     (descending, skipping the last). For each rank with 2+ ids, a node's barycenter is the mean
     row of its neighbors on lower ranks (down) or higher ranks (up), or its own row if none.
  4. Form units — one per free node, one per container (its members in rank order) — keyed by the
     mean of their members' barycenters; stable-sort by key, then original unit index.
  5. If the order changed, hand the rank's sorted row values out in the new order, recount, and
     keep the new order/rows only when the count is **strictly** lower.
  6. Stop after a sweep with no improvement, or when `best` reaches 0.
- **Usage:**
  ```dart
  final crossings = _sweepCrossings(
    order,
    rows,
    nodeRanks,
    [
      for (final edge in edges)
        if (nodeMap.containsKey(edge.from) && nodeMap.containsKey(edge.to))
          edge,
    ],
    memberGroup,
    sweeps,
  );
  ```
  (`_placeNodes`, lines 378–389.)
- **Notes:** Because rows are only permuted within a rank, straight chains stay straight where
  they were, and the result never has more crossings than the input. Each trial recounts every
  edge pair, so the sweep costs O(sweeps × ranks × E² × span).

### `static Map<String, double> _orderPositions(Map<int, List<String>> order, Map<String, double> rows)` <a id="_orderpositions"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 593).
- **Purpose:** Give every placed node a strictly ordered position in its rank.
- **Inputs:** `order`, `rows`.
- **Returns:** id → `rows[id] + index × 1e-4`, where `index` is the node's position in its rank list.
- **Side effects:** None.
- **Algorithm:** One map comprehension over every rank's indexed id list.
- **Usage:**
  ```dart
  var best = countCrossings(ranks, _orderPositions(order, rows), edges);
  ```
  (`_sweepCrossings`, line 503; also line 572 for each trial order.)
- **Notes:** Two nodes on the same row value still stack in list order; the index term keeps that
  order visible to `countCrossings`.

### `static int countCrossings(Map<String, int> ranks, Map<String, double> positions, List<ServiceTopologyEdge> edges)` <a id="countcrossings"></a>
- **Kind:** static method of `ServiceTopologyLayout` (public).
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 613).
- **Purpose:** Count edge crossings between ranks.
- **Inputs:** `ranks` (node id → rank), `positions` (node id → any measure that orders a rank),
  `edges`.
- **Returns:** The number of times two edges swap order from one rank line to the next, summed
  over every edge pair.
- **Side effects:** None.
- **Algorithm:**
  1. Turn each edge into a span `(r0, p0) → (r1, p1)` with `r0 < r1`; skip edges within one rank
     or with an end missing from `ranks`/`positions`.
  2. For every pair of spans, walk the rank lines they share (`max(r0)..min(r1)`), interpolating
     each span's position linearly on each line; take the sign of the difference (0 within
     `_rowEpsilon`). Each change between non-zero signs counts one crossing.
- **Usage:**
  ```dart
  final count = countCrossings(
    ranks,
    _orderPositions(trialOrder, trialRows),
    edges,
  );
  ```
  (`_sweepCrossings`, lines 570–574; also called directly by
  `test/service_topology_layout_test.dart`, line 228.)
- **Notes:** The bilayer inversion count generalized to long edges. Two edges that meet on a line
  and continue in swapped order count once; two that only share an end do not count. O(E² × span).

### `static ({Map<String, Rect> rects, Map<String, Rect> groups}) _placeContainers(Map<String, Rect> flat, Map<String, double> targets, Map<String, int> ranks, Map<String, List<String>> groups)` <a id="_placecontainers"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 678).
- **Purpose:** Draw device containers around their members.
- **Inputs:** `flat` (rects from `_placeNodes`), `targets` (row targets from `_placeNodes`),
  `ranks`, `groups` (device node id → member ids).
- **Returns:** A record: `rects` (adjusted rects, now including each grouped device's header tab)
  and `groups` (container rects keyed by device node id).
- **Side effects:** None.
- **Algorithm:**
  1. Build items: one per container (top = its highest member's flat top) and one per free node;
     sort by top, containers before free nodes on a tie, then by index.
  2. Keep a floor per rank and a running `shift`. A free node lands at
     `max(flatTop + shift, floor + verticalGap)` and raises its rank's floor.
  3. A container spans its members' ranks. `memberTop` = `item.top + shift + headerSpace`
     (`headerSpace = containerHeaderHeight + containerPadding`), raised to
     `floor + verticalGap + headerSpace` for every floor in its ranks; `shift` becomes
     `memberTop − item.top`.
  4. Members (by flat top) go to `memberTop + target − firstTarget`, but at least `verticalGap`
     below the previous member in their rank.
  5. The container is the members' bounds grown by `containerPadding`, with its top at
     `memberTop − headerSpace`. The header tab is `containerHeaderHeight` tall at the container's
     top-left, `min(container.width, nodeWidth)` wide. Every rank in the span gets the container's
     bottom as its floor.
- **Usage:**
  ```dart
  final contained = _placeContainers(
    nodeRects,
    placed.targets,
    nodeRanks,
    groups,
  );
  ```
  (`build`, lines 207–212.)
- **Notes:** Members return to their row targets, so they don't keep a gap another device's node
  left above them; the running shift keeps rows below aligned across ranks. By construction every
  member lies inside its container, no free node meets a container, and containers never overlap,
  so there is no fallback. The header is narrow so edges can still enter the container from
  above. Container rects are not routing obstacles; the header tabs are.

### `static Map<String, double> _compactRankRows(List<ServiceTopologyNode> nodes, Map<String, double> desiredRows)` <a id="_compactrankrows"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 786).
- **Purpose:** Recompute a compact row number for one rank's nodes only, so unused rows from
  *other* ranks don't leave blank bands in this one.
- **Inputs:** `nodes` (already filtered to one rank), `desiredRows` (global map).
- **Returns:** `Map<String, double>` — node id → compact row, local to this rank.
- **Side effects:** None.
- **Algorithm:** Build a row-value map from only this rank's nodes' `desiredRows` values via
  [`_compactRowValueMap`](#_compactrowvaluemap), then look up each node's compacted value via
  [`_compactRowValue`](#_compactrowvalue).
- **Usage:**
  ```dart
  final rankRows = _compactRankRows(rankNodes, desiredRows);
  ```
  (`_placeNodes`, line 367.)
- **Notes:** Because compaction is rank-local, the same raw `desiredRows` value can map to a
  different compacted row number in two different ranks — this is intentional (each rank only
  cares about its own vertical gaps).

### `static Map<String, double> _compactDesiredRows(ServiceTopologyGraph graph, Map<String, double> desiredRows)` <a id="_compactdesiredrows"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 804).
- **Purpose:** Remove row gaps in the global `desiredRows` map that exist only because
  `_routeRows` reserved a row for a route/source with no corresponding visible node.
- **Inputs:** `graph`, `desiredRows`.
- **Returns:** `Map<String, double>` — same keys as `desiredRows`, compacted values.
- **Side effects:** None.
- **Algorithm:** Collect and sort the desired-row values that actually belong to a `graph.nodes`
  entry (`usedRows`); if empty, return input unchanged. Build a compaction map from `usedRows` via
  [`_compactRowValueMap`](#_compactrowvaluemap), then remap every entry in `desiredRows` through
  [`_compactRowValue`](#_compactrowvalue).
- **Usage:**
  ```dart
  final compactRows = _compactDesiredRows(graph, desiredRows);
  ```
  (`build`, line 192.)
- **Notes:** This is the *global* compaction pass (across all ranks at once), run before
  `_placeNodes`; `_compactRankRows` is a second, rank-local compaction run afterward for the same
  purpose at finer granularity.

### `static Map<double, double> _compactRowValueMap(Iterable<double> rows)` <a id="_compactrowvaluemap"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 829).
- **Purpose:** Turn a sparse, possibly-irregular set of raw row values into a dense compacted
  sequence, collapsing large gaps while preserving small ordering gaps as visual breathing room.
- **Inputs:** `rows` — raw row values (may contain near-duplicates).
- **Returns:** `Map<double, double>` mapping each distinct raw row (deduped within `_rowEpsilon`)
  to its compacted position.
- **Side effects:** None.
- **Algorithm:**
  1. Sort `rows`, then dedupe adjacent values within `_rowEpsilon` into `compactedRows`.
  2. Walk `compactedRows` in order, accumulating `nextRow`; for each step after the first, add
     `rawGap.clamp(0.72, 1.0)` — so a same-source route gap (raw step 1.0) stays close to a full
     row, while a between-source gap (raw step 0.38) still contributes at least 0.72, guaranteeing
     visible separation without letting gaps as large as 1.35 (empty-source spacing) stretch the
     canvas proportionally.
- **Usage:**
  ```dart
  final rowMap = _compactRowValueMap(
    nodes.map((node) => desiredRows[node.id]).whereType<double>(),
  );
  ```
  (`_compactRankRows`, lines 790–792; also `_compactDesiredRows`, line 816.)
- **Notes:** The `clamp(0.72, 1.0)` bounds are the load-bearing constants for how "loose" versus
  "tight" compacted rows can look; `_rowPositions` then scales each step by the row's height plus
  `rowGap`.

### `static double _compactRowValue(double row, Map<double, double> rowMap)` <a id="_compactrowvalue"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 856).
- **Purpose:** Resolve one raw desired-row value to its compacted row via `rowMap`, tolerating
  floating-point drift.
- **Inputs:** `row`, `rowMap` (from `_compactRowValueMap`).
- **Returns:** The matching compacted value, or `row` unchanged if no key in `rowMap` is within
  `_rowEpsilon`.
- **Side effects:** None.
- **Algorithm:** Linear scan of `rowMap.entries`, matching on `(row - entry.key).abs() <=
  _rowEpsilon`; O(n) per lookup (n = distinct compacted rows).
- **Usage:**
  ```dart
  node.id: _compactRowValue(desiredRows[node.id] ?? 0, rowMap),
  ```
  (`_compactRankRows`, line 795; also `_compactDesiredRows`, line 820.)
- **Notes:** Falling back to the original `row` (rather than throwing) means a value from outside
  the map it was built from is preserved as-is instead of being remapped.

### `static Map<String, int> _nodeRanks(ServiceTopologyGraph graph, List<ServiceTopologyEdge> validEdges, {bool alignDomainSinks = false})` <a id="_noderanks"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 872).
- **Purpose:** Derive each node's horizontal rank (column) from the edge graph via relaxation,
  optionally move sink domains to the last rank, then compress ranks into a dense `0..N` sequence.
- **Inputs:** `graph`, `validEdges`, `alignDomainSinks` (default `false`; `build` passes
  `options.alignDomainSinks`, which defaults to `true`).
- **Returns:** `Map<String, int>` — node id → dense rank.
- **Side effects:** None.
- **Algorithm:**
  1. Seed `ranks`: `device` nodes start at rank 0; every other node kind starts at rank 1.
  2. Set `rankLimit = max(2, nodeCount + 1)`. For up to `nodeCount + 2` iterations: for every edge,
     relax `ranks[edge.to] = max(ranks[edge.to], min(rankLimit, ranks[edge.from] + 1))`; also call
     [`_alignSiblingPortRanks`](#_alignsiblingportranks) each iteration and OR its `changed` result
     in. Stop early once a full pass makes no change.
  3. If `alignDomainSinks`: every `domain` node that is not the `from` of any valid edge takes the
     highest rank found.
  4. Collect `uniqueRanks` (sorted, deduped) and remap each node's raw rank to its index, producing
     a dense `0..N` rank sequence with no unused gaps.
- **Usage:**
  ```dart
  var nodeRanks = _nodeRanks(
    graph,
    validEdges,
    alignDomainSinks: options.alignDomainSinks,
  );
  ```
  (`build`, lines 186–190.)
- **Notes:** `rankLimit` caps propagation so a cyclic edge graph cannot grow ranks unboundedly —
  it guarantees termination (the `nodeCount + 2` bound is also a hard iteration cap) instead of
  preventing cycles outright. Sink alignment lines final addresses up in one right-hand column.

### `static bool _alignSiblingPortRanks(List<ServiceTopologyEdge> edges, Map<String, ServiceTopologyNode> nodeMap, Map<String, int> ranks)` <a id="_alignsiblingportranks"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 925).
- **Purpose:** Pull sibling "port-like" child nodes of the same service (e.g. paired FRP
  ingress/public-port nodes) up to the same rank so they read as one visual unit.
- **Inputs:** `edges`, `nodeMap`, `ranks` (mutated in place).
- **Returns:** `bool` — whether any rank was changed this call.
- **Side effects:** Mutates `ranks` in place (raises some entries).
- **Algorithm:**
  1. For every edge whose `from` node is a `service` and whose `to` node is `compact` and of kind
     `endpoint` or `remoteEntry`, group `to` ids under their common `from` service id
     (`servicePorts`).
  2. For each service with 2+ such sibling ports, compute `targetRank` as the max current rank
     among them, then raise any sibling below `targetRank` up to it, marking `changed = true`.
- **Usage:**
  ```dart
  if (_alignSiblingPortRanks(validEdges, nodeMap, ranks)) {
    changed = true;
  }
  ```
  (`_nodeRanks`, lines 893–895, called once per relaxation iteration.)
- **Notes:** Only ever raises ranks (never lowers), consistent with `_nodeRanks`'s monotonic
  relaxation; being called inside the same loop means sibling alignment can itself trigger further
  edge relaxation on the next iteration.

### `static Map<String, double> _routeRows(ServiceTopologyGraph graph, List<ServiceRoute> routes, Map<String, ServiceTopologyNode> nodeMap, {bool byDevice = false})` <a id="_routerows"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 988).
- **Purpose:** Assign every route a preferred row along a virtual row axis, grouped by source
  service and ordered so routes from the same source land on adjacent rows.
- **Inputs:** `graph`, `routes`, `nodeMap`, `byDevice` (order sources by device first).
- **Returns:** `Map<String, double>` — route id → row score.
- **Side effects:** None.
- **Algorithm:**
  1. Group routes by `_serviceNodeId(route.sourceServiceId)` into `routesBySource`.
  2. Collect all source ids (every route source plus every `localService` node, routed or not)
     and sort them: with `byDevice`, first by the local helper `deviceKey` (local devices before
     remote ones — role `remoteDevice` — then lower-cased device label, then device id); then by
     lower-cased label.
  3. Walk sources in that order, maintaining a running `row`: a source with no routes still
     advances `row` by 1.35 (reserves a gap without emitting any row entries); a source with
     routes sorts them via [`_compareRoutesForLayout`](#_compareroutesforlayout), assigns each a
     sequential row (`row += 1` per route), then adds a further 0.38 gap before the next source.
- **Usage:**
  ```dart
  final routeRows = _routeRows(
    graph,
    routes,
    nodeMap,
    byDevice: groups.isNotEmpty,
  );
  ```
  (`build`, lines 173–178.)
- **Notes:** `byDevice` gives each device's services a contiguous band of rows, so its container
  stays compact. The 1.35/0.38/1.0 spacing constants are what
  [`_compactRowValueMap`](#_compactrowvaluemap)'s `clamp(0.72, 1.0)` step later normalizes.

### `static Map<String, double> _desiredRows(ServiceTopologyGraph graph, List<ServiceRoute> routes, Map<String, double> routeRows, Map<String, Set<String>> incoming, Map<String, Set<String>> outgoing)` <a id="_desiredrows"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1063).
- **Purpose:** Derive each node's preferred row: directly from the routes it participates in when
  possible, otherwise by propagating from already-scored neighbors, otherwise a stable fallback
  order.
- **Inputs:** `graph`, `routes`, `routeRows` (from `_routeRows`), `incoming`/`outgoing` adjacency.
- **Returns:** `Map<String, double>` — node id → desired row (every node gets an entry).
- **Side effects:** None.
- **Algorithm:**
  1. For each service node, collect the rows of routes it originates (`sourceRouteRows`).
  2. For every node, gather `scores` = rows of its own `routeIds` plus (if it's a service) its
     source-route rows; if any scores exist, `desired[node.id] = _median(scores)`.
  3. Iterate up to 10 times: for any node still without a `desired` entry, gather the `desired`
     scores of its `incoming`/`outgoing` neighbors and set `desired[node.id] = _median(...)` if any
     exist; stop early once a full pass makes no change.
  4. Any nodes still unscored (isolated from any routed node) get sequential fallback rows
     starting at `max(desired.values) + 1` (or 0 if `desired` is empty), ordered by
     `_roleOrder` then label.
- **Usage:**
  ```dart
  final desiredRows = _desiredRows(
    graph,
    routes,
    routeRows,
    incoming,
    outgoing,
  );
  ```
  (`build`, lines 179–185.)
- **Notes:** The 10-iteration cap on neighbor propagation (step 3) means a very long chain of
  otherwise-unrouted nodes could still fall through to the step-4 fallback if propagation hasn't
  reached them within 10 passes — in practice bounded by typical topology diameters.

### `static Map<ServiceTopologyEdge, List<Offset>> _routeEdges(List<ServiceTopologyEdge> validEdges, Map<String, Rect> rects, Map<String, int> ranks, Size size)` <a id="_routeedges"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1133).
- **Purpose:** Entry point for edge routing: builds shared obstacle/grid state once, then routes
  every edge against it, accumulating routed segments so later edges avoid earlier ones.
- **Inputs:** `validEdges` (`build` passes the drawn edges only), `rects` (placed node rects,
  including header tabs), `ranks`, `size` (canvas).
- **Returns:** `Map<ServiceTopologyEdge, List<Offset>>` — one polyline per edge (possibly empty on
  routing failure).
- **Side effects:** None (builds fresh local collections).
- **Algorithm:**
  1. Compute `outgoingOffsets`/`incomingOffsets` via [`_portOffsets`](#_portoffsets) so edges
     sharing a node side fan out.
  2. Build `obstacles` as every node rect inflated by `_routingClearance`, then build a shared
     [`_RoutingGridBase.fromObstacles`](#_routinggridbase-fromobstacles) and an empty
     `_RoutedSegments` index.
  3. Order edges by descending `_edgeSpan` (longest first), then by `_laneRank(edge.lane)`, then
     by `'from->to'` string — so the edges most likely to need real pathfinding claim direct
     corridors before shorter edges have to route around them.
  4. For each edge in that order, call [`_routeEdge`](#_routeedge) with the shared obstacles/grid
     and the segments routed so far; add the result's segments (via
     [`_segmentsForPath`](#_segmentsforpath)) to `routedSegments` with [`addAll`](#addall).
- **Usage:**
  ```dart
  final edgePaths = _routeEdges(drawnEdges, nodeRects, nodeRanks, size);
  ```
  (`build`, line 227.)
- **Notes:** `routedSegments` accumulates monotonically across the whole call — congestion cost
  is therefore order-dependent: earlier-routed (longer) edges get first pick of clear corridors,
  and later edges pay a cost to detour around them. Container rects are not obstacles.

### `static Map<ServiceTopologyEdge, double> _portOffsets(List<ServiceTopologyEdge> edges, Map<String, Rect> rects, Map<String, int> ranks, {required bool outgoing})` <a id="_portoffsets"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1191).
- **Purpose:** For edges that share the same node on their `from` (or `to`) side, compute a
  perpendicular offset per edge so they fan out along that node's edge instead of overlapping.
- **Inputs:** `edges`, `rects`, `ranks`, `outgoing` (whether grouping by `from` or `to`).
- **Returns:** `Map<ServiceTopologyEdge, double>` — per-edge vertical offset from the node center.
- **Side effects:** None.
- **Algorithm:**
  1. Group edges by the relevant node id (`entry.key`).
  2. For each group, compute `maxOffset = max(0, nodeRect.height / 2 - 12)` and sort the group's
     edges by peer center y, then by `ranks[peer]`, then by `'from->to'` string.
  3. Assign offsets symmetric around the group's midpoint index: `((i - midpoint) * 9.0).clamp
     (-maxOffset, maxOffset)`, i.e. 9px spacing between adjacent edges, clamped so offsets never
     leave the node's own edge.
- **Usage:**
  ```dart
  final outgoingOffsets = _portOffsets(validEdges, rects, ranks, outgoing: true);
  final incomingOffsets = _portOffsets(validEdges, rects, ranks, outgoing: false);
  ```
  (`_routeEdges`, lines 1139–1150.)
- **Notes:** Called twice per layout (once per direction) since an edge's exit fan-out on its
  `from` node is independent of its entry fan-out on its `to` node. A header tab is only 40 px
  tall, so its `maxOffset` is 8.

### `static List<Offset> _routeEdge({required Rect from, required Rect to, required double fromOffset, required double toOffset, required List<Rect> obstacles, required _RoutingGridBase gridBase, required _RoutedSegments routedSegments, required Size size})` <a id="_routeedge"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1235).
- **Purpose:** Route one edge between two placed node rects, trying multiple anchor-side
  candidates and keeping whichever produces the lowest-scoring valid path.
- **Inputs:** `from`/`to` rects, per-edge port offsets, shared `obstacles`/`gridBase`,
  `routedSegments` (index of segments routed so far), canvas `size`.
- **Returns:** A simplified orthogonal polyline, or `[]` if every candidate anchor pair fails.
- **Side effects:** None.
- **Algorithm:**
  1. Determine `forward` (`to` is right of `from`) and `sameRank` (centers within 8px
     horizontally); pick a preferred `startSide`/`endSide`: same-rank edges exit/enter whichever
     side (`left`/`right`) faces away from the canvas midline, otherwise the natural
     forward/backward sides.
  2. Build an ordered, deduplicated candidate list: the preferred pair first, then the four
     `{left,right}×{left,right}` combinations as fallbacks.
  3. For each candidate: compute anchor points via `_anchor` + offset, then push them out by
     `_routingEscape` along `_sideVector` and clamp to the canvas (`_clampOffset`) to get
     `startExit`/`endEntry`. Skip the candidate if either stub is blocked by an obstacle other
     than the node's own inflated rect ([`_stubBlocked`](#_stubblocked)).
  4. Route the middle segment: try [`_fastRouteBetween`](#_fastroutebetween) first, falling back
     to [`_routeBetween`](#_routebetween) if it returns `null`. Skip the candidate if both fail.
  5. Assemble the full path (`start → startExit → middle (skip duplicate first point) → end`),
     simplify it ([`_simplifyPolyline`](#_simplifypolyline)), and score it
     ([`_pathScore`](#_pathscore)); keep the lowest-scoring candidate seen so far.
  6. Return the best path found, or `const []` if no candidate produced one.
- **Usage:**
  ```dart
  final path = _routeEdge(
    from: from,
    to: to,
    fromOffset: outgoingOffsets[edge] ?? 0,
    toOffset: incomingOffsets[edge] ?? 0,
    obstacles: obstacles,
    gridBase: gridBase,
    routedSegments: routedSegments,
    size: size,
  );
  ```
  (`_routeEdges`, lines 1170–1179.)
- **Notes:** All candidate anchor pairs (at most 5) are tried unconditionally (no early exit on
  first success) — a fixed, small combinatorial search rather than a greedy first-match, trading a
  bounded amount of extra work for a cleaner picked route.

### `static List<Offset>? _fastRouteBetween({required Offset start, required Offset goal, required List<Rect> obstacles, required _RoutedSegments routedSegments, required Size size})` <a id="_fastroutebetween"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1330).
- **Purpose:** Try a battery of cheap, direct orthogonal candidate paths between two already-
  escaped points before falling back to full grid pathfinding.
- **Inputs:** `start`, `goal` (already pushed past their nodes' stubs), `obstacles`,
  `routedSegments`, `size`.
- **Returns:** The best clear simplified polyline found, or `null` if none of the candidates are
  obstacle-clear (signaling the caller to fall back to `_routeBetween`).
- **Side effects:** None.
- **Algorithm:** Build and test candidates via a local `addCandidate` helper that snaps,
  simplifies ([`_simplifyPolyline`](#_simplifypolyline)) and obstacle-checks
  ([`_pathClear`](#_pathclear)) each shape:
  1. A straight line, only if `start`/`goal` already share an x or y (within `_epsilon`).
  2. Two single-bend "L" shapes (`goal.dx, start.dy` corner and `start.dx, goal.dy` corner).
  3. Two "Z" shapes through the midpoint (`midX`/`midY`).
  4. Up to four "around the bounding box" routes via tracks offset `_routingTrackGap` outside the
     `start`/`goal` bounding box on each side (left/right/top/bottom), clamped to the canvas.
  Among all obstacle-clear candidates, sort by [`_pathScore`](#_pathscore) and return the lowest;
  `null` if the candidate list ended up empty.
- **Usage:**
  ```dart
  final middle =
      _fastRouteBetween(
        start: startExit,
        goal: endEntry,
        obstacles: obstacles,
        routedSegments: routedSegments,
        size: size,
      ) ??
      _routeBetween(...);
  ```
  (`_routeEdge`, lines 1292–1307.)
- **Notes:** Most edges in a real topology (same or adjacent rank, nothing between them) resolve
  here without ever running the A*-style grid search in `_routeBetween`.

### `static List<Offset>? _routeBetween({required Offset start, required Offset goal, required List<Rect> obstacles, required _RoutingGridBase gridBase, required _RoutedSegments routedSegments, required Size size})` <a id="_routebetween"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1390).
- **Purpose:** Find an obstacle-avoiding orthogonal path between two escaped points using an
  A*-style priority-queue search over a shared+per-edge coordinate grid.
- **Inputs:** `start`, `goal`, `obstacles`, `gridBase` (shared tracks), `routedSegments`, `size`.
- **Returns:** A simplified polyline, or `null` if `start`/`goal` don't land on a grid coordinate
  or no path is found.
- **Side effects:** None (builds fresh local search state each call).
- **Algorithm:**
  1. Extend `gridBase`'s shared `xs`/`ys` with per-call tracks: `start`/`goal` themselves and
     ±`_routingTrackGap` around them, and every segment in `routedSegments.all` (its endpoints,
     plus ±`_routingTrackGap` on its perpendicular axis) — so new lanes open up next to existing
     routed edges instead of forcing everything through the same shared tracks.
  2. Sort the combined coordinates into `xValues`/`yValues`; locate `start`/`goal` grid indices;
     return `null` if either isn't an exact grid point.
  3. Allocate typed search state: `distances` (`Float64List`, `pointCount * 3`, filled with
     infinity), `previous` (`Int32List`, same size, `-1` = no predecessor), and `stepCosts`
     (`Float64List`, `pointCount * 2`, one slot per horizontal/vertical grid step, `NaN` = not yet
     computed).
  4. Run a Dijkstra/A* search over states `(point, direction)` (`direction`: 0 = start, 1 =
     horizontal move, 2 = vertical move), using [`_RouteHeap`](#add) as the open set, ordered by
     `g + heuristic` where the heuristic is `_manhattan` distance to `goal`.
  5. For each popped state, expand to the 4 orthogonal grid neighbors. The step's cost is looked
     up in `stepCosts` at `min(point, next) * 2 + (vertical ? 1 : 0)`; on first use it is computed
     as `-1` if [`_segmentBlocked`](#_segmentblocked), else `_manhattan` length +
     [`_congestionCost`](#_congestioncost), and cached. Blocked (negative) steps are skipped.
     Total = step cost + a 26.0 turn penalty (only if `currentDirection` is set and differs).
     Relax and push only if `nextCost + _epsilon < distances[nextState]`.
  6. Stop as soon as a state at `goalPoint` is popped (lowest-cost first by the min-heap);
     reconstruct the path by walking `previous` back until `-1`, reverse it, and simplify
     ([`_simplifyPolyline`](#_simplifypolyline)).
- **Usage:**
  ```dart
  _routeBetween(
    start: startExit,
    goal: endEntry,
    obstacles: obstacles,
    gridBase: gridBase,
    routedSegments: routedSegments,
    size: size,
  );
  ```
  (`_routeEdge`, lines 1300–1307, as the `??` fallback of `_fastRouteBetween`.)
- **Notes:** A step is reached from both ends and in several directions, and neither its obstacles
  nor its congestion change during one search, so caching it is result-identical to recomputing
  (all costs are multiples of 0.5, so summation order cannot change them). Together with the
  `_RoutedSegments` index this took a 43-node / 64-edge graph from about 23–29 s to about 1.1 s
  ungrouped / 0.2 s grouped on a developer machine; the 61-node / 91-edge synthetic test graph
  lays out in about 3.4 s ungrouped and 0.4 s grouped. The 3-state-per-point direction encoding
  lets the turn penalty distinguish "continuing straight" from "just turned".

### `static double _pathScore(List<Offset> path, _RoutedSegments routedSegments)` <a id="_pathscore"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1524).
- **Purpose:** Score a fully-formed routed path so that competing anchor-pair/candidate paths can
  be ranked and the cleanest one picked.
- **Inputs:** `path`, `routedSegments` (previously committed segments, for congestion).
- **Returns:** `double.infinity` if `path.length < 2`; otherwise a lower-is-better score.
- **Side effects:** None.
- **Algorithm:** For each consecutive point pair: add `_manhattan` distance, add
  [`_congestionCost`](#_congestioncost) against `routedSegments`, and add a 26.0 penalty whenever
  the segment's direction (horizontal vs vertical, from the `dx` epsilon test) differs from the
  previous segment's direction.
- **Usage:**
  ```dart
  final score = _pathScore(path, routedSegments);
  if (score < bestScore) {
    bestScore = score;
    bestPath = path;
  }
  ```
  (`_routeEdge`, lines 1315–1319; also `_fastRouteBetween`, lines 1376–1381.)
- **Notes:** Uses the same 26.0 turn-penalty constant as `_routeBetween`'s search cost, so paths
  found by the fast router and the A* router are scored on a consistent scale.

### `static bool _pathClear(List<Offset> path, List<Rect> obstacles)` <a id="_pathclear"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1547).
- **Purpose:** Check whether every segment of a candidate polyline is obstacle-free, before the
  fast router accepts it.
- **Inputs:** `path`, `obstacles`.
- **Returns:** `false` if `path.length < 2`; otherwise `true` only if no consecutive pair is
  blocked.
- **Side effects:** None.
- **Algorithm:** Loop over consecutive point pairs, calling
  [`_segmentBlocked`](#_segmentblocked) on each; short-circuit `false` on the first blocked
  segment.
- **Usage:**
  ```dart
  final path = _simplifyPolyline(points.map(_snapOffset).toList());
  if (path.length < 2 || !_pathClear(path, obstacles)) return;
  ```
  (`_fastRouteBetween`'s local `addCandidate`, lines 1340–1341.)
- **Notes:** None.

### `static bool _stubBlocked(Offset a, Offset b, List<Rect> obstacles, {required Rect allowed})` <a id="_stubblocked"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1560).
- **Purpose:** Check whether a node's short exit/entry stub segment is blocked by some *other*
  obstacle (excluding the node's own inflated rect, which the stub is expected to leave through).
- **Inputs:** `a`, `b` (stub endpoints), `obstacles`, `allowed` (the node's own inflated rect, to
  ignore).
- **Returns:** `true` if any obstacle other than `allowed` blocks the stub.
- **Side effects:** None.
- **Algorithm:** Loop over `obstacles`, skipping any that is `_sameRect` as `allowed`; call
  [`_segmentBlocked`](#_segmentblocked) against each remaining single-obstacle list, returning
  `true` on the first hit.
- **Usage:**
  ```dart
  if (_stubBlocked(start, startExit, obstacles, allowed: fromObstacle) ||
      _stubBlocked(endEntry, end, obstacles, allowed: toObstacle)) {
    continue;
  }
  ```
  (`_routeEdge`, lines 1288–1291.)
- **Notes:** Without the `allowed` exclusion, every stub would be flagged as blocked by the very
  node it's leaving/entering, since the stub necessarily starts on that node's own inflated
  boundary.

### `static bool _segmentBlocked(Offset a, Offset b, List<Rect> obstacles)` <a id="_segmentblocked"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1578).
- **Purpose:** Check one orthogonal segment against the full obstacle list.
- **Inputs:** `a`, `b`, `obstacles`.
- **Returns:** `true` if the segment is non-orthogonal, or if its bounding rect (inflated by 0.6)
  overlaps any obstacle.
- **Side effects:** None.
- **Algorithm:** If neither `dx` nor `dy` is within `_epsilon` (i.e. the segment is diagonal),
  treat it as blocked outright — the router only ever produces axis-aligned segments, so this
  doubles as an invariant check. Otherwise build the segment's bounding `Rect` (min/max of both
  endpoints), inflate it by 0.6 (a small edge-touch margin), and return whether any obstacle
  `.overlaps` it.
- **Usage:**
  ```dart
  stepCost = _segmentBlocked(a, b, obstacles)
      ? -1
      : _manhattan(a, b) + _congestionCost(a, b, routedSegments);
  ```
  (`_routeBetween`'s step-cost cache, lines 1490–1492.)
- **Notes:** The core geometric primitive of the router (`_pathClear`, `_stubBlocked`, and every
  first-time grid step in `_routeBetween`).

### `static double _congestionCost(Offset a, Offset b, _RoutedSegments routedSegments)` <a id="_congestioncost"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1599).
- **Purpose:** Penalize a candidate segment for running through, near, or across already-routed
  segments, so multiple edges sharing a corridor spread into distinct parallel tracks instead of
  overlapping.
- **Inputs:** `a`, `b` (candidate segment endpoints), `routedSegments`.
- **Returns:** `double` — summed penalty across the routed segments.
- **Side effects:** None.
- **Algorithm:** Delegates to [`_RoutedSegments.cost`](#cost): per routed segment, 180.0 on the
  same line with overlapping span, else 58.0 for a parallel one within `_routingTrackGap * 0.85`
  with overlapping span, else 28.0 for a perpendicular crossing.
- **Usage:**
  ```dart
  : _manhattan(a, b) + _congestionCost(a, b, routedSegments);
  ```
  (`_routeBetween`, line 1492; also `_pathScore`, line 1532.)
- **Notes:** Results are identical to the former linear scan over every routed segment; only the
  segments near the candidate's axis are now visited. Literal lane reuse is penalized roughly 6×
  harder than a crossing, with "too close but not coincident" in between.

### `static List<_Segment> _segmentsForPath(List<Offset> path)` <a id="_segmentsforpath"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1610).
- **Purpose:** Convert an accepted routed polyline into the `_Segment` list used for future
  congestion checks.
- **Inputs:** `path`.
- **Returns:** `List<_Segment>` — one per consecutive point pair whose length exceeds `_epsilon`
  (drops accidental zero-length duplicates).
- **Side effects:** None.
- **Algorithm:** Loop `i` from 1 to `path.length - 1`; if `(path[i] - path[i-1]).distance >
  _epsilon`, append `_Segment(path[i-1], path[i])`.
- **Usage:**
  ```dart
  paths[edge] = path;
  routedSegments.addAll(_segmentsForPath(path));
  ```
  (`_routeEdges`, lines 1180–1181.)
- **Notes:** Dropping zero-length segments is what lets `_RoutedSegments.addAll` file each segment
  as exactly one of horizontal or vertical.

### `static List<Offset> _simplifyPolyline(List<Offset> points)` <a id="_simplifypolyline"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1625).
- **Purpose:** Clean up a raw candidate polyline into its minimal orthogonal representation:
  dedupe near-identical points, then drop interior points that don't represent an actual turn.
- **Inputs:** `points`.
- **Returns:** `List<Offset>` — deduped and turn-simplified.
- **Side effects:** None.
- **Algorithm:**
  1. Dedupe: keep a point only if it's more than `_epsilon` away from the last kept point.
  2. If fewer than 3 points remain after dedup, return as-is (nothing to simplify).
  3. Otherwise walk the interior points: for each `current` between `previous` (last kept) and
     `next`, check if `previous→current→next` is a straight horizontal run (all three share y) or
     straight vertical run (all three share x); only keep `current` if it's neither (i.e. it's an
     actual turn point).
- **Usage:**
  ```dart
  final path = _simplifyPolyline([
    start,
    startExit,
    ...middle.skip(1),
    end,
  ]);
  ```
  (`_routeEdge`, lines 1309–1314.)
- **Notes:** A specialized, orthogonal-only simplification (not Douglas-Peucker) — it only removes
  points exactly collinear along one of the two grid axes.

### `static int _compareRoutesForLayout(ServiceRoute a, ServiceRoute b)` <a id="_compareroutesforlayout"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1695).
- **Purpose:** Order one service's routes for row assignment: by access lane first, then HTTP
  method, then display target.
- **Inputs:** `a`, `b` (`ServiceRoute`).
- **Returns:** Standard `Comparator<ServiceRoute>` `int` (negative/zero/positive).
- **Side effects:** None.
- **Algorithm:** Three-tier tie-break, returning as soon as one tier differs: (1)
  `_laneOrder(serviceAccessLaneForRoute(route))` (local < vpn < public); (2) first-hop method name
  (`_routeMethodName`), alphabetically; (3) `serviceRouteDisplayTarget(route)`, alphabetically,
  case-insensitive.
- **Usage:**
  ```dart
  final orderedRoutes = [...sourceRoutes]..sort(_compareRoutesForLayout);
  ```
  (`_routeRows`, line 1048.)
- **Notes:** `serviceAccessLaneForRoute`/`serviceRouteDisplayTarget` are defined in
  `lib/features/services/services/service_analysis.dart`, not this file.

### `static double _median(List<double> values)` <a id="_median"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1749).
- **Purpose:** Compute the statistical median of a list of row scores, used to derive a node's
  desired row from its routes/neighbors.
- **Inputs:** `values` (non-empty in every call site).
- **Returns:** `double` — the median value.
- **Side effects:** None.
- **Algorithm:** Sort a copy of `values`; if the count is odd, return the exact middle element;
  if even, return the average of the two middle elements.
- **Usage:**
  ```dart
  if (scores.isNotEmpty) desired[node.id] = _median(scores);
  ```
  (`_desiredRows`, line 1089, and again at line 1105 for neighbor propagation.)
- **Notes:** Using the median rather than the mean means one far-outlier route row doesn't drag a
  node's whole position toward it.

### `factory _RoutingGridBase.fromObstacles(List<Rect> obstacles, Size size)` <a id="_routinggridbase-fromobstacles"></a>
- **Kind:** factory constructor of `_RoutingGridBase`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1858).
- **Purpose:** Build the shared set of x/y routing-track coordinates derived once from node
  obstacles and canvas size, reused across every edge's pathfinding call.
- **Inputs:** `obstacles` (inflated node rects), `size` (canvas).
- **Returns:** A new `_RoutingGridBase` with populated `xs`/`ys`.
- **Side effects:** None.
- **Algorithm:** Always add the four canvas-margin tracks (`padding/2` and `size - padding/2` on
  each axis). For every obstacle, add four tracks offset `_routingTrackGap` *outside* its
  boundary (`left - gap`, `right + gap`, `top - gap`, `bottom + gap`) — deliberately never adding
  a track through the obstacle's own boundary or center, so the shared grid never routes a segment
  flush against (or through) a node. All values are clamped to the canvas and snapped to 0.5.
- **Usage:**
  ```dart
  final gridBase = _RoutingGridBase.fromObstacles(obstacles, size);
  ```
  (`_routeEdges`, line 1154 — built once per `build()` call and passed to every `_routeEdge`/
  `_routeBetween` invocation.)
- **Notes:** `_routeBetween` still adds per-call tracks on top of this shared base for the
  specific start/goal/routed segments of that one edge.

### `void addAll(Iterable<_Segment> segments)` <a id="addall"></a>
- **Kind:** method of `_RoutedSegments`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1898).
- **Purpose:** Add segments to the list and the axis indexes.
- **Inputs:** `segments`.
- **Returns:** `void`.
- **Side effects:** Mutates `all`, `_horizontal`, `_vertical`.
- **Algorithm:** Append each segment to `all`; insert a horizontal one into `_horizontal` at
  [`_lowerBound`](#_lowerbound) of its y, else a vertical one into `_vertical` at the lower bound
  of its x, keeping both lists sorted.
- **Usage:**
  ```dart
  routedSegments.addAll(_segmentsForPath(path));
  ```
  (`_routeEdges`, line 1181.)
- **Notes:** A segment is filed as horizontal or vertical, never both — `_segmentsForPath` drops
  zero-length segments. Insertion is O(n) per segment (list shift), paid once per routed segment.

### `double cost(Offset a, Offset b)` <a id="cost"></a>
- **Kind:** method of `_RoutedSegments`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1928).
- **Purpose:** Score how much a candidate segment conflicts with the routed segments.
- **Inputs:** `a`, `b` — the candidate's ends.
- **Returns:** `double` — 180 per routed segment on the same line whose span overlaps it, else 58
  per parallel one within `0.85 × _routingTrackGap` whose span overlaps, plus 28 per perpendicular
  one it crosses.
- **Side effects:** None.
- **Algorithm:** For a horizontal candidate at `y`: binary-search `_horizontal` from `y - near`
  and walk while `s.a.dy <= y + near`; add 180 for each that
  [`sameAxisOverlap`](#sameaxisoverlap)s the candidate, else 58 for each that
  [`nearAxisOverlap`](#nearaxisoverlap)s it. Then walk `_vertical` over
  `[minX - _epsilon, maxX + _epsilon]` and add 28 for each the candidate [`crosses`](#crosses). A
  vertical candidate mirrors this with the axes swapped.
- **Usage:**
  ```dart
  ) => routedSegments.cost(a, b);
  ```
  (`_congestionCost`, line 1603.)
- **Notes:** Applies the same three tests as checking the candidate against every segment, but
  visits only segments inside the candidate's band — parallel ones within the near distance of
  its line, perpendicular ones whose line lies within its span — so it produces the same sums. Costs are whole
  numbers, so the order of the sum cannot change the result.

### `static int _lowerBound(List<_Segment> sorted, double value, double Function(_Segment) key)` <a id="_lowerbound"></a>
- **Kind:** static method of `_RoutedSegments`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1988).
- **Purpose:** Find the first index whose key is at least `value`.
- **Inputs:** `sorted` (ascending by `key`), `value`, `key`.
- **Returns:** `int` — the insertion point, `sorted.length` when none.
- **Side effects:** None.
- **Algorithm:** Standard binary search over `[low, high)`: move `low` past `middle` while
  `key(sorted[middle]) < value`, else shrink `high` to `middle`.
- **Usage:**
  ```dart
  var i = _lowerBound(_horizontal, y - near, (s) => s.a.dy);
  ```
  (`cost`, lines 1935, 1949, 1959, 1973; `addAll`, lines 1903 and 1908.)
- **Notes:** None.

### `bool sameAxisOverlap(_Segment other)` <a id="sameaxisoverlap"></a>
- **Kind:** method of `_Segment`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 2027).
- **Purpose:** Determine whether two segments lie on the exact same horizontal or vertical line
  and their spans overlap — i.e. would visually coincide.
- **Inputs:** `other`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** If both segments are `horizontal` and share the same y (within `_epsilon`), defer
  to [`_rangesOverlap`](#_rangesoverlap) on their x spans; if both `vertical` and share the same x,
  defer to `_rangesOverlap` on their y spans; otherwise `false` (different axis or offset line).
- **Usage:**
  ```dart
  if (candidate.sameAxisOverlap(other)) {
  ```
  ([`_RoutedSegments.cost`](#cost), lines 1940 and 1964 — the 180 tier.)
- **Notes:** Stricter than `nearAxisOverlap` — the lines must coincide within `_epsilon`.

### `bool nearAxisOverlap(_Segment other, double distance)` <a id="nearaxisoverlap"></a>
- **Kind:** method of `_Segment`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 2044).
- **Purpose:** Determine whether two parallel segments run within a caller-supplied `distance` of
  each other and their spans overlap — a softer "too close" congestion signal rather than a hard
  obstacle.
- **Inputs:** `other`, `distance`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Same structure as `sameAxisOverlap` but the line-coincidence test uses `<=
  distance` instead of `< _epsilon`.
- **Usage:**
  ```dart
  } else if (candidate.nearAxisOverlap(other, near)) {
  ```
  ([`_RoutedSegments.cost`](#cost), lines 1942 and 1966, with `near = _routingTrackGap * 0.85` —
  the 58 tier.)
- **Notes:** The `0.85` factor keeps "near" a bit tighter than the actual track spacing, so
  properly spaced adjacent lanes are not penalized.

### `bool crosses(_Segment other)` <a id="crosses"></a>
- **Kind:** method of `_Segment`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 2061).
- **Purpose:** Determine whether a horizontal and a vertical segment actually intersect (a real
  T/X crossing), rather than merely being nearby.
- **Inputs:** `other`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** If `this` is horizontal and `other` is vertical, check `other`'s x falls within
  `this`'s x span *and* `this`'s y falls within `other`'s y span (both via
  [`_between`](#_between)); the symmetric case mirrors this; two segments on the same axis never
  "cross" by this definition.
- **Usage:**
  ```dart
  if (candidate.crosses(_vertical[i])) cost += 28.0;
  ```
  ([`_RoutedSegments.cost`](#cost), lines 1953 and 1977 — the 28 tier.)
- **Notes:** A perpendicular crossing is penalized far less than lane reuse because crossings are
  unavoidable in an orthogonal layout and not actually confusing.

### `static bool _rangesOverlap(double a1, double a2, double b1, double b2)` <a id="_rangesoverlap"></a>
- **Kind:** static method of `_Segment`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 2078).
- **Purpose:** Determine whether two 1-D ranges (each given as two unordered endpoints) overlap by
  more than `_epsilon`.
- **Inputs:** `a1`, `a2`, `b1`, `b2`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Normalize both ranges to `(min, max)` pairs; overlap iff
  `max(aMin, bMin) < min(aMax, bMax) - _epsilon` — a strict overlap requirement, so ranges that
  merely touch at an endpoint do not count.
- **Usage:**
  ```dart
  return _rangesOverlap(a.dx, b.dx, other.a.dx, other.b.dx);
  ```
  (`sameAxisOverlap`, lines 2031 and 2034; `nearAxisOverlap`, lines 2048 and 2051.)
- **Notes:** The strict comparison keeps two segments that just touch end-to-end on the same line
  from being penalized as overlapping.

### `static bool _between(double value, double start, double end)` <a id="_between"></a>
- **Kind:** static method of `_Segment`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 2091).
- **Purpose:** Inclusive range membership test with `_epsilon` slack on both ends, used to test
  whether a crossing point falls within a segment's span.
- **Inputs:** `value`, `start`, `end` (unordered).
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Normalize to `minValue = min(start, end) - _epsilon`, `maxValue = max(start, end)
  + _epsilon`; return `value >= minValue && value <= maxValue`.
- **Usage:**
  ```dart
  return _between(other.a.dx, a.dx, b.dx) &&
      _between(a.dy, other.a.dy, other.b.dy);
  ```
  (`crosses`, lines 2063–2068.)
- **Notes:** Unlike `_rangesOverlap`, this is deliberately inclusive, so a crossing exactly at a
  segment's endpoint still counts.

### `void add(_RouteState state)` <a id="add"></a>
- **Kind:** method of `_RouteHeap`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 2125).
- **Purpose:** Insert a new search state into the binary min-heap, maintaining heap order.
- **Inputs:** `state`.
- **Returns:** None.
- **Side effects:** Appends to `_items` and reorders it via `_bubbleUp`.
- **Algorithm:** Append `state` to the end of `_items`, then call
  [`_bubbleUp`](#_bubbleup) on its new index to restore the min-heap invariant — standard binary
  heap insert, `O(log n)`.
- **Usage:**
  ```dart
  heap.add(_RouteState(startState, _manhattan(start, goal)));
  ```
  (`_routeBetween`, line 1460, seeding the search; also for every relaxed neighbor at line 1505.)
- **Notes:** None beyond the standard binary-heap insert contract.

### `_RouteState removeFirst()` <a id="removefirst"></a>
- **Kind:** method of `_RouteHeap`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 2135).
- **Purpose:** Pop and return the lowest-cost state (the heap root), restoring heap order
  afterward.
- **Inputs:** None.
- **Returns:** `_RouteState` — the minimum-cost entry.
- **Side effects:** Mutates `_items` (removes the last element, may overwrite the root).
- **Algorithm:** Save `_items.first`; remove and save `_items.removeLast()`; if any items remain,
  move the removed last element into slot 0 and call [`_bubbleDown`](#_bubbledown) on it; return
  the saved first (root) value — standard binary heap extract-min, `O(log n)`.
- **Usage:**
  ```dart
  final current = heap.removeFirst();
  ```
  (`_routeBetween`, line 1464, the main search loop.)
- **Notes:** Correctly handles the single-element case: `first` and `last` are the same element,
  and the `_items.isNotEmpty` guard skips `_bubbleDown` on an empty heap.

### `void _bubbleUp(int index)` <a id="_bubbleup"></a>
- **Kind:** method of `_RouteHeap`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 2150).
- **Purpose:** Restore the min-heap invariant upward from `index` after an insertion.
- **Inputs:** `index`.
- **Returns:** `void`.
- **Side effects:** Mutates `_items` via `_swap`.
- **Algorithm:** While `index > 0`, compute `parent = (index - 1) >> 1`; if the parent's `.cost` is
  already `<=` the current item's, stop; otherwise `_swap` them and continue from `parent`.
- **Usage:**
  ```dart
  void add(_RouteState state) {
    _items.add(state);
    _bubbleUp(_items.length - 1);
  }
  ```
  (`add`, lines 2125–2128.)
- **Notes:** Standard array-backed binary heap parent-index arithmetic (`(i - 1) >> 1`).

### `void _bubbleDown(int index)` <a id="_bubbledown"></a>
- **Kind:** method of `_RouteHeap`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 2164).
- **Purpose:** Restore the min-heap invariant downward from `index` after the root is replaced.
- **Inputs:** `index`.
- **Returns:** `void`.
- **Side effects:** Mutates `_items` via `_swap`.
- **Algorithm:** Loop: compute `left = index*2+1`, `right = left+1`; find whichever of
  `{index, left, right}` (bounds-checked) has the smallest `.cost` (`smallest`); if it's still
  `index`, stop; otherwise `_swap` `index` and `smallest` and continue from `smallest`.
- **Usage:**
  ```dart
  if (_items.isNotEmpty) {
    _items[0] = last;
    _bubbleDown(0);
  }
  ```
  (`removeFirst`, lines 2138–2141.)
- **Notes:** Standard array-backed binary heap child-index arithmetic (`i*2+1`, `i*2+2`).
