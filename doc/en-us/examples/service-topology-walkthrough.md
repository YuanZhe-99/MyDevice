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
- `dev-vps` — the rented VPS (`DeviceCategory.vps`).

**Services** (`ServiceNode`, see
[Data Formats](../data-formats.md#servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart)):

- `svc-jellyfin` on `dev-home`: `kind: media`, `templateId` referencing the bundled
  Jellyfin template, one `ServiceEndpoint` `ep-jellyfin` (`protocol: http`, `port: 8096`,
  `scope: localhost`).
- `svc-caddy` on `dev-home`: `kind: reverseProxy`, one `ServiceEndpoint` `ep-caddy`
  (`protocol: https`, `port: 443`, `scope: lan` — same device as Jellyfin, so per
  [Services and Topology](../features/services-topology.md#topology-graph-layout-high-level)
  this stays a local node even though it forwards traffic onward).
- `svc-frp` on `dev-home` (the FRP client) and a corresponding FRP server presence on
  `dev-vps`. Two sibling endpoints on the VPS side, per the FRP modeling rule:
  - `ep-frp-ingress` on `dev-vps`: the FRP **ingress/listening** endpoint, e.g. port
    `57000`.
  - `ep-frp-public` on `dev-vps`: the FRP **public remote-entry** port, e.g. port `443`.

## Route and hops

A single `ServiceRoute` represents the whole access path:

```text
ServiceRoute(
  name: <generated, hidden from user>,
  sourceServiceId: 'svc-jellyfin',
  sourceEndpointId: 'ep-jellyfin',
  hops: [
    ServiceRouteHop(type: reverseProxy, serviceId: 'svc-caddy', endpointId: 'ep-caddy',
                     method: caddy),
    ServiceRouteHop(type: tunnel, serviceId: 'svc-frp', endpointId: 'ep-frp-ingress',
                     method: frp),
    ServiceRouteHop(type: publicEndpoint, endpointId: 'ep-frp-public'),
    ServiceRouteHop(type: dns, host: 'media.example.com'),
  ],
  finalUrl: 'https://media.example.com',
  accessLevel: public,
)
```

(Field names confirmed against `ServiceRoute`/`ServiceRouteHop` in
`lib/features/services/models/service.dart` — see
[Data Formats](../data-formats.md#servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart).
Exact hop ordering/count is illustrative of the concept; the app's quick access-route
creation flow for an "FRP" access type would generate the equivalent hops for the user
automatically — see
[Services and Topology](../features/services-topology.md#quick-access-route-creation-vs-the-advanced-editor).)

If `media.example.com` is one of several domains sharing this exact access path (e.g. a
wildcard or multiple subdomains all routed the same way), the additional
domains/URLs go into `extraJson['publicTargets']` on the route rather than duplicating
the whole route per domain (see
[Data Formats](../data-formats.md#servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart)).

## How the FRP ingress/public split is modeled

Per the FRP modeling rule (`AGENTS.md`, and
[Services and Topology](../features/services-topology.md#frp-style-ingresspublic-port-modeling)):

- The path is **not** modeled as a single chain
  `source → FRP ingress port → FRP public port → domain`.
- Instead, `ep-frp-ingress` (57000) and `ep-frp-public` (443) are **sibling port
  chips** under the same FRP service on `dev-vps`.
- The **source endpoint's route hop connects to the FRP ingress port** (`ep-frp-ingress`)
  — this is the tunnel's listening side, where the home server's FRP client actually
  connects.
- The **FRP public port connects onward to the domain** (`ep-frp-public` →
  `media.example.com`) — this is the internet-facing side that DNS actually resolves
  to.

This distinction matters because the ingress port (57000) and the public port (443) are
never actually chained to each other from a network-traffic point of view — a client
never connects to 57000 and gets forwarded to 443 as a further hop; rather, FRP
internally bridges the tunnel to the public listener. Modeling them as siblings instead
of a chain keeps the diagram accurate to how FRP actually works and avoids implying a
non-existent client-facing hop through the ingress port.

## How the topology graph renders this

Per [Service Topology Layout](../algorithms/service-topology-layout.md):

1. `svc-jellyfin` and `svc-caddy` sit on the same rank column-group as
   `dev-home` (local services), with `svc-caddy` shifted to a later rank than
   `svc-jellyfin` per the semantic layered layout so the arrow flow still reads
   left-to-right even though both are on the same physical device.
2. `dev-vps` and its FRP ports sit in a later rank (remote/public side).
   `_alignSiblingPortRanks` pulls `ep-frp-ingress` and `ep-frp-public` onto the same
   rank as each other so the two FRP port chips appear side-by-side rather than one
   trailing the other.
3. Edges are routed orthogonally: `ep-jellyfin → ep-caddy` (same device, short local
   edge), `ep-caddy → ep-frp-ingress` (crossing to the VPS rank), and
   `ep-frp-public → media.example.com` (a domain/URL leaf node) — each edge computed by
   `_fastRouteBetween`/`_routeBetween` with turn/congestion costs so these three edges
   don't visually overlap even though they all flow through the same general area of
   the canvas.
4. Both FRP port chips render as small rounded-square chips (port icon + number) rather
   than full node cards, per the port-chip rendering rule.

## Related

- [Services and Topology](../features/services-topology.md) — the full feature
  description, including quick access-route creation and templates.
- [Service Topology Layout](../algorithms/service-topology-layout.md) — the layout/
  routing algorithm referenced above.
- [Data Formats](../data-formats.md) — the exact `ServiceRoute`/`ServiceRouteHop` field
  shapes.
