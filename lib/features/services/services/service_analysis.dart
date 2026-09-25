import '../../devices/models/device.dart';
import '../../network/models/network.dart';
import '../models/service.dart';

const serviceRoutePublicTargetsKey = 'publicTargets';

/// Key in a route's `extraJson` that pins the route's topology access lane.
///
/// The value is a [ServiceAccessLane] name: `local`, `vpn` or `public`. The
/// key is optional and additive: builds older than 1.5.6 keep it through the
/// `extraJson` unknown-field pattern and go on inferring the lane, and an
/// absent or unknown value falls back to that same inference here.
const serviceRouteAccessLaneKey = 'accessLane';

enum ServiceTopologyNodeKind {
  device,
  service,
  endpoint,
  relay,
  remoteEntry,
  domain,
}

enum ServiceTopologyNodeRole {
  localDevice,
  remoteDevice,
  localService,
  remoteService,
  localEndpoint,
  lanAccess,
  vpnAccess,
  publicRelay,
  remotePublicEntry,
  domain,
}

enum ServiceAccessLane { local, vpn, public }

class ServiceTopologyNode {
  final String id;
  final ServiceTopologyNodeKind kind;
  final ServiceTopologyNodeRole role;
  final String label;
  final String? detail;
  final String? deviceId;
  final String? serviceId;
  final String? endpointId;
  final ServiceAccessLane? lane;
  final ServiceRouteMethod? method;
  final bool compact;
  final List<String> routeIds;

  /// Purpose: Create a service topology node instance.
  /// Inputs: `compact`.
  /// Returns: A new `ServiceTopologyNode` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  const ServiceTopologyNode({
    required this.id,
    required this.kind,
    required this.role,
    required this.label,
    this.detail,
    this.deviceId,
    this.serviceId,
    this.endpointId,
    this.lane,
    this.method,
    this.compact = false,
    this.routeIds = const [],
  });

  /// Purpose: Implement the merge route behavior for this file.
  /// Inputs: `routeId`.
  /// Returns: `ServiceTopologyNode`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  ServiceTopologyNode mergeRoute(String routeId) {
    if (routeIds.contains(routeId)) return this;
    return merge(this, routeId: routeId);
  }

  /// Purpose: Implement the merge behavior for this file.
  /// Inputs: `other`.
  /// Returns: `ServiceTopologyNode`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  ServiceTopologyNode merge(ServiceTopologyNode other, {String? routeId}) {
    final routes = <String>{...routeIds, ...other.routeIds};
    if (routeId != null) routes.add(routeId);
    final preferredRole = _preferTopologyRole(role, other.role);
    final otherDetail = other.detail?.trim();
    final shouldPreferOtherDetail =
        otherDetail != null &&
        otherDetail.isNotEmpty &&
        preferredRole == other.role &&
        preferredRole != role;
    return ServiceTopologyNode(
      id: id,
      kind: kind,
      role: preferredRole,
      label: label,
      detail: shouldPreferOtherDetail
          ? other.detail
          : (detail?.isNotEmpty == true ? detail : other.detail),
      deviceId: deviceId,
      serviceId: serviceId,
      endpointId: endpointId,
      lane: lane ?? other.lane,
      method: method ?? other.method,
      compact: compact || other.compact,
      routeIds: routes.toList(),
    );
  }
}

class ServiceTopologyEdge {
  final String from;
  final String to;
  final String? label;
  final String? routeId;
  final ServiceAccessLane? lane;
  final ServiceRouteMethod? method;

  /// Every route that runs along this edge, in the order they added it.
  ///
  /// Edges are shared: two routes through the same pair of nodes in the same
  /// lane and method produce one edge, whose [routeId] names only the first.
  /// Selection highlighting needs all of them. Empty for the structural
  /// device-to-service edges no route adds.
  final List<String> routeIds;

  /// Purpose: Create a service topology edge instance.
  /// Inputs: None.
  /// Returns: A new `ServiceTopologyEdge` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  const ServiceTopologyEdge({
    required this.from,
    required this.to,
    this.label,
    this.routeId,
    this.lane,
    this.method,
    this.routeIds = const [],
  });

  /// Purpose: Return this edge with one more route running along it.
  /// Inputs: `routeId`.
  /// Returns: `ServiceTopologyEdge` — this edge itself when the route is
  /// already listed.
  /// Side effects: None.
  /// Notes: Keeps [routeId], the route that added the edge first.
  ServiceTopologyEdge withRoute(String routeId) {
    if (routeIds.contains(routeId)) return this;
    return ServiceTopologyEdge(
      from: from,
      to: to,
      label: label,
      routeId: this.routeId,
      lane: lane,
      method: method,
      routeIds: [...routeIds, routeId],
    );
  }
}

class ServiceTopologyGraph {
  final List<ServiceTopologyNode> nodes;
  final List<ServiceTopologyEdge> edges;

  /// Purpose: Create a service topology graph instance.
  /// Inputs: None.
  /// Returns: A new `ServiceTopologyGraph` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  const ServiceTopologyGraph({required this.nodes, required this.edges});

  /// Purpose: Return whether empty is true.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isEmpty => nodes.isEmpty;
}

class ServicePortUse {
  final ServiceNode service;
  final ServiceEndpoint endpoint;
  final ServiceTransport transport;
  final int port;
  final String bindAddress;

  /// Purpose: Create a service port use instance.
  /// Inputs: None.
  /// Returns: A new `ServicePortUse` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  const ServicePortUse({
    required this.service,
    required this.endpoint,
    required this.transport,
    required this.port,
    required this.bindAddress,
  });

  /// Purpose: Return the current uses any address value.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get usesAnyAddress => bindAddress == '*';
}

class ServicePortConflict {
  final String deviceId;
  final int port;
  final ServiceTransport transport;
  final List<ServicePortUse> uses;
  final bool potential;

  /// Purpose: Create a service port conflict instance.
  /// Inputs: `potential`.
  /// Returns: A new `ServicePortConflict` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  const ServicePortConflict({
    required this.deviceId,
    required this.port,
    required this.transport,
    required this.uses,
    this.potential = false,
  });
}

enum ServiceWarningKind {
  missingDevice,
  inactiveDevice,
  missingEndpointNetwork,
  missingSourceService,
  missingSourceEndpoint,
  missingHopService,
  missingHopEndpoint,
  missingHopDevice,
  emptyRoute,
  publicRouteMissingUrl,
  duplicateFinalUrl,
}

class ServiceWarning {
  final ServiceWarningKind kind;
  final String name;
  final String? detail;

  /// Purpose: Create a service warning instance.
  /// Inputs: `kind`, `name`.
  /// Returns: A new `ServiceWarning` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  const ServiceWarning(this.kind, this.name, {this.detail});
}

