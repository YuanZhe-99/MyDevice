# lib/features/services/views/service_endpoint_dialog.dart

The endpoint editor dialog (`_ServiceEndpointDialog`) shared by the service edit page
([service_edit_page.md](service_edit_page.md)) and the guided access-path page's inline
"Add endpoint". It edits one `ServiceEndpoint` — label, protocol, transport, port and port end,
bind address, path, scope and the primary flag — and returns the result without persisting it;
the caller decides whether to keep the endpoint in a form or save it straight away.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`showServiceEndpointDialog`](#showserviceendpointdialog) | top-level function | A | Show the endpoint dialog and return what the user saved. |
| `_ServiceEndpointDialog` constructor | constructor (`_ServiceEndpointDialog`) | B | The dialog widget (initial endpoint, default primary flag). |
| `createState` | method (`_ServiceEndpointDialog`) | B | Create the dialog state. |
| `initState` | method (`_ServiceEndpointDialogState`) | B | Seed the five controllers and the dropdowns from the initial endpoint or the defaults. |
| `dispose` | method (`_ServiceEndpointDialogState`) | B | Dispose the controllers — after the closing animation. |
| `_submit` | method (`_ServiceEndpointDialogState`) | B | Pop the endpoint the fields describe. |
| `build` | method (widget build, `_ServiceEndpointDialogState`) | B | The endpoint form: label, protocol, transport, ports, bind address, path, scope, primary. |
| `_emptyToNull` | top-level function | B | Trim a field value and turn an empty result into null. |

## Documentation

### `Future<ServiceEndpoint?> showServiceEndpointDialog(BuildContext context, {ServiceEndpoint? initial, required bool defaultPrimary})` <a id="showserviceendpointdialog"></a>
- **Kind:** top-level function
- **Source:** `lib/features/services/views/service_endpoint_dialog.dart` (line 18)
- **Purpose:** Show a modal dialog for creating or editing one `ServiceEndpoint` and return it.
- **Inputs:** `context`; `initial` — the endpoint to edit, or null to add one; `defaultPrimary` —
  whether a new endpoint starts with the primary box ticked.
- **Returns:** `Future<ServiceEndpoint?>` — the built endpoint after Save, or null when the user
  cancels or dismisses the dialog.
- **Side effects:** Shows the dialog. Nothing is written to storage.
- **Algorithm:**
  1. `showDialog` with `_ServiceEndpointDialog`, which seeds its text controllers and the
     protocol / transport / scope dropdowns from `initial`, or from the defaults `http`, `tcp`
     and `lan`, and starts the primary checkbox at `initial?.isPrimary ?? defaultPrimary`.
  2. On Save (`_submit`), the dialog pops a `ServiceEndpoint` that keeps `initial`'s id and
     `extraJson`; blank label, bind address and path become null through `_emptyToNull`, and
     the ports parse with `int.tryParse` (unparsable text becomes null).
  3. The dialog state disposes its five controllers in its own `dispose`, once the route is
     gone.
- **Usage:**
  ```dart
  final endpoint = await showServiceEndpointDialog(
    context,
    defaultPrimary: _endpoints.isEmpty,
  );
  if (endpoint != null) setState(() => _endpoints.add(endpoint));
  ```
- **Notes:** Moved from the service edit page's private `_showEndpointDialog` in 1.5.6. Two
  things changed: the "first endpoint defaults to primary" decision is now the caller's
  `defaultPrimary`, since the guided page adds endpoints to services it does not hold in a form;
  and the dialog became its own stateful widget, because the old code disposed the controllers
  as soon as `showDialog` returned — while the closing animation still rebuilt the fields, which
  asserts in debug builds.
