import 'dart:math' as math;

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
            if (graph.isEmpty)
              _emptyInline(l10n.noServiceRoutes)
            else
              SizedBox(height: 420, child: _ServiceTopologyView(graph: graph)),
          ],
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
        .map((route) => route.finalUrl)
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
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
    final generatedTargets = targets.isEmpty && _method.isPortMapping
        ? <String?>[null]
        : targets;
    final routes = <ServiceRoute>[];
    for (final target in generatedTargets) {
      final hop = _buildHop(method);
      final label = target == null || target.trim().isEmpty
          ? serviceRouteMethodLabel(method)
          : compactAccessTargetLabel(target);
      routes.add(
        ServiceRoute(
          name:
              '${source.name} via ${serviceRouteMethodLabel(method)}${label == serviceRouteMethodLabel(method) ? '' : ' - $label'}',
          sourceServiceId: source.id,
          sourceEndpointId: _sourceEndpointId,
          hops: [hop],
          finalUrl: target,
          accessLevel: _accessLevel,
          notes: _emptyToNull(_notesCtrl.text),
        ),
      );
    }
    return routes;
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
                    for (final service in widget.services.where(
                      (service) => service.id != _sourceServiceId,
                    ))
                      DropdownMenuItem(
                        value: service.id,
                        child: Text(service.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _relayServiceId = value),
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
}

class _ServiceTopologyView extends StatelessWidget {
  final ServiceTopologyGraph graph;

