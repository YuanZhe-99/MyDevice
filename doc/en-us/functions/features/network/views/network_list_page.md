# lib/features/network/views/network_list_page.dart

The networks home screen (see [Networks](../../../../features/networks.md)). Owns the network
list's load/sort/reorder state, one card per [`Network`](../models/network.md#network-new) (with a
per-type logo/icon), and the add/edit/detail navigation flow backed by
[`NetworkStorage`](../services/network_storage.md). Unlike the device/dataset list pages, this page
does **not** register with `AutoSyncService` for local-data-change notifications — it reloads only
on navigating back from a push (see [`_buildNetworkCard`](#buildnetworkcard-note) in the
Declarations table below).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `NetworkListPage` (constructor) | constructor | B | Create the page widget (no parameters). |
| `createState` | method (`NetworkListPage`) | B | Create the page's mutable state object. |
| [`initState`](#initstate) | method (widget lifecycle) | A | Register the auto-sync listener and kick off preference/network loading. |
| `dispose` | method (widget lifecycle) | B | Unregister the auto-sync listener. |
| `_handleLocalDataChanged` | method (`_NetworkListPageState`) | B | Reload networks in response to an auto-sync notification. |
| [`_loadSortPrefs`](#loadsortprefs) | method (`_NetworkListPageState`) | A | Load the persisted sort mode/direction from device storage config. |
| [`_saveSortPrefs`](#savesortprefs) | method (`_NetworkListPageState`) | A | Persist the current sort mode/direction to device storage config. |
| [`_sortedNetworks`](#sortednetworks) | getter (`_NetworkListPageState`) | A | Sort `_networks` per the current sort mode/direction. |
| [`_load`](#load) | method (`_NetworkListPageState`) | A | Reload the network list from storage and refresh state. |
| [`_onReorder`](#onreorder) | method (`_NetworkListPageState`) | A | Move a network within the custom order and persist the new order. |
| `_typeIcon` | method (`_NetworkListPageState`) | B | Map a `NetworkType` to a fallback `IconData` (used when no logo asset exists). |
| `_typeLabel` | method (`_NetworkListPageState`) | B | Map a `NetworkType` to its localized label. |
| `_sortModeLabel` | method (`_NetworkListPageState`) | B | Map a `NetworkSortMode` to its localized label. |
| `_buildNetworkCard` | method (widget helper) | B | Render one network's card, with an optional trailing drag handle. |
| `_setColumnsPref` | method (`_NetworkListPageState`) | B | Store a new column preference (`DeviceStorage.setNetworkListColumns`) and re-render. |
| `build` | method (widget) | B | Build the scaffold: app bar, column control (hidden at capacity 1 and while reordering), sort menu, network list — one `adaptiveTileRow` per index above one column — or reorder view, add FAB. Column count from `listColumnCount` at `shellContentWidth − 16` and `networkTileMinWidth`. |

Row count (15) matches `grep -c 'Purpose:' network_list_page.dart` (15) exactly.

## Documentation

### `void initState()` <a id="initstate"></a>
- **Kind:** method of `_NetworkListPageState` (widget lifecycle override).
- **Source:** `lib/features/network/views/network_list_page.dart` (line 43).
- **Purpose:** Wire this page into the auto-sync notification system and kick off the initial
  preference/network loads.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Registers `_handleLocalDataChanged` with
  `AutoSyncService.instance.addOnLocalDataChanged`; starts an async load chain.
- **Algorithm:** 1. Calls `super.initState()`. 2. Registers `_handleLocalDataChanged` as an
  `AutoSyncService` local-data-changed listener, so a background sync that brings in new network
  data reloads this list automatically. 3. Chains `_loadSortPrefs().then((_) => _load())` — sort
  preferences load first, then networks load and sort using those already-loaded preferences.
- **Usage:** Invoked automatically by the Flutter framework when `_NetworkListPageState` is first
  inserted into the tree; no direct call site.
- **Notes:** The counterpart `dispose()` calls
  `AutoSyncService.instance.removeOnLocalDataChanged(_handleLocalDataChanged)` to avoid leaking the
  listener after the page is disposed (see
  [`auto_sync_service.md#addonlocaldatachanged`](../../../shared/services/auto_sync_service.md)).

### `Future<void> _loadSortPrefs()` <a id="loadsortprefs"></a>
- **Kind:** method of `_NetworkListPageState`.
- **Source:** `lib/features/network/views/network_list_page.dart` (line 74).
- **Purpose:** Load the persisted sort mode and sort direction from device storage config, falling
  back to sensible defaults.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads config via `DeviceStorage.readConfig()`; calls `setState`.
- **Algorithm:** Reads the config map; resolves `_sortMode` by matching the stored
  `'networkSortMode'` string against `NetworkSortMode.values` by `.name`, falling back to
  `NetworkSortMode.custom` if missing/unrecognized (`firstOrNull ?? NetworkSortMode.custom`);
  resolves `_sortAscending` (default `false`) directly; applies both via one `setState`.
- **Usage:** Chained after construction in [`initState`](#initstate).
- **Notes:** None.

### `Future<void> _saveSortPrefs()` <a id="savesortprefs"></a>
- **Kind:** method of `_NetworkListPageState`.
- **Source:** `lib/features/network/views/network_list_page.dart` (line 91).
- **Purpose:** Persist the current sort mode and direction back to device storage config.
- **Inputs:** None (reads `_sortMode`, `_sortAscending`).
- **Returns:** `Future<void>`.
- **Side effects:** Reads then writes the config via `DeviceStorage.readConfig()`/`writeConfig()`.
- **Algorithm:** Reads the existing config map, overwrites `'networkSortMode'` (as the enum's
  `.name`) and `'networkSortAscending'`, writes the whole map back — preserving any other keys.
- **Usage:** Called from the sort menu's `onSelected` handler in `build`, right after each mutates
  `_sortMode`/`_sortAscending`.
- **Notes:** None.

### `List<Network> get _sortedNetworks` <a id="sortednetworks"></a>
- **Kind:** getter of `_NetworkListPageState`.
- **Source:** `lib/features/network/views/network_list_page.dart` (line 103).
- **Purpose:** Produce the list for display: `_networks` sorted by the active `NetworkSortMode` and
  direction (or left in custom/storage order).
- **Inputs:** None (reads `_networks`, `_sortMode`, `_sortAscending`).
- **Returns:** `List<Network>` — a sorted copy; `_networks` itself is never mutated.
- **Side effects:** None.
- **Algorithm:** 1. Copy `_networks` into `list`. 2. If `_sortMode == custom`, return the copy
  unsorted immediately (custom order is whatever is currently in storage). 3. Otherwise build a
  comparator: `alphabetical` compares lowercased names; `subnet` compares `subnet` strings with
  nulls always sorted last (`a.subnet == null` → `1`, i.e. sorts after). 4. Wrap the comparator to
  respect `_sortAscending`: if ascending, swap the argument order (`comparator(b, a)`) to invert the
  otherwise-descending comparator. 5. Sort and return the copy.
- **Usage:** Read by the non-reordering branch of `build`'s `ListView.builder`:
  `_sortedNetworks[index]`.
- **Notes:** The `subnet` sort's null-handling is direction-invariant — nulls stay last whether
  ascending or descending, because the ascending wrapper swaps the comparator's arguments rather
  than negating its result (same technique as `_DeviceListPageState._sortedDevices`, see
  [`../../devices/views/device_list_page.md#_sorteddevices`](../../devices/views/device_list_page.md)).

### `Future<void> _load()` <a id="load"></a>
- **Kind:** method of `_NetworkListPageState`.
- **Source:** `lib/features/network/views/network_list_page.dart` (line 131).
- **Purpose:** Reload the full network list from storage and refresh the page's state.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads via `NetworkStorage.load()`; `setState` updates `_networks`.
- **Algorithm:** Awaits `NetworkStorage.load()`, then sets `_networks = data.networks` (discarding
  `data.assignments` — this page only shows the network list, not per-network device assignments).
- **Usage:** Called from [`initState`](#initstate) (after prefs load), `_handleLocalDataChanged`
  (auto-sync), and after returning from the add/detail page pushes in `build` (see the note below on
  `_buildNetworkCard`).
- **Notes:** <a id="buildnetworkcard-note"></a>Because this page has no `AutoSyncService`
  registration tied to *local edits made on this page itself* (only to background-sync
  notifications via [`initState`](#initstate)), every navigation push in `build` — both the "add"
  FAB and `_buildNetworkCard`'s `onTap` into `NetworkDetailPage` — calls `_load()` again after the
  pushed route returns, which is how edits/deletes made on those pages become visible here.

### `Future<void> _onReorder(int oldIndex, int newIndex)` <a id="onreorder"></a>
- **Kind:** method of `_NetworkListPageState`.
- **Source:** `lib/features/network/views/network_list_page.dart` (line 141).
- **Purpose:** Move a network to a new position in the custom order and persist the change.
- **Inputs:** `oldIndex`, `newIndex` — as supplied by `ReorderableListView.builder`'s
  `onReorderItem` callback.
- **Returns:** `Future<void>`.
- **Side effects:** Mutates `_networks` in place; `setState`; persists via `NetworkStorage.save`.
- **Algorithm:** Removes the network at `oldIndex` and reinserts it at `newIndex`; calls `setState`
  to reflect the reorder immediately; loads the current `NetworkData` (to read the latest
  `assignments`) and awaits `NetworkStorage.save(NetworkData(networks: _networks, assignments:
  data.assignments))` to persist the new network order without disturbing assignments.
- **Usage:** `onReorderItem: _onReorder,` on the `ReorderableListView.builder` shown while
  `_reordering` is true, in `build`.
- **Notes:** The doc comment notes `onReorderItem` (as opposed to the older `onReorder` callback)
  already adjusts `newIndex` after the removal, so no extra index-adjustment logic is needed here —
  same convention as `_DeviceListPageState._onReorder`
  (`../../devices/views/device_list_page.md#_onreorder`).
