# lib/features/services/views/service_topology_widgets.dart

What the full-screen topology ([`service_topology_page.md`](service_topology_page.md)) draws with,
split out of `service_list_page.dart` in 1.5.6: `ServiceTopologyNodeCard` (a full card, or a
small port chip for compact nodes, or the header tab of a device container — selected with a
heavier border, dimmed when a selection leaves it out, and announced to screen readers by label,
role and lane), `ServiceTopologyEdgePainter` (the device containers, then the routed edges with
arrow heads, coloured by access lane, the selection's edges emphasized), `ServiceTopologyLegend` (the key to the lane and role colours),
`fitTransform` (the move mode's Fit), and the icon and colour helpers behind them.
`serviceAccessLaneColor` — which moved here from the guided access-path page — is the one lane
colour rule for the painter, the legend and that page's preview. `iconForServiceIcon` and
`iconForService` reach beyond the topology: the service list
([`service_list_page.md`](service_list_page.md)), the service editor and its template picker
([`service_edit_page.md`](service_edit_page.md)) and the guided access-path page
([`service_access_path_page.md`](service_access_path_page.md)) draw service icons with them.

**Row-count note:** `grep -c 'Purpose:' service_topology_widgets.dart` returns **28**, one per
declaration below (**8 Tier A / 20 Tier B**; the nested `offset` of `fitTransform` counts). The
public constants `topologyDimmedNodeOpacity` (0.35) and `topologyDimmedEdgeAlpha` (0.18) are
documented in source and not listed. The English-only `topologyLaneLabel` and
`topologyRoleLabel` of the extraction are gone: cards and details use the localized
`serviceAccessLaneLabel` and `serviceTopologyRoleLabel` from
[`../services/service_labels.md`](../services/service_labels.md), and `_nodeFill` / `_nodeBorder`
became the role-keyed `_roleFill` / `_roleBorder` so the legend can use them.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ServiceTopologyNodeCard` (constructor) | constructor | B | Create the node card widget (node, icon, tap handler, selected, dimmed, header). |
| [`build`](#cardbuild) | method (widget, `ServiceTopologyNodeCard`) | A | Render the card, chip or header tab with its semantics, selection border and dimming. |
| `_buildHeader` | method (widget helper, `ServiceTopologyNodeCard`) | B | A device container's header tab: icon, then name and localized category in one ellipsized line. |
| `_buildChip` | method (widget helper, `ServiceTopologyNodeCard`) | B | The compact port chip: icon over the short label, full text in the tooltip. |
| `_buildCard` | method (widget helper, `ServiceTopologyNodeCard`) | B | The full card: icon avatar, label, subtitle and lane. |
| `ServiceTopologyEdgePainter` (constructor) | constructor | B | Create the edge painter (graph, layout, color scheme, highlight). |
| [`paint`](#paint) | method (`ServiceTopologyEdgePainter`, `CustomPainter` override) | A | Draw the device containers, then every edge's routed polyline and arrowhead, the selection's edges emphasized. |
| [`_paintContainers`](#paintcontainers) | method (`ServiceTopologyEdgePainter`) | A | Fill and outline each device container, dashed for remote and VPS devices. |
| `_dashed` | static method (`ServiceTopologyEdgePainter`) | B | A dashed copy of a path (7 px dashes, 5 px gaps). |
| `_paintEdge` | method (`ServiceTopologyEdgePainter`) | B | Stroke one edge's path at a given alpha and width. |
| [`_drawPolyline`](#drawpolyline) | method (`ServiceTopologyEdgePainter`) | A | Draw one edge's path plus a triangular arrowhead at its end. |
| `_edgeColor` | method (`ServiceTopologyEdgePainter`) | B | An edge's lane colour, the outline colour without a lane. |
| `shouldRepaint` | method (`ServiceTopologyEdgePainter`) | B | Repaint only when the graph, layout, color scheme or highlight changed. |
| `serviceAccessLaneColor` | top-level function | B | The colour of an access lane (local tertiary, VPN secondary, public primary). |
| [`_nodeSubtitle`](#nodesubtitle) | top-level function | A | The subtitle a topology node card shows: a relay's localized method or hop type, a device's localized category, else the builder's detail. |
| [`_compactTopologyLabel`](#compacttopologylabel) | top-level function | A | Shorten a topology node's label/detail to a compact chip-sized string. |
| [`iconForTopologyNode`](#iconfortopologynode) | top-level function | A | Resolve the icon for a topology node, by kind and its resolved device/service. |
| `iconForRouteMethod` | top-level function | B | Map a `ServiceRouteMethod` to its display icon (null → the generic route icon). |
| `primaryRouteMethod` | top-level function | B | Return a route's first hop method, if any. |
| `_roleFill` | top-level function | B | Map a node role to its card fill colour. |
| `_roleBorder` | top-level function | B | Map a node role to its card border and icon colour. |
| `iconForServiceIcon` | top-level function | B | Map a service's stored icon key to its `IconData` (`Icons.dns` when unknown). |
| `iconForService` | top-level function | B | Resolve a service's icon via `iconForServiceIcon`. |
| `ServiceTopologyLegend` (constructor) | constructor | B | Create the legend. |
| `build` | method (widget, `ServiceTopologyLegend`) | B | A wrap of the three lane line samples and six role swatches with their localized labels. |
| `_entry` | method (widget helper, `ServiceTopologyLegend`) | B | One legend entry: a swatch and its label. |
| [`fitTransform`](#fittransform) | top-level function | A | The transform that fits a canvas into a viewer within its zoom limits and pan margin. |
| `offset` | nested function (`fitTransform`) | B | The scaled canvas's offset on one axis: centred when it keeps the viewer in bounds, else 0. |

## Documentation

### `Widget build(BuildContext context)` (`ServiceTopologyNodeCard`) <a id="cardbuild"></a>
- **Kind:** method (widget build) of `ServiceTopologyNodeCard`.
- **Source:** `lib/features/services/views/service_topology_widgets.dart` (line 64).
- **Purpose:** Render a node as a full card or a port chip, with its selection state.
- **Inputs:** `context`.
- **Returns:** The widget tree.
- **Side effects:** None.
- **Algorithm:** Resolve the localized lane label and the role's border colour; build
  `_buildHeader` when `header` is set, else `_buildChip` for a compact node, `_buildCard`
  otherwise (the selected card's border 3.0 wide, the chip's and header's 2.4, instead of 1.4
  and 1.2); wrap it in an `Opacity` of
  `topologyDimmedNodeOpacity` when `dimmed`; wrap that in a `Semantics` container whose label is
  "label, role, lane", with `selected`, `button` and the tap action, excluding the children's own
  semantics.
- **Usage:** One per laid-out node in the page's `_buildViewer`, with `header` set for a device
  node that heads a container (`layout.groupRects`).
- **Notes:** Excluding the children keeps the tooltip and the texts from being read a second
  time; the `Semantics` supplies the tap action itself.

### `void paint(Canvas canvas, Size size)` <a id="paint"></a>
- **Kind:** method of `ServiceTopologyEdgePainter` (`CustomPainter` override).
- **Source:** `lib/features/services/views/service_topology_widgets.dart` (line 309).
- **Purpose:** Draw every graph edge's routed polyline and arrowhead onto the canvas, emphasizing
  the selection's edges when there is one.
- **Inputs:** `canvas`; `size` (not used directly — the layout already carries absolute
  coordinates).
- **Returns:** None.
- **Side effects:** Draws onto `canvas`.
- **Algorithm:** First [`_paintContainers`](#paintcontainers). Then, without a highlight, every
  edge through `_paintEdge` at 0.62 alpha and 2.2 wide.
  With one, first the edges it leaves out at `topologyDimmedEdgeAlpha` (0.18) and 2.2 wide, then
  its lit edges on top at full alpha and 3.0 wide. `_paintEdge` looks the edge's points up in
  `layout.edgePaths`, skips fewer than two, and strokes them in `_edgeColor(edge)` with round
  caps and joins through [`_drawPolyline`](#drawpolyline).
- **Usage:** Invoked by the Flutter framework whenever the `CustomPaint` this painter backs needs to
  repaint (gated by `shouldRepaint`, which also compares the highlight).
- **Notes:** The routed points (the orthogonal path with obstacle avoidance) come from
  [`ServiceTopologyLayout.build`](../services/service_topology_layout.md#build) — this painter only
  draws the path it's given; it does no routing itself. Drawing the lit edges last keeps a
  highlighted route visible where it crosses faded ones. Hidden edges (`layout.hiddenEdges`, the
  device-to-service edges a container implies) have no path and so are never drawn.

### `void _paintContainers(Canvas canvas)` <a id="paintcontainers"></a>
- **Kind:** method of `ServiceTopologyEdgePainter`.
- **Source:** `lib/features/services/views/service_topology_widgets.dart` (line 335).
- **Purpose:** Paint the device containers of the layout.
- **Inputs:** `canvas`.
- **Returns:** `void`.
- **Side effects:** Draws onto `canvas`.
- **Algorithm:** For each `layout.groupRects` entry, look up the device node; draw an 18 px
  rounded rect filled with `_roleFill` of its role at alpha 0.22, then its outline in
  `_roleBorder` at alpha 0.55, 1.2 wide — through `_dashed` when the device is remote
  (`remoteDevice` role) or a VPS (its `detail` is `DeviceCategory.vps.name`). When a highlight
  leaves the device out, the fill drops to 0.08 and the border to 0.25.
- **Usage:** First step of [`paint`](#paint), so edges run over containers.
- **Notes:** The container's label is not painted here: the device node's own card, drawn in
  its header variant, sits on the container's top-left corner.

### `void _drawPolyline(Canvas canvas, Paint paint, List<Offset> points)` <a id="drawpolyline"></a>
- **Kind:** method of `ServiceTopologyEdgePainter`.
- **Source:** `lib/features/services/views/service_topology_widgets.dart` (line 417).
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
- **Source:** `lib/features/services/views/service_topology_widgets.dart` (line 496).
- **Purpose:** Return the subtitle a topology node card shows under its label.
- **Inputs:** `context`, `node`.
- **Returns:** `String?` — null when there is nothing to show.
- **Side effects:** None.
- **Algorithm:** For a device node whose `detail` is a `DeviceCategory` name, return
  `deviceCategoryLabel`. For a relay node, return the localized method
  (`serviceRouteMethodUiLabel`) when the node has one, else the localized hop type when `detail`
  is a raw hop-type name. Every other node returns its trimmed `detail`, or null when empty.
- **Usage:** `ServiceTopologyNodeCard._buildCard`'s subtitle, joined with the lane label, and
  `_buildHeader`'s category.
- **Notes:** The graph builder stores raw enum names in a relay's and a device's `detail`;
  localizing at render time keeps [`service_analysis.dart`](../services/service_analysis.md)
  language-free. Before 1.5.6 device cards showed the raw category name (e.g. `vps`).

### `String _compactTopologyLabel(ServiceTopologyNode node)` <a id="compacttopologylabel"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/services/views/service_topology_widgets.dart` (line 525).
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
- **Usage:** `_compactTopologyLabel(node)` in `ServiceTopologyNodeCard._buildChip`, the compact (port-chip)
  branch.
- **Notes:** Preferring the *last* number match (not the first) is what lets a detail string like
  `"tcp bind-host:8080"` show `8080` rather than an earlier, unrelated number in the bind address;
  this is a display-only shortening — the node's full label/detail remains available via its
  `Tooltip`.

### `IconData iconForTopologyNode(ServiceTopologyNode node, List<ServiceNode> services, List<Device> devices)` <a id="iconfortopologynode"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/services/views/service_topology_widgets.dart` (line 547).
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
  `_ServiceTopologyViewState._buildViewer` and the node details'
  [`build`](service_topology_page.md#detailsbuild).
- **Notes:** None.

### `Matrix4 fitTransform(Size canvas, Size viewport, {required double minScale, required double maxScale, double boundaryMargin = 0})` <a id="fittransform"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/services/views/service_topology_widgets.dart` (line 825).
- **Purpose:** Compute the transform that fits a canvas into an `InteractiveViewer`.
- **Inputs:** `canvas` — the child as the viewer lays it out (turned when the canvas is rotated);
  `viewport` — the viewer's size; `minScale`, `maxScale` — the viewer's zoom limits;
  `boundaryMargin` — the viewer's margin around the child.
- **Returns:** `Matrix4` — a uniform scale on all three axes and a translation; the identity for
  an empty canvas or viewport.
- **Side effects:** None.
- **Algorithm:** 1. `scale = min(viewport.width / canvas.width, viewport.height /
  canvas.height)`, clamped to the limits. 2. Per axis (`offset`): no room ⇒ 0; room ⇒ centred
  when half the room is at most `boundaryMargin × scale`, else 0. 3.
  `Matrix4.diagonal3Values(scale, scale, scale)` with that translation.
- **Usage:** The page view's `fitToViewport`, with the move mode's 0.35 / 2.4 limits and 180
  margin.
- **Notes:** The scale goes on the z axis too because `InteractiveViewer` reads its zoom back with
  `getMaxScaleOnAxis`; a z of 1 would read as 100 % whenever the fit zooms out. Centring beyond the
  margin is skipped because the viewer snaps an out-of-bounds offset back to 0 on the next pan,
  so it would only make the graph jump. `test/service_topology_page_test.dart` pins the tighter
  axis, both limits, the margin rule and the empty cases.
