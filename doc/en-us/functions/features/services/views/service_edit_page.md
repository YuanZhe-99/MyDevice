# lib/features/services/views/service_edit_page.dart

Flutter view for creating/editing a single `ServiceNode` (the manual service-inventory
entry described in [Services and Topology](../../../../features/services-topology.md)).
It hosts the add/edit form (name, device, kind, runtime, state, endpoints list, notes,
Docker Compose text) plus a bottom-sheet template picker (`_ServiceTemplatePicker`) that
prefills fields from `service_template_service.dart` templates — matching the
manual-inventory-only constraint (templates only prefill; they never perform discovery).
Persistence goes through `ServiceStorage.addOrUpdateService`/`deleteService`
(`lib/features/services/services/service_storage.dart`); the device picklist comes from
`DeviceStorage.load()` filtered to `device.isInService`. The page is pushed from
`lib/features/services/views/service_list_page.dart`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ServiceEditPage` constructor | constructor (`ServiceEditPage`) | B | Create a service edit page instance (optionally pre-bound to an existing service/device). |
| `createState` | method (`ServiceEditPage`) | B | Create the mutable state object for this widget. |
| [`_editing`](#editing) | getter (`_ServiceEditPageState`) | B | Report whether the page is editing an existing service vs. creating a new one. |
| `initState` | method (`_ServiceEditPageState`) | B | Seed controllers/fields from an existing service (or defaults) and kick off device loading. |
| `dispose` | method (`_ServiceEditPageState`) | B | Dispose the four text controllers. |
| [`_loadDevices`](#loaddevices) | method (`_ServiceEditPageState`) | A | Load the device list, restrict it to service-eligible devices, and pick a default. |
| [`_applyTemplate`](#applytemplate) | method (`_ServiceEditPageState`) | A | Apply a chosen `ServiceTemplate`'s fields/endpoints/Compose text onto the draft service. |
| `_templateName` | method (`_ServiceEditPageState`) | B | Resolve a template id to its display name for the picker button label. |
| `_pickTemplate` | method (`_ServiceEditPageState`) | B | Open the template picker bottom sheet and apply the chosen template. |
| [`_save`](#save) | method (`_ServiceEditPageState`) | A | Validate the form, build a `ServiceNode`, persist it, and close the page. |
| [`_delete`](#delete) | method (`_ServiceEditPageState`) | A | Confirm and delete the service being edited. |
| `_copyCompose` | method (`_ServiceEditPageState`) | B | Copy the Docker Compose text field to the clipboard and show a snackbar. |
| `_addEndpoint` | method (`_ServiceEditPageState`) | B | Open the endpoint dialog and append the result to the endpoints list. |
| `_editEndpoint` | method (`_ServiceEditPageState`) | B | Open the endpoint dialog pre-filled from an existing endpoint and replace it in place. |
| [`_showEndpointDialog`](#showendpointdialog) | method (`_ServiceEditPageState`) | A | Show the add/edit modal dialog for one `ServiceEndpoint` and build the result. |
| `build` | method (widget build, `_ServiceEditPageState`) | B | Render the service edit form (fields, endpoint cards, Compose editor, save/delete actions). |
| `_emptyToNull` | top-level function | B | Trim a string and convert an empty result to `null`. |
| `_ServiceTemplatePicker` constructor | constructor (`_ServiceTemplatePicker`) | B | Create a service template picker instance. |
| `createState` | method (`_ServiceTemplatePicker`) | B | Create the mutable state object for the template picker widget. |
| `dispose` | method (`_ServiceTemplatePickerState`) | B | Dispose the search text controller. |
| [`_filteredTemplates`](#filteredtemplates) | getter (`_ServiceTemplatePickerState`) | A | Filter templates by selected kind/search query and sort them (featured first, then kind, then name). |
| `build` | method (widget build, `_ServiceTemplatePickerState`) | B | Render the draggable template picker sheet (search field, kind chips, template list). |

## Documentation

### `bool get _editing` <a id="editing"></a>
- **Kind:** getter of `_ServiceEditPageState`
- **Source:** `lib/features/services/views/service_edit_page.dart` (line 53)
- **Purpose:** Report whether `widget.service` is non-null, i.e. whether the page is editing an existing service rather than creating a new one.
- **Inputs:** None.
- **Returns:** `bool` — `true` when `widget.service != null`.
- **Side effects:** None.
- **Algorithm:** Single expression: `widget.service != null`.
- **Usage:**
  ```dart
  title: Text(_editing ? l10n.editService : l10n.addService),
  ```
- **Notes:** Also gates the delete action button in the app bar.

### `Future<void> _loadDevices()` <a id="loaddevices"></a>
- **Kind:** method of `_ServiceEditPageState`
- **Source:** `lib/features/services/views/service_edit_page.dart` (line 97, called from `initState` at line 75)
- **Purpose:** Load all known devices and restrict the device picker to devices flagged for the Services feature, defaulting the selection.
- **Inputs:** None (reads `widget.service`/`widget.deviceId` indirectly via existing `_deviceId`).
- **Returns:** `Future<void>`.
- **Side effects:** Calls `DeviceStorage.load()` (local file-system I/O); calls `setState` to populate `_devices`, default `_deviceId`, and clear `_loading`.
- **Algorithm:**
  1. Await `DeviceStorage.load()`.
  2. Bail out if the widget was unmounted while awaiting.
  3. Filter the loaded devices to those where `device.isInService` is true.
  4. `setState`: store the filtered list in `_devices`; if `_deviceId` is still unset, default it to the first eligible device's id (`??=`); clear `_loading`.
- **Usage:**
  ```dart
  @override
  void initState() {
    super.initState();
    ...
    _loadDevices();
  }
  ```
- **Notes:** Devices not flagged `isInService` are excluded from the picker even if a service already references them (e.g. via `widget.deviceId`); the guard `if (!mounted) return` avoids `setState` after disposal.

### `void _applyTemplate(ServiceTemplate template)` <a id="applytemplate"></a>
- **Kind:** method of `_ServiceEditPageState`
- **Source:** `lib/features/services/views/service_edit_page.dart` (line 113)
- **Purpose:** Copy a chosen service template's name, icon, kind, runtime, endpoints, and (if present) Docker Compose text into the current draft, replacing the endpoint list.
- **Inputs:** `template` — the `ServiceTemplate` selected in the picker (from `service_template_service.dart`).
- **Returns:** `void`.
- **Side effects:** Calls `setState`; overwrites `_nameCtrl.text`, `_iconCtrl.text`, and (conditionally) `_composeCtrl.text`; replaces `_endpoints` entirely.
- **Algorithm:**
  1. Record `_templateId = template.id`.
  2. Overwrite the name field and icon (both the stored `_icon` and its text controller) from the template.
  3. Copy `template.kind` and `template.runtime`.
  4. Rebuild `_endpoints` as a fresh list of `ServiceEndpoint` objects cloned field-by-field from `template.endpoints` (new instances, not the template's own objects).
  5. If the template has non-empty `dockerCompose`, overwrite `_composeCtrl.text` with it; otherwise leave whatever the user already typed untouched.
- **Usage:**
  ```dart
  Future<void> _pickTemplate() async {
    final template = await showModalBottomSheet<ServiceTemplate>(...);
    if (template != null) _applyTemplate(template);
  }
  ```
- **Notes:** Applying a template always replaces the endpoint list wholesale (no merge with manually added endpoints); Compose text is only overwritten when the template actually supplies one, so switching to a template without Compose notes preserves existing text.

### `Future<void> _save()` <a id="save"></a>
- **Kind:** method of `_ServiceEditPageState`
- **Source:** `lib/features/services/views/service_edit_page.dart` (line 174)
- **Purpose:** Validate the form, assemble a `ServiceNode` from the current draft state, persist it, and close the page.
- **Inputs:** None (reads form/controller/field state).
- **Returns:** `Future<void>`.
- **Side effects:** Calls `ServiceStorage.addOrUpdateService` (local file-system I/O); on success, pops the route with result `true`.
- **Algorithm:**
  1. Run form validation (`_formKey.currentState!.validate()`); return early if invalid.
  2. Return early if no device is selected (`_deviceId == null`).
  3. Build a `ServiceNode`, reusing `existing?.id` (so edits update in place rather than creating a new record), `existing?.tags`, and `existing?.extraJson` unchanged; take name/kind/runtime/state/endpoints from the current draft fields; convert notes and Compose text through `_emptyToNull` so blank text is stored as `null` rather than an empty string.
  4. Await `ServiceStorage.addOrUpdateService(service)`.
  5. If still mounted, pop the page with `true` to signal the caller (`service_list_page.dart`) that data changed.
- **Usage:**
  ```dart
  IconButton(icon: const Icon(Icons.save), onPressed: _save),
  ```
- **Notes:** Only the name field has a form validator (`serviceNameRequired`); device selection is checked manually rather than through the `Form` validation chain. Endpoint list content itself is not re-validated here — validation for each endpoint happens when it is added/edited via `_showEndpointDialog`.

### `Future<void> _delete()` <a id="delete"></a>
- **Kind:** method of `_ServiceEditPageState`
- **Source:** `lib/features/services/views/service_edit_page.dart` (line 202)
- **Purpose:** Ask the user to confirm, then delete the service being edited.
- **Inputs:** None (uses `widget.service`).
- **Returns:** `Future<void>`.
- **Side effects:** Shows a confirmation `AlertDialog`; on confirm, calls `ServiceStorage.deleteService` (local file-system I/O) and pops the page with `true`.
- **Algorithm:**
  1. Return early if `widget.service` is null (nothing to delete — the delete button is only shown when `_editing`, so this is a defensive guard).
  2. Show an `AlertDialog` asking to confirm deletion of the named service, with Cancel/Delete actions returning `false`/`true`.
  3. If the user confirmed, await `ServiceStorage.deleteService(service.id)`, then pop the page with `true` if still mounted.
- **Usage:**
  ```dart
  if (_editing)
    IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
  ```
- **Notes:** Deleting here only removes the `ServiceNode` record itself; any `ServiceRoute`s that reference this service's endpoints are not cleaned up by this method (out of scope for this file).

### `Future<ServiceEndpoint?> _showEndpointDialog({ServiceEndpoint? initial})` <a id="showendpointdialog"></a>
- **Kind:** method of `_ServiceEditPageState`
- **Source:** `lib/features/services/views/service_edit_page.dart` (line 269)
- **Purpose:** Show a modal dialog for creating or editing one `ServiceEndpoint` (label, protocol, transport, port/port-end, bind address, path, scope, primary flag) and return the resulting object.
- **Inputs:** `initial` — an existing `ServiceEndpoint` to prefill for editing, or `null` to create a new one.
- **Returns:** `Future<ServiceEndpoint?>` — the built endpoint if the user tapped Save, or `null` if cancelled/dismissed.
- **Side effects:** Shows an `AlertDialog` via `showDialog`; disposes its local text controllers after the dialog closes.
- **Algorithm:**
  1. Seed local `TextEditingController`s and dropdown state (`protocol`, `transport`, `scope`) from `initial`, or defaults (`ServiceProtocol.http`, `ServiceTransport.tcp`, `ServiceScope.lan`).
  2. Default `primary` to `initial?.isPrimary`, or — for a brand-new endpoint — `true` if this would be the first endpoint in `_endpoints` (`_endpoints.isEmpty`), so the first endpoint added is auto-marked primary.
  3. Build a `StatefulBuilder`-backed `AlertDialog` with fields for label, protocol, transport, port/port-end (numeric), bind address, path, scope, and a primary checkbox, each updating local dialog state via `setDialogState`.
  4. On Save, pop the dialog with a new `ServiceEndpoint` built from the current dialog state: `label`/`bindAddress`/`path` pass through `_emptyToNull`; `port`/`portEnd` are parsed with `int.tryParse` (invalid/empty text becomes `null`); `extraJson` is carried over unchanged from `initial`.
  5. Dispose all five local controllers regardless of outcome, then return the dialog result.
- **Usage:**
  ```dart
  Future<void> _addEndpoint() async {
    final endpoint = await _showEndpointDialog();
    if (endpoint != null) setState(() => _endpoints.add(endpoint));
  }
  ```
- **Notes:** Port fields accept free-form text and silently fall back to `null` on unparsable input (no inline error is shown for a bad port); the "first endpoint defaults to primary" rule only applies when adding a brand-new endpoint (`initial == null`), not when editing.

### `List<ServiceTemplate> get _filteredTemplates` <a id="filteredtemplates"></a>
- **Kind:** getter of `_ServiceTemplatePickerState`
- **Source:** `lib/features/services/views/service_edit_page.dart` (line 702)
- **Purpose:** Compute the template list to show in the picker, filtered by the selected kind and search text, sorted with featured templates first.
- **Inputs:** None (reads `_searchCtrl.text` and `_kind`).
- **Returns:** `List<ServiceTemplate>`.
- **Side effects:** None (calls `ServiceTemplateService.loadTemplates()`, which is a pure read of the built-in template catalog).
- **Algorithm:**
  1. Lower-case and trim the search query.
  2. Load all templates and keep those where `_kind` is unset or matches `template.kind`, **and** the query is empty or matches the template's name, id, or any tag (case-insensitively).
  3. Sort the filtered list: featured templates (`template.featured`) sort before non-featured; ties broken by `kind.index`, then by case-insensitive name.
- **Usage:**
  ```dart
  itemCount: _filteredTemplates.length + 1,
  itemBuilder: (context, index) {
    ...
    final template = _filteredTemplates[index - 1];
  ```
- **Notes:** This getter re-filters and re-sorts on every access (including every `itemBuilder` call in the list), which is acceptable given the small, in-memory template catalog described in [Services and Topology](../../../../features/services-topology.md#service-templates).
