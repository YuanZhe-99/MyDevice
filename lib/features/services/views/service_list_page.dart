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
import '../services/service_topology_layout.dart';
import '../services/service_storage.dart';
import 'service_edit_page.dart';
import 'service_route_edit_page.dart';

enum _ServiceView { overview, devices, routes, ports }

enum _TopologyInteractionMode { select, move }

enum _QuickAccessMethod {
  /// Purpose: Implement the direct behavior for this file.
  /// Inputs: `custom`.
  /// Returns: `dynamic`.
  /// Side effects: Implementation-dependent.
  /// Notes: Implementations should preserve this contract.
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

  /// Purpose: Create a quick access method instance.
  /// Inputs: `routeMethod`.
  /// Returns: A new `_QuickAccessMethod` instance.
  /// Side effects: Implementation-dependent.
  /// Notes: Implementations should preserve this contract.
  const _QuickAccessMethod(this.routeMethod);

  /// Purpose: Return whether port mapping is true.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isPortMapping =>
      routeMethod == ServiceRouteMethod.frp ||
      routeMethod == ServiceRouteMethod.routerPortForward;
}

class ServiceListPage extends StatefulWidget {
  /// Purpose: Create a service list page instance.
  /// Inputs: None.
  /// Returns: A new `ServiceListPage` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  const ServiceListPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `State` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
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

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Registers listeners and may kick off asynchronous loading.
  /// Notes: Guard any post-await UI updates with `mounted` when needed.
  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnLocalDataChanged(_handleLocalDataChanged);
    _load();
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

  /// Purpose: Load the relevant data into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Look up device by id from the current in-memory state.
  /// Inputs: `id`.
  /// Returns: `Device?`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Device? _deviceById(String id) =>
      _devices.where((device) => device.id == id).firstOrNull;

  /// Purpose: Look up service by id from the current in-memory state.
  /// Inputs: `id`.
  /// Returns: `ServiceNode?`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  ServiceNode? _serviceById(String id) =>
      _services.where((service) => service.id == id).firstOrNull;

