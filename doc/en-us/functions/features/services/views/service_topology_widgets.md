# lib/features/services/views/service_topology_widgets.dart

What the full-screen topology ([`service_topology_page.md`](service_topology_page.md)) draws with,
split out of `service_list_page.dart` in 1.5.6 without a change in behavior:
`ServiceTopologyNodeCard` (a full card, or a small port chip for compact nodes),
`ServiceTopologyEdgePainter` (the routed edges with arrow heads, coloured by access lane), and the
icon, colour and label helpers behind them. `iconForServiceIcon` and `iconForService` reach
beyond the topology: the service list ([`service_list_page.md`](service_list_page.md)), the
service editor and its template picker ([`service_edit_page.md`](service_edit_page.md)) and the
guided access-path page ([`service_access_path_page.md`](service_access_path_page.md)) draw service
icons with them.

**Row-count note:** `grep -c 'Purpose:' service_topology_widgets.dart` returns **18**, one per
declaration below (**5 Tier A / 13 Tier B**). The ten top-level helpers from
`_compactTopologyLabel` to `iconForService` had no `/// Purpose:` block while they lived in
`service_list_page.dart`; they gained one in the move, and the six the topology page or other
files call became public (`iconForTopologyNode`, `iconForRouteMethod`, `primaryRouteMethod`,
`topologyLaneLabel`, `topologyRoleLabel`, `iconForService`).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ServiceTopologyNodeCard` (constructor) | constructor | B | Create the node card widget (node, icon, tap handler). |
| `build` | method (widget, `ServiceTopologyNodeCard`) | B | Render a node as a compact port chip or a full label/detail card. |
| `ServiceTopologyEdgePainter` (constructor) | constructor | B | Create the edge painter (graph, layout, color scheme). |
| [`paint`](#paint) | method (`ServiceTopologyEdgePainter`, `CustomPainter` override) | A | Draw every edge's routed polyline and arrowhead onto the canvas. |
| [`_drawPolyline`](#drawpolyline) | method (`ServiceTopologyEdgePainter`) | A | Draw one edge's path plus a triangular arrowhead at its end. |
| `_edgeColor` | method (`ServiceTopologyEdgePainter`) | B | Map an edge's access lane to a color-scheme color. |
| `shouldRepaint` | method (`ServiceTopologyEdgePainter`) | B | Repaint only when the graph, layout, or color scheme changed. |
| [`_nodeSubtitle`](#nodesubtitle) | top-level function | A | The subtitle a topology node card shows: a relay's localized method or hop type, else the builder's detail. |
| [`_compactTopologyLabel`](#compacttopologylabel) | top-level function | A | Shorten a topology node's label/detail to a compact chip-sized string. |
| [`iconForTopologyNode`](#iconfortopologynode) | top-level function | A | Resolve the icon for a topology node, by kind and its resolved device/service. |
| `iconForRouteMethod` | top-level function | B | Map a `ServiceRouteMethod` to its display icon (null → the generic route icon). |
| `primaryRouteMethod` | top-level function | B | Return a route's first hop method, if any. |
| `topologyLaneLabel` | top-level function | B | Map a `ServiceAccessLane` to its (English) display label. |
| `topologyRoleLabel` | top-level function | B | Map a `ServiceTopologyNodeRole` to its (English) display label. |
| `_nodeFill` | top-level function | B | Map a topology node's role to its card fill color. |
| `_nodeBorder` | top-level function | B | Map a topology node's role to its card border color. |
| `iconForServiceIcon` | top-level function | B | Map a service's stored icon key to its `IconData` (`Icons.dns` when unknown). |
| `iconForService` | top-level function | B | Resolve a service's icon via `iconForServiceIcon`. |

## Documentation

### `void paint(Canvas canvas, Size size)` <a id="paint"></a>
- **Kind:** method of `ServiceTopologyEdgePainter` (`CustomPainter` override).
- **Source:** `lib/features/services/views/service_topology_widgets.dart` (line 175).
- **Purpose:** Draw every graph edge's routed polyline and arrowhead onto the canvas.
- **Inputs:** `canvas`; `size` (not used directly — the layout already carries absolute
  coordinates).
- **Returns:** None.
- **Side effects:** Draws onto `canvas`.
- **Algorithm:** For each edge in `graph.edges`: look up its routed points in `layout.edgePaths`;
  skip if missing or fewer than 2 points; build a `Paint` colored by `_edgeColor(edge)` (62% alpha,
  2.2 stroke width, round cap/join); delegate the actual drawing to
  [`_drawPolyline`](#drawpolyline).
- **Usage:** Invoked by the Flutter framework whenever the `CustomPaint` this painter backs needs to
  repaint (gated by `shouldRepaint`).
- **Notes:** The routed points (the orthogonal path with obstacle avoidance) come from
  [`ServiceTopologyLayout.build`](../services/service_topology_layout.md#build) — this painter only
  draws the path it's given; it does no routing itself.

### `void _drawPolyline(Canvas canvas, Paint paint, List<Offset> points)` <a id="drawpolyline"></a>
- **Kind:** method of `ServiceTopologyEdgePainter`.
- **Source:** `lib/features/services/views/service_topology_widgets.dart` (line 195).
- **Purpose:** Draw one edge's multi-segment path plus a triangular arrowhead at its end.
- **Inputs:** `canvas`, `paint`, `points` — the routed polyline (2 or more points).
- **Returns:** `void`.
- **Side effects:** Draws onto `canvas`.
- **Algorithm:** 1. Build a `Path` moving to `points.first` then `lineTo` through every subsequent
  point; draw it. 2. Scan backward from the end to find the last point more than 0.5px from the
  endpoint, to use as the direction reference (guards against a degenerate near-zero-length final
  segment). 3. Compute the approach angle via `atan2`. 4. Draw two short lines from the endpoint
  back at `angle ± 0.45` radians (a `V`-shaped arrowhead, ~9px long).
- **Usage:** Called once per edge from [`paint`](#paint).
- **Notes:** The backward scan for a non-degenerate reference point means the arrowhead's direction
  reflects the edge's actual approach direction even if the router emitted a near-duplicate final
  point.

### `String? _nodeSubtitle(BuildContext context, ServiceTopologyNode node)` <a id="nodesubtitle"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/services/views/service_topology_widgets.dart` (line 257).
- **Purpose:** Return the subtitle a topology node card shows under its label.
- **Inputs:** `context`, `node`.
- **Returns:** `String?` — null when there is nothing to show.
- **Side effects:** None.
- **Algorithm:** For a relay node, return the localized method (`serviceRouteMethodUiLabel`) when
  the node has one, else the localized hop type when `detail` is a raw hop-type name. Every other
  node returns its trimmed `detail`, or null when empty.