  const _ServiceTopologyView({required this.graph});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _TopologyLayout.build(graph, constraints.maxWidth);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(160),
              minScale: 0.35,
              maxScale: 2.2,
              child: CustomPaint(
                size: layout.size,
                painter: _ServiceTopologyPainter(
                  graph: graph,
                  layout: layout,
                  colorScheme: Theme.of(context).colorScheme,
                  textTheme: Theme.of(context).textTheme,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopologyLayout {
  final Size size;
  final Map<String, Rect> nodeRects;

  const _TopologyLayout({required this.size, required this.nodeRects});

  static const nodeWidth = 178.0;
  static const nodeHeight = 68.0;
  static const horizontalGap = 48.0;
  static const verticalGap = 26.0;
  static const padding = 24.0;

  static _TopologyLayout build(
    ServiceTopologyGraph graph,
    double viewportWidth,
  ) {
    final nodeById = {for (final node in graph.nodes) node.id: node};
    final remoteDeviceIds = graph.edges
        .where(
          (edge) => nodeById[edge.to]?.kind == ServiceTopologyNodeKind.device,
        )
        .where((edge) {
          final fromKind = nodeById[edge.from]?.kind;
          return fromKind == ServiceTopologyNodeKind.relay ||
              fromKind == ServiceTopologyNodeKind.remoteEntry;
        })
        .map((edge) => edge.to)
        .toSet();
    final columns = <int, List<ServiceTopologyNode>>{};
    for (final node in graph.nodes) {
      final column = switch (node.kind) {
        ServiceTopologyNodeKind.device =>
          remoteDeviceIds.contains(node.id) ? 4 : 0,
        ServiceTopologyNodeKind.service => 1,
        ServiceTopologyNodeKind.endpoint => 2,
        ServiceTopologyNodeKind.relay => 3,
        ServiceTopologyNodeKind.remoteEntry => 5,
        ServiceTopologyNodeKind.domain => 6,
      };
      columns.putIfAbsent(column, () => []).add(node);
    }
    for (final nodes in columns.values) {
      nodes.sort(
        (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
    }

    final rects = <String, Rect>{};
    var maxHeight = 0.0;
    for (final entry in columns.entries) {
      final x = padding + entry.key * (nodeWidth + horizontalGap);
      for (var i = 0; i < entry.value.length; i++) {
        final y = padding + i * (nodeHeight + verticalGap);
        rects[entry.value[i].id] = Rect.fromLTWH(x, y, nodeWidth, nodeHeight);
        maxHeight = math.max(maxHeight, y + nodeHeight + padding);
      }
    }
    final maxColumn = columns.keys.fold<int>(0, math.max);
    final width = math.max(
      viewportWidth,
      padding * 2 + (maxColumn + 1) * nodeWidth + maxColumn * horizontalGap,
    );
    final height = math.max(320.0, maxHeight);
    return _TopologyLayout(size: Size(width, height), nodeRects: rects);
  }
}

class _ServiceTopologyPainter extends CustomPainter {
  final ServiceTopologyGraph graph;
  final _TopologyLayout layout;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  _ServiceTopologyPainter({
    required this.graph,
    required this.layout,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final edge in graph.edges) {
      final from = layout.nodeRects[edge.from];
      final to = layout.nodeRects[edge.to];
      if (from == null || to == null) continue;
      _drawEdge(canvas, edgePaint, from, to);
    }
    for (final node in graph.nodes) {
      final rect = layout.nodeRects[node.id];
      if (rect == null) continue;
      _drawNode(canvas, node, rect);
    }
  }

  void _drawEdge(Canvas canvas, Paint paint, Rect from, Rect to) {
    final start = Offset(from.right, from.center.dy);
    final end = Offset(to.left, to.center.dy);
    final dx = math.max(32.0, (end.dx - start.dx).abs() * 0.45);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(start.dx + dx, start.dy, end.dx - dx, end.dy, end.dx, end.dy);
    canvas.drawPath(path, paint);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
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

  void _drawNode(Canvas canvas, ServiceTopologyNode node, Rect rect) {
    final fill = _nodeFill(node.kind);
    final border = _nodeBorder(node.kind);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    _drawIcon(canvas, node.kind, Offset(rect.left + 18, rect.center.dy));
    _paintText(
      canvas,
      node.label,
      Offset(rect.left + 42, rect.top + 13),
      rect.width - 54,
      textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ) ??
          TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700),
    );
    final detail = node.detail;
    if (detail != null && detail.trim().isNotEmpty) {
      _paintText(
        canvas,
        detail,
        Offset(rect.left + 42, rect.top + 38),
        rect.width - 54,
        textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant) ??
            TextStyle(color: colorScheme.onSurfaceVariant),
      );
    }
  }

  void _drawIcon(Canvas canvas, ServiceTopologyNodeKind kind, Offset center) {
    final paint = Paint()..color = _nodeBorder(kind).withValues(alpha: 0.22);
    canvas.drawCircle(center, 14, paint);
    final text = switch (kind) {
      ServiceTopologyNodeKind.device => 'D',
      ServiceTopologyNodeKind.service => 'S',
      ServiceTopologyNodeKind.endpoint => ':',
      ServiceTopologyNodeKind.relay => 'R',
      ServiceTopologyNodeKind.remoteEntry => 'IP',
      ServiceTopologyNodeKind.domain => 'DNS',
    };
    _paintText(
      canvas,
      text,
      Offset(center.dx - 11, center.dy - 7),
      22,
      TextStyle(
        color: _nodeBorder(kind),
        fontSize: text.length > 2 ? 8 : 11,
        fontWeight: FontWeight.w800,
      ),
      align: TextAlign.center,
    );
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    double width,
    TextStyle style, {
    TextAlign align = TextAlign.start,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  Color _nodeFill(ServiceTopologyNodeKind kind) => switch (kind) {
    ServiceTopologyNodeKind.device => colorScheme.primaryContainer.withValues(
      alpha: 0.72,
    ),
    ServiceTopologyNodeKind.service =>
      colorScheme.secondaryContainer.withValues(alpha: 0.72),
    ServiceTopologyNodeKind.endpoint =>
      colorScheme.tertiaryContainer.withValues(alpha: 0.72),
    ServiceTopologyNodeKind.relay => colorScheme.surfaceContainerHighest,
    ServiceTopologyNodeKind.remoteEntry =>
      colorScheme.errorContainer.withValues(alpha: 0.54),
    ServiceTopologyNodeKind.domain => colorScheme.primary.withValues(
      alpha: 0.14,
    ),
  };

  Color _nodeBorder(ServiceTopologyNodeKind kind) => switch (kind) {
    ServiceTopologyNodeKind.device => colorScheme.primary,
    ServiceTopologyNodeKind.service => colorScheme.secondary,
    ServiceTopologyNodeKind.endpoint => colorScheme.tertiary,
    ServiceTopologyNodeKind.relay => colorScheme.outline,
    ServiceTopologyNodeKind.remoteEntry => colorScheme.error,
    ServiceTopologyNodeKind.domain => colorScheme.primary,
  };

  @override
  bool shouldRepaint(covariant _ServiceTopologyPainter oldDelegate) =>
      oldDelegate.graph != graph ||
      oldDelegate.layout != layout ||
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.textTheme != textTheme;
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
