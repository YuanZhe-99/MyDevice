import '../../devices/models/device.dart';
import '../../network/models/network.dart';
import '../models/service.dart';

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
