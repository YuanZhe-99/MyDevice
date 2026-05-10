import '../../devices/models/device.dart';
import '../../network/models/network.dart';
import '../models/service.dart';

enum ServiceTopologyNodeKind {
  device,
  service,
  endpoint,
  relay,
  remoteEntry,
  domain,
}

class ServiceTopologyNode {
  final String id;
  final ServiceTopologyNodeKind kind;
  final String label;
  final String? detail;
  final String? deviceId;
  final String? serviceId;

  const ServiceTopologyNode({
    required this.id,
    required this.kind,
    required this.label,
    this.detail,
    this.deviceId,
    this.serviceId,
  });
}

class ServiceTopologyEdge {
  final String from;
  final String to;
  final String? label;
  final String? routeId;

  const ServiceTopologyEdge({
    required this.from,
    required this.to,
    this.label,
    this.routeId,
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

  void addNode(ServiceTopologyNode node) {
    nodes.putIfAbsent(node.id, () => node);
  }

  void addEdge(String from, String to, {String? label, String? routeId}) {
    if (from == to || !nodes.containsKey(from) || !nodes.containsKey(to)) {
      return;
    }
    final key = '$from->$to:${label ?? ''}';
    edges.putIfAbsent(
      key,
      () => ServiceTopologyEdge(
        from: from,
        to: to,
        label: label,
        routeId: routeId,
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
        label: device?.name ?? deviceId,
        detail: device?.category.name,
        deviceId: deviceId,
      ),
    );
    return id;
  }

  String addServiceNode(ServiceNode service) {
    final deviceId = addDeviceNode(service.deviceId);
    final id = serviceNodeId(service.id);
    addNode(
      ServiceTopologyNode(
        id: id,
        kind: ServiceTopologyNodeKind.service,
        label: service.name,
        detail: service.endpoints.isEmpty
            ? service.kind.name
            : service.endpoints
                  .map((endpoint) => endpoint.portText)
                  .where((text) => text != '-')
                  .take(3)
                  .join(', '),
        deviceId: service.deviceId,
        serviceId: service.id,
      ),
    );
    addEdge(deviceId, id);
    return id;
  }

  String addEndpointNode(ServiceNode service, ServiceEndpoint endpoint) {
    final id = endpointNodeId(service.id, endpoint.id);
    addNode(
      ServiceTopologyNode(
        id: id,
        kind: ServiceTopologyNodeKind.endpoint,
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
      ),
    );
    addEdge(serviceNodeId(service.id), id);
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
      final endpointId = addEndpointNode(source, sourceEndpoint);
      addEdge(currentId, endpointId, routeId: route.id);
      currentId = endpointId;
    }

    for (final hop in route.hops) {
      if (_isPortMappingHop(hop)) {
        final relayId = _relayNodeId(hop);
        addNode(
          ServiceTopologyNode(
            id: relayId,
            kind: ServiceTopologyNodeKind.relay,
            label: _relayLabel(hop, serviceMap),
            detail: hop.method?.name ?? hop.type.name,
            serviceId: hop.serviceId,
            deviceId: hop.deviceId,
          ),
        );
        addEdge(currentId, relayId, routeId: route.id);
        currentId = relayId;

        if (hop.deviceId != null) {
          final remoteDeviceId = addDeviceNode(hop.deviceId!);
          addEdge(currentId, remoteDeviceId, routeId: route.id);
          currentId = remoteDeviceId;
        }

        if (_hasRemoteEntry(hop)) {
          final remoteId = _remoteEntryNodeId(hop);
          addNode(
            ServiceTopologyNode(
              id: remoteId,
              kind: ServiceTopologyNodeKind.remoteEntry,
              label: _remoteEntryLabel(hop),
              detail: hop.scheme,
              deviceId: hop.deviceId,
            ),
          );
          addEdge(currentId, remoteId, routeId: route.id);
          currentId = remoteId;
        }
        continue;
      }

      if (hop.serviceId != null && serviceMap.containsKey(hop.serviceId)) {
        final hopService = serviceMap[hop.serviceId]!;
        final hopServiceId = addServiceNode(hopService);
        addEdge(currentId, hopServiceId, routeId: route.id);
        currentId = hopServiceId;
        final hopEndpoint = _endpointForRoute(hopService, hop.endpointId);
        if (hopEndpoint != null) {
          final endpointId = addEndpointNode(hopService, hopEndpoint);
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
          label: label,
          detail: hop.method?.name ?? hop.type.name,
          serviceId: hop.serviceId,
          deviceId: hop.deviceId,
        ),
      );
      addEdge(currentId, relayId, routeId: route.id);
      currentId = relayId;
    }

    final target = route.finalUrl?.trim();
    if (target != null && target.isNotEmpty) {
      final targetId = 'domain:${_canonicalAccessTarget(target)}';
      addNode(
        ServiceTopologyNode(
          id: targetId,
          kind: ServiceTopologyNodeKind.domain,
          label: compactAccessTargetLabel(target),
          detail: target,
        ),
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

    if (route.accessLevel == ServiceAccessLevel.public &&
        (route.finalUrl == null || route.finalUrl!.trim().isEmpty)) {
      warnings.add(
        ServiceWarning(ServiceWarningKind.publicRouteMissingUrl, route.name),
      );
    }

    final finalUrl = route.finalUrl?.trim().toLowerCase();
    if (finalUrl != null && finalUrl.isNotEmpty) {
      finalUrls.putIfAbsent(finalUrl, () => []).add(route);
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
  final device = hop.deviceId ?? '';
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
