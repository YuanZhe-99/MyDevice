import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../devices/services/device_storage.dart';
import '../models/network.dart';
import '../services/network_storage.dart';
import 'network_detail_page.dart';
import 'network_edit_page.dart';

enum NetworkSortMode { custom, alphabetical, subnet }

class NetworkListPage extends StatefulWidget {
  const NetworkListPage({super.key});

  @override
  State<NetworkListPage> createState() => _NetworkListPageState();
}

class _NetworkListPageState extends State<NetworkListPage> {
  List<Network> _networks = [];
  NetworkSortMode _sortMode = NetworkSortMode.custom;
  bool _sortAscending = false;
  bool _reordering = false;

  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnLocalDataChanged(_handleLocalDataChanged);
    _loadSortPrefs().then((_) => _load());
  }

  @override
  void dispose() {
    AutoSyncService.instance.removeOnLocalDataChanged(_handleLocalDataChanged);
    super.dispose();
  }

  void _handleLocalDataChanged() {
    if (mounted) _load();
  }

  Future<void> _loadSortPrefs() async {
    final config = await DeviceStorage.readConfig();
    final mode = config['networkSortMode'] as String?;
    final asc = config['networkSortAscending'] as bool? ?? false;
    setState(() {
      _sortMode =
          NetworkSortMode.values.where((e) => e.name == mode).firstOrNull ??
          NetworkSortMode.custom;
      _sortAscending = asc;
    });
  }

  Future<void> _saveSortPrefs() async {
    final config = await DeviceStorage.readConfig();
    config['networkSortMode'] = _sortMode.name;
    config['networkSortAscending'] = _sortAscending;
    await DeviceStorage.writeConfig(config);
  }

  List<Network> get _sortedNetworks {
    var list = List<Network>.of(_networks);
    if (_sortMode == NetworkSortMode.custom) return list;
    int Function(Network, Network) comparator;
    if (_sortMode == NetworkSortMode.alphabetical) {
      comparator = (a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase());
    } else {
      // subnet: nulls last
      comparator = (a, b) {
        if (a.subnet == null && b.subnet == null) return 0;
        if (a.subnet == null) return 1;
        if (b.subnet == null) return -1;
        return a.subnet!.compareTo(b.subnet!);
      };
    }
    final effectiveComparator = _sortAscending
        ? (Network a, Network b) => comparator(b, a)
        : comparator;
    list.sort(effectiveComparator);
    return list;
  }

  Future<void> _load() async {
    final data = await NetworkStorage.load();
    if (mounted) setState(() => _networks = data.networks);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _networks.removeAt(oldIndex);
    _networks.insert(newIndex, item);
    setState(() {});
    final data = await NetworkStorage.load();
    await NetworkStorage.save(
      NetworkData(networks: _networks, assignments: data.assignments),
    );
  }

  IconData _typeIcon(NetworkType type) => switch (type) {
    NetworkType.lan => Icons.router,
    NetworkType.tailscale => Icons.vpn_lock,
    NetworkType.zerotier => Icons.vpn_lock,
    NetworkType.easytier => Icons.vpn_lock,
    NetworkType.wireguard => Icons.vpn_lock,
    NetworkType.other => Icons.lan,
  };

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

  String _sortModeLabel(AppLocalizations l10n, NetworkSortMode mode) =>
      switch (mode) {
        NetworkSortMode.custom => l10n.sortCustom,
        NetworkSortMode.alphabetical => l10n.sortAlphabetical,
        NetworkSortMode.subnet => l10n.sortSubnet,
      };

  Widget _buildNetworkCard(
    Network net,
    ColorScheme cs,
    AppLocalizations l10n, {
    Widget? trailing,
  }) {
    final logo = _typeLogo[net.type];
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: logo != null
              ? SvgPicture.asset(
                  logo,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    cs.onPrimaryContainer,
                    BlendMode.srcIn,
                  ),
                )
              : Icon(_typeIcon(net.type), color: cs.onPrimaryContainer),
        ),
        title: Text(net.name),
        subtitle: Text(
          [
            _typeLabel(l10n, net.type),
            if (net.subnet != null) net.subnet,
          ].join(' · '),
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: trailing != null
            ? null
            : () async {
                await Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => NetworkDetailPage(networkId: net.id),
                  ),
                );
                _load();
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navNetworks),
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
                ...NetworkSortMode.values.map(
                  (m) => CheckedPopupMenuItem<NetworkSortMode>(
                    value: m,
                    checked: _sortMode == m,
                    child: Text(_sortModeLabel(l10n, m)),
                  ),
                ),
                if (_sortMode != NetworkSortMode.custom) ...[
                  const PopupMenuDivider(),
                  CheckedPopupMenuItem<String>(
                    value: 'ascending',
                    checked: _sortAscending,
                    child: Text(l10n.sortAscending),
                  ),
                ],
                if (_sortMode == NetworkSortMode.custom) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'reorder',
                    child: Text(l10n.sortReorder),
                  ),
                ],
              ],
              onSelected: (value) {
                if (value is NetworkSortMode) {
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
      body: _networks.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.noNetworks,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          : _reordering
          ? ReorderableListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _networks.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final net = _networks[index];
                return KeyedSubtree(
                  key: ValueKey(net.id),
                  child: _buildNetworkCard(
                    net,
                    cs,
                    l10n,
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                  ),
                );
              },
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _sortedNetworks.length,
              itemBuilder: (context, index) {
                final net = _sortedNetworks[index];
                return _buildNetworkCard(net, cs, l10n);
              },
            ),
      floatingActionButton: _reordering
          ? null
          : FloatingActionButton(
              onPressed: () async {
                await Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => const NetworkEditPage()),
                );
                _load();
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}
