import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../../shared/views/device_map_page.dart';
import '../../devices/models/device.dart';
import '../../devices/services/device_storage.dart';
import '../models/network.dart';
import '../services/network_storage.dart';
import 'network_edit_page.dart';

enum NetworkDeviceSortMode { deviceOrder, alphabetical, ip }

class NetworkDetailPage extends StatefulWidget {
  final String networkId;

  const NetworkDetailPage({super.key, required this.networkId});

  @override
  State<NetworkDetailPage> createState() => _NetworkDetailPageState();
}

class _NetworkDetailPageState extends State<NetworkDetailPage> {
  Network? _network;
  List<NetworkDevice> _assignments = [];
  List<Device> _allDevices = [];
  NetworkDeviceSortMode _sortMode = NetworkDeviceSortMode.deviceOrder;
  bool _sortAscending = false;
  bool _groupByCategory = false;
  bool _exitNodeFirst = false;

  @override
  void initState() {
    super.initState();
    _loadSortPrefs().then((_) => _load());
  }

  Future<void> _loadSortPrefs() async {
    final config = await DeviceStorage.readConfig();
    final mode = config['netDetailSortMode'] as String?;
    final asc = config['netDetailSortAscending'] as bool? ?? false;
    final group = config['netDetailGroupByCategory'] as bool? ?? false;
    final exitFirst = config['netDetailExitFirst'] as bool? ?? false;
    setState(() {
      _sortMode = NetworkDeviceSortMode.values
              .where((e) => e.name == mode)
              .firstOrNull ??
          NetworkDeviceSortMode.deviceOrder;
      _sortAscending = asc;
      _groupByCategory = group;
      _exitNodeFirst = exitFirst;
    });
  }

  Future<void> _saveSortPrefs() async {
    final config = await DeviceStorage.readConfig();
    config['netDetailSortMode'] = _sortMode.name;
    config['netDetailSortAscending'] = _sortAscending;
    config['netDetailGroupByCategory'] = _groupByCategory;
    config['netDetailExitFirst'] = _exitNodeFirst;
    await DeviceStorage.writeConfig(config);
  }

