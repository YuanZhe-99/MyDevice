# lib/features/devices/views/device_list_page.dart

The device inventory's home screen (see [Devices](../../../../features/devices.md)). Owns the
device list's load/sort/filter/group state, the financial-summary header card that links to
`device_finance_overview_page.dart`, add/edit/delete/reorder flows backed by
`lib/features/devices/services/device_storage.dart`, and the "add from template" bottom sheet
(`_TemplatePicker`, using `lib/features/devices/services/preset_service.dart`). It registers with
`AutoSyncService` (`lib/shared/services/auto_sync_service.dart`) so the list refreshes itself
whenever a background sync brings in new local data. The online-search FAB
(`_addFromSearch`, wired to `chip_search_dialog`/`device_search_dialog`'s sibling
`showDeviceSearchDialog`) is gated behind `AppFlavor.isFull` — see
[Online Search and Presets](../../../../features/online-search-and-presets.md) for the store-flavor
gating requirements this satisfies (call site 4 of 4).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `DeviceListPage` (constructor) | constructor | B | Create the page widget (no parameters). |
| `createState` | method (`DeviceListPage`) | B | Create the page's mutable state object. |
| [`initState`](#initstate) | method (widget lifecycle) | A | Register the auto-sync listener and kick off preference/device loading. |
| `dispose` | method (widget lifecycle) | B | Unregister the auto-sync listener. |
| `_handleLocalDataChanged` | method (`_DeviceListPageState`) | B | Reload devices in response to an auto-sync notification. |
| [`_loadSortPrefs`](#_loadsortprefs) | method (`_DeviceListPageState`) | A | Load persisted sort mode/grouping/direction from device storage config. |
| [`_loadFinancialPrefs`](#_loadfinancialprefs) | method (`_DeviceListPageState`) | A | Load the persisted default currency for finance display. |
| [`_saveSortPrefs`](#_savesortprefs) | method (`_DeviceListPageState`) | A | Persist the current sort mode/grouping/direction to device storage config. |
| [`_visibleDevices`](#_visibledevices) | getter (`_DeviceListPageState`) | A | Filter `_devices` by the active `DeviceStatusFilter`. |
| [`_sortedDevices`](#_sorteddevices) | getter (`_DeviceListPageState`) | A | Sort and optionally group the visible devices per the current sort settings. |
| [`_loadDevices`](#_loaddevices) | method (`_DeviceListPageState`) | A | Reload the device list from storage and refresh state. |
| `_addDevice` | method (`_DeviceListPageState`) | B | Push the blank device edit page, then reload. |
| `_addFromSearch` | method (`_DeviceListPageState`) | B | Run the online device search dialog, then open the edit page pre-filled with its result. |
| `_editDevice` | method (`_DeviceListPageState`) | B | Push the device edit page for an existing device, then reload. |
| `_viewDevice` | method (`_DeviceListPageState`) | B | Push the device detail page, then reload. |
| `_viewFinancialOverview` | method (`_DeviceListPageState`) | B | Push the financial overview page, then reload. |
| [`_confirmDeleteDevice`](#_confirmdeletedevice) | method (`_DeviceListPageState`) | A | Confirm and, if accepted, delete a device and notify the sync layer. |
| [`_addFromTemplate`](#_addfromtemplate) | method (`_DeviceListPageState`) | A | Pick a bundled device template, materialize it into a `Device`, and open it for editing. |
| `_categoryLabel` | method (`_DeviceListPageState`) | B | Map a `DeviceCategory` to its localized label. |
| `_sortModeLabel` | method (`_DeviceListPageState`) | B | Map a `SortMode` to its localized label. |
| `_filterLabel` | method (`_DeviceListPageState`) | B | Map a `DeviceStatusFilter` to its localized label. |
| [`_statusCount`](#_statuscount) | method (`_DeviceListPageState`) | A | Count devices with a given lifecycle status. |
| [`_totalFinancialCost`](#_totalfinancialcost-list) | method (`_DeviceListPageState`) | A | Sum `totalCost()` across all devices. |
| [`_totalDailyCost`](#_totaldailycost-list) | method (`_DeviceListPageState`) | A | Sum current `averageDailyCost()` across all devices. |
| [`_moneyText`](#_moneytext-list) | method (`_DeviceListPageState`) | A | Format an amount with the page's default-currency symbol. |
| `_setSortMode` | method (`_DeviceListPageState`) | B | Set the sort mode and persist it. |
| `_toggleGroupByCategory` | method (`_DeviceListPageState`) | B | Toggle category grouping and persist it. |
| `_toggleSortOrder` | method (`_DeviceListPageState`) | B | Toggle ascending/descending order and persist it. |
| [`_onReorder`](#_onreorder) | method (`_DeviceListPageState`) | A | Move a device within the custom order and persist the new order. |
| `build` | method (widget) | B | Build the scaffold: app bar, sort/group menu, device list or reorder view, FABs. |
| `_buildDeviceList` | method (widget helper) | B | Build the scrollable device list, inserting category headers when grouping is on. |
| `_buildHomeHeader` | method (widget helper) | B | Build the financial-summary card and status filter segmented control. |
| `_buildMetric` | method (widget helper) | B | Render one label/value metric column. |
| `_buildStatusCount` | method (widget helper) | B | Render one lifecycle-status count with a progress bar. |
| `_buildDismissibleCard` | method (widget helper) | B | Wrap a device card in a `Dismissible` with swipe-to-edit/swipe-to-delete. |
| `_DeviceCard` (constructor) | constructor | B | Store the device, category label, currency, tap handler, and optional trailing widget. |
| `_DeviceCard.build` | method (widget) | B | Render one device's list tile (avatar, name, category/brand/daily-cost subtitle). |
| `_TemplateChoice` (constructor) | constructor | B | Pair a chosen template with the capacity selected for it. |
| `_TemplatePicker` (constructor) | constructor | B | Store the bundled template list for the picker sheet. |
| `_TemplatePicker.createState` | method (`_TemplatePicker`) | B | Create the picker's mutable state object. |
| [`_filtered`](#_filtered) | getter (`_TemplatePickerState`) | A | Filter templates by the current search query. |
| [`_choose`](#_choose) | method (`_TemplatePickerState`) | A | Resolve which storage capacity a chosen template should use. |
| `_TemplatePickerState.build` | method (widget) | B | Render the draggable template-picker sheet (search field + filtered list). |

## Documentation

### `void initState()` <a id="initstate"></a>
- **Kind:** method of `_DeviceListPageState` (widget lifecycle override)
- **Source:** `lib/features/devices/views/device_list_page.dart` (line 54)
- **Purpose:** Wire this page into the auto-sync notification system and kick off the initial
  preference/device loads.
- **Inputs:** None.
- **Returns:** `None`.
- **Side effects:** Registers `_handleLocalDataChanged` with
  `AutoSyncService.instance.addOnLocalDataChanged`; starts two independent async load chains.
- **Algorithm:**
  1. Calls `super.initState()`.
  2. Registers `_handleLocalDataChanged` as an `AutoSyncService` local-data-changed listener, so
     that whenever a background sync pulls in new data, the device list reloads itself
     automatically.
  3. Calls `_loadFinancialPrefs()` (fire-and-forget — not awaited).
  4. Chains `_loadSortPrefs().then((_) => _loadDevices())` — sort/group/direction preferences are
     loaded first, then devices are loaded and sorted/grouped using those already-loaded
     preferences (avoids a visible re-sort flash after the list first renders).
- **Usage:** Invoked automatically by the Flutter framework when `_DeviceListPageState` is first
  inserted into the tree; no direct call site.
- **Notes:** The counterpart `dispose()` (line 67) calls
  `AutoSyncService.instance.removeOnLocalDataChanged(_handleLocalDataChanged)` to avoid leaking the
  listener after the page is disposed.

### `Future<void> _loadSortPrefs()` <a id="_loadsortprefs"></a>
- **Kind:** method of `_DeviceListPageState`
- **Source:** `lib/features/devices/views/device_list_page.dart` (line 86)
- **Purpose:** Load the persisted sort mode, category-grouping flag, and sort direction from
  device storage config, falling back to sensible defaults.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads config via `DeviceStorage.readConfig()`; calls `setState`.
- **Algorithm:**
  1. Reads the config map.
  2. Resolves `_sortMode` by matching the stored `'sortMode'` string against `SortMode.values` by
     `.name`, falling back to `SortMode.custom` if the stored value is missing or unrecognized
     (`firstOrNull ?? SortMode.custom`).
  3. Resolves `_groupByCategory` (default `false`) and `_sortAscending` (default `false`) directly
     as booleans.
  4. Applies all three via a single `setState`.
- **Usage:** Chained after construction in [`initState`](#initstate):
  `_loadSortPrefs().then((_) => _loadDevices());`.
- **Notes:** None.

### `Future<void> _loadFinancialPrefs()` <a id="_loadfinancialprefs"></a>
- **Kind:** method of `_DeviceListPageState`
- **Source:** `lib/features/devices/views/device_list_page.dart` (line 105)
- **Purpose:** Load the user's configured default currency so finance figures on this page format
  correctly.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `DeviceExchangeRateService.getDefaultCurrency()`; `setState` if still
  mounted.
- **Algorithm:** Awaits the service call, then sets `_defaultCurrency` if the widget is still
  mounted (guards against a `setState` after disposal if the page was popped before this resolved).
- **Usage:** Called once from [`initState`](#initstate), fire-and-forget.
- **Notes:** None.

### `Future<void> _saveSortPrefs()` <a id="_savesortprefs"></a>
- **Kind:** method of `_DeviceListPageState`
- **Source:** `lib/features/devices/views/device_list_page.dart` (line 115)
- **Purpose:** Persist the current sort mode, grouping flag, and sort direction back to device
  storage config.
- **Inputs:** None (reads `_sortMode`, `_groupByCategory`, `_sortAscending`).
- **Returns:** `Future<void>`.
- **Side effects:** Reads then writes the config via `DeviceStorage.readConfig()`/`writeConfig()`.
- **Algorithm:** Reads the existing config map, overwrites the three sort-related keys
  (`'sortMode'` as the enum's `.name`, `'groupByCategory'`, `'sortAscending'`), and writes the
  whole map back — preserving any other keys already in the config.
- **Usage:** Called from [`_setSortMode`](#), `_toggleGroupByCategory`, and `_toggleSortOrder`
  after each mutates its respective state field.
- **Notes:** None.

### `List<Device> get _visibleDevices` <a id="_visibledevices"></a>
- **Kind:** getter of `_DeviceListPageState`
- **Source:** `lib/features/devices/views/device_list_page.dart` (line 128)
- **Purpose:** Apply the active `DeviceStatusFilter` to the full device list.
- **Inputs:** None (reads `_devices`, `_statusFilter`).
- **Returns:** `List<Device>` — the subset matching the filter.
- **Side effects:** None.
- **Algorithm:** Filters `_devices` with a `switch` on `_statusFilter`: `all` keeps everything;
  `inService` keeps `device.isInService`; `retired`/`sold` keep devices whose
  `lifecycleStatus` equals the corresponding `DeviceLifecycleStatus` (see
  [Devices](../../../../features/devices.md#lifecycle-and-finance-tracking) for how
  `lifecycleStatus` is derived).
- **Usage:** Read at the top of [`_sortedDevices`](#_sorteddevices): `var list =
  List<Device>.of(_visibleDevices);`.
- **Notes:** None.

### `List<Device> get _sortedDevices` <a id="_sorteddevices"></a>
- **Kind:** getter of `_DeviceListPageState`
- **Source:** `lib/features/devices/views/device_list_page.dart` (line 147)
- **Purpose:** Produce the final list for display: `_visibleDevices` sorted by the active
  `SortMode` and direction, optionally grouped by category.
- **Inputs:** None (reads `_visibleDevices`, `_sortMode`, `_sortAscending`, `_groupByCategory`,
  `_devices`).
- **Returns:** `List<Device>`.
- **Side effects:** None (does not mutate `_devices`; sorts a copy).
- **Algorithm:**
  1. Copies `_visibleDevices` into `list`.
  2. If `_sortMode == SortMode.custom`: this mode means "whatever order is in storage" — no
     comparator is applied. If `_groupByCategory` is on, the list is still sorted by
     `category.index`, but ties are broken by each device's original index in `_devices` (i.e.
     `_devices.indexOf(a).compareTo(_devices.indexOf(b))`), preserving custom order *within* each
     category. Returns immediately.
  3. Otherwise builds a `comparator`: `alphabetical` compares lowercased names;
     `releaseDate`/`purchaseDate` compare the respective date descending (newest first) with nulls
     always sorted last regardless of direction (`a.releaseDate == null` → return `1`, i.e. `a`
     sorts after `b`).
  4. Wraps the comparator to respect `_sortAscending`: if ascending, swaps the argument order
     (`comparator(b, a)`) to invert the (naturally-descending) comparator.
  5. If `_groupByCategory` is on, sorts by `category.index` first, falling back to
     `effectiveComparator` within each category; otherwise sorts the whole list by
     `effectiveComparator` directly.
- **Usage:** `final sorted = _sortedDevices;` in `_buildDeviceList`
  (`lib/features/devices/views/device_list_page.dart`, line 638).
- **Notes:** The null-handling in the date comparators is direction-invariant — nulls are always
  last, both ascending and descending, because the ascending wrapper simply swaps the comparator's
  two arguments rather than negating its result.

### `Future<void> _loadDevices()` <a id="_loaddevices"></a>
- **Kind:** method of `_DeviceListPageState`
- **Source:** `lib/features/devices/views/device_list_page.dart` (line 203)
- **Purpose:** Reload the full device list from storage and refresh the page's state.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads via `DeviceStorage.load()`; `setState` updates `_devices` and clears
  `_loading`.
- **Algorithm:** Awaits `DeviceStorage.load()`, then sets `_devices = data.devices` and
  `_loading = false`.
- **Usage:** Called from [`initState`](#initstate) (after prefs load), `_handleLocalDataChanged`
  (auto-sync), and after every add/edit/delete/reorder/template flow to keep the list current.
- **Notes:** This is the single point through which the page picks up any change to the
  underlying device data, whether made locally on this page or pulled in by a background sync.

### `Future<bool> _confirmDeleteDevice(Device device)` <a id="_confirmdeletedevice"></a>
- **Kind:** method of `_DeviceListPageState`
- **Source:** `lib/features/devices/views/device_list_page.dart` (line 288)
- **Purpose:** Show a confirmation dialog for deleting a device, and if confirmed, delete it and
  refresh the list.
- **Inputs:** `device` — the device the user swiped to delete.
- **Returns:** `Future<bool>` — `true` if the device was deleted, `false` if cancelled.
- **Side effects:** Shows an `AlertDialog`; on confirmation, calls `DeviceStorage.deleteDevice`,
  `AutoSyncService.instance.notifySaved()`, and reloads devices.
- **Algorithm:**
  1. Shows an `AlertDialog` with Cancel/Delete actions, awaiting a `bool?` from `showDialog`.
  2. If the result is exactly `true`: deletes the device by ID via `DeviceStorage.deleteDevice`,
     calls `AutoSyncService.instance.notifySaved()` (marks local data as changed so a sync run will
     pick up the deletion — see [Devices](../../../../features/devices.md#cascade-rules-on-retiresell-delete)
     for what deleting a device cascades to at the model layer), reloads the device list, and
     returns `true`.
  3. Otherwise returns `false` without side effects.
- **Usage:** `confirmDismiss: (direction) async { ... return _confirmDeleteDevice(device); }` in
  `_buildDismissibleCard` (`lib/features/devices/views/device_list_page.dart`, line 944) — the
  `Dismissible`'s `confirmDismiss` uses the returned `bool` to decide whether to actually remove
  the swiped tile.
- **Notes:** None.

### `Future<void> _addFromTemplate()` <a id="_addfromtemplate"></a>
- **Kind:** method of `_DeviceListPageState`
- **Source:** `lib/features/devices/views/device_list_page.dart` (line 321)
- **Purpose:** Let the user pick a bundled device template, then open a pre-filled edit page for
  the resulting device.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Loads bundled JSON via `PresetService`; shows a modal bottom sheet
  (`_TemplatePicker`); navigates to `DeviceEditPage`; reloads devices.
- **Algorithm:**
  1. Awaits `PresetService.loadTemplates()` (see
     [Online Search and Presets](../../../../features/online-search-and-presets.md#bundled-presets--preset_servicedart)
     for the lazy-load/caching behavior).
  2. Returns early if unmounted.
  3. Shows `_TemplatePicker` in a scroll-controlled modal bottom sheet, awaiting the selected
     `DeviceTemplate?`.
  4. If a template was picked and the widget is still mounted: awaits
     `PresetService.loadCpus()`/`loadGpus()` (also lazily cached), returns early if unmounted after
     those resolve, then calls `template.toDevice(cpuPresets: cpus, gpuPresets: gpus)` to build a
     concrete `Device` from the template, pushes `DeviceEditPage(device: device)`, and reloads.
- **Usage:** `onPressed: _addFromTemplate,` on the "add from template" FAB in `build`
  (`lib/features/devices/views/device_list_page.dart`, line 618).
- **Notes:** Three separate `mounted` checks guard the three awaited steps (template load, picker
  result, cpu/gpu preset load) since the user could navigate away from the page during any of
  them.

### `int _statusCount(DeviceLifecycleStatus status)` <a id="_statuscount"></a>
- **Kind:** method of `_DeviceListPageState`
- **Source:** `lib/features/devices/views/device_list_page.dart` (line 394)
- **Purpose:** Count how many devices currently have a given lifecycle status.
- **Inputs:** `status`.
- **Returns:** `int`.
- **Side effects:** None.
- **Algorithm:** `_devices.where((d) => d.lifecycleStatus == status).length`.
- **Usage:** `_statusCount(DeviceLifecycleStatus.inService)` etc. in `_buildHomeHeader`
  (`lib/features/devices/views/device_list_page.dart`, lines 700–702), feeding the three status
  progress bars.
- **Notes:** None.

### `double _totalFinancialCost()` <a id="_totalfinancialcost-list"></a>
- **Kind:** method of `_DeviceListPageState`
- **Source:** `lib/features/devices/views/device_list_page.dart` (line 402)
- **Purpose:** Sum `Device.totalCost()` (as of now) across every device, for the home header's
  "Total Cost" metric.
- **Inputs:** None.
- **Returns:** `double`.
- **Side effects:** None.
- **Algorithm:** `_devices.fold(0, (sum, device) => sum + device.totalCost())`.
- **Usage:** `_moneyText(_totalFinancialCost())` in `_buildHomeHeader`
  (`lib/features/devices/views/device_list_page.dart`, line 747).
- **Notes:** Same shape as `DeviceFinanceOverviewPage._totalFinancialCost` (this file's list-page
  header shows the same aggregate the finance overview page's summary card shows).

### `double _totalDailyCost()` <a id="_totaldailycost-list"></a>
- **Kind:** method of `_DeviceListPageState`
- **Source:** `lib/features/devices/views/device_list_page.dart` (line 410)
- **Purpose:** Sum `Device.averageDailyCost()` (as of now) across every device, for the home
  header's "Daily Cost" metric.
- **Inputs:** None.
- **Returns:** `double`.
- **Side effects:** None.
- **Algorithm:** `_devices.fold(0, (sum, device) => sum + (device.averageDailyCost() ?? 0))`.
- **Usage:** `_moneyText(_totalDailyCost())` in `_buildHomeHeader`
  (`lib/features/devices/views/device_list_page.dart`, line 755).
- **Notes:** None.

### `String _moneyText(double amount)` <a id="_moneytext-list"></a>
- **Kind:** method of `_DeviceListPageState`
- **Source:** `lib/features/devices/views/device_list_page.dart` (line 418)
- **Purpose:** Format a plain amount with the page's configured default-currency symbol.
- **Inputs:** `amount` — already in `_defaultCurrency`.
- **Returns:** `String` — `"{symbol}{amount.toStringAsFixed(2)}"`.
- **Side effects:** None (looks up the symbol via `DeviceExchangeRateService.currencySymbol`).
- **Algorithm:** Symbol lookup + 2-decimal formatting, no conversion — identical shape to
  `DeviceFinanceOverviewPage._moneyText`.
- **Usage:** `_moneyText(_totalFinancialCost())`, `_moneyText(_totalDailyCost())` in
  `_buildHomeHeader`.
- **Notes:** None.

### `Future<void> _onReorder(int oldIndex, int newIndex)` <a id="_onreorder"></a>
- **Kind:** method of `_DeviceListPageState`
- **Source:** `lib/features/devices/views/device_list_page.dart` (line 458)
- **Purpose:** Move a device to a new position in the custom (storage) order and persist the
  change.
- **Inputs:** `oldIndex`, `newIndex` — as supplied by `ReorderableListView.builder`'s
  `onReorderItem` callback.
- **Returns:** `Future<void>`.
- **Side effects:** Mutates `_devices` in place; `setState`; persists via `DeviceStorage.save`.
- **Algorithm:** Removes the device at `oldIndex` and reinserts it at `newIndex`, calls `setState`
  to reflect the reorder immediately, then awaits `DeviceStorage.save(DeviceData(devices:
  _devices))` to persist the new order.
- **Usage:** `onReorderItem: _onReorder,` on the `ReorderableListView.builder` shown while
  `_reordering` is true, in `build` (`lib/features/devices/views/device_list_page.dart`, line 586).
- **Notes:** The source doc comment notes `onReorderItem` (as opposed to the older `onReorder`
  callback) already adjusts `newIndex` after the removal, so this method doesn't need its own
  index-adjustment logic — a common source of off-by-one bugs with Flutter's reorder callbacks.

### `List<DeviceTemplate> get _filtered` <a id="_filtered"></a>
- **Kind:** getter of `_TemplatePickerState`
- **Source:** `lib/features/devices/views/device_list_page.dart` (line 1040)
- **Purpose:** Filter the bundled device template list by the current search query.
- **Inputs:** None (reads `_query`, `widget.templates`).
- **Returns:** `List<DeviceTemplate>` — all templates if the query is empty, otherwise those whose
  name, brand, model, CPU, GPU or RAM contains the (case-insensitive) query.
- **Side effects:** None.
- **Algorithm:** Returns `widget.templates` unfiltered if `_query` is empty; otherwise joins each
  template's `name`, `brand`, `model`, `cpu`, `gpu` and `ram` into one lowercased haystack and keeps
  templates whose haystack `contains` the query.
- **Usage:** `final items = _filtered;` in `_TemplatePickerState.build`
  (`lib/features/devices/views/device_list_page.dart`, line 1056), driving the picker's `ListView`.
- **Notes:** The field set deliberately matches what the tile displays. Filtering on `name` alone
  meant typing a chip the subtitle was showing — "Snapdragon", "Apple M4" — returned nothing.

### `Future<void> _choose(DeviceTemplate t)` <a id="_choose"></a>
- **Kind:** method of `_TemplatePickerState`
- **Source:** `lib/features/devices/views/device_list_page.dart`
- **Purpose:** Resolve which storage capacity a chosen template should use, then close the sheet.
- **Inputs:** `t` — the tapped template.
- **Returns:** `Future<void>`; pops the sheet with a `_TemplateChoice`.
- **Side effects:** May open a capacity dialog; pops the enclosing bottom sheet.
- **Algorithm:** With one capacity or none, pop immediately with index 0. Otherwise show a
  `SimpleDialog` listing each capacity's `displayString` and pop with the chosen index.
- **Notes:** Templates with a single capacity skip the dialog, so the common case is still one tap.
  Dismissing the dialog cancels the selection rather than silently defaulting to the smallest
  capacity — which is what `toDevice` used to do for every multi-capacity template.
