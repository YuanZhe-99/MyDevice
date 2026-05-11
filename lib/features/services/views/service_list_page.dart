import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../../shared/services/image_share_service.dart';
import '../../devices/models/device.dart';
import '../../devices/services/device_storage.dart';
import '../../devices/widgets/device_category_icon.dart';
import '../../network/models/network.dart';
import '../../network/services/network_storage.dart';
import '../models/service.dart';
import '../services/service_analysis.dart';
import '../services/service_storage.dart';
import 'service_edit_page.dart';
import 'service_route_edit_page.dart';

enum _ServiceView { overview, devices, routes, ports }

enum _TopologyInteractionMode { select, move }

enum _QuickAccessMethod {
  direct(ServiceRouteMethod.direct),
  caddy(ServiceRouteMethod.caddy),
  nginx(ServiceRouteMethod.nginx),
  traefik(ServiceRouteMethod.traefik),
  frp(ServiceRouteMethod.frp),
  pangolin(ServiceRouteMethod.pangolin),
  cloudflareTunnel(ServiceRouteMethod.cloudflareTunnel),
  tailscaleFunnel(ServiceRouteMethod.tailscaleFunnel),
  routerPortForward(ServiceRouteMethod.routerPortForward),
  custom(ServiceRouteMethod.custom);

  final ServiceRouteMethod routeMethod;

  const _QuickAccessMethod(this.routeMethod);

