import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/services/service_analysis.dart';
import 'package:my_device/features/services/services/service_topology_layout.dart';

/// Purpose: Register the test cases defined in this file.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: This serves as the test entry point for the file.
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

  test('topology layout compacts sparse route rows within each rank', () {
    final graph = _buildSparseRouteGraph();
    final layout = ServiceTopologyLayout.build(graph.graph, graph.routes, 640);

    final appA = layout.nodeRects['service:app-a']!;
    final appB = layout.nodeRects['service:app-b']!;

    expect((appB.top - appA.top).abs(), lessThan(180));
  });

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

  test('a row of port chips is shorter than a row of cards', () {
    final data = _chipRowsData();
    final graph = buildServiceTopology(
      services: data.services,
      routes: data.routes,
      devices: data.devices,
    );
    final layout = ServiceTopologyLayout.build(graph, data.routes, 900);

    final chips = [
      layout.nodeRects['endpoint:app:a']!,
      layout.nodeRects['endpoint:app:b']!,
      layout.nodeRects['endpoint:app:c']!,
    ]..sort((a, b) => a.top.compareTo(b.top));
    final stride = chips[2].top - chips[1].top;
    expect(stride, lessThan(ServiceTopologyLayout.nodeHeight + 44));
    expect(
      stride,
      ServiceTopologyLayout.portChipSize + ServiceTopologyLayout.rowGap,
    );
    expect(
      chips[1].top - chips[0].top,
      ServiceTopologyLayout.nodeHeight + ServiceTopologyLayout.rowGap,
      reason: 'the first row also holds the service card',
    );
  });

  test('domain sinks share the last rank and paths stay clean', () {
    for (final sample in [_buildSampleGraph(), _frpSample()]) {
      final layout = ServiceTopologyLayout.build(
        sample.graph,
        sample.routes,
        480,
      );
      final lastRank = layout.nodeRanks.values.reduce(math.max);
      final domains = sample.graph.nodes.where(
        (node) => node.kind == ServiceTopologyNodeKind.domain,
      );
      expect(domains, isNotEmpty);
      for (final domain in domains) {
        expect(layout.nodeRanks[domain.id], lastRank, reason: domain.id);
      }
      _expectCleanPaths(sample.graph, layout);
    }

    final sample = _buildSampleGraph();
    final unaligned = ServiceTopologyLayout.build(
      sample.graph,
      sample.routes,
      480,
      options: const ServiceTopologyLayoutOptions(alignDomainSinks: false),
    );
    expect(
      {
        for (final node in sample.graph.nodes)
          if (node.kind == ServiceTopologyNodeKind.domain)
            unaligned.nodeRanks[node.id],
      }.length,
      greaterThan(1),
      reason: 'without alignment the sample domains sit on different ranks',
    );
  });

  test('countCrossings counts order swaps between ranks', () {
    ServiceTopologyEdge edge(String from, String to) =>
        ServiceTopologyEdge(from: from, to: to);
    final ranks = {'a': 0, 'b': 0, 'c': 1, 'd': 1, 'x': 2, 'y': 2};
    final positions = {
      'a': 0.0,
      'b': 1.0,
      'c': 0.0,
      'd': 1.0,
      'x': 0.0,
      'y': 1.0,
    };
    int count(List<ServiceTopologyEdge> edges) =>
        ServiceTopologyLayout.countCrossings(ranks, positions, edges);

    expect(count([edge('a', 'd'), edge('b', 'c')]), 1);
    expect(count([edge('a', 'c'), edge('b', 'd')]), 0);
    expect(count([edge('a', 'c'), edge('a', 'd')]), 0, reason: 'shared end');
    expect(count([edge('a', 'y'), edge('b', 'x')]), 1, reason: 'long edges');
    expect(
      count([edge('a', 'y'), edge('b', 'x'), edge('c', 'x')]),
      1,
      reason: 'meeting at a shared end is not a crossing',
    );
    expect(count([edge('a', 'b')]), 0, reason: 'same-rank edges are ignored');
  });

  test('the barycenter sweep removes crossings and never adds any', () {
    final shared = _sharedVpsSample();
    for (final group in [false, true]) {
      final unswept = ServiceTopologyLayout.build(
        shared.graph,
        shared.routes,
        900,
        options: ServiceTopologyLayoutOptions(
          groupByDevice: group,
          crossingSweeps: 0,
        ),
      );
      final swept = ServiceTopologyLayout.build(
        shared.graph,
        shared.routes,
        900,
        options: ServiceTopologyLayoutOptions(groupByDevice: group),
      );
      expect(swept.crossings, lessThan(unswept.crossings), reason: '$group');
      _expectCleanPaths(shared.graph, swept);
    }

    for (final sample in [
      _buildSampleGraph(),
      _buildSparseRouteGraph(),
      _frpSample(),
    ]) {
      for (final group in [false, true]) {
        final unswept = ServiceTopologyLayout.build(
          sample.graph,
          sample.routes,
          640,
          options: ServiceTopologyLayoutOptions(
            groupByDevice: group,
            crossingSweeps: 0,
          ),
        );
        final swept = ServiceTopologyLayout.build(
          sample.graph,
          sample.routes,
          640,
          options: ServiceTopologyLayoutOptions(groupByDevice: group),
        );
        expect(swept.crossings, lessThanOrEqualTo(unswept.crossings));
      }
    }
  });

  test('device containers hold their members and nothing else', () {
    for (final sample in [
      _buildSampleGraph(),
      _frpSample(),
      _sharedVpsSample(),
    ]) {
      final graph = sample.graph;
      final layout = ServiceTopologyLayout.build(
        graph,
        sample.routes,
        640,
        options: const ServiceTopologyLayoutOptions(groupByDevice: true),
      );
      final nodes = {for (final node in graph.nodes) node.id: node};
      final grouped = {
        for (final node in graph.nodes)
          if (node.kind == ServiceTopologyNodeKind.device &&
              graph.nodes.any(
                (other) =>
                    other.kind == ServiceTopologyNodeKind.service &&
                    other.deviceId == node.deviceId,
              ))
            node.id,
      };
      expect(layout.groupRects.keys.toSet(), grouped);

      bool member(String id, String group) {
        final node = nodes[id]!;
        return node.deviceId == nodes[group]!.deviceId &&
            (node.kind == ServiceTopologyNodeKind.service ||
                node.kind == ServiceTopologyNodeKind.endpoint ||
                node.kind == ServiceTopologyNodeKind.remoteEntry);
      }

      for (final entry in layout.groupRects.entries) {
        final container = entry.value;
        final header = layout.nodeRects[entry.key]!;
        expect(_inside(header, container), isTrue, reason: entry.key);
        expect(header.top, container.top);
        expect(header.height, ServiceTopologyLayout.containerHeaderHeight);
        for (final rect in layout.nodeRects.entries) {
          if (rect.key == entry.key) continue;
          if (member(rect.key, entry.key)) {
            expect(
              _inside(rect.value, container),
              isTrue,
              reason: '${rect.key} inside ${entry.key}',
            );
            expect(rect.value.top, greaterThan(header.bottom));
          } else {
            expect(
              rect.value.overlaps(container),
              isFalse,
              reason: '${rect.key} intrudes on ${entry.key}',
            );
          }
        }
        for (final other in layout.groupRects.entries) {
          if (other.key == entry.key) continue;
          expect(
            other.value.overlaps(container),
            isFalse,
            reason: '${other.key} overlaps ${entry.key}',
          );
        }
      }

      final implied = {
        for (final edge in graph.edges)
          if (grouped.contains(edge.from) &&
              nodes[edge.to]!.kind == ServiceTopologyNodeKind.service &&
              member(edge.to, edge.from))
            edge,
      };
      expect(layout.hiddenEdges, implied);
      expect(implied, isNotEmpty);
      _expectCleanPaths(graph, layout);

      final flat = ServiceTopologyLayout.build(graph, sample.routes, 640);
      expect(flat.groupRects, isEmpty);
      expect(flat.hiddenEdges, isEmpty);
      for (final edge in graph.edges) {
        expect(flat.edgePaths[edge], isNotNull);
      }
      for (final id in grouped) {
        expect(flat.nodeRects[id]!.height, ServiceTopologyLayout.nodeHeight);
      }
    }
  });

  test('the walkthrough graph groups home and VPS with the domain last', () {
    final sample = _frpSample();
    final layout = ServiceTopologyLayout.build(
      sample.graph,
      sample.routes,
      900,
      options: const ServiceTopologyLayoutOptions(groupByDevice: true),
    );
    expect(layout.groupRects.keys.toSet(), {'device:mac', 'device:cloud'});
    expect(
      layout.nodeRanks['endpoint:frp:frp57000'],
      layout.nodeRanks['remote:cloud::443'],
      reason: 'the FRP ports stay siblings',
    );
    expect(
      layout.nodeRanks['domain:example.com'],
      layout.nodeRanks.values.reduce(math.max),
    );
  });

  test('a 60-node, 80-edge graph lays out', () {
    final sample = _syntheticSample();
    expect(sample.graph.nodes.length, greaterThanOrEqualTo(60));
    expect(sample.graph.edges.length, greaterThanOrEqualTo(80));
    for (final group in [false, true]) {
      final watch = Stopwatch()..start();
      final layout = ServiceTopologyLayout.build(
        sample.graph,
        sample.routes,
        900,
        options: ServiceTopologyLayoutOptions(groupByDevice: group),
      );
      watch.stop();
      // Logged, not asserted: CI machines vary too much for a time limit.
      // ignore: avoid_print
      print(
        'synthetic topology (${sample.graph.nodes.length} nodes, '
        '${sample.graph.edges.length} edges, grouped: $group): '
        '${watch.elapsedMilliseconds} ms, ${layout.crossings} crossings',
      );
      expect(layout.nodeRects.length, sample.graph.nodes.length);
    }
  });
}

