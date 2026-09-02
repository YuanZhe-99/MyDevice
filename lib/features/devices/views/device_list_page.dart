import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../app/flavor.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/views/device_map_page.dart';
import '../../../shared/widgets/adaptive_tile_grid.dart';
import '../models/device.dart';
import '../services/device_storage.dart';
import '../services/exchange_rate_service.dart';
import '../services/preset_service.dart';
import 'device_detail_page.dart';
import 'device_edit_page.dart';
import 'device_finance_overview_page.dart';
import 'device_search_dialog.dart';
import '../widgets/device_avatar.dart';
import '../widgets/device_category_icon.dart';

enum SortMode { custom, alphabetical, purchaseDate, releaseDate }

enum DeviceStatusFilter { all, inService, retired, sold }

class DeviceListPage extends StatefulWidget {
  /// Purpose: Create a device list page instance.
  /// Inputs: None.
  /// Returns: A new `DeviceListPage` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  const DeviceListPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `State` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  @override
  State<DeviceListPage> createState() => _DeviceListPageState();
}

class _DeviceListPageState extends State<DeviceListPage> {
  List<Device> _devices = [];
  bool _loading = true;
  SortMode _sortMode = SortMode.custom;
  bool _groupByCategory = false;
  bool _sortAscending = false;
  DeviceStatusFilter _statusFilter = DeviceStatusFilter.all;
  String _defaultCurrency = DeviceExchangeRateService.defaultDefaultCurrency;
  int _columnsPref = listColumnsAuto;

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Registers listeners and may kick off asynchronous loading.
  /// Notes: Guard any post-await UI updates with `mounted` when needed.
  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnLocalDataChanged(_handleLocalDataChanged);
    _loadFinancialPrefs();
    _loadSortPrefs().then((_) => _loadDevices());
  }

  /// Purpose: Release listeners, controllers, and other owned resources.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Releases owned resources and unregisters listeners.
  /// Notes: Call the superclass implementation in the expected lifecycle order.
  @override
  void dispose() {
    AutoSyncService.instance.removeOnLocalDataChanged(_handleLocalDataChanged);
    super.dispose();
  }

  /// Purpose: Handle local data changed and trigger the appropriate follow-up work.
  /// Inputs: None.
  /// Returns: `void`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  void _handleLocalDataChanged() {
    if (mounted) _loadDevices();
  }

  /// Purpose: Load sort prefs into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _loadSortPrefs() async {
    final config = await DeviceStorage.readConfig();
    final mode = config['sortMode'] as String?;
    final group = config['groupByCategory'] as bool? ?? false;
    final asc = config['sortAscending'] as bool? ?? false;
    final columns = await DeviceStorage.getDeviceListColumns();
    if (!mounted) return;
    setState(() {
      _sortMode =
          SortMode.values.where((e) => e.name == mode).firstOrNull ??
          SortMode.custom;
      _groupByCategory = group;
      _sortAscending = asc;
      _columnsPref = columns;
    });
  }

  /// Purpose: Store a new column preference and re-render with it.
  /// Inputs: `columns` — `listColumnsAuto` or a pinned count.
  /// Returns: `void`.
  /// Side effects: Updates widget state and writes `storage_config.json`.
  /// Notes: Internal helper used within this file only. The stored value is
  /// clamped at render time, so a count picked on a desktop survives a fold.
  void _setColumnsPref(int columns) {
    setState(() => _columnsPref = columns);
    DeviceStorage.setDeviceListColumns(columns);
  }

  /// Purpose: Load financial prefs into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _loadFinancialPrefs() async {
    final currency = await DeviceExchangeRateService.getDefaultCurrency();
    if (mounted) setState(() => _defaultCurrency = currency);
  }

  /// Purpose: Save sort prefs to the relevant storage or service layer.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _saveSortPrefs() async {
    final config = await DeviceStorage.readConfig();
    config['sortMode'] = _sortMode.name;
    config['groupByCategory'] = _groupByCategory;
    config['sortAscending'] = _sortAscending;
    await DeviceStorage.writeConfig(config);
  }

  /// Purpose: Provide the internal visible devices helper for this file.
  /// Inputs: None.
  /// Returns: `List<Device>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  List<Device> get _visibleDevices {
    return _devices.where((device) {
      return switch (_statusFilter) {
        DeviceStatusFilter.all => true,
        DeviceStatusFilter.inService => device.isInService,
        DeviceStatusFilter.retired =>
          device.lifecycleStatus == DeviceLifecycleStatus.retired,
        DeviceStatusFilter.sold =>
          device.lifecycleStatus == DeviceLifecycleStatus.sold,
      };
    }).toList();
  }

  /// Purpose: Provide the internal sorted devices helper for this file.
  /// Inputs: None.
  /// Returns: `List<Device>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  /// Returns the sorted / grouped list for display.
  List<Device> get _sortedDevices {
    var list = List<Device>.of(_visibleDevices);
    if (_sortMode == SortMode.custom) {
      // Custom order = storage order; grouping still applies
      if (_groupByCategory) {
        list.sort((a, b) {
          final cmp = a.category.index.compareTo(b.category.index);
          if (cmp != 0) return cmp;
          // Preserve relative order within category
          return _devices.indexOf(a).compareTo(_devices.indexOf(b));
        });
      }
      return list;
    }
    int Function(Device, Device) comparator;
    if (_sortMode == SortMode.alphabetical) {
      comparator = (a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase());
    } else if (_sortMode == SortMode.releaseDate) {
      // releaseDate: nulls last
      comparator = (a, b) {
        if (a.releaseDate == null && b.releaseDate == null) return 0;
        if (a.releaseDate == null) return 1;
        if (b.releaseDate == null) return -1;
        return b.releaseDate!.compareTo(a.releaseDate!);
      };
    } else {
      // purchaseDate: nulls last
      comparator = (a, b) {
        if (a.purchaseDate == null && b.purchaseDate == null) return 0;
        if (a.purchaseDate == null) return 1;
        if (b.purchaseDate == null) return -1;
        return b.purchaseDate!.compareTo(a.purchaseDate!);
      };
    }
    // Apply ascending/descending
    final effectiveComparator = _sortAscending
        ? (Device a, Device b) => comparator(b, a)
        : comparator;
    if (_groupByCategory) {
      list.sort((a, b) {
        final cmp = a.category.index.compareTo(b.category.index);
        if (cmp != 0) return cmp;
        return effectiveComparator(a, b);
      });
    } else {
      list.sort(effectiveComparator);
    }
    return list;
  }

  /// Purpose: Load devices into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _loadDevices() async {
    final data = await DeviceStorage.load();
    setState(() {
      _devices = data.devices;
      _loading = false;
    });
  }

  /// Purpose: Add device through the current flow.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _addDevice() async {
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => const DeviceEditPage()));
    await _loadDevices();
  }

  /// Purpose: Add from search through the current flow.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _addFromSearch() async {
    final result = await showDeviceSearchDialog(context);
    if (result == null || !mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => DeviceEditPage(searchResult: result)),
    );
    await _loadDevices();
  }

  /// Purpose: Edit device and refresh local state when needed.
  /// Inputs: `device`.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _editDevice(Device device) async {
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => DeviceEditPage(device: device)));
    await _loadDevices();
  }

  /// Purpose: Provide the internal view device helper for this file.
  /// Inputs: `device`.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _viewDevice(Device device) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) =>
            DeviceDetailPage(device: device, onDeviceChanged: () {}),
      ),
    );
    await _loadDevices();
  }

  /// Purpose: Provide the internal view financial overview helper for this file.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _viewFinancialOverview() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => DeviceFinanceOverviewPage(
          devices: _devices,
          defaultCurrency: _defaultCurrency,
        ),
      ),
    );
    await _loadDevices();
  }

  /// Purpose: Provide the internal confirm delete device helper for this file.
  /// Inputs: `device`.
  /// Returns: `Future<bool>`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Future<bool> _confirmDeleteDevice(Device device) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteDevice),
        content: Text(l10n.deleteDeviceConfirm(device.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DeviceStorage.deleteDevice(device.id);
      AutoSyncService.instance.notifySaved();
      await _loadDevices();
      return true;
    }
    return false;
  }

  /// Purpose: Add from template through the current flow.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _addFromTemplate() async {
    final templates = await PresetService.loadTemplates();
    if (!mounted) return;
    final choice = await showModalBottomSheet<_TemplateChoice>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TemplatePicker(templates: templates),
    );
    if (choice != null && mounted) {
      final cpus = await PresetService.loadCpus();
      final gpus = await PresetService.loadGpus();
      if (!mounted) return;
      final device = choice.template.toDevice(
        cpuPresets: cpus,
        gpuPresets: gpus,
        storageIndex: choice.storageIndex,
      );
      await Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute(builder: (_) => DeviceEditPage(device: device)));
      await _loadDevices();
    }
  }

  /// Purpose: Return the display label for category label.
  /// Inputs: `context`, `category`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _categoryLabel(BuildContext context, DeviceCategory category) {
    final l10n = AppLocalizations.of(context)!;
    return switch (category) {
      DeviceCategory.desktop => l10n.deviceCategoryDesktop,
      DeviceCategory.laptop => l10n.deviceCategoryLaptop,
      DeviceCategory.phone => l10n.deviceCategoryPhone,
      DeviceCategory.tablet => l10n.deviceCategoryTablet,
      DeviceCategory.headphone => l10n.deviceCategoryHeadphone,
      DeviceCategory.watch => l10n.deviceCategoryWatch,
      DeviceCategory.router => l10n.deviceCategoryRouter,
      DeviceCategory.gameConsole => l10n.deviceCategoryGameConsole,
      DeviceCategory.vps => l10n.deviceCategoryVps,
      DeviceCategory.devBoard => l10n.deviceCategoryDevBoard,
      DeviceCategory.other => l10n.deviceCategoryOther,
    };
  }

  /// Purpose: Return the display label for sort mode label.
  /// Inputs: `l10n`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _sortModeLabel(AppLocalizations l10n, SortMode mode) => switch (mode) {
    SortMode.custom => l10n.sortCustom,
    SortMode.alphabetical => l10n.sortAlphabetical,
    SortMode.purchaseDate => l10n.sortPurchaseDate,
    SortMode.releaseDate => l10n.sortReleaseDate,
  };

  /// Purpose: Return the display label for filter label.
  /// Inputs: `l10n`, `filter`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _filterLabel(AppLocalizations l10n, DeviceStatusFilter filter) =>
      switch (filter) {
        DeviceStatusFilter.all => l10n.filterAll,
        DeviceStatusFilter.inService => l10n.statusInService,
        DeviceStatusFilter.retired => l10n.statusRetired,
        DeviceStatusFilter.sold => l10n.statusSold,
      };

  /// Purpose: Provide the internal status count helper for this file.
  /// Inputs: `status`.
  /// Returns: `int`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  int _statusCount(DeviceLifecycleStatus status) =>
      _devices.where((d) => d.lifecycleStatus == status).length;

  /// Purpose: Provide the internal total financial cost helper for this file.
  /// Inputs: None.
  /// Returns: `double`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  double _totalFinancialCost() =>
      _devices.fold(0, (sum, device) => sum + device.totalCost());

  /// Purpose: Provide the internal total daily cost helper for this file.
  /// Inputs: None.
  /// Returns: `double`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  double _totalDailyCost() =>
      _devices.fold(0, (sum, device) => sum + (device.averageDailyCost() ?? 0));

  /// Purpose: Provide the internal money text helper for this file.
  /// Inputs: `amount`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _moneyText(double amount) {
    final symbol = DeviceExchangeRateService.currencySymbol(_defaultCurrency);
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Purpose: Update sort mode with the provided value.
  /// Inputs: `mode`.
  /// Returns: `void`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  void _setSortMode(SortMode mode) {
    setState(() => _sortMode = mode);
    _saveSortPrefs();
  }

  /// Purpose: Provide the internal toggle group by category helper for this file.
  /// Inputs: None.
  /// Returns: `void`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  void _toggleGroupByCategory() {
    setState(() => _groupByCategory = !_groupByCategory);
    _saveSortPrefs();
  }

  /// Purpose: Provide the internal toggle sort order helper for this file.
  /// Inputs: None.
  /// Returns: `void`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  void _toggleSortOrder() {
    setState(() => _sortAscending = !_sortAscending);
    _saveSortPrefs();
  }

  /// Purpose: Provide the internal on reorder helper for this file.
  /// Inputs: `oldIndex`, `newIndex`.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: `onReorderItem` already adjusts `newIndex` after removal.
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final item = _devices.removeAt(oldIndex);
    _devices.insert(newIndex, item);
    setState(() {});
    await DeviceStorage.save(DeviceData(devices: _devices));
  }

  bool _reordering = false;

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state. Updates widget state and triggers a rebuild. Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // The gate reads the whole screen; the capacity reads what the list gets
    // after the navigation rail and the tiles' 16 dp horizontal margin.
    final screen = MediaQuery.sizeOf(context);
    final contentWidth = shellContentWidth(screen.width) - 32;
    final capacity = canSplitLayout(screen.width, screen.height)
        ? columnCapacity(contentWidth, minItemWidth: deviceTileMinWidth)
        : 1;
    final columns = listColumnCount(
      screenWidth: screen.width,
      screenHeight: screen.height,
      contentWidth: contentWidth,
      minItemWidth: deviceTileMinWidth,
      preference: _columnsPref,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: l10n.mapViewDevices,
            onPressed: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => DeviceMapPage(
                    title: l10n.mapViewDevices,
                    devices: _devices,
                  ),
                ),
              );
            },
          ),
          if (_reordering)
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: l10n.save,
              onPressed: () => setState(() => _reordering = false),
            )
          else ...[
            listColumnsButton(
              context,
              preference: _columnsPref,
              capacity: capacity,
              onChanged: _setColumnsPref,
            ),
            PopupMenuButton<dynamic>(
              icon: const Icon(Icons.sort),
              tooltip: l10n.sortTitle,
              itemBuilder: (_) => [
                ...SortMode.values.map(
                  (m) => CheckedPopupMenuItem<SortMode>(
                    value: m,
                    checked: _sortMode == m,
                    child: Text(_sortModeLabel(l10n, m)),
                  ),
                ),
                const PopupMenuDivider(),
                if (_sortMode != SortMode.custom)
                  CheckedPopupMenuItem<String>(
                    value: 'ascending',
                    checked: _sortAscending,
                    child: Text(l10n.sortAscending),
                  ),
                CheckedPopupMenuItem<String>(
                  value: 'group',
                  checked: _groupByCategory,
                  child: Text(l10n.sortGroupByCategory),
                ),
                if (_sortMode == SortMode.custom &&
                    _statusFilter == DeviceStatusFilter.all) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'reorder',
                    child: Text(l10n.sortReorder),
                  ),
                ],
              ],
              onSelected: (value) {
                if (value is SortMode) {
                  _setSortMode(value);
                } else if (value == 'ascending') {
                  _toggleSortOrder();
                } else if (value == 'group') {
                  _toggleGroupByCategory();
                } else if (value == 'reorder') {
                  setState(() => _reordering = true);
                }
              },
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                l10n.totalDevices(_devices.length),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.devices_other,
                      size: 64,
                      color: theme.colorScheme.primary.withAlpha(128),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noDevices,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            )
          : _reordering
          ? ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _devices.length,
              onReorderItem: _onReorder,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return _DeviceCard(
                  key: ValueKey(device.id),
                  device: device,
                  categoryLabel: _categoryLabel(context, device.category),
                  defaultCurrency: _defaultCurrency,
                  onTap: () {},
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                );
              },
            )
          : _buildDeviceList(l10n, theme, columns),
      floatingActionButton: _reordering
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (AppFlavor.isFull)
                  FloatingActionButton.small(
                    heroTag: 'search',
                    onPressed: _addFromSearch,
                    tooltip: l10n.fetchFromInternet,
                    child: const Icon(Icons.travel_explore),
                  ),
                if (AppFlavor.isFull) const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'template',
                  onPressed: _addFromTemplate,
                  child: const Icon(Icons.file_copy_outlined),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'add',
                  onPressed: _addDevice,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
    );
  }

  /// Purpose: Build one device tile for the current column count.
  /// Inputs: `device`, `l10n`, `theme`, `columns`.
  /// Returns: `Widget`.
  /// Side effects: None beyond the tile's own handlers.
  /// Notes: Internal helper used within this file only. At one column the
  /// tile keeps its swipe-to-edit and swipe-to-delete `Dismissible`; above it
  /// a horizontal drag inside one narrow cell is ambiguous, so the chevron
  /// becomes a menu carrying the same two actions — the same trailing menu the
  /// services tiles already use. Delete has no other entrance, so the menu is
  /// what keeps it reachable.
  Widget _buildTile(
    Device device,
    AppLocalizations l10n,
    ThemeData theme,
    int columns,
  ) {
    if (columns == 1) return _buildDismissibleCard(device, l10n, theme);
    return _DeviceCard(
      device: device,
      categoryLabel: _categoryLabel(context, device.category),
      defaultCurrency: _defaultCurrency,
      onTap: () => _viewDevice(device),
      margin: const EdgeInsets.symmetric(vertical: 6),
      trailing: PopupMenuButton<String>(
        itemBuilder: (_) => [
          PopupMenuItem(value: 'edit', child: Text(l10n.editDevice)),
          PopupMenuItem(value: 'delete', child: Text(l10n.deleteDevice)),
        ],
        onSelected: (value) {
          if (value == 'edit') {
            _editDevice(device);
          } else if (value == 'delete') {
            _confirmDeleteDevice(device);
          }
        },
      ),
    );
  }

  /// Purpose: Lay a run of devices out as list children at a column count.
  /// Inputs: `devices`, `l10n`, `theme`, `columns`.
  /// Returns: `List<Widget>` — the tiles themselves at one column, else one
  /// padded `Row` per [listRowCount] row.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The 16 dp horizontal
  /// padding replaces the margin the single-column card carries itself, so
  /// the rows align with the header card above them.
  List<Widget> _tileRows(
    List<Device> devices,
    AppLocalizations l10n,
    ThemeData theme,
    int columns,
  ) {
    final rows = adaptiveTileRows(
      columns: columns,
      itemCount: devices.length,
      itemBuilder: (i) => _buildTile(devices[i], l10n, theme, columns),
    );
    if (columns == 1) return rows;
    return [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: row,
        ),
    ];
  }

  /// Purpose: Build and return device list for the current context.
  /// Inputs: `l10n`, `theme`, `columns` — from `listColumnCount`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only. The flat list keeps
  /// `ListView.builder` virtualization by building one row per index; the
  /// grouped list is materialized already, so it spreads `_tileRows` per
  /// category under that category's header.
  Widget _buildDeviceList(AppLocalizations l10n, ThemeData theme, int columns) {
    final sorted = _sortedDevices;
    final header = _buildHomeHeader(l10n, theme);
    if (sorted.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          header,
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              l10n.noDevices,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      );
    }
    // Insert category headers when grouping
    if (_groupByCategory) {
      final widgets = <Widget>[header];
      DeviceCategory? lastCat;
      final group = <Device>[];
      void flush() {
        if (group.isEmpty) return;
        widgets.addAll(_tileRows(List.of(group), l10n, theme, columns));
        group.clear();
      }

      for (final device in sorted) {
        if (device.category != lastCat) {
          flush();
          lastCat = device.category;
          widgets.add(
            Padding(
              key: ValueKey('header_${device.category.name}'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                _categoryLabel(context, device.category),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          );
        }
        group.add(device);
      }
      flush();
      return ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: widgets,
      );
    }
    if (columns == 1) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: sorted.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return header;
          return _buildDismissibleCard(sorted[index - 1], l10n, theme);
        },
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: listRowCount(sorted.length, columns) + 1,
      itemBuilder: (context, index) {
        if (index == 0) return header;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: adaptiveTileRow(
            rowIndex: index - 1,
            columns: columns,
            itemCount: sorted.length,
            itemBuilder: (i) => _buildTile(sorted[i], l10n, theme, columns),
          ),
        );
      },
    );
  }

  /// Purpose: Build and return home header for the current context.
  /// Inputs: `l10n`, `theme`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildHomeHeader(AppLocalizations l10n, ThemeData theme) {
    final cs = theme.colorScheme;
    final inService = _statusCount(DeviceLifecycleStatus.inService);
    final retired = _statusCount(DeviceLifecycleStatus.retired);
    final sold = _statusCount(DeviceLifecycleStatus.sold);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            color: cs.surfaceContainerHighest.withAlpha(128),
            child: InkWell(
              onTap: _viewFinancialOverview,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.financialOverview,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${_devices.length}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetric(
                            theme,
                            l10n.financialTotalCost,
                            _moneyText(_totalFinancialCost()),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetric(
                            theme,
                            l10n.financialDailyCost,
                            _moneyText(_totalDailyCost()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusCount(
                            theme,
                            l10n.statusInService,
                            inService,
                            cs.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatusCount(
                            theme,
                            l10n.statusRetired,
                            retired,
                            cs.secondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatusCount(
                            theme,
                            l10n.statusSold,
                            sold,
                            cs.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<DeviceStatusFilter>(
              showSelectedIcon: false,
              segments: DeviceStatusFilter.values
                  .map(
                    (filter) => ButtonSegment(
                      value: filter,
                      label: Text(_filterLabel(l10n, filter)),
                    ),
                  )
                  .toList(),
              selected: {_statusFilter},
              onSelectionChanged: (selection) {
                setState(() {
                  _statusFilter = selection.first;
                  if (_statusFilter != DeviceStatusFilter.all) {
                    _reordering = false;
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Purpose: Build and return metric for the current context.
  /// Inputs: `theme`, `label`, `value`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildMetric(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  /// Purpose: Build and return status count for the current context.
  /// Inputs: `theme`, `label`, `count`, `color`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildStatusCount(
    ThemeData theme,
    String label,
    int count,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          minHeight: 4,
          value: _devices.isEmpty ? 0 : count / _devices.length,
          color: color,
          backgroundColor: color.withAlpha(28),
        ),
        const SizedBox(height: 4),
        Text('$count', style: theme.textTheme.labelMedium),
      ],
    );
  }

  /// Purpose: Build and return dismissible card for the current context.
  /// Inputs: `device`, `l10n`, `theme`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildDismissibleCard(
    Device device,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Dismissible(
      key: ValueKey(device.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        color: theme.colorScheme.primary,
        child: Row(
          children: [
            Icon(Icons.edit, color: theme.colorScheme.onPrimary),
            const SizedBox(width: 8),
            Text(
              l10n.swipeEditHint,
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.error,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              l10n.swipeDeleteHint,
              style: TextStyle(
                color: theme.colorScheme.onError,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.delete, color: theme.colorScheme.onError),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _editDevice(device);
          return false;
        } else {
          return _confirmDeleteDevice(device);
        }
      },
      child: _DeviceCard(
        device: device,
        categoryLabel: _categoryLabel(context, device.category),
        defaultCurrency: _defaultCurrency,
        onTap: () => _viewDevice(device),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final Device device;
  final String categoryLabel;
  final String defaultCurrency;
  final VoidCallback onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  /// Purpose: Create a device card instance.
  /// Inputs: `device`, `categoryLabel`, `defaultCurrency`, `onTap`, optional
  /// `trailing`, optional `margin`.
  /// Returns: A new `_DeviceCard` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: `margin` defaults to the 16 dp horizontal / 6 dp vertical the
  /// single-column list always had; the multi-column rows pass a vertical-only
  /// margin because the row itself carries the horizontal padding.
  const _DeviceCard({
    super.key,
    required this.device,
    required this.categoryLabel,
    required this.defaultCurrency,
    required this.onTap,
    this.trailing,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subtitleParts = <String>[categoryLabel];
    if (device.brand != null) subtitleParts.add(device.brand!);
    final dailyCost = device.averageDailyCost();
    if (dailyCost != null) {
      final symbol = DeviceExchangeRateService.currencySymbol(defaultCurrency);
      subtitleParts.add(
        '${l10n.financialDailyCost}: $symbol${dailyCost.toStringAsFixed(2)}',
      );
    }

    return Card(
      margin: margin,
      child: ListTile(
        leading: DeviceAvatar.fromDevice(device),
        title: Text(device.name),
        subtitle: Text(
          subtitleParts.join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// A template plus the storage capacity the user picked for it.
///
/// Templates may list several capacities; the picker resolves the choice so
/// `toDevice` receives a concrete index rather than silently taking the first.
class _TemplateChoice {
  final DeviceTemplate template;
  final int storageIndex;

  /// Purpose: Pair a chosen template with the capacity selected for it.
  /// Inputs: `template`, `storageIndex`.
  /// Returns: A new `_TemplateChoice` instance.
  /// Side effects: None.
  /// Notes: None.
  const _TemplateChoice(this.template, this.storageIndex);
}

class _TemplatePicker extends StatefulWidget {
  final List<DeviceTemplate> templates;

  /// Purpose: Create a template picker instance.
  /// Inputs: None.
  /// Returns: A new `_TemplatePicker` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  const _TemplatePicker({required this.templates});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `State` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  @override
  State<_TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<_TemplatePicker> {
  String _query = '';

  /// Purpose: Provide the internal filtered helper for this file.
  /// Inputs: None.
  /// Returns: `List<DeviceTemplate>`.
  /// Side effects: None.
  /// Notes: Matches every field the tile actually displays — name, brand,
  /// model, CPU and RAM. Filtering on `name` alone meant typing a chip the
  /// subtitle was showing, such as "Snapdragon" or "Apple M4", returned
  /// nothing. Internal helper used within this file only.
  List<DeviceTemplate> get _filtered {
    if (_query.isEmpty) return widget.templates;
    final q = _query.toLowerCase();
    return widget.templates.where((t) {
      final haystack = [
        t.name,
        t.brand,
        t.model,
        t.cpu,
        t.gpu,
        t.ram,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  /// Purpose: Resolve which storage capacity a chosen template should use.
  /// Inputs: `t` — the tapped template.
  /// Returns: `Future<void>`; pops the sheet with a `_TemplateChoice`.
  /// Side effects: May open a capacity dialog; pops the enclosing sheet.
  /// Notes: Templates with one capacity (or none) skip the dialog entirely, so
  /// the common case is still a single tap. Dismissing the dialog cancels the
  /// selection rather than defaulting to the smallest capacity.
  /// Internal helper used within this file only.
  Future<void> _choose(DeviceTemplate t) async {
    if (t.storage.length <= 1) {
      Navigator.pop(context, _TemplateChoice(t, 0));
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final index = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.storage),
        children: [
          for (var i = 0; i < t.storage.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, i),
              child: Text(t.storage[i].displayString),
            ),
        ],
      ),
    );
    if (index != null && mounted) {
      Navigator.pop(context, _TemplateChoice(t, index));
    }
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state. Updates widget state and triggers a rebuild.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = _filtered;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l10n.fromTemplate,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchTemplatePlaceholder,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final t = items[index];
                return ListTile(
                  leading: Icon(deviceCategoryIcon(t.category)),
                  title: Text(t.name),
                  subtitle: Text(
                    [t.brand, t.cpu, t.ram].where((s) => s != null).join(' · '),
                  ),
                  dense: true,
                  onTap: () => _choose(t),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
