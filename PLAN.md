# PLAN.md — Topology view and access-path creation overhaul (release 1.5.6)

**Temporary work order for the implementation agents. Not user documentation.**

- Written 2026-09-24 against `master` at `9c0b7a1` (app `1.5.5+44`, `myapps_data` v1.0.2).
- Target release: **1.5.6** — pre-approved by the repository owner on 2026-09-24. Version
  bump, `version-history.md` entry and tag happen only in Phase 6, never earlier.
- English only. Do **not** mirror this file into `doc/zh-cn/`, do not list it in any
  `INDEX.md`, do not link it from the docs.
- **Delete this file when everything is done.** The agent that completes the last remaining
  phase removes it with `git rm PLAN.md` in the same commit that finishes that phase (the
  release commit of Phase 6). If phases are done by different agents or sessions, each agent
  updates the status board below in its commits; only the agent that closes the final phase
  deletes the file. Nothing in the tree may reference PLAN.md after that commit.

## 0. Status board (update in the commit that changes it)

| Phase | Scope | Status | Commits / notes |
|---|---|---|---|
| 1 | Foundations: access patterns, lane override, labels, dead code, shared dialogs | todo | |
| 2 | Guided "Add access path" page replaces the quick dialog | todo | |
| 3 | Topology extraction + selection highlighting, legend, filters, fit/reset | todo | |
| 4 | Layout engine: row stride, domain alignment, crossing sweep, device containers | todo | |
| 5 | Topology as a launchpad; editor parity; small list polish | todo | |
| 6 | Release 1.5.6, doc sweep, delete PLAN.md | todo | |

Rules for every agent working from this plan:

1. Follow `AGENTS.md` exactly: fetch remotes and check for divergence before editing; read
   `doc/en-us/` first; Function Explanation Layer comment on every declaration you add or
   touch; docs updated **in the same commit**, `doc/zh-cn/` mirrored per
   `translation-guide.md`; report in English and Chinese; ask before pushing.
2. Work the phases in order. Each phase is one or more commits; every commit leaves
   `flutter analyze` and `flutter test` green.
3. No version bump, no tag, no `version-history.md` release entry before Phase 6.
4. Keep the behavior contract (`AGENTS.md`): no wire-format or local-format change beyond the
   additive `extraJson` key in D3; facades untouched; `data_modules.dart` untouched.
5. Do not widen scope. Anything noticed but out of scope goes into the final report, not the
   diff.

## 1. Scope

### 1.1 Goals

1. Make the topology diagram answer the reader's questions at a glance: which device runs
   what, which access routes go where, and what a selected node participates in — while
   keeping the FRP semantics (ingress/public sibling ports) and the performance work of
   v0.5.9–v0.5.12.
2. Turn "add a service access path" (源服务端点 → 各跳 → 最终地址, one `ServiceRoute`) into a
   guided, pattern-based flow that covers the common self-hosting setups in one screen,
   including the two-hop chain *app → same-device reverse proxy → tunnel/FRP → domain*, with
   inline creation of missing endpoints and relay services, a live chain preview, and
   advisory validation before saving.
3. Let the topology act as a launchpad: node actions open the guided flow with context
   prefilled; routes that fit a pattern reopen in the guided flow.
4. Keep every persisted format backward compatible: builds older than 1.5.6 must read data
   written by 1.5.6 and preserve what they do not understand.

### 1.2 Non-goals

- No discovery, port scanning, or connecting to servers — the manual-inventory-only
  constraint in `doc/en-us/features/services-topology.md` stands.
- No change to `service_data.json` field semantics, the WebDAV wire format, `.sync_base/`,
  or backups. The only persisted addition is the optional `extraJson['accessLane']` key (D3).
- No change to `packages/myapps_data` or to the shared-service facades.
- No embedded topology preview on the overview card (removed on purpose in v0.5.4).
- No replacement of the edge router (fast clear path → A* fallback stays).
- No merging of the topology's select and move modes (a v0.5.3 decision); this plan adds
  fit/reset to move mode only.

### 1.3 Hard constraints the code imposes

- Generated localizations are tracked (`lib/l10n/app_localizations*.dart`). After editing
  the ARB files run `flutter gen-l10n` and commit the output. Every new key goes into all
  four ARB files: `app_en.arb`, `app_ja.arb`, `app_zh.arb`, `app_zh_TW.arb`.
- Widget tests drive real pages in Simplified Chinese (`test/support/pump.dart`,
  `pumpPageAt`, `pumpUntil`, `seedAppDir` in `test/support/fake_storage.dart`). Find widgets
  by `Key`, type, or the zh string — never by the English string.
- `serviceRouteMethodLabel` and `serviceRouteGeneratedName` (`service_analysis.dart`) feed
  persisted route names, the Markdown export and the local API. They stay unlocalized. UI
  strings get separate localized helpers (Phase 1).
- Every width decision is a named predicate in `lib/shared/utils/adaptive_layout.dart` or
  `lib/shared/utils/detail_layout.dart` with the number justified in its doc comment and
  recorded in `doc/en-us/adaptive-layout.md` (the whole-tree grep for inline width
  comparisons must stay empty — see `v1.5.4` in `version-history.md`).

## 2. Current state (verified against the source, not just the docs)

### 2.1 Adding an access path today

- Six entry points all open `_QuickAccessRouteDialog` in
  `lib/features/services/views/service_list_page.dart`: the app-bar link icon, the overview
  button, the topology card's action row, the per-service route-group card, the service
  tile menu, and the topology node bottom sheet. Only `source` is ever prefilled.
- The dialog is one `AlertDialog` with six to nine stacked dropdowns and fields: source
  service, endpoint, method (`_QuickAccessMethod`, ten values, default `cloudflareTunnel`),
  access level (rendered as raw enum names via `level.name`), relay service (every service
  but the source; FRP-like ones first for port mapping), then for FRP / router port forward:
  remote device, remote host, remote port; then targets and notes.