  int _compareIp(String? a, String? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    final aParts = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final bParts = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < 4 && i < aParts.length && i < bParts.length; i++) {
      final cmp = aParts[i].compareTo(bParts[i]);
      if (cmp != 0) return cmp;
    }
    return a.compareTo(b);
  }

  List<NetworkDevice> get _sortedAssignments {
    var list = List<NetworkDevice>.of(_assignments);

    int Function(NetworkDevice, NetworkDevice) comparator;
    switch (_sortMode) {
      case NetworkDeviceSortMode.deviceOrder:
        comparator = (a, b) {
          final ai = _allDevices.indexWhere((d) => d.id == a.deviceId);
          final bi = _allDevices.indexWhere((d) => d.id == b.deviceId);
          return ai.compareTo(bi);
        };
      case NetworkDeviceSortMode.alphabetical:
        comparator = (a, b) {
          final aName = _findDevice(a.deviceId)?.name ?? a.deviceId;
          final bName = _findDevice(b.deviceId)?.name ?? b.deviceId;
          return aName.toLowerCase().compareTo(bName.toLowerCase());
        };
      case NetworkDeviceSortMode.ip:
        comparator = (a, b) => _compareIp(a.ipAddress, b.ipAddress);
    }

    final effectiveComparator = _sortAscending
        ? (NetworkDevice a, NetworkDevice b) => comparator(b, a)
        : comparator;

    if (_groupByCategory) {
      list.sort((a, b) {
        final aCat =
            _findDevice(a.deviceId)?.category ?? DeviceCategory.other;
        final bCat =
            _findDevice(b.deviceId)?.category ?? DeviceCategory.other;
        final cmp = aCat.index.compareTo(bCat.index);
        if (cmp != 0) return cmp;
        return effectiveComparator(a, b);
      });
    } else {
      list.sort(effectiveComparator);
    }

    if (_exitNodeFirst) {
      final exits = list.where((a) => a.isExitNode).toList();
      final rest = list.where((a) => !a.isExitNode).toList();
      list = [...exits, ...rest];
    }

    return list;
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

  String _sortModeLabel(AppLocalizations l10n, NetworkDeviceSortMode mode) =>
      switch (mode) {
        NetworkDeviceSortMode.deviceOrder => l10n.sortCustom,
        NetworkDeviceSortMode.alphabetical => l10n.sortAlphabetical,
        NetworkDeviceSortMode.ip => l10n.sortByIp,
      };

  Future<void> _load() async {
    final netData = await NetworkStorage.load();
    final devData = await DeviceStorage.load();
    if (!mounted) return;
    setState(() {
      _network = netData.networks
          .where((n) => n.id == widget.networkId)
          .firstOrNull;
      _assignments = netData.assignments
          .where((a) => a.networkId == widget.networkId)
          .toList();
      _allDevices = devData.devices;
    });
  }

  Device? _findDevice(String id) =>
      _allDevices.where((d) => d.id == id).firstOrNull;

  static const _typeLogo = {
    NetworkType.tailscale: 'assets/logos/tailscale.svg',
    NetworkType.zerotier: 'assets/logos/zerotier.svg',
    NetworkType.wireguard: 'assets/logos/wireguard.svg',
  };

  String _typeLabel(AppLocalizations l10n, NetworkType type) => switch (type) {
        NetworkType.lan => l10n.networkTypeLan,
        NetworkType.tailscale => l10n.networkTypeTailscale,
        NetworkType.zerotier => l10n.networkTypeZerotier,
        NetworkType.easytier => l10n.networkTypeEasytier,
        NetworkType.wireguard => l10n.networkTypeWireguard,
        NetworkType.other => l10n.networkTypeOther,
      };

  String _addressModeLabel(AppLocalizations l10n, AddressMode mode) =>
      switch (mode) {
        AddressMode.dhcp => l10n.addressModeDhcp,
        AddressMode.static_ => l10n.addressModeStatic,
      };

  Future<void> _deleteNetwork() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteNetwork),
        content: Text(l10n.deleteNetworkConfirm),
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
    if (confirm == true) {
      await NetworkStorage.deleteNetwork(widget.networkId);
      AutoSyncService.instance.notifySaved();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _addDevice() async {
    final assignedIds = _assignments.map((a) => a.deviceId).toSet();
    final available = _allDevices.where((d) => !assignedIds.contains(d.id)).toList();
    if (available.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final device = await showModalBottomSheet<Device>(
      context: context,
      builder: (ctx) => _DevicePicker(devices: available),
    );
    if (device == null || !mounted) return;

    // Show configuration dialog
    final result = await _showAssignmentDialog(
      l10n,
      NetworkDevice(
        networkId: widget.networkId,
        deviceId: device.id,
      ),
    );
    if (result != null) {
      await NetworkStorage.setAssignment(result);
      AutoSyncService.instance.notifySaved();
      _load();
    }
  }

  Future<void> _editAssignment(NetworkDevice assignment) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await _showAssignmentDialog(l10n, assignment);
    if (result != null) {
      await NetworkStorage.setAssignment(result);
      AutoSyncService.instance.notifySaved();
      _load();
    }
  }

  Future<void> _removeAssignment(NetworkDevice assignment) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeDevice),
        content: Text(l10n.removeDeviceConfirm),
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
    if (confirm == true) {
      await NetworkStorage.removeAssignment(
          assignment.networkId, assignment.deviceId);
      AutoSyncService.instance.notifySaved();
      _load();
    }
  }

  Future<NetworkDevice?> _showAssignmentDialog(
      AppLocalizations l10n, NetworkDevice initial) async {
    var mode = initial.addressMode;
    final ipCtrl = TextEditingController(text: initial.ipAddress ?? '');
    final hostnameCtrl = TextEditingController(text: initial.hostname ?? '');
    var isExit = initial.isExitNode;

    return showDialog<NetworkDevice>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.networkDeviceConfig),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AddressMode>(
                  value: mode,
                  decoration: InputDecoration(labelText: l10n.networkAddressMode),
                  items: AddressMode.values
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(_addressModeLabel(l10n, m)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => mode = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ipCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.networkIpAddress,
                    hintText: 'e.g. 192.168.1.100',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: hostnameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.networkHostname,
                    hintText: 'e.g. my-server',
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: isExit,
                  title: Text(l10n.networkExitNode),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) =>
                      setDialogState(() => isExit = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                final ip = ipCtrl.text.trim();
                final hostname = hostnameCtrl.text.trim();
                Navigator.pop(
                  ctx,
                  NetworkDevice(
                    networkId: initial.networkId,
                    deviceId: initial.deviceId,
                    addressMode: mode,
                    ipAddress: ip.isEmpty ? null : ip,
                    hostname: hostname.isEmpty ? null : hostname,
                    isExitNode: isExit,
                  ),
                );
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_network == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final net = _network!;

    return Scaffold(
      appBar: AppBar(
        title: Text(net.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: l10n.mapViewNetworkDevices,
            onPressed: () {
              final devicesInNetwork = _assignments
                  .map((a) => _findDevice(a.deviceId))
                  .whereType<Device>()
                  .toList();
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => DeviceMapPage(
                    title: l10n.mapViewNetworkDevices,
                    devices: devicesInNetwork,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => NetworkEditPage(network: net),
                ),
              );
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteNetwork,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Network info ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_typeLogo.containsKey(net.type))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SvgPicture.asset(
                        _typeLogo[net.type]!,
                        width: 32,
                        height: 32,
                        colorFilter: ColorFilter.mode(
                            cs.onSurface, BlendMode.srcIn),
                      ),
                    ),
                  _infoRow(l10n.networkType, _typeLabel(l10n, net.type)),
                  if (net.subnet != null)
                    _infoRow(l10n.networkSubnet, net.subnet!),
                  if (net.gateway != null)
                    _infoRow(l10n.networkGateway, net.gateway!),
                  if (net.dnsServers.isNotEmpty)
                    _infoRow(l10n.networkDns, net.dnsServers.join(', ')),
                  if (net.notes != null)
                    _infoRow(l10n.deviceNotes, net.notes!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Devices header ──
          Row(
            children: [
              Icon(Icons.devices, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(l10n.networkDevices,
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: cs.primary, fontWeight: FontWeight.w600)),
              const Spacer(),
              PopupMenuButton<dynamic>(
                icon: const Icon(Icons.sort, size: 20),
                tooltip: l10n.sortTitle,
                itemBuilder: (_) => [
                  ...NetworkDeviceSortMode.values.map(
                    (m) => CheckedPopupMenuItem<NetworkDeviceSortMode>(
                      value: m,
                      checked: _sortMode == m,
                      child: Text(_sortModeLabel(l10n, m)),
                    ),
                  ),
                  const PopupMenuDivider(),
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
                  CheckedPopupMenuItem<String>(
                    value: 'exitFirst',
                    checked: _exitNodeFirst,
                    child: Text(l10n.sortExitNodeFirst),
                  ),
                ],
                onSelected: (value) {
                  if (value is NetworkDeviceSortMode) {
                    setState(() => _sortMode = value);
                  } else if (value == 'ascending') {
                    setState(() => _sortAscending = !_sortAscending);
                  } else if (value == 'group') {
                    setState(
                        () => _groupByCategory = !_groupByCategory);
                  } else if (value == 'exitFirst') {
                    setState(
                        () => _exitNodeFirst = !_exitNodeFirst);
                  }
                  _saveSortPrefs();
                },
              ),
              TextButton.icon(
                onPressed: _addDevice,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addDevice),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_assignments.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(l10n.noNetworkDevices,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              ),
            )
          else
            ..._buildDeviceList(l10n, cs),
        ],
      ),
    );
  }

  List<Widget> _buildDeviceList(AppLocalizations l10n, ColorScheme cs) {
    final sorted = _sortedAssignments;
    if (!_groupByCategory) {
      return sorted.map((a) => _buildDeviceCard(a, l10n, cs)).toList();
    }
    // Group by category with headers
    final widgets = <Widget>[];
    DeviceCategory? lastCat;
    for (final a in sorted) {
      final dev = _findDevice(a.deviceId);
      final cat = dev?.category ?? DeviceCategory.other;
      if (cat != lastCat) {
        lastCat = cat;
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
          child: Text(
            _categoryLabel(context, cat),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
        ));
      }
      widgets.add(_buildDeviceCard(a, l10n, cs));
    }
    return widgets;
  }

  Widget _buildDeviceCard(
      NetworkDevice a, AppLocalizations l10n, ColorScheme cs) {
    final dev = _findDevice(a.deviceId);
    final subtitle = [
      _addressModeLabel(l10n, a.addressMode),
      if (a.ipAddress != null) a.ipAddress!,
      if (a.hostname != null) a.hostname!,
      if (a.isExitNode) l10n.networkExitNode,
    ].join(' · ');

    return Card(
      child: ListTile(
        leading: Icon(Icons.device_hub, color: cs.primary),
        title: Text(dev?.name ?? a.deviceId),
        subtitle: Text(subtitle),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _editAssignment(a);
            if (v == 'remove') _removeAssignment(a);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(l10n.editNetwork)),
            PopupMenuItem(value: 'remove', child: Text(l10n.removeDevice)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

/// Bottom sheet to pick a device.
class _DevicePicker extends StatelessWidget {
  final List<Device> devices;

  const _DevicePicker({required this.devices});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            AppLocalizations.of(context)!.networkPickDevice,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final d = devices[index];
              return ListTile(
                leading: const Icon(Icons.device_hub),
                title: Text(d.name),
                subtitle: Text([d.brand, d.model]
                    .where((s) => s != null)
                    .join(' ')),
                onTap: () => Navigator.pop(context, d),
              );
            },
          ),
        ),
      ],
    );
  }
}