  /// Purpose: Look up endpoint by id from the current in-memory state.
  /// Inputs: `service`, `endpointId`.
  /// Returns: `ServiceEndpoint?`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  ServiceEndpoint? _endpointById(ServiceNode service, String? endpointId) {
    if (endpointId == null) return service.endpoints.firstOrNull;
    return service.endpoints
        .where((endpoint) => endpoint.id == endpointId)
        .firstOrNull;
  }

  /// Purpose: Add service through the current flow.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _addService() async {
    final result = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ServiceEditPage()));
    if (result == true) _load();
  }

  /// Purpose: Edit service and refresh local state when needed.
  /// Inputs: `service`.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _editService(ServiceNode service) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => ServiceEditPage(service: service)),
    );
    if (result == true) _load();
  }

  /// Purpose: Add route through the current flow.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _addRoute({ServiceNode? source}) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => ServiceRouteEditPage(sourceService: source),
      ),
    );
    if (result == true) _load();
  }

  /// Purpose: Add access route through the current flow.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Edit route and refresh local state when needed.
  /// Inputs: `route`.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _editRoute(ServiceRoute route) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => ServiceRouteEditPage(route: route)),
    );
    if (result == true) _load();
  }

  /// Purpose: Return the display label for view label.
  /// Inputs: `l10n`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _viewLabel(AppLocalizations l10n, _ServiceView view) => switch (view) {
    _ServiceView.overview => l10n.servicesOverview,
    _ServiceView.devices => l10n.servicesByDevice,
    _ServiceView.routes => l10n.serviceRoutes,
    _ServiceView.ports => l10n.servicePorts,
  };

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
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

  /// Purpose: Build and return current view for the current context.
  /// Inputs: None.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildCurrentView(AppLocalizations l10n) => switch (_view) {
    _ServiceView.overview => _buildOverview(l10n),
    _ServiceView.devices => _buildDevices(l10n),
    _ServiceView.routes => _buildRoutes(l10n),
    _ServiceView.ports => _buildPorts(l10n),
  };

  /// Purpose: Build and return overview for the current context.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            const minMetricWidth = 150.0;
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width - 32;
            final columnCount = math.min(
              4,
              math.max(
                1,
                ((availableWidth + spacing) / (minMetricWidth + spacing))
                    .floor(),
              ),
            );
            final cardWidth =
                (availableWidth - spacing * (columnCount - 1)) / columnCount;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _metricCard(
                  l10n.activeServices,
                  activeCount,
                  Icons.dns_outlined,
                  width: cardWidth,
                ),
                _metricCard(
                  l10n.serviceDevices,
                  deviceCount,
                  Icons.devices_other,
                  width: cardWidth,
                ),
                _metricCard(
                  l10n.serviceRoutes,
                  _routes.length,
                  Icons.alt_route,
                  width: cardWidth,
                ),
                _metricCard(
                  l10n.publicRoutes,
                  publicRoutes,
                  Icons.public,
                  width: cardWidth,
                ),
              ],
            );
          },
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

  /// Purpose: Build and return devices for the current context.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Build and return routes for the current context.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildRoutes(AppLocalizations l10n) {
    if (_routes.isEmpty) return _emptyState(l10n.noServiceRoutes);
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [for (final route in _routes) _routeCard(route)],
    );
  }

  /// Purpose: Build and return ports for the current context.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal topology card helper for this file.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final title = Row(
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: compact ? WrapAlignment.start : WrapAlignment.end,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.max(0.0, constraints.maxWidth),
                  ),
                  child: TextButton.icon(
                    onPressed: () => _addAccessRoute(),
                    icon: const Icon(Icons.add_link),
                    label: Text(
                      l10n.serviceAddAccess,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (!graph.isEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.max(0.0, constraints.maxWidth),
                    ),
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openTopology(graph),
                      icon: const Icon(Icons.open_in_full),
                      label: Text(
                        l10n.serviceOpenTopology,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (compact) ...[
                  title,
                  const SizedBox(height: 12),
                  actions,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 16),
                      actions,
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
            );
          },
        ),
      ),
    );
  }

  /// Purpose: Provide the internal open topology helper for this file.
  /// Inputs: `graph`.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal routes grouped by service helper for this file.
  /// Inputs: None.
  /// Returns: `List<MapEntry<String, List<ServiceRoute>>>`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal service route group card helper for this file.
  /// Inputs: `l10n`, `serviceId`, `routes`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal metric card helper for this file.
  /// Inputs: `label`, `value`, `icon`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _metricCard(
    String label,
    int value,
    IconData icon, {
    double width = 160,
  }) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
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

  /// Purpose: Provide the internal service tile helper for this file.
  /// Inputs: `service`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal route card helper for this file.
  /// Inputs: `route`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Return the display label for hop label.
  /// Inputs: `hop`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal route summary helper for this file.
  /// Inputs: `route`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal routes for endpoint helper for this file.
  /// Inputs: `serviceId`, `endpointId`.
  /// Returns: `String?`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal warning text helper for this file.
  /// Inputs: `l10n`, `warning`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal empty state helper for this file.
  /// Inputs: `message`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal empty inline helper for this file.
  /// Inputs: `message`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Create a quick access route dialog instance.
  /// Inputs: None.
  /// Returns: A new `_QuickAccessRouteDialog` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  const _QuickAccessRouteDialog({
    required this.services,
    required this.devices,
    this.initialService,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `State` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
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

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Registers listeners and may kick off asynchronous loading.
  /// Notes: Guard any post-await UI updates with `mounted` when needed.
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

  /// Purpose: Release listeners, controllers, and other owned resources.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Releases owned resources and unregisters listeners.
  /// Notes: Call the superclass implementation in the expected lifecycle order.
  @override
  void dispose() {
    _targetsCtrl.dispose();
    _remoteHostCtrl.dispose();
    _remotePortCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Purpose: Provide the internal selected source helper for this file.
  /// Inputs: None.
  /// Returns: `ServiceNode?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  ServiceNode? get _selectedSource => _sourceServiceId == null
      ? null
      : widget.services
            .where((service) => service.id == _sourceServiceId)
            .firstOrNull;

  /// Purpose: Build and return routes for the current context.
  /// Inputs: None.
  /// Returns: `List<ServiceRoute>`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Build and return hop for the current context.
  /// Inputs: `method`.
  /// Returns: `ServiceRouteHop`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal submit helper for this file.
  /// Inputs: None.
  /// Returns: `void`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_buildRoutes());
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state. Updates widget state and triggers a rebuild.
  /// Notes: Keep this method cheap because Flutter may call it often.
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

  /// Purpose: Provide the internal relay service options helper for this file.
  /// Inputs: None.
  /// Returns: `List<ServiceNode>`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal is frp like service helper for this file.
  /// Inputs: `service`.
  /// Returns: `bool`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  bool _isFrpLikeService(ServiceNode service) {
    final text = [
      service.name,
      service.templateId,
      service.icon,
      service.kind.name,
    ].whereType<String>().join(' ').toLowerCase();
    return text.contains('frp') || service.kind == ServiceKind.tunnel;
  }

  /// Purpose: Provide the internal device name helper for this file.
  /// Inputs: `id`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _deviceName(String id) =>
      widget.devices.where((device) => device.id == id).firstOrNull?.name ?? id;
}

