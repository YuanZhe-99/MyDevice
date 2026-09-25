# lib/features/services/views/service_list_page.dart

The Services tab's top-level page and its entire topology sub-flow, described conceptually in
[Services and Topology](../../../../features/services-topology.md). This one file owns two
layers: (1) the main list page (`ServiceListPage`/`_ServiceListPageState`) with its four views
(overview/by-device/routes/ports); and (2) the full-screen topology page and its rendering
(`_ServiceTopologyPage`, `_ServiceTopologyView`, `_TopologyNodeCard`,
`_ServiceTopologyEdgePainter`, and the `_TopologyLayoutRequest` layout-cache key). Every "Add
access" entry point pushes the guided access-path page
([`service_access_path_page.md`](service_access_path_page.md)) through `_addAccessPath`; the
quick-access route dialog this file held until 1.5.6 is gone. Graph construction,
warning/conflict detection, and most route-formatting helpers are read from
`service_analysis.dart` ([`../services/service_analysis.md`](../services/service_analysis.md));
node/edge placement and edge routing come from `service_topology_layout.dart`
([`../services/service_topology_layout.md`](../services/service_topology_layout.md)); warning
texts and other UI labels come from [`../services/service_labels.md`](../services/service_labels.md).
Persistence goes through `ServiceStorage`/`DeviceStorage`/`NetworkStorage`
([`../services/service_storage.md`](../services/service_storage.md)); the add/edit forms this page
pushes to live in [`service_edit_page.md`](service_edit_page.md) and
[`service_route_edit_page.md`](service_route_edit_page.md). Like the app's other list pages,
`_ServiceListPageState` registers with
[`AutoSyncService`](../../../shared/services/auto_sync_service.md) so a background sync reloads the
list automatically.

