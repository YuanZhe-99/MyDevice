import '../../devices/models/device.dart';
import '../../network/models/network.dart';
import '../models/service.dart';

const serviceRoutePublicTargetsKey = 'publicTargets';

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
  final List<String> routeIds;

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
    this.routeIds = const [],
  });

  ServiceTopologyNode mergeRoute(String routeId) {
    if (routeIds.contains(routeId)) return this;
    return merge(this, routeId: routeId);
  }

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

  const ServiceTopologyEdge({
    required this.from,
    required this.to,
    this.label,
    this.routeId,
    this.lane,
    this.method,
  });
}

class ServiceTopologyGraph {
  final List<ServiceTopologyNode> nodes;
  final List<ServiceTopologyEdge> edges;

  const ServiceTopologyGraph({required this.nodes, required this.edges});

  bool get isEmpty => nodes.isEmpty;
}

class ServicePortUse {
  final ServiceNode service;
  final ServiceEndpoint endpoint;
  final ServiceTransport transport;
  final int port;
  final String bindAddress;

  const ServicePortUse({
    required this.service,
    required this.endpoint,
    required this.transport,
    required this.port,
    required this.bindAddress,
  });

  bool get usesAnyAddress => bindAddress == '*';
}

class ServicePortConflict {
  final String deviceId;
  final int port;
  final ServiceTransport transport;
  final List<ServicePortUse> uses;
  final bool potential;

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

ServiceTopologyGraph buildServiceTopology({
  required List<ServiceNode> services,
  required List<ServiceRoute> routes,
  required List<Device> devices,
}) {
  final deviceMap = {for (final device in devices) device.id: device};
  final serviceMap = {for (final service in services) service.id: service};
  final nodes = <String, ServiceTopologyNode>{};
  final edges = <String, ServiceTopologyEdge>{};

  void addNode(ServiceTopologyNode node, {String? routeId}) {
    nodes.update(
      node.id,
      (existing) => existing.merge(node, routeId: routeId),
      ifAbsent: () => routeId == null ? node : node.mergeRoute(routeId),
    );
  }

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
    edges.putIfAbsent(
      key,
      () => ServiceTopologyEdge(
        from: from,
        to: to,
        label: label,
        routeId: routeId,
        lane: lane,
        method: method,
      ),
    );
  }

  String deviceNodeId(String deviceId) => 'device:$deviceId';
  String serviceNodeId(String serviceId) => 'service:$serviceId';
  String endpointNodeId(String serviceId, String endpointId) =>
      'endpoint:$serviceId:$endpointId';

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
          final hopDeviceId = addRemoteDeviceNode(
            hopService.deviceId,
            routeId: route.id,
          );
          final hopServiceId = addServiceNode(
            hopService,
            remote: true,
            routeId: route.id,
            detailOverride: hop.method == null
                ? hop.type.name
                : '${serviceRouteMethodLabel(hop.method!)} service',
          );
          addEdge(currentId, hopDeviceId, routeId: route.id);
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

List<ServiceWarning> findServiceReferenceWarnings({
  required List<ServiceNode> services,
  required List<ServiceRoute> routes,
  required List<Device> devices,
  required List<Network> networks,
}) {
  final warnings = <ServiceWarning>[];
  final deviceMap = {for (final d in devices) d.id: d};
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
    final source = services
        .where((s) => s.id == route.sourceServiceId)
        .firstOrNull;
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
    if (entry.value.length > 1) {
      warnings.add(
        ServiceWarning(
          ServiceWarningKind.duplicateFinalUrl,
          entry.key,
          detail: entry.value.map((route) => route.name).join(', '),
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

ServiceAccessLane serviceAccessLaneForRoute(ServiceRoute route) {
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
