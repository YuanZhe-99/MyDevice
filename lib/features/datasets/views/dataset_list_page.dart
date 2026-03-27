import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../devices/models/device.dart';
import '../../devices/services/device_storage.dart';
import '../models/dataset.dart';
import '../services/dataset_storage.dart';
import 'dataset_edit_page.dart';

enum DataSetSortMode { custom, alphabetical }

class DataSetListPage extends StatefulWidget {
  const DataSetListPage({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadSortPrefs().then((_) => _load());
  }

  Future<void> _loadSortPrefs() async {
    final config = await DeviceStorage.readConfig();
    final mode = config['datasetSortMode'] as String?;
    final asc = config['datasetSortAscending'] as bool? ?? false;
    setState(() {
      _sortMode = DataSetSortMode.values
              .where((e) => e.name == mode)
              .firstOrNull ??
          DataSetSortMode.custom;
      _sortAscending = asc;
    });
  }

  Future<void> _saveSortPrefs() async {
    final config = await DeviceStorage.readConfig();
    config['datasetSortMode'] = _sortMode.name;
    config['datasetSortAscending'] = _sortAscending;
    await DeviceStorage.writeConfig(config);
  }

  List<DataSet> get _sortedDatasets {
    var list = List<DataSet>.of(_datasets);
    if (_sortMode == DataSetSortMode.custom) return list;
    int Function(DataSet, DataSet) comparator =
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
    final effectiveComparator = _sortAscending
        ? (DataSet a, DataSet b) => comparator(b, a)
        : comparator;
    list.sort(effectiveComparator);
    return list;
  }

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

  Future<void> _addDataSet() async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => const DataSetEditPage()),
    );
    if (result == true) _load();
  }

  Future<void> _editDataSet(DataSet ds) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => DataSetEditPage(dataSet: ds)),
    );
    if (result == true) _load();
  }

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

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _datasets.removeAt(oldIndex);
    _datasets.insert(newIndex, item);
    setState(() {});
    await DataSetStorage.save(DataSetData(datasets: _datasets));
    AutoSyncService.instance.notifySaved();
  }

  Widget _buildDataSetTile(DataSet ds, {Widget? trailing}) {
    final lines = _storageLines(ds);
    return ListTile(
      leading: Text(ds.emoji, style: const TextStyle(fontSize: 28)),
      title: Text(ds.name),
      subtitle: lines.isNotEmpty
          ? Text(
              lines.join('\n'),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: trailing != null ? null : () => _editDataSet(ds),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
          else
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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                )
              : _reordering
                  ? ReorderableListView.builder(
                      itemCount: _datasets.length,
                      onReorder: _onReorder,
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
                          ),
                        );
                      },
                    )
                  : ListView.builder(
                      itemCount: _sortedDatasets.length,
                      itemBuilder: (context, index) {
                        final ds = _sortedDatasets[index];
                        return Dismissible(
                          key: ValueKey(ds.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            color:
                                Theme.of(context).colorScheme.errorContainer,
                            child: Icon(Icons.delete,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer),
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
