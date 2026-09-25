# lib/features/services/views/service_topology_page.dart

The full-screen service topology described in
[Services and Topology](../../../../features/services-topology.md#views): `ServiceTopologyPage`,
which the Services overview's topology card pushes on the root navigator
([`service_list_page.md`](service_list_page.md), `_openTopology`) with a `ServiceTopologyGraph`
built from the current inventory, and the canvas it hosts, `_ServiceTopologyView`. The page owns
the select / move mode switch, the 90-degree rotation and the PNG export; the view owns the
deferred, cached layout (`_TopologyLayoutRequest` is its cache key) and the node details sheet.
Node cards, the edge painter and the icon and label helpers come from
[`service_topology_widgets.md`](service_topology_widgets.md); node and edge placement from
[`../services/service_topology_layout.md`](../services/service_topology_layout.md). The file was
split out of `service_list_page.dart` in 1.5.6 without a change in behavior.

**Row-count note:** `grep -c 'Purpose:' service_topology_page.dart` returns **16**, one per
declaration below (**7 Tier A / 9 Tier B**). `enum _TopologyInteractionMode { select, move }`
(line 17) is a member-less enum and is not listed: select mode wires each node card's tap to the
details sheet and scrolls the canvas; move mode drops the taps and wraps the canvas in an
`InteractiveViewer`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `_ServiceTopologyView` (constructor) | constructor | B | Create the topology view widget (graph, data, callbacks, mode, rotation, capture/layout callbacks). |
| `createState` | method (`_ServiceTopologyView`) | B | Create the topology view's mutable state object. |
| `build` | method (widget, `_ServiceTopologyViewState`) | B | Lay out the topology canvas inside a `LayoutBuilder`, requesting/showing the cached layout. |
| [`_ensureLayout`](#ensurelayout) | method (`_ServiceTopologyViewState`) | A | Schedule a deferred layout calculation for a request, deduplicating in-flight requests. |
| [`_calculateLayout`](#calculatelayout) | method (`_ServiceTopologyViewState`) | A | Run the layout engine for one request and cache the result if it's still current. |
| `_buildLoading` | method (widget helper) | B | Render the small loading spinner shown before layout is ready. |
| `_reportLayoutReady` | method (`_ServiceTopologyViewState`) | B | Notify the parent (deferred to next frame) when layout readiness changes. |
| `_buildViewer` | method (widget helper) | B | Render the positioned node cards and edge painter, wrapped for rotation/capture/pan-zoom. |
| [`_showNodeDetails`](#shownodedetails) | method (`_ServiceTopologyViewState`) | A | Resolve a tapped node's device/service/related routes and show them in a bottom sheet. |
| [`_TopologyLayoutRequest` (constructor)](#topologylayoutrequest-new) | constructor | A | Create a layout cache-key value (graph, routes, viewport width). |
| [`==`](#equals) | operator (`_TopologyLayoutRequest`) | A | Compare two requests by graph/route identity and viewport width. |
| [`hashCode`](#hashcode) | getter (`_TopologyLayoutRequest`) | A | Hash a request consistently with its equality contract. |
| `ServiceTopologyPage` (constructor) | constructor | B | Create the full-screen topology page widget. |
| `createState` | method (`ServiceTopologyPage`) | B | Create the page's mutable state object. |
| [`_exportTopologyImage`](#exporttopologyimage) | method (`_ServiceTopologyPageState`) | A | Capture the topology canvas as a PNG and hand it to the platform share flow. |
| `build` | method (widget, `_ServiceTopologyPageState`) | B | Build the topology page scaffold: rotate/export actions, mode switch, topology view. |

## Documentation

### `void _ensureLayout(_TopologyLayoutRequest request)` <a id="ensurelayout"></a>
- **Kind:** method of `_ServiceTopologyViewState`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 108).
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
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 122).
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

### `void _showNodeDetails(BuildContext context, ServiceTopologyNode node)` <a id="shownodedetails"></a>
- **Kind:** method of `_ServiceTopologyViewState`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 245).
- **Purpose:** Resolve a tapped topology node's device/service/related routes and show them in a
  bottom sheet with edit/add-access actions.
- **Inputs:** `context`, `node`.
- **Returns:** `void`.
- **Side effects:** Shows a `showModalBottomSheet`; its action buttons call
  `widget.onEditService`/`widget.onEditRoute`/`widget.onAddAccess` and pop the sheet.
- **Algorithm:** 1. Resolve `device`/`service` from `node.deviceId`/`node.serviceId` against
  `widget.devices`/`widget.services` (`null` if unset or unresolved). 2. Resolve `relatedRoutes`
  with `relatedRoutesForNode(node, widget.routes, services: widget.services)`
  ([`service_analysis.md`](../services/service_analysis.md#relatedroutesfornode)). 3. Show a
  bottom sheet listing the node's own label/role/detail/lane;
  the device tile if resolved; the service tile (with endpoints) plus Edit/Add-access buttons if
  resolved; and one tile per related route (edit-on-tap) if any.
- **Usage:** `onTap: widget.mode == _TopologyInteractionMode.select ? () =>
  _showNodeDetails(context, node) : null` in `_buildViewer` — only wired up in select mode, not in
  move/zoom mode.
- **Notes:** `relatedRoutes` matches by `node.routeIds` (routes that touched this node while the
  graph was built), a service node also by its service anywhere along a route, and a device node
  by the services it hosts. Before 1.5.6 the rule lived inline here and matched every free-form
  hop for nodes without a service; the related routes' access levels are now localized.

### `const _TopologyLayoutRequest({required this.graph, required this.routes, required this.viewportWidth})` <a id="topologylayoutrequest-new"></a>
- **Kind:** constructor.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 382).
- **Purpose:** Create the value used as a topology layout's cache key.
- **Inputs:** `graph`, `routes`, `viewportWidth`.
- **Returns:** A new `_TopologyLayoutRequest`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:** Constructed once per `build` call in `_ServiceTopologyViewState.build`.
- **Notes:** None.

### `bool operator ==(Object other)` <a id="equals"></a>
- **Kind:** operator of `_TopologyLayoutRequest`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 394).
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
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 407).
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

### `Future<void> _exportTopologyImage()` <a id="exporttopologyimage"></a>
- **Kind:** method of `_ServiceTopologyPageState`.
- **Source:** `lib/features/services/views/service_topology_page.dart` (line 467).
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
- **Usage:** `onPressed: _exporting || !_layoutReady ? null : _exportTopologyImage` on the app bar's
  export `IconButton` in `build`.
- **Notes:** The actual share/save mechanism (share sheet vs. file picker vs. clipboard) is
  platform-specific and lives inside `ImageShareService`, not here — see
  [Platform Notes](../../../../platform-notes.md#android).