List<ServicePortUse> listServicePortUses(List<ServiceNode> services) {
  final uses = <ServicePortUse>[];
  for (final service in services) {
    for (final endpoint in service.endpoints) {
      if (endpoint.port == null) continue;
      final transports = endpoint.transport == ServiceTransport.tcpUdp
          ? [ServiceTransport.tcp, ServiceTransport.udp]
          : [endpoint.transport];
      final start = endpoint.port!;
      final end = endpoint.portEnd != null && endpoint.portEnd! >= start
          ? endpoint.portEnd!
          : start;
      for (final transport in transports) {
        for (var port = start; port <= end; port++) {
          uses.add(
            ServicePortUse(
              service: service,
              endpoint: endpoint,
              transport: transport,
              port: port,
              bindAddress: normalizedBindAddress(endpoint.bindAddress),
            ),
          );
        }
      }
    }
  }

  /// Purpose: Implement the sort behavior for this file.
  /// Inputs: `deviceCmp`.
  /// Returns: `dynamic`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  uses.sort((a, b) {
    final deviceCmp = a.service.deviceId.compareTo(b.service.deviceId);
    if (deviceCmp != 0) return deviceCmp;
    final transportCmp = a.transport.index.compareTo(b.transport.index);
    if (transportCmp != 0) return transportCmp;
    final portCmp = a.port.compareTo(b.port);
    if (portCmp != 0) return portCmp;
    return a.service.name.toLowerCase().compareTo(b.service.name.toLowerCase());
  });
  return uses;
}

List<ServicePortConflict> findServicePortConflicts(List<ServiceNode> services) {
  final usesByKey = <String, List<ServicePortUse>>{};
  for (final use in listServicePortUses(services)) {
    final key = '${use.service.deviceId}:${use.transport.name}:${use.port}';
    usesByKey.putIfAbsent(key, () => []).add(use);
  }

  final conflicts = <ServicePortConflict>[];
  for (final entry in usesByKey.entries) {
    if (entry.value.length < 2) continue;
    final overlapping = <ServicePortUse>[];
    for (var i = 0; i < entry.value.length; i++) {
      for (var j = i + 1; j < entry.value.length; j++) {
        final a = entry.value[i];
        final b = entry.value[j];
        if (_bindsOverlap(a.bindAddress, b.bindAddress)) {
          overlapping.add(a);
          overlapping.add(b);
        }
      }
    }
    final distinctUses = overlapping.toSet().toList();
    if (distinctUses.length < 2) continue;
    final parts = entry.key.split(':');
    final allConcrete = distinctUses.every((use) => !use.usesAnyAddress);
    conflicts.add(
      ServicePortConflict(
        deviceId: parts[0],
        transport: ServiceTransport.fromJson(parts[1]),
        port: int.parse(parts[2]),
        uses: distinctUses,
        potential: allConcrete,
      ),
    );
  }
  return conflicts;
}

