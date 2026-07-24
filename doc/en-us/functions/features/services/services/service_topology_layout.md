# lib/features/services/services/service_topology_layout.dart

`ServiceTopologyLayout` is a pure, static layout/routing engine for the services-topology graph
view: given a `ServiceTopologyGraph` (nodes/edges, from `service_analysis.dart`) and the
`ServiceRoute` list that produced it, `ServiceTopologyLayout.build` computes a canvas `Size`, a
`Rect` per node, an integer rank per node, and a pre-routed orthogonal polyline (`List<Offset>`)
per edge. The widget layer (`ServiceTopologyView` in
`../../../../features/services/views/service_list_page.md`, called from
`lib/features/services/views/service_list_page.dart`) only paints these precomputed values — it
does no layout or pathfinding of its own, and the result is cached per graph/routes/viewport/
rotation so switching modes doesn't force a relayout. This file is the single most
algorithm-dense file in the app: most of its private helpers implement real graph-rank
propagation, row compaction, or orthogonal A*-style pathfinding rather than widget composition.

See [Service Topology Layout](../../../../algorithms/service-topology-layout.md) for the
high-level description of the two algorithms this file implements (dynamic semantic ranking, and
fast-clear-path-first orthogonal routing with A* fallback) and
[Services and Topology](../../../../features/services-topology.md) for the feature this layout
renders. The concept doc's cited function names (`_nodeRanks`, `_alignSiblingPortRanks`,
`_placeNodes`, `_fastRouteBetween`, `_routeBetween`, `_RouteHeap`/`_RouteState`,
`_congestionCost`) were verified against the current source while writing this page; one detail
in the concept doc is refined below: `_nodeRanks` does not start every node at rank 0 — device
nodes start at rank 0 and every other node kind starts at rank 1 (see that entry below).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ServiceTopologyLayout` | class | B | Immutable layout result: canvas size, node rects, node ranks, edge paths. |
| `size` | field (`ServiceTopologyLayout`) | B | Computed canvas size for the topology. |
| `nodeRects` | field (`ServiceTopologyLayout`) | B | Node id → placed `Rect`. |
| `nodeRanks` | field (`ServiceTopologyLayout`) | B | Node id → assigned integer rank (column). |
| `edgePaths` | field (`ServiceTopologyLayout`) | B | Edge → pre-routed orthogonal polyline. |
| `ServiceTopologyLayout.new` | constructor (`ServiceTopologyLayout`) | B | Forwarding const constructor for the four required fields. |
| `nodeWidth` | static const (`ServiceTopologyLayout`) | B | Default node card width (204.0). |
| `nodeHeight` | static const (`ServiceTopologyLayout`) | B | Default node card height (76.0). |
| `portChipSize` | static const (`ServiceTopologyLayout`) | B | Compact port-chip width/height (52.0). |
| `rankGap` | static const (`ServiceTopologyLayout`) | B | Horizontal gap between rank columns (38.0). |
| `verticalGap` | static const (`ServiceTopologyLayout`) | B | Minimum vertical gap between stacked nodes (24.0). |
| `padding` | static const (`ServiceTopologyLayout`) | B | Canvas edge padding (24.0). |
| `_routingMargin` | static const (`ServiceTopologyLayout`) | B | Extra canvas margin reserved for routed edges (72.0). |
| `_routingClearance` | static const (`ServiceTopologyLayout`) | B | Obstacle inflation applied to node rects during routing (14.0). |
| `_routingEscape` | static const (`ServiceTopologyLayout`) | B | Length of the perpendicular exit/entry stub at each node (18.0). |
| `_routingTrackGap` | static const (`ServiceTopologyLayout`) | B | Spacing between parallel routing tracks/lanes (22.0). |
| [`build`](#build) | static method (`ServiceTopologyLayout`) | A | Compute node positions and pre-routed edge paths for a topology graph. |
| [`_placeNodes`](#_placenodes) | static method (`ServiceTopologyLayout`) | A | Place nodes into rank columns and compact rows within each rank. |
| [`_compactRankRows`](#_compactrankrows) | static method (`ServiceTopologyLayout`) | A | Compact desired rows within one rank before turning them into y positions. |
| [`_compactDesiredRows`](#_compactdesiredrows) | static method (`ServiceTopologyLayout`) | A | Remove row gaps only reserved by routes without visible nodes. |
| [`_compactRowValueMap`](#_compactrowvaluemap) | static method (`ServiceTopologyLayout`) | A | Build a compact value map from sparse desired-row values. |
| [`_compactRowValue`](#_compactrowvalue) | static method (`ServiceTopologyLayout`) | A | Look up a compacted row value for one raw desired row. |
| [`_nodeRanks`](#_noderanks) | static method (`ServiceTopologyLayout`) | A | Propagate and densify the per-node horizontal rank (column). |
| [`_alignSiblingPortRanks`](#_alignsiblingportranks) | static method (`ServiceTopologyLayout`) | A | Pull sibling ingress/public port nodes to the same rank. |
| `_nodeWidth` | static method (`ServiceTopologyLayout`) | B | Node card width, or `portChipSize` when the node is compact. |
| `_nodeHeight` | static method (`ServiceTopologyLayout`) | B | Node card height, or `portChipSize` when the node is compact. |
| [`_routeRows`](#_routerows) | static method (`ServiceTopologyLayout`) | A | Assign each route a preferred row along a virtual row axis. |
| [`_desiredRows`](#_desiredrows) | static method (`ServiceTopologyLayout`) | A | Derive each node's preferred row from its routes/neighbors. |
| [`_routeEdges`](#_routeedges) | static method (`ServiceTopologyLayout`) | A | Entry point: route every edge into an orthogonal polyline. |
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

**Row-count note:** `grep -c 'Purpose:' service_topology_layout.dart` returns **56** — every method,
constructor, getter, and factory in the file carries a `/// Purpose:` doc comment. The Declarations
table above has **87** rows because it also lists declarations the big-file/doc-comment convention
in this codebase does not annotate: the 5 class/enum declarations themselves (`ServiceTopologyLayout`,
`_TopologySide`, `_RoutingGridBase`, `_Segment`, `_RouteState`, `_RouteHeap` — 6, one of which,
`_TopologySide`, is an enum), 15 plain data fields across those classes, 12 `static const`/top-level
constants (10 layout constants + `_epsilon`/`_rowEpsilon`), and 2 trivial one-line getters
(`_Segment.horizontal`/`.vertical`) that read as property accessors rather than doc-commented
behavior. 56 (documented) + 31 (undocumented fields/consts/classes/getters) = 87, which reconciles
exactly.

