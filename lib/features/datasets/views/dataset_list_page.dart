import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/widgets/adaptive_tile_grid.dart';
import '../../devices/models/device.dart';
import '../../devices/services/device_storage.dart';
import '../models/dataset.dart';
import '../services/dataset_storage.dart';
import 'dataset_edit_page.dart';

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

  /// Purpose: Load sort prefs into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _loadSortPrefs() async {
    final config = await DeviceStorage.readConfig();
    final mode = config['datasetSortMode'] as String?;
    final asc = config['datasetSortAscending'] as bool? ?? false;
    final columns = await DeviceStorage.getDataSetListColumns();
    if (!mounted) return;
    setState(() {
      _sortMode =
          DataSetSortMode.values.where((e) => e.name == mode).firstOrNull ??
          DataSetSortMode.custom;
      _sortAscending = asc;
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
    await DataSetStorage.save(DataSetData(datasets: _datasets));
    AutoSyncService.instance.notifySaved();
  }

  /// Purpose: Build and return data set tile for the current context.
  /// Inputs: `ds`; optional `trailing`; `reorderHandle` — true when the
  /// trailing widget is a drag handle, which disables the tap-to-edit.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildDataSetTile(
    DataSet ds, {
    Widget? trailing,
    bool reorderHandle = false,
  }) {
    final lines = _storageLines(ds);
    return ListTile(
      leading: Text(ds.emoji, style: const TextStyle(fontSize: 28)),
      title: Text(ds.name),
      subtitle: lines.isNotEmpty
          ? Text(lines.join('\n'), maxLines: 4, overflow: TextOverflow.ellipsis)
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: reorderHandle ? null : () => _editDataSet(ds),
    );
  }

  /// Purpose: Build one dataset tile for a multi-column row.
  /// Inputs: `ds`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None beyond the tile's own handlers.
  /// Notes: Internal helper used within this file only. The single-column
  /// list deletes by swipe; a horizontal drag inside one narrow cell is
  /// ambiguous, so above one column the chevron becomes a menu carrying the
  /// delete action — the only other entrance delete has.
  Widget _buildMenuTile(DataSet ds, AppLocalizations l10n) {
    return _buildDataSetTile(
      ds,
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
                if (_sortMode == DataSetSortMode.custom) ...[
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
          : columns > 1
          ? ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
              itemBuilder: (context, index) {
                final ds = sorted[index];
                return Dismissible(
                  key: ValueKey(ds.id),
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
                  child: _buildDataSetTile(ds),
                );
              },
            ),
    );
  }
}