/// Purpose: Build the semantic topology graph from saved services and routes.
/// Inputs: `services`, `routes`, `devices`.
/// Returns: A `ServiceTopologyGraph` whose nodes are sorted by kind, then
/// label.
/// Side effects: None.
/// Notes: Every service gets a device-to-service edge whether or not a route
/// uses it. Port-mapping hops (FRP, router port forward) render the relay
/// service with its ingress endpoint and the public entry as sibling chips.
/// The layout engine consumes this graph unchanged; it never re-derives
/// modeling rules.
ServiceTopologyGraph buildServiceTopology({
  required List<ServiceNode> services,
  required List<ServiceRoute> routes,
  required List<Device> devices,
}) {
  final deviceMap = {for (final device in devices) device.id: device};
  final serviceMap = {for (final service in services) service.id: service};
  final nodes = <String, ServiceTopologyNode>{};
  final edges = <String, ServiceTopologyEdge>{};

  /// Purpose: Add node through the current flow.
  /// Inputs: `node`.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  void addNode(ServiceTopologyNode node, {String? routeId}) {
    nodes.update(
      node.id,
      (existing) => existing.merge(node, routeId: routeId),
      ifAbsent: () => routeId == null ? node : node.mergeRoute(routeId),
    );
  }

  /// Purpose: Add an edge between two existing nodes, or record another route
  /// on the edge already there.
  /// Inputs: `from`, `to` — node ids; `label`; `routeId` — the route adding the
  /// edge, null for a structural edge.
  /// Returns: None.
  /// Side effects: Adds to or replaces an entry of the local `edges` map.
  /// Notes: Edges are keyed by endpoints, label, lane and method, so routes that
  /// share all four share one edge; a later route is appended to its `routeIds`
  /// in place, which keeps the edge order — and so the layout — unchanged. A
  /// self-loop or an unknown node is ignored.
  void addEdge(String from, String to, {String? label, String? routeId}) {
    if (from == to || !nodes.containsKey(from) || !nodes.containsKey(to)) {
      return;
    }
    final route = routeId == null
        ? null
        : routes.where((r) => r.id == routeId).firstOrNull;
    final lane = route == null ? null : serviceAccessLaneForRoute(route);
    final method = route?.hops
        .map((hop) => hop.method)
        .whereType<ServiceRouteMethod>()
        .firstOrNull;
    final key =
        '$from->$to:${label ?? ''}:${lane?.name ?? ''}:${method?.name ?? ''}';
    final existing = edges[key];
    if (existing != null) {
      if (routeId != null) edges[key] = existing.withRoute(routeId);
      return;
    }
    edges[key] = ServiceTopologyEdge(
      from: from,
      to: to,
      label: label,
      routeId: routeId,
      lane: lane,
      method: method,
      routeIds: routeId == null ? const [] : [routeId],
    );
  }

  /// Purpose: Implement the device node id behavior for this file.
  /// Inputs: `deviceId`.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  String deviceNodeId(String deviceId) => 'device:$deviceId';

  /// Purpose: Implement the service node id behavior for this file.
  /// Inputs: `serviceId`.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  String serviceNodeId(String serviceId) => 'service:$serviceId';

  /// Purpose: Implement the endpoint node id behavior for this file.
  /// Inputs: `serviceId`, `endpointId`.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  String endpointNodeId(String serviceId, String endpointId) =>
      'endpoint:$serviceId:$endpointId';

  /// Purpose: Add device node through the current flow.
  /// Inputs: `deviceId`.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  String addDeviceNode(String deviceId) {
    final device = deviceMap[deviceId];
    final id = deviceNodeId(deviceId);
    addNode(
      ServiceTopologyNode(
        id: id,
        kind: ServiceTopologyNodeKind.device,
        role: ServiceTopologyNodeRole.localDevice,
        label: device?.name ?? deviceId,
        detail: device?.category.name,
        deviceId: deviceId,
      ),
    );
    return id;
  }

  /// Purpose: Add remote device node through the current flow.
  /// Inputs: `deviceId`.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  String addRemoteDeviceNode(String deviceId, {String? routeId}) {
    final device = deviceMap[deviceId];
    final id = deviceNodeId(deviceId);
    addNode(
      ServiceTopologyNode(
        id: id,
        kind: ServiceTopologyNodeKind.device,
        role: ServiceTopologyNodeRole.remoteDevice,
        label: device?.name ?? deviceId,
        detail: device?.category.name,
        deviceId: deviceId,
      ),
      routeId: routeId,
    );
    return id;
  }

  /// Purpose: Add service node through the current flow.
  /// Inputs: `service`.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  String addServiceNode(
    ServiceNode service, {
    bool remote = false,
    String? routeId,
    String? detailOverride,
  }) {
    final deviceId = remote
        ? addRemoteDeviceNode(service.deviceId, routeId: routeId)
        : addDeviceNode(service.deviceId);
    final id = serviceNodeId(service.id);
    addNode(
      ServiceTopologyNode(
        id: id,
        kind: ServiceTopologyNodeKind.service,
        role: remote
            ? ServiceTopologyNodeRole.remoteService
            : ServiceTopologyNodeRole.localService,
        label: service.name,
        detail:
            detailOverride ??
            (service.endpoints.isEmpty
                ? service.kind.name
                : service.endpoints
                      .map((endpoint) => endpoint.portText)
                      .where((text) => text != '-')
                      .take(3)
                      .join(', ')),
        deviceId: service.deviceId,
        serviceId: service.id,
      ),
      routeId: routeId,
    );
    if (remote) {
      addEdge(deviceId, id, routeId: routeId);
    } else {
      addEdge(deviceId, id);
    }
    return id;
  }

  /// Purpose: Add endpoint node through the current flow.
  /// Inputs: `service`, `endpoint`.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  String addEndpointNode(
    ServiceNode service,
    ServiceEndpoint endpoint, {
    bool remote = false,
    String? routeId,
  }) {
    final id = endpointNodeId(service.id, endpoint.id);
    addNode(
      ServiceTopologyNode(
        id: id,
        kind: ServiceTopologyNodeKind.endpoint,
        role: remote
            ? ServiceTopologyNodeRole.remoteService
            : ServiceTopologyNodeRole.localEndpoint,
        label: endpoint.label?.trim().isNotEmpty == true
            ? endpoint.label!.trim()
            : endpoint.protocol.name.toUpperCase(),
        detail: [
          if (endpoint.bindAddress?.trim().isNotEmpty == true)
            endpoint.bindAddress!.trim(),
          endpoint.portText,
          if (endpoint.path?.trim().isNotEmpty == true) endpoint.path!.trim(),
        ].where((part) => part.isNotEmpty && part != '-').join(':'),
        deviceId: service.deviceId,
        serviceId: service.id,
        endpointId: endpoint.id,
        compact: true,
      ),
      routeId: routeId,
    );
    addEdge(serviceNodeId(service.id), id, routeId: routeId);
    return id;
  }

  for (final service in services) {
    addServiceNode(service);
  }

  for (final route in routes) {
    final source = serviceMap[route.sourceServiceId];
    if (source == null) continue;
    var currentId = addServiceNode(source);
    final sourceEndpoint = _endpointForRoute(source, route.sourceEndpointId);
    if (sourceEndpoint != null) {
      final endpointId = addEndpointNode(
        source,
        sourceEndpoint,
        routeId: route.id,
      );
      addEdge(currentId, endpointId, routeId: route.id);
      currentId = endpointId;
    }

    for (final hop in route.hops) {
      if (_isPortMappingHop(hop)) {
        final hopService = hop.serviceId == null
            ? null
            : serviceMap[hop.serviceId];
        if (hopService != null) {
          final hopServiceId = addServiceNode(
            hopService,
            remote: true,
            routeId: route.id,
            detailOverride: hop.method == null
                ? hop.type.name
                : '${serviceRouteMethodLabel(hop.method!)} service',
          );
          final ingressEndpoint = _portMappingIngressEndpoint(hopService, hop);
          if (ingressEndpoint != null) {
            final ingressEndpointId = addEndpointNode(
              hopService,
              ingressEndpoint,
              remote: true,
              routeId: route.id,
            );
            addEdge(currentId, ingressEndpointId, routeId: route.id);
          } else {
            addEdge(currentId, hopServiceId, routeId: route.id);
          }
          currentId = hopServiceId;
        } else {
          final relayId = _relayNodeId(hop);
          addNode(
            ServiceTopologyNode(
              id: relayId,
              kind: ServiceTopologyNodeKind.relay,
              role: _roleForRelay(route, hop),
              label: _relayLabel(hop, serviceMap),
              detail: hop.method?.name ?? hop.type.name,
              serviceId: hop.serviceId,
              deviceId: hop.deviceId,
              lane: serviceAccessLaneForRoute(route),
              method: hop.method,
            ),
            routeId: route.id,
          );
          addEdge(currentId, relayId, routeId: route.id);
          currentId = relayId;

          if (hop.deviceId != null) {
            final remoteDeviceId = addRemoteDeviceNode(
              hop.deviceId!,
              routeId: route.id,
            );
            addEdge(currentId, remoteDeviceId, routeId: route.id);
            currentId = remoteDeviceId;
          }
        }

        if (_hasRemoteEntry(hop)) {
          final remoteId = _remoteEntryNodeId(hop);
          addNode(
            ServiceTopologyNode(
              id: remoteId,
              kind: ServiceTopologyNodeKind.remoteEntry,
              role: ServiceTopologyNodeRole.remotePublicEntry,
              label: _remoteEntryLabel(hop),
              detail: hop.scheme,
              deviceId: hop.deviceId ?? hopService?.deviceId,
              lane: serviceAccessLaneForRoute(route),
              method: hop.method,
              compact: true,
            ),
            routeId: route.id,
          );
          addEdge(currentId, remoteId, routeId: route.id);
          currentId = remoteId;
        }
        continue;
      }

      if (hop.serviceId != null && serviceMap.containsKey(hop.serviceId)) {
        final hopService = serviceMap[hop.serviceId]!;
        final hopIsRemote = _isRemoteHopService(
          source: source,
          hopService: hopService,
          deviceMap: deviceMap,
        );
        final hopServiceId = addServiceNode(
          hopService,
          remote: hopIsRemote,
          routeId: route.id,
        );
        addEdge(currentId, hopServiceId, routeId: route.id);
        currentId = hopServiceId;
        final hopEndpoint = _endpointForRoute(hopService, hop.endpointId);
        if (hopEndpoint != null) {
          final endpointId = addEndpointNode(
            hopService,
            hopEndpoint,
            remote: hopIsRemote,
            routeId: route.id,
          );
          addEdge(currentId, endpointId, routeId: route.id);
          currentId = endpointId;
        }
        continue;
      }

      final label = _relayLabel(hop, serviceMap);
      if (label.trim().isEmpty) continue;
      final relayId = _relayNodeId(hop);
      addNode(
        ServiceTopologyNode(
          id: relayId,
          kind: ServiceTopologyNodeKind.relay,
          role: _roleForRelay(route, hop),
          label: label,
          detail: hop.method?.name ?? hop.type.name,
          serviceId: hop.serviceId,
          deviceId: hop.deviceId,
          lane: serviceAccessLaneForRoute(route),
          method: hop.method,
        ),
        routeId: route.id,
      );
      addEdge(currentId, relayId, routeId: route.id);
      currentId = relayId;
    }

    for (final target in serviceRouteAccessTargets(route)) {
      final targetId = 'domain:${_canonicalAccessTarget(target)}';
      addNode(
        ServiceTopologyNode(
          id: targetId,
          kind: ServiceTopologyNodeKind.domain,
          role: ServiceTopologyNodeRole.domain,
          label: compactAccessTargetLabel(target),
          detail: target,
          lane: serviceAccessLaneForRoute(route),
        ),
        routeId: route.id,
      );
      addEdge(currentId, targetId, routeId: route.id);
    }
  }

  final sortedNodes = nodes.values.toList()
    ..sort((a, b) {
      final kindCmp = a.kind.index.compareTo(b.kind.index);
      if (kindCmp != 0) return kindCmp;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
  return ServiceTopologyGraph(nodes: sortedNodes, edges: edges.values.toList());
}

/// Purpose: Find service and route references that look broken or ambiguous.
/// Inputs: `services`, `routes`, `devices`, `networks`.
/// Returns: A list of warnings for the Services overview.
/// Side effects: None.
/// Notes: Duplicate public targets are only ambiguous across devices or overlapping source ports.
List<ServiceWarning> findServiceReferenceWarnings({
  required List<ServiceNode> services,
  required List<ServiceRoute> routes,
  required List<Device> devices,
  required List<Network> networks,
}) {
  final warnings = <ServiceWarning>[];
  final deviceMap = {for (final d in devices) d.id: d};
  final serviceMap = {for (final service in services) service.id: service};
  final networkIds = networks.map((n) => n.id).toSet();

  for (final service in services) {
    final device = deviceMap[service.deviceId];
    if (device == null) {
      warnings.add(
        ServiceWarning(ServiceWarningKind.missingDevice, service.name),
      );
    } else if (!device.isInService) {
      warnings.add(
        ServiceWarning(ServiceWarningKind.inactiveDevice, service.name),
      );
    }
    for (final endpoint in service.endpoints) {
      if (endpoint.networkId != null &&
          !networkIds.contains(endpoint.networkId)) {
        warnings.add(
          ServiceWarning(
            ServiceWarningKind.missingEndpointNetwork,
            service.name,
          ),
        );
      }
    }
  }

  final finalUrls = <String, List<ServiceRoute>>{};
  for (final route in routes) {
    final source = serviceMap[route.sourceServiceId];
    if (source == null) {
      warnings.add(
        ServiceWarning(ServiceWarningKind.missingSourceService, route.name),
      );
    } else if (route.sourceEndpointId != null &&
        !source.endpoints.any(
          (endpoint) => endpoint.id == route.sourceEndpointId,
        )) {
      warnings.add(
        ServiceWarning(ServiceWarningKind.missingSourceEndpoint, route.name),
      );
    }

    if (route.hops.isEmpty) {
      warnings.add(ServiceWarning(ServiceWarningKind.emptyRoute, route.name));
    }

    final targets = serviceRouteAccessTargets(route);
    if (route.accessLevel == ServiceAccessLevel.public && targets.isEmpty) {
      warnings.add(
        ServiceWarning(ServiceWarningKind.publicRouteMissingUrl, route.name),
      );
    }

    for (final target in targets) {
      final key = _canonicalAccessTarget(target);
      finalUrls.putIfAbsent(key, () => []).add(route);
    }

    for (final hop in route.hops) {
      if (hop.serviceId != null) {
        final hopService = services
            .where((s) => s.id == hop.serviceId)
            .firstOrNull;
        if (hopService == null) {
          warnings.add(
            ServiceWarning(ServiceWarningKind.missingHopService, route.name),
          );
        } else if (hop.endpointId != null &&
            !hopService.endpoints.any(
              (endpoint) => endpoint.id == hop.endpointId,
            )) {
          warnings.add(
            ServiceWarning(ServiceWarningKind.missingHopEndpoint, route.name),
          );
        }
      }
      if (hop.deviceId != null && !deviceMap.containsKey(hop.deviceId)) {
        warnings.add(
          ServiceWarning(ServiceWarningKind.missingHopDevice, route.name),
        );
      }
    }
  }

  for (final entry in finalUrls.entries) {
    final conflictingRoutes = _conflictingPublicTargetRoutes(
      entry.value,
      serviceMap,
    );
    if (conflictingRoutes.length > 1) {
      warnings.add(
        ServiceWarning(
          ServiceWarningKind.duplicateFinalUrl,
          entry.key,
          detail: conflictingRoutes.map((route) => route.name).join(', '),
        ),
      );
    }
  }

  return warnings;
}

String normalizedBindAddress(String? bindAddress) {
  final bind = bindAddress?.trim();
  if (bind == null || bind.isEmpty || bind == '0.0.0.0' || bind == '::') {
    return '*';
  }
  return bind;
}

bool _bindsOverlap(String a, String b) => a == '*' || b == '*' || a == b;

/// Purpose: Return only routes that make a shared public target ambiguous.
/// Inputs: `routes`, `serviceMap`.
/// Returns: Routes involved in at least one duplicate-target conflict.
/// Side effects: None.
/// Notes: Same-device routes with clearly different source ports can share a public hostname.
List<ServiceRoute> _conflictingPublicTargetRoutes(
  List<ServiceRoute> routes,
  Map<String, ServiceNode> serviceMap,
) {
  final conflicting = <ServiceRoute>{};
  for (var i = 0; i < routes.length; i++) {
    for (var j = i + 1; j < routes.length; j++) {
      if (_publicTargetRoutesConflict(routes[i], routes[j], serviceMap)) {
        conflicting.add(routes[i]);
        conflicting.add(routes[j]);
      }
    }
  }
  return [
    for (final route in routes)
      if (conflicting.contains(route)) route,
  ];
}

/// Purpose: Decide whether two routes sharing a public target should warn.
/// Inputs: `a`, `b`, `serviceMap`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Unknown source services or ports are treated conservatively as ambiguous.
bool _publicTargetRoutesConflict(
  ServiceRoute a,
  ServiceRoute b,
  Map<String, ServiceNode> serviceMap,
) {
  final aService = serviceMap[a.sourceServiceId];
  final bService = serviceMap[b.sourceServiceId];
  if (aService == null || bService == null) return true;
  if (aService.deviceId != bService.deviceId) return true;

  final aEndpoint = _sourceEndpointForDuplicateTargetCheck(aService, a);
  final bEndpoint = _sourceEndpointForDuplicateTargetCheck(bService, b);
  if (aEndpoint == null || bEndpoint == null) return true;
  return _endpointPortsOverlap(aEndpoint, bEndpoint);
}

/// Purpose: Resolve the source endpoint to use when checking duplicate public targets.
/// Inputs: `service`, `route`.
/// Returns: The selected endpoint, inferred single endpoint, or null.
/// Side effects: None.
/// Notes: A missing endpoint is ambiguous unless the service has exactly one endpoint.
ServiceEndpoint? _sourceEndpointForDuplicateTargetCheck(
  ServiceNode service,
  ServiceRoute route,
) {
  final selected = _endpointForRoute(service, route.sourceEndpointId);
  if (selected != null) return selected;
  if (route.sourceEndpointId == null && service.endpoints.length == 1) {
    return service.endpoints.single;
  }
  return null;
}

/// Purpose: Check whether two endpoint port ranges overlap.
/// Inputs: `a`, `b`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Missing ports are considered overlapping because the target cannot be disambiguated.
bool _endpointPortsOverlap(ServiceEndpoint a, ServiceEndpoint b) {
  final aStart = a.port;
  final bStart = b.port;
  if (aStart == null || bStart == null) return true;
  final aEnd = a.portEnd != null && a.portEnd! >= aStart ? a.portEnd! : aStart;
  final bEnd = b.portEnd != null && b.portEnd! >= bStart ? b.portEnd! : bStart;
  final maxStart = aStart > bStart ? aStart : bStart;
  final minEnd = aEnd < bEnd ? aEnd : bEnd;
  return maxStart <= minEnd;
}

ServiceTopologyNodeRole _preferTopologyRole(
  ServiceTopologyNodeRole current,
  ServiceTopologyNodeRole incoming,
) {
  if (current == incoming) return current;
  if (_isRemoteRole(incoming)) return incoming;
  return current;
}

bool _isRemoteRole(ServiceTopologyNodeRole role) =>
    role == ServiceTopologyNodeRole.remoteDevice ||
    role == ServiceTopologyNodeRole.remoteService ||
    role == ServiceTopologyNodeRole.remotePublicEntry ||
    role == ServiceTopologyNodeRole.domain;

bool _isRemoteHopService({
  required ServiceNode source,
  required ServiceNode hopService,
  required Map<String, Device> deviceMap,
}) {
  if (hopService.deviceId == source.deviceId) return false;
  return deviceMap[hopService.deviceId]?.category == DeviceCategory.vps;
}

/// Purpose: Classify a route into the local, VPN or public access lane.
/// Inputs: `route`.
/// Returns: `ServiceAccessLane`.
/// Side effects: None.
/// Notes: A valid `extraJson['accessLane']` (see [serviceRouteAccessLaneKey])
/// wins. Otherwise the lane is inferred exactly as before 1.5.6: a
/// public-style hop method (FRP, router port forward, Caddy, Nginx, Traefik,
/// Cloudflare Tunnel, Pangolin) means public regardless of the access level;
/// then Tailscale Funnel or a VPN access level means VPN; then a public or
/// authenticated access level means public; anything else is local.
ServiceAccessLane serviceAccessLaneForRoute(ServiceRoute route) {
  final explicit = serviceRouteExplicitAccessLane(route);
  if (explicit != null) return explicit;
  final methods = route.hops
      .map((hop) => hop.method)
      .whereType<ServiceRouteMethod>();
  if (methods.any(
    (method) =>
        method == ServiceRouteMethod.frp ||
        method == ServiceRouteMethod.routerPortForward ||
        method == ServiceRouteMethod.caddy ||
        method == ServiceRouteMethod.nginx ||
        method == ServiceRouteMethod.traefik ||
        method == ServiceRouteMethod.cloudflareTunnel ||
        method == ServiceRouteMethod.pangolin,
  )) {
    return ServiceAccessLane.public;
  }
  if (methods.any((method) => method == ServiceRouteMethod.tailscaleFunnel) ||
      route.accessLevel == ServiceAccessLevel.vpn) {
    return ServiceAccessLane.vpn;
  }
  if (route.accessLevel == ServiceAccessLevel.public ||
      route.accessLevel == ServiceAccessLevel.authenticated) {
    return ServiceAccessLane.public;
  }
  return ServiceAccessLane.local;
}

ServiceTopologyNodeRole _roleForRelay(ServiceRoute route, ServiceRouteHop hop) {
  final lane = serviceAccessLaneForRoute(route);
  if (lane == ServiceAccessLane.local) return ServiceTopologyNodeRole.lanAccess;
  if (lane == ServiceAccessLane.vpn) return ServiceTopologyNodeRole.vpnAccess;
  return ServiceTopologyNodeRole.publicRelay;
}

ServiceEndpoint? _endpointForRoute(ServiceNode service, String? endpointId) {
  if (endpointId == null) return null;
  return service.endpoints
      .where((endpoint) => endpoint.id == endpointId)
      .firstOrNull;
}

/// Purpose: Resolve the ingress endpoint a port-mapping hop connects to.
/// Inputs: `service` — the hop's relay service; `hop`.
/// Returns: The hop's explicit endpoint when it resolves, else the service's
/// default ingress, else null.
/// Side effects: None.
/// Notes: The default is [serviceDefaultIngressEndpoint], which the guided
/// access-path flow also uses, so a draft the user does not touch records the
/// same ingress this inference would pick.
ServiceEndpoint? _portMappingIngressEndpoint(
  ServiceNode service,
  ServiceRouteHop hop,
) {
  final explicit = _endpointForRoute(service, hop.endpointId);
  if (explicit != null) return explicit;
  return serviceDefaultIngressEndpoint(service);
}

/// Purpose: Pick the endpoint a relay service receives tunnelled traffic on
/// when a route does not name one.
/// Inputs: `service`.
/// Returns: The primary endpoint, else the first endpoint, else null.
/// Side effects: None.
/// Notes: Shared by the topology builder's FRP inference and the guided
/// access-path flow's ingress default.
ServiceEndpoint? serviceDefaultIngressEndpoint(ServiceNode service) =>
    service.endpoints.where((endpoint) => endpoint.isPrimary).firstOrNull ??
    service.endpoints.firstOrNull;

/// Purpose: Read a route's explicit access-lane override.
/// Inputs: `route`.
/// Returns: The lane named by `extraJson['accessLane']`, or null when the key
/// is absent or holds an unknown value.
/// Side effects: None.
/// Notes: Unknown values are ignored rather than rejected, so a newer build's
/// value cannot break an older reader.
ServiceAccessLane? serviceRouteExplicitAccessLane(ServiceRoute route) {
  final value = route.extraJson[serviceRouteAccessLaneKey];
  if (value is! String) return null;
  return ServiceAccessLane.values
      .where((lane) => lane.name == value)
      .firstOrNull;
}

/// Purpose: Write or remove the access-lane override in a route's
/// `extraJson`.
/// Inputs: `extraJson` — the route's existing map; `lane` — the lane to pin,
/// or null to return to inference.
/// Returns: A new map; the input is not modified.
/// Side effects: None.
/// Notes: Every other key, known or unknown, is carried over unchanged.
Map<String, dynamic> serviceRouteExtraJsonWithAccessLane(
  Map<String, dynamic> extraJson,
  ServiceAccessLane? lane,
) {
  final next = Map<String, dynamic>.of(extraJson)
    ..remove(serviceRouteAccessLaneKey);
  if (lane != null) next[serviceRouteAccessLaneKey] = lane.name;
  return next;
}

/// Purpose: List the routes a topology node takes part in, for selection
/// highlighting and the node details.
/// Inputs: `node`; `routes` — the routes the graph was built from;
/// `services` — optional, lets a device node find the services it hosts.
/// Returns: The matching routes, in their original order.
/// Side effects: None.
/// Notes: Every node matches the routes recorded on it (`routeIds`), which is
/// all an endpoint chip, relay, remote entry or domain needs. A service node
/// also matches the routes it is the source or a hop of. A device node also
/// matches routes whose source or hop service runs on it, or whose hop names
/// it as the device. A missing id never matches a missing reference, so a
/// node without a service does not pick up every free-form hop.
List<ServiceRoute> relatedRoutesForNode(
  ServiceTopologyNode node,
  List<ServiceRoute> routes, {
  List<ServiceNode> services = const [],
}) {
  final routeIds = node.routeIds.toSet();
  final serviceId = node.serviceId;
  final deviceId = node.deviceId;
  final hosted = <String>{
    if (node.kind == ServiceTopologyNodeKind.device && deviceId != null)
      for (final service in services)
        if (service.deviceId == deviceId) service.id,
  };

  /// Purpose: Decide whether one route belongs to the node.
  /// Inputs: `route`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Local helper of [relatedRoutesForNode].
  bool matches(ServiceRoute route) {
    if (routeIds.contains(route.id)) return true;
    switch (node.kind) {
      case ServiceTopologyNodeKind.service:
        if (serviceId == null) return false;
        return route.sourceServiceId == serviceId ||
            route.hops.any((hop) => hop.serviceId == serviceId);
      case ServiceTopologyNodeKind.device:
        if (deviceId == null) return false;
        return hosted.contains(route.sourceServiceId) ||
            route.hops.any(
              (hop) =>
                  hop.deviceId == deviceId ||
                  (hop.serviceId != null && hosted.contains(hop.serviceId)),
            );
      case ServiceTopologyNodeKind.endpoint:
      case ServiceTopologyNodeKind.relay:
      case ServiceTopologyNodeKind.remoteEntry:
      case ServiceTopologyNodeKind.domain:
        return false;
    }
  }

  return [
    for (final route in routes)
      if (matches(route)) route,
  ];
}

/// What the full-screen topology is narrowed to: some devices, some access
/// lanes, a search text. The default narrows nothing.
///
/// Compared by value, so the page can memoize the graph it builds for a
/// filter and rebuild only when the filter really changed.
class ServiceTopologyFilter {
  /// The devices whose services and routes are shown; null shows every device.
  final Set<String>? deviceIds;

  /// The access lanes whose routes are shown.
  final Set<ServiceAccessLane> lanes;

  /// Text a route or service must contain, compared case-insensitively.
  final String query;

  /// Purpose: Create a topology filter.
  /// Inputs: `deviceIds` — null for every device; `lanes` — every lane by
  /// default; `query` — empty by default.
  /// Returns: A new `ServiceTopologyFilter`.
  /// Side effects: None.
  /// Notes: An empty `deviceIds` set is kept as given; the page never makes
  /// one, since clearing the last device chip means "every device".
  const ServiceTopologyFilter({
    this.deviceIds,
    this.lanes = const {
      ServiceAccessLane.local,
      ServiceAccessLane.vpn,
      ServiceAccessLane.public,
    },
    this.query = '',
  });

  /// Purpose: Report whether the filter narrows the devices.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get narrowsDevices => deviceIds != null;

  /// Purpose: Report whether the filter leaves out a lane.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get narrowsLanes => !ServiceAccessLane.values.every(lanes.contains);

  /// Purpose: Report whether the filter has search text.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Whitespace alone does not count.
  bool get hasQuery => query.trim().isNotEmpty;

  /// Purpose: Count the filter's active parts, for the app-bar badge.
  /// Inputs: None.
  /// Returns: `int`, 0 to 3 — devices, lanes and search count once each.
  /// Side effects: None.
  /// Notes: None.
  int get activeCount =>
      (narrowsDevices ? 1 : 0) + (narrowsLanes ? 1 : 0) + (hasQuery ? 1 : 0);

  /// Purpose: Report whether the filter narrows anything.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isActive => activeCount > 0;

  /// Purpose: Create a copy with selected parts replaced.
  /// Inputs: `deviceIds`, `clearDeviceIds` — back to every device; `lanes`;
  /// `query`.
  /// Returns: `ServiceTopologyFilter`.
  /// Side effects: None.
  /// Notes: None.
  ServiceTopologyFilter copyWith({
    Set<String>? deviceIds,
    bool clearDeviceIds = false,
    Set<ServiceAccessLane>? lanes,
    String? query,
  }) => ServiceTopologyFilter(
    deviceIds: clearDeviceIds ? null : (deviceIds ?? this.deviceIds),
    lanes: lanes ?? this.lanes,
    query: query ?? this.query,
  );

  /// Purpose: Compare two filters by value.
  /// Inputs: `other`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Sets compare by content; the query compares as typed.
  @override
  bool operator ==(Object other) =>
      other is ServiceTopologyFilter &&
      _sameSet(other.deviceIds, deviceIds) &&
      _sameSet(other.lanes, lanes) &&
      other.query == query;

  /// Purpose: Hash a filter consistently with `==`.
  /// Inputs: None.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: Order-independent over both sets.
  @override
  int get hashCode => Object.hash(
    deviceIds == null ? null : Object.hashAllUnordered(deviceIds!),
    Object.hashAllUnordered(lanes),
    query,
  );
}

/// Purpose: Compare two optional sets by content.
/// Inputs: `a`, `b`.
/// Returns: `bool` — true when both are null or both hold the same elements.
/// Side effects: None.
/// Notes: Internal helper of [ServiceTopologyFilter].
bool _sameSet<T>(Set<T>? a, Set<T>? b) {
  if (a == null || b == null) return a == b;
  return a.length == b.length && a.containsAll(b);
}

/// Purpose: Narrow the services and routes a topology is built from.
/// Inputs: `services`, `routes` — the whole inventory; `filter`.
/// Returns: The services and routes to hand to [buildServiceTopology]; the
/// inputs themselves when the filter narrows nothing.
/// Side effects: None.
/// Notes: A route stays when its source service runs on a chosen device, its
/// lane is chosen, and the search text is found in its source or a hop
/// service's name, a hop's label or host, or one of its targets. A service
/// stays when a kept route runs through it — also on a device that was not
/// chosen, so an FRP server on a VPS still draws its ingress chip — or when
/// it runs on a chosen device and neither the lanes nor the search narrow
/// anything (or the search text is in its name). Lanes and search are about
/// routes, so they hide the services no kept route touches.
({List<ServiceNode> services, List<ServiceRoute> routes})
filterServiceTopologyInput({
  required List<ServiceNode> services,
  required List<ServiceRoute> routes,
  required ServiceTopologyFilter filter,
}) {
  if (!filter.isActive) return (services: services, routes: routes);
  final byId = {for (final service in services) service.id: service};
  final query = filter.query.trim().toLowerCase();
  final deviceIds = filter.deviceIds;

  /// Purpose: Report whether a service runs on a chosen device.
  /// Inputs: `service`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Local helper of [filterServiceTopologyInput].
  bool onChosenDevice(ServiceNode? service) =>
      deviceIds == null ||
      (service != null && deviceIds.contains(service.deviceId));

  /// Purpose: Report whether a text contains the search text.
  /// Inputs: `text`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Local helper of [filterServiceTopologyInput].
  bool hit(String? text) => text != null && text.toLowerCase().contains(query);

  /// Purpose: Report whether a route matches the search text.
  /// Inputs: `route`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Local helper of [filterServiceTopologyInput].
  bool routeMatches(ServiceRoute route) {
    if (query.isEmpty) return true;
    if (hit(byId[route.sourceServiceId]?.name)) return true;
    for (final hop in route.hops) {
      if (hit(byId[hop.serviceId]?.name) || hit(hop.label) || hit(hop.host)) {
        return true;
      }
    }
    return serviceRouteAccessTargets(route).any(hit);
  }

  final keptRoutes = [
    for (final route in routes)
      if (onChosenDevice(byId[route.sourceServiceId]) &&
          filter.lanes.contains(serviceAccessLaneForRoute(route)) &&
          routeMatches(route))
        route,
  ];
  final routeServiceIds = <String>{
    for (final route in keptRoutes) ...[
      route.sourceServiceId,
      for (final hop in route.hops)
        if (hop.serviceId != null) hop.serviceId!,
    ],
  };
  final narrowsRoutes = filter.narrowsLanes || filter.hasQuery;
  final keptServices = [
    for (final service in services)
      if (routeServiceIds.contains(service.id) ||
          (onChosenDevice(service) &&
              (!narrowsRoutes || (filter.hasQuery && hit(service.name)))))
        service,
  ];
  return (services: keptServices, routes: keptRoutes);
}

/// The nodes and edges a selection lights up on the topology.
class ServiceTopologyHighlight {
  /// Ids of the nodes that stay fully opaque.
  final Set<String> nodeIds;

  /// The edges drawn emphasized.
  final Set<ServiceTopologyEdge> edges;

  /// Purpose: Create a highlight.
  /// Inputs: `nodeIds`, `edges`.
  /// Returns: A new `ServiceTopologyHighlight`.
  /// Side effects: None.
  /// Notes: Edges are the graph's own instances, compared by identity.
  const ServiceTopologyHighlight({required this.nodeIds, required this.edges});
}

/// Purpose: Work out which nodes and edges a set of routes lights up.
/// Inputs: `graph`; `routes` — the highlighted routes, e.g. from
/// [relatedRoutesForNode]; `selectedNodeId` — the selected node, lit even
/// when it takes part in none of them.
/// Returns: `ServiceTopologyHighlight`.
/// Side effects: None.
/// Notes: A node is lit when one of its `routeIds` is highlighted, and a
/// service node also when it is a highlighted route's source or hop service
/// — the builder does not record routes on the source service node. A device
/// node is lit when it hosts a lit service, endpoint, relay or entry, so a
/// route's own machine never fades behind it. An edge is lit when one of its
/// `routeIds` is highlighted, and a structural edge (no routes) when both its
/// ends are lit.
ServiceTopologyHighlight serviceTopologyHighlight(
  ServiceTopologyGraph graph,
  List<ServiceRoute> routes, {
  String? selectedNodeId,
}) {
  final routeIds = {for (final route in routes) route.id};
  final serviceIds = <String>{
    for (final route in routes) ...[
      route.sourceServiceId,
      for (final hop in route.hops)
        if (hop.serviceId != null) hop.serviceId!,
    ],
  };
  final nodeIds = <String>{
    for (final node in graph.nodes)
      if (node.id == selectedNodeId ||
          node.routeIds.any(routeIds.contains) ||
          (node.kind == ServiceTopologyNodeKind.service &&
              serviceIds.contains(node.serviceId)))
        node.id,
  };
  final hostDeviceIds = <String>{
    for (final node in graph.nodes)
      if (node.kind != ServiceTopologyNodeKind.device &&
          node.deviceId != null &&
          nodeIds.contains(node.id))
        node.deviceId!,
  };
  for (final node in graph.nodes) {
    if (node.kind == ServiceTopologyNodeKind.device &&
        hostDeviceIds.contains(node.deviceId)) {
      nodeIds.add(node.id);
    }
  }
  final edges = <ServiceTopologyEdge>{
    for (final edge in graph.edges)
      if (edge.routeIds.any(routeIds.contains) ||
          (edge.routeIds.isEmpty &&
              nodeIds.contains(edge.from) &&
              nodeIds.contains(edge.to)))
        edge,
  };
  return ServiceTopologyHighlight(nodeIds: nodeIds, edges: edges);
}

bool _isPortMappingHop(ServiceRouteHop hop) =>
    hop.method == ServiceRouteMethod.frp ||
    hop.method == ServiceRouteMethod.routerPortForward ||
    hop.type == ServiceRouteHopType.portForward;

bool _hasRemoteEntry(ServiceRouteHop hop) =>
    hop.host?.trim().isNotEmpty == true || hop.port != null;

String _relayNodeId(ServiceRouteHop hop) {
  final method = hop.method?.name ?? hop.type.name;
  final service = hop.serviceId ?? '';
  final label = hop.label?.trim().toLowerCase() ?? '';
  final host = hop.host?.trim().toLowerCase() ?? '';
  return 'relay:$method:$service:$label:$host';
}

String _remoteEntryNodeId(ServiceRouteHop hop) {
  final device = hop.deviceId ?? hop.serviceId ?? '';
  final host = hop.host?.trim().toLowerCase() ?? '';
  final port = hop.port?.toString() ?? '';
  return 'remote:$device:$host:$port';
}

String _relayLabel(ServiceRouteHop hop, Map<String, ServiceNode> services) {
  final service = hop.serviceId == null ? null : services[hop.serviceId];
  if (service != null) return service.name;
  if (hop.label?.trim().isNotEmpty == true) return hop.label!.trim();
  if (hop.method != null) return serviceRouteMethodLabel(hop.method!);
  return switch (hop.type) {
    ServiceRouteHopType.reverseProxy => 'Reverse Proxy',
    ServiceRouteHopType.tunnel => 'Tunnel',
    ServiceRouteHopType.portForward => 'Port Forward',
    ServiceRouteHopType.publicEndpoint => 'Public Endpoint',
    ServiceRouteHopType.internalEndpoint => 'Internal Endpoint',
    ServiceRouteHopType.dns => 'DNS',
    ServiceRouteHopType.origin => 'Origin',
    ServiceRouteHopType.manual =>
      hop.host?.trim().isNotEmpty == true ? _remoteEntryLabel(hop) : 'Manual',
  };
}

String _remoteEntryLabel(ServiceRouteHop hop) {
  final host = hop.host?.trim();
  final port = hop.port;
  if (host != null && host.isNotEmpty && port != null) return '$host:$port';
  if (host != null && host.isNotEmpty) return host;
  if (port != null) return ':$port';
  return 'Remote entry';
}

String serviceRouteMethodLabel(ServiceRouteMethod method) => switch (method) {
  ServiceRouteMethod.caddy => 'Caddy',
  ServiceRouteMethod.nginx => 'Nginx',
  ServiceRouteMethod.traefik => 'Traefik',
  ServiceRouteMethod.frp => 'FRP',
  ServiceRouteMethod.cloudflareTunnel => 'Cloudflare Tunnel',
  ServiceRouteMethod.pangolin => 'Pangolin',
  ServiceRouteMethod.tailscaleFunnel => 'Tailscale Funnel',
  ServiceRouteMethod.routerPortForward => 'Router Port Forward',
  ServiceRouteMethod.direct => 'Direct',
  ServiceRouteMethod.custom => 'Custom',
};

List<String> serviceRouteAccessTargets(ServiceRoute route) {
  final targets = <String>[];

  /// Purpose: Add target through the current flow.
  /// Inputs: `value`.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  void addTarget(Object? value) {
    if (value is! String) return;
    final target = value.trim();
    if (target.isEmpty) return;
    final key = _canonicalAccessTarget(target);
    if (targets.any((existing) => _canonicalAccessTarget(existing) == key)) {
      return;
    }
    targets.add(target);
  }

  /// Purpose: Add target through the current flow.
  /// Inputs: `finalUrl`.
  /// Returns: `dynamic`.
  /// Side effects: Implementation-dependent.
  /// Notes: Implementations should preserve this contract.
  addTarget(route.finalUrl);
  final extraTargets = route.extraJson[serviceRoutePublicTargetsKey];
  if (extraTargets is Iterable) {
    for (final target in extraTargets) {
      addTarget(target);
    }
  } else {
    addTarget(extraTargets);
  }
  return targets;
}

