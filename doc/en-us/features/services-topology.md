# Services and Topology

Model source: `lib/features/services/models/service.dart`. Layout algorithm source:
`lib/features/services/services/service_topology_layout.dart`. See
[Data Formats](../data-formats.md#servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart)
for the exact model fields, and
[Service Topology Layout](../algorithms/service-topology-layout.md) for the layout/routing
algorithm deep dive. For a worked example, see
[Service Topology Walkthrough](../examples/service-topology-walkthrough.md).

## Manual-inventory-only constraint

This is the single most important constraint on the whole feature, stated directly in
`AGENTS.md`: **Service management is a manual inventory/notes module, not an operations
or monitoring system.** It must not connect to servers, scan ports, inspect Docker,
start/stop services, or store secrets. Users hand-enter service, port, route, and Docker
Compose notes for personal reference — nothing here performs discovery.

Service data is stored in `service_data.json` and syncs/backs up/imports like the other
primary modules (see [Data Formats](../data-formats.md#persisted-data-inventory)).

## Model recap

- **`ServiceNode`** — a service instance on a device: `deviceId`, `name`,
  `templateId`/`icon`/`kind`/`runtime`/`state`, `endpoints`
  (`List<ServiceEndpoint>`), `tags`, `notes`, optional `dockerCompose` (plain text,
  copyable from the editor — no credential/token management is added to this field),
  `modifiedAt`, `extraJson`.
- **`ServiceEndpoint`** — a manually recorded local/listening endpoint: protocol,
  transport, bind address, port or port range (`port`/`portEnd`), optional
  path/`networkId`, `scope`, `isPrimary` flag, notes, `extraJson`.
- **`ServiceRoute`** — a manually recorded access path from a source service endpoint
  through ordered `hops` to a final URL/address. `finalUrl` stores the first target for
  backward compatibility; additional grouped URLs/domains for the *same* access path are
  stored in `extraJson['publicTargets']`.
- **`ServiceRouteHop`** — one route hop: origin, reverse proxy, tunnel, port forward,
  public endpoint, internal endpoint, DNS, or manual note. Hops can reference existing
  services/endpoints (`serviceId`/`endpointId`/`deviceId`) or remain entirely free-form
  (`label`/`scheme`/`host`/`port`/`path`).

Full field lists: [Data Formats](../data-formats.md).

## Views

The Services tab has four views: **overview**, **by-device**, **route**, and **port**.

The overview generates a manual service topology graph from saved services/routes,
grouped by local devices while allowing shared remote devices/VPS nodes across multiple
local devices. The graph distinguishes:

- Local service endpoints.
- LAN/WiFi access.
- VPN/Tailscale access.
- Relay/proxy/tunnel hops.
- FRP/router-style remote port entries.
- Final domains/URLs.

The overview card's header/actions layout is responsive so titles like "service
topology" don't collapse vertically on narrow screens, and it uses an **open-topology
button** rather than a scaled-down embedded preview, because real graphs are too dense
to read at preview size. The full-screen topology adds selectable node details, a
separate move/zoom mode, internal 90-degree rotation (without changing system
orientation), and PNG export/share (platform-specific mechanism —
see [Platform Notes](../platform-notes.md#android)).

## Topology graph layout (high level)

Topology layout is **semantic and compact rather than fixed-column**: dynamic graph
ranks are derived from actual edges and compressed per graph so unused role columns
don't waste canvas space. The full-screen topology defers expensive layout until after
the first frame and caches layouts by graph, routes, width, and rotation-derived
viewport, so mode changes (e.g. entering move/zoom mode) don't rerun routing.

Edges are precomputed by a **fast clear-path orthogonal router with an A* fallback**,
inflated node obstacles, turn costs, congestion costs, explicit exit/entry stubs, and
outside-obstacle routing tracks — so arrows avoid element interiors and enter/leave
cards perpendicularly. See [Service Topology Layout](../algorithms/service-topology-layout.md)
for the algorithm detail (class/function names, obstacle model, cost function).

Direct/LAN/VPN access nodes and remote VPS devices appear as **parallel branches**
after the source endpoint rather than a single chain, and same-device public reverse
proxy services (e.g. Caddy) stay local but can be placed later in routed paths so
arrows keep moving left-to-right.

## Quick access-route creation vs. the advanced editor

**Quick access-route creation** is the default, simple flow for adding direct,
reverse-proxy, tunnel, FRP, and router port-forward access paths — it covers the common
cases without asking the user to build a multi-hop chain by hand. The **advanced route
editor** remains available for manual multi-hop chains that don't fit one of those
templates. Route *names* are generated internally (hidden from the user); user-facing
route descriptions belong in `notes` instead.

## Access patterns

`lib/features/services/services/service_access_patterns.dart` names the self-hosting setups a
single access path usually follows, so a route can be described the way the user thinks about
it rather than as a list of hops. Each pattern produces exactly one `ServiceRoute` whose hops the
topology builder already understands:

| Pattern | Hop(s) |
|---|---|
| Direct (LAN / VPN) | one `manual` hop, method `direct` |
| Reverse proxy | one `reverseProxy` hop through the proxy service and its endpoint; method Caddy, Nginx or Traefik from the service, else custom |
| Cloudflare Tunnel, Pangolin, Tailscale Funnel | one `tunnel` hop with that method, through a relay service when one is chosen |
| FRP | one `portForward` hop, method `frp`, through the FRP server service, with its **ingress endpoint chosen explicitly**, the server's device, and the public host/port |
| Router port forward | one `portForward` hop, method `routerPortForward`, on the router device, with the public host/port |

The five tunnel and port-mapping patterns can add **a reverse-proxy hop first** — the chain
*app → Caddy on the same machine → FRP or a tunnel → domain* that used to need the advanced
editor. The FRP ingress defaults to the relay's primary endpoint, else its first — exactly the
endpoint the topology inferred before 1.5.6 for a hop that named none — so a path the user does
not touch renders the same graph.

A pattern is never stored. A saved route is classified again whenever it opens, and it counts as
a pattern only if the guided form can reproduce it field for field: one or two hops, the
optional proxy hop first, a recognised last hop, an access level and lane that form one
*reachability*, and no hop notes, schemes, paths or other details the form does not show.
Everything else — three hops, a custom access level, hand-edited hop fields — belongs to the
advanced editor, which keeps it intact.

## Lane override

The topology colours and orders every route by its **access lane** — LAN / WiFi, VPN /
Tailscale, or Public / VPS. Before 1.5.6 the lane was always inferred, method first: any hop
through FRP, a router port forward, Caddy, Nginx, Traefik, Cloudflare Tunnel or Pangolin made a
route public, whatever its access level said. That cannot express a LAN-only reverse proxy
(Caddy with split DNS), which was always drawn in the public lane.

A route can now pin its lane in `extraJson['accessLane']` (`local`, `vpn` or `public`; see
[Data Formats](../data-formats.md#app-written-extrajson-keys)). The key is optional and additive:
without it the old inference applies unchanged, so existing routes draw exactly as before, and
older builds keep the key and keep inferring. A route's **reachability** — LAN, VPN, Public, or
Public with login — is the pair of its access level and this lane: LAN pins the local lane, VPN
the VPN lane, and both public choices the public lane (the login variant saves the
`authenticated` access level).

## FRP-style ingress/public port modeling

For FRP-style access, the path is modeled as: VPS/remote device → FRP service on that
VPS/remote device, with **sibling FRP port chips**:

- An **ingress/listening endpoint**, e.g. port `57000`.
- A separate **public remote-entry port**, e.g. port `443`.

The **source endpoint connects to the FRP ingress port**, while the **FRP public port
connects to one or more domains** — ingress and public FRP ports are *not* modeled as a
chain (i.e. not ingress → public port → domain as three sequential hops; the source
connects directly to ingress, and public connects directly to the domain(s), as
siblings under the same FRP service). See
[Service Topology Walkthrough](../examples/service-topology-walkthrough.md) for a full
worked example of this exact pattern.

Topology endpoints and remote public-entry ports render as small rounded-square **port
chips** with an icon and port number, so ports stay visible without competing visually
with primary device/service/domain nodes.

## Service templates

`service_template_service.dart` supplies templates for common self-hosted tools: Caddy,
Gitea, Jellyfin, Pangolin, FRP, Cloudflare Tunnel, File Browser, Vaultwarden, Nextcloud,
WordPress, Code Server, OpenCode, AdGuard Home, LuCI, Minecraft Server, and related
homelab services. Templates only **prefill** names/icons/types/default ports/Compose
examples — they do not perform discovery, matching the manual-inventory-only
constraint above.

## Port conflict detection

Port conflict detection is **advisory only**: it warns about multiple manually entered
services using the same device/transport/port, but must never block saves, because
bind addresses and user intent may legitimately vary (e.g. two services correctly bound
to different interfaces on the same port).

## Related

- [Service Topology Layout](../algorithms/service-topology-layout.md) — the layout and
  routing algorithm.
- [Service Topology Walkthrough](../examples/service-topology-walkthrough.md) — a
  worked FRP example.
- [Data Formats](../data-formats.md) — full model fields.
- [Backup and Restore](../backup-restore.md#markdown-export) — Markdown export includes
  service endpoints, routes, hops, Compose notes, and grouped public targets.
- [Platform Notes](../platform-notes.md#desktop-local-api-server) — read-only
  `/service/*` API endpoints.