**Row-count note:** `grep -c 'Purpose:' service_list_page.dart` returns **58**, and every block
sits directly above a real declaration. The file also has **10 undocumented top-level helper
functions** at its tail (lines 1834–2008: `_compactTopologyLabel` through `_iconForService`) with
no `/// Purpose:` block at all. That gives **58 + 10 = 68** real declarations, split **19 Tier A /
49 Tier B** below. 1.5.6 removed the quick-access dialog (`_QuickAccessMethod`, whose first enum
constant carried the one block that documented no declaration, `_QuickAccessRouteDialog` and its
state), `_warningText` (now `serviceWarningLabel` in `service_labels.dart`), and the two tail
helpers only the dialog used (`_splitTargets`, `_emptyToNull`); `_isFrpLikeService` moved to
[`service_access_patterns.md`](../services/service_access_patterns.md) and `_nodeSubtitle` was
added.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ServiceListPage` (constructor) | constructor | B | Create the page widget (no parameters). |
| `createState` | method (`ServiceListPage`) | B | Create the page's mutable state object. |
| [`initState`](#initstate) | method (`_ServiceListPageState`, widget lifecycle) | A | Register the auto-sync listener and kick off the initial services/routes/devices/networks load. |
| `dispose` | method (`_ServiceListPageState`, widget lifecycle) | B | Unregister the auto-sync listener. |
| `_handleLocalDataChanged` | method (`_ServiceListPageState`) | B | Reload services/routes/devices/networks in response to an auto-sync notification. |
| [`_load`](#load) | method (`_ServiceListPageState`) | A | Reload services, routes, devices, and networks from storage. |
| `_deviceById` | method (`_ServiceListPageState`) | B | Look up a device by id in the loaded device list. |
| `_serviceById` | method (`_ServiceListPageState`) | B | Look up a service by id in the loaded service list. |
| `_endpointById` | method (`_ServiceListPageState`) | B | Look up an endpoint by id on a service, or its first endpoint if no id is given. |
| `_addService` | method (`_ServiceListPageState`) | B | Push the blank service edit page, then reload when it pops a `ServiceEditOutcome`. |
| `_editService` | method (`_ServiceListPageState`) | B | Push the service edit page for an existing service, then reload when it pops a `ServiceEditOutcome` (a save or a delete). |
| `_addRoute` | method (`_ServiceListPageState`) | B | Push the advanced route editor, then reload if it reported a save. |
| [`_addAccessPath`](#addaccesspath) | method (`_ServiceListPageState`) | A | Push the guided access-path page for a new access path; reload when it saved. |
| `_editRoute` | method (`_ServiceListPageState`) | B | Push the advanced route editor for an existing route, then reload if it reported a save. |
| `_viewLabel` | method (`_ServiceListPageState`) | B | Map a `_ServiceView` to its localized segmented-button label. |
| `build` | method (widget, `_ServiceListPageState`) | B | Build the scaffold: app bar actions, FAB, view switcher, current view body. |
| `_setColumnsPref` | method (`_ServiceListPageState`) | B | Store a new column preference (`DeviceStorage.setServiceListColumns`) and re-render. |
| `_buildCurrentView` | method (widget helper) | B | Dispatch to the builder for the currently selected `_ServiceView`, passing the column count from `listColumnCount` (at `shellContentWidth − 16` and `serviceCardMinWidth`) to the three list views. |
| `_buildOverview` | method (widget helper) | B | Render the overview view: metric cards (columns from `serviceMetricColumns`), topology card, warnings, route groups, service list. |
| `_buildDevices` | method (widget helper) | B | Render the by-device view: services grouped and expandable per device, the cards in `adaptiveTileRows` at the given column count. |
| `_buildRoutes` | method (widget helper, `_ServiceListPageState`) | B | Render the routes view: one card per route, in `adaptiveTileRows`. |
| `_buildPorts` | method (widget helper) | B | Render the ports view: port-conflicts banner plus per-device port usage cards, the cards in `adaptiveTileRows`. |
| `_topologyCard` | method (widget helper) | B | Render the overview's topology summary card; the header/actions row is gated by `useTopologyActionsRow` from `adaptive_layout.dart`. |
| `_openTopology` | method (`_ServiceListPageState`) | B | Push the full-screen topology page for a built graph. |
| [`_routesGroupedByService`](#routesgroupedbyservice) | method (`_ServiceListPageState`) | A | Group routes by source service id and sort the groups by service name. |
| `_serviceRouteGroupCard` | method (widget helper) | B | Render one service's route group as an expandable card. |
| `_metricCard` | method (widget helper) | B | Render one overview metric tile (icon, value, label). |
| `_serviceTile` | method (widget helper) | B | Render one service's list tile (icon, device, endpoints, route count, menu). |
| `_routeCard` | method (widget helper) | B | Render one route's summary card. |
| [`_hopLabel`](#hoplabel) | method (`_ServiceListPageState`) | A | Compute a display label for one route hop. |
| [`_routeSummary`](#routesummary) | method (`_ServiceListPageState`) | A | Build the "source -> hops -> targets" summary line for a route. |
| [`_routesForEndpoint`](#routesforendpoint) | method (`_ServiceListPageState`) | A | Find the display names of routes that use a given service endpoint. |
| `_emptyState` | method (widget helper) | B | Render a centered empty-state message. |
| `_emptyInline` | method (widget helper) | B | Render a padded inline empty-state message. |
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
| `_ServiceTopologyPage` (constructor) | constructor | B | Create the full-screen topology page widget. |
| `createState` | method (`_ServiceTopologyPage`) | B | Create the page's mutable state object. |
| [`_exportTopologyImage`](#exporttopologyimage) | method (`_ServiceTopologyPageState`) | A | Capture the topology canvas as a PNG and hand it to the platform share flow. |
| `build` | method (widget, `_ServiceTopologyPageState`) | B | Build the topology page scaffold: rotate/export actions, mode switch, topology view. |
| `_TopologyNodeCard` (constructor) | constructor | B | Create the node card widget (node, icon, tap handler). |
| `build` | method (widget, `_TopologyNodeCard`) | B | Render a node as a compact port chip or a full label/detail card. |
| `_ServiceTopologyEdgePainter` (constructor) | constructor | B | Create the edge painter (graph, layout, color scheme). |
| [`paint`](#paint) | method (`_ServiceTopologyEdgePainter`, `CustomPainter` override) | A | Draw every edge's routed polyline and arrowhead onto the canvas. |
| [`_drawPolyline`](#drawpolyline) | method (`_ServiceTopologyEdgePainter`) | A | Draw one edge's path plus a triangular arrowhead at its end. |
| `_edgeColor` | method (`_ServiceTopologyEdgePainter`) | B | Map an edge's access lane to a color-scheme color. |
| `shouldRepaint` | method (`_ServiceTopologyEdgePainter`) | B | Repaint only when the graph, layout, or color scheme changed. |
| [`_nodeSubtitle`](#nodesubtitle) | top-level function | A | The subtitle a topology node card shows: a relay's localized method or hop type, else the builder's detail. |
| [`_compactTopologyLabel`](#compacttopologylabel) | top-level function | A | Shorten a topology node's label/detail to a compact chip-sized string. |
| [`_iconForTopologyNode`](#iconfortopologynode) | top-level function | A | Resolve the icon for a topology node, by kind and its resolved device/service. |
| `_iconForMethod` | top-level function | B | Map a `ServiceRouteMethod` to its display icon. |
| `_primaryMethod` | top-level function | B | Return a route's first hop method, if any. |
| `_laneLabel` | top-level function | B | Map a `ServiceAccessLane` to its display label. |
| `_roleLabel` | top-level function | B | Map a `ServiceTopologyNodeRole` to its display label. |
| `_nodeFill` | top-level function | B | Map a topology node's role to its card fill color. |
| `_nodeBorder` | top-level function | B | Map a topology node's role to its card border color. |
| `iconForServiceIcon` | top-level function | B | Map a service's stored icon key to its `IconData`. |
| `_iconForService` | top-level function | B | Resolve a service's icon via `iconForServiceIcon`. |

`enum _ServiceView { overview, devices, routes,
ports }` and `enum _TopologyInteractionMode { select, move }` (lines 27/29) are simple, member-less
enums with no constructor/methods of their own, so they aren't listed either — they only appear as
the parameter/return types of the methods above (`_viewLabel`, `_buildCurrentView`, the
`SegmentedButton`s in `build`).

`iconForServiceIcon` (line 1961) is the one **public** (non-underscore) top-level declaration in
this file; it's also called from `service_edit_page.dart` (see
[`service_edit_page.md`](service_edit_page.md)) to render the icon preview next to the service
name/icon field and the template picker's per-template icon.

## Documentation

### `void initState()` <a id="initstate"></a>
- **Kind:** method of `_ServiceListPageState` (widget lifecycle override).
- **Source:** `lib/features/services/views/service_list_page.dart` (line 63).
- **Purpose:** Wire this page into the auto-sync notification system and kick off the initial
  services/routes/devices/networks load.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Registers `_handleLocalDataChanged` with
  `AutoSyncService.instance.addOnLocalDataChanged`; starts an async load.
- **Algorithm:** 1. Calls `super.initState()`. 2. Registers `_handleLocalDataChanged` as an
  `AutoSyncService` local-data-changed listener. 3. Calls `_load()` (not awaited).
- **Usage:** Invoked automatically by the Flutter framework when `_ServiceListPageState` is first
  inserted into the tree; no direct call site.
- **Notes:** The counterpart `dispose()` calls
  `AutoSyncService.instance.removeOnLocalDataChanged(_handleLocalDataChanged)` to avoid leaking the
  listener (see
  [`auto_sync_service.md#addonlocaldatachanged`](../../../shared/services/auto_sync_service.md)).