- `_buildHop` produces exactly **one hop**, so the most common chain (app → Caddy on the
  same box → FRP/Cloudflare → domain) needs the advanced editor. For port-mapping hops the
  dialog never sets `endpointId`; the FRP ingress is inferred later by
  `_portMappingIngressEndpoint` (explicit → primary → first endpoint of the relay).
- `ServiceRouteEditPage` (advanced editor): `_showHopDialog` shows raw enum names for hop
  type and method, eight free-form fields per hop, move up/down, and `_routePreview`.
  Constructor: `ServiceRouteEditPage({route, sourceService})`; `route != null` means
  editing. It pops `true` on save and on delete.
- `_editRoute` always opens the advanced editor, even for routes the quick dialog made.
- No inline creation: a missing endpoint or relay service means cancel, create, start over.
- No validation before save; `findServiceReferenceWarnings` only runs on the overview.
- `serviceAccessLaneForRoute` is method-first: caddy / nginx / traefik / frp /
  routerPortForward / cloudflareTunnel / pangolin ⇒ `public` regardless of access level;
  tailscaleFunnel or `accessLevel == vpn` ⇒ `vpn`; `public`/`authenticated` ⇒ `public`; else
  `local`. A LAN-only reverse-proxy domain (Caddy plus split DNS) is therefore always drawn
  in the public lane.
- `ServiceEditPage({service, deviceId})` pops `true` on save and on delete; the list page
  pushes it with `push<bool>` and reloads on `true`. Its `_showEndpointDialog` is private.
- Templates that matter here (`service_template_service.dart` ids): `caddy`, `nginx`,
  `traefik`, `frp` (kind `tunnel`, one endpoint on 7000), `pangolin`, `cloudflare-tunnel`,
  `cloudflare-tunnel-compose`, `tailscale`. `DeviceCategory` has `router` and `vps`.
  `NetworkDevice` carries `ipAddress` and `hostname` per device/network assignment.

### 2.2 The topology today

- Graph: `buildServiceTopology` in `lib/features/services/services/service_analysis.dart`.
  Node kinds device / service / endpoint (compact chip) / relay / remoteEntry (compact chip)
  / domain, with roles; edges deduplicated by from/to/label/lane/method. Every service gets
  a device→service edge, routes or not.
- `ServiceTopologyNode.layoutColumn` is written by the builder (4/5 for public reverse
  proxies) and **never read** by the layout since v0.5.9. Dead field.
- Layout: `ServiceTopologyLayout.build(graph, routes, viewportWidth)` in
  `service_topology_layout.dart`: rank propagation (`_nodeRanks`, devices start at 0, others
  at 1, sibling port alignment), route rows (`_routeRows` orders sources by **label**, not by
  device), desired rows as medians (`_desiredRows`), compaction, placement (`_placeNodes`,
  fixed `rowStride = nodeHeight + 44`), then orthogonal routing (`_routeEdges`: fast path,
  A* fallback, turn and congestion costs, shared tracks).
- Widget layer, all inside `service_list_page.dart` (2488 lines): `_ServiceTopologyPage`
  (rotate, export PNG, select/move segmented button), `_ServiceTopologyView` (layout
  deferred to a post-frame callback and cached by `_TopologyLayoutRequest`, whose equality
  is graph identity + routes identity + rounded viewport width; select mode = nested
  `SingleChildScrollView`s, move mode = `InteractiveViewer` 0.35–2.4), `_TopologyNodeCard`
  (204×76 card or 52 px chip), `_ServiceTopologyEdgePainter` (2.2 px stroke at alpha 0.62,
  colour by lane, arrowhead), node tap → modal bottom sheet (`_showNodeDetails`).
- No selection or highlighting, no legend, no filters, no fit/reset, no edge labels.
  `_laneLabel`, `_roleLabel` and the relay fallbacks in `_relayLabel` are hardcoded
  English; relay node subtitles show raw enum names (`hop.method?.name ?? hop.type.name`).
