# lib/features/services/views/service_route_edit_page.dart

Flutter view implementing the **advanced multi-hop route editor** described in
[Services and Topology](../../../../features/services-topology.md#adding-an-access-path)
— as opposed to the guided access-path page
([`service_access_path_page.md`](service_access_path_page.md)), this page lets a user
build/reorder an arbitrary ordered list of `ServiceRouteHop`s from a source service
endpoint to one or more final targets. It accepts an unsaved route handed over by the guided
page (`draft:`), writes or clears the route's topology-lane override from its **Topology lane**
dropdown, and offers **Guided editor** whenever the form fits an access pattern. It reads/writes `ServiceRoute` records through
`ServiceStorage.load`/`addOrUpdateRoute`/`deleteRoute`
(`lib/features/services/services/service_storage.dart`) and delegates route-naming and
multi-target parsing to helpers in `service_analysis.dart`
(`serviceRouteGeneratedName`, `serviceRouteAccessTargets`,
`serviceRouteExtraJsonWithTargets`, `serviceRouteExtraJsonWithAccessLane`) — route names are
generated internally and hidden from the user, matching the concept doc's statement that
user-facing descriptions belong in `notes` instead. Hop types, route methods and access levels
are shown through the localized helpers in [service_labels.md](../services/service_labels.md)
(`serviceHopTypeLabel`, `serviceRouteMethodUiLabel`, `serviceAccessLevelLabel`) rather than raw
enum names; the saved values are the enums themselves, unchanged. The page is pushed from
`lib/features/services/views/service_list_page.dart` — for the topology's node details too,
through its `onEditRoute` callback — and from the guided page's hand-off.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ServiceRouteEditPage` constructor | constructor (`ServiceRouteEditPage`) | B | Create a service route edit page instance (optionally pre-bound to an existing route, a source service, or an unsaved `draft` route). |
| `createState` | method (`ServiceRouteEditPage`) | B | Create the mutable state object for this widget. |
| [`_editing`](#editing) | getter (`_ServiceRouteEditPageState`) | B | Report whether the page is editing an existing route vs. creating a new one. |
| `initState` | method (`_ServiceRouteEditPageState`) | B | Seed controllers/fields — and the lane override — from `widget.route ?? widget.draft` (or defaults) and kick off service loading. |
| `dispose` | method (`_ServiceRouteEditPageState`) | B | Dispose the final-URL and notes text controllers. |
| [`_load`](#load) | method (`_ServiceRouteEditPageState`) | A | Load all services, drop a source or endpoint that no longer exists, and default the selection. |
| `_selectedSource` | getter (`_ServiceRouteEditPageState`) | B | Look up the currently selected source `ServiceNode` by id. |
| `_selectedEndpoint` | getter (`_ServiceRouteEditPageState`) | B | Look up the currently selected source `ServiceEndpoint` by id. |
| [`_save`](#save) | method (`_ServiceRouteEditPageState`) | A | Validate the form, persist `_buildRoute()`, and close the page. |
| [`_buildRoute`](#buildroute) | method (`_ServiceRouteEditPageState`) | A | Build the route the form describes (generated name, targets, lane override). |
| [`_openGuidedEditor`](#openguidededitor) | method (`_ServiceRouteEditPageState`) | A | Hand the form state to the guided access-path page. |
| [`_delete`](#delete) | method (`_ServiceRouteEditPageState`) | A | Confirm and delete the route being edited. |
| `_addHop` | method (`_ServiceRouteEditPageState`) | B | Open the hop dialog and append the result to the hops list. |
| `_editHop` | method (`_ServiceRouteEditPageState`) | B | Open the hop dialog pre-filled from an existing hop and replace it in place. |
| [`_showHopDialog`](#showhopdialog) | method (`_ServiceRouteEditPageState`) | A | Show `_ServiceRouteHopDialog` and return the hop it pops. |
| `build` | method (widget build, `_ServiceRouteEditPageState`) | B | Render the scaffold (save/delete actions) around `_buildFormBody`. |
| `_buildFormBody` | method (widget helper) | B | Choose the layout inside the one `Form`: a single `ListView` of both halves, or — when `useDetailTwoPane` passes — a `Row` of an `editFormLeftPaneWidth`-wide scrolling source pane and a right `ListView` of the hops. Both panes scroll. |
| `_buildSourceFields` | method (widget helper) | B | Source/endpoint pickers, access level (localized labels), the topology-lane dropdown, targets field and the preview card with the guided-editor action. |
| `_buildHopFields` | method (widget helper) | B | The hop list, notes and the save button — extracted from `build` unchanged. |
| [`_hopTitle`](#hoptitle) | method (`_ServiceRouteEditPageState`) | A | Compute the display title for one hop, preferring its linked service name, then label, then host, then the localized hop type. |
| [`_hopSubtitle`](#hopsubtitle) | method (`_ServiceRouteEditPageState`) | A | Compose the multi-part subtitle line for one hop (localized type and method, endpoint, host/scheme/port/path, notes). |
| `_hopEndpoint` | method (`_ServiceRouteEditPageState`) | B | Look up the `ServiceEndpoint` a hop references, if any. |
| `_moveHop` | method (`_ServiceRouteEditPageState`) | B | Reorder the hops list by moving one hop from one index to another. |
| [`_routePreview`](#routepreview) | method (`_ServiceRouteEditPageState`) | A | Build the human-readable "source -> hop -> ... -> target" preview string through `serviceRouteChainPreview`. |
| [`_splitTargets`](#splittargets) | top-level function | A | Parse the multi-line/comma-separated final-URL text field into a list of individual target strings. |
| `_emptyToNull` | top-level function | B | Trim a string and convert an empty result to `null`. |
| `_ServiceRouteHopDialog` constructor | constructor (`_ServiceRouteHopDialog`) | B | The hop editor dialog (initial hop, services). |
| `createState` | method (`_ServiceRouteHopDialog`) | B | Create the dialog state. |
| `initState` | method (`_ServiceRouteHopDialogState`) | B | Seed the six controllers and the type/method/service/endpoint from the initial hop. |
| `dispose` | method (`_ServiceRouteHopDialogState`) | B | Dispose the controllers — after the closing animation. |
| `_submit` | method (`_ServiceRouteHopDialogState`) | B | Pop the hop the fields describe, keeping the initial id and `extraJson`. |
| [`build`](#hopdialogbuild) | method (widget build, `_ServiceRouteHopDialogState`) | A | The hop form; dangling service/endpoint ids stay selectable. |

## Documentation

### `bool get _editing` <a id="editing"></a>
- **Kind:** getter of `_ServiceRouteEditPageState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 59)
- **Purpose:** Report whether `widget.route` is non-null, i.e. whether the page is editing an existing route rather than creating a new one.
- **Inputs:** None.
- **Returns:** `bool` — `true` when `widget.route != null`.
- **Side effects:** None.
- **Algorithm:** Single expression: `widget.route != null`.
- **Usage:**
  ```dart
  title: Text(_editing ? l10n.editServiceRoute : l10n.addServiceRoute),
  ```
- **Notes:** Also gates the delete action button in the app bar.

### `Future<void> _load()` <a id="load"></a>
- **Kind:** method of `_ServiceRouteEditPageState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 101, called from `initState`)
- **Purpose:** Load all services (for the source-service dropdown and hop-service pickers) and make the source selection valid.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `ServiceStorage.load()` (local file-system I/O); calls `setState` to populate `_services`, fix up `_sourceServiceId`/`_sourceEndpointId`, and clear `_loading`.
- **Algorithm:**
  1. Await `ServiceStorage.load()`.
  2. Bail out if the widget was unmounted while awaiting.
  3. `setState`: store `data.services`; if the selected source is not among them (none chosen, a deleted service, or the empty id of a draft without a source), fall back to the first service and clear the endpoint; clear an endpoint id the source does not have; then default an unset endpoint to the source's first endpoint; clear `_loading`.
- **Usage:**
  ```dart
  @override
  void initState() {
    super.initState();
    ...
    _load();
  }
  ```
- **Notes:** The fix-ups keep the source and endpoint dropdowns' `initialValue` among their items, which they assert; before 1.5.6 a route whose source service had been deleted tripped that assert.

### `Future<void> _save()` <a id="save"></a>
- **Kind:** method of `_ServiceRouteEditPageState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 147)
- **Purpose:** Validate the form, persist the route it describes, and close the page.
- **Inputs:** None (reads form/controller/field state).
- **Returns:** `Future<void>`.
- **Side effects:** Calls `ServiceStorage.addOrUpdateRoute` (local file-system I/O); on success, pops the route with result `true`.
- **Algorithm:**
  1. Run form validation; return early if invalid. Return early if `_sourceServiceId` is null.
  2. Await `ServiceStorage.addOrUpdateRoute(_buildRoute())`.
  3. If still mounted, pop the page with `true`.
- **Usage:**
  ```dart
  IconButton(icon: const Icon(Icons.save), onPressed: _save),
  ```
- **Notes:** The only explicit guard is `_sourceServiceId == null`; route naming, target bookkeeping and the lane override live in [`_buildRoute`](#buildroute).

### `ServiceRoute _buildRoute()` <a id="buildroute"></a>
- **Kind:** method of `_ServiceRouteEditPageState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 162)
- **Purpose:** Build the route the form currently describes.
- **Inputs:** None (reads form/controller/field state).
- **Returns:** `ServiceRoute`.
- **Side effects:** None.
- **Algorithm:** Parse the targets field ([`_splitTargets`](#splittargets)); keep `widget.route`'s id when editing (a draft saves as a new route); generate the name with `serviceRouteGeneratedName`; set `finalUrl` to the first target; rebuild `extraJson` from the route's or the draft's own map through `serviceRouteExtraJsonWithTargets`, then `serviceRouteExtraJsonWithAccessLane` with the lane dropdown's value (*Auto* = null removes the override).
- **Usage:** `_save`, `_routePreview`, and the check that decides whether to offer the guided editor.
- **Notes:** An unknown source becomes the empty id, which `ServiceAccessDraft.fromRoute` rejects, so the guided action stays hidden until a source is chosen.

### `Future<void> _openGuidedEditor()` <a id="openguidededitor"></a>
- **Kind:** method of `_ServiceRouteEditPageState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 193)
- **Purpose:** Open the guided access-path page on the current form state.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Pushes [`ServiceAccessPathPage`](service_access_path_page.md); pops `true` when it saved or deleted.
- **Algorithm:** Build the route; read it with `ServiceAccessDraft.fromRoute` (return when it does not fit a pattern); push the page with `route:` when editing, so the id is kept, else with the draft; when it pops `true`, pop `true` too.
- **Usage:** The "Guided editor" button in the preview card, shown only while the form fits a pattern.
- **Notes:** Pushed on top rather than replacing this page, so the result still reaches whoever opened the editor.

### `Future<void> _delete()` <a id="delete"></a>
- **Kind:** method of `_ServiceRouteEditPageState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 212)
- **Purpose:** Ask the user to confirm, then delete the route being edited.
- **Inputs:** None (uses `widget.route`).
- **Returns:** `Future<void>`.
- **Side effects:** Shows a confirmation `AlertDialog`; on confirm, calls `ServiceStorage.deleteRoute` (local file-system I/O) and pops the page with `true`.
- **Algorithm:**
  1. Return early if `widget.route` is null (defensive — the delete button only shows when `_editing`).
  2. Show an `AlertDialog` confirming deletion of the route by name, with Cancel/Delete actions returning `false`/`true`.
  3. If confirmed, await `ServiceStorage.deleteRoute(route.id)`, then pop the page with `true` if still mounted.
- **Usage:**
  ```dart
  if (_editing)
    IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
  ```
- **Notes:** None beyond the mirror-image behavior of `service_edit_page.dart`'s `_delete`.

### `Future<ServiceRouteHop?> _showHopDialog({ServiceRouteHop? initial})` <a id="showhopdialog"></a>
- **Kind:** method of `_ServiceRouteEditPageState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 265)
- **Purpose:** Show the hop editor dialog and return the hop it pops.
- **Inputs:** `initial` — an existing `ServiceRouteHop` to edit, or `null` to create a new one.
- **Returns:** `Future<ServiceRouteHop?>` — the built hop if Save was tapped, or `null` if cancelled/dismissed.
- **Side effects:** Shows `_ServiceRouteHopDialog` via `showDialog`.
- **Algorithm:** `showDialog(builder: (_) => _ServiceRouteHopDialog(initial: initial, services: _services))`.
- **Usage:**
  ```dart
  Future<void> _addHop() async {
    final hop = await _showHopDialog();
    if (hop != null) setState(() => _hops.add(hop));
  }
  ```
- **Notes:** Before 1.5.6 the dialog was built inline and its six text controllers were disposed as soon as `showDialog` returned — while the dialog's exit animation was still rebuilding the fields, which asserts in debug builds. The dialog widget now owns and disposes them.

### `Widget build(BuildContext context)` (`_ServiceRouteHopDialogState`) <a id="hopdialogbuild"></a>
- **Kind:** method (widget build) of `_ServiceRouteHopDialogState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 733)
- **Purpose:** Render the hop form.
- **Inputs:** `context`. **Returns:** The widget tree. **Side effects:** None.
- **Algorithm:** An `AlertDialog` with the hop-type dropdown (`serviceHopTypeLabel`), the optional route-method dropdown (`serviceRouteMethodUiLabel`), the linked-service dropdown (`null` = manual hop; choosing a service resets the endpoint to its first endpoint), the endpoint dropdown when a service is linked, and label, scheme, port, host, path and notes fields. Save runs `_submit`.
- **Usage:** Built by `_showHopDialog`.
- **Notes:** A service or endpoint id the inventory no longer has stays selectable as its raw id, so opening such a hop neither asserts nor silently drops the reference. The dropdowns are `isExpanded`, so a long product or service name ellipsizes instead of overflowing a phone-width dialog. A hop can mix a linked service with free-form fields; the dialog does not force them apart.

### `String _hopTitle(ServiceRouteHop hop)` <a id="hoptitle"></a>
- **Kind:** method of `_ServiceRouteEditPageState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 557)
- **Purpose:** Pick the best available display title for a hop: the linked service's name if resolvable, else the hop's own label, else its host, else its localized type label.
- **Inputs:** `hop` — the `ServiceRouteHop` to title.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:**
  1. If `hop.serviceId` is set, look it up in `_services`; if found, return that service's `name`.
  2. Otherwise, if `hop.label` is set and non-empty, return it.
  3. Otherwise, if `hop.host` is set and non-empty, return it.
  4. Otherwise, fall back to `serviceHopTypeLabel(l10n, hop.type)` (e.g. "Manual", "Reverse proxy" in English).
- **Usage:**
  ```dart
  title: Text(_hopTitle(_hops[i])),
  ```
  (the hop list's card titles; the preview names hops through `serviceRouteChainPreview` since
  1.5.6 — see [`_routePreview`](#routepreview))
- **Notes:** A hop whose linked service was later deleted from storage silently falls through to the label/host/type fallback chain rather than erroring, since the `.where(...).firstOrNull` lookup simply returns nothing.

### `String _hopSubtitle(ServiceRouteHop hop)` <a id="hopsubtitle"></a>
- **Kind:** method of `_ServiceRouteEditPageState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 572)
- **Purpose:** Build the secondary detail line for a hop's list card, combining its type, method, linked endpoint (if any), free-form host/scheme/port/path, and notes.
- **Inputs:** `hop` — the `ServiceRouteHop` to describe.
- **Returns:** `String` — the parts joined with `' · '`, omitting any empty/null parts.
- **Side effects:** None (calls the sibling `_hopEndpoint` lookup).
- **Algorithm:**
  1. Resolve the hop's linked endpoint via `_hopEndpoint(hop)`.
  2. Assemble a list of candidate strings: `serviceHopTypeLabel(l10n, hop.type)`; the method through `serviceRouteMethodUiLabel` when set; if an endpoint was resolved, `'<protocol>/<portText>'`; if `hop.host` is set, a formatted `scheme://host:port/path` string built only from the parts that are present; `hop.notes`.
  3. Filter to non-null, non-empty strings and join with `' · '`.
- **Usage:**
  ```dart
  subtitle: Text(_hopSubtitle(_hops[i])),
  ```
- **Notes:** The host-based string is built independently of the linked-endpoint string, so a hop can show both an endpoint summary and a separate host/scheme/port/path summary at once if both are populated.

### `String _routePreview()` <a id="routepreview"></a>
- **Kind:** method of `_ServiceRouteEditPageState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 616)
- **Purpose:** Build the one-line "source -> hop -> ... -> target" preview shown in the card above the hop list.
- **Inputs:** None (reads the form through `_buildRoute`).
- **Returns:** `String` — the arrow-joined chain, or `'-'` if there is nothing to show yet.
- **Side effects:** None.
- **Algorithm:** `serviceRouteChainPreview(_buildRoute(), services: _services, hopFallback: (hop) => serviceHopFallbackLabel(l10n, hop))` — see [`service_analysis.md`](../services/service_analysis.md#serviceroutechainpreview).
- **Usage:**
  ```dart
  Text(_routePreview()),
  ```
- **Notes:** Shared with the guided page since 1.5.6, so both editors describe a route in the same words; a port-mapping hop also shows its public host and port. Recomputes on every `build()`, so the preview always reflects unsaved edits.

### `List<String> _splitTargets(String value)` <a id="splittargets"></a>
- **Kind:** top-level function
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 906)
- **Purpose:** Parse the raw text of the final-URL/targets field into a clean list of individual target strings, supporting one target per line or comma-separated targets.
- **Inputs:** `value` — the raw text from `_finalUrlCtrl`.
- **Returns:** `List<String>` — trimmed, non-empty targets in original order.
- **Side effects:** None.
- **Algorithm:**
  1. Split `value` on the regex `[\n,]+` (one or more newlines and/or commas, so consecutive separators collapse rather than producing empty entries).
  2. Trim each resulting piece.
  3. Drop any piece that is empty after trimming.
- **Usage:**
  ```dart
  final targets = _splitTargets(_finalUrlCtrl.text);
  ```
  used in [`_buildRoute`](#buildroute) to build both `finalUrl` and the `extraJson` grouped-targets payload, so [`_save`](#save) and [`_routePreview`](#routepreview) both read the parsed targets from the route it returns.
- **Notes:** This is the parsing side of the "grouped public targets" feature described in [Services and Topology](../../../../features/services-topology.md) — a single route can list several domains/URLs for the same access path, entered one per line or comma-separated in one text field.