Map<String, dynamic> serviceRouteExtraJsonWithTargets(
  Map<String, dynamic> extraJson,
  List<String> targets,
) {
  final next = Map<String, dynamic>.of(extraJson)
    ..remove(serviceRoutePublicTargetsKey);
  if (targets.length > 1) {
    next[serviceRoutePublicTargetsKey] = targets;
  }
  return next;
}

String serviceRouteDisplayTarget(ServiceRoute route) {
  final targets = serviceRouteAccessTargets(route);
  if (targets.isEmpty) return route.name;
  if (targets.length == 1) return targets.single;
  return '${targets.first} +${targets.length - 1}';
}

String serviceRouteGeneratedName({
  required String sourceName,
  required List<ServiceRouteHop> hops,
  required List<String> targets,
}) {
  final method = hops
      .map((hop) => hop.method)
      .whereType<ServiceRouteMethod>()
      .firstOrNull;
  final hop = hops.firstOrNull;
  final via = method == null
      ? (hop?.label?.trim().isNotEmpty == true
            ? hop!.label!.trim()
            : hop?.type.name ?? 'Access')
      : serviceRouteMethodLabel(method);
  final target = targets.isNotEmpty
      ? _targetsSummary(targets, maxItems: 1)
      : (hop != null && _hasRemoteEntry(hop) ? _remoteEntryLabel(hop) : null);
  return [
    sourceName.trim().isEmpty ? 'Service' : sourceName.trim(),
    'via $via',
    if (target != null && target.trim().isNotEmpty) '- $target',
  ].join(' ');
}

