# lib/features/network/views/network_detail_page.dart

The detail screen for one [`Network`](../models/network.md#network-new): its info card, a
sortable/groupable list of assigned devices
([`NetworkDevice`](../models/network.md#networkdevice-new)), a map view of those devices (via
[`DeviceMapPage`](../../../shared/views/device_map_page.md)), and add/edit/remove flows for
assignments backed by [`NetworkStorage`](../services/network_storage.md). Edit/config dialogs
construct `NetworkDevice` values directly rather than through `copyWith`. See
[Networks](../../../../features/networks.md) for why `NetworkDevice` has no `id`/`modifiedAt` and
what that means for how [`setAssignment`](../services/network_storage.md#setassignment) matches an
existing assignment (by the `(networkId, deviceId)` pair, not an id).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `NetworkDetailPage` (constructor) | constructor | B | Create the page widget (required `networkId`). |
| `createState` | method (`NetworkDetailPage`) | B | Create the page's mutable state object. |
| [`initState`](#initstate) | method (widget lifecycle) | A | Kick off loading sort preferences, then the network/device/assignment data. |
| [`_loadSortPrefs`](#loadsortprefs) | method (`_NetworkDetailPageState`) | A | Load the persisted sort mode/direction/grouping/exit-first flags from device storage config. |
| [`_saveSortPrefs`](#savesortprefs) | method (`_NetworkDetailPageState`) | A | Persist those four sort-related flags to device storage config. |
| [`_compareIp`](#compareip) | method (`_NetworkDetailPageState`) | A | Compare two dotted-quad IP strings numerically, octet by octet. |
| [`_sortedAssignments`](#sortedassignments) | getter (`_NetworkDetailPageState`) | A | Sort/group/reorder `_assignments` per the current sort mode, direction, grouping, and exit-first settings. |
| `_categoryLabel` | method (`_NetworkDetailPageState`) | B | Map a `DeviceCategory` to its localized label. |
| `_sortModeLabel` | method (`_NetworkDetailPageState`) | B | Map a `NetworkDeviceSortMode` to its localized label. |
| [`_load`](#load) | method (`_NetworkDetailPageState`) | A | Reload the network, its assignments, and the full device list from storage. |
| `_findDevice` | method (`_NetworkDetailPageState`) | B | Look up a device by id in the loaded device list. |
| `_typeLabel` | method (`_NetworkDetailPageState`) | B | Map a `NetworkType` to its localized label. |
| `_addressModeLabel` | method (`_NetworkDetailPageState`) | B | Map an `AddressMode` to its localized label. |
| [`_deleteNetwork`](#deletenetwork) | method (`_NetworkDetailPageState`) | A | Confirm and, if accepted, delete this network and pop. |
| [`_addDevice`](#adddevice) | method (`_NetworkDetailPageState`) | A | Pick an unassigned device, configure its assignment, and persist it. |
| [`_editAssignment`](#editassignment) | method (`_NetworkDetailPageState`) | A | Re-open the assignment-configuration dialog for an existing assignment and persist changes. |
| [`_removeAssignment`](#removeassignment) | method (`_NetworkDetailPageState`) | A | Confirm and, if accepted, remove a device's assignment from this network. |
| [`_showAssignmentDialog`](#showassignmentdialog) | method (`_NetworkDetailPageState`) | A | Show the address-mode/IP/hostname/exit-node configuration dialog for one assignment. |
| `build` | method (widget) | B | Build the scaffold: app bar (map/edit/delete actions) around `_buildBody`. |
| `_buildBody` | method (widget helper) | B | Choose the layout: a single `ListView` (info card, then the devices header and list) unless `useDetailTwoPane` passes, in which case a `Row` of a `detailLeftPaneWidth`-wide scrolling info card and a right `ListView` of the devices children. |
| `_buildInfoCard` | method (widget helper) | B | The network info card (type logo, type, subnet, gateway, DNS, notes), extracted from `build` unchanged. |
| `_buildDevicesChildren` | method (widget helper) | B | The devices header row plus the assignment list or its empty-state card, extracted from `build` unchanged. |
| `_buildDeviceList` | method (widget helper) | B | Build the device-card list, inserting category headers when grouping is on. |
| `_buildDeviceCard` | method (widget helper) | B | Render one assignment's card (device name, mode/IP/hostname/exit-node subtitle, edit/remove menu). |
| `_infoRow` | method (widget helper) | B | Render one label/value row in the network info card. |
| `_DevicePicker` (constructor) | constructor | B | Store the list of unassigned devices for the picker sheet. |
| `_DevicePicker.build` | method (widget) | B | Render the bottom-sheet list of devices to pick from. |

Row count (24) matches `grep -c 'Purpose:' network_detail_page.dart` (24) exactly.

## Documentation

### `void initState()` <a id="initstate"></a>
- **Kind:** method of `_NetworkDetailPageState` (widget lifecycle override).
- **Source:** `lib/features/network/views/network_detail_page.dart` (line 48).
- **Purpose:** Kick off the initial preference load, then the network/assignment/device data load.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Starts an async load chain.
- **Algorithm:** Calls `super.initState()`, then chains `_loadSortPrefs().then((_) => _load())`.
- **Usage:** Invoked automatically by the Flutter framework when `_NetworkDetailPageState` is first
  inserted into the tree; no direct call site.
- **Notes:** Unlike the list pages in this app, this page has no `dispose()` override and does not
  register with `AutoSyncService` for local-data-change notifications — it only reloads explicitly,
  after its own add/edit/delete/remove actions (see each of those methods below) and after
  returning from the edit-network push in `build`.

### `Future<void> _loadSortPrefs()` <a id="loadsortprefs"></a>
- **Kind:** method of `_NetworkDetailPageState`.
- **Source:** `lib/features/network/views/network_detail_page.dart` (line 59).
- **Purpose:** Load the persisted sort mode, sort direction, category-grouping flag, and
  exit-node-first flag from device storage config, falling back to defaults.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads config via `DeviceStorage.readConfig()`; calls `setState`.
- **Algorithm:** Reads the config map; resolves `_sortMode` from `'netDetailSortMode'` against
  `NetworkDeviceSortMode.values` by `.name` (default `deviceOrder`); resolves
  `_sortAscending`/`_groupByCategory`/`_exitNodeFirst` from `'netDetailSortAscending'`/
  `'netDetailGroupByCategory'`/`'netDetailExitFirst'` (all default `false`); applies all four via
  one `setState`.
- **Usage:** Chained after construction in [`initState`](#initstate).
- **Notes:** These four config keys (`netDetailSortMode`, `netDetailSortAscending`,
  `netDetailGroupByCategory`, `netDetailExitFirst`) are distinct from `NetworkListPage`'s
  `networkSortMode`/`networkSortAscending` — the network list and each network's device list sort
  independently.

### `Future<void> _saveSortPrefs()` <a id="savesortprefs"></a>
- **Kind:** method of `_NetworkDetailPageState`.
- **Source:** `lib/features/network/views/network_detail_page.dart` (line 82).
- **Purpose:** Persist the current sort mode, direction, grouping flag, and exit-first flag back to
  device storage config.
- **Inputs:** None (reads the four corresponding state fields).
- **Returns:** `Future<void>`.
- **Side effects:** Reads then writes the config via `DeviceStorage.readConfig()`/`writeConfig()`.
- **Algorithm:** Reads the existing config map, overwrites all four keys, writes the whole map back.
- **Usage:** Called from the sort menu's `onSelected` handler in `build`, after each toggle mutates
  its state field.
- **Notes:** None.

### `int _compareIp(String? a, String? b)` <a id="compareip"></a>
- **Kind:** method of `_NetworkDetailPageState`.
- **Source:** `lib/features/network/views/network_detail_page.dart` (line 96).
- **Purpose:** Compare two dotted-quad IP address strings numerically (octet by octet), not
  lexicographically, so an address with a single-digit final octet correctly sorts before one with
  a two-digit final octet at the same prefix (plain string comparison would get this backwards).
- **Inputs:** `a`, `b` — nullable IP strings.
- **Returns:** `int` — standard comparator contract; nulls always sort last regardless of which
  side is null.
- **Side effects:** None.
- **Algorithm:** 1. If both are `null`, return `0`. 2. If only `a` is `null`, return `1` (sorts
  after); if only `b` is `null`, return `-1`. 3. Split each string on `'.'` and parse each part with
  `int.tryParse(s) ?? 0` (a malformed octet degrades to `0` rather than throwing). 4. Compare up to
  the first 4 parts pairwise, returning the first nonzero comparison. 5. If all compared parts are
  equal, fall back to a plain string `compareTo` on the original strings (a tie-breaker for
  addresses with fewer than 4 dotted parts, or otherwise identical numeric octets).
- **Usage:** Used as the `NetworkDeviceSortMode.ip` case's comparator inside
  [`_sortedAssignments`](#sortedassignments): `(a, b) => _compareIp(a.ipAddress, b.ipAddress)`.
- **Notes:** A malformed octet (non-numeric) silently becomes `0` for comparison purposes rather
  than being treated as "invalid" — this can place a malformed address earlier than it might
  intuitively belong, but it never throws.

### `List<NetworkDevice> get _sortedAssignments` <a id="sortedassignments"></a>
- **Kind:** getter of `_NetworkDetailPageState`.
- **Source:** `lib/features/network/views/network_detail_page.dart` (line 114).
- **Purpose:** Produce the final assignment list for display: sorted by the active
  `NetworkDeviceSortMode` and direction, optionally grouped by device category, optionally with
  exit-node assignments pulled to the front.
- **Inputs:** None (reads `_assignments`, `_sortMode`, `_sortAscending`, `_groupByCategory`,
  `_exitNodeFirst`, `_allDevices`).
- **Returns:** `List<NetworkDevice>` — a new list; `_assignments` itself is never mutated.
- **Side effects:** None.
- **Algorithm:** 1. Copy `_assignments` into `list`. 2. Build a `comparator` via a `switch` on
  `_sortMode`: `deviceOrder` compares each assignment's device's index in `_allDevices`;
  `alphabetical` compares device names (falling back to raw `deviceId` if the device is missing)
  case-insensitively; `ip` delegates to [`_compareIp`](#compareip). 3. Wrap the comparator to
  respect `_sortAscending` (swap argument order when ascending). 4. If `_groupByCategory`: sort by
  each assignment's device's `DeviceCategory.index` first (defaulting to `DeviceCategory.other` for
  a missing device), falling back to the effective comparator within each category group.
  Otherwise, sort the whole list by the effective comparator directly. 5. If `_exitNodeFirst`:
  partition the (already sorted) list into `isExitNode == true` and `false`, and concatenate exits
  first — this happens *after* the main sort/grouping, so exit nodes are pulled to the front as a
  whole block without disturbing the relative order established by steps 2–4 within each partition.
- **Usage:** Read at the top of `_buildDeviceList` (this file, line 641):
  `final sorted = _sortedAssignments;`.
- **Notes:** The exit-node-first partition is applied last and is independent of grouping — turning
  on both `_groupByCategory` and `_exitNodeFirst` still shows every exit node before every
  non-exit-node, category headers notwithstanding (i.e. `_exitNodeFirst` effectively overrides
  strict category grouping at the very top level of the list).

### `Future<void> _load()` <a id="load"></a>
- **Kind:** method of `_NetworkDetailPageState`.
- **Source:** `lib/features/network/views/network_detail_page.dart` (line 199).
- **Purpose:** Reload this network's own record, its device assignments, and the full device list
  (needed to resolve assignment `deviceId`s to names/categories).
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads via `NetworkStorage.load()` and `DeviceStorage.load()`; `setState` updates
  `_network`, `_assignments`, `_allDevices`.
- **Algorithm:** Awaits both loads, returns early if unmounted, then sets: `_network` to the entry
  in `netData.networks` whose `id == widget.networkId` (`null` if the network was deleted
  elsewhere); `_assignments` to every entry in `netData.assignments` whose `networkId ==
  widget.networkId`; `_allDevices` to the full device list.
- **Usage:** Called from [`initState`](#initstate) (after prefs load) and after every
  add/edit/delete/remove action in this file.
- **Notes:** If `_network` resolves to `null` (the network was deleted, e.g. from another device via
  sync, while this page was open), `build` shows a loading spinner indefinitely instead of an error
  state — there's no explicit "network not found" UI path.

### `Future<void> _deleteNetwork()` <a id="deletenetwork"></a>
- **Kind:** method of `_NetworkDetailPageState`.
- **Source:** `lib/features/network/views/network_detail_page.dart` (line 258).
- **Purpose:** Show a confirmation dialog, and if confirmed, delete this network and leave the
  page.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Shows an `AlertDialog`; on confirmation, calls
  `NetworkStorage.deleteNetwork(widget.networkId)`, `AutoSyncService.instance.notifySaved()`, and
  pops the page.
- **Algorithm:** 1. Shows an `AlertDialog` with Cancel/Delete, awaiting a `bool?`. 2. If `true`:
  awaits `NetworkStorage.deleteNetwork` (which also cascades to delete every assignment referencing
  this network — see
  [`network_storage.md#deletenetwork`](../services/network_storage.md)), calls
  `notifySaved()`, and pops if still mounted.
- **Usage:** Wired to the app bar's delete `IconButton.onPressed`.
- **Notes:** None.

### `Future<void> _addDevice()` <a id="adddevice"></a>
- **Kind:** method of `_NetworkDetailPageState`.
- **Source:** `lib/features/network/views/network_detail_page.dart` (line 289).
- **Purpose:** Let the user pick an in-service, not-yet-assigned device, configure its address
  mode/IP/hostname/exit-node flag, and persist the new assignment.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a modal bottom sheet (`_DevicePicker`, this file) and (if a device is
  picked) the assignment-configuration dialog; calls `NetworkStorage.setAssignment`,
  `AutoSyncService.instance.notifySaved()`, and reloads.
- **Algorithm:** 1. Compute `available` — every device that `isInService` and is not already in
  `_assignments` (by `deviceId`). 2. Return immediately if `available` is empty (no UI shown at all
  — the FAB/button click is a silent no-op in that case). 3. Show `_DevicePicker` in a modal bottom
  sheet, awaiting the picked `Device?`; return if `null` or unmounted. 4. Show
  [`_showAssignmentDialog`](#showassignmentdialog) seeded with a fresh `NetworkDevice(networkId:
  widget.networkId, deviceId: device.id)` (default `dhcp`, no IP/hostname, not an exit node),
  awaiting the configured `NetworkDevice?`. 5. If non-null: await
  `NetworkStorage.setAssignment(result)`, call `notifySaved()`, and reload.
- **Usage:** Wired to the "Add device" `TextButton.icon.onPressed` in `build`'s devices-header row.
- **Notes:** Because `available` excludes retired/sold devices (`isInService` check), a device that
  leaves service is not offered here even though its historical assignment (if any) may still exist
  from before — matching the cascade rule in
  [Devices](../../../../features/devices.md#cascade-rules-on-retiresell-delete), where leaving
  service actually removes any existing assignment via `DeviceStorage`'s own cleanup.

### `Future<void> _editAssignment(NetworkDevice assignment)` <a id="editassignment"></a>
- **Kind:** method of `_NetworkDetailPageState`.
- **Source:** `lib/features/network/views/network_detail_page.dart` (line 320).
- **Purpose:** Re-open the assignment-configuration dialog pre-filled with an existing assignment's
  values, and persist any changes.
- **Inputs:** `assignment` — the existing `NetworkDevice` to edit.
- **Returns:** `Future<void>`.
- **Side effects:** Shows [`_showAssignmentDialog`](#showassignmentdialog); if a result comes back,
  calls `NetworkStorage.setAssignment`, `AutoSyncService.instance.notifySaved()`, and reloads.
- **Algorithm:** Awaits `_showAssignmentDialog(l10n, assignment)`; if the result is non-null, awaits
  `NetworkStorage.setAssignment(result)` (matched and replaced by the `(networkId, deviceId)` pair —
  see [`network_storage.md#setassignment`](../services/network_storage.md)), calls `notifySaved()`,
  and reloads.
- **Usage:** Selected from the per-card `PopupMenuButton`'s `'edit'` item in `_buildDeviceCard`
  (this file, line 674).
- **Notes:** Because `NetworkDevice` has no `id`, "editing" an assignment here is really "replace
  the assignment matching this `(networkId, deviceId)` pair with a newly-constructed one" — see
  [Networks](../../../../features/networks.md#composite-key-identity--and-why).

### `Future<void> _removeAssignment(NetworkDevice assignment)` <a id="removeassignment"></a>
- **Kind:** method of `_NetworkDetailPageState`.
- **Source:** `lib/features/network/views/network_detail_page.dart` (line 335).
- **Purpose:** Show a confirmation dialog, and if confirmed, remove a device's assignment from this
  network.
- **Inputs:** `assignment` — the `NetworkDevice` to remove.
- **Returns:** `Future<void>`.
- **Side effects:** Shows an `AlertDialog`; on confirmation, calls
  `NetworkStorage.removeAssignment`, `AutoSyncService.instance.notifySaved()`, and reloads.
- **Algorithm:** 1. Shows an `AlertDialog` with Cancel/Delete, awaiting a `bool?`. 2. If `true`:
  awaits `NetworkStorage.removeAssignment(assignment.networkId, assignment.deviceId)`, calls
  `notifySaved()`, and reloads.
- **Usage:** Selected from the per-card `PopupMenuButton`'s `'remove'` item in `_buildDeviceCard`.
- **Notes:** None.

### `Future<NetworkDevice?> _showAssignmentDialog(AppLocalizations l10n, NetworkDevice initial)` <a id="showassignmentdialog"></a>
- **Kind:** method of `_NetworkDetailPageState`.
- **Source:** `lib/features/network/views/network_detail_page.dart` (line 369).
- **Purpose:** Show the modal dialog for configuring one assignment's address mode, IP address,
  hostname, and exit-node flag, seeded from `initial`.
- **Inputs:** `l10n`; `initial` — the `NetworkDevice` to seed the dialog's fields from (a fresh
  unsaved instance for "add", the existing one for "edit").
- **Returns:** `Future<NetworkDevice?>` — the configured `NetworkDevice` if the user saved, `null`
  if they cancelled.
- **Side effects:** Shows a `StatefulBuilder`-backed `AlertDialog` with local dialog state
  (`mode`, two `TextEditingController`s, `isExit`) that is not written back to the page's own state
  until Save is pressed.
- **Algorithm:** 1. Seed local dialog state from `initial`. 2. Build an `AlertDialog` containing a
  `DropdownButtonFormField<AddressMode>`, two `TextField`s (IP, hostname), and a
  `CheckboxListTile` (exit node), all wired to `setDialogState` so the dialog rebuilds independently
  of the page behind it. 3. Cancel pops with no value. 4. Save reads the trimmed IP/hostname text
  (empty string becomes `null`) and pops with a new `NetworkDevice` built from `initial.networkId`/
  `initial.deviceId` (identity fields never change), the dialog's `mode`/`ip`/`hostname`/`isExit`,
  and `initial.extraJson` (preserved unchanged).
- **Usage:** Called by both [`_addDevice`](#adddevice) (with a fresh `NetworkDevice`) and
  [`_editAssignment`](#editassignment) (with the existing one).
- **Notes:** This dialog constructs the returned `NetworkDevice` directly rather than via
  `NetworkDevice.copyWith` — every field (including `networkId`/`deviceId`, which `copyWith` doesn't
  even expose as parameters) is passed explicitly.