class _ServiceTopologyView extends StatefulWidget {
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
  final ValueChanged<bool>? onLayoutReadyChanged;

  /// Purpose: Create a service topology view instance.
  /// Inputs: `graph`, service data, callbacks, `mode`, rotation, and optional capture/layout callbacks.
  /// Returns: A new `_ServiceTopologyView` instance.
  /// Side effects: None.
  /// Notes: The associated state object caches expensive topology layouts.
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
    this.onLayoutReadyChanged,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `_ServiceTopologyViewState` instance.
  /// Side effects: None.
  /// Notes: The state defers layout work until after the route can paint.
  @override
  State<_ServiceTopologyView> createState() => _ServiceTopologyViewState();
}

class _ServiceTopologyViewState extends State<_ServiceTopologyView> {
  ServiceTopologyLayout? _layout;
  _TopologyLayoutRequest? _completedRequest;
  _TopologyLayoutRequest? _pendingRequest;
  bool? _reportedLayoutReady;
  int _layoutGeneration = 0;

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Schedules asynchronous layout work when viewport inputs change.
  /// Notes: Keeps expensive topology layout out of the first synchronous page build.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final turns = widget.quarterTurns % 4;
        final viewportWidth = turns.isOdd && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : constraints.maxWidth;
        final request = _TopologyLayoutRequest(
          graph: widget.graph,
          routes: widget.routes,
          viewportWidth: viewportWidth.round(),
        );
        final ready = _completedRequest == request && _layout != null;
        if (!ready) _ensureLayout(request);
        _reportLayoutReady(ready);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            child: ready
                ? _buildViewer(context, _layout!, turns)
                : _buildLoading(),
          ),
        );
      },
    );
  }

  /// Purpose: Schedule layout computation for the requested topology inputs.
  /// Inputs: `request`.
  /// Returns: None.
  /// Side effects: Updates cached layout state after asynchronous computation finishes.
  /// Notes: Multiple rebuilds for the same request share one pending computation.
  void _ensureLayout(_TopologyLayoutRequest request) {
    if (_pendingRequest == request) return;
    _pendingRequest = request;
    final generation = ++_layoutGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateLayout(request, generation);
    });
  }

  /// Purpose: Calculate and cache a topology layout for one request.
  /// Inputs: `request`, `generation`.
  /// Returns: None.
  /// Side effects: Updates widget state and triggers a rebuild when still current.
  /// Notes: Runs after the first frame so the topology page can show immediately.
  Future<void> _calculateLayout(
    _TopologyLayoutRequest request,
    int generation,
  ) async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted ||
        generation != _layoutGeneration ||
        _pendingRequest != request) {
      return;
    }
    final layout = ServiceTopologyLayout.build(
      request.graph,
      request.routes,
      request.viewportWidth.toDouble(),
    );
    if (!mounted ||
        generation != _layoutGeneration ||
        _pendingRequest != request) {
      return;
    }
    setState(() {
      _layout = layout;
      _completedRequest = request;
      _pendingRequest = null;
    });
  }

  /// Purpose: Build the loading placeholder shown while topology layout is calculated.
  /// Inputs: None.
  /// Returns: A lightweight loading widget.
  /// Side effects: None.
  /// Notes: Avoids heavy work in the first route transition frame.
  Widget _buildLoading() {
    return const Center(
      child: SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(strokeWidth: 2.6),
      ),
    );
  }

  /// Purpose: Report whether the current topology layout can be captured or exported.
  /// Inputs: `ready`.
  /// Returns: None.
  /// Side effects: Calls the parent readiness callback after the current frame.
  /// Notes: The callback is deferred so build remains side-effect-free.
  void _reportLayoutReady(bool ready) {
    if (_reportedLayoutReady == ready) return;
    _reportedLayoutReady = ready;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onLayoutReadyChanged?.call(ready);
    });
  }

  /// Purpose: Build and return viewer for the current context.
  /// Inputs: `context`, `layout`, `turns`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildViewer(
    BuildContext context,
    ServiceTopologyLayout layout,
    int turns,
  ) {
    Widget canvas = SizedBox.fromSize(
      size: layout.size,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ServiceTopologyEdgePainter(
                graph: widget.graph,
                layout: layout,
                colorScheme: Theme.of(context).colorScheme,
              ),
            ),
          ),
          for (final node in widget.graph.nodes)
            if (layout.nodeRects[node.id] != null)
              Positioned.fromRect(
                rect: layout.nodeRects[node.id]!,
                child: _TopologyNodeCard(
                  node: node,
                  icon: _iconForTopologyNode(
                    node,
                    widget.services,
                    widget.devices,
                  ),
                  onTap: widget.mode == _TopologyInteractionMode.select
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
    if (widget.repaintBoundaryKey != null) {
      canvas = RepaintBoundary(key: widget.repaintBoundaryKey, child: canvas);
    }
    if (widget.mode == _TopologyInteractionMode.select) {
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

  /// Purpose: Show node details in the current UI flow.
  /// Inputs: `context`, `node`.
  /// Returns: `void`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  void _showNodeDetails(BuildContext context, ServiceTopologyNode node) {
    final device = node.deviceId == null
        ? null
        : widget.devices
              .where((device) => device.id == node.deviceId)
              .firstOrNull;
    final service = node.serviceId == null
        ? null
        : widget.services
              .where((service) => service.id == node.serviceId)
              .firstOrNull;
    final relatedRoutes = widget.routes
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
                  child: Icon(
                    _iconForTopologyNode(node, widget.services, widget.devices),
                  ),
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
                        widget.onEditService(service);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(AppLocalizations.of(context)!.editService),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        widget.onAddAccess(source: service);
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
                      widget.onEditRoute(route);
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

class _TopologyLayoutRequest {
  final ServiceTopologyGraph graph;
  final List<ServiceRoute> routes;
  final int viewportWidth;

  /// Purpose: Create a topology layout request cache key.
  /// Inputs: `graph`, `routes`, `viewportWidth`.
  /// Returns: A new `_TopologyLayoutRequest` instance.
  /// Side effects: None.
  /// Notes: Uses graph and route list identity so mode-only rebuilds reuse the cached layout.
  const _TopologyLayoutRequest({
    required this.graph,
    required this.routes,
    required this.viewportWidth,
  });

  /// Purpose: Compare layout request keys for cache reuse.
  /// Inputs: `other`.
  /// Returns: Whether both requests describe the same layout inputs.
  /// Side effects: None.
  /// Notes: Viewport width is rounded to avoid tiny constraint jitter causing re-layout.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TopologyLayoutRequest &&
          identical(other.graph, graph) &&
          identical(other.routes, routes) &&
          other.viewportWidth == viewportWidth;

  /// Purpose: Produce a hash for the layout request cache key.
  /// Inputs: None.
  /// Returns: An integer hash code.
  /// Side effects: None.
  /// Notes: Matches the equality contract for graph identity, route identity, and viewport width.
  @override
  int get hashCode => Object.hash(
    identityHashCode(graph),
    identityHashCode(routes),
    viewportWidth,
  );
}

class _ServiceTopologyPage extends StatefulWidget {
  final ServiceTopologyGraph graph;
  final List<ServiceNode> services;
  final List<Device> devices;
  final List<ServiceRoute> routes;
  final ValueChanged<ServiceNode> onEditService;
  final ValueChanged<ServiceRoute> onEditRoute;
  final Future<void> Function({ServiceNode? source}) onAddAccess;

  /// Purpose: Create a service topology page instance.
  /// Inputs: None.
  /// Returns: A new `_ServiceTopologyPage` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  const _ServiceTopologyPage({
    required this.graph,
    required this.services,
    required this.devices,
    required this.routes,
    required this.onEditService,
    required this.onEditRoute,
    required this.onAddAccess,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `State` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  @override
  State<_ServiceTopologyPage> createState() => _ServiceTopologyPageState();
}

class _ServiceTopologyPageState extends State<_ServiceTopologyPage> {
  _TopologyInteractionMode _mode = _TopologyInteractionMode.select;
  final _captureKey = GlobalKey();
  int _quarterTurns = 0;
  bool _exporting = false;
  bool _layoutReady = false;

  /// Purpose: Export topology image to an external representation.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _exportTopologyImage() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_layoutReady) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.serviceTopology)));
      return;
    }
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

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state. Updates widget state and triggers a rebuild.
  /// Notes: Keep this method cheap because Flutter may call it often.
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
            onPressed: _exporting || !_layoutReady
                ? null
                : _exportTopologyImage,
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
                onLayoutReadyChanged: (ready) {
                  if (_layoutReady == ready) return;
                  setState(() => _layoutReady = ready);
                },
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

  /// Purpose: Create a topology node card instance.
  /// Inputs: None.
  /// Returns: A new `_TopologyNodeCard` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  const _TopologyNodeCard({
    required this.node,
    required this.icon,
    required this.onTap,
  });

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = _nodeBorder(context, node);
    final compact = node.compact;
    if (compact) {
      return Tooltip(
        message: [
          node.label,
          node.detail,
          node.lane == null ? null : _laneLabel(node.lane!),
        ].whereType<String>().join('\n'),
        child: SizedBox.square(
          dimension: ServiceTopologyLayout.portChipSize,
          child: Card(
            margin: EdgeInsets.zero,
            color: _nodeFill(context, node),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: border, width: 1.2),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 16, color: border),
                    const SizedBox(height: 2),
                    Text(
                      _compactTopologyLabel(node),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      if (node.detail?.trim().isNotEmpty == true ||
                          node.lane != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (node.detail?.trim().isNotEmpty == true)
                              node.detail,
                            if (node.lane != null) _laneLabel(node.lane!),
                          ].whereType<String>().join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
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

class _ServiceTopologyEdgePainter extends CustomPainter {
  final ServiceTopologyGraph graph;
  final ServiceTopologyLayout layout;
  final ColorScheme colorScheme;

  /// Purpose: Create a service topology edge painter instance.
  /// Inputs: None.
  /// Returns: A new `_ServiceTopologyEdgePainter` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  const _ServiceTopologyEdgePainter({
    required this.graph,
    required this.layout,
    required this.colorScheme,
  });

  /// Purpose: Implement the paint behavior for this file.
  /// Inputs: `canvas`, `size`.
  /// Returns: None.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in graph.edges) {
      final points = layout.edgePaths[edge];
      if (points == null || points.length < 2) continue;
      final paint = Paint()
        ..color = _edgeColor(edge).withValues(alpha: 0.62)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      _drawPolyline(canvas, paint, points);
    }
  }

  /// Purpose: Provide the internal draw polyline helper for this file.
  /// Inputs: `canvas`, `paint`, `points`.
  /// Returns: `void`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  void _drawPolyline(Canvas canvas, Paint paint, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);

    final end = points.last;
    var previous = points[points.length - 2];
    for (var i = points.length - 2; i >= 0; i--) {
      if ((end - points[i]).distance > 0.5) {
        previous = points[i];
        break;
      }
    }
    final angle = math.atan2(end.dy - previous.dy, end.dx - previous.dx);
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

  /// Purpose: Provide the internal edge color helper for this file.
  /// Inputs: None.
  /// Returns: `Color`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Color _edgeColor(ServiceTopologyEdge edge) => switch (edge.lane) {
    ServiceAccessLane.local => colorScheme.tertiary,
    ServiceAccessLane.vpn => colorScheme.secondary,
    ServiceAccessLane.public => colorScheme.primary,
    null => colorScheme.outline,
  };

  /// Purpose: Implement the should repaint behavior for this file.
  /// Inputs: `oldDelegate`.
  /// Returns: `bool`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
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

String _compactTopologyLabel(ServiceTopologyNode node) {
  if (node.kind == ServiceTopologyNodeKind.remoteEntry) {
    final label = node.label.trim();
    final portMatch = RegExp(r':(\d{1,5}(?:-\d{1,5})?)$').firstMatch(label);
    if (portMatch != null) return portMatch.group(1)!;
    if (label.length <= 5) return label;
    return label.substring(0, 5);
  }
  final source = [node.label, node.detail].whereType<String>().join(' ');
  final matches = RegExp(r'\d{1,5}(?:-\d{1,5})?').allMatches(source).toList();
  if (matches.isNotEmpty) return matches.last.group(0)!;
  final label = node.label.trim();
  if (label.length <= 5) return label;
  return label.substring(0, 5);
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
