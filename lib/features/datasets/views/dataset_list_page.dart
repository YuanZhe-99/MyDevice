import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/widgets/adaptive_tile_grid.dart';
import '../../devices/models/device.dart';
import '../../devices/services/device_storage.dart';
import '../models/dataset.dart';
import '../services/dataset_placement.dart';
import '../services/dataset_storage.dart';
import 'dataset_copy_summary.dart';
import 'dataset_edit_page.dart';
import 'dataset_topology_page.dart';

enum DataSetSortMode { custom, alphabetical }

class DataSetListPage extends StatefulWidget {
  /// Purpose: Create a data set list page instance.
  /// Inputs: None.
  /// Returns: A new `DataSetListPage` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  const DataSetListPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `State` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  @override
  State<DataSetListPage> createState() => _DataSetListPageState();
}

class _DataSetListPageState extends State<DataSetListPage> {
  List<DataSet> _datasets = [];
  List<Device> _devices = [];
  bool _loading = true;
  DataSetSortMode _sortMode = DataSetSortMode.custom;
  bool _sortAscending = false;
  bool _reordering = false;
  int _columnsPref = listColumnsAuto;
  DataSetGroupMode _groupMode = DataSetGroupMode.none;

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Registers listeners and may kick off asynchronous loading.
  /// Notes: Guard any post-await UI updates with `mounted` when needed.
  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnLocalDataChanged(_handleLocalDataChanged);
    _loadSortPrefs().then((_) => _load());
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
    if (mounted) _load();
  }

  /// Purpose: Load the sort, grouping and column preferences.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: An unknown or missing `datasetGroupMode` means no grouping.
  Future<void> _loadSortPrefs() async {
    final config = await DeviceStorage.readConfig();
    final mode = config['datasetSortMode'] as String?;
    final asc = config['datasetSortAscending'] as bool? ?? false;
    final group = config['datasetGroupMode'] as String?;
    final columns = await DeviceStorage.getDataSetListColumns();
    if (!mounted) return;
    setState(() {
      _sortMode =
          DataSetSortMode.values.where((e) => e.name == mode).firstOrNull ??
          DataSetSortMode.custom;
      _sortAscending = asc;
      _groupMode =
          DataSetGroupMode.values.where((e) => e.name == group).firstOrNull ??
          DataSetGroupMode.none;
      _columnsPref = columns;
    });
  }

  /// Purpose: Store a new column preference and re-render with it.
  /// Inputs: `columns` — `listColumnsAuto` or a pinned count.
  /// Returns: `void`.
  /// Side effects: Updates widget state and writes `storage_config.json`.
  /// Notes: Internal helper used within this file only.
  void _setColumnsPref(int columns) {
    setState(() => _columnsPref = columns);
    DeviceStorage.setDataSetListColumns(columns);
  }

  /// Purpose: Persist the grouping mode.
  /// Inputs: `mode`.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state; writes `storage_config.json`.
  /// Notes: `datasetGroupMode` is written only when grouping is on and
  /// removed otherwise, so a default install's config has no such key.
  Future<void> _setGroupMode(DataSetGroupMode mode) async {
    setState(() => _groupMode = mode);
    final config = await DeviceStorage.readConfig();
    if (mode == DataSetGroupMode.none) {
      config.remove('datasetGroupMode');
    } else {
      config['datasetGroupMode'] = mode.name;
    }
    await DeviceStorage.writeConfig(config);
  }

  /// Purpose: Open the data set topology.
  /// Inputs: None.
  /// Returns: `Future<void>` that completes when the topology closes.
  /// Side effects: Pushes `DataSetTopologyPage` on the root navigator;
  /// reloads this list afterwards.
  /// Notes: Hands it an editor that completes once the edit page has closed
  /// and a `reload` returning the current data, so an edit made from the
  /// topology shows there at once.
  Future<void> _openTopology() async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => DataSetTopologyPage(
          dataSets: _datasets,
          devices: _devices,
          onEditDataSet: (ds) async {
            await Navigator.of(context, rootNavigator: true).push<bool>(
              MaterialPageRoute(builder: (_) => DataSetEditPage(dataSet: ds)),
            );
          },
          reload: () async {
            await _load();
            return (dataSets: _datasets, devices: _devices);
          },
        ),
      ),
    );
    if (mounted) _load();
  }

  /// Purpose: Save sort prefs to the relevant storage or service layer.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _saveSortPrefs() async {
    final config = await DeviceStorage.readConfig();
    config['datasetSortMode'] = _sortMode.name;
    config['datasetSortAscending'] = _sortAscending;
    await DeviceStorage.writeConfig(config);
  }

  /// Purpose: Provide the internal sorted datasets helper for this file.
  /// Inputs: None.
  /// Returns: `List<DataSet>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  List<DataSet> get _sortedDatasets {
    var list = List<DataSet>.of(_datasets);
    if (_sortMode == DataSetSortMode.custom) return list;
    int comparator(DataSet a, DataSet b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    final effectiveComparator = _sortAscending
        ? (DataSet a, DataSet b) => comparator(b, a)
        : comparator;
    list.sort(effectiveComparator);
    return list;
  }

  /// Purpose: Load the relevant data into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _load() async {
    final dsData = await DataSetStorage.load();
    final devData = await DeviceStorage.load();
    if (!mounted) return;
    setState(() {
      _datasets = dsData.datasets;
      _devices = devData.devices;
      _loading = false;
    });
  }

  /// Purpose: Provide the internal storage lines helper for this file.
  /// Inputs: `ds`.
  /// Returns: `List<String>`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  /// Build structured subtitle lines: group storages by device.
  List<String> _storageLines(DataSet ds) {
    final lines = <String>[];
    for (final link in ds.storageLinks) {
      final device = _devices.where((d) => d.id == link.deviceId).firstOrNull;
      if (device == null) continue;
      final storageParts = <String>[];
      for (final idx in link.storageIndices) {
        if (idx < device.storage.length) {
          storageParts.add(device.storage[idx].displayString);
        }
      }
      for (final id in link.arrayIds) {
        final array = device.storageArrays.where((a) => a.id == id);
        if (array.isNotEmpty) storageParts.add(array.first.displayString);
      }
      if (storageParts.isEmpty) {
        lines.add(device.name);
      } else {
        lines.add('${device.name} – ${storageParts.join(', ')}');
      }
    }
    return lines;
  }

  /// Purpose: Add data set through the current flow.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _addDataSet() async {
    final result = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<bool>(MaterialPageRoute(builder: (_) => const DataSetEditPage()));
    if (result == true) _load();
  }

  /// Purpose: Edit data set and refresh local state when needed.
  /// Inputs: `ds`.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _editDataSet(DataSet ds) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => DataSetEditPage(dataSet: ds)),
    );
    if (result == true) _load();
  }

  /// Purpose: Delete data set from the relevant storage or state.
  /// Inputs: `ds`.
  /// Returns: `Future<void>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
  Future<void> _deleteDataSet(DataSet ds) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteDataSet),
        content: Text(l10n.deleteDataSetConfirm(ds.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DataSetStorage.delete(ds.id);
      AutoSyncService.instance.notifySaved();
      _load();
    }
  }

  /// Purpose: Provide the internal on reorder helper for this file.
  /// Inputs: `oldIndex`, `newIndex`.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: `onReorderItem` already adjusts `newIndex` after removal.
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final item = _datasets.removeAt(oldIndex);
    _datasets.insert(newIndex, item);
    setState(() {});
    // Load the container first so unknown top-level fields survive the save.
    final data = await DataSetStorage.load();
    await DataSetStorage.save(
      DataSetData(datasets: _datasets, extraJson: data.extraJson),
    );
    AutoSyncService.instance.notifySaved();
  }

  /// Purpose: Build and return data set tile for the current context.
  /// Inputs: `ds`; optional `trailing`; `reorderHandle` — true when the
  /// trailing widget is a drag handle, which disables the tap-to-edit;
  /// `subtitle` — replaces the storage-summary subtitle (grouped lists).
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildDataSetTile(
    DataSet ds, {
    Widget? trailing,
    bool reorderHandle = false,
    Widget? subtitle,
  }) {
    final lines = _storageLines(ds);
    return ListTile(
      leading: Text(ds.emoji, style: const TextStyle(fontSize: 28)),
      title: Text(ds.name),
      subtitle:
          subtitle ??
          (lines.isNotEmpty
              ? Text(
                  lines.join('\n'),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                )
              : null),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: reorderHandle ? null : () => _editDataSet(ds),
    );
  }

  /// Purpose: Build one dataset tile for a multi-column row.
  /// Inputs: `ds`, `l10n`; `subtitle` — as for `_buildDataSetTile`.
  /// Returns: `Widget`.
  /// Side effects: None beyond the tile's own handlers.
  /// Notes: Internal helper used within this file only. The single-column
  /// list deletes by swipe; a horizontal drag inside one narrow cell is
  /// ambiguous, so above one column the chevron becomes a menu carrying the
  /// delete action — the only other entrance delete has.
  Widget _buildMenuTile(DataSet ds, AppLocalizations l10n, {Widget? subtitle}) {
    return _buildDataSetTile(
      ds,
      subtitle: subtitle,
      trailing: PopupMenuButton<String>(
        itemBuilder: (_) => [
          PopupMenuItem(value: 'delete', child: Text(l10n.deleteDataSet)),
        ],
        onSelected: (value) {
          if (value == 'delete') _deleteDataSet(ds);
        },
      ),
    );
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state. Updates widget state and triggers a rebuild.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Gate on the whole screen; measure capacity from what the list gets
    // after the navigation rail and the 8 dp the multi-column rows add.
    final screen = MediaQuery.sizeOf(context);
    final contentWidth = shellContentWidth(screen.width) - 16;
    final capacity = canSplitLayout(screen.width, screen.height)
        ? columnCapacity(contentWidth, minItemWidth: dataSetTileMinWidth)
        : 1;
    final columns = listColumnCount(
      screenWidth: screen.width,
      screenHeight: screen.height,
      contentWidth: contentWidth,
      minItemWidth: dataSetTileMinWidth,
      preference: _columnsPref,
    );
    final sorted = _sortedDatasets;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navDataSets),
        actions: [
          if (_reordering)
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: l10n.save,
              onPressed: () => setState(() => _reordering = false),
            )
          else ...[
            IconButton(
              key: const Key('dataset-topology'),
              tooltip: l10n.dataSetTopology,
              onPressed: _loading ? null : _openTopology,
              icon: const Icon(Icons.account_tree_outlined),
            ),
            listColumnsButton(
              context,
              preference: _columnsPref,
              capacity: capacity,
              onChanged: _setColumnsPref,
            ),
            PopupMenuButton<DataSetGroupMode>(
              key: const Key('dataset-group'),
              icon: Icon(
                _groupMode == DataSetGroupMode.none
                    ? Icons.workspaces_outline
                    : Icons.workspaces,
              ),
              tooltip: l10n.dataSetGroupBy,
              itemBuilder: (_) => [
                for (final mode in DataSetGroupMode.values)
                  CheckedPopupMenuItem<DataSetGroupMode>(
                    key: ValueKey('dataset-group-mode-${mode.name}'),
                    value: mode,
                    checked: _groupMode == mode,
                    child: Text(switch (mode) {
                      DataSetGroupMode.none => l10n.dataSetGroupNone,
                      DataSetGroupMode.device => l10n.dataSetGroupByDevice,
                      DataSetGroupMode.storage => l10n.dataSetGroupByStorage,
                    }),
                  ),
              ],
              onSelected: _setGroupMode,
            ),
            PopupMenuButton<dynamic>(
              icon: const Icon(Icons.sort),
              tooltip: l10n.sortTitle,
              itemBuilder: (_) => [
                ...DataSetSortMode.values.map(
                  (m) => CheckedPopupMenuItem<DataSetSortMode>(
                    value: m,
                    checked: _sortMode == m,
                    child: Text(switch (m) {
                      DataSetSortMode.custom => l10n.sortCustom,
                      DataSetSortMode.alphabetical => l10n.sortAlphabetical,
                    }),
                  ),
                ),
                if (_sortMode != DataSetSortMode.custom) ...[
                  const PopupMenuDivider(),
                  CheckedPopupMenuItem<String>(
                    value: 'ascending',
                    checked: _sortAscending,
                    child: Text(l10n.sortAscending),
                  ),
                ],
                if (_sortMode == DataSetSortMode.custom &&
                    _groupMode == DataSetGroupMode.none) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'reorder',
                    child: Text(l10n.sortReorder),
                  ),
                ],
              ],
              onSelected: (value) {
                if (value is DataSetSortMode) {
                  setState(() => _sortMode = value);
                  _saveSortPrefs();
                } else if (value == 'ascending') {
                  setState(() => _sortAscending = !_sortAscending);
                  _saveSortPrefs();
                } else if (value == 'reorder') {
                  setState(() => _reordering = true);
                }
              },
            ),
          ],
        ],
      ),
      floatingActionButton: _reordering
          ? null
          : FloatingActionButton(
              onPressed: _addDataSet,
              child: const Icon(Icons.add),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _datasets.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.noDataSets,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : _reordering
          ? ReorderableListView.builder(
              padding: navBarAwarePadding(context, EdgeInsets.zero),
              itemCount: _datasets.length,
              onReorderItem: _onReorder,
              itemBuilder: (context, index) {
                final ds = _datasets[index];
                return KeyedSubtree(
                  key: ValueKey(ds.id),
                  child: _buildDataSetTile(
                    ds,
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                    reorderHandle: true,
                  ),
                );
              },
            )
          : _groupMode != DataSetGroupMode.none
          ? _buildGroupedList(sorted, columns, l10n)
          : columns > 1
          ? ListView.builder(
              padding: navBarAwarePadding(
                context,
                const EdgeInsets.symmetric(horizontal: 8),
              ),
              itemCount: listRowCount(sorted.length, columns),
              itemBuilder: (context, index) => adaptiveTileRow(
                rowIndex: index,
                columns: columns,
                itemCount: sorted.length,
                itemBuilder: (i) => _buildMenuTile(sorted[i], l10n),
              ),
            )
          : ListView.builder(
              itemCount: sorted.length,
              itemBuilder: (context, index) => _buildSwipeTile(sorted[index]),
            ),
    );
  }

  /// Purpose: Build a single-column tile that deletes on a swipe.
  /// Inputs: `ds`; `key` — the `Dismissible`'s key, `ValueKey(ds.id)` when
  /// null; `subtitle` — as for `_buildDataSetTile`.
  /// Returns: `Widget`.
  /// Side effects: None beyond the tile's own handlers.
  /// Notes: A grouped list shows a data set once per group, so it passes a
  /// key that includes the group.
  Widget _buildSwipeTile(DataSet ds, {Key? key, Widget? subtitle}) {
    return Dismissible(
      key: key ?? ValueKey(ds.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          Icons.delete,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) async {
        await _deleteDataSet(ds);
        return false;
      },
      child: _buildDataSetTile(ds, subtitle: subtitle),
    );
  }

  /// Purpose: Name a group in its header.
  /// Inputs: `group`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Storage groups read "device · storage" (or "device · array").
  String _groupTitle(DataSetGroup group, AppLocalizations l10n) {
    final device = group.device;
    if (device == null) return l10n.dataSetUnlinked;
    final place = group.place;
    if (place == null) return device.name;
    return '${device.name} · ${placeLabel(place, l10n.dataSetStorageFallback)}';
  }

  /// Purpose: Build a tile's subtitle inside a group.
  /// Inputs: `ds`, `group`, `l10n`.
  /// Returns: The copy count, then where else the data set is; null in the
  /// unlinked group.
  /// Side effects: None.
  /// Notes: [dataSetReplicaSummary] words the count; a data set with at most one
  /// usable copy (copies on failed drives do not count) is drawn in the
  /// error colour, since it has no backup. "Also on" lists the other devices in a device group,
  /// the other device-and-storage places in a storage group.
  Widget? _groupedSubtitle(
    DataSet ds,
    DataSetGroup group,
    AppLocalizations l10n,
  ) {
    if (group.isUnlinked) return null;
    final replicas = resolveReplicas(ds, _devices);
    final others = <String>[];
    for (final r in replicas) {
      final String place;
      if (group.place == null) {
        if (r.device.id == group.device!.id) continue;
        place = r.device.name;
      } else {
        if (r.device.id == group.device!.id &&
            r.place.key == group.place!.key) {
          continue;
        }
        place =
            '${r.device.name} – ${placeLabel(r.place, l10n.dataSetStorageFallback)}';
      }
      if (!others.contains(place)) others.add(place);
    }
    final summary = dataSetReplicaSummary(l10n, replicas);
    final theme = Theme.of(context);
    return Text(
      [
        summary.text,
        if (others.isNotEmpty) l10n.dataSetAlsoOn(others.join(', ')),
      ].join('\n'),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: summary.warn ? TextStyle(color: theme.colorScheme.error) : null,
    );
  }

  /// Purpose: Build the grouped list.
  /// Inputs: `sorted` — the data sets in display order; `columns`, `l10n`.
  /// Returns: A `ListView` of group headers (keyed `dataset-group-<key>`)
  /// each followed by its tiles.
  /// Side effects: None.
  /// Notes: One column swipes to delete; more columns use the menu tile.
  Widget _buildGroupedList(
    List<DataSet> sorted,
    int columns,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    for (final group in groupDataSets(sorted, _devices, _groupMode)) {
      final count = group.dataSets.length;
      children.add(
        Padding(
          key: ValueKey('dataset-group-${group.key}'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            '${_groupTitle(group, l10n)} ($count)',
            style: theme.textTheme.titleSmall?.copyWith(
              color: group.isUnlinked
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.primary,
            ),
          ),
        ),
      );
      if (columns == 1) {
        for (final ds in group.dataSets) {
          children.add(
            _buildSwipeTile(
              ds,
              key: ValueKey('${group.key}/${ds.id}'),
              subtitle: _groupedSubtitle(ds, group, l10n),
            ),
          );
        }
        continue;
      }
      for (var row = 0; row < listRowCount(count, columns); row++) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: adaptiveTileRow(
              rowIndex: row,
              columns: columns,
              itemCount: count,
              itemBuilder: (i) => _buildMenuTile(
                group.dataSets[i],
                l10n,
                subtitle: _groupedSubtitle(group.dataSets[i], group, l10n),
              ),
            ),
          ),
        );
      }
    }
    return ListView(
      padding: navBarAwarePadding(context, EdgeInsets.zero),
      children: children,
    );
  }
}
