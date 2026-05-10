import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../devices/models/device.dart';
import '../../devices/services/device_storage.dart';
import '../../network/models/network.dart';
import '../../network/services/network_storage.dart';
import '../models/service.dart';
import '../services/service_analysis.dart';
import '../services/service_storage.dart';
import 'service_edit_page.dart';
import 'service_route_edit_page.dart';

enum _ServiceView { overview, devices, routes, ports }

class ServiceListPage extends StatefulWidget {
  const ServiceListPage({super.key});

  @override
  State<ServiceListPage> createState() => _ServiceListPageState();
}

class _ServiceListPageState extends State<ServiceListPage> {
  List<ServiceNode> _services = [];
  List<ServiceRoute> _routes = [];
  List<Device> _devices = [];
  List<Network> _networks = [];
  _ServiceView _view = _ServiceView.overview;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnLocalDataChanged(_handleLocalDataChanged);
    _load();
  }

  @override
  void dispose() {
    AutoSyncService.instance.removeOnLocalDataChanged(_handleLocalDataChanged);
    super.dispose();
  }

  void _handleLocalDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final serviceData = await ServiceStorage.load();
    final deviceData = await DeviceStorage.load();
    final networkData = await NetworkStorage.load();
    if (!mounted) return;
    setState(() {
      _services = serviceData.services;
      _routes = serviceData.routes;
      _devices = deviceData.devices;
      _networks = networkData.networks;
      _loading = false;
    });
  }

  Device? _deviceById(String id) =>
      _devices.where((device) => device.id == id).firstOrNull;

  ServiceNode? _serviceById(String id) =>
      _services.where((service) => service.id == id).firstOrNull;

  ServiceEndpoint? _endpointById(ServiceNode service, String? endpointId) {
    if (endpointId == null) return service.endpoints.firstOrNull;
    return service.endpoints
        .where((endpoint) => endpoint.id == endpointId)
        .firstOrNull;
  }

  Future<void> _addService() async {
    final result = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ServiceEditPage()));
    if (result == true) _load();
  }

  Future<void> _editService(ServiceNode service) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => ServiceEditPage(service: service)),
    );
    if (result == true) _load();
  }

  Future<void> _addRoute({ServiceNode? source}) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => ServiceRouteEditPage(sourceService: source),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _editRoute(ServiceRoute route) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => ServiceRouteEditPage(route: route)),
    );
    if (result == true) _load();
  }

  String _viewLabel(AppLocalizations l10n, _ServiceView view) => switch (view) {
    _ServiceView.overview => l10n.servicesOverview,
    _ServiceView.devices => l10n.servicesByDevice,
    _ServiceView.routes => l10n.serviceRoutes,
    _ServiceView.ports => l10n.servicePorts,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navServices),
        actions: [
          IconButton(
            icon: const Icon(Icons.alt_route),
            tooltip: l10n.addServiceRoute,
            onPressed: _services.isEmpty ? null : () => _addRoute(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addService,
            onPressed: _addService,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addService,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_ServiceView>(
                    segments: [
                      for (final view in _ServiceView.values)
                        ButtonSegment(
                          value: view,
                          label: Text(_viewLabel(l10n, view)),
                        ),
                    ],
                    selected: {_view},
                    onSelectionChanged: (selected) {
                      setState(() => _view = selected.single);
                    },
                  ),
                ),
                Expanded(child: _buildCurrentView(l10n)),
              ],
            ),
    );
  }

  Widget _buildCurrentView(AppLocalizations l10n) => switch (_view) {
    _ServiceView.overview => _buildOverview(l10n),
    _ServiceView.devices => _buildDevices(l10n),
    _ServiceView.routes => _buildRoutes(l10n),
    _ServiceView.ports => _buildPorts(l10n),
  };

  Widget _buildOverview(AppLocalizations l10n) {
    if (_services.isEmpty) return _emptyState(l10n.noServices);

    final warnings = findServiceReferenceWarnings(
      services: _services,
      routes: _routes,
      devices: _devices,
      networks: _networks,
    );
    final conflicts = findServicePortConflicts(_services);
    final activeCount = _services
        .where((service) => service.state == ServiceState.active)
        .length;
    final deviceCount = _services
        .map((service) => service.deviceId)
        .toSet()
        .length;
    final publicRoutes = _routes
        .where((route) => route.accessLevel == ServiceAccessLevel.public)
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metricCard(l10n.activeServices, activeCount, Icons.dns_outlined),
            _metricCard(l10n.serviceDevices, deviceCount, Icons.devices_other),
            _metricCard(l10n.serviceRoutes, _routes.length, Icons.alt_route),
            _metricCard(l10n.publicRoutes, publicRoutes, Icons.public),
          ],
        ),
        if (warnings.isNotEmpty || conflicts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.serviceWarnings,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final conflict in conflicts.take(3))
                    Text(
                      l10n.servicePortConflict(
                        _deviceById(conflict.deviceId)?.name ??
                            conflict.deviceId,
                        conflict.port,
                      ),
                    ),
                  for (final warning in warnings.take(3))
                    Text(_warningText(l10n, warning)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(l10n.serviceRoutes, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (_routes.isEmpty)
          _emptyInline(l10n.noServiceRoutes)
        else
          for (final route in _routes) _routeCard(route),
        const SizedBox(height: 16),
        Text(l10n.navServices, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final service in _services.take(8)) _serviceTile(service),
      ],
    );
  }

  Widget _buildDevices(AppLocalizations l10n) {
    if (_services.isEmpty) return _emptyState(l10n.noServices);
    final grouped = <String, List<ServiceNode>>{};
    for (final service in _services) {
      grouped.putIfAbsent(service.deviceId, () => []).add(service);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final aName = _deviceById(a.key)?.name ?? a.key;
        final bName = _deviceById(b.key)?.name ?? b.key;
        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        for (final entry in entries)
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.devices_other),
              title: Text(_deviceById(entry.key)?.name ?? entry.key),
              subtitle: Text(l10n.serviceCount(entry.value.length)),
              initiallyExpanded: true,
              children: [
                for (final service in entry.value) _serviceTile(service),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRoutes(AppLocalizations l10n) {
    if (_routes.isEmpty) return _emptyState(l10n.noServiceRoutes);
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [for (final route in _routes) _routeCard(route)],
    );
  }

  Widget _buildPorts(AppLocalizations l10n) {
    if (_services.isEmpty) return _emptyState(l10n.noServices);
    final conflicts = findServicePortConflicts(_services);
    final portUses = listServicePortUses(_services);
    final servicesByDevice = <String, List<ServiceNode>>{};
    for (final service in _services) {
      servicesByDevice.putIfAbsent(service.deviceId, () => []).add(service);
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (conflicts.isNotEmpty)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.servicePortConflicts,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final conflict in conflicts)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${_deviceById(conflict.deviceId)?.name ?? conflict.deviceId} · ${conflict.transport.name}/${conflict.port}${conflict.potential ? ' (${l10n.servicePotentialConflict})' : ''}: ${conflict.uses.map((use) => use.service.name).join(', ')}',
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (portUses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Text(
              l10n.servicePortUsage,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        for (final entry in servicesByDevice.entries)
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.settings_ethernet),
              title: Text(_deviceById(entry.key)?.name ?? entry.key),
              initiallyExpanded: true,
              children: [
                for (final use in portUses.where(
                  (use) => use.service.deviceId == entry.key,
                ))
                  ListTile(
                    dense: true,
                    leading: Icon(_iconForService(use.service)),
                    title: Text('${use.transport.name}/${use.port}'),
                    subtitle: Text(
                      [
                            use.service.name,
                            use.endpoint.label,
                            use.bindAddress == '*'
                                ? l10n.serviceAnyAddress
                                : use.bindAddress,
                            use.endpoint.path,
                            _routesForEndpoint(use.service.id, use.endpoint.id),
                          ]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                    ),
                    onTap: () => _editService(use.service),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _metricCard(String label, int value, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(height: 12),
              Text('$value', style: Theme.of(context).textTheme.headlineSmall),
              Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serviceTile(ServiceNode service) {
    final device = _deviceById(service.deviceId);
    final routeCount = _routes
        .where((route) => route.sourceServiceId == service.id)
        .length;
    final endpointText = service.endpoints
        .map((endpoint) => '${endpoint.protocol.name}/${endpoint.portText}')
        .join(', ');
    return ListTile(
      leading: CircleAvatar(child: Icon(_iconForService(service), size: 22)),
      title: Text(service.name),
      subtitle: Text(
        [
          device?.name ?? service.deviceId,
          if (endpointText.isNotEmpty) endpointText,
          if (routeCount > 0)
            AppLocalizations.of(context)!.serviceRouteCount(routeCount),
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            child: Text(AppLocalizations.of(context)!.editService),
          ),
          PopupMenuItem(
            value: 'route',
            child: Text(AppLocalizations.of(context)!.addServiceRoute),
          ),
        ],
        onSelected: (value) {
          if (value == 'route') {
            _addRoute(source: service);
          } else {
            _editService(service);
          }
        },
      ),
      onTap: () => _editService(service),
    );
  }

  Widget _routeCard(ServiceRoute route) {
    final source = _serviceById(route.sourceServiceId);
    final sourceEndpoint = source != null
        ? _endpointById(source, route.sourceEndpointId)
        : null;
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.alt_route)),
        title: Text(
          route.finalUrl?.isNotEmpty == true ? route.finalUrl! : route.name,
        ),
        subtitle: Text(
          _routeSummary(route, source: source, sourceEndpoint: sourceEndpoint),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _editRoute(route),
      ),
    );
  }

  String _hopLabel(ServiceRouteHop hop) {
    final service = hop.serviceId != null ? _serviceById(hop.serviceId!) : null;
    if (service != null) {
      final endpoint = hop.endpointId == null
          ? null
          : _endpointById(service, hop.endpointId);
      return endpoint?.port != null
          ? '${service.name} ${endpoint!.portText}'
          : service.name;
    }
    if (hop.label != null && hop.label!.isNotEmpty) return hop.label!;
    if (hop.host != null && hop.host!.isNotEmpty) {
      return '${hop.scheme != null ? '${hop.scheme}://' : ''}${hop.host}${hop.port != null ? ':${hop.port}' : ''}${hop.path ?? ''}';
    }
    return hop.type.name;
  }

  String _routeSummary(
    ServiceRoute route, {
    ServiceNode? source,
    ServiceEndpoint? sourceEndpoint,
  }) {
    final parts = <String>[
      if (source != null)
        sourceEndpoint?.port != null
            ? '${source.name} ${sourceEndpoint!.portText}'
            : source.name,
      ...route.hops.map(_hopLabel),
    ];
    final path = parts.isEmpty ? route.name : parts.join(' -> ');
    return [path, route.accessLevel.name].join('\n');
  }

  String? _routesForEndpoint(String serviceId, String endpointId) {
    final routeNames = _routes
        .where(
          (route) =>
              (route.sourceServiceId == serviceId &&
                  route.sourceEndpointId == endpointId) ||
              route.hops.any(
                (hop) =>
                    hop.serviceId == serviceId && hop.endpointId == endpointId,
              ),
        )
        .map(
          (route) =>
              route.finalUrl?.isNotEmpty == true ? route.finalUrl! : route.name,
        )
        .toList();
    if (routeNames.isEmpty) return null;
    return routeNames.join(', ');
  }

  String _warningText(AppLocalizations l10n, ServiceWarning warning) {
    return switch (warning.kind) {
      ServiceWarningKind.missingDevice => l10n.serviceWarningMissingDevice(
        warning.name,
      ),
      ServiceWarningKind.inactiveDevice => l10n.serviceWarningInactiveDevice(
        warning.name,
      ),
      ServiceWarningKind.missingEndpointNetwork =>
        l10n.serviceWarningMissingNetwork(warning.name),
      ServiceWarningKind.missingSourceService =>
        l10n.serviceWarningMissingSource(warning.name),
      ServiceWarningKind.missingSourceEndpoint =>
        l10n.serviceWarningMissingSourceEndpoint(warning.name),
      ServiceWarningKind.missingHopService =>
        l10n.serviceWarningMissingHopService(warning.name),
      ServiceWarningKind.missingHopEndpoint =>
        l10n.serviceWarningMissingHopEndpoint(warning.name),
      ServiceWarningKind.missingHopDevice =>
        l10n.serviceWarningMissingHopDevice(warning.name),
      ServiceWarningKind.emptyRoute => l10n.serviceWarningEmptyRoute(
        warning.name,
      ),
      ServiceWarningKind.publicRouteMissingUrl =>
        l10n.serviceWarningPublicRouteMissingUrl(warning.name),
      ServiceWarningKind.duplicateFinalUrl =>
        l10n.serviceWarningDuplicateFinalUrl(warning.name),
    };
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _emptyInline(String message) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

IconData iconForServiceIcon(String? icon) => switch (icon) {
  'code' => Icons.code,
  'terminal' => Icons.terminal,
  'sports_esports' => Icons.sports_esports,
  'edit_document' => Icons.edit_document,
  'source' => Icons.source,
  'folder' => Icons.folder,
  'keyboard_alt' => Icons.keyboard_alt,
  'cloud' => Icons.cloud,
  'password' => Icons.password,
  'smart_toy' => Icons.smart_toy,
  'theaters' => Icons.theaters,
  'article' => Icons.article,
  'hub' => Icons.hub,
  'download' => Icons.download,
  'router' => Icons.router,
  'shield' => Icons.shield,
  'alt_route' => Icons.alt_route,
  'swap_horiz' => Icons.swap_horiz,
  'cloud_sync' => Icons.cloud_sync,
  'deployed_code' => Icons.inventory_2,
  'home' => Icons.home,
  'photo_library' => Icons.photo_library,
  'movie' => Icons.movie,
  'sync' => Icons.sync,
  'inventory_2' => Icons.inventory_2,
  'database' => Icons.storage,
  'monitoring' => Icons.analytics,
  'monitor_heart' => Icons.monitor_heart,
  'memory' => Icons.memory,
  'science' => Icons.science,
  'desktop_windows' => Icons.desktop_windows,
  'vpn_lock' => Icons.vpn_lock,
  'folder_shared' => Icons.folder_shared,
  'music_note' => Icons.music_note,
  'search' => Icons.search,
  'menu_book' => Icons.menu_book,
  'payments' => Icons.payments,
  'sticky_note_2' => Icons.sticky_note_2,
  'precision_manufacturing' => Icons.precision_manufacturing,
  'rss_feed' => Icons.rss_feed,
  'fact_check' => Icons.fact_check,
  'view_kanban' => Icons.view_kanban,
  _ => Icons.dns,
};

IconData _iconForService(ServiceNode service) =>
    iconForServiceIcon(service.icon);
