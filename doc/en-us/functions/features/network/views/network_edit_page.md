# lib/features/network/views/network_edit_page.dart

The add/edit form for a single [`Network`](../models/network.md#network-new) — name, type
dropdown, subnet/gateway/DNS/notes fields. Reused for both "add" (`network: null`) and "edit"
(`network: existing`) via one constructor parameter, matching the shape of every other feature's
edit page in this app. Saves through
[`NetworkStorage.addOrUpdateNetwork`](../services/network_storage.md#addorupdatenetwork). See
[Networks](../../../../features/networks.md) for the model this page edits.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `NetworkEditPage` (constructor) | constructor | B | Create the page widget (optional `network` to edit). |
| `createState` | method (`NetworkEditPage`) | B | Create the page's mutable state object. |
| `_isEditing` | getter (`_NetworkEditPageState`) | B | Return whether an existing `Network` was passed in. |
| `initState` | method (widget lifecycle) | B | Seed text controllers and the type dropdown from `widget.network`. |
| `dispose` | method (widget lifecycle) | B | Dispose the five text controllers. |
| `_nonEmpty` | method (`_NetworkEditPageState`) | B | Trim a field's text, returning `null` if it's blank. |
| `_typeLabel` | method (`_NetworkEditPageState`) | B | Map a `NetworkType` to its localized label. |
| [`_save`](#save) | method (`_NetworkEditPageState`) | A | Validate the form, build a `Network`, persist it, and pop. |
| `build` | method (widget) | B | Build the scaffold: name/type/subnet/gateway/DNS/notes form fields in a column capped at `formMaxWidth` (600) and centred — width only, so a phone is unchanged. |

Row count (9) matches `grep -c 'Purpose:' network_edit_page.dart` (9) exactly.

## Documentation

### `Future<void> _save()` <a id="save"></a>
- **Kind:** method of `_NetworkEditPageState`.
- **Source:** `lib/features/network/views/network_edit_page.dart` (line 102).
- **Purpose:** Validate the form, build a `Network` from the current field values, persist it, and
  close the page.
- **Inputs:** None (reads the form's `TextEditingController`s and `_type`).
- **Returns:** `Future<void>`.
- **Side effects:** Calls `NetworkStorage.addOrUpdateNetwork` (writes `network_data.json`); calls
  `AutoSyncService.instance.notifySaved()`; pops the page if still mounted.
- **Algorithm:** 1. Validate the form via `_formKey`; return early if invalid. 2. Split the DNS
  field's raw text on any run of commas/semicolons/whitespace (`RegExp(r'[,;\s]+')`) into a list of
  non-empty server strings, or `[]` if the field is blank. 3. Construct a `Network`, reusing
  `widget.network?.id` (preserving identity on edit, minting a new UUID on add — see
  [`Network`](../models/network.md#network-new)), trimming `name`, and passing `subnet`/`gateway`/
  `notes` through [`_nonEmpty`](#save) so a blank field persists as `null` rather than an empty
  string. 4. Await `NetworkStorage.addOrUpdateNetwork(network)`. 5. Call
  `AutoSyncService.instance.notifySaved()` (in addition to the notification `save()` already does
  internally — see [`network_storage.md#save`](../services/network_storage.md)). 6. Pop the
  navigator if the widget is still mounted.
- **Usage:** Wired as the app bar's Save `TextButton.onPressed` in `build`.
- **Notes:** The DNS split regex accepts commas, semicolons, *or* whitespace as separators
  interchangeably, so a comma-separated list and a plain space-separated list of the same servers
  parse into an identical `List<String>`. `_nonEmpty`
  (see the Tier B row above) is what turns a blank subnet/gateway/notes field into `null` in the
  persisted `Network` rather than an empty string — this matters because
  [`Network.toJson`](../models/network.md#network-tojson) omits `null` fields from the written JSON
  entirely, but would still write an empty-string field.
