# lib/features/services/views/service_list_page.dart

The Services tab's top-level page and its entire topology sub-flow, described conceptually in
[Services and Topology](../../../../features/services-topology.md). This one file owns three
layers: (1) the main list page (`ServiceListPage`/`_ServiceListPageState`) with its four views
(overview/by-device/routes/ports); (2) the quick-access route dialog
(`_QuickAccessRouteDialog`/`_QuickAccessRouteDialogState`), the simple/default flow for adding a
direct/reverse-proxy/tunnel/FRP/router-port-forward access path; and (3) the full-screen topology
page and its rendering (`_ServiceTopologyPage`, `_ServiceTopologyView`, `_TopologyNodeCard`,
`_ServiceTopologyEdgePainter`, and the `_TopologyLayoutRequest` layout-cache key). Graph
construction, warning/conflict detection, and most route-formatting helpers are read from
`service_analysis.dart` ([`../services/service_analysis.md`](../services/service_analysis.md));
node/edge placement and edge routing come from `service_topology_layout.dart`
([`../services/service_topology_layout.md`](../services/service_topology_layout.md)). Persistence
goes through `ServiceStorage`/`DeviceStorage`/`NetworkStorage`
([`../services/service_storage.md`](../services/service_storage.md)); the add/edit forms this page
pushes to live in [`service_edit_page.md`](service_edit_page.md) and
[`service_route_edit_page.md`](service_route_edit_page.md). Like the app's other list pages,
`_ServiceListPageState` registers with
[`AutoSyncService`](../../../shared/services/auto_sync_service.md) so a background sync reloads the
list automatically.