- Tests: `test/service_topology_layout_test.dart` (six layout tests: chips, rank
  compression, row compaction, obstacle avoidance, FRP sibling ports, perpendicular entry),
  `test/service_module_test.dart` (graph-shape tests such as "places direct and FRP ingress
  after endpoint", "keeps same-device public proxy service local", "marks ports and remote
  entries as compact nodes"), `test/service_columns_ui_test.dart`.

### 2.3 Pain points this plan addresses

| # | Pain point | Fixed in |
|---|---|---|
| P1 | Quick flow builds one hop; proxy + tunnel chains need the advanced editor | Phase 2 |
| P2 | The form is shaped like the data model, not like the user's setup | Phase 2 |
| P3 | No inline creation of endpoints / relay services | Phase 1–2 |
| P4 | FRP ingress endpoint is implicit, never chosen | Phase 1–2 |
| P5 | Raw enum names and hardcoded English labels in dropdowns and topology | Phase 1–3 |
| P6 | LAN-only reverse-proxy routes are always classified public | Phase 1 (D3) |
| P7 | No preview or advisory validation before saving | Phase 2 |
| P8 | Cannot see what passes through a node | Phase 3 |
| P9 | Device fan-out edges; no visual grouping by device | Phase 4 |
| P10 | Final domains scattered across ranks | Phase 4 |
| P11 | Crossings from shared nodes (shared VPS, shared proxy, shared domain) | Phase 4 |
| P12 | Chip-only rows waste vertical space (fixed 120 px stride for 52 px chips) | Phase 4 |
| P13 | Dense graphs cannot be filtered | Phase 3 |
| P14 | No fit-to-screen / reset in move mode | Phase 3 |
| P15 | 2488-line view file mixes list, dialog and topology | Phase 3 |
| P16 | Dead `layoutColumn` field | Phase 1 |

## 3. Design decisions (settled — do not re-litigate; record deviations in the status board)

- **D1 — Access patterns are a pure-Dart layer.** New file
  `lib/features/services/services/service_access_patterns.dart` with:
  `enum ServiceAccessPattern { direct, reverseProxy, cloudflareTunnel, pangolin, frp,
  routerPortForward, tailscaleFunnel }`; `enum ServiceReachability { lan, vpn, public,
  publicAuthenticated }` (maps to `ServiceAccessLevel.lan/vpn/public/authenticated` and to
  `ServiceAccessLane.local/vpn/public/public`); an immutable `ServiceAccessDraft` with
  `copyWith`; `ServiceAccessDraft.toRoute({required services})`;
  `detectServiceAccessPattern(route, services)` and `ServiceAccessDraft.fromRoute(route,
  services)`. The page is a thin form over the draft. Everything is unit-testable without
  widgets.
- **D2 — One route per access path; hop shapes are exactly what `buildServiceTopology`
  already understands.** No graph-builder change is needed for the guided flow. Pattern → hops:

  | Pattern | Hop(s) produced (in order) |
  |---|---|
  | direct | `ServiceRouteHop(type: manual, method: direct, label: serviceRouteMethodLabel(direct))` |
  | reverseProxy | `reverseProxy(method: caddy \| nginx \| traefik \| custom — derived from the proxy service's templateId/name/kind, serviceId: proxy, endpointId: proxyEndpoint)` |
  | cloudflareTunnel | `tunnel(method: cloudflareTunnel, serviceId: relay?, label: serviceRouteMethodLabel(...) when no service)` |
  | pangolin | `tunnel(method: pangolin, serviceId: relay?, label as above)` |
  | tailscaleFunnel | `tunnel(method: tailscaleFunnel, serviceId: relay?, label as above)` |
  | frp | `portForward(method: frp, serviceId: frps, endpointId: ingress — explicit, deviceId: frps.deviceId, host: publicHost?, port: publicPort)` |
  | routerPortForward | `portForward(method: routerPortForward, deviceId: router?, label when no service, host: publicHost?, port: publicPort)` |
  | prefix "through a reverse proxy first" (allowed on cloudflareTunnel, pangolin, tailscaleFunnel, frp, routerPortForward) | a `reverseProxy(...)` hop **before** the pattern hop — the two-hop chain the quick flow lacked |

  The FRP default ingress equals today's inference (`_portMappingIngressEndpoint`: primary
  else first) so a draft that the user does not touch produces the same graph as before.
- **D3 — Explicit lane override, additive and optional.** New constant
  `serviceRouteAccessLaneKey = 'accessLane'` next to `serviceRoutePublicTargetsKey`; value
  `local | vpn | public`. `serviceAccessLaneForRoute` returns it when present and valid,
  otherwise today's inference, unchanged. The guided page always writes it (from
  reachability); the advanced editor gains a "Lane: Auto / LAN / VPN / Public" dropdown that
  writes or removes it. Older builds preserve the key through `extraJson` and keep inferring.
  Documented in `data-formats.md` (both languages) as a route `extraJson` key like
  `publicTargets`.
- **D4 — Editor parity.** Editing a route: if `detectServiceAccessPattern` matches, open the
  guided page; else the advanced editor. Guided → advanced hands over the draft
  (`ServiceRouteEditPage(draft: route)`, a new parameter for an unsaved initial route;
  `_editing` stays `widget.route != null`). Advanced → guided is offered only when detection
  matches the current form state.
- **D5 — Inline creation persists immediately.** "Add endpoint" saves the endpoint onto the
  chosen service via `ServiceStorage.addOrUpdateService` right away and selects it. "Create
  relay service…" pushes `ServiceEditPage(deviceId:, template:)` and receives the saved
  node back. Accepted trade-off: cancelling the route afterwards leaves the endpoint or
  service behind — both are valid inventory on their own.
- **D6 — Semantic graph unchanged; the layout gets options.** `buildServiceTopology` keeps
  its node/edge shape (existing graph tests stay valid, apart from the `layoutColumn`
  removal). New `ServiceTopologyLayoutOptions({groupByDevice, alignDomainSinks,
  bundleFanOut})` passed to `ServiceTopologyLayout.build`; the result gains `groupRects`
  (device containers) and `hiddenEdges` (edges implied by containment, not routed or
  painted).
- **D7 — Selection highlights routes.** Tapping a node selects it and highlights every route
  through it; unrelated nodes and edges dim. The related-route rule now inline in
  `_showNodeDetails` (route ids on the node, routes whose source or any hop is the node's
  service) moves to a pure `relatedRoutesForNode(node, routes)` in `service_analysis.dart`.
- **D8 — Details: bottom sheet on phones, side pane on split windows** (`useDetailTwoPane`
  from `detail_layout.dart`), consistent with the 1.5.x pages. Selection state lives in the
  page, so a highlight survives the sheet closing.
- **D9 — Filters produce a subgraph, never a paint-time mask.** Filter state (device set,
  lane set, search text) → filtered services and routes → `buildServiceTopology` → a
  memoized graph instance → the existing layout cache. `_TopologyLayoutRequest` must also
  compare the layout options.
- **D10 — Legend is a strip outside the canvas** (below the mode row; not part of the PNG
  export). Fit and reset use a `TransformationController` in move mode.
- **D11 — Extract the widgets.** Topology → `service_topology_page.dart` (page, view,
  layout request, details) and `service_topology_widgets.dart` (node card, edge painter,
  legend, icon/colour helpers, the public `iconForServiceIcon`). Guided flow →
  `service_access_path_page.dart`. Endpoint dialog → `service_endpoint_dialog.dart`.
  `service_list_page.dart` keeps the list and overview only. Every new file gets a functions
  page in `doc/en-us/functions/…` and `doc/zh-cn/functions/…` plus `INDEX.md` rows and
  totals in both languages.
