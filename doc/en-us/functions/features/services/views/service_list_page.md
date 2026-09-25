# lib/features/services/views/service_list_page.dart

The Services tab's top-level page, described conceptually in
[Services and Topology](../../../../features/services-topology.md): `ServiceListPage` and
`_ServiceListPageState` with its four views (overview/by-device/routes/ports). The overview's
topology card opens the full-screen topology, which lives in
[`service_topology_page.md`](service_topology_page.md) since 1.5.6, with its node card, edge
painter and icon helpers in [`service_topology_widgets.md`](service_topology_widgets.md). Every
"Add access" entry point pushes the guided access-path page
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

**Row-count note:** `grep -c 'Purpose:' service_list_page.dart` returns **34**, every block sits
directly above a real declaration, and every declaration has one: **34** rows, split **7 Tier A /
27 Tier B** below. 1.5.6 removed the quick-access dialog (`_QuickAccessMethod`, whose first enum
constant carried the one block that documented no declaration, `_QuickAccessRouteDialog` and its
state), `_warningText` (now `serviceWarningLabel` in `service_labels.dart`), and the two tail
helpers only the dialog used (`_splitTargets`, `_emptyToNull`); `_isFrpLikeService` moved to
[`service_access_patterns.md`](../services/service_access_patterns.md). It then moved the whole
topology sub-flow out — 16 declarations to [`service_topology_page.md`](service_topology_page.md)
and 18 to [`service_topology_widgets.md`](service_topology_widgets.md), including the ten tail
helpers that had no `/// Purpose:` block here.

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
| `_openTopology` | method (`_ServiceListPageState`) | B | Push `ServiceTopologyPage` for a built graph. |
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

`enum _ServiceView { overview, devices, routes, ports }` (line 24) is a simple, member-less enum
with no constructor/methods of its own, so it isn't listed either — it only appears as the
parameter/return type of `_viewLabel` and `_buildCurrentView` and in the `SegmentedButton` in
`build`.

The service and route icons this page shows come from
[`service_topology_widgets.md`](service_topology_widgets.md) (`iconForService`), which the service
editor and the guided access-path page share.

## Documentation

### `void initState()` <a id="initstate"></a>
- **Kind:** method of `_ServiceListPageState` (widget lifecycle override).
- **Source:** `lib/features/services/views/service_list_page.dart` (line 58).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 89).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 191).
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
  service as source), and passed through as the `onAddAccess` callback to `ServiceTopologyPage`,
  whose node details ([`_showDetailsSheet`](service_topology_page.md#showdetailssheet),
  [`_buildDetailsPane`](service_topology_page.md#builddetailspane)) call it; its type is
  `Future<void> Function({ServiceAccessDraft? draft})`.
- **Notes:** Replaced `_addAccessRoute` and the `_QuickAccessRouteDialog` it opened in 1.5.6. The
  page persists the route itself, so this method only reloads.

### `List<MapEntry<String, List<ServiceRoute>>> _routesGroupedByService()` <a id="routesgroupedbyservice"></a>
- **Kind:** method of `_ServiceListPageState`.
- **Source:** `lib/features/services/views/service_list_page.dart` (line 743).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 922).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 939).
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
- **Source:** `lib/features/services/views/service_list_page.dart` (line 964).
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
