# lib/features/services/views/service_topology_page.dart

The full-screen service topology described in
[Services and Topology](../../../../features/services-topology.md#views): `ServiceTopologyPage`,
which the Services overview's topology card pushes on the root navigator
([`service_list_page.md`](service_list_page.md), `_openTopology`) with a `ServiceTopologyGraph`
built from the current inventory, and the canvas it hosts, `_ServiceTopologyView`. The file was
split out of `service_list_page.dart` in 1.5.6 and then gained the topology's interaction:

- **Selection.** Tapping a node in select mode selects it; the routes through it
  (`relatedRoutesForNode`) light up through `serviceTopologyHighlight`, every other node is
  dimmed and every other edge faded. A tap on the empty canvas, the selection chip or the
  details pane's close button clears it.
- **Details.** On phones a tap also opens the details bottom sheet; on `useDetailTwoPane`
  windows a non-modal pane of `topologyDetailPaneWidth` sits beside the canvas instead, always
  present so a selection never changes the canvas width. In the pane a route row narrows the
  highlight to that route and its edit button opens the route editor.
- **Filters.** An app-bar action opens a sheet of device chips, lane chips and a search field;
  the page builds and memoizes the narrowed graph (`filterServiceTopologyInput`), and a badge
  counts the active parts.
- **Legend.** A collapsible strip under the mode row (`ServiceTopologyLegend`), outside the
  exported canvas.
- **Fit and reset.** In move mode, icon buttons fit the canvas into the viewer (`fitTransform`)
  or reset its transform.

The page owns the mode, rotation, export, selection and filter state; the view owns the
deferred, cached layout (`_TopologyLayoutRequest` is its cache key). Node cards, the edge
painter, the legend and the icon, colour and fit helpers come from
[`service_topology_widgets.md`](service_topology_widgets.md); the filter and highlight logic
from [`../services/service_analysis.md`](../services/service_analysis.md); node and edge
placement from [`../services/service_topology_layout.md`](../services/service_topology_layout.md).

**Row-count note:** `grep -c 'Purpose:' service_topology_page.dart` returns **36**, one per
declaration below (**16 Tier A / 20 Tier B**). `enum _TopologyInteractionMode { select, move }`
(line 18) is a member-less enum and is not listed: select mode wires node taps and the
background tap and scrolls the canvas; move mode drops the taps and wraps the canvas in an
`InteractiveViewer`. The private constants `_minScale` (0.35), `_maxScale` (2.4) and
`_boundaryMargin` (180) are that viewer's limits, shared with `fitTransform`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `_ServiceTopologyView` (constructor) | constructor | B | Create the canvas widget: graph, inventory, mode, rotation, capture key, selection, taps, transform. |
| `createState` | method (`_ServiceTopologyView`) | B | Create the canvas's mutable state object. |
| `build` | method (widget, `_ServiceTopologyViewState`) | B | Lay out the canvas inside a `LayoutBuilder`, requesting/showing the cached layout and remembering the viewport. |
| [`_ensureLayout`](#ensurelayout) | method (`_ServiceTopologyViewState`) | A | Schedule a deferred layout calculation for a request, deduplicating in-flight requests. |
| [`_calculateLayout`](#calculatelayout) | method (`_ServiceTopologyViewState`) | A | Run the layout engine for one request and cache the result if it's still current. |
| `_buildLoading` | method (widget helper) | B | Render the small loading spinner shown before layout is ready. |
| `_reportLayoutReady` | method (`_ServiceTopologyViewState`) | B | Notify the parent (deferred to next frame) when layout readiness changes. |
| [`fitToViewport`](#fittoviewport) | method (`_ServiceTopologyViewState`) | A | Fit the laid-out canvas into the view through the transformation controller. |
| [`_buildViewer`](#buildviewer) | method (widget helper) | A | Render the edges and node cards with the selection, in a scroll view (select) or an `InteractiveViewer` (move). |
| [`_TopologyLayoutRequest` (constructor)](#topologylayoutrequest-new) | constructor | A | Create a layout cache-key value (graph, routes, viewport width). |
| [`==`](#equals) | operator (`_TopologyLayoutRequest`) | A | Compare two requests by graph/route identity and viewport width. |
| [`hashCode`](#hashcode) | getter (`_TopologyLayoutRequest`) | A | Hash a request consistently with its equality contract. |
| `ServiceTopologyPage` (constructor) | constructor | B | Create the full-screen topology page widget. |
| `createState` | method (`ServiceTopologyPage`) | B | Create the page's mutable state object. |
| `dispose` | method (`_ServiceTopologyPageState`, widget lifecycle) | B | Dispose the transformation controller. |
| [`_visible`](#visible) | method (`_ServiceTopologyPageState`) | A | The graph and routes the current filter shows, memoized per filter. |
| [`_selectionIn`](#selectionin) | method (`_ServiceTopologyPageState`) | A | Resolve the selected node, its related routes and the highlight on the visible graph. |
| [`_selectNode`](#selectnode) | method (`_ServiceTopologyPageState`) | A | Select a tapped node; open the details sheet where there is no pane. |
| `_clearSelection` | method (`_ServiceTopologyPageState`) | B | Clear the selection and the focused route. |
| `_toggleRouteFocus` | method (`_ServiceTopologyPageState`) | B | Narrow the highlight to one related route, or widen it back. |
| `_setFilter` | method (`_ServiceTopologyPageState`) | B | Apply a filter and reset the move-mode transform. |
| `_openFilters` | method (`_ServiceTopologyPageState`) | B | Open the filter sheet with the devices that host services. |
| [`_showDetailsSheet`](#showdetailssheet) | method (`_ServiceTopologyPageState`) | A | Show a node's details in a bottom sheet whose actions call the editors. |
| [`_exportTopologyImage`](#exporttopologyimage) | method (`_ServiceTopologyPageState`) | A | Capture the topology canvas, highlight included, as a PNG and hand it to the platform share flow. |
| [`build`](#pagebuild) | method (widget, `_ServiceTopologyPageState`) | A | Build the scaffold: filter/rotate/export actions, mode row, legend strip, canvas, details pane. |
| `_buildModeRow` | method (widget helper) | B | The select / move switch, plus Fit and Reset icon buttons in move mode. |
| `_buildLegendStrip` | method (widget helper) | B | The legend toggle, the legend, and the selection chip that clears it. |
| [`_buildDetailsPane`](#builddetailspane) | method (widget helper) | A | The split window's details pane: a hint, or the selected node's details. |
| `_buildNoMatch` | method (widget helper) | B | The "nothing matches" message with a "Clear filters" button. |
| `_TopologyNodeDetails` (constructor) | constructor | B | Create the node details for the sheet or the pane. |
| [`build`](#detailsbuild) | method (widget, `_TopologyNodeDetails`) | A | Render the node, its device and service with their actions, and its routes. |
| `_TopologyFilterSheet` (constructor) | constructor | B | Create the filter sheet from a filter, the device chips and a change callback. |
| `createState` | method (`_TopologyFilterSheet`) | B | Create the sheet's mutable state object. |
| `dispose` | method (`_TopologyFilterSheetState`, widget lifecycle) | B | Dispose the search controller. |
| `_update` | method (`_TopologyFilterSheetState`) | B | Apply a change to the sheet and hand it to the page. |
| [`build`](#filterbuild) | method (widget, `_TopologyFilterSheetState`) | A | Render the search field, the lane chips and the device chips. |

## Documentation

### `void _ensureLayout(_TopologyLayoutRequest request)` <a id="ensurelayout"></a>
- **Kind:** method of `_ServiceTopologyViewState`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 135).
- **Purpose:** Schedule a deferred layout calculation for a request, unless an identical request is
  already pending.
- **Inputs:** `request`.
- **Returns:** None.
- **Side effects:** Sets `_pendingRequest`; increments `_layoutGeneration`; schedules a post-frame
  callback that calls [`_calculateLayout`](#calculatelayout).
- **Algorithm:** 1. If `_pendingRequest == request` (same graph/routes identity and viewport width
  — see [`_TopologyLayoutRequest.==`](#equals)), return without doing anything (already in flight).
  2. Otherwise record `request` as `_pendingRequest`, increment `_layoutGeneration`, and capture the
  new value as `generation`. 3. Register `WidgetsBinding.instance.addPostFrameCallback` to call
  `_calculateLayout(request, generation)`.
- **Usage:** Called from `build` whenever `_completedRequest != request || _layout == null` (i.e.
  the current graph/routes/viewport combination hasn't been laid out yet).
- **Notes:** This is the mechanism behind the behavior described in
  [Services and Topology](../../../../features/services-topology.md#topology-graph-layout-high-level)
  — "the full-screen topology defers expensive layout until after the first frame and caches
  layouts by graph, routes, width, and rotation-derived viewport, so mode changes ... don't rerun
  routing." The `_layoutGeneration` counter is what lets a newer request invalidate a still-in-flight
  older one (see [`_calculateLayout`](#calculatelayout)).

### `Future<void> _calculateLayout(_TopologyLayoutRequest request, int generation)` <a id="calculatelayout"></a>
- **Kind:** method of `_ServiceTopologyViewState`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 149).
- **Purpose:** Run the topology layout engine for one request, after yielding a frame, and cache
  the result if it's still the current request.
- **Inputs:** `request`; `generation` — the `_layoutGeneration` value captured when this
  computation was scheduled.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `ServiceTopologyLayout.build`; `setState` updates `_layout`/
  `_completedRequest`/`_pendingRequest` when still current.
- **Algorithm:** 1. `await Future<void>.delayed(Duration.zero)` — yields at least one frame so this
  doesn't block the frame that scheduled it. 2. Bail out if unmounted, or if `generation` no longer
  equals `_layoutGeneration`, or if `_pendingRequest` no longer equals `request` (a newer request
  superseded this one). 3. Compute
  `ServiceTopologyLayout.build(request.graph, request.routes, request.viewportWidth.toDouble())`
  (see [`../services/service_topology_layout.md#build`](../services/service_topology_layout.md#build)).
  4. Re-check the same three staleness conditions (the computation itself may have taken long
  enough for a newer request to arrive). 5. `setState` to store the layout, mark `request` as
  `_completedRequest`, and clear `_pendingRequest`.
- **Usage:** Only called via the post-frame callback registered by
  [`_ensureLayout`](#ensurelayout).
- **Notes:** The double staleness check (before *and* after `ServiceTopologyLayout.build`) is what
  prevents a slow, now-obsolete layout computation (e.g. for a viewport width from just before a
  rotation) from clobbering state after a newer request has already completed.

### `void fitToViewport()` <a id="fittoviewport"></a>
- **Kind:** method of `_ServiceTopologyViewState`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 211).
- **Purpose:** Fit the laid-out canvas into the view.
- **Inputs:** None.
- **Returns:** `void`.
- **Side effects:** Sets `widget.transformationController.value`.
- **Algorithm:** Take the cached layout's size, swapped for an odd number of quarter turns (the
  viewer sees the rotated canvas), and the viewport size remembered by `build`; set the
  controller to `fitTransform(canvas, viewport, minScale: _minScale, maxScale: _maxScale,
  boundaryMargin: _boundaryMargin)` (see
  [`service_topology_widgets.md`](service_topology_widgets.md#fittransform)).
- **Usage:** The page's Fit button calls it through a `GlobalKey<_ServiceTopologyViewState>`:
  `onPressed: () => _viewKey.currentState?.fitToViewport()`.
- **Notes:** Does nothing before the first layout or without a controller. The page resets the
  controller to the identity on Reset, on rotation and on every filter change, since a fit
  computed for one canvas is wrong for the next.

### `Widget _buildViewer(BuildContext context, ServiceTopologyLayout layout, int turns)` <a id="buildviewer"></a>
- **Kind:** method (widget helper) of `_ServiceTopologyViewState`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 238).
- **Purpose:** Build the canvas — edges and node cards — inside its viewer.
- **Inputs:** `context`; `layout` — the cached layout; `turns` — quarter turns, 0 to 3.
- **Returns:** `Widget`.
- **Side effects:** None.
- **Algorithm:** 1. A `Stack` at `layout.size`: a `CustomPaint` with `ServiceTopologyEdgePainter`
  (given the highlight), then one `ServiceTopologyNodeCard` per laid-out node, keyed
  `topology-node-<id>`, `selected` for the selected node and `dimmed` when a highlight leaves it
  out, with `onTap` only in select mode. 2. Wrap in a `RotatedBox` for a rotation and in the
  export `RepaintBoundary`. 3. Select mode: a `GestureDetector` keyed `topology-canvas` whose tap
  clears the selection, around two nested scroll views. Move mode: an `InteractiveViewer` on the
  page's `TransformationController` with `_boundaryMargin`, `_minScale` and `_maxScale`.
- **Usage:** `build`, once the layout for the current request is ready.
- **Notes:** A tap on a node card wins the gesture arena over the background tap, so only taps
  that miss every card clear the selection. Selection changes only repaint: the layout request
  does not include the highlight.

### `const _TopologyLayoutRequest({required this.graph, required this.routes, required this.viewportWidth})` <a id="topologylayoutrequest-new"></a>
- **Kind:** constructor.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 321).
- **Purpose:** Create the value used as a topology layout's cache key.
- **Inputs:** `graph`, `routes`, `viewportWidth`.
- **Returns:** A new `_TopologyLayoutRequest`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:** Constructed once per `build` call in `_ServiceTopologyViewState.build`.
- **Notes:** None.

### `bool operator ==(Object other)` <a id="equals"></a>
- **Kind:** operator of `_TopologyLayoutRequest`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 333).
- **Purpose:** Compare two layout requests for cache-reuse purposes.
- **Inputs:** `other`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** `true` if `identical(this, other)`, or if `other` is a `_TopologyLayoutRequest`
  with `identical` `graph`, `identical` `routes`, and an equal `viewportWidth`.
- **Usage:** Used implicitly via `==`/`!=` in `build` (`_completedRequest == request`) and
  [`_ensureLayout`](#ensurelayout) (`_pendingRequest == request`).
- **Notes:** Uses **identity** (`identical`), not value equality, for `graph`/`routes` — two
  structurally-equal-but-distinct `ServiceTopologyGraph`/route-list instances would compare
  unequal. This is intentional: any new `buildServiceTopology`/[`_load`](service_list_page.md#load) call invalidates the
  cache even if the resulting graph looks the same, and it avoids a deep structural comparison on
  every build. `viewportWidth` is rounded to an `int` (in `_ServiceTopologyViewState.build`) before
  comparison, to avoid tiny constraint jitter forcing a re-layout.

### `int get hashCode` <a id="hashcode"></a>
- **Kind:** getter of `_TopologyLayoutRequest`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 346).
- **Purpose:** Produce a hash code consistent with the identity-based `==` above.
- **Inputs:** None.
- **Returns:** `int`.
- **Side effects:** None.
- **Algorithm:** `Object.hash(identityHashCode(graph), identityHashCode(routes), viewportWidth)`.
- **Usage:** Not called explicitly anywhere in this file — `_TopologyLayoutRequest` values are only
  ever compared via `==`, not stored in a `Map`/`Set` — but Dart requires a `hashCode` consistent
  with `==` whenever the latter is overridden.
- **Notes:** Uses `identityHashCode` (matching `==`'s identity-based comparison for `graph`/
  `routes`), so two structurally-equal instances built from different underlying `graph`/`routes`
  objects also hash differently.

### `({ServiceTopologyGraph graph, List<ServiceRoute> routes}) _visible()` <a id="visible"></a>
- **Kind:** method of `_ServiceTopologyPageState`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 446).
- **Purpose:** Return the graph and routes the current filter shows.
- **Inputs:** None.
- **Returns:** The page's own `graph` and `routes` when the filter narrows nothing; otherwise the
  graph `buildServiceTopology` builds from `filterServiceTopologyInput`'s services and routes.
- **Side effects:** Caches the filtered graph with its filter in `_filtered`.
- **Algorithm:** 1. Inactive filter ⇒ `(widget.graph, widget.routes)`. 2. A cache for an equal
  filter ⇒ its graph and routes. 3. Otherwise narrow the inventory with
  [`filterServiceTopologyInput`](../services/service_analysis.md#filterservicetopologyinput),
  build the graph, cache and return it.
- **Usage:** `build`, `_showDetailsSheet`.
- **Notes:** Returning the same instances until the filter changes is what keeps the view's
  identity-keyed layout cache ([`==`](#equals)) hitting across rebuilds — a new graph per build
  would relayout on every frame.

### `_selectionIn(ServiceTopologyGraph graph, List<ServiceRoute> routes)` <a id="selectionin"></a>
- **Kind:** method of `_ServiceTopologyPageState`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 474).
- **Purpose:** Resolve the selection on the visible graph.
- **Inputs:** `graph`, `routes` — from [`_visible`](#visible).
- **Returns:** A record of the selected node, its related routes and the
  `ServiceTopologyHighlight`; null when nothing is selected or the filters hide the node.
- **Side effects:** Caches the result in `_lit`.
- **Algorithm:** 1. Find the node with `_selectedNodeId` in `graph`. 2. Reuse `_lit` when it was
  built for the same graph instance, node and focused route. 3. Otherwise take
  `relatedRoutesForNode(node, routes, services:)`; narrow to the focused route when it is among
  them; compute
  [`serviceTopologyHighlight`](../services/service_analysis.md#servicetopologyhighlight) with
  the node as `selectedNodeId`; cache.
- **Usage:** `build`.
- **Notes:** The cache keeps one highlight instance while the selection stands, so the edge
  painter's `shouldRepaint` stays false across unrelated rebuilds. A selection whose node a filter
  hides is kept, not cleared, and comes back with the node.

### `void _selectNode(ServiceTopologyNode node)` <a id="selectnode"></a>
- **Kind:** method of `_ServiceTopologyPageState`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 522).
- **Purpose:** Select a tapped node.
- **Inputs:** `node`.
- **Returns:** `void`.
- **Side effects:** Sets `_selectedNodeId`, clears `_focusedRouteId`; without a details pane,
  opens the details sheet.
- **Algorithm:** `setState`; then, when `useDetailTwoPane` is false for the window, call
  [`_showDetailsSheet`](#showdetailssheet).
- **Usage:** The view's `onNodeTap`.
- **Notes:** The selection lives in the page rather than in the sheet, so the highlight stays
  after the sheet closes.

### `void _showDetailsSheet(ServiceTopologyNode node)` <a id="showdetailssheet"></a>
- **Kind:** method of `_ServiceTopologyPageState`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 602).
- **Purpose:** Show a node's details in a bottom sheet.
- **Inputs:** `node`.
- **Returns:** `void`.
- **Side effects:** Shows a modal bottom sheet; its actions pop it and call
  `widget.onEditService`, `widget.onEditRoute` or `widget.onAddAccess`.
- **Algorithm:** Resolve the related routes on the visible routes and show
  [`_TopologyNodeDetails`](#detailsbuild) (key `topology-details-sheet`, `shrinkWrap`) in a
  scroll-controlled sheet with a drag handle. A route row opens the route's editor; "Edit
  service" and "Add access" open the service editor and the guided access-path page (with the
  service as source).
- **Usage:** [`_selectNode`](#selectnode), on windows without the details pane.
- **Notes:** Replaces the view's `_showNodeDetails` of 1.5.6's extraction; its content is the
  shared details widget, so the sheet and the pane cannot drift apart.

### `Future<void> _exportTopologyImage()` <a id="exporttopologyimage"></a>
- **Kind:** method of `_ServiceTopologyPageState`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 646).
- **Purpose:** Capture the topology canvas (via its `RepaintBoundary`) as a PNG and hand it to the
  platform-appropriate share/save flow.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a snackbar if not ready; sets `_exporting`; renders the boundary to an
  image and shares it via `ImageShareService.sharePngBytes`; shows a failure snackbar on error.
- **Algorithm:** 1. If `!_layoutReady`, show a snackbar and return (nothing to capture yet).
  2. `setState(() => _exporting = true)`. 3. `await WidgetsBinding.instance.endOfFrame` (ensure the
  frame with the current layout has actually painted). 4. Find the `RenderRepaintBoundary` via
  `_captureKey.currentContext`; throw a `StateError` if unavailable. 5.
  `boundary.toImage(pixelRatio: 3)`, then `image.toByteData(format: ui.ImageByteFormat.png)`; throw
  a `StateError` if encoding failed. 6. If still mounted, call
  `ImageShareService.sharePngBytes(context, bytes, fileName: 'mydevice_topology.png')` (see
  [`../../../shared/services/image_share_service.md#sharepngbytes`](../../../shared/services/image_share_service.md#sharepngbytes)).
  7. On any exception, show a failure snackbar (if mounted). 8. `finally`: clear `_exporting` (if
  mounted).
- **Usage:** `onPressed: _exporting || !canExport ? null : _exportTopologyImage` on the app bar's
  export `IconButton` in [`build`](#pagebuild).
- **Notes:** The actual share/save mechanism (share sheet vs. file picker vs. clipboard) is
  platform-specific and lives inside `ImageShareService`, not here — see
  [Platform Notes](../../../../platform-notes.md#android). The boundary wraps the canvas with
  its highlight, so a selected route exports on its own; the legend strip and the details pane
  are outside it. `build` disables the action while no layout is ready or the filters leave an
  empty graph.

### `Widget build(BuildContext context)` <a id="pagebuild"></a>
- **Kind:** method (widget build) of `_ServiceTopologyPageState`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 696).
- **Purpose:** Build the topology page scaffold.
- **Inputs:** `context`.
- **Returns:** The widget tree.
- **Side effects:** None beyond filling the `_visible` and `_selectionIn` caches.
- **Algorithm:** 1. Resolve the visible graph and the selection. 2. The app bar's actions: the
  filter button (key `topology-filter`, a `Badge` with `ServiceTopologyFilter.activeCount` while
  a filter is active), rotation (which also resets the transform) and export (enabled only with
  a ready layout of a non-empty graph). 3. The topology column: `_buildModeRow`,
  `_buildLegendStrip`, then either `_buildNoMatch` (an empty filtered graph) or the
  `_ServiceTopologyView` with the highlight, the selected id, `_selectNode`, a background tap
  that clears a selection, and the transform. 4. On `useDetailTwoPane` windows, a `Row` of the
  column, a divider and [`_buildDetailsPane`](#builddetailspane) at
  `topologyDetailPaneWidth(width)`; otherwise the column alone.
- **Usage:** Called by the framework.
- **Notes:** The pane is present even with nothing selected: the layout depends on the canvas
  width, so a pane that came and went with the selection would relayout — and flash the loading
  spinner — on every tap.

### `Widget _buildDetailsPane(AppLocalizations l10n, ...? selection)` <a id="builddetailspane"></a>
- **Kind:** method (widget helper) of `_ServiceTopologyPageState`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 900).
- **Purpose:** Build the details pane of a split window.
- **Inputs:** `l10n`; `selection` — from [`_selectionIn`](#selectionin), or null.
- **Returns:** `Widget`.
- **Side effects:** None.
- **Algorithm:** Nothing selected ⇒ a centred hint (key `topology-details-empty`). Otherwise
  [`_TopologyNodeDetails`](#detailsbuild) (key `topology-details-pane`) with the focused route,
  the focus hint when there is more than one route, `_toggleRouteFocus` for route rows, the
  route editor for their edit buttons, and `_clearSelection` for the close button.
- **Usage:** [`build`](#pagebuild) on split windows.
- **Notes:** Non-modal: the canvas stays interactive beside it, so another node can be selected
  directly.

### `Widget build(BuildContext context)` (`_TopologyNodeDetails`) <a id="detailsbuild"></a>
- **Kind:** method (widget build) of `_TopologyNodeDetails`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 1016).
- **Purpose:** Render a node's details.
- **Inputs:** `context`.
- **Returns:** The widget tree.
- **Side effects:** None.
- **Algorithm:** A `ListView` of: the node tile (icon, label; role, detail and lane as subtitle;
  a close button keyed `topology-details-close` when `onClose` is set); the device tile with its
  localized category (`deviceCategoryLabel`); the service tile with its endpoints and the "Edit
  service" / "Add access" buttons; then "Routes", the focus hint when asked for, and one row per
  related route (key `topology-route-<id>`, `selected` when focused): method icon, target,
  targets summary, localized access level and lane, and an edit button
  (`topology-route-edit-<id>`) when `onRouteEdit` is set, else a chevron.
- **Usage:** [`_showDetailsSheet`](#showdetailssheet) and [`_buildDetailsPane`](#builddetailspane).
- **Notes:** Every label is localized (`serviceTopologyRoleLabel`, `serviceAccessLaneLabel`,
  `serviceAccessLevelLabel`, `deviceCategoryLabel`); before 1.5.6 role, lane and device category
  showed in English or as raw enum names.

### `Widget build(BuildContext context)` (`_TopologyFilterSheetState`) <a id="filterbuild"></a>
- **Kind:** method (widget build) of `_TopologyFilterSheetState`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 1197).
- **Purpose:** Render the filter sheet.
- **Inputs:** `context`.
- **Returns:** The widget tree.
- **Side effects:** None; the controls call `_update`, which hands each change to the page.
- **Algorithm:** A title with "Clear filters" (`topology-filter-clear`, enabled while a filter is
  active; also clears the search field); the search field (`topology-filter-search`); lane chips
  (`topology-filter-lane-<lane>`, a coloured dot and the localized lane, no checkmark); device
  chips — "All devices" (`topology-filter-all-devices`) and one per device
  (`topology-filter-device-<id>`).
- **Usage:** `_openFilters`, as the sheet's content.
- **Notes:** The last selected lane cannot be turned off, since no lane shows nothing. Clearing
  the last device chip means every device again. Changes apply live; closing the sheet keeps
  them.