/// Purpose: Check that every drawn edge is an orthogonal path that avoids
/// every node but its own ends.
/// Inputs: `graph`, `layout`.
/// Returns: None.
/// Side effects: Records test expectations.
/// Notes: Hidden edges must have no path; every other edge must have one.
void _expectCleanPaths(
  ServiceTopologyGraph graph,
  ServiceTopologyLayout layout,
) {
  for (final edge in graph.edges) {
    final path = layout.edgePaths[edge];
    if (layout.hiddenEdges.contains(edge)) {
      expect(path, isNull, reason: 'hidden ${edge.from} -> ${edge.to}');
      continue;
    }
    expect(path, isNotNull, reason: '${edge.from} -> ${edge.to}');
    expect(path!.length, greaterThanOrEqualTo(2));
    for (var i = 1; i < path.length; i++) {
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
}

/// Purpose: Report whether one rect lies inside another.
/// Inputs: `inner`, `outer`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Allows a hundredth of a pixel for rounding.
bool _inside(Rect inner, Rect outer) {
  final slack = outer.inflate(0.01);
  return slack.left <= inner.left &&
      slack.top <= inner.top &&
      slack.right >= inner.right &&
      slack.bottom >= inner.bottom;
}

/// Purpose: Build the FRP walkthrough data as a sample graph.
/// Inputs: None.
/// Returns: `_SampleGraph`.
/// Side effects: None.
/// Notes: Caddy on a Mac publishes `example.com` through FRP on a VPS.
_SampleGraph _frpSample() {
  final data = _frpTopologyData();
  return _SampleGraph(
    buildServiceTopology(
      services: data.services,
      routes: data.routes,
      devices: data.devices,
    ),
    data.routes,
  );
}

/// Purpose: Build one service whose three endpoints are each a route's source.
/// Inputs: None.
/// Returns: `_FrpTopologyData` — devices, services and routes.
/// Side effects: None.
/// Notes: The routes have no hops and no targets, so the endpoint chips are
/// alone on their rows except the first, which the service card shares.
_FrpTopologyData _chipRowsData() {
  final device = Device(
    id: 'box',
    name: 'Box',
    category: DeviceCategory.desktop,
  );
  final service = ServiceNode(
    id: 'app',
    deviceId: device.id,
    name: 'App',
    endpoints: [
      ServiceEndpoint(id: 'a', port: 8001),
      ServiceEndpoint(id: 'b', port: 8002),
      ServiceEndpoint(id: 'c', port: 8003),
    ],
  );
  return _FrpTopologyData(
    devices: [device],
    services: [service],
    routes: [
      for (final endpoint in ['a', 'b', 'c'])
        ServiceRoute(
          id: 'route-$endpoint',
          name: 'Route $endpoint',
          sourceServiceId: service.id,
          sourceEndpointId: endpoint,
        ),
    ],
  );
}

/// Purpose: Build two home devices publishing through one shared VPS.
/// Inputs: None.
/// Returns: `_SampleGraph`.
/// Side effects: None.
/// Notes: Two services on each home device go out through one FRP server;
/// one domain is shared by a service of each device. Service names are
/// chosen so the label order interleaves the devices, which the row order
/// alone leaves crossed.
_SampleGraph _sharedVpsSample() {
  final devices = [
    Device(id: 'home-a', name: 'Alpha box', category: DeviceCategory.desktop),
    Device(id: 'home-b', name: 'Beta NAS', category: DeviceCategory.desktop),
    Device(id: 'vps', name: 'VPS', category: DeviceCategory.vps),
  ];
  ServiceNode service(String id, String device, String name, int port) =>
      ServiceNode(
        id: id,
        deviceId: device,
        name: name,
        endpoints: [ServiceEndpoint(id: '$id-ep', port: port, isPrimary: true)],
      );
  final services = [
    service('zapp', 'home-a', 'Zeta app', 8080),
    service('aapp', 'home-a', 'Alpha app', 8081),
    service('bapp', 'home-b', 'Beta app', 9000),
    service('capp', 'home-b', 'Aardvark', 9001),
    ServiceNode(
      id: 'frp',
      deviceId: 'vps',
      name: 'FRP',
      kind: ServiceKind.tunnel,
      endpoints: [ServiceEndpoint(id: 'frp-ep', port: 7000, isPrimary: true)],
    ),
  ];
  ServiceRoute frp(String id, String source, int port, String target) =>
      ServiceRoute(
        id: id,
        name: id,
        sourceServiceId: source,
        sourceEndpointId: '$source-ep',
        accessLevel: ServiceAccessLevel.public,
        finalUrl: target,
        hops: [
          ServiceRouteHop(
            type: ServiceRouteHopType.portForward,
            method: ServiceRouteMethod.frp,
            serviceId: 'frp',
            deviceId: 'vps',
            port: port,
          ),
        ],
      );
  final routes = [
    frp('r1', 'zapp', 443, 'shared.example.com'),
    frp('r2', 'bapp', 8443, 'shared.example.com'),
    frp('r3', 'aapp', 444, 'a.example.com'),
    frp('r4', 'capp', 445, 'c.example.com'),
    ServiceRoute(
      id: 'r5',
      name: 'r5',
      sourceServiceId: 'zapp',
      sourceEndpointId: 'zapp-ep',
      finalUrl: 'http://z.lan',
      hops: [
        ServiceRouteHop(
          type: ServiceRouteHopType.manual,
          method: ServiceRouteMethod.direct,
        ),
      ],
    ),
  ];
  return _SampleGraph(
    buildServiceTopology(services: services, routes: routes, devices: devices),
    routes,
  );
}

/// Purpose: Build a synthetic inventory of at least 60 nodes and 80 edges.
/// Inputs: None.
/// Returns: `_SampleGraph`.
/// Side effects: None.
/// Notes: Three home devices with a Caddy and three services each; every
/// service is published through one of two VPS FRP servers, two of them
/// through their device's Caddy first, and reached on the LAN as well.
_SampleGraph _syntheticSample() {
  final devices = <Device>[];
  final services = <ServiceNode>[];
  final routes = <ServiceRoute>[];
  for (var v = 0; v < 2; v++) {
    devices.add(
      Device(id: 'vps$v', name: 'VPS $v', category: DeviceCategory.vps),
    );
    services.add(
      ServiceNode(
        id: 'frp$v',
        deviceId: 'vps$v',
        name: 'FRP $v',
        kind: ServiceKind.tunnel,
        endpoints: [ServiceEndpoint(id: 'bind', port: 7000, isPrimary: true)],
      ),
    );
  }
  for (var d = 0; d < 3; d++) {
    devices.add(
      Device(id: 'home$d', name: 'Home $d', category: DeviceCategory.desktop),
    );
    services.add(
      ServiceNode(
        id: 'caddy$d',
        deviceId: 'home$d',
        name: 'Caddy $d',
        kind: ServiceKind.reverseProxy,
        endpoints: [ServiceEndpoint(id: 'https', port: 443, isPrimary: true)],
      ),
    );
    for (var s = 0; s < 3; s++) {
      final id = 'app$d-$s';
      services.add(
        ServiceNode(
          id: id,
          deviceId: 'home$d',
          name: 'App $d.$s',
          endpoints: [
            ServiceEndpoint(id: 'web', port: 8000 + s, isPrimary: true),
          ],
        ),
      );
      routes.add(
        ServiceRoute(
          id: '$id-public',
          name: '$id public',
          sourceServiceId: id,
          sourceEndpointId: 'web',
          accessLevel: ServiceAccessLevel.public,
          finalUrl: 'https://$id.example.com',
          hops: [
            if (s != 1)
              ServiceRouteHop(
                type: ServiceRouteHopType.reverseProxy,
                method: ServiceRouteMethod.caddy,
                serviceId: 'caddy$d',
                endpointId: 'https',
              ),
            ServiceRouteHop(
              type: ServiceRouteHopType.portForward,
              method: ServiceRouteMethod.frp,
              serviceId: 'frp${(d + s) % 2}',
              deviceId: 'vps${(d + s) % 2}',
              port: 10000 + d * 10 + s,
            ),
          ],
        ),
      );
      routes.add(
        ServiceRoute(
          id: '$id-lan',
          name: '$id lan',
          sourceServiceId: id,
          sourceEndpointId: 'web',
          finalUrl: 'http://home$d.lan:${8000 + s}',
          hops: [
            ServiceRouteHop(
              type: ServiceRouteHopType.manual,
              method: ServiceRouteMethod.direct,
            ),
          ],
        ),
      );
    }
  }
  return _SampleGraph(
    buildServiceTopology(services: services, routes: routes, devices: devices),
    routes,
  );
}

/// Purpose: Build and return sample graph for the current context.
/// Inputs: None.
/// Returns: `_SampleGraph`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
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

/// Purpose: Build a graph whose route rows would be sparse without rank-local compaction.
/// Inputs: None.
/// Returns: `_SampleGraph`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
_SampleGraph _buildSparseRouteGraph() {
  final device = Device(
    id: 'device-1',
    name: 'Mac mini',
    category: DeviceCategory.desktop,
  );
  final appA = ServiceNode(
    id: 'app-a',
    deviceId: device.id,
    name: 'App A',
    endpoints: [ServiceEndpoint(id: 'endpoint-a', port: 8000)],
  );
  final appB = ServiceNode(
    id: 'app-b',
    deviceId: device.id,
    name: 'App B',
    endpoints: [ServiceEndpoint(id: 'endpoint-b', port: 9000)],
  );
  final routes = [
    for (var i = 0; i < 6; i++)
      ServiceRoute(
        id: 'app-a-route-$i',
        name: 'App A Public $i',
        sourceServiceId: appA.id,
        sourceEndpointId: 'endpoint-a',
        accessLevel: ServiceAccessLevel.public,
        hops: [ServiceRouteHop(type: ServiceRouteHopType.tunnel)],
        finalUrl: 'https://a$i.example.com',
      ),
    ServiceRoute(
      id: 'app-b-route',
      name: 'App B Public',
      sourceServiceId: appB.id,
      sourceEndpointId: 'endpoint-b',
      accessLevel: ServiceAccessLevel.public,
      hops: [ServiceRouteHop(type: ServiceRouteHopType.tunnel)],
      finalUrl: 'https://b.example.com',
    ),
  ];
  final graph = buildServiceTopology(
    services: [appA, appB],
    routes: routes,
    devices: [device],
  );
  return _SampleGraph(graph, routes);
}

/// Purpose: Provide the internal frp topology data helper for this file.
/// Inputs: None.
/// Returns: `_FrpTopologyData`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
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

/// Purpose: Provide the internal node helper for this file.
/// Inputs: `graph`, `id`.
/// Returns: `ServiceTopologyNode`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
ServiceTopologyNode _node(ServiceTopologyGraph graph, String id) =>
    graph.nodes.singleWhere((node) => node.id == id);

/// Purpose: Provide the internal has edge helper for this file.
/// Inputs: `graph`, `from`, `to`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
bool _hasEdge(ServiceTopologyGraph graph, String from, String to) =>
    graph.edges.any((edge) => edge.from == from && edge.to == to);

/// Purpose: Provide the internal horizontal helper for this file.
/// Inputs: `a`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
bool _horizontal(Offset a, Offset b) => (a.dy - b.dy).abs() < 0.01;

bool _vertical(Offset a, Offset b) => (a.dx - b.dx).abs() < 0.01;

bool _onHorizontalSide(Offset point, Rect rect) =>
    (point.dx - rect.left).abs() < 0.01 || (point.dx - rect.right).abs() < 0.01;

/// Purpose: Provide the internal segment crosses rect interior helper for this file.
/// Inputs: `a`, `b`, `rect`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
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

/// Purpose: Provide the internal polyline intersects rect helper for this file.
/// Inputs: `path`, `rect`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
bool _polylineIntersectsRect(List<Offset> path, Rect rect) {
  for (var i = 1; i < path.length; i++) {
    if (_segmentIntersectsRect(path[i - 1], path[i], rect)) return true;
  }
  return false;
}

/// Purpose: Provide the internal segment intersects rect helper for this file.
/// Inputs: `a`, `b`, `rect`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
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

/// Purpose: Provide the internal ranges overlap helper for this file.
/// Inputs: `a1`, `a2`, `b1`, `b2`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
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

  /// Purpose: Create a frp topology data instance.
  /// Inputs: None.
  /// Returns: A new `_FrpTopologyData` instance.
  /// Side effects: None.
  /// Notes: None.
  const _FrpTopologyData({
    required this.devices,
    required this.services,
    required this.routes,
  });
}

class _SampleGraph {
  final ServiceTopologyGraph graph;
  final List<ServiceRoute> routes;

  /// Purpose: Create a sample graph instance.
  /// Inputs: `graph`, `routes`.
  /// Returns: A new `_SampleGraph` instance.
  /// Side effects: Implementation-dependent.
  /// Notes: Implementations should preserve this contract.
  const _SampleGraph(this.graph, this.routes);
}