/// Purpose: Describe a route's whole chain on one line, for previews.
/// Inputs: `route`; `services`; `devices` — optional, names the device of a
/// hop service that runs somewhere other than the source; `hopFallback` —
/// labels a hop that has neither a service nor a label of its own.
/// Returns: The steps joined with ` -> `, or `-` when there are none.
/// Side effects: None.
/// Notes: Steps are the source (with its endpoint's port), each hop (a
/// service with its endpoint's port — for a port mapping, the ingress the
/// topology would pick — else the hop's label, else `hopFallback`), each
/// port mapping's public host and port, then the access targets. A label
/// equal to the hop method's generated English label counts as no label, so
/// a caller can localize it through `hopFallback`; without one the method
/// label, else the raw type name, is used. Shared by the guided access-path
/// page and the advanced route editor.
String serviceRouteChainPreview(
  ServiceRoute route, {
  required List<ServiceNode> services,
  List<Device> devices = const [],
  String Function(ServiceRouteHop hop)? hopFallback,
}) {
  final serviceMap = {for (final service in services) service.id: service};
  final deviceMap = {for (final device in devices) device.id: device};
  final source = serviceMap[route.sourceServiceId];

  /// Purpose: Append an endpoint's port to a name.
  /// Inputs: `name`, `endpoint`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Local helper of [serviceRouteChainPreview].
  String withPort(String name, ServiceEndpoint? endpoint) =>
      endpoint?.port == null ? name : '$name ${endpoint!.portText}';

  final parts = <String>[
    if (source != null)
      withPort(source.name, _endpointForRoute(source, route.sourceEndpointId)),
  ];
  for (final hop in route.hops) {
    final service = hop.serviceId == null ? null : serviceMap[hop.serviceId];
    final label = hop.label?.trim() ?? '';
    final generatedLabel =
        hop.method != null && label == serviceRouteMethodLabel(hop.method!);
    if (service != null) {
      final endpoint = _isPortMappingHop(hop)
          ? _portMappingIngressEndpoint(service, hop)
          : _endpointForRoute(service, hop.endpointId);
      var text = withPort(service.name, endpoint);
      final device = deviceMap[service.deviceId];
      if (device != null && service.deviceId != source?.deviceId) {
        text = '$text (${device.name})';
      }
      parts.add(text);
    } else if (label.isNotEmpty && !generatedLabel) {
      parts.add(label);
    } else if (!_hasRemoteEntry(hop) || generatedLabel) {
      parts.add(
        hopFallback?.call(hop) ??
            (hop.method != null
                ? serviceRouteMethodLabel(hop.method!)
                : hop.type.name),
      );
    }
    if (_hasRemoteEntry(hop)) parts.add(_remoteEntryLabel(hop));
  }
  parts.addAll(serviceRouteAccessTargets(route).map(compactAccessTargetLabel));
  return parts.isEmpty ? '-' : parts.join(' -> ');
}

String serviceRouteTargetsSummary(ServiceRoute route, {int maxItems = 3}) {
  final targets = serviceRouteAccessTargets(route);
  return _targetsSummary(targets, maxItems: maxItems);
}

String _targetsSummary(List<String> targets, {int maxItems = 3}) {
  final labels = targets.map(compactAccessTargetLabel).toList();
  if (labels.isEmpty) return '';
  final visible = labels.take(maxItems).join(', ');
  final remaining = labels.length - maxItems;
  return remaining > 0 ? '$visible +$remaining' : visible;
}

String compactAccessTargetLabel(String target) {
  final trimmed = target.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    final port = uri.hasPort ? ':${uri.port}' : '';
    final path = uri.path.isNotEmpty && uri.path != '/' ? uri.path : '';
    return '${uri.host}$port$path';
  }
  return trimmed;
}

String _canonicalAccessTarget(String target) =>
    compactAccessTargetLabel(target).trim().toLowerCase();
