# lib/features/services/views/service_route_edit_page.dart

Flutter view implementing the **advanced multi-hop route editor** described in
[Services and Topology](../../../../features/services-topology.md#quick-access-route-creation-vs-the-advanced-editor)
— as opposed to the default quick access-route creation flow, this page lets a user
build/reorder an arbitrary ordered list of `ServiceRouteHop`s from a source service
endpoint to one or more final targets. It reads/writes `ServiceRoute` records through
`ServiceStorage.load`/`addOrUpdateRoute`/`deleteRoute`
(`lib/features/services/services/service_storage.dart`) and delegates route-naming and
multi-target parsing to helpers in `service_analysis.dart`
(`serviceRouteGeneratedName`, `serviceRouteAccessTargets`,
`serviceRouteExtraJsonWithTargets`, `compactAccessTargetLabel`) — route names are
generated internally and hidden from the user, matching the concept doc's statement that
user-facing descriptions belong in `notes` instead. The page is pushed from
`lib/features/services/views/service_list_page.dart`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ServiceRouteEditPage` constructor | constructor (`ServiceRouteEditPage`) | B | Create a service route edit page instance (optionally pre-bound to an existing route/source service). |
| `createState` | method (`ServiceRouteEditPage`) | B | Create the mutable state object for this widget. |
| [`_editing`](#editing) | getter (`_ServiceRouteEditPageState`) | B | Report whether the page is editing an existing route vs. creating a new one. |
| `initState` | method (`_ServiceRouteEditPageState`) | B | Seed controllers/fields from an existing route (or defaults) and kick off service loading. |
| `dispose` | method (`_ServiceRouteEditPageState`) | B | Dispose the final-URL and notes text controllers. |
| [`_load`](#load) | method (`_ServiceRouteEditPageState`) | A | Load all services and default the source service/endpoint selection. |
| `_selectedSource` | getter (`_ServiceRouteEditPageState`) | B | Look up the currently selected source `ServiceNode` by id. |
| `_selectedEndpoint` | getter (`_ServiceRouteEditPageState`) | B | Look up the currently selected source `ServiceEndpoint` by id. |
| [`_save`](#save) | method (`_ServiceRouteEditPageState`) | A | Validate the form, build a `ServiceRoute` (with a generated name and parsed targets), persist it, and close the page. |
| [`_delete`](#delete) | method (`_ServiceRouteEditPageState`) | A | Confirm and delete the route being edited. |
| `_addHop` | method (`_ServiceRouteEditPageState`) | B | Open the hop dialog and append the result to the hops list. |
| `_editHop` | method (`_ServiceRouteEditPageState`) | B | Open the hop dialog pre-filled from an existing hop and replace it in place. |
| [`_showHopDialog`](#showhopdialog) | method (`_ServiceRouteEditPageState`) | A | Show the add/edit modal dialog for one `ServiceRouteHop` and build the result. |
| `build` | method (widget build, `_ServiceRouteEditPageState`) | B | Render the scaffold (save/delete actions) around `_buildFormBody`. |
| `_buildFormBody` | method (widget helper) | B | Choose the layout inside the one `Form`: a single `ListView` of both halves, or — when `useDetailTwoPane` passes — a `Row` of an `editFormLeftPaneWidth`-wide scrolling source pane and a right `ListView` of the hops. Both panes scroll. |
| `_buildSourceFields` | method (widget helper) | B | Source/endpoint pickers, access level, targets field and the preview card — extracted from `build` unchanged. |
| `_buildHopFields` | method (widget helper) | B | The hop list, notes and the save button — extracted from `build` unchanged. |
| [`_hopTitle`](#hoptitle) | method (`_ServiceRouteEditPageState`) | A | Compute the display title for one hop, preferring its linked service name, then label, then host, then hop type. |
| [`_hopSubtitle`](#hopsubtitle) | method (`_ServiceRouteEditPageState`) | A | Compose the multi-part subtitle line for one hop (type, method, endpoint, host/scheme/port/path, notes). |
| `_hopEndpoint` | method (`_ServiceRouteEditPageState`) | B | Look up the `ServiceEndpoint` a hop references, if any. |
| `_moveHop` | method (`_ServiceRouteEditPageState`) | B | Reorder the hops list by moving one hop from one index to another. |
| [`_routePreview`](#routepreview) | method (`_ServiceRouteEditPageState`) | A | Build the human-readable "source -> hop -> ... -> target" preview string shown above the hop list. |
| [`_splitTargets`](#splittargets) | top-level function | A | Parse the multi-line/comma-separated final-URL text field into a list of individual target strings. |
| `_emptyToNull` | top-level function | B | Trim a string and convert an empty result to `null`. |

## Documentation

### `bool get _editing` <a id="editing"></a>
- **Kind:** getter of `_ServiceRouteEditPageState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 44)
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
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 85, called from `initState` at line 65)
- **Purpose:** Load all services (for the source-service dropdown and hop-service pickers) and default the selected source service/endpoint if not already set.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `ServiceStorage.load()` (local file-system I/O); calls `setState` to populate `_services`, default `_sourceServiceId`/`_sourceEndpointId`, and clear `_loading`.
- **Algorithm:**
  1. Await `ServiceStorage.load()`.
  2. Bail out if the widget was unmounted while awaiting.
  3. `setState`: store `data.services` in `_services`; if `_sourceServiceId` is still unset, default it to the first loaded service's id (`??=`); if `_sourceEndpointId` is still unset, default it to the newly-resolved source service's first endpoint id; clear `_loading`.