- **Usage:** `ServiceTopologyNodeCard.build`'s full-card subtitle, joined with the lane label.
- **Notes:** The graph builder stores raw enum names in a relay's `detail`; localizing at render
  time keeps [`service_analysis.dart`](../services/service_analysis.md) language-free.

### `String _compactTopologyLabel(ServiceTopologyNode node)` <a id="compacttopologylabel"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/services/views/service_topology_widgets.dart` (line 278).
- **Purpose:** Shorten a topology node's label/detail to a short string that fits inside a compact
  port-chip.
- **Inputs:** `node`.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** For a `remoteEntry` node: extract a trailing `:port` (or `:start-end`) suffix from
  the label via regex and return just that port text if found; otherwise return the label unchanged
  if 5 characters or fewer, else its first 5 characters. For any other node kind: search the joined
  `label` + `detail` text for the *last* port-like number sequence and return it if found;
  otherwise fall back to the same short-label-or-truncate rule.
- **Usage:** `_compactTopologyLabel(node)` in `ServiceTopologyNodeCard.build`'s compact (port-chip)
  branch.
- **Notes:** Preferring the *last* number match (not the first) is what lets a detail string like
  `"tcp bind-host:8080"` show `8080` rather than an earlier, unrelated number in the bind address;
  this is a display-only shortening — the node's full label/detail remains available via its
  `Tooltip`.

### `IconData iconForTopologyNode(ServiceTopologyNode node, List<ServiceNode> services, List<Device> devices)` <a id="iconfortopologynode"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/services/views/service_topology_widgets.dart` (line 300).
- **Purpose:** Resolve the icon to show for a topology node, based on its kind and, when
  resolvable, its underlying device/service.
- **Inputs:** `node`, `services`, `devices`.
- **Returns:** `IconData`.
- **Side effects:** None.
- **Algorithm:** `device` kind → the resolved device's category icon (`deviceCategoryIcon`), or a
  generic devices icon if unresolved. `service` kind → the resolved service's icon
  (`iconForService`), or a generic `dns` icon if unresolved. `endpoint` kind → a fixed
  ethernet-settings icon. `remoteEntry` → a public icon. `domain` → a language icon. Anything else
  → `iconForRouteMethod(node.method)`.
- **Usage:** `iconForTopologyNode(node, widget.services, widget.devices)` in
  `_ServiceTopologyViewState._buildViewer` and [`_showNodeDetails`](service_topology_page.md#shownodedetails).
- **Notes:** None.