- **D12 — Localized labels are UI-only.** New
  `lib/features/services/services/service_labels.dart` with helpers that take
  `AppLocalizations`: hop type, route method (generic values Direct / Custom / Router Port
  Forward localized; product names Caddy, Nginx, Traefik, FRP, Cloudflare Tunnel, Pangolin,
  Tailscale Funnel returned as-is), access level, lane, topology role, pattern name and
  description, reachability. Persisted names and exports do not change.
- **D13 — Layout option defaults.** `alignDomainSinks: true`; `groupByDevice: true` with a
  user toggle in the topology app bar (session state; persisting it is optional and, if
  done, goes through `DeviceStorage` like `serviceListColumns`); `bundleFanOut: false`
  until an agent has verified it visually — flip the default only with a screenshot-backed
  note in the report.

## 4. Phase 1 — Foundations (pure Dart and shared pieces; no visible UI change)

**Effort:** M. **Files:** `service_access_patterns.dart` (new), `service_labels.dart`
(new), `service_endpoint_dialog.dart` (new), `service_analysis.dart`, `service_edit_page.dart`,
`service_route_edit_page.dart` (labels only), `service_list_page.dart` (call sites only),
ARB ×4, tests, docs.

1. **Access patterns** (D1, D2). Implement the enums, `ServiceAccessDraft` (fields:
   `id` of the route when editing, `sourceServiceId`, `sourceEndpointId`, `pattern`,
   `reachability`, `viaProxy` flag, `proxyServiceId`, `proxyEndpointId`, `relayServiceId`,
   `relayEndpointId` (FRP ingress), `remoteDeviceId`, `publicHost`, `publicPort`, `targets`,
   `notes`, `extraJson` passthrough), `toRoute`, `detectServiceAccessPattern`, `fromRoute`.
   - `toRoute` keeps the route `id` and the hop ids when editing (so sync sees an update, not
     a delete plus add), sets `finalUrl = targets.firstOrNull`, writes targets via
     `serviceRouteExtraJsonWithTargets`, writes `accessLane` (D3), sets `accessLevel` from
     reachability, names the route with `serviceRouteGeneratedName`.
   - `detect` rules: one or two hops; an optional first `reverseProxy` hop is the prefix; the
     last hop decides — `method direct` ⇒ direct; type `reverseProxy` (or method caddy /
     nginx / traefik) as the only hop ⇒ reverseProxy; method cloudflareTunnel / pangolin /
     tailscaleFunnel ⇒ that pattern; method frp, or type `portForward` with a `serviceId` ⇒
     frp; method routerPortForward, or type `portForward` without a `serviceId` ⇒
     routerPortForward; anything else ⇒ `null`. Reachability from `accessLane` when present,
     else from `accessLevel`.
   - Tests (`test/service_access_patterns_test.dart`): a parameterized round trip over every
     pattern × prefix on/off × reachability (`toRoute` → `detect` → `fromRoute` → equal
     draft); FRP hop carries the chosen ingress `endpointId` and `deviceId`; the untouched
     FRP draft yields the same ingress as `_portMappingIngressEndpoint` would infer; a
     three-hop route detects as `null`; editing preserves unknown `extraJson` keys.
2. **Lane override** (D3): constant, `serviceAccessLaneForRoute` reads it first (ignore
   unknown values). Tests in `test/service_module_test.dart`: "explicit accessLane overrides
   method inference" (Caddy route with `accessLane: local` renders in the local lane) and
   "invalid accessLane falls back to inference".
3. **Remove `layoutColumn`** (P16): field, constructor parameter, `merge`, every
   `layoutColumn:` argument and the `sourceProxyColumn` logic in `buildServiceTopology`.
   `grep -rn layoutColumn lib test doc` must be empty afterwards.
4. **Localized labels** (D12): `service_labels.dart` + ARB keys in all four files. Replace raw
   `.name` rendering in `ServiceRouteEditPage` (hop type, method, access level) now; the
   quick dialog's `level.name` disappears with the dialog in Phase 2; topology labels move in
   Phase 3. Relay node subtitles: the widget renders the localized method label from
   `node.method` when set, else the existing `detail`.
5. **Shared endpoint dialog**: move `_showEndpointDialog` to
   `showServiceEndpointDialog(BuildContext context, {ServiceEndpoint? initial, required bool
   defaultPrimary})` in `service_endpoint_dialog.dart`; `service_edit_page.dart` calls it.
   No behavior change.
6. **`ServiceEditPage` returns what it saved** (prerequisite for D5): add an optional
   `ServiceTemplate? template` parameter applied through the existing `_applyTemplate` on
   first build, and pop a small result value instead of `true` — `class ServiceEditOutcome {
   final ServiceNode? saved; final bool deleted; }`. Update the two call sites in
   `service_list_page.dart` (`_addService`, `_editService`: `push<ServiceEditOutcome>`,
   reload when the result is non-null). `grep -rn "ServiceEditPage(" lib` to confirm there
   are no others.
7. **`relatedRoutesForNode(ServiceTopologyNode node, List<ServiceRoute> routes)`** in
   `service_analysis.dart` (D7), with a test; `_showNodeDetails` calls it.

