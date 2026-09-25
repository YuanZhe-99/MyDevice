# lib/features/services/services/service_access_patterns.dart

Pure-Dart model behind the guided **Add access path** flow described in
[Services and Topology](../../../../features/services-topology.md#access-patterns). It names
the common self-hosting setups as `ServiceAccessPattern`s, keeps the form state in an immutable
`ServiceAccessDraft`, turns a draft into exactly one `ServiceRoute` whose hops
[service_analysis.md](service_analysis.md)'s `buildServiceTopology` already renders, and reads
a saved route back only when that round trip is lossless. Validation (blocking issues) and
advisory warnings live here too, so the page stays a thin form and everything is testable
without widgets (`test/service_access_patterns_test.dart`).

Nothing here is persisted as a new field: a pattern is re-detected from the hops every time a
route opens. The only persisted addition of 1.5.6 is the route's `extraJson['accessLane']`,
written through `serviceRouteExtraJsonWithAccessLane` (see
[Data Formats](../../../../data-formats.md#extrajson-unknown-field-preservation)).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `fixedMethod` | getter (`ServiceAccessPattern`) | B | The route method the pattern's access hop records; null for the reverse proxy, whose method comes from the proxy service. |
| [`allowsProxyPrefix`](#allowsproxyprefix) | getter (`ServiceAccessPattern`) | A | Whether the "through a reverse proxy first" hop is offered. |
| `requiresTargets` | getter (`ServiceAccessPattern`) | B | Whether a saved route needs at least one URL or domain (reverse proxy and the three tunnels). |
| `requiresPublicPort` | getter (`ServiceAccessPattern`) | B | Whether the pattern records a required public entry port (FRP, router port forward). |
| `usesRelayService` | getter (`ServiceAccessPattern`) | B | Whether the access hop can reference a relay service. |
| `requiresRelayService` | getter (`ServiceAccessPattern`) | B | Whether the relay service is mandatory (FRP only). |
| `defaultReachability` | getter (`ServiceAccessPattern`) | B | LAN for direct access, public for everything else. |
| [`accessLevel`](#accesslevel) | getter (`ServiceReachability`) | A | The route access level a reachability saves. |
| [`lane`](#lane) | getter (`ServiceReachability`) | A | The topology lane a reachability pins. |
| [`ServiceAccessDraft` constructor](#serviceaccessdraft-new) | constructor | A | Create a draft; defaults to a direct LAN path. |
| `usesProxyPrefix` | getter (`ServiceAccessDraft`) | B | `viaProxy` when the pattern allows the prefix. |
| `needsProxy` | getter (`ServiceAccessDraft`) | B | Whether the draft needs a proxy service (reverse-proxy pattern or prefix). |
| [`copyWith`](#copywith) | method (`ServiceAccessDraft`) | A | Replace or clear fields; identity metadata carries over. |
| [`toRoute`](#toroute) | method (`ServiceAccessDraft`) | A | Build the one `ServiceRoute` the draft describes. |
| [`_proxyHop`](#proxyhop) | method (`ServiceAccessDraft`) | A | Build the reverse-proxy hop. |
| [`_accessHop`](#accesshop) | method (`ServiceAccessDraft`) | A | Build the pattern's own hop. |
| [`fromRoute`](#fromroute) | static method (`ServiceAccessDraft`) | A | Read a saved route back into a draft when the round trip is lossless. |
| [`forNode`](#fornode) | static method (`ServiceAccessDraft`) | A | The draft a topology node's "add access path" action starts from. |
| `relayDraft` (nested in `forNode`) | local function | B | The relay draft for a relay service, preferring a given FRP ingress. |
| [`operator ==`](#equals) | operator (`ServiceAccessDraft`) | A | Compare drafts by form content. |
| `hashCode` | getter (`ServiceAccessDraft`) | B | Hash of the compared fields; `extraJson` contributes its key count. |
| `toString` | method (`ServiceAccessDraft`) | B | Diagnostic text for test failures. |
| [`detectServiceAccessPattern`](#detectserviceaccesspattern) | top-level function | A | Name the pattern a saved route follows, or null. |
| [`serviceReachabilityForRoute`](#servicereachabilityforroute) | top-level function | A | Read a route's reachability from its access level and lane override. |
| [`serviceAccessDraftIssues`](#serviceaccessdraftissues) | top-level function | A | List the blocking problems of a draft. |
| `present` (nested in `serviceAccessDraftIssues`) | local function | B | Whether an id names an existing service. |
| [`serviceAccessDraftWarnings`](#serviceaccessdraftwarnings) | top-level function | A | List the advisory FRP findings of a draft. |
| [`serviceProxyMethodFor`](#serviceproxymethodfor) | top-level function | A | Caddy / Nginx / Traefik / custom for a proxy service. |
| `isReverseProxyLikeService` | top-level function | B | Kind `reverseProxy` or a known proxy template or name. |
| [`isFrpLikeService`](#isfrplikeservice) | top-level function | A | The FRP relay heuristic, moved here from the removed quick access dialog. |
| [`serviceRelayPatternFor`](#servicerelaypatternfor) | top-level function | A | FRP or Pangolin for a named relay service on a VPS, else null. |
| [`serviceRouteOpensGuided`](#serviceroutesopensguided) | top-level function | A | Whether a saved route opens in the guided page or the advanced editor. |
| [`serviceAccessProxySuggestions`](#serviceaccessproxysuggestions) | top-level function | A | Proxy-like services to suggest, the source's machine first. |
| [`serviceAccessRelaySuggestions`](#serviceaccessrelaysuggestions) | top-level function | A | Relay services to suggest for a pattern, VPS devices first. |
| `named` (nested in `serviceAccessRelaySuggestions`) | local function | B | Whether a service's name, template or icon names the product. |
| `serviceAccessRelayTemplateId` | top-level function | B | The template "Create relay service…" starts from: `frp`, `pangolin`, `cloudflare-tunnel`, `tailscale`. |
| `serviceAccessRouterCandidates` | top-level function | B | Devices for the router picker, routers first, then by name. |
| [`suggestedDirectTarget`](#suggesteddirecttarget) | top-level function | A | The address a direct access path opens, from the device's assignments. |
| `hasAddress` (nested in `suggestedDirectTarget`) | local function | B | Whether an assignment records an IP address or a host name. |
| `matches` (nested in `suggestedDirectTarget`) | local function | B | Whether an assignment's network suits the reachability. |
| [`suggestedPublicHost`](#suggestedpublichost) | top-level function | A | The FRP public host from the relay device's only assignment. |
| `_isProxyHop` | top-level function | B | Whether a hop can be the reverse-proxy prefix. |
| [`_patternForHop`](#patternforhop) | top-level function | A | Classify a route's last hop into a pattern. |
| [`_sameAccessShape`](#sameaccessshape) | top-level function | A | Check that a rebuilt route reproduces a saved route's content. |
| `_cleanTargets` | top-level function | B | Trim targets, drop empty and case-insensitive duplicates. |
| `_trimmedOrNull` | top-level function | B | Trim a string; empty becomes null. |
| `_jsonEquals` | top-level function | B | Deep equality for JSON-shaped maps, lists and scalars. |

The enums `ServiceAccessPattern` (`direct`, `reverseProxy`, `cloudflareTunnel`, `pangolin`,
`frp`, `routerPortForward`, `tailscaleFunnel`), `ServiceReachability` (`lan`, `vpn`, `public`,
`publicAuthenticated`), `ServiceAccessDraftIssue` (`missingSource`, `missingProxy`,
`missingRelay`, `invalidPublicPort`, `missingTargets`) and `ServiceAccessDraftWarning`
(`relayWithoutIngress`, `relayOnSourceDevice`) carry no other declarations.

## Documentation

### `bool get allowsProxyPrefix` <a id="allowsproxyprefix"></a>
- **Kind:** getter of `ServiceAccessPattern`. **Source:** line 45.
- **Purpose:** Report whether the "through a reverse proxy first" prefix hop is offered.
- **Inputs:** None. **Returns:** `bool`. **Side effects:** None.
- **Algorithm:** `false` for `direct` and `reverseProxy`, `true` for the other five.
- **Usage:** The guided page shows the prefix switch only when this is true; `fromRoute` rejects
  a two-hop route whose last hop names a pattern without the prefix.
- **Notes:** The prefix is what builds the two-hop chain *app → reverse proxy → tunnel or port
  mapping* that the old quick dialog could not create.

### `ServiceAccessLevel get accessLevel` <a id="accesslevel"></a>
- **Kind:** getter of `ServiceReachability`. **Source:** line 126.
- **Purpose:** Return the route access level a reachability saves.
- **Inputs:** None. **Returns:** `ServiceAccessLevel`. **Side effects:** None.
- **Algorithm:** `lan`→`lan`, `vpn`→`vpn`, `public`→`public`, `publicAuthenticated`→
  `authenticated`.
- **Usage:** `toRoute` writes it to `ServiceRoute.accessLevel`.
- **Notes:** `ServiceAccessLevel.custom` has no reachability, so routes using it stay with the
  advanced editor.

### `ServiceAccessLane get lane` <a id="lane"></a>
- **Kind:** getter of `ServiceReachability`. **Source:** line 138.
- **Purpose:** Return the topology lane a reachability pins.
- **Inputs:** None. **Returns:** `ServiceAccessLane`. **Side effects:** None.
- **Algorithm:** `lan`→`local`, `vpn`→`vpn`, both public variants→`public`.
- **Usage:** `toRoute` writes it as `extraJson['accessLane']`, so a LAN-only reverse proxy draws
  in the local lane instead of the public one the method inference would pick.
- **Notes:** None.

### `const ServiceAccessDraft({...})` <a id="serviceaccessdraft-new"></a>
- **Kind:** constructor. **Source:** line 211.
- **Purpose:** Create an access-path draft.
- **Inputs:** All optional: `routeId` (the edited route), `sourceServiceId`, `sourceEndpointId`,
  `pattern` (default `direct`), `reachability` (default `lan`), `viaProxy` (default `false`),
  `proxyServiceId`, `proxyEndpointId`, `proxyMethod` (null = derive from the proxy service),
  `relayServiceId`, `relayEndpointId` (for FRP, the ingress), `remoteDeviceId` (the router of a
  router port forward), `publicHost`, `publicPort`, `targets`, `notes`, `extraJson` (the edited
  route's unknown keys, without `publicTargets` and `accessLane`), `baseHops` (the edited
  route's hops), `initialDeviceId` (a device whose services the source picker offers first — a UI
  hint set by `forNode` for a device node, never saved).
- **Returns:** A new `ServiceAccessDraft`. **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:** `const ServiceAccessDraft(sourceServiceId: service.id)` starts a new path from a
  service; `ServiceAccessDraft.fromRoute` starts an edit.
- **Notes:** Immutable; the page replaces the whole value through `copyWith` on every change.

### `ServiceAccessDraft copyWith({...})` <a id="copywith"></a>
- **Kind:** method of `ServiceAccessDraft`. **Source:** line 255.
- **Purpose:** Create a copy with selected fields replaced or cleared.
- **Inputs:** Any content field; a `clearX` flag sets nullable field `X` to null.
- **Returns:** `ServiceAccessDraft`. **Side effects:** None.
- **Algorithm:** Field-by-field `clear ? null : (value ?? this.value)`, the repository's usual
  `copyWith` convention.
- **Usage:** `draft.copyWith(relayServiceId: id, clearRelayEndpointId: true)` when the user
  picks another relay.
- **Notes:** `routeId`, `extraJson`, `baseHops` and `initialDeviceId` always carry over, so an
  edit keeps its identity whatever the user changes.

### `ServiceRoute toRoute({required List<ServiceNode> services})` <a id="toroute"></a>
- **Kind:** method of `ServiceAccessDraft`. **Source:** line 333.
- **Purpose:** Build the one `ServiceRoute` the draft describes.
- **Inputs:** `services` — for the source name, the derived proxy method, and the FRP relay's
  device and default ingress.
- **Returns:** `ServiceRoute`. **Side effects:** None.
- **Algorithm:**
  1. Hops: the reverse-proxy pattern is one `_proxyHop`; every other pattern is an optional
     `_proxyHop` (when `usesProxyPrefix`) followed by `_accessHop`. The edited route's hops are
     reused position by position — the last base hop for the access hop, the first for the
     prefix — so ids and hop `extraJson` survive.
  2. Targets are trimmed and de-duplicated; `finalUrl` is the first, the rest go through
     `serviceRouteExtraJsonWithTargets`.
  3. `accessLevel` comes from the reachability, and `serviceRouteExtraJsonWithAccessLane` pins
     `accessLane` to the reachability's lane.
  4. The name is `serviceRouteGeneratedName` (unlocalized, like every persisted name); empty
     notes become null.
- **Usage:** Saving calls it after `serviceAccessDraftIssues` came back empty; the live preview
  and the duplicate-target warning call it on the incomplete draft as the user types.
- **Notes:** The route keeps the edited route's id, so sync sees an update rather than a delete
  and an add.

### `ServiceRouteHop _proxyHop(Map<String, ServiceNode> byId, ServiceRouteHop? base)` <a id="proxyhop"></a>
- **Kind:** method of `ServiceAccessDraft`. **Source:** line 375.
- **Purpose:** Build the reverse-proxy hop, either the whole reverse-proxy pattern or the prefix.
- **Inputs:** `byId` — services by id; `base` — the edited hop at this position.
- **Returns:** `ServiceRouteHop`. **Side effects:** None.
- **Algorithm:** Type `reverseProxy`; method `proxyMethod`, else `serviceProxyMethodFor(proxy)`,
  else `custom` when no proxy is chosen; `serviceId`/`endpointId` from the draft; id and
  `extraJson` from `base`.
- **Usage:** Called by `toRoute` and by `_accessHop`'s reverse-proxy case.
- **Notes:** No label is written: the topology labels the hop by its service.

### `ServiceRouteHop _accessHop(Map<String, ServiceNode> byId, ServiceRouteHop? base)` <a id="accesshop"></a>
- **Kind:** method of `ServiceAccessDraft`. **Source:** line 402.
- **Purpose:** Build the pattern's own hop.
- **Inputs:** `byId` — services by id; `base` — the edited hop at this position.
- **Returns:** `ServiceRouteHop`. **Side effects:** None.
- **Algorithm:**

  | Pattern | Hop |
  |---|---|
  | direct | `manual`, method `direct`, label `Direct` |
  | cloudflareTunnel / pangolin / tailscaleFunnel | `tunnel`, the pattern's method, `serviceId`/`endpointId` of the relay when chosen, else the method label |
  | frp | `portForward`, method `frp`, the relay's `serviceId` and `deviceId`, the chosen ingress (else `serviceDefaultIngressEndpoint`) as `endpointId`, `host`/`port` of the public entry |
  | routerPortForward | `portForward`, method `routerPortForward`, the router as `deviceId`, label `Router Port Forward`, `host`/`port` of the public entry |

- **Usage:** Called by `toRoute`.
- **Notes:** The FRP ingress is always written explicitly; the untouched default equals what the
  topology builder inferred for a hop without one, so the graph does not change.

### `static ServiceAccessDraft? fromRoute(ServiceRoute route, List<ServiceNode> services)` <a id="fromroute"></a>
- **Kind:** static method of `ServiceAccessDraft`. **Source:** line 483.
- **Purpose:** Read a saved route back into a draft for the guided page.
- **Inputs:** `route`; `services` — the current services.
- **Returns:** The draft, or null when the guided page cannot edit the route without changing or
  losing something.
- **Side effects:** None.
- **Algorithm:**
  1. `serviceReachabilityForRoute` must succeed.
  2. One or two hops; a first hop of two must be a reverse-proxy hop (`_isProxyHop`); the last
     hop must classify (`_patternForHop`), and a prefix needs `allowsProxyPrefix`.
  3. Build the draft from the hops. A proxy method equal to what the proxy service implies reads
     back as null ("derive"); an FRP hop without an endpoint reads back its default ingress.
  4. Rebuild the route with `toRoute` and require `_sameAccessShape`; require
     `serviceAccessDraftIssues` to be empty.
- **Usage:** [`serviceRouteOpensGuided`](#serviceroutesopensguided) decides with it whether a
  saved route opens in the guided page or the advanced editor; the guided page reads the route
  it opens with it.
- **Notes:** Stays null for three hops, hop notes, paths or schemes, a custom access level, a
  lane override that disagrees with the access level, a free-form FRP hop without a service, or
  a tunnel without a target — all of which the advanced editor keeps intact.

### `static ServiceAccessDraft? forNode(ServiceTopologyNode node, {required List<ServiceNode> services, required List<ServiceRoute> routes, required List<Device> devices})` <a id="fornode"></a>
- **Kind:** static method of `ServiceAccessDraft`. **Source:** line 568.
- **Purpose:** Build the draft a topology node's "add access path" action starts from.
- **Inputs:** `node`; `services`, `routes`, `devices` — the inventory the graph was built from.
- **Returns:** The draft, or null for a node without such an action. **Side effects:** None.
- **Algorithm:** By node kind:
  - **device** — `ServiceAccessDraft(initialDeviceId: node.deviceId)`.
  - **service** — the local `relayDraft` when [`serviceRelayPatternFor`](#servicerelaypatternfor)
    names the service a relay: that pattern, its default (public) reachability, the relay and,
    for FRP, the default ingress (`serviceDefaultIngressEndpoint`); otherwise
    `ServiceAccessDraft(sourceServiceId: …)`.
  - **endpoint** — a relay's port (role `remoteService`, e.g. the FRP ingress chip) gives the
    relay draft with that endpoint as the ingress; any other endpoint gives the source draft with
    `sourceEndpointId` set.
  - **domain** — the node's full target (`detail`, else `label`) as the only target, and the
    pattern every route through the node detects ([`detectServiceAccessPattern`](#detectserviceaccesspattern))
    when they all agree, with its default reachability; direct otherwise.
  - **relay**, **remoteEntry** — null; so is a node whose service or endpoint is gone.
- **Usage:** The topology details' actions ([`service_topology_page.md`](../views/service_topology_page.md)).
- **Notes:** A relay service offers both actions on the topology — add access from the relay
  itself (the plain source draft, built by the page) and expose another service through it (this
  draft). Tested in `test/service_access_patterns_test.dart` ("drafts from topology nodes").

### `bool operator ==(Object other)` <a id="equals"></a>
- **Kind:** operator of `ServiceAccessDraft`. **Source:** line 650.
- **Purpose:** Compare drafts by form content.
- **Inputs:** `other`. **Returns:** `bool`. **Side effects:** None.
- **Algorithm:** Every content field; `targets` and `extraJson` deeply through `_jsonEquals`.
- **Usage:** The round-trip tests compare `fromRoute(draft.toRoute(...))` with the original.
- **Notes:** `routeId` and `baseHops` are identity metadata and `initialDeviceId` is a UI hint;
  none of them is compared.

### `ServiceAccessPattern? detectServiceAccessPattern(ServiceRoute route, List<ServiceNode> services)` <a id="detectserviceaccesspattern"></a>
- **Kind:** top-level function. **Source:** line 723.
- **Purpose:** Name the access pattern a saved route follows.
- **Inputs:** `route`, `services`. **Returns:** The pattern, or null. **Side effects:** None.
- **Algorithm:** `ServiceAccessDraft.fromRoute(route, services)?.pattern`. The last hop decides:
  method `direct` ⇒ direct; a reverse-proxy hop (type, or method Caddy / Nginx / Traefik) as the
  only hop ⇒ reverse proxy; method Cloudflare Tunnel, Pangolin or Tailscale Funnel ⇒ that
  pattern; method FRP, or a `portForward` hop with a service ⇒ FRP; method router port forward,
  or a `portForward` hop without a service ⇒ router port forward.
- **Usage:** The advanced editor's "Guided editor" action and the domain case of
  [`forNode`](#fornode).
- **Notes:** Detection is defined as "the guided page can edit this losslessly", not as a loose
  classification.

### `ServiceReachability? serviceReachabilityForRoute(ServiceRoute route)` <a id="servicereachabilityforroute"></a>
- **Kind:** top-level function. **Source:** line 736.
- **Purpose:** Read the reachability a saved route expresses.
- **Inputs:** `route`. **Returns:** `ServiceReachability?`. **Side effects:** None.
- **Algorithm:** Map the access level (`authenticated` ⇒ `publicAuthenticated`, `custom` ⇒ null).
  With a valid `accessLane` override, the override must equal that reachability's lane,
  otherwise null. An unknown override value is ignored.
- **Usage:** Called by `fromRoute`.
- **Notes:** Deliberately stricter than "the lane wins": opening a route whose override and
  access level disagree must not silently rewrite either.

### `List<ServiceAccessDraftIssue> serviceAccessDraftIssues(ServiceAccessDraft draft, List<ServiceNode> services)` <a id="serviceaccessdraftissues"></a>
- **Kind:** top-level function. **Source:** line 757.
- **Purpose:** List the problems that keep a draft from being saved.
- **Inputs:** `draft`, `services`. **Returns:** The issues, empty when saveable.
- **Side effects:** None.
- **Algorithm:** `missingSource` without an existing source; `missingProxy` when `needsProxy` and
  the proxy is missing; `missingRelay` when FRP has no relay or any chosen relay no longer
  exists; `invalidPublicPort` outside 1–65535 for FRP and router port forward; `missingTargets`
  when `requiresTargets` and no non-blank target remains.
- **Usage:** The guided page disables saving and shows inline errors from it; `fromRoute`
  requires it to be empty.
- **Notes:** The source endpoint is not checked — a service without endpoints is a valid source.

### `List<ServiceAccessDraftWarning> serviceAccessDraftWarnings(ServiceAccessDraft draft, List<ServiceNode> services)` <a id="serviceaccessdraftwarnings"></a>
- **Kind:** top-level function. **Source:** line 794.
- **Purpose:** List advisory findings the guided page shows beside the preview.
- **Inputs:** `draft`, `services`. **Returns:** The warnings. **Side effects:** None.
- **Algorithm:** FRP only: `relayWithoutIngress` when the relay has no endpoint to act as the
  ingress; `relayOnSourceDevice` when the relay runs on the source's own device.
- **Usage:** Shown with the reference warnings in the preview card.
- **Notes:** Advisory like port conflicts: never blocks saving.

### `ServiceRouteMethod serviceProxyMethodFor(ServiceNode proxy)` <a id="serviceproxymethodfor"></a>
- **Kind:** top-level function. **Source:** line 821.
- **Purpose:** Pick the route method a reverse-proxy hop through a service records.
- **Inputs:** `proxy`. **Returns:** `ServiceRouteMethod`. **Side effects:** None.
- **Algorithm:** Lower-case template id, name and icon; `caddy`, then `nginx`, then `traefik`
  substrings win; otherwise `custom`.
- **Usage:** `_proxyHop` when the draft has no explicit `proxyMethod`; `fromRoute` to decide
  whether a saved method was the derived one.
- **Notes:** None.

### `bool isFrpLikeService(ServiceNode service)` <a id="isfrplikeservice"></a>
- **Kind:** top-level function. **Source:** line 850.
- **Purpose:** Report whether a service looks like an FRP server or another tunnel endpoint.
- **Inputs:** `service`. **Returns:** `bool`. **Side effects:** None.
- **Algorithm:** "frp" in the lower-cased name, template id, icon or kind name, or kind `tunnel`.
- **Usage:** Orders relay candidates for port-mapping hops.
- **Notes:** Moved unchanged from the removed quick access dialog's private `_isFrpLikeService`.
  `serviceAccessRelaySuggestions` uses it as the FRP fallback when no service is named after FRP.

### `ServiceAccessPattern? serviceRelayPatternFor(ServiceNode service, List<Device> devices)` <a id="servicerelaypatternfor"></a>
- **Kind:** top-level function. **Source:** line 869.
- **Purpose:** Name the relay pattern a VPS service offers other services.
- **Inputs:** `service`; `devices` — to find its device. **Returns:** `pangolin`, `frp` or null.
  **Side effects:** None.
- **Algorithm:** Null unless the service's device has category `vps`; then `pangolin` when the
  lower-cased name, template id or icon contains "pangolin", `frp` when it contains "frp", else
  null.
- **Usage:** [`forNode`](#fornode), for a service node and a relay's endpoint chip.
- **Notes:** Stricter than [`isFrpLikeService`](#isfrplikeservice): kind `tunnel` alone does not
  count, since Cloudflare and Tailscale tunnels are not relays another service is exposed through.

### `bool serviceRouteOpensGuided(ServiceRoute route, List<ServiceNode> services)` <a id="serviceroutesopensguided"></a>
- **Kind:** top-level function. **Source:** line 896.
- **Purpose:** Decide which editor a saved route opens in.
- **Inputs:** `route`, `services`. **Returns:** `true` for the guided page, `false` for the
  advanced editor. **Side effects:** None.
- **Algorithm:** `ServiceAccessDraft.fromRoute(route, services) != null`.
- **Usage:** `_editRoute` in [`service_list_page.md`](../views/service_list_page.md), which every
  place that opens a saved route goes through — route cards, route groups, the overview and the
  topology's details.
- **Notes:** Using the lossless round trip rather than a looser classification means the guided
  page never has to hand an opened route straight over to the advanced editor.

### `List<String> serviceAccessProxySuggestions(List<ServiceNode> services, {String? sourceServiceId})` <a id="serviceaccessproxysuggestions"></a>
- **Kind:** top-level function. **Source:** line 906.
- **Purpose:** List the services worth suggesting as a reverse proxy.
- **Inputs:** `services`; `sourceServiceId` — excluded, and its device's proxies come first.
- **Returns:** Service ids. **Side effects:** None.
- **Algorithm:** Keep `isReverseProxyLikeService` services other than the source; sort those on
  the source's device first, then by name.
- **Usage:** The guided page's proxy picker (suggested group) and its "preselect when exactly
  one" rule.
- **Notes:** The picker still offers every other service below the suggestions.

### `List<String> serviceAccessRelaySuggestions(ServiceAccessPattern pattern, List<ServiceNode> services, List<Device> devices, {String? sourceServiceId})` <a id="serviceaccessrelaysuggestions"></a>
- **Kind:** top-level function. **Source:** line 936.
- **Purpose:** List the services worth suggesting as the relay of a pattern.
- **Inputs:** `pattern`, `services`, `devices`; `sourceServiceId` — excluded.
- **Returns:** Service ids; empty for patterns without a relay. **Side effects:** None.
- **Algorithm:** Keep services whose lower-cased name, template id or icon contains the pattern's
  keyword — `frp`, `pangolin`, `cloudflare` (which also matches `cloudflared`) or `tailscale`.
  FRP falls back to `isFrpLikeService` when nothing is named after it. Sort services on VPS
  devices first, then by name.
- **Usage:** The guided page's relay picker (suggested group) and the preselection when exactly
  one service is suggested.
- **Notes:** A heuristic over names only, like the rest of the inventory: nothing inspects a
  real server.

### `String? suggestedDirectTarget({required ServiceNode source, ServiceEndpoint? endpoint, required List<NetworkDevice> assignments, required List<Network> networks, required ServiceReachability reachability})` <a id="suggesteddirecttarget"></a>
- **Kind:** top-level function. **Source:** line 1030.
- **Purpose:** Suggest the address a direct access path opens.
- **Inputs:** `source`; `endpoint` — the chosen source endpoint; `assignments`, `networks` —
  where the source's device sits; `reachability`.
- **Returns:** `scheme://host:port/path` from what is known, or null.
- **Side effects:** None.
- **Algorithm:** Only LAN and VPN reachability get a suggestion. Among the source device's
  assignments with an address, prefer one on a LAN network (LAN) or on an overlay network —
  Tailscale, ZeroTier, EasyTier, WireGuard (VPN) — else take the first. VPN prefers the host
  name (MagicDNS), LAN the IP address. The scheme comes from an http/https endpoint, other
  protocols get none; the endpoint is the chosen one, or the only one. The endpoint's path is
  appended.
- **Usage:** The guided page prefills the targets of a direct access path with it and offers it
  as a chip.
- **Notes:** With several endpoints and none chosen, no port is guessed.

### `String? suggestedPublicHost(ServiceNode relay, List<NetworkDevice> assignments)` <a id="suggestedpublichost"></a>
- **Kind:** top-level function. **Source:** line 1097.
- **Purpose:** Suggest the public host of an FRP relay.
- **Inputs:** `relay`, `assignments`. **Returns:** `String?`. **Side effects:** None.
- **Algorithm:** When the relay's device has exactly one network assignment, its host name, else
  its IP address; otherwise null.
- **Usage:** The guided page prefills an empty FRP public host with it.
- **Notes:** Several assignments make the guess ambiguous, so none is made.

### `ServiceAccessPattern? _patternForHop(ServiceRouteHop hop)` <a id="patternforhop"></a>
- **Kind:** top-level function. **Source:** line 1128.
- **Purpose:** Classify a route's last hop into a pattern.
- **Inputs:** `hop`. **Returns:** `ServiceAccessPattern?`. **Side effects:** None.
- **Algorithm:** Switch on the method (see `detectServiceAccessPattern`); for a `custom` or
  missing method fall back to the hop type: `reverseProxy` ⇒ reverse proxy, `portForward` ⇒ FRP
  with a service, router port forward without one; anything else ⇒ null.
- **Usage:** Called by `fromRoute`.
- **Notes:** None.

### `bool _sameAccessShape(ServiceRoute saved, ServiceRoute rebuilt, Map<String, ServiceNode> byId)` <a id="sameaccessshape"></a>
- **Kind:** top-level function. **Source:** line 1168.
- **Purpose:** Check that a rebuilt route reproduces a saved route's content.
- **Inputs:** `saved`, `rebuilt`, `byId`. **Returns:** `bool`. **Side effects:** None.
- **Algorithm:** Compare source service and endpoint, access level, trimmed notes, the access
  target lists and, hop by hop, type, method, service, endpoint, device, label, scheme, host,
  port, path and notes. A saved FRP hop without an endpoint compares as its default ingress.
- **Usage:** The last gate in `fromRoute`.
- **Notes:** Ids, the generated name, timestamps and `extraJson` are not compared: `toRoute`
  preserves the first and last, regenerates the name like the advanced editor does, and writes
  `accessLane`.
