import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/services/service_analysis.dart';
import 'package:my_device/features/services/services/service_topology_layout.dart';

void main() {
  test('topology layout renders port nodes as square chips', () {
    final graph = _buildSampleGraph();
    final layout = ServiceTopologyLayout.build(graph.graph, graph.routes, 480);

    final endpointRect = layout.nodeRects['endpoint:jellyfin:web']!;
    final remoteEntryRect = layout.nodeRects.entries
        .singleWhere((entry) => entry.key.startsWith('remote:'))
        .value;

    expect(endpointRect.width, ServiceTopologyLayout.portChipSize);
    expect(endpointRect.height, ServiceTopologyLayout.portChipSize);
    expect(remoteEntryRect.width, ServiceTopologyLayout.portChipSize);
    expect(remoteEntryRect.height, ServiceTopologyLayout.portChipSize);
  });

  test(
    'topology layout compresses ranks instead of using fixed role columns',
    () {
      final graph = _buildSampleGraph();
      final layout = ServiceTopologyLayout.build(
        graph.graph,
        graph.routes,
        480,
      );
      final ranks = layout.nodeRanks.values.toSet().toList()..sort();

      expect(ranks, List.generate(ranks.length, (index) => index));
      expect(ranks.length, lessThan(9));
      expect(layout.nodeRanks['domain:jellyfin.example.com'], lessThan(8));
    },
  );

  test('topology router keeps edge paths out of unrelated node rectangles', () {
    final graph = _buildSampleGraph();
    final layout = ServiceTopologyLayout.build(graph.graph, graph.routes, 480);

    for (final edge in graph.graph.edges) {
      final path = layout.edgePaths[edge];
      expect(path, isNotNull, reason: '${edge.from} -> ${edge.to}');
      for (var i = 1; i < path!.length; i++) {
        expect(
          _isOrthogonal(path[i - 1], path[i]),
          isTrue,
          reason: '${edge.from} -> ${edge.to}',
        );
      }

      for (final entry in layout.nodeRects.entries) {
        if (entry.key == edge.from || entry.key == edge.to) continue;
        expect(
          _polylineIntersectsRect(path, entry.value.inflate(0.5)),
          isFalse,
          reason: '${edge.from} -> ${edge.to} crosses ${entry.key}',
        );
      }
    }
  });
}

_SampleGraph _buildSampleGraph() {
  final devices = [
    Device(id: 'mac-mini', name: 'Mac mini', category: DeviceCategory.desktop),
  ];
  final jellyfin = ServiceNode(
    id: 'jellyfin',
    deviceId: 'mac-mini',
    name: 'Jellyfin',
    endpoints: [ServiceEndpoint(id: 'web', port: 8096)],
  );
  final vaultwarden = ServiceNode(
    id: 'vaultwarden',
    deviceId: 'mac-mini',
    name: 'Vaultwarden',
    endpoints: [ServiceEndpoint(id: 'web', port: 59880)],
  );
  final caddy = ServiceNode(
    id: 'caddy',
    deviceId: 'mac-mini',
    name: 'Caddy',
    kind: ServiceKind.reverseProxy,
    endpoints: [ServiceEndpoint(id: 'https', port: 443)],
  );
  final routes = [
    ServiceRoute(
      id: 'jellyfin-public',
      name: 'Jellyfin via Caddy',
      sourceServiceId: jellyfin.id,
      sourceEndpointId: 'web',
      accessLevel: ServiceAccessLevel.public,
      hops: [
        ServiceRouteHop(
          type: ServiceRouteHopType.reverseProxy,
          method: ServiceRouteMethod.caddy,
          serviceId: caddy.id,
          endpointId: 'https',
        ),
      ],
      finalUrl: 'https://jellyfin.example.com',
    ),
    ServiceRoute(
      id: 'vaultwarden-public',
      name: 'Vaultwarden via Caddy',
      sourceServiceId: vaultwarden.id,
      sourceEndpointId: 'web',
      accessLevel: ServiceAccessLevel.public,
      hops: [
        ServiceRouteHop(
          type: ServiceRouteHopType.reverseProxy,
          method: ServiceRouteMethod.caddy,
          serviceId: caddy.id,
          endpointId: 'https',
        ),
      ],
      finalUrl: 'https://vault.example.com',
    ),
    ServiceRoute(
      id: 'caddy-frp',
      name: 'Caddy FRP',
      sourceServiceId: caddy.id,
      sourceEndpointId: 'https',
      accessLevel: ServiceAccessLevel.public,
      hops: [
        ServiceRouteHop(
          type: ServiceRouteHopType.portForward,
          method: ServiceRouteMethod.frp,
          host: '203.0.113.10',
          port: 443,
        ),
      ],
      finalUrl: 'https://cloud.example.com',
    ),
  ];
  final graph = buildServiceTopology(
    services: [jellyfin, vaultwarden, caddy],
    routes: routes,
    devices: devices,
  );
  return _SampleGraph(graph, routes);
}

bool _isOrthogonal(Offset a, Offset b) =>
    (a.dx - b.dx).abs() < 0.01 || (a.dy - b.dy).abs() < 0.01;

bool _polylineIntersectsRect(List<Offset> path, Rect rect) {
  for (var i = 1; i < path.length; i++) {
    if (_segmentIntersectsRect(path[i - 1], path[i], rect)) return true;
  }
  return false;
}

bool _segmentIntersectsRect(Offset a, Offset b, Rect rect) {
  final bounds = Rect.fromLTRB(
    math.min(a.dx, b.dx),
    math.min(a.dy, b.dy),
    math.max(a.dx, b.dx),
    math.max(a.dy, b.dy),
  ).inflate(0.01);
  if (!bounds.overlaps(rect)) return false;
  if ((a.dy - b.dy).abs() < 0.01) {
    return a.dy > rect.top &&
        a.dy < rect.bottom &&
        _rangesOverlap(a.dx, b.dx, rect.left, rect.right);
  }
  if ((a.dx - b.dx).abs() < 0.01) {
    return a.dx > rect.left &&
        a.dx < rect.right &&
        _rangesOverlap(a.dy, b.dy, rect.top, rect.bottom);
  }
  return true;
}

bool _rangesOverlap(double a1, double a2, double b1, double b2) {
  final aMin = math.min(a1, a2);
  final aMax = math.max(a1, a2);
  final bMin = math.min(b1, b2);
  final bMax = math.max(b1, b2);
  return math.max(aMin, bMin) < math.min(aMax, bMax);
}

class _SampleGraph {
  final ServiceTopologyGraph graph;
  final List<ServiceRoute> routes;

  const _SampleGraph(this.graph, this.routes);
}
