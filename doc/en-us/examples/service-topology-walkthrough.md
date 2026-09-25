# Service Topology Walkthrough

A worked example of adding a service behind a reverse proxy behind an FRP tunnel to a
public domain, and how the [Services and Topology](../features/services-topology.md)
route/hop model and topology rendering represent it. This follows the FRP modeling rule
from `AGENTS.md` and [Service Topology Layout](../algorithms/service-topology-layout.md).

## Scenario

The user self-hosts Jellyfin on a home server, exposed to the public internet through:

1. **Caddy**, a reverse proxy running on the same home server, terminating TLS and
   routing by hostname.
2. **FRP**, tunneling from the home server to a VPS the user rents, so the home
   connection doesn't need port forwarding on the home router.
3. A **public domain**, `media.example.com`, pointed at the VPS.

## Inventory entries

Following the manual-inventory-only constraint (see
[Services and Topology](../features/services-topology.md#manual-inventory-only-constraint)),
the user hand-enters all of this — nothing here is auto-discovered.

**Devices** (see [Devices](../features/devices.md)):
- `dev-home` — the home server.
- `dev-vps` — the rented VPS (`DeviceCategory.vps`), with one network assignment whose host
  name is `vps.example.com`.

**Services** (`ServiceNode`, see
[Data Formats](../data-formats.md#servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart)):

- `svc-jellyfin` on `dev-home`: `kind: media`, one `ServiceEndpoint` `ep-jellyfin`
  (`protocol: http`, `port: 8096`).
- `svc-caddy` on `dev-home`: `kind: reverseProxy`, template `caddy`, one `ServiceEndpoint`
  `ep-caddy` (`protocol: https`, `port: 443`) — same device as Jellyfin, so it stays a local
  node even though it forwards traffic onward.
- `svc-frp` on `dev-vps`: the FRP server, template `frp`, one `ServiceEndpoint`
  `ep-frp-ingress` (port `57000`) — the **ingress/listening** port the home server's FRP
  client connects to.

The VPS's public port `443` is **not** an endpoint of its own. It is the public entry of the
route's FRP hop (`host`/`port`), which the topology renders as a remote-entry chip beside the
ingress chip.

## How the user enters this

On the guided **Add access path** page (see
[Services and Topology](../features/services-topology.md#adding-an-access-path)), one screen:

1. **Service and port:** Jellyfin; its only endpoint, `Web · 8096`, is preselected.
2. **How is it reached?:** the **FRP** card. Reachability switches to **Public**.
3. **Details:**
   - **Through a reverse proxy first:** on. Caddy is the only proxy-like service, so it is
     preselected with its primary endpoint, `HTTPS · 443`.
   - **FRP server:** `svc-frp` is the only FRP-named service, so it is preselected, and its
     primary endpoint, the **ingress** chip `57000`, with it.
   - **Public host:** prefilled with `vps.example.com` from `dev-vps`'s single network
     assignment. **Public port:** `443`.
   - **Domains:** `media.example.com`.

The preview card then reads
`Jellyfin 8096 -> Caddy 443 -> FRP 57000 (dev-vps) -> vps.example.com:443 -> media.example.com`
in the Public / VPS lane, and Save writes one route.

## Route and hops

A single `ServiceRoute` represents the whole access path:

```text
ServiceRoute(
  name: 'Jellyfin via Caddy - media.example.com',   // generated, hidden from the user
  sourceServiceId: 'svc-jellyfin',
  sourceEndpointId: 'ep-jellyfin',
  hops: [
    ServiceRouteHop(type: reverseProxy, method: caddy,
                    serviceId: 'svc-caddy', endpointId: 'ep-caddy'),
    ServiceRouteHop(type: portForward, method: frp,
                    serviceId: 'svc-frp', endpointId: 'ep-frp-ingress',
                    deviceId: 'dev-vps', host: 'vps.example.com', port: 443),
  ],
  finalUrl: 'https://media.example.com',
  accessLevel: public,
  extraJson: {'accessLane': 'public'},
)
```

(Field names confirmed against `ServiceRoute`/`ServiceRouteHop` in
`lib/features/services/models/service.dart` — see
[Data Formats](../data-formats.md#servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart).
The guided page writes exactly these two hops for "FRP, through a reverse proxy first"; the FRP
hop always names its ingress endpoint explicitly, and `accessLane` pins the lane the chosen
reachability implies — see
[Services and Topology](../features/services-topology.md#access-patterns).)

If `media.example.com` is one of several domains sharing this exact access path (e.g. a
wildcard or multiple subdomains all routed the same way), the additional
domains/URLs go into `extraJson['publicTargets']` on the route rather than duplicating
the whole route per domain (see
[Data Formats](../data-formats.md#app-written-extrajson-keys)).

## How the FRP ingress/public split is modeled

Per the FRP modeling rule (`AGENTS.md`, and
[Services and Topology](../features/services-topology.md#frp-style-ingresspublic-port-modeling)):

- The path is **not** modeled as a single chain
  `source → FRP ingress port → FRP public port → domain`.
- Instead, the ingress endpoint chip (`ep-frp-ingress`, 57000) and the public remote-entry
  chip (443, from the hop's `host`/`port`) are **sibling port chips** under the same FRP
  service on `dev-vps`.
- The **route's previous step connects to the FRP ingress port** — here Caddy's endpoint
  `ep-caddy`, since Caddy is the hop before FRP. This is the tunnel's listening side, where the
  home server's FRP client actually connects.
- The **FRP public port connects onward to the domain** (`:443` → `media.example.com`) —
  this is the internet-facing side that DNS actually resolves to.

This distinction matters because the ingress port (57000) and the public port (443) are
never actually chained to each other from a network-traffic point of view — a client
never connects to 57000 and gets forwarded to 443 as a further hop; rather, FRP
internally bridges the tunnel to the public listener. Modeling them as siblings instead
of a chain keeps the diagram accurate to how FRP actually works and avoids implying a
non-existent client-facing hop through the ingress port.

## How the topology graph renders this

Per [Service Topology Layout](../algorithms/service-topology-layout.md):

1. `svc-jellyfin` and `svc-caddy` are local service nodes under `dev-home`; Caddy sits at a
   later rank than Jellyfin's endpoint chip because the route passes Jellyfin → Caddy, so the
   arrows keep reading left-to-right even though both run on the same machine.
2. `dev-vps`, `svc-frp` and its port chips sit in later ranks (remote/public side).
   `_alignSiblingPortRanks` pulls the ingress chip and the public-entry chip onto the same
   rank so the two FRP port chips appear side by side rather than one trailing the other.
3. Edges are routed orthogonally: `ep-jellyfin → svc-caddy → ep-caddy` (short local edges),
   `ep-caddy → ep-frp-ingress` (crossing to the VPS side), `svc-frp → :443`, and
   `:443 → media.example.com` (a domain/URL leaf node) — each computed by
   `_fastRouteBetween`/`_routeBetween` with turn/congestion costs so they don't visually
   overlap even though they all flow through the same general area of the canvas.
4. Both FRP port chips render as small rounded-square chips (port icon + number) rather
   than full node cards, per the port-chip rendering rule.

## Related

- [Services and Topology](../features/services-topology.md) — the full feature
  description, including the guided access-path page, access patterns and templates.
- [Service Topology Layout](../algorithms/service-topology-layout.md) — the layout/
  routing algorithm referenced above.
- [Data Formats](../data-formats.md) — the exact `ServiceRoute`/`ServiceRouteHop` field
  shapes.