**Row-count note:** `grep -c 'Purpose:' service_list_page.dart` returns **72**. Unlike
`service_analysis.dart` (see [`service_analysis.md`](../services/service_analysis.md)), none of
these 72 blocks are misattached to a call-site statement — every single one sits directly above a
real declaration (verified by reading the line immediately following each block). However, one of
the 72 (the block above line 32, `direct(ServiceRouteMethod.direct),`) documents an **enum
constant**, not a function/method/constructor/getter — it's the first of `_QuickAccessMethod`'s ten
values, and the other nine (`caddy` through `custom`) have no doc block at all. Consistent with
this doc set's convention of listing only behavior-bearing declarations (plain data fields are
likewise omitted; see `service_analysis.md`'s field-exclusion precedent), that one enum-constant
block is described here in prose rather than as its own Declarations-table row. So **71** of the 72
blocks document genuine declarations. Separately, this file has **12 undocumented top-level helper
functions** at its tail (lines 2253–2438: `_splitTargets` through `_iconForService`) with no
`/// Purpose:` block at all. That gives **71 + 12 = 83** real declarations total, split **24 Tier A
/ 59 Tier B** below.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `_QuickAccessMethod` (constructor) | constructor | B | Create an enum value wrapping the underlying `ServiceRouteMethod`. |
| `isPortMapping` | getter (`_QuickAccessMethod`) | B | Whether this quick-access method is FRP or router port-forward (vs. a proxy/tunnel/direct). |
| `ServiceListPage` (constructor) | constructor | B | Create the page widget (no parameters). |
| `createState` | method (`ServiceListPage`) | B | Create the page's mutable state object. |
| [`initState`](#initstate) | method (`_ServiceListPageState`, widget lifecycle) | A | Register the auto-sync listener and kick off the initial services/routes/devices/networks load. |
| `dispose` | method (`_ServiceListPageState`, widget lifecycle) | B | Unregister the auto-sync listener. |
| `_handleLocalDataChanged` | method (`_ServiceListPageState`) | B | Reload services/routes/devices/networks in response to an auto-sync notification. |
| [`_load`](#load) | method (`_ServiceListPageState`) | A | Reload services, routes, devices, and networks from storage. |
| `_deviceById` | method (`_ServiceListPageState`) | B | Look up a device by id in the loaded device list. |
| `_serviceById` | method (`_ServiceListPageState`) | B | Look up a service by id in the loaded service list. |
| `_endpointById` | method (`_ServiceListPageState`) | B | Look up an endpoint by id on a service, or its first endpoint if no id is given. |
| `_addService` | method (`_ServiceListPageState`) | B | Push the blank service edit page, then reload if it reported a save. |
| `_editService` | method (`_ServiceListPageState`) | B | Push the service edit page for an existing service, then reload if it reported a save. |
| `_addRoute` | method (`_ServiceListPageState`) | B | Push the advanced route editor, then reload if it reported a save. |
| [`_addAccessRoute`](#addaccessroute) | method (`_ServiceListPageState`) | A | Show the quick-access dialog and persist every route it returns. |
| `_editRoute` | method (`_ServiceListPageState`) | B | Push the advanced route editor for an existing route, then reload if it reported a save. |
| `_viewLabel` | method (`_ServiceListPageState`) | B | Map a `_ServiceView` to its localized segmented-button label. |
| `build` | method (widget, `_ServiceListPageState`) | B | Build the scaffold: app bar actions, FAB, view switcher, current view body. |
| `_buildCurrentView` | method (widget helper) | B | Dispatch to the builder for the currently selected `_ServiceView`. |
| `_buildOverview` | method (widget helper) | B | Render the overview view: metric cards, topology card, warnings, route groups, service list. |
| `_buildDevices` | method (widget helper) | B | Render the by-device view: services grouped and expandable per device. |
| `_buildRoutes` | method (widget helper, `_ServiceListPageState`) | B | Render the routes view: one card per route. |
| `_buildPorts` | method (widget helper) | B | Render the ports view: port-conflicts banner plus per-device port usage list. |
| `_topologyCard` | method (widget helper) | B | Render the overview's topology summary card with a responsive header/actions row. |
| `_openTopology` | method (`_ServiceListPageState`) | B | Push the full-screen topology page for a built graph. |
| [`_routesGroupedByService`](#routesgroupedbyservice) | method (`_ServiceListPageState`) | A | Group routes by source service id and sort the groups by service name. |
| `_serviceRouteGroupCard` | method (widget helper) | B | Render one service's route group as an expandable card. |
| `_metricCard` | method (widget helper) | B | Render one overview metric tile (icon, value, label). |
| `_serviceTile` | method (widget helper) | B | Render one service's list tile (icon, device, endpoints, route count, menu). |
| `_routeCard` | method (widget helper) | B | Render one route's summary card. |
| [`_hopLabel`](#hoplabel) | method (`_ServiceListPageState`) | A | Compute a display label for one route hop. |
| [`_routeSummary`](#routesummary) | method (`_ServiceListPageState`) | A | Build the "source -> hops -> targets" summary line for a route. |
| [`_routesForEndpoint`](#routesforendpoint) | method (`_ServiceListPageState`) | A | Find the display names of routes that use a given service endpoint. |
| `_warningText` | method (`_ServiceListPageState`) | B | Map a `ServiceWarning` to its localized message. |
| `_emptyState` | method (widget helper) | B | Render a centered empty-state message. |
| `_emptyInline` | method (widget helper) | B | Render a padded inline empty-state message. |
| `_QuickAccessRouteDialog` (constructor) | constructor | B | Create the dialog widget (services, devices, optional initial service). |
| `createState` | method (`_QuickAccessRouteDialog`) | B | Create the dialog's mutable state object. |
| [`initState`](#initstate-quickaccessroutedialogstate) | method (`_QuickAccessRouteDialogState`, widget lifecycle) | A | Create the text controllers and seed the default source service/endpoint. |
| `dispose` | method (`_QuickAccessRouteDialogState`, widget lifecycle) | B | Dispose the four text controllers. |
| `_selectedSource` | getter (`_QuickAccessRouteDialogState`) | B | Resolve the currently selected source `ServiceNode`, if any. |
| [`_buildRoutes`](#buildroutes) | method (`_QuickAccessRouteDialogState`) | A | Assemble the single `ServiceRoute` described by the current form state. |
| [`_buildHop`](#buildhop) | method (`_QuickAccessRouteDialogState`) | A | Build the one `ServiceRouteHop` matching the selected quick-access method. |
| `_submit` | method (`_QuickAccessRouteDialogState`) | B | Validate the form and pop the dialog with the built route list. |
| `build` | method (widget, `_QuickAccessRouteDialogState`) | B | Render the quick-access form (source/endpoint/method/relay/access-level fields). |
| [`_relayServiceOptions`](#relayserviceoptions) | method (`_QuickAccessRouteDialogState`) | A | List candidate relay services, preferring FRP-like ones for port-mapping methods. |
| [`_isFrpLikeService`](#isfrplikeservice) | method (`_QuickAccessRouteDialogState`) | A | Heuristically decide whether a service looks like an FRP/tunnel relay. |
| `_deviceName` | method (`_QuickAccessRouteDialogState`) | B | Resolve a device id to its name, or the id itself if unresolved. |
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
| [`_splitTargets`](#splittargets) | top-level function | A | Split a newline/comma-separated string into trimmed, non-empty target strings. |
| `_emptyToNull` | top-level function | B | Trim a string and convert an empty result to `null`. |
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

`_QuickAccessMethod`'s other nine enum values (`caddy`, `nginx`, `traefik`, `frp`, `pangolin`,
`cloudflareTunnel`, `tailscaleFunnel`, `routerPortForward`, `custom`) are plain data, like `direct`,
and are likewise not given their own table rows. `enum _ServiceView { overview, devices, routes,
ports }` and `enum _TopologyInteractionMode { select, move }` (lines 22/24) are simple, member-less
enums with no constructor/methods of their own, so they aren't listed either — they only appear as
the parameter/return types of the methods above (`_viewLabel`, `_buildCurrentView`, the
`SegmentedButton`s in `build`).

`iconForServiceIcon` (line 2391) is the one **public** (non-underscore) top-level declaration in
this file; it's also called from `service_edit_page.dart` (see
[`service_edit_page.md`](service_edit_page.md)) to render the icon preview next to the service
name/icon field and the template picker's per-template icon.

## Documentation

### `void initState()` <a id="initstate"></a>
- **Kind:** method of `_ServiceListPageState` (widget lifecycle override).
- **Source:** `lib/features/services/views/service_list_page.dart` (line 93).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 124).
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
  after every add/edit/access-route flow (the `if (result == true) _load();` pattern in
  `_addService`/`_editService`/`_addRoute`/`_editRoute`, and `await _load();` in
  [`_addAccessRoute`](#addaccessroute)).
- **Notes:** The three storages are loaded sequentially rather than with `Future.wait`, so total
  load time is additive across them — acceptable given these are small local JSON files.

### `Future<void> _addAccessRoute({ServiceNode? source})` <a id="addaccessroute"></a>
- **Kind:** method of `_ServiceListPageState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 210).
- **Purpose:** Open the quick-access route dialog and persist every route it returns.
- **Inputs:** `source` — optional service to preselect as the dialog's source service.
- **Returns:** `Future<void>`.
- **Side effects:** Shows `_QuickAccessRouteDialog`; calls `ServiceStorage.addOrUpdateRoute` once
  per returned route; reloads.
- **Algorithm:** 1. `showDialog<List<ServiceRoute>>` with
  `_QuickAccessRouteDialog(services: _services, devices: _devices, initialService: source)`.
  2. Return early if the result is `null` or empty (dialog cancelled). 3. For each returned route,
  `await ServiceStorage.addOrUpdateRoute(route)`, sequentially. 4. `await _load()`.
- **Usage:**
  ```dart
  IconButton(
    icon: const Icon(Icons.add_link),
    tooltip: l10n.serviceAddAccess,
    onPressed: _services.isEmpty ? null : () => _addAccessRoute(),
  ),
  ```
  Also called (with a specific `source`) from `_buildOverview`'s add-access button,
  `_serviceRouteGroupCard`, `_serviceTile`'s popup menu, `_topologyCard`'s action row, and passed
  through as the `onAddAccess` callback to `_ServiceTopologyPage`/`_ServiceTopologyView`/
  [`_showNodeDetails`](#shownodedetails).
- **Notes:** [`_QuickAccessRouteDialogState._buildRoutes`](#buildroutes) currently always returns a
  single-element (or empty) list, but this method is written to loop over an arbitrary list, so a
  future dialog variant that submits multiple routes at once needs no change here.

### `List<MapEntry<String, List<ServiceRoute>>> _routesGroupedByService()` <a id="routesgroupedbyservice"></a>
- **Kind:** method of `_ServiceListPageState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 737).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 912).
- **Purpose:** Compute a short display label for one route hop, for the route summary line.
- **Inputs:** `hop`.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** 1. If the hop's `serviceId` resolves to a known service, return that service's
  name. 2. Else if `hop.label` is non-empty, return it. 3. Else if `hop.host` is non-empty, return
  a `scheme://host:port/path`-shaped string built from whichever of `scheme`/`port`/`path` are
  present. 4. Otherwise fall back to `hop.type.name`.
- **Usage:** `route.hops.map(_hopLabel)` inside [`_routeSummary`](#routesummary).
- **Notes:** This is the UI text-summary counterpart to `_relayLabel` in `service_analysis.dart`'s
  topology-graph builder — both implement a similar service-name/label/host/type fallback chain for
  a hop, but independently (this one for the route list's text, that one for the graph's node
  label); see
  [`../services/service_analysis.md#relaylabel`](../services/service_analysis.md#relaylabel).

### `String _routeSummary(ServiceRoute route, {ServiceNode? source, ServiceEndpoint? sourceEndpoint})` <a id="routesummary"></a>
- **Kind:** method of `_ServiceListPageState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 929).
- **Purpose:** Build the two-line textual summary shown under each route card: the source-to-target
  path, then the access level.
- **Inputs:** `route`; `source`/`sourceEndpoint` — already-resolved source service/endpoint (so this
  method doesn't have to re-resolve them).
- **Returns:** `String` — the arrow-joined path and `route.accessLevel.name` joined by `'\n'`.
- **Side effects:** None.
- **Algorithm:** 1. Build a `parts` list: the source service's name (with its endpoint's port text
  appended if the endpoint has a port), then each hop's [`_hopLabel`](#hoplabel), then each access
  target (`serviceRouteAccessTargets(route)`) run through `compactAccessTargetLabel`. 2. Join
  non-empty `parts` with `' -> '`, or fall back to `route.name` if `parts` ended up empty.
  3. Append `route.accessLevel.name` as a second line.
- **Usage:** `_routeSummary(route, source: source, sourceEndpoint: sourceEndpoint)` in
  `_routeCard`'s subtitle.
- **Notes:** In practice `parts` can't actually be empty (a route always has at least one hop), so
  the `route.name` fallback is defensive rather than a normally-reached path.

### `String? _routesForEndpoint(String serviceId, String endpointId)` <a id="routesforendpoint"></a>
- **Kind:** method of `_ServiceListPageState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 951).
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

### `void initState()` <a id="initstate-quickaccessroutedialogstate"></a>
- **Kind:** method of `_QuickAccessRouteDialogState` (widget lifecycle override). Disambiguated
  from [`_ServiceListPageState.initState`](#initstate) above since both are named `initState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1084).
- **Purpose:** Create the dialog's text controllers and seed the default source service/endpoint
  selection.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Instantiates four `TextEditingController`s; sets `_sourceServiceId`/
  `_sourceEndpointId`.
- **Algorithm:** 1. `super.initState()`. 2. Create `_targetsCtrl`/`_remoteHostCtrl`/
  `_remotePortCtrl`/`_notesCtrl`. 3. Default `_sourceServiceId` to `widget.initialService?.id`,
  falling back to the first entry of `widget.services`. 4. Default `_sourceEndpointId` to the
  resolved source's first endpoint id.
- **Usage:** Invoked automatically when `_QuickAccessRouteDialog`'s state is created, e.g. from the
  `showDialog(... builder: (context) => _QuickAccessRouteDialog(...))` call in
  [`_addAccessRoute`](#addaccessroute).
- **Notes:** The counterpart `dispose()` (line 1101) disposes all four controllers. Unlike the outer
  page, this dialog does not register with `AutoSyncService` — it's a short-lived modal form, not a
  persistent page.

### `List<ServiceRoute> _buildRoutes()` <a id="buildroutes"></a>
- **Kind:** method of `_QuickAccessRouteDialogState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1125).
- **Purpose:** Assemble the single `ServiceRoute` described by the current form state, ready to
  hand back to the caller.
- **Inputs:** None (reads the dialog's form-state fields).
- **Returns:** `List<ServiceRoute>` — empty if no source service is selected, otherwise a
  single-element list.
- **Side effects:** None (pure construction).
- **Algorithm:** 1. Resolve `_selectedSource`; return `const []` if `null`. 2. Split
  `_targetsCtrl.text` into targets via [`_splitTargets`](#splittargets). 3. Build the one hop via
  [`_buildHop`](#buildhop)`(_method.routeMethod)`. 4. Construct one `ServiceRoute` whose `name`
  comes from `serviceRouteGeneratedName`, `finalUrl` is the first target, and `extraJson` carries
  any remaining targets via `serviceRouteExtraJsonWithTargets`.
- **Usage:** `Navigator.of(context).pop(_buildRoutes());` in `_submit`.
- **Notes:** Despite the plural name/return type, this always builds **at most one** `ServiceRoute`
  — the quick-access flow only ever creates a single route with a single hop per submission, per
  [Quick access-route creation vs. the advanced editor](../../../../features/services-topology.md#quick-access-route-creation-vs-the-advanced-editor).

### `ServiceRouteHop _buildHop(ServiceRouteMethod method)` <a id="buildhop"></a>
- **Kind:** method of `_QuickAccessRouteDialogState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1155).
- **Purpose:** Build the one `ServiceRouteHop` matching the currently selected quick-access method.
- **Inputs:** `method`.
- **Returns:** `ServiceRouteHop`.
- **Side effects:** None.
- **Algorithm:** If `_method.isPortMapping` (FRP or router port-forward): build a
  `ServiceRouteHopType.portForward` hop carrying `_relayServiceId`/`_remoteDeviceId` plus the
  parsed `_remoteHostCtrl`/`_remotePortCtrl` text (falling back to a method-name label when no
  relay service is chosen). Otherwise: pick the hop type by a `switch` on `method` (`direct` →
  `manual`; `caddy`/`nginx`/`traefik` → `reverseProxy`; `routerPortForward` → `portForward`;
  everything else, i.e. the tunnel-style methods `frp`/`pangolin`/`cloudflareTunnel`/
  `tailscaleFunnel`/`custom` → `tunnel`), with `serviceId: _relayServiceId` and the same label
  fallback.
- **Usage:** `_buildHop(method)` in [`_buildRoutes`](#buildroutes).
- **Notes:** Implements the FRP ingress/public-port modeling split described in
  [Services and Topology](../../../../features/services-topology.md#frp-style-ingresspublic-port-modeling)
  — the port-mapping branch here produces the *ingress*-port hop; the paired public remote-entry
  port comes from the separate `_remoteHostCtrl`/`_remotePortCtrl` fields, not a second hop.

### `List<ServiceNode> _relayServiceOptions()` <a id="relayserviceoptions"></a>
- **Kind:** method of `_QuickAccessRouteDialogState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1426).
- **Purpose:** List candidate relay services for the "via" dropdown, preferring FRP-like services
  first when the selected method is a port-mapping method.
- **Inputs:** None (reads `widget.services`, `_sourceServiceId`, `_method`).
- **Returns:** `List<ServiceNode>` — every service except the selected source, sorted.
- **Side effects:** None.
- **Algorithm:** 1. Filter out the currently selected source service. 2. Sort: when
  `_method.isPortMapping`, services where [`_isFrpLikeService`](#isfrplikeservice) is `true` sort
  before those where it's `false`; otherwise (or as a tiebreak), compare names case-insensitively.
- **Usage:** Populates the relay-service dropdown's `items` in `build`.
- **Notes:** The FRP-preference sort is a UX convenience only (surfacing the likely-right relay
  first) — it does not filter out non-FRP-like services; any service remains selectable.

### `bool _isFrpLikeService(ServiceNode service)` <a id="isfrplikeservice"></a>
- **Kind:** method of `_QuickAccessRouteDialogState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1446).
- **Purpose:** Heuristically decide whether a service looks like an FRP/tunnel relay, for sorting
  the relay dropdown.
- **Inputs:** `service`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Join `service.name`/`templateId`/`icon`/`kind.name` (skipping nulls) into one
  lower-cased string; return `true` if it contains `"frp"` or if `service.kind ==
  ServiceKind.tunnel`.
- **Usage:** Called from [`_relayServiceOptions`](#relayserviceoptions)'s sort comparator.
- **Notes:** A pure naming/kind heuristic — it does not inspect any actual service configuration
  (Docker Compose text, endpoints, etc.), consistent with the manual-inventory-only design (no
  discovery), per [Services and Topology](../../../../features/services-topology.md).

### `void _ensureLayout(_TopologyLayoutRequest request)` <a id="ensurelayout"></a>
- **Kind:** method of `_ServiceTopologyViewState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1554).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1568).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1691).
- **Purpose:** Resolve a tapped topology node's device/service/related routes and show them in a
  bottom sheet with edit/add-access actions.
- **Inputs:** `context`, `node`.
- **Returns:** `void`.
- **Side effects:** Shows a `showModalBottomSheet`; its action buttons call
  `widget.onEditService`/`widget.onEditRoute`/`widget.onAddAccess` and pop the sheet.
- **Algorithm:** 1. Resolve `device`/`service` from `node.deviceId`/`node.serviceId` against
  `widget.devices`/`widget.services` (`null` if unset or unresolved). 2. Resolve `relatedRoutes`:
  routes whose id is in `node.routeIds`, or whose source service, or whose any hop's service,
  matches `node.serviceId`. 3. Show a bottom sheet listing the node's own label/role/detail/lane;
  the device tile if resolved; the service tile (with endpoints) plus Edit/Add-access buttons if
  resolved; and one tile per related route (edit-on-tap) if any.
- **Usage:** `onTap: widget.mode == _TopologyInteractionMode.select ? () =>
  _showNodeDetails(context, node) : null` in `_buildViewer` — only wired up in select mode, not in
  move/zoom mode.
- **Notes:** `relatedRoutes` matches by `node.routeIds` (routes that touched this node while the
  graph was built) as well as by service id, so a route can surface here even when this exact node
  wasn't its source, as long as the node's service appears anywhere along the route's hops.

### `const _TopologyLayoutRequest({required this.graph, required this.routes, required this.viewportWidth})` <a id="topologylayoutrequest-new"></a>
- **Kind:** constructor.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1822).
- **Purpose:** Create the value used as a topology layout's cache key.
- **Inputs:** `graph`, `routes`, `viewportWidth`.
- **Returns:** A new `_TopologyLayoutRequest`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:** Constructed once per `build` call in `_ServiceTopologyViewState.build`.
- **Notes:** None.

### `bool operator ==(Object other)` <a id="equals"></a>
- **Kind:** operator of `_TopologyLayoutRequest`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1834).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1847).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 1899).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 2180).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 2199).
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

### `List<String> _splitTargets(String value)` <a id="splittargets"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 2253).
- **Purpose:** Split a free-form, newline/comma-separated string of access targets into a clean
  list.
- **Inputs:** `value` — raw text from the quick-access dialog's targets field.
- **Returns:** `List<String>` — trimmed, non-empty entries.
- **Side effects:** None.
- **Algorithm:** Split on the regex `[\n,]+`; trim each piece; drop empty results.
- **Usage:** `_splitTargets(_targetsCtrl.text)` in
  [`_QuickAccessRouteDialogState._buildRoutes`](#buildroutes).
- **Notes:** Accepts either newline- or comma-separated input (or a mix), so a user can paste a list
  of domains either way.

### `String _compactTopologyLabel(ServiceTopologyNode node)` <a id="compacttopologylabel"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 2264).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 2280).
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