## Documentation

### `static ServiceTopologyLayout build(ServiceTopologyGraph graph, List<ServiceRoute> routes, double viewportWidth)` <a id="build"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 41).
- **Purpose:** Compute node rectangles, ranks, canvas size, and pre-routed edge polylines for one
  topology graph/route set/viewport width.
- **Inputs:** `graph` (nodes + edges), `routes` (drives row grouping), `viewportWidth` (minimum
  canvas width).
- **Returns:** A new `ServiceTopologyLayout` with `size`, `nodeRects`, `nodeRanks`, `edgePaths`.
- **Side effects:** None — pure function of its inputs.
- **Algorithm:**
  1. Build `nodeMap` (id → node) and `validEdges` — edges whose `from`/`to` both resolve to a
     real node are kept; dangling edges are silently dropped.
  2. Build `incoming`/`outgoing` adjacency sets for every node from `validEdges`.
  3. Compute `routeRows` ([`_routeRows`](#_routerows)), then `desiredRows`
     ([`_desiredRows`](#_desiredrows)) from routes/adjacency.
  4. Compute `nodeRanks` ([`_nodeRanks`](#_noderanks)) independently from the edge graph.
  5. Compact `desiredRows` globally ([`_compactDesiredRows`](#_compactdesiredrows)), then place
     nodes into rank columns with rank-local row compaction
     ([`_placeNodes`](#_placenodes)) to get `nodeRects`.
  6. Compute canvas `size` as `max(viewportWidth, maxRight + padding + _routingMargin)` ×
     `max(360.0, maxBottom + padding + _routingMargin)`, from the furthest node rect's
     right/bottom.
  7. Route every edge ([`_routeEdges`](#_routeedges)) against the now-final rects/ranks/size to
     get `edgePaths`.
- **Usage:**
  ```dart
  final layout = ServiceTopologyLayout.build(
    request.graph,
    request.routes,
    request.viewportWidth.toDouble(),
  );
  ```
  (`lib/features/services/views/service_list_page.dart`, `_calculateLayout`, deferred to run after
  the first frame per `AGENTS.md`'s `v0.5.12` note.)
- **Notes:** Row/rank computation (steps 3–4) is intentionally independent of node placement
  (step 5) — ranks come purely from the edge graph, while rows come from routes/neighbors; they
  are only combined when `_placeNodes` sorts nodes within each rank by desired row.

### `static Map<String, Rect> _placeNodes(ServiceTopologyGraph graph, Map<String, int> nodeRanks, Map<String, double> desiredRows)` <a id="_placenodes"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 101).
- **Purpose:** Place nodes into rank (column) buckets, order them within each rank, and lay out
  x/y rectangles with rank-local row compaction.
- **Inputs:** `graph`, `nodeRanks` (from `_nodeRanks`), `desiredRows` (already globally compacted).
- **Returns:** `Map<String, Rect>` — one placed rectangle per node id.
- **Side effects:** None.
- **Algorithm:**
  1. Group nodes by rank (`ranked[rank]`), then sort each rank's nodes by
     `desiredRows` ascending, tie-broken by [`_roleOrder`](#build) then `_laneBucket` then label.
  2. Compute each rank's column width as the max `_nodeWidth` of its nodes; lay out `rankX`
     left-to-right, advancing by `rankWidth + rankGap` per rank.
  3. For each rank, recompute a **rank-local** compacted row map via
     [`_compactRankRows`](#_compactrankrows) (independent of the global compaction already applied
     to `desiredRows` — this removes blank bands that exist only because *other* ranks used those
     rows).
  4. Walk the rank's nodes top-to-bottom: target y is `padding + row * (nodeHeight + 44)`, but
     never less than `previousBottom + verticalGap` (so compaction never overlaps the previous
     node); x is centered within the rank's column width.
- **Usage:**
  ```dart
  final nodeRects = _placeNodes(graph, nodeRanks, compactRows);
  ```
  (`build`, line 74.)
- **Notes:** The vertical row stride (`nodeHeight + 44`) is a fixed constant, separate from
  `verticalGap` (24.0) — `verticalGap` only kicks in as a minimum-spacing floor when two rows
  compact close enough together to otherwise collide.

### `static Map<String, double> _compactRankRows(List<ServiceTopologyNode> nodes, Map<String, double> desiredRows)` <a id="_compactrankrows"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 168).
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
  final rankRows = _compactRankRows(nodes, desiredRows);
  ```
  (`_placeNodes`, line 147.)
- **Notes:** Because compaction is rank-local, the same raw `desiredRows` value can map to a
  different compacted row number in two different ranks — this is intentional (each rank only
  cares about its own vertical gaps).

### `static Map<String, double> _compactDesiredRows(ServiceTopologyGraph graph, Map<String, double> desiredRows)` <a id="_compactdesiredrows"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 186).
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
  (`build`, line 73.)
- **Notes:** This is the *global* compaction pass (across all ranks at once), run before
  `_placeNodes`; `_compactRankRows` is a second, rank-local compaction run afterward for the same
  purpose at finer granularity.

### `static Map<double, double> _compactRowValueMap(Iterable<double> rows)` <a id="_compactrowvaluemap"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 211).
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
  (`_compactRankRows`, line 172–174.)
- **Notes:** The `clamp(0.72, 1.0)` bounds are the load-bearing constants for how "loose" versus
  "tight" compacted rows can look; they were not surfaced in the concept doc and are only visible
  by reading this method.

### `static double _compactRowValue(double row, Map<double, double> rowMap)` <a id="_compactrowvalue"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 238).
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
  (`_compactRankRows`, line 177.)
- **Notes:** Falling back to the original `row` (rather than throwing) means a value from outside
  the map it was built from is preserved as-is instead of being remapped.

### `static Map<String, int> _nodeRanks(ServiceTopologyGraph graph, List<ServiceTopologyEdge> validEdges)` <a id="_noderanks"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 250).
- **Purpose:** Derive each node's horizontal rank (column) from the edge graph via relaxation,
  then compress the resulting sparse ranks into a dense `0..N` sequence.
- **Inputs:** `graph`, `validEdges`.
- **Returns:** `Map<String, int>` — node id → dense rank.
- **Side effects:** None.
- **Algorithm:**
  1. Seed `ranks`: every node of kind `ServiceTopologyNodeKind.device` starts at rank 0; every
     other node kind starts at rank 1 (this differs from a naive "everyone starts at 0" reading —
     device nodes are pinned to the left edge from the outset).
  2. Set `rankLimit = max(2, nodeCount + 1)`. For up to `nodeCount + 2` iterations: for every edge,
     relax `ranks[edge.to] = max(ranks[edge.to], min(rankLimit, ranks[edge.from] + 1))`; also call
     [`_alignSiblingPortRanks`](#_alignsiblingportranks) each iteration and OR its `changed` result
     in. Stop early once a full pass makes no change.
  3. Collect `uniqueRanks` (sorted, deduped) and remap each node's raw rank to its index in that
     sorted list, producing a dense `0..N` rank sequence with no unused gaps.
- **Usage:**
  ```dart
  final nodeRanks = _nodeRanks(graph, validEdges);
  ```
  (`build`, line 72.)
- **Notes:** `rankLimit` caps propagation so a cyclic edge graph cannot grow ranks unboundedly —
  it guarantees termination (the fixed-point loop bound `nodeCount + 2` is also a hard iteration
  cap even if `changed` never settles) instead of preventing cycles outright.

### `static bool _alignSiblingPortRanks(List<ServiceTopologyEdge> edges, Map<String, ServiceTopologyNode> nodeMap, Map<String, int> ranks)` <a id="_alignsiblingportranks"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 291).
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
  (`_nodeRanks`, line 270–272, called once per relaxation iteration.)
- **Notes:** Only ever raises ranks (never lowers), consistent with `_nodeRanks`'s monotonic
  relaxation; being called inside the same loop means sibling alignment can itself trigger further
  edge relaxation on the next iteration.

### `static Map<String, double> _routeRows(ServiceTopologyGraph graph, List<ServiceRoute> routes, Map<String, ServiceTopologyNode> nodeMap)` <a id="_routerows"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 349).
- **Purpose:** Assign every route a preferred row along a virtual row axis, grouped by source
  service and ordered so routes from the same source land on adjacent rows.
- **Inputs:** `graph`, `routes`, `nodeMap`.
- **Returns:** `Map<String, double>` — route id → row score.
- **Side effects:** None.
- **Algorithm:**
  1. Group routes by `_serviceNodeId(route.sourceServiceId)` into `routesBySource`.
  2. Collect all source ids (routed or not — including local-service nodes with zero routes) and
     sort them alphabetically by label.
  3. Walk sources in that order, maintaining a running `row`: a source with no routes still
     advances `row` by 1.35 (reserves a gap without emitting any row entries); a source with
     routes sorts them via [`_compareRoutesForLayout`](#_compareroutesforlayout), assigns each a
     sequential row (`row += 1` per route), then adds a further 0.38 gap before the next source.
- **Usage:**
  ```dart
  final routeRows = _routeRows(graph, routes, nodeMap);
  ```
  (`build`, line 64.)
- **Notes:** The 1.35/0.38/1.0 spacing constants are exactly what
  [`_compactRowValueMap`](#_compactrowvaluemap)'s `clamp(0.72, 1.0)` step later normalizes — an
  empty-source gap (1.35) and an inter-source gap (0.38) compact very differently once real nodes
  are involved.

### `static Map<String, double> _desiredRows(ServiceTopologyGraph graph, List<ServiceRoute> routes, Map<String, double> routeRows, Map<String, Set<String>> incoming, Map<String, Set<String>> outgoing)` <a id="_desiredrows"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 399).
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
  final desiredRows = _desiredRows(graph, routes, routeRows, incoming, outgoing);
  ```
  (`build`, line 65–71.)
- **Notes:** The 10-iteration cap on neighbor propagation (step 3) means a very long chain of
  otherwise-unrouted nodes could still fall through to the step-4 fallback if propagation hasn't
  reached them within 10 passes — in practice bounded by typical topology diameters.

### `static Map<ServiceTopologyEdge, List<Offset>> _routeEdges(List<ServiceTopologyEdge> validEdges, Map<String, Rect> rects, Map<String, int> ranks, Size size)` <a id="_routeedges"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 469).
- **Purpose:** Entry point for edge routing: builds shared obstacle/grid state once, then routes
  every edge against it, accumulating routed segments so later edges avoid earlier ones.
- **Inputs:** `validEdges`, `rects` (placed node rects), `ranks`, `size` (canvas).
- **Returns:** `Map<ServiceTopologyEdge, List<Offset>>` — one polyline per edge (possibly empty on
  routing failure).
- **Side effects:** None (builds fresh local collections).
- **Algorithm:**
  1. Compute `outgoingOffsets`/`incomingOffsets` via [`_portOffsets`](#_portoffsets) so edges
     sharing a node side fan out.
  2. Build `obstacles` as every node rect inflated by `_routingClearance`, then build a shared
     [`_RoutingGridBase.fromObstacles`](#_routinggridbase-fromobstacles).
  3. Order edges by descending [`_edgeSpan`](#build) (longest first), then by
     `_laneRank(edge.lane)`, then by `'from->to'` string — so the edges most likely to need real
     pathfinding claim direct corridors before shorter edges have to route around them.
  4. For each edge in that order, call [`_routeEdge`](#_routeedge) with the shared obstacles/grid
     and the segments routed so far; append the result's segments (via
     [`_segmentsForPath`](#_segmentsforpath)) to `routedSegments` before moving to the next edge.
- **Usage:**
  ```dart
  final edgePaths = _routeEdges(validEdges, nodeRects, nodeRanks, size);
  ```
  (`build`, line 86.)
- **Notes:** `routedSegments` accumulates monotonically across the whole call — congestion cost
  (via `_congestionCost`) is therefore order-dependent: earlier-routed (longer) edges get first
  pick of clear corridors, and later edges pay a cost to detour around them.

### `static Map<ServiceTopologyEdge, double> _portOffsets(List<ServiceTopologyEdge> edges, Map<String, Rect> rects, Map<String, int> ranks, {required bool outgoing})` <a id="_portoffsets"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 527).
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
  (`_routeEdges`, line 475–486.)
- **Notes:** Called twice per layout (once per direction) since an edge's exit fan-out on its
  `from` node is independent of its entry fan-out on its `to` node.

### `static List<Offset> _routeEdge({required Rect from, required Rect to, required double fromOffset, required double toOffset, required List<Rect> obstacles, required _RoutingGridBase gridBase, required List<_Segment> routedSegments, required Size size})` <a id="_routeedge"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 571).
- **Purpose:** Route one edge between two placed node rects, trying multiple anchor-side
  candidates and keeping whichever produces the lowest-scoring valid path.
- **Inputs:** `from`/`to` rects, per-edge port offsets, shared `obstacles`/`gridBase`,
  `routedSegments` routed so far, canvas `size`.
- **Returns:** A simplified orthogonal polyline, or `[]` if every candidate anchor pair fails.
- **Side effects:** None.
- **Algorithm:**
  1. Determine `forward` (`to` is right of `from`) and `sameRank` (centers within 8px
     horizontally); pick a preferred `startSide`/`endSide`: same-rank edges exit/enter whichever
     side (`left`/`right`) faces away from the canvas midline, otherwise the natural
     forward/backward sides.
  2. Build an ordered, deduplicated candidate list: the preferred pair first, then the four
     `{left,right}×{left,right}` combinations as fallbacks.
  3. For each candidate: compute anchor points via [`_anchor`](#build) + offset, then push them
     out by `_routingEscape` along [`_sideVector`](#build) and clamp to the canvas
     ([`_clampOffset`](#build)) to get `startExit`/`endEntry`. Skip the candidate if either stub is
     blocked by an obstacle other than the node's own inflated rect
     ([`_stubBlocked`](#_stubblocked)).
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
  (`_routeEdges`, line 506–515.)
- **Notes:** All 5 candidate anchor pairs are tried unconditionally (no early exit on first
  success) — this is a fixed, small combinatorial search (≤5 candidates × 2 routing attempts each)
  rather than a greedy first-match, trading a bounded amount of extra work for a cleaner picked
  route.

### `static List<Offset>? _fastRouteBetween({required Offset start, required Offset goal, required List<Rect> obstacles, required List<_Segment> routedSegments, required Size size})` <a id="_fastroutebetween"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 666).
- **Purpose:** Try a battery of cheap, direct orthogonal candidate paths between two already-
  escaped points before falling back to full grid pathfinding.
- **Inputs:** `start`, `goal` (already pushed past their nodes' stubs), `obstacles`,
  `routedSegments`, `size`.
- **Returns:** The best clear simplified polyline found, or `null` if none of the candidates are
  obstacle-clear (signaling the caller to fall back to `_routeBetween`).
- **Side effects:** None.
- **Algorithm:** Build and test candidates via a local `addCandidate` helper that simplifies
  ([`_simplifyPolyline`](#_simplifypolyline)) and obstacle-checks
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
  final middle = _fastRouteBetween(
    start: startExit,
    goal: endEntry,
    obstacles: obstacles,
    routedSegments: routedSegments,
    size: size,
  ) ?? _routeBetween(...);
  ```
  (`_routeEdge`, line 628–643.)
- **Notes:** This is the optimization the concept doc and `AGENTS.md` describe: most edges in a
  real topology (same or adjacent rank, nothing between them) resolve here without ever running
  the A*-style grid search in `_routeBetween`.

### `static List<Offset>? _routeBetween({required Offset start, required Offset goal, required List<Rect> obstacles, required _RoutingGridBase gridBase, required List<_Segment> routedSegments, required Size size})` <a id="_routebetween"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 726).
- **Purpose:** Find an obstacle-avoiding orthogonal path between two escaped points using an
  A*-style priority-queue search over a shared+per-edge coordinate grid.
- **Inputs:** `start`, `goal`, `obstacles`, `gridBase` (shared tracks), `routedSegments`, `size`.
- **Returns:** A simplified polyline, or `null` if `start`/`goal` don't land on a grid coordinate
  or no path is found.
- **Side effects:** None (builds fresh local search state each call).
- **Algorithm:**
  1. Extend `gridBase`'s shared `xs`/`ys` with per-call tracks: around `start`/`goal` themselves
     (±`_routingTrackGap`), and around every already-`routedSegments` segment (offset on its
     perpendicular axis) — so new lanes open up next to existing routed edges instead of forcing
     everything through the same shared tracks.
  2. Sort the combined coordinates into `xValues`/`yValues`; locate `start`/`goal` grid indices;
     return `null` if either isn't an exact grid point.
  3. Run a Dijkstra/A* search over states `(point, direction)` (`direction`: 0 = start, 1 =
     horizontal move, 2 = vertical move), using [`_RouteHeap`](#add) as the open set, ordered by
     `g + heuristic` where the heuristic is [`_manhattan`](#_median) distance to `goal`. Distances
     are held in a flat `List<double>` sized `pointCount * 3` (one slot per point per direction).
  4. For each popped state, expand to the 4 orthogonal grid neighbors; skip a neighbor if
     [`_segmentBlocked`](#_segmentblocked) rejects the connecting segment. Edge cost = `_manhattan`
     step + a 26.0 turn penalty (only if `currentDirection` is set and differs from the neighbor's
     direction) + [`_congestionCost`](#_congestioncost) against `routedSegments`. Relax and push
     the neighbor state only if the new cost strictly improves (`nextCost + _epsilon <
     distances[nextState]`).
  5. Stop as soon as any state reaching `goalPoint` is popped (guaranteed lowest-cost first by the
     min-heap); reconstruct the path by walking `previous[]` back to `start`, reverse it, and
     simplify ([`_simplifyPolyline`](#_simplifypolyline)).
- **Usage:**
  ```dart
  final middle = _fastRouteBetween(...) ?? _routeBetween(
    start: startExit,
    goal: endEntry,
    obstacles: obstacles,
    gridBase: gridBase,
    routedSegments: routedSegments,
    size: size,
  );
  ```
  (`_routeEdge`, line 628–643.)
- **Notes:** This is the "A* fallback" the concept doc and `AGENTS.md` refer to; because it only
  runs when `_fastRouteBetween` fails, its `O((grid size) log(grid size))` cost is paid rarely in
  practice. The 3-state-per-point direction encoding is what lets the turn-penalty term
  distinguish "continuing straight" from "just turned" without a separate parent-pointer lookup.

### `static double _pathScore(List<Offset> path, List<_Segment> routedSegments)` <a id="_pathscore"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 844).
- **Purpose:** Score a fully-formed routed path so that competing anchor-pair/candidate paths can
  be ranked and the cleanest one picked.
- **Inputs:** `path`, `routedSegments` (previously committed segments, for congestion).
- **Returns:** `double.infinity` if `path.length < 2`; otherwise a lower-is-better score.
- **Side effects:** None.
- **Algorithm:** For each consecutive point pair: add [`_manhattan`](#_median) distance, add
  [`_congestionCost`](#_congestioncost) against `routedSegments`, and add a 26.0 penalty whenever
  the segment's direction (horizontal vs vertical, from the `dx`/`dy` epsilon test) differs from
  the previous segment's direction.
- **Usage:**
  ```dart
  final score = _pathScore(path, routedSegments);
  if (score < bestScore) {
    bestScore = score;
    bestPath = path;
  }
  ```
  (`_routeEdge`, line 651–655.)
- **Notes:** Uses the same 26.0 turn-penalty constant as `_routeBetween`'s search cost, so paths
  found by the fast router and the A* router are scored on a consistent scale and can be compared
  directly by `_routeEdge`.

### `static bool _pathClear(List<Offset> path, List<Rect> obstacles)` <a id="_pathclear"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 867).
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
  (`_fastRouteBetween`'s local `addCandidate`, line 676–677.)
- **Notes:** This is the "check whether every segment in a candidate polyline avoids obstacles"
  check the concept doc refers to as `_isSegmentPathClear`-style validation.

### `static bool _stubBlocked(Offset a, Offset b, List<Rect> obstacles, {required Rect allowed})` <a id="_stubblocked"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 880).
- **Purpose:** Check whether a node's short exit/entry stub segment is blocked by some *other*
  obstacle (excluding the node's own inflated rect, which the stub is expected to leave through).
- **Inputs:** `a`, `b` (stub endpoints), `obstacles`, `allowed` (the node's own inflated rect, to
  ignore).
- **Returns:** `true` if any obstacle other than `allowed` blocks the stub.
- **Side effects:** None.
- **Algorithm:** Loop over `obstacles`, skipping any that is [`_sameRect`](#build) as `allowed`;
  call [`_segmentBlocked`](#_segmentblocked) against each remaining single-obstacle list, returning
  `true` on the first hit.
- **Usage:**
  ```dart
  if (_stubBlocked(start, startExit, obstacles, allowed: fromObstacle) ||
      _stubBlocked(endEntry, end, obstacles, allowed: toObstacle)) {
    continue;
  }
  ```
  (`_routeEdge`, line 624–627.)
- **Notes:** Without the `allowed` exclusion, every stub would be flagged as blocked by the very
  node it's leaving/entering, since the stub necessarily starts on that node's own inflated
  boundary.

### `static bool _segmentBlocked(Offset a, Offset b, List<Rect> obstacles)` <a id="_segmentblocked"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 898).
- **Purpose:** Check one orthogonal segment against the full obstacle list.
- **Inputs:** `a`, `b`, `obstacles`.
- **Returns:** `true` if the segment is non-orthogonal, or if its bounding rect (inflated by 0.6)
  overlaps any obstacle.
- **Side effects:** None.
- **Algorithm:** If neither `dx` nor `dy` is within `_epsilon` (i.e. the segment is diagonal),
  treat it as blocked outright — the router only ever produces axis-aligned segments, so this
  doubles as an invariant check. Otherwise build the segment's bounding `Rect` (min/max of both
  endpoints), inflate it by 0.6 (a small anti-aliasing/edge-touch margin), and return whether any
  obstacle `.overlaps` it.
- **Usage:**
  ```dart
  if (_segmentBlocked(a, b, obstacles)) continue;
  ```
  (`_routeBetween`'s neighbor expansion, line 813.)
- **Notes:** This is the core geometric primitive nearly every routing function above ultimately
  depends on (`_pathClear`, `_stubBlocked`, and every neighbor expansion in `_routeBetween`).

### `static double _congestionCost(Offset a, Offset b, List<_Segment> routedSegments)` <a id="_congestioncost"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 916).
- **Purpose:** Penalize a candidate segment for running through, near, or across already-routed
  segments, so multiple edges sharing a corridor spread into distinct parallel tracks instead of
  overlapping.
- **Inputs:** `a`, `b` (candidate segment endpoints), `routedSegments`.
- **Returns:** `double` — summed penalty across every prior segment.
- **Side effects:** None.
- **Algorithm:** Wrap `a`/`b` as a `_Segment` candidate; for each prior `segment`, add exactly one
  of, in priority order: 180.0 if [`sameAxisOverlap`](#sameaxisoverlap) (literal overlap on the
  same line), else 58.0 if [`nearAxisOverlap`](#nearaxisoverlap) within `_routingTrackGap * 0.85`
  (running in an adjacent, too-close lane), else 28.0 if [`crosses`](#crosses) (a simple
  perpendicular crossing) — otherwise 0. Costs from different prior segments accumulate (summed).
- **Usage:**
  ```dart
  final congestionCost = _congestionCost(a, b, routedSegments);
  final nextCost = currentCost + _manhattan(a, b) + turnCost + congestionCost;
  ```
  (`_routeBetween`, line 818–820; also used directly by `_pathScore`.)
- **Notes:** The three penalty tiers (180 / 58 / 28) are ordered so that literal lane reuse is
  penalized roughly 3× harder than a simple crossing, and "too close but not coincident" sits
  between the two — this is the concrete implementation the concept doc's "turn/congestion cost"
  description refers to.

### `static List<_Segment> _segmentsForPath(List<Offset> path)` <a id="_segmentsforpath"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 940).
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
  (`_routeEdges`, line 516–517.)
- **Notes:** This is how a newly-routed edge's path becomes an obstacle-adjacent input (via
  `_congestionCost`) for every edge routed after it in the same `_routeEdges` call.

### `static List<Offset> _simplifyPolyline(List<Offset> points)` <a id="_simplifypolyline"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 955).
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
  final path = _simplifyPolyline([start, startExit, ...middle.skip(1), end]);
  ```
  (`_routeEdge`, line 645–650.)
- **Notes:** This is a specialized, orthogonal-only simplification (not a general Douglas-Peucker
  pass) — it can only ever remove points that are exactly collinear along one of the two grid
  axes, matching the fact every segment produced by this router is axis-aligned.

### `static int _compareRoutesForLayout(ServiceRoute a, ServiceRoute b)` <a id="_compareroutesforlayout"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1025).
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
  (`_routeRows`, line 384.)
- **Notes:** `serviceAccessLaneForRoute`/`serviceRouteDisplayTarget` are defined in
  `lib/features/services/services/service_analysis.dart`, not this file — this comparator is the
  layout module's own opinion on route ordering, independent of however routes are ordered
  elsewhere in the UI.

### `static double _median(List<double> values)` <a id="_median"></a>
- **Kind:** static method of `ServiceTopologyLayout`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1079).
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
  (`_desiredRows`, line 425, and again at line 441 for neighbor propagation.)
- **Notes:** Using the median rather than the mean means one far-outlier route row doesn't drag a
  node's whole position toward it — the node instead lands with the "typical" row of its routes.

### `factory _RoutingGridBase.fromObstacles(List<Rect> obstacles, Size size)` <a id="_routinggridbase-fromobstacles"></a>
- **Kind:** factory constructor of `_RoutingGridBase`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1188).
- **Purpose:** Build the shared set of x/y routing-track coordinates derived once from node
  obstacles and canvas size, reused across every edge's pathfinding call.
- **Inputs:** `obstacles` (inflated node rects), `size` (canvas).
- **Returns:** A new `_RoutingGridBase` with populated `xs`/`ys`.
- **Side effects:** None.
- **Algorithm:** Always add the four canvas-margin tracks (`padding/2` and `size - padding/2` on
  each axis). For every obstacle, add four tracks offset `_routingTrackGap` *outside* its
  boundary (`left - gap`, `right + gap`, `top - gap`, `bottom + gap`) — deliberately never adding
  a track through the obstacle's own left/right/top/bottom coordinate, so the shared grid never
  routes a segment flush against (or through) a node's boundary.
- **Usage:**
  ```dart
  final gridBase = _RoutingGridBase.fromObstacles(obstacles, size);
  ```
  (`_routeEdges`, line 490 — built once per `build()` call and passed to every `_routeEdge`/
  `_routeBetween` invocation.)
- **Notes:** Building this once per layout (rather than per edge) is the "reused across all edge
  searches" optimization the concept doc calls out; `_routeBetween` still adds per-call extra
  tracks on top of this shared base for the specific start/goal/routed-segments of that one edge.

### `bool sameAxisOverlap(_Segment other)` <a id="sameaxisoverlap"></a>
- **Kind:** method of `_Segment`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1230).
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
  if (candidate.sameAxisOverlap(segment)) {
    cost += 180.0;
  }
  ```
  (`_congestionCost`, line 924–925 — the highest-penalty congestion tier.)
- **Notes:** This is a stricter check than `nearAxisOverlap` — it requires the lines to coincide
  exactly (within `_epsilon`), not merely run close together.

### `bool nearAxisOverlap(_Segment other, double distance)` <a id="nearaxisoverlap"></a>
- **Kind:** method of `_Segment`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1247).
- **Purpose:** Determine whether two parallel segments run within a caller-supplied `distance` of
  each other and their spans overlap — used as a softer "too close" congestion signal rather than
  a hard obstacle.
- **Inputs:** `other`, `distance` (tolerance, in practice `_routingTrackGap * 0.85`).
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Same structure as `sameAxisOverlap` but the line-coincidence test uses `<=
  distance` instead of `< _epsilon`, so near-parallel (not exactly coincident) tracks within
  `distance` of each other still count as overlapping.
- **Usage:**
  ```dart
  } else if (candidate.nearAxisOverlap(segment, _routingTrackGap * 0.85)) {
    cost += 58.0;
  }
  ```
  (`_congestionCost`, line 926–927.)
- **Notes:** The `0.85` multiplier on `_routingTrackGap` at the call site means "near" is
  deliberately a bit tighter than the actual track spacing used elsewhere, so legitimately
  adjacent (properly-spaced) lanes don't themselves get penalized.

### `bool crosses(_Segment other)` <a id="crosses"></a>
- **Kind:** method of `_Segment`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1264).
- **Purpose:** Determine whether a horizontal and a vertical segment actually intersect (a real
  T/X crossing), rather than merely being nearby.
- **Inputs:** `other`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** If `this` is horizontal and `other` is vertical, check `other`'s x falls within
  `this`'s x span *and* `this`'s y falls within `other`'s y span (both via
  [`_between`](#_between)); the symmetric case (`this` vertical, `other` horizontal) mirrors this;
  two segments on the same axis (both horizontal or both vertical) never "cross" by this
  definition.
- **Usage:**
  ```dart
  } else if (candidate.crosses(segment)) {
    cost += 28.0;
  }
  ```
  (`_congestionCost`, line 928–929 — the lightest congestion penalty tier.)
- **Notes:** A perpendicular crossing is penalized far less (28.0) than lane reuse (180.0/58.0)
  because crossings are visually unavoidable in an orthogonal layout and not actually confusing,
  unlike two edges running along the same track.

### `static bool _rangesOverlap(double a1, double a2, double b1, double b2)` <a id="_rangesoverlap"></a>
- **Kind:** static method of `_Segment`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1281).
- **Purpose:** Determine whether two 1-D ranges (each given as two unordered endpoints) overlap by
  more than `_epsilon`.
- **Inputs:** `a1`, `a2`, `b1`, `b2`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Normalize both ranges to `(min, max)` pairs; overlap iff
  `max(aMin, bMin) < min(aMax, bMax) - _epsilon` — i.e. a strict overlap requirement, so ranges
  that merely touch at an endpoint do not count as overlapping.
- **Usage:**
  ```dart
  return _rangesOverlap(a.dx, b.dx, other.a.dx, other.b.dx);
  ```
  (`sameAxisOverlap`, line 1234, and similarly in `nearAxisOverlap`.)
- **Notes:** The strict (`- _epsilon`) comparison is what keeps two segments that just touch
  end-to-end on the same line from being flagged as "overlapping" (they'd only be flagged by
  `crosses`/adjacency logic elsewhere if relevant).

### `static bool _between(double value, double start, double end)` <a id="_between"></a>
- **Kind:** static method of `_Segment`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1294).
- **Purpose:** Inclusive range membership test with `_epsilon` slack on both ends, used by
  `crosses` to test whether an intersection point actually falls within a segment's span.
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
  (`crosses`, line 1266–1267.)
- **Notes:** Unlike `_rangesOverlap`, this is deliberately inclusive/lenient (`+ _epsilon` widens
  the range) rather than strict, so a crossing exactly at a segment's endpoint still counts as a
  real crossing.

### `void add(_RouteState state)` <a id="add"></a>
- **Kind:** method of `_RouteHeap`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1328).
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
  (`_routeBetween`, line 788, seeding the search; also called for every relaxed neighbor at line
  825.)
- **Notes:** None beyond the standard binary-heap insert contract.

### `_RouteState removeFirst()` <a id="removefirst"></a>
- **Kind:** method of `_RouteHeap`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1338).
- **Purpose:** Pop and return the lowest-cost state (the heap root), restoring heap order
  afterward.
- **Inputs:** None.
- **Returns:** `_RouteState` — the minimum-cost entry.
- **Side effects:** Mutates `_items` (removes the last element, may overwrite the root).
- **Algorithm:** Save `_items.first`; remove and save `_items.removeLast()`; if any items remain,
  move the removed last element into slot 0 and call [`_bubbleDown`](#_bubbledown) on it to restore
  heap order; return the saved first (root) value — standard binary heap extract-min, `O(log n)`.
- **Usage:**
  ```dart
  final current = heap.removeFirst();
  ```
  (`_routeBetween`, line 792, the main A* search loop.)
- **Notes:** Correctly handles the single-element case: `first` and `last` are the same element,
  and the `_items.isNotEmpty` guard skips `_bubbleDown` on an empty heap.

### `void _bubbleUp(int index)` <a id="_bubbleup"></a>
- **Kind:** method of `_RouteHeap`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1353).
- **Purpose:** Restore the min-heap invariant upward from `index` after an insertion.
- **Inputs:** `index`.
- **Returns:** `void`.
- **Side effects:** Mutates `_items` via `_swap`.
- **Algorithm:** While `index > 0`, compute `parent = (index - 1) >> 1`; if the parent's `.cost` is
  already `<=` the current item's, stop; otherwise [`_swap`](#build) them and continue from
  `parent`.
- **Usage:**
  ```dart
  void add(_RouteState state) {
    _items.add(state);
    _bubbleUp(_items.length - 1);
  }
  ```
  (`add`, line 1328–1331.)
- **Notes:** Standard array-backed binary heap parent-index arithmetic (`(i - 1) >> 1`).

### `void _bubbleDown(int index)` <a id="_bubbledown"></a>
- **Kind:** method of `_RouteHeap`.
- **Source:** `lib/features/services/services/service_topology_layout.dart` (line 1367).
- **Purpose:** Restore the min-heap invariant downward from `index` after the root is replaced.
- **Inputs:** `index`.
- **Returns:** `void`.
- **Side effects:** Mutates `_items` via `_swap`.
- **Algorithm:** Loop: compute `left = index*2+1`, `right = left+1`; find whichever of
  `{index, left, right}` (bounds-checked) has the smallest `.cost` (`smallest`); if it's still
  `index`, stop; otherwise [`_swap`](#build) `index` and `smallest` and continue from `smallest`.
- **Usage:**
  ```dart
  if (_items.isNotEmpty) {
    _items[0] = last;
    _bubbleDown(0);
  }
  ```
  (`removeFirst`, line 1341–1344.)
- **Notes:** Standard array-backed binary heap child-index arithmetic (`i*2+1`, `i*2+2`).