### `Future<void> _load()` <a id="load"></a>
- **Kind:** method of `_ServiceListPageState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 94).
- **Purpose:** Reload services, routes, devices, and networks from their respective storages and
  refresh the page's state.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads via `ServiceStorage.load()`, `DeviceStorage.load()`,
  `NetworkStorage.load()`; `setState` updates `_services`/`_routes`/`_devices`/`_networks` and
  clears `_loading`.
- **Algorithm:** Awaits `ServiceStorage.load()` (services + routes), then `DeviceStorage.load()`,
  then `NetworkStorage.load()`, sequentially (not in parallel); returns early if unmounted; one
  `setState` assigns all four lists and sets `_loading = false`.
- **Usage:** Called from [`initState`](#initstate), `_handleLocalDataChanged` (auto-sync), and
  after every add/edit/access-path flow: `if (result != null) _load();` on the
  `ServiceEditOutcome` of `_addService`/`_editService`, `if (result == true) _load();` in
  `_addRoute`/`_editRoute`, and `await _load();` in [`_addAccessPath`](#addaccesspath) when the
  page saved.
- **Notes:** The three storages are loaded sequentially rather than with `Future.wait`, so total
  load time is additive across them — acceptable given these are small local JSON files.

### `Future<void> _addAccessPath({ServiceAccessDraft? draft})` <a id="addaccesspath"></a>
- **Kind:** method of `_ServiceListPageState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 196).
- **Purpose:** Open the guided access-path page for a new access path.
- **Inputs:** `draft` — optional starting draft, e.g. `ServiceAccessDraft(sourceServiceId: ...)`
  to preselect the source service.
- **Returns:** `Future<void>`.
- **Side effects:** Pushes [`ServiceAccessPathPage`](service_access_path_page.md) on the root
  navigator; reloads when it pops `true` (the page itself saved the route).
