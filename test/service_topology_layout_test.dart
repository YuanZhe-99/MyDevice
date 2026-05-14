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
          _horizontal(path[i - 1], path[i]) || _vertical(path[i - 1], path[i]),
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

  test('FRP topology keeps ingress and public ports as sibling FRP ports', () {
    final data = _frpTopologyData();
    final graph = buildServiceTopology(
      services: data.services,
      routes: data.routes,
      devices: data.devices,
    );

    expect(_node(graph, 'endpoint:frp:frp57000').detail, contains('57000'));
    expect(_node(graph, 'remote:cloud::443').label, ':443');
    expect(_hasEdge(graph, 'service:frp', 'endpoint:frp:frp57000'), isTrue);
    expect(
      _hasEdge(graph, 'endpoint:caddy:caddy443', 'endpoint:frp:frp57000'),
      isTrue,
    );
    expect(_hasEdge(graph, 'service:frp', 'remote:cloud::443'), isTrue);
    expect(_hasEdge(graph, 'remote:cloud::443', 'domain:example.com'), isTrue);
    expect(
      _hasEdge(graph, 'endpoint:frp:frp57000', 'remote:cloud::443'),
      isFalse,
    );
  });

  test('topology routing avoids nodes and enters cards perpendicularly', () {
    final data = _frpTopologyData();
    final graph = buildServiceTopology(
      services: data.services,
      routes: data.routes,
      devices: data.devices,
    );
    final layout = ServiceTopologyLayout.build(graph, data.routes, 900);

    for (final edge in graph.edges) {
      final points = layout.edgePaths[edge];
      expect(points, isNotNull, reason: '${edge.from} -> ${edge.to}');
      expect(
        points!.length,
        greaterThanOrEqualTo(2),
        reason: '${edge.from} -> ${edge.to}',
      );

      final from = layout.nodeRects[edge.from]!;
      final to = layout.nodeRects[edge.to]!;
      expect(_onHorizontalSide(points.first, from), isTrue);
      expect(_onHorizontalSide(points.last, to), isTrue);
      expect(_horizontal(points.first, points[1]), isTrue);
      expect(_horizontal(points[points.length - 2], points.last), isTrue);

      for (var i = 1; i < points.length; i++) {
        final a = points[i - 1];
        final b = points[i];
        expect(
          _horizontal(a, b) || _vertical(a, b),
          isTrue,
          reason: '${edge.from} -> ${edge.to}: $a -> $b',
        );
        for (final entry in layout.nodeRects.entries) {
          if (entry.key == edge.from || entry.key == edge.to) continue;
          expect(
            _segmentCrossesRectInterior(a, b, entry.value),
            isFalse,
            reason: '${edge.from} -> ${edge.to} crosses ${entry.key}: $a -> $b',
          );
        }
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

_FrpTopologyData _frpTopologyData() {
  final devices = [
    Device(id: 'mac', name: 'Mac mini', category: DeviceCategory.desktop),
    Device(id: 'cloud', name: 'Cloudcone VPS', category: DeviceCategory.vps),
  ];
  final services = [
    ServiceNode(
      id: 'caddy',
      deviceId: 'mac',
      name: 'Caddy',
      kind: ServiceKind.reverseProxy,
      endpoints: [
        ServiceEndpoint(
          id: 'caddy443',
          label: 'HTTPS',
          protocol: ServiceProtocol.https,
          port: 443,
          isPrimary: true,
        ),
      ],
    ),
    ServiceNode(
      id: 'frp',
      deviceId: 'cloud',
      name: 'FRP',
      kind: ServiceKind.tunnel,
      endpoints: [
        ServiceEndpoint(
          id: 'frp57000',
          label: 'Default',
          protocol: ServiceProtocol.http,
          transport: ServiceTransport.tcpUdp,
          port: 57000,
          scope: ServiceScope.public,
          isPrimary: true,
        ),
      ],
    ),
  ];
  final routes = [
    ServiceRoute(
      id: 'route',
      name: 'FRP public route',
      sourceServiceId: 'caddy',
      sourceEndpointId: 'caddy443',
      accessLevel: ServiceAccessLevel.public,
      finalUrl: 'example.com',
      hops: [
        ServiceRouteHop(
          type: ServiceRouteHopType.portForward,
          method: ServiceRouteMethod.frp,
          serviceId: 'frp',
          deviceId: 'cloud',
          port: 443,
        ),
      ],
    ),
  ];
  return _FrpTopologyData(devices: devices, services: services, routes: routes);
}

ServiceTopologyNode _node(ServiceTopologyGraph graph, String id) =>
    graph.nodes.singleWhere((node) => node.id == id);

bool _hasEdge(ServiceTopologyGraph graph, String from, String to) =>
    graph.edges.any((edge) => edge.from == from && edge.to == to);

bool _horizontal(Offset a, Offset b) => (a.dy - b.dy).abs() < 0.01;

bool _vertical(Offset a, Offset b) => (a.dx - b.dx).abs() < 0.01;

bool _onHorizontalSide(Offset point, Rect rect) =>
    (point.dx - rect.left).abs() < 0.01 || (point.dx - rect.right).abs() < 0.01;

bool _segmentCrossesRectInterior(Offset a, Offset b, Rect rect) {
  final inner = rect.deflate(0.5);
  if (inner.isEmpty) return false;
  if (_horizontal(a, b)) {
    if (a.dy <= inner.top || a.dy >= inner.bottom) return false;
    return _rangesOverlap(a.dx, b.dx, inner.left, inner.right);
  }
  if (_vertical(a, b)) {
    if (a.dx <= inner.left || a.dx >= inner.right) return false;
    return _rangesOverlap(a.dy, b.dy, inner.top, inner.bottom);
  }
  return true;
}

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
  if (_horizontal(a, b)) {
    return a.dy > rect.top &&
        a.dy < rect.bottom &&
        _rangesOverlap(a.dx, b.dx, rect.left, rect.right);
  }
  if (_vertical(a, b)) {
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

class _FrpTopologyData {
  final List<Device> devices;
  final List<ServiceNode> services;
  final List<ServiceRoute> routes;

  const _FrpTopologyData({
    required this.devices,
    required this.services,
    required this.routes,
  });
}

class _SampleGraph {
  final ServiceTopologyGraph graph;
  final List<ServiceRoute> routes;

  const _SampleGraph(this.graph, this.routes);
}