**Docs (both languages):** new function pages `functions/features/services/services/
service_access_patterns.md`, `service_labels.md`, `functions/features/services/views/
service_endpoint_dialog.md`; updated `service_analysis.md`, `service_edit_page.md`,
`service_route_edit_page.md`, `service_list_page.md`; `functions/INDEX.md` rows and totals;
`data-formats.md` (`accessLane` key, in the route bullet and in the `extraJson` section);
`features/services-topology.md` (new "Access patterns" and "Lane override" sections;
the existing quick-access paragraph stays accurate until Phase 2 replaces it);
`translation-guide.md` §5.2: reuse the wording `doc/zh-cn/features/services-topology.md`
already uses (访问路径 for access path, 入口端口 for ingress endpoint, 中继/代理服务 for
relay/proxy service, and whatever it uses for lane) and add only the new terms — access
pattern 访问模式, reachability 可达范围, public entry 公网入口, device container 设备分组框,
route highlight 路由高亮.

**Acceptance:** analyze/test green; no UI visible change except localized dropdown labels
in the advanced editor; `layoutColumn` gone; round-trip tests pass.

## 5. Phase 2 — Guided "Add access path" page

**Effort:** L. **Files:** `service_access_path_page.dart` (new), `service_list_page.dart`
(remove `_QuickAccessRouteDialog`, `_QuickAccessMethod`, `_splitTargets` if unused; rewire
entry points), `service_route_edit_page.dart` (`draft` parameter, lane dropdown, "Guided
editor" hand-off), ARB ×4, tests, docs.

**Page:** `ServiceAccessPathPage({ServiceAccessDraft? draft, ServiceRoute? route})` pushed on
the root navigator like the edit pages; pops `true` when a route was saved or deleted. One
scrolling form with progressive disclosure (no `Stepper`); on windows that pass
`useDetailTwoPane` the form is the left pane at `editFormLeftPaneWidth` and the preview +
warnings card is the right pane (record the choice in `adaptive-layout.md`'s edit-page table).

1. **Section 1 — Source.** Service picker as a searchable bottom sheet grouped by device
   (reuse the template picker's search-field pattern and the `sheetInitialSize` /
   `sheetMaxSize` conventions); preselected from the draft. Endpoint `ChoiceChip`s
   (`label · portText`) plus a "＋ Add endpoint" chip that opens `showServiceEndpointDialog`
   and persists immediately (D5). A single endpoint is preselected; no endpoints ⇒ the add
   chip carries the hint text.
2. **Section 2 — Pattern.** A wrap/grid of pattern cards (icon from `_iconForMethod`, name,
   one-line description — all localized): Direct (LAN / VPN), Reverse proxy, Cloudflare
   Tunnel, Pangolin, FRP, Router port forward, Tailscale Funnel, and a last card "Custom /
   multi-hop" that pushes `ServiceRouteEditPage(draft: draft.toRoute(...))`. Selecting a
   pattern sets the default reachability (direct ⇒ lan; the rest ⇒ public) without
   overriding a value the user already changed.
3. **Section 3 — Details, per pattern.**
   - Reachability chips (LAN · VPN · Public · Public, login required) — always.
   - "Through a reverse proxy first" switch for cloudflareTunnel / pangolin / tailscaleFunnel /
     frp / routerPortForward: proxy service picker (candidates: kind `reverseProxy` or
     template `caddy` / `nginx` / `traefik`, any device, device name shown), proxy endpoint
     chips (+ add), "Create proxy service…" (`ServiceEditPage(deviceId: source device,
     template: caddy)`).
   - reverseProxy: the same proxy picker, endpoint chips, create action.
   - cloudflareTunnel / tailscaleFunnel: optional relay service picker (kind `tunnel` or
     matching template), else free-form; targets required.
   - pangolin: relay picker preferring `vps` devices, "Create relay service…" with template
     `pangolin` on a chosen device; targets required.
   - frp: relay picker preferring `_isFrpLikeService` candidates (move that heuristic into
     `service_access_patterns.dart` as `isFrpLikeService`), "Create relay service…" with
     template `frp` on a chosen `vps` device; **ingress endpoint chips** from the relay
     (default per D2, + add); public entry host (prefilled from the relay device's single
     `NetworkDevice.hostname ?? ipAddress` when exactly one assignment exists; optional) and
     public port (required, 1–65535); domains optional.
   - routerPortForward: router device picker (devices of category `router` first; optional),
     public host / DDNS (optional), public port (required), domains optional.
   - direct: targets optional, prefilled with a suggestion `scheme://host:port` built from the
     source device's assignment address and the endpoint's protocol/port when available.
   - Notes.
   - **Advisory warnings** (never block saving): run `findServiceReferenceWarnings` over
     `[...existingRoutes, draftRoute]` and show the entries naming the draft route (duplicate
     target, public without target); plus two local checks — the FRP relay has no endpoint
     to serve as ingress; the relay service sits on the same device as the source for FRP.
   - **Preview card**: chain text from a pure helper `serviceRouteChainPreview(route,
     services, devices)` added to `service_analysis.dart` (fold `_routePreview` from the
     advanced editor into it and reuse there), lane colour dot, access level.
4. **Actions:** Save (`FilledButton`), "Advanced editor" (`TextButton`; if the pushed editor
   pops `true`, this page pops `true`), Cancel. Edit mode: title "Edit access path", delete in
   the app bar with a confirmation, `ServiceStorage.deleteRoute`.
5. **Entry points:** every former dialog caller opens the page; the callback type used by the
   topology (`onAddAccess`) becomes `Future<void> Function({ServiceAccessDraft? draft})`.
6. **Advanced editor:** `draft` parameter (D4); lane dropdown (D3); a "Guided editor" action
   shown only when `detectServiceAccessPattern` matches the current form state.
7. **Remove** `_QuickAccessRouteDialog`, `_QuickAccessMethod` and now-unused helpers.

**Tests:** `test/service_access_path_page_test.dart` with `seedAppDir` fixtures (home
server with Jellyfin 8096 and Caddy 443, a `vps` device with an FRP service on 57000 and a
network assignment with a hostname): (a) FRP pattern shows ingress chips and requires a
public port; saving writes one route whose hop has `method frp`, the chosen `endpointId`,
`deviceId` of the VPS, and `extraJson.accessLane == 'public'`; (b) the proxy prefix adds a
`reverseProxy` hop first; (c) a duplicate target shows the advisory warning and saving still
succeeds; (d) "Advanced editor" pushes `ServiceRouteEditPage` with the draft; (e) the page
renders at a phone geometry and at a split geometry (two panes) — use the named geometries
already in `test/service_columns_ui_test.dart` / `adaptive-layout.md`.

**Docs (both languages):** new `functions/features/services/views/service_access_path_page.md`;
updated `service_list_page.md` (dialog section removed, entry points), `service_route_edit_page.md`,
`service_analysis.md` (`serviceRouteChainPreview`); `INDEX.md`; `features/services-topology.md`
("Quick access-route creation vs. the advanced editor" rewritten around patterns, prefix,
reachability, inline creation, advisory warnings); `examples/service-topology-walkthrough.md`
(the "how the user enters this" text describes the guided page: FRP pattern with proxy
prefix, ingress 57000, public 443); `adaptive-layout.md` (edit-page table row for the new
page; the sheet-size rows if the pickers reuse `sheetInitialSize`).

**Acceptance:** the quick dialog is gone; every entry point opens the page; the Jellyfin →
Caddy → FRP → domain chain is created in one screen and renders exactly like the walkthrough
graph (existing FRP topology tests unchanged and green).

## 6. Phase 3 — Topology extraction and interaction

**Effort:** L. **Files:** `service_topology_page.dart` (new), `service_topology_widgets.dart`
(new), `service_list_page.dart` (shrinks), `service_analysis.dart`, `detail_layout.dart`,
ARB ×4, tests, docs.

1. **Extraction** (D11) first, as its own commit with no behavior change: move the page,
   view, request key, node card, painter and helpers; `service_edit_page.dart` imports
   `iconForServiceIcon` from the widgets file. Update the functions pages and INDEX rows for
   the three files.
2. **Selection and highlighting** (D7): page state `selectedNodeId` and
   `highlightedRouteIds`. Tap a node in select mode ⇒ select it, highlight
   `relatedRoutesForNode(...)`. Painter: highlighted edges at full alpha and width 3.0;
   with a selection active, other edges at alpha 0.18. Node cards not on a highlighted route
   (and not the selected node or its device) wrap in `Opacity(0.35)`. Tap on empty canvas
   clears the selection; an "×" chip in the legend strip also clears it. Highlighting is
   part of what the PNG export captures (a deliberate feature: export one route).
3. **Details** (D8): phones keep the bottom sheet (opened from the same tap, after the
   highlight is set). On `useDetailTwoPane` windows the page body becomes `Row[Expanded
   (topology), SizedBox(width: topologyDetailPaneWidth(width), child: details)]` where
   `topologyDetailPaneWidth` is a new predicate in `detail_layout.dart` (number justified in
   its comment, tabled in `adaptive-layout.md`). The pane is non-modal with a close button;
   tapping a route row narrows the highlight to that route (tap again to widen back).
4. **Legend** (D10): a collapsible chip strip under the mode row — lane line samples
   (LAN / VPN / Public colours from the painter) and node role swatches (local device /
   local service / endpoint chip / remote device / remote entry chip / domain).
5. **Filters** (D9): app-bar filter action opening a sheet with device chips (multi-select),
   lane toggles, and a search field (matches service names, node labels, targets). Filtered
   routes = routes whose source service's device is selected, whose lane is selected, and
   which match the search; filtered services = services on the selected devices (hop services
   on other devices are added by the builder as today). Memoize the filtered graph; show an
   active-filter count badge; "Clear" resets.
6. **Fit / reset** (D10): in move mode, a `TransformationController` on the
   `InteractiveViewer`, "Fit" computes scale = `min(viewportW / canvasW, viewportH / canvasH)`
   clamped to the viewer's min/max and centres the canvas; "Reset" sets identity. Implement
   the matrix maths as a pure function `fitTransform(Size canvas, Size viewport, {double
   minScale, double maxScale})` in the widgets file and unit-test it.
7. **Localize** `_laneLabel`, `_roleLabel`, relay subtitles (D12) and update
   `serviceTopologyHint` to mention selection and filters.
8. **Accessibility:** `Semantics(label:)` on node cards (label + role + lane).

**Tests:** `test/service_topology_page_test.dart` (seeded storage, pumped at a phone and a
split geometry): tapping a service node dims an unrelated node and keeps the related domain
opaque; the filter sheet with only the LAN lane selected removes public-lane nodes; the legend
strip is present; the split geometry shows the details pane instead of a sheet. Pure tests
for `fitTransform` and `relatedRoutesForNode`.

**Docs (both languages):** new `service_topology_page.md`, `service_topology_widgets.md`;
updated `service_list_page.md`, `service_analysis.md`, `INDEX.md`; `features/services-topology.md`
("Views" and the full-screen topology paragraph: selection, details pane, legend, filters,
fit/reset); `adaptive-layout.md` (new predicate row; the "already a LayoutBuilder" row for
the topology page updated); `platform-notes.md` only if export behavior changes.

**Acceptance:** `service_list_page.dart` no longer contains topology or dialog code; select a
node ⇒ its routes stand out; filters and fit work at both geometries.

## 7. Phase 4 — Layout engine

**Effort:** L. **Files:** `service_topology_layout.dart`, `service_topology_page.dart` /
widgets (container painting, header card variant, toggle), tests, `algorithms/service-topology-layout.md`.

Land these as separate commits in this order; each has its own tests.

1. **Row stride by content** (P12). Replace the fixed `rowStride` with per-row heights:
   for each compact row value `r` (after `_compactDesiredRows`), `rowHeight[r] = max` node
   height among nodes on that row across all ranks; `y(r) = padding + Σ_{k<r}(rowHeight[k] +
   rowGap)`, with `rowGap` a named constant (start at 36). Test: a rank whose rows hold only
   chips places consecutive chips closer than `nodeHeight + 44`; the existing six layout
   tests stay green.
2. **Domain sink alignment** (P10, `alignDomainSinks`). After propagation and before
   compression in `_nodeRanks`, set every `domain` node without outgoing edges to the maximum
   rank. Test: on the sample graph all domain nodes share the last rank; paths remain
   orthogonal and obstacle-free (reuse the existing polyline checks).
3. **Crossing counter and barycenter sweep** (P11). Add `_countCrossings(orderByRank,
   edges)` (bilayer inversion count between adjacent ranks) and, after the initial
   row-based order in `_placeNodes`, up to four alternating down/up barycenter sweeps. A
   sweep's new order for a rank is accepted only if the total crossing count strictly
   decreases; when a node moves, it swaps compact row values with the node it passes, so the
   cross-rank row alignment that keeps chain edges straight is preserved as a permutation.
   Container members (item 4) move as a block. Tests: the counter on a hand-built two-rank
   graph; a crafted graph (two local devices sharing one VPS and one domain) ends with fewer
   crossings than the un-swept order; the sample graphs never end with more.
4. **Device containers** (P9, `groupByDevice`). Members of device D: nodes with
   `deviceId == D` and kind `service`, `endpoint` or `remoteEntry`. The device node becomes
   the container header (a strip of `containerHeaderHeight` ≈ 40 across the container's top;
   `_TopologyNodeCard` gains a header variant). `groupRects[D]` = bounding box of the members
   plus header and padding. Device→service edges of grouped devices go into `hiddenEdges`
   and are neither routed nor painted; edges *into* a device node (free-form port-mapping hops
   with a `deviceId`) route to the header's left edge. A device node without members (e.g. a
   router referenced only by a hop) stays a plain card. The painter draws containers below
   the edges: low-alpha fill by role, dashed border for remote / VPS devices, label in the
   header.
   - Placement: order sources in `_routeRows` by (device order, source label) — local
     devices by name first, then remote ones — so a device's members occupy a contiguous band
     of rows; then a bounded post-pass that, while any non-member node rect or another
     container intersects a container rect, pushes the intruder (and everything below it in
     its rank) down by the overlap plus `verticalGap`, recomputing rects; give up after
     `nodes.length` iterations and fall back to flat placement for that graph (log nothing,
     just return `groupRects` empty).
   - Invariants, each a test on the sample graph and the two-local-devices-one-VPS graph:
     every member rect lies inside its container; no non-member node intersects a container;
     containers do not overlap each other; every routed edge still avoids every node rect;
     `hiddenEdges` contains exactly the device→service edges of grouped devices; with
     `groupByDevice: false` the output equals the pre-phase layout for the same input.
   - Page: app-bar toggle "Group by device" (default on per D13); the request key includes the
     options.
5. **Fan-out bundling** (`bundleFanOut`, optional, default off). For edges sharing the same
   `from` node and exit side whose targets sit in the same rank, route one trunk to a
   vertical fan line at `targetRankX − _routingTrackGap` and per-target L-segments from
   there; validate every segment with `_pathClear`, otherwise fall back to individual
   routing. Test: three domains behind one FRP public port share a trunk segment; all paths
   remain obstacle-free. Skip this item entirely if items 1–4 consume the budget; record the
   decision in the status board.
6. **Performance check:** a test builds a synthetic 60-node / 80-edge graph and asserts the
   layout completes (log the `Stopwatch` time; do not assert a duration in CI). Only if that
   time exceeds ~100 ms on a developer machine consider `compute()`; note that `edgePaths` is
   keyed by `ServiceTopologyEdge` identity (no `==`), so an isolate round trip would need
   index keys or value equality first.

**Docs (both languages):** `algorithms/service-topology-layout.md` (new sections: row
heights, sink alignment, crossing sweep, containers with the invariants and the fallback,
bundling if landed; the constants block updated), `features/services-topology.md` (layout
paragraph and the toggle), `functions/…/service_topology_layout.md` (every new or changed
declaration), `examples/service-topology-walkthrough.md` ("How the topology graph renders
this": containers for `dev-home` and `dev-vps`, domain column on the right).

**Acceptance:** all previous layout tests green; new invariant tests green; the walkthrough
graph shows two containers, port chips as siblings, and the domain on the last rank.

## 8. Phase 5 — Topology as a launchpad and editor parity

**Effort:** S–M. **Files:** `service_topology_page.dart`, `service_list_page.dart`,
`service_access_patterns.dart` (helpers), tests, docs.

1. **Contextual drafts from node actions** (details sheet / pane):
   - service node ⇒ "Add access path from here" (`sourceServiceId` prefilled; existing
     behavior, now via the draft);
   - endpoint chip ⇒ same, with `sourceEndpointId` prefilled;
   - domain node ⇒ "Add another service to this target" (`targets` prefilled, pattern from the
     first route on the node when unambiguous);
   - service node that is a relay on a `vps` device (FRP / Pangolin) ⇒ "Expose a service
     through this relay" (`pattern` and `relayServiceId` prefilled);
   - device node / container header ⇒ "Add access path for a service on this device" (source
     picker filtered to that device via a new `initialDeviceId` on the draft).
   Provide `ServiceAccessDraft.forNode(node, services, routes)` as a pure helper with tests.
2. **Route opening rule** (D4) everywhere a route is opened: route cards, route groups, the
   overview, the details pane, the service tile menu.
3. **List polish:** `_routeCard` leading icon from `_iconForMethod(_primaryMethod(route))`
   instead of the constant `alt_route`; route summary shows the lane label (localized).

**Tests:** `forNode` cases (domain, relay, device, service); a widget test that a route saved
through the guided page reopens in the guided page from the routes view, and that a three-hop
route reopens in the advanced editor.

**Docs (both languages):** `features/services-topology.md` (node actions), function pages
for the touched files.

## 9. Phase 6 — Release 1.5.6 and clean-up

1. Doc sweep: read every page touched by Phases 1–5 in both languages against the code;
   fix drift; run the `translation-guide.md` §6 checklist for each zh page; confirm
   `functions/INDEX.md` totals in both languages match `grep -c 'Purpose:'` reality per the
   INDEX's own convention.
2. Version locations (per `AGENTS.md`): `pubspec.yaml` `version: 1.5.6+45` and
   `msix_config.msix_version: 1.5.6.0`; `installer.iss` `AppVersion=1.5.6` (output
   filenames stay derived from `{#SetupSetting("AppVersion")}`). Never touch the settings
   page version display.
3. `doc/en-us/version-history.md` (and zh) entry `v1.5.6` in the house style (what changed
   and why, the decisions D1–D13 in prose, the new `accessLane` key, the layout options and
   their defaults, tests added), ending with "Versions unified to `1.5.6+45` / MSIX `1.5.6.0`
   / installer `1.5.6`".
4. `flutter analyze && flutter test` on the final tree.
5. Final commit: version bump + history entry + **`git rm PLAN.md`** + status board is moot
   (the file is gone). Annotated tag `v1.5.6`. Push the commit first, then the tag, only
   after the user confirms the push (`AGENTS.md` step 9; during planning the owner said they
   would update the Gitea remote themselves — confirm the current expectation before pushing
   anywhere).
6. Report in English and Chinese: what changed, what was verified, pre-change version
   `1.5.5+44` → `1.5.6+45`, configured remotes, anything skipped (bundling, persistence of
   the group toggle) and why.

## 10. Verification (every phase)

```bash
flutter gen-l10n            # whenever an ARB file changed; commit the generated output
flutter analyze
flutter test                # full suite; CI runs the same (see doc/en-us/ci-cd.md)
flutter test test/service_access_patterns_test.dart test/service_module_test.dart \
             test/service_topology_layout_test.dart                     # narrow loop
grep -rn layoutColumn lib test doc   # must be empty after Phase 1
```

Widget tests use the geometries and helpers already in `test/support/` and drive in Simplified
Chinese; add fixtures through `seedAppDir` rather than hand-written JSON.

## 11. Documentation checklist (tick per phase, both languages)

- [ ] `doc/*/functions/<mirrored path>.md` for every new or changed file, with the
      Declarations table, tiers and per-declaration entries in the existing style.
- [ ] `doc/*/functions/INDEX.md` rows, per-directory totals and the totals paragraph.
- [ ] `doc/*/features/services-topology.md`.
- [ ] `doc/*/algorithms/service-topology-layout.md` (Phase 4).
- [ ] `doc/*/examples/service-topology-walkthrough.md` (Phases 2 and 4).
- [ ] `doc/*/data-formats.md` (`accessLane`, Phase 1).
- [ ] `doc/*/adaptive-layout.md` (new predicates and page rows, Phases 2–3).
- [ ] `doc/*/translation-guide.md` §5.2 (new app-specific terms; nothing cross-cutting, so
      the sibling repos are not touched).
- [ ] `doc/*/version-history.md` (Phase 6 only).

## 12. Risks and pitfalls (read before coding)

- **Layout cache key.** `_TopologyLayoutRequest` compares graph and routes by identity.
  Filters (Phase 3) and options (Phase 4) must produce stable instances (memoize) and be part
  of the key, or the view re-lays out on every rebuild.
- **`ServiceTopologyEdge` has no `==`.** `edgePaths` and `hiddenEdges` are identity-keyed;
  always pass the same graph instance from build to paint.
- **Existing graph tests assert device→service edges** (e.g. `vps → service:frp`). Containers
  hide those edges in the layout, not in the graph (D6) — do not "fix" the tests.
- **FRP semantics are a documented rule**: ingress and public ports stay siblings under the
  FRP service; the source connects to the ingress; the public port connects to the domain(s).
  Phase 2's explicit ingress and Phase 4's containers must not alter `_alignSiblingPortRanks`
  behavior; `test/service_topology_layout_test.dart` "FRP topology keeps ingress and public
  ports as sibling FRP ports" is the guard.
- **Lane inference for legacy routes is deliberately unchanged** (D3). Do not reinterpret
  `accessLevel == lan` (the model default) as an explicit choice.
- **Persisted names stay English.** Only UI labels are localized (D12); changing
  `serviceRouteMethodLabel` would rename routes on every device after sync.
- **Immediate persistence in inline creation** (D5) means the page must reload its service
  list after the dialog returns and must keep the user's other selections.
- **Test fonts.** The default test font renders Latin glyphs as full em squares; layouts are
  measured in zh (see `pumpPageAt`). Do not assert on English text.
- **`flutter gen-l10n` output is committed**; a missing key in one ARB breaks the build for
  that locale. `app_ja.arb` already trails `app_en.arb` by two keys — leave that as is, but
  add every new key to all four files.
- **Do not restore a mini preview on the overview card** and do not make the two topology
  modes one (see §1.2).

## 13. Open items for the owner (none block Phase 1)

- Persist the "Group by device" toggle in `storage_config.json` (`topologyGroupByDevice`)
  or keep it per session? Default in this plan: per session; persistence is a one-line
  follow-up through `DeviceStorage`.
- Fan-out bundling (Phase 4 item 5) is optional and off by default; decide after seeing the
  first screenshots.
