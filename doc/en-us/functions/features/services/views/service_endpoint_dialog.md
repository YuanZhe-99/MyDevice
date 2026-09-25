# lib/features/services/views/service_endpoint_dialog.dart

The endpoint editor dialog shared by the service edit page
([service_edit_page.md](service_edit_page.md)) and the guided access-path page's inline
"Add endpoint". It edits one `ServiceEndpoint` — label, protocol, transport, port and port end,
bind address, path, scope and the primary flag — and returns the result without persisting it;
the caller decides whether to keep the endpoint in a form or save it straight away.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`showServiceEndpointDialog`](#showserviceendpointdialog) | top-level function | A | Show the endpoint dialog and return what the user saved. |
| `_emptyToNull` | top-level function | B | Trim a field value and turn an empty result into null. |

## Documentation

### `Future<ServiceEndpoint?> showServiceEndpointDialog(BuildContext context, {ServiceEndpoint? initial, required bool defaultPrimary})` <a id="showserviceendpointdialog"></a>
- **Kind:** top-level function
- **Source:** `lib/features/services/views/service_endpoint_dialog.dart` (line 14)
- **Purpose:** Show a modal dialog for creating or editing one `ServiceEndpoint` and return it.
- **Inputs:** `context`; `initial` — the endpoint to edit, or null to add one; `defaultPrimary` —
  whether a new endpoint starts with the primary box ticked.
- **Returns:** `Future<ServiceEndpoint?>` — the built endpoint after Save, or null when the user
  cancels or dismisses the dialog.
- **Side effects:** Shows an `AlertDialog`; disposes its five text controllers once it closes.
  Nothing is written to storage.
- **Algorithm:**
  1. Seed the text controllers and the protocol / transport / scope dropdowns from `initial`,
     or from the defaults `http`, `tcp` and `lan`.
  2. Start the primary checkbox at `initial?.isPrimary ?? defaultPrimary`.
  3. On Save, pop a `ServiceEndpoint` that keeps `initial`'s id and `extraJson`; blank label,
     bind address and path become null through `_emptyToNull`, and the ports parse with
     `int.tryParse` (unparsable text becomes null).
- **Usage:**
  ```dart
  final endpoint = await showServiceEndpointDialog(
    context,
    defaultPrimary: _endpoints.isEmpty,
  );
  if (endpoint != null) setState(() => _endpoints.add(endpoint));
  ```
- **Notes:** Moved unchanged from the service edit page's private `_showEndpointDialog` in 1.5.6;
  the only difference is that the "first endpoint defaults to primary" decision is now the
  caller's `defaultPrimary`, since the guided page adds endpoints to services it does not hold in
  a form.