- **Usage:**
  ```dart
  @override
  void initState() {
    super.initState();
    ...
    _load();
  }
  ```
- **Notes:** The endpoint default is resolved after the source-service default is applied (both inside the same `setState` callback), so a brand-new route defaults to "first service, first endpoint of that service" if `widget.sourceService` was not supplied.

### `Future<void> _save()` <a id="save"></a>
- **Kind:** method of `_ServiceRouteEditPageState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 125)
- **Purpose:** Validate the form, assemble a `ServiceRoute` (with an internally generated name and parsed target list) from the current draft state, persist it, and close the page.
- **Inputs:** None (reads form/controller/field state).
- **Returns:** `Future<void>`.
- **Side effects:** Calls `ServiceStorage.addOrUpdateRoute` (local file-system I/O); on success, pops the route with result `true`.
- **Algorithm:**
  1. Run form validation; return early if invalid. Return early if `_sourceServiceId` is null.
  2. Parse the final-URL text field into a list of `targets` via [`_splitTargets`](#splittargets).
  3. Build a `ServiceRoute`, reusing `existing?.id` for in-place edits. The route `name` is generated via `serviceRouteGeneratedName(sourceName: ..., hops: _hops, targets: targets)` — never user-typed. `finalUrl` is set to `targets.firstOrNull` (first target only, for backward compatibility). `extraJson` is rebuilt via `serviceRouteExtraJsonWithTargets(existing?.extraJson ?? const {}, targets)`, which stores the full target list (grouped public targets, per [Services and Topology](../../../../features/services-topology.md)).
  4. Await `ServiceStorage.addOrUpdateRoute(route)`.
  5. If still mounted, pop the page with `true`.
- **Usage:**
  ```dart
  IconButton(icon: const Icon(Icons.save), onPressed: _save),
  ```
- **Notes:** Unlike `service_edit_page.dart`'s `_save`, this method has no field-level `Form` validator on the target/name inputs visible in this file — the only explicit guard is `_sourceServiceId == null`; route naming and target-list bookkeeping are fully delegated to `service_analysis.dart` helpers rather than implemented inline here.

### `Future<void> _delete()` <a id="delete"></a>
- **Kind:** method of `_ServiceRouteEditPageState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 158)
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
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 210)
- **Purpose:** Show a modal dialog for creating or editing one `ServiceRouteHop` (type, method, optional linked service/endpoint, label, scheme/host/port/path, notes) and return the resulting object.
- **Inputs:** `initial` — an existing `ServiceRouteHop` to prefill for editing, or `null` to create a new one.
- **Returns:** `Future<ServiceRouteHop?>` — the built hop if Save was tapped, or `null` if cancelled/dismissed.
- **Side effects:** Shows an `AlertDialog` via `showDialog`; disposes its six local text controllers after the dialog closes.
- **Algorithm:**
  1. Seed local controllers/state from `initial` (or blank/defaults: `ServiceRouteHopType.manual`, no method, no linked service/endpoint).
  2. Build a `StatefulBuilder`-backed `AlertDialog` with: hop-type dropdown, optional route-method dropdown, a "linked service" dropdown (`null` = manual/free-form hop) whose `onChanged` also resets `endpointId` to the newly-selected service's first endpoint, a conditional endpoint dropdown (only shown when a service is linked), and free-form label/scheme/port/host/path/notes fields.
  3. On Save, pop the dialog with a new `ServiceRouteHop` built from dialog state: text fields pass through `_emptyToNull`; `port` is parsed with `int.tryParse`; `serviceId`/`endpointId`/`method` are taken as-is; `extraJson` carries over from `initial`.
  4. Dispose all six local controllers regardless of outcome, then return the dialog result.
