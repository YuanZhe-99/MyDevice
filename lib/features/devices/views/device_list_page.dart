import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../app/flavor.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../../shared/services/image_service.dart';
import '../../../shared/views/device_map_page.dart';
import '../models/device.dart';
import '../services/device_storage.dart';
import '../services/preset_service.dart';
import 'device_detail_page.dart';
import 'device_edit_page.dart';
import 'device_search_dialog.dart';
import '../widgets/device_category_icon.dart';

enum SortMode { custom, alphabetical, purchaseDate, releaseDate }

class DeviceListPage extends StatefulWidget {
  const DeviceListPage({super.key});

  @override
  State<DeviceListPage> createState() => _DeviceListPageState();
}

class _DeviceListPageState extends State<DeviceListPage> {
  List<Device> _devices = [];
  bool _loading = true;
  SortMode _sortMode = SortMode.custom;
  bool _groupByCategory = false;
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadSortPrefs().then((_) => _loadDevices());
  }

  Future<void> _loadSortPrefs() async {
    final config = await DeviceStorage.readConfig();
    final mode = config['sortMode'] as String?;
    final group = config['groupByCategory'] as bool? ?? false;
    final asc = config['sortAscending'] as bool? ?? false;
    setState(() {
      _sortMode = SortMode.values.where((e) => e.name == mode).firstOrNull ??
          SortMode.custom;
      _groupByCategory = group;
      _sortAscending = asc;
    });
  }

  Future<void> _saveSortPrefs() async {
    final config = await DeviceStorage.readConfig();
    config['sortMode'] = _sortMode.name;
    config['groupByCategory'] = _groupByCategory;
    config['sortAscending'] = _sortAscending;
    await DeviceStorage.writeConfig(config);
  }

  /// Returns the sorted / grouped list for display.
  List<Device> get _sortedDevices {
    var list = List<Device>.of(_devices);
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
      comparator = (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
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

  Future<void> _loadDevices() async {
    final data = await DeviceStorage.load();
    setState(() {
      _devices = data.devices;
      _loading = false;
    });
  }

  Future<void> _addDevice() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const DeviceEditPage()),
    );
    await _loadDevices();
  }

  Future<void> _addFromSearch() async {
    final result = await showDeviceSearchDialog(context);
    if (result == null || !mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => DeviceEditPage(searchResult: result),
      ),
    );
    await _loadDevices();
  }

  Future<void> _editDevice(Device device) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => DeviceEditPage(device: device),
      ),
    );
    await _loadDevices();
  }

  Future<void> _viewDevice(Device device) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => DeviceDetailPage(
          device: device,
          onDeviceChanged: () {},
        ),
      ),
    );
    await _loadDevices();
  }

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

  Future<void> _addFromTemplate() async {
    final templates = await PresetService.loadTemplates();
    if (!mounted) return;
    final template = await showModalBottomSheet<DeviceTemplate>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TemplatePicker(templates: templates),
    );
    if (template != null && mounted) {
      final cpus = await PresetService.loadCpus();
      final gpus = await PresetService.loadGpus();
      final device = template.toDevice(cpuPresets: cpus, gpuPresets: gpus);
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => DeviceEditPage(device: device),
        ),
      );
      await _loadDevices();
    }
  }

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

  String _sortModeLabel(AppLocalizations l10n, SortMode mode) => switch (mode) {
        SortMode.custom => l10n.sortCustom,
        SortMode.alphabetical => l10n.sortAlphabetical,
        SortMode.purchaseDate => l10n.sortPurchaseDate,
        SortMode.releaseDate => l10n.sortReleaseDate,
      };

  void _setSortMode(SortMode mode) {
    setState(() => _sortMode = mode);
    _saveSortPrefs();
  }

  void _toggleGroupByCategory() {
    setState(() => _groupByCategory = !_groupByCategory);
    _saveSortPrefs();
  }

  void _toggleSortOrder() {
    setState(() => _sortAscending = !_sortAscending);
    _saveSortPrefs();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _devices.removeAt(oldIndex);
    _devices.insert(newIndex, item);
    setState(() {});
    await DeviceStorage.save(DeviceData(devices: _devices));
  }

  bool _reordering = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

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
                if (_sortMode == SortMode.custom) ...[
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
                      onReorder: _onReorder,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        return _DeviceCard(
                          key: ValueKey(device.id),
                          device: device,
                          categoryLabel: _categoryLabel(context, device.category),
                          onTap: () {},
                          trailing: ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle),
                          ),
                        );
                      },
                    )
                  : _buildDeviceList(l10n, theme),
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
                if (AppFlavor.isFull)
                  const SizedBox(height: 8),
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

  Widget _buildDeviceList(AppLocalizations l10n, ThemeData theme) {
    final sorted = _sortedDevices;
    // Insert category headers when grouping
    if (_groupByCategory && sorted.isNotEmpty) {
      final widgets = <Widget>[];
      DeviceCategory? lastCat;
      for (final device in sorted) {
        if (device.category != lastCat) {
          lastCat = device.category;
          widgets.add(
            Padding(
              key: ValueKey('header_${device.category.name}'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                _categoryLabel(context, device.category),
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
          );
        }
        widgets.add(_buildDismissibleCard(device, l10n, theme));
      }
      return ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: widgets,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: sorted.length,
      itemBuilder: (context, index) =>
          _buildDismissibleCard(sorted[index], l10n, theme),
    );
  }

  Widget _buildDismissibleCard(
      Device device, AppLocalizations l10n, ThemeData theme) {
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
        onTap: () => _viewDevice(device),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final Device device;
  final String categoryLabel;
  final VoidCallback onTap;
  final Widget? trailing;

  const _DeviceCard({
    super.key,
    required this.device,
    required this.categoryLabel,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[categoryLabel];
    if (device.brand != null) subtitleParts.add(device.brand!);
    if (device.cpu.model != null) subtitleParts.add(device.cpu.model!);
    if (device.storage.isNotEmpty) {
      final total = device.storage
          .where((s) => s.capacity != null)
          .map((s) => s.capacity!)
          .join(' + ');
      if (total.isNotEmpty) subtitleParts.add(total);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: _buildLeading(theme),
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

  Widget _buildLeading(ThemeData theme) {
    if (device.emoji != null) {
      return CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(device.emoji!, style: const TextStyle(fontSize: 20)),
      );
    }
    if (device.imagePath != null) {
      return FutureBuilder<File>(
        future: ImageService.resolve(device.imagePath!),
        builder: (context, snap) {
          if (snap.hasData && snap.data!.existsSync()) {
            return CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: ClipOval(
                child: Image.file(
                  snap.data!,
                  fit: BoxFit.contain,
                  width: 40,
                  height: 40,
                ),
              ),
            );
          }
          return CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              deviceCategoryIcon(device.category),
              color: theme.colorScheme.onPrimaryContainer,
            ),
          );
        },
      );
    }
    return CircleAvatar(
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Icon(
        deviceCategoryIcon(device.category),
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _TemplatePicker extends StatefulWidget {
  final List<DeviceTemplate> templates;

  const _TemplatePicker({required this.templates});

  @override
  State<_TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<_TemplatePicker> {
  String _query = '';

  List<DeviceTemplate> get _filtered {
    if (_query.isEmpty) return widget.templates;
    final q = _query.toLowerCase();
    return widget.templates
        .where((t) => t.name.toLowerCase().contains(q))
        .toList();
  }

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
            child: Text(l10n.fromTemplate,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search...',
                border: OutlineInputBorder(),
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
                    [t.brand, t.cpu, t.ram]
                        .where((s) => s != null)
                        .join(' · '),
                  ),
                  dense: true,
                  onTap: () => Navigator.pop(context, t),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