- **Algorithm:** `push<bool>` the page with `draft`; `await _load()` when the result is `true`.
- **Usage:**
  ```dart
  IconButton(
    icon: const Icon(Icons.add_link),
    tooltip: l10n.serviceAddAccess,
    onPressed: _services.isEmpty ? null : () => _addAccessPath(),
  ),
  ```
  Also called from `_buildOverview`'s add-access button and `_topologyCard`'s action row
  (without a draft), from `_serviceRouteGroupCard` and `_serviceTile`'s popup menu (with the
  service as source), and passed through as the `onAddAccess` callback to
  `_ServiceTopologyPage`/`_ServiceTopologyView`/[`_showNodeDetails`](#shownodedetails), whose
  type is `Future<void> Function({ServiceAccessDraft? draft})`.
- **Notes:** Replaced `_addAccessRoute` and the `_QuickAccessRouteDialog` it opened in 1.5.6. The
  page persists the route itself, so this method only reloads.

### `List<MapEntry<String, List<ServiceRoute>>> _routesGroupedByService()` <a id="routesgroupedbyservice"></a>
- **Kind:** method of `_ServiceListPageState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 748).
- **Purpose:** Group all routes by their source service id, for the overview's per-service route
  cards.
- **Inputs:** None.
- **Returns:** `List<MapEntry<String, List<ServiceRoute>>>`, sorted by resolved service name
  (case-insensitive); an unresolved id sorts by its own raw text.
- **Side effects:** None.
- **Algorithm:** 1. Bucket `_routes` into a map keyed by `route.sourceServiceId`
  (`putIfAbsent(...).add(route)`). 2. Convert to a list of entries. 3. Sort by
  `_serviceById(key)?.name ?? key`, lower-cased.
- **Usage:** `for (final entry in _routesGroupedByService()) _serviceRouteGroupCard(l10n, entry.key,
  entry.value)` in `_buildOverview`.
- **Notes:** A route whose source service was since deleted still groups under its raw (unresolved)
  service id rather than being dropped from the overview.

### `String _hopLabel(ServiceRouteHop hop)` <a id="hoplabel"></a>
- **Kind:** method of `_ServiceListPageState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 927).
- **Purpose:** Compute a short display label for one route hop, for the route summary line.
- **Inputs:** `hop`.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** 1. If the hop's `serviceId` resolves to a known service, return that service's
  name. 2. Else if `hop.label` is non-empty, return it. 3. Else if `hop.host` is non-empty, return
  a `scheme://host:port/path`-shaped string built from whichever of `scheme`/`port`/`path` are
  present. 4. Otherwise fall back to the localized hop type (`serviceHopTypeLabel`).