- **Usage:**
  ```dart
  Future<void> _addHop() async {
    final hop = await _showHopDialog();
    if (hop != null) setState(() => _hops.add(hop));
  }
  ```
- **Notes:** Selecting a different linked service resets `endpointId` to that service's first endpoint (or `null` if it has none) rather than leaving a stale endpoint id from the previous selection; a hop can mix a linked service/endpoint with free-form `label`/`scheme`/`host`/`port`/`path` fields simultaneously — the dialog does not enforce that they be mutually exclusive.

### `String _hopTitle(ServiceRouteHop hop)` <a id="hoptitle"></a>
- **Kind:** method of `_ServiceRouteEditPageState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 603)
- **Purpose:** Pick the best available display title for a hop: the linked service's name if resolvable, else the hop's own label, else its host, else its type name.
- **Inputs:** `hop` — the `ServiceRouteHop` to title.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:**
  1. If `hop.serviceId` is set, look it up in `_services`; if found, return that service's `name`.
  2. Otherwise, if `hop.label` is set and non-empty, return it.
  3. Otherwise, if `hop.host` is set and non-empty, return it.
  4. Otherwise, fall back to `hop.type.name` (e.g. `manual`, `reverseProxy`).
- **Usage:**
  ```dart
  title: Text(_hopTitle(_hops[i])),
  ```
  and reused inside [`_routePreview`](#routepreview): `..._hops.map(_hopTitle),`
- **Notes:** A hop whose linked service was later deleted from storage silently falls through to the label/host/type fallback chain rather than erroring, since the `.where(...).firstOrNull` lookup simply returns nothing.

### `String _hopSubtitle(ServiceRouteHop hop)` <a id="hopsubtitle"></a>
- **Kind:** method of `_ServiceRouteEditPageState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 618)
- **Purpose:** Build the secondary detail line for a hop's list card, combining its type, method, linked endpoint (if any), free-form host/scheme/port/path, and notes.
- **Inputs:** `hop` — the `ServiceRouteHop` to describe.
- **Returns:** `String` — the parts joined with `' · '`, omitting any empty/null parts.
- **Side effects:** None (calls the sibling `_hopEndpoint` lookup).
- **Algorithm:**
  1. Resolve the hop's linked endpoint via `_hopEndpoint(hop)`.
  2. Assemble a list of candidate strings: `hop.type.name`; `hop.method?.name`; if an endpoint was resolved, `'<protocol>/<portText>'`; if `hop.host` is set, a formatted `scheme://host:port/path` string built only from the parts that are present; `hop.notes`.
  3. Filter to non-null, non-empty strings and join with `' · '`.
- **Usage:**
  ```dart
  subtitle: Text(_hopSubtitle(_hops[i])),
  ```
- **Notes:** The host-based string is built independently of the linked-endpoint string, so a hop can show both an endpoint summary and a separate host/scheme/port/path summary at once if both are populated.

### `String _routePreview()` <a id="routepreview"></a>
- **Kind:** method of `_ServiceRouteEditPageState`
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 660)
- **Purpose:** Build the one-line "source -> hop -> ... -> target" preview shown in the card above the hop list, reflecting the full route chain as currently drafted.
- **Inputs:** None (reads `_selectedSource`, `_selectedEndpoint`, `_hops`, and the final-URL text field).
- **Returns:** `String` — the arrow-joined chain, or `'-'` if there is nothing to show yet.
- **Side effects:** None.
- **Algorithm:**
  1. Start the parts list with the source: if a source service is selected, use `'<name> <portText>'` when a source endpoint with a port is also selected, else just the service name.
  2. Append the title of every hop (via [`_hopTitle`](#hoptitle), in order).
  3. Append every parsed target from the final-URL field (via [`_splitTargets`](#splittargets)), each rendered through `compactAccessTargetLabel` (from `service_analysis.dart`).
  4. Join all parts with `' -> '`, or return `'-'` if the combined list is empty.
- **Usage:**
  ```dart
  Text(_routePreview()),
  ```
- **Notes:** This recomputes on every `build()` (the final-URL field's `onChanged` calls bare `setState(() {})`), so the preview always reflects unsaved edits, including hops not yet persisted.

### `List<String> _splitTargets(String value)` <a id="splittargets"></a>
- **Kind:** top-level function
- **Source:** `lib/features/services/views/service_route_edit_page.dart` (line 680)
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
  used in [`_save`](#save) to build both `finalUrl` and the `extraJson` grouped-targets payload, and in [`_routePreview`](#routepreview) to render the target chain.
- **Notes:** This is the parsing side of the "grouped public targets" feature described in [Services and Topology](../../../../features/services-topology.md) — a single route can list several domains/URLs for the same access path, entered one per line or comma-separated in one text field.