  bool get isPortMapping =>
      routeMethod == ServiceRouteMethod.frp ||
      routeMethod == ServiceRouteMethod.routerPortForward;
}

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

  Future<void> _addAccessRoute({ServiceNode? source}) async {
    final routes = await showDialog<List<ServiceRoute>>(
      context: context,
      builder: (context) => _QuickAccessRouteDialog(
        services: _services,
        devices: _devices,
        initialService: source,
      ),
    );
    if (routes == null || routes.isEmpty) return;
    for (final route in routes) {
      await ServiceStorage.addOrUpdateRoute(route);
    }
    await _load();
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
            icon: const Icon(Icons.add_link),
            tooltip: l10n.serviceAddAccess,
            onPressed: _services.isEmpty ? null : () => _addAccessRoute(),
          ),
          IconButton(
            icon: const Icon(Icons.alt_route),
            tooltip: l10n.serviceAdvancedRoute,
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
        const SizedBox(height: 16),
        _topologyCard(l10n),
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
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _addAccessRoute(),
            icon: const Icon(Icons.add_link),
            label: Text(l10n.serviceAddAccess),
          ),
        ),
        const SizedBox(height: 8),
        if (_routes.isEmpty)
          _emptyInline(l10n.noServiceRoutes)
        else
          for (final entry in _routesGroupedByService())
            _serviceRouteGroupCard(l10n, entry.key, entry.value),
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

  Widget _topologyCard(AppLocalizations l10n) {
    final graph = buildServiceTopology(
      services: _services,
      routes: _routes,
      devices: _devices,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.serviceTopology,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addAccessRoute(),
                  icon: const Icon(Icons.add_link),
                  label: Text(l10n.serviceAddAccess),
                ),
                if (!graph.isEmpty) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _openTopology(graph),
                    icon: const Icon(Icons.open_in_full),
                    label: Text(l10n.serviceOpenTopology),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.serviceTopologyHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (graph.isEmpty) _emptyInline(l10n.noServiceRoutes),
          ],
        ),
      ),
    );
  }

  Future<void> _openTopology(ServiceTopologyGraph graph) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => _ServiceTopologyPage(
          graph: graph,
          services: _services,
          devices: _devices,
          routes: _routes,
          onEditService: _editService,
          onEditRoute: _editRoute,
          onAddAccess: _addAccessRoute,
        ),
      ),
    );
  }

  List<MapEntry<String, List<ServiceRoute>>> _routesGroupedByService() {
    final grouped = <String, List<ServiceRoute>>{};
    for (final route in _routes) {
      grouped.putIfAbsent(route.sourceServiceId, () => []).add(route);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final aName = _serviceById(a.key)?.name ?? a.key;
        final bName = _serviceById(b.key)?.name ?? b.key;
        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });
    return entries;
  }

  Widget _serviceRouteGroupCard(
    AppLocalizations l10n,
    String serviceId,
    List<ServiceRoute> routes,
  ) {
    final service = _serviceById(serviceId);
    final domains = routes
        .expand(serviceRouteAccessTargets)
        .map(compactAccessTargetLabel)
        .toList();
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Icon(
            service == null ? Icons.alt_route : _iconForService(service),
          ),
        ),
        title: Text(service?.name ?? serviceId),
        subtitle: Text(
          [
            l10n.serviceRouteCount(routes.length),
            if (domains.isNotEmpty) domains.take(3).join(', '),
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          for (final route in routes) _routeCard(route),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextButton.icon(
                onPressed: service == null
                    ? null
                    : () => _addAccessRoute(source: service),
                icon: const Icon(Icons.add_link),
                label: Text(l10n.serviceAddAccess),
              ),
            ),
          ),
        ],
      ),
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
            child: Text(AppLocalizations.of(context)!.serviceAddAccess),
          ),
        ],
        onSelected: (value) {
          if (value == 'route') {
            _addAccessRoute(source: service);
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
        title: Text(serviceRouteDisplayTarget(route)),
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
      return service.name;
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
      ...serviceRouteAccessTargets(route).map(compactAccessTargetLabel),
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
        .map((route) => serviceRouteDisplayTarget(route))
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

class _QuickAccessRouteDialog extends StatefulWidget {
  final List<ServiceNode> services;
  final List<Device> devices;
  final ServiceNode? initialService;

  const _QuickAccessRouteDialog({
    required this.services,
    required this.devices,
    this.initialService,
  });

  @override
  State<_QuickAccessRouteDialog> createState() =>
      _QuickAccessRouteDialogState();
}

class _QuickAccessRouteDialogState extends State<_QuickAccessRouteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _targetsCtrl;
  late final TextEditingController _remoteHostCtrl;
  late final TextEditingController _remotePortCtrl;
  late final TextEditingController _notesCtrl;
  String? _sourceServiceId;
  String? _sourceEndpointId;
  String? _relayServiceId;
  String? _remoteDeviceId;
  _QuickAccessMethod _method = _QuickAccessMethod.cloudflareTunnel;
  ServiceAccessLevel _accessLevel = ServiceAccessLevel.public;

  @override
  void initState() {
    super.initState();
    _targetsCtrl = TextEditingController();
    _remoteHostCtrl = TextEditingController();
    _remotePortCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _sourceServiceId =
        widget.initialService?.id ?? widget.services.firstOrNull?.id;
    _sourceEndpointId = _selectedSource?.endpoints.firstOrNull?.id;
  }

  @override
  void dispose() {
    _targetsCtrl.dispose();
    _remoteHostCtrl.dispose();
    _remotePortCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  ServiceNode? get _selectedSource => _sourceServiceId == null
      ? null
      : widget.services
            .where((service) => service.id == _sourceServiceId)
            .firstOrNull;

  List<ServiceRoute> _buildRoutes() {
    final source = _selectedSource;
    if (source == null) return const [];
    final method = _method.routeMethod;
    final targets = _splitTargets(_targetsCtrl.text);
    final hop = _buildHop(method);
    final routeTargets = targets;
    return [
      ServiceRoute(
        name: serviceRouteGeneratedName(
          sourceName: source.name,
          hops: [hop],
          targets: routeTargets,
        ),
        sourceServiceId: source.id,
        sourceEndpointId: _sourceEndpointId,
        hops: [hop],
        finalUrl: routeTargets.firstOrNull,
        accessLevel: _accessLevel,
        notes: _emptyToNull(_notesCtrl.text),
        extraJson: serviceRouteExtraJsonWithTargets(const {}, routeTargets),
      ),
    ];
  }

  ServiceRouteHop _buildHop(ServiceRouteMethod method) {
    if (_method.isPortMapping) {
      return ServiceRouteHop(
        type: ServiceRouteHopType.portForward,
        method: method,
        serviceId: _relayServiceId,
        deviceId: _remoteDeviceId,
        label: _relayServiceId == null ? serviceRouteMethodLabel(method) : null,
        host: _emptyToNull(_remoteHostCtrl.text),
        port: int.tryParse(_remotePortCtrl.text.trim()),
      );
    }
    return ServiceRouteHop(
      type: switch (method) {
        ServiceRouteMethod.direct => ServiceRouteHopType.manual,
        ServiceRouteMethod.caddy ||
        ServiceRouteMethod.nginx ||
        ServiceRouteMethod.traefik => ServiceRouteHopType.reverseProxy,
        ServiceRouteMethod.routerPortForward => ServiceRouteHopType.portForward,
        _ => ServiceRouteHopType.tunnel,
      },
      method: method,
      serviceId: _relayServiceId,
      label: _relayServiceId == null ? serviceRouteMethodLabel(method) : null,
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_buildRoutes());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final source = _selectedSource;
    return AlertDialog(
      title: Text(l10n.serviceAddAccess),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _sourceServiceId,
                  decoration: InputDecoration(
                    labelText: l10n.routeSourceService,
                  ),
                  items: [
                    for (final service in widget.services)
                      DropdownMenuItem(
                        value: service.id,
                        child: Text(service.name),
                      ),
                  ],
                  validator: (value) =>
                      value == null ? l10n.serviceNameRequired : null,
                  onChanged: (value) => setState(() {
                    _sourceServiceId = value;
                    _sourceEndpointId =
                        _selectedSource?.endpoints.firstOrNull?.id;
                    if (_relayServiceId == value) _relayServiceId = null;
                  }),
                ),
                if (source != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _sourceEndpointId,
                    decoration: InputDecoration(
                      labelText: l10n.serviceEndpoint,
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(l10n.optionalNone),
                      ),
                      for (final endpoint in source.endpoints)
                        DropdownMenuItem(
                          value: endpoint.id,
                          child: Text(
                            '${endpoint.label ?? endpoint.protocol.name} · ${endpoint.portText}',
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _sourceEndpointId = value),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<_QuickAccessMethod>(
                  initialValue: _method,
                  decoration: InputDecoration(
                    labelText: l10n.serviceAccessMethod,
                  ),
                  items: [
                    for (final method in _QuickAccessMethod.values)
                      DropdownMenuItem(
                        value: method,
                        child: Text(
                          serviceRouteMethodLabel(method.routeMethod),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _method = value;
                      _accessLevel = value == _QuickAccessMethod.direct
                          ? ServiceAccessLevel.lan
                          : ServiceAccessLevel.public;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ServiceAccessLevel>(
                  initialValue: _accessLevel,
                  decoration: InputDecoration(
                    labelText: l10n.serviceAccessLevel,
                  ),
                  items: [
                    for (final level in ServiceAccessLevel.values)
                      DropdownMenuItem(value: level, child: Text(level.name)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _accessLevel = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _relayServiceId,
                  decoration: InputDecoration(
                    labelText: l10n.serviceRelayService,
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(l10n.optionalNone),
                    ),
                    for (final service in _relayServiceOptions())
                      DropdownMenuItem(
                        value: service.id,
                        child: Text(
                          _method.isPortMapping
                              ? '${service.name} · ${_deviceName(service.deviceId)}'
                              : service.name,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _relayServiceId = value;
                    if (_method.isPortMapping && value != null) {
                      final service = widget.services
                          .where((service) => service.id == value)
                          .firstOrNull;
                      _remoteDeviceId = service?.deviceId ?? _remoteDeviceId;
                    }
                  }),
                ),
                if (_method.isPortMapping) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _remoteDeviceId,
                    decoration: InputDecoration(
                      labelText: l10n.serviceRemoteDevice,
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(l10n.optionalNone),
                      ),
                      for (final device in widget.devices)
                        DropdownMenuItem(
                          value: device.id,
                          child: Text(device.name),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _remoteDeviceId = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _remoteHostCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.serviceRemoteHost,
                      hintText: '203.0.113.10 or vps.example.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _remotePortCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.serviceRemotePort,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (!_method.isPortMapping) return null;
                      final port = int.tryParse(value?.trim() ?? '');
                      if (port == null || port <= 0 || port > 65535) {
                        return l10n.serviceRemotePortRequired;
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _targetsCtrl,
                  decoration: InputDecoration(
                    labelText: _method.isPortMapping
                        ? l10n.serviceDomains
                        : l10n.serviceFinalUrl,
                    hintText: _method.isPortMapping
                        ? 'domain1.com\ndomain2.com'
                        : 'https://app.example.com',
                    helperText: _method.isPortMapping
                        ? l10n.serviceDomainsHint
                        : l10n.serviceAccessTargetsHint,
                  ),
                  minLines: 2,
                  maxLines: 4,
                  validator: (value) {
                    if (_method.isPortMapping) return null;
                    if (_splitTargets(value ?? '').isEmpty) {
                      return l10n.serviceAccessTargetRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  decoration: InputDecoration(labelText: l10n.deviceNotes),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add_link),
          label: Text(l10n.save),
        ),
      ],
    );
  }

  List<ServiceNode> _relayServiceOptions() {
    final candidates = widget.services
        .where((service) => service.id != _sourceServiceId)
        .toList();
    candidates.sort((a, b) {
      if (_method.isPortMapping) {
        final aPreferred = _isFrpLikeService(a) ? 0 : 1;
        final bPreferred = _isFrpLikeService(b) ? 0 : 1;
        if (aPreferred != bPreferred) return aPreferred.compareTo(bPreferred);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return candidates;
  }

  bool _isFrpLikeService(ServiceNode service) {
    final text = [
      service.name,
      service.templateId,
      service.icon,
      service.kind.name,
    ].whereType<String>().join(' ').toLowerCase();
    return text.contains('frp') || service.kind == ServiceKind.tunnel;
  }

  String _deviceName(String id) =>
      widget.devices.where((device) => device.id == id).firstOrNull?.name ?? id;
}

class _ServiceTopologyView extends StatelessWidget {
  final ServiceTopologyGraph graph;
  final List<ServiceNode> services;
  final List<Device> devices;
  final List<ServiceRoute> routes;
  final ValueChanged<ServiceNode> onEditService;
  final ValueChanged<ServiceRoute> onEditRoute;
  final Future<void> Function({ServiceNode? source}) onAddAccess;
  final _TopologyInteractionMode mode;
  final int quarterTurns;
  final GlobalKey? repaintBoundaryKey;

  const _ServiceTopologyView({
    required this.graph,
    required this.services,
    required this.devices,
    required this.routes,
    required this.onEditService,
    required this.onEditRoute,
    required this.onAddAccess,
    this.mode = _TopologyInteractionMode.select,
    this.quarterTurns = 0,
    this.repaintBoundaryKey,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final turns = quarterTurns % 4;
        final viewportWidth = turns.isOdd && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : constraints.maxWidth;
        final layout = _TopologyLayout.build(graph, routes, viewportWidth);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            child: _buildViewer(context, layout, turns),
          ),
        );
      },
    );
  }

  Widget _buildViewer(BuildContext context, _TopologyLayout layout, int turns) {
    Widget canvas = SizedBox.fromSize(
      size: layout.size,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ServiceTopologyEdgePainter(
                graph: graph,
                layout: layout,
                colorScheme: Theme.of(context).colorScheme,
              ),
            ),
          ),
          for (final node in graph.nodes)
            if (layout.nodeRects[node.id] != null)
              Positioned.fromRect(
                rect: layout.nodeRects[node.id]!,
                child: _TopologyNodeCard(
                  node: node,
                  icon: _iconForTopologyNode(node, services, devices),
                  onTap: mode == _TopologyInteractionMode.select
                      ? () => _showNodeDetails(context, node)
                      : null,
                ),
              ),
        ],
      ),
    );
    if (turns != 0) {
      canvas = RotatedBox(quarterTurns: turns, child: canvas);
    }
    if (repaintBoundaryKey != null) {
      canvas = RepaintBoundary(key: repaintBoundaryKey, child: canvas);
    }
    if (mode == _TopologyInteractionMode.select) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(child: canvas),
      );
    }
    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(180),
      minScale: 0.35,
      maxScale: 2.4,
      child: canvas,
    );
  }

  void _showNodeDetails(BuildContext context, ServiceTopologyNode node) {
    final device = node.deviceId == null
        ? null
        : devices.where((device) => device.id == node.deviceId).firstOrNull;
    final service = node.serviceId == null
        ? null
        : services.where((service) => service.id == node.serviceId).firstOrNull;
    final relatedRoutes = routes
        .where(
          (route) =>
              node.routeIds.contains(route.id) ||
              route.sourceServiceId == node.serviceId ||
              route.hops.any((hop) => hop.serviceId == node.serviceId),
        )
        .toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Icon(_iconForTopologyNode(node, services, devices)),
                ),
                title: Text(node.label),
                subtitle: Text(
                  [
                    _roleLabel(node.role),
                    if (node.detail?.trim().isNotEmpty == true) node.detail,
                    if (node.lane != null) _laneLabel(node.lane!),
                  ].whereType<String>().join(' · '),
                ),
              ),
              if (device != null)
                ListTile(
                  leading: Icon(deviceCategoryIcon(device.category)),
                  title: Text(device.name),
                  subtitle: Text(device.category.name),
                ),
              if (service != null) ...[
                ListTile(
                  leading: Icon(_iconForService(service)),
                  title: Text(service.name),
                  subtitle: Text(
                    service.endpoints
                        .map(
                          (endpoint) =>
                              '${endpoint.protocol.name}/${endpoint.portText}',
                        )
                        .join(', '),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        onEditService(service);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(AppLocalizations.of(context)!.editService),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        onAddAccess(source: service);
                      },
                      icon: const Icon(Icons.add_link),
                      label: Text(
                        AppLocalizations.of(context)!.serviceAddAccess,
                      ),
                    ),
                  ],
                ),
              ],
              if (relatedRoutes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.serviceRoutes,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final route in relatedRoutes)
                  ListTile(
                    leading: Icon(_iconForMethod(_primaryMethod(route))),
                    title: Text(serviceRouteDisplayTarget(route)),
                    subtitle: Text(
                      [
                        serviceRouteTargetsSummary(route),
                        route.accessLevel.name,
                        _laneLabel(serviceAccessLaneForRoute(route)),
                      ].where((part) => part.isNotEmpty).join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onEditRoute(route);
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceTopologyPage extends StatefulWidget {
  final ServiceTopologyGraph graph;
  final List<ServiceNode> services;
  final List<Device> devices;
  final List<ServiceRoute> routes;
  final ValueChanged<ServiceNode> onEditService;
  final ValueChanged<ServiceRoute> onEditRoute;
  final Future<void> Function({ServiceNode? source}) onAddAccess;

  const _ServiceTopologyPage({
    required this.graph,
    required this.services,
    required this.devices,
    required this.routes,
    required this.onEditService,
    required this.onEditRoute,
    required this.onAddAccess,
  });

  @override
  State<_ServiceTopologyPage> createState() => _ServiceTopologyPageState();
}

class _ServiceTopologyPageState extends State<_ServiceTopologyPage> {
  _TopologyInteractionMode _mode = _TopologyInteractionMode.select;
  final _captureKey = GlobalKey();
  int _quarterTurns = 0;
  bool _exporting = false;

  Future<void> _exportTopologyImage() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _exporting = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Topology image boundary is not available.');
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) {
        throw StateError('Topology image encoding failed.');
      }
      if (!mounted) return;
      await ImageShareService.sharePngBytes(
        context,
        bytes,
        fileName: 'mydevice_topology.png',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.serviceTopology),
        actions: [
          IconButton(
            tooltip: l10n.serviceRotateTopology,
            onPressed: () {
              setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
            },
            icon: const Icon(Icons.screen_rotation_alt),
          ),
          IconButton(
            tooltip: l10n.serviceExportTopologyImage,
            onPressed: _exporting ? null : _exportTopologyImage,
            icon: _exporting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegmentedButton<_TopologyInteractionMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: _TopologyInteractionMode.select,
                  icon: const Icon(Icons.touch_app),
                  label: Text(l10n.serviceTopologySelectMode),
                ),
                ButtonSegment(
                  value: _TopologyInteractionMode.move,
                  icon: const Icon(Icons.open_with),
                  label: Text(l10n.serviceTopologyMoveMode),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selected) {
                setState(() => _mode = selected.single);
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _ServiceTopologyView(
                graph: widget.graph,
                services: widget.services,
                devices: widget.devices,
                routes: widget.routes,
                onEditService: widget.onEditService,
                onEditRoute: widget.onEditRoute,
                onAddAccess: widget.onAddAccess,
                mode: _mode,
                quarterTurns: _quarterTurns,
                repaintBoundaryKey: _captureKey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopologyNodeCard extends StatelessWidget {
  final ServiceTopologyNode node;
  final IconData icon;
  final VoidCallback? onTap;

  const _TopologyNodeCard({
    required this.node,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = _nodeBorder(context, node);
    return Tooltip(
      message: [node.label, node.detail].whereType<String>().join('\n'),
      child: Card(
        margin: EdgeInsets.zero,
        color: _nodeFill(context, node),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border, width: 1.4),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: border.withValues(alpha: 0.18),
                  foregroundColor: border,
                  child: Icon(icon, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (node.detail?.trim().isNotEmpty == true)
                            node.detail,
                          if (node.lane != null) _laneLabel(node.lane!),
                        ].whereType<String>().join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopologyLayout {
  final Size size;
  final Map<String, Rect> nodeRects;
  final Map<String, int> nodeColumns;

  const _TopologyLayout({
    required this.size,
    required this.nodeRects,
    required this.nodeColumns,
  });

  static const nodeWidth = 204.0;
  static const nodeHeight = 76.0;
  static const horizontalGap = 56.0;
  static const verticalGap = 26.0;
  static const padding = 24.0;

  static _TopologyLayout build(
    ServiceTopologyGraph graph,
    List<ServiceRoute> routes,
    double viewportWidth,
  ) {
    final nodeMap = {for (final node in graph.nodes) node.id: node};
    final nodeColumns = {
      for (final node in graph.nodes) node.id: _columnForNode(node),
    };
    final incoming = <String, Set<String>>{};
    final outgoing = <String, Set<String>>{};
    for (final node in graph.nodes) {
      incoming[node.id] = <String>{};
      outgoing[node.id] = <String>{};
    }

    for (final edge in graph.edges) {
      if (!nodeMap.containsKey(edge.from) || !nodeMap.containsKey(edge.to)) {
        continue;
      }
      outgoing.putIfAbsent(edge.from, () => <String>{}).add(edge.to);
      incoming.putIfAbsent(edge.to, () => <String>{}).add(edge.from);
    }

    final routeRows = _routeRows(graph, routes, nodeMap);
    final desiredRows = _desiredRows(
      graph,
      routes,
      routeRows,
      incoming,
      outgoing,
    );

    final columns = <int, List<ServiceTopologyNode>>{};
    for (final node in graph.nodes) {
      columns.putIfAbsent(nodeColumns[node.id]!, () => []).add(node);
    }
    final orderedColumns = columns.keys.toList()..sort();
    for (final nodes in columns.values) {
      nodes.sort((a, b) {
        final rowCmp = (desiredRows[a.id] ?? 0).compareTo(
          desiredRows[b.id] ?? 0,
        );
        if (rowCmp != 0) return rowCmp;

        final roleCmp = _roleOrder(a).compareTo(_roleOrder(b));
        if (roleCmp != 0) return roleCmp;

        final laneCmp = _laneBucket(a).compareTo(_laneBucket(b));
        if (laneCmp != 0) return laneCmp;

        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
    }

    final rects = <String, Rect>{};
    var maxHeight = 360.0;
    const rowStride = nodeHeight + 62;
    for (final column in orderedColumns) {
      final nodes = columns[column] ?? const <ServiceTopologyNode>[];
      final x = padding + column * (nodeWidth + horizontalGap);
      var previousBottom = padding - verticalGap;
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        final targetY = padding + (desiredRows[node.id] ?? 0) * rowStride;
        final y = math.max(targetY, previousBottom + verticalGap);
        rects[node.id] = Rect.fromLTWH(x, y, nodeWidth, nodeHeight);
        maxHeight = math.max(maxHeight, y + nodeHeight + padding);
        previousBottom = y + nodeHeight;
      }
    }
    final maxColumn = columns.keys.fold<int>(0, math.max);
    final width = math.max(
      viewportWidth,
      padding * 2 + (maxColumn + 1) * nodeWidth + maxColumn * horizontalGap,
    );
    final height = math.max(360.0, maxHeight);
    return _TopologyLayout(
      size: Size(width, height),
      nodeRects: rects,
      nodeColumns: nodeColumns,
    );
  }

  static Map<String, double> _routeRows(
    ServiceTopologyGraph graph,
    List<ServiceRoute> routes,
    Map<String, ServiceTopologyNode> nodeMap,
  ) {
    final routesBySource = <String, List<ServiceRoute>>{};
    for (final route in routes) {
      routesBySource
          .putIfAbsent(_serviceNodeId(route.sourceServiceId), () => [])
          .add(route);
    }

    final sourceIds = <String>{
      ...routesBySource.keys,
      for (final node in graph.nodes)
        if (node.kind == ServiceTopologyNodeKind.service &&
            node.role == ServiceTopologyNodeRole.localService)
          node.id,
    }.toList();
    sourceIds.sort((a, b) {
      final aNode = nodeMap[a];
      final bNode = nodeMap[b];
      final aLabel = aNode?.label.toLowerCase() ?? a;
      final bLabel = bNode?.label.toLowerCase() ?? b;
      return aLabel.compareTo(bLabel);
    });

    final rows = <String, double>{};
    var row = 0.0;
    for (final sourceId in sourceIds) {
      final sourceRoutes = routesBySource[sourceId] ?? const <ServiceRoute>[];
      if (sourceRoutes.isEmpty) {
        row += 1.45;
        continue;
      }
      final orderedRoutes = [...sourceRoutes]..sort(_compareRoutesForLayout);
      for (final route in orderedRoutes) {
        rows[route.id] = row;
        row += 1;
      }
      row += 0.45;
    }
    return rows;
  }

  static Map<String, double> _desiredRows(
    ServiceTopologyGraph graph,
    List<ServiceRoute> routes,
    Map<String, double> routeRows,
    Map<String, Set<String>> incoming,
    Map<String, Set<String>> outgoing,
  ) {
    final sourceRouteRows = <String, List<double>>{};
    for (final route in routes) {
      final row = routeRows[route.id];
      if (row == null) continue;
      sourceRouteRows
          .putIfAbsent(_serviceNodeId(route.sourceServiceId), () => [])
          .add(row);
    }

    final desired = <String, double>{};
    for (final node in graph.nodes) {
      final scores = <double>[];
      for (final routeId in node.routeIds) {
        final row = routeRows[routeId];
        if (row != null) scores.add(row);
      }
      if (node.kind == ServiceTopologyNodeKind.service) {
        scores.addAll(sourceRouteRows[node.id] ?? const <double>[]);
      }
      if (scores.isNotEmpty) {
        desired[node.id] = _median(scores);
      }
    }

    for (var iteration = 0; iteration < 8; iteration++) {
      var changed = false;
      for (final node in graph.nodes) {
        if (desired.containsKey(node.id)) continue;
        final scores = <double>[];
        for (final neighborId in {
          ...?incoming[node.id],
          ...?outgoing[node.id],
        }) {
          final score = desired[neighborId];
          if (score != null) scores.add(score);
        }
        if (scores.isEmpty) continue;
        desired[node.id] = _median(scores);
        changed = true;
      }
      if (!changed) break;
    }

    var fallbackRow = desired.values.isEmpty
        ? 0.0
        : desired.values.reduce(math.max) + 1;
    final fallbackNodes =
        graph.nodes.where((node) => !desired.containsKey(node.id)).toList()
          ..sort((a, b) {
            final roleCmp = _roleOrder(a).compareTo(_roleOrder(b));
            if (roleCmp != 0) return roleCmp;
            return a.label.toLowerCase().compareTo(b.label.toLowerCase());
          });
    for (final node in fallbackNodes) {
      desired[node.id] = fallbackRow;
      fallbackRow += 1;
    }
    return desired;
  }

  static String _serviceNodeId(String serviceId) => 'service:$serviceId';

  static int _compareRoutesForLayout(ServiceRoute a, ServiceRoute b) {
    final laneCmp = _laneOrder(
      serviceAccessLaneForRoute(a),
    ).compareTo(_laneOrder(serviceAccessLaneForRoute(b)));
    if (laneCmp != 0) return laneCmp;

    final methodCmp = (_routeMethodName(a)).compareTo(_routeMethodName(b));
    if (methodCmp != 0) return methodCmp;

    return serviceRouteDisplayTarget(
      a,
    ).toLowerCase().compareTo(serviceRouteDisplayTarget(b).toLowerCase());
  }

  static int _laneOrder(ServiceAccessLane lane) => switch (lane) {
    ServiceAccessLane.local => 0,
    ServiceAccessLane.vpn => 1,
    ServiceAccessLane.public => 2,
  };

  static String _routeMethodName(ServiceRoute route) =>
      route.hops
          .map((hop) => hop.method?.name)
          .whereType<String>()
          .firstOrNull ??
      '';

  static double _median(List<double> values) {
    final ordered = [...values]..sort();
    final middle = ordered.length ~/ 2;
    if (ordered.length.isOdd) return ordered[middle];
    return (ordered[middle - 1] + ordered[middle]) / 2;
  }

  static int _columnForNode(ServiceTopologyNode node) {
    if (node.kind == ServiceTopologyNodeKind.domain) {
      return node.lane == ServiceAccessLane.public ? 8 : 4;
    }
    if (node.kind == ServiceTopologyNodeKind.endpoint &&
        node.role == ServiceTopologyNodeRole.remoteService) {
      return 7;
    }
    return switch (node.role) {
      ServiceTopologyNodeRole.localDevice => 0,
      ServiceTopologyNodeRole.localService => 1,
      ServiceTopologyNodeRole.localEndpoint => 2,
      ServiceTopologyNodeRole.lanAccess ||
      ServiceTopologyNodeRole.vpnAccess => 3,
      ServiceTopologyNodeRole.publicRelay => 4,
      ServiceTopologyNodeRole.remoteDevice => 5,
      ServiceTopologyNodeRole.remoteService => 6,
      ServiceTopologyNodeRole.remotePublicEntry => 7,
      ServiceTopologyNodeRole.domain => 8,
    };
  }

  static int _roleOrder(ServiceTopologyNode node) {
    if (node.kind == ServiceTopologyNodeKind.endpoint &&
        node.role == ServiceTopologyNodeRole.remoteService) {
      return 8;
    }
    return switch (node.role) {
      ServiceTopologyNodeRole.localDevice => 0,
      ServiceTopologyNodeRole.localService => 1,
      ServiceTopologyNodeRole.localEndpoint => 2,
      ServiceTopologyNodeRole.lanAccess => 3,
      ServiceTopologyNodeRole.vpnAccess => 4,
      ServiceTopologyNodeRole.publicRelay => 5,
      ServiceTopologyNodeRole.remoteDevice => 6,
      ServiceTopologyNodeRole.remoteService => 7,
      ServiceTopologyNodeRole.remotePublicEntry => 9,
      ServiceTopologyNodeRole.domain => 10,
    };
  }

  static int _laneBucket(ServiceTopologyNode node) => switch (node.lane) {
    ServiceAccessLane.local => 0,
    ServiceAccessLane.vpn => 1,
    ServiceAccessLane.public => 2,
    null => -1,
  };
}

class _ServiceTopologyEdgePainter extends CustomPainter {
  final ServiceTopologyGraph graph;
  final _TopologyLayout layout;
  final ColorScheme colorScheme;

  const _ServiceTopologyEdgePainter({
    required this.graph,
    required this.layout,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outgoingOffsets = _buildPortOffsets(outgoing: true);
    final incomingOffsets = _buildPortOffsets(outgoing: false);
    for (final edge in graph.edges) {
      final from = layout.nodeRects[edge.from];
      final to = layout.nodeRects[edge.to];
      if (from == null || to == null) continue;
      final paint = Paint()
        ..color = _edgeColor(edge).withValues(alpha: 0.62)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final start = Offset(
        from.right,
        from.center.dy + (outgoingOffsets[edge] ?? 0),
      );
      final end = Offset(to.left, to.center.dy + (incomingOffsets[edge] ?? 0));
      _drawEdge(canvas, paint, start, end);
    }
  }

  Map<ServiceTopologyEdge, double> _buildPortOffsets({required bool outgoing}) {
    final grouped = <String, List<ServiceTopologyEdge>>{};
    for (final edge in graph.edges) {
      final from = layout.nodeRects[edge.from];
      final to = layout.nodeRects[edge.to];
      if (from == null || to == null) continue;
      final nodeId = outgoing ? edge.from : edge.to;
      grouped.putIfAbsent(nodeId, () => []).add(edge);
    }

    final offsets = <ServiceTopologyEdge, double>{};
    for (final edges in grouped.values) {
      edges.sort((a, b) {
        final aPeer = outgoing
            ? layout.nodeRects[a.to]
            : layout.nodeRects[a.from];
        final bPeer = outgoing
            ? layout.nodeRects[b.to]
            : layout.nodeRects[b.from];
        final yCmp = (aPeer?.center.dy ?? 0).compareTo(bPeer?.center.dy ?? 0);
        if (yCmp != 0) return yCmp;

        final aColumn =
            (outgoing
                ? layout.nodeColumns[a.to]
                : layout.nodeColumns[a.from]) ??
            0;
        final bColumn =
            (outgoing
                ? layout.nodeColumns[b.to]
                : layout.nodeColumns[b.from]) ??
            0;
        final columnCmp = aColumn.compareTo(bColumn);
        if (columnCmp != 0) return columnCmp;

        final aKey = '${a.from}->${a.to}:${a.routeId ?? ''}:${a.label ?? ''}';
        final bKey = '${b.from}->${b.to}:${b.routeId ?? ''}:${b.label ?? ''}';
        return aKey.compareTo(bKey);
      });

      final midpoint = (edges.length - 1) / 2;
      for (var i = 0; i < edges.length; i++) {
        offsets[edges[i]] = (i - midpoint) * 10.0;
      }
    }
    return offsets;
  }

  void _drawEdge(Canvas canvas, Paint paint, Offset start, Offset end) {
    final travel = end.dx - start.dx;
    final lead = math.max(18.0, math.min(32.0, travel.abs() * 0.22));
    final exitX = start.dx + lead;
    final entryX = end.dx - lead;
    final middleX = entryX <= exitX
        ? (start.dx + end.dx) / 2
        : (exitX + entryX) / 2;

    final path = Path()..moveTo(start.dx, start.dy);
    if ((end.dy - start.dy).abs() < 1) {
      path.lineTo(end.dx, end.dy);
    } else {
      path
        ..lineTo(exitX, start.dy)
        ..lineTo(middleX, start.dy)
        ..lineTo(middleX, end.dy)
        ..lineTo(entryX, end.dy)
        ..lineTo(end.dx, end.dy);
    }
    canvas.drawPath(path, paint);

    final arrowOrigin = Offset(math.min(entryX, end.dx - 10), end.dy);
    final angle = math.atan2(end.dy - arrowOrigin.dy, end.dx - arrowOrigin.dx);
    final arrow = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - 9 * math.cos(angle - 0.45),
        end.dy - 9 * math.sin(angle - 0.45),
      )
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - 9 * math.cos(angle + 0.45),
        end.dy - 9 * math.sin(angle + 0.45),
      );
    canvas.drawPath(arrow, paint);
  }

  Color _edgeColor(ServiceTopologyEdge edge) => switch (edge.lane) {
    ServiceAccessLane.local => colorScheme.tertiary,
    ServiceAccessLane.vpn => colorScheme.secondary,
    ServiceAccessLane.public => colorScheme.primary,
    null => colorScheme.outline,
  };

  @override
  bool shouldRepaint(covariant _ServiceTopologyEdgePainter oldDelegate) =>
      oldDelegate.graph != graph ||
      oldDelegate.layout != layout ||
      oldDelegate.colorScheme != colorScheme;
}

List<String> _splitTargets(String value) => value
    .split(RegExp(r'[\n,]+'))
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

IconData _iconForTopologyNode(
  ServiceTopologyNode node,
  List<ServiceNode> services,
  List<Device> devices,
) {
  if (node.kind == ServiceTopologyNodeKind.device && node.deviceId != null) {
    final device = devices
        .where((device) => device.id == node.deviceId)
        .firstOrNull;
    return device == null
        ? Icons.devices_other_outlined
        : deviceCategoryIcon(device.category);
  }
  if (node.kind == ServiceTopologyNodeKind.service) {
    final service = services
        .where((service) => service.id == node.serviceId)
        .firstOrNull;
    return service == null ? Icons.dns_outlined : _iconForService(service);
  }
  if (node.kind == ServiceTopologyNodeKind.endpoint) {
    return Icons.settings_ethernet;
  }
  if (node.kind == ServiceTopologyNodeKind.remoteEntry) return Icons.public;
  if (node.kind == ServiceTopologyNodeKind.domain) return Icons.language;
  return _iconForMethod(node.method);
}

IconData _iconForMethod(ServiceRouteMethod? method) => switch (method) {
  ServiceRouteMethod.caddy => Icons.alt_route,
  ServiceRouteMethod.nginx => Icons.account_tree_outlined,
  ServiceRouteMethod.traefik => Icons.hub_outlined,
  ServiceRouteMethod.frp => Icons.swap_horiz,
  ServiceRouteMethod.cloudflareTunnel => Icons.cloud_sync,
  ServiceRouteMethod.pangolin => Icons.hub,
  ServiceRouteMethod.tailscaleFunnel => Icons.vpn_lock,
  ServiceRouteMethod.routerPortForward => Icons.router,
  ServiceRouteMethod.direct => Icons.near_me_outlined,
  ServiceRouteMethod.custom => Icons.route,
  null => Icons.route,
};

ServiceRouteMethod? _primaryMethod(ServiceRoute route) => route.hops
    .map((hop) => hop.method)
    .whereType<ServiceRouteMethod>()
    .firstOrNull;

String _laneLabel(ServiceAccessLane lane) => switch (lane) {
  ServiceAccessLane.local => 'LAN / WiFi',
  ServiceAccessLane.vpn => 'VPN / Tailscale',
  ServiceAccessLane.public => 'Public / VPS',
};

String _roleLabel(ServiceTopologyNodeRole role) => switch (role) {
  ServiceTopologyNodeRole.localDevice => 'Local device',
  ServiceTopologyNodeRole.remoteDevice => 'Remote / VPS device',
  ServiceTopologyNodeRole.localService => 'Local service',
  ServiceTopologyNodeRole.remoteService => 'Remote service',
  ServiceTopologyNodeRole.localEndpoint => 'Local endpoint',
  ServiceTopologyNodeRole.lanAccess => 'LAN / WiFi access',
  ServiceTopologyNodeRole.vpnAccess => 'VPN / Tailscale access',
  ServiceTopologyNodeRole.publicRelay => 'Public relay',
  ServiceTopologyNodeRole.remotePublicEntry => 'Remote public entry',
  ServiceTopologyNodeRole.domain => 'Domain / URL',
};

Color _nodeFill(BuildContext context, ServiceTopologyNode node) {
  final cs = Theme.of(context).colorScheme;
  return switch (node.role) {
    ServiceTopologyNodeRole.localDevice => cs.primaryContainer.withValues(
      alpha: 0.74,
    ),
    ServiceTopologyNodeRole.remoteDevice => cs.errorContainer.withValues(
      alpha: 0.55,
    ),
    ServiceTopologyNodeRole.localService => cs.secondaryContainer.withValues(
      alpha: 0.74,
    ),
    ServiceTopologyNodeRole.remoteService => cs.errorContainer.withValues(
      alpha: 0.42,
    ),
    ServiceTopologyNodeRole.localEndpoint => cs.tertiaryContainer.withValues(
      alpha: 0.72,
    ),
    ServiceTopologyNodeRole.lanAccess => cs.tertiary.withValues(alpha: 0.14),
    ServiceTopologyNodeRole.vpnAccess => cs.secondary.withValues(alpha: 0.14),
    ServiceTopologyNodeRole.publicRelay => cs.primary.withValues(alpha: 0.13),
    ServiceTopologyNodeRole.remotePublicEntry => cs.errorContainer.withValues(
      alpha: 0.62,
    ),
    ServiceTopologyNodeRole.domain => cs.primaryContainer.withValues(
      alpha: 0.42,
    ),
  };
}

Color _nodeBorder(BuildContext context, ServiceTopologyNode node) {
  final cs = Theme.of(context).colorScheme;
  return switch (node.role) {
    ServiceTopologyNodeRole.localDevice => cs.primary,
    ServiceTopologyNodeRole.remoteDevice => cs.error,
    ServiceTopologyNodeRole.localService => cs.secondary,
    ServiceTopologyNodeRole.remoteService => cs.error,
    ServiceTopologyNodeRole.localEndpoint => cs.tertiary,
    ServiceTopologyNodeRole.lanAccess => cs.tertiary,
    ServiceTopologyNodeRole.vpnAccess => cs.secondary,
    ServiceTopologyNodeRole.publicRelay => cs.primary,
    ServiceTopologyNodeRole.remotePublicEntry => cs.error,
    ServiceTopologyNodeRole.domain => cs.primary,
  };
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
