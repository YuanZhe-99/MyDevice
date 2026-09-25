import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/widgets/adaptive_tile_grid.dart';
import '../../devices/models/device.dart';
import '../../devices/services/device_storage.dart';
import '../../network/models/network.dart';
import '../../network/services/network_storage.dart';
import '../models/service.dart';
import '../services/service_access_patterns.dart';
import '../services/service_analysis.dart';
import '../services/service_labels.dart';
import '../services/service_storage.dart';
import 'service_access_path_page.dart';
import 'service_edit_page.dart';
import 'service_route_edit_page.dart';
import 'service_topology_page.dart';
import 'service_topology_widgets.dart';

enum _ServiceView { overview, devices, routes, ports }

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
    final columns = await DeviceStorage.getServiceListColumns();
    if (!mounted) return;
    setState(() {
      _services = serviceData.services;
      _routes = serviceData.routes;
      _devices = deviceData.devices;
      _networks = networkData.networks;
      _columnsPref = columns;
      _loading = false;
    });
  }

  /// Purpose: Store a new column preference and re-render with it.
  /// Inputs: `columns` — `listColumnsAuto` or a pinned count.
  /// Returns: `void`.
  /// Side effects: Updates widget state and writes `storage_config.json`.
  /// Notes: Internal helper used within this file only. One preference serves
  /// the devices, routes and ports views; the overview stays a single column.
  void _setColumnsPref(int columns) {
    setState(() => _columnsPref = columns);
    DeviceStorage.setServiceListColumns(columns);
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
    final result = await Navigator.of(context, rootNavigator: true)
        .push<ServiceEditOutcome>(
          MaterialPageRoute(builder: (_) => const ServiceEditPage()),
        );
    if (result != null) _load();
  }

  /// Purpose: Edit service and refresh local state when needed.
  /// Inputs: `service`.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _editService(ServiceNode service) async {
    final result = await Navigator.of(context, rootNavigator: true)
        .push<ServiceEditOutcome>(
          MaterialPageRoute(builder: (_) => ServiceEditPage(service: service)),
        );
    if (result != null) _load();
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

  /// Purpose: Open the guided access-path page for a new access path.
  /// Inputs: `draft` — the starting draft, e.g. with the source prefilled.
  /// Returns: `Future<void>`.
  /// Side effects: Pushes `ServiceAccessPathPage` on the root navigator;
  /// reloads when it saved.
  /// Notes: Every "Add access" entry point on this page and in the topology
  /// comes through here.
  Future<void> _addAccessPath({ServiceAccessDraft? draft}) async {
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => ServiceAccessPathPage(draft: draft)),
    );
    if (saved == true) await _load();
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
    // Gate on the whole screen; measure capacity from what the views get
    // after the navigation rail and their 8 dp padding. The overview is a
    // heterogeneous scroll and never takes columns, so its button is hidden.
    final screen = MediaQuery.sizeOf(context);
    final contentWidth = shellContentWidth(screen.width) - 16;
    final capacity = canSplitLayout(screen.width, screen.height)
        ? columnCapacity(contentWidth, minItemWidth: serviceCardMinWidth)
        : 1;
    final columns = listColumnCount(
      screenWidth: screen.width,
      screenHeight: screen.height,
      contentWidth: contentWidth,
      minItemWidth: serviceCardMinWidth,
      preference: _columnsPref,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navServices),
        actions: [
          if (_view != _ServiceView.overview)
            listColumnsButton(
              context,
              preference: _columnsPref,
              capacity: capacity,
              onChanged: _setColumnsPref,
            ),
          IconButton(
            icon: const Icon(Icons.add_link),
            tooltip: l10n.serviceAddAccess,
            onPressed: _services.isEmpty ? null : () => _addAccessPath(),
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
                Expanded(child: _buildCurrentView(l10n, columns)),
              ],
            ),
    );
  }

  /// Purpose: Build and return current view for the current context.
  /// Inputs: `l10n`, `columns` — from `listColumnCount`, ignored by the
  /// overview.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildCurrentView(AppLocalizations l10n, int columns) =>
      switch (_view) {
        _ServiceView.overview => _buildOverview(l10n),
        _ServiceView.devices => _buildDevices(l10n, columns),
        _ServiceView.routes => _buildRoutes(l10n, columns),
        _ServiceView.ports => _buildPorts(l10n, columns),
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
            const spacing = listTileGap;
            final availableWidth = constraints.maxWidth;
            final columnCount = serviceMetricColumns(availableWidth);
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
                    Text(serviceWarningLabel(l10n, warning)),
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
            onPressed: () => _addAccessPath(),
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
  /// Inputs: `l10n`, `columns` — cards per row.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only. The cards are
  /// materialized children of one `ListView`, so `adaptiveTileRows` spreads
  /// them; expansion tiles of different heights top-align within a row.
  Widget _buildDevices(AppLocalizations l10n, int columns) {
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
      children: adaptiveTileRows(
        columns: columns,
        itemCount: entries.length,
        itemBuilder: (i) {
          final entry = entries[i];
          return Card(
            child: ExpansionTile(
              leading: const Icon(Icons.devices_other),
              title: Text(_deviceById(entry.key)?.name ?? entry.key),
              subtitle: Text(l10n.serviceCount(entry.value.length)),
              initiallyExpanded: true,
              children: [
                for (final service in entry.value) _serviceTile(service),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Purpose: Build and return routes for the current context.
  /// Inputs: `l10n`, `columns` — cards per row.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildRoutes(AppLocalizations l10n, int columns) {
    if (_routes.isEmpty) return _emptyState(l10n.noServiceRoutes);
    return ListView(
      padding: const EdgeInsets.all(8),
      children: adaptiveTileRows(
        columns: columns,
        itemCount: _routes.length,
        itemBuilder: (i) => _routeCard(_routes[i]),
      ),
    );
  }

  /// Purpose: Build and return ports for the current context.
  /// Inputs: `l10n`, `columns` — per-device cards per row; the conflicts
  /// card and the heading stay full width.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildPorts(AppLocalizations l10n, int columns) {
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
        ...adaptiveTileRows(
          columns: columns,
          itemCount: servicesByDevice.length,
          itemBuilder: (i) {
            final entry = servicesByDevice.entries.elementAt(i);
            return Card(
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
                      leading: Icon(iconForService(use.service)),
                      title: Text('${use.transport.name}/${use.port}'),
                      subtitle: Text(
                        [
                              use.service.name,
                              use.endpoint.label,
                              use.bindAddress == '*'
                                  ? l10n.serviceAnyAddress
                                  : use.bindAddress,
                              use.endpoint.path,
                              _routesForEndpoint(
                                use.service.id,
                                use.endpoint.id,
                              ),
                            ]
                            .whereType<String>()
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                      ),
                      onTap: () => _editService(use.service),
                    ),
                ],
              ),
            );
          },
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
            final compact = !useTopologyActionsRow(constraints.maxWidth);
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
                    onPressed: () => _addAccessPath(),
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
        builder: (_) => ServiceTopologyPage(
          graph: graph,
          services: _services,
          devices: _devices,
          routes: _routes,
          onEditService: _editService,
          onEditRoute: _editRoute,
          onAddAccess: _addAccessPath,
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
            service == null ? Icons.alt_route : iconForService(service),
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
                    : () => _addAccessPath(
                        draft: ServiceAccessDraft(sourceServiceId: service.id),
                      ),
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
      leading: CircleAvatar(child: Icon(iconForService(service), size: 22)),
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
            _addAccessPath(
              draft: ServiceAccessDraft(sourceServiceId: service.id),
            );
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
    return serviceHopTypeLabel(AppLocalizations.of(context)!, hop.type);
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
    return [
      path,
      serviceAccessLevelLabel(AppLocalizations.of(context)!, route.accessLevel),
    ].join('\n');
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
