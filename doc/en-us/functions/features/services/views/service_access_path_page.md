# lib/features/services/views/service_access_path_page.dart

The guided **Add access path** page described in
[Services and Topology](../../../../features/services-topology.md#adding-an-access-path). It is a
thin form over a `ServiceAccessDraft` from
[service_access_patterns.md](../services/service_access_patterns.md): the user picks the source
service and endpoint, then an access pattern (direct, reverse proxy, Cloudflare Tunnel,
Pangolin, FRP, router port forward, Tailscale Funnel), then fills the few details that pattern
needs, and the page saves exactly one `ServiceRoute` through `ServiceStorage.addOrUpdateRoute`.
It replaced the single-hop quick access dialog in 1.5.6.

Missing pieces are created inline and **persisted immediately**: "Add endpoint" saves the
endpoint onto its service at once (through the shared
[`showServiceEndpointDialog`](service_endpoint_dialog.md)), and "Create proxy service…" /
"Create relay service…" push [`ServiceEditPage`](service_edit_page.md) with a template and select
the service it pops in its `ServiceEditOutcome`. Cancelling the access path afterwards leaves
those behind; they are valid inventory on their own. A live preview card shows the chain
(`serviceRouteChainPreview`), the lane and access level, and advisory warnings, which never block
saving. "Advanced editor" and the "Custom / multi-hop" card hand the draft to
[`ServiceRouteEditPage`](service_route_edit_page.md).

The page is pushed on the root navigator by every "Add access" entry point of
[service_list_page.md](service_list_page.md) — the app bar, the overview, the topology card, a
service's route group, the service tile menu and the topology's node actions, which start it
from a node-specific draft (`ServiceAccessDraft.forNode`) — by `_editRoute` for every saved route
that fits it, and by the advanced editor's "Guided editor" action. It pops `true` after a save or a delete and nothing when the
user backs out.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ServiceAccessPathPage` constructor | constructor | B | Create the page for a new path (`draft`) or a saved route (`route`). |
| `createState` | method (`ServiceAccessPathPage`) | B | Create the page state. |
| `_editing` | getter (`_ServiceAccessPathPageState`) | B | Whether a saved route is being edited. |
| `initState` | method (`_ServiceAccessPathPageState`) | B | Create the four text controllers and start `_load(initial: true)`. |
| `dispose` | method (`_ServiceAccessPathPageState`) | B | Dispose the controllers. |
| [`_load`](#load) | method (`_ServiceAccessPathPageState`) | A | Load the inventory; on the first load resolve the starting draft. |
| `_syncControllers` | method (`_ServiceAccessPathPageState`) | B | Copy the draft's text fields into the controllers. |
| `_update` | method (`_ServiceAccessPathPageState`) | B | Replace the draft and rebuild. |
| `_serviceById` | method (`_ServiceAccessPathPageState`) | B | Look up a service by id. |
| `_deviceById` | method (`_ServiceAccessPathPageState`) | B | Look up a device by id. |
| `_servicesOnInitialDevice` | method (`_ServiceAccessPathPageState`) | B | The services on the draft's `initialDeviceId`, by name; preselected when there is one, suggested first in the source picker. |
| [`_withDefaultSourceEndpoint`](#withdefaultsourceendpoint) | method (`_ServiceAccessPathPageState`) | A | Preselect the source endpoint when the choice is obvious. |
| [`_pickSource`](#picksource) | method (`_ServiceAccessPathPageState`) | A | Pick the source service in the sheet. |
| [`_selectPattern`](#selectpattern) | method (`_ServiceAccessPathPageState`) | A | Switch the pattern, with defaults and preselection. |
| `_withRelay` | method (`_ServiceAccessPathPageState`) | B | Point the draft at a relay; FRP gets its default ingress. |
| `_withSingleProxyCandidate` | method (`_ServiceAccessPathPageState`) | B | Preselect the proxy when exactly one proxy-like service exists. |
| `_withProxy` | method (`_ServiceAccessPathPageState`) | B | Point the draft at a proxy with its default endpoint; method back to "derive". |
| `_prefillDirectTarget` | method (`_ServiceAccessPathPageState`) | B | Fill an empty targets field with the direct-access suggestion and remember it as `_autoTarget`. |
| `_prefillPublicHost` | method (`_ServiceAccessPathPageState`) | B | Fill an empty FRP public host from the relay device's single assignment. |
| `_directSuggestion` | method (`_ServiceAccessPathPageState`) | B | `suggestedDirectTarget` for the current source and endpoint. |
| `_pickProxy` | method (`_ServiceAccessPathPageState`) | B | Pick the proxy in the sheet, proxy-like services suggested first. |
| `_pickRelay` | method (`_ServiceAccessPathPageState`) | B | Pick the relay in the sheet, the pattern's candidates suggested first. |
| [`_createService`](#createservice) | method (`_ServiceAccessPathPageState`) | A | Create a proxy or relay service inline from a template and select it. |
| [`_addEndpointTo`](#addendpointto) | method (`_ServiceAccessPathPageState`) | A | Save a new endpoint onto a service at once and select it. |
| [`_save`](#save) | method (`_ServiceAccessPathPageState`) | A | Save the one route, or show the blocking issues. |
| `_delete` | method (`_ServiceAccessPathPageState`) | B | Confirm and delete the edited route; pop `true`. |
| [`_openAdvancedEditor`](#openadvancededitor) | method (`_ServiceAccessPathPageState`) | A | Hand the draft to the advanced route editor. |
| `_handedOver` | getter (`_ServiceAccessPathPageState`) | B | Whether the route could not be read into a draft at all. |
| `build` | method (widget build, `_ServiceAccessPathPageState`) | B | Scaffold with title, delete (edit mode) and save actions around `_buildBody`. |
| [`_buildBody`](#buildbody) | method (widget helper) | A | One column, or two panes on split windows. |
| `_sectionTitle` | method (widget helper) | B | Numbered section heading. |
| `_buildSourceSection` | method (widget helper) | B | Source tile and endpoint chips with "Add endpoint". |
| `_buildPatternSection` | method (widget helper) | B | Pattern cards in equal-height rows of `accessPatternColumns`, plus the custom card. |
| [`_buildDetailsSection`](#builddetailssection) | method (widget helper) | A | The fields the selected pattern needs. |
| [`_buildPreviewCard`](#buildpreviewcard) | method (widget helper) | A | Chain, lane, access level and advisory warnings. |
| [`_draftReferenceWarnings`](#draftreferencewarnings) | method (`_ServiceAccessPathPageState`) | A | The reference warnings that concern the draft route. |
| `_buildActions` | method (widget helper) | B | Cancel, Advanced editor, Save. |
| `_showServicePicker` | method (`_ServiceAccessPathPageState`) | B | Open `_ServicePickerSheet` and return the picked service. |
| `serviceAccessPatternIcon` | top-level function | B | The icon of a pattern card, matching the route-method icons. |
| `_splitTargets` | top-level function | B | Split the targets field by line or comma. |
| `_ServiceTile` constructor | constructor | B | Tile showing a chosen service, or a prompt to choose one. |
| `build` | method (widget build, `_ServiceTile`) | B | Card with icon, name, device and ports; error text below. |
| `_EndpointChips` constructor | constructor | B | Endpoint choice chips plus an add chip. |
| `build` | method (widget build, `_EndpointChips`) | B | Chips keyed `<prefix>-<endpoint id>`, optional "none" chip. |
| `_PatternCard` constructor | constructor | B | One selectable pattern card. |
| `build` | method (widget build, `_PatternCard`) | B | Icon row, title, description; selected state with border, fill, check and semantics. |
| `_ServicePickerSheet` constructor | constructor | B | The searchable service picker sheet. |
| `createState` | method (`_ServicePickerSheet`) | B | Create the sheet state. |
| `dispose` | method (`_ServicePickerSheetState`) | B | Dispose the search controller. |
| `_deviceName` | method (`_ServicePickerSheetState`) | B | A service's device name. |
| `_matches` | method (`_ServicePickerSheetState`) | B | Search match on service name, device name and ports. |
| [`build`](#pickerbuild) | method (widget build, `_ServicePickerSheetState`) | A | Suggested services first, then the rest grouped by device. |
| `_header` | method (widget helper) | B | Group heading. |
| `_tile` | method (widget helper) | B | One service row, keyed `access-pick-<id>`. |

## Documentation

### `Future<void> _load({bool initial = false})` <a id="load"></a>
- **Kind:** method of `_ServiceAccessPathPageState`
- **Source:** `lib/features/services/views/service_access_path_page.dart` (line 122)
- **Purpose:** Load services, routes, devices, networks and assignments; on the first load
  resolve the draft the page starts with.
- **Inputs:** `initial` — true only for the call from `initState`.
- **Returns:** `Future<void>`.
- **Side effects:** Reads `ServiceStorage`, `DeviceStorage` and `NetworkStorage`; updates state.
- **Algorithm:**
  1. Load the three stores and replace the inventory lists.
  2. On the first load: read `widget.route` with `ServiceAccessDraft.fromRoute`; else use
     `widget.draft`, else an empty draft. Drop a source that no longer exists; a draft started
     from a device (`initialDeviceId`) with exactly one service gets that service as its source
     (`_servicesOnInitialDevice`); preselect an obvious source endpoint, and copy the draft into
     the text fields. A route read back marks
     the reachability as the user's own choice, so switching patterns does not reset it.
  3. If a route was given but cannot be read into a draft, open the advanced editor after the
     frame (`_openAdvancedEditor`); closing it closes this page too.
  4. Otherwise, on the first load of a new path, prefill the direct-access suggestion
     (`_prefillDirectTarget`) — so a draft that arrives with its source set, from a service's
     route group or tile menu, opens with the address filled in like a source picked by hand —
     and the FRP public-host suggestion (`_prefillPublicHost`), so a draft that arrives with its
     relay set, from the topology's "Expose a service through this relay", gets the host too.
- **Usage:** `initState`, and after every inline creation so the new endpoint or service is
  there to select.
- **Notes:** Later loads keep the draft untouched; they only refresh what it points into.

### `ServiceAccessDraft _withDefaultSourceEndpoint(ServiceAccessDraft draft)` <a id="withdefaultsourceendpoint"></a>
- **Kind:** method of `_ServiceAccessPathPageState`
- **Source:** `lib/features/services/views/service_access_path_page.dart` (line 225)
- **Purpose:** Preselect the source endpoint when the choice is obvious.
- **Inputs:** `draft`. **Returns:** `ServiceAccessDraft`. **Side effects:** None.
- **Algorithm:** Keep an existing choice. Otherwise a source with exactly one endpoint gets that
  endpoint, one with a primary endpoint gets the primary one, and one without endpoints stays
  without.
- **Usage:** `_load` and `_pickSource`.
- **Notes:** With several endpoints and no primary one the user chooses.

### `Future<void> _pickSource()` <a id="picksource"></a>
- **Kind:** method of `_ServiceAccessPathPageState`
- **Source:** `lib/features/services/views/service_access_path_page.dart` (line 244)
- **Purpose:** Let the user pick the source service.
- **Inputs:** None. **Returns:** `Future<void>`.
- **Side effects:** Opens the picker sheet; updates the draft; may prefill the direct target.
- **Algorithm:** Pick from every service, the initial device's services
  (`_servicesOnInitialDevice`) suggested first; clear the endpoint and preselect the obvious one;
  a proxy or relay equal to the new source is cleared, since a service cannot pass traffic to
  itself.
- **Usage:** The source tile's `onTap`.
- **Notes:** None.

### `void _selectPattern(ServiceAccessPattern pattern)` <a id="selectpattern"></a>
- **Kind:** method of `_ServiceAccessPathPageState`
- **Source:** `lib/features/services/views/service_access_path_page.dart` (line 285)
- **Purpose:** Switch the draft to another access pattern.
- **Inputs:** `pattern`. **Returns:** `void`. **Side effects:** Updates the draft and prefilled
  fields.
- **Algorithm:**
  1. Switch the pattern and drop the relay (it was chosen for another pattern) and, unless the
     new pattern is router port forward, the router.
  2. Apply `pattern.defaultReachability` (direct ⇒ LAN, the rest ⇒ public) unless the user has
     picked a reachability.
  3. Leaving the direct pattern, clear the targets field if it still holds exactly the
     suggestion the page filled in itself (`_autoTarget`); text the user typed or edited stays.
     The remembered suggestion is forgotten either way.
  4. Preselect the relay when `serviceAccessRelaySuggestions` names exactly one service, and the
     proxy when the draft needs one and exactly one proxy-like service exists.
  5. Prefill the direct target and the FRP public host where the fields are empty.
- **Usage:** Each pattern card's `onTap`.
- **Notes:** The proxy prefix flag survives the switch, so switching back restores it. Without
  step 3 a LAN address suggested for direct access would be saved as the "domain" of an FRP or
  tunnel path the user picked next.

### `Future<void> _createService({required String templateId, String? deviceId, required bool asProxy})` <a id="createservice"></a>
- **Kind:** method of `_ServiceAccessPathPageState`
- **Source:** `lib/features/services/views/service_access_path_page.dart` (line 484)
- **Purpose:** Create a proxy or relay service inline and select it.
- **Inputs:** `templateId` — `caddy` for the proxy, the pattern's relay template otherwise;
  `deviceId` — where the new service starts (the source's device, or the first VPS for FRP and
  Pangolin); `asProxy`.
- **Returns:** `Future<void>`.
- **Side effects:** Pushes `ServiceEditPage(deviceId:, template:)`, which saves the service;
  reloads; updates the draft.
- **Algorithm:** Await the edit page's `ServiceEditOutcome`; on `saved`, reload and select the
  new service as proxy or relay with its default endpoint.
- **Usage:** "Create proxy service…" and "Create relay service…".
- **Notes:** The user can still change the template's device, name and ports on the edit page.

### `Future<void> _addEndpointTo(ServiceNode service, ServiceAccessDraft Function(ServiceAccessDraft, ServiceEndpoint) onAdded)` <a id="addendpointto"></a>
- **Kind:** method of `_ServiceAccessPathPageState`
- **Source:** `lib/features/services/views/service_access_path_page.dart` (line 516)
- **Purpose:** Add an endpoint to a service right away and select it.
- **Inputs:** `service`; `onAdded` — returns the draft with the new endpoint selected.
- **Returns:** `Future<void>`.
- **Side effects:** Shows the endpoint dialog; saves the service; reloads; updates the draft.
- **Algorithm:** Show `showServiceEndpointDialog` (primary by default on a service without
  endpoints); re-read the service from storage, append the endpoint, save with
  `ServiceStorage.addOrUpdateService`; reload and apply `onAdded`.
- **Usage:** The "Add endpoint" chip of the source, proxy, relay and FRP ingress rows.
- **Notes:** Re-reading before saving keeps an edit made elsewhere from being overwritten.

### `Future<void> _save()` <a id="save"></a>
- **Kind:** method of `_ServiceAccessPathPageState`
- **Source:** `lib/features/services/views/service_access_path_page.dart` (line 542)
- **Purpose:** Save the access path as one route and close the page.
- **Inputs:** None. **Returns:** `Future<void>`.
- **Side effects:** Persists the route and pops `true`; with blocking issues, shows them and a
  snackbar instead.
- **Algorithm:** `serviceAccessDraftIssues`; if any, set `_showIssues` so the fields show their
  errors and stop. Otherwise `ServiceStorage.addOrUpdateRoute(_draft.toRoute(...))` and pop.
- **Usage:** The app-bar save action and the Save button.
- **Notes:** Advisory warnings never block saving.

### `Future<void> _openAdvancedEditor()` <a id="openadvancededitor"></a>
- **Kind:** method of `_ServiceAccessPathPageState`
- **Source:** `lib/features/services/views/service_access_path_page.dart` (line 598)
- **Purpose:** Hand the current draft over to the advanced route editor.
- **Inputs:** None. **Returns:** `Future<void>`.
- **Side effects:** Pushes `ServiceRouteEditPage`; pops `true` when the editor saved or deleted.
- **Algorithm:** Build the route from the draft; push `ServiceRouteEditPage(route: ...)` in edit
  mode (the id is kept) or `ServiceRouteEditPage(draft: ...)` for a new path; when it pops
  `true`, pop `true` too. A page that only exists to hand over an unreadable route closes with
  the editor.
- **Usage:** The "Advanced editor" button and the "Custom / multi-hop" card.
- **Notes:** The editor is pushed on top rather than replacing this page, so its result still
  reaches whoever opened this page.

### `Widget _buildBody(BuildContext context, AppLocalizations l10n)` <a id="buildbody"></a>
- **Kind:** method (widget helper)
- **Source:** `lib/features/services/views/service_access_path_page.dart` (line 666)
- **Purpose:** Lay the form out in one column or two panes.
- **Inputs:** `context`, `l10n`. **Returns:** `Widget`. **Side effects:** None.
- **Algorithm:** Without `useDetailTwoPane`, one `ListView` (key `access-single-pane`) of the
  source, pattern and details sections, the preview card and the actions. With it, a `Row` (key
  `access-two-pane`): a left pane of `editFormLeftPaneWidth` with the choices — source and
  pattern — and a right pane with the details, the preview and the actions. Both panes scroll.
- **Usage:** `build`.
- **Notes:** Pushed above the shell, so the width is the raw window. The split puts the decisions
  on the left and what they need beside them; the whole form on the left would leave the right
  pane holding only the preview.

### `List<Widget> _buildDetailsSection(BuildContext context, AppLocalizations l10n)` <a id="builddetailssection"></a>
- **Kind:** method (widget helper)
- **Source:** `lib/features/services/views/service_access_path_page.dart` (line 866)
- **Purpose:** Build the fields the selected pattern needs.
- **Inputs:** `context`, `l10n`. **Returns:** `List<Widget>`. **Side effects:** None.
- **Algorithm:** Always the reachability chips (LAN · VPN · Public · Public, login required).
  Then, as the pattern needs them: the "Through a reverse proxy first" switch; the proxy tile
  with its endpoint chips and "Create proxy service…"; the relay tile (required for FRP,
  clearable otherwise) with endpoint chips — for FRP the **ingress** chips, defaulting to the
  relay's primary endpoint — and "Create relay service…"; the router picker (routers first); the
  public host and the required public port. The router picker is an `isExpanded` dropdown whose
  device names ellipsize, so a long name cannot overflow a narrow pane. Then the targets field
  (labelled as domains for port mappings), the direct-access suggestion chip, and notes.
  Blocking issues show as field errors once a save was attempted.
- **Usage:** `_buildBody`.
- **Notes:** Every widget a test drives carries a key (`access-proxy-switch`,
  `access-public-port`, `access-targets`, `access-ingress-<id>`, …).

### `Widget _buildPreviewCard(BuildContext context, AppLocalizations l10n)` <a id="buildpreviewcard"></a>
- **Kind:** method (widget helper)
- **Source:** `lib/features/services/views/service_access_path_page.dart` (line 1193)
- **Purpose:** Show the chain, lane, access level and advisory warnings of the draft.
- **Inputs:** `context`, `l10n`. **Returns:** `Widget`. **Side effects:** None.
- **Algorithm:** Build the draft route; show `serviceRouteChainPreview` with
  `serviceHopFallbackLabel` as the fallback, so a hop without a service or label of its own is
  named by its localized method ("Direct", "Router port forward") and only then by its type; a
  dot in the lane colour with the lane and access-level labels; then one row per warning from
  `_draftReferenceWarnings` and `serviceAccessDraftWarnings`.
- **Usage:** `_buildBody`.
- **Notes:** Recomputed on every build — the inventory is small and the preview must follow each
  keystroke.

### `List<ServiceWarning> _draftReferenceWarnings(ServiceRoute route)` <a id="draftreferencewarnings"></a>
- **Kind:** method of `_ServiceAccessPathPageState`
- **Source:** `lib/features/services/views/service_access_path_page.dart` (line 1273)
- **Purpose:** Find the reference warnings that concern the draft route.
- **Inputs:** `route` — the draft as a route. **Returns:** `List<ServiceWarning>`.
- **Side effects:** None.
- **Algorithm:** Run `findServiceReferenceWarnings` over the saved routes with the draft in place
  of the route it edits; keep the warnings naming the draft route, and duplicate-target warnings
  whose route list contains it; drop the kinds a blocking issue already covers — missing source,
  missing hop service, empty route, and, for patterns whose targets are required (reverse proxy
  and the three tunnels), a public route without a URL.
- **Usage:** `_buildPreviewCard`.
- **Notes:** This is what surfaces "duplicate final URL" before saving; the warning is advisory,
  exactly as on the overview.

### `Widget build(BuildContext context)` (`_ServicePickerSheetState`) <a id="pickerbuild"></a>
- **Kind:** method (widget build) of `_ServicePickerSheetState`
- **Source:** `lib/features/services/views/service_access_path_page.dart` (line 1724)
- **Purpose:** Render the searchable service picker.
- **Inputs:** `context`. **Returns:** The widget tree. **Side effects:** None.
- **Algorithm:** Filter by the search text (service name, device name, ports); sort by device,
  then name; show the suggested services first under their own heading and the others after,
  grouped by device when nothing is suggested. Tapping a row pops its service.
- **Usage:** `_showServicePicker`.
- **Notes:** Opens at `sheetInitialSize(window height, preferred: 0.82)`, capped at
  `sheetMaxSize`, like the service template picker.
