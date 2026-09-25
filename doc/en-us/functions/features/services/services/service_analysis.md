# lib/features/services/services/service_analysis.dart

Pure-computation companion to the Services feature described in
[../../../../features/services-topology.md](../../../../features/services-topology.md) and the
layout engine in [service_topology_layout.md](service_topology_layout.md): builds the
`ServiceTopologyGraph` (nodes/edges) from saved services/routes, detects port conflicts and
dangling references, and provides the access-target/route-naming helpers shared by the UI and
`import_export_service.dart`'s Markdown export. Since 1.5.6 it also owns the route access-lane
override (`extraJson['accessLane']`, see
[Data Formats](../../../../data-formats.md#extrajson-unknown-field-preservation)), the default
FRP ingress shared with [service_access_patterns.md](service_access_patterns.md),
`relatedRoutesForNode`, which the topology uses for node details, and the full-screen topology's
selection and filter logic: every edge records all the routes along it (`routeIds`),
`serviceTopologyHighlight` works out what a selection lights up, and `ServiceTopologyFilter` with
`filterServiceTopologyInput` narrows the inventory a graph is built from.

**Row-count note:** `grep -c 'Purpose:' service_analysis.dart` returns **37**, but 2 of those
blocks are misattached to non-declarations by the doc-comment tool that authored them — one sits
above a call `uses.sort(...)` inside `listServicePortUses` (not a declaration), and one sits above
a call `addTarget(route.finalUrl);` inside `serviceRouteAccessTargets` (the real declaration of
`addTarget`, a few lines above, already carries its own correct block). So only **35** blocks
document real declarations. This file has **59** real declarations total (10 class
members + 49 top-level/nested functions), so **24** are undocumented — the same arithmetic
reconciles (35 documented + 24 undocumented = 59; 35 documented + 2 misattached = 37 raw grep
matches). 1.5.6 added ten blocks: `buildServiceTopology`, `serviceAccessLaneForRoute` and
`_portMappingIngressEndpoint` gained theirs, and the seven new declarations below came with
theirs. The topology's selection and filters then added **17** more declarations, each with its
block (`ServiceTopologyEdge.withRoute`, the `ServiceTopologyFilter` class's constructor, five
getters, `copyWith`, `==` and `hashCode`, `_sameSet`, `filterServiceTopologyInput` and its three
nested helpers, `ServiceTopologyHighlight`'s constructor and `serviceTopologyHighlight`): the
file now returns **54** raw matches, **52** documented declarations, and **76** declarations in
all (**44 Tier A / 32 Tier B**).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`ServiceTopologyNode` constructor](#servicetopologynode-new) | constructor | A | Create an immutable topology node. |
| [`mergeRoute`](#mergeroute) | method (`ServiceTopologyNode`) | A | Attach a route id to a node, merging if it already exists. |
| [`merge`](#merge) | method (`ServiceTopologyNode`) | A | Combine two node instances that share an id. |
| [`ServiceTopologyEdge` constructor](#servicetopologyedge-new) | constructor | A | Create an immutable topology edge. |
| `withRoute` | method (`ServiceTopologyEdge`) | B | Return the edge with one more route along it (`routeIds`), keeping `routeId`. |
| [`ServiceTopologyGraph` constructor](#servicetopologygraph-new) | constructor | A | Create the graph result value. |
| `isEmpty` | getter (`ServiceTopologyGraph`) | B | Whether the graph has no nodes. |
| [`ServicePortUse` constructor](#serviceportuse-new) | constructor | A | Create one endpoint/port/transport usage record. |
| `usesAnyAddress` | getter (`ServicePortUse`) | B | Whether the bind address is the wildcard `'*'`. |
| [`ServicePortConflict` constructor](#serviceportconflict-new) | constructor | A | Create a detected port conflict record. |
| [`ServiceWarning` constructor](#servicewarning-new) | constructor | A | Create a reference-integrity warning record. |
| [`listServicePortUses`](#listserviceportuses) | top-level function | A | Expand every service endpoint into concrete per-port usage records. |
| [`findServicePortConflicts`](#findserviceportconflicts) | top-level function | A | Group port uses and flag overlapping bind addresses on the same device/transport/port. |
| [`buildServiceTopology`](#buildservicetopology) | top-level function | A | Build the full topology graph from services, routes, and devices. |
| [`addNode`](#addnode) (nested in `buildServiceTopology`) | local function | A | Insert or merge a node by id. |
| [`addEdge`](#addedge) (nested in `buildServiceTopology`) | local function | A | Insert a deduplicated edge, or record another route on the one already there. |
| `deviceNodeId` (nested) | local function | B | Format a device node id. |
| `serviceNodeId` (nested) | local function | B | Format a service node id. |
| `endpointNodeId` (nested) | local function | B | Format an endpoint node id. |
| [`addDeviceNode`](#adddevicenode) (nested) | local function | A | Add/merge a local device node. |
| [`addRemoteDeviceNode`](#addremotedevicenode) (nested) | local function | A | Add/merge a remote device node under a route. |
| [`addServiceNode`](#addservicenode) (nested) | local function | A | Add/merge a service node and its device edge. |
| [`addEndpointNode`](#addendpointnode) (nested) | local function | A | Add/merge an endpoint node and its service edge. |
| [`findServiceReferenceWarnings`](#findservicereferencewarnings) | top-level function | A | Find broken/ambiguous service and route references. |
| [`normalizedBindAddress`](#normalizedbindaddress) | top-level function | A | Canonicalize a bind address to `'*'` for any wildcard form. |
| `_bindsOverlap` | top-level function | A | Whether two bind addresses could collide. |
| [`_conflictingPublicTargetRoutes`](#conflictingpublictargetroutes) | top-level function | A | Filter routes down to those in a duplicate-target conflict. |
| [`_publicTargetRoutesConflict`](#publictargetroutesconflict) | top-level function | A | Decide whether two routes sharing a target should warn. |
| [`_sourceEndpointForDuplicateTargetCheck`](#sourceendpointforduplicatetargetcheck) | top-level function | A | Resolve the source endpoint used for target-conflict comparison. |
| [`_endpointPortsOverlap`](#endpointportsoverlap) | top-level function | A | Whether two endpoints' port ranges overlap. |
| [`_preferTopologyRole`](#prefertopologyrole) | top-level function | A | Pick the more specific of two roles when merging nodes. |
| `_isRemoteRole` | top-level function | B | Whether a role is one of the "remote" roles. |
| [`_isRemoteHopService`](#isremotehopservice) | top-level function | A | Whether a hop's service should render as remote. |
| [`serviceAccessLaneForRoute`](#serviceaccesslaneforroute) | top-level function | A | Classify a route's access lane (local/VPN/public): the explicit `accessLane` override first, else method-first inference. |
| `_roleForRelay` | top-level function | B | Map a route's lane to a relay node role. |
| `_endpointForRoute` | top-level function | B | Look up an endpoint by id on a service. |
| [`_portMappingIngressEndpoint`](#portmappingingressendpoint) | top-level function | A | Resolve the ingress endpoint for an FRP/port-forward hop. |
| [`serviceDefaultIngressEndpoint`](#servicedefaultingressendpoint) | top-level function | A | The endpoint a relay receives tunnelled traffic on when a route names none. |
| [`serviceRouteExplicitAccessLane`](#serviceroutexplicitaccesslane) | top-level function | A | Read a route's `accessLane` override. |
| [`serviceRouteExtraJsonWithAccessLane`](#serviceroutextrajsonwithaccesslane) | top-level function | A | Write or remove the `accessLane` override. |
| [`relatedRoutesForNode`](#relatedroutesfornode) | top-level function | A | The routes a topology node takes part in. |
| `matches` (nested in `relatedRoutesForNode`) | local function | B | Decide whether one route belongs to the node. |
| [`ServiceTopologyFilter` constructor](#servicetopologyfilter-new) | constructor | A | Create a topology filter: devices, lanes, search text; the default narrows nothing. |
| `narrowsDevices` | getter (`ServiceTopologyFilter`) | B | Whether the filter narrows the devices. |
| `narrowsLanes` | getter (`ServiceTopologyFilter`) | B | Whether the filter leaves out a lane. |
| `hasQuery` | getter (`ServiceTopologyFilter`) | B | Whether the filter has (non-blank) search text. |
| `activeCount` | getter (`ServiceTopologyFilter`) | B | How many of devices, lanes and search are active, 0 to 3. |
| `isActive` | getter (`ServiceTopologyFilter`) | B | Whether the filter narrows anything. |
| `copyWith` | method (`ServiceTopologyFilter`) | B | Copy with parts replaced; `clearDeviceIds` returns to every device. |
| `==` | operator (`ServiceTopologyFilter`) | B | Compare by value: sets by content, the query as typed. |
| `hashCode` | getter (`ServiceTopologyFilter`) | B | Hash consistently with `==`, order-independent over the sets. |
| `_sameSet` | top-level function | B | Compare two optional sets by content. |
| [`filterServiceTopologyInput`](#filterservicetopologyinput) | top-level function | A | Narrow the services and routes a topology is built from. |
| `onChosenDevice` (nested in `filterServiceTopologyInput`) | local function | B | Whether a service runs on a chosen device. |
| `hit` (nested in `filterServiceTopologyInput`) | local function | B | Whether a text contains the search text. |
| `routeMatches` (nested in `filterServiceTopologyInput`) | local function | B | Whether a route matches the search text. |
| `ServiceTopologyHighlight` constructor | constructor | B | Create a highlight: lit node ids and lit edges. |
| [`serviceTopologyHighlight`](#servicetopologyhighlight) | top-level function | A | Work out which nodes and edges a set of routes lights up. |
| `_isPortMappingHop` | top-level function | B | Whether a hop is an FRP/port-forward-style hop. |
| `_hasRemoteEntry` | top-level function | B | Whether a hop has a remote host/port worth rendering. |
| `_relayNodeId` | top-level function | B | Format a stable id for a relay node. |
| `_remoteEntryNodeId` | top-level function | B | Format a stable id for a remote-entry node. |
| [`_relayLabel`](#relaylabel) | top-level function | A | Compute a relay node's display label. |
| `_remoteEntryLabel` | top-level function | B | Format a remote-entry node's display label. |
| `serviceRouteMethodLabel` | top-level function | B | `ServiceRouteMethod` enum → display label. |
| [`serviceRouteAccessTargets`](#servicerouteaccesstargets) | top-level function | A | Collect a route's deduplicated public access targets. |
| [`addTarget`](#addtarget) (nested in `serviceRouteAccessTargets`) | local function | A | Add one target if non-empty and not a duplicate. |
| [`serviceRouteExtraJsonWithTargets`](#servicerouteextrajsonwithtargets) | top-level function | A | Write grouped targets back into a route's `extraJson`. |
| [`serviceRouteDisplayTarget`](#serviceroutedisplaytarget) | top-level function | A | Pick a route's primary display string. |
| [`serviceRouteGeneratedName`](#serviceroutegeneratedname) | top-level function | A | Generate a route's internal display name. |
| [`serviceRouteChainPreview`](#serviceroutechainpreview) | top-level function | A | Describe a route's whole chain on one line, for the two editors' previews. |
| `withPort` (nested in `serviceRouteChainPreview`) | local function | B | Append an endpoint's port to a name. |
| `serviceRouteTargetsSummary` | top-level function | B | Thin wrapper over `_targetsSummary` for a route. |
| [`_targetsSummary`](#targetssummary) | top-level function | A | Join target labels with a "+N more" truncation. |
| [`compactAccessTargetLabel`](#compactaccesstargetlabel) | top-level function | A | Shorten a URL/target to a compact host[:port][path] label. |
| `_canonicalAccessTarget` | top-level function | B | Lowercase/compact form of a target, for dedup comparison. |

## Documentation

### `const ServiceTopologyNode({...})` <a id="servicetopologynode-new"></a>
- **Kind:** constructor. **Source:** line 58.
- **Purpose:** Create an immutable topology node (device/service/endpoint/relay/remote-entry/
  domain) for the rendered graph.
- **Inputs:** `id`, `kind`, `role`, `label` required; `detail`/`deviceId`/`serviceId`/
  `endpointId`/`lane`/`method` optional; `compact` (default `false`); `routeIds`
  (default `[]`).
- **Returns:** A new `ServiceTopologyNode`. **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:** Constructed throughout `buildServiceTopology`'s nested `add*Node` helpers.
- **Notes:** `routeIds` tracks every route that touches this node, since one node (e.g. a shared
  device) can be reused across multiple routes.

### `ServiceTopologyNode mergeRoute(String routeId)` <a id="mergeroute"></a>
- **Kind:** method of `ServiceTopologyNode`. **Source:** line 78.
- **Purpose:** Attach a route id to this node if not already present.
- **Inputs:** `routeId`. **Returns:** `ServiceTopologyNode`.
- **Side effects:** None (returns a new/same instance; does not mutate).
- **Algorithm:** Return `this` unchanged if `routeIds` already contains `routeId`; otherwise
  delegate to `merge(this, routeId: routeId)`.
- **Usage:** Called by `addNode` when a node is newly created under a specific route.
- **Notes:** None.

### `ServiceTopologyNode merge(ServiceTopologyNode other, {String? routeId})` <a id="merge"></a>
- **Kind:** method of `ServiceTopologyNode`. **Source:** line 88.
- **Purpose:** Combine two node values that share an id (the same device/service/endpoint
  reached via different routes) into one.
- **Inputs:** `other`; optional `routeId` to add.
- **Returns:** A new merged `ServiceTopologyNode`.
- **Side effects:** None.
- **Algorithm:** Union `routeIds`; pick the more specific role via `_preferTopologyRole`; prefer
  `other.detail` only when its role won **and** it has non-empty detail, otherwise keep this
  node's own non-empty detail or fall back to `other.detail`; take the first non-null `lane`/
  `method`; OR the `compact` flags.
- **Usage:** Called by `addNode`'s `nodes.update` merge path whenever a node id is revisited.
- **Notes:** The detail-preference logic exists so a node first seen with generic detail (e.g. a
  service's kind) gets upgraded to more specific detail (e.g. its endpoint summary) once a route
  with a "more remote" role touches it, without losing existing good detail otherwise.

### `const ServiceTopologyEdge({...})` <a id="servicetopologyedge-new"></a>
- **Kind:** constructor. **Source:** line 138.
- **Purpose:** Create an immutable directed edge between two node ids.
- **Inputs:** `from`, `to` required; `label`/`routeId`/`lane`/`method` optional; `routeIds` —
  every route along the edge, empty by default.
- **Returns:** A new `ServiceTopologyEdge`. **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:** Constructed by `addEdge` and `withRoute`.
- **Notes:** `routeId` names only the route that added the edge first; `routeIds` (since 1.5.6)
  names them all, because routes through the same two nodes in the same lane and method share one
  edge, and selection highlighting must light that edge for each of them. Structural
  device-to-service edges have none.

### `const ServiceTopologyGraph({required this.nodes, required this.edges})` <a id="servicetopologygraph-new"></a>
- **Kind:** constructor. **Source:** line 177.
- **Purpose:** Wrap the final sorted node/edge lists as the `buildServiceTopology` result.
- **Inputs:** `nodes`, `edges`. **Returns:** A new `ServiceTopologyGraph`. **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:** Returned by `buildServiceTopology`; consumed by
  [service_topology_layout.md](service_topology_layout.md)'s layout engine.
- **Notes:** None.

### `const ServicePortUse({...})` <a id="serviceportuse-new"></a>
- **Kind:** constructor. **Source:** line 199.
- **Purpose:** Record one concrete `(service, endpoint, transport, port, bindAddress)` usage,
  expanded from a possibly-ranged endpoint.
- **Inputs:** all five fields, required. **Returns:** A new `ServicePortUse`.
  **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:** Constructed by `listServicePortUses`.
- **Notes:** None.

### `const ServicePortConflict({...})` <a id="serviceportconflict-new"></a>
- **Kind:** constructor. **Source:** line 227.
- **Purpose:** Record a detected (or potential) port collision between two or more service uses.
- **Inputs:** `deviceId`, `port`, `transport`, `uses` required; `potential` (default `false`).
- **Returns:** A new `ServicePortConflict`. **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:** Constructed by `findServicePortConflicts`.
- **Notes:** `potential` distinguishes a soft/advisory conflict (all uses bind to a concrete,
  non-wildcard address, so they may not actually collide at runtime) from a harder one — matching
  this repo's documented "port conflict detection is advisory only" rule.

### `const ServiceWarning(this.kind, this.name, {this.detail})` <a id="servicewarning-new"></a>
- **Kind:** constructor. **Source:** line 260.
- **Purpose:** Record one reference-integrity warning for the Services overview.
- **Inputs:** `kind` (`ServiceWarningKind`), `name`, optional `detail`.
- **Returns:** A new `ServiceWarning`. **Side effects:** None.
- **Algorithm:** Plain field assignment (positional constructor).
- **Usage:** Constructed throughout `findServiceReferenceWarnings`.
- **Notes:** None.

### `List<ServicePortUse> listServicePortUses(List<ServiceNode> services)` <a id="listserviceportuses"></a>
- **Kind:** top-level function. **Source:** line 263.
- **Purpose:** Expand every service endpoint's (possibly-ranged) port into individual concrete
  `ServicePortUse` records, one per transport when an endpoint declares `tcpUdp`.
- **Inputs:** `services`. **Returns:** `List<ServicePortUse>`, sorted by device id, then
  transport, then port, then service name (case-insensitive).
- **Side effects:** None.
- **Algorithm:** For each endpoint with a non-null `port`, expand `[port, portEnd ?? port]`
  across each applicable transport (`tcp`+`udp` when the endpoint is `tcpUdp`, else just its own
  transport), normalizing the bind address via `normalizedBindAddress`; sort the result.
- **Usage:** Called by `findServicePortConflicts`.
- **Notes:** None.

### `List<ServicePortConflict> findServicePortConflicts(List<ServiceNode> services)` <a id="findserviceportconflicts"></a>
- **Kind:** top-level function. **Source:** line 308.
- **Purpose:** Group port uses by `(deviceId, transport, port)` and flag groups where at least
  two entries have overlapping bind addresses.
- **Inputs:** `services`. **Returns:** `List<ServicePortConflict>`.
- **Side effects:** None.
- **Algorithm:** Bucket `listServicePortUses` results by key; for buckets with 2+ entries, do a
  pairwise `_bindsOverlap` check to collect the overlapping subset (deduplicated via `toSet`);
  build a `ServicePortConflict` per surviving bucket, marking `potential: true` only when every
  overlapping use has a concrete (non-wildcard) bind address.
- **Usage:** Called by the Services overview to render port-conflict warnings.
- **Notes:** Advisory only, per this repo's documented rule — conflicts never block saves.

### `ServiceTopologyGraph buildServiceTopology({required List<ServiceNode> services, required List<ServiceRoute> routes, required List<Device> devices})` <a id="buildservicetopology"></a>
- **Kind:** top-level function. **Source:** line 356.
- **Purpose:** The core topology-graph builder: turns saved services and access routes into the
  node/edge graph the layout engine renders.
- **Inputs:** `services`, `routes`, `devices`. **Returns:** `ServiceTopologyGraph` (nodes sorted
  by kind then label).
- **Side effects:** None (pure over its inputs).
- **Algorithm:** Build device/service lookup maps. Define local helpers `addNode`/`addEdge`
  (dedup by id/key) and id formatters `deviceNodeId`/`serviceNodeId`/`endpointNodeId`, plus
  `addDeviceNode`/`addRemoteDeviceNode`/`addServiceNode`/`addEndpointNode` (each builds the node
  and wires its edge to its parent). First, add every service (and its device) as a plain local
  node. Then, for each route: add the source service/endpoint chain; walk each hop — FRP/
  port-forward-style hops (`_isPortMappingHop`) render as a remote service+ingress-port pair (or a
  relay+remote-device pair if the hop's service can't be resolved), followed by a remote-entry
  node if the hop has a host/port (`_hasRemoteEntry`); hops that reference a resolvable service
  render as a (possibly remote) service+endpoint node pair; everything else renders as a generic
  relay node via `_relayLabel`/`_roleForRelay`. Finally, add one domain node per access target
  (`serviceRouteAccessTargets`) at the end of the chain. Sort nodes by kind then label before
  returning.
- **Usage:** Called by the Services overview page to build the graph handed to the layout engine
  ([service_topology_layout.md](service_topology_layout.md)).
- **Notes:** This is the single function that encodes every topology-modeling rule described in
  [../../../../features/services-topology.md](../../../../features/services-topology.md) — the
  FRP ingress/public port distinction and the local/remote role assignment live here, not in the
  layout or rendering code. The former layout-column hint it used to write for same-device public
  reverse proxies was never read by the layout after v0.5.9 and was removed in 1.5.6.

### `void addNode(ServiceTopologyNode node, {String? routeId})` (nested) <a id="addnode"></a>
- **Kind:** local function inside `buildServiceTopology`. **Source:** line 371.
- **Purpose:** Insert a node by id, merging with any existing node of the same id.
- **Inputs:** `node`, optional `routeId`. **Returns:** `void`.
- **Side effects:** Mutates the enclosing `nodes` map.
- **Algorithm:** `nodes.update(node.id, (existing) => existing.merge(node, routeId: routeId),
  ifAbsent: () => routeId == null ? node : node.mergeRoute(routeId))`.
- **Usage:** Called by every `add*Node` helper below.
- **Notes:** None.

### `void addEdge(String from, String to, {String? label, String? routeId})` (nested) <a id="addedge"></a>
- **Kind:** local function inside `buildServiceTopology`. **Source:** line 389.
- **Purpose:** Insert a deduplicated edge between two already-added nodes.
- **Inputs:** `from`, `to`; optional `label`/`routeId`. **Returns:** `void`.
- **Side effects:** Mutates the enclosing `edges` map.
- **Algorithm:** No-op if `from == to` or either endpoint isn't in `nodes` yet. Resolve the
  route's access lane and first hop method (if any); build a composite dedup key from
  `from/to/label/lane/method`. An edge already under the key gets the route appended to its
  `routeIds` (`withRoute`, replacing the map entry in place); otherwise a new
  `ServiceTopologyEdge` is stored with `routeIds: [routeId]` (or none).
- **Usage:** Called throughout `buildServiceTopology`'s route-walking loop.
- **Notes:** The composite key (not just `from->to`) is what allows multiple distinct edges
  between the same two nodes when they differ by lane or method (e.g. one route via public FRP
  and another via VPN between the same two services). Replacing an entry keeps its position in
  the map, so edge order — and the layout — is unchanged by the route list.

### `String addDeviceNode(String deviceId)` (nested) <a id="adddevicenode"></a>
- **Kind:** local function inside `buildServiceTopology`. **Source:** line 446.
- **Purpose:** Add (or reuse) a local-device node.
- **Inputs:** `deviceId`. **Returns:** the node id.
- **Side effects:** Calls `addNode`.
- **Algorithm:** Look up the device (falling back to the raw id as label if unresolved); build a
  `localDevice`-role node keyed by `deviceNodeId(deviceId)`.
- **Usage:** Called by `addServiceNode` for a service's own device.
- **Notes:** None.

### `String addRemoteDeviceNode(String deviceId, {String? routeId})` (nested) <a id="addremotedevicenode"></a>
- **Kind:** local function inside `buildServiceTopology`. **Source:** line 467.
- **Purpose:** Add (or reuse) a remote-device node, tagged with a route id.
- **Inputs:** `deviceId`; optional `routeId`. **Returns:** the node id.
- **Side effects:** Calls `addNode`.
- **Algorithm:** Same as `addDeviceNode` but with role `remoteDevice` and passing `routeId`
  through so `merge`'s role-preference logic can upgrade a previously-local device node if it's
  later reached remotely via another route.
- **Usage:** Called for hop-referenced devices on a different physical device than the route's
  source.
- **Notes:** None.

### `String addServiceNode(ServiceNode service, {bool remote = false, String? routeId, String? detailOverride, ServiceRouteMethod? method})` (nested) <a id="addservicenode"></a>
- **Kind:** local function inside `buildServiceTopology`. **Source:** line 492.
- **Purpose:** Add (or reuse) a service node, its owning device node, and the edge between them.
- **Inputs:** `service`; `remote` (default `false`) — a hop service on the remote side; optional
  `routeId` (the route adding it), `detailOverride` (replaces the default detail) and `method`
  (the hop method that made the service a relay). **Returns:** the node id.
- **Side effects:** Calls `addDeviceNode`/`addRemoteDeviceNode`, `addNode`, `addEdge`.
- **Algorithm:** Resolve the device node (remote or local per `remote`); build the service node
  (role `remoteService` or `localService`) with `detailOverride` or a default (the service's kind,
  or up to 3 endpoint port texts joined) and `method`; wire the device→service edge (tagged with
  `routeId` only when remote).
- **Usage:** Called once per service up front (as a plain local node) and again per route hop
  that references a service. A port-mapping hop's service is added with `remote: true`,
  `detailOverride` set to the English "`<serviceRouteMethodLabel(method)>` service" (or the raw
  hop-type name when the hop has no method) and `method: hop.method`.
- **Notes:** The recorded `method` lets the canvas card localize that English detail
  ([`_nodeSubtitle`](../views/service_topology_widgets.md#nodesubtitle)) without the builder
  touching localization.

### `String addEndpointNode(ServiceNode service, ServiceEndpoint endpoint, {bool remote = false, String? routeId})` (nested) <a id="addendpointnode"></a>
- **Kind:** local function inside `buildServiceTopology`. **Source:** line 539.
- **Purpose:** Add (or reuse) an endpoint node and wire it to its parent service node.
- **Inputs:** `service`, `endpoint`; `remote`; optional `routeId`. **Returns:** the node id.
- **Side effects:** Calls `addNode`, `addEdge`.
- **Algorithm:** Build a `compact: true` node whose label is the endpoint's trimmed label or its
  protocol name, and whose detail joins bind address/port text/path (skipping empty/`'-'` parts);
  wire the service→endpoint edge.
- **Usage:** Called for a route's source endpoint and for FRP-style hops' resolved ingress
  endpoint.
- **Notes:** Always marked `compact: true`, distinguishing endpoint nodes visually from full
  device/service nodes in the layout (see
  [service_topology_layout.md](service_topology_layout.md)).

### `List<ServiceWarning> findServiceReferenceWarnings({required List<ServiceNode> services, required List<ServiceRoute> routes, required List<Device> devices, required List<Network> networks})` <a id="findservicereferencewarnings"></a>
- **Kind:** top-level function. **Source:** line 751.
- **Purpose:** Scan saved services and routes for broken or ambiguous references, for display in
  the Services overview.
- **Inputs:** `services`, `routes`, `devices`, `networks`. **Returns:** `List<ServiceWarning>`.
- **Side effects:** None.
- **Algorithm:** Per service: warn on a missing device (`missingDevice`) or a retired/sold device
  (`inactiveDevice`); per endpoint, warn if its `networkId` doesn't resolve (`missingEndpointNetwork`).
  Per route: warn on a missing source service/endpoint, an empty hop list (`emptyRoute`), or a
  `public`-access route with no resolvable access targets (`publicRouteMissingUrl`); per hop, warn
  on a missing hop service/endpoint/device. Finally, group routes by their canonical access
  targets and, for each group with more than one *conflicting* route (per
  `_conflictingPublicTargetRoutes`), emit one `duplicateFinalUrl` warning listing the conflicting
  route names.
- **Usage:** Called by the Services overview page to render its warnings list.
- **Notes:** Duplicate-target warnings are narrowed to genuinely ambiguous cases — same-device
  routes with clearly different source ports do not warn, per
  `_publicTargetRoutesConflict`/`_endpointPortsOverlap`.

### `String normalizedBindAddress(String? bindAddress)` <a id="normalizedbindaddress"></a>
- **Kind:** top-level function. **Source:** line 863.
- **Purpose:** Canonicalize any wildcard-meaning bind address form to the single sentinel `'*'`.
- **Inputs:** `bindAddress` (nullable). **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** Trim; treat `null`/empty/`'0.0.0.0'`/`'::'` as `'*'`; otherwise return the
  trimmed value unchanged.
- **Usage:** Called by `listServicePortUses` before comparing bind addresses across services.
- **Notes:** Without this normalization, `0.0.0.0` and an unset bind address would not be
  recognized as the same "listens on everything" case for conflict detection.

### `List<ServiceRoute> _conflictingPublicTargetRoutes(List<ServiceRoute> routes, Map<String, ServiceNode> serviceMap)` <a id="conflictingpublictargetroutes"></a>
- **Kind:** top-level function. **Source:** line 878.
- **Purpose:** Given a set of routes sharing one canonical access target, return only the subset
  actually in conflict with each other.
- **Inputs:** `routes`, `serviceMap`. **Returns:** the conflicting subset, original order.
- **Side effects:** None.
- **Algorithm:** Pairwise `_publicTargetRoutesConflict` check; collect any route appearing in at
  least one conflicting pair into a set, then filter the original list by that set (preserving
  order).
- **Usage:** Called by `findServiceReferenceWarnings`.
- **Notes:** None.

### `bool _publicTargetRoutesConflict(ServiceRoute a, ServiceRoute b, Map<String, ServiceNode> serviceMap)` <a id="publictargetroutesconflict"></a>
- **Kind:** top-level function. **Source:** line 902.
- **Purpose:** Decide whether two routes sharing a public target are ambiguous enough to warn
  about.
- **Inputs:** `a`, `b`, `serviceMap`. **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Unknown source service on either side, or sources on different devices → treat
  as conflicting (`true`, conservative). Otherwise resolve each side's effective source endpoint
  (`_sourceEndpointForDuplicateTargetCheck`) — unknown endpoint on either side → conflicting.
  Otherwise conflict iff the two endpoints' port ranges overlap (`_endpointPortsOverlap`).
- **Usage:** Called by `_conflictingPublicTargetRoutes`.
- **Notes:** "Same device, clearly different source ports" is the one case that does *not* warn
  — matching the comment on `findServiceReferenceWarnings`'s doc block.

### `ServiceEndpoint? _sourceEndpointForDuplicateTargetCheck(ServiceNode service, ServiceRoute route)` <a id="sourceendpointforduplicatetargetcheck"></a>
- **Kind:** top-level function. **Source:** line 923.
- **Purpose:** Resolve the endpoint to use when comparing two routes' source ports for the
  duplicate-target check.
- **Inputs:** `service`, `route`. **Returns:** `ServiceEndpoint?`.
- **Side effects:** None.
- **Algorithm:** Use the route's explicit `sourceEndpointId` if it resolves; otherwise, if no
  endpoint was specified **and** the service has exactly one endpoint, infer that single endpoint;
  otherwise `null` (ambiguous).
- **Usage:** Called by `_publicTargetRoutesConflict`.
- **Notes:** A service with multiple endpoints and no explicit source endpoint is treated as
  ambiguous rather than guessing.

### `bool _endpointPortsOverlap(ServiceEndpoint a, ServiceEndpoint b)` <a id="endpointportsoverlap"></a>
- **Kind:** top-level function. **Source:** line 940.
- **Purpose:** Test whether two endpoints' (possibly-ranged) port intervals overlap.
- **Inputs:** `a`, `b`. **Returns:** `bool` — `true` (conservatively) if either side has no port
  at all.
- **Side effects:** None.
- **Algorithm:** Missing `port` on either side → `true`. Otherwise compute each side's
  `[start, end]` interval (`portEnd` if set and `>= start`, else just `start`) and test
  `max(aStart,bStart) <= min(aEnd,bEnd)`.
- **Usage:** Called by `_publicTargetRoutesConflict`.
- **Notes:** None.

### `ServiceTopologyNodeRole _preferTopologyRole(ServiceTopologyNodeRole current, ServiceTopologyNodeRole incoming)` <a id="prefertopologyrole"></a>
- **Kind:** top-level function. **Source:** line 951.
- **Purpose:** Pick the more informative of two roles when merging two node observations for the
  same id.
- **Inputs:** `current`, `incoming`. **Returns:** `ServiceTopologyNodeRole`.
- **Side effects:** None.
- **Algorithm:** Equal roles → keep either; if `incoming` is a "remote" role
  (`_isRemoteRole`) it wins; otherwise keep `current`.
- **Usage:** Called by `ServiceTopologyNode.merge`.
- **Notes:** Encodes the rule "once a shared node is known to be reached remotely via any route,
  treat it as remote everywhere," rather than the first-seen role winning arbitrarily.

### `bool _isRemoteHopService({required ServiceNode source, required ServiceNode hopService, required Map<String, Device> deviceMap})` <a id="isremotehopservice"></a>
- **Kind:** top-level function. **Source:** line 966.
- **Purpose:** Decide whether a hop's referenced service should be rendered as remote.
- **Inputs:** `source` (route's source service), `hopService`, `deviceMap`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Same device as the source → not remote. Otherwise remote iff the hop's device
  category is `vps` — matching this repo's documented VPS/remote-device shared-branch modeling
  rule for FRP-style paths.
- **Usage:** Called by `buildServiceTopology`'s hop-walking loop.
- **Notes:** None.

### `ServiceAccessLane serviceAccessLaneForRoute(ServiceRoute route)` <a id="serviceaccesslaneforroute"></a>
- **Kind:** top-level function. **Source:** line 985.
- **Purpose:** Classify a route into one of three access lanes (local/VPN/public) for topology
  rendering and edge grouping.
- **Inputs:** `route`. **Returns:** `ServiceAccessLane`.
- **Side effects:** None.
- **Algorithm:** A valid `extraJson['accessLane']` (`serviceRouteExplicitAccessLane`) wins.
  Otherwise, unchanged since before 1.5.6: if any hop uses a "public-style" method (FRP, router
  port-forward, Caddy, Nginx, Traefik, Cloudflare Tunnel, Pangolin) → `public`. Else if any hop
  uses Tailscale Funnel, or the route's `accessLevel` is `vpn` → `vpn`. Else if `accessLevel` is
  `public` or `authenticated` → `public`. Otherwise → `local`.
- **Usage:** Called throughout `buildServiceTopology` and by `_roleForRelay` to determine edge/
  node coloring and grouping in the rendered topology.
- **Notes:** Without an override, method-based classification takes priority over the route's
  own `accessLevel` field — a route marked `lan` but routed through Caddy is still classified
  `public`. The guided access-path page therefore always writes the override, and the advanced
  editor's lane dropdown can write or clear it. Legacy routes are never reinterpreted: an absent
  override means exactly the old inference.

### `ServiceEndpoint? _portMappingIngressEndpoint(ServiceNode service, ServiceRouteHop hop)` <a id="portmappingingressendpoint"></a>
- **Kind:** top-level function. **Source:** line 1036.
- **Purpose:** Resolve which endpoint on the hop's service represents the FRP/port-forward
  ingress port.
- **Inputs:** `service`, `hop`. **Returns:** `ServiceEndpoint?`.
- **Side effects:** None.
- **Algorithm:** Use the hop's explicit `endpointId` if it resolves (`_endpointForRoute`);
  otherwise fall back to `serviceDefaultIngressEndpoint` — the service's primary endpoint, or its
  first endpoint if none is marked primary.
- **Usage:** Called by `buildServiceTopology`'s FRP/port-forward hop branch.
- **Notes:** Implements the FRP ingress-vs-public-port modeling rule from
  [../../../../features/services-topology.md](../../../../features/services-topology.md): the
  ingress endpoint is what the source connects to, distinct from the separate public remote-entry
  port rendered via `_hasRemoteEntry`/`addRemoteDeviceNode`.

### `ServiceEndpoint? serviceDefaultIngressEndpoint(ServiceNode service)` <a id="servicedefaultingressendpoint"></a>
- **Kind:** top-level function. **Source:** line 1052.
- **Purpose:** Pick the endpoint a relay service receives tunnelled traffic on when a route does
  not name one.
- **Inputs:** `service`. **Returns:** The primary endpoint, else the first, else null.
- **Side effects:** None.
- **Algorithm:** `endpoints.where(isPrimary).firstOrNull ?? endpoints.firstOrNull`.
- **Usage:** `_portMappingIngressEndpoint`'s fallback, and the guided FRP pattern's default
  ingress chip.
- **Notes:** Sharing one function is what guarantees that an FRP draft the user does not touch
  records the ingress the topology already inferred, so saving it does not move any edge.

### `ServiceAccessLane? serviceRouteExplicitAccessLane(ServiceRoute route)` <a id="serviceroutexplicitaccesslane"></a>
- **Kind:** top-level function. **Source:** line 1063.
- **Purpose:** Read a route's explicit access-lane override.
- **Inputs:** `route`. **Returns:** The lane named by `extraJson['accessLane']`, or null when the
  key is absent, not a string, or not one of `local` / `vpn` / `public`.
- **Side effects:** None.
- **Algorithm:** Match the string against `ServiceAccessLane.values` by name.
- **Usage:** `serviceAccessLaneForRoute`, and the guided flow's reachability check.
- **Notes:** Unknown values are ignored rather than rejected, so a newer build's value cannot
  break an older reader.

### `Map<String, dynamic> serviceRouteExtraJsonWithAccessLane(Map<String, dynamic> extraJson, ServiceAccessLane? lane)` <a id="serviceroutextrajsonwithaccesslane"></a>
- **Kind:** top-level function. **Source:** line 1078.
- **Purpose:** Write or remove the access-lane override in a route's `extraJson`.
- **Inputs:** `extraJson` — the route's existing map; `lane` — the lane to pin, or null to
  return the route to inference.
- **Returns:** A new map. **Side effects:** None (the input is not modified).
- **Algorithm:** Copy, remove `accessLane`, then set it to `lane.name` when `lane` is non-null.
- **Usage:** `ServiceAccessDraft.toRoute` (always, from the reachability) and the advanced
  editor's lane dropdown (Auto removes the key).
- **Notes:** Every other key, known or unknown, is carried over — the same contract as
  `serviceRouteExtraJsonWithTargets`.

### `List<ServiceRoute> relatedRoutesForNode(ServiceTopologyNode node, List<ServiceRoute> routes, {List<ServiceNode> services = const []})` <a id="relatedroutesfornode"></a>
- **Kind:** top-level function. **Source:** line 1100.
- **Purpose:** List the routes a topology node takes part in, for the node details and for
  selection highlighting.
- **Inputs:** `node`; `routes` — the routes the graph was built from; `services` — optional, lets
  a device node find the services it hosts.
- **Returns:** The matching routes in their original order. **Side effects:** None.
- **Algorithm:** Every node matches the routes recorded in its `routeIds`. A service node also
  matches routes it is the source of or a hop of. A device node also matches routes whose source
  or hop service runs on it, or whose hop names it as `deviceId`. Endpoint chips, relays, remote
  entries and domains match their `routeIds` only.
- **Usage:** The topology page's `_selectionIn` (the details list and the highlight) and
  `_showDetailsSheet`.
- **Notes:** Replaces the inline rule the node-details sheet used before 1.5.6, which compared
  `hop.serviceId == node.serviceId` even when both were null — so tapping a domain listed every
  route with a free-form hop. A missing id never matches a missing reference now.

### `const ServiceTopologyFilter({Set<String>? deviceIds, Set<ServiceAccessLane> lanes = {...all}, String query = ''})` <a id="servicetopologyfilter-new"></a>
- **Kind:** constructor. **Source:** line 1170.
- **Purpose:** Create what the full-screen topology is narrowed to.
- **Inputs:** `deviceIds` — the devices whose services and routes show, null for every device;
  `lanes` — the access lanes whose routes show, all three by default; `query` — search text,
  compared case-insensitively.
- **Returns:** A new `ServiceTopologyFilter`. **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:** The topology page's `_filter` (the default instance narrows nothing) and its filter
  sheet, through `copyWith`.
- **Notes:** Compared by value (`==`/`hashCode`), so the page can memoize the graph it builds for
  a filter. `activeCount` feeds the app-bar badge: devices, lanes and search count once each, and
  whitespace alone is no search.

### `({List<ServiceNode> services, List<ServiceRoute> routes}) filterServiceTopologyInput({required List<ServiceNode> services, required List<ServiceRoute> routes, required ServiceTopologyFilter filter})` <a id="filterservicetopologyinput"></a>
- **Kind:** top-level function. **Source:** line 1281.
- **Purpose:** Narrow the services and routes a topology is built from — filters produce a
  subgraph, never a paint-time mask.
- **Inputs:** `services`, `routes` — the whole inventory; `filter`.
- **Returns:** The services and routes to hand to `buildServiceTopology`; the inputs themselves
  when the filter narrows nothing.
- **Side effects:** None.
- **Algorithm:** 1. A route stays when its source service runs on a chosen device, its lane
  (`serviceAccessLaneForRoute`) is chosen, and the search text is found in its source or a hop
  service's name, a hop's label or host, or one of its targets. 2. A service stays when a kept
  route runs through it (as source or hop), or when it runs on a chosen device and neither lanes
  nor search narrow anything — or the search text is in its own name.
- **Usage:** The topology page's `_visible`.
- **Notes:** Hop services on devices that were not chosen stay: `buildServiceTopology` only draws
  a hop's service — an FRP server's ingress chip, say — when the service is in the list it is
  given, so dropping it would change the route's shape. Lanes and search are about routes, so
  they hide the services no kept route touches; the device filter alone keeps a chosen device's
  route-less services.

### `ServiceTopologyHighlight serviceTopologyHighlight(ServiceTopologyGraph graph, List<ServiceRoute> routes, {String? selectedNodeId})` <a id="servicetopologyhighlight"></a>
- **Kind:** top-level function. **Source:** line 1378.
- **Purpose:** Work out which nodes and edges a set of routes lights up on the topology.
- **Inputs:** `graph`; `routes` — the highlighted routes, e.g. from `relatedRoutesForNode`, or
  one of them; `selectedNodeId` — lit even when it takes part in none of them.
- **Returns:** `ServiceTopologyHighlight` — lit node ids and lit edges (the graph's own
  instances).
- **Side effects:** None.
- **Algorithm:** 1. A node is lit when one of its `routeIds` is highlighted, when it is the
  selected node, or when it is a service node whose service is a highlighted route's source or
  hop. 2. A device node is lit when it hosts a lit service, endpoint, relay or entry. 3. An edge
  is lit when one of its `routeIds` is highlighted, and a structural edge (no routes) when both
  its ends are lit.
- **Usage:** The topology page's `_selectionIn`; the view dims unlit node cards and the edge
  painter fades unlit edges.
- **Notes:** The source-service rule exists because the builder records routes on hops, chips
  and targets but not on a route's source service node. Edge identity is enough for the painter:
  `ServiceTopologyEdge` has no value equality, and the highlight is always computed on the graph
  being drawn.

### `String _relayLabel(ServiceRouteHop hop, Map<String, ServiceNode> services)` <a id="relaylabel"></a>
- **Kind:** top-level function. **Source:** line 1446.
- **Purpose:** Compute the display label for a generic (non-service, non-port-mapping) relay
  node.
- **Inputs:** `hop`, `services`. **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** Prefer the hop's referenced service's name; else its own trimmed label; else,
  for a known `method`, `serviceRouteMethodLabel(method)`; else switch on `hop.type` to a fixed
  English label per type (Reverse Proxy/Tunnel/Port Forward/Public Endpoint/Internal Endpoint/
  DNS/Origin), with the `manual` case falling back to `_remoteEntryLabel` when a host is present,
  else `'Manual'`.
- **Usage:** Called by `buildServiceTopology`'s generic-relay branch.
- **Notes:** None.

### `List<String> serviceRouteAccessTargets(ServiceRoute route)` <a id="servicerouteaccesstargets"></a>
- **Kind:** top-level function. **Source:** line 1486.
- **Purpose:** Collect a route's deduplicated public access targets: its `finalUrl` plus any
  grouped targets stored in `extraJson.publicTargets`.
- **Inputs:** `route`. **Returns:** `List<String>`, original-encounter order, first occurrence
  wins on duplicates (by canonical form).
- **Side effects:** None.
- **Algorithm:** Define a local `addTarget` that trims, rejects empty strings, and skips values
  already present by canonical form (`_canonicalAccessTarget`); add `route.finalUrl`, then every
  entry of `extraJson[serviceRoutePublicTargetsKey]` if it's an `Iterable`, or the raw value
  itself otherwise.
- **Usage:** Called by `buildServiceTopology` (domain nodes), `findServiceReferenceWarnings`,
  `serviceRouteDisplayTarget`, `serviceRouteTargetsSummary`, `serviceRouteGeneratedName`, and
  `import_export_service.dart`'s Markdown export.
- **Notes:** `finalUrl` always appears first (or alone) in the result, matching this repo's
  documented compatibility rule that `finalUrl` remains "the first target for compatibility."

### `void addTarget(Object? value)` (nested) <a id="addtarget"></a>
- **Kind:** local function inside `serviceRouteAccessTargets`. **Source:** line 1494.
- **Purpose:** Add one candidate target to the enclosing `targets` list if it's a non-empty,
  non-duplicate string.
- **Inputs:** `value` (untyped — tolerates non-string JSON values). **Returns:** `void`.
- **Side effects:** Mutates the enclosing `targets` list.
- **Algorithm:** Reject non-`String`/empty-after-trim values; compute the canonical form and
  reject if any existing target already canonicalizes the same; otherwise append the (untrimmed
  form is not re-added — actually the trimmed) target.
- **Usage:** Called for `route.finalUrl` and for each entry in `extraJson.publicTargets`.
- **Notes:** A second `/// Purpose:` comment appears above the *call* `addTarget(route.finalUrl);`
  a few lines below this declaration — that one documents the call site, not a second
  declaration, and is not counted in this page's Declarations table (see the row-count note at
  the top of this page).

### `Map<String, dynamic> serviceRouteExtraJsonWithTargets(Map<String, dynamic> extraJson, List<String> targets)` <a id="servicerouteextrajsonwithtargets"></a>
- **Kind:** top-level function. **Source:** line 1522.
- **Purpose:** Write a route's grouped extra access targets back into its `extraJson`, ready for
  persistence.
- **Inputs:** `extraJson` (existing map), `targets`. **Returns:** a new
  `Map<String, dynamic>`.
- **Side effects:** None (returns a copy).
- **Algorithm:** Copy `extraJson`, remove any existing `publicTargets` key, then re-add it only
  when `targets.length > 1` (a single target is fully represented by `finalUrl` alone and needs
  no grouped-targets entry).
- **Usage:** Called from the route editor when saving grouped public targets.
- **Notes:** None.

### `String serviceRouteDisplayTarget(ServiceRoute route)` <a id="serviceroutedisplaytarget"></a>
- **Kind:** top-level function. **Source:** line 1534.
- **Purpose:** Pick the single string used to display a route's primary target (e.g. as a
  Markdown section heading, per `import_export_service.md`).
- **Inputs:** `route`. **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** No targets → `route.name`. One target → that target verbatim. Multiple → the
  first target plus a `'+N'` suffix for the remainder.
- **Usage:** Called by `import_export_service.dart`'s Markdown export (see
  [../../../shared/services/import_export_service.md](../../../shared/services/import_export_service.md))
  and by the route list UI.
- **Notes:** None.

### `String serviceRouteGeneratedName({required String sourceName, required List<ServiceRouteHop> hops, required List<String> targets})` <a id="serviceroutegeneratedname"></a>
- **Kind:** top-level function. **Source:** line 1541.
- **Purpose:** Generate the route's internal display name (`"<source> via <method> - <target>"`)
  used when the user hasn't written a custom description.
- **Inputs:** `sourceName`, `hops`, `targets`. **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** Determine the "via" phrase from the first hop's method label, else its own
  label, else its type name, defaulting to `'Access'` with no hops. Determine a target summary
  from `_targetsSummary(targets, maxItems: 1)`, or the first hop's remote-entry label if there
  are no targets but a remote entry exists. Join `sourceName`, `'via <phrase>'`, and
  `'- <target>'` (only when present) with spaces.
- **Usage:** Called by the route editor to auto-generate a route's name.
- **Notes:** Per this repo's documented convention, route names are internally generated —
  user-facing route descriptions belong in `notes`, not this generated name.

### `String serviceRouteChainPreview(ServiceRoute route, {required List<ServiceNode> services, List<Device> devices = const [], String Function(ServiceRouteHop hop)? hopFallback})` <a id="serviceroutechainpreview"></a>
- **Kind:** top-level function. **Source:** line 1580.
- **Purpose:** Describe a route's whole chain on one line.
- **Inputs:** `route`; `services`; `devices` — optional, names the device of a hop service that
  runs somewhere other than the source; `hopFallback` — names a hop that has neither a service
  nor a label of its own.
- **Returns:** The steps joined with `' -> '`, or `'-'` when there are none.
- **Side effects:** None.
- **Algorithm:** The source service with its endpoint's port; then per hop: its service with the
  endpoint's port — for a port-mapping hop the ingress `_portMappingIngressEndpoint` picks, so the
  preview matches the topology — and `(device)` when that service runs elsewhere; else the hop's
  label; else `hopFallback` (default: the method label, else the raw type name). A label equal to
  the hop method's generated English label counts as no label, so a caller can localize it. A
  port mapping's public `host:port` follows as its own step; the access targets close the chain.
- **Usage:** The guided access-path page's preview card and the advanced route editor's
  `_routePreview`, both passing `serviceHopFallbackLabel`.
- **Notes:** Replaced the advanced editor's inline preview in 1.5.6 so both editors describe a
  route in the same words.

### `String _targetsSummary(List<String> targets, {int maxItems = 3})` <a id="targetssummary"></a>
- **Kind:** top-level function. **Source:** line 1638.
- **Purpose:** Join a list of access targets into a compact, truncated summary string.
- **Inputs:** `targets`; `maxItems` (default 3). **Returns:** `String` — empty if `targets` is
  empty.
- **Side effects:** None.
- **Algorithm:** Map each target through `compactAccessTargetLabel`; join the first `maxItems`
  with `', '`; if more remain, append `' +<remaining count>'`.
- **Usage:** Called by `serviceRouteTargetsSummary` and `serviceRouteGeneratedName`.
- **Notes:** None.

### `String compactAccessTargetLabel(String target)` <a id="compactaccesstargetlabel"></a>
- **Kind:** top-level function. **Source:** line 1646.
- **Purpose:** Shorten a URL-like access target to a compact `host[:port][path]` label for
  display, or return it unchanged if it isn't a parseable absolute URL.
- **Inputs:** `target`. **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** `Uri.tryParse`; if it has both a scheme and a non-empty host, render
  `host[:port][path]` (path omitted if empty or just `'/'`); otherwise return the trimmed input
  verbatim.
- **Usage:** Called by `buildServiceTopology` (domain node labels), `_targetsSummary`, and
  `import_export_service.dart`'s route-target rendering.
- **Notes:** None.