- **Usage:** `route.hops.map(_hopLabel)` inside [`_routeSummary`](#routesummary).
- **Notes:** This is the UI text-summary counterpart to `_relayLabel` in `service_analysis.dart`'s
  topology-graph builder — both implement a similar service-name/label/host/type fallback chain for
  a hop, but independently (this one for the route list's text, that one for the graph's node
  label); see
  [`../services/service_analysis.md#relaylabel`](../services/service_analysis.md#relaylabel).

### `String _routeSummary(ServiceRoute route, {ServiceNode? source, ServiceEndpoint? sourceEndpoint})` <a id="routesummary"></a>
- **Kind:** method of `_ServiceListPageState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 944).
- **Purpose:** Build the two-line textual summary shown under each route card: the source-to-target
  path, then the access level.
- **Inputs:** `route`; `source`/`sourceEndpoint` — already-resolved source service/endpoint (so this
  method doesn't have to re-resolve them).
- **Returns:** `String` — the arrow-joined path and the localized access level
  (`serviceAccessLevelLabel`) joined by `'\n'`.
- **Side effects:** None.
- **Algorithm:** 1. Build a `parts` list: the source service's name (with its endpoint's port text
  appended if the endpoint has a port), then each hop's [`_hopLabel`](#hoplabel), then each access
  target (`serviceRouteAccessTargets(route)`) run through `compactAccessTargetLabel`. 2. Join
  non-empty `parts` with `' -> '`, or fall back to `route.name` if `parts` ended up empty.
  3. Append the localized access level as a second line.
- **Usage:** `_routeSummary(route, source: source, sourceEndpoint: sourceEndpoint)` in
  `_routeCard`'s subtitle.
- **Notes:** In practice `parts` can't actually be empty (a route always has at least one hop), so
  the `route.name` fallback is defensive rather than a normally-reached path.

### `String? _routesForEndpoint(String serviceId, String endpointId)` <a id="routesforendpoint"></a>
- **Kind:** method of `_ServiceListPageState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 969).
- **Purpose:** Find the display names of every route that uses a given service endpoint, either as
  its source or via a hop, for the ports view's subtitle.
- **Inputs:** `serviceId`, `endpointId`.
- **Returns:** `String?` — a comma-joined list of route display targets, or `null` if no route
  references this endpoint.
- **Side effects:** None.
- **Algorithm:** Filter `_routes` to those where either (`sourceServiceId` and `sourceEndpointId`
  both match), or any hop's (`serviceId` and `endpointId`) both match; map the survivors through
  `serviceRouteDisplayTarget`; join with `', '`; return `null` if nothing matched.
- **Usage:** `_routesForEndpoint(use.service.id, use.endpoint.id)` inside `_buildPorts`'s per-port
  subtitle (joined with the other `whereType<String>()`-filtered parts).
- **Notes:** Matches on the *combination* of service id and endpoint id — a route referencing the
  same service but a different one of its endpoints does not match.

### `void _ensureLayout(_TopologyLayoutRequest request)` <a id="ensurelayout"></a>
- **Kind:** method of `_ServiceTopologyViewState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1111).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1125).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1248).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1383).
- **Purpose:** Create the value used as a topology layout's cache key.
- **Inputs:** `graph`, `routes`, `viewportWidth`.
- **Returns:** A new `_TopologyLayoutRequest`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:** Constructed once per `build` call in `_ServiceTopologyViewState.build`.
- **Notes:** None.

### `bool operator ==(Object other)` <a id="equals"></a>
- **Kind:** operator of `_TopologyLayoutRequest`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1395).
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
  unequal. This is intentional: any new `buildServiceTopology`/[`_load`](#load) call invalidates the
  cache even if the resulting graph looks the same, and it avoids a deep structural comparison on
  every build. `viewportWidth` is rounded to an `int` (in `_ServiceTopologyViewState.build`) before
  comparison, to avoid tiny constraint jitter forcing a re-layout.

### `int get hashCode` <a id="hashcode"></a>
- **Kind:** getter of `_TopologyLayoutRequest`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1408).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1460).
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

### `void paint(Canvas canvas, Size size)` <a id="paint"></a>
- **Kind:** method of `_ServiceTopologyEdgePainter` (`CustomPainter` override).
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1740).
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
- **Kind:** method of `_ServiceTopologyEdgePainter`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1759).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1820).
- **Purpose:** Return the subtitle a topology node card shows under its label.
- **Inputs:** `context`, `node`.
- **Returns:** `String?` — null when there is nothing to show.
- **Side effects:** None.
- **Algorithm:** For a relay node, return the localized method (`serviceRouteMethodUiLabel`) when
  the node has one, else the localized hop type when `detail` is a raw hop-type name. Every other
  node returns its trimmed `detail`, or null when empty.
- **Usage:** `_TopologyNodeCard.build`'s full-card subtitle, joined with the lane label.
- **Notes:** The graph builder stores raw enum names in a relay's `detail`; localizing at render
  time keeps [`service_analysis.dart`](../services/service_analysis.md) language-free.

### `String _compactTopologyLabel(ServiceTopologyNode node)` <a id="compacttopologylabel"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1834).
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
- **Usage:** `_compactTopologyLabel(node)` in `_TopologyNodeCard.build`'s compact (port-chip)
  branch.
- **Notes:** Preferring the *last* number match (not the first) is what lets a detail string like
  `"tcp bind-host:8080"` show `8080` rather than an earlier, unrelated number in the bind address;
  this is a display-only shortening — the node's full label/detail remains available via its
  `Tooltip`.

### `IconData _iconForTopologyNode(ServiceTopologyNode node, List<ServiceNode> services, List<Device> devices)` <a id="iconfortopologynode"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1850).
- **Purpose:** Resolve the icon to show for a topology node, based on its kind and, when
  resolvable, its underlying device/service.
- **Inputs:** `node`, `services`, `devices`.
- **Returns:** `IconData`.
- **Side effects:** None.
- **Algorithm:** `device` kind → the resolved device's category icon (`deviceCategoryIcon`), or a
  generic devices icon if unresolved. `service` kind → the resolved service's icon
  (`_iconForService`), or a generic `dns` icon if unresolved. `endpoint` kind → a fixed
  ethernet-settings icon. `remoteEntry` → a public icon. `domain` → a language icon. Anything else
  → `_iconForMethod(node.method)`.
- **Usage:** `_iconForTopologyNode(node, widget.services, widget.devices)` in
  `_ServiceTopologyViewState._buildViewer` and [`_showNodeDetails`](#shownodedetails).
- **Notes:** None.
